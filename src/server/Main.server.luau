-- Server-Hauptskript: baut die Map, verbindet Spieler, Knöpfe, Packs, Events und Klauen.
-- Liegt in Studio unter: ServerScriptService > Server > Main

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Modules = script.Parent:WaitForChild("Modules")
local Data = require(Modules.Data)
local Map = require(Modules.Map)
local Bases = require(Modules.Bases)
local Steal = require(Modules.Steal)
local Packs = require(Modules.Packs)
local Events = require(Modules.Events)
local Coins = require(Modules.Coins)
local Quests = require(Modules.Quests)
local Rebirth = require(Modules.Rebirth)
local Skills = require(Modules.Skills)
local Leaderboard = require(Modules.Leaderboard)

print(`[Server] {Config.GameName} v{Config.Version} startet ...`)

-- Remotes (Kommunikation Server <-> Client) ----------------------------------
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
for _, name in { "Notify", "BigText", "Announce", "MoneyPopup", "OpenPacks", "BuyPack", "PackResult", "Pop", "Quests", "Rebirth", "BuySkill", "Merge", "Merges" } do
	local event = Instance.new("RemoteEvent")
	event.Name = name
	event.Parent = remotes
end
remotes.Parent = ReplicatedStorage

-- Map bauen ------------------------------------------------------------------
local plots = Map.Build()
Bases.Init(plots, remotes)
Packs.Init(remotes)
local mapFolder = workspace:WaitForChild("KreaturenMap")
Events.Start(mapFolder)
Coins.Start(mapFolder)
Quests.Init(remotes)
Leaderboard.Start(mapFolder)

-- Klatsche (zum Schlagen von Dieben) -------------------------------------------
local function giveSlapper(player: Player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack or backpack:FindFirstChild("Klatsche") then
		return
	end
	local tool = Instance.new("Tool")
	tool.Name = "Klatsche"
	tool.ToolTip = "Hau Diebe, damit sie die Beute fallen lassen!"
	tool.CanBeDropped = false
	tool.GripPos = Vector3.new(0, -1.5, 0)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.6, 4, 0.6)
	handle.Color = Color3.fromRGB(140, 90, 50)
	handle.Material = Enum.Material.Wood
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool

	local head = Instance.new("Part")
	head.Name = "Kopf"
	head.Size = Vector3.new(2.2, 1.6, 0.4)
	head.Color = Color3.fromRGB(255, 80, 80)
	head.CanCollide = false
	head.Massless = true
	head.CFrame = handle.CFrame * CFrame.new(0, 2.6, 0)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = head
	weld.Parent = head
	head.Parent = tool

	local normalGrip = tool.Grip
	local swinging = false
	tool.Activated:Connect(function()
		if swinging then
			return
		end
		swinging = true
		-- kleine Schwung-Animation über den Griff
		tool.Grip = normalGrip * CFrame.Angles(math.rad(-80), 0, 0)
		local hit = Steal.Hit(player)
		if hit then
			Bases.BigText(player, "TREFFER!", Color3.fromRGB(100, 255, 130), "Hit")
			Bases.Track(Bases.GetState(player), "HitThief", 1)
		end
		task.wait(0.25)
		tool.Grip = normalGrip
		swinging = false
	end)

	tool.Parent = backpack
end

-- Spieler --------------------------------------------------------------------
local function onCharacter(player: Player, character: Model)
	local state = Bases.GetState(player)
	if not state then
		return
	end
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root then
		return
	end
	task.wait(0.1)
	if character.Parent then
		character:PivotTo(Bases.SpawnCFrame(state))
	end
	local hum = character:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.WalkSpeed = Steal.WalkSpeed
	end
	giveSlapper(player)
end

local function onPlayerAdded(player: Player)
	local data, saveable = Data.Load(player.UserId)
	if not player.Parent then
		return -- schon wieder weg
	end
	local state = Bases.AddPlayer(player, data, saveable)
	if not state then
		player:Kick("Dieser Server ist voll (alle Bases belegt). Bitte nochmal joinen!")
		return
	end
	if not saveable then
		Bases.Notify(player, "Hinweis: Dein Fortschritt wird gerade nicht gespeichert.", Color3.fromRGB(255, 200, 90))
	end
	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
	if player.Character then
		task.spawn(onCharacter, player, player.Character)
	end
	print(`[Server] {player.Name} hat Base {state.Plot.Index} bekommen.`)
	Quests.Fill(state)
	task.delay(4, function()
		if player.Parent and Bases.GetState(player) == state then
			Bases.CheckDailyBonus(state)
		end
	end)
end

local function onPlayerRemoving(player: Player)
	Steal.OnPlayerLeaving(player)
	local state = Bases.RemovePlayer(player)
	if state then
		Quests.Forget(state)
		task.spawn(Leaderboard.Submit, player, state)
	end
	if state and state.Saveable then
		Data.Save(player.UserId, state.Data)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

-- Knöpfe und Kreaturen (ProximityPrompts) ------------------------------------
ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
	local kind = prompt:GetAttribute("Kind")
	local plotIndex = prompt:GetAttribute("PlotIndex")
	local slot = prompt:GetAttribute("Slot")
	if kind == "Packs" then
		remotes.OpenPacks:FireClient(player)
	elseif kind == "Wild" then
		Events.Grab(player, prompt:GetAttribute("WildId"))
	elseif kind == "Steal" then
		Steal.TryStart(player, plotIndex, slot)
	elseif kind == "Sell" then
		Bases.Sell(player, plotIndex, slot)
	elseif kind == "Lock" then
		Bases.Lock(player, prompt.Parent.Parent:GetAttribute("PlotIndex"))
	elseif kind == "Upgrade" then
		Bases.Upgrade(player, prompt.Parent.Parent:GetAttribute("PlotIndex"))
	end
end)

-- Pack-Kauf vom Client ------------------------------------------------------
remotes.BuyPack.OnServerEvent:Connect(function(player, packId, count)
	if type(packId) == "string" and (count == nil or type(count) == "number") then
		Packs.Buy(player, packId, count)
	end
end)

-- Wiedergeburt, Skill-Baum und Verschmelzen
remotes.Rebirth.OnServerEvent:Connect(function(player)
	Rebirth.Do(player)
end)
remotes.BuySkill.OnServerEvent:Connect(function(player, id)
	if type(id) == "string" then
		Skills.Buy(player, id)
	end
end)
local lastMerge = {} -- [player] = os.clock(), damit niemand den Knopf hämmert
remotes.Merge.OnServerEvent:Connect(function(player, entry)
	if type(entry) ~= "string" or #entry > 80 then
		return
	end
	local now = os.clock()
	if lastMerge[player] and now - lastMerge[player] < 0.5 then
		return
	end
	lastMerge[player] = now
	Bases.Merge(player, entry)
end)
Players.PlayerRemoving:Connect(function(player)
	lastMerge[player] = nil
end)

-- Schleifen ------------------------------------------------------------------
task.spawn(function()
	while true do
		task.wait(Config.IncomeInterval)
		Bases.Tick(Config.IncomeInterval)
	end
end)

local stealTimer = 0
RunService.Heartbeat:Connect(function(dt)
	stealTimer += dt
	if stealTimer >= 0.1 then
		stealTimer = 0
		Steal.Update()
	end
end)

task.spawn(function()
	while true do
		task.wait(Config.AutoSaveInterval)
		for player, state in Bases.States do
			if state.Saveable then
				task.spawn(Data.Save, player.UserId, state.Data)
			end
		end
	end
end)

-- Beim Herunterfahren alle speichern
game:BindToClose(function()
	local pending = 0
	for player, state in Bases.States do
		if state.Saveable then
			pending += 1
			task.spawn(function()
				Data.Save(player.UserId, state.Data)
				pending -= 1
			end)
		end
	end
	local start = os.clock()
	while pending > 0 and os.clock() - start < 25 do
		task.wait(0.2)
	end
end)

print("[Server] Bereit! Viel Spaß beim Sammeln und Klauen.")
