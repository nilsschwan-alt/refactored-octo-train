-- Verwaltet die Bases: Spieler zuweisen, Kreaturen anzeigen, Geld und Kasse,
-- Verkaufen, Upgrades und das Base-Schloss.
-- Kreaturen stehen im Spielstand als Eintrag: "Blubbo" oder "Blubbo|Gold".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Map = require(script.Parent.Map)
local CreatureModels = require(script.Parent.CreatureModels)
local FX = require(script.Parent.FX)

local Bases = {}

Bases.Plots = {}
Bases.States = {} -- [player] = state
Bases.IncomeMultiplier = 1 -- wird vom Goldrausch-Event verändert
Bases.LocksDisabled = false -- Diebes-Nacht: keine Schlösser
local remotes

local RED = Color3.fromRGB(255, 90, 90)

-- Nachrichten an Spieler ---------------------------------------------------------
function Bases.Notify(player: Player, text: string, color: Color3?)
	if player and player.Parent then
		remotes.Notify:FireClient(player, text, color or Color3.new(1, 1, 1))
	end
end

-- Großer Text in der Bildschirmmitte (z.B. "GEKLAUT!")
function Bases.BigText(player: Player, text: string, color: Color3, sound: string?, flash: boolean?)
	if player and player.Parent then
		remotes.BigText:FireClient(player, text, color, sound, flash)
	end
end

-- Ansage für den ganzen Server (mit Konfetti)
function Bases.Announce(text: string, color: Color3)
	remotes.Announce:FireAllClients(text, color)
end

-- Seltener Fund? Dann großer Reveal für alle
function Bases.AnnounceIfRare(player: Player, entry: string, how: string)
	local def, mutation = Config.ParseEntry(entry)
	if not def then
		return
	end
	local rank = Config.RarityRank(def.Rarity)
	if rank >= Config.RarityRank("Legendary") or mutation == "Regenbogen" then
		local rarity = Config.Rarities[def.Rarity]
		Bases.Announce(
			`{player.DisplayName} hat {how}: {string.upper(rarity.Name)} {Config.EntryName(entry)}!`,
			rarity.Color
		)
	end
end

function Bases.Init(plots, remoteFolder)
	Bases.Plots = plots
	remotes = remoteFolder
	for _, plot in plots do
		Bases.RefreshPlot(plot)
		-- Kasse einsammeln durch Drüberlaufen
		plot.CashPad.Touched:Connect(function(hit)
			local player = Players:GetPlayerFromCharacter(hit.Parent)
			if player and plot.Owner == player then
				Bases.CollectCash(Bases.States[player])
			end
		end)
	end
end

function Bases.GetState(player: Player)
	return Bases.States[player]
end

function Bases.Level(state)
	return Config.BaseLevels[state.Data.BaseLevel]
end

-- Geld ---------------------------------------------------------------------------
function Bases.AddMoney(state, amount: number)
	state.Data.Money = math.max(0, state.Data.Money + amount)
	state.Player:SetAttribute("Money", math.floor(state.Data.Money))
	if state.MoneyValue then
		state.MoneyValue.Value = math.floor(state.Data.Money)
	end
end

function Bases.CollectCash(state)
	if not state then
		return
	end
	local amount = math.floor(state.Data.Cash)
	if amount < 1 then
		return
	end
	state.Data.Cash -= amount
	Bases.AddMoney(state, amount)
	remotes.MoneyPopup:FireClient(state.Player, amount)
	Bases.RefreshCash(state)
	FX.Burst(state.Plot.CashPad.Position + Vector3.new(0, 1, 0), Color3.fromRGB(255, 215, 50), 25)
end

function Bases.RefreshCash(state)
	state.Plot.CashLabel.Text = `{Config.FormatNumber(state.Data.Cash)} $`
end

function Bases.Income(state): number
	local total = 0
	for slotKey, entry in state.Data.Slots do
		if not state.Plot.Stolen[tonumber(slotKey)] then
			total += Config.EntryIncome(entry)
		end
	end
	return total * Bases.Level(state).IncomeBonus * Bases.IncomeMultiplier
end

-- Plätze ---------------------------------------------------------------------------
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
	local entry = state.Data.Slots[tostring(slot)]
	if not entry or plot.Stolen[slot] then
		return
	end
	local def, mutation = Config.ParseEntry(entry)
	if not def then
		return
	end
	local model = CreatureModels.Build(def, { Label = true, Mutation = mutation })
	model:PivotTo(Map.SlotCFrame(plot, slot))
	local body = model.PrimaryPart
	local rarity = Config.Rarities[def.Rarity]
	local name = Config.EntryName(entry)
	addPrompt(body, "Steal", "Klauen", name, rarity.StealTime, plot, slot)
	local sellPrice = math.floor(Config.EntryValue(entry) * Config.SellFactor)
	addPrompt(body, "Sell", `Verkaufen ({Config.FormatNumber(sellPrice)} $)`, name, 0.6, plot, slot)
	model.Parent = plot.Creatures
	plot.SlotModels[slot] = model
end

function Bases.RenderAll(state)
	for slot = 1, Config.BaseLevels[#Config.BaseLevels].Slots do
		Bases.RenderSlot(state, slot)
	end
end

-- Neue Kreatur in die Base stellen. Gibt den Platz zurück oder nil, wenn voll.
function Bases.GiveCreature(state, entry: string): number?
	local slot = Bases.FreeSlot(state)
	if not slot then
		return nil
	end
	state.Data.Slots[tostring(slot)] = entry
	Bases.RenderSlot(state, slot)
	-- Neue Kreatur ploppt mit Funken auf
	local model = state.Plot.SlotModels[slot]
	local def = Config.ParseEntry(entry)
	if model and def then
		FX.PopIn(model)
		FX.Burst(model:GetPivot().Position + Vector3.new(0, 2, 0), Config.Rarities[def.Rarity].Color, 35)
		FX.Ring(model:GetPivot().Position + Vector3.new(0, 0.3, 0), Config.Rarities[def.Rarity].Color, 8)
	end
	return slot
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
		plot.CashLabel.Text = ""
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
		labels[3].TextColor3 = RED
		plot.Laser.Transparency = 0.45
		plot.LockPrompt.ActionText = `Zu ({left}s)`
	else
		labels[3].Text = if Bases.LocksDisabled then "Diebes-Nacht: kein Schloss!" else "Offen"
		labels[3].TextColor3 = if Bases.LocksDisabled then RED else Color3.fromRGB(150, 255, 150)
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
	Bases.RefreshCash(state)
end

-- Spieler kommt / geht -------------------------------------------------------------
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
	player:SetAttribute("Pity", data.Pity)
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

-- Tagesbonus beim Joinen
function Bases.CheckDailyBonus(state)
	local today = math.floor(os.time() / 86400)
	if state.Data.LastDaily >= today then
		return
	end
	state.Data.LastDaily = today
	local bonus = Config.DailyBonus[state.Data.BaseLevel] or Config.DailyBonus[1]
	Bases.AddMoney(state, bonus)
	Bases.BigText(state.Player, `TAGESBONUS +{Config.FormatNumber(bonus)} $`, Color3.fromRGB(255, 220, 60), "Reveal")
	remotes.MoneyPopup:FireClient(state.Player, bonus)
end

-- Aktionen -------------------------------------------------------------------------
function Bases.Sell(player: Player, plotIndex: number, slot: number)
	local state = Bases.States[player]
	if not state or state.Plot.Index ~= plotIndex or state.Plot.Stolen[slot] then
		return
	end
	local entry = state.Data.Slots[tostring(slot)]
	if not entry then
		return
	end
	state.Data.Slots[tostring(slot)] = nil
	Bases.RenderSlot(state, slot)
	local price = math.floor(Config.EntryValue(entry) * Config.SellFactor)
	Bases.AddMoney(state, price)
	remotes.MoneyPopup:FireClient(player, price)
	Bases.Notify(player, `{Config.EntryName(entry)} für {Config.FormatNumber(price)} $ verkauft.`)
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
		Bases.Notify(player, `Du brauchst {Config.FormatNumber(nextLevel.Cost)} $ für das Upgrade.`, RED)
		return
	end
	Bases.AddMoney(state, -nextLevel.Cost)
	state.Data.BaseLevel += 1
	state.LevelValue.Value = state.Data.BaseLevel
	player:SetAttribute("BaseLevel", state.Data.BaseLevel)
	Map.BuildDecor(state.Plot, state.Data.BaseLevel)
	Bases.RefreshPlot(state.Plot)
	Bases.BigText(player, `BASE-UPGRADE: {string.upper(nextLevel.Name)}!`, Color3.fromRGB(80, 255, 120), "Upgrade")
	local center = state.Plot.CFrame.Position + Vector3.new(0, 0.5, 0)
	FX.Ring(center, Color3.fromRGB(80, 255, 120), 50)
	for _, offset in { Vector3.new(-20, 4, -20), Vector3.new(20, 4, -20), Vector3.new(-20, 4, 20), Vector3.new(20, 4, 20) } do
		FX.Burst(state.Plot.CFrame:PointToWorldSpace(offset), Color3.fromRGB(80, 255, 120), 40)
	end
	Bases.Notify(player, `Jetzt {nextLevel.Slots} Plätze und x{nextLevel.IncomeBonus} Einkommen.`, Color3.fromRGB(80, 255, 120))
	if state.Data.BaseLevel >= 4 then
		Bases.Announce(`{player.DisplayName} hat jetzt einen {nextLevel.Name}!`, Color3.fromRGB(80, 255, 120))
	end
end

function Bases.Lock(player: Player, plotIndex: number)
	local state = Bases.States[player]
	if not state or state.Plot.Index ~= plotIndex or state.Locked then
		return
	end
	if Bases.LocksDisabled then
		Bases.Notify(player, "Diebes-Nacht! Schlösser gehen gerade nicht.", RED)
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

-- Alle Schlösser öffnen (Diebes-Nacht)
function Bases.UnlockAll()
	for _, state in Bases.States do
		state.Locked = false
		Bases.RefreshPlot(state.Plot)
	end
end

-- Läuft jede Sekunde: Geld in die Kasse, Schloss-Timer, Schilder
function Bases.Tick(dt: number)
	local now = os.clock()
	for player, state in Bases.States do
		local income = Bases.Income(state)
		state.Data.Cash += income * dt
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

function Bases.SpawnCFrame(state): CFrame
	return state.Plot.SpawnCFrame
end

return Bases
