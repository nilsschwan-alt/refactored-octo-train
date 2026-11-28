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

-- Einkommen aller Kreaturen in der Base zusammen (ohne Boni, so wie es auf den Kreaturen steht)
function Packs.SlotIncome(state): number
	local total = 0
	for _, entry in state.Data.Slots do
		total += Config.EntryIncome(entry)
	end
	return total
end

-- count = 1, 3 oder 10. Ist die Base voll, stehen danach die besten dort, der Rest kommt ins Inventar.
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
	local incomeBefore = Packs.SlotIncome(state)
	local soldCount, soldMoney = 0, 0 -- wegen vollem Inventar verkauft
	local storedCount = 0 -- so viele Kreaturen kamen ins Inventar
	local lastText: string? = nil -- Meldung zur letzten Kreatur (für die einzelne Kiste)
	for i = 1, count do
		local entry, pity = roll(state, pack)
		entries[i] = entry
		pities[i] = pity
		local got = Bases.Receive(state, entry)
		lastText = Bases.ReceiveText(got, entry)
		if got.Kind ~= "placed" then
			storedCount += 1
		end
		if got.Sold then
			storedCount -= 1
			soldCount += 1
			soldMoney += got.Money
		end
	end
	player:SetAttribute("Pity", state.Data.Pity)
	Bases.Track(state, "OpenPacks", count)

	-- gain = so viel mehr verdienen die Kreaturen in der Base jetzt (für den Ergebnis-Bildschirm)
	local gain = math.max(0, Packs.SlotIncome(state) - incomeBefore)
	remotes.PackResult:FireClient(player, entries, pack.Id, pities, soldCount, soldMoney, storedCount, gain)
	local showDelay = if count > 1 then 6 else 4 -- erst nach der Öffnungs-Animation
	if refund > 0 then
		Bases.AddMoney(state, refund, "quest")
		task.delay(showDelay, function()
			if player.Parent then
				Bases.BigText(player, `GRATIS-KISTE! +{Config.FormatNumber(refund)} $ zurück`, Color3.fromRGB(90, 220, 110), "Quest")
			end
		end)
	end
	if count == 1 then
		-- bei mehreren Kisten steht das auf dem Ergebnis-Bildschirm
		if lastText then
			local text = lastText
			task.delay(showDelay, function()
				Bases.Notify(player, text, Color3.fromRGB(120, 200, 255))
			end)
		end
	elseif soldCount > 0 then
		task.delay(showDelay, function()
			Bases.Notify(
				player,
				`Inventar voll: {soldCount} schwächste Kreatur(en) für {Config.FormatNumber(soldMoney)} $ verkauft.`,
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
