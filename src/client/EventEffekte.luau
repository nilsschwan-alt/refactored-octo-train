-- Optik und Töne zu den Events (was ein Event bewirkt, rechnet der Server in Events.luau):
--   Meteor: Pfeil am Bildschirmrand mit Entfernung, Wumms und Kamera-Wackeln beim Einschlag
--   Goldrausch: goldenes Licht, Goldregen, goldener Bildschirmrand
--   Diebes-Nacht: kühle, dunkle Farben (auch in den Welten mit eigener Uhrzeit)
--   Klick-Fieber: glühender Bildschirmrand
-- Der Server sagt über Attribute an workspace, was gerade läuft:
--   EventName, EventPhase ("warn" / "active"), EventTarget (dorthin zeigt der Pfeil)
-- Wird von Main geladen. Main gibt seine Hilfsfunktionen mit (ctx).
-- Liegt in Studio unter: StarterPlayer > StarterPlayerScripts > Client > EventEffekte

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)

local WHITE = Color3.new(1, 1, 1)
local GOLD = Color3.fromRGB(255, 205, 60)
local ORANGE = Color3.fromRGB(255, 140, 40)
local FEVER = Color3.fromRGB(255, 95, 40)

-- Farbstimmung je Event (liegt über dem normalen Licht und über der Welt-Farbe)
local MOODS = {
	Goldrausch = { TintColor = Color3.fromRGB(255, 236, 175), Saturation = 0.15, Brightness = 0.04, Contrast = 0.05 },
	Diebesnacht = { TintColor = Color3.fromRGB(150, 165, 235), Saturation = -0.15, Brightness = -0.06, Contrast = 0.1 },
	Klickfieber = { TintColor = Color3.fromRGB(255, 220, 205), Saturation = 0.2, Brightness = 0, Contrast = 0.08 },
}
local NO_MOOD = { TintColor = WHITE, Saturation = 0, Brightness = 0, Contrast = 0 }
-- Leuchtender Bildschirmrand: Farbe und wie schnell er pulsiert
local GLOWS = {
	Goldrausch = { Color = GOLD, Pulse = 0.9 },
	Klickfieber = { Color = FEVER, Pulse = 0.6 },
}
local START_SOUNDS = { Goldrausch = "GoldStart", Diebesnacht = "NightStart", Klickfieber = "FeverStart" }

return function(ctx)
	local player = Players.LocalPlayer
	local Remotes = ReplicatedStorage:WaitForChild("Remotes")
	local corner, label, stroke, tween, playSound = ctx.Corner, ctx.Label, ctx.Stroke, ctx.Tween, ctx.PlaySound

	-- eigene Ebene über den ganzen Bildschirm, liegt unter der Knopf-Leiste und allen Fenstern
	local fx = Instance.new("ScreenGui")
	fx.Name = "EventEffekte"
	fx.ResetOnSpawn = false
	fx.IgnoreGuiInset = true
	fx.DisplayOrder = 0 -- SpielLeiste hat 1, SpielUI 2
	fx.Parent = player:WaitForChild("PlayerGui")

	local mood = Instance.new("ColorCorrectionEffect")
	mood.Name = "EventFarbe"
	mood.Parent = Lighting

	-- Leuchtender Rand ----------------------------------------------------------------
	local glow = Instance.new("Frame")
	glow.Name = "Rand"
	glow.Size = UDim2.fromScale(1, 1)
	glow.BackgroundTransparency = 1
	glow.Visible = false
	glow.Parent = fx
	local glowSides = {}
	-- { Größe, Position, Drehung des Verlaufs }: außen kräftig, nach innen durchsichtig
	for _, side in {
		{ UDim2.new(1, 0, 0, 90), UDim2.fromScale(0, 0), 90 },
		{ UDim2.new(1, 0, 0, 90), UDim2.new(0, 0, 1, -90), 270 },
		{ UDim2.new(0, 90, 1, 0), UDim2.fromScale(0, 0), 0 },
		{ UDim2.new(0, 90, 1, 0), UDim2.new(1, -90, 0, 0), 180 },
	} do
		local f = Instance.new("Frame")
		f.Size = side[1]
		f.Position = side[2]
		f.BorderSizePixel = 0
		f.BackgroundTransparency = 1
		f.Parent = glow
		local g = Instance.new("UIGradient")
		g.Rotation = side[3]
		g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1) })
		g.Parent = f
		table.insert(glowSides, f)
	end
	local glowTweens = {}

	local function setGlow(info)
		for _, t in glowTweens do
			t:Cancel()
		end
		table.clear(glowTweens)
		if not info then
			for _, f in glowSides do
				tween(f, 0.5, { BackgroundTransparency = 1 })
			end
			task.delay(0.55, function()
				if #glowTweens == 0 then
					glow.Visible = false
				end
			end)
			return
		end
		glow.Visible = true
		for _, f in glowSides do
			f.BackgroundColor3 = info.Color
			f.BackgroundTransparency = 0.75
			local t = TweenService:Create(f, TweenInfo.new(info.Pulse, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{ BackgroundTransparency = 0.35 })
			t:Play()
			table.insert(glowTweens, t)
		end
	end

	-- Goldregen -----------------------------------------------------------------------
	-- Ein unsichtbares Dach über der Kamera, aus dem Funken fallen (nur auf dem eigenen Bildschirm)
	local rain: Part? = nil
	local function setRain(on: boolean)
		if on and not rain then
			local p = Instance.new("Part")
			p.Name = "Goldregen"
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.Transparency = 1
			p.Size = Vector3.new(80, 1, 80)
			local e = Instance.new("ParticleEmitter")
			e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			e.Color = ColorSequence.new(Color3.fromRGB(255, 225, 90), Color3.fromRGB(255, 180, 40))
			e.LightEmission = 0.9
			e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(0.3, 0.9), NumberSequenceKeypoint.new(1, 0) })
			e.Lifetime = NumberRange.new(1.8, 2.6)
			e.Speed = NumberRange.new(14, 22)
			e.EmissionDirection = Enum.NormalId.Bottom
			e.SpreadAngle = Vector2.new(8, 8)
			e.Rotation = NumberRange.new(0, 360)
			e.RotSpeed = NumberRange.new(-120, 120)
			e.Rate = 70
			e.Parent = p
			p.Parent = workspace
			rain = p
		elseif not on and rain then
			local old = rain
			rain = nil
			local e = old:FindFirstChildOfClass("ParticleEmitter")
			if e then
				e.Enabled = false
			end
			task.delay(3, function()
				old:Destroy()
			end)
		end
	end

	-- Welches Event läuft gerade? -----------------------------------------------------
	local active: string? = nil
	local function refresh()
		local name = workspace:GetAttribute("EventName")
		local now: string? = if workspace:GetAttribute("EventPhase") == "active" and type(name) == "string" then name else nil
		if now == active then
			return
		end
		active = now
		tween(mood, 1.2, (now and MOODS[now]) or NO_MOOD)
		setGlow(now and GLOWS[now] or nil)
		setRain(now == "Goldrausch")
		if now and START_SOUNDS[now] then
			playSound(START_SOUNDS[now])
		end
	end
	workspace:GetAttributeChangedSignal("EventName"):Connect(refresh)
	workspace:GetAttributeChangedSignal("EventPhase"):Connect(refresh)
	refresh()

	-- Wegweiser zum Meteor --------------------------------------------------------------
	local pointer = Instance.new("Frame")
	pointer.Name = "Wegweiser"
	pointer.AnchorPoint = Vector2.new(0.5, 0.5)
	pointer.Size = UDim2.fromOffset(10, 10)
	pointer.BackgroundTransparency = 1
	pointer.Visible = false
	pointer.Parent = fx
	local pointerScale = Instance.new("UIScale")
	pointerScale.Parent = pointer
	local arrow = label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(56, 56),
		Font = Enum.Font.FredokaOne,
		TextColor3 = ORANGE,
		TextStrokeTransparency = 0,
		Text = "▲",
		Parent = pointer,
	})
	local distance = label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.5, 34),
		Size = UDim2.fromOffset(120, 28),
		BackgroundTransparency = 0.2,
		BackgroundColor3 = Color3.fromRGB(30, 20, 20),
		Font = Enum.Font.FredokaOne,
		TextColor3 = WHITE,
		Text = "",
		Parent = pointer,
	})
	corner(distance, 14)
	stroke(distance, ORANGE, 2).ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	TweenService:Create(pointerScale, TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = 1.15 }):Play()

	-- Ränder, die der Pfeil frei lässt: links die Knopf-Leiste mit der Geld-Anzeige, rechts die
	-- Aufgaben, oben Ansage und Countdown, unten die Combo-Anzeige. Auf kleinen Bildschirmen
	-- (Handy quer) schrumpfen sie mit, sonst bliebe für den Pfeil kein Platz.
	local MAX_LEFT, MAX_RIGHT, MAX_TOP, MAX_BOTTOM = 310, 340, 230, 280
	local hideAt = Config.Events.Meteor.ArrowHide

	RunService.RenderStepped:Connect(function()
		local target = workspace:GetAttribute("EventTarget")
		local camera = workspace.CurrentCamera
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if typeof(target) ~= "Vector3" or not camera or not root or not root:IsA("BasePart") or (ctx.Busy and ctx.Busy()) then
			pointer.Visible = false
			return
		end
		local view = camera.ViewportSize
		local LEFT = math.min(MAX_LEFT, view.X * 0.3)
		local RIGHT = math.min(MAX_RIGHT, view.X * 0.3)
		local TOP = math.min(MAX_TOP, view.Y * 0.28)
		local BOTTOM = math.min(MAX_BOTTOM, view.Y * 0.3)
		local world = player:GetAttribute("World")
		if type(world) == "string" and world ~= "" then
			-- In einer Welt ist der Meteor zu weit weg für einen Pfeil: nur ein Hinweis oben
			pointer.Visible = true
			arrow.Visible = false
			distance.Size = UDim2.fromOffset(300, 28)
			distance.Text = "☄️ Meteor auf der Hauptinsel!"
			pointer.Position = UDim2.fromOffset(view.X / 2, math.max(view.Y * 0.7, view.Y - MAX_BOTTOM - 10))
			return
		end
		local far = (target - root.Position).Magnitude
		if far < hideAt then
			pointer.Visible = false
			return
		end
		pointer.Visible = true
		arrow.Visible = true
		distance.Size = UDim2.fromOffset(120, 28)
		distance.Text = `☄️ {math.floor(far)} m`

		local p = camera:WorldToViewportPoint(target + Vector3.new(0, 6, 0))
		local at = Vector2.new(p.X, p.Y)
		local inFront = p.Z > 0
		if inFront and at.X > LEFT and at.X < view.X - RIGHT and at.Y > TOP and at.Y < view.Y - BOTTOM then
			-- Stelle ist im Bild: Pfeil zeigt von oben darauf
			pointer.Position = UDim2.fromOffset(at.X, at.Y - 60)
			arrow.Rotation = 180
			return
		end
		-- Sonst klebt der Pfeil am Bildschirmrand und zeigt in die Richtung
		local center = view / 2
		local dir = at - center
		if not inFront then
			dir = -dir
		end
		if dir.Magnitude < 1 then
			dir = Vector2.new(0, 1)
		end
		local roomX = math.max(20, if dir.X > 0 then view.X - RIGHT - center.X else center.X - LEFT)
		local roomY = math.max(20, if dir.Y > 0 then view.Y - BOTTOM - center.Y else center.Y - TOP)
		local scale = math.min(
			if math.abs(dir.X) > 0.001 then roomX / math.abs(dir.X) else math.huge,
			if math.abs(dir.Y) > 0.001 then roomY / math.abs(dir.Y) else math.huge
		)
		local edge = center + dir * scale
		pointer.Position = UDim2.fromOffset(edge.X, edge.Y)
		arrow.Rotation = math.deg(math.atan2(dir.Y, dir.X)) + 90
	end)

	-- Einmalige Effekte vom Server ------------------------------------------------------
	local flash = Instance.new("Frame")
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.fromRGB(255, 200, 140)
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.Parent = fx

	Remotes.EventFx.OnClientEvent:Connect(function(kind: string, position: Vector3?)
		if kind == "MeteorImpact" and typeof(position) == "Vector3" then
			local camera = workspace.CurrentCamera
			local range = Config.Events.Meteor.ShakeRange
			local far = if camera then (camera.CFrame.Position - position).Magnitude else math.huge
			if far > range or (ctx.Busy and ctx.Busy()) then
				return
			end
			-- je näher, desto mehr Wumms
			local near = 1 - far / range
			playSound("MeteorImpact")
			if ctx.Shake then
				ctx.Shake(1.5 + near * 6, 0.5 + near * 0.6)
			end
			if near > 0.5 then
				flash.BackgroundTransparency = 1 - (near - 0.5) * 1.2
				tween(flash, 0.6, { BackgroundTransparency = 1 })
			end
		elseif kind == "Shadow" then
			playSound("ShadowNear")
		end
	end)

	RunService.RenderStepped:Connect(function()
		if rain then
			local camera = workspace.CurrentCamera
			if camera then
				rain.CFrame = CFrame.new(camera.Focus.Position + Vector3.new(0, 26, 0))
			end
		end
	end)
end
