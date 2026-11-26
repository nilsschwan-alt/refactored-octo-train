-- Effekte in der Welt: Funken-Explosion, Schockwellen-Ring, Kreatur "ploppt" auf.
-- Alles verschwindet von selbst wieder.

local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local FX = {}

local folder = Instance.new("Folder")
folder.Name = "Effekte"
folder.Parent = workspace

local function anchorPart(position: Vector3): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.new(1, 1, 1)
	p.CFrame = CFrame.new(position)
	p.Parent = folder
	return p
end

-- Funken in alle Richtungen
function FX.Burst(position: Vector3, color: Color3, amount: number?)
	local holder = anchorPart(position)
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	e.LightEmission = 1
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 0) })
	e.Lifetime = NumberRange.new(0.6, 1.2)
	e.Speed = NumberRange.new(15, 30)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration = Vector3.new(0, -20, 0)
	e.Drag = 2
	e.Rate = 0
	e.Parent = holder
	e:Emit(amount or 40)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 18
	light.Brightness = 4
	light.Parent = holder
	TweenService:Create(light, TweenInfo.new(0.8), { Brightness = 0 }):Play()
	Debris:AddItem(holder, 2)
end

-- Leuchtender Ring, der sich am Boden ausbreitet
function FX.Ring(position: Vector3, color: Color3, radius: number)
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.Material = Enum.Material.Neon
	ring.Color = color
	ring.Transparency = 0.2
	ring.Size = Vector3.new(0.4, 2, 2)
	ring.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = folder
	TweenService:Create(ring, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.4, radius * 2, radius * 2),
		Transparency = 1,
	}):Play()
	Debris:AddItem(ring, 1)
end

-- Kreatur wächst mit Überschwinger aus dem Boden
function FX.PopIn(model: Model)
	if not model.PrimaryPart then
		return
	end
	local ok = pcall(function()
		model:ScaleTo(0.05)
	end)
	if not ok then
		return
	end
	task.spawn(function()
		local duration = 0.45
		local start = os.clock()
		while model.Parent do
			local t = math.min(1, (os.clock() - start) / duration)
			-- "Back"-Kurve: kurz über 1 hinaus, dann zurück
			local c = 1.7
			local eased = 1 + (c + 1) * (t - 1) ^ 3 + c * (t - 1) ^ 2
			pcall(function()
				model:ScaleTo(math.max(0.05, eased))
			end)
			if t >= 1 then
				break
			end
			task.wait()
		end
		if model.Parent then
			pcall(function()
				model:ScaleTo(1)
			end)
		end
	end)
end

return FX
