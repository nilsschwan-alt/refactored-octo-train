-- ALLE Spielwerte an einem Ort. Hier kannst du balancen, ohne die Logik anzufassen.
-- Liegt in Studio unter: ReplicatedStorage > Shared > Config

local Config = {}

Config.GameName = "Kreaturen-Klau"
Config.Version = "0.15.2"

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
-- Große Zahlen darf man mit Unterstrichen schreiben: 1_000_000 ist eine Million.
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
	{ Id = "Glitzergans", Name = "Glitzergans", Pack = "Gold", Rarity = "Epic", Price = 11_000, Income = 150,
		Color = Color3.fromRGB(255, 250, 235), Accent = Color3.fromRGB(255, 200, 60), Extra = "Hut" },
	{ Id = "Kronenloewe", Name = "Kronenlöwe", Pack = "Gold", Rarity = "Legendary", Price = 30_000, Income = 500,
		Color = Color3.fromRGB(240, 170, 50), Accent = Color3.fromRGB(255, 235, 120), Extra = "Krone" },
	-- Kristall-Kiste
	{ Id = "Splitterspatz", Name = "Splitter-Spatz", Pack = "Kristall", Rarity = "Common", Price = 20_000, Income = 60,
		Color = Color3.fromRGB(190, 150, 255), Accent = Color3.fromRGB(120, 240, 255), Extra = "Fuehler" },
	{ Id = "QuarzQualle", Name = "Quarz-Qualle", Pack = "Kristall", Rarity = "Uncommon", Price = 50_000, Income = 150,
		Color = Color3.fromRGB(255, 170, 230), Accent = Color3.fromRGB(200, 240, 255), Extra = "Tentakel" },
	{ Id = "PrismaPanda", Name = "Prisma-Panda", Pack = "Kristall", Rarity = "Rare", Price = 120_000, Income = 360,
		Color = Color3.fromRGB(245, 245, 255), Accent = Color3.fromRGB(150, 90, 255), Extra = "Ohren" },
	{ Id = "JuwelenJaguar", Name = "Juwelen-Jaguar", Pack = "Kristall", Rarity = "Epic", Price = 300_000, Income = 1100,
		Color = Color3.fromRGB(90, 60, 170), Accent = Color3.fromRGB(80, 255, 200), Extra = "Ohren" },
	{ Id = "KristallDrache", Name = "Kristall-Drache", Pack = "Kristall", Rarity = "Legendary", Price = 800_000, Income = 3600,
		Color = Color3.fromRGB(150, 100, 255), Accent = Color3.fromRGB(140, 250, 255), Extra = "Stacheln" },
	{ Id = "RegenbogenRex", Name = "Regenbogen-Rex", Pack = "Kristall", Rarity = "Mythic", Price = 3_000_000, Income = 15_000,
		Color = Color3.fromRGB(255, 80, 200), Accent = Color3.fromRGB(80, 255, 230), Extra = "Krone" },
	-- Lava-Kiste
	{ Id = "Glutkaefer", Name = "Glutkäfer", Pack = "Lava", Rarity = "Common", Price = 500_000, Income = 500,
		Color = Color3.fromRGB(70, 40, 35), Accent = Color3.fromRGB(255, 120, 30), Extra = "Fuehler" },
	{ Id = "LavaLurch", Name = "Lava-Lurch", Pack = "Lava", Rarity = "Uncommon", Price = 1_200_000, Income = 1250,
		Color = Color3.fromRGB(60, 40, 40), Accent = Color3.fromRGB(255, 90, 20), Extra = "Stacheln" },
	{ Id = "AscheAffe", Name = "Asche-Affe", Pack = "Lava", Rarity = "Rare", Price = 3_000_000, Income = 3000,
		Color = Color3.fromRGB(95, 90, 95), Accent = Color3.fromRGB(255, 150, 40), Extra = "Ohren" },
	{ Id = "VulkanWidder", Name = "Vulkan-Widder", Pack = "Lava", Rarity = "Epic", Price = 7_500_000, Income = 9000,
		Color = Color3.fromRGB(110, 55, 40), Accent = Color3.fromRGB(255, 200, 60), Extra = "Hoerner" },
	{ Id = "MagmaMammut", Name = "Magma-Mammut", Pack = "Lava", Rarity = "Legendary", Price = 20_000_000, Income = 30_000,
		Color = Color3.fromRGB(55, 35, 35), Accent = Color3.fromRGB(255, 80, 20), Extra = "Hoerner" },
	{ Id = "FeuerPhoenix", Name = "Feuer-Phönix", Pack = "Lava", Rarity = "Mythic", Price = 75_000_000, Income = 125_000,
		Color = Color3.fromRGB(255, 110, 30), Accent = Color3.fromRGB(255, 230, 90), Extra = "Krone" },
	-- Eis-Kiste
	{ Id = "Schneehase", Name = "Schneehase", Pack = "Eis", Rarity = "Common", Price = 10_000_000, Income = 4000,
		Color = Color3.fromRGB(245, 250, 255), Accent = Color3.fromRGB(170, 220, 255), Extra = "Ohren" },
	{ Id = "EisIgel", Name = "Eiskristall-Igel", Pack = "Eis", Rarity = "Uncommon", Price = 25_000_000, Income = 10_000,
		Color = Color3.fromRGB(170, 230, 255), Accent = Color3.fromRGB(240, 255, 255), Extra = "Stacheln" },
	{ Id = "FrostRobbe", Name = "Frost-Robbe", Pack = "Eis", Rarity = "Rare", Price = 60_000_000, Income = 24_000,
		Color = Color3.fromRGB(200, 225, 245), Accent = Color3.fromRGB(90, 150, 220), Extra = nil },
	{ Id = "GletscherBaer", Name = "Gletscher-Bär", Pack = "Eis", Rarity = "Epic", Price = 150_000_000, Income = 72_000,
		Color = Color3.fromRGB(235, 245, 255), Accent = Color3.fromRGB(110, 190, 255), Extra = "Ohren" },
	{ Id = "SturmWolf", Name = "Schneesturm-Wolf", Pack = "Eis", Rarity = "Legendary", Price = 400_000_000, Income = 240_000,
		Color = Color3.fromRGB(150, 180, 220), Accent = Color3.fromRGB(240, 250, 255), Extra = "Ohren" },
	{ Id = "EisTitan", Name = "Eis-Titan", Pack = "Eis", Rarity = "Mythic", Price = 1_500_000_000, Income = 1_000_000,
		Color = Color3.fromRGB(110, 200, 255), Accent = Color3.fromRGB(255, 255, 255), Extra = "Krone" },
	-- Galaxie-Kiste
	{ Id = "MondMotte", Name = "Mond-Motte", Pack = "Galaxie", Rarity = "Common", Price = 200_000_000, Income = 32_000,
		Color = Color3.fromRGB(210, 210, 235), Accent = Color3.fromRGB(120, 110, 200), Extra = "Fuehler" },
	{ Id = "KometenKater", Name = "Kometen-Kater", Pack = "Galaxie", Rarity = "Uncommon", Price = 500_000_000, Income = 80_000,
		Color = Color3.fromRGB(60, 50, 120), Accent = Color3.fromRGB(120, 220, 255), Extra = "Ohren" },
	{ Id = "NebelNarwal", Name = "Nebel-Narwal", Pack = "Galaxie", Rarity = "Rare", Price = 1_200_000_000, Income = 190_000,
		Color = Color3.fromRGB(150, 80, 220), Accent = Color3.fromRGB(255, 150, 230), Extra = "Hoerner" },
	{ Id = "SaturnSchildkroete", Name = "Saturn-Schildkröte", Pack = "Galaxie", Rarity = "Epic", Price = 3_000_000_000, Income = 580_000,
		Color = Color3.fromRGB(70, 90, 170), Accent = Color3.fromRGB(255, 200, 110), Extra = "Panzer" },
	{ Id = "Sternenschnecke", Name = "Sternen-Schnecke", Pack = "Galaxie", Rarity = "Legendary", Price = 8_000_000_000, Income = 1_900_000,
		Color = Color3.fromRGB(40, 30, 90), Accent = Color3.fromRGB(255, 220, 90), Extra = "Panzer" },
	{ Id = "KosmoKrake", Name = "Kosmo-Krake", Pack = "Galaxie", Rarity = "Mythic", Price = 30_000_000_000, Income = 8_000_000,
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

-- Sterne (Verschmelzen) ----------------------------------------------------------
-- 3 gleiche Kreaturen (gleiche Art, gleiche Mutation, gleich viele Sterne) werden zu einer
-- mit einem Stern mehr. Multipliers = so viel mehr Geld macht sie mit 1, 2, 3, 4, 5 Sternen.
Config.Stars = {
	Max = 5,
	Need = 3, -- so viele gleiche braucht man für einen Stern mehr
	-- Einkommen mit 1 bis 5 Sternen (mal so viel wie ohne Stern). Jede Stufe ist etwas mehr
	-- als das Dreifache der vorigen, damit sich Verschmelzen immer lohnt.
	Multipliers = { 3.2, 10, 32, 100, 320 },
	SizeBonus = 0.07, -- pro Stern wird die Kreatur so viel größer
	AnnounceFrom = 3, -- ab so vielen Sternen erfährt es der ganze Server
}
function Config.StarMultiplier(stars: number?): number
	if not stars or stars <= 0 then
		return 1
	end
	return Config.Stars.Multipliers[math.min(stars, #Config.Stars.Multipliers)]
end

-- Skill-Baum (Waben-Netz) -----------------------------------------------------------
-- Bezahlt wird mit Tokens. Tokens gibt es für Wiedergeburten und für geschaffte Aufgaben.
-- Jede Fähigkeit ist eine Wabe. Hex = Platz im Netz (Mitte ist 0,0). Lernen kann man nur
-- Waben, die an die Mitte oder an eine schon gelernte Wabe angrenzen.
-- Max = höchste Stufe, Costs = Token-Preis je Stufe, PerLevel = Wirkung pro Stufe.
-- Text: {v} wird durch die Wirkung ersetzt (bei Percent = true als Prozent).
Config.Skills = {
	QuestsPerToken = 2, -- jede 2. geschaffte Aufgabe gibt Tokens
	TokensPerQuest = 1,
	Branches = {
		Geld = { Name = "Geld & Klick", Icon = "💰", Color = Color3.fromRGB(255, 200, 60) },
		Glueck = { Name = "Glück", Icon = "🍀", Color = Color3.fromRGB(90, 220, 110) },
		Dieb = { Name = "Dieb & Schutz", Icon = "🛡️", Color = Color3.fromRGB(255, 95, 110) },
	},
	List = {
		-- Geld & Klick (innen: 2 Waben, Mitte: 4, außen: 6)
		{ Id = "Income", Branch = "Geld", Hex = { 1, 0 }, Name = "Sparschwein", Icon = "🐷", Max = 5, Costs = { 1, 1, 2, 2, 3 }, PerLevel = 0.05, Percent = true, Text = "+{v} % Einkommen" },
		{ Id = "ClickPower", Branch = "Geld", Hex = { 1, -1 }, Name = "Klick-Kraft", Icon = "👆", Max = 5, Costs = { 1, 1, 2, 2, 3 }, PerLevel = 0.25, Percent = true, Text = "+{v} % Geld pro Klick" },
		{ Id = "AutoClick", Branch = "Geld", Hex = { 2, 0 }, Name = "Auto-Klicker", Icon = "🤖", Max = 5, Costs = { 1, 1, 2, 2, 3 }, PerLevel = 1, Text = "{v} Klick(s) pro Sekunde ganz von allein" },
		{ Id = "Crit", Branch = "Geld", Hex = { 2, -1 }, Name = "Volltreffer", Icon = "💥", Max = 5, Costs = { 1, 1, 2, 2, 3 }, PerLevel = 0.02, Percent = true, Text = "+{v} % Chance auf einen Volltreffer (viel mehr Geld)" },
		{ Id = "CritPower", Branch = "Geld", Hex = { 2, -2 }, Name = "Wumms", Icon = "🌟", Max = 3, Costs = { 2, 3, 4 }, PerLevel = 1, Text = "Volltreffer bringen noch {v}x mehr" },
		{ Id = "QuestBonus", Branch = "Geld", Hex = { 1, -2 }, Name = "Quest-Profi", Icon = "📜", Max = 3, Costs = { 2, 3, 4 }, PerLevel = 0.15, Percent = true, Text = "Aufgaben bringen +{v} % Geld" },
		{ Id = "ComboTime", Branch = "Geld", Hex = { 3, 0 }, Name = "Langer Atem", Icon = "⏱️", Max = 3, Costs = { 2, 3, 4 }, PerLevel = 0.5, Text = "Die Combo hält {v} Sekunden länger" },
		{ Id = "ComboPower", Branch = "Geld", Hex = { 3, -1 }, Name = "Combo-Meister", Icon = "🔥", Max = 3, Costs = { 2, 3, 4 }, PerLevel = 0.2, Percent = true, Text = "Der Combo-Bonus ist +{v} % stärker" },
		{ Id = "GoldDonkey", Branch = "Geld", Hex = { 3, -2 }, Name = "Goldesel", Icon = "👑", Max = 1, Costs = { 8 }, PerLevel = 0.25, Percent = true, Text = "+{v} % Einkommen, für immer" },
		{ Id = "WorldClick", Branch = "Geld", Hex = { 3, -3 }, Name = "Welten-Bummler", Icon = "🌍", Max = 3, Costs = { 2, 3, 4 }, PerLevel = 0.2, Percent = true, Text = "In den Welten +{v} % Geld pro Klick" },
		{ Id = "Jackpot", Branch = "Geld", Hex = { 2, -3 }, Name = "Jackpot", Icon = "🎰", Max = 3, Costs = { 3, 4, 5 }, PerLevel = 0.002, Percent = true, Text = "{v} % Chance pro Klick auf den Jackpot" },
		{ Id = "GoldRush", Branch = "Geld", Hex = { 1, -3 }, Name = "Goldgräber", Icon = "⛏️", Max = 3, Costs = { 2, 3, 4 }, PerLevel = 0.25, Percent = true, Text = "Im Goldrausch noch +{v} % Einkommen dazu" },
		-- Glück
		{ Id = "Luck", Branch = "Glueck", Hex = { 0, -1 }, Name = "Glück", Icon = "🍀", Max = 5, Costs = { 1, 1, 2, 2, 3 }, PerLevel = 0.2, Percent = true, Text = "Selten und besser: +{v} % wahrscheinlicher" },
		{ Id = "Mutation", Branch = "Glueck", Hex = { -1, 0 }, Name = "Mutations-Gespür", Icon = "🌈", Max = 5, Costs = { 1, 1, 2, 2, 3 }, PerLevel = 0.15, Percent = true, Text = "Mutationen: +{v} % wahrscheinlicher" },
		{ Id = "Pity", Branch = "Glueck", Hex = { 0, -2 }, Name = "Garantie", Icon = "🎯", Max = 5, Costs = { 1, 1, 2, 2, 3 }, PerLevel = 1, Text = "Legendär-Garantie {v} Kiste(n) früher" },
		{ Id = "Refund", Branch = "Glueck", Hex = { -1, -1 }, Name = "Gratis-Kiste", Icon = "🎁", Max = 5, Costs = { 1, 1, 2, 2, 3 }, PerLevel = 0.03, Percent = true, Text = "{v} % Chance: eine Kiste kostet nichts" },
		{ Id = "SellBonus", Branch = "Glueck", Hex = { -2, 0 }, Name = "Händler", Icon = "🤝", Max = 3, Costs = { 2, 3, 4 }, PerLevel = 0.1, Percent = true, Text = "+{v} % Geld beim Verkaufen" },
		{ Id = "StarLuck", Branch = "Glueck", Hex = { -2, 1 }, Name = "Sternen-Glück", Icon = "✨", Max = 3, Costs = { 2, 3, 4 }, PerLevel = 0.05, Percent = true, Text = "{v} % Chance auf einen Extra-Stern beim Verschmelzen" },
		{ Id = "TokenLuck", Branch = "Glueck", Hex = { 0, -3 }, Name = "Token-Finder", Icon = "💠", Max = 3, Costs = { 2, 3, 4 }, PerLevel = 0.1, Percent = true, Text = "{v} % Chance auf ein Extra-Token bei jeder Aufgabe" },
		{ Id = "DailyLuck", Branch = "Glueck", Hex = { -1, -2 }, Name = "Frühaufsteher", Icon = "🌅", Max = 3, Costs = { 2, 3, 4 }, PerLevel = 0.5, Percent = true, Text = "Der Tagesbonus ist +{v} % größer" },
		{ Id = "MythicLuck", Branch = "Glueck", Hex = { -2, -1 }, Name = "Glückspilz", Icon = "🍄", Max = 1, Costs = { 8 }, PerLevel = 1, Percent = true, Text = "Mythisch: +{v} % wahrscheinlicher" },
		{ Id = "Heritage", Branch = "Glueck", Hex = { -3, 0 }, Name = "Erbstück", Icon = "🧳", Max = 2, Costs = { 3, 5 }, PerLevel = 1, Text = "Bei der Wiedergeburt bleiben {v} Kreatur(en) mehr, die Stein-Burg gibt es dann gleich dazu" },
		{ Id = "StartMoney", Branch = "Glueck", Hex = { -3, 1 }, Name = "Startkapital", Icon = "💼", Max = 3, Costs = { 2, 3, 4 }, PerLevel = 5, Percent = true, Text = "+{v} % Startgeld nach der Wiedergeburt" },
		{ Id = "UpgradeDiscount", Branch = "Glueck", Hex = { -3, 2 }, Name = "Baumeister", Icon = "🔨", Max = 3, Costs = { 2, 3, 4 }, PerLevel = 0.05, Percent = true, Text = "Der Base-Ausbau kostet {v} % weniger" },
		-- Dieb & Schutz
		{ Id = "CarrySpeed", Branch = "Dieb", Hex = { -1, 1 }, Name = "Schnelle Beine", Icon = "👟", Max = 5, Costs = { 1, 1, 2, 2, 3 }, PerLevel = 0.6, Text = "+{v} Tempo, wenn du Beute trägst" },
		{ Id = "LockTime", Branch = "Dieb", Hex = { 0, 1 }, Name = "Dickes Schloss", Icon = "🔒", Max = 5, Costs = { 1, 1, 2, 2, 3 }, PerLevel = 0.15, Percent = true, Text = "Schloss hält +{v} % länger" },
		{ Id = "HitRange", Branch = "Dieb", Hex = { -2, 2 }, Name = "Lange Klatsche", Icon = "🏏", Max = 3, Costs = { 2, 3, 4 }, PerLevel = 1.5, Text = "Klatsche reicht +{v} Studs weiter" },
		{ Id = "LockCooldown", Branch = "Dieb", Hex = { -1, 2 }, Name = "Schnelles Schloss", Icon = "⏰", Max = 5, Costs = { 1, 1, 2, 2, 3 }, PerLevel = 8, Text = "Schloss ist {v} Sekunden früher wieder bereit" },
		{ Id = "LootBonus", Branch = "Dieb", Hex = { 0, 2 }, Name = "Beute-Bonus", Icon = "💎", Max = 3, Costs = { 2, 3, 4 }, PerLevel = 30, Text = "Geklaut: sofort {v} Sekunden Einkommen der Beute" },
		{ Id = "Comfort", Branch = "Dieb", Hex = { 1, 1 }, Name = "Trostpflaster", Icon = "💝", Max = 3, Costs = { 2, 3, 4 }, PerLevel = 0.25, Percent = true, Text = "Wirst du beklaut: {v} % vom Wert als Geld" },
		{ Id = "ThiefSlow", Branch = "Dieb", Hex = { -3, 3 }, Name = "Klebefalle", Icon = "🕸️", Max = 3, Costs = { 2, 3, 4 }, PerLevel = 0.08, Percent = true, Text = "Wer dich beklaut, trägt {v} % langsamer" },
		{ Id = "StunTime", Branch = "Dieb", Hex = { -2, 3 }, Name = "Dicker Brummer", Icon = "💫", Max = 3, Costs = { 2, 3, 4 }, PerLevel = 0.5, Text = "Getroffene Diebe stehen {v} Sekunden länger still" },
		{ Id = "Vault", Branch = "Dieb", Hex = { -1, 3 }, Name = "Tresor", Icon = "🏦", Max = 1, Costs = { 8 }, PerLevel = 1, Text = "Deine beste Kreatur kann niemand klauen" },
		{ Id = "HitCooldown", Branch = "Dieb", Hex = { 0, 3 }, Name = "Flinke Klatsche", Icon = "⚡", Max = 3, Costs = { 2, 3, 4 }, PerLevel = 0.1, Percent = true, Text = "Die Klatsche ist {v} % schneller wieder bereit" },
		{ Id = "PortalShield", Branch = "Dieb", Hex = { 1, 2 }, Name = "Portal-Schutz", Icon = "🛡️", Max = 3, Costs = { 2, 3, 4 }, PerLevel = 2, Text = "Nach dem Portal {v} Sekunden länger geschützt" },
		{ Id = "WalkSpeed", Branch = "Dieb", Hex = { 2, 1 }, Name = "Flitzer", Icon = "💨", Max = 4, Costs = { 2, 2, 3, 4 }, PerLevel = 0.5, Text = "+{v} Lauftempo, immer" },
	},
}
Config.SkillById = {}
for _, skill in Config.Skills.List do
	Config.SkillById[skill.Id] = skill
end

-- Wirkung einer Fähigkeit: skills = { Income = 2, ... } (Stufen), gibt Stufe x PerLevel zurück
function Config.SkillValue(skills, id: string): number
	local skill = Config.SkillById[id]
	local level = skills and skills[id] or 0
	return if skill then level * skill.PerLevel else 0
end

-- Beschreibung für eine Stufe, z.B. "+15 % Einkommen"
function Config.SkillText(skill, level: number): string
	local value = skill.PerLevel * level
	if skill.Percent then
		value *= 100
	end
	local shown = if math.abs(value - math.floor(value + 0.5)) < 0.001 then tostring(math.floor(value + 0.5)) else string.format("%.1f", value)
	shown = string.gsub(shown, "%.", ",") -- deutsches Komma: "0,5 Sekunden"
	return (string.gsub(skill.Text, "{v}", shown))
end

-- Grenzt Wabe a an Wabe b? (Sechseck-Netz, 6 Nachbarn)
function Config.HexAdjacent(a, b): boolean
	local dq, dr = a[1] - b[1], a[2] - b[2]
	return (dq == 1 and dr == 0)
		or (dq == -1 and dr == 0)
		or (dq == 0 and dr == 1)
		or (dq == 0 and dr == -1)
		or (dq == 1 and dr == -1)
		or (dq == -1 and dr == 1)
end

-- Darf man die Fähigkeit lernen? Sie muss an die Mitte oder an eine gelernte Wabe grenzen.
function Config.SkillReachable(skills, skill): boolean
	if Config.HexAdjacent(skill.Hex, { 0, 0 }) then
		return true
	end
	for _, other in Config.Skills.List do
		if other ~= skill and (skills and skills[other.Id] or 0) > 0 and Config.HexAdjacent(skill.Hex, other.Hex) then
			return true
		end
	end
	return false
end

-- Nach so vielen Kisten ohne Legendär+ gibt es die Garantie (Fähigkeit "Garantie" zieht ab)
function Config.PityFor(skills): number
	return math.max(5, Config.PityThreshold - Config.SkillValue(skills, "Pity"))
end

-- Mutations-Chancen mit der Fähigkeit "Mutations-Gespür"
function Config.MutationWeightsFor(skills, base)
	local bonus = 1 + Config.SkillValue(skills, "Mutation")
	local weights = {}
	for id, w in base or Config.MutationWeights do
		weights[id] = if id == "Normal" then w else w * bonus
	end
	return weights
end

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
		Price = 200_000,
		Rebirths = 1,
		Color = Color3.fromRGB(180, 100, 255),
		Weights = { Common = 48, Uncommon = 30, Rare = 15, Epic = 6, Legendary = 1, Mythic = 0.3 },
	},
	{
		Id = "Lava",
		Name = "Lava-Kiste",
		Price = 5_000_000,
		Rebirths = 2,
		Color = Color3.fromRGB(255, 95, 35),
		Weights = { Common = 48, Uncommon = 30, Rare = 15, Epic = 6, Legendary = 1, Mythic = 0.3 },
	},
	{
		Id = "Eis",
		Name = "Eis-Kiste",
		Price = 100_000_000,
		Rebirths = 3,
		Color = Color3.fromRGB(130, 215, 255),
		Weights = { Common = 48, Uncommon = 30, Rare = 15, Epic = 6, Legendary = 1, Mythic = 0.3 },
	},
	{
		Id = "Galaxie",
		Name = "Galaxie-Kiste",
		Price = 2_000_000_000,
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

-- Glück (Skill-Baum) macht Selten und besser wahrscheinlicher, "Glückspilz" dazu Mythisch.
-- Seltenheiten, für die die Kiste keine Kreatur hat, fallen raus.
-- skills = { Luck = 2, ... } (Stufen des Spielers) oder nil
function Config.PackWeights(pack, skills)
	local bonus = 1 + Config.SkillValue(skills, "Luck")
	local mythicBonus = 1 + Config.SkillValue(skills, "MythicLuck")
	local has = {}
	for _, creature in pack.Creatures do
		has[creature.Rarity] = true
	end
	local weights = {}
	for rarity, w in pack.Weights do
		if has[rarity] then
			local weight = if Config.RarityRank(rarity) >= Config.RarityRank("Rare") then w * bonus else w
			if rarity == "Mythic" then
				weight *= mythicBonus
			end
			weights[rarity] = weight
		end
	end
	return weights
end

-- Welten ---------------------------------------------------------------------
-- Vier eigene Inseln, erreichbar durch die Portale hinter dem Kisten-Shop.
-- Jede Welt gehört zu einer Kiste und geht mit derselben Wiedergeburt auf.
-- Dort bringt jeder Klick mehr Geld, und immer wieder taucht ein wildes Monster aus der
-- Kiste dieser Welt auf: schnappen und zu Fuß nach Hause tragen (wie beim Meteor).
Config.Worlds = {
	ArrivalShield = 6, -- so viele Sekunden kann einen niemand hauen, wenn man mit Beute aus einer Welt kommt
	PortalCooldown = 2.5, -- Pause zwischen zwei Reisen
	HomeCooldown = 5, -- Pause für die Knöpfe "Heim" und "Welten"
	Wild = {
		Interval = 150, -- so viele Sekunden nach dem Schnappen kommt das nächste wilde Monster
		FirstAfter = 20, -- das erste kommt kurz nach dem Start
		Lifetime = 600, -- so lange wartet es, danach kommt ein neues an anderer Stelle
		Weights = { Uncommon = 45, Rare = 35, Epic = 15, Legendary = 4.5, Mythic = 0.5 },
		MutationWeights = { Normal = 80, Gold = 13, Diamant = 5.5, Regenbogen = 1.5 },
		AnnounceFrom = "Epic", -- ab dieser Seltenheit erfährt es der ganze Server
	},
	-- ClickFactor: ein Klick bringt dort so viel mehr Geld als auf der Hauptinsel
	-- Tint: Farbstich des Bildes in der Welt, Clock: Uhrzeit dort (0 = Nacht, weglassen = wie draußen)
	-- Sky: Dunst und Horizont dort (Color = hell, Decay = dunkel; Density, Offset, Haze = wie dicht)
	-- Ambient: Farbe des Schattenlichts dort (weglassen = wie draußen)
	-- Bloom: wie stark Neon-Teile dort strahlen (Intensity kleiner = weniger, Threshold größer = weniger)
	List = {
		{
			Id = "Kristall",
			Name = "Kristall-Tal",
			Icon = "💎",
			Pack = "Kristall",
			Rebirths = 1,
			ClickFactor = 1.5,
			Color = Color3.fromRGB(190, 110, 255),
			Tint = Color3.fromRGB(242, 230, 255),
			Sky = { Color = Color3.fromRGB(235, 205, 255), Decay = Color3.fromRGB(160, 120, 230) },
		},
		{
			Id = "Lava",
			Name = "Lava-Krater",
			Icon = "🌋",
			Pack = "Lava",
			Rebirths = 2,
			ClickFactor = 2,
			Color = Color3.fromRGB(255, 110, 35),
			Tint = Color3.fromRGB(255, 232, 214),
			Sky = { Color = Color3.fromRGB(255, 170, 120), Decay = Color3.fromRGB(150, 60, 40), Density = 0.32, Offset = 0.2, Haze = 1.4 },
			Ambient = Color3.fromRGB(195, 150, 130), -- warmes Schattenlicht, sonst wirkt der Boden grünlich
			Clock = 17.85, -- Abendrot
		},
		{
			Id = "Eis",
			Name = "Eis-Gipfel",
			Icon = "❄️",
			Pack = "Eis",
			Rebirths = 3,
			ClickFactor = 2.5,
			Color = Color3.fromRGB(120, 215, 255),
			Tint = Color3.fromRGB(228, 240, 255),
			Sky = { Color = Color3.fromRGB(225, 238, 255), Decay = Color3.fromRGB(170, 200, 240) },
		},
		{
			Id = "Galaxie",
			Name = "Sternen-Insel",
			Icon = "🌌",
			Pack = "Galaxie",
			Rebirths = 4,
			ClickFactor = 3,
			Color = Color3.fromRGB(110, 120, 255),
			Tint = Color3.fromRGB(224, 218, 255),
			Sky = { Color = Color3.fromRGB(120, 110, 210), Decay = Color3.fromRGB(40, 30, 90) },
			Bloom = { Intensity = 0.2, Threshold = 1.9 }, -- nachts überstrahlen die Leuchtbäume sonst zu weißen Flecken
			Clock = 0,
		},
	},
}
Config.WorldById = {}
for index, world in Config.Worlds.List do
	world.Index = index
	Config.WorldById[world.Id] = world
end
function Config.WorldUnlocked(world, rebirths: number?): boolean
	return (rebirths or 0) >= world.Rebirths
end
-- Welche Welt geht genau mit dieser Zahl an Wiedergeburten auf?
function Config.WorldAtRebirth(rebirths: number)
	for _, world in Config.Worlds.List do
		if world.Rebirths == rebirths then
			return world
		end
	end
	return nil
end

-- Selbst Geld machen: der Klicker ---------------------------------------------------
-- Überall in die Welt klicken (oder tippen) gibt sofort Geld, zusätzlich zum Einkommen
-- der Kreaturen. Schnell hintereinander klicken baut eine Combo auf.
Config.Click = {
	IncomeSeconds = 0.08, -- ein Klick = so viele Sekunden von DEINEM Einkommen
	MinValue = 1, -- aber mindestens so viel
	MaxPerSecond = 12, -- mehr Klicks pro Sekunde zählt der Server nicht (gegen Auto-Klick-Programme)
	CritChance = 0.03, -- Chance auf einen Volltreffer (Fähigkeit "Volltreffer" erhöht sie)
	CritFactor = 5, -- ein Volltreffer bringt so viel mal mehr (Fähigkeit "Wumms" erhöht es)
	JackpotFactor = 50, -- der Jackpot (nur mit der Fähigkeit) bringt so viel mal mehr
	Combo = {
		Timeout = 1.5, -- so viele Sekunden ohne Klick, dann ist die Combo weg
		ShowFrom = 5, -- ab so vielen Klicks am Stück sieht man die Combo-Anzeige
		-- { ab so vielen Klicks am Stück, Geld mal so viel, Name }
		Steps = {
			{ 10, 1.2, "WARM" },
			{ 30, 1.5, "HEISS" },
			{ 60, 2, "FEUER" },
			{ 120, 3, "INFERNO" },
		},
	},
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
		Clicks = { Text = "Klicke {n}x für Geld", Min = 200, Max = 500, Factor = 0.8 },
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
-- Dafür: dauerhaft mehr Einkommen und Tokens für den Skill-Baum.
Config.Rebirth = {
	-- Kosten der 1., 2., 3. ... Wiedergeburt. Faustregel: etwa 20 Kisten der besten Sorte,
	-- die man gerade kaufen darf. Jede der ersten vier schaltet eine neue Kiste frei.
	Costs = { 150_000, 4_000_000, 100_000_000, 2_000_000_000, 40_000_000_000 },
	CostGrowth = 5, -- danach kostet jede weitere 5x so viel
	IncomePerRebirth = 0.5, -- +50 % Einkommen pro Wiedergeburt
	KeepCreatures = 4, -- so viele der besten Kreaturen bleiben
	TokensPerRebirth = 3, -- Tokens für den Skill-Baum
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
	-- Wie oft welches Event kommt (größere Zahl = öfter)
	Weights = { Meteor = 35, Goldrausch = 25, Diebesnacht = 20, Klickfieber = 20 },

	Meteor = {
		Duration = 90, -- so lange liegt die Kreatur herum, bis sie verschwindet
		GrabTime = 1.5,
		-- Die Kreatur kommt aus der besten Kiste, die ALLE Spieler auf dem Server schon
		-- kaufen dürfen (sonst bekämen Neue sofort Monster vom Ende des Spiels).
		Weights = { Epic = 55, Legendary = 37, Mythic = 8 },
		-- Mutationen beim Meteor sind wahrscheinlicher
		MutationWeights = { Normal = 55, Gold = 25, Diamant = 14, Regenbogen = 6 },
		TargetRadius = 12, -- so groß ist der rote Zielkreis, der den Einschlag ankündigt
		ShakeRange = 260, -- bis zu dieser Entfernung wackelt beim Einschlag die Kamera
		ArrowHide = 22, -- so nah dran verschwindet der Wegweiser-Pfeil
	},
	Goldrausch = {
		Duration = 60,
		IncomeMultiplier = 2, -- gilt für das Einkommen UND für jeden Klick
	},
	Diebesnacht = {
		Duration = 60,
		WalkSpeed = 22, -- alle laufen schneller
		CarrySpeed = 18, -- auch mit Beute
		-- Schatten-Diebe: schleichen zu jeder Base, schnappen sich ein Monster und hauen damit ab.
		-- Mit der Klatsche verjagen gibt eine Belohnung. Entkommt einer, ist das Monster bis zum
		-- Morgen weg (es kommt am Ende der Nacht von allein zurück).
		Shadows = {
			First = 5, -- der erste kommt nach so vielen Sekunden
			Interval = 13, -- danach alle X Sekunden einer pro Base
			MaxPerBase = 2, -- mehr sind nie gleichzeitig an einer Base
			StopBefore = 14, -- so viele Sekunden vor dem Morgen kommt keiner mehr
			Speed = 11, -- Tempo auf dem Weg zur Base (Spieler laufen 16)
			GrabTime = 2.5, -- so lange braucht er am Monster, bis er es hat
			FleeSpeed = 8, -- Tempo mit Beute
			RewardSeconds = 20, -- Belohnung fürs Verjagen = so viele Sekunden Einkommen
			RewardMin = 50, -- aber mindestens so viel
			TokenChance = 0.15, -- Chance auf ein Token pro verjagtem Schatten
		},
	},
	Klickfieber = {
		Duration = 60,
		ComboSpeed = 2, -- jeder Klick zählt so oft für die Combo (und sie reißt nicht ab)
		CritFactor = 3, -- Volltreffer-Chance mal so viel
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
	-- Verschmelzen: Zischen beim Zusammenfliegen, dann der Schlag, wenn die neue Kreatur erscheint
	Merge = { { "ZoomUp", 1, 0.9, 0 }, { "Anvil", 1.2, 1.1, 0.38 }, { "Bell", 1.5, 0.9, 0.38, 1.4 } },
	MergeBig = { { "ZoomUp", 0.9, 1, 0 }, { "Smash", 1, 0.6, 0.38, 1.8 }, { "StingWin", 1, 0.8, 0.42 } }, -- ab 3 Sternen
	ClickTick = { { "Click", 1.5, 0.22, 0 }, { "Ping", 2.4, 0.1, 0 } }, -- jeder Klick (wird mit der Combo höher)
	Crit = { { "Punch", 1.4, 0.5, 0, 0.6 }, { "Ping", 2, 0.4, 0.03 }, { "Ping", 2.6, 0.3, 0.09 } }, -- Volltreffer
	ComboUp = { { "MetalRing", 1, 0.5, 0, 0.7 }, { "Ping", 1.5, 0.4, 0.05 } }, -- nächste Combo-Stufe (wird höher)
	Travel = { { "ZoomUp", 1.2, 0.8, 0 }, { "Bell", 2, 0.5, 0.25, 1 } }, -- durchs Portal
	Skill = { { "MetalRing", 1.3, 0.6, 0, 0.9 }, { "Ping", 1.5, 0.5, 0.05 }, { "Ping", 2, 0.5, 0.14 } }, -- Fähigkeit gelernt
	Stolen = { { "Oof", 0.85, 0.8, 0 }, { "Swoosh", 0.5, 0.6, 0 }, { "Ping", 0.5, 0.5, 0.15 } },
	Hit = { { "Swoosh", 1.6, 0.7, 0 }, { "Ping", 0.6, 0.6, 0.03 } },
	-- Events
	MeteorImpact = { { "Punch", 0.8, 1, 0, 1.6 }, { "Boom", 1, 0.9, 0, 1.4 }, { "Thud", 0.7, 0.8, 0 } }, -- Einschlag
	GoldStart = { { "Bell", 1.5, 0.8, 0, 1.2 }, { "Ping", 1.5, 0.5, 0.05 }, { "Ping", 2, 0.5, 0.15 }, { "Ping", 3, 0.6, 0.25 } }, -- Goldrausch geht los
	NightStart = { { "StingSmall", 0.8, 0.7, 0, 2.2 }, { "Swoosh", 0.5, 0.6, 0 } }, -- Diebes-Nacht geht los
	ShadowNear = { { "Swoosh", 0.45, 0.7, 0 }, { "Ping", 0.4, 0.5, 0.1 } }, -- ein Schatten-Dieb ist an deiner Base
	FeverStart = { { "Riser", 1.4, 0.5, 0, 1.4 }, { "StingStabs", 1.2, 0.7, 0.2, 1.6 } }, -- Klick-Fieber geht los
	EventEnd = { { "Bell", 1, 0.7, 0, 1.2 }, { "Ping", 1.5, 0.5, 0.05 }, { "Ping", 2, 0.5, 0.15 } }, -- Bilanz am Ende
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

-- Kreaturen-Einträge im Spielstand: "Blubbo", "Blubbo|Gold", mit Sternen "Blubbo|Gold|2"
-- oder ohne Mutation "Blubbo||2". Gibt (Kreatur, Mutation, Sterne) zurück.
function Config.ParseEntry(entry: string)
	local parts = string.split(entry, "|")
	local def = Config.CreatureById[parts[1]]
	local mutation = parts[2]
	if mutation == nil or mutation == "" or not Config.Mutations[mutation] then
		mutation = "Normal"
	end
	local stars = math.clamp(math.floor(tonumber(parts[3]) or 0), 0, Config.Stars.Max)
	return def, mutation, stars
end

function Config.MakeEntry(id: string, mutation: string?, stars: number?): string
	local m = if mutation and mutation ~= "Normal" then mutation else ""
	if stars and stars > 0 then
		return `{id}|{m}|{stars}`
	end
	if m ~= "" then
		return id .. "|" .. m
	end
	return id
end

function Config.EntryIncome(entry: string): number
	local def, mutation, stars = Config.ParseEntry(entry)
	return if def then def.Income * Config.Mutations[mutation].Multiplier * Config.StarMultiplier(stars) else 0
end

-- Wert: mit Sternen so viel wie alle Kreaturen zusammen, die darin stecken
function Config.EntryValue(entry: string): number
	local def, mutation, stars = Config.ParseEntry(entry)
	return if def then def.Price * Config.Mutations[mutation].Multiplier * Config.Stars.Need ^ stars else 0
end

function Config.StarText(stars: number?): string
	return if stars and stars > 0 then string.rep("★", stars) else ""
end

function Config.EntryName(entry: string): string
	local def, mutation, stars = Config.ParseEntry(entry)
	if not def then
		return "?"
	end
	local m = Config.Mutations[mutation]
	local name = if m.Name ~= "" then `{m.Name}-{def.Name}` else def.Name
	return if stars > 0 then `{name} {Config.StarText(stars)}` else name
end

-- Was kommt beim Verschmelzen heraus? nil, wenn die Kreatur schon alle Sterne hat.
function Config.MergeResult(entry: string, extraStars: number?): string?
	local def, mutation, stars = Config.ParseEntry(entry)
	if not def or stars >= Config.Stars.Max then
		return nil
	end
	return Config.MakeEntry(def.Id, mutation, math.min(Config.Stars.Max, stars + 1 + (extraStars or 0)))
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

-- Wie FormatNumber, aber kleine krumme Werte mit einer Nachkommastelle (für "+3.2 $/s")
function Config.FormatRate(n: number): string
	if n < 100 and math.abs(n - math.floor(n + 0.5)) > 0.04 then
		return string.format("%.1f", n)
	end
	return Config.FormatNumber(n + 0.04)
end

-- GROSSBUCHSTABEN, auch für ä, ö, ü (string.upper lässt die klein)
function Config.Upper(text: string): string
	return (string.upper(text):gsub("ä", "Ä"):gsub("ö", "Ö"):gsub("ü", "Ü"))
end

return Config
