-- Laden und Speichern der Spielstände (Geld, Base-Stufe, Kreaturen) per DataStore.
-- Wenn der DataStore nicht erreichbar ist (z. B. in Studio ohne API-Zugriff),
-- spielt man mit einem frischen Stand, und es wird NICHTS gespeichert,
-- damit kein echter Spielstand überschrieben wird.

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Data = {}

local store = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DataStoreName)
	end)
	if ok then
		store = result
	else
		warn("[Data] DataStore nicht verfügbar, es wird nicht gespeichert:", result)
	end
end

local function key(userId: number): string
	return "Spieler_" .. userId
end

function Data.Default()
	return {
		Money = Config.StartMoney,
		BaseLevel = 1,
		Slots = {}, -- ["1"] = "Blubbo", ["2"] = "Funkelfuchs|Gold", mit Sternen "Blubbo||2"
		Bag = {}, -- Inventar: alle Kreaturen, die nicht in der Base stehen, z.B. { Blubbo = 3, ["Blubbo|Gold"] = 1 }
		Feed = {}, -- Futter, das beim Verbessern übrig blieb, pro Art, z.B. { Blubbo = 1 }
		Cash = 0, -- alt: frühere Kasse. Reste werden beim Join aufs Konto gebucht
		Pity = 0, -- Packs seit dem letzten Legendär+
		LastDaily = 0, -- Tag (seit 1970) des letzten Tagesbonus
		Rebirths = 0, -- Wiedergeburten
		Tokens = 0, -- für den Skill-Baum
		Skills = {}, -- { Income = 2, Luck = 1, ... } gelernte Stufen im Skill-Baum
		QuestCount = 0, -- geschaffte Aufgaben (jede x-te gibt Tokens)
		Stats = {}, -- Zähler für die Erfolge, z.B. { OpenPacks = 12, Clicks = 340 }
		Achieved = {}, -- erreichte Stufe pro Erfolg, z.B. { Packs = 2 }
		TotalEarned = 0, -- insgesamt verdient (für die Bestenliste)
		Quests = {}, -- { { Kind = "Clicks", Goal = 20, Progress = 3, Reward = 500 }, ... }
	}
end

-- Ganz neuer Spieler: Startgeld + eine Gratis-Kreatur
function Data.NewPlayer()
	local data = Data.Default()
	if Config.CreatureById[Config.StarterCreature] then
		data.Slots["1"] = Config.StarterCreature
	end
	return data
end

-- Prüft geladene Daten und repariert Unsinn (falsche Typen, gelöschte Kreaturen ...)
local function sanitize(raw)
	local data = Data.Default()
	if type(raw) ~= "table" then
		return data
	end
	if type(raw.Money) == "number" and raw.Money == raw.Money then
		data.Money = math.max(0, raw.Money)
	end
	if type(raw.BaseLevel) == "number" then
		data.BaseLevel = math.clamp(math.floor(raw.BaseLevel), 1, #Config.BaseLevels)
	end
	for _, field in { "Cash", "Pity", "LastDaily", "Rebirths", "Tokens", "TotalEarned", "QuestCount" } do
		if type(raw[field]) == "number" and raw[field] == raw[field] then
			data[field] = math.max(0, raw[field])
		end
	end
	data.Rebirths = math.floor(data.Rebirths)
	data.Tokens = math.floor(data.Tokens)
	data.QuestCount = math.floor(data.QuestCount)
	if type(raw.Stats) == "table" then
		for kind, value in raw.Stats do
			if type(kind) == "string" and #kind <= 30 and type(value) == "number" and value == value and value > 0 then
				data.Stats[kind] = value
			end
		end
	end
	if type(raw.Achieved) == "table" then
		for _, achievement in Config.Achievements do
			local tier = raw.Achieved[achievement.Id]
			if type(tier) == "number" and tier == tier then
				data.Achieved[achievement.Id] = math.clamp(math.floor(tier), 0, #achievement.Goals)
			end
		end
	end
	-- Alte Spielstände hatten "Upgrades" (Glück, Münz-Magnet, Klick-Kraft): Die Stufen
	-- gelten im Skill-Baum weiter.
	local rawSkills = if type(raw.Skills) == "table" then raw.Skills elseif type(raw.Upgrades) == "table" then raw.Upgrades else nil
	if rawSkills then
		for _, skill in Config.Skills.List do
			local level = rawSkills[skill.Id]
			if type(level) == "number" and level == level then
				data.Skills[skill.Id] = math.clamp(math.floor(level), 0, skill.Max)
			end
		end
		-- Die Münzen gibt es nicht mehr: Wer Münz-Fähigkeiten hatte, behält die Stufen
		-- als die Klick-Fähigkeit, die jetzt auf derselben Wabe sitzt.
		for old, new in { Magnet = "AutoClick", CoinValue = "Crit", BigCoins = "CritPower" } do
			local level = rawSkills[old]
			if type(level) == "number" and level == level and data.Skills[new] == nil then
				data.Skills[new] = math.clamp(math.floor(level), 0, Config.SkillById[new].Max)
			end
		end
	end
	if type(raw.Quests) == "table" then
		for _, q in raw.Quests do
			if
				type(q) == "table"
				and Config.Quests.Types[q.Kind]
				and type(q.Goal) == "number"
				and type(q.Progress) == "number"
				and type(q.Reward) == "number"
				and #data.Quests < Config.Quests.Active
			then
				table.insert(data.Quests, { Kind = q.Kind, Goal = math.max(1, q.Goal), Progress = math.max(0, q.Progress), Reward = math.max(0, q.Reward) })
			end
		end
	end
	local maxSlots = Config.BaseLevels[data.BaseLevel].Slots
	if type(raw.Slots) == "table" then
		for slotKey, creatureId in raw.Slots do
			local slot = tonumber(slotKey)
			if slot and slot >= 1 and slot <= maxSlots and type(creatureId) == "string" and Config.ParseEntry(creatureId) then
				data.Slots[tostring(slot)] = creatureId
			end
		end
	end
	-- Inventar (früher hieß es Lager: Stock). Mehr als hineinpasst, wird nicht geladen.
	local bagLeft = Config.Inventory.Size
	for _, source in { raw.Bag, raw.Stock } do
		if type(source) == "table" then
			for entry, amount in source do
				if bagLeft > 0 and type(entry) == "string" and type(amount) == "number" and amount == amount and amount >= 1 then
					local def, mutation, stars = Config.ParseEntry(entry)
					if def then
						local clean = Config.MakeEntry(def.Id, mutation, stars)
						local count = math.min(math.floor(amount), bagLeft)
						data.Bag[clean] = (data.Bag[clean] or 0) + count
						bagLeft -= count
					end
				end
			end
		end
	end
	if type(raw.Feed) == "table" then
		for id, amount in raw.Feed do
			if type(id) == "string" and Config.CreatureById[id] and type(amount) == "number" and amount == amount and amount >= 1 then
				data.Feed[id] = math.min(math.floor(amount), 999)
			end
		end
	end
	return data
end

-- Gibt (daten, darfSpeichern) zurück
function Data.Load(userId: number)
	if not store then
		return Data.NewPlayer(), false
	end
	for attempt = 1, 3 do
		local ok, result = pcall(function()
			return store:GetAsync(key(userId))
		end)
		if ok then
			if result == nil then
				return Data.NewPlayer(), true
			end
			return sanitize(result), true
		end
		warn(`[Data] Laden fehlgeschlagen (Versuch {attempt}):`, result)
		if tostring(result):find("Studio") or tostring(result):find("API") then
			warn(
				"[Data] Tipp: In Studio unter Home > Game Settings > Security 'Enable Studio Access to API Services' einschalten (Spiel muss veröffentlicht sein)."
			)
			break
		end
		task.wait(2)
	end
	return Data.NewPlayer(), false
end

function Data.Save(userId: number, data): boolean
	if not store then
		return false
	end
	local copy = {
		Money = math.floor(data.Money),
		BaseLevel = data.BaseLevel,
		Slots = table.clone(data.Slots),
		Bag = table.clone(data.Bag),
		Feed = table.clone(data.Feed),
		Cash = math.floor(data.Cash),
		Pity = data.Pity,
		LastDaily = data.LastDaily,
		Rebirths = data.Rebirths,
		Tokens = data.Tokens,
		Skills = table.clone(data.Skills),
		QuestCount = data.QuestCount,
		Stats = table.clone(data.Stats),
		Achieved = table.clone(data.Achieved),
		TotalEarned = math.floor(data.TotalEarned),
		Quests = {},
	}
	for _, q in data.Quests do
		table.insert(copy.Quests, { Kind = q.Kind, Goal = q.Goal, Progress = math.floor(q.Progress), Reward = math.floor(q.Reward) })
	end
	for attempt = 1, 3 do
		local ok, err = pcall(function()
			store:SetAsync(key(userId), copy, { userId })
		end)
		if ok then
			return true
		end
		warn(`[Data] Speichern fehlgeschlagen (Versuch {attempt}):`, err)
		task.wait(2)
	end
	return false
end

return Data
