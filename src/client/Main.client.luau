-- Client-Skript: alles, was der Spieler sieht.
-- Geld-Anzeige, Meldungen, große Texte, Server-Ansagen mit Konfetti, Geld-Popups,
-- Event-Countdown, Pack-Shop mit Chancen, Pack-Öffnung, Regenbogen-Farben
-- und welche E-Knöpfe man sieht.
-- Liegt in Studio unter: StarterPlayer > StarterPlayerScripts > Client > Main

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "SpielUI"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local overlayGui = Instance.new("ScreenGui") -- liegt über allem (Pack-Öffnung, Konfetti)
overlayGui.Name = "SpielOverlay"
overlayGui.ResetOnSpawn = false
overlayGui.DisplayOrder = 10
overlayGui.IgnoreGuiInset = true
overlayGui.Parent = player.PlayerGui

-- Hilfsfunktionen --------------------------------------------------------------
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
	local parent = props.Parent
	props.Parent = nil
	for k, v in props do
		(l :: any)[k] = v
	end
	l.Parent = parent
	return l
end

local function stroke(parent: Instance, color: Color3, thickness: number?)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness or 2
	s.Parent = parent
	return s
end

local function playSound(key: string?)
	local id = key and Config.Sounds[key]
	if not id then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = 0.6
	sound.Parent = SoundService
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	task.delay(10, function()
		if sound.Parent then
			sound:Destroy()
		end
	end)
end

local function tween(obj: Instance, time: number, props, style: Enum.EasingStyle?)
	local t = TweenService:Create(obj, TweenInfo.new(time, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

-- Konfetti ---------------------------------------------------------------------
local CONFETTI_COLORS = {
	Color3.fromRGB(255, 80, 80),
	Color3.fromRGB(255, 220, 60),
	Color3.fromRGB(80, 255, 120),
	Color3.fromRGB(80, 180, 255),
	Color3.fromRGB(220, 100, 255),
}
local function confetti(amount: number)
	for _ = 1, amount do
		local piece = Instance.new("Frame")
		piece.Size = UDim2.fromOffset(math.random(8, 14), math.random(12, 20))
		piece.Position = UDim2.new(math.random(), 0, 0, -20)
		piece.Rotation = math.random(0, 360)
		piece.BorderSizePixel = 0
		piece.BackgroundColor3 = CONFETTI_COLORS[math.random(1, #CONFETTI_COLORS)]
		piece.Parent = overlayGui
		local time = math.random(18, 32) / 10
		local t = tween(piece, time, {
			Position = UDim2.new(piece.Position.X.Scale + (math.random() - 0.5) * 0.3, 0, 1.1, 0),
			Rotation = piece.Rotation + math.random(-400, 400),
		}, Enum.EasingStyle.Linear)
		t.Completed:Once(function()
			piece:Destroy()
		end)
	end
end

-- Geld-Anzeige -----------------------------------------------------------------
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
	Text = "+0 $/s in die Kasse",
	Parent = moneyBox,
})

local function updateMoney()
	moneyLabel.Text = `💰 {Config.FormatNumber(player:GetAttribute("Money") or 0)} $`
	incomeLabel.Text = `+{Config.FormatNumber(player:GetAttribute("Income") or 0)} $/s in die Kasse`
end
player:GetAttributeChangedSignal("Money"):Connect(updateMoney)
player:GetAttributeChangedSignal("Income"):Connect(updateMoney)
updateMoney()

-- Geld-Popup: "+500 $" steigt neben der Geld-Anzeige auf
Remotes.MoneyPopup.OnClientEvent:Connect(function(amount: number)
	playSound("Collect")
	local pop = label({
		Size = UDim2.fromOffset(220, 44),
		Position = UDim2.new(0, 20, 0.5, -90),
		Font = Enum.Font.FredokaOne,
		TextColor3 = Color3.fromRGB(120, 255, 120),
		TextStrokeTransparency = 0,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = `+{Config.FormatNumber(amount)} $`,
		Parent = gui,
	})
	tween(pop, 1.2, { Position = UDim2.new(0, 20, 0.5, -170), TextTransparency = 1, TextStrokeTransparency = 1 })
	task.delay(1.3, function()
		pop:Destroy()
	end)
	-- Geld-Anzeige kurz "hüpfen" lassen
	moneyBox.Size = UDim2.fromOffset(264, 70)
	tween(moneyBox, 0.25, { Size = UDim2.fromOffset(240, 64) }, Enum.EasingStyle.Back)
end)

-- Kleine Meldungen (oben) ------------------------------------------------------
local notifyList = Instance.new("Frame")
notifyList.Size = UDim2.new(0, 460, 0, 170)
notifyList.Position = UDim2.new(0.5, -230, 0, 60)
notifyList.BackgroundTransparency = 1
notifyList.Parent = gui
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 6)
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.Parent = notifyList

Remotes.Notify.OnClientEvent:Connect(function(text: string, color: Color3)
	local box = label({
		Size = UDim2.new(1, 0, 0, 34),
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
			tween(box, 0.5, { TextTransparency = 1, BackgroundTransparency = 1 }).Completed:Wait()
			box:Destroy()
		end
	end)
end)

-- Großer Text in der Mitte ("GEKLAUT!", "ERWISCHT!") -----------------------------
local flash = Instance.new("Frame")
flash.Size = UDim2.fromScale(1, 1)
flash.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
flash.BackgroundTransparency = 1
flash.BorderSizePixel = 0
flash.Parent = overlayGui

local bigLabel = label({
	Size = UDim2.new(0.8, 0, 0, 90),
	Position = UDim2.new(0.1, 0, 0.32, 0),
	Font = Enum.Font.FredokaOne,
	TextStrokeTransparency = 0,
	TextTransparency = 1,
	TextStrokeColor3 = Color3.new(0, 0, 0),
	Text = "",
	Parent = overlayGui,
})
local bigToken = 0

local function showBigText(text: string, color: Color3, sound: string?, doFlash: boolean?)
	bigToken += 1
	local token = bigToken
	playSound(sound)
	bigLabel.Text = text
	bigLabel.TextColor3 = color
	bigLabel.TextTransparency = 0
	bigLabel.TextStrokeTransparency = 0
	bigLabel.Size = UDim2.new(0.4, 0, 0, 40)
	bigLabel.Position = UDim2.new(0.3, 0, 0.36, 0)
	tween(bigLabel, 0.35, { Size = UDim2.new(0.8, 0, 0, 90), Position = UDim2.new(0.1, 0, 0.32, 0) }, Enum.EasingStyle.Back)
	if doFlash then
		task.spawn(function()
			for _ = 1, 3 do
				flash.BackgroundTransparency = 0.6
				tween(flash, 0.3, { BackgroundTransparency = 1 })
				task.wait(0.35)
			end
		end)
	end
	task.delay(2.2, function()
		if token == bigToken then
			tween(bigLabel, 0.4, { TextTransparency = 1, TextStrokeTransparency = 1 })
		end
	end)
end
Remotes.BigText.OnClientEvent:Connect(showBigText)

-- Server-Ansage (für alle) mit Konfetti -----------------------------------------
local announceBox = label({
	Size = UDim2.new(0, 640, 0, 48),
	Position = UDim2.new(0.5, -320, 0, -60),
	BackgroundColor3 = Color3.fromRGB(20, 20, 30),
	BackgroundTransparency = 0.1,
	Font = Enum.Font.FredokaOne,
	Text = "",
	Parent = gui,
})
corner(announceBox, 12)
local announceStroke = stroke(announceBox, Color3.new(1, 1, 1), 3)
local announceToken = 0

Remotes.Announce.OnClientEvent:Connect(function(text: string, color: Color3)
	announceToken += 1
	local token = announceToken
	announceBox.Text = text
	announceBox.TextColor3 = color
	announceStroke.Color = color
	announceBox.Position = UDim2.new(0.5, -320, 0, -60)
	tween(announceBox, 0.4, { Position = UDim2.new(0.5, -320, 0, 8) }, Enum.EasingStyle.Back)
	playSound("Reveal")
	confetti(40)
	task.delay(5, function()
		if token == announceToken then
			tween(announceBox, 0.4, { Position = UDim2.new(0.5, -320, 0, -60) })
		end
	end)
end)

-- Event-Countdown (oben rechts) -------------------------------------------------
local eventBox = label({
	Size = UDim2.fromOffset(300, 44),
	Position = UDim2.new(1, -312, 0, 60),
	BackgroundColor3 = Color3.fromRGB(30, 20, 50),
	BackgroundTransparency = 0.15,
	Font = Enum.Font.FredokaOne,
	TextColor3 = Color3.fromRGB(255, 220, 60),
	Text = "",
	Visible = false,
	Parent = gui,
})
corner(eventBox, 10)
stroke(eventBox, Color3.fromRGB(255, 220, 60), 2)

RunService.RenderStepped:Connect(function()
	local title = workspace:GetAttribute("EventTitle")
	local endsAt = workspace:GetAttribute("EventEndsAt")
	if not title or not endsAt then
		eventBox.Visible = false
		return
	end
	local left = math.max(0, math.ceil(endsAt - workspace:GetServerTimeNow()))
	eventBox.Visible = true
	if workspace:GetAttribute("EventPhase") == "warn" then
		eventBox.Text = `{title} in {left}s`
	else
		eventBox.Text = `{title}: noch {left}s`
	end
end)

-- Pack-Shop ---------------------------------------------------------------------
local shop = Instance.new("Frame")
shop.Size = UDim2.new(0, 760, 0, 420)
shop.Position = UDim2.new(0.5, -380, 0.5, -210)
shop.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
shop.Visible = false
shop.Parent = gui
corner(shop, 14)
local shopScale = Instance.new("UIScale")
shopScale.Parent = shop

label({
	Size = UDim2.new(1, -60, 0, 40),
	Position = UDim2.fromOffset(16, 8),
	Font = Enum.Font.FredokaOne,
	TextColor3 = Color3.fromRGB(255, 220, 60),
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "Pack-Shop",
	Parent = shop,
})
local pityLabel = label({
	Size = UDim2.new(1, -32, 0, 22),
	Position = UDim2.fromOffset(16, 48),
	TextColor3 = Color3.fromRGB(255, 190, 40),
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "",
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

local packRow = Instance.new("Frame")
packRow.Size = UDim2.new(1, -24, 1, -90)
packRow.Position = UDim2.fromOffset(12, 80)
packRow.BackgroundTransparency = 1
packRow.Parent = shop
local rowLayout = Instance.new("UIListLayout")
rowLayout.FillDirection = Enum.FillDirection.Horizontal
rowLayout.Padding = UDim.new(0, 12)
rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
rowLayout.Parent = packRow

local packButtons = {}
for _, pack in Config.Packs do
	local card = Instance.new("Frame")
	card.Size = UDim2.new(1 / #Config.Packs, -10, 1, 0)
	card.BackgroundColor3 = Color3.fromRGB(45, 45, 65)
	card.Parent = packRow
	corner(card, 12)
	stroke(card, pack.Color, 3)

	label({
		Size = UDim2.new(1, -16, 0, 34),
		Position = UDim2.fromOffset(8, 8),
		Font = Enum.Font.FredokaOne,
		TextColor3 = pack.Color,
		Text = pack.Name,
		Parent = card,
	})

	-- Chancen anzeigen
	local y = 48
	for _, rarityKey in Config.RarityOrder do
		local percent = Config.Percent(pack.Weights, rarityKey)
		if percent > 0 then
			local rarity = Config.Rarities[rarityKey]
			local text = if percent < 1 then string.format("%.1f %%", percent) else string.format("%d %%", math.floor(percent + 0.5))
			label({
				Size = UDim2.new(1, -24, 0, 20),
				Position = UDim2.fromOffset(12, y),
				TextColor3 = rarity.Color,
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = `{rarity.Name}: {text}`,
				Parent = card,
			})
			y += 24
		end
	end

	local buy = Instance.new("TextButton")
	buy.Size = UDim2.new(1, -24, 0, 50)
	buy.Position = UDim2.new(0, 12, 1, -62)
	buy.BackgroundColor3 = Color3.fromRGB(60, 200, 90)
	buy.TextColor3 = Color3.new(1, 1, 1)
	buy.Font = Enum.Font.GothamBold
	buy.TextScaled = true
	buy.Text = `Öffnen: {Config.FormatNumber(pack.Price)} $`
	buy.Parent = card
	corner(buy, 10)
	buy.Activated:Connect(function()
		playSound("Click")
		Remotes.BuyPack:FireServer(pack.Id)
	end)
	packButtons[pack.Id] = { Button = buy, Price = pack.Price }
end

local function updateShop()
	local money = player:GetAttribute("Money") or 0
	for _, entry in packButtons do
		entry.Button.BackgroundColor3 = if money >= entry.Price
			then Color3.fromRGB(60, 200, 90)
			else Color3.fromRGB(90, 90, 100)
	end
	local left = Config.PityThreshold - (player:GetAttribute("Pity") or 0)
	pityLabel.Text = `Garantiert Legendär oder besser in spätestens {math.max(1, left)} Packs`
end
player:GetAttributeChangedSignal("Money"):Connect(updateShop)
player:GetAttributeChangedSignal("Pity"):Connect(updateShop)

local function fitShop()
	local camera = workspace.CurrentCamera
	if camera then
		local size = camera.ViewportSize
		shopScale.Scale = math.min(1, size.X / 800, size.Y / 480)
	end
end

Remotes.OpenPacks.OnClientEvent:Connect(function()
	updateShop()
	fitShop()
	shop.Visible = true
end)

-- Packs-Knopf: öffnet den Shop von überall (auch Taste P)
local opening = false -- läuft gerade eine Pack-Öffnung?
local UserInputService = game:GetService("UserInputService")
local packsButton = Instance.new("TextButton")
packsButton.Size = UDim2.fromOffset(240, 54)
packsButton.Position = UDim2.new(0, 12, 0.5, 40)
packsButton.BackgroundColor3 = Color3.fromRGB(255, 170, 40)
packsButton.TextColor3 = Color3.new(1, 1, 1)
packsButton.Font = Enum.Font.FredokaOne
packsButton.TextScaled = true
packsButton.Text = "📦 PACKS (P)"
packsButton.Parent = gui
corner(packsButton, 10)
stroke(packsButton, Color3.fromRGB(255, 255, 255), 2)

local function toggleShop()
	if opening then
		return
	end
	if shop.Visible then
		shop.Visible = false
	else
		updateShop()
		fitShop()
		shop.Visible = true
	end
	playSound("Click")
end
packsButton.Activated:Connect(toggleShop)
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.P then
		toggleShop()
	end
end)

-- Knopf leicht pulsieren lassen, wenn man sich ein Pack leisten kann
task.spawn(function()
	while true do
		local money = player:GetAttribute("Money") or 0
		local canBuy = money >= Config.Packs[1].Price
		if canBuy and not shop.Visible then
			tween(packsButton, 0.4, { Size = UDim2.fromOffset(252, 58) }).Completed:Wait()
			tween(packsButton, 0.4, { Size = UDim2.fromOffset(240, 54) }).Completed:Wait()
		else
			task.wait(0.5)
		end
	end
end)

-- Pack-Öffnung: Wackeln, Blitz, Reveal ------------------------------------------
local function openPackAnimation(entry: string, packId: string, wasPity: boolean)
	local def, mutationId = Config.ParseEntry(entry)
	if not def then
		return
	end
	local pack
	for _, p in Config.Packs do
		if p.Id == packId then
			pack = p
		end
	end
	local rarity = Config.Rarities[def.Rarity]
	local mutation = Config.Mutations[mutationId]
	local rank = Config.RarityRank(def.Rarity)
	opening = true
	shop.Visible = false

	local dim = Instance.new("Frame")
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = Color3.new(0, 0, 0)
	dim.BackgroundTransparency = 1
	dim.Parent = overlayGui
	tween(dim, 0.3, { BackgroundTransparency = 0.35 })

	-- Das Pack
	local box = Instance.new("Frame")
	box.AnchorPoint = Vector2.new(0.5, 0.5)
	box.Position = UDim2.fromScale(0.5, 0.5)
	box.Size = UDim2.fromOffset(150, 190)
	box.BackgroundColor3 = pack and pack.Color or Color3.new(1, 1, 1)
	box.Parent = dim
	corner(box, 16)
	stroke(box, Color3.new(1, 1, 1), 4)
	label({
		Size = UDim2.fromScale(1, 0.4),
		Position = UDim2.fromScale(0, 0.3),
		Font = Enum.Font.FredokaOne,
		Text = "?",
		Parent = box,
	})

	-- Wackeln, immer stärker. Bei seltenen Kreaturen leuchtet der Rand schon in der Farbe.
	local glow = box:FindFirstChildOfClass("UIStroke")
	for i = 1, 14 do
		local strength = i * 1.5
		box.Rotation = if i % 2 == 0 then strength else -strength
		if i > 8 and rank >= Config.RarityRank("Epic") and glow then
			glow.Color = rarity.Color
			glow.Thickness = 4 + i
		end
		playSound(if i % 3 == 0 then "Click" else nil)
		task.wait(0.11)
	end
	box.Rotation = 0

	-- Blitz
	local white = Instance.new("Frame")
	white.Size = UDim2.fromScale(1, 1)
	white.BackgroundColor3 = if rank >= Config.RarityRank("Legendary") then rarity.Color else Color3.new(1, 1, 1)
	white.BackgroundTransparency = 0
	white.Parent = overlayGui
	tween(white, 0.6, { BackgroundTransparency = 1 })
	task.delay(0.7, function()
		white:Destroy()
	end)
	box:Destroy()
	playSound("Reveal")

	-- Reveal-Karte
	local card = Instance.new("Frame")
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.Size = UDim2.fromOffset(40, 50)
	card.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
	card.Parent = dim
	corner(card, 18)
	stroke(card, mutation.Color or rarity.Color, 6)
	tween(card, 0.4, { Size = UDim2.fromOffset(340, 300) }, Enum.EasingStyle.Back)

	local swatch = Instance.new("Frame")
	swatch.AnchorPoint = Vector2.new(0.5, 0)
	swatch.Position = UDim2.new(0.5, 0, 0, 20)
	swatch.Size = UDim2.fromOffset(100, 100)
	swatch.BackgroundColor3 = mutation.Color or def.Color
	swatch.Parent = card
	corner(swatch, 20)
	if mutationId == "Regenbogen" then
		CollectionService:AddTag(swatch, "RainbowGui")
	end

	label({
		Size = UDim2.new(1, -20, 0, 40),
		Position = UDim2.new(0, 10, 0, 130),
		Font = Enum.Font.FredokaOne,
		TextColor3 = rarity.Color,
		Text = Config.EntryName(entry),
		Parent = card,
	})
	label({
		Size = UDim2.new(1, -20, 0, 28),
		Position = UDim2.new(0, 10, 0, 172),
		TextColor3 = rarity.Color,
		Text = string.upper(rarity.Name) .. (if mutation.Name ~= "" then ` · {mutation.Name} x{mutation.Multiplier}` else ""),
		Parent = card,
	})
	label({
		Size = UDim2.new(1, -20, 0, 26),
		Position = UDim2.new(0, 10, 0, 204),
		TextColor3 = Color3.fromRGB(130, 255, 130),
		Text = `+{Config.FormatNumber(Config.EntryIncome(entry))} $/s`,
		Parent = card,
	})
	label({
		Size = UDim2.new(1, -20, 0, 20),
		Position = UDim2.new(0, 10, 1, -34),
		TextColor3 = Color3.fromRGB(180, 180, 190),
		Text = if wasPity then "Pity-Garantie! · Klicken zum Schließen" else "Klicken zum Schließen",
		Parent = card,
	})

	if rank >= Config.RarityRank("Epic") or mutationId ~= "Normal" then
		confetti(if rank >= Config.RarityRank("Legendary") then 120 else 50)
	end

	-- Schließen per Klick oder nach 4 Sekunden
	local closeButtonOverlay = Instance.new("TextButton")
	closeButtonOverlay.Size = UDim2.fromScale(1, 1)
	closeButtonOverlay.BackgroundTransparency = 1
	closeButtonOverlay.Text = ""
	closeButtonOverlay.Parent = dim
	local closed = false
	local function close()
		if closed then
			return
		end
		closed = true
		dim:Destroy()
		opening = false
		-- Shop wieder aufmachen, damit man direkt das nächste Pack öffnen kann
		updateShop()
		shop.Visible = true
	end
	closeButtonOverlay.Activated:Connect(close)
	task.delay(4, close)
end

Remotes.PackResult.OnClientEvent:Connect(function(entry: string, packId: string, wasPity: boolean)
	if opening then
		return
	end
	task.spawn(openPackAnimation, entry, packId, wasPity)
end)

-- Regenbogen-Mutation: Farbe wechselt ständig ------------------------------------
RunService.Heartbeat:Connect(function()
	local hue = (os.clock() * 0.25) % 1
	local color = Color3.fromHSV(hue, 0.85, 1)
	for _, part in CollectionService:GetTagged("Rainbow") do
		if part:IsA("BasePart") then
			part.Color = color
		end
	end
	for _, frame in CollectionService:GetTagged("RainbowGui") do
		if frame:IsA("GuiObject") then
			frame.BackgroundColor3 = color
		end
	end
end)

-- Welche E-Knöpfe sieht MEIN Spieler? -------------------------------------------
-- Eigene Base: Verkaufen, Schloss, Upgrade. Fremde Base: Klauen. Überall: Packs, Meteor.
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
	local carrying = player:GetAttribute("Carrying") ~= nil
	local enabled
	if kind == "Steal" or kind == "Sell" or kind == "Lock" or kind == "Upgrade" then
		local plot = findPlot(prompt)
		local ownerId = plot and plot:GetAttribute("OwnerUserId")
		local isMine = ownerId == player.UserId
		if kind == "Steal" then
			enabled = active and ownerId ~= nil and not isMine and not plot:GetAttribute("Locked") and not carrying
		else
			enabled = active and isMine
		end
	elseif kind == "Wild" then
		enabled = active and not carrying
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
