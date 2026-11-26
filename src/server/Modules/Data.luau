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
		Slots = {}, -- ["1"] = "Blubbo", ["2"] = "Funkelfuchs", ...
	}
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
	local maxSlots = Config.BaseLevels[data.BaseLevel].Slots
	if type(raw.Slots) == "table" then
		for slotKey, creatureId in raw.Slots do
			local slot = tonumber(slotKey)
			if slot and slot >= 1 and slot <= maxSlots and Config.CreatureById[creatureId] then
				data.Slots[tostring(slot)] = creatureId
			end
		end
	end
	return data
end

-- Gibt (daten, darfSpeichern) zurück
function Data.Load(userId: number)
	if not store then
		return Data.Default(), false
	end
	for attempt = 1, 3 do
		local ok, result = pcall(function()
			return store:GetAsync(key(userId))
		end)
		if ok then
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
	return Data.Default(), false
end

function Data.Save(userId: number, data): boolean
	if not store then
		return false
	end
	local copy = {
		Money = math.floor(data.Money),
		BaseLevel = data.BaseLevel,
		Slots = table.clone(data.Slots),
	}
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
