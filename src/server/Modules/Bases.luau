-- Verwaltet die Bases: Spieler zuweisen, Kreaturen anzeigen, Geld, Kaufen,
-- Verkaufen, Upgrades und das Base-Schloss.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Map = require(script.Parent.Map)
local CreatureModels = require(script.Parent.CreatureModels)

local Bases = {}

Bases.Plots = {}
Bases.States = {} -- [player] = state
local remotes

function Bases.Init(plots, remoteFolder)
	Bases.Plots = plots
	remotes = remoteFolder
	for _, plot in plots do
		Bases.RefreshPlot(plot)
	end
end

function Bases.Notify(player: Player, text: string, color: Color3?)
	if player and player.Parent then
		remotes.Notify:FireClient(player, text, color or Color3.new(1, 1, 1))
	end
end

function Bases.GetState(player: Player)
	return Bases.States[player]
end

function Bases.Level(state)
	return Config.BaseLevels[state.Data.BaseLevel]
end

-- Geld --------------------------------------------------------------------
function Bases.AddMoney(state, amount: number)
	state.Data.Money = math.max(0, state.Data.Money + amount)
	state.Player:SetAttribute("Money", math.floor(state.Data.Money))
	if state.MoneyValue then
		state.MoneyValue.Value = math.floor(state.Data.Money)
	end
end

function Bases.Income(state): number
	local total = 0
	for slotKey, id in state.Data.Slots do
		if not state.Plot.Stolen[tonumber(slotKey)] then
			total += Config.CreatureById[id].Income
		end
	end
	return total * Bases.Level(state).IncomeBonus
end

-- Plätze ------------------------------------------------------------------
function Bases.FreeSlot(state): number?
	for slot = 1, Bases.Level(state).Slots do
		if state.Data.Slots[tostring(slot)] == nil then
			return slot
		end
	end
	return nil
end

local function addPrompt(parent, kind, action, object, hold, plot, slot)
	local p = Map.MakePrompt(parent, kind, action, object, hold, 10)
	p:SetAttribute("PlotIndex", plot.Index)
	p:SetAttribute("Slot", slot)
	return p
end

-- Zeigt die Kreatur auf einem Platz an (oder entfernt sie, wenn der Platz leer/geklaut ist)
function Bases.RenderSlot(state, slot: number)
	local plot = state.Plot
	local old = plot.SlotModels[slot]
	if old then
		old:Destroy()
		plot.SlotModels[slot] = nil
	end
	local id = state.Data.Slots[tostring(slot)]
	if not id or plot.Stolen[slot] then
		return
	end
	local def = Config.CreatureById[id]
	local model = CreatureModels.Build(def, { Label = true })
	model:PivotTo(Map.SlotCFrame(plot, slot))
	model:SetAttribute("Slot", slot)
	local body = model.PrimaryPart
	local rarity = Config.Rarities[def.Rarity]
	addPrompt(body, "Steal", "Klauen", def.Name, rarity.StealTime, plot, slot)
	local sellPrice = math.floor(def.Price * Config.SellFactor)
	addPrompt(body, "Sell", `Verkaufen ({Config.FormatNumber(sellPrice)} $)`, def.Name, 0.6, plot, slot)
	model.Parent = plot.Creatures
	plot.SlotModels[slot] = model
end

function Bases.RenderAll(state)
	for slot = 1, Config.BaseLevels[#Config.BaseLevels].Slots do
		Bases.RenderSlot(state, slot)
	end
end

function Bases.PlaceCreature(state, slot: number, id: string)
	state.Data.Slots[tostring(slot)] = id
	Bases.RenderSlot(state, slot)
end

-- Schild, Schloss-Anzeige, Upgrade-Knopf aktualisieren
function Bases.RefreshPlot(plot)
	local owner = plot.Owner
	local state = owner and Bases.States[owner]
	local labels = plot.SignLabels
	if not state then
		labels[1].Text = "Freie Base"
		labels[2].Text = ""
		labels[3].Text = ""
		plot.Laser.Transparency = 1
		plot.LockPrompt:SetAttribute("Active", false)
		plot.UpgradePrompt:SetAttribute("Active", false)
		plot.Model:SetAttribute("Locked", false)
		return
	end

	local level = state.Data.BaseLevel
	local levelInfo = Config.BaseLevels[level]
	labels[1].Text = `Base von {owner.DisplayName}`
	labels[2].Text = `Stufe {level}: {levelInfo.Name}`
	labels[2].TextColor3 = Color3.fromRGB(255, 220, 90)

	local now = os.clock()
	if state.Locked then
		local left = math.ceil(state.LockEnd - now)
		labels[3].Text = `🔒 Abgeschlossen ({left}s)`
		labels[3].TextColor3 = Color3.fromRGB(255, 90, 90)
		plot.Laser.Transparency = 0.45
		plot.LockPrompt.ActionText = `Zu ({left}s)`
	else
		labels[3].Text = "Offen"
		labels[3].TextColor3 = Color3.fromRGB(150, 255, 150)
		plot.Laser.Transparency = 1
		local wait = math.ceil(state.LockReadyAt - now)
		plot.LockPrompt.ActionText = if wait > 0 then `Bereit in {wait}s` else `Abschließen ({levelInfo.LockTime}s)`
	end
	plot.LockPrompt:SetAttribute("Active", true)
	plot.Model:SetAttribute("Locked", state.Locked)

	local nextLevel = Config.BaseLevels[level + 1]
	if nextLevel then
		plot.UpgradePrompt.ActionText = `Upgrade: {Config.FormatNumber(nextLevel.Cost)} $`
		plot.UpgradePrompt.ObjectText = `Stufe {level + 1}: {nextLevel.Name}`
		plot.UpgradePrompt:SetAttribute("Active", true)
	else
		plot.UpgradePrompt.ActionText = "Max. Stufe"
		plot.UpgradePrompt:SetAttribute("Active", false)
	end
end

-- Spieler kommt / geht -----------------------------------------------------
function Bases.AddPlayer(player: Player, data, saveable: boolean)
	local plot
	for _, p in Bases.Plots do
		if not p.Owner then
			plot = p
			break
		end
	end
	if not plot then
		return nil
	end

	local state = {
		Player = player,
		Data = data,
		Saveable = saveable,
		Plot = plot,
		Locked = false,
		LockEnd = 0,
		LockReadyAt = 0,
	}
	Bases.States[player] = state
	plot.Owner = player
	plot.Model:SetAttribute("OwnerUserId", player.UserId)
	player:SetAttribute("PlotIndex", plot.Index)

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local money = Instance.new("IntValue")
	money.Name = "Geld"
	money.Parent = leaderstats
	local levelValue = Instance.new("IntValue")
	levelValue.Name = "Base"
	levelValue.Value = data.BaseLevel
	levelValue.Parent = leaderstats
	leaderstats.Parent = player
	state.MoneyValue = money
	state.LevelValue = levelValue

	Bases.AddMoney(state, 0)
	player:SetAttribute("BaseLevel", data.BaseLevel)
	Map.BuildDecor(plot, data.BaseLevel)
	Bases.RenderAll(state)
	Bases.RefreshPlot(plot)
	return state
end

function Bases.RemovePlayer(player: Player)
	local state = Bases.States[player]
	if not state then
		return nil
	end
	local plot = state.Plot
	Bases.States[player] = nil
	for slot, model in plot.SlotModels do
		model:Destroy()
		plot.SlotModels[slot] = nil
	end
	table.clear(plot.Stolen)
	plot.Owner = nil
	plot.Model:SetAttribute("OwnerUserId", nil)
	Map.BuildDecor(plot, 1)
	Bases.RefreshPlot(plot)
	return state
end

-- Aktionen -------------------------------------------------------------------
function Bases.Buy(player: Player, creatureId: string)
	local state = Bases.States[player]
	local def = Config.CreatureById[creatureId]
	if not state or not def then
		return
	end
	if state.Data.Money < def.Price then
		Bases.Notify(player, "Nicht genug Geld!", Color3.fromRGB(255, 90, 90))
		return
	end
	local slot = Bases.FreeSlot(state)
	if not slot then
		Bases.Notify(player, "Deine Base ist voll! Upgraden oder etwas verkaufen.", Color3.fromRGB(255, 90, 90))
		return
	end
	Bases.AddMoney(state, -def.Price)
	Bases.PlaceCreature(state, slot, def.Id)
	Bases.Notify(player, `{def.Name} gekauft!`, Config.Rarities[def.Rarity].Color)
end

function Bases.Sell(player: Player, plotIndex: number, slot: number)
	local state = Bases.States[player]
	if not state or state.Plot.Index ~= plotIndex or state.Plot.Stolen[slot] then
		return
	end
	local id = state.Data.Slots[tostring(slot)]
	if not id then
		return
	end
	local def = Config.CreatureById[id]
	state.Data.Slots[tostring(slot)] = nil
	Bases.RenderSlot(state, slot)
	local price = math.floor(def.Price * Config.SellFactor)
	Bases.AddMoney(state, price)
	Bases.Notify(player, `{def.Name} für {Config.FormatNumber(price)} $ verkauft.`)
end

function Bases.Upgrade(player: Player, plotIndex: number)
	local state = Bases.States[player]
	if not state or state.Plot.Index ~= plotIndex then
		return
	end
	local nextLevel = Config.BaseLevels[state.Data.BaseLevel + 1]
	if not nextLevel then
		return
	end
	if state.Data.Money < nextLevel.Cost then
		Bases.Notify(player, `Du brauchst {Config.FormatNumber(nextLevel.Cost)} $ für das Upgrade.`, Color3.fromRGB(255, 90, 90))
		return
	end
	Bases.AddMoney(state, -nextLevel.Cost)
	state.Data.BaseLevel += 1
	state.LevelValue.Value = state.Data.BaseLevel
	player:SetAttribute("BaseLevel", state.Data.BaseLevel)
	Map.BuildDecor(state.Plot, state.Data.BaseLevel)
	Bases.RefreshPlot(state.Plot)
	Bases.Notify(player, `Base verbessert: {nextLevel.Name}! Jetzt {nextLevel.Slots} Plätze.`, Color3.fromRGB(80, 255, 120))
end

function Bases.Lock(player: Player, plotIndex: number)
	local state = Bases.States[player]
	if not state or state.Plot.Index ~= plotIndex or state.Locked then
		return
	end
	local now = os.clock()
	if now < state.LockReadyAt then
		Bases.Notify(player, `Schloss lädt noch ({math.ceil(state.LockReadyAt - now)}s).`, Color3.fromRGB(255, 200, 90))
		return
	end
	local lockTime = Bases.Level(state).LockTime
	state.Locked = true
	state.LockEnd = now + lockTime
	state.LockReadyAt = state.LockEnd + Config.LockCooldown
	Bases.RefreshPlot(state.Plot)
	Bases.Notify(player, `Base für {lockTime} Sekunden abgeschlossen!`, Color3.fromRGB(255, 120, 120))
end

-- Läuft jede Sekunde: Einkommen auszahlen, Schloss-Timer, Schilder
function Bases.Tick(dt: number)
	local now = os.clock()
	for player, state in Bases.States do
		local income = Bases.Income(state)
		Bases.AddMoney(state, income * dt)
		player:SetAttribute("Income", income)
		if state.Locked and now >= state.LockEnd then
			state.Locked = false
			Bases.Notify(player, "Deine Base ist wieder offen!", Color3.fromRGB(255, 200, 90))
		end
		Bases.RefreshPlot(state.Plot)
	end
end

function Bases.IsInsideOwnBase(state, position: Vector3): boolean
	return Map.IsInside(state.Plot, position)
end

-- Beim Spawnen in die eigene Base setzen
function Bases.SpawnCFrame(state): CFrame
	return state.Plot.SpawnCFrame
end

return Bases
