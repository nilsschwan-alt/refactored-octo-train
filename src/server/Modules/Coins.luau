-- Münzen auf der Straße und in den Welten: einfach drüberlaufen und einsammeln.
-- Der Wert passt sich an: eine Münze ist ein paar Sekunden DEINES Einkommens wert.
-- Ab und zu gibt's eine Riesen-Münze. Der Münz-Magnet (Skill-Baum) vergrößert den Sammel-Radius.
-- Jedes Gebiet (Straße, jede Welt) hat seine eigenen Münzen: Coins.AddZone().

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Bases = require(script.Parent.Bases)
local Map = require(script.Parent.Map)
local FX = require(script.Parent.FX)

local Coins = {}

local C = Config.Coins
local folder
local coins = {} -- [part] = { Big = bool, Expires = number, Zone = Gebiet }
local zones = {}

local GOLD = Color3.fromRGB(255, 205, 40)

-- Neues Münz-Gebiet: { Max = Anzahl, Factor = Wert-Faktor, Color = Farbe, Point = function(): Vector3 }
function Coins.AddZone(zone)
	zone.Count = 0
	table.insert(zones, zone)
end

local function spawnCoin(zone)
	local big = math.random() < C.BigChance
	local size = if big then 4.5 else 2.4
	local coin = Instance.new("Part")
	coin.Name = if big then "RiesenMuenze" else "Muenze"
	coin.Shape = Enum.PartType.Cylinder
	coin.Size = Vector3.new(size * 0.25, size, size)
	coin.Color = zone.Color
	coin.Material = Enum.Material.Neon
	coin.Anchored = true
	coin.CanCollide = false
	coin.CanQuery = false
	coin.CanTouch = false
	local pos = zone.Point() + Vector3.new(0, size / 2 + 1, 0)
	-- stehend (Zylinder liegt sonst auf der Seite); der Client lässt sie drehen und hüpfen
	coin.CFrame = CFrame.new(pos) * CFrame.Angles(0, math.random() * math.pi, 0)
	coin:SetAttribute("BaseY", pos.Y)
	if big then
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = zone.Color
		sparkles.Parent = coin
		local light = Instance.new("PointLight")
		light.Color = zone.Color
		light.Range = 10
		light.Brightness = 1
		light.Parent = coin
	end
	coin.Parent = folder
	CollectionService:AddTag(coin, "SpinCoin")
	coins[coin] = { Big = big, Expires = os.clock() + C.Lifetime, Zone = zone }
	zone.Count += 1
end

local function removeCoin(coin: BasePart)
	local info = coins[coin]
	if info then
		coins[coin] = nil
		info.Zone.Count -= 1
	end
	coin:Destroy()
end

local function collect(player: Player, coin: BasePart)
	local info = coins[coin]
	local state = Bases.GetState(player)
	if not info or not state then
		return
	end
	local color = info.Zone.Color
	local value = math.max(C.MinValue, Bases.Income(state) * C.ValueSeconds) * (1 + Bases.Skill(state, "CoinValue")) * info.Zone.Factor
	-- Fähigkeit "Riesen-Münzen": eine normale Münze wird beim Einsammeln manchmal zur Riesen-Münze
	local big = info.Big or math.random() < Bases.Skill(state, "BigCoins")
	if big then
		value *= C.BigFactor
	end
	value = math.floor(value)
	local position = coin.Position
	removeCoin(coin)
	Bases.AddMoney(state, value)
	Bases.Track(state, "Coins", 1)
	Bases.Pop(player, value, position + Vector3.new(0, 2, 0), nil, color)
	if big then
		FX.Burst(position, color, 40)
		Bases.BigText(player, `RIESEN-MÜNZE +{Config.FormatNumber(value)} $`, color, "Collect")
	end
end

-- Läuft alle 0.15 s: Wer steht nah genug an einer Münze?
local function update()
	local now = os.clock()
	for coin, info in coins do
		if now > info.Expires or not coin.Parent then
			removeCoin(coin)
		end
	end
	for _, player in Players:GetPlayers() do
		local state = Bases.GetState(player)
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if state and root then
			local radius = C.PickupRadius + Bases.Skill(state, "Magnet")
			for coin in coins do
				local offset = coin.Position - root.Position
				if (offset * Vector3.new(1, 0.5, 1)).Magnitude <= radius + coin.Size.Y / 2 then
					collect(player, coin)
				end
			end
		end
	end
end

function Coins.Start(mapFolder: Instance)
	folder = Instance.new("Folder")
	folder.Name = "Muenzen"
	folder.Parent = mapFolder
	Coins.AddZone({ Max = C.MaxOnMap, Factor = 1, Color = GOLD, Point = Map.RandomStreetPoint })
	task.spawn(function()
		while true do
			task.wait(C.SpawnInterval)
			for _, zone in zones do
				if zone.Count < zone.Max then
					spawnCoin(zone)
				end
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.15)
			update()
		end
	end)
end

return Coins
