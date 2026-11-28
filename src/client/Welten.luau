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
	local label, tween, playSound = ctx.Label, ctx.Tween, ctx.PlaySound

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
	local homeHolder: Frame -- Halter des Heim-Knopfs (zum Ein- und Ausblenden)
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
		homeHolder.Visible = world ~= nil
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
	do
		local button, _, _, holder = ctx.HudButton(6, Color3.fromRGB(50, 165, 105), "🏠", "Heim", "H")
		homeButton, homeHolder = button, holder
		homeHolder.Visible = false
	end
	local function goHome()
		if homeHolder.Visible then
			playSound("Click")
			Remotes.GoHome:FireServer()
		end
	end
	homeButton.Activated:Connect(goHome)

	-- Knopf "Welten": Reise-Fenster, von überall direkt in eine offene Welt ------------
	local worldButton = ctx.HudButton(5, Color3.fromRGB(120, 95, 235), "🌀", "Welten", "T")

	local Stil = ctx.Stil -- gemeinsamer Fenster-Stil (Stil.luau)
	local ROW = 70
	local TRAVEL_GREEN = Color3.fromRGB(60, 190, 110)
	local panel, showPanel = Stil.Window(500, 78 + (#Config.Worlds.List + 1) * ROW + 30, Color3.fromRGB(120, 95, 235), "🌀 Welten")
	panel.Name = "WeltenFenster"
	local hint = label({
		Size = UDim2.new(1, -32, 0, 20),
		Position = UDim2.new(0, 16, 1, -30),
		Font = Enum.Font.GothamMedium,
		TextColor3 = Stil.Dim,
		Text = "Mit Beute auf dem Kopf kannst du nicht reisen.",
		Parent = panel,
	})

	-- Eine Zeile: Symbol, Name, Zeile darunter und der Knopf "Reisen"
	local rows = {}
	local function addRow(index: number, id: string, icon: string, name: string, color: Color3, world)
		local row, rowStroke = Stil.Panel(panel, UDim2.new(1, -32, 0, ROW - 8), UDim2.fromOffset(16, 78 + (index - 1) * ROW))
		rowStroke.Color = color
		rowStroke.Thickness = 2
		label({ Size = UDim2.fromOffset(44, 44), Position = UDim2.fromOffset(10, 9), Text = icon, Parent = row })
		label({
			Size = UDim2.fromOffset(240, 26),
			Position = UDim2.fromOffset(64, 7),
			Font = Enum.Font.FredokaOne,
			TextColor3 = color:Lerp(WHITE, 0.4),
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = name,
			Parent = row,
		})
		local sub = label({
			Size = UDim2.fromOffset(240, 18),
			Position = UDim2.fromOffset(64, 35),
			Font = Enum.Font.GothamMedium,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = "",
			Parent = row,
		})
		local go = Stil.Button(row, "Reisen", TRAVEL_GREEN, UDim2.fromOffset(132, 46), UDim2.new(1, -142, 0.5, -23))
		go.Button.Activated:Connect(function()
			local blocked = player:GetAttribute("Carrying") ~= nil
				or (world ~= nil and (not Config.WorldUnlocked(world, rebirths()) or player:GetAttribute("World") == world.Id))
			if blocked then
				playSound("Tick", 0.6)
				return
			end
			playSound("Click")
			go.Pop()
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
		local carrying = player:GetAttribute("Carrying") ~= nil
		for _, row in rows do
			local world = row.World
			local open = world == nil or Config.WorldUnlocked(world, rebirths())
			local isHere = world ~= nil and here == world.Id
			local can = open and not isHere and not carrying
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
			row.Go.SetText(if not open then "Gesperrt" elseif isHere then "Hier" else "Reisen")
			row.Go.SetEnabled(can, TRAVEL_GREEN)
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
		showPanel()
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
