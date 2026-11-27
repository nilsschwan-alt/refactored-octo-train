-- ALLE Spielwerte an einem Ort. Hier kannst du balancen, ohne die Logik anzufassen.
-- Liegt in Studio unter: ReplicatedStorage > Shared > Config

local Config = {}

Config.GameName = "Kreaturen-Klau"
Config.Version = "0.8.0"

-- Geld & Speichern ---------------------------------------------------------
Config.StartMoney = 300 -- reicht für die erste Holz-Kiste
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
-- Jede Kreatur gehört zu genau einer Kiste (Pack = Id der Kiste). Jede Kiste hat ihre
-- eigenen Kreaturen, und die werden von Kiste zu Kiste viel stärker.
-- Price = Wert (beim Verkaufen gibt es die Hälfte), Income = Geld pro Sekunde
-- Faustregel fürs Balancing: Einkommen innerhalb einer Kiste 1 : 2,5 : 6 : 18 : 60 (: 250),
-- und die nächste Kiste bringt etwa das 8-Fache.
-- Color, Accent, Extra = Aussehen der Klotz-Version, falls es kein 3D-Modell gibt.
-- Extra: "Ohren", "Hoerner", "Panzer", "Fuehler", "Hut", "Krone", "Stacheln", "Tentakel"
Config.Creatures = {
	-- Holz-Kiste
	{ Id = "Blubbo", Name = "Blubbo", Pack = "Holz", Rarity = "Common", Price = 30, Income = 1,
		Color = Color3.fromRGB(120, 220, 100), Accent = Color3.fromRGB(70, 160, 60), Extra = nil },
	{ Id = "Kruemelkrabbe", Name = "Krümelkrabbe", Pack = "Holz", Rarity = "Uncommon", Price = 75, Income = 3,
		Color = Color3.fromRGB(240, 120, 80), Accent = Color3.fromRGB(200, 70, 40), Extra = "Fuehler" },
	{ Id = "PupsiPilz", Name = "Pupsi-Pilz", Pack = "Holz", Rarity = "Rare", Price = 180, Income = 6,
		Color = Color3.fromRGB(245, 235, 210), Accent = Color3.fromRGB(220, 50, 50), Extra = "Hut" },
	{ Id = "Zappelfrosch", Name = "Zappelfrosch", Pack = "Holz", Rarity = "Epic", Price = 450, Income = 18,
		Color = Color3.fromRGB(60, 200, 160), Accent = Color3.fromRGB(250, 230, 60), Extra = "Ohren" },
	{ Id = "Funkelfuchs", Name = "Funkelfuchs", Pack = "Holz", Rarity = "Legendary", Price = 1200, Income = 60,
		Color = Color3.fromRGB(255, 140, 40), Accent = Color3.fromRGB(255, 255, 255), Extra = "Ohren" },
	-- Gold-Kiste
	{ Id = "Muenzmaus", Name = "Münzmaus", Pack = "Gold", Rarity = "Common", Price = 750, Income = 8,
		Color = Color3.fromRGB(250, 205, 70), Accent = Color3.fromRGB(255, 240, 170), Extra = "Ohren" },
	{ Id = "Wolkenwurm", Name = "Wolkenwurm", Pack = "Gold", Rarity = "Uncommon", Price = 1900, Income = 20,
		Color = Color3.fromRGB(220, 235, 255), Accent = Color3.fromRGB(130, 180, 255), Extra = "Fuehler" },
	{ Id = "Donnerdachs", Name = "Donnerdachs", Pack = "Gold", Rarity = "Rare", Price = 4500, Income = 50,
		Color = Color3.fromRGB(80, 80, 110), Accent = Color3.fromRGB(255, 240, 60), Extra = "Hoerner" },
	{ Id = "Glitzergans", Name = "Glitzergans", Pack = "Gold", Rarity = "Epic", Price = 11000, Income = 150,
		Color = Color3.fromRGB(255, 250, 235), Accent = Color3.fromRGB(255, 200, 60), Extra = "Hut" },
	{ Id = "Kronenloewe", Name = "Kronenlöwe", Pack = "Gold", Rarity = "Legendary", Price = 30000, Income = 500,
		Color = Color3.fromRGB(240, 170, 50), Accent = Color3.fromRGB(255, 235, 120), Extra = "Krone" },
	-- Kristall-Kiste
	{ Id = "Splitterspatz", Name = "Splitterspatz", Pack = "Kristall", Rarity = "Common", Price = 15000, Income = 60,
		Color = Color3.fromRGB(190, 150, 255), Accent = Color3.fromRGB(120, 240, 255), Extra = "Fuehler" },
	{ Id = "QuarzQualle", Name = "Quarz-Qualle", Pack = "Kristall", Rarity = "Uncommon", Price = 38000, Income = 150,
		Color = Color3.fromRGB(255, 170, 230), Accent = Color3.fromRGB(200, 240, 255), Extra = "Tentakel" },
	{ Id = "PrismaPanda", Name = "Prisma-Panda", Pack = "Kristall", Rarity = "Rare", Price = 90000, Income = 360,
		Color = Color3.fromRGB(245, 245, 255), Accent = Color3.fromRGB(150, 90, 255), Extra = "Ohren" },
	{ Id = "JuwelenJaguar", Name = "Juwelen-Jaguar", Pack = "Kristall", Rarity = "Epic", Price = 220000, Income = 1100,
		Color = Color3.fromRGB(90, 60, 170), Accent = Color3.fromRGB(80, 255, 200), Extra = "Ohren" },
	{ Id = "KristallDrache", Name = "Kristall-Drache", Pack = "Kristall", Rarity = "Legendary", Price = 600000, Income = 3600,
		Color = Color3.fromRGB(150, 100, 255), Accent = Color3.fromRGB(140, 250, 255), Extra = "Stacheln" },
	{ Id = "RegenbogenRex", Name = "Regenbogen-Rex", Pack = "Kristall", Rarity = "Mythic", Price = 2200000, Income = 15000,
		Color = Color3.fromRGB(255, 80, 200), Accent = Color3.fromRGB(80, 255, 230), Extra = "Krone" },
	-- Lava-Kiste
	{ Id = "Glutkaefer", Name = "Glutkäfer", Pack = "Lava", Rarity = "Common", Price = 350000, Income = 500,
		Color = Color3.fromRGB(70, 40, 35), Accent = Color3.fromRGB(255, 120, 30), Extra = "Fuehler" },
	{ Id = "LavaLurch", Name = "Lava-Lurch", Pack = "Lava", Rarity = "Uncommon", Price = 880000, Income = 1250,
		Color = Color3.fromRGB(60, 40, 40), Accent = Color3.fromRGB(255, 90, 20), Extra = "Stacheln" },
	{ Id = "AscheAffe", Name = "Asche-Affe", Pack = "Lava", Rarity = "Rare", Price = 2100000, Income = 3000,
		Color = Color3.fromRGB(95, 90, 95), Accent = Color3.fromRGB(255, 150, 40), Extra = "Ohren" },
	{ Id = "VulkanWidder", Name = "Vulkan-Widder", Pack = "Lava", Rarity = "Epic", Price = 5200000, Income = 9000,
		Color = Color3.fromRGB(110, 55, 40), Accent = Color3.fromRGB(255, 200, 60), Extra = "Hoerner" },
	{ Id = "MagmaMammut", Name = "Magma-Mammut", Pack = "Lava", Rarity = "Legendary", Price = 14000000, Income = 30000,
		Color = Color3.fromRGB(55, 35, 35), Accent = Color3.fromRGB(255, 80, 20), Extra = "Hoerner" },
	{ Id = "FeuerPhoenix", Name = "Feuer-Phönix", Pack = "Lava", Rarity = "Mythic", Price = 52000000, Income = 125000,
		Color = Color3.fromRGB(255, 110, 30), Accent = Color3.fromRGB(255, 230, 90), Extra = "Krone" },
	-- Eis-Kiste
	{ Id = "Schneehase", Name = "Schneehase", Pack = "Eis", Rarity = "Common", Price = 8000000, Income = 4000,
		Color = Color3.fromRGB(245, 250, 255), Accent = Color3.fromRGB(170, 220, 255), Extra = "Ohren" },
	{ Id = "EisIgel", Name = "Eiskristall-Igel", Pack = "Eis", Rarity = "Uncommon", Price = 20000000, Income = 10000,
		Color = Color3.fromRGB(170, 230, 255), Accent = Color3.fromRGB(240, 255, 255), Extra = "Stacheln" },
	{ Id = "FrostRobbe", Name = "Frost-Robbe", Pack = "Eis", Rarity = "Rare", Price = 48000000, Income = 24000,
		Color = Color3.fromRGB(200, 225, 245), Accent = Color3.fromRGB(90, 150, 220), Extra = nil },
	{ Id = "GletscherBaer", Name = "Gletscher-Bär", Pack = "Eis", Rarity = "Epic", Price = 120000000, Income = 72000,
		Color = Color3.fromRGB(235, 245, 255), Accent = Color3.fromRGB(110, 190, 255), Extra = "Ohren" },
	{ Id = "SturmWolf", Name = "Schneesturm-Wolf", Pack = "Eis", Rarity = "Legendary", Price = 320000000, Income = 240000,
		Color = Color3.fromRGB(150, 180, 220), Accent = Color3.fromRGB(240, 250, 255), Extra = "Ohren" },
	{ Id = "EisTitan", Name = "Eis-Titan", Pack = "Eis", Rarity = "Mythic", Price = 1200000000, Income = 1000000,
		Color = Color3.fromRGB(110, 200, 255), Accent = Color3.fromRGB(255, 255, 255), Extra = "Krone" },
	-- Galaxie-Kiste
	{ Id = "MondMotte", Name = "Mond-Motte", Pack = "Galaxie", Rarity = "Common", Price = 160000000, Income = 32000,
		Color = Color3.fromRGB(210, 210, 235), Accent = Color3.fromRGB(120, 110, 200), Extra = "Fuehler" },
	{ Id = "KometenKater", Name = "Kometen-Kater", Pack = "Galaxie", Rarity = "Uncommon", Price = 400000000, Income = 80000,
		Color = Color3.fromRGB(60, 50, 120), Accent = Color3.fromRGB(120, 220, 255), Extra = "Ohren" },
	{ Id = "NebelNarwal", Name = "Nebel-Narwal", Pack = "Galaxie", Rarity = "Rare", Price = 960000000, Income = 190000,
		Color = Color3.fromRGB(150, 80, 220), Accent = Color3.fromRGB(255, 150, 230), Extra = "Hoerner" },
	{ Id = "SaturnSchildkroete", Name = "Saturn-Schildkröte", Pack = "Galaxie", Rarity = "Epic", Price = 2400000000, Income = 580000,
		Color = Color3.fromRGB(70, 90, 170), Accent = Color3.fromRGB(255, 200, 110), Extra = "Panzer" },
	{ Id = "Sternenschnecke", Name = "Sternenschnecke", Pack = "Galaxie", Rarity = "Legendary", Price = 6400000000, Income = 1900000,
		Color = Color3.fromRGB(40, 30, 90), Accent = Color3.fromRGB(255, 220, 90), Extra = "Panzer" },
	{ Id = "KosmoKrake", Name = "Kosmo-Krake", Pack = "Galaxie", Rarity = "Mythic", Price = 24000000000, Income = 8000000,
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

-- Kisten (im Code heißen sie Packs) -----------------------------------------------
-- Jede Kiste hat ihre eigenen Kreaturen (siehe oben, Feld Pack).
-- Rebirths = so viele Wiedergeburten braucht man, um die Kiste kaufen zu dürfen.
-- Weights = Chancen pro Seltenheit. Mythisch gibt es erst ab der Kristall-Kiste.
-- Faustregel: Jede Kiste kostet etwa das 20- bis 25-Fache der vorigen.
-- Pity: Nach so vielen Kisten ohne Legendär oder besser ist die nächste garantiert Legendär+.
Config.PityThreshold = 20
Config.Packs = {
	{
		Id = "Holz",
		Name = "Holz-Kiste",
		Price = 300,
		Rebirths = 0,
		Color = Color3.fromRGB(170, 120, 70),
		Weights = { Common = 48, Uncommon = 30, Rare = 15, Epic = 6, Legendary = 1 },
	},
	{
		Id = "Gold",
		Name = "Gold-Kiste",
		Price = 7500,
		Rebirths = 0,
		Color = Color3.fromRGB(255, 200, 40),
		Weights = { Common = 48, Uncommon = 30, Rare = 15, Epic = 6, Legendary = 1 },
	},
	{
		Id = "Kristall",
		Name = "Kristall-Kiste",
		Price = 150000,
		Rebirths = 1,
		Color = Color3.fromRGB(180, 100, 255),
		Weights = { Common = 48, Uncommon = 30, Rare = 15, Epic = 6, Legendary = 1, Mythic = 0.3 },
	},
	{
		Id = "Lava",
		Name = "Lava-Kiste",
		Price = 3500000,
		Rebirths = 2,
		Color = Color3.fromRGB(255, 95, 35),
		Weights = { Common = 48, Uncommon = 30, Rare = 15, Epic = 6, Legendary = 1, Mythic = 0.3 },
	},
	{
		Id = "Eis",
		Name = "Eis-Kiste",
		Price = 80000000,
		Rebirths = 3,
		Color = Color3.fromRGB(130, 215, 255),
		Weights = { Common = 48, Uncommon = 30, Rare = 15, Epic = 6, Legendary = 1, Mythic = 0.3 },
	},
	{
		Id = "Galaxie",
		Name = "Galaxie-Kiste",
		Price = 1600000000,
		Rebirths = 4,
		Color = Color3.fromRGB(85, 95, 255),
		Weights = { Common = 48, Uncommon = 30, Rare = 15, Epic = 6, Legendary = 1, Mythic = 0.3 },
	},
}

-- Schnellzugriff (wird automatisch gefüllt): Config.PackById.Holz, und jede Kiste kennt
-- ihre Kreaturen (pack.Creatures) und ihren Platz in der Liste (pack.Index).
Config.PackById = {}
for index, pack in Config.Packs do
	pack.Index = index
	pack.Creatures = {}
	Config.PackById[pack.Id] = pack
end
for _, creature in Config.Creatures do
	local pack = Config.PackById[creature.Pack]
	if pack then
		table.insert(pack.Creatures, creature)
	end
end

-- Darf man die Kiste mit so vielen Wiedergeburten schon kaufen?
function Config.PackUnlocked(pack, rebirths: number?): boolean
	return (rebirths or 0) >= (pack.Rebirths or 0)
end

-- Die beste Kiste, die man mit so vielen Wiedergeburten kaufen darf
function Config.BestPack(rebirths: number?)
	local best = Config.Packs[1]
	for _, pack in Config.Packs do
		if Config.PackUnlocked(pack, rebirths) then
			best = pack
		end
	end
	return best
end

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

-- Glück (aus dem Rebirth-Shop) macht Selten und besser wahrscheinlicher.
-- Seltenheiten, für die die Kiste keine Kreatur hat, fallen raus.
function Config.PackWeights(pack, luckLevel: number?)
	local bonus = 1 + (luckLevel or 0) * Config.Rebirth.Upgrades.Luck.PerLevel
	local has = {}
	for _, creature in pack.Creatures do
		has[creature.Rarity] = true
	end
	local weights = {}
	for rarity, w in pack.Weights do
		if has[rarity] then
			weights[rarity] = if Config.RarityRank(rarity) >= Config.RarityRank("Rare") then w * bonus else w
		end
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
		OpenPacks = { Text = "Öffne {n} Kisten", Min = 3, Max = 8, Factor = 1.2 },
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
	-- Kosten der 1., 2., 3. ... Wiedergeburt. Faustregel: etwa 20 Kisten der besten Sorte,
	-- die man gerade kaufen darf. Jede der ersten vier schaltet eine neue Kiste frei.
	Costs = { 150000, 3000000, 60000000, 1500000000, 30000000000 },
	CostGrowth = 5, -- danach kostet jede weitere 5x so viel
	IncomePerRebirth = 0.5, -- +50 % Einkommen pro Wiedergeburt
	KeepCreatures = 4, -- so viele der besten Kreaturen bleiben
	TokensPerRebirth = 2,
	Upgrades = {
		Luck = { Name = "Glück", Icon = "🍀", Desc = "Selten+ in Kisten wahrscheinlicher", Max = 5, PerLevel = 0.2, Costs = { 1, 2, 3, 4, 5 } },
		Magnet = { Name = "Münz-Magnet", Icon = "🧲", Desc = "Münzen von weiter weg einsammeln", Max = 5, PerLevel = 3, Costs = { 1, 1, 2, 2, 3 } },
		ClickPower = { Name = "Klick-Kraft", Icon = "👆", Desc = "Mehr Geld pro Klick", Max = 5, PerLevel = 1, Costs = { 1, 2, 2, 3, 4 } },
	},
	UpgradeOrder = { "Luck", "Magnet", "ClickPower" },
}
function Config.RebirthCost(rebirths: number): number
	local costs = Config.Rebirth.Costs
	if rebirths < #costs then
		return costs[rebirths + 1]
	end
	return math.floor(costs[#costs] * Config.Rebirth.CostGrowth ^ (rebirths - #costs + 1))
end
-- Welche Kiste schaltet die nächste Wiedergeburt frei? (nil = keine neue)
function Config.RebirthUnlock(rebirths: number)
	for _, pack in Config.Packs do
		if pack.Rebirths == rebirths + 1 then
			return pack
		end
	end
	return nil
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
		-- Die Kreatur kommt aus der besten Kiste, die ALLE Spieler auf dem Server schon
		-- kaufen dürfen (sonst bekämen Neue sofort Monster vom Ende des Spiels).
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
	-- Creator-Store-Sounds von APM und Pro Sound Effects (in jedem Spiel erlaubt), Richtung
	-- "wuchtig und episch". Alle in Studio ausgemessen: Sie fangen ohne Vorlauf an, darum
	-- sitzen sie genau auf dem Bild. Hinter jedem steht die Länge.
	Thud = "rbxassetid://9126267607", -- dumpfer Aufschlag, 0,73 s
	Boom = "rbxassetid://1837830656", -- tiefer Kino-Wumms, 2,9 s
	SubHit = "rbxassetid://9126009571", -- tiefer Trommelschlag, 0,63 s
	Kick = "rbxassetid://9043367506", -- harter Schlag, 1,15 s
	MetalRing = "rbxassetid://1837829473", -- heller Metall-Schlag, klingt lange nach
	Riser = "rbxassetid://1847543036", -- Becken, das anschwillt (am lautesten bei 2,07 s)
	Rip = "rbxassetid://9117624703", -- Reißen, 1,36 s
	Punch = "rbxassetid://9040280079", -- großer Einschlag, 5 s (Kraft in den ersten 1,3 s)
	Smash = "rbxassetid://9040283831", -- zweiter großer Einschlag, 7 s
	ZoomUp = "rbxassetid://9125648149", -- Zischen nach oben, 0,72 s
	Anvil = "rbxassetid://9113133643", -- Amboss-Schlag, 0,77 s
	Bell = "rbxassetid://1843035275", -- Orchester-Glocke, klingt lange nach
	WoodWhoosh = "rbxassetid://9120972321", -- kurzes Zischen, 0,56 s
	WoodTick = "rbxassetid://9119982224", -- Holzblock-Klick, 0,1 s
	StingSmall = "rbxassetid://1846902656", -- ein tiefer Orchester-Schlag, 3,4 s
	StingStabs = "rbxassetid://1846902224", -- kurze Orchester-Schläge, 3,5 s
	StingWin = "rbxassetid://1840076509", -- Orchester-Tusch, 2,25 s
	StingBrute = "rbxassetid://1837950656", -- großer Tusch, 6,5 s
	StingPower = "rbxassetid://1841824473", -- größter Tusch, 5,1 s
}

-- Nach so vielen Sekunden ist der Riser am lautesten. Die Pack-Öffnung startet ihn so,
-- dass diese Stelle genau auf den Knall fällt.
Config.RiserPeak = 2.07

-- Daraus werden kleine Melodien: { Geräusch, Tonhöhe, Lautstärke, Verzögerung in Sekunden }
-- Optional eine fünfte Zahl: nach so vielen Sekunden wird der Ton ausgeblendet (für Sounds,
-- die lange nachklingen).
-- Tonhöhe 1 = normal, 2 = eine Oktave höher, 1.26 / 1.5 = Terz / Quinte (klingt nach Fanfare)
Config.Sounds = {
	Click = { { "Click", 1, 0.5, 0 } },
	Tick = { { "Tick", 1, 0.35, 0 } },
	Collect = { { "Ping", 1.5, 0.45, 0 }, { "Ping", 2, 0.35, 0.07 } },
	Coin = { { "Ping", 2.2, 0.25, 0 } },
	Reveal = { { "Ping", 1, 0.5, 0 }, { "Ping", 1.26, 0.5, 0.09 }, { "Ping", 1.5, 0.6, 0.18 } },
	-- Pack-Öffnung: ein Eintrag pro Moment der Animation -------------------------
	PackDrop = { { "WoodWhoosh", 0.7, 1, 0 } }, -- Pack fällt
	PackSlam = { { "Boom", 1, 0.8, 0, 1.2 }, { "Thud", 0.9, 0.7, 0 } }, -- Pack schlägt auf
	PackHit = { { "SubHit", 1, 1.3, 0 }, { "Kick", 1, 0.35, 0, 0.5 } }, -- jeder Schlag (wird höher)
	TellStep = { { "MetalRing", 1, 0.6, 0, 0.8 } }, -- Farbe steigt eine Stufe (wird höher)
	PackBurst = { { "Punch", 1, 0.9, 0, 1.6 }, { "Rip", 1, 0.5, 0 } }, -- Pack platzt
	PackBurstBig = { { "Smash", 1, 0.6, 0, 1.8 } }, -- dazu ab Episch
	Appear = { { "ZoomUp", 1, 1, 0 } }, -- Kreatur steigt auf
	Stamp = { { "Anvil", 1, 1.2, 0 }, { "Thud", 1.5, 0.5, 0 } }, -- Mutations-Stempel
	CountTick = { { "WoodTick", 1, 0.9, 0, 0.25 } }, -- Zahl zählt hoch
	CountDone = { { "Bell", 1.5, 1, 0, 1.2 } },
	CardDeal = { { "WoodWhoosh", 1.2, 0.8, 0 } }, -- Karte fliegt raus
	CardFlip = { { "WoodTick", 0.75, 1.2, 0, 0.25 }, { "WoodWhoosh", 1.6, 0.3, 0 } }, -- Karte dreht sich um
	-- Tusch bei der Landung, je seltener desto größer
	RevealCommon = { { "StingSmall", 1.25, 0.5, 0, 1.2 } },
	Rare = { { "StingStabs", 1, 0.6, 0, 1.3 } },
	Epic = { { "StingWin", 1, 0.8, 0 } },
	Legendary = { { "StingBrute", 1, 0.9, 0, 3.5 }, { "Boom", 1, 0.5, 0, 1.5 } },
	Mythic = { { "StingPower", 1, 1, 0 }, { "Boom", 0.8, 0.7, 0, 2 } },
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

-- Zufällige Kreatur einer Seltenheit aus einer Kiste. Hat die Kiste keine Kreatur dieser
-- Seltenheit, gibt es die nächstbeste darunter.
function Config.RandomCreatureOfRarity(rarity: string, pack)
	local pool = if pack then pack.Creatures else Config.Creatures
	local rank = Config.RarityRank(rarity)
	while rank >= 1 do
		local list = {}
		for _, def in pool do
			if def.Rarity == Config.RarityOrder[rank] then
				table.insert(list, def)
			end
		end
		if #list > 0 then
			return list[math.random(1, #list)]
		end
		rank -= 1
	end
	return pool[1]
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
	local units = { { 1e15, "Qa" }, { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } }
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
