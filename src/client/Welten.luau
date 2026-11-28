-- Welten auf dem Client: Portal-Wirbel drehen, rote Sperre und Schild je nach eigener
-- Wiedergeburt, Licht-Stimmung je Welt, Lichtblitz beim Reisen, der Knopf "Heim" und
-- der Knopf "Welten" mit dem Reise-Fenster (von überall direkt in eine offene Welt).
-- Wird von Main geladen. Main gibt seine Hilfsfunktionen mit (ctx).
-- Liegt in Studio unter: StarterPlayer > StarterPlayerScripts > Client > Welten

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)

local WHITE = Color3.new(1, 1, 1)
local GREEN = Color3.fromRGB(120, 255, 150)
local RED = Color3.fromRGB(255, 120, 120)
-- winziger Versatz: daran erkennt das Skript seine eigene Uhrzeit wieder
local CLOCK_MARK = 0.0137

return function(ctx)
	local player = Players.LocalPlayer
	local Remotes = ReplicatedStorage:WaitForChild("Remotes")
	local gui: ScreenGui = ctx.Gui
	local corner, label, stroke, tween, playSound = ctx.Corner, ctx.Label, ctx.Stroke, ctx.Tween, ctx.PlaySound

	local function rebirths(): number
		return player:GetAttribute("Rebirths") or 0
	end

	-- Portale: Sperre und Schild ------------------------------------------------------
	-- Wer genug Wiedergeburten hat, sieht die rote Sperre nicht und läuft einfach durch.
	local function refreshLock(part: Instance)
		if part:IsA("BasePart") then
			local open = rebirths() >= (part:GetAttribute("Rebirths") or 0)
			part.CanCollide = not open
			part.LocalTransparencyModifier = if open then 1 else 0
		end
	end

	local function refreshSign(sign: Instance)
		task.spawn(function()
			local line = sign:WaitForChild("Zeile2", 5)
			if line and line:IsA("TextLabel") then
				local need = sign:GetAttribute("Rebirths") or 0
				if rebirths() >= need then
					line.Text = "✅ Offen, lauf hinein!"
					line.TextColor3 = GREEN
				else
					line.Text = `🔒 ab Wiedergeburt {need}`
					line.TextColor3 = RED
				end
			end
		end)
	end

	local function refreshPortals()
		for _, part in CollectionService:GetTagged("PortalSperre") do
			refreshLock(part)
		end
		for _, sign in CollectionService:GetTagged("PortalSchild") do
			refreshSign(sign)
		end
	end
	CollectionService:GetInstanceAddedSignal("PortalSperre"):Connect(refreshLock)
	CollectionService:GetInstanceAddedSignal("PortalSchild"):Connect(refreshSign)
	player:GetAttributeChangedSignal("Rebirths"):Connect(refreshPortals)
	refreshPortals()

	-- Der Wirbel im Portal dreht sich
	local wirbelBase = setmetatable({}, { __mode = "k" })
	RunService.RenderStepped:Connect(function()
		local angle = os.clock() * 1.6
		for _, bar in CollectionService:GetTagged("PortalWirbel") do
			if bar:IsA("BasePart") then
				local base = wirbelBase[bar]
				if not base then
					base = bar.CFrame
					wirbelBase[bar] = base
				end
				bar.CFrame = base * CFrame.Angles(0, 0, angle)
			end
		end
	end)

	-- Licht-Stimmung je Welt ---------------------------------------------------------
	-- Farbstich und (wo eingestellt) eigene Uhrzeit. Das gilt nur für den eigenen Bildschirm.
	local tint = Instance.new("ColorCorrectionEffect")
	tint.Name = "WeltFarbe"
	tint.Parent = Lighting

	local outsideClock = Lighting.ClockTime -- Uhrzeit, die der Server gerade vorgibt
	local wantedClock: number? = nil
	Lighting:GetPropertyChangedSignal("ClockTime"):Connect(function()
		local now = Lighting.ClockTime
		if wantedClock and math.abs(now - wantedClock) < 0.0005 then
			return -- das war unsere eigene Änderung
		end
		-- Der Server hat die Uhr gestellt (z.B. Diebes-Nacht): merken, in der Welt aber dabei bleiben
		outsideClock = now
		if wantedClock then
			Lighting.ClockTime = wantedClock
		end
	end)

	local homeButton: TextButton
	local outsideSky -- Dunst-Farben der Hauptinsel, beim ersten Mal gemerkt
	local outsideAmbient = Lighting.OutdoorAmbient -- Schattenlicht der Hauptinsel
	local outsideBloom -- Leuchten der Hauptinsel, beim ersten Mal gemerkt

	local function applyWorld()
		local world = Config.WorldById[player:GetAttribute("World") or ""]
		tween(tint, 0.6, { TintColor = if world then world.Tint else WHITE })
		local haze = Lighting:FindFirstChild("SpielDunst")
		if haze and haze:IsA("Atmosphere") then
			outsideSky = outsideSky
				or { Color = haze.Color, Decay = haze.Decay, Density = haze.Density, Offset = haze.Offset, Haze = haze.Haze }
			local sky = (world and world.Sky) or outsideSky
			-- was eine Welt nicht festlegt, bleibt wie auf der Hauptinsel
			local goal = {}
			for key, value in outsideSky do
				goal[key] = if sky[key] ~= nil then sky[key] else value
			end
			tween(haze, 0.6, goal)
		end
		tween(Lighting, 0.6, { OutdoorAmbient = (world and world.Ambient) or outsideAmbient })
		local bloom = Lighting:FindFirstChild("SpielLeuchten")
		if bloom and bloom:IsA("BloomEffect") then
			outsideBloom = outsideBloom or { Intensity = bloom.Intensity, Threshold = bloom.Threshold }
			local want = (world and world.Bloom) or outsideBloom
			bloom.Intensity = want.Intensity or outsideBloom.Intensity
			bloom.Threshold = want.Threshold or outsideBloom.Threshold
		end
		if world and world.Clock then
			wantedClock = world.Clock + CLOCK_MARK
			Lighting.ClockTime = wantedClock
		elseif wantedClock then
			wantedClock = nil
			Lighting.ClockTime = outsideClock
		end
		homeButton.Visible = world ~= nil
	end

	-- Lichtblitz beim Reisen
	local flash = Instance.new("Frame")
	flash.Name = "ReiseBlitz"
	flash.Size = UDim2.new(1, 0, 1, 200)
	flash.Position = UDim2.fromOffset(0, -100)
	flash.BackgroundColor3 = WHITE
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.ZIndex = 60
	flash.Active = false
	flash.Parent = gui
	Remotes.Travel.OnClientEvent:Connect(function(worldId: string?)
		local world = worldId and Config.WorldById[worldId]
		playSound("Travel")
		flash.BackgroundColor3 = if world then world.Color:Lerp(WHITE, 0.65) else WHITE
		tween(flash, 0.15, { BackgroundTransparency = 0 })
		task.delay(0.6, function()
			tween(flash, 0.7, { BackgroundTransparency = 1 })
		end)
	end)

	-- Knopf "Heim": nur in einer Welt zu sehen, bringt einen direkt vor die eigene Base
	homeButton = Instance.new("TextButton")
	homeButton.Name = "HeimKnopf"
	homeButton.Size = UDim2.fromOffset(72, 72)
	homeButton.Position = UDim2.new(0, 412, 0.5, 40)
	homeButton.BackgroundColor3 = Color3.fromRGB(50, 165, 105)
	homeButton.Text = ""
	homeButton.Visible = false
	homeButton.Parent = gui
	corner(homeButton, 12)
	stroke(homeButton, WHITE, 2)
	label({ Size = UDim2.new(1, 0, 0.62, 0), Position = UDim2.fromScale(0, 0.04), Text = "🏠", Parent = homeButton })
	label({
		Size = UDim2.new(1, -8, 0.3, 0),
		Position = UDim2.new(0, 4, 0.66, 0),
		Font = Enum.Font.FredokaOne,
		TextStrokeTransparency = 0.4,
		Text = "Heim",
		Parent = homeButton,
	})
	local function goHome()
		if homeButton.Visible then
			playSound("Click")
			Remotes.GoHome:FireServer()
		end
	end
	homeButton.Activated:Connect(goHome)

	-- Knopf "Welten": Reise-Fenster, von überall direkt in eine offene Welt ------------
	local worldButton = Instance.new("TextButton")
	worldButton.Name = "WeltenKnopf"
	worldButton.Size = UDim2.fromOffset(72, 72)
	worldButton.Position = UDim2.new(0, 332, 0.5, 40)
	worldButton.BackgroundColor3 = Color3.fromRGB(120, 95, 235)
	worldButton.Text = ""
	worldButton.Parent = gui
	corner(worldButton, 12)
	stroke(worldButton, WHITE, 2)
	label({ Size = UDim2.new(1, 0, 0.62, 0), Position = UDim2.fromScale(0, 0.04), Text = "🌀", Parent = worldButton })
	label({
		Size = UDim2.new(1, -8, 0.3, 0),
		Position = UDim2.new(0, 4, 0.66, 0),
		Font = Enum.Font.FredokaOne,
		TextStrokeTransparency = 0.4,
		Text = "Welten",
		Parent = worldButton,
	})

	local ROW = 62
	local panel = Instance.new("Frame")
	panel.Name = "WeltenFenster"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(460, 74 + (#Config.Worlds.List + 1) * ROW + 34)
	panel.BackgroundColor3 = Color3.fromRGB(26, 23, 40)
	panel.Visible = false
	panel.Active = true -- fängt Klicks ab, damit im Fenster kein Klick-Geld entsteht
	panel.Parent = gui
	corner(panel, 14)
	stroke(panel, Color3.fromRGB(120, 95, 235), 3)
	local panelScale = Instance.new("UIScale")
	panelScale.Parent = panel
	label({
		Size = UDim2.fromOffset(330, 40),
		Position = UDim2.fromOffset(16, 8),
		Font = Enum.Font.FredokaOne,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "🌀 Welten",
		Parent = panel,
	})
	local close = Instance.new("TextButton")
	close.Size = UDim2.fromOffset(40, 40)
	close.Position = UDim2.new(1, -50, 0, 10)
	close.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
	close.Text = "X"
	close.TextColor3 = WHITE
	close.Font = Enum.Font.GothamBold
	close.TextScaled = true
	close.Parent = panel
	corner(close, 8)
	close.Activated:Connect(function()
		panel.Visible = false
	end)
	local hint = label({
		Size = UDim2.new(1, -32, 0, 20),
		Position = UDim2.new(0, 16, 1, -30),
		Font = Enum.Font.Gotham,
		TextColor3 = Color3.fromRGB(190, 185, 215),
		Text = "Mit Beute auf dem Kopf kannst du nicht reisen.",
		Parent = panel,
	})

	-- Eine Zeile: Symbol, Name, Zeile darunter und der Knopf "Reisen"
	local rows = {}
	local function addRow(index: number, id: string, icon: string, name: string, color: Color3, world)
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -32, 0, ROW - 8)
		row.Position = UDim2.fromOffset(16, 62 + (index - 1) * ROW)
		row.BackgroundColor3 = Color3.fromRGB(40, 36, 60)
		row.Parent = panel
		corner(row, 10)
		local rowStroke = stroke(row, color, 2)
		label({ Size = UDim2.fromOffset(44, 44), Position = UDim2.fromOffset(8, 5), Text = icon, Parent = row })
		label({
			Size = UDim2.fromOffset(220, 26),
			Position = UDim2.fromOffset(62, 4),
			Font = Enum.Font.FredokaOne,
			TextColor3 = color:Lerp(WHITE, 0.4),
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = name,
			Parent = row,
		})
		local sub = label({
			Size = UDim2.fromOffset(220, 18),
			Position = UDim2.fromOffset(62, 31),
			Font = Enum.Font.Gotham,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = "",
			Parent = row,
		})
		local go = Instance.new("TextButton")
		go.Size = UDim2.fromOffset(120, 40)
		go.Position = UDim2.new(1, -128, 0.5, -20)
		go.Font = Enum.Font.FredokaOne
		go.TextScaled = true
		go.TextColor3 = WHITE
		go.Text = "Reisen"
		go.Parent = row
		corner(go, 10)
		local goPad = Instance.new("UIPadding") -- Schrift nicht bis an den Rand
		goPad.PaddingTop, goPad.PaddingBottom = UDim.new(0, 6), UDim.new(0, 6)
		goPad.PaddingLeft, goPad.PaddingRight = UDim.new(0, 8), UDim.new(0, 8)
		goPad.Parent = go
		go.Activated:Connect(function()
			if world and not Config.WorldUnlocked(world, rebirths()) then
				playSound("Tick", 0.6)
				return
			end
			playSound("Click")
			panel.Visible = false
			Remotes.TravelTo:FireServer(id)
		end)
		table.insert(rows, { World = world, Id = id, Sub = sub, Go = go, Stroke = rowStroke, Color = color })
	end
	addRow(1, "Hub", "🌀", "Portal-Platz", Color3.fromRGB(255, 200, 60), nil)
	for i, world in Config.Worlds.List do
		addRow(i + 1, world.Id, world.Icon, world.Name, world.Color, world)
	end

	local function refreshRows()
		local here = player:GetAttribute("World")
		for _, row in rows do
			local world = row.World
			local open = world == nil or Config.WorldUnlocked(world, rebirths())
			if not world then
				row.Sub.Text = "hinter dem Kisten-Shop"
				row.Sub.TextColor3 = Color3.fromRGB(205, 200, 225)
			elseif not open then
				row.Sub.Text = `🔒 ab Wiedergeburt {world.Rebirths}`
				row.Sub.TextColor3 = RED
			elseif here == world.Id then
				row.Sub.Text = "✅ Hier bist du gerade"
				row.Sub.TextColor3 = GREEN
			else
				row.Sub.Text = `Klick-Geld x{(string.gsub(tostring(world.ClickFactor), "%.", ","))} · wilde Monster`
				row.Sub.TextColor3 = Color3.fromRGB(205, 200, 225)
			end
			row.Go.Text = if open then "Reisen" else "Gesperrt"
			row.Go.BackgroundColor3 = if open then Color3.fromRGB(60, 190, 110) else Color3.fromRGB(95, 95, 110)
			row.Go.AutoButtonColor = open
			row.Stroke.Transparency = if open then 0 else 0.6
		end
		hint.Visible = player:GetAttribute("Carrying") ~= nil
	end

	local function toggleWorlds()
		if panel.Visible then
			panel.Visible = false
			return
		end
		refreshRows()
		local fit = 1
		local camera = workspace.CurrentCamera
		if camera then
			local size = camera.ViewportSize
			fit = math.min(1, size.X / (panel.Size.X.Offset + 40), size.Y / (panel.Size.Y.Offset + 40))
		end
		panelScale.Scale = fit * 0.8
		tween(panelScale, 0.25, { Scale = fit }, Enum.EasingStyle.Back)
		panel.Visible = true
		playSound("Click")
	end
	worldButton.Activated:Connect(toggleWorlds)
	player:GetAttributeChangedSignal("Rebirths"):Connect(refreshRows)
	player:GetAttributeChangedSignal("World"):Connect(refreshRows)
	player:GetAttributeChangedSignal("Carrying"):Connect(refreshRows)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.H then
			goHome()
		elseif input.KeyCode == Enum.KeyCode.T then
			toggleWorlds()
		end
	end)

	player:GetAttributeChangedSignal("World"):Connect(applyWorld)
	applyWorld()
	return { Panel = panel }
end
