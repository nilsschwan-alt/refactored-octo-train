-- Baut eine Kreatur. Wenn in Studio unter ReplicatedStorage > KreaturenModelle ein Modell
-- mit dem Namen der Kreatur (Id) liegt, wird das genommen (KI-Modelle). Sonst wird die
-- Kreatur wie früher aus einfachen Blöcken gebaut. So läuft das Spiel auch ohne die Modelle.
-- Vorne ist -Z (dahin schaut die Kreatur). Der Pivot liegt unten in der Mitte,
-- damit model:PivotTo(cf) die Kreatur genau auf den Boden bei cf stellt.

local CollectionService = game:GetService("CollectionService")
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

local MODEL_FOLDER = "KreaturenModelle"
local AI_HEIGHT_FACTOR = 1.5 -- KI-Modell ist so hoch wie Seltenheits-Größe x 1.5

-- KI-Modell aus ReplicatedStorage.KreaturenModelle (falls in Studio angelegt)
local function findAiModel(id: string): Model?
	local folder = ReplicatedStorage:FindFirstChild(MODEL_FOLDER)
	local template = folder and folder:FindFirstChild(id)
	if template and template:IsA("Model") and template:FindFirstChildWhichIsA("BasePart", true) then
		return template
	end
	return nil
end

-- KI-Modell klonen, auf die richtige Größe bringen und eine unsichtbare "Body"-Hülle drumlegen.
-- Die Hülle ist das PrimaryPart: daran hängen Schilder, E-Knöpfe, Klicks und Effekte.
local function buildFromAiModel(template: Model, def, s: number, mutationId: string, mutation): (Model, BasePart, number)
	local model = template:Clone()
	model.Name = def.Id
	model.PrimaryPart = nil
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanTouch = false
		elseif d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy()
		end
	end

	local height = model:GetExtentsSize().Y
	if height > 0.05 then
		model:ScaleTo(model:GetScale() * (s * AI_HEIGHT_FACTOR) / height)
	end

	-- Mutation: leuchtende Hülle über dem Modell, die Textur (Gesicht usw.) bleibt sichtbar
	if mutationId ~= "Normal" and mutation.Color then
		for _, mesh in model:GetDescendants() do
			if mesh:IsA("MeshPart") then
				local shell = mesh:Clone()
				shell:ClearAllChildren()
				shell.Name = "MutationsGlanz"
				shell.TextureID = ""
				shell.Material = Enum.Material.ForceField
				shell.Color = mutation.Color
				shell.Size = mesh.Size * 1.06
				shell.CFrame = mesh.CFrame
				shell.CanCollide = false
				shell.CanQuery = false
				shell.CanTouch = false
				shell.CastShadow = false
				if mutationId == "Regenbogen" then
					CollectionService:AddTag(shell, "Rainbow") -- Farbe wechselt beim Client
				end
				shell.Parent = mesh.Parent
			end
		end
	end

	local pivot = model:GetPivot()
	local boxCF, boxSize = model:GetBoundingBox()
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = boxSize
	body.CFrame = boxCF
	body.Transparency = 1
	body.Anchored = true
	body.CanCollide = false
	body.CanTouch = false
	body.CastShadow = false
	body.PivotOffset = boxCF:ToObjectSpace(pivot) -- Pivot bleibt unten in der Mitte
	body.Parent = model
	model.PrimaryPart = body
	return model, body, boxSize.Y / 2 + 1.2
end

-- Kreatur aus einfachen Blöcken (Backup, wenn es kein KI-Modell gibt)
local function buildFromBlocks(def, s: number, mutationId: string, mutation): (Model, BasePart, number)
	local h = s * 0.8 -- Körperhöhe
	local top = h -- Oberkante des Körpers

	local model = Instance.new("Model")
	model.Name = def.Id

	local bodyColor = def.Color
	local bodyMaterial = if def.Rarity == "Mythic" then Enum.Material.Glass else Enum.Material.SmoothPlastic
	if mutationId == "Gold" then
		bodyColor = mutation.Color
		bodyMaterial = Enum.Material.Metal
	elseif mutationId == "Diamant" then
		bodyColor = mutation.Color
		bodyMaterial = Enum.Material.Glass
	elseif mutationId == "Regenbogen" then
		bodyMaterial = Enum.Material.Neon
	end
	local body = makePart(model, Vector3.new(s, h, s), CFrame.new(0, h / 2, 0), bodyColor, bodyMaterial)
	if mutationId == "Gold" then
		body.Reflectance = 0.35
	elseif mutationId == "Diamant" then
		body.Transparency = 0.15
		body.Reflectance = 0.2
	elseif mutationId == "Regenbogen" then
		CollectionService:AddTag(body, "Rainbow") -- Farbe wechselt beim Client
	end
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

	return model, body, h / 2 + s * 0.6 + 1.2
end

-- opts = { Scale = number?, Anchored = boolean?, Label = boolean?, Mutation = string?, PriceText = string? }
function CreatureModels.Build(def, opts): Model
	opts = opts or {}
	local rarity = Config.Rarities[def.Rarity]
	local s = rarity.Size * (opts.Scale or 1)
	local mutationId = opts.Mutation or "Normal"
	local mutation = Config.Mutations[mutationId] or Config.Mutations.Normal

	local model, body, labelY
	local template = findAiModel(def.Id)
	if template then
		local ok, m, b, y = pcall(buildFromAiModel, template, def, s, mutationId, mutation)
		if ok then
			model, body, labelY = m, b, y
		else
			warn(`[Kreaturen] KI-Modell {def.Id} ging nicht, nehme Block-Version: {m}`)
		end
	end
	if not model then
		model, body, labelY = buildFromBlocks(def, s, mutationId, mutation)
	end

	-- Effekte nach Seltenheit
	if rarity.Light then
		local light = Instance.new("PointLight")
		light.Color = rarity.Color
		light.Range = s * 3
		light.Brightness = 2
		light.Parent = body
	end
	if rarity.Sparkles or mutationId ~= "Normal" then
		local sparkles = Instance.new("ParticleEmitter")
		sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		sparkles.Color = ColorSequence.new(mutation.Color or rarity.Color, def.Accent)
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
		local lines = if opts.PriceText then 3 else 2
		-- Größe teils in Studs, teils in Pixeln: aus der Nähe gut lesbar, von weitem
		-- schmal genug, dass sich die Schilder benachbarter Kreaturen nicht überlappen
		gui.Size = UDim2.new(4, 70, 0.55 * lines, 12 * lines)
		gui.StudsOffsetWorldSpace = Vector3.new(0, labelY, 0)
		gui.MaxDistance = 70
		gui.AlwaysOnTop = false
		gui.Adornee = body
		gui.Parent = body

		local name = Instance.new("TextLabel")
		name.Size = UDim2.new(1, 0, 1 / lines, 0)
		name.BackgroundTransparency = 1
		name.Font = Enum.Font.FredokaOne
		name.TextScaled = true
		name.TextColor3 = rarity.Color
		name.TextStrokeTransparency = 0.3
		name.Text = if mutation.Name ~= "" then `{mutation.Name}-{def.Name}` else def.Name
		if mutation.Color then
			local stroke = Instance.new("UIStroke")
			stroke.Color = mutation.Color
			stroke.Thickness = 2
			stroke.Parent = name
		end
		name.Parent = gui

		local info = Instance.new("TextLabel")
		info.Size = UDim2.new(1, 0, 1 / lines, 0)
		info.Position = UDim2.fromScale(0, 1 / lines)
		info.BackgroundTransparency = 1
		info.Font = Enum.Font.GothamBold
		info.TextScaled = true
		info.TextColor3 = Color3.fromRGB(120, 255, 120)
		info.TextStrokeTransparency = 0.3
		info.Text = `{rarity.Name} · +{Config.FormatNumber(def.Income * mutation.Multiplier)} $/s`
		info.Parent = gui

		if opts.PriceText then
			local price = info:Clone()
			price.Position = UDim2.fromScale(0, 2 / lines)
			price.TextColor3 = Color3.fromRGB(255, 220, 60)
			price.Text = opts.PriceText
			price.Parent = gui
		end
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
