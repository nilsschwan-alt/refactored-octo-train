-- Baut die komplette Map per Skript: Boden, Shop in der Mitte und 8 Bases im Kreis.
-- BuildDecor() baut die Optik einer Base je nach Stufe neu (Holz -> Stein -> Lichter -> Neon -> Kristall).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Map = {}

local FLOOR_Y = 2 -- Oberkante der Base-Böden
local S = Config.Map.BaseSize
local GAP = 16 -- Breite des Eingangs

local function part(props): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	local parent = props.Parent
	props.Parent = nil
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = parent
	return p
end

local function billboard(adornee: BasePart, size: UDim2, offset: Vector3, lines: number, maxDistance: number?)
	local gui = Instance.new("BillboardGui")
	gui.Size = size
	gui.StudsOffsetWorldSpace = offset
	gui.MaxDistance = maxDistance or 250
	gui.Adornee = adornee
	gui.Parent = adornee
	local labels = {}
	for i = 1, lines do
		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, 0, 1 / lines, 0)
		label.Position = UDim2.new(0, 0, (i - 1) / lines, 0)
		label.BackgroundTransparency = 1
		label.Font = if i == 1 then Enum.Font.FredokaOne else Enum.Font.GothamBold
		label.TextScaled = true
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextStrokeTransparency = 0.2
		label.Text = ""
		label.Parent = gui
		labels[i] = label
	end
	return gui, labels
end

local function prompt(parent: Instance, kind: string, action: string, object: string, hold: number, distance: number?)
	local p = Instance.new("ProximityPrompt")
	p.ActionText = action
	p.ObjectText = object
	p.HoldDuration = hold
	p.MaxActivationDistance = distance or 10
	p.RequiresLineOfSight = false
	p:SetAttribute("Kind", kind)
	CollectionService:AddTag(p, "GamePrompt")
	p.Parent = parent
	return p
end
Map.MakePrompt = prompt

-- Position der Kreaturen-Plätze (lokal in der Base, vorne = -Z)
local SLOT_X = { -16, -5.5, 5.5, 16 }
local SLOT_Z = { -2, 10, 22 }
local function slotOffset(slot: number): CFrame
	local col = (slot - 1) % 4 + 1
	local row = math.floor((slot - 1) / 4) + 1
	return CFrame.new(SLOT_X[col], 0, SLOT_Z[row])
end

-- Optik pro Stufe ----------------------------------------------------------
local STYLES = {
	{
		Floor = Color3.fromRGB(165, 115, 65), FloorMat = Enum.Material.WoodPlanks,
		Wall = Color3.fromRGB(115, 75, 40), WallMat = Enum.Material.WoodPlanks, WallHeight = 3, WallThick = 0.8,
		Pad = Color3.fromRGB(210, 180, 130), PadMat = Enum.Material.Wood,
	},
	{
		Floor = Color3.fromRGB(120, 120, 128), FloorMat = Enum.Material.Slate,
		Wall = Color3.fromRGB(145, 145, 150), WallMat = Enum.Material.Cobblestone, WallHeight = 8, WallThick = 1.5,
		Pad = Color3.fromRGB(175, 175, 180), PadMat = Enum.Material.Concrete,
	},
	{
		Floor = Color3.fromRGB(200, 190, 170), FloorMat = Enum.Material.Pebble,
		Wall = Color3.fromRGB(175, 90, 70), WallMat = Enum.Material.Brick, WallHeight = 10, WallThick = 1.5,
		Pad = Color3.fromRGB(240, 230, 200), PadMat = Enum.Material.Marble,
		Upper = true, UpperY = 14, Lamp = Color3.fromRGB(255, 220, 120),
	},
	{
		Floor = Color3.fromRGB(28, 28, 42), FloorMat = Enum.Material.SmoothPlastic,
		Wall = Color3.fromRGB(22, 22, 38), WallMat = Enum.Material.SmoothPlastic, WallHeight = 12, WallThick = 1.5,
		Pad = Color3.fromRGB(0, 200, 255), PadMat = Enum.Material.Neon,
		Trim = Color3.fromRGB(0, 230, 255),
		Upper = true, UpperY = 16, Lamp = Color3.fromRGB(255, 0, 200),
	},
	{
		Floor = Color3.fromRGB(245, 245, 250), FloorMat = Enum.Material.Marble,
		Wall = Color3.fromRGB(255, 195, 50), WallMat = Enum.Material.Metal, WallHeight = 14, WallThick = 1.5,
		Pad = Color3.fromRGB(190, 120, 255), PadMat = Enum.Material.Neon,
		Trim = Color3.fromRGB(200, 120, 255),
		Upper = true, UpperY = 18, Lamp = Color3.fromRGB(255, 230, 150),
		Crystals = true,
	},
}

local function sparkle(parent: BasePart, color: Color3)
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(color)
	e.LightEmission = 1
	e.Size = NumberSequence.new(0.8, 0)
	e.Lifetime = NumberRange.new(1, 2)
	e.Rate = 20
	e.Speed = NumberRange.new(2, 5)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Parent = parent
end

function Map.BuildDecor(plot, level: number)
	local style = STYLES[level]
	local cf = plot.CFrame
	local folder = plot.Decor
	folder:ClearAllChildren()

	plot.Floor.Color = style.Floor
	plot.Floor.Material = style.FloorMat

	local h, t = style.WallHeight, style.WallThick
	local function wall(size: Vector3, offset: Vector3)
		part({
			Name = "Wand",
			Size = size,
			CFrame = cf * CFrame.new(offset),
			Color = style.Wall,
			Material = style.WallMat,
			Reflectance = if style.WallMat == Enum.Material.Metal then 0.25 else 0,
			Parent = folder,
		})
		if style.Trim then
			part({
				Name = "Leiste",
				Size = Vector3.new(size.X + 0.2, 0.5, size.Z + 0.2),
				CFrame = cf * CFrame.new(offset + Vector3.new(0, size.Y / 2 + 0.25, 0)),
				Color = style.Trim,
				Material = Enum.Material.Neon,
				CanCollide = false,
				Parent = folder,
			})
		end
	end
	local sideW = S / 2 - GAP / 2
	wall(Vector3.new(S, h, t), Vector3.new(0, h / 2, S / 2 - t / 2)) -- hinten
	wall(Vector3.new(t, h, S), Vector3.new(-S / 2 + t / 2, h / 2, 0)) -- links
	wall(Vector3.new(t, h, S), Vector3.new(S / 2 - t / 2, h / 2, 0)) -- rechts
	wall(Vector3.new(sideW, h, t), Vector3.new(-(GAP / 2 + sideW / 2), h / 2, -S / 2 + t / 2)) -- vorne links
	wall(Vector3.new(sideW, h, t), Vector3.new(GAP / 2 + sideW / 2, h / 2, -S / 2 + t / 2)) -- vorne rechts

	-- Plätze für Kreaturen
	local slots = Config.BaseLevels[level].Slots
	for slot = 1, slots do
		part({
			Name = "Platz" .. slot,
			Size = Vector3.new(8, 0.4, 8),
			CFrame = cf * slotOffset(slot) * CFrame.new(0, 0.2, 0),
			Color = style.Pad,
			Material = style.PadMat,
			Transparency = if style.PadMat == Enum.Material.Neon then 0.35 else 0,
			Parent = folder,
		})
	end

	-- Zweites Stockwerk mit Lichtern
	if style.Upper then
		local y = style.UpperY
		local deckFront, deckBack = 4.5, S / 2
		local depth = deckBack - deckFront
		part({
			Name = "Obergeschoss",
			Size = Vector3.new(S, 1, depth),
			CFrame = cf * CFrame.new(0, y, deckFront + depth / 2),
			Color = style.Wall,
			Material = style.WallMat,
			Parent = folder,
		})
		part({
			Name = "Gelaender",
			Size = Vector3.new(S, 2.5, 0.4),
			CFrame = cf * CFrame.new(0, y + 1.75, deckFront + 0.2),
			Color = style.Trim or style.Wall,
			Material = if style.Trim then Enum.Material.Neon else style.WallMat,
			Transparency = if style.Trim then 0.3 else 0,
			Parent = folder,
		})
		for _, x in { -S / 2 + 1.5, -S / 6, S / 6, S / 2 - 1.5 } do
			part({
				Name = "Saeule",
				Size = Vector3.new(1.5, y, 1.5),
				CFrame = cf * CFrame.new(x, y / 2, deckFront + 0.75),
				Color = style.Wall,
				Material = style.WallMat,
				Parent = folder,
			})
			local lamp = part({
				Name = "Lampe",
				Size = Vector3.new(1.4, 1.4, 1.4),
				CFrame = cf * CFrame.new(x, y + 3.7, deckFront + 0.75),
				Color = style.Lamp,
				Material = Enum.Material.Neon,
				CanCollide = false,
				Shape = Enum.PartType.Ball,
				Parent = folder,
			})
			local light = Instance.new("PointLight")
			light.Color = style.Lamp
			light.Range = 22
			light.Brightness = 1.5
			light.Parent = lamp
		end
		-- Treppe nach oben (rechts an der Wand)
		local steps = math.ceil(y / 1.5)
		for i = 1, steps do
			part({
				Name = "Stufe",
				Size = Vector3.new(5, 1.5 * i, 2),
				CFrame = cf * CFrame.new(S / 2 - 4.5, 0.75 * i, deckFront - steps * 2 + (i - 1) * 2 + 1),
				Color = style.Wall,
				Material = style.WallMat,
				Parent = folder,
			})
		end
	end

	-- Kristalle und Lichtsäule für die höchste Stufe
	if style.Crystals then
		local corners = { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }
		for i, c in corners do
			local color = if i % 2 == 0 then Color3.fromRGB(0, 255, 255) else Color3.fromRGB(200, 100, 255)
			local crystal = part({
				Name = "Kristall",
				Size = Vector3.new(3, 12, 3),
				CFrame = cf
					* CFrame.new(c[1] * (S / 2 - 1), h + 5, c[2] * (S / 2 - 1))
					* CFrame.Angles(math.rad(15 * c[2]), math.rad(45), math.rad(15 * c[1])),
				Color = color,
				Material = Enum.Material.Neon,
				Transparency = 0.15,
				CanCollide = false,
				Parent = folder,
			})
			sparkle(crystal, color)
		end
		local beam = part({
			Name = "Lichtsaeule",
			Size = Vector3.new(3, 120, 3),
			CFrame = cf * CFrame.new(0, 60 + style.UpperY, S / 2 - 6),
			Color = Color3.fromRGB(255, 220, 90),
			Material = Enum.Material.Neon,
			Transparency = 0.55,
			CanCollide = false,
			CanQuery = false,
			CastShadow = false,
			Parent = folder,
		})
		sparkle(beam, Color3.fromRGB(255, 230, 120))
	end
end

function Map.SlotCFrame(plot, slot: number): CFrame
	return plot.CFrame * slotOffset(slot) * CFrame.new(0, 0.4, 0)
end

-- Prüft, ob eine Position in einer Base liegt
function Map.IsInside(plot, position: Vector3): boolean
	local localPos = plot.CFrame:PointToObjectSpace(position)
	return math.abs(localPos.X) <= S / 2 and math.abs(localPos.Z) <= S / 2 and localPos.Y < 40
end

function Map.Build()
	local old = workspace:FindFirstChild("KreaturenMap")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "KreaturenMap"
	root.Parent = workspace

	-- Wiese
	part({
		Name = "Wiese",
		Size = Vector3.new(380, 1, 380),
		CFrame = CFrame.new(0, 0.5, 0),
		Color = Color3.fromRGB(90, 170, 70),
		Material = Enum.Material.Grass,
		Parent = root,
	})

	-- Platz in der Mitte mit Shop
	local r = Config.Map.ShopRadius
	part({
		Name = "Marktplatz",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1, r * 2, r * 2),
		CFrame = CFrame.new(0, 1.5, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(230, 220, 200),
		Material = Enum.Material.Pebble,
		Parent = root,
	})
	local counter = part({
		Name = "ShopTheke",
		Size = Vector3.new(14, 4, 14),
		CFrame = CFrame.new(0, 4, 0),
		Color = Color3.fromRGB(255, 170, 40),
		Parent = root,
	})
	for _, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		part({
			Name = "ShopSaeule",
			Size = Vector3.new(1.5, 10, 1.5),
			CFrame = CFrame.new(c[1] * 9, 7, c[2] * 9),
			Color = Color3.new(1, 1, 1),
			Parent = root,
		})
	end
	for i = 0, 3 do
		part({
			Name = "ShopDach",
			Size = Vector3.new(22, 1, 5.5),
			CFrame = CFrame.new(0, 12.5, -8.25 + i * 5.5),
			Color = if i % 2 == 0 then Color3.fromRGB(255, 80, 80) else Color3.new(1, 1, 1),
			Parent = root,
		})
	end
	local _, shopLabels = billboard(counter, UDim2.fromOffset(320, 90), Vector3.new(0, 14, 0), 2, 400)
	shopLabels[1].Text = "KREATUREN-SHOP"
	shopLabels[1].TextColor3 = Color3.fromRGB(255, 220, 60)
	shopLabels[2].Text = "Hier Kreaturen kaufen!"
	prompt(counter, "Shop", "Shop öffnen", "Kreaturen-Shop", 0, 14)

	-- Bases
	local basesFolder = Instance.new("Folder")
	basesFolder.Name = "Bases"
	basesFolder.Parent = root

	local plots = {}
	local count = Config.Map.BaseCount
	local radius = Config.Map.BaseRadius
	for i = 1, count do
		local angle = (i - 1) / count * math.pi * 2
		local pos = Vector3.new(math.cos(angle) * radius, FLOOR_Y, math.sin(angle) * radius)
		local cf = CFrame.lookAt(pos, Vector3.new(0, FLOOR_Y, 0))

		local model = Instance.new("Model")
		model.Name = "Base_" .. i
		model:SetAttribute("IsPlot", true)
		model:SetAttribute("PlotIndex", i)
		model.Parent = basesFolder

		local floor = part({
			Name = "Boden",
			Size = Vector3.new(S, 1, S),
			CFrame = cf * CFrame.new(0, -0.5, 0),
			Parent = model,
		})

		-- Weg zur Mitte
		local inner, outer = Config.Map.ShopRadius - 1, radius - S / 2
		local len = outer - inner
		local mid = Vector3.new(math.cos(angle), 0, math.sin(angle)) * (inner + len / 2)
		part({
			Name = "Weg",
			Size = Vector3.new(12, 0.2, len),
			CFrame = CFrame.lookAt(mid + Vector3.new(0, 1.05, 0), Vector3.new(0, 1.05, 0)),
			Color = Color3.fromRGB(150, 140, 130),
			Material = Enum.Material.Slate,
			Parent = model,
		})

		-- Torbogen mit Schild
		for _, side in { -1, 1 } do
			part({
				Name = "Torpfosten",
				Size = Vector3.new(1.5, 14, 1.5),
				CFrame = cf * CFrame.new(side * (GAP / 2 + 0.75), 7, -S / 2 - 0.75),
				Color = Color3.fromRGB(60, 60, 70),
				Parent = model,
			})
		end
		local arch = part({
			Name = "Torbogen",
			Size = Vector3.new(GAP + 3, 2, 1.5),
			CFrame = cf * CFrame.new(0, 15, -S / 2 - 0.75),
			Color = Color3.fromRGB(60, 60, 70),
			Parent = model,
		})
		local _, signLabels = billboard(arch, UDim2.fromOffset(300, 110), Vector3.new(0, 4.5, 0), 3, 300)

		-- Laserwand (sichtbar, wenn die Base abgeschlossen ist)
		local laser = part({
			Name = "Laserwand",
			Size = Vector3.new(GAP, 13, 0.4),
			CFrame = cf * CFrame.new(0, 6.5, -S / 2 - 0.75),
			Color = Color3.fromRGB(255, 30, 30),
			Material = Enum.Material.Neon,
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
			CastShadow = false,
			Parent = model,
		})

		-- Knöpfe: Schloss (links) und Upgrade (rechts)
		local function pedestal(x: number, color: Color3, title: string)
			part({
				Name = "Sockel",
				Size = Vector3.new(3, 3, 3),
				CFrame = cf * CFrame.new(x, 1.5, -20),
				Color = Color3.fromRGB(70, 70, 80),
				Parent = model,
			})
			local button = part({
				Name = "Knopf",
				Size = Vector3.new(2.4, 0.6, 2.4),
				CFrame = cf * CFrame.new(x, 3.3, -20),
				Color = color,
				Material = Enum.Material.Neon,
				Parent = model,
			})
			local _, labels = billboard(button, UDim2.fromOffset(140, 30), Vector3.new(0, 2.5, 0), 1, 60)
			labels[1].Text = title
			labels[1].TextColor3 = color
			return button
		end
		local lockButton = pedestal(-14, Color3.fromRGB(255, 60, 60), "Schloss")
		local upgradeButton = pedestal(14, Color3.fromRGB(80, 255, 120), "Upgrade")
		local lockPrompt = prompt(lockButton, "Lock", "Abschließen", "Base-Schloss", 0.3, 8)
		local upgradePrompt = prompt(upgradeButton, "Upgrade", "Upgrade", "Base", 0.5, 8)

		local decor = Instance.new("Folder")
		decor.Name = "Deko"
		decor.Parent = model
		local creatures = Instance.new("Folder")
		creatures.Name = "Kreaturen"
		creatures.Parent = model

		local plot = {
			Index = i,
			CFrame = cf,
			Model = model,
			Floor = floor,
			Decor = decor,
			Creatures = creatures,
			Laser = laser,
			SignLabels = signLabels,
			LockPrompt = lockPrompt,
			UpgradePrompt = upgradePrompt,
			SpawnCFrame = cf * CFrame.new(0, 4, -12),
			Owner = nil,
			SlotModels = {},
			Stolen = {},
		}
		Map.BuildDecor(plot, 1)
		plots[i] = plot
	end

	return plots
end

return Map
