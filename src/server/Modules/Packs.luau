-- Packs: Mit Ingame-Geld ein Pack kaufen, eine zufällige Kreatur kommt raus.
-- Teurere Packs = bessere Chancen. Pity: nach X Packs ohne Legendär+ ist das nächste garantiert Legendär+.
-- Die Chancen stehen in Config.Packs und werden im Shop angezeigt.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Map = require(script.Parent.Map)
local Bases = require(script.Parent.Bases)

local Packs = {}

local remotes
local packById = {}
for _, pack in Config.Packs do
	packById[pack.Id] = pack
end

local LEGENDARY = Config.RarityRank("Legendary")

function Packs.Init(remoteFolder)
	remotes = remoteFolder
end

function Packs.Buy(player: Player, packId: string)
	local state = Bases.GetState(player)
	local pack = packById[packId]
	if not state or not pack then
		return
	end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root or (root.Position - Map.PackShopPosition).Magnitude > 35 then
		Bases.Notify(player, "Geh zum Pack-Shop am Ende der Straße!", Color3.fromRGB(255, 200, 90))
		return
	end
	if state.Data.Money < pack.Price then
		Bases.Notify(player, "Nicht genug Geld!", Color3.fromRGB(255, 90, 90))
		return
	end
	if not Bases.FreeSlot(state) then
		Bases.Notify(player, "Deine Base ist voll! Upgraden oder etwas verkaufen.", Color3.fromRGB(255, 90, 90))
		return
	end

	-- Seltenheit würfeln (mit Pity)
	local weights = pack.Weights
	local pity = state.Data.Pity + 1 >= Config.PityThreshold
	if pity then
		weights = {}
		for rarity, w in pack.Weights do
			if Config.RarityRank(rarity) >= LEGENDARY then
				weights[rarity] = w
			end
		end
		local total = 0
		for _, w in weights do
			total += w
		end
		if total <= 0 then
			weights = { Legendary = 1 }
		end
	end
	local rarity = Config.RollWeighted(weights)
	local def = Config.RandomCreatureOfRarity(rarity)
	local mutation = Config.RollWeighted(Config.MutationWeights)
	local entry = Config.MakeEntry(def.Id, mutation)

	if Config.RarityRank(rarity) >= LEGENDARY then
		state.Data.Pity = 0
	else
		state.Data.Pity += 1
	end
	player:SetAttribute("Pity", state.Data.Pity)

	Bases.AddMoney(state, -pack.Price)
	Bases.GiveCreature(state, entry)
	remotes.PackResult:FireClient(player, entry, pack.Id, pity)
	-- Ansage erst nach der Öffnungs-Animation, damit nichts verraten wird
	task.delay(3.5, function()
		if player.Parent then
			Bases.AnnounceIfRare(player, entry, "aus einem Pack gezogen")
		end
	end)
end

return Packs
