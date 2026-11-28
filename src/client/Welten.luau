-- Welten auf dem Client: Portal-Wirbel drehen, rote Sperre und Schild je nach eigener
-- Wiedergeburt, Licht-Stimmung je Welt, Lichtblitz beim Reisen und der Knopf "Heim".
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

	local function applyWorld()
		local world = Config.WorldById[player:GetAttribute("World") or ""]
		tween(tint, 0.6, { TintColor = if world then world.Tint else WHITE })
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
	homeButton.Position = UDim2.new(0, 332, 0.5, 40)
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
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.H then
			goHome()
		end
	end)

	player:GetAttributeChangedSignal("World"):Connect(applyWorld)
	applyWorld()
end
