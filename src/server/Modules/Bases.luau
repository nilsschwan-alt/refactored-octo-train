-- Verwaltet die Bases: Spieler zuweisen, Kreaturen anzeigen, Geld (kommt automatisch),
-- Verkaufen, Upgrades und das Base-Schloss.
-- Kreaturen stehen im Spielstand als Eintrag: "Blubbo" oder "Blubbo|Gold".

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
-- Aufgaben-Fortschritt melden. Wird von Quests.Init gesetzt (so gibt es keine Schleife zwischen den Modulen).
Bases.Track = function(_state, _kind: string, _amount: number) end
local remotes
local lastClick = {} -- [player] = os.clock()

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
	end
end

function Bases.GetState(player: Player)
	return Bases.States[player]
end

function Bases.Level(state)
	return Config.BaseLevels[state.Data.BaseLevel]
end

-- Geld ---------------------------------------------------------------------------
-- source = "quest": zählt nicht für die "Verdiene X $"-Aufgabe
function Bases.AddMoney(state, amount: number, source: string?)
	state.Data.Money = math.max(0, state.Data.Money + amount)
	if amount > 0 then
		state.Data.TotalEarned += amount
		if source ~= "quest" then
			Bases.Track(state, "Earn", amount)
		end
	end
	state.Player:SetAttribute("Money", math.floor(state.Data.Money))
	if state.MoneyValue then
		state.MoneyValue.Value = math.floor(state.Data.Money)
	end
end

function Bases.Income(state): number
	local total = 0
	for slotKey, entry in state.Data.Slots do
		if not state.Plot.Stolen[tonumber(slotKey)] then
			total += Config.EntryIncome(entry)
		end
	end
	return total * Bases.Multiplier(state)
end

-- Alle Boni zusammen: Base-Stufe x Wiedergeburt x Goldrausch
function Bases.Multiplier(state): number
	return Bases.Level(state).IncomeBonus * Config.RebirthMultiplier(state.Data.Rebirths) * Bases.IncomeMultiplier
end

-- Schwebende "+X $"-Zahl an einer Stelle in der Welt (nur für diesen Spieler)
function Bases.Pop(player: Player, amount: number, position: Vector3, model: Instance?, color: Color3?)
	if player.Parent then
		remotes.Pop:FireClient(player, amount, position, model, color)
	end
end

-- Attribute für die Anzeige im Client (Rebirth-Menü, Shop-Chancen)
function Bases.RefreshStats(state)
	local player = state.Player
	local data = state.Data
	player:SetAttribute("Rebirths", data.Rebirths)
	player:SetAttribute("Tokens", data.Tokens)
	player:SetAttribute("BaseLevel", data.BaseLevel)
	for id in Config.Rebirth.Upgrades do
		player:SetAttribute("Up_" .. id, data.Upgrades[id] or 0)
	end
	if state.RebirthValue then
		state.RebirthValue.Value = data.Rebirths
	end
	if state.LevelValue then
		state.LevelValue.Value = data.BaseLevel
	end
end

-- Klick auf eine eigene Kreatur = sofort Geld
function Bases.Click(player: Player, plot, slot: number)
	local state = Bases.States[player]
	if not state or state.Plot ~= plot or plot.Stolen[slot] then
		return
	end
	local now = os.clock()
	if lastClick[player] and now - lastClick[player] < Config.Click.Cooldown then
		return
	end
	lastClick[player] = now
	local entry = state.Data.Slots[tostring(slot)]
	local model = plot.SlotModels[slot]
	if not entry or not model then
		return
	end
	local power = 1 + (state.Data.Upgrades.ClickPower or 0) * Config.Rebirth.Upgrades.ClickPower.PerLevel
	local amount = math.max(
		Config.Click.MinValue,
		math.floor(Config.EntryIncome(entry) * Config.Click.IncomeSeconds * Bases.Multiplier(state) * power)
	)
	Bases.AddMoney(state, amount)
	Bases.Track(state, "Clicks", 1)
	Bases.Pop(player, amount, model:GetPivot().Position + Vector3.new(0, 4, 0), model)
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

-- Leuchtring unter einem Platz in der Seltenheits-Farbe färben (nil = leer, Grundfarbe)
local function colorRing(plot, slot: number, color: Color3?)
	local ring = plot.Decor:FindFirstChild("PlatzRing" .. slot)
	if ring and ring:IsA("BasePart") then
		ring.Color = color or ring:GetAttribute("EmptyColor") or ring.Color
	end
end

-- Alle Leuchtringe neu färben (nach einem Base-Upgrade, weil dann die Deko neu gebaut wird)
function Bases.RefreshRings(state)
	local plot = state.Plot
	for slot = 1, Config.BaseLevels[#Config.BaseLevels].Slots do
		local entry = state.Data.Slots[tostring(slot)]
		local def = entry and not plot.Stolen[slot] and Config.ParseEntry(entry)
		colorRing(plot, slot, def and Config.Rarities[def.Rarity].Color or nil)
	end
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
		colorRing(plot, slot, nil)
		return
	end
	local def, mutation = Config.ParseEntry(entry)
	if not def then
		colorRing(plot, slot, nil)
		return
	end
	colorRing(plot, slot, Config.Rarities[def.Rarity].Color)
	local model = CreatureModels.Build(def, { Label = true, Mutation = mutation })
	model:PivotTo(Map.SlotCFrame(plot, slot))
	local body = model.PrimaryPart
	local rarity = Config.Rarities[def.Rarity]
	local name = Config.EntryName(entry)
	addPrompt(body, "Steal", "Klauen", name, rarity.StealTime, plot, slot)
	local sellPrice = math.floor(Config.EntryValue(entry) * Config.SellFactor)
	addPrompt(body, "Sell", `Verkaufen ({Config.FormatNumber(sellPrice)} $)`, name, 0.6, plot, slot)
	-- Anklicken = Geld (nur der Besitzer bekommt etwas)
	local clicker = Instance.new("ClickDetector")
	clicker.MaxActivationDistance = Config.Click.MaxDistance
	clicker.Parent = body
	clicker.MouseClick:Connect(function(who)
		Bases.Click(who, plot, slot)
	end)
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
		plot.Laser.Transparency = 1
		plot.LockPrompt:SetAttribute("Active", false)
		plot.UpgradePrompt:SetAttribute("Active", false)
		plot.Model:SetAttribute("Locked", false)
		return
	end

	local level = state.Data.BaseLevel
	local levelInfo = Config.BaseLevels[level]
	labels[1].Text = `Base von {owner.DisplayName}`
	labels[2].Text = `Stufe {level}: {levelInfo.Name} · +{Config.FormatNumber(Bases.Income(state))} $/s`
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
	local rebirthValue = Instance.new("IntValue")
	rebirthValue.Name = "Rebirths"
	rebirthValue.Value = data.Rebirths
	rebirthValue.Parent = leaderstats
	leaderstats.Parent = player
	state.MoneyValue = money
	state.LevelValue = levelValue
	state.RebirthValue = rebirthValue

	-- Früher gab es eine Kasse zum Einsammeln. Was dort aus alten Spielständen noch liegt,
	-- kommt jetzt direkt aufs Konto.
	if data.Cash and data.Cash >= 1 then
		data.Money += math.floor(data.Cash)
	end
	data.Cash = 0
	Bases.AddMoney(state, 0)
	Bases.RefreshStats(state)
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
	lastClick[player] = nil
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
	Bases.RefreshStats(state)
	Map.BuildDecor(state.Plot, state.Data.BaseLevel)
	Bases.RefreshRings(state)
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

-- Läuft jede Sekunde: Geld direkt aufs Konto, Schloss-Timer, Schilder
function Bases.Tick(dt: number)
	local now = os.clock()
	for player, state in Bases.States do
		local income = Bases.Income(state)
		if income > 0 then
			Bases.AddMoney(state, income * dt)
		end
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
