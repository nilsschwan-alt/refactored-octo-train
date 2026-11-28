-- Baut die komplette Map per Skript: Weg, Pack-Shop und 2 Reihen mit je 4 Häusern.
-- Jede Base ist ein Haus zum Reinlaufen, die Kreaturen stehen drinnen.
-- BuildDecor() baut das Haus je nach Stufe neu (Holz -> Stein -> Lichter -> Neon -> Kristall).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local World = require(script.Parent.World)

local Map = {}

local FLOOR_Y = 2 -- Oberkante der Base-Böden
local S = Config.Map.BaseSize
local GAP = 16 -- Breite des Tors

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

-- Haus: vorne (-Z, zur Straße) ist das offene Tor
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90)) -- dreht Zylinder so, dass sie stehen
local FRONT = -22 -- hier steht die Vorderwand (lokal, von der Base-Mitte aus)
local PORCH = 5 -- so weit ragt die Veranda vor das Tor
local WALL = 1.5 -- Wandstärke
local DOOR_H = 14 -- Höhe des Tors
local GATE_HALF = GAP / 2 + 0.75 -- Abstand der Torpfosten zur Mitte
local DOOR_EDGE = GATE_HALF + 0.75 -- ab hier beginnt links und rechts die Vorderwand
local COL_GAP, ROW_GAP = 12, 13 -- Abstand der Kreaturen-Plätze
local FIRST_ROW = 12 -- so weit hinter dem Tor steht die erste Reihe

-- Größe je Stufe: HalfW = halbe Innenbreite, Depth = Innentiefe, Height = Wandhöhe,
-- Cols = Kreaturen pro Reihe. Cols x Reihen muss zu den Plätzen in Config.BaseLevels passen.
local HOUSES = {
	{ HalfW = 18, Depth = 36, Height = 17, Cols = 2 }, -- 4 Plätze
	{ HalfW = 22, Depth = 36, Height = 18, Cols = 3 }, -- 6
	{ HalfW = 28, Depth = 36, Height = 19, Cols = 4 }, -- 8
	{ HalfW = 33, Depth = 36, Height = 20, Cols = 5 }, -- 10
	{ HalfW = 34, Depth = 50, Height = 23, Cols = 4 }, -- 12
}

-- Position der Kreaturen-Plätze (lokal, vorne = -Z): Reihen von vorne nach hinten
local function slotOffset(level: number, slot: number): CFrame
	local house = HOUSES[level] or HOUSES[1]
	local col = (slot - 1) % house.Cols + 1
	local row = math.floor((slot - 1) / house.Cols) + 1
	return CFrame.new((col - (house.Cols + 1) / 2) * COL_GAP, 0, FRONT + FIRST_ROW + (row - 1) * ROW_GAP)
end

-- Optik pro Stufe ----------------------------------------------------------
-- Rim = leuchtender Rand um den Sockel, Wall = Wände, Trim = Eckpfosten und Zierleisten,
-- Roof = Dach-Art ("Giebel", "Zinnen", "Neon", "Glas"), Ring = Leuchtring um leere Plätze
local STYLES = {
	{ -- 1 Holz-Hütte
		Wall = Color3.fromRGB(188, 138, 88), WallMat = Enum.Material.WoodPlanks,
		Trim = Color3.fromRGB(108, 70, 40), TrimMat = Enum.Material.Wood,
		Roof = "Giebel", RoofColor = Color3.fromRGB(170, 66, 52), RoofMat = Enum.Material.Slate,
		Glass = Color3.fromRGB(190, 225, 255), Rug = Color3.fromRGB(190, 60, 60),
		Floor = Color3.fromRGB(205, 155, 100), FloorMat = Enum.Material.WoodPlanks,
		Rim = Color3.fromRGB(130, 85, 50), RimMat = Enum.Material.Wood,
		Gate = Color3.fromRGB(125, 85, 50), GateMat = Enum.Material.Wood,
		Pad = Color3.fromRGB(235, 205, 155), PadMat = Enum.Material.Wood,
		Ring = Color3.fromRGB(255, 225, 170),
	},
	{ -- 2 Stein-Burg
		Wall = Color3.fromRGB(165, 165, 176), WallMat = Enum.Material.Cobblestone,
		Trim = Color3.fromRGB(118, 118, 130), TrimMat = Enum.Material.Slate,
		Roof = "Zinnen", RoofColor = Color3.fromRGB(135, 135, 148), RoofMat = Enum.Material.Slate,
		Glass = Color3.fromRGB(170, 215, 255), Rug = Color3.fromRGB(60, 100, 200),
		Floor = Color3.fromRGB(150, 150, 162), FloorMat = Enum.Material.Slate,
		Rim = Color3.fromRGB(120, 200, 255), RimMat = Enum.Material.Neon,
		Gate = Color3.fromRGB(140, 140, 150), GateMat = Enum.Material.Cobblestone,
		Pad = Color3.fromRGB(205, 205, 212), PadMat = Enum.Material.Concrete,
		Ring = Color3.fromRGB(170, 220, 255),
	},
	{ -- 3 Lichter-Villa
		Wall = Color3.fromRGB(252, 248, 240), WallMat = Enum.Material.Marble,
		Trim = Color3.fromRGB(255, 200, 70), TrimMat = Enum.Material.Metal,
		Roof = "Giebel", RoofColor = Color3.fromRGB(214, 112, 72), RoofMat = Enum.Material.Slate,
		Glass = Color3.fromRGB(255, 235, 180), Rug = Color3.fromRGB(200, 50, 70),
		Floor = Color3.fromRGB(242, 228, 198), FloorMat = Enum.Material.Pebble,
		Rim = Color3.fromRGB(230, 190, 90), RimMat = Enum.Material.SmoothPlastic,
		Bulb = Color3.fromRGB(255, 225, 120),
		Gate = Color3.fromRGB(252, 248, 240), GateMat = Enum.Material.Marble, GateTrim = Color3.fromRGB(255, 200, 70),
		Pad = Color3.fromRGB(255, 246, 225), PadMat = Enum.Material.Marble,
		Ring = Color3.fromRGB(255, 220, 130),
	},
	{ -- 4 Neon-Palast
		Wall = Color3.fromRGB(34, 28, 62), WallMat = Enum.Material.SmoothPlastic,
		Trim = Color3.fromRGB(0, 230, 255), TrimMat = Enum.Material.Neon,
		Roof = "Neon", RoofColor = Color3.fromRGB(24, 20, 46), RoofMat = Enum.Material.SmoothPlastic,
		Glass = Color3.fromRGB(0, 230, 255), Rug = Color3.fromRGB(255, 60, 200),
		Floor = Color3.fromRGB(38, 32, 64), FloorMat = Enum.Material.SmoothPlastic,
		Rim = Color3.fromRGB(0, 230, 255), RimMat = Enum.Material.Neon,
		Gate = Color3.fromRGB(32, 26, 58), GateMat = Enum.Material.SmoothPlastic, GateTrim = Color3.fromRGB(255, 60, 200),
		Pad = Color3.fromRGB(60, 55, 100), PadMat = Enum.Material.SmoothPlastic,
		Ring = Color3.fromRGB(0, 200, 255),
	},
	{ -- 5 Kristall-Festung
		Wall = Color3.fromRGB(248, 245, 255), WallMat = Enum.Material.Marble,
		Trim = Color3.fromRGB(255, 205, 70), TrimMat = Enum.Material.Metal,
		Roof = "Glas", RoofColor = Color3.fromRGB(205, 150, 255), RoofMat = Enum.Material.Glass,
		Glass = Color3.fromRGB(215, 165, 255), Rug = Color3.fromRGB(150, 80, 230),
		Floor = Color3.fromRGB(225, 215, 250), FloorMat = Enum.Material.Marble,
		Rim = Color3.fromRGB(200, 120, 255), RimMat = Enum.Material.Neon,
		LampBrightness = 0.55, -- weißes Haus mit Glasdach: sonst ist es drinnen zu grell
		Gate = Color3.fromRGB(255, 200, 60), GateMat = Enum.Material.Metal, GateTrim = Color3.fromRGB(200, 120, 255),
		Pad = Color3.fromRGB(240, 235, 255), PadMat = Enum.Material.Marble,
		Ring = Color3.fromRGB(210, 150, 255),
	},
}

local function sparkle(parent: BasePart, color: Color3, rate: number?)
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(color)
	e.LightEmission = 1
	e.Size = NumberSequence.new(0.8, 0)
	e.Lifetime = NumberRange.new(1, 2)
	e.Rate = rate or 20
	e.Speed = NumberRange.new(2, 5)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Parent = parent
end

local function pointLight(parent: BasePart, color: Color3, range: number, brightness: number)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Parent = parent
end

-- Haus-Bausteine --------------------------------------------------------------------------
-- Quader zwischen zwei Ecken (lokal zur Base). extra = weitere Eigenschaften.
local function box(folder: Instance, cf: CFrame, name: string, x0: number, x1: number, y0: number, y1: number, z0: number, z1: number, color: Color3, material: Enum.Material, extra: { [string]: any }?): Part
	local p = part({
		Name = name,
		Size = Vector3.new(math.abs(x1 - x0), math.abs(y1 - y0), math.abs(z1 - z0)),
		CFrame = cf * CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2),
		Color = color,
		Material = material,
	})
	if extra then
		for k, v in extra do
			(p :: any)[k] = v
		end
	end
	p.Parent = folder
	return p
end

-- Dach-Teile: Man läuft nicht dagegen, die Kamera bleibt nicht daran hängen, und der Client
-- blendet sie aus, sobald man selbst im Haus steht (Tag "HausDach", siehe Main.client).
local function roofPart(p: BasePart): BasePart
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	CollectionService:AddTag(p, "HausDach")
	return p
end

local NO_HIT = { CanCollide = false, CanQuery = false, CanTouch = false }

-- Wand mit Fenstern. along = "X" oder "Z": In diese Richtung läuft die Wand von a0 bis a1,
-- b0 bis b1 ist ihre Dicke. windows = Anzahl Fenster (0 = glatte Wand).
local function windowWall(folder: Instance, cf: CFrame, style, along: string, a0: number, a1: number, b0: number, b1: number, h: number, windows: number)
	local function seg(name: string, s0: number, s1: number, y0: number, y1: number, color: Color3, material: Enum.Material, grow: number?, extra: { [string]: any }?)
		local g = grow or 0
		if s1 - s0 < 0.05 then
			return nil
		end
		if along == "X" then
			return box(folder, cf, name, s0, s1, y0, y1, b0 - g, b1 + g, color, material, extra)
		end
		return box(folder, cf, name, b0 - g, b1 + g, y0, y1, s0, s1, color, material, extra)
	end
	if windows <= 0 then
		seg("Wand", a0, a1, 0, h, style.Wall, style.WallMat)
		return
	end
	local SILL, TOP, WIDTH = 4, 11, 7
	seg("Wand", a0, a1, 0, SILL, style.Wall, style.WallMat)
	seg("Wand", a0, a1, TOP, h, style.Wall, style.WallMat)
	local step = (a1 - a0) / windows
	local edge = a0
	for i = 1, windows do
		local mid = a0 + (i - 0.5) * step
		seg("Wand", edge, mid - WIDTH / 2, SILL, TOP, style.Wall, style.WallMat)
		seg("Fenster", mid - WIDTH / 2, mid + WIDTH / 2, SILL, TOP, style.Glass, Enum.Material.Glass, -0.5, { Transparency = 0.55, CastShadow = false })
		seg("Fensterbank", mid - WIDTH / 2 - 0.4, mid + WIDTH / 2 + 0.4, SILL - 0.5, SILL, style.Trim, style.TrimMat, 0.35)
		seg("Fenstersturz", mid - WIDTH / 2 - 0.4, mid + WIDTH / 2 + 0.4, TOP, TOP + 0.5, style.Trim, style.TrimMat, 0.35)
		seg("Fensterkreuz", mid - 0.2, mid + 0.2, SILL, TOP, style.Trim, style.TrimMat, -0.4)
		edge = mid + WIDTH / 2
	end
	seg("Wand", edge, a1, SILL, TOP, style.Wall, style.WallMat)
end

-- Spitzdach: First läuft von vorne nach hinten, der Giebel zeigt zur Straße.
-- outer = halbe Außenbreite, z0/z1 = Außenkanten vorne/hinten, h = Wandhöhe. Gibt die Firsthöhe zurück.
local function gableRoof(folder: Instance, cf: CFrame, style, outer: number, z0: number, z1: number, h: number): number
	local rise = outer * 0.45
	local over = 2.2 -- Überstand
	local theta = math.atan(rise / outer)
	local half = outer + over
	local drop = half * math.tan(theta) -- so weit fällt das Dach vom First bis zur Traufe
	local length = half / math.cos(theta)
	local thick = 1.5 -- Dicke der Dachplatten
	for _, side in { -1, 1 } do
		-- Mitte der Unterkante, dann eine halbe Dicke nach oben
		local mx, my = side * half / 2, h + rise - drop / 2
		local nx, ny = side * math.sin(theta) * thick / 2, math.cos(theta) * thick / 2
		roofPart(part({
			Name = "Dach",
			Size = Vector3.new(length, thick, z1 - z0 + over * 2),
			CFrame = cf * CFrame.new(mx + nx, my + ny, (z0 + z1) / 2) * CFrame.Angles(0, 0, -side * theta),
			Color = style.RoofColor,
			Material = style.RoofMat,
			Parent = folder,
		}))
	end
	roofPart(box(folder, cf, "First", -1, 1, h + rise - 0.2, h + rise + 1.9, z0 - over - 0.3, z1 + over + 0.3, style.Trim, style.TrimMat))
	-- Giebel vorne und hinten: Stufen, deren Ecken unter den Dachplatten verschwinden
	for _, z in { z0 + WALL / 2, z1 - WALL / 2 } do
		for k = 0, math.ceil(rise) - 1 do
			local w = outer * (1 - k / rise)
			local top = math.min(h + k + 1, h + rise)
			roofPart(box(folder, cf, "Giebel", -w, w, h + k, top, z - WALL / 2, z + WALL / 2, style.Wall, style.WallMat))
		end
	end
	return h + rise
end

-- Flaches Dach (Platte mit kleinem Überstand)
local function flatRoof(folder: Instance, cf: CFrame, style, outer: number, z0: number, z1: number, h: number, extra: { [string]: any }?): Part
	return roofPart(box(folder, cf, "Dach", -outer - 0.6, outer + 0.6, h, h + 1, z0 - 0.6, z1 + 0.6, style.RoofColor, style.RoofMat, extra)) :: Part
end

-- Kleine Lampe mit Licht (Laterne, Fackel)
local function lantern(folder: Instance, cf: CFrame, x: number, y: number, z: number, color: Color3, range: number)
	box(folder, cf, "Laternenhalter", x - 0.25, x + 0.25, y + 0.6, y + 0.9, z - 0.25, z + 0.9, Color3.fromRGB(50, 45, 45), Enum.Material.Metal, NO_HIT)
	local glow = box(folder, cf, "Laterne", x - 0.5, x + 0.5, y - 0.6, y + 0.6, z - 0.5, z + 0.5, color, Enum.Material.Neon, NO_HIT)
	pointLight(glow, color, range, 1)
end

-- Stehender Zylinder von y0 bis y1
local function pillar(folder: Instance, cf: CFrame, name: string, x: number, z: number, y0: number, y1: number, radius: number, color: Color3, material: Enum.Material, extra: { [string]: any }?): Part
	local p = part({
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(y1 - y0, radius * 2, radius * 2),
		CFrame = cf * CFrame.new(x, (y0 + y1) / 2, z) * UPRIGHT,
		Color = color,
		Material = material,
	})
	if extra then
		for k, v in extra do
			(p :: any)[k] = v
		end
	end
	p.Parent = folder
	return p
end

-- Kristall-Gruppe: ein großer Kristall mit Spitze, daneben zwei kleinere, schräg (leuchtet und funkelt)
local function crystal(folder: Instance, cf: CFrame, x: number, y: number, z: number, height: number, color: Color3): Part
	local main
	for i, info in { { 0, 0, 1, 0, 0 }, { 0.32, 0.2, 0.62, 22, 40 }, { -0.28, -0.24, 0.5, -26, 110 } } do
		local hgt = height * info[3]
		local width = hgt * 0.2
		-- die schrägen kleinen stecken etwas tiefer, sonst hebt sich eine Kante vom Boden
		local base = cf * CFrame.new(x + info[1] * height * 0.5, y - (if i > 1 then 0.6 else 0), z + info[2] * height * 0.5) * CFrame.Angles(0, math.rad(info[5]), 0) * CFrame.Angles(math.rad(info[4]), 0, 0)
		local shaft = part({
			Name = "Kristall",
			Size = Vector3.new(width, hgt, width),
			CFrame = base * CFrame.new(0, hgt / 2, 0) * CFrame.Angles(0, math.rad(45), 0),
			Color = color,
			Material = Enum.Material.Neon,
			Transparency = 0.12,
			CanCollide = false,
			CanQuery = false,
			Parent = folder,
		})
		-- Spitze: ein Würfel, der auf der Ecke steht
		part({
			Name = "Kristallspitze",
			Size = Vector3.new(width * 0.98, width * 0.98, width * 0.98),
			CFrame = base * CFrame.new(0, hgt, 0) * CFrame.Angles(0, math.rad(45), 0) * CFrame.Angles(0, 0, math.rad(35.264)) * CFrame.Angles(math.rad(45), 0, 0),
			Color = color:Lerp(Color3.new(1, 1, 1), 0.25),
			Material = Enum.Material.Neon,
			Transparency = 0.12,
			CanCollide = false,
			CanQuery = false,
			Parent = folder,
		})
		if i == 1 then
			main = shaft
			sparkle(shaft, color, 8)
			pointLight(shaft, color, 14, 0.7)
		end
	end
	return main
end

-- Baut das Haus einer Base neu: Wände, Dach, Deko und die Kreaturen-Plätze je nach Stufe.
function Map.BuildDecor(plot, level: number)
	local style = STYLES[level] or STYLES[1]
	local house = HOUSES[level] or HOUSES[1]
	local cf = plot.CFrame
	local folder = plot.Decor
	folder:ClearAllChildren()
	plot.Level = level

	local hw, depth, h = house.HalfW, house.Depth, house.Height
	local outer = hw + WALL -- halbe Außenbreite
	local zFront = FRONT - WALL / 2 -- Außenkante vorne
	local zIn = FRONT + WALL / 2 -- Innenkante der Vorderwand
	local zBack = FRONT + depth -- Innenkante der Rückwand
	local zOut = zBack + WALL -- Außenkante hinten
	local zMid = (zIn + zBack) / 2

	-- Boden: das ganze Haus plus eine kleine Veranda vor dem Tor
	plot.Floor.Size = Vector3.new(outer * 2 + 2, 1, zOut + 1 - (FRONT - PORCH))
	plot.Floor.CFrame = cf * CFrame.new(0, -0.5, (FRONT - PORCH + zOut + 1) / 2)
	plot.Floor.Color = style.Floor
	plot.Floor.Material = style.FloorMat
	-- Leuchtender Rand um den Sockel
	box(folder, cf, "Rand", -outer - 1.6, outer + 1.6, -1, -0.4, FRONT - PORCH - 0.6, zOut + 1.6, style.Rim, style.RimMat, NO_HIT)

	-- Tor in Stufen-Farbe
	for _, gatePart in plot.Gate do
		gatePart.Color = style.Gate
		gatePart.Material = style.GateMat
		gatePart.Reflectance = if style.GateMat == Enum.Material.Metal then 0.3 else 0
	end
	if style.GateTrim then
		box(folder, cf, "Torleuchte", -GAP / 2 - 1.6, GAP / 2 + 1.6, DOOR_H - 0.35, DOOR_H + 0.15, zFront - 0.25, zIn + 0.25, style.GateTrim, Enum.Material.Neon, NO_HIT)
	end

	-- Wände: vorne links und rechts vom Tor, darüber ein Band, dann Seiten und Rückwand
	local frontLength = outer - DOOR_EDGE
	local frontWindows = if frontLength >= 22 then 2 elseif frontLength >= 11 then 1 else 0
	windowWall(folder, cf, style, "X", -outer, -DOOR_EDGE, zFront, zIn, h, frontWindows)
	windowWall(folder, cf, style, "X", DOOR_EDGE, outer, zFront, zIn, h, frontWindows)
	box(folder, cf, "Wand", -DOOR_EDGE, DOOR_EDGE, DOOR_H + 2, h, zFront, zIn, style.Wall, style.WallMat)
	local sideWindows = if depth > 36 then 3 else 2
	windowWall(folder, cf, style, "Z", zIn, zBack, -outer, -hw, h, sideWindows)
	windowWall(folder, cf, style, "Z", zIn, zBack, hw, outer, h, sideWindows)
	windowWall(folder, cf, style, "X", -outer, outer, zBack, zOut, h, math.floor(outer * 2 / 14))

	-- Eckpfosten und Zierleiste oben
	for _, sx in { -1, 1 } do
		for _, z in { FRONT, zBack + WALL / 2 } do
			local x = sx * (hw + WALL / 2)
			box(folder, cf, "Eckpfosten", x - 1.1, x + 1.1, 0, h + 0.3, z - 1.1, z + 1.1, style.Trim, style.TrimMat)
		end
		local x0, x1 = sx * (hw - 0.3), sx * (outer + 0.3)
		box(folder, cf, "Zierleiste", math.min(x0, x1), math.max(x0, x1), h - 1.2, h + 0.05, zFront, zOut, style.Trim, style.TrimMat, NO_HIT)
	end
	box(folder, cf, "Zierleiste", -outer, outer, h - 1.2, h + 0.05, zFront - 0.3, zIn + 0.3, style.Trim, style.TrimMat, NO_HIT)
	box(folder, cf, "Zierleiste", -outer, outer, h - 1.2, h + 0.05, zBack - 0.3, zOut + 0.3, style.Trim, style.TrimMat, NO_HIT)

	-- Drinnen: Deckenlampen und ein Teppich hinter dem Tor
	local lampColor = style.Ring:Lerp(Color3.new(1, 1, 1), 0.5)
	for i = 1, if depth > 36 then 2 else 1 do
		local z = if depth > 36 then zIn + depth * (i * 2 - 1) / 4 else zMid
		box(folder, cf, "Lampenkette", -0.12, 0.12, h - 3, h, z - 0.12, z + 0.12, Color3.fromRGB(60, 55, 55), Enum.Material.Metal, NO_HIT)
		local lamp = box(folder, cf, "Deckenlampe", -1.3, 1.3, h - 4, h - 3, z - 1.3, z + 1.3, style.Ring, Enum.Material.Neon, NO_HIT)
		pointLight(lamp, lampColor, 50, style.LampBrightness or 1.1)
	end
	box(folder, cf, "Teppich", -5, 5, 0, 0.12, zIn + 0.6, zIn + 6.5, style.Rug, Enum.Material.Fabric, NO_HIT)

	-- Dach je nach Stufe
	local top = h + 1
	if style.Roof == "Giebel" then
		top = gableRoof(folder, cf, style, outer, zFront, zOut, h)
	elseif style.Roof == "Glas" then
		flatRoof(folder, cf, style, outer, zFront, zOut, h, { Transparency = 0.5 })
		-- goldenes Gitter über dem Glas
		for i = -1, 1 do
			roofPart(box(folder, cf, "Dachbalken", i * outer * 0.6 - 0.4, i * outer * 0.6 + 0.4, h + 1, h + 1.5, zFront - 0.6, zOut + 0.6, style.Trim, style.TrimMat))
		end
		for i = 0, 2 do
			local z = zFront + (zOut - zFront) * i / 2
			roofPart(box(folder, cf, "Dachbalken", -outer - 0.6, outer + 0.6, h + 1, h + 1.5, z - 0.4, z + 0.4, style.Trim, style.TrimMat))
		end
	else
		flatRoof(folder, cf, style, outer, zFront, zOut, h)
	end

	-- Extras je Stufe -----------------------------------------------------------------
	if level == 1 then
		-- Holz-Hütte: Schornstein mit Rauch, Laternen am Tor, Kisten und ein Fass davor
		local chimney = roofPart(box(folder, cf, "Schornstein", hw * 0.45, hw * 0.45 + 2.6, h + 1, top + 2.5, zBack - 8, zBack - 5.4, Color3.fromRGB(150, 78, 62), Enum.Material.Brick))
		local smoke = Instance.new("ParticleEmitter")
		smoke.Name = "Rauch"
		smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
		smoke.Color = ColorSequence.new(Color3.fromRGB(235, 235, 235))
		smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) })
		smoke.Size = NumberSequence.new(1.2, 3.5)
		smoke.Lifetime = NumberRange.new(3, 4.5)
		smoke.Rate = 3
		smoke.Speed = NumberRange.new(2, 3)
		smoke.SpreadAngle = Vector2.new(12, 12)
		smoke.EmissionDirection = Enum.NormalId.Top
		smoke.Parent = chimney
		for _, sx in { -1, 1 } do
			lantern(folder, cf, sx * (DOOR_EDGE + 2), 10.5, zFront - 0.9, Color3.fromRGB(255, 200, 110), 22)
		end
		box(folder, cf, "Kiste", outer - 4.2, outer - 1.2, 0, 3, FRONT - 4, FRONT - 1, Color3.fromRGB(170, 120, 70), Enum.Material.WoodPlanks)
		box(folder, cf, "Kiste", outer - 3.6, outer - 1.6, 3, 5, FRONT - 3.6, FRONT - 1.6, Color3.fromRGB(190, 140, 85), Enum.Material.WoodPlanks)
		pillar(folder, cf, "Fass", -outer + 2.6, FRONT - 2.6, 0, 3.2, 1.4, Color3.fromRGB(140, 92, 54), Enum.Material.Wood)
	elseif level == 2 then
		-- Stein-Burg: Zinnen rundherum, zwei Türme vorne mit blauem Dach und Fahne, Fackeln am Tor
		for x = -outer + 1, outer - 1, 4 do
			roofPart(box(folder, cf, "Zinne", x - 1, x + 1, h + 1, h + 3, zFront - 0.6, zIn + 0.2, style.Wall, style.WallMat))
			roofPart(box(folder, cf, "Zinne", x - 1, x + 1, h + 1, h + 3, zBack - 0.2, zOut + 0.6, style.Wall, style.WallMat))
		end
		for z = zIn + 3, zBack - 3, 4 do
			for _, sx in { -1, 1 } do
				local x0, x1 = sx * hw - sx * 0.2, sx * outer + sx * 0.6
				roofPart(box(folder, cf, "Zinne", math.min(x0, x1), math.max(x0, x1), h + 1, h + 3, z - 1, z + 1, style.Wall, style.WallMat))
			end
		end
		for _, sx in { -1, 1 } do
			local x = sx * (outer + 1.5)
			pillar(folder, cf, "Turm", x, FRONT, -0.9, h + 6, 3.4, style.Wall, style.WallMat)
			pillar(folder, cf, "Turmkranz", x, FRONT, h + 6, h + 7.4, 4.1, style.Trim, style.TrimMat, NO_HIT)
			for i = 0, 5 do
				pillar(folder, cf, "Turmdach", x, FRONT, h + 7.4 + i * 1.3, h + 8.7 + i * 1.3, 3.8 - i * 0.62, Color3.fromRGB(70, 115, 200), Enum.Material.Slate, NO_HIT)
			end
			box(folder, cf, "Fahnenmast", x - 0.15, x + 0.15, h + 15, h + 20.5, FRONT - 0.15, FRONT + 0.15, Color3.fromRGB(70, 70, 78), Enum.Material.Metal, NO_HIT)
			box(folder, cf, "Fahne", x, x + sx * 3, h + 18.5, h + 20.5, FRONT - 0.08, FRONT + 0.08, Color3.fromRGB(215, 50, 55), Enum.Material.Fabric, NO_HIT)
			lantern(folder, cf, sx * (DOOR_EDGE + 1.6), 10.5, zFront - 0.9, Color3.fromRGB(255, 150, 60), 24)
		end
	elseif level == 3 then
		-- Lichter-Villa: Säulen-Vordach, Lichterkette an der Fassade, Pflanzen am Tor
		for _, sx in { -1, 1 } do
			pillar(folder, cf, "Saeule", sx * (DOOR_EDGE + 1.5), FRONT - 3.2, 0, DOOR_H + 1, 1, style.Wall, style.WallMat)
			pillar(folder, cf, "Saeulenfuss", sx * (DOOR_EDGE + 1.5), FRONT - 3.2, 0, 0.8, 1.5, style.Trim, style.TrimMat, NO_HIT)
			pillar(folder, cf, "Pflanzkuebel", sx * (outer - 3), FRONT - 2.6, 0, 1.8, 1.4, Color3.fromRGB(196, 110, 72), Enum.Material.Slate)
			part({
				Name = "Pflanze",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(3.6, 3.6, 3.6),
				CFrame = cf * CFrame.new(sx * (outer - 3), 3.2, FRONT - 2.6),
				Color = Color3.fromRGB(70, 170, 80),
				Material = Enum.Material.Grass,
				CanCollide = false,
				Parent = folder,
			})
		end
		box(folder, cf, "Vordach", -DOOR_EDGE - 3, DOOR_EDGE + 3, DOOR_H + 1, DOOR_H + 2, FRONT - 4.6, zFront, style.Wall, style.WallMat, NO_HIT)
		box(folder, cf, "Vordachleiste", -DOOR_EDGE - 3.2, DOOR_EDGE + 3.2, DOOR_H + 2, DOOR_H + 2.4, FRONT - 4.8, zFront, style.Trim, style.TrimMat, NO_HIT)
		local n = 0
		for x = -outer + 1.5, outer - 1.5, 3 do
			n += 1
			local sag = math.abs(math.sin(n * 1.3)) * 0.5
			local bulb = part({
				Name = "Lichterkette",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(0.9, 0.9, 0.9),
				CFrame = cf * CFrame.new(x, h - 2 - sag, zFront - 0.7),
				Color = style.Bulb,
				Material = Enum.Material.Neon,
				CanCollide = false,
				CanQuery = false,
				Parent = folder,
			})
			if n % 4 == 0 then
				pointLight(bulb, style.Bulb, 16, 0.8)
			end
		end
	elseif level == 4 then
		-- Neon-Palast: Leuchtstreifen unten und auf dem Dach, zwei hohe Neon-Säulen vorne
		local pink = Color3.fromRGB(255, 60, 200)
		for _, sx in { -1, 1 } do
			local x0, x1 = sx * outer, sx * (outer + 0.25)
			box(folder, cf, "Neonstreifen", math.min(x0, x1), math.max(x0, x1), 0.3, 0.9, zFront, zOut, pink, Enum.Material.Neon, NO_HIT)
			local px = sx * (outer - 2.5)
			local pylon = box(folder, cf, "Neonsaeule", px - 0.6, px + 0.6, 0, h + 7, FRONT - 3.6, FRONT - 2.4, pink, Enum.Material.Neon)
			pointLight(pylon, pink, 26, 0.9)
		end
		box(folder, cf, "Neonstreifen", -outer, outer, 0.3, 0.9, zOut, zOut + 0.25, pink, Enum.Material.Neon, NO_HIT)
		for _, sx in { -1, 1 } do
			box(folder, cf, "Neonstreifen", sx * DOOR_EDGE, sx * outer, 0.3, 0.9, zFront - 0.25, zFront, pink, Enum.Material.Neon, NO_HIT)
		end
		-- Neon-Rahmen und Linien auf dem Dach
		for i = -1, 1 do
			roofPart(box(folder, cf, "Dachlinie", -outer - 0.6, outer + 0.6, h + 1, h + 1.3, zMid + i * depth * 0.3 - 0.3, zMid + i * depth * 0.3 + 0.3, if i == 0 then pink else style.Trim, Enum.Material.Neon))
		end
		for _, sx in { -1, 1 } do
			local x = sx * (outer + 0.3)
			roofPart(box(folder, cf, "Dachkante", x - 0.3, x + 0.3, h + 1, h + 1.5, zFront - 0.6, zOut + 0.6, style.Trim, Enum.Material.Neon))
		end
		roofPart(box(folder, cf, "Dachkante", -outer - 0.6, outer + 0.6, h + 1, h + 1.5, zFront - 0.6, zFront, style.Trim, Enum.Material.Neon))
		roofPart(box(folder, cf, "Dachkante", -outer - 0.6, outer + 0.6, h + 1, h + 1.5, zOut, zOut + 0.6, style.Trim, Enum.Material.Neon))
		-- zweite Dachstufe mit pinker Leuchtkante und einem Leuchtturm in der Mitte
		local tx, tz0, tz1 = outer - 6, zFront + 6, zOut - 6
		roofPart(box(folder, cf, "Dachstufe", -tx, tx, h + 1, h + 4.5, tz0, tz1, style.Wall, style.WallMat))
		roofPart(box(folder, cf, "Dachkante", -tx - 0.3, tx + 0.3, h + 4.5, h + 5, tz0 - 0.3, tz0 + 0.3, pink, Enum.Material.Neon))
		roofPart(box(folder, cf, "Dachkante", -tx - 0.3, tx + 0.3, h + 4.5, h + 5, tz1 - 0.3, tz1 + 0.3, pink, Enum.Material.Neon))
		for _, sx in { -1, 1 } do
			roofPart(box(folder, cf, "Dachkante", sx * tx - 0.3, sx * tx + 0.3, h + 4.5, h + 5, tz0, tz1, pink, Enum.Material.Neon))
		end
		roofPart(box(folder, cf, "Dachturm", -3, 3, h + 4.5, h + 9, zMid - 3, zMid + 3, style.Wall, style.WallMat))
		local glow = roofPart(box(folder, cf, "Dachleuchte", -2.2, 2.2, h + 9, h + 12, zMid - 2.2, zMid + 2.2, style.Trim, Enum.Material.Neon))
		pointLight(glow, style.Trim, 40, 1)
		-- Neon-Rahmen links und rechts am Tor
		for _, sx in { -1, 1 } do
			local x = sx * (DOOR_EDGE + 0.3)
			box(folder, cf, "Torneon", x - 0.3, x + 0.3, 0, DOOR_H + 2, zFront - 0.3, zFront, style.Trim, Enum.Material.Neon, NO_HIT)
		end
	elseif level == 5 then
		-- Kristall-Festung: Kristalle auf den Ecken und am Tor, Lichtsäule aus der Dachmitte
		local cyan, purple = Color3.fromRGB(0, 255, 255), Color3.fromRGB(200, 100, 255)
		local i = 0
		for _, sx in { -1, 1 } do
			for _, z in { FRONT, zBack + WALL / 2 } do
				i += 1
				local zc = if z == FRONT then FRONT + 3 else zBack - 2
				crystal(folder, cf, sx * (hw - 3), h + 1, zc, 13, if i % 2 == 0 then cyan else purple)
			end
			crystal(folder, cf, sx * (outer + 2.5), -1, FRONT - 1, 13, cyan)
			crystal(folder, cf, sx * (outer + 2.5), -1, zMid + 9, 11, purple)
			crystal(folder, cf, sx * (outer + 2.5), -1, zBack - 2, 12, cyan)
		end
		crystal(folder, cf, 0, h + 1, zMid, 18, purple)
		local beam = part({
			Name = "Lichtsaeule",
			Size = Vector3.new(3, 120, 3),
			CFrame = cf * CFrame.new(0, h + 62, zMid),
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

	-- Runde Podeste für die Kreaturen, mit Leuchtring (färbt Bases.RenderSlot nach Seltenheit)
	local slots = Config.BaseLevels[level].Slots
	for slot = 1, slots do
		local base = cf * slotOffset(level, slot)
		part({
			Name = "Platz" .. slot,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.4, 6.4, 6.4),
			CFrame = base * CFrame.new(0, 0.2, 0) * UPRIGHT,
			Color = style.Pad,
			Material = style.PadMat,
			Parent = folder,
		})
		local ring = part({
			Name = "PlatzRing" .. slot,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.25, 7.2, 7.2),
			CFrame = base * CFrame.new(0, 0.125, 0) * UPRIGHT,
			Color = style.Ring,
			Material = Enum.Material.Neon,
			CanCollide = false,
			Parent = folder,
		})
		ring:SetAttribute("EmptyColor", style.Ring)
	end
end

function Map.SlotCFrame(plot, slot: number): CFrame
	return plot.CFrame * slotOffset(plot.Level or 1, slot) * CFrame.new(0, 0.4, 0)
end

-- Prüft, ob eine Position im Haus einer Base liegt (Veranda zählt mit)
function Map.IsInside(plot, position: Vector3): boolean
	local house = HOUSES[plot.Level or 1] or HOUSES[1]
	local p = plot.CFrame:PointToObjectSpace(position)
	return math.abs(p.X) <= house.HalfW + WALL and p.Z >= FRONT - PORCH and p.Z <= FRONT + house.Depth + WALL and p.Y > -3 and p.Y < 40
end

local STREET_HALF = Config.Map.StreetHalfLength
Map.PackShopPosition = Vector3.new(STREET_HALF + 35, FLOOR_Y, 0)
Map.StatuePosition = Vector3.new(-STREET_HALF - 35, FLOOR_Y, 0)

-- Zufälliger Punkt auf der Straße (für den Meteor)
function Map.RandomStreetPoint(): Vector3
	local half = Config.Map.StreetWidth / 2 - 4
	local z = math.random() * (half - 5) + 5
	if math.random() < 0.5 then
		z = -z
	end
	local x = math.random(-STREET_HALF + 15, STREET_HALF - 15)
	if math.abs(x) < 18 then
		x += 30 -- nicht im Brunnen landen
	end
	return Vector3.new(x, FLOOR_Y, z)
end

function Map.Build()
	local old = workspace:FindFirstChild("KreaturenMap")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "KreaturenMap"
	root.Parent = workspace

	local street = Config.Map.StreetWidth

	-- Boden, Straße, Deko, Landschaft und Licht baut das World-Modul
	World.Build(root, {
		Part = part,
		Billboard = billboard,
		FloorY = FLOOR_Y,
		StreetHalf = STREET_HALF,
		PackShop = Map.PackShopPosition,
		Statue = Map.StatuePosition,
		BaseSize = S,
		BaseZ = street / 2 + S / 2 + 4,
		BaseFront = street / 2 + S / 2 + 4 + FRONT - PORCH, -- hier beginnt die Veranda der Häuser
	})

	-- Pack-Shop am Ende der Straße
	local shopPos = Map.PackShopPosition
	local counter = part({
		Name = "PackTheke",
		Size = Vector3.new(14, 4, 14),
		CFrame = CFrame.new(shopPos + Vector3.new(0, 2, 0)),
		Color = Color3.fromRGB(255, 170, 40),
		Parent = root,
	})
	for _, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		part({
			Name = "ShopSaeule",
			Size = Vector3.new(1.5, 10, 1.5),
			CFrame = CFrame.new(shopPos + Vector3.new(c[1] * 9, 5, c[2] * 9)),
			Color = Color3.new(1, 1, 1),
			Parent = root,
		})
	end
	for i = 0, 3 do
		part({
			Name = "ShopDach",
			Size = Vector3.new(22, 1, 5.5),
			CFrame = CFrame.new(shopPos + Vector3.new(0, 10.5, -8.25 + i * 5.5)),
			Color = if i % 2 == 0 then Color3.fromRGB(255, 80, 80) else Color3.new(1, 1, 1),
			Parent = root,
		})
	end
	-- Auf der Theke stehen die Kisten: als 3D-Modell (ReplicatedStorage.PackModelle), sonst als Würfel
	local packModels = ReplicatedStorage:FindFirstChild("PackModelle")
	for i, pack in Config.Packs do
		local offset = Vector3.new(-3, 4, (i - (#Config.Packs + 1) / 2) * 2.6)
		local template = packModels and packModels:FindFirstChild(pack.Id)
		if template and template:IsA("Model") then
			local chest = template:Clone()
			chest.Name = pack.Id .. "Pack"
			for _, d in chest:GetDescendants() do
				if d:IsA("BasePart") then
					d.Anchored = true
					d.CanCollide = false
					d.CanTouch = false
					d.CanQuery = false
				end
			end
			-- alle Kisten etwa gleich groß, egal in welcher Größe das Modell gespeichert ist
			local chestSize = chest:GetExtentsSize()
			chest:ScaleTo(chest:GetScale() * math.min(2.35 / math.max(chestSize.X, 0.1), 2.3 / math.max(chestSize.Y, 0.1)))
			-- Vorderseite der Modelle zeigt nach -Z, die Spieler kommen von -X
			chest:PivotTo(CFrame.new(shopPos + offset) * CFrame.Angles(0, math.rad(90), 0))
			chest.Parent = root
		else
			part({
				Name = pack.Id .. "Pack",
				Size = Vector3.new(2, 2.4, 2),
				CFrame = CFrame.new(shopPos + offset + Vector3.new(0, 1.2, 0)) * CFrame.Angles(0, math.rad(20), 0),
				Color = pack.Color,
				Material = Enum.Material.Neon,
				Parent = root,
			})
		end
	end
	local _, shopLabels = billboard(counter, UDim2.fromOffset(320, 90), Vector3.new(0, 12, 0), 2, 500)
	shopLabels[1].Text = "KISTEN-SHOP"
	shopLabels[1].TextColor3 = Color3.fromRGB(255, 220, 60)
	shopLabels[2].Text = "Kisten öffnen, Glück haben!"
	prompt(counter, "Packs", "Kisten ansehen", "Kisten-Shop", 0, 14)
	workspace:SetAttribute("PackShopPosition", shopPos)

	-- Bases: 4 Häuser oben, 4 unten, Tor zur Straße
	local basesFolder = Instance.new("Folder")
	basesFolder.Name = "Bases"
	basesFolder.Parent = root

	local plots = {}
	local perRow = math.ceil(Config.Map.BaseCount / 2)
	for i = 1, Config.Map.BaseCount do
		local row = if i <= perRow then 1 else -1
		local col = (i - 1) % perRow + 1
		local x = (col - (perRow + 1) / 2) * Config.Map.BaseSpacing
		local z = row * (street / 2 + S / 2 + 4)
		local pos = Vector3.new(x, FLOOR_Y, z)
		local cf = CFrame.lookAt(pos, Vector3.new(x, FLOOR_Y, 0))

		local model = Instance.new("Model")
		model.Name = "Base_" .. i
		model:SetAttribute("IsPlot", true)
		model:SetAttribute("PlotIndex", i)
		model.Parent = basesFolder

		-- Boden des Hauses (Größe und Farbe setzt BuildDecor je nach Stufe)
		local floor = part({
			Name = "Boden",
			Size = Vector3.new(S, 1, S),
			CFrame = cf * CFrame.new(0, -0.5, 0),
			Parent = model,
		})

		-- Tor mit Schild, sitzt in der Vorderwand
		local gate = {}
		for _, side in { -1, 1 } do
			table.insert(gate, part({
				Name = "Torpfosten",
				Size = Vector3.new(1.5, DOOR_H, 1.5),
				CFrame = cf * CFrame.new(side * GATE_HALF, DOOR_H / 2, FRONT),
				Color = Color3.fromRGB(60, 60, 70),
				Parent = model,
			}))
		end
		local arch = part({
			Name = "Torbogen",
			Size = Vector3.new(GAP + 3, 2, 1.5),
			CFrame = cf * CFrame.new(0, DOOR_H + 1, FRONT),
			Color = Color3.fromRGB(60, 60, 70),
			Parent = model,
		})
		table.insert(gate, arch)
		-- Schild nur aus der Nähe sichtbar, sonst ist die Map voller "Freie Base"-Schilder
		-- (ein Stück vor der Wand, sonst steckt es halb im Giebel)
		local _, signLabels = billboard(arch, UDim2.fromOffset(300, 110), cf:VectorToWorldSpace(Vector3.new(0, 4.5, -3)), 3, 170)

		-- Laserwand (sichtbar, wenn die Base abgeschlossen ist)
		local laser = part({
			Name = "Laserwand",
			Size = Vector3.new(GAP, 13, 0.4),
			CFrame = cf * CFrame.new(0, 6.5, FRONT),
			Color = Color3.fromRGB(255, 30, 30),
			Material = Enum.Material.Neon,
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
			CastShadow = false,
			Parent = model,
		})

		-- Knöpfe drinnen neben dem Tor: Schloss (links) und Upgrade (rechts)
		local function pedestal(px: number, color: Color3, title: string)
			part({
				Name = "Sockel",
				Size = Vector3.new(3, 3, 3),
				CFrame = cf * CFrame.new(px, 1.5, FRONT + 2.6),
				Color = Color3.fromRGB(70, 70, 80),
				Parent = model,
			})
			local button = part({
				Name = "Knopf",
				Size = Vector3.new(2.4, 0.6, 2.4),
				CFrame = cf * CFrame.new(px, 3.3, FRONT + 2.6),
				Color = color,
				Material = Enum.Material.Neon,
				Parent = model,
			})
			-- Schild etwas höher und immer obenauf, damit die Torpfosten es nicht verdecken
			local sign, labels = billboard(button, UDim2.fromOffset(140, 30), Vector3.new(0, 3.5, 0), 1, 60)
			sign.AlwaysOnTop = true
			labels[1].Text = title
			labels[1].TextColor3 = color
			return button
		end
		local lockButton = pedestal(-13.5, Color3.fromRGB(255, 60, 60), "Schloss")
		local upgradeButton = pedestal(13.5, Color3.fromRGB(80, 255, 120), "Upgrade")
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
			Gate = gate,
			Decor = decor,
			Creatures = creatures,
			Laser = laser,
			SignLabels = signLabels,
			LockPrompt = lockPrompt,
			UpgradePrompt = upgradePrompt,
			SpawnCFrame = cf * CFrame.new(0, 4, FRONT + 6),
			Level = 1,
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
