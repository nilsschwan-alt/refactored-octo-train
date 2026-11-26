-- ALLE Spielwerte an einem Ort. Hier kannst du balancen, ohne die Logik anzufassen.
-- Liegt in Studio unter: ReplicatedStorage > Shared > Config

local Config = {}

Config.GameName = "Kreaturen-Klau"
Config.Version = "0.2.0"

-- Geld & Speichern ---------------------------------------------------------
Config.StartMoney = 100
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
Config.Map = {
	BaseCount = 8, -- passt zu 8 Spielern pro Server
	BaseRadius = 120, -- Abstand der Bases von der Mitte
	BaseSize = 56, -- Kantenlänge einer Base
	ShopRadius = 30, -- Größe des Platzes in der Mitte
	ShopUseDistance = 45, -- so nah an der Mitte muss man zum Kaufen sein
}

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
