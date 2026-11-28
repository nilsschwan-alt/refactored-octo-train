-- Client-Skript: alles, was der Spieler sieht.
-- Geld-Anzeige, Meldungen, große Texte, Server-Ansagen mit Konfetti, Geld-Popups,
-- Event-Countdown, Pack-Shop mit Chancen, Pack-Öffnung, Regenbogen-Farben,
-- welche E-Knöpfe man sieht und Hausdächer, die verschwinden, wenn man im Haus steht.
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
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)

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

-- Von jedem Geräusch liegt ein fertig geladenes Exemplar bereit. Ohne das lädt Roblox den Ton
-- bei jedem Abspielen neu, und er kommt etwa eine Drittelsekunde zu spät.
local soundBank = Instance.new("Folder")
soundBank.Name = "SoundVorrat"
soundBank.Parent = SoundService
local soundTemplates: { [string]: Sound } = {}
for name, id in Config.SoundSamples do
	local template = Instance.new("Sound")
	template.Name = name
	template.SoundId = id
	template.Parent = soundBank
	soundTemplates[name] = template
end
local function newSound(sample: string): Sound?
	local template = soundTemplates[sample]
	return if template then template:Clone() else nil
end

-- Spielt eine kleine Melodie aus Config.Sounds (pitch = zusätzliche Tonhöhe)
local function playSound(key: string?, pitch: number?)
	local melody = key and Config.Sounds[key]
	if not melody then
		return
	end
	for _, note in melody do
		if soundTemplates[note[1]] then
			task.delay(note[4] or 0, function()
				local sound = newSound(note[1]) :: Sound
				sound.PlaybackSpeed = (note[2] or 1) * (pitch or 1)
				sound.Volume = note[3] or 0.5
				sound.Parent = SoundService
				sound:Play()
				sound.Ended:Once(function()
					sound:Destroy()
				end)
				if note[5] then
					-- lange Sounds nach ihrer kräftigen Stelle ausblenden
					task.delay(note[5], function()
						if sound.Parent then
							TweenService:Create(sound, TweenInfo.new(0.35), { Volume = 0 }):Play()
							task.wait(0.4)
							sound:Destroy()
						end
					end)
				end
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
	incomeLabel.Text = `+{Config.FormatRate(player:GetAttribute("Income") or 0)} $/s automatisch`
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

-- Vorderseite eines Packs: Folie, Streifen, Name, "?" und ein Glanz, der drüberläuft.
-- Wird fürs 3D-Pack und für die Rückseiten der Karten benutzt.
local function packFace(parent: Instance, title: string, bigText: string, packColor: Color3, radius: number?): Frame
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = packColor
	bg.BorderSizePixel = 0
	bg.ClipsDescendants = true
	bg.Parent = parent
	if radius then
		corner(bg, radius)
	end
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(WHITE, packColor:Lerp(BLACK, 0.4))
	gradient.Rotation = 90
	gradient.Parent = bg
	if not radius then
		-- helle Streifen oben und unten (nur beim eckigen 3D-Pack, bei runden Karten stehen sie über)
		for _, yScale in { 0, 1 } do
			local strip = Instance.new("Frame")
			strip.AnchorPoint = Vector2.new(0, yScale)
			strip.Position = UDim2.fromScale(0, yScale)
			strip.Size = UDim2.fromScale(1, 0.06)
			strip.BackgroundColor3 = WHITE
			strip.BackgroundTransparency = 0.35
			strip.BorderSizePixel = 0
			strip.Parent = bg
		end
	end
	if title ~= "" then
		label({
			Size = UDim2.fromScale(0.9, 0.16),
			Position = UDim2.fromScale(0.05, 0.09),
			Font = Enum.Font.FredokaOne,
			TextStrokeTransparency = 0.3,
			Text = title,
			Parent = bg,
		})
	end
	local circle = Instance.new("Frame")
	circle.AnchorPoint = Vector2.new(0.5, 0.5)
	circle.Position = UDim2.fromScale(0.5, 0.58)
	circle.Size = UDim2.fromScale(0.62, 0.62)
	circle.SizeConstraint = Enum.SizeConstraint.RelativeXX
	circle.BackgroundColor3 = WHITE
	circle.BackgroundTransparency = 0.8
	circle.BorderSizePixel = 0
	circle.Parent = bg
	corner(circle, 2000)
	stroke(circle, WHITE, 3)
	label({
		Size = UDim2.fromScale(1, 0.42),
		Position = UDim2.fromScale(0, 0.37),
		Font = Enum.Font.FredokaOne,
		TextStrokeTransparency = 0.3,
		Text = bigText,
		ZIndex = 2,
		Parent = bg,
	})
	local shine = Instance.new("Frame")
	shine.Size = UDim2.fromScale(1, 1)
	shine.BackgroundColor3 = WHITE
	shine.BorderSizePixel = 0
	shine.ZIndex = 3
	shine.Parent = bg
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
	return bg
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

-- Kisten-Shop ---------------------------------------------------------------------
-- Links die Liste aller Kisten (gesperrte mit Schloss), rechts die gewählte Kiste groß in
-- 3D, die Kreaturen, die drinstecken, und die Kauf-Knöpfe.
local SHOP_W, SHOP_H = 900, 560
local SHOP_DARK = Color3.fromRGB(26, 22, 52)
local SHOP_GREEN = Color3.fromRGB(60, 200, 90)
local shop = Instance.new("Frame")
shop.AnchorPoint = Vector2.new(0.5, 0.5)
shop.Size = UDim2.fromOffset(SHOP_W, SHOP_H)
shop.Position = UDim2.fromScale(0.5, 0.5)
shop.BackgroundColor3 = WHITE
shop.Visible = false
shop.Parent = gui
corner(shop, 22)
stroke(shop, WHITE, 4)
local shopGradient = Instance.new("UIGradient")
shopGradient.Color = ColorSequence.new(Color3.fromRGB(72, 54, 140), SHOP_DARK)
shopGradient.Rotation = 90
shopGradient.Parent = shop
local shopScale = Instance.new("UIScale")
shopScale.Parent = shop

label({
	Size = UDim2.fromOffset(300, 44),
	Position = UDim2.fromOffset(22, 12),
	Font = Enum.Font.FredokaOne,
	TextColor3 = Color3.fromRGB(255, 225, 80),
	TextStrokeTransparency = 0.3,
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "✨ KISTEN-SHOP",
	Parent = shop,
})

-- Glücks-Garantie als Balken: füllt sich mit jeder Kiste ohne Legendär
local pityBar = Instance.new("Frame")
pityBar.Size = UDim2.fromOffset(430, 30)
pityBar.Position = UDim2.new(1, -500, 0, 19)
pityBar.BackgroundColor3 = Color3.fromRGB(20, 16, 40)
pityBar.Parent = shop
corner(pityBar, 15)
stroke(pityBar, Color3.fromRGB(255, 200, 60), 2)
local pityFill = Instance.new("Frame")
pityFill.Size = UDim2.fromScale(0, 1)
pityFill.BackgroundColor3 = Color3.fromRGB(255, 190, 40)
pityFill.Parent = pityBar
corner(pityFill, 15)
local pityFillGradient = Instance.new("UIGradient")
pityFillGradient.Color = ColorSequence.new(Color3.fromRGB(255, 240, 150), Color3.fromRGB(255, 150, 30))
pityFillGradient.Rotation = 90
pityFillGradient.Parent = pityFill
local pityLabel = label({
	Size = UDim2.new(1, -16, 1, -8),
	Position = UDim2.fromOffset(8, 4),
	Font = Enum.Font.FredokaOne,
	TextStrokeTransparency = 0.2,
	Text = "",
	ZIndex = 2,
	Parent = pityBar,
})
stroke(pityLabel, BLACK, 2)

local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.fromOffset(42, 42)
closeButton.Position = UDim2.new(1, -56, 0, 13)
closeButton.BackgroundColor3 = Color3.fromRGB(235, 70, 80)
closeButton.Text = "X"
closeButton.TextColor3 = WHITE
closeButton.Font = Enum.Font.FredokaOne
closeButton.TextScaled = true
closeButton.Parent = shop
corner(closeButton, 21)
stroke(closeButton, WHITE, 3).ApplyStrokeMode = Enum.ApplyStrokeMode.Border
closeButton.Activated:Connect(function()
	shop.Visible = false
end)

-- 3D-Modell einer Kiste (aus ReplicatedStorage.PackModelle), falls es eins gibt
local function packTemplate(pack): Model?
	local folder = ReplicatedStorage:FindFirstChild("PackModelle")
	local template = folder and folder:FindFirstChild(pack.Id)
	return if template and template:IsA("Model") then template else nil
end

-- ViewportFrame mit der Kiste drin. Gibt das Fenster, das Modell und dessen Höhe zurück.
local function packViewport(template: Model, size: number): (ViewportFrame, Model, number)
	local vp = Instance.new("ViewportFrame")
	vp.Size = UDim2.fromOffset(size, size)
	vp.BackgroundTransparency = 1
	vp.Ambient = Color3.fromRGB(170, 170, 185)
	vp.LightColor = WHITE
	vp.LightDirection = Vector3.new(-0.3, -0.8, 1)
	local model = template:Clone()
	model:PivotTo(CFrame.new())
	model.Parent = vp
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	camera.Parent = vp
	vp.CurrentCamera = camera
	local boxCF, boxSize = model:GetBoundingBox()
	local center = boxCF.Position
	local radius = math.max(boxSize.X, boxSize.Y, boxSize.Z) * 0.68
	local dist = radius / math.tan(math.rad(camera.FieldOfView / 2))
	camera.CFrame = CFrame.lookAt(center + Vector3.new(0, boxSize.Y * 0.35, -dist), center)
	return vp, model, boxSize.Y
end

-- Große Vorschau einer Kiste: das 3D-Modell dreht sich langsam. Gibt es (noch) kein Modell,
-- sieht man eine schräge Tafel, die wippt.
local function packPreview(parent: GuiObject, pack, size: number, centerY: number)
	local glow = Instance.new("Frame")
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.new(0.5, 0, 0, centerY)
	glow.Size = UDim2.fromOffset(size * 0.9, size * 0.9)
	glow.BackgroundColor3 = pack.Color
	glow.BackgroundTransparency = 0.7
	glow.BorderSizePixel = 0
	glow.Parent = parent
	corner(glow, size)
	local rays = sunburst(parent, pack.Color, size * 1.1)
	rays.Position = UDim2.new(0.5, 0, 0, centerY)
	for _, r in rays:GetChildren() do
		if r:IsA("Frame") then
			r.Size = UDim2.new(0, 12, 1, 0)
			r.BackgroundTransparency = 0.8
		end
	end

	local template = packTemplate(pack)
	if template then
		local vp, model, height = packViewport(template, size)
		vp.AnchorPoint = Vector2.new(0.5, 0.5)
		vp.Position = UDim2.new(0.5, 0, 0, centerY)
		vp.Parent = parent
		task.spawn(function()
			while vp.Parent do
				if shop.Visible then
					local t = os.clock()
					model:PivotTo(CFrame.new(0, math.sin(t * 2) * height * 0.04, 0) * CFrame.Angles(0, t * 0.9, 0))
				end
				RunService.RenderStepped:Wait()
			end
		end)
		return
	end

	local holder = Instance.new("Frame")
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.new(0.5, 0, 0, centerY)
	holder.Size = UDim2.fromOffset(size * 0.6, size * 0.82)
	holder.BackgroundTransparency = 1
	holder.Rotation = -7
	holder.Parent = parent
	packFace(holder, "", "?", pack.Color, 10)
	stroke(holder, WHITE, 3)
	corner(holder, 10)
	task.spawn(function()
		while holder.Parent do
			if shop.Visible then
				local t = os.clock()
				holder.Position = UDim2.new(0.5, 0, 0, centerY + math.sin(t * 2) * 4)
				holder.Rotation = -7 + math.sin(t * 1.3) * 3
			end
			RunService.RenderStepped:Wait()
		end
	end)
end

local function percentText(percent: number): string
	return if percent < 1 then string.format("%.1f %%", percent) else string.format("%d %%", math.floor(percent + 0.5))
end

-- Liste links ---------------------------------------------------------------------
local SHOP_ROW_H = 76
local shopList = Instance.new("ScrollingFrame")
shopList.Size = UDim2.fromOffset(240, SHOP_H - 84)
shopList.Position = UDim2.fromOffset(16, 68)
shopList.BackgroundColor3 = Color3.fromRGB(18, 15, 36)
shopList.BackgroundTransparency = 0.35
shopList.BorderSizePixel = 0
shopList.ScrollBarThickness = 6
shopList.ScrollingDirection = Enum.ScrollingDirection.Y
shopList.CanvasSize = UDim2.fromOffset(0, #Config.Packs * SHOP_ROW_H + 8)
shopList.Parent = shop
corner(shopList, 14)

-- Rechte Seite: die gewählte Kiste
local shopDetail = Instance.new("Frame")
shopDetail.Size = UDim2.fromOffset(SHOP_W - 284, SHOP_H - 84)
shopDetail.Position = UDim2.fromOffset(268, 68)
shopDetail.BackgroundColor3 = WHITE
shopDetail.Parent = shop
corner(shopDetail, 16)
local detailStroke = stroke(shopDetail, WHITE, 3)
local detailGradient = Instance.new("UIGradient")
detailGradient.Rotation = 90
detailGradient.Parent = shopDetail

local selectedPack = Config.Packs[1]
local shopBuilt = false -- Liste und rechte Seite werden beim ersten Öffnen gebaut
local shopRows = {}
local detailContent: Frame? = nil
local detailButtons = {} -- { Button, Price }
local detailChances = {} -- { Label, Rarity, Share }
local updateShop -- kommt weiter unten

-- Rechte Seite für eine Kiste neu aufbauen
local function buildDetail(pack)
	if detailContent then
		detailContent:Destroy()
	end
	detailButtons, detailChances = {}, {}
	local rebirths = player:GetAttribute("Rebirths") or 0
	local unlocked = Config.PackUnlocked(pack, rebirths)
	local width = shopDetail.Size.X.Offset
	detailStroke.Color = pack.Color
	detailGradient.Color = ColorSequence.new(pack.Color:Lerp(SHOP_DARK, 0.5), SHOP_DARK)

	local content = Instance.new("Frame")
	content.Size = UDim2.fromScale(1, 1)
	content.BackgroundTransparency = 1
	content.Parent = shopDetail
	detailContent = content

	-- große Kiste links oben
	local stage = Instance.new("Frame")
	stage.Size = UDim2.fromOffset(230, 212)
	stage.Position = UDim2.fromOffset(8, 4)
	stage.BackgroundTransparency = 1
	stage.Parent = content
	packPreview(stage, pack, 200, 108)

	local nameLabel = label({
		Size = UDim2.fromOffset(width - 262, 46),
		Position = UDim2.fromOffset(248, 14),
		Font = Enum.Font.FredokaOne,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = pack.Name,
		ZIndex = 2,
		Parent = content,
	})
	stroke(nameLabel, pack.Color:Lerp(BLACK, 0.65), 3)
	label({
		Size = UDim2.fromOffset(width - 262, 22),
		Position = UDim2.fromOffset(248, 62),
		Font = Enum.Font.GothamBold,
		TextColor3 = Color3.fromRGB(215, 210, 240),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = `{#pack.Creatures} eigene Kreaturen  ·  {Config.FormatNumber(pack.Price)} $ pro Kiste`,
		ZIndex = 2,
		Parent = content,
	})

	if unlocked then
		-- 1x / 3x / 10x
		local buttonRow = Instance.new("Frame")
		buttonRow.Size = UDim2.fromOffset(width - 262, 76)
		buttonRow.Position = UDim2.fromOffset(248, 100)
		buttonRow.BackgroundTransparency = 1
		buttonRow.Parent = content
		local buttonLayout = Instance.new("UIListLayout")
		buttonLayout.FillDirection = Enum.FillDirection.Horizontal
		buttonLayout.Padding = UDim.new(0, 8)
		buttonLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
		buttonLayout.Parent = buttonRow
		for _, option in Config.PackCounts do
			local cost = Config.PackCost(pack, option.Count)
			local buy = Instance.new("TextButton")
			buy.Size = UDim2.new(1 / #Config.PackCounts, -6, 1, 0)
			buy.BackgroundColor3 = SHOP_GREEN
			buy.TextColor3 = WHITE
			buy.Font = Enum.Font.FredokaOne
			buy.TextScaled = true
			buy.TextStrokeTransparency = 0.4
			buy.Text = `{option.Count}x\n{Config.FormatNumber(cost)} $`
			buy.Parent = buttonRow
			corner(buy, 14)
			stroke(buy, WHITE, 2).ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			local buyGradient = Instance.new("UIGradient")
			buyGradient.Color = ColorSequence.new(WHITE, Color3.fromRGB(190, 190, 190))
			buyGradient.Rotation = 90
			buyGradient.Parent = buy
			local pad = Instance.new("UIPadding")
			pad.PaddingTop = UDim.new(0, 7)
			pad.PaddingBottom = UDim.new(0, 7)
			pad.PaddingLeft = UDim.new(0, 6)
			pad.PaddingRight = UDim.new(0, 6)
			pad.Parent = buy
			if option.Discount < 1 then
				local tag = label({
					Size = UDim2.fromOffset(54, 22),
					Position = UDim2.new(1, -44, 0, -14),
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
			table.insert(detailButtons, { Button = buy, Price = cost })
		end
		label({
			Size = UDim2.fromOffset(width - 262, 18),
			Position = UDim2.fromOffset(248, 184),
			Font = Enum.Font.Gotham,
			TextColor3 = Color3.fromRGB(185, 180, 215),
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = "Base voll? Dann bleiben die besten, der Rest wird verkauft.",
			Parent = content,
		})
	else
		-- gesperrt: zeigen, was man dafür tun muss
		local lock = Instance.new("Frame")
		lock.Size = UDim2.fromOffset(width - 262, 100)
		lock.Position = UDim2.fromOffset(248, 100)
		lock.BackgroundColor3 = Color3.fromRGB(60, 30, 95)
		lock.Parent = content
		corner(lock, 14)
		stroke(lock, Color3.fromRGB(200, 120, 255), 2)
		label({
			Size = UDim2.new(1, -20, 0, 40),
			Position = UDim2.fromOffset(10, 10),
			Font = Enum.Font.FredokaOne,
			TextStrokeTransparency = 0.4,
			Text = `🔒 Ab Wiedergeburt {pack.Rebirths}`,
			Parent = lock,
		})
		local missing = pack.Rebirths - rebirths
		label({
			Size = UDim2.new(1, -20, 0, 34),
			Position = UDim2.fromOffset(10, 56),
			Font = Enum.Font.GothamBold,
			TextColor3 = Color3.fromRGB(225, 200, 255),
			TextWrapped = true,
			Text = if missing == 1
				then "Noch 1 Wiedergeburt. Die machst du mit dem Rebirth-Knopf oder Taste R."
				else `Noch {missing} Wiedergeburten. Die machst du mit dem Rebirth-Knopf oder Taste R.`,
			Parent = lock,
		})
	end

	-- Kreaturen dieser Kiste, die schwächste links, die seltenste rechts
	label({
		Size = UDim2.fromOffset(300, 22),
		Position = UDim2.fromOffset(16, 216),
		Font = Enum.Font.FredokaOne,
		TextColor3 = Color3.fromRGB(255, 225, 80),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "Das steckt drin:",
		Parent = content,
	})
	local creatures = table.clone(pack.Creatures)
	table.sort(creatures, function(a, b)
		if a.Rarity ~= b.Rarity then
			return Config.RarityRank(a.Rarity) < Config.RarityRank(b.Rarity)
		end
		return a.Income < b.Income
	end)
	local share = {}
	for _, def in creatures do
		share[def.Rarity] = (share[def.Rarity] or 0) + 1
	end
	local count = math.max(1, #creatures)
	local gap = 8
	local tileW = math.min(112, math.floor((width - 28 - (count - 1) * gap) / count))
	local startX = math.floor((width - (count * tileW + (count - 1) * gap)) / 2)
	for i, def in creatures do
		local rarity = Config.Rarities[def.Rarity]
		local tile = Instance.new("Frame")
		tile.Size = UDim2.fromOffset(tileW, 224)
		tile.Position = UDim2.fromOffset(startX + (i - 1) * (tileW + gap), 242)
		tile.BackgroundColor3 = Color3.fromRGB(18, 15, 36)
		tile.BackgroundTransparency = 0.2
		tile.Parent = content
		corner(tile, 12)
		stroke(tile, rarity.Color, 2)
		local iconSize = math.min(tileW - 10, 88)
		local _, iconScale = creatureIcon(tile, def, "Normal", iconSize, 6)
		task.delay(i * 0.04, function()
			tween(iconScale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
		end)
		-- Lange Namen brechen am Bindestrich um, statt winzig zu werden
		local nameLabel = label({
			Size = UDim2.new(1, -6, 0, 38),
			Position = UDim2.fromOffset(3, 96),
			Font = Enum.Font.FredokaOne,
			TextWrapped = true,
			Text = (string.gsub(def.Name, "%-", "-\n", 1)),
			Parent = tile,
		})
		local nameLimit = Instance.new("UITextSizeConstraint")
		nameLimit.MinTextSize = 12
		nameLimit.MaxTextSize = 17
		nameLimit.Parent = nameLabel
		local rarityLabel = label({
			Size = UDim2.new(1, -6, 0, 18),
			Position = UDim2.fromOffset(3, 136),
			Font = Enum.Font.GothamBold,
			TextColor3 = rarity.Color,
			Text = rarity.Name,
			Parent = tile,
		})
		local rarityLimit = Instance.new("UITextSizeConstraint")
		rarityLimit.MinTextSize = 11
		rarityLimit.MaxTextSize = 15
		rarityLimit.Parent = rarityLabel
		local chance = label({
			Size = UDim2.new(1, -8, 0, 24),
			Position = UDim2.fromOffset(4, 156),
			Font = Enum.Font.FredokaOne,
			Text = "",
			Parent = tile,
		})
		table.insert(detailChances, { Label = chance, Rarity = def.Rarity, Share = share[def.Rarity] })
		label({
			Size = UDim2.new(1, -8, 0, 22),
			Position = UDim2.fromOffset(4, 190),
			Font = Enum.Font.GothamBold,
			TextColor3 = Color3.fromRGB(120, 255, 140),
			Text = `+{Config.FormatNumber(def.Income)} $/s`,
			Parent = tile,
		})
	end
end

local function selectPack(pack)
	selectedPack = pack
	if shopBuilt then
		buildDetail(pack)
		updateShop()
	end
end

-- Liste links aufbauen (einmal, beim ersten Öffnen)
local function buildShopList()
	for index, pack in Config.Packs do
		local row = Instance.new("TextButton")
		row.Size = UDim2.new(1, -22, 0, SHOP_ROW_H - 8)
		row.Position = UDim2.fromOffset(8, 8 + (index - 1) * SHOP_ROW_H)
		row.BackgroundColor3 = WHITE
		row.AutoButtonColor = false
		row.Text = ""
		row.Parent = shopList
		corner(row, 12)
		local rowStroke = stroke(row, pack.Color, 2)
		rowStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		local rowGradient = Instance.new("UIGradient")
		rowGradient.Color = ColorSequence.new(pack.Color:Lerp(SHOP_DARK, 0.35), SHOP_DARK)
		rowGradient.Parent = row

		-- kleines Bild der Kiste
		local thumb = Instance.new("Frame")
		thumb.Size = UDim2.fromOffset(56, 56)
		thumb.Position = UDim2.fromOffset(6, 6)
		thumb.BackgroundColor3 = pack.Color
		thumb.BackgroundTransparency = 0.55
		thumb.Parent = row
		corner(thumb, 12)
		local template = packTemplate(pack)
		if template then
			local vp, model = packViewport(template, 56)
			model:PivotTo(CFrame.Angles(0, math.rad(25), 0))
			vp.Parent = thumb
		else
			label({ Size = UDim2.fromScale(1, 1), Text = "📦", Parent = thumb })
		end
		local lockIcon = label({
			Size = UDim2.fromOffset(26, 26),
			Position = UDim2.fromOffset(36, 36),
			Text = "🔒",
			ZIndex = 3,
			Parent = row,
		})

		label({
			Size = UDim2.new(1, -78, 0, 26),
			Position = UDim2.fromOffset(70, 8),
			Font = Enum.Font.FredokaOne,
			TextStrokeTransparency = 0.5,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = pack.Name,
			Parent = row,
		})
		local sub = label({
			Size = UDim2.new(1, -78, 0, 20),
			Position = UDim2.fromOffset(70, 38),
			Font = Enum.Font.GothamBold,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = "",
			Parent = row,
		})
		row.Activated:Connect(function()
			playSound("Click")
			selectPack(pack)
		end)
		shopRows[pack.Id] = { Row = row, Stroke = rowStroke, Sub = sub, Lock = lockIcon, Thumb = thumb, Pack = pack }
	end
end

function updateShop()
	if not shopBuilt then
		return
	end
	local money = player:GetAttribute("Money") or 0
	-- Fähigkeiten aus dem Skill-Baum, die Chancen und Garantie verändern
	local skills = {
		Luck = player:GetAttribute("Sk_Luck") or 0,
		MythicLuck = player:GetAttribute("Sk_MythicLuck") or 0,
		Pity = player:GetAttribute("Sk_Pity") or 0,
	}
	local rebirths = player:GetAttribute("Rebirths") or 0
	for _, r in shopRows do
		local pack = r.Pack
		local unlocked = Config.PackUnlocked(pack, rebirths)
		local selected = pack == selectedPack
		r.Lock.Visible = not unlocked
		r.Row.BackgroundTransparency = if unlocked then 0 else 0.5
		r.Thumb.BackgroundTransparency = if unlocked then 0.55 else 0.8
		if unlocked then
			r.Sub.Text = `{Config.FormatNumber(pack.Price)} $`
			r.Sub.TextColor3 = if money >= pack.Price then Color3.fromRGB(120, 255, 140) else Color3.fromRGB(200, 195, 225)
		else
			r.Sub.Text = `Ab Wiedergeburt {pack.Rebirths}`
			r.Sub.TextColor3 = Color3.fromRGB(225, 170, 255)
		end
		r.Stroke.Thickness = if selected then 4 else 2
		r.Stroke.Color = if selected then WHITE else pack.Color
	end
	for _, b in detailButtons do
		b.Button.BackgroundColor3 = if money >= b.Price then SHOP_GREEN else Color3.fromRGB(105, 100, 125)
	end
	local weights = Config.PackWeights(selectedPack, skills)
	for _, c in detailChances do
		c.Label.Text = percentText(Config.Percent(weights, c.Rarity) / c.Share)
	end
	local pity = player:GetAttribute("Pity") or 0
	local threshold = Config.PityFor(skills)
	local left = math.max(1, threshold - pity)
	pityLabel.Text = `Garantie: Legendär oder besser in spätestens {left} Kisten`
	pityFill.Size = UDim2.fromScale(math.clamp(pity / threshold, 0.08, 1), 1)
end
player:GetAttributeChangedSignal("Money"):Connect(updateShop)
player:GetAttributeChangedSignal("Pity"):Connect(updateShop)
for _, attr in { "Sk_Luck", "Sk_MythicLuck", "Sk_Pity" } do
	player:GetAttributeChangedSignal(attr):Connect(updateShop)
end

-- Nach einer Wiedergeburt: Schlösser neu prüfen und gleich die neue Kiste zeigen
local shopRebirths = player:GetAttribute("Rebirths") or 0
player:GetAttributeChangedSignal("Rebirths"):Connect(function()
	local now = player:GetAttribute("Rebirths") or 0
	if now > shopRebirths then
		selectedPack = Config.BestPack(now)
	end
	shopRebirths = now
	if shopBuilt then
		buildDetail(selectedPack)
		updateShop()
	end
end)

local function fitShop(): number
	local camera = workspace.CurrentCamera
	local scale = 1
	if camera then
		local size = camera.ViewportSize
		scale = math.min(1, size.X / (SHOP_W + 40), size.Y / (SHOP_H + 40))
	end
	shopScale.Scale = scale
	return scale
end

-- Shop aufmachen: ploppt kurz auf
local function showShop()
	if not shopBuilt then
		shopBuilt = true
		-- beim ersten Öffnen: die beste Kiste zeigen, die man sich gerade leisten kann
		local money = player:GetAttribute("Money") or 0
		local rebirths = player:GetAttribute("Rebirths") or 0
		for _, pack in Config.Packs do
			if Config.PackUnlocked(pack, rebirths) and (money >= pack.Price or pack.Index == 1) then
				selectedPack = pack
			end
		end
		buildShopList()
		buildDetail(selectedPack)
	end
	updateShop()
	local scale = fitShop()
	if not shop.Visible then
		shopScale.Scale = scale * 0.8
		tween(shopScale, 0.22, { Scale = scale }, Enum.EasingStyle.Back)
	end
	shop.Visible = true
end

Remotes.OpenPacks.OnClientEvent:Connect(showShop)

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
		showShop()
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

-- Pack-Öffnung ------------------------------------------------------------------------
-- Läuft als kleine Zwischensequenz auf einer eigenen Bühne: Kamera fährt ran, das Pack
-- knallt aufs Podest, lädt Schlag für Schlag auf, verrät seine Farbe, platzt, und die
-- Kreatur steigt in 3D heraus. Jeder Moment startet seinen Ton in derselben Zeile wie
-- das Bild, damit Ton und Bild genau zusammenpassen.
local Lighting = game:GetService("Lighting")
local ContentProvider = game:GetService("ContentProvider")
local StarterGui = game:GetService("StarterGui")

-- Sounds vorladen, damit beim ersten Pack nichts verzögert kommt
task.spawn(function()
	local list = {}
	for _, template in soundTemplates do
		table.insert(list, template)
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
	local sound = newSound(sample)
	if not sound then
		return nil
	end
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

-- Die Bühne --------------------------------------------------------------------------
-- Ein dunkler Raum hoch über der Insel. Dort steht ein Podest, auf dem das Pack landet.
-- Die Kamera gehört während der Öffnung dem Skript und fährt wie in einem Film mit.
local STAGE = CFrame.new(0, 3000, 0) -- Mitte des Bühnenbodens
local PEDESTAL_TOP = 0.6 -- Höhe des Podests
local PACK_Y = 2.95 -- so hoch ist die Mitte des Packs, wenn es auf dem Podest steht
local RARE_RANK = Config.RarityRank("Rare")
local EPIC_RANK = Config.RarityRank("Epic")
local LEGENDARY_RANK = Config.RarityRank("Legendary")
local MYTHIC_RANK = Config.RarityRank("Mythic")

-- GROSSBUCHSTABEN, auch für ä, ö, ü (string.upper lässt die klein)
local function upperDe(text: string): string
	return (string.upper(text):gsub("ä", "Ä"):gsub("ö", "Ö"):gsub("ü", "Ü"))
end

-- Wie tween(), aber wird zum Ende hin schneller (für Fallen und Zuklappen)
local function tweenIn(obj: Instance, time: number, props, style: Enum.EasingStyle?)
	local t = TweenService:Create(obj, TweenInfo.new(time, style or Enum.EasingStyle.Quad, Enum.EasingDirection.In), props)
	t:Play()
	return t
end

-- Ein Teil für die Bühne: fest, ohne Kollision
local function stagePart(props): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	local parent = props.Parent
	props.Parent = nil
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = parent
	return p
end

-- Flache runde Scheibe, die auf dem Boden liegt (y = Höhe der Mitte)
local function stageDisc(parent: Instance, y: number, diameter: number, height: number, color: Color3, material: Enum.Material): Part
	return stagePart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, diameter, diameter),
		CFrame = STAGE * CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Color = color,
		Material = material,
		Parent = parent,
	})
end

-- Funken, die man mit :Emit(anzahl) losschießt
local function sparkEmitter(parent: Instance, color: Color3, size: number, speed: number): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(color)
	e.LightEmission = 1
	e.Size = NumberSequence.new(size, 0)
	e.Lifetime = NumberRange.new(0.45, 0.95)
	e.Speed = NumberRange.new(speed * 0.4, speed)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration = Vector3.new(0, -14, 0)
	e.Drag = 2
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-200, 200)
	e.Parent = parent
	return e
end

-- Weiches Leuchten aus übereinander liegenden Rauch-Teilchen (Rate 0 = aus)
local function glowEmitter(parent: Instance, size: number): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(WHITE)
	e.LightEmission = 1
	e.LockedToPart = true
	e.Size = NumberSequence.new(size, size * 1.5)
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, 0.72),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Lifetime = NumberRange.new(0.5, 0.8)
	e.Speed = NumberRange.new(0)
	e.Rate = 0
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-40, 40)
	e.ZOffset = -4 -- hinter das Pack schieben, sonst bleicht das Glühen es aus
	e.Parent = parent
	return e
end

-- Eine "Puppe" ist ein Modell auf der Bühne, das über drei Werte bewegt wird:
-- Pos (Ort), Tilt (Drehung in Grad) und Size (Größe). Die Werte kann man tweenen.
local function makePuppet(show, model: Model, baseScale: number, facing: CFrame)
	local p = {
		Model = model,
		Pos = Instance.new("Vector3Value"),
		Tilt = Instance.new("Vector3Value"),
		Size = Instance.new("NumberValue"),
		BaseScale = baseScale,
		Facing = facing,
		Jitter = 0, -- Zittern in Studs
		Idle = false, -- hüpft und schaut sich um
		IdleStart = 0,
		LastScale = -1,
	}
	p.Size.Value = 1
	table.insert(show.Trash, p.Pos)
	table.insert(show.Trash, p.Tilt)
	table.insert(show.Trash, p.Size)
	show.Puppets[p] = true
	return p
end

local function updatePuppet(p)
	local model = p.Model
	local scale = math.max(0.03, p.Size.Value) * p.BaseScale
	if math.abs(scale - p.LastScale) > 0.0005 then
		p.LastScale = scale
		model:ScaleTo(scale)
	end
	local pos = p.Pos.Value
	local tilt = p.Tilt.Value
	local yaw = tilt.Y
	if p.Jitter > 0 then
		pos += Vector3.new(math.random() - 0.5, math.random() - 0.5, 0) * (p.Jitter * 2)
	end
	if p.Idle then
		local t = os.clock() - p.IdleStart
		pos += Vector3.new(0, math.abs(math.sin(t * 3.2)) * 0.28, 0)
		yaw += math.sin(t * 1.4) * 28
	end
	model:PivotTo(STAGE * CFrame.new(pos) * p.Facing * CFrame.Angles(math.rad(tilt.X), math.rad(yaw), math.rad(tilt.Z)))
end

-- Wartet. Gibt true zurück, sobald der Spieler geklickt hat (dann geht es sofort weiter).
local function beat(show, seconds: number): boolean
	local stop = os.clock() + seconds
	while os.clock() < stop do
		if show.Skip then
			return true
		end
		task.wait()
	end
	return show.Skip
end

-- Bildschirm blitzt kurz in einer Farbe auf
local function screenFlash(show, color: Color3, strength: number, time: number)
	local f = Instance.new("Frame")
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundColor3 = color
	f.BackgroundTransparency = 1 - strength
	f.BorderSizePixel = 0
	f.ZIndex = 20
	f.Parent = show.Root
	tween(f, time, { BackgroundTransparency = 1 })
	task.delay(time + 0.05, function()
		f:Destroy()
	end)
end

-- Leuchtende Scheibe, die sich auf dem Podest schnell ausbreitet und verblasst
local function stageRing(show, color: Color3, diameter: number, time: number)
	local ring = stageDisc(show.Folder, PEDESTAL_TOP + 0.04, 2, 0.06, color, Enum.Material.Neon)
	ring.Transparency = 0.6
	tween(ring, time, { Size = Vector3.new(0.06, diameter, diameter), Transparency = 1 })
	task.delay(time + 0.05, function()
		ring:Destroy()
	end)
end

-- Strahlen hinter dem Podest ein- oder ausblenden (alpha 0 = unsichtbar, 1 = voll)
local function setRays(show, alpha: number, time: number)
	for i, r in show.Rays:GetChildren() do
		if r:IsA("Frame") then
			local strong = if i % 2 == 0 then 0.55 else 0.3
			tween(r, time, { BackgroundTransparency = 1 - alpha * strong })
		end
	end
end

-- Alles auf der Bühne in eine Farbe tauchen (die Farbe der Seltenheit)
local function setShowColor(show, p, color: Color3)
	show.Ring.Color = color
	show.FloorGlow.Color = color
	show.Rim.Color = color
	for _, r in show.Rays:GetChildren() do
		if r:IsA("Frame") then
			r.BackgroundColor3 = color
		end
	end
	if p then
		for _, seg in p.Cracks do
			if seg:IsA("Beam") then
				seg.Color = ColorSequence.new(color)
			else
				seg.Color = color
			end
		end
		p.Glow.Color = ColorSequence.new(color)
		p.Light.Color = color
		p.Sparks.Color = ColorSequence.new(color, WHITE)
	end
end

-- Bühne aufbauen und Kamera übernehmen. Alles landet in show.Trash und wird am Ende entfernt.
local function setupShow(show)
	local camera = workspace.CurrentCamera
	show.Puppets = {}
	show.Trash = {}
	show.Skip = false
	show.Clicks = 0
	show.Again = false

	-- Schwarzblende, damit der Kamerasprung nicht hart aussieht
	local fader = Instance.new("Frame")
	fader.Size = UDim2.fromScale(1, 1)
	fader.BackgroundColor3 = BLACK
	fader.BackgroundTransparency = 1
	fader.BorderSizePixel = 0
	fader.ZIndex = 50
	fader.Parent = overlayGui
	show.Fader = fader
	tween(fader, 0.14, { BackgroundTransparency = 0 })
	task.wait(0.15)

	local folder = Instance.new("Folder")
	folder.Name = "PackBuehne"
	show.Folder = folder
	table.insert(show.Trash, folder)

	-- Raum: Boden, Decke und vier Wände (dick, damit kein Tageslicht reinkommt)
	local wallColor = Color3.fromRGB(20, 16, 38)
	local function wall(size: Vector3, pos: Vector3, color: Color3?)
		stagePart({
			Size = size,
			CFrame = STAGE * CFrame.new(pos),
			Color = color or wallColor,
			CastShadow = true,
			Parent = folder,
		})
	end
	wall(Vector3.new(96, 4, 96), Vector3.new(0, -2, 0), Color3.fromRGB(28, 23, 54))
	wall(Vector3.new(96, 4, 96), Vector3.new(0, 52, 0))
	wall(Vector3.new(96, 60, 4), Vector3.new(0, 24, -36))
	wall(Vector3.new(96, 60, 4), Vector3.new(0, 24, 44))
	wall(Vector3.new(4, 60, 96), Vector3.new(-46, 24, 0))
	wall(Vector3.new(4, 60, 96), Vector3.new(46, 24, 0))

	-- Podest mit Leuchtrand und Lichtfleck auf dem Boden
	stageDisc(folder, PEDESTAL_TOP / 2, 7, PEDESTAL_TOP, Color3.fromRGB(48, 42, 88), Enum.Material.SmoothPlastic)
	show.Ring = stageDisc(folder, PEDESTAL_TOP / 2, 7.5, 0.22, WHITE, Enum.Material.Neon)
	show.FloorGlow = stageDisc(folder, 0.03, 13, 0.05, Color3.fromRGB(120, 90, 255), Enum.Material.Neon)
	show.FloorGlow.Transparency = 0.93

	-- Strahlenkranz hinter dem Podest (erst unsichtbar)
	local board = stagePart({
		Size = Vector3.new(34, 34, 0.2),
		CFrame = STAGE * CFrame.new(0, 5, -15),
		Transparency = 1,
		Parent = folder,
	})
	local boardGui = Instance.new("SurfaceGui")
	boardGui.Face = Enum.NormalId.Back
	boardGui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	boardGui.CanvasSize = Vector2.new(700, 700)
	boardGui.LightInfluence = 0
	boardGui.Parent = board
	show.Rays = sunburst(boardGui, WHITE, 700)
	for _, r in show.Rays:GetChildren() do
		if r:IsA("Frame") then
			r.Size = UDim2.new(0, 64, 1, 0)
			r.BackgroundTransparency = 1
		end
	end

	-- Licht: Scheinwerfer von vorne oben, farbiges Licht von hinten
	local keyPart = stagePart({
		Size = Vector3.new(1, 1, 1),
		CFrame = CFrame.lookAt(STAGE * Vector3.new(0, 15, 10), STAGE * Vector3.new(0, 2, 0)),
		Transparency = 1,
		Parent = folder,
	})
	local key = Instance.new("SpotLight")
	key.Face = Enum.NormalId.Front
	key.Angle = 60
	key.Range = 44
	key.Brightness = 2.6
	key.Color = Color3.fromRGB(255, 242, 228)
	key.Parent = keyPart
	show.Key = key
	local rimPart = stagePart({
		Size = Vector3.new(1, 1, 1),
		CFrame = STAGE * CFrame.new(0, 5, -7),
		Transparency = 1,
		Parent = folder,
	})
	local rim = Instance.new("PointLight")
	rim.Range = 28
	rim.Brightness = 1.4
	rim.Color = Color3.fromRGB(150, 110, 255)
	rim.Parent = rimPart
	show.Rim = rim

	-- Glitzer-Staub in der Luft und Staubwolke fürs Aufschlagen
	local air = stagePart({
		Size = Vector3.new(40, 1, 34),
		CFrame = STAGE * CFrame.new(0, 15, -4),
		Transparency = 1,
		Parent = folder,
	})
	local motes = Instance.new("ParticleEmitter")
	motes.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	motes.Color = ColorSequence.new(Color3.fromRGB(200, 190, 255))
	motes.LightEmission = 1
	motes.Size = NumberSequence.new(0.16)
	motes.Transparency = NumberSequence.new(0.35)
	motes.Lifetime = NumberRange.new(7, 10)
	motes.Rate = 12
	motes.Speed = NumberRange.new(1, 2)
	motes.EmissionDirection = Enum.NormalId.Bottom
	motes.Parent = air
	local dustPart = stagePart({
		Size = Vector3.new(5, 0.2, 5),
		CFrame = STAGE * CFrame.new(0, PEDESTAL_TOP, 0),
		Transparency = 1,
		Parent = folder,
	})
	local dust = Instance.new("ParticleEmitter")
	dust.Enabled = false
	dust.Texture = "rbxasset://textures/particles/smoke_main.dds"
	dust.Color = ColorSequence.new(Color3.fromRGB(190, 180, 230))
	dust.Size = NumberSequence.new(1.2, 3.4)
	dust.Transparency = NumberSequence.new(0.55, 1)
	dust.Lifetime = NumberRange.new(0.45, 0.8)
	dust.Speed = NumberRange.new(5, 10)
	dust.SpreadAngle = Vector2.new(80, 80)
	dust.Drag = 3
	dust.Rotation = NumberRange.new(0, 360)
	dust.Parent = dustPart
	show.Dust = dust
	-- Funken für den großen Knall (hängen am Podest, nicht am Pack)
	local burstPart = stagePart({
		Size = Vector3.new(1, 1, 1),
		CFrame = STAGE * CFrame.new(0, PACK_Y, 0),
		Transparency = 1,
		Parent = folder,
	})
	show.Burst = sparkEmitter(burstPart, WHITE, 0.9, 30)
	show.Burst.Lifetime = NumberRange.new(0.6, 1.3)

	folder.Parent = workspace

	-- Alles, was als Bild über der Bühne liegt (Schrift, Karten, Knöpfe)
	local root = Instance.new("Frame")
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundTransparency = 1
	root.Parent = overlayGui
	show.Root = root
	table.insert(show.Trash, root)
	-- Klick irgendwo: beim Aufladen überspringen, am Ende schließen
	local catcher = Instance.new("TextButton")
	catcher.Size = UDim2.fromScale(1, 1)
	catcher.BackgroundTransparency = 1
	catcher.Text = ""
	catcher.Parent = root
	catcher.Activated:Connect(function()
		show.Clicks += 1
		show.Skip = true
	end)

	-- Kamera: drei Werte, die man tweenen kann
	show.CamPos = Instance.new("Vector3Value")
	show.CamPos.Value = Vector3.new(0, 7.5, 24)
	show.CamLook = Instance.new("Vector3Value")
	show.CamLook.Value = Vector3.new(0, 3, 0)
	show.CamFov = Instance.new("NumberValue")
	show.CamFov.Value = 55
	table.insert(show.Trash, show.CamPos)
	table.insert(show.Trash, show.CamLook)
	table.insert(show.Trash, show.CamFov)

	-- Hintergrund leicht unscharf, das Pack bleibt scharf
	local dof = Instance.new("DepthOfFieldEffect")
	dof.FarIntensity = 0.3
	dof.NearIntensity = 0
	dof.InFocusRadius = 9
	dof.FocusDistance = 14
	dof.Parent = camera
	table.insert(show.Trash, dof)

	-- Dunst aus, Leuchten etwas stärker (wird am Ende zurückgestellt)
	local atmosphere = Lighting:FindFirstChild("SpielDunst") or Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		show.Atmosphere = atmosphere
		show.SavedDensity = atmosphere.Density
		atmosphere.Density = 0
	end
	local bloom = Lighting:FindFirstChild("SpielLeuchten") or Lighting:FindFirstChildOfClass("BloomEffect")
	if bloom then
		show.Bloom = bloom
		show.SavedBloom = { bloom.Intensity, bloom.Size, bloom.Threshold }
		bloom.Intensity = 0.6
		bloom.Size = 24
		bloom.Threshold = 1.2
	end

	-- Eigene Anzeige und die Roblox-Leisten ausblenden, damit es wie im Kino aussieht
	gui.Enabled = false
	show.CoreGui = {}
	pcall(function()
		StarterGui:SetCore("TopbarEnabled", false)
	end)
	pcall(function()
		for _, kind in { Enum.CoreGuiType.PlayerList, Enum.CoreGuiType.Backpack, Enum.CoreGuiType.Chat, Enum.CoreGuiType.EmotesMenu } do
			show.CoreGui[kind] = StarterGui:GetCoreGuiEnabled(kind)
			StarterGui:SetCoreGuiEnabled(kind, false)
		end
	end)

	camera.CameraType = Enum.CameraType.Scriptable
	pcall(function()
		RunService:UnbindFromRenderStep("PackKamera") -- falls von einem früheren Fehler noch eine hängt
	end)
	RunService:BindToRenderStep("PackKamera", Enum.RenderPriority.Camera.Value, function()
		local cam = workspace.CurrentCamera
		if cam.CameraType ~= Enum.CameraType.Scriptable then
			cam.CameraType = Enum.CameraType.Scriptable
		end
		local from, to = STAGE * show.CamPos.Value, STAGE * show.CamLook.Value
		cam.CFrame = CFrame.lookAt(from, to)
		cam.Focus = CFrame.new(to)
		cam.FieldOfView = show.CamFov.Value
		-- Maus freigeben (in der Ich-Ansicht hängt sie sonst in der Mitte fest)
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		dof.FocusDistance = (from - to).Magnitude
		for p in show.Puppets do
			updatePuppet(p)
		end
	end)
	tween(fader, 0.22, { BackgroundTransparency = 1 })
end

-- Bühne abbauen, Kamera zurückgeben. Läuft immer, auch wenn unterwegs etwas schiefging.
local function teardownShow(show, savedType: Enum.CameraType, savedFov: number)
	local fader = show.Fader
	if fader then
		tween(fader, 0.16, { BackgroundTransparency = 0 })
		task.wait(0.17)
	end
	pcall(function()
		RunService:UnbindFromRenderStep("PackKamera")
	end)
	local camera = workspace.CurrentCamera
	camera.CameraType = if savedType == Enum.CameraType.Scriptable then Enum.CameraType.Custom else savedType
	camera.FieldOfView = savedFov
	gui.Enabled = true
	pcall(function()
		StarterGui:SetCore("TopbarEnabled", true)
	end)
	for kind, enabled in show.CoreGui or {} do
		pcall(function()
			StarterGui:SetCoreGuiEnabled(kind, enabled)
		end)
	end
	if show.Atmosphere then
		show.Atmosphere.Density = show.SavedDensity
	end
	if show.Bloom then
		show.Bloom.Intensity, show.Bloom.Size, show.Bloom.Threshold = show.SavedBloom[1], show.SavedBloom[2], show.SavedBloom[3]
	end
	for _, thing in show.Trash or {} do
		if typeof(thing) == "Instance" then
			thing:Destroy()
		end
	end
	if fader then
		tween(fader, 0.25, { BackgroundTransparency = 1 })
		task.delay(0.3, function()
			fader:Destroy()
		end)
	end
end

-- Führt eine Öffnung aus: Bühne auf, abspielen, Bühne ab. Danach Shop oder gleich nochmal.
local function runShow(pack, count: number, play)
	local camera = workspace.CurrentCamera
	local savedType, savedFov = camera.CameraType, camera.FieldOfView
	opening = true
	shop.Visible = false
	local show = {}
	local ok, err = pcall(function()
		setupShow(show)
		play(show)
	end)
	if not ok then
		warn(`[Pack-Öffnung] Fehler in der Animation: {err}`)
	end
	local cleaned = pcall(teardownShow, show, savedType, savedFov)
	if not cleaned then
		-- Sicherheitsnetz: die Kamera gehört auf jeden Fall wieder dem Spieler
		pcall(function()
			RunService:UnbindFromRenderStep("PackKamera")
		end)
		workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
		workspace.CurrentCamera.FieldOfView = savedFov
		gui.Enabled = true
		if show.Fader then
			show.Fader:Destroy()
		end
	end
	opening = false
	if show.Again and pack then
		Remotes.BuyPack:FireServer(pack.Id, count)
	else
		showShop()
	end
end

-- Das Pack als 3D-Modell. Liegt in ReplicatedStorage.PackModelle ein Modell mit der Id des
-- Packs (z.B. "Holz"), wird das genommen. Sonst gibt es eine Folien-Tafel mit Bild vorne.
local PACK_HEIGHT = 4.2 -- Höhe des 3D-Modells auf der Bühne
local function buildPack(show, pack, bigText: string)
	local packColor = pack and pack.Color or WHITE
	local folder = ReplicatedStorage:FindFirstChild("PackModelle")
	local template = pack and folder and folder:FindFirstChild(pack.Id)
	local model: Model? = nil
	local baseScale = 1
	if template and template:IsA("Model") then
		local clone = template:Clone()
		for _, d in clone:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				d.CanTouch = false
				d.CanQuery = false
				d.CastShadow = false
			elseif d:IsA("LuaSourceContainer") then
				d:Destroy()
			end
		end
		local height = clone:GetExtentsSize().Y
		if height > 0.05 then
			model = clone
			baseScale = clone:GetScale() * PACK_HEIGHT / height
			clone:ScaleTo(baseScale)
			clone:PivotTo(CFrame.new())
		else
			clone:Destroy()
		end
	end

	local body: Part? = nil
	local face: SurfaceGui? = nil
	local sparkHost: BasePart
	local coreCF: CFrame
	local facing = CFrame.identity
	local restY, centerOffset = PACK_Y, 0
	if model then
		-- KI-Modell: Pivot unten in der Mitte, Vorderseite zeigt nach -Z (also umdrehen)
		local boxCF, boxSize = model:GetBoundingBox()
		sparkHost = stagePart({
			Name = "Huelle",
			Size = boxSize,
			CFrame = boxCF,
			Transparency = 1,
			Parent = model,
		})
		coreCF = CFrame.new(boxCF.Position) * CFrame.new(0, 0, boxSize.Z / 2 + 0.3)
		facing = CFrame.Angles(0, math.pi, 0)
		restY, centerOffset = PEDESTAL_TOP, PACK_HEIGHT / 2
	else
		local slab = Instance.new("Model")
		slab.Name = "Pack"
		local slabBody = stagePart({
			Name = "Body",
			Size = Vector3.new(2.8, 3.8, 0.5),
			Color = packColor,
			Material = Enum.Material.Foil,
			Parent = slab,
		})
		slab.PrimaryPart = slabBody
		for _, dir in { 1, -1 } do
			stagePart({
				Name = "Rand",
				Size = Vector3.new(2.8, 0.38, 0.16),
				CFrame = CFrame.new(0, dir * 2.09, 0),
				Color = packColor:Lerp(WHITE, 0.5),
				Material = Enum.Material.Metal,
				Parent = slab,
			})
		end
		local slabFace = Instance.new("SurfaceGui")
		slabFace.Face = Enum.NormalId.Back -- die Seite, die zur Kamera zeigt
		slabFace.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
		slabFace.CanvasSize = Vector2.new(280, 380)
		slabFace.LightInfluence = 0
		slabFace.Parent = slabBody
		packFace(slabFace, pack and pack.Name or "Pack", bigText, packColor)
		model, body, face, sparkHost = slab, slabBody, slabFace, slabBody
		coreCF = CFrame.new(0, 0, -0.6)
	end

	local core = stagePart({
		Name = "Kern",
		Size = Vector3.new(0.4, 0.4, 0.4),
		CFrame = coreCF,
		Transparency = 1,
		Parent = model,
	})
	local light = Instance.new("PointLight")
	light.Range = 14
	light.Brightness = 0
	light.Parent = core

	local p = makePuppet(show, model :: Model, baseScale, facing)
	p.Body = body
	p.Face = face
	p.Core = core
	p.Color = packColor
	p.RestY = restY -- so hoch steht das Pack auf dem Podest (Höhe seines Pivots)
	p.CenterOffset = centerOffset -- so weit liegt seine Mitte über dem Pivot
	p.Cracks = {}
	p.Glow = glowEmitter(core, 4.5)
	p.Light = light
	p.Sparks = sparkEmitter(sparkHost, WHITE, 0.55, 16)
	if not body and bigText ~= "?" then
		-- Beim 3D-Modell schwebt die Anzahl ("10x") als Schild vor dem Pack
		local badge = Instance.new("BillboardGui")
		badge.Size = UDim2.fromScale(3.4, 1.7)
		badge.AlwaysOnTop = true
		badge.Adornee = sparkHost
		badge.Parent = sparkHost
		label({
			Size = UDim2.fromScale(1, 1),
			Font = Enum.Font.FredokaOne,
			TextStrokeTransparency = 0,
			Text = bigText,
			Parent = badge,
		})
		p.Badge = badge
	end
	return p
end

-- Licht bricht aus dem Pack. Bei der Folien-Tafel als gezackter Riss auf der Vorderseite,
-- beim 3D-Modell als Lichtstrahl, der hinter dem Pack hervorschießt.
local function addCrack(p, seed: number, color: Color3)
	local rng = Random.new(seed)
	local body = p.Body
	if not body then
		-- 3D-Truhe: ein Lichtstrahl, der hinter der Truhe hervorbricht und nach außen breiter
		-- und blasser wird
		local k = p.Model:GetScale() / p.BaseScale -- aktuelle Größe des Packs
		local len = rng:NextNumber(4.6, 6.6) * k
		local host = stagePart({
			Name = "Strahl",
			Size = Vector3.new(0.2, 0.2, 0.2),
			CFrame = p.Core.CFrame * CFrame.Angles(0, 0, rng:NextNumber(0, math.pi * 2)),
			Transparency = 1,
			Parent = p.Model,
		})
		local from = Instance.new("Attachment")
		from.Parent = host
		local to = Instance.new("Attachment")
		to.Position = Vector3.new(len, 0, 0)
		to.Parent = host
		local beam = Instance.new("Beam")
		beam.Attachment0 = from
		beam.Attachment1 = to
		beam.FaceCamera = true
		beam.Segments = 1
		beam.LightEmission = 1
		beam.LightInfluence = 0
		beam.Brightness = 1.6
		beam.Color = ColorSequence.new(color)
		beam.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.25),
			NumberSequenceKeypoint.new(0.6, 0.6),
			NumberSequenceKeypoint.new(1, 1),
		})
		beam.Width0 = 0
		beam.Width1 = 0
		beam.Parent = host
		tween(beam, 0.16, { Width0 = 0.35 * k, Width1 = 1.5 * k }, Enum.EasingStyle.Back)
		table.insert(p.Cracks, beam)
		return
	end
	local k = body.Size.X / 2.8 -- aktuelle Größe des Packs
	local halfX, halfY = body.Size.X * 0.44, body.Size.Y * 0.44
	local x, y = rng:NextNumber(-0.3, 0.3) * body.Size.X, rng:NextNumber(-0.32, 0.32) * body.Size.Y
	local angle = rng:NextNumber(0, math.pi * 2)
	for _ = 1, 3 do
		local len = rng:NextNumber(0.5, 0.95) * k
		local nx = math.clamp(x + math.cos(angle) * len, -halfX, halfX)
		local ny = math.clamp(y + math.sin(angle) * len, -halfY, halfY)
		local dx, dy = nx - x, ny - y
		local real = math.sqrt(dx * dx + dy * dy)
		if real > 0.05 then
			local seg = stagePart({
				Name = "Riss",
				Size = Vector3.new(real + 0.03 * k, 0.05 * k, 0.04 * k),
				CFrame = body.CFrame * CFrame.new((x + nx) / 2, (y + ny) / 2, body.Size.Z / 2 + 0.02 * k) * CFrame.Angles(0, 0, math.atan2(dy, dx)),
				Color = color,
				Material = Enum.Material.Neon,
				Parent = p.Model,
			})
			table.insert(p.Cracks, seg)
		end
		x, y = nx, ny
		angle += rng:NextNumber(-1.1, 1.1)
	end
end

-- 1. Akt: Kamera fährt ran, das Pack fällt von oben und knallt aufs Podest
local function enterPack(show, pack, bigText: string)
	local p = buildPack(show, pack, bigText)
	local rest = p.RestY
	p.Pos.Value = Vector3.new(0, rest + 14, 0)
	p.Tilt.Value = Vector3.new(0, -360, 20)
	updatePuppet(p)
	p.Model.Parent = show.Folder
	tween(show.CamPos, 0.9, { Value = Vector3.new(0, 3.9, 14) }, Enum.EasingStyle.Quart)
	task.wait(0.15) -- kurz warten, bis die Schwarzblende offen ist

	local fall = 0.42
	playSound("PackDrop")
	tweenIn(p.Pos, fall, { Value = Vector3.new(0, rest, 0) })
	tween(p.Tilt, fall, { Value = Vector3.zero }, Enum.EasingStyle.Linear)
	task.wait(fall)

	-- Aufschlag: dumpfer Schlag, Staub, Ring, das Pack federt kurz nach
	playSound("PackSlam")
	shake(2.4, 0.3)
	show.Dust:Emit(18)
	stageRing(show, WHITE, 15, 0.45)
	p.Size.Value = 0.8
	tween(p.Size, 0.45, { Value = 1 }, Enum.EasingStyle.Elastic)
	p.Pos.Value = Vector3.new(0, rest - 0.25, 0)
	tween(p.Pos, 0.3, { Value = Vector3.new(0, rest, 0) }, Enum.EasingStyle.Back)
	return p
end

-- 2. Akt: Schläge. Bei jedem Schlag ruckt das Pack, bekommt einen Riss, der Ton wird höher,
-- die Kamera rückt näher und das Raumlicht wird dunkler. Gibt true zurück, wenn übersprungen.
local function chargePack(show, p, hits: number, rank: number): boolean
	local gap = 0.44
	for i = 1, hits do
		if beat(show, gap) then
			return true
		end
		if i == 1 and rank >= EPIC_RANK then
			-- Ab Episch schwillt unter allem ein Becken an. Es startet so, dass seine lauteste
			-- Stelle genau auf den Knall fällt.
			local left = 0
			for k = 1, hits do
				left += gap * 0.86 ^ k
			end
			left += (rank - RARE_RANK + 1) * 0.46
			local speed = math.clamp(Config.RiserPeak / left, 0.8, 1.5)
			task.delay(math.max(0, left - Config.RiserPeak / speed), function()
				if show.Puppets[p] and not show.Skip then
					show.Riser = startSound("Riser", 0.8, speed)
				end
			end)
		end
		local t = i / hits
		local side = if i % 2 == 0 then 1 else -1
		playSound("PackHit", 2 ^ ((i - 1) * 2 / 12)) -- jeder Schlag einen Ganzton höher
		p.Tilt.Value = Vector3.new(0, side * 12, side * (10 + t * 14))
		tween(p.Tilt, gap * 0.85, { Value = Vector3.zero }, Enum.EasingStyle.Elastic)
		p.Size.Value = 1.12 + t * 0.12
		tween(p.Size, gap * 0.7, { Value = 1 + t * 0.06 }, Enum.EasingStyle.Back)
		p.Pos.Value = Vector3.new(0, p.RestY + 0.35 + t * 0.4, 0)
		tween(p.Pos, gap * 0.6, { Value = Vector3.new(0, p.RestY, 0) }, Enum.EasingStyle.Bounce)
		addCrack(p, i * 17 + hits, WHITE)
		p.Sparks:Emit(6 + i * 4)
		p.Light.Brightness = t * 2.6
		p.Glow.Rate = t * 12
		shake(0.6 + t * 1.6, 0.18)
		tween(show.CamPos, gap, { Value = Vector3.new(0, 3.9 - t * 0.4, 14 - t * 3) })
		tween(show.CamFov, gap, { Value = 55 - t * 7 })
		show.Key.Brightness = 2.6 - t * 1.6
		gap *= 0.86
	end
	return beat(show, gap)
end

-- 3. Akt (ab Selten): Das Pack hebt ab und verrät seine Farbe. Die Farbe steigt Stufe für
-- Stufe (blau, lila, gold, pink), und man hofft bei jeder Stufe, dass noch eine kommt.
-- Gibt true zurück, wenn übersprungen.
local function tellRarity(show, p, rank: number): boolean
	if rank < RARE_RANK then
		return false
	end
	local steps = rank - RARE_RANK + 1
	local stepTime = if steps == 1 then 0.4 else 0.46
	local total = steps * stepTime
	local lift = Vector3.new(0, p.RestY + 0.5 + steps * 0.25, 0)
	local lookY = lift.Y + p.CenterOffset -- die Kamera schaut auf die Mitte des Packs
	tween(p.Pos, total, { Value = lift }, Enum.EasingStyle.Sine)
	tween(show.CamLook, total, { Value = Vector3.new(0, lookY, 0) }, Enum.EasingStyle.Sine)
	tween(show.CamPos, total, { Value = Vector3.new(0, lookY + 0.6, 10 - steps * 0.3) }, Enum.EasingStyle.Sine)
	tween(show.CamFov, total, { Value = 46 })
	setRays(show, 0.5, total)
	local skipped = false
	for s = 1, steps do
		local color = Config.Rarities[Config.RarityOrder[RARE_RANK + s - 1]].Color
		playSound("TellStep", 2 ^ ((s - 1) * 3 / 12)) -- jede Stufe eine kleine Terz höher
		setShowColor(show, p, color)
		p.Jitter = 0.02 + s * 0.03
		p.Size.Value = 1.24
		tween(p.Size, stepTime * 0.8, { Value = 1.08 + s * 0.02 }, Enum.EasingStyle.Back)
		p.Sparks:Emit(14)
		p.Light.Brightness = 2.2 + s * 0.35 -- mehr bleicht die Truhe aus
		stageRing(show, color, 12 + s * 3, 0.45)
		shake(1 + s * 0.5, stepTime * 0.6)
		if beat(show, stepTime) then
			skipped = true
			break
		end
	end
	stopSound(show.Riser, 0.06)
	show.Riser = nil
	if not skipped and rank >= LEGENDARY_RANK then
		-- Ganz kurz ist alles still und dunkel. Genau dann knallt es am schönsten.
		p.Jitter = 0
		show.Key.Brightness = 0
		show.Rim.Brightness = 0.3
		skipped = beat(show, if rank >= MYTHIC_RANK then 0.42 else 0.24)
	end
	return skipped
end

-- 4. Akt: Das Pack platzt. Ein winziger Stillstand, dann Blitz, Knall, Scherben, Druckwelle.
local function burstPack(show, p, rank: number, color: Color3)
	local isEpic = rank >= EPIC_RANK
	local isLegendary = rank >= LEGENDARY_RANK
	local body = p.Body
	stopSound(show.Riser, 0.05) -- falls übersprungen wurde, läuft er noch
	show.Riser = nil
	p.Jitter = 0
	p.Size.Value = 1.32
	task.wait(0.06)

	playSound("PackBurst")
	if isEpic then
		playSound("PackBurstBig")
	end
	show.Puppets[p] = nil -- ab jetzt fliegen die Teile einzeln
	local center = p.Core.Position
	if p.Badge then
		p.Badge:Destroy()
	end
	p.Glow.Rate = 0
	tween(p.Light, 0.4, { Brightness = 0 })
	if body then
		-- Folien-Tafel: zwei Hälften reißen auseinander
		local bodyCF, bodySize, bodyColor = body.CFrame, body.Size, body.Color
		p.Face:Destroy()
		body.Transparency = 1
		for _, dir in { -1, 1 } do
			local half = stagePart({
				Size = Vector3.new(bodySize.X / 2, bodySize.Y, bodySize.Z),
				CFrame = bodyCF * CFrame.new(dir * bodySize.X / 4, 0, 0),
				Color = bodyColor,
				Material = Enum.Material.Foil,
				Parent = show.Folder,
			})
			tween(half, 0.6, {
				CFrame = bodyCF * CFrame.new(dir * 9, 2.5, 1) * CFrame.Angles(math.rad(40), dir * math.rad(70), dir * math.rad(-120)),
				Transparency = 1,
			})
			task.delay(0.65, function()
				half:Destroy()
			end)
		end
	end
	for _, seg in p.Cracks do
		if seg:IsA("Beam") then
			-- Lichtstrahlen blitzen breit auf und sind weg
			seg.Width1 *= 2.2
			tween(seg, 0.22, { Width0 = 0, Width1 = 0 })
		end
	end
	for _, part in p.Model:GetDescendants() do
		if part:IsA("BasePart") and part ~= body and part.Name ~= "Kern" and part.Name ~= "Huelle" and part.Name ~= "Strahl" then
			if part.Name == "Riss" or part.Name == "Rand" then
				-- Ränder, Risse und Lichtstrahlen fliegen als Scherben weg
				local away = part.Position - center
				if away.Magnitude < 0.1 then
					away = Vector3.new(math.random() - 0.5, math.random() - 0.5, 0.2)
				end
				local target = part.Position + away.Unit * (5 + math.random() * 6) + Vector3.new(0, math.random() * 2, math.random() * 3)
				tween(part, 0.5, {
					CFrame = CFrame.new(target) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6),
					Transparency = 1,
				})
			else
				-- 3D-Modell: bläht sich kurz auf und ist weg
				tween(part, 0.16, { Size = part.Size * 1.35, Transparency = 1 })
			end
		end
	end
	-- Scherben in der Farbe des Packs fliegen in alle Richtungen
	for i = 1, 16 do
		local s = 0.3 + math.random() * 0.6
		local shard = stagePart({
			Size = Vector3.new(s, s * 1.4, 0.12),
			CFrame = CFrame.new(center) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6),
			Color = if i % 3 == 0 then WHITE else p.Color,
			Material = Enum.Material.Foil,
			Parent = show.Folder,
		})
		local dir = Vector3.new(math.random() - 0.5, math.random() - 0.3, math.random() - 0.5).Unit
		tween(shard, 0.55 + math.random() * 0.25, {
			CFrame = CFrame.new(center + dir * (6 + math.random() * 7)) * CFrame.Angles(math.random() * 9, math.random() * 9, math.random() * 9),
			Transparency = 1,
		})
		task.delay(0.9, function()
			shard:Destroy()
		end)
	end
	task.delay(0.7, function()
		p.Model:Destroy()
	end)

	screenFlash(show, if isLegendary then color:Lerp(WHITE, 0.5) else WHITE, 0.95, if isLegendary then 0.7 else 0.5)
	show.Burst.Color = ColorSequence.new(color, WHITE)
	show.Burst:Emit(40 + rank * 14)
	stageRing(show, color, 30, 0.5)
	shockwave(show.Root, color, if isLegendary then 1300 else 800)
	if isLegendary then
		task.delay(0.12, function()
			if show.Root.Parent then
				stageRing(show, WHITE, 40, 0.6)
				shockwave(show.Root, WHITE, 1000)
			end
		end)
	end
	starBurst(UDim2.fromScale(0.5, 0.5), color, if isLegendary then 40 else 20, if isLegendary then 460 else 300)
	shake(if rank >= MYTHIC_RANK then 8 elseif isLegendary then 6 elseif isEpic then 4 else 2.5, if isLegendary then 0.9 else 0.45)

	-- Kamera springt zurück (wirkt wie ein Rückstoß), Licht geht wieder an
	setShowColor(show, nil, color)
	setRays(show, 1, 0.3)
	show.Key.Brightness = 3
	show.Rim.Brightness = 2
	show.CamFov.Value = 72
	tween(show.CamFov, 0.6, { Value = 50 }, Enum.EasingStyle.Back)
	tween(show.CamPos, 0.6, { Value = Vector3.new(0, 4.4, 13.5) }, Enum.EasingStyle.Back)
	tween(show.CamLook, 0.4, { Value = Vector3.new(0, 3, 0) })
end

-- Kreatur als 3D-Modell für die Bühne. Gibt das Modell und seine Grundgröße zurück.
local function buildShowCreature(def, rank: number): (Model, number)
	local wanted = 3.5 + rank * 0.25 -- Höhe in Studs: seltene sind größer
	local folder = ReplicatedStorage:FindFirstChild("KreaturenModelle")
	local template = folder and folder:FindFirstChild(def.Id)
	if template and template:IsA("Model") then
		local model = template:Clone()
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				d.CanTouch = false
				d.CanQuery = false
				d.CastShadow = false
			elseif d:IsA("LuaSourceContainer") then
				d:Destroy()
			end
		end
		local height = model:GetExtentsSize().Y
		if height > 0.05 then
			return model, model:GetScale() * wanted / height
		end
		model:Destroy()
	end
	-- Backup ohne KI-Modell: Klotz mit Augen und Bauchbinde (schaut wie die Modelle nach -Z)
	local s = wanted * 0.8
	local model = Instance.new("Model")
	local body = stagePart({
		Name = "Body",
		Size = Vector3.new(s, s, s),
		CFrame = CFrame.new(0, s / 2, 0),
		Color = def.Color,
		Parent = model,
	})
	for _, x in { -0.22, 0.22 } do
		stagePart({
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * (s * 0.24),
			CFrame = CFrame.new(x * s, s * 0.62, -s * 0.5),
			Color = WHITE,
			Parent = model,
		})
		stagePart({
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * (s * 0.12),
			CFrame = CFrame.new(x * s, s * 0.6, -s * 0.59),
			Color = BLACK,
			Parent = model,
		})
	end
	stagePart({
		Size = Vector3.new(s * 1.04, s * 0.18, s * 1.04),
		CFrame = CFrame.new(0, s * 0.16, 0),
		Color = def.Accent,
		Parent = model,
	})
	body.PivotOffset = CFrame.new(0, -s / 2, 0) -- Pivot unten in der Mitte
	model.PrimaryPart = body
	return model, 1
end

-- Mutation: leuchtende Hülle über der Kreatur (wie in der Base)
local function addMutationShell(model: Model, mutationId: string, mutation)
	if not mutation.Color then
		return
	end
	-- Die ganze Kreatur bekommt einen Schimmer und einen Rand in der Farbe der Mutation.
	-- Erst blitzt sie ganz in der Farbe auf, dann scheint ihr eigenes Aussehen wieder durch.
	local glow = Instance.new("Highlight")
	glow.Name = "MutationsGlanz"
	glow.DepthMode = Enum.HighlightDepthMode.Occluded
	glow.FillColor = mutation.Color
	glow.FillTransparency = 0
	glow.OutlineColor = mutation.Color:Lerp(WHITE, 0.3)
	glow.OutlineTransparency = 0
	glow.Parent = model
	tween(glow, 0.5, { FillTransparency = 0.6 })
	if mutationId == "Regenbogen" then
		CollectionService:AddTag(glow, "Rainbow")
	end
end

-- 5. Akt: Die Kreatur wirbelt aus dem Licht nach oben und landet auf dem Podest.
-- Die Funktion kommt genau im Moment der Landung zurück (da gehört die Fanfare hin).
local function revealCreature(show, def, rank: number, color: Color3)
	local model, baseScale = buildShowCreature(def, rank)
	local c = makePuppet(show, model, baseScale, CFrame.Angles(0, math.pi, 0)) -- umdrehen: Gesicht zur Kamera
	c.Pos.Value = Vector3.new(0, PACK_Y - 0.8, 0)
	c.Size.Value = 0.12
	c.Tilt.Value = Vector3.new(0, -540, 0)
	updatePuppet(c)
	model.Parent = show.Folder
	c.Sparks = sparkEmitter(stagePart({
		Name = "Funken",
		Size = Vector3.new(3, 3, 3),
		CFrame = STAGE * CFrame.new(0, PEDESTAL_TOP + 2, 0),
		Transparency = 1,
		Parent = show.Folder,
	}), color, 0.6, 12)

	playSound("Appear")
	local rise = 0.52
	tween(c.Size, rise, { Value = 1 }, Enum.EasingStyle.Back)
	tween(c.Tilt, rise, { Value = Vector3.zero }, Enum.EasingStyle.Quart)
	tween(c.Pos, rise * 0.55, { Value = Vector3.new(0, PACK_Y + 0.4, 0) })
	task.wait(rise * 0.55)
	tweenIn(c.Pos, rise * 0.45, { Value = Vector3.new(0, PEDESTAL_TOP, 0) })
	task.wait(rise * 0.45)

	-- Landung
	c.Size.Value = 0.84
	tween(c.Size, 0.45, { Value = 1 }, Enum.EasingStyle.Elastic)
	c.IdleStart = os.clock()
	c.Idle = true
	show.Dust:Emit(10)
	stageRing(show, color, 20, 0.5)
	c.Sparks:Emit(20 + rank * 6)
	shake(if rank >= LEGENDARY_RANK then 4 else 1.5, 0.3)
	return c
end

local function stingerKey(rank: number): string
	if rank >= MYTHIC_RANK then
		return "Mythic"
	elseif rank >= LEGENDARY_RANK then
		return "Legendary"
	elseif rank >= EPIC_RANK then
		return "Epic"
	elseif rank >= RARE_RANK then
		return "Rare"
	end
	return "RevealCommon"
end

-- Schriftzug in der Mitte (y und Höhe als Anteil vom Bildschirm)
local function showLine(show, text: string, color: Color3, y: number, height: number): (TextLabel, UIScale)
	local l = label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, y),
		Size = UDim2.fromScale(0.9, height),
		Font = Enum.Font.FredokaOne,
		TextColor3 = color,
		TextStrokeTransparency = 0,
		Text = text,
		ZIndex = 4,
		Parent = show.Root,
	})
	stroke(l, BLACK, 3)
	local s = Instance.new("UIScale")
	s.Parent = l
	return l, s
end

-- Zahl zählt hoch, bei jedem Schritt ein Tick, der höher wird, am Ende ein "Ding"
local function countIncome(l: TextLabel, scale: UIScale, from: number, to: number, time: number, prefix: string?)
	local pre = prefix or ""
	local steps = math.clamp(math.floor(time / 0.05), 4, 12)
	for i = 1, steps do
		local v = from + (to - from) * (i / steps)
		l.Text = `{pre}+{Config.FormatNumber(math.floor(v + 0.5))} $/s`
		playSound("CountTick", 1 + i * 0.06)
		task.wait(time / steps)
	end
	l.Text = `{pre}+{Config.FormatNumber(to)} $/s`
	playSound("CountDone")
	scale.Scale = 1.35
	tween(scale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
end

local function showButton(show, text: string, color: Color3, xOffset: number): TextButton
	local b = Instance.new("TextButton")
	b.AnchorPoint = Vector2.new(0.5, 0.5)
	b.Position = UDim2.new(0.5, xOffset, 0.93, 0)
	b.Size = UDim2.fromOffset(230, 48)
	b.BackgroundColor3 = color
	b.Font = Enum.Font.FredokaOne
	b.TextScaled = true
	b.TextColor3 = WHITE
	b.TextStrokeTransparency = 0.5
	b.Text = text
	b.ZIndex = 6
	b.Parent = show.Root
	corner(b, 12)
	stroke(b, WHITE, 3).ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 7)
	pad.PaddingBottom = UDim.new(0, 7)
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.Parent = b
	local s = Instance.new("UIScale")
	s.Scale = 0
	s.Parent = b
	tween(s, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	return b
end

-- Letzter Akt: "Nochmal" und "Fertig". Wartet auf einen Klick oder bis die Zeit um ist.
local function waitForEnd(show, pack, count: number, seconds: number)
	local cost = if pack then Config.PackCost(pack, count) else 0
	local again: TextButton? = nil
	if pack and (player:GetAttribute("Money") or 0) >= cost then
		again = showButton(show, `Nochmal · {Config.FormatNumber(cost)} $`, Color3.fromRGB(60, 200, 90), -125)
		again.Activated:Connect(function()
			show.Again = true
		end)
	end
	local done = showButton(show, "Fertig", Color3.fromRGB(90, 90, 115), if again then 125 else 0)
	local baseClicks = show.Clicks
	done.Activated:Connect(function()
		show.Clicks += 1
	end)
	local stop = os.clock() + seconds
	while os.clock() < stop and not show.Again and show.Clicks == baseClicks do
		task.wait()
	end
	if show.Again or show.Clicks ~= baseClicks then
		playSound("Click")
	end
end

-- Ein Pack: die ganze Zwischensequenz mit einer Kreatur
local function openPackAnimation(entry: string, packId: string, wasPity: boolean)
	local def, mutationId = Config.ParseEntry(entry)
	if not def then
		return
	end
	local pack = findPack(packId)
	local rarity = Config.Rarities[def.Rarity]
	local mutation = Config.Mutations[mutationId]
	local rank = Config.RarityRank(def.Rarity)
	local isLegendary = rank >= LEGENDARY_RANK
	runShow(pack, 1, function(show)
		local p = enterPack(show, pack, "?")
		-- Seltene laden länger auf: 3 Schläge bei Gewöhnlich, bis 6 ab Episch
		local _ = chargePack(show, p, 2 + math.min(rank, 4), rank) or tellRarity(show, p, rank)
		show.Skip = false
		burstPack(show, p, rank, rarity.Color)
		local c = revealCreature(show, def, rank, rarity.Color)

		-- Landung: Fanfare und Schriftzug kommen im selben Moment
		playSound(stingerKey(rank))
		local banner, bannerScale = showLine(show, upperDe(rarity.Name) .. (if isLegendary then "!!" else "!"), rarity.Color, 0.16, 0.13)
		banner.Rotation = -5
		bannerScale.Scale = 3.2
		tween(bannerScale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
		tween(banner, 0.3, { Rotation = 0 }, Enum.EasingStyle.Back)
		if wasPity then
			showLine(show, "PITY-GARANTIE!", Color3.fromRGB(255, 230, 120), 0.065, 0.045)
		end
		if rank >= EPIC_RANK then
			confetti(if rank >= MYTHIC_RANK then 200 elseif isLegendary then 140 else 60)
		end
		if rank >= MYTHIC_RANK then
			-- Mythisch: es knallt noch ein paar Mal nach
			task.spawn(function()
				for i = 1, 3 do
					task.wait(0.45)
					if not show.Root.Parent then
						return
					end
					stageRing(show, if i % 2 == 0 then WHITE else rarity.Color, 30, 0.6)
					starBurst(UDim2.fromScale(0.25 + math.random() * 0.5, 0.25 + math.random() * 0.4), rarity.Color, 18, 260)
					c.Sparks:Emit(30)
				end
				confetti(120)
			end)
		end
		-- ruhige Kamerafahrt um die Kreatur, damit das Bild nicht steht
		task.delay(0.6, function()
			tween(show.CamPos, 6, { Value = Vector3.new(if isLegendary then 3.2 else 1.4, 4.1, 12.2) }, Enum.EasingStyle.Sine)
		end)

		task.wait(0.25)
		local name, nameScale = showLine(show, def.Name, WHITE, 0.79, 0.075)
		nameScale.Scale = 0.3
		tween(nameScale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
		playSound("Pop")
		task.wait(0.22)
		local income, incomeScale = showLine(show, "+0 $/s", Color3.fromRGB(130, 255, 130), 0.86, 0.055)
		countIncome(income, incomeScale, 0, def.Income, 0.4)

		if mutationId ~= "Normal" then
			-- Zweite Überraschung: der Mutations-Stempel knallt drauf, die Zahl springt hoch
			task.wait(0.3)
			local stampColor = mutation.Color or WHITE
			local stamp = label({
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.69, 0.36),
				Size = UDim2.fromScale(0.24, 0.085),
				BackgroundTransparency = 0,
				BackgroundColor3 = stampColor,
				Font = Enum.Font.FredokaOne,
				TextColor3 = BLACK,
				Text = `{string.upper(mutation.Name)} x{mutation.Multiplier}`,
				Rotation = 30,
				ZIndex = 5,
				Parent = show.Root,
			})
			corner(stamp, 12)
			stroke(stamp, WHITE, 4).ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			if mutationId == "Regenbogen" then
				CollectionService:AddTag(stamp, "RainbowGui")
			end
			local stampScale = Instance.new("UIScale")
			stampScale.Scale = 4
			stampScale.Parent = stamp
			tweenIn(stampScale, 0.16, { Scale = 1 })
			tweenIn(stamp, 0.16, { Rotation = 9 })
			task.wait(0.16)
			playSound("Stamp")
			shake(3.5, 0.3)
			screenFlash(show, stampColor, 0.45, 0.4)
			addMutationShell(c.Model, mutationId, mutation)
			c.Sparks.Color = ColorSequence.new(stampColor, WHITE)
			c.Sparks:Emit(40)
			c.Size.Value = 1.25
			tween(c.Size, 0.45, { Value = 1 }, Enum.EasingStyle.Elastic)
			stageRing(show, stampColor, 24, 0.5)
			name.Text = Config.EntryName(entry)
			name.TextColor3 = stampColor
			task.wait(0.25)
			countIncome(income, incomeScale, def.Income, Config.EntryIncome(entry), 0.45)
			confetti(60)
		end

		waitForEnd(show, pack, 1, if isLegendary then 9 elseif rank >= EPIC_RANK then 7 else 5.5)
	end)
end

-- Mehrere Packs: ein Pack platzt, die Karten fliegen verdeckt raus. Erst drehen sich die
-- normalen schnell um, die besten glühen schon vorher und kommen einzeln zum Schluss.
local function openMultiAnimation(entries: { string }, packId: string, pities: { boolean }, soldCount: number)
	local pack = findPack(packId)
	local packColor = pack and pack.Color or WHITE
	local bestRank = 1
	for _, entry in entries do
		local def = Config.ParseEntry(entry)
		if def then
			bestRank = math.max(bestRank, Config.RarityRank(def.Rarity))
		end
	end
	local bestRarity = Config.Rarities[Config.RarityOrder[bestRank]]
	runShow(pack, #entries, function(show)
		local p = enterPack(show, pack, `{#entries}x`)
		local _ = chargePack(show, p, 3, bestRank) or tellRarity(show, p, bestRank)
		show.Skip = false
		burstPack(show, p, bestRank, bestRarity.Color)

		-- Bühne etwas abdunkeln, damit man die Karten gut lesen kann
		local dim = Instance.new("Frame")
		dim.Size = UDim2.fromScale(1, 1)
		dim.BackgroundColor3 = BLACK
		dim.BackgroundTransparency = 1
		dim.BorderSizePixel = 0
		dim.Parent = show.Root
		tween(dim, 0.3, { BackgroundTransparency = 0.5 })
		local blur = Instance.new("BlurEffect")
		blur.Size = 0
		blur.Parent = workspace.CurrentCamera
		table.insert(show.Trash, blur)
		tween(blur, 0.3, { Size = 12 })

		-- Karten-Raster: alle in einer Reihe (bis 5) oder 5 x 2
		local perRow = if #entries <= 5 then #entries else 5
		local rowsCount = math.ceil(#entries / perRow)
		local cardW, cardH, gap = 150, 196, 14
		local grid = Instance.new("Frame")
		grid.AnchorPoint = Vector2.new(0.5, 0.5)
		grid.Position = UDim2.fromScale(0.5, 0.5)
		grid.Size = UDim2.fromOffset(perRow * cardW + (perRow - 1) * gap, rowsCount * cardH + (rowsCount - 1) * gap)
		grid.BackgroundTransparency = 1
		grid.Parent = show.Root
		local gridScale = Instance.new("UIScale")
		gridScale.Parent = grid
		local view = workspace.CurrentCamera.ViewportSize
		gridScale.Scale = math.min(1, (view.X - 40) / grid.Size.X.Offset, (view.Y - 230) / grid.Size.Y.Offset)

		local cards = {}
		for i, entry in entries do
			local def, mutationId = Config.ParseEntry(entry)
			if def then
				local rarity = Config.Rarities[def.Rarity]
				local mutation = Config.Mutations[mutationId]
				local col = (i - 1) % perRow
				local row = math.floor((i - 1) / perRow)
				local holder = Instance.new("Frame")
				holder.AnchorPoint = Vector2.new(0.5, 0.5)
				holder.Position = UDim2.fromScale(0.5, 0.5)
				holder.Size = UDim2.fromOffset(cardW, cardH)
				holder.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
				holder.ClipsDescendants = true
				holder.Rotation = math.random(-30, 30)
				holder.Parent = grid
				corner(holder, 14)
				local border = stroke(holder, WHITE, 4)
				local scale = Instance.new("UIScale")
				scale.Scale = 0.15
				scale.Parent = holder

				-- Vorderseite (erst unsichtbar)
				local front = Instance.new("Frame")
				front.Size = UDim2.fromScale(1, 1)
				front.BackgroundTransparency = 1
				front.Visible = false
				front.Parent = holder
				local header = label({
					Size = UDim2.new(1, 0, 0, 24),
					BackgroundTransparency = 0,
					BackgroundColor3 = rarity.Color,
					Font = Enum.Font.FredokaOne,
					TextStrokeTransparency = 0.4,
					Text = upperDe(rarity.Name),
					Parent = front,
				})
				local headerPad = Instance.new("UIPadding")
				headerPad.PaddingLeft = UDim.new(0, 12)
				headerPad.PaddingRight = UDim.new(0, 12)
				headerPad.PaddingTop = UDim.new(0, 2)
				headerPad.PaddingBottom = UDim.new(0, 2)
				headerPad.Parent = header
				local _, iconScale = creatureIcon(front, def, mutationId, 94, 24)
				label({
					Size = UDim2.new(1, -12, 0, 24),
					Position = UDim2.new(0, 6, 0, 118),
					Font = Enum.Font.FredokaOne,
					TextColor3 = rarity.Color,
					TextStrokeTransparency = 0.5,
					Text = Config.EntryName(entry),
					Parent = front,
				})
				if mutation.Name ~= "" then
					local mutationLabel = label({
						Size = UDim2.new(1, -24, 0, 18),
						Position = UDim2.new(0, 12, 0, 144),
						BackgroundTransparency = 0,
						BackgroundColor3 = mutation.Color or WHITE,
						Font = Enum.Font.FredokaOne,
						TextColor3 = BLACK,
						Text = `{string.upper(mutation.Name)} x{mutation.Multiplier}`,
						Parent = front,
					})
					corner(mutationLabel, 6)
					if mutationId == "Regenbogen" then
						CollectionService:AddTag(mutationLabel, "RainbowGui")
					end
				end
				label({
					Size = UDim2.new(1, -12, 0, 22),
					Position = UDim2.new(0, 6, 1, -28),
					TextColor3 = Color3.fromRGB(130, 255, 130),
					Text = if pities[i]
						then `PITY! +{Config.FormatNumber(Config.EntryIncome(entry))} $/s`
						else `+{Config.FormatNumber(Config.EntryIncome(entry))} $/s`,
					Parent = front,
				})
				-- Rückseite sieht aus wie das Pack
				local back = packFace(holder, "", "?", packColor, 14)

				table.insert(cards, {
					Index = i,
					Holder = holder,
					Scale = scale,
					Border = border,
					Front = front,
					Back = back,
					IconScale = iconScale,
					Rank = Config.RarityRank(def.Rarity),
					Color = mutation.Color or rarity.Color,
					RarityColor = rarity.Color,
					Mutated = mutationId ~= "Normal",
					Target = UDim2.fromOffset(col * (cardW + gap) + cardW / 2, row * (cardH + gap) + cardH / 2),
					Flipped = false,
				})
			end
		end

		-- Karte umdrehen. style: "quiet" (sofort, ohne Ton), "normal" oder "big" (mit Auftritt)
		local function flip(card, style: string, order: number)
			local holder = card.Holder
			if style ~= "quiet" then
				tweenIn(holder, 0.07, { Size = UDim2.fromOffset(0, cardH) })
				task.wait(0.07)
			end
			card.Flipped = true
			card.Back.Visible = false
			card.Front.Visible = true
			holder.Rotation = 0
			if card.Rank >= LEGENDARY_RANK then
				card.Border:Destroy()
				animatedBorder(holder, card.Color, 6)
			else
				card.Border.Color = card.Color
				card.Border.Thickness = if card.Rank >= EPIC_RANK then 6 else 4
			end
			holder.Size = UDim2.fromOffset(0, cardH)
			tween(holder, 0.22, { Size = UDim2.fromOffset(cardW, cardH) }, Enum.EasingStyle.Back)
			tween(card.IconScale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
			if card.Rank >= EPIC_RANK or card.Mutated then
				shineOnce(holder, 0.25)
			end
			if style == "quiet" then
				card.Scale.Scale = 1
				return
			end
			local center = UDim2.fromOffset(holder.AbsolutePosition.X + holder.AbsoluteSize.X / 2, holder.AbsolutePosition.Y + holder.AbsoluteSize.Y / 2)
			if style == "big" then
				-- großer Auftritt: Karte kommt nach vorne und bleibt kurz groß stehen
				holder.Parent = nil
				holder.Parent = grid
				local hold = if card.Rank >= LEGENDARY_RANK then 0.9 else 0.35
				card.Scale.Scale = 1.7
				tween(card.Scale, 0.3, { Scale = 1.4 }, Enum.EasingStyle.Back)
				task.delay(hold, function()
					tween(card.Scale, 0.25, { Scale = 1 })
				end)
				playSound(stingerKey(card.Rank))
				screenFlash(show, card.RarityColor, 0.35, 0.35)
				if card.Rank >= LEGENDARY_RANK then
					shake(if card.Rank >= MYTHIC_RANK then 7 else 5, 0.6)
					confetti(80)
					starBurst(center, card.RarityColor, 30, 320)
				else
					shake(2.5, 0.3)
					starBurst(center, card.RarityColor, 16, 200)
				end
				return
			end
			card.Scale.Scale = 1.2
			tween(card.Scale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
			if card.Mutated then
				playSound("Epic")
				starBurst(center, card.Color, 14, 170)
			elseif card.Rank >= RARE_RANK then
				playSound("Rare")
			else
				playSound("CardFlip", 1 + order * 0.05)
			end
		end

		-- Karten fliegen verdeckt aus der Mitte auf ihre Plätze
		for k, card in cards do
			playSound("CardDeal", 0.9 + k * 0.05)
			tween(card.Holder, 0.3, { Position = card.Target, Rotation = 0 }, Enum.EasingStyle.Back)
			tween(card.Scale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
			task.wait(0.055)
		end
		task.wait(0.3)

		local skipButton = Instance.new("TextButton")
		skipButton.AnchorPoint = Vector2.new(0.5, 0.5)
		skipButton.Position = UDim2.fromScale(0.5, 0.93)
		skipButton.Size = UDim2.fromOffset(220, 46)
		skipButton.BackgroundColor3 = Color3.fromRGB(255, 200, 60)
		skipButton.Font = Enum.Font.FredokaOne
		skipButton.TextScaled = true
		skipButton.TextColor3 = Color3.fromRGB(50, 35, 10)
		skipButton.Text = "Überspringen ⏩"
		skipButton.ZIndex = 6
		skipButton.Parent = show.Root
		corner(skipButton, 12)
		stroke(skipButton, WHITE, 3).ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		skipButton.Activated:Connect(function()
			show.Skip = true
		end)

		-- Vorschau: Karten ab Episch glühen schon verdeckt in ihrer Farbe
		local special, normal = {}, {}
		for _, card in cards do
			table.insert(if card.Rank >= EPIC_RANK then special else normal, card)
		end
		table.sort(special, function(a, b)
			if a.Rank ~= b.Rank then
				return a.Rank < b.Rank
			end
			return a.Index < b.Index
		end)
		if #special > 0 and not show.Skip then
			playSound("TellStep", 1.19)
			for _, card in special do
				card.Border.Color = card.RarityColor
				card.Border.Thickness = 7
				card.Scale.Scale = 1.18
				tween(card.Scale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
				shineOnce(card.Holder, 0)
			end
			beat(show, 0.45)
		end

		-- Erst die normalen, schnell hintereinander und jede einen Ton höher
		for k, card in normal do
			if show.Skip then
				break
			end
			flip(card, "normal", k)
			beat(show, if card.Rank >= RARE_RANK or card.Mutated then 0.28 else 0.13)
		end
		-- Dann die besten einzeln: Karte zittert, Ticks werden schneller, dann der Auftritt
		for _, card in special do
			if show.Skip then
				break
			end
			local wiggle = if card.Rank >= LEGENDARY_RANK then 0.75 else 0.42
			local start, ticks = os.clock(), 0
			while os.clock() - start < wiggle and not show.Skip do
				local t = os.clock() - start
				card.Holder.Rotation = math.sin(t * 42) * (3 + t * 6)
				if t > ticks * 0.07 then
					ticks += 1
					playSound("Tick", 1 + t)
				end
				task.wait()
			end
			card.Holder.Rotation = 0
			if show.Skip then
				break
			end
			flip(card, "big", 0)
			beat(show, if card.Rank >= LEGENDARY_RANK then 1.3 else 0.6)
		end

		-- Übersprungen: alles, was noch verdeckt ist, sofort aufdecken und die beste einmal feiern
		local skipped = show.Skip
		for _, card in cards do
			if not card.Flipped then
				flip(card, "quiet", 0)
			end
		end
		skipButton:Destroy()
		show.Skip = false
		if skipped then
			playSound(stingerKey(bestRank))
			if bestRank >= LEGENDARY_RANK then
				shake(5, 0.5)
			end
		end
		if bestRank >= EPIC_RANK then
			confetti(if bestRank >= LEGENDARY_RANK then 120 else 50)
		end

		-- Zusammenfassung: was bringt das alles zusammen?
		local total = 0
		for _, entry in entries do
			total += Config.EntryIncome(entry)
		end
		task.wait(0.25)
		local sum, sumScale = showLine(show, "Zusammen +0 $/s", Color3.fromRGB(130, 255, 130), 0.1, 0.07)
		countIncome(sum, sumScale, 0, total, 0.5, "Zusammen ")
		if soldCount > 0 then
			label({
				AnchorPoint = Vector2.new(0.5, 0.5),
				Size = UDim2.new(0.9, 0, 0, 24),
				Position = UDim2.fromScale(0.5, 0.86),
				TextColor3 = Color3.fromRGB(215, 215, 225),
				Text = `Base voll: {soldCount} schwächste automatisch verkauft`,
				ZIndex = 4,
				Parent = show.Root,
			})
		end
		waitForEnd(show, pack, #entries, if bestRank >= LEGENDARY_RANK then 10 else 7)
	end)
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
		elseif part:IsA("Highlight") then
			part.FillColor = color
			part.OutlineColor = color
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

-- Hausdächer: Stehe ich in einem Haus, wird dessen Dach für mich durchsichtig, damit die
-- Kamera von oben hineinschauen kann. Alle anderen sehen das Dach weiter.
do
	local fade = {} -- [Base-Modell] = 0 (Dach sichtbar) bis 1 (ausgeblendet)
	local function apply(model: Instance, alpha: number)
		local deko = model:FindFirstChild("Deko")
		if not deko then
			return
		end
		for _, d in deko:GetChildren() do
			if d:IsA("BasePart") and CollectionService:HasTag(d, "HausDach") then
				d.LocalTransparencyModifier = alpha
			end
		end
	end
	RunService.Heartbeat:Connect(function(dt)
		local map = workspace:FindFirstChild("KreaturenMap")
		local bases = map and map:FindFirstChild("Bases")
		if not bases then
			return
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		for _, model in bases:GetChildren() do
			local target = 0
			local floor = model:FindFirstChild("Boden")
			if root and floor and floor:IsA("BasePart") then
				local p = floor.CFrame:PointToObjectSpace(root.Position)
				-- die vorderen 5 Studs des Bodens sind die Veranda vor dem Tor, die zählt nicht
				if math.abs(p.X) <= floor.Size.X / 2 and p.Z >= -floor.Size.Z / 2 + 5 and p.Z <= floor.Size.Z / 2 and p.Y > -2 and p.Y < 45 then
					target = 1
				end
			end
			local alpha = fade[model] or 0
			if alpha ~= target then
				local step = dt * 4
				alpha = if target > alpha then math.min(target, alpha + step) else math.max(target, alpha - step)
				fade[model] = alpha
				apply(model, alpha)
			end
		end
	end)
	-- Wird das Haus neu gebaut (Upgrade), während ich drin stehe: neue Dachteile gleich ausblenden
	CollectionService:GetInstanceAddedSignal("HausDach"):Connect(function(inst)
		local model = findPlot(inst)
		if model and inst:IsA("BasePart") then
			inst.LocalTransparencyModifier = fade[model] or 0
		end
	end)
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
-- ganz unten: wann es das nächste Token für den Skill-Baum gibt
local questToken = label({
	Size = UDim2.new(1, 0, 0, 20),
	Font = Enum.Font.FredokaOne,
	TextColor3 = Color3.fromRGB(120, 220, 255),
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "",
	LayoutOrder = 99,
	Parent = questBox,
})
local questRows = {}
local lastProgress = {}

Remotes.Quests.OnClientEvent:Connect(function(list, tokenIn: number?)
	if tokenIn then
		questToken.Text = if tokenIn <= 1 then "💠 Token: nächste Aufgabe!" else `💠 Token in {tokenIn} Aufgaben`
	end
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
rebirthPanel.Size = UDim2.fromOffset(620, 364)
rebirthPanel.Position = UDim2.new(0.5, -310, 0.5, -182)
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
-- Eigene, große Zeile dafür, was die nächste Wiedergeburt freischaltet
local rebirthUnlock = label({
	Size = UDim2.new(1, -32, 0, 30),
	Position = UDim2.fromOffset(16, 84),
	Font = Enum.Font.FredokaOne,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = Color3.fromRGB(255, 225, 120),
	Text = "",
	Parent = rebirthPanel,
})
stroke(rebirthUnlock, BLACK, 1.5)
local rebirthDesc = label({
	Size = UDim2.new(1, -32, 0, 44),
	Position = UDim2.fromOffset(16, 118),
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	TextColor3 = Color3.fromRGB(200, 200, 215),
	TextScaled = false,
	TextSize = 17,
	TextWrapped = true,
	Font = Enum.Font.Gotham,
	Text = "",
	Parent = rebirthPanel,
})
local costBar = Instance.new("Frame")
costBar.Size = UDim2.new(1, -32, 0, 26)
costBar.Position = UDim2.fromOffset(16, 170)
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
doRebirth.Position = UDim2.fromOffset(16, 204)
doRebirth.BackgroundColor3 = PURPLE
doRebirth.TextColor3 = Color3.new(1, 1, 1)
doRebirth.Font = Enum.Font.FredokaOne
doRebirth.TextScaled = true
doRebirth.Text = "WIEDERGEBURT!"
doRebirth.Parent = rebirthPanel
corner(doRebirth, 12)
local tokenLabel = label({
	Size = UDim2.new(1, -32, 0, 28),
	Position = UDim2.fromOffset(16, 266),
	Font = Enum.Font.FredokaOne,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = Color3.fromRGB(120, 220, 255),
	Text = "",
	Parent = rebirthPanel,
})

-- Tokens gibt man im Skill-Baum aus (Menus.luau)
local skillLink = Instance.new("TextButton")
skillLink.Size = UDim2.new(1, -32, 0, 46)
skillLink.Position = UDim2.fromOffset(16, 302)
skillLink.BackgroundColor3 = Color3.fromRGB(60, 120, 215)
skillLink.TextColor3 = Color3.new(1, 1, 1)
skillLink.Font = Enum.Font.FredokaOne
skillLink.TextScaled = true
skillLink.Text = "💠 Tokens im Skill-Baum ausgeben"
skillLink.Parent = rebirthPanel
corner(skillLink, 12)

local function updateRebirth()
	local rebirths = player:GetAttribute("Rebirths") or 0
	local money = player:GetAttribute("Money") or 0
	local tokens = player:GetAttribute("Tokens") or 0
	local cost = Config.RebirthCost(rebirths)
	rebirthInfo.Text = `Wiedergeburten: {rebirths}   ·   Einkommen x{Config.RebirthMultiplier(rebirths)} → x{Config.RebirthMultiplier(rebirths + 1)}`
	local unlock = Config.RebirthUnlock(rebirths)
	rebirthDesc.Text = `Du behältst deine {Config.Rebirth.KeepCreatures} besten Kreaturen. Geld und Base-Stufe starten neu. Dafür bekommst du für immer mehr Einkommen und +{Config.Rebirth.TokensPerRebirth} Tokens für den Skill-Baum.`
	if unlock then
		rebirthUnlock.Text = `🎁 Schaltet frei: {unlock.Name} mit neuen, stärkeren Kreaturen!`
		rebirthUnlock.TextColor3 = unlock.Color:Lerp(WHITE, 0.35)
	else
		rebirthUnlock.Text = "⭐ Alle Kisten freigeschaltet. Jede Wiedergeburt macht dich weiter reicher!"
		rebirthUnlock.TextColor3 = Color3.fromRGB(255, 225, 120)
	end
	costFill.Size = UDim2.fromScale(math.clamp(money / cost, 0, 1), 1)
	costText.Text = `{Config.FormatNumber(money)} / {Config.FormatNumber(cost)} $`
	doRebirth.BackgroundColor3 = if money >= cost then PURPLE else Color3.fromRGB(90, 90, 100)
	tokenLabel.Text = `💠 Tokens: {tokens}`
end
for _, attr in { "Money", "Rebirths", "Tokens" } do
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
		updateRebirth()
		local camera = workspace.CurrentCamera
		if camera then
			local size = camera.ViewportSize
			rebirthScale.Scale = math.min(1, size.X / 660, size.Y / 404)
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

-- Skill-Baum und Fusion (eigene Datei: Menus.luau)
local menus = require(script.Parent:WaitForChild("Menus"))({
	Gui = gui,
	Corner = corner,
	Label = label,
	Stroke = stroke,
	Tween = tween,
	PlaySound = playSound,
	StarBurst = starBurst,
	CreatureIcon = creatureIcon,
	Busy = function()
		return opening
	end,
})
skillLink.Activated:Connect(function()
	menus.ToggleSkills()
end)

-- Es ist immer nur ein Fenster offen: Geht eins auf, gehen die anderen zu.
do
	local panels = { shop, rebirthPanel, menus.SkillPanel, menus.MergePanel }
	for _, panel in panels do
		panel:GetPropertyChangedSignal("Visible"):Connect(function()
			if panel.Visible then
				for _, other in panels do
					if other ~= panel then
						other.Visible = false
					end
				end
			end
		end)
	end
end
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
