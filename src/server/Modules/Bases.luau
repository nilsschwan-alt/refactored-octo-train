-- Verwaltet die Bases: Spieler zuweisen, Kreaturen anzeigen, Geld (kommt automatisch),
-- Inventar, Verkaufen, Verbessern (Sterne), Upgrades und das Base-Schloss.
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
local inventoryPending = {} -- [state] = true, wenn das Inventar an den Client raus muss

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
	Bases.QueueInventory(state)
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

-- Inventar und Sterne ----------------------------------------------------------------
-- Aktiv = steht in der Base (state.Data.Slots), verdient Geld und kann geklaut werden.
-- Inventar = state.Data.Bag[eintrag] = Anzahl: alle anderen Kreaturen. Sie verdienen nichts,
-- sind aber sicher und dienen als Futter: Mit "Verbessern" bekommt eine Kreatur einen Stern
-- und frisst dafür Kreaturen ihrer Art aus dem Inventar (die Mutation ist egal, aber nie eine,
-- die stärker ist als sie selbst). Futter, das dabei übrig bleibt, merkt sich
-- state.Data.Feed[artId] für den nächsten Stern.
local STAR_COLOR = Color3.fromRGB(255, 215, 70)
local BAG_COLOR = Color3.fromRGB(120, 200, 255)

-- So viele Kreaturen liegen im Inventar
function Bases.BagCount(state): number
	local total = 0
	for _, count in state.Data.Bag do
		total += count
	end
	return total
end

local function bagAdd(state, entry: string, amount: number)
	state.Data.Bag[entry] = (state.Data.Bag[entry] or 0) + amount
	Bases.QueueInventory(state)
end

local function bagTake(state, entry: string, amount: number): boolean
	local have = state.Data.Bag[entry] or 0
	if have < amount then
		return false
	end
	state.Data.Bag[entry] = if have > amount then have - amount else nil
	Bases.QueueInventory(state)
	return true
end

-- Legt eine Kreatur ins Inventar. Ist es danach zu voll, wird die schwächste darin verkauft
-- (das Geld ist dann schon gebucht). Gibt (verkaufter Eintrag oder nil, Preis) zurück.
function Bases.Store(state, entry: string): (string?, number)
	bagAdd(state, entry, 1)
	if Bases.BagCount(state) <= Config.Inventory.Size then
		return nil, 0
	end
	local worst, worstIncome = entry, Config.EntryIncome(entry)
	for other in state.Data.Bag do
		local income = Config.EntryIncome(other)
		if income < worstIncome then
			worst, worstIncome = other, income
		end
	end
	bagTake(state, worst, 1)
	local price = Bases.SellPrice(state, worst)
	Bases.AddMoney(state, price)
	return worst, price
end

-- Futter für diese Kreatur: alle im Inventar von derselben Art, die schwächer sind als sie
-- (oder genau gleich). Gleich starke andere, z.B. Gold ohne Stern und Normal mit Stern, bleiben.
-- inBag = sie liegt selbst im Inventar (dann zählt sie nicht als ihr eigenes Futter).
-- Gibt die Liste { { Entry, Count, Points } } (das schwächste Futter zuerst) und die Summe zurück.
local function foodFor(state, entry: string, inBag: boolean)
	local def = Config.ParseEntry(entry)
	local income = Config.EntryIncome(entry)
	local list, total = {}, 0
	for other, count in state.Data.Bag do
		-- gleiche Art, und entweder genau die gleiche Kreatur oder eine schwächere
		if Config.ParseEntry(other) == def and (other == entry or Config.EntryIncome(other) < income) then
			local n = if inBag and other == entry then count - 1 else count
			if n > 0 then
				local points = Config.FoodPoints(other)
				table.insert(list, { Entry = other, Count = n, Points = points })
				total += n * points
			end
		end
	end
	table.sort(list, function(a, b)
		if a.Points ~= b.Points then
			return a.Points < b.Points
		end
		return a.Entry < b.Entry
	end)
	return list, total
end

-- Futter-Stand für die Anzeige: (vorhanden, nötig). nötig = nil: hat schon alle Sterne.
local function feedState(state, entry: string, inBag: boolean): (number, number?)
	local def, _, stars = Config.ParseEntry(entry)
	local cost = Config.StarCost(stars)
	if not def or not cost then
		return 0, nil
	end
	local _, total = foodFor(state, entry, inBag)
	return math.min(cost, (state.Data.Feed[def.Id] or 0) + total), cost
end

-- Schickt das Inventar an den Client (gebündelt):
-- { Size, Count, Slots, Items = { { Entry, Count, Slot (wenn aktiv), Stolen, Have, Cost, Price } } }
function Bases.QueueInventory(state)
	if inventoryPending[state] then
		return
	end
	inventoryPending[state] = true
	task.delay(0.25, function()
		inventoryPending[state] = nil
		if Bases.States[state.Player] ~= state then
			return
		end
		local items = {}
		for slot = 1, Bases.Level(state).Slots do
			local entry = state.Data.Slots[tostring(slot)]
			if entry and Config.ParseEntry(entry) then
				local have, cost = feedState(state, entry, false)
				table.insert(items, { Entry = entry, Count = 1, Slot = slot, Stolen = state.Plot.Stolen[slot] ~= nil, Have = have, Cost = cost, Price = Bases.SellPrice(state, entry) })
			end
		end
		for entry, count in state.Data.Bag do
			local have, cost = feedState(state, entry, true)
			table.insert(items, { Entry = entry, Count = count, Have = have, Cost = cost, Price = Bases.SellPrice(state, entry) })
		end
		remotes.Inventory:FireClient(state.Player, {
			Size = Config.Inventory.Size,
			Count = Bases.BagCount(state),
			Slots = Bases.Level(state).Slots,
			Items = items,
		})
	end)
end

-- Gibt einer Kreatur einen Stern und verbraucht dafür Futter aus dem Inventar.
-- slot = ihr Platz in der Base, wenn sie aktiv ist, sonst nil (dann liegt sie im Inventar).
-- Gibt (neuer Eintrag, Sternen-Glück) zurück, oder (nil, Grund): "gone", "max" oder "food".
local function starUp(state, entry: string, slot: number?): (string?, any)
	local def, mutation, stars = Config.ParseEntry(entry)
	if not def then
		return nil, "gone"
	end
	if slot then
		if state.Data.Slots[tostring(slot)] ~= entry or state.Plot.Stolen[slot] then
			return nil, "gone"
		end
	elseif (state.Data.Bag[entry] or 0) < 1 then
		return nil, "gone"
	end
	local cost = Config.StarCost(stars)
	if not cost then
		return nil, "max"
	end
	local list, total = foodFor(state, entry, slot == nil)
	local have = state.Data.Feed[def.Id] or 0
	if have + total < cost then
		return nil, "food"
	end
	for _, food in list do
		while have < cost and food.Count > 0 do
			bagTake(state, food.Entry, 1)
			food.Count -= 1
			have += food.Points
		end
	end
	have -= cost
	state.Data.Feed[def.Id] = if have > 0 then have else nil

	local newStars = stars + 1
	local lucky = false
	if newStars < Config.Stars.Max and math.random() < Bases.Skill(state, "StarLuck") then
		newStars += 1 -- Sternen-Glück: gleich noch einer dazu
		lucky = true
	end
	local result = Config.MakeEntry(def.Id, mutation, newStars)
	if slot then
		state.Data.Slots[tostring(slot)] = result
		Bases.RenderSlot(state, slot)
		local model = state.Plot.SlotModels[slot]
		local target = Map.SlotCFrame(state.Plot, slot).Position + Vector3.new(0, 2, 0)
		if model then
			FX.PopIn(model)
		end
		FX.Burst(target, STAR_COLOR, 40 + newStars * 15)
		FX.Ring(target - Vector3.new(0, 1.7, 0), STAR_COLOR, 10 + newStars * 3)
		FX.Ring(target - Vector3.new(0, 1.7, 0), Config.Rarities[def.Rarity].Color, 6 + newStars * 2)
		Bases.RefreshPlot(state.Plot)
	else
		bagTake(state, entry, 1)
		bagAdd(state, result, 1)
	end
	Bases.Track(state, "StarUp", 1)
	return result, lucky
end

local function starUpFailed(player: Player, reason: string)
	if reason == "max" then
		Bases.Notify(player, "Diese Kreatur hat schon alle Sterne.", RED)
	elseif reason == "food" then
		Bases.Notify(player, "Dafür fehlt noch Futter: Sammle mehr von dieser Art.", RED)
	end
end

-- Spieler drückt "Verbessern" bei einer Kreatur
function Bases.StarUp(player: Player, entry: string, slot: number?)
	local state = Bases.States[player]
	if not state then
		return
	end
	local result, lucky = starUp(state, entry, slot)
	if not result then
		starUpFailed(player, lucky)
		Bases.QueueInventory(state)
		return
	end
	local _, _, stars = Config.ParseEntry(result)
	local name = Config.EntryName(result)
	Bases.BigText(player, `{if lucky then "STERNEN-GLÜCK!" else "NEUER STERN!"} {Config.StarText(stars)}`, STAR_COLOR, if stars >= 3 then "MergeBig" else "Merge", lucky == true)
	Bases.Notify(player, `⭐ {name} macht jetzt +{Config.FormatRate(Config.EntryIncome(result))} $/s.`, STAR_COLOR)
	if stars >= Config.Stars.AnnounceFrom then
		Bases.Announce(`{player.DisplayName} hat einen neuen Stern: {name}!`, STAR_COLOR)
	end
end

-- Spieler drückt "Alle verbessern": verteilt Sterne, solange Futter da ist, die stärksten zuerst
function Bases.StarUpAll(player: Player)
	local state = Bases.States[player]
	if not state then
		return
	end
	local count, bestStars, bestEntry = 0, 0, nil -- bestEntry = die stärkste, die einen Stern bekam
	local starEntry = nil -- die mit den meisten Sternen (für die Ansage an alle)
	for _ = 1, 300 do
		local targets = {}
		for slot = 1, Bases.Level(state).Slots do
			local entry = state.Data.Slots[tostring(slot)]
			if entry and not state.Plot.Stolen[slot] then
				table.insert(targets, { Entry = entry, Slot = slot })
			end
		end
		for entry in state.Data.Bag do
			table.insert(targets, { Entry = entry })
		end
		table.sort(targets, function(a, b)
			local ia, ib = Config.EntryIncome(a.Entry), Config.EntryIncome(b.Entry)
			if ia ~= ib then
				return ia > ib
			end
			if (a.Slot ~= nil) ~= (b.Slot ~= nil) then
				return a.Slot ~= nil -- bei gleich starken zuerst die aktive
			end
			return if a.Slot then a.Slot < b.Slot else a.Entry < b.Entry
		end)
		local done = false
		for _, target in targets do
			local result = starUp(state, target.Entry, target.Slot)
			if result then
				local _, _, stars = Config.ParseEntry(result)
				count += 1
				if stars > bestStars then
					bestStars, starEntry = stars, result
				end
				if not bestEntry or Config.EntryIncome(result) > Config.EntryIncome(bestEntry) then
					bestEntry = result
				end
				done = true
				break
			end
		end
		if not done then
			break
		end
	end
	if count == 0 or not bestEntry then
		Bases.Notify(player, "Gerade gibt es nichts zu verbessern: Es fehlt Futter.", RED)
		return
	end
	Bases.BigText(player, `{count} {if count == 1 then "NEUER STERN" else "NEUE STERNE"}!`, STAR_COLOR, if bestStars >= 3 then "MergeBig" else "Merge")
	Bases.Notify(player, `⭐ {count}x verbessert. Am besten: {Config.EntryName(bestEntry)} mit +{Config.FormatRate(Config.EntryIncome(bestEntry))} $/s.`, STAR_COLOR)
	if starEntry and bestStars >= Config.Stars.AnnounceFrom then
		Bases.Announce(`{player.DisplayName} hat einen neuen Stern: {Config.EntryName(starEntry)}!`, STAR_COLOR)
	end
end

-- Kreatur aus dem Inventar in die Base stellen. Ist die Base voll, geht dafür die schwächste
-- aktive ins Inventar.
function Bases.Equip(player: Player, entry: string)
	local state = Bases.States[player]
	if not state or (state.Data.Bag[entry] or 0) < 1 or not Config.ParseEntry(entry) then
		return
	end
	local packed: string? = nil
	if not Bases.FreeSlot(state) then
		local slot = Bases.WeakestSlot(state)
		packed = slot and state.Data.Slots[tostring(slot)]
		if not slot or not packed then
			Bases.Notify(player, "Geht gerade nicht: Es ist kein Platz frei.", RED)
			return
		end
		state.Data.Slots[tostring(slot)] = nil
		bagAdd(state, packed, 1)
	end
	bagTake(state, entry, 1)
	Bases.GiveCreature(state, entry)
	Bases.RefreshPlot(state.Plot)
	if packed then
		Bases.Notify(player, `{Config.EntryName(entry)} steht jetzt in der Base, {Config.EntryName(packed)} ist im Inventar.`, BAG_COLOR)
	end
end

-- Aktive Kreatur aus der Base ins Inventar legen
function Bases.Unequip(player: Player, slot: number)
	local state = Bases.States[player]
	local entry = state and state.Data.Slots[tostring(slot)]
	if not state or not entry or state.Plot.Stolen[slot] then
		return
	end
	if Bases.BagCount(state) >= Config.Inventory.Size then
		Bases.Notify(player, "Dein Inventar ist voll. Verkaufe oder verbessere erst etwas.", RED)
		return
	end
	state.Data.Slots[tostring(slot)] = nil
	Bases.RenderSlot(state, slot)
	bagAdd(state, entry, 1)
	Bases.RefreshPlot(state.Plot)
	Bases.Notify(player, `🎒 {Config.EntryName(entry)} ist jetzt im Inventar. Der Platz bleibt frei.`, BAG_COLOR)
end

-- Kreaturen aus dem Inventar verkaufen (all = alle von diesem Eintrag)
function Bases.SellFromBag(player: Player, entry: string, all: boolean?)
	local state = Bases.States[player]
	local have = state and state.Data.Bag[entry] or 0
	if not state or have < 1 or not Config.ParseEntry(entry) then
		return
	end
	local count = if all then have else 1
	bagTake(state, entry, count)
	local price = Bases.SellPrice(state, entry) * count
	Bases.AddMoney(state, price)
	remotes.MoneyPopup:FireClient(player, price)
	local amount = if count > 1 then `{count}x ` else ""
	Bases.Notify(player, `{amount}{Config.EntryName(entry)} für {Config.FormatNumber(price)} $ verkauft.`)
end

-- Spieler drückt "Beste aufstellen": Die stärksten Kreaturen (aktiv und Inventar) kommen in
-- die Base, der Rest ins Inventar.
function Bases.EquipBest(player: Player)
	local state = Bases.States[player]
	if not state then
		return
	end
	local usable = 0 -- Plätze, die frei sind oder auf denen eine Kreatur steht, die nicht gerade geklaut wird
	local active = {} -- { { Slot, Entry } }
	local all = {} -- alle Kreaturen, die aufgestellt werden könnten
	for slot = 1, Bases.Level(state).Slots do
		local entry = state.Data.Slots[tostring(slot)]
		if not entry then
			usable += 1
		elseif not state.Plot.Stolen[slot] then
			usable += 1
			table.insert(active, { Slot = slot, Entry = entry })
			table.insert(all, entry)
		end
	end
	for entry, count in state.Data.Bag do
		for _ = 1, math.min(count, usable) do
			table.insert(all, entry)
		end
	end
	table.sort(all, function(a, b)
		local ia, ib = Config.EntryIncome(a), Config.EntryIncome(b)
		if ia ~= ib then
			return ia > ib
		end
		return a < b
	end)
	local want = {} -- [eintrag] = so viele sollen stehen
	local order = {} -- dieselben in der Reihenfolge stark -> schwach
	for i = 1, math.min(usable, #all) do
		want[all[i]] = (want[all[i]] or 0) + 1
		table.insert(order, all[i])
	end
	-- Wer schon steht und bleiben soll, bleibt. Der Rest wird eingepackt.
	local changed = 0
	for _, item in active do
		if (want[item.Entry] or 0) > 0 then
			want[item.Entry] -= 1
		else
			state.Data.Slots[tostring(item.Slot)] = nil
			Bases.RenderSlot(state, item.Slot)
			bagAdd(state, item.Entry, 1)
		end
	end
	for _, entry in order do
		if (want[entry] or 0) > 0 and bagTake(state, entry, 1) then
			want[entry] -= 1
			Bases.GiveCreature(state, entry)
			changed += 1
		end
	end
	Bases.RefreshPlot(state.Plot)
	if changed > 0 then
		Bases.Notify(player, `Deine besten Kreaturen stehen jetzt in der Base ({changed} neu aufgestellt).`, BAG_COLOR)
	else
		Bases.Notify(player, "Deine besten Kreaturen stehen schon in der Base.", BAG_COLOR)
	end
end

-- Freie Plätze in der Base mit den stärksten Kreaturen aus dem Inventar füllen (nach einem
-- Base-Upgrade, einem Verkauf oder wenn etwas geklaut wurde). Gibt zurück, wie viele nachrückten.
function Bases.FillFree(state): number
	local moved = 0
	while Bases.FreeSlot(state) do
		local best, bestIncome = nil, -1
		for entry in state.Data.Bag do
			local income = Config.EntryIncome(entry)
			if income > bestIncome or (income == bestIncome and best and entry < best) then
				best, bestIncome = entry, income
			end
		end
		if not best or not bagTake(state, best, 1) then
			break
		end
		Bases.GiveCreature(state, best)
		moved += 1
	end
	if moved > 0 then
		Bases.RefreshPlot(state.Plot)
		Bases.Notify(state.Player, `🎒 {moved} {if moved == 1 then "Kreatur rückt" else "Kreaturen rücken"} aus dem Inventar in die Base nach.`, BAG_COLOR)
	end
	return moved
end

-- Eine neue Kreatur kommt an (Kiste, Meteor, Welt, geklaut). Ist ein Platz frei, kommt sie in
-- die Base. Ist die Base voll und sie ist besser als die schwächste dort, tauschen die beiden.
-- Wer keinen Platz in der Base bekommt, landet im Inventar. Verkauft wird nur, wenn das voll ist.
-- Gibt zurück: { Kind = "placed" | "swapped" | "stored", Rest = wer ins Inventar kam,
--   Sold = Eintrag, der wegen vollem Inventar verkauft wurde (oder nil), Money = sein Preis }
function Bases.Receive(state, entry: string)
	if Bases.FreeSlot(state) then
		Bases.GiveCreature(state, entry)
		return { Kind = "placed", Money = 0 }
	end
	local rest, kind = entry, "stored"
	local slot = Bases.WeakestSlot(state)
	local old = slot and state.Data.Slots[tostring(slot)]
	if slot and old and Config.EntryIncome(entry) > Config.EntryIncome(old) then
		state.Data.Slots[tostring(slot)] = nil
		Bases.GiveCreature(state, entry) -- nimmt den Platz, der gerade frei wurde
		rest, kind = old, "swapped"
	end
	local sold, price = Bases.Store(state, rest)
	return { Kind = kind, Rest = rest, Sold = sold, Money = price }
end

-- Meldung dazu, was mit einer neuen Kreatur passiert ist (nil = sie steht einfach in der Base)
function Bases.ReceiveText(got, entry: string): string?
	local text: string? = nil
	if got.Kind == "swapped" then
		text = `{Config.EntryName(entry)} steht jetzt in deiner Base, {Config.EntryName(got.Rest)} ist im Inventar.`
	elseif got.Kind == "stored" then
		text = `🎒 Base voll: {Config.EntryName(entry)} liegt im Inventar.`
	end
	if got.Sold then
		local sold = `Inventar voll: {Config.EntryName(got.Sold)} für {Config.FormatNumber(got.Money)} $ verkauft.`
		if got.Sold ~= got.Rest then
			text = if text then `{text} {sold}` else sold
		elseif got.Kind == "swapped" then
			-- die rausgetauschte war selbst die schwächste: Sie lag nie wirklich im Inventar
			text = `{Config.EntryName(entry)} steht jetzt in deiner Base. {sold}`
		else
			text = sold
		end
	end
	return text
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
	inventoryPending[state] = nil
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
	Bases.FillFree(state)
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
	Bases.FillFree(state) -- die neuen Plätze gleich aus dem Inventar besetzen
	Bases.Track(state, "BaseUpgrade", 1)
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
