-- Laufband: Alle paar Sekunden kommt eine zufällige Kreatur (mit Mutation) aufs Band.
-- Wer zuerst E hält und genug Geld hat, bekommt sie. Seltene werden im ganzen Server angesagt.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local CreatureModels = require(script.Parent.CreatureModels)
local Map = require(script.Parent.Map)
local Bases = require(script.Parent.Bases)

local Conveyor = {}

local items = {} -- [id] = { Entry, Price, Model, Tween }
local nextId = 0
local folder

local function rollEntry(): string
	local rarity = Config.RollWeighted(Config.Conveyor.Weights)
	local def = Config.RandomCreatureOfRarity(rarity)
	local mutation = Config.RollWeighted(Config.MutationWeights)
	return Config.MakeEntry(def.Id, mutation)
end

local function removeItem(id: number)
	local item = items[id]
	if not item then
		return
	end
	items[id] = nil
	if item.Tween then
		item.Tween:Cancel()
	end
	item.Model:Destroy()
end

function Conveyor.SpawnOne()
	local entry = rollEntry()
	local def, mutation = Config.ParseEntry(entry)
	local price = math.floor(Config.EntryValue(entry) * Config.Conveyor.PriceFactor)

	nextId += 1
	local id = nextId
	local model = CreatureModels.Build(def, {
		Label = true,
		Mutation = mutation,
		Anchored = false,
		PriceText = `{Config.FormatNumber(price)} $`,
	})
	local body = model.PrimaryPart
	body.Anchored = true -- nur der Körper ist verankert, der Rest hängt dran

	-- Kreatur schaut zur Seite (zu einer Reihe), fährt in +X-Richtung
	local startCF = CFrame.new(Map.BeltStart) * CFrame.Angles(0, math.rad(math.random(0, 1) * 180), 0)
	model:PivotTo(startCF)
	model.Parent = folder

	local p = Map.MakePrompt(body, "BeltBuy", `Kaufen: {Config.FormatNumber(price)} $`, Config.EntryName(entry),
		Config.Conveyor.BuyHoldTime, 10)
	p:SetAttribute("BeltId", id)

	local distance = (Map.BeltEnd - Map.BeltStart).Magnitude
	local endCF = body.CFrame + (Map.BeltEnd - Map.BeltStart)
	local tween = TweenService:Create(body, TweenInfo.new(distance / Config.Conveyor.Speed, Enum.EasingStyle.Linear),
		{ CFrame = endCF })
	items[id] = { Entry = entry, Price = price, Model = model, Tween = tween }
	tween.Completed:Connect(function(state)
		if state == Enum.PlaybackState.Completed then
			removeItem(id)
		end
	end)
	tween:Play()

	-- Seltene Kreatur? Alle sollen hinrennen!
	local rank = Config.RarityRank(def.Rarity)
	if rank >= Config.RarityRank(Config.Conveyor.AnnounceFrom) or mutation == "Regenbogen" then
		local rarity = Config.Rarities[def.Rarity]
		Bases.Announce(`⚡ {string.upper(rarity.Name)} auf dem Laufband: {Config.EntryName(entry)}!`, rarity.Color)
	end
end

function Conveyor.Buy(player: Player, id: number)
	local item = items[id]
	local state = Bases.GetState(player)
	if not item or not state then
		return
	end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root or (item.Model:GetPivot().Position - root.Position).Magnitude > 16 then
		return
	end
	if state.Data.Money < item.Price then
		Bases.Notify(player, "Nicht genug Geld!", Color3.fromRGB(255, 90, 90))
		return
	end
	if not Bases.FreeSlot(state) then
		Bases.Notify(player, "Deine Base ist voll! Upgraden oder etwas verkaufen.", Color3.fromRGB(255, 90, 90))
		return
	end
	removeItem(id)
	Bases.AddMoney(state, -item.Price)
	Bases.GiveCreature(state, item.Entry)

	local def, mutation = Config.ParseEntry(item.Entry)
	local rarity = Config.Rarities[def.Rarity]
	if Config.RarityRank(def.Rarity) >= Config.RarityRank("Epic") or mutation ~= "Normal" then
		Bases.BigText(player, `{string.upper(Config.EntryName(item.Entry))}!`, rarity.Color, "Reveal")
	else
		Bases.Notify(player, `{Config.EntryName(item.Entry)} gekauft!`, rarity.Color)
	end
	Bases.AnnounceIfRare(player, item.Entry, "vom Laufband geholt")
end

function Conveyor.Start(parentFolder: Instance)
	folder = Instance.new("Folder")
	folder.Name = "LaufbandKreaturen"
	folder.Parent = parentFolder
	task.spawn(function()
		while true do
			Conveyor.SpawnOne()
			task.wait(Config.Conveyor.SpawnInterval)
		end
	end)
end

return Conveyor
