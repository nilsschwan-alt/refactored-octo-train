-- ALLE Spielwerte an einem Ort. Hier kannst du balancen, ohne die Logik anzufassen.
-- Liegt in Studio unter: ReplicatedStorage > Shared > Config

local Config = {}

Config.GameName = "Kreaturen-Klau"
Config.Version = "0.5.3"

-- Geld & Speichern ---------------------------------------------------------
Config.StartMoney = 300 -- reicht für das erste Holz-Pack
Config.StarterCreature = "Blubbo" -- jeder Neue bekommt diese Kreatur geschenkt
Config.IncomeInterval = 1 -- alle X Sekunden gibt's Geld
Config.AutoSaveInterval = 120 -- Sekunden zwischen automatischen Speicherungen
Config.DataStoreName = "KreaturenDaten_v1" -- Name ändern = alle Spielstände neu

-- Verkaufen: so viel vom Kaufpreis bekommt man zurück
Config.SellFactor = 0.5

-- Klauen -------------------------------------------------------------------
Config.Steal = {
	CarrySpeed = 10, -- Laufgeschwindigkeit, solange man etwas trägt (normal 16)
	CanJumpWhileCarrying = false,
	HitRange = 9, -- Reichweite der Klatsche
	HitCooldown = 0.8, -- Sekunden zwischen zwei Schlägen
	StunTime = 1.5, -- so lange steht ein getroffener Dieb still
	MaxStealDistance = 14, -- so nah muss man an der Kreatur stehen
}

-- Base-Schloss
Config.LockCooldown = 60 -- Sekunden Pause nach dem Schloss, bevor man es wieder benutzen kann

-- Seltenheiten -------------------------------------------------------------
-- StealTime = so lange muss man E gedrückt halten, um zu klauen
-- Size = Größe der Kreatur in Blöcken
Config.Rarities = {
	Common = { Name = "Gewöhnlich", Color = Color3.fromRGB(190, 190, 190), StealTime = 0.6, Size = 3 },
	Uncommon = { Name = "Ungewöhnlich", Color = Color3.fromRGB(90, 220, 90), StealTime = 1, Size = 3.4 },
	Rare = { Name = "Selten", Color = Color3.fromRGB(70, 150, 255), StealTime = 1.5, Size = 3.8 },
	Epic = { Name = "Episch", Color = Color3.fromRGB(180, 80, 255), StealTime = 2.2, Size = 4.3, Light = true },
	Legendary = {
		Name = "Legendär",
		Color = Color3.fromRGB(255, 190, 40),
		StealTime = 3,
		Size = 4.8,
		Light = true,
		Sparkles = true,
	},
	Mythic = {
		Name = "Mythisch",
		Color = Color3.fromRGB(255, 70, 140),
		StealTime = 4,
		Size = 5.5,
		Light = true,
		Sparkles = true,
	},
}

-- Kreaturen ----------------------------------------------------------------
-- Price = Kaufpreis, Income = Geld pro Sekunde
-- Extra = Form-Zusatz: "Ohren", "Hoerner", "Panzer", "Fuehler", "Hut", "Krone", "Stacheln", "Tentakel"
Config.Creatures = {
	{ Id = "Blubbo", Name = "Blubbo", Rarity = "Common", Price = 50, Income = 1,
		Color = Color3.fromRGB(120, 220, 100), Accent = Color3.fromRGB(70, 160, 60), Extra = nil },
	{ Id = "Kruemelkrabbe", Name = "Krümelkrabbe", Rarity = "Common", Price = 120, Income = 2,
		Color = Color3.fromRGB(240, 120, 80), Accent = Color3.fromRGB(200, 70, 40), Extra = "Fuehler" },
	{ Id = "PupsiPilz", Name = "Pupsi-Pilz", Rarity = "Uncommon", Price = 400, Income = 5,
		Color = Color3.fromRGB(245, 235, 210), Accent = Color3.fromRGB(220, 50, 50), Extra = "Hut" },
	{ Id = "Zappelfrosch", Name = "Zappelfrosch", Rarity = "Uncommon", Price = 900, Income = 10,
		Color = Color3.fromRGB(60, 200, 160), Accent = Color3.fromRGB(250, 230, 60), Extra = "Ohren" },
	{ Id = "Wolkenwurm", Name = "Wolkenwurm", Rarity = "Rare", Price = 2500, Income = 22,
		Color = Color3.fromRGB(220, 235, 255), Accent = Color3.fromRGB(130, 180, 255), Extra = "Fuehler" },
	{ Id = "Funkelfuchs", Name = "Funkelfuchs", Rarity = "Rare", Price = 6000, Income = 45,
		Color = Color3.fromRGB(255, 140, 40), Accent = Color3.fromRGB(255, 255, 255), Extra = "Ohren" },
	{ Id = "LavaLurch", Name = "Lava-Lurch", Rarity = "Epic", Price = 15000, Income = 100,
		Color = Color3.fromRGB(60, 40, 40), Accent = Color3.fromRGB(255, 90, 20), Extra = "Stacheln" },
	{ Id = "Donnerdachs", Name = "Donnerdachs", Rarity = "Epic", Price = 40000, Income = 230,
		Color = Color3.fromRGB(80, 80, 110), Accent = Color3.fromRGB(255, 240, 60), Extra = "Hoerner" },
	{ Id = "EisIgel", Name = "Eiskristall-Igel", Rarity = "Legendary", Price = 120000, Income = 600,
		Color = Color3.fromRGB(170, 230, 255), Accent = Color3.fromRGB(240, 255, 255), Extra = "Stacheln" },
	{ Id = "Sternenschnecke", Name = "Sternenschnecke", Rarity = "Legendary", Price = 350000, Income = 1500,
		Color = Color3.fromRGB(40, 30, 90), Accent = Color3.fromRGB(255, 220, 90), Extra = "Panzer" },
	{ Id = "RegenbogenRex", Name = "Regenbogen-Rex", Rarity = "Mythic", Price = 1000000, Income = 4000,
		Color = Color3.fromRGB(255, 80, 200), Accent = Color3.fromRGB(80, 255, 230), Extra = "Krone" },
	{ Id = "KosmoKrake", Name = "Kosmo-Krake", Rarity = "Mythic", Price = 3000000, Income = 10000,
		Color = Color3.fromRGB(110, 40, 200), Accent = Color3.fromRGB(0, 255, 255), Extra = "Tentakel" },
}

-- Schnellzugriff per Id (wird automatisch gefüllt)
Config.CreatureById = {}
for _, creature in Config.Creatures do
	Config.CreatureById[creature.Id] = creature
end

-- Base-Stufen --------------------------------------------------------------
-- Cost = Preis für das Upgrade AUF diese Stufe
-- Slots = Plätze für Kreaturen (maximal 12)
-- LockTime = so lange bleibt die Base zu, wenn man das Schloss drückt
-- IncomeBonus = Multiplikator auf das Einkommen
Config.BaseLevels = {
	{ Name = "Holz-Hütte", Cost = 0, Slots = 4, LockTime = 30, IncomeBonus = 1.0 },
	{ Name = "Stein-Burg", Cost = 750, Slots = 6, LockTime = 40, IncomeBonus = 1.1 },
	{ Name = "Lichter-Villa", Cost = 7500, Slots = 8, LockTime = 50, IncomeBonus = 1.25 },
	{ Name = "Neon-Palast", Cost = 75000, Slots = 10, LockTime = 60, IncomeBonus = 1.5 },
	{ Name = "Kristall-Festung", Cost = 750000, Slots = 12, LockTime = 75, IncomeBonus = 2.0 },
}

-- Map ----------------------------------------------------------------------
-- Zwei Reihen mit je 4 Bases, dazwischen eine Straße.
Config.Map = {
	BaseCount = 8, -- passt zu 8 Spielern pro Server
	BaseSize = 56, -- Kantenlänge einer Base
	BaseSpacing = 90, -- Abstand der Bases nebeneinander (Mitte zu Mitte)
	StreetWidth = 76, -- Breite zwischen den Reihen (Fahrbahn + Gehwege)
	StreetHalfLength = 200, -- Straße geht von x = -200 bis +200
}

-- ==========================================================================
-- DROP-RATEN: Alle Chancen an einem Ort. Die Zahlen sind Gewichte, keine
-- Prozente. Die Chance ist Gewicht / Summe aller Gewichte. Beispiel:
-- { Common = 60, Rare = 30, Epic = 10 } = 60 % / 30 % / 10 %
-- ==========================================================================

-- Mutationen ----------------------------------------------------------------
-- Jede neue Kreatur (Pack, Meteor) würfelt eine Mutation.
-- Multiplier = mehr Geld pro Sekunde und höherer Wert
Config.Mutations = {
	Normal = { Name = "", Multiplier = 1 },
	Gold = { Name = "Gold", Multiplier = 2, Color = Color3.fromRGB(255, 200, 40) },
	Diamant = { Name = "Diamant", Multiplier = 3, Color = Color3.fromRGB(150, 240, 255) },
	Regenbogen = { Name = "Regenbogen", Multiplier = 5, Color = Color3.fromRGB(255, 120, 220) },
}
Config.MutationWeights = {
	Normal = 85,
	Gold = 10,
	Diamant = 4,
	Regenbogen = 1,
}

-- Packs ----------------------------------------------------------------------
-- Pity: Nach so vielen Packs ohne Legendär oder besser ist das nächste garantiert Legendär+.
Config.PityThreshold = 20
Config.Packs = {
	{
		Id = "Holz",
		Name = "Holz-Pack",
		Price = 300,
		Color = Color3.fromRGB(170, 120, 70),
		Weights = { Common = 60, Uncommon = 28, Rare = 10, Epic = 1.8, Legendary = 0.2, Mythic = 0 },
	},
	{
		Id = "Gold",
		Name = "Gold-Pack",
		Price = 6000,
		Color = Color3.fromRGB(255, 200, 40),
		Weights = { Common = 20, Uncommon = 35, Rare = 30, Epic = 12, Legendary = 2.7, Mythic = 0.3 },
	},
	{
		Id = "Kristall",
		Name = "Kristall-Pack",
		Price = 120000,
		Color = Color3.fromRGB(180, 100, 255),
		Weights = { Common = 0, Uncommon = 10, Rare = 35, Epic = 38, Legendary = 14, Mythic = 3 },
	},
}

-- Mehrfach-Öffnen: 1x, 3x oder 10x auf einmal. Discount = Rabatt (0.9 = 10 % billiger)
-- Ist die Base voll, bleiben die besten Kreaturen, der Rest wird automatisch verkauft.
Config.PackCounts = {
	{ Count = 1, Discount = 1 },
	{ Count = 3, Discount = 1 },
	{ Count = 10, Discount = 0.9 },
}
function Config.PackCost(pack, count: number): number
	for _, option in Config.PackCounts do
		if option.Count == count then
			return math.floor(pack.Price * count * option.Discount)
		end
	end
	return math.huge
end

-- Glück (aus dem Rebirth-Shop) macht Selten und besser wahrscheinlicher
function Config.PackWeights(pack, luckLevel: number?)
	local bonus = 1 + (luckLevel or 0) * Config.Rebirth.Upgrades.Luck.PerLevel
	local weights = {}
	for rarity, w in pack.Weights do
		weights[rarity] = if Config.RarityRank(rarity) >= Config.RarityRank("Rare") then w * bonus else w
	end
	return weights
end

-- Selbst Geld machen ---------------------------------------------------------------
-- Münzen liegen auf der Straße. Wert = so viele Sekunden von DEINEM Einkommen.
Config.Coins = {
	MaxOnMap = 30, -- so viele Münzen liegen höchstens herum
	SpawnInterval = 1, -- alle X Sekunden kommt eine neue
	Lifetime = 45, -- danach verschwindet sie
	ValueSeconds = 4, -- Münze = 4 Sekunden Einkommen
	MinValue = 10, -- aber mindestens so viel
	BigChance = 0.07, -- Chance auf eine Riesen-Münze
	BigFactor = 10, -- Riesen-Münze ist so viel mehr wert
	PickupRadius = 4, -- so nah muss man ran (Münz-Magnet vergrößert das)
}

-- Auf eigene Kreaturen klicken = sofort Geld
Config.Click = {
	Cooldown = 0.1, -- höchstens 10 Klicks pro Sekunde
	IncomeSeconds = 1, -- ein Klick = 1 Sekunde Einkommen DIESER Kreatur
	MinValue = 1,
	MaxDistance = 40,
}

-- Aufgaben -----------------------------------------------------------------------
-- Immer 3 Aufgaben aktiv. Geschafft = Geld, und sofort kommt eine neue.
-- Belohnung = RewardSeconds Sekunden Einkommen x Factor (mindestens MinReward)
Config.Quests = {
	Active = 3,
	RewardSeconds = 150,
	MinReward = 300,
	Types = {
		OpenPacks = { Text = "Öffne {n} Packs", Min = 3, Max = 8, Factor = 1.2 },
		Steal = { Text = "Klau {n} Kreatur(en) aus fremden Bases", Min = 1, Max = 2, Factor = 2 },
		Coins = { Text = "Sammle {n} Münzen auf der Straße", Min = 15, Max = 35, Factor = 1 },
		Clicks = { Text = "Klick {n}x auf deine Kreaturen", Min = 60, Max = 150, Factor = 0.8 },
		Earn = { Text = "Verdiene {n} $", EarnSeconds = 200, MinGoal = 1000, Factor = 1 },
		HitThief = { Text = "Hau {n} Dieb(e) mit der Klatsche", Min = 1, Max = 2, Factor = 1.5 },
	},
}

-- Bestenliste
Config.Leaderboard = {
	StoreName = "Bestenliste_Verdient_v1",
	RefreshInterval = 60,
}

-- Wiedergeburt (Rebirth) ---------------------------------------------------------
-- Kostet Geld, setzt Geld und Base-Stufe zurück, die besten Kreaturen bleiben.
-- Dafür: dauerhaft mehr Einkommen und Tokens für den Rebirth-Shop.
Config.Rebirth = {
	BaseCost = 15000, -- erste Wiedergeburt
	CostGrowth = 3, -- jede weitere kostet 3x so viel
	IncomePerRebirth = 0.5, -- +50 % Einkommen pro Wiedergeburt
	KeepCreatures = 4, -- so viele der besten Kreaturen bleiben
	TokensPerRebirth = 2,
	Upgrades = {
		Luck = { Name = "Glück", Icon = "🍀", Desc = "Selten+ in Packs wahrscheinlicher", Max = 5, PerLevel = 0.2, Costs = { 1, 2, 3, 4, 5 } },
		Magnet = { Name = "Münz-Magnet", Icon = "🧲", Desc = "Münzen von weiter weg einsammeln", Max = 5, PerLevel = 3, Costs = { 1, 1, 2, 2, 3 } },
		ClickPower = { Name = "Klick-Kraft", Icon = "👆", Desc = "Mehr Geld pro Klick", Max = 5, PerLevel = 1, Costs = { 1, 2, 2, 3, 4 } },
	},
	UpgradeOrder = { "Luck", "Magnet", "ClickPower" },
}
function Config.RebirthCost(rebirths: number): number
	return math.floor(Config.Rebirth.BaseCost * Config.Rebirth.CostGrowth ^ rebirths)
end
function Config.RebirthMultiplier(rebirths: number): number
	return 1 + rebirths * Config.Rebirth.IncomePerRebirth
end

-- Events ---------------------------------------------------------------------
Config.Events = {
	MinPause = 180, -- frühestens alle 3 Minuten ein Event
	MaxPause = 300, -- spätestens alle 5 Minuten
	Warning = 10, -- so viele Sekunden vorher kommt der Countdown
	FirstEventAfter = 45, -- das erste Event kommt schon nach X Sekunden (gut zum Testen)
	Weights = { Meteor = 50, Goldrausch = 30, Diebesnacht = 20 },

	Meteor = {
		Duration = 90, -- so lange liegt die Kreatur herum, bis sie verschwindet
		GrabTime = 1.5,
		Weights = { Epic = 55, Legendary = 37, Mythic = 8 },
		-- Mutationen beim Meteor sind wahrscheinlicher
		MutationWeights = { Normal = 55, Gold = 25, Diamant = 14, Regenbogen = 6 },
	},
	Goldrausch = {
		Duration = 60,
		IncomeMultiplier = 2,
	},
	Diebesnacht = {
		Duration = 60,
		WalkSpeed = 22, -- alle laufen schneller
		CarrySpeed = 18, -- auch mit Beute
	},
}

-- Tagesbonus (einmal pro Tag beim Joinen), je nach Base-Stufe
Config.DailyBonus = { 500, 2000, 10000, 50000, 200000 }

-- Sounds -------------------------------------------------------------------
-- Grund-Geräusche. Die mitgelieferten Roblox-Sounds funktionieren immer.
-- Eigene Sounds: In Studio Toolbox > Audio (Creator Store) einen Sound suchen,
-- Rechtsklick > "Copy Asset ID" und hier eintragen, z.B. Ping = "rbxassetid://1234567890".
Config.SoundSamples = {
	Ping = "rbxasset://sounds/electronicpingshort.wav",
	Click = "rbxasset://sounds/button.wav",
	Swoosh = "rbxasset://sounds/swoosh.wav",
	Oof = "rbxasset://sounds/uuhhh.mp3",
	Tick = "rbxasset://sounds/clickfast.wav",
}

-- Daraus werden kleine Melodien: { Geräusch, Tonhöhe, Lautstärke, Verzögerung in Sekunden }
-- Tonhöhe 1 = normal, 2 = eine Oktave höher, 1.26 / 1.5 = Terz / Quinte (klingt nach Fanfare)
Config.Sounds = {
	Click = { { "Click", 1, 0.5, 0 } },
	Tick = { { "Tick", 1, 0.35, 0 } },
	Collect = { { "Ping", 1.5, 0.45, 0 }, { "Ping", 2, 0.35, 0.07 } },
	Coin = { { "Ping", 2.2, 0.25, 0 } },
	Reveal = { { "Ping", 1, 0.5, 0 }, { "Ping", 1.26, 0.5, 0.09 }, { "Ping", 1.5, 0.6, 0.18 } },
	Epic = { { "Ping", 1, 0.5, 0 }, { "Ping", 1.26, 0.5, 0.09 }, { "Ping", 1.5, 0.6, 0.18 }, { "Ping", 2, 0.7, 0.3 } },
	Legendary = {
		{ "Swoosh", 0.7, 0.6, 0 },
		{ "Ping", 1, 0.6, 0.05 },
		{ "Ping", 1.26, 0.6, 0.15 },
		{ "Ping", 1.5, 0.7, 0.25 },
		{ "Ping", 2, 0.8, 0.38 },
		{ "Ping", 2.52, 0.8, 0.5 },
		{ "Ping", 3, 0.9, 0.62 },
	},
	Upgrade = {
		{ "Swoosh", 0.8, 0.6, 0 },
		{ "Ping", 0.75, 0.6, 0.05 },
		{ "Ping", 1, 0.6, 0.15 },
		{ "Ping", 1.26, 0.6, 0.25 },
		{ "Ping", 1.5, 0.8, 0.35 },
	},
	Announce = { { "Ping", 1.5, 0.4, 0 }, { "Ping", 2, 0.4, 0.12 } },
	Stolen = { { "Oof", 0.85, 0.8, 0 }, { "Swoosh", 0.5, 0.6, 0 }, { "Ping", 0.5, 0.5, 0.15 } },
	Hit = { { "Swoosh", 1.6, 0.7, 0 }, { "Ping", 0.6, 0.6, 0.03 } },
	Swoosh = { { "Swoosh", 1, 0.6, 0 } },
	Pop = { { "Click", 1.6, 0.25, 0 }, { "Ping", 2.6, 0.12, 0 } },
	Quest = { { "Ping", 1.5, 0.5, 0 }, { "Ping", 2, 0.5, 0.1 }, { "Ping", 3, 0.6, 0.2 } },
	Card = { { "Swoosh", 1.8, 0.35, 0 }, { "Click", 1.2, 0.3, 0 } },
	Rebirth = {
		{ "Swoosh", 0.5, 0.8, 0 },
		{ "Ping", 0.5, 0.6, 0.1 },
		{ "Ping", 0.75, 0.6, 0.25 },
		{ "Ping", 1, 0.7, 0.4 },
		{ "Ping", 1.5, 0.8, 0.55 },
		{ "Ping", 2, 0.9, 0.7 },
		{ "Ping", 3, 1, 0.85 },
		{ "Swoosh", 1.5, 0.7, 0.85 },
	},
}

-- Normale Laufgeschwindigkeit
Config.WalkSpeed = 16

-- Kreaturen-Einträge im Spielstand: "Blubbo" oder "Blubbo|Gold"
function Config.ParseEntry(entry: string)
	local id, mutation = string.match(entry, "^([^|]+)|?(.*)$")
	local def = id and Config.CreatureById[id]
	if mutation == nil or mutation == "" or not Config.Mutations[mutation] then
		mutation = "Normal"
	end
	return def, mutation
end

function Config.MakeEntry(id: string, mutation: string?): string
	if mutation and mutation ~= "Normal" then
		return id .. "|" .. mutation
	end
	return id
end

function Config.EntryIncome(entry: string): number
	local def, mutation = Config.ParseEntry(entry)
	return if def then def.Income * Config.Mutations[mutation].Multiplier else 0
end

function Config.EntryValue(entry: string): number
	local def, mutation = Config.ParseEntry(entry)
	return if def then def.Price * Config.Mutations[mutation].Multiplier else 0
end

function Config.EntryName(entry: string): string
	local def, mutation = Config.ParseEntry(entry)
	if not def then
		return "?"
	end
	local m = Config.Mutations[mutation]
	return if m.Name ~= "" then `{m.Name}-{def.Name}` else def.Name
end

Config.RarityOrder = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" }
function Config.RarityRank(rarity: string): number
	return table.find(Config.RarityOrder, rarity) or 0
end

-- Zufall nach Gewichten: { A = 10, B = 5 } -> "A" oder "B"
function Config.RollWeighted(weights, rng: Random?): string
	local total = 0
	for _, w in weights do
		total += w
	end
	local roll = (if rng then rng:NextNumber() else math.random()) * total
	-- feste Reihenfolge, damit es fair bleibt
	local keys = {}
	for k in weights do
		table.insert(keys, k)
	end
	table.sort(keys)
	for _, k in keys do
		roll -= weights[k]
		if roll <= 0 and weights[k] > 0 then
			return k
		end
	end
	for _, k in keys do
		if weights[k] > 0 then
			return k
		end
	end
	return keys[1]
end

-- Zufällige Kreatur einer Seltenheit
function Config.RandomCreatureOfRarity(rarity: string)
	local list = {}
	for _, def in Config.Creatures do
		if def.Rarity == rarity then
			table.insert(list, def)
		end
	end
	return list[math.random(1, #list)]
end

-- Chance in Prozent (für die Anzeige)
function Config.Percent(weights, key: string): number
	local total = 0
	for _, w in weights do
		total += w
	end
	return if total > 0 then (weights[key] or 0) / total * 100 else 0
end

-- Zahlen hübsch anzeigen: 1500 -> "1.5K", 2300000 -> "2.3M"
function Config.FormatNumber(n: number): string
	n = math.floor(n)
	local units = { { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } }
	for _, unit in units do
		if n >= unit[1] then
			local value = n / unit[1]
			local text = if value >= 100 then tostring(math.floor(value)) else string.format("%.1f", value)
			text = text:gsub("%.0$", "")
			return text .. unit[2]
		end
	end
	return tostring(n)
end

return Config
