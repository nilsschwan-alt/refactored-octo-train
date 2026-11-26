-- Client-Skript: Geld-Anzeige, Shop-Fenster, Meldungen und welche Knöpfe man sieht.
-- Liegt in Studio unter: StarterPlayer > StarterPlayerScripts > Client > Main

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "SpielUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.Parent = player:WaitForChild("PlayerGui")

local function corner(parent: Instance, radius: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 10)
	c.Parent = parent
end

local function label(props): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.TextColor3 = Color3.new(1, 1, 1)
	l.Font = Enum.Font.GothamBold
	l.TextScaled = true
	for k, v in props do
		(l :: any)[k] = v
	end
	return l
end

-- Geld-Anzeige ---------------------------------------------------------------
local moneyBox = Instance.new("Frame")
moneyBox.Size = UDim2.fromOffset(240, 64)
moneyBox.Position = UDim2.new(0, 12, 0.5, -32)
moneyBox.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
moneyBox.BackgroundTransparency = 0.2
moneyBox.Parent = gui
corner(moneyBox)

local moneyLabel = label({
	Size = UDim2.new(1, -16, 0.6, 0),
	Position = UDim2.fromOffset(8, 4),
	Font = Enum.Font.FredokaOne,
	TextColor3 = Color3.fromRGB(255, 220, 60),
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "0 $",
	Parent = moneyBox,
})
local incomeLabel = label({
	Size = UDim2.new(1, -16, 0.35, 0),
	Position = UDim2.new(0, 8, 0.6, 0),
	TextColor3 = Color3.fromRGB(130, 255, 130),
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "+0 $/s",
	Parent = moneyBox,
})

local function updateMoney()
	moneyLabel.Text = `💰 {Config.FormatNumber(player:GetAttribute("Money") or 0)} $`
	incomeLabel.Text = `+{Config.FormatNumber(player:GetAttribute("Income") or 0)} $/s`
end
player:GetAttributeChangedSignal("Money"):Connect(updateMoney)
player:GetAttributeChangedSignal("Income"):Connect(updateMoney)
updateMoney()

-- Meldungen ------------------------------------------------------------------
local notifyList = Instance.new("Frame")
notifyList.Size = UDim2.new(0, 460, 0, 200)
notifyList.Position = UDim2.new(0.5, -230, 0, 10)
notifyList.BackgroundTransparency = 1
notifyList.Parent = gui
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 6)
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.Parent = notifyList

Remotes.Notify.OnClientEvent:Connect(function(text: string, color: Color3)
	local box = label({
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundTransparency = 0.25,
		BackgroundColor3 = Color3.fromRGB(20, 20, 30),
		TextColor3 = color,
		Text = text,
		Parent = notifyList,
	})
	corner(box, 8)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingBottom = UDim.new(0, 4)
	pad.Parent = box
	-- Maximal 4 Meldungen gleichzeitig
	local boxes = {}
	for _, child in notifyList:GetChildren() do
		if child:IsA("TextLabel") then
			table.insert(boxes, child)
		end
	end
	if #boxes > 4 then
		boxes[1]:Destroy()
	end
	task.delay(4, function()
		if box.Parent then
			local tween = TweenService:Create(box, TweenInfo.new(0.5), { TextTransparency = 1, BackgroundTransparency = 1 })
			tween:Play()
			tween.Completed:Wait()
			box:Destroy()
		end
	end)
end)

-- Shop-Fenster ---------------------------------------------------------------
local shop = Instance.new("Frame")
shop.Size = UDim2.new(0, 520, 0.7, 0)
shop.Position = UDim2.new(0.5, -260, 0.15, 0)
shop.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
shop.Visible = false
shop.Parent = gui
corner(shop, 14)

label({
	Size = UDim2.new(1, -60, 0, 44),
	Position = UDim2.fromOffset(14, 8),
	Font = Enum.Font.FredokaOne,
	TextColor3 = Color3.fromRGB(255, 220, 60),
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "Kreaturen-Shop",
	Parent = shop,
})

local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.fromOffset(40, 40)
closeButton.Position = UDim2.new(1, -50, 0, 10)
closeButton.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
closeButton.Text = "X"
closeButton.TextColor3 = Color3.new(1, 1, 1)
closeButton.Font = Enum.Font.GothamBold
closeButton.TextScaled = true
closeButton.Parent = shop
corner(closeButton, 8)
closeButton.Activated:Connect(function()
	shop.Visible = false
end)

local list = Instance.new("ScrollingFrame")
list.Size = UDim2.new(1, -20, 1, -70)
list.Position = UDim2.fromOffset(10, 60)
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.ScrollBarThickness = 8
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.CanvasSize = UDim2.new()
list.Parent = shop
local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 8)
listLayout.Parent = list

local buyButtons = {}
for _, def in Config.Creatures do
	local rarity = Config.Rarities[def.Rarity]
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -12, 0, 64)
	row.BackgroundColor3 = Color3.fromRGB(45, 45, 65)
	row.Parent = list
	corner(row, 10)

	local stroke = Instance.new("UIStroke")
	stroke.Color = rarity.Color
	stroke.Thickness = 2
	stroke.Parent = row

	local swatch = Instance.new("Frame")
	swatch.Size = UDim2.fromOffset(44, 44)
	swatch.Position = UDim2.fromOffset(10, 10)
	swatch.BackgroundColor3 = def.Color
	swatch.Parent = row
	corner(swatch, 8)

	label({
		Size = UDim2.new(0.5, -60, 0, 28),
		Position = UDim2.fromOffset(64, 6),
		Font = Enum.Font.FredokaOne,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = def.Name,
		Parent = row,
	})
	label({
		Size = UDim2.new(0.5, -60, 0, 22),
		Position = UDim2.fromOffset(64, 36),
		TextColor3 = rarity.Color,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = `{rarity.Name} · +{Config.FormatNumber(def.Income)} $/s`,
		Parent = row,
	})

	local buy = Instance.new("TextButton")
	buy.Size = UDim2.new(0, 150, 0, 44)
	buy.Position = UDim2.new(1, -160, 0, 10)
	buy.BackgroundColor3 = Color3.fromRGB(60, 200, 90)
	buy.TextColor3 = Color3.new(1, 1, 1)
	buy.Font = Enum.Font.GothamBold
	buy.TextScaled = true
	buy.Text = `{Config.FormatNumber(def.Price)} $`
	buy.Parent = row
	corner(buy, 8)
	buy.Activated:Connect(function()
		Remotes.BuyCreature:FireServer(def.Id)
	end)
	buyButtons[def.Id] = { Button = buy, Price = def.Price }
end

local function updateShopButtons()
	local money = player:GetAttribute("Money") or 0
	for _, entry in buyButtons do
		entry.Button.BackgroundColor3 = if money >= entry.Price
			then Color3.fromRGB(60, 200, 90)
			else Color3.fromRGB(90, 90, 100)
	end
end
player:GetAttributeChangedSignal("Money"):Connect(updateShopButtons)

Remotes.OpenShop.OnClientEvent:Connect(function()
	updateShopButtons()
	shop.Visible = true
end)

-- Shop schließen, wenn man weggeht
task.spawn(function()
	while true do
		task.wait(0.5)
		if shop.Visible then
			local char = player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			if root and (root.Position * Vector3.new(1, 0, 1)).Magnitude > Config.Map.ShopUseDistance then
				shop.Visible = false
			end
		end
	end
end)

-- Welche Knöpfe sieht MEIN Spieler? ------------------------------------------
-- Eigene Base: Verkaufen, Schloss, Upgrade. Fremde Base: Klauen.
local function findPlot(inst: Instance): Instance?
	local current = inst.Parent
	while current and current ~= workspace do
		if current:GetAttribute("IsPlot") then
			return current
		end
		current = current.Parent
	end
	return nil
end

local function refreshPrompt(prompt: ProximityPrompt)
	local kind = prompt:GetAttribute("Kind")
	local active = prompt:GetAttribute("Active") ~= false
	local plot = findPlot(prompt)
	local ownerId = plot and plot:GetAttribute("OwnerUserId")
	local isMine = ownerId == player.UserId
	local enabled
	if kind == "Steal" then
		enabled = active
			and ownerId ~= nil
			and not isMine
			and not plot:GetAttribute("Locked")
			and player:GetAttribute("Carrying") == nil
	elseif kind == "Sell" or kind == "Lock" or kind == "Upgrade" then
		enabled = active and isMine
	else
		enabled = active
	end
	if prompt.Enabled ~= enabled then
		prompt.Enabled = enabled
	end
end

CollectionService:GetInstanceAddedSignal("GamePrompt"):Connect(function(prompt)
	if prompt:IsA("ProximityPrompt") then
		refreshPrompt(prompt)
	end
end)

task.spawn(function()
	while true do
		for _, prompt in CollectionService:GetTagged("GamePrompt") do
			if prompt:IsA("ProximityPrompt") then
				refreshPrompt(prompt)
			end
		end
		task.wait(0.25)
	end
end)

print(`[Client] Hallo {player.Name}, willkommen bei {Config.GameName}!`)
