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

-- Spielt eine kleine Melodie aus Config.Sounds (pitch = zusätzliche Tonhöhe)
local function playSound(key: string?, pitch: number?)
	local melody = key and Config.Sounds[key]
	if not melody then
		return
	end
	for _, note in melody do
		local id = Config.SoundSamples[note[1]]
		if id then
			task.delay(note[4] or 0, function()
				local sound = Instance.new("Sound")
				sound.SoundId = id
				sound.PlaybackSpeed = (note[2] or 1) * (pitch or 1)
				sound.Volume = note[3] or 0.5
				sound.Parent = SoundService
				sound:Play()
				sound.Ended:Once(function()
					sound:Destroy()
				end)
				task.delay(8, function()
					if sound.Parent then
						sound:Destroy()
					end
				end)
			end)
		end
	end
end

-- Kamera wackeln lassen (stärke in Grad, dauer in Sekunden)
local shakeUntil, shakeStrength = 0, 0
local function shake(strength: number, duration: number)
	shakeStrength = math.max(if os.clock() < shakeUntil then shakeStrength else 0, strength)
	shakeUntil = math.max(shakeUntil, os.clock() + duration)
end
RunService:BindToRenderStep("Kamerawackeln", Enum.RenderPriority.Camera.Value + 1, function()
	local left = shakeUntil - os.clock()
	if left <= 0 then
		return
	end
	local camera = workspace.CurrentCamera
	local s = math.rad(shakeStrength) * math.min(1, left * 3)
	camera.CFrame = camera.CFrame * CFrame.Angles((math.random() - 0.5) * s, (math.random() - 0.5) * s, (math.random() - 0.5) * s * 0.5)
end)

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

-- Sterne fliegen von einem Punkt nach außen
local function starBurst(center: UDim2, color: Color3, amount: number, distance: number?)
	for i = 1, amount do
		local star = Instance.new("TextLabel")
		star.BackgroundTransparency = 1
		star.Text = if i % 3 == 0 then "✦" else "★"
		star.TextScaled = true
		star.TextColor3 = if i % 2 == 0 then color else Color3.new(1, 1, 1)
		star.AnchorPoint = Vector2.new(0.5, 0.5)
		star.Size = UDim2.fromOffset(math.random(16, 30), math.random(16, 30))
		star.Position = center
		star.Rotation = math.random(0, 360)
		star.Parent = overlayGui
		local angle = (i / amount) * math.pi * 2 + math.random() * 0.4
		local dist = (distance or 220) * (0.6 + math.random() * 0.6)
		local target = center + UDim2.fromOffset(math.cos(angle) * dist, math.sin(angle) * dist)
		tween(star, 0.7 + math.random() * 0.4, { Position = target, TextTransparency = 1, Rotation = star.Rotation + 180 })
		task.delay(1.2, function()
			star:Destroy()
		end)
	end
end

-- Strahlenkranz, der sich hinter etwas dreht
local function sunburst(parent: Instance, color: Color3, size: number): Frame
	local holder = Instance.new("Frame")
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromOffset(size, size)
	holder.BackgroundTransparency = 1
	holder.Parent = parent
	for i = 0, 11 do
		local ray = Instance.new("Frame")
		ray.AnchorPoint = Vector2.new(0.5, 0.5)
		ray.Position = UDim2.fromScale(0.5, 0.5)
		ray.Size = UDim2.new(0, 26, 1, 0)
		ray.Rotation = i * 15
		ray.BackgroundColor3 = color
		ray.BackgroundTransparency = if i % 2 == 0 then 0.55 else 0.75
		ray.BorderSizePixel = 0
		ray.Parent = holder
		local gradient = Instance.new("UIGradient")
		gradient.Rotation = 90
		gradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0),
			NumberSequenceKeypoint.new(1, 1),
		})
		gradient.Parent = ray
	end
	task.spawn(function()
		while holder.Parent do
			holder.Rotation += 0.6
			RunService.RenderStepped:Wait()
		end
	end)
	return holder
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
	Text = "+0 $/s automatisch",
	Parent = moneyBox,
})

-- Die Zahl zählt sichtbar hoch/runter statt zu springen
local shownMoney = player:GetAttribute("Money") or 0
local function updateMoney()
	incomeLabel.Text = `+{Config.FormatNumber(player:GetAttribute("Income") or 0)} $/s automatisch`
end

-- Jedes Mal, wenn Geld dazukommt: kleines grünes "+X $" steigt neben der Geld-Anzeige auf
local lastMoney = player:GetAttribute("Money") or 0
player:GetAttributeChangedSignal("Money"):Connect(function()
	local now = player:GetAttribute("Money") or 0
	local gain = now - lastMoney
	lastMoney = now
	if gain < 1 then
		return
	end
	local gainLabel = Instance.new("TextLabel")
	gainLabel.BackgroundTransparency = 1
	gainLabel.Size = UDim2.fromOffset(140, 26)
	gainLabel.Position = UDim2.new(1, 8, 0, 6) -- rechts neben der Geld-Anzeige
	gainLabel.Font = Enum.Font.FredokaOne
	gainLabel.TextScaled = true
	gainLabel.TextXAlignment = Enum.TextXAlignment.Left
	gainLabel.TextColor3 = Color3.fromRGB(130, 255, 130)
	gainLabel.TextStrokeTransparency = 0.3
	gainLabel.Text = `+{Config.FormatNumber(gain)} $`
	gainLabel.Parent = moneyBox
	tween(gainLabel, 0.9, { Position = gainLabel.Position - UDim2.fromOffset(0, 30), TextTransparency = 1, TextStrokeTransparency = 1 })
	task.delay(1, function()
		gainLabel:Destroy()
	end)
end)
RunService.RenderStepped:Connect(function(dt)
	local target = player:GetAttribute("Money") or 0
	if math.abs(target - shownMoney) < 1 then
		shownMoney = target
	else
		shownMoney += (target - shownMoney) * math.min(1, dt * 6)
	end
	moneyLabel.Text = `💰 {Config.FormatNumber(shownMoney)} $`
end)
player:GetAttributeChangedSignal("Income"):Connect(updateMoney)
updateMoney()

-- Geld-Popup: Münzen fliegen zur Geld-Anzeige, "+500 $" steigt auf
Remotes.MoneyPopup.OnClientEvent:Connect(function(amount: number)
	local coins = math.clamp(math.floor(math.log10(math.max(amount, 1)) * 3), 4, 14)
	local camera = workspace.CurrentCamera
	local view = camera and camera.ViewportSize or Vector2.new(1280, 720)
	local targetPos = moneyBox.AbsolutePosition + Vector2.new(30, 30)
	for i = 1, coins do
		local coin = Instance.new("TextLabel")
		coin.BackgroundTransparency = 1
		coin.Text = "🪙"
		coin.TextScaled = true
		coin.AnchorPoint = Vector2.new(0.5, 0.5)
		coin.Size = UDim2.fromOffset(34, 34)
		coin.Position = UDim2.fromOffset(view.X / 2 + math.random(-120, 120), view.Y * 0.6 + math.random(-60, 60))
		coin.Parent = overlayGui
		task.delay(i * 0.04, function()
			-- erst kurz hochspringen, dann zur Anzeige fliegen
			local up = coin.Position - UDim2.fromOffset(0, math.random(40, 90))
			tween(coin, 0.18, { Position = up }).Completed:Wait()
			local t = tween(coin, 0.45, { Position = UDim2.fromOffset(targetPos.X, targetPos.Y), Size = UDim2.fromOffset(18, 18) }, Enum.EasingStyle.Quad)
			t.Completed:Wait()
			coin:Destroy()
			playSound("Coin", 1 + i * 0.03)
			moneyBox.Size = UDim2.fromOffset(256, 68)
			tween(moneyBox, 0.15, { Size = UDim2.fromOffset(240, 64) }, Enum.EasingStyle.Back)
		end)
	end
	playSound("Collect")
	local pop = label({
		Size = UDim2.fromOffset(260, 50),
		Position = UDim2.new(0, 20, 0.5, -90),
		Font = Enum.Font.FredokaOne,
		TextColor3 = Color3.fromRGB(120, 255, 120),
		TextStrokeTransparency = 0,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = `+{Config.FormatNumber(amount)} $`,
		Parent = gui,
	})
	local popScale = Instance.new("UIScale")
	popScale.Scale = 0.3
	popScale.Parent = pop
	tween(popScale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(0.5, function()
		tween(pop, 1, { Position = UDim2.new(0, 20, 0.5, -170), TextTransparency = 1, TextStrokeTransparency = 1 })
	end)
	task.delay(1.6, function()
		pop:Destroy()
	end)
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

local bigScale = Instance.new("UIScale")
bigScale.Parent = bigLabel
local bigStroke = stroke(bigLabel, Color3.new(0, 0, 0), 4)

local function showBigText(text: string, color: Color3, sound: string?, doFlash: boolean?)
	bigToken += 1
	local token = bigToken
	playSound(sound)
	bigLabel.Text = text
	bigLabel.TextColor3 = color
	bigLabel.TextTransparency = 0
	bigLabel.TextStrokeTransparency = 0
	bigStroke.Transparency = 0
	bigLabel.Size = UDim2.new(0.8, 0, 0, 100)
	bigLabel.Position = UDim2.new(0.1, 0, 0.3, 0)
	bigLabel.Rotation = -8
	bigScale.Scale = 0.2
	tween(bigScale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	tween(bigLabel, 0.35, { Rotation = 0 }, Enum.EasingStyle.Back)
	starBurst(UDim2.fromScale(0.5, 0.36), color, 18, 260)

	-- Leichtes Wackeln des Textes
	task.spawn(function()
		for i = 1, 6 do
			if token ~= bigToken then
				return
			end
			task.wait(0.06)
			bigLabel.Rotation = (if i % 2 == 0 then 1 else -1) * (6 - i) * 0.6
		end
		bigLabel.Rotation = 0
	end)

	if doFlash or sound == "Stolen" or sound == "Hit" then
		shake(if sound == "Hit" then 4 else 2.5, 0.5)
	end
	if doFlash then
		task.spawn(function()
			for _ = 1, 3 do
				flash.BackgroundTransparency = 0.55
				tween(flash, 0.3, { BackgroundTransparency = 1 })
				task.wait(0.35)
			end
		end)
	end
	if sound == "Upgrade" or sound == "Reveal" or sound == "Quest" then
		confetti(50)
	elseif sound == "Rebirth" then
		confetti(160)
		shake(5, 0.9)
		task.spawn(function()
			for i = 1, 4 do
				starBurst(UDim2.fromScale(0.2 + math.random() * 0.6, 0.2 + math.random() * 0.5), color, 16, 200)
				task.wait(0.18 * i)
			end
		end)
	end
	task.delay(2.2, function()
		if token == bigToken then
			tween(bigScale, 0.3, { Scale = 1.3 })
			tween(bigLabel, 0.3, { TextTransparency = 1, TextStrokeTransparency = 1 })
			tween(bigStroke, 0.3, { Transparency = 1 })
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
	Visible = false, -- sonst sieht man oben kurz eine leere Leiste
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
	announceBox.Visible = true
	tween(announceBox, 0.4, { Position = UDim2.new(0.5, -320, 0, 8) }, Enum.EasingStyle.Back)
	playSound("Announce")
	confetti(40)
	task.delay(5, function()
		if token == announceToken then
			tween(announceBox, 0.4, { Position = UDim2.new(0.5, -320, 0, -60) })
			task.delay(0.45, function()
				if token == announceToken then
					announceBox.Visible = false
				end
			end)
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

	-- Chancen anzeigen (werden mit Glück aus dem Rebirth-Shop aktualisiert)
	local y = 48
	local chanceLabels = {}
	for _, rarityKey in Config.RarityOrder do
		if (pack.Weights[rarityKey] or 0) > 0 then
			local rarity = Config.Rarities[rarityKey]
			chanceLabels[rarityKey] = label({
				Size = UDim2.new(1, -24, 0, 20),
				Position = UDim2.fromOffset(12, y),
				TextColor3 = rarity.Color,
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = "",
				Parent = card,
			})
			y += 24
		end
	end

	-- 1x / 3x / 10x
	local buttonRow = Instance.new("Frame")
	buttonRow.Size = UDim2.new(1, -16, 0, 58)
	buttonRow.Position = UDim2.new(0, 8, 1, -66)
	buttonRow.BackgroundTransparency = 1
	buttonRow.Parent = card
	local buttonLayout = Instance.new("UIListLayout")
	buttonLayout.FillDirection = Enum.FillDirection.Horizontal
	buttonLayout.Padding = UDim.new(0, 5)
	buttonLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	buttonLayout.Parent = buttonRow
	local buttons = {}
	for _, option in Config.PackCounts do
		local cost = Config.PackCost(pack, option.Count)
		local buy = Instance.new("TextButton")
		buy.Size = UDim2.new(1 / #Config.PackCounts, -4, 1, 0)
		buy.BackgroundColor3 = Color3.fromRGB(60, 200, 90)
		buy.TextColor3 = Color3.new(1, 1, 1)
		buy.Font = Enum.Font.FredokaOne
		buy.TextScaled = true
		buy.TextStrokeTransparency = 0.5
		buy.Text = `{option.Count}x\n{Config.FormatNumber(cost)} $`
		buy.Parent = buttonRow
		corner(buy, 10)
		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0, 4)
		pad.PaddingBottom = UDim.new(0, 4)
		pad.PaddingLeft = UDim.new(0, 3)
		pad.PaddingRight = UDim.new(0, 3)
		pad.Parent = buy
		if option.Discount < 1 then
			local tag = label({
				Size = UDim2.fromOffset(46, 18),
				Position = UDim2.new(1, -40, 0, -14),
				BackgroundTransparency = 0,
				BackgroundColor3 = Color3.fromRGB(255, 60, 90),
				Font = Enum.Font.FredokaOne,
				Text = `-{math.floor((1 - option.Discount) * 100 + 0.5)} %`,
				ZIndex = 3,
				Parent = buy,
			})
			tag.Rotation = 12
			corner(tag, 6)
		end
		buy.Activated:Connect(function()
			playSound("Click")
			Remotes.BuyPack:FireServer(pack.Id, option.Count)
		end)
		table.insert(buttons, { Button = buy, Price = cost })
	end
	packButtons[pack.Id] = { Buttons = buttons, Pack = pack, Chances = chanceLabels }
end

local function percentText(percent: number): string
	return if percent < 1 then string.format("%.1f %%", percent) else string.format("%d %%", math.floor(percent + 0.5))
end

local function updateShop()
	local money = player:GetAttribute("Money") or 0
	local luck = player:GetAttribute("Up_Luck") or 0
	for _, entry in packButtons do
		for _, b in entry.Buttons do
			b.Button.BackgroundColor3 = if money >= b.Price then Color3.fromRGB(60, 200, 90) else Color3.fromRGB(90, 90, 100)
		end
		local weights = Config.PackWeights(entry.Pack, luck)
		for rarityKey, l in entry.Chances do
			local rarity = Config.Rarities[rarityKey]
			l.Text = `{rarity.Name}: {percentText(Config.Percent(weights, rarityKey))}`
		end
	end
	local left = Config.PityThreshold - (player:GetAttribute("Pity") or 0)
	pityLabel.Text = `Garantiert Legendär oder besser in spätestens {math.max(1, left)} Packs`
end
player:GetAttributeChangedSignal("Money"):Connect(updateShop)
player:GetAttributeChangedSignal("Pity"):Connect(updateShop)
player:GetAttributeChangedSignal("Up_Luck"):Connect(updateShop)
updateShop()

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
-- Kleiner quadratischer Shop-Knopf unter der Geld-Anzeige
local packsButton = Instance.new("TextButton")
packsButton.Size = UDim2.fromOffset(72, 72)
packsButton.Position = UDim2.new(0, 12, 0.5, 40)
packsButton.BackgroundColor3 = Color3.fromRGB(255, 170, 40)
packsButton.Text = ""
packsButton.AutoButtonColor = true
packsButton.Parent = gui
corner(packsButton, 12)
stroke(packsButton, Color3.fromRGB(255, 255, 255), 2)
local packsScale = Instance.new("UIScale")
packsScale.Parent = packsButton
label({
	Size = UDim2.new(1, 0, 0.62, 0),
	Position = UDim2.fromScale(0, 0.04),
	Text = "🏪",
	Parent = packsButton,
})
label({
	Size = UDim2.new(1, -8, 0.3, 0),
	Position = UDim2.new(0, 4, 0.66, 0),
	Font = Enum.Font.FredokaOne,
	TextStrokeTransparency = 0.4,
	Text = "Shop",
	Parent = packsButton,
})

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
			tween(packsScale, 0.4, { Scale = 1.1 }).Completed:Wait()
			tween(packsScale, 0.4, { Scale = 1 }).Completed:Wait()
		else
			task.wait(0.5)
		end
	end
end)

-- Pack-Öffnung: Folien-Pack, Risse, Platzen, 3D-Kreatur auf der Karte -----------------
local Lighting = game:GetService("Lighting")
local ContentProvider = game:GetService("ContentProvider")

-- Sounds vorladen, damit beim ersten Pack nichts verzögert kommt
task.spawn(function()
	local list = {}
	for _, id in Config.SoundSamples do
		local sound = Instance.new("Sound")
		sound.SoundId = id
		table.insert(list, sound)
	end
	pcall(function()
		ContentProvider:PreloadAsync(list)
	end)
end)

local function findPack(packId: string)
	for _, p in Config.Packs do
		if p.Id == packId then
			return p
		end
	end
	return nil
end

-- Sound starten, den man später wieder stoppen kann (Trommelwirbel beim Aufladen)
local function startSound(sample: string, volume: number, pitch: number?): Sound?
	local id = Config.SoundSamples[sample]
	if not id then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume
	sound.PlaybackSpeed = pitch or 1
	sound.Parent = SoundService
	sound:Play()
	task.delay(12, function()
		if sound.Parent then
			sound:Destroy()
		end
	end)
	return sound
end

local function stopSound(sound: Sound?, fade: number)
	if not sound then
		return
	end
	tween(sound, fade, { Volume = 0 })
	task.delay(fade + 0.05, function()
		sound:Destroy()
	end)
end

-- Welcher Reveal-Sound passt zur Seltenheit?
local function revealSoundKey(rank: number, mutated: boolean): string
	if rank >= 6 then
		return "Mythic"
	elseif rank >= 5 then
		return "Legendary"
	elseif rank >= 4 or mutated then
		return "Epic"
	elseif rank >= 3 then
		return "Rare"
	end
	return "RevealCommon"
end

-- Kreatur für die Karte: 3D-KI-Modell im ViewportFrame, das wippt und sich hin und her dreht.
-- Gibt es kein Modell, gibt es wie früher ein Farbfeld mit Augen.
-- Gibt das Bild zurück (mit UIScale zum Aufploppen).
local function creatureIcon(parent: GuiObject, def, mutationId: string, size: number, y: number): (GuiObject, UIScale)
	local mutation = Config.Mutations[mutationId] or Config.Mutations.Normal
	local rarity = Config.Rarities[def.Rarity]

	-- Leuchtkreis hinter der Kreatur
	local glow = Instance.new("Frame")
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.new(0.5, 0, 0, y + size / 2)
	glow.Size = UDim2.fromOffset(size * 0.92, size * 0.92)
	glow.BackgroundColor3 = mutation.Color or rarity.Color
	glow.BackgroundTransparency = 0.72
	glow.BorderSizePixel = 0
	glow.Parent = parent
	corner(glow, size)
	if mutationId == "Regenbogen" then
		CollectionService:AddTag(glow, "RainbowGui")
	end

	local iconScale = Instance.new("UIScale")
	iconScale.Scale = 0

	local folder = ReplicatedStorage:FindFirstChild("KreaturenModelle")
	local template = folder and folder:FindFirstChild(def.Id)
	if template and template:IsA("Model") then
		local vp = Instance.new("ViewportFrame")
		vp.AnchorPoint = Vector2.new(0.5, 0)
		vp.Position = UDim2.new(0.5, 0, 0, y)
		vp.Size = UDim2.fromOffset(size, size)
		vp.BackgroundTransparency = 1
		vp.Ambient = Color3.fromRGB(165, 165, 180)
		vp.LightColor = Color3.new(1, 1, 1)
		vp.LightDirection = Vector3.new(-0.3, -0.8, 1) -- Licht von vorne oben
		if mutation.Color then
			vp.ImageColor3 = Color3.new(1, 1, 1):Lerp(mutation.Color, 0.35)
		end
		local model = template:Clone()
		model:PivotTo(CFrame.new())
		model.Parent = vp
		local camera = Instance.new("Camera")
		camera.FieldOfView = 30
		camera.Parent = vp
		vp.CurrentCamera = camera
		local boxCF, boxSize = model:GetBoundingBox()
		local center = boxCF.Position
		local radius = math.max(boxSize.X, boxSize.Y, boxSize.Z) * 0.62
		local dist = radius / math.tan(math.rad(camera.FieldOfView / 2))
		-- Kamera vor der Kreatur (die schaut nach -Z)
		camera.CFrame = CFrame.lookAt(center + Vector3.new(0, boxSize.Y * 0.12, -dist), center)
		iconScale.Parent = vp
		vp.Parent = parent
		task.spawn(function()
			local start = os.clock()
			while vp.Parent do
				local t = os.clock() - start
				local hop = math.abs(math.sin(t * 3)) * boxSize.Y * 0.06
				model:PivotTo(CFrame.new(0, hop, 0) * CFrame.Angles(0, math.sin(t * 1.3) * 0.6, 0))
				RunService.RenderStepped:Wait()
			end
		end)
		return vp, iconScale
	end

	local swatchSize = math.floor(size * 0.75)
	local swatch = Instance.new("Frame")
	swatch.AnchorPoint = Vector2.new(0.5, 0.5)
	swatch.Position = UDim2.new(0.5, 0, 0, y + size / 2)
	swatch.Size = UDim2.fromOffset(swatchSize, swatchSize)
	swatch.BackgroundColor3 = mutation.Color or def.Color
	swatch.Parent = parent
	corner(swatch, math.floor(swatchSize * 0.22))
	stroke(swatch, def.Accent, 4)
	iconScale.Parent = swatch
	if mutationId == "Regenbogen" then
		CollectionService:AddTag(swatch, "RainbowGui")
	end
	local eyeSize = math.floor(swatchSize * 0.22)
	for _, x in { 0.3, 0.7 } do
		local eye = Instance.new("Frame")
		eye.AnchorPoint = Vector2.new(0.5, 0.5)
		eye.Position = UDim2.fromScale(x, 0.42)
		eye.Size = UDim2.fromOffset(eyeSize, eyeSize)
		eye.BackgroundColor3 = Color3.new(1, 1, 1)
		eye.Parent = swatch
		corner(eye, eyeSize)
		local pupil = Instance.new("Frame")
		pupil.AnchorPoint = Vector2.new(0.5, 0.5)
		pupil.Position = UDim2.fromScale(0.5, 0.55)
		pupil.Size = UDim2.fromOffset(math.ceil(eyeSize * 0.45), math.ceil(eyeSize * 0.55))
		pupil.BackgroundColor3 = Color3.new(0, 0, 0)
		pupil.Parent = eye
		corner(pupil, eyeSize)
	end
	return swatch, iconScale
end

-- Rand, über den ein Glanz in der Seltenheits-Farbe läuft (ab Legendär)
local function animatedBorder(holder: GuiObject, color: Color3, thickness: number)
	local s = stroke(holder, Color3.new(1, 1, 1), thickness)
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, color),
		ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(1, color),
	})
	gradient.Parent = s
	task.spawn(function()
		while holder.Parent do
			gradient.Rotation = (gradient.Rotation + 4) % 360
			RunService.RenderStepped:Wait()
		end
	end)
end

-- Einmal ein Glanz quer über eine Karte
local function shineOnce(holder: GuiObject, delay: number)
	local shine = Instance.new("Frame")
	shine.Size = UDim2.fromScale(1, 1)
	shine.BackgroundColor3 = Color3.new(1, 1, 1)
	shine.BorderSizePixel = 0
	shine.ZIndex = 5
	shine.Parent = holder
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 25
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.42, 1),
		NumberSequenceKeypoint.new(0.5, 0.35),
		NumberSequenceKeypoint.new(0.58, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	gradient.Offset = Vector2.new(-1, 0)
	gradient.Parent = shine
	task.delay(delay, function()
		tween(gradient, 0.7, { Offset = Vector2.new(1, 0) })
		task.wait(0.75)
		shine:Destroy()
	end)
end

-- Druckwelle: Ring, der schnell groß wird und verblasst
local function shockwave(parent: Instance, color: Color3, maxSize: number)
	local ring = Instance.new("Frame")
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.5)
	ring.Size = UDim2.fromOffset(60, 60)
	ring.BackgroundTransparency = 1
	ring.Parent = parent
	corner(ring, maxSize)
	local s = stroke(ring, color, 14)
	tween(ring, 0.6, { Size = UDim2.fromOffset(maxSize, maxSize) })
	tween(s, 0.6, { Transparency = 1, Thickness = 2 })
	task.delay(0.65, function()
		ring:Destroy()
	end)
end

-- Das Pack: Folie mit Streifen, Name, "?" und einem Glanz, der drüberläuft
local function makePackBox(parent: Instance, title: string, bigText: string, packColor: Color3, w: number, h: number)
	local box = Instance.new("Frame")
	box.AnchorPoint = Vector2.new(0.5, 0.5)
	box.Position = UDim2.fromScale(0.5, -0.3)
	box.Size = UDim2.fromOffset(w, h)
	box.BackgroundColor3 = packColor
	box.ClipsDescendants = true
	box.Parent = parent
	corner(box, 18)
	local boxStroke = stroke(box, Color3.new(1, 1, 1), 5)
	local boxScale = Instance.new("UIScale")
	boxScale.Parent = box
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(Color3.new(1, 1, 1), packColor:Lerp(Color3.new(0, 0, 0), 0.35))
	gradient.Rotation = 90
	gradient.Parent = box
	-- Folien-Streifen oben und unten wie bei einer Sammelkarten-Packung
	for _, yScale in { 0, 1 } do
		local strip = Instance.new("Frame")
		strip.AnchorPoint = Vector2.new(0, yScale)
		strip.Position = UDim2.fromScale(0, yScale)
		strip.Size = UDim2.new(1, 0, 0, 14)
		strip.BackgroundColor3 = Color3.new(1, 1, 1)
		strip.BackgroundTransparency = 0.35
		strip.BorderSizePixel = 0
		strip.Parent = box
	end
	label({
		Size = UDim2.new(1, -16, 0.18, 0),
		Position = UDim2.new(0, 8, 0, 20),
		Font = Enum.Font.FredokaOne,
		TextStrokeTransparency = 0.3,
		Text = title,
		Parent = box,
	})
	local question = label({
		Size = UDim2.fromScale(1, 0.45),
		Position = UDim2.fromScale(0, 0.32),
		Font = Enum.Font.FredokaOne,
		TextStrokeTransparency = 0.3,
		Text = bigText,
		Parent = box,
	})
	local shine = Instance.new("Frame")
	shine.Size = UDim2.fromScale(1, 1)
	shine.BackgroundColor3 = Color3.new(1, 1, 1)
	shine.BorderSizePixel = 0
	shine.ZIndex = 3
	shine.Parent = box
	local shineGradient = Instance.new("UIGradient")
	shineGradient.Rotation = 25
	shineGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.44, 1),
		NumberSequenceKeypoint.new(0.5, 0.5),
		NumberSequenceKeypoint.new(0.56, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	shineGradient.Offset = Vector2.new(-1, 0)
	shineGradient.Parent = shine
	task.spawn(function()
		while shine.Parent do
			shineGradient.Offset = Vector2.new(-1, 0)
			tween(shineGradient, 0.8, { Offset = Vector2.new(1, 0) })
			task.wait(1.1)
		end
	end)
	return box, boxStroke, boxScale, question
end

-- Ein Riss im Pack: 3 Zacken von einem zufälligen Punkt aus
local function addCrack(box: Frame, color: Color3, seed: number, list: { Frame })
	local rng = Random.new(seed)
	local w, h = box.Size.X.Offset, box.Size.Y.Offset
	local x, y = rng:NextNumber(0.2, 0.8) * w, rng:NextNumber(0.2, 0.8) * h
	local angle = rng:NextNumber(0, math.pi * 2)
	for _ = 1, 3 do
		local len = rng:NextNumber(24, 44)
		local nx, ny = x + math.cos(angle) * len, y + math.sin(angle) * len
		local seg = Instance.new("Frame")
		seg.AnchorPoint = Vector2.new(0.5, 0.5)
		seg.Position = UDim2.fromOffset((x + nx) / 2, (y + ny) / 2)
		seg.Size = UDim2.fromOffset(len + 2, 4)
		seg.Rotation = math.deg(angle)
		seg.BackgroundColor3 = color
		seg.BorderSizePixel = 0
		seg.ZIndex = 4
		seg.Parent = box
		table.insert(list, seg)
		x, y = nx, ny
		angle += rng:NextNumber(-1, 1)
	end
end

-- Pack aufladen: wackeln, Ticks werden höher, Risse mit Licht, Leuchtkreis wächst.
-- Seltene laden länger, ab Episch gibt es einen Trommelwirbel und die Farbe verrät sich am Ende.
local function chargePack(box: Frame, boxStroke: UIStroke, boxScale: UIScale, question: TextLabel, rays: Frame, glow: Frame, rank: number, color: Color3, steps: number, baseWait: number)
	local isEpic = rank >= Config.RarityRank("Epic")
	local isLegendary = rank >= Config.RarityRank("Legendary")
	local drum = if isEpic then startSound("DrumRoll", 0.55) else nil
	local cracks = {}
	local crackCount = 0
	for i = 1, steps do
		local t = i / steps
		local strength = 2 + t * 14
		box.Rotation = (if i % 2 == 0 then 1 else -1) * strength
		box.Position = UDim2.new(0.5, math.random(-1, 1) * t * 8, 0.5, math.random(-1, 1) * t * 8)
		boxScale.Scale = 1 + t * 0.28
		question.Rotation = -box.Rotation
		playSound("Tick", 0.8 + t * 1.2)
		local reveal = isEpic and t > 0.6
		local rayColor = if reveal then color else Color3.new(1, 1, 1)
		for _, r in rays:GetChildren() do
			if r:IsA("Frame") then
				r.BackgroundColor3 = rayColor
				r.BackgroundTransparency = 1 - t * 0.5
			end
		end
		-- Risse: ab gut einem Drittel immer mehr
		local want = math.floor(math.max(0, t - 0.3) * 10)
		while crackCount < want do
			crackCount += 1
			addCrack(box, Color3.new(1, 1, 1), crackCount * 13 + rank, cracks)
		end
		glow.Size = UDim2.fromOffset(220 + t * 180, 220 + t * 180)
		glow.BackgroundTransparency = 0.9 - t * 0.4
		if reveal then
			-- Licht in der Seltenheits-Farbe scheint durch die Risse
			boxStroke.Color = color
			boxStroke.Thickness = 5 + t * 8
			glow.BackgroundColor3 = color
			for _, seg in cracks do
				seg.BackgroundColor3 = color
				seg.Size = UDim2.fromOffset(seg.Size.X.Offset, 6)
			end
		end
		if isLegendary and t > 0.5 then
			shake(t * 1.5, 0.2)
		end
		task.wait(baseWait - t * baseWait * 0.4)
	end
	stopSound(drum, 0.15)
	-- Ab Legendär: kurzer Moment Stille, das Pack glüht in der Farbe und wird groß
	if isLegendary then
		box.Rotation = 0
		question.Rotation = 0
		tween(box, 0.35, { BackgroundColor3 = color, Position = UDim2.fromScale(0.5, 0.48) })
		tween(boxScale, 0.35, { Scale = 1.5 })
		shake(3, 0.35)
		task.wait(0.4)
	end
end

-- Pack platzt: reißt in zwei Hälften, Blitz, Druckwelle, Sterne
local function burstPack(dim: Frame, box: Frame, packColor: Color3, rank: number, color: Color3)
	local isEpic = rank >= Config.RarityRank("Epic")
	local isLegendary = rank >= Config.RarityRank("Legendary")
	playSound("PackCrack")
	local absPos, absSize = box.AbsolutePosition - dim.AbsolutePosition, box.AbsoluteSize
	local halfColor = box.BackgroundColor3
	box:Destroy()
	for _, dir in { -1, 1 } do
		local half = Instance.new("Frame")
		half.AnchorPoint = Vector2.new(0.5, 0.5)
		half.Size = UDim2.fromOffset(absSize.X, absSize.Y / 2)
		half.Position = UDim2.fromOffset(absPos.X + absSize.X / 2, absPos.Y + absSize.Y * (if dir < 0 then 0.25 else 0.75))
		half.BackgroundColor3 = halfColor
		half.Parent = dim
		corner(half, 14)
		local s = stroke(half, Color3.new(1, 1, 1), 4)
		tween(half, 0.55, {
			Position = half.Position + UDim2.fromOffset(dir * 180, dir * 260),
			Rotation = dir * 40,
			BackgroundTransparency = 1,
		})
		tween(s, 0.55, { Transparency = 1 })
		task.delay(0.6, function()
			half:Destroy()
		end)
	end
	local flash = Instance.new("Frame")
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = if isLegendary then color else Color3.new(1, 1, 1)
	flash.BorderSizePixel = 0
	flash.Parent = overlayGui
	tween(flash, 0.7, { BackgroundTransparency = 1 })
	task.delay(0.8, function()
		flash:Destroy()
	end)
	shockwave(dim, if isEpic then color else packColor, if isLegendary then 1100 else 700)
	if isLegendary then
		task.delay(0.12, function()
			shockwave(dim, Color3.new(1, 1, 1), 900)
		end)
	end
	starBurst(UDim2.fromScale(0.5, 0.5), color, if isLegendary then 44 else 22, if isLegendary then 440 else 290)
	if rank >= 6 then
		shake(8, 1.1)
	elseif isLegendary then
		shake(6, 0.8)
	elseif isEpic then
		shake(2.5, 0.4)
	end
end

-- Hintergrund: unscharf, dunkel, Strahlen und Leuchtkreis hinter dem Pack
local function openingBackdrop(raySize: number)
	local blur = Instance.new("BlurEffect")
	blur.Size = 0
	blur.Parent = Lighting
	tween(blur, 0.4, { Size = 18 })
	local dim = Instance.new("Frame")
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = Color3.new(0, 0, 0)
	dim.BackgroundTransparency = 1
	dim.Parent = overlayGui
	tween(dim, 0.4, { BackgroundTransparency = 0.4 })
	local glow = Instance.new("Frame")
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.fromScale(0.5, 0.5)
	glow.Size = UDim2.fromOffset(220, 220)
	glow.BackgroundColor3 = Color3.new(1, 1, 1)
	glow.BackgroundTransparency = 1
	glow.BorderSizePixel = 0
	glow.Parent = dim
	corner(glow, 2000)
	local rays = sunburst(dim, Color3.new(1, 1, 1), raySize)
	rays.Position = UDim2.fromScale(0.5, 0.5)
	for _, r in rays:GetChildren() do
		if r:IsA("Frame") then
			r.BackgroundTransparency = 1
		end
	end
	return blur, dim, rays, glow
end

local function openPackAnimation(entry: string, packId: string, wasPity: boolean)
	local def, mutationId = Config.ParseEntry(entry)
	if not def then
		return
	end
	local pack = findPack(packId)
	local rarity = Config.Rarities[def.Rarity]
	local mutation = Config.Mutations[mutationId]
	local rank = Config.RarityRank(def.Rarity)
	local isEpic = rank >= Config.RarityRank("Epic")
	local isLegendary = rank >= Config.RarityRank("Legendary")
	local packColor = pack and pack.Color or Color3.new(1, 1, 1)
	opening = true
	shop.Visible = false

	local blur, dim, rays, glow = openingBackdrop(520)

	-- Das Pack fällt von oben rein
	local box, boxStroke, boxScale, question = makePackBox(dim, pack and pack.Name or "Pack", "?", packColor, 160, 210)
	playSound("Swoosh", 0.8)
	tween(box, 0.6, { Position = UDim2.fromScale(0.5, 0.5) }, Enum.EasingStyle.Bounce)
	task.wait(0.6)

	chargePack(box, boxStroke, boxScale, question, rays, glow, rank, rarity.Color, 12 + math.max(0, rank - 2) * 4, 0.12)
	burstPack(dim, box, packColor, rank, rarity.Color)
	playSound(revealSoundKey(rank, mutationId ~= "Normal"))
	if rank >= 6 then
		-- Mythisch: großer Schriftzug knallt oben rein
		local slam = label({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.new(0.8, 0, 0, 90),
			Position = UDim2.fromScale(0.5, 0.13),
			Font = Enum.Font.FredokaOne,
			TextColor3 = rarity.Color,
			TextStrokeTransparency = 0,
			Text = string.upper(rarity.Name) .. "!!",
			ZIndex = 6,
			Parent = dim,
		})
		local slamScale = Instance.new("UIScale")
		slamScale.Scale = 3
		slamScale.Parent = slam
		tween(slamScale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	end
	for _, r in rays:GetChildren() do
		if r:IsA("Frame") then
			r.BackgroundColor3 = rarity.Color
			r.BackgroundTransparency = 0.45
		end
	end
	tween(rays, 0.5, { Size = UDim2.fromOffset(if isLegendary then 900 else 650, if isLegendary then 900 else 650) })
	glow.BackgroundColor3 = mutation.Color or rarity.Color
	tween(glow, 0.5, { Size = UDim2.fromOffset(460, 460), BackgroundTransparency = 0.75 })

	-- Reveal-Karte dreht sich auf (Breite 0 -> voll sieht aus wie ein Umdrehen)
	local card = Instance.new("Frame")
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.Size = UDim2.fromOffset(0, 340)
	card.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
	card.ClipsDescendants = true
	card.Parent = dim
	corner(card, 18)
	if isLegendary then
		animatedBorder(card, mutation.Color or rarity.Color, 7)
	else
		stroke(card, mutation.Color or rarity.Color, 6)
	end
	tween(card, 0.45, { Size = UDim2.fromOffset(340, 340) }, Enum.EasingStyle.Back)
	shineOnce(card, 0.5)

	label({
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundTransparency = 0,
		BackgroundColor3 = rarity.Color,
		Font = Enum.Font.FredokaOne,
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeTransparency = 0.3,
		Text = string.upper(rarity.Name) .. "!",
		Parent = card,
	})

	local _, iconScale = creatureIcon(card, def, mutationId, 136, 40)
	task.delay(0.25, function()
		tween(iconScale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
	end)

	label({
		Size = UDim2.new(1, -20, 0, 36),
		Position = UDim2.new(0, 10, 0, 180),
		Font = Enum.Font.FredokaOne,
		TextColor3 = rarity.Color,
		TextStrokeTransparency = 0.5,
		Text = Config.EntryName(entry),
		Parent = card,
	})
	if mutation.Name ~= "" then
		local mutationLabel = label({
			Size = UDim2.new(1, -40, 0, 24),
			Position = UDim2.new(0, 20, 0, 218),
			BackgroundTransparency = 0,
			BackgroundColor3 = mutation.Color or Color3.new(1, 1, 1),
			Font = Enum.Font.FredokaOne,
			TextColor3 = Color3.new(0, 0, 0),
			Text = `{string.upper(mutation.Name)} x{mutation.Multiplier}`,
			Parent = card,
		})
		corner(mutationLabel, 8)
		if mutationId == "Regenbogen" then
			CollectionService:AddTag(mutationLabel, "RainbowGui")
		end
	end
	label({
		Size = UDim2.new(1, -20, 0, 28),
		Position = UDim2.new(0, 10, 0, 248),
		TextColor3 = Color3.fromRGB(130, 255, 130),
		Text = `+{Config.FormatNumber(Config.EntryIncome(entry))} $/s`,
		Parent = card,
	})
	label({
		Size = UDim2.new(1, -20, 0, 18),
		Position = UDim2.new(0, 10, 1, -28),
		TextColor3 = Color3.fromRGB(180, 180, 190),
		Text = if wasPity then "Pity-Garantie! · Klicken zum Schließen" else "Klicken zum Schließen",
		Parent = card,
	})

	if isEpic or mutationId ~= "Normal" then
		confetti(if rank >= 6 then 200 elseif isLegendary then 140 else 60)
	end
	if rank >= 6 then
		-- Mythisch: zweite Welle Konfetti und Sterne
		task.delay(0.8, function()
			confetti(120)
			starBurst(UDim2.fromScale(0.5, 0.5), mutation.Color or rarity.Color, 30, 500)
		end)
	end

	-- Schließen per Klick oder automatisch
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
		tween(blur, 0.25, { Size = 0 }).Completed:Once(function()
			blur:Destroy()
		end)
		tween(card, 0.2, { Size = UDim2.fromOffset(0, 340) })
		task.wait(0.2)
		dim:Destroy()
		opening = false
		-- Shop wieder aufmachen, damit man direkt das nächste Pack öffnen kann
		updateShop()
		shop.Visible = true
	end
	task.delay(0.6, function()
		closeButtonOverlay.Activated:Connect(close)
	end)
	task.delay(if rank >= 6 then 8 elseif isLegendary then 6.5 else 4.5, close)
end

-- Mehrere Packs auf einmal: Pack platzt, dann drehen sich die Karten nacheinander um.
-- Mit "Überspringen" kommen alle restlichen Karten sofort.
local function openMultiAnimation(entries: { string }, packId: string, pities: { boolean }, soldCount: number)
	local pack = findPack(packId)
	local packColor = pack and pack.Color or Color3.new(1, 1, 1)
	-- beste Kreatur finden (bestimmt, wie heftig es wird)
	local bestRank, bestIndex = 0, 1
	for i, entry in entries do
		local def = Config.ParseEntry(entry)
		local rank = def and Config.RarityRank(def.Rarity) or 0
		if rank > bestRank then
			bestRank, bestIndex = rank, i
		end
	end
	local bestDef = Config.ParseEntry(entries[bestIndex])
	local bestRarity = bestDef and Config.Rarities[bestDef.Rarity] or Config.Rarities.Common
	local isEpic = bestRank >= Config.RarityRank("Epic")
	local isLegendary = bestRank >= Config.RarityRank("Legendary")
	opening = true
	shop.Visible = false

	local blur, dim, rays, glow = openingBackdrop(700)

	-- Stapel aus Packs fällt rein und lädt auf
	local box, boxStroke, boxScale, question = makePackBox(dim, pack and pack.Name or "Pack", `{#entries}x`, packColor, 170, 220)
	playSound("Swoosh", 0.7)
	tween(box, 0.55, { Position = UDim2.fromScale(0.5, 0.5) }, Enum.EasingStyle.Bounce)
	task.wait(0.55)
	chargePack(box, boxStroke, boxScale, question, rays, glow, bestRank, bestRarity.Color, 10 + math.max(0, bestRank - 2) * 3, 0.1)
	burstPack(dim, box, packColor, bestRank, bestRarity.Color)
	playSound("RevealCommon")
	tween(glow, 0.4, { BackgroundTransparency = 1 })

	-- Karten-Raster: alle in einer Reihe (bis 5) oder 5 x 2
	local perRow = if #entries <= 5 then #entries else 5
	local rowsCount = math.ceil(#entries / perRow)
	local cardW, cardH, gap = 150, 196, 14
	local grid = Instance.new("Frame")
	grid.AnchorPoint = Vector2.new(0.5, 0.5)
	grid.Position = UDim2.fromScale(0.5, 0.5)
	grid.Size = UDim2.fromOffset(perRow * cardW + (perRow - 1) * gap, rowsCount * cardH + (rowsCount - 1) * gap)
	grid.BackgroundTransparency = 1
	grid.Parent = dim
	local gridScale = Instance.new("UIScale")
	gridScale.Parent = grid
	local camera = workspace.CurrentCamera
	if camera then
		local view = camera.ViewportSize
		gridScale.Scale = math.min(1, (view.X - 40) / grid.Size.X.Offset, (view.Y - 180) / grid.Size.Y.Offset)
	end

	-- quiet = übersprungen: keine einzelnen Sounds und Effekte
	local function makeCard(i: number, entry: string, quiet: boolean)
		local def, mutationId = Config.ParseEntry(entry)
		if not def then
			return
		end
		local rarity = Config.Rarities[def.Rarity]
		local mutation = Config.Mutations[mutationId]
		local rank = Config.RarityRank(def.Rarity)
		local col = (i - 1) % perRow
		local row = math.floor((i - 1) / perRow)
		local holder = Instance.new("Frame")
		holder.AnchorPoint = Vector2.new(0.5, 0.5)
		holder.Position = UDim2.fromOffset(col * (cardW + gap) + cardW / 2, row * (cardH + gap) + cardH / 2)
		holder.Size = UDim2.fromOffset(0, cardH)
		holder.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
		holder.ClipsDescendants = true
		holder.Parent = grid
		corner(holder, 14)
		if rank >= Config.RarityRank("Legendary") then
			animatedBorder(holder, mutation.Color or rarity.Color, 6)
		else
			stroke(holder, mutation.Color or rarity.Color, if rank >= 4 then 6 else 4)
		end
		label({
			Size = UDim2.new(1, 0, 0, 24),
			BackgroundTransparency = 0,
			BackgroundColor3 = rarity.Color,
			Font = Enum.Font.FredokaOne,
			TextStrokeTransparency = 0.4,
			Text = string.upper(rarity.Name),
			Parent = holder,
		})
		local _, iconScale = creatureIcon(holder, def, mutationId, 80, 26)
		tween(iconScale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
		label({
			Size = UDim2.new(1, -12, 0, 28),
			Position = UDim2.new(0, 6, 0, 108),
			Font = Enum.Font.FredokaOne,
			TextColor3 = rarity.Color,
			TextStrokeTransparency = 0.5,
			Text = Config.EntryName(entry),
			Parent = holder,
		})
		if mutation.Name ~= "" then
			local mutationLabel = label({
				Size = UDim2.new(1, -24, 0, 18),
				Position = UDim2.new(0, 12, 0, 138),
				BackgroundTransparency = 0,
				BackgroundColor3 = mutation.Color or Color3.new(1, 1, 1),
				Font = Enum.Font.FredokaOne,
				TextColor3 = Color3.new(0, 0, 0),
				Text = `{string.upper(mutation.Name)} x{mutation.Multiplier}`,
				Parent = holder,
			})
			corner(mutationLabel, 6)
		end
		label({
			Size = UDim2.new(1, -12, 0, 22),
			Position = UDim2.new(0, 6, 1, -28),
			TextColor3 = Color3.fromRGB(130, 255, 130),
			Text = if pities[i] then `PITY! +{Config.FormatNumber(Config.EntryIncome(entry))} $/s` else `+{Config.FormatNumber(Config.EntryIncome(entry))} $/s`,
			Parent = holder,
		})
		-- Umdrehen mit kleinem Ploppen
		local pop = Instance.new("UIScale")
		pop.Scale = 1.2
		pop.Parent = holder
		tween(holder, 0.3, { Size = UDim2.fromOffset(cardW, cardH) }, Enum.EasingStyle.Back)
		tween(pop, 0.3, { Scale = 1 })
		if rank >= 4 or mutationId ~= "Normal" then
			shineOnce(holder, 0.3)
		end
		if quiet then
			return
		end
		local center = UDim2.fromOffset(
			holder.AbsolutePosition.X + holder.AbsoluteSize.X / 2,
			holder.AbsolutePosition.Y + holder.AbsoluteSize.Y / 2
		)
		if rank >= Config.RarityRank("Legendary") then
			playSound(revealSoundKey(rank, false))
			shake(if rank >= 6 then 7 else 5, 0.6)
			confetti(80)
			starBurst(center, rarity.Color, 30, 300)
		elseif rank >= Config.RarityRank("Epic") or mutationId ~= "Normal" then
			playSound("Epic")
			shake(2, 0.3)
			starBurst(center, mutation.Color or rarity.Color, 16, 180)
		elseif rank >= Config.RarityRank("Rare") then
			playSound("Rare")
		else
			playSound("Card", 0.9 + i * 0.05)
		end
	end

	-- Überspringen-Knopf
	local skip = false
	local skipButton = Instance.new("TextButton")
	skipButton.AnchorPoint = Vector2.new(0.5, 1)
	skipButton.Position = UDim2.new(0.5, 0, 1, -24)
	skipButton.Size = UDim2.fromOffset(220, 46)
	skipButton.BackgroundColor3 = Color3.fromRGB(255, 200, 60)
	skipButton.Font = Enum.Font.FredokaOne
	skipButton.TextScaled = true
	skipButton.TextColor3 = Color3.fromRGB(50, 35, 10)
	skipButton.Text = "Überspringen ⏩"
	skipButton.ZIndex = 5
	skipButton.Parent = dim
	corner(skipButton, 12)
	stroke(skipButton, Color3.new(1, 1, 1), 3).ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	skipButton.Activated:Connect(function()
		skip = true
		skipButton.Visible = false
	end)

	for i, entry in entries do
		makeCard(i, entry, skip)
		if not skip then
			local def = Config.ParseEntry(entry)
			local rank = def and Config.RarityRank(def.Rarity) or 0
			-- Seltene Karten: kurze Pause, damit man es feiert
			local waitTime = if rank >= 5 then 0.9 elseif rank >= 4 then 0.45 elseif rank >= 3 then 0.25 else 0.18
			local start = os.clock()
			while not skip and os.clock() - start < waitTime do
				task.wait()
			end
		end
	end
	skipButton:Destroy()
	if skip then
		-- übersprungen: die beste Karte trotzdem einmal feiern
		playSound(revealSoundKey(bestRank, false))
		if isLegendary then
			shake(5, 0.5)
		end
	end
	for _, r in rays:GetChildren() do
		if r:IsA("Frame") then
			r.BackgroundColor3 = bestRarity.Color
			r.BackgroundTransparency = 0.5
		end
	end
	if isEpic then
		confetti(if isLegendary then 120 else 50)
	end

	label({
		Size = UDim2.new(0, 520, 0, 26),
		Position = UDim2.new(0.5, -260, 1, -60),
		TextColor3 = Color3.fromRGB(200, 200, 210),
		Text = if soldCount > 0
			then `Base voll: {soldCount} schwächste automatisch verkauft · Klicken zum Schließen`
			else "Klicken zum Schließen",
		Parent = dim,
	})

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
		tween(blur, 0.25, { Size = 0 }).Completed:Once(function()
			blur:Destroy()
		end)
		tween(gridScale, 0.2, { Scale = 0.01 })
		task.wait(0.2)
		dim:Destroy()
		opening = false
		updateShop()
		shop.Visible = true
	end
	task.delay(0.4, function()
		closeButtonOverlay.Activated:Connect(close)
	end)
	task.delay(if isLegendary then 7 else 5, close)
end

Remotes.PackResult.OnClientEvent:Connect(function(entries: { string }, packId: string, pities: { boolean }, soldCount: number?)
	if opening or type(entries) ~= "table" or #entries == 0 then
		return
	end
	if #entries == 1 then
		task.spawn(openPackAnimation, entries[1], packId, pities[1])
	else
		task.spawn(openMultiAnimation, entries, packId, pities, soldCount or 0)
	end
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

-- Münzen auf der Straße drehen sich und hüpfen ---------------------------------
RunService.RenderStepped:Connect(function()
	local t = os.clock()
	for _, coin in CollectionService:GetTagged("SpinCoin") do
		if coin:IsA("BasePart") then
			local pos = coin.Position
			local baseY = coin:GetAttribute("BaseY") or pos.Y
			local phase = pos.X * 0.1 + pos.Z * 0.1
			coin.CFrame = CFrame.new(pos.X, baseY + math.sin(t * 3 + phase) * 0.4, pos.Z) * CFrame.Angles(0, t * 3 + phase, 0)
		end
	end
end)

-- Schwebende "+X $" in der Welt (Klick auf Kreatur, Münze) ----------------------
local squishing = {}
local function squish(model: Model)
	if squishing[model] then
		return
	end
	squishing[model] = true
	task.spawn(function()
		local ok = pcall(function()
			-- relativ zur jetzigen Größe (KI-Modelle sind schon skaliert)
			local base = model:GetScale()
			for _, s in { 1.12, 1.18, 1.08, 0.97, 1 } do
				model:ScaleTo(base * s)
				task.wait(0.03)
			end
		end)
		local _ = ok
		squishing[model] = nil
	end)
end

Remotes.Pop.OnClientEvent:Connect(function(amount: number, position: Vector3, model: Instance?, color: Color3?)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.CFrame = CFrame.new(position + Vector3.new((math.random() - 0.5) * 2, 0, (math.random() - 0.5) * 2))
	anchor.Parent = workspace
	local board = Instance.new("BillboardGui")
	board.Size = UDim2.fromOffset(160, 50)
	board.AlwaysOnTop = true
	board.LightInfluence = 0
	board.Parent = anchor
	local text = label({
		Size = UDim2.fromScale(1, 1),
		Font = Enum.Font.FredokaOne,
		TextColor3 = color or Color3.fromRGB(120, 255, 120),
		TextStrokeTransparency = 0,
		Text = `+{Config.FormatNumber(amount)} $`,
		Parent = board,
	})
	local popScale = Instance.new("UIScale")
	popScale.Scale = 0.4
	popScale.Parent = text
	tween(popScale, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
	tween(anchor, 0.9, { CFrame = anchor.CFrame + Vector3.new(0, 4, 0) })
	task.delay(0.4, function()
		tween(text, 0.5, { TextTransparency = 1, TextStrokeTransparency = 1 })
	end)
	task.delay(1, function()
		anchor:Destroy()
	end)
	if color then
		playSound("Coin", 0.9 + math.random() * 0.3)
	else
		playSound("Pop", 0.9 + math.random() * 0.25)
	end
	if model and model:IsA("Model") then
		squish(model)
	end
end)

-- Aufgaben (rechts) ---------------------------------------------------------------
local questBox = Instance.new("Frame")
questBox.Size = UDim2.fromOffset(300, 36)
questBox.Position = UDim2.new(1, -312, 0, 112)
questBox.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
questBox.BackgroundTransparency = 0.2
questBox.AutomaticSize = Enum.AutomaticSize.Y
questBox.Parent = gui
corner(questBox, 10)
local questPad = Instance.new("UIPadding")
questPad.PaddingTop = UDim.new(0, 6)
questPad.PaddingBottom = UDim.new(0, 8)
questPad.PaddingLeft = UDim.new(0, 8)
questPad.PaddingRight = UDim.new(0, 8)
questPad.Parent = questBox
local questLayout = Instance.new("UIListLayout")
questLayout.Padding = UDim.new(0, 6)
questLayout.SortOrder = Enum.SortOrder.LayoutOrder
questLayout.Parent = questBox
label({
	Size = UDim2.new(1, 0, 0, 24),
	Font = Enum.Font.FredokaOne,
	TextColor3 = Color3.fromRGB(255, 220, 60),
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "📜 Aufgaben",
	LayoutOrder = 0,
	Parent = questBox,
})
local questRows = {}
local lastProgress = {}

Remotes.Quests.OnClientEvent:Connect(function(list)
	for i, quest in list do
		local row = questRows[i]
		if not row then
			local frame = Instance.new("Frame")
			frame.Size = UDim2.new(1, 0, 0, 50)
			frame.BackgroundColor3 = Color3.fromRGB(40, 40, 58)
			frame.LayoutOrder = i
			frame.Parent = questBox
			corner(frame, 8)
			local text = label({
				Size = UDim2.new(0.7, -6, 0, 22),
				Position = UDim2.fromOffset(6, 3),
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = "",
				Parent = frame,
			})
			local reward = label({
				Size = UDim2.new(0.3, -6, 0, 22),
				Position = UDim2.new(0.7, 0, 0, 3),
				TextXAlignment = Enum.TextXAlignment.Right,
				TextColor3 = Color3.fromRGB(255, 220, 60),
				Text = "",
				Parent = frame,
			})
			local bar = Instance.new("Frame")
			bar.Size = UDim2.new(1, -12, 0, 16)
			bar.Position = UDim2.fromOffset(6, 29)
			bar.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
			bar.Parent = frame
			corner(bar, 8)
			local fill = Instance.new("Frame")
			fill.Size = UDim2.fromScale(0, 1)
			fill.BackgroundColor3 = Color3.fromRGB(80, 220, 120)
			fill.Parent = bar
			corner(fill, 8)
			local count = label({
				Size = UDim2.fromScale(1, 1),
				TextStrokeTransparency = 0.4,
				Text = "",
				ZIndex = 2,
				Parent = bar,
			})
			local scale = Instance.new("UIScale")
			scale.Parent = frame
			row = { Frame = frame, Text = text, Reward = reward, Fill = fill, Count = count, Scale = scale }
			questRows[i] = row
		end
		row.Frame.Visible = true
		local changedQuest = row.Text.Text ~= quest.Text
		row.Text.Text = quest.Text
		row.Reward.Text = `🎁 {Config.FormatNumber(quest.Reward)} $`
		row.Count.Text = `{Config.FormatNumber(quest.Progress)} / {Config.FormatNumber(quest.Goal)}`
		local ratio = math.clamp(quest.Progress / math.max(1, quest.Goal), 0, 1)
		if changedQuest then
			row.Fill.Size = UDim2.fromScale(ratio, 1)
			row.Scale.Scale = 0.6
			tween(row.Scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
		else
			tween(row.Fill, 0.2, { Size = UDim2.fromScale(ratio, 1) })
			if (lastProgress[i] or 0) < quest.Progress then
				row.Scale.Scale = 1.04
				tween(row.Scale, 0.15, { Scale = 1 })
			end
		end
		lastProgress[i] = quest.Progress
	end
	for i = #list + 1, #questRows do
		questRows[i].Frame.Visible = false
	end
end)

-- Wiedergeburt (Rebirth) ---------------------------------------------------------
local PURPLE = Color3.fromRGB(170, 90, 255)
local rebirthButton = Instance.new("TextButton")
rebirthButton.Size = UDim2.fromOffset(72, 72)
rebirthButton.Position = UDim2.new(0, 92, 0.5, 40)
rebirthButton.BackgroundColor3 = PURPLE
rebirthButton.Text = ""
rebirthButton.Parent = gui
corner(rebirthButton, 12)
stroke(rebirthButton, Color3.fromRGB(255, 255, 255), 2)
local rebirthButtonScale = Instance.new("UIScale")
rebirthButtonScale.Parent = rebirthButton
label({
	Size = UDim2.new(1, 0, 0.62, 0),
	Position = UDim2.fromScale(0, 0.04),
	Text = "🔄",
	Parent = rebirthButton,
})
label({
	Size = UDim2.new(1, -8, 0.3, 0),
	Position = UDim2.new(0, 4, 0.66, 0),
	Font = Enum.Font.FredokaOne,
	TextStrokeTransparency = 0.4,
	Text = "Rebirth",
	Parent = rebirthButton,
})

local rebirthPanel = Instance.new("Frame")
rebirthPanel.Size = UDim2.fromOffset(620, 450)
rebirthPanel.Position = UDim2.new(0.5, -310, 0.5, -225)
rebirthPanel.BackgroundColor3 = Color3.fromRGB(30, 25, 45)
rebirthPanel.Visible = false
rebirthPanel.Parent = gui
corner(rebirthPanel, 14)
stroke(rebirthPanel, PURPLE, 3)
local rebirthScale = Instance.new("UIScale")
rebirthScale.Parent = rebirthPanel

label({
	Size = UDim2.new(1, -70, 0, 40),
	Position = UDim2.fromOffset(16, 8),
	Font = Enum.Font.FredokaOne,
	TextColor3 = Color3.fromRGB(210, 160, 255),
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "🔄 Wiedergeburt",
	Parent = rebirthPanel,
})
local rebirthClose = Instance.new("TextButton")
rebirthClose.Size = UDim2.fromOffset(40, 40)
rebirthClose.Position = UDim2.new(1, -50, 0, 10)
rebirthClose.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
rebirthClose.Text = "X"
rebirthClose.TextColor3 = Color3.new(1, 1, 1)
rebirthClose.Font = Enum.Font.GothamBold
rebirthClose.TextScaled = true
rebirthClose.Parent = rebirthPanel
corner(rebirthClose, 8)

local rebirthInfo = label({
	Size = UDim2.new(1, -32, 0, 28),
	Position = UDim2.fromOffset(16, 52),
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = Color3.fromRGB(130, 255, 130),
	Text = "",
	Parent = rebirthPanel,
})
label({
	Size = UDim2.new(1, -32, 0, 36),
	Position = UDim2.fromOffset(16, 82),
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	TextColor3 = Color3.fromRGB(200, 200, 215),
	TextWrapped = true,
	Font = Enum.Font.Gotham,
	Text = `Du behältst deine {Config.Rebirth.KeepCreatures} besten Kreaturen. Geld und Base-Stufe gehen zurück auf Anfang. Dafür: für immer mehr Einkommen und +{Config.Rebirth.TokensPerRebirth} Tokens.`,
	Parent = rebirthPanel,
})
local costBar = Instance.new("Frame")
costBar.Size = UDim2.new(1, -32, 0, 26)
costBar.Position = UDim2.fromOffset(16, 124)
costBar.BackgroundColor3 = Color3.fromRGB(15, 15, 22)
costBar.Parent = rebirthPanel
corner(costBar, 10)
local costFill = Instance.new("Frame")
costFill.Size = UDim2.fromScale(0, 1)
costFill.BackgroundColor3 = PURPLE
costFill.Parent = costBar
corner(costFill, 10)
local costText = label({
	Size = UDim2.fromScale(1, 1),
	TextStrokeTransparency = 0.3,
	ZIndex = 2,
	Text = "",
	Parent = costBar,
})
local doRebirth = Instance.new("TextButton")
doRebirth.Size = UDim2.new(1, -32, 0, 52)
doRebirth.Position = UDim2.fromOffset(16, 158)
doRebirth.BackgroundColor3 = PURPLE
doRebirth.TextColor3 = Color3.new(1, 1, 1)
doRebirth.Font = Enum.Font.FredokaOne
doRebirth.TextScaled = true
doRebirth.Text = "WIEDERGEBURT!"
doRebirth.Parent = rebirthPanel
corner(doRebirth, 12)
local tokenLabel = label({
	Size = UDim2.new(1, -32, 0, 28),
	Position = UDim2.fromOffset(16, 220),
	Font = Enum.Font.FredokaOne,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = Color3.fromRGB(120, 220, 255),
	Text = "",
	Parent = rebirthPanel,
})

local upgradeRow = Instance.new("Frame")
upgradeRow.Size = UDim2.new(1, -24, 0, 180)
upgradeRow.Position = UDim2.fromOffset(12, 256)
upgradeRow.BackgroundTransparency = 1
upgradeRow.Parent = rebirthPanel
local upgradeLayout = Instance.new("UIListLayout")
upgradeLayout.FillDirection = Enum.FillDirection.Horizontal
upgradeLayout.Padding = UDim.new(0, 10)
upgradeLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
upgradeLayout.Parent = upgradeRow

local upgradeCards = {}
for _, id in Config.Rebirth.UpgradeOrder do
	local info = Config.Rebirth.Upgrades[id]
	local card = Instance.new("Frame")
	card.Size = UDim2.new(1 / #Config.Rebirth.UpgradeOrder, -8, 1, 0)
	card.BackgroundColor3 = Color3.fromRGB(45, 40, 65)
	card.Parent = upgradeRow
	corner(card, 12)
	label({
		Size = UDim2.new(1, -12, 0, 30),
		Position = UDim2.fromOffset(6, 6),
		Font = Enum.Font.FredokaOne,
		Text = `{info.Icon} {info.Name}`,
		Parent = card,
	})
	label({
		Size = UDim2.new(1, -16, 0, 36),
		Position = UDim2.fromOffset(8, 38),
		Font = Enum.Font.Gotham,
		TextWrapped = true,
		TextColor3 = Color3.fromRGB(200, 200, 215),
		Text = info.Desc,
		Parent = card,
	})
	local levelLabel = label({
		Size = UDim2.new(1, -16, 0, 22),
		Position = UDim2.fromOffset(8, 80),
		TextColor3 = Color3.fromRGB(255, 220, 60),
		Text = "",
		Parent = card,
	})
	local buy = Instance.new("TextButton")
	buy.Size = UDim2.new(1, -16, 0, 50)
	buy.Position = UDim2.new(0, 8, 1, -58)
	buy.TextColor3 = Color3.new(1, 1, 1)
	buy.Font = Enum.Font.FredokaOne
	buy.TextScaled = true
	buy.Text = ""
	buy.Parent = card
	corner(buy, 10)
	buy.Activated:Connect(function()
		playSound("Click")
		Remotes.BuyUpgrade:FireServer(id)
	end)
	upgradeCards[id] = { Level = levelLabel, Button = buy, Info = info }
end

local function updateRebirth()
	local rebirths = player:GetAttribute("Rebirths") or 0
	local money = player:GetAttribute("Money") or 0
	local tokens = player:GetAttribute("Tokens") or 0
	local cost = Config.RebirthCost(rebirths)
	rebirthInfo.Text = `Wiedergeburten: {rebirths}   ·   Einkommen x{Config.RebirthMultiplier(rebirths)} → x{Config.RebirthMultiplier(rebirths + 1)}`
	costFill.Size = UDim2.fromScale(math.clamp(money / cost, 0, 1), 1)
	costText.Text = `{Config.FormatNumber(money)} / {Config.FormatNumber(cost)} $`
	doRebirth.BackgroundColor3 = if money >= cost then PURPLE else Color3.fromRGB(90, 90, 100)
	tokenLabel.Text = `💠 Tokens: {tokens}`
	for id, card in upgradeCards do
		local level = player:GetAttribute("Up_" .. id) or 0
		local info = card.Info
		card.Level.Text = `Stufe {level} / {info.Max}`
		if level >= info.Max then
			card.Button.Text = "MAX"
			card.Button.BackgroundColor3 = Color3.fromRGB(200, 160, 40)
		else
			local price = info.Costs[level + 1]
			card.Button.Text = `Kaufen: {price} 💠`
			card.Button.BackgroundColor3 = if tokens >= price then Color3.fromRGB(60, 200, 90) else Color3.fromRGB(90, 90, 100)
		end
	end
end
for _, attr in { "Money", "Rebirths", "Tokens", "Up_Luck", "Up_Magnet", "Up_ClickPower" } do
	player:GetAttributeChangedSignal(attr):Connect(function()
		if rebirthPanel.Visible then
			updateRebirth()
		end
	end)
end

-- Sicherheitsabfrage: zweimal klicken
local confirmUntil = 0
doRebirth.Activated:Connect(function()
	local rebirths = player:GetAttribute("Rebirths") or 0
	if (player:GetAttribute("Money") or 0) < Config.RebirthCost(rebirths) then
		playSound("Click", 0.6)
		return
	end
	if os.clock() > confirmUntil then
		confirmUntil = os.clock() + 3
		doRebirth.Text = "SICHER? NOCHMAL KLICKEN!"
		playSound("Click")
		task.delay(3, function()
			if os.clock() >= confirmUntil then
				doRebirth.Text = "WIEDERGEBURT!"
			end
		end)
		return
	end
	confirmUntil = 0
	doRebirth.Text = "WIEDERGEBURT!"
	Remotes.Rebirth:FireServer()
	rebirthPanel.Visible = false
end)

local function toggleRebirth()
	if opening then
		return
	end
	rebirthPanel.Visible = not rebirthPanel.Visible
	if rebirthPanel.Visible then
		shop.Visible = false
		updateRebirth()
		local camera = workspace.CurrentCamera
		if camera then
			local size = camera.ViewportSize
			rebirthScale.Scale = math.min(1, size.X / 660, size.Y / 490)
		end
		rebirthScale.Scale *= 0.8
		tween(rebirthScale, 0.25, { Scale = rebirthScale.Scale / 0.8 }, Enum.EasingStyle.Back)
	end
	playSound("Click")
end
rebirthButton.Activated:Connect(toggleRebirth)
rebirthClose.Activated:Connect(function()
	rebirthPanel.Visible = false
end)
shop:GetPropertyChangedSignal("Visible"):Connect(function()
	if shop.Visible then
		rebirthPanel.Visible = false
	end
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.R then
		toggleRebirth()
	end
end)

-- Rebirth-Knopf pulsiert, sobald man sich die Wiedergeburt leisten kann
task.spawn(function()
	while true do
		local cost = Config.RebirthCost(player:GetAttribute("Rebirths") or 0)
		if (player:GetAttribute("Money") or 0) >= cost and not rebirthPanel.Visible then
			tween(rebirthButtonScale, 0.35, { Scale = 1.15 }).Completed:Wait()
			tween(rebirthButtonScale, 0.35, { Scale = 1 }).Completed:Wait()
		else
			task.wait(0.5)
		end
	end
end)

print(`[Client] Hallo {player.Name}, willkommen bei {Config.GameName}!`)
