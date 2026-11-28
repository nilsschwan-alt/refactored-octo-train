-- Verwaltet die Bases: Spieler zuweisen, Kreaturen anzeigen, Geld (kommt automatisch),
-- Verkaufen, Verschmelzen (Sterne), Upgrades und das Base-Schloss.
-- Kreaturen stehen im Spielstand als Eintrag: "Blubbo", "Blubbo|Gold" oder mit Sternen "Blubbo|Gold|2".

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Map = require(script.Parent.Map)
local CreatureModels = require(script.Parent.CreatureModels)
local FX = require(script.Parent.FX)

local Bases = {}

Bases.Plots = {}
Bases.States = {} -- [player] = state
Bases.IncomeMultiplier = 1 -- wird vom Goldrausch-Event verändert
Bases.EventEarned = nil :: { [Player]: number }? -- zählt während eines Events mit, wer wie viel verdient
Bases.LocksDisabled = false -- Diebes-Nacht: keine Schlösser
-- Aufgaben-Fortschritt melden. Wird von Quests.Init gesetzt (so gibt es keine Schleife zwischen den Modulen).
Bases.Track = function(_state, _kind: string, _amount: number) end
local remotes
local mergePending = {} -- [state] = true, wenn die Verschmelzen-Liste an den Client raus muss

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
			`{player.DisplayName} hat {how}: {Config.Upper(rarity.Name)} {Config.EntryName(entry)}!`,
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

-- Wirkung einer Fähigkeit aus dem Skill-Baum (Stufe x Wirkung pro Stufe, 0 = nicht gelernt)
function Bases.Skill(state, id: string): number
	return Config.SkillValue(state.Data.Skills, id)
end

-- Verkaufspreis einer Kreatur für diesen Spieler (mit der Fähigkeit "Händler")
function Bases.SellPrice(state, entry: string): number
	return math.floor(Config.EntryValue(entry) * Config.SellFactor * (1 + Bases.Skill(state, "SellBonus")))
end

-- So lange hält das Schloss / so lange ist danach Pause (mit den Schloss-Fähigkeiten)
function Bases.LockTime(state): number
	return math.floor(Bases.Level(state).LockTime * (1 + Bases.Skill(state, "LockTime")) + 0.5)
end
function Bases.LockCooldown(state): number
	return math.max(10, Config.LockCooldown - Bases.Skill(state, "LockCooldown"))
end

-- Geld ---------------------------------------------------------------------------
-- source = "quest": zählt nicht für die "Verdiene X $"-Aufgabe
function Bases.AddMoney(state, amount: number, source: string?)
	state.Data.Money = math.max(0, state.Data.Money + amount)
	if amount > 0 then
		local earned = Bases.EventEarned
		if earned then
			earned[state.Player] = (earned[state.Player] or 0) + amount
		end
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

-- Goldrausch-Faktor für diesen Spieler (1 = gerade kein Goldrausch).
-- Fähigkeit "Goldgräber": im Goldrausch noch etwas obendrauf
function Bases.RushFactor(state): number
	if Bases.IncomeMultiplier <= 1 then
		return 1
	end
	return Bases.IncomeMultiplier * (1 + Bases.Skill(state, "GoldRush"))
end

-- Alle Boni zusammen: Base-Stufe x Wiedergeburt x Skill-Baum x Goldrausch
function Bases.Multiplier(state): number
	local skillBonus = 1 + Bases.Skill(state, "Income") + Bases.Skill(state, "GoldDonkey")
	return Bases.Level(state).IncomeBonus * Config.RebirthMultiplier(state.Data.Rebirths) * skillBonus * Bases.RushFactor(state)
end

-- Preis für den Ausbau auf diese Stufe (Fähigkeit "Baumeister" macht ihn billiger)
function Bases.UpgradeCost(state, level): number
	return math.floor(level.Cost * (1 - Bases.Skill(state, "UpgradeDiscount")))
end

-- Schwebende "+X $"-Zahl an einer Stelle in der Welt (nur für diesen Spieler).
-- Wird gerade nirgends benutzt, bleibt aber als Werkzeug für später.
function Bases.Pop(player: Player, amount: number, position: Vector3, model: Instance?, color: Color3?)
	if player.Parent then
		remotes.Pop:FireClient(player, amount, position, model, color)
	end
end

-- Attribute für die Anzeige im Client (Rebirth-Menü, Skill-Baum, Shop-Chancen)
function Bases.RefreshStats(state)
	local player = state.Player
	local data = state.Data
	player:SetAttribute("Rebirths", data.Rebirths)
	player:SetAttribute("Tokens", data.Tokens)
	player:SetAttribute("BaseLevel", data.BaseLevel)
	for _, skill in Config.Skills.List do
		player:SetAttribute("Sk_" .. skill.Id, data.Skills[skill.Id] or 0)
	end
	if state.RebirthValue then
		state.RebirthValue.Value = data.Rebirths
	end
	if state.LevelValue then
		state.LevelValue.Value = data.BaseLevel
	end
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
	Bases.QueueMerges(state)
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
	local def, mutation, stars = Config.ParseEntry(entry)
	if not def then
		colorRing(plot, slot, nil)
		return
	end
	colorRing(plot, slot, Config.Rarities[def.Rarity].Color)
	local model = CreatureModels.Build(def, { Label = true, Mutation = mutation, Stars = stars })
	model:PivotTo(Map.SlotCFrame(plot, slot))
	local body = model.PrimaryPart
	local rarity = Config.Rarities[def.Rarity]
	local name = Config.EntryName(entry)
	addPrompt(body, "Steal", "Klauen", name, rarity.StealTime, plot, slot)
	local sellPrice = Bases.SellPrice(state, entry)
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

-- Verschmelzen (Sterne) -------------------------------------------------------------
-- Welche Kreaturen kann man gerade verschmelzen? Gibt { [eintrag] = { platz, platz, ... } } zurück
-- (nur Einträge, von denen genug gleiche in der Base stehen und die noch Sterne bekommen können).
function Bases.MergeGroups(state)
	local groups = {}
	for slot = 1, Bases.Level(state).Slots do
		local entry = state.Data.Slots[tostring(slot)]
		if entry and not state.Plot.Stolen[slot] then
			groups[entry] = groups[entry] or {}
			table.insert(groups[entry], slot)
		end
	end
	for entry, slots in groups do
		if #slots < Config.Stars.Need or not Config.MergeResult(entry) then
			groups[entry] = nil
		end
	end
	return groups
end

-- Schickt die Liste der möglichen Verschmelzungen an den Client (gebündelt)
function Bases.QueueMerges(state)
	if mergePending[state] then
		return
	end
	mergePending[state] = true
	task.delay(0.25, function()
		mergePending[state] = nil
		if Bases.States[state.Player] ~= state then
			return
		end
		local list = {}
		for entry, slots in Bases.MergeGroups(state) do
			table.insert(list, { Entry = entry, Count = #slots, Result = Config.MergeResult(entry) })
		end
		table.sort(list, function(a, b)
			return Config.EntryIncome(a.Result) > Config.EntryIncome(b.Result)
		end)
		remotes.Merges:FireClient(state.Player, list)
	end)
end

-- Kreatur fliegt zum Ziel und schrumpft dabei weg
local function flyInto(model: Model, target: Vector3)
	task.spawn(function()
		local from = model:GetPivot()
		local base = model:GetScale()
		local duration = 0.38
		local start = os.clock()
		while model.Parent do
			local t = math.min(1, (os.clock() - start) / duration)
			local eased = t * t
			local pos = from.Position:Lerp(target, eased) + Vector3.new(0, math.sin(t * math.pi) * 5, 0)
			pcall(function()
				model:PivotTo(CFrame.new(pos) * from.Rotation * CFrame.Angles(0, t * 8, 0))
				model:ScaleTo(base * math.max(0.08, 1 - eased * 0.9))
			end)
			if t >= 1 then
				break
			end
			task.wait()
		end
		model:Destroy()
	end)
end

-- Macht aus den Kreaturen auf diesen Plätzen eine mit mehr Sternen. Sie landet auf dem
-- ersten Platz. Gibt den neuen Eintrag zurück.
local function mergeSlots(state, entry: string, slots: { number }, quiet: boolean?): string
	local plot = state.Plot
	local player = state.Player
	local extra = 0
	local _, _, stars = Config.ParseEntry(entry)
	if stars + 1 < Config.Stars.Max and math.random() < Bases.Skill(state, "StarLuck") then
		extra = 1 -- Sternen-Glück: gleich zwei Sterne
	end
	local result = Config.MergeResult(entry, extra) :: string
	local targetSlot = slots[1]
	local target = Map.SlotCFrame(plot, targetSlot).Position + Vector3.new(0, 2, 0)

	-- Modelle der Zutaten fliegen zusammen
	for i, slot in slots do
		local model = plot.SlotModels[slot]
		state.Data.Slots[tostring(slot)] = nil
		if model then
			for _, d in model:GetDescendants() do
				if d:IsA("ProximityPrompt") or d:IsA("ClickDetector") or d:IsA("BillboardGui") then
					d:Destroy()
				end
			end
			if quiet then
				plot.SlotModels[slot] = nil
				model:Destroy()
			elseif i > 1 then
				plot.SlotModels[slot] = nil
				flyInto(model, target)
			end
			-- die Kreatur auf dem Zielplatz bleibt stehen, bis die neue erscheint
		end
	end
	state.Data.Slots[tostring(targetSlot)] = result
	for i, slot in slots do
		if i > 1 then
			Bases.RenderSlot(state, slot)
		end
	end

	local def, _, newStars = Config.ParseEntry(result)
	local color = Color3.fromRGB(255, 215, 70)
	local function appear()
		if Bases.States[player] ~= state or state.Data.Slots[tostring(targetSlot)] ~= result then
			return
		end
		Bases.RenderSlot(state, targetSlot)
		local model = plot.SlotModels[targetSlot]
		if model then
			FX.PopIn(model)
			FX.Burst(target, color, 40 + newStars * 15)
			FX.Ring(target - Vector3.new(0, 1.7, 0), color, 10 + newStars * 3)
			if def then
				FX.Ring(target - Vector3.new(0, 1.7, 0), Config.Rarities[def.Rarity].Color, 6 + newStars * 2)
			end
		end
	end
	if quiet then
		appear()
	else
		task.delay(0.4, appear)
		local name = Config.EntryName(result)
		if extra > 0 then
			Bases.BigText(player, `STERNEN-GLÜCK! {Config.StarText(newStars)}`, color, "MergeBig", true)
		else
			Bases.BigText(player, `VERSCHMOLZEN! {Config.StarText(newStars)}`, color, if newStars >= 3 then "MergeBig" else "Merge")
		end
		Bases.Notify(player, `{name} macht jetzt +{Config.FormatRate(Config.EntryIncome(result))} $/s.`, color)
		if newStars >= Config.Stars.AnnounceFrom then
			Bases.Announce(`{player.DisplayName} hat verschmolzen: {name}!`, color)
		end
	end
	Bases.RefreshPlot(plot)
	return result
end

-- Spieler drückt "Verschmelzen" für einen Eintrag
function Bases.Merge(player: Player, entry: string)
	local state = Bases.States[player]
	if not state then
		return
	end
	local slots = Bases.MergeGroups(state)[entry]
	if not slots then
		Bases.Notify(player, `Dafür brauchst du {Config.Stars.Need} gleiche Kreaturen in deiner Base.`, RED)
		Bases.QueueMerges(state)
		return
	end
	table.sort(slots)
	local use = {}
	for i = 1, Config.Stars.Need do
		use[i] = slots[i]
	end
	mergeSlots(state, entry, use)
end

-- Base voll und eine neue Kreatur kommt: Stehen schon genug gleiche da, wird sofort
-- verschmolzen statt verkauft. Gibt den neuen Eintrag zurück oder nil.
function Bases.TryAbsorb(state, entry: string): string?
	if not Config.MergeResult(entry) then
		return nil
	end
	local same = {}
	for slot = 1, Bases.Level(state).Slots do
		if state.Data.Slots[tostring(slot)] == entry and not state.Plot.Stolen[slot] then
			table.insert(same, slot)
		end
	end
	if #same < Config.Stars.Need - 1 then
		return nil
	end
	local use = {}
	for i = 1, Config.Stars.Need - 1 do
		use[i] = same[i]
	end
	return mergeSlots(state, entry, use, true)
end

-- Der Platz mit der wertvollsten Kreatur (für den Tresor)
function Bases.BestSlot(state): number?
	local best, bestIncome = nil, -1
	for slotKey, entry in state.Data.Slots do
		local income = Config.EntryIncome(entry)
		local slot = tonumber(slotKey)
		if slot and (income > bestIncome or (income == bestIncome and best and slot < best)) then
			best, bestIncome = slot, income
		end
	end
	return best
end

-- Der Platz mit der schwächsten Kreatur, die gerade in der Base steht
-- (für den Tausch bei voller Base und für die Schatten-Diebe)
function Bases.WeakestSlot(state): number?
	local worst, worstIncome = nil, math.huge
	for slotKey, entry in state.Data.Slots do
		local slot = tonumber(slotKey)
		if slot and not state.Plot.Stolen[slot] then
			local income = Config.EntryIncome(entry)
			if income < worstIncome or (income == worstIncome and worst and slot > worst) then
				worst, worstIncome = slot, income
			end
		end
	end
	return worst
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
	labels[2].Text = `Stufe {level}: {levelInfo.Name} · +{Config.FormatRate(Bases.Income(state))} $/s`
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
		plot.LockPrompt.ActionText = if wait > 0 then `Bereit in {wait}s` else `Abschließen ({Bases.LockTime(state)}s)`
	end
	plot.LockPrompt:SetAttribute("Active", true)
	plot.Model:SetAttribute("Locked", state.Locked)

	local nextLevel = Config.BaseLevels[level + 1]
	if nextLevel then
		plot.UpgradePrompt.ActionText = `Upgrade: {Config.FormatNumber(Bases.UpgradeCost(state, nextLevel))} $`
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
	mergePending[state] = nil
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
	local bonus = math.floor((Config.DailyBonus[state.Data.BaseLevel] or Config.DailyBonus[1]) * (1 + Bases.Skill(state, "DailyLuck")))
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
	local price = Bases.SellPrice(state, entry)
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
	local cost = Bases.UpgradeCost(state, nextLevel)
	if state.Data.Money < cost then
		Bases.Notify(player, `Du brauchst {Config.FormatNumber(cost)} $ für das Upgrade.`, RED)
		return
	end
	Bases.AddMoney(state, -cost)
	state.Data.BaseLevel += 1
	Bases.RefreshStats(state)
	Map.BuildDecor(state.Plot, state.Data.BaseLevel)
	Bases.RenderAll(state) -- das größere Haus ordnet die Plätze neu an
	Bases.RefreshRings(state)
	Bases.RefreshPlot(state.Plot)
	Bases.BigText(player, `BASE-UPGRADE: {Config.Upper(nextLevel.Name)}!`, Color3.fromRGB(80, 255, 120), "Upgrade")
	local center = state.Plot.CFrame.Position + Vector3.new(0, 0.5, 0)
	FX.Ring(center, Color3.fromRGB(80, 255, 120), 50)
	for _, offset in { Vector3.new(-18, 6, -28), Vector3.new(18, 6, -28), Vector3.new(-12, 4, -8), Vector3.new(12, 4, -8) } do
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
	local lockTime = Bases.LockTime(state)
	state.Locked = true
	state.LockEnd = now + lockTime
	state.LockReadyAt = state.LockEnd + Bases.LockCooldown(state)
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
