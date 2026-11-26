-- Baut eine Kreatur aus einfachen Blöcken.
-- Vorne ist -Z (dahin schaut die Kreatur). Der Pivot liegt unten in der Mitte,
-- damit model:PivotTo(cf) die Kreatur genau auf den Boden bei cf stellt.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local CreatureModels = {}

local GOLD = Color3.fromRGB(255, 200, 50)

local function makePart(model: Model, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = true
	p.CanCollide = false
	p.CastShadow = true
	p.Parent = model
	return p
end

-- opts = { Scale = number?, Anchored = boolean?, Label = boolean? }
function CreatureModels.Build(def, opts): Model
	opts = opts or {}
	local rarity = Config.Rarities[def.Rarity]
	local s = rarity.Size * (opts.Scale or 1)
	local h = s * 0.8 -- Körperhöhe
	local top = h -- Oberkante des Körpers

	local model = Instance.new("Model")
	model.Name = def.Id

	local bodyMaterial = if def.Rarity == "Mythic" then Enum.Material.Glass else Enum.Material.SmoothPlastic
	local body = makePart(model, Vector3.new(s, h, s), CFrame.new(0, h / 2, 0), def.Color, bodyMaterial)
	body.Name = "Body"
	body.PivotOffset = CFrame.new(0, -h / 2, 0)
	model.PrimaryPart = body

	-- Augen
	local front = -s / 2
	for _, side in { -1, 1 } do
		makePart(model, Vector3.new(s * 0.26, s * 0.26, 0.1), CFrame.new(side * s * 0.22, h * 0.68, front - 0.05),
			Color3.new(1, 1, 1))
		makePart(model, Vector3.new(s * 0.12, s * 0.14, 0.1), CFrame.new(side * s * 0.22, h * 0.66, front - 0.12),
			Color3.new(0.05, 0.05, 0.05))
	end
	-- Mund
	makePart(model, Vector3.new(s * 0.3, s * 0.06, 0.1), CFrame.new(0, h * 0.35, front - 0.05), def.Accent)

	-- Füße
	for _, side in { -1, 1 } do
		makePart(model, Vector3.new(s * 0.3, s * 0.12, s * 0.35), CFrame.new(side * s * 0.28, s * 0.06, front + s * 0.15),
			def.Accent)
	end

	-- Form-Zusatz
	local extra = def.Extra
	local accent = def.Accent
	if extra == "Ohren" then
		for _, side in { -1, 1 } do
			makePart(model, Vector3.new(s * 0.22, s * 0.4, s * 0.15), CFrame.new(side * s * 0.3, top + s * 0.2, 0), accent)
		end
	elseif extra == "Hoerner" then
		for _, side in { -1, 1 } do
			makePart(model, Vector3.new(s * 0.12, s * 0.5, s * 0.12),
				CFrame.new(side * s * 0.3, top + s * 0.22, -s * 0.1) * CFrame.Angles(0, 0, math.rad(-side * 20)), accent,
				Enum.Material.Neon)
		end
	elseif extra == "Panzer" then
		makePart(model, Vector3.new(s * 0.9, s * 0.5, s * 0.7), CFrame.new(0, top + s * 0.2, s * 0.15), accent)
		makePart(model, Vector3.new(s * 0.5, s * 0.25, s * 0.4), CFrame.new(0, top + s * 0.55, s * 0.15), accent,
			Enum.Material.Neon)
	elseif extra == "Fuehler" then
		for _, side in { -1, 1 } do
			makePart(model, Vector3.new(0.15, s * 0.5, 0.15), CFrame.new(side * s * 0.2, top + s * 0.25, -s * 0.2),
				Color3.new(0.1, 0.1, 0.1))
			makePart(model, Vector3.new(s * 0.18, s * 0.18, s * 0.18), CFrame.new(side * s * 0.2, top + s * 0.55, -s * 0.2),
				accent, Enum.Material.Neon)
		end
	elseif extra == "Hut" then
		makePart(model, Vector3.new(s * 1.4, s * 0.35, s * 1.4), CFrame.new(0, top + s * 0.17, 0), accent)
		for i = 1, 3 do
			makePart(model, Vector3.new(s * 0.2, 0.1, s * 0.2),
				CFrame.new((i - 2) * s * 0.4, top + s * 0.35 + 0.05, (i % 2) * s * 0.3 - s * 0.15), Color3.new(1, 1, 1))
		end
	elseif extra == "Krone" then
		makePart(model, Vector3.new(s * 0.7, s * 0.15, s * 0.7), CFrame.new(0, top + s * 0.075, 0), GOLD, Enum.Material.Neon)
		for _, off in { Vector3.new(-1, 0, -1), Vector3.new(1, 0, -1), Vector3.new(-1, 0, 1), Vector3.new(1, 0, 1) } do
			makePart(model, Vector3.new(s * 0.12, s * 0.3, s * 0.12),
				CFrame.new(off.X * s * 0.28, top + s * 0.25, off.Z * s * 0.28), GOLD, Enum.Material.Neon)
		end
	elseif extra == "Stacheln" then
		for i = 1, 4 do
			makePart(model, Vector3.new(s * 0.15, s * 0.4, s * 0.15),
				CFrame.new(0, top + s * 0.15, -s * 0.3 + (i - 1) * s * 0.22) * CFrame.Angles(math.rad(25), 0, 0), accent,
				Enum.Material.Neon)
		end
	elseif extra == "Tentakel" then
		for i = 0, 5 do
			local a = i / 6 * math.pi * 2
			makePart(model, Vector3.new(s * 0.15, s * 0.15, s * 0.6),
				CFrame.new(math.cos(a) * s * 0.55, s * 0.08, math.sin(a) * s * 0.55) * CFrame.Angles(0, -a + math.pi / 2, 0),
				accent, Enum.Material.Neon)
		end
	end

	-- Effekte nach Seltenheit
	if rarity.Light then
		local light = Instance.new("PointLight")
		light.Color = rarity.Color
		light.Range = s * 3
		light.Brightness = 2
		light.Parent = body
	end
	if rarity.Sparkles then
		local sparkles = Instance.new("ParticleEmitter")
		sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		sparkles.Color = ColorSequence.new(rarity.Color, def.Accent)
		sparkles.Size = NumberSequence.new(0.4, 0)
		sparkles.Lifetime = NumberRange.new(0.8, 1.5)
		sparkles.Rate = 12
		sparkles.Speed = NumberRange.new(1, 3)
		sparkles.SpreadAngle = Vector2.new(180, 180)
		sparkles.LightEmission = 1
		sparkles.Parent = body
	end

	-- Namensschild
	if opts.Label then
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromOffset(170, 48)
		gui.StudsOffsetWorldSpace = Vector3.new(0, h / 2 + s * 0.6 + 1.2, 0)
		gui.MaxDistance = 70
		gui.AlwaysOnTop = false
		gui.Adornee = body
		gui.Parent = body

		local name = Instance.new("TextLabel")
		name.Size = UDim2.new(1, 0, 0.55, 0)
		name.BackgroundTransparency = 1
		name.Font = Enum.Font.FredokaOne
		name.TextScaled = true
		name.TextColor3 = rarity.Color
		name.TextStrokeTransparency = 0.3
		name.Text = def.Name
		name.Parent = gui

		local info = Instance.new("TextLabel")
		info.Size = UDim2.new(1, 0, 0.45, 0)
		info.Position = UDim2.fromScale(0, 0.55)
		info.BackgroundTransparency = 1
		info.Font = Enum.Font.GothamBold
		info.TextScaled = true
		info.TextColor3 = Color3.fromRGB(120, 255, 120)
		info.TextStrokeTransparency = 0.3
		info.Text = `{rarity.Name} · +{Config.FormatNumber(def.Income)} $/s`
		info.Parent = gui
	end

	-- Zum Tragen: alles an den Körper schweißen und schwerelos machen
	if opts.Anchored == false then
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				part.Anchored = false
				part.Massless = true
				part.CanCollide = false
				part.CanTouch = false
				part.CanQuery = false
				if part ~= body then
					local weld = Instance.new("WeldConstraint")
					weld.Part0 = body
					weld.Part1 = part
					weld.Parent = part
				end
			end
		end
	end

	return model
end

return CreatureModels
