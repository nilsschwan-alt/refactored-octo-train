-- Bestenlisten in der Welt (neben der Riesen-Statue):
--   links:  Top 10 aller Zeiten (insgesamt verdientes Geld, über alle Server, per OrderedDataStore)
--   rechts: Wer ist gerade auf diesem Server vorne?
-- Ohne DataStore (Studio ohne API-Zugriff) zeigt die linke Tafel einen Hinweis.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Bases = require(script.Parent.Bases)
local Map = require(script.Parent.Map)

local Leaderboard = {}

local store = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetOrderedDataStore(Config.Leaderboard.StoreName)
	end)
	if ok then
		store = result
	end
end

local names = {} -- [userId] = Name (Cache)
local boards = {}

local function nameOf(userId: number): string
	if names[userId] then
		return names[userId]
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	names[userId] = if ok and name then name else "Spieler"
	return names[userId]
end

-- Eine Tafel mit Titel und 10 Zeilen bauen
local function buildBoard(parent: Instance, position: Vector3, title: string, color: Color3)
	local board = Instance.new("Part")
	board.Name = "Bestenliste"
	board.Anchored = true
	board.Size = Vector3.new(18, 14, 1)
	board.Color = Color3.fromRGB(25, 25, 40)
	board.Material = Enum.Material.SmoothPlastic
	-- schaut zur Straße (+X)
	board.CFrame = CFrame.lookAt(position + Vector3.new(0, 10, 0), position + Vector3.new(1, 10, 0))
	board.Parent = parent
	for _, side in { -1, 1 } do
		local leg = Instance.new("Part")
		leg.Name = "Bein"
		leg.Anchored = true
		leg.Size = Vector3.new(0.8, 4, 0.8)
		leg.Color = Color3.fromRGB(60, 60, 75)
		leg.CFrame = board.CFrame * CFrame.new(side * 7, -9, 0)
		leg.Parent = parent
	end
	local frameLight = Instance.new("Part")
	frameLight.Name = "Rahmen"
	frameLight.Anchored = true
	frameLight.CanCollide = false
	frameLight.Size = Vector3.new(18.6, 14.6, 0.6)
	frameLight.Color = color
	frameLight.Material = Enum.Material.Neon
	frameLight.CFrame = board.CFrame * CFrame.new(0, 0, 0.3)
	frameLight.Parent = parent

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(540, 420)
	gui.LightInfluence = 0
	gui.Parent = board

	local head = Instance.new("TextLabel")
	head.Size = UDim2.new(1, -20, 0, 50)
	head.Position = UDim2.fromOffset(10, 6)
	head.BackgroundTransparency = 1
	head.Font = Enum.Font.FredokaOne
	head.TextScaled = true
	head.TextColor3 = color
	head.Text = title
	head.Parent = gui

	local rows = {}
	for i = 1, 10 do
		local row = Instance.new("TextLabel")
		row.Size = UDim2.new(1, -30, 0, 32)
		row.Position = UDim2.fromOffset(15, 56 + (i - 1) * 35)
		row.BackgroundTransparency = if i % 2 == 0 then 1 else 0.85
		row.BackgroundColor3 = Color3.new(1, 1, 1)
		row.Font = Enum.Font.GothamBold
		row.TextScaled = true
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextColor3 = if i == 1
			then Color3.fromRGB(255, 215, 50)
			elseif i == 2 then Color3.fromRGB(220, 220, 235)
			elseif i == 3 then Color3.fromRGB(230, 150, 80)
			else Color3.new(1, 1, 1)
		row.Text = ""
		row.Parent = gui
		rows[i] = row
	end
	return rows
end

local function setRows(rows, list)
	for i = 1, 10 do
		local item = list[i]
		rows[i].Text = if item then `  {i}. {item}` else ""
	end
end

local function refreshServer()
	local list = {}
	for player, state in Bases.States do
		table.insert(list, { Player = player, State = state })
	end
	table.sort(list, function(a, b)
		if a.State.Data.Rebirths ~= b.State.Data.Rebirths then
			return a.State.Data.Rebirths > b.State.Data.Rebirths
		end
		return a.State.Data.Money > b.State.Data.Money
	end)
	local lines = {}
	for _, item in list do
		local data = item.State.Data
		table.insert(lines, `{item.Player.DisplayName}  ·  🔄{data.Rebirths}  ·  {Config.FormatNumber(data.Money)} $`)
	end
	setRows(boards.Server, lines)
end

-- Eigene Werte in die globale Liste schreiben
local function submitAll()
	if not store then
		return
	end
	for player, state in Bases.States do
		if state.Saveable then
			local value = math.floor(state.Data.TotalEarned)
			pcall(function()
				store:SetAsync(tostring(player.UserId), value)
			end)
		end
	end
end

local function refreshGlobal()
	if not store then
		setRows(boards.Global, { "Nur im veröffentlichten Spiel", "(mit API-Zugriff)" })
		return
	end
	local ok, pages = pcall(function()
		return store:GetSortedAsync(false, 10)
	end)
	if not ok then
		setRows(boards.Global, { "Gerade nicht erreichbar ..." })
		return
	end
	local lines = {}
	for _, item in pages:GetCurrentPage() do
		local userId = tonumber(item.key)
		local name = if userId then nameOf(userId) else "?"
		table.insert(lines, `{name}  ·  {Config.FormatNumber(item.value)} $`)
	end
	setRows(boards.Global, lines)
end

function Leaderboard.Start(parent: Instance)
	local base = Map.StatuePosition
	boards.Global = buildBoard(parent, base + Vector3.new(10, 0, -27), "🌍 Top 10: Meistes Geld verdient", Color3.fromRGB(255, 215, 50))
	boards.Server = buildBoard(parent, base + Vector3.new(10, 0, 27), "🏠 Dieser Server", Color3.fromRGB(120, 220, 255))
	task.spawn(function()
		while true do
			refreshServer()
			task.wait(3)
		end
	end)
	task.spawn(function()
		task.wait(10)
		while true do
			submitAll()
			refreshGlobal()
			task.wait(Config.Leaderboard.RefreshInterval)
		end
	end)
end

-- Beim Verlassen noch schnell eintragen
function Leaderboard.Submit(player: Player, state)
	if store and state and state.Saveable then
		pcall(function()
			store:SetAsync(tostring(player.UserId), math.floor(state.Data.TotalEarned))
		end)
	end
end

return Leaderboard
