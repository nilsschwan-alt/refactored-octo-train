-- Kisten (Packs): Mit Ingame-Geld eine Kiste kaufen (von überall über den Shop-Knopf), eine zufällige Kreatur kommt raus.
-- 1x, 3x oder 10x auf einmal. Jede Kiste hat ihre eigenen Kreaturen, teurere Kisten haben viel stärkere.
-- Neue Kisten werden mit Wiedergeburten freigeschaltet (pack.Rebirths).
-- Pity: nach X Kisten ohne Legendär+ ist die nächste garantiert Legendär+.
-- Die Chancen stehen in Config.Packs und werden im Shop angezeigt.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Bases = require(script.Parent.Bases)

local Packs = {}

local remotes
local packById = Config.PackById

local LEGENDARY = Config.RarityRank("Legendary")

function Packs.Init(remoteFolder)
	remotes = remoteFolder
end

-- Eine Kreatur würfeln (mit Pity und Glück). Gibt (eintrag, warPity) zurück.
local function roll(state, pack)
	local skills = state.Data.Skills
	local weights = Config.PackWeights(pack, skills)
	local pity = state.Data.Pity + 1 >= Config.PityFor(skills)
	if pity then
		local filtered = {}
		local total = 0
		for rarity, w in weights do
			if Config.RarityRank(rarity) >= LEGENDARY then
				filtered[rarity] = w
				total += w
			end
		end
		weights = if total > 0 then filtered else { Legendary = 1 }
	end
	local rarity = Config.RollWeighted(weights)
	local def = Config.RandomCreatureOfRarity(rarity, pack)
	local mutation = Config.RollWeighted(Config.MutationWeightsFor(skills))
	if Config.RarityRank(rarity) >= LEGENDARY then
		state.Data.Pity = 0
	else
		state.Data.Pity += 1
	end
	return Config.MakeEntry(def.Id, mutation), pity
end

-- Schlechteste Kreatur in der Base (die gerade nicht geklaut wird)
local function worstSlot(state): (number?, number)
	local worst, worstIncome = nil, math.huge
	for slotKey, entry in state.Data.Slots do
		local slot = tonumber(slotKey)
		if slot and not state.Plot.Stolen[slot] then
			local income = Config.EntryIncome(entry)
			if income < worstIncome then
				worst, worstIncome = slot, income
			end
		end
	end
	return worst, worstIncome
end

-- count = 1, 3 oder 10. Ist die Base voll, bleiben die besten Kreaturen, der Rest wird verkauft.
function Packs.Buy(player: Player, packId: string, count: number?)
	local state = Bases.GetState(player)
	local pack = packById[packId]
	count = count or 1
	if not state or not pack then
		return
	end
	if not Config.PackUnlocked(pack, state.Data.Rebirths) then
		Bases.Notify(player, `Die {pack.Name} gibt es erst ab Wiedergeburt {pack.Rebirths}.`, Color3.fromRGB(255, 90, 90))
		return
	end
	local cost = Config.PackCost(pack, count)
	if cost == math.huge then
		return
	end
	if state.Data.Money < cost then
		Bases.Notify(player, "Nicht genug Geld!", Color3.fromRGB(255, 90, 90))
		return
	end
	Bases.AddMoney(state, -cost)

	-- Fähigkeit "Gratis-Kiste": jede Kiste hat eine kleine Chance, nichts zu kosten
	local freeChance = Bases.Skill(state, "Refund")
	local freeCount = 0
	if freeChance > 0 then
		for _ = 1, count do
			if math.random() < freeChance then
				freeCount += 1
			end
		end
	end
	local refund = math.floor(cost / count * freeCount)

	local entries, pities = {}, {}
	local soldCount, soldMoney = 0, 0
	local merged = {} -- Namen der Kreaturen, die bei voller Base automatisch verschmolzen wurden
	for i = 1, count do
		local entry, pity = roll(state, pack)
		entries[i] = entry
		pities[i] = pity
		if not Bases.FreeSlot(state) then
			-- Base voll. Stehen schon genug gleiche da? Dann verschmelzen statt verkaufen.
			local absorbed = Bases.TryAbsorb(state, entry)
			if absorbed then
				table.insert(merged, Config.EntryName(absorbed))
				continue
			end
			-- Sonst: ist die neue besser als die schlechteste? Dann tauschen.
			local slot, worstIncome = worstSlot(state)
			local sellEntry = entry
			if slot and Config.EntryIncome(entry) > worstIncome then
				sellEntry = state.Data.Slots[tostring(slot)]
				state.Data.Slots[tostring(slot)] = nil
				Bases.RenderSlot(state, slot)
			end
			local price = Bases.SellPrice(state, sellEntry)
			soldCount += 1
			soldMoney += price
			if sellEntry ~= entry then
				Bases.GiveCreature(state, entry)
			end
		else
			Bases.GiveCreature(state, entry)
		end
	end
	player:SetAttribute("Pity", state.Data.Pity)
	if soldMoney > 0 then
		Bases.AddMoney(state, soldMoney)
	end
	Bases.Track(state, "OpenPacks", count)

	remotes.PackResult:FireClient(player, entries, pack.Id, pities, soldCount, soldMoney)
	local showDelay = if count > 1 then 6 else 4 -- erst nach der Öffnungs-Animation
	if refund > 0 then
		Bases.AddMoney(state, refund, "quest")
		task.delay(showDelay, function()
			if player.Parent then
				Bases.BigText(player, `GRATIS-KISTE! +{Config.FormatNumber(refund)} $ zurück`, Color3.fromRGB(90, 220, 110), "Quest")
			end
		end)
	end
	if #merged > 0 then
		task.delay(showDelay + 0.5, function()
			Bases.Notify(player, `✨ Base voll: automatisch verschmolzen zu {table.concat(merged, ", ")}.`, Color3.fromRGB(255, 215, 70))
		end)
	end
	if soldCount > 0 then
		task.delay(if count > 1 then 6 else 4, function()
			Bases.Notify(
				player,
				`Base voll: {soldCount} schwächste Kreatur(en) automatisch für {Config.FormatNumber(soldMoney)} $ verkauft.`,
				Color3.fromRGB(255, 200, 90)
			)
		end)
	end
	-- Ansage erst nach der Öffnungs-Animation, damit nichts verraten wird
	task.delay(if count > 1 then 5 else 3.5, function()
		if player.Parent then
			for _, entry in entries do
				Bases.AnnounceIfRare(player, entry, "aus einer Kiste gezogen")
			end
		end
	end)
end

return Packs
