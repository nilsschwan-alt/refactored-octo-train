-- Baut die komplette Map per Skript: Weg, Pack-Shop und 2 Reihen mit je 4 runden Bases.
-- BuildDecor() baut die Optik einer Base je nach Stufe neu (Holz -> Stein -> Lichter -> Neon -> Kristall).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local World = require(script.Parent.World)

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

-- Runde Base: Boden-Radius, Zaun-Radius und Tor (vorne = -Z, zur Straße)
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90)) -- dreht Zylinder so, dass sie stehen
local RADIUS = S / 2
local FENCE_R = RADIUS - 1
local GATE_HALF = GAP / 2 + 0.75 -- Abstand der Torpfosten zur Mitte
local GATE_Z = -math.sqrt(FENCE_R ^ 2 - GATE_HALF ^ 2) -- Tor sitzt genau im Zaun-Ring
local GATE_ANGLE = math.asin(GATE_HALF / FENCE_R) -- dort hört der Zaun links und rechts auf
-- Glaskuppel (Stufe 4 und 5): Kugel, deren Mitte unter dem Boden liegt, oben 22 hoch
local DOME_R, DOME_Y = 34, -12
-- Lichterbögen (Stufe 3): flacherer Bogen, der genau auf dem Zaun landet, oben 18 hoch
local ARC_R, ARC_Y = 29.25, -11.25

-- Position der Kreaturen-Plätze (lokal in der Base, vorne = -Z)
local SLOT_X = { -15, -5, 5, 15 }
local SLOT_Z = { -6, 5, 16 }
local function slotOffset(slot: number): CFrame
	local col = (slot - 1) % 4 + 1
	local row = math.floor((slot - 1) / 4) + 1
	return CFrame.new(SLOT_X[col], 0, SLOT_Z[row])
end

-- Optik pro Stufe ----------------------------------------------------------
-- Rim = leuchtender Rand unter dem Boden, Fence = Zaun-Art, Ring = Leuchtring um leere Plätze
local STYLES = {
	{ -- 1 Holz-Hütte
		Floor = Color3.fromRGB(205, 155, 100), FloorMat = Enum.Material.WoodPlanks,
		Rim = Color3.fromRGB(130, 85, 50), RimMat = Enum.Material.Wood,
		Fence = "Holz", FenceColor = Color3.fromRGB(160, 110, 65), FenceMat = Enum.Material.WoodPlanks, FenceHeight = 3,
		Post = Color3.fromRGB(120, 80, 45), PostMat = Enum.Material.Wood,
		Gate = Color3.fromRGB(125, 85, 50), GateMat = Enum.Material.Wood,
		Pad = Color3.fromRGB(235, 205, 155), PadMat = Enum.Material.Wood,
		Ring = Color3.fromRGB(255, 225, 170),
	},
	{ -- 2 Stein-Burg
		Floor = Color3.fromRGB(150, 150, 162), FloorMat = Enum.Material.Slate,
		Rim = Color3.fromRGB(120, 200, 255), RimMat = Enum.Material.Neon,
		Fence = "Stein", FenceColor = Color3.fromRGB(175, 175, 185), FenceMat = Enum.Material.Cobblestone, FenceHeight = 5,
		Post = Color3.fromRGB(145, 145, 155), PostMat = Enum.Material.Cobblestone,
		Gate = Color3.fromRGB(140, 140, 150), GateMat = Enum.Material.Cobblestone,
		Pad = Color3.fromRGB(205, 205, 212), PadMat = Enum.Material.Concrete,
		Ring = Color3.fromRGB(170, 220, 255),
	},
	{ -- 3 Lichter-Villa
		Floor = Color3.fromRGB(242, 228, 198), FloorMat = Enum.Material.Pebble,
		Rim = Color3.fromRGB(255, 200, 70), RimMat = Enum.Material.Neon,
		Fence = "Lichter", FenceColor = Color3.fromRGB(252, 248, 240), FenceMat = Enum.Material.Marble, FenceHeight = 3.5,
		Post = Color3.fromRGB(255, 200, 70), PostMat = Enum.Material.SmoothPlastic, Bulb = Color3.fromRGB(255, 225, 120),
		Gate = Color3.fromRGB(252, 248, 240), GateMat = Enum.Material.Marble, GateTrim = Color3.fromRGB(255, 200, 70),
		Pad = Color3.fromRGB(255, 246, 225), PadMat = Enum.Material.Marble,
		Ring = Color3.fromRGB(255, 220, 130),
		Arcs = true,
	},
	{ -- 4 Neon-Palast
		Floor = Color3.fromRGB(38, 32, 64), FloorMat = Enum.Material.SmoothPlastic,
		Rim = Color3.fromRGB(0, 230, 255), RimMat = Enum.Material.Neon,
		Fence = "Neon", FenceColor = Color3.fromRGB(32, 26, 58), FenceMat = Enum.Material.SmoothPlastic, FenceHeight = 4,
		Post = Color3.fromRGB(255, 60, 200), PostMat = Enum.Material.Neon, Trim = Color3.fromRGB(0, 230, 255),
		Gate = Color3.fromRGB(32, 26, 58), GateMat = Enum.Material.SmoothPlastic, GateTrim = Color3.fromRGB(255, 60, 200),
		Pad = Color3.fromRGB(60, 55, 100), PadMat = Enum.Material.SmoothPlastic,
		Ring = Color3.fromRGB(0, 200, 255),
		Dome = Color3.fromRGB(120, 230, 255),
	},
	{ -- 5 Kristall-Festung
		Floor = Color3.fromRGB(248, 245, 255), FloorMat = Enum.Material.Marble,
		Rim = Color3.fromRGB(200, 120, 255), RimMat = Enum.Material.Neon,
		Fence = "Kristall", FenceColor = Color3.fromRGB(255, 200, 60), FenceMat = Enum.Material.Metal, FenceHeight = 4.5,
		Post = Color3.fromRGB(255, 215, 90), PostMat = Enum.Material.Metal, Trim = Color3.fromRGB(200, 120, 255),
		Gate = Color3.fromRGB(255, 200, 60), GateMat = Enum.Material.Metal, GateTrim = Color3.fromRGB(200, 120, 255),
		Pad = Color3.fromRGB(240, 235, 255), PadMat = Enum.Material.Marble,
		Ring = Color3.fromRGB(210, 150, 255),
		Dome = Color3.fromRGB(225, 175, 255),
		Crystals = true,
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

-- Punkt auf einem Kreis um die Base-Mitte. angle 0 = vorne (-Z).
-- Die lokale -Z-Achse des Ergebnisses zeigt zur Mitte, X läuft am Kreis entlang.
local function ringCFrame(cf: CFrame, angle: number, radius: number, y: number): CFrame
	local pos = Vector3.new(math.sin(angle) * radius, y, -math.cos(angle) * radius)
	return cf * CFrame.lookAt(pos, Vector3.new(0, y, 0))
end

-- Villen -------------------------------------------------------------------------------
-- Liegt in Studio unter ReplicatedStorage > BaseModelle ein Modell "Stufe1" bis "Stufe5",
-- steht es als richtiges Gebäude hinter den Kreaturen-Plätzen. Vorne am Modell ist -Z, der
-- Pivot liegt unten in der Mitte. Fehlt das Modell, sieht die Base aus wie bisher.
local VILLA_FOLDER = "BaseModelle"
local VILLA_WIDTH = { 32, 36, 40, 42, 44 } -- Breite je Stufe in Studs
local VILLA_MAX_DEPTH = 36 -- tiefer darf sie nicht werden (dahinter liegen Wald und Teich)
local VILLA_MAX_HEIGHT = 46
local VILLA_FRONT_Z = 23 -- so weit hinter der Base-Mitte beginnt die Villa

local function findVilla(level: number): Model?
	local villas = ReplicatedStorage:FindFirstChild(VILLA_FOLDER)
	local template = villas and villas:FindFirstChild("Stufe" .. level)
	if template and template:IsA("Model") and template:FindFirstChildWhichIsA("BasePart", true) then
		return template
	end
	return nil
end

-- Baut die Villa der Stufe hinter die Base. Gibt ihre halbe Breite zurück (dort bleibt der
-- Zaun offen), oder nil, wenn es kein Modell gibt.
local function buildVilla(cf: CFrame, level: number, style, folder: Instance): number?
	local template = findVilla(level)
	if not template then
		return nil
	end
	local villa = template:Clone()
	villa.Name = "Villa"
	for _, d in villa:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false -- die Wände macht unten ein unsichtbarer Kasten
			d.CanTouch = false
			d.CanQuery = false
		elseif d:IsA("LuaSourceContainer") then
			d:Destroy()
		end
	end
	local size = villa:GetExtentsSize()
	if size.X < 0.5 or size.Y < 0.5 or size.Z < 0.5 then
		villa:Destroy()
		return nil
	end
	local width = VILLA_WIDTH[level] or VILLA_WIDTH[#VILLA_WIDTH]
	local factor = math.min(width / size.X, VILLA_MAX_DEPTH / size.Z, VILLA_MAX_HEIGHT / size.Y)
	villa:ScaleTo(villa:GetScale() * factor)

	-- erst grob hinstellen, dann so schieben, dass sie genau hinter den Plätzen auf dem Boden steht
	villa:PivotTo(cf)
	local boxCF, boxSize = villa:GetBoundingBox()
	local want = (cf * CFrame.new(0, boxSize.Y / 2 - 0.3, VILLA_FRONT_Z + boxSize.Z / 2)).Position
	villa:PivotTo(villa:GetPivot() + (want - boxCF.Position))
	villa.Parent = folder

	local center = cf * CFrame.new(0, 0, VILLA_FRONT_Z + boxSize.Z / 2)
	-- Terrasse unter der Villa (verdeckt die Kante zwischen Podest und Wiese)
	part({
		Name = "Terrasse",
		Size = Vector3.new(boxSize.X + 6, 4, boxSize.Z + 8),
		CFrame = center * CFrame.new(0, -2.06, -1),
		Color = style.Pad,
		Material = style.PadMat,
		Parent = folder,
	})
	-- unsichtbarer Kasten, damit niemand durch die Villa läuft
	part({
		Name = "VillaWand",
		Size = Vector3.new(boxSize.X - 2, boxSize.Y, boxSize.Z - 2),
		CFrame = center * CFrame.new(0, boxSize.Y / 2, 0),
		Transparency = 1,
		CanQuery = false,
		CastShadow = false,
		Parent = folder,
	})
	-- warmes Licht vor der Fassade
	local lamp = part({
		Name = "VillaLicht",
		Size = Vector3.new(1, 1, 1),
		CFrame = cf * CFrame.new(0, 9, VILLA_FRONT_Z - 5),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		Parent = folder,
	})
	pointLight(lamp, style.Ring, 34, 0.9)
	return boxSize.X / 2
end

-- Runder Zaun mit Lücke fürs Tor, je Stufe anders. villaHalf = halbe Breite der Villa:
-- dort hinten bleibt der Zaun offen, die Fassade ist dann die Rückwand.
local function buildFence(cf: CFrame, style, folder: Instance, villaHalf: number?)
	local h = style.FenceHeight
	local count = 28
	local step = (math.pi * 2 - GATE_ANGLE * 2) / count
	local chord = 2 * FENCE_R * math.sin(step / 2) + 0.2
	local segR = FENCE_R * math.cos(step / 2)
	local kind = style.Fence
	local metal = style.FenceMat == Enum.Material.Metal
	-- so breit ist die Lücke für die Villa (als Winkel links und rechts von hinten = 180°)
	local villaAngle = if villaHalf then math.asin(math.clamp((villaHalf - 1.5) / FENCE_R, 0, 0.95)) else 0

	for i = 0, count - 1 do
		local mid = GATE_ANGLE + (i + 0.5) * step
		if math.abs(mid - math.pi) < villaAngle then
			continue
		end
		if kind == "Holz" then
			-- zwei Latten zwischen den Pfosten
			for _, y in { 1.1, 2.4 } do
				part({
					Name = "Latte",
					Size = Vector3.new(chord, 0.5, 0.4),
					CFrame = ringCFrame(cf, mid, segR, y),
					Color = style.FenceColor,
					Material = style.FenceMat,
					Parent = folder,
				})
			end
		else
			local thick = if kind == "Stein" then 1.5 else 1
			part({
				Name = "Mauer",
				Size = Vector3.new(chord, h, thick),
				CFrame = ringCFrame(cf, mid, segR, h / 2),
				Color = style.FenceColor,
				Material = style.FenceMat,
				Reflectance = if metal then 0.3 else 0,
				Parent = folder,
			})
			if kind == "Stein" and i % 2 == 0 then
				-- Zinnen wie bei einer Burg
				part({
					Name = "Zinne",
					Size = Vector3.new(chord * 0.5, 1.2, thick + 0.1),
					CFrame = ringCFrame(cf, mid, segR, h + 0.6),
					Color = style.FenceColor,
					Material = style.FenceMat,
					Parent = folder,
				})
			end
			if style.Trim then
				part({
					Name = "Leiste",
					Size = Vector3.new(chord, 0.4, thick + 0.2),
					CFrame = ringCFrame(cf, mid, segR, h + 0.2),
					Color = style.Trim,
					Material = Enum.Material.Neon,
					CanCollide = false,
					Parent = folder,
				})
			end
		end
	end

	-- Pfosten an den Stößen (bei Stein und Lichtern nur jeder zweite, aber immer an den Torseiten)
	for i = 0, count do
		local every = if kind == "Holz" then 1 else 2
		if i % every ~= 0 and i ~= count then
			continue
		end
		local a = GATE_ANGLE + i * step
		if math.abs(a - math.pi) < villaAngle - step * 0.6 then
			continue
		end
		local postH = h + (if kind == "Holz" then 0.6 else 1.2)
		local w = if kind == "Stein" then 2.4 else if kind == "Holz" then 0.8 else 1.3
		part({
			Name = "Pfosten",
			Size = Vector3.new(w, postH, w),
			CFrame = ringCFrame(cf, a, FENCE_R, postH / 2),
			Color = style.Post,
			Material = style.PostMat,
			Reflectance = if style.PostMat == Enum.Material.Metal then 0.3 else 0,
			Parent = folder,
		})
		if kind == "Stein" then
			part({
				Name = "Pfostenkappe",
				Size = Vector3.new(w + 0.6, 0.6, w + 0.6),
				CFrame = ringCFrame(cf, a, FENCE_R, postH + 0.3),
				Color = style.FenceColor,
				Material = style.FenceMat,
				Parent = folder,
			})
		elseif kind == "Lichter" then
			local bulb = part({
				Name = "Gluehbirne",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(1.5, 1.5, 1.5),
				CFrame = ringCFrame(cf, a, FENCE_R, postH + 0.75),
				Color = style.Bulb,
				Material = Enum.Material.Neon,
				CanCollide = false,
				Parent = folder,
			})
			if i % 4 == 0 then
				pointLight(bulb, style.Bulb, 14, 1)
			end
		elseif kind == "Kristall" then
			local crystal = part({
				Name = "Pfostenkristall",
				Size = Vector3.new(1.1, 2.6, 1.1),
				CFrame = ringCFrame(cf, a, FENCE_R, postH + 1.3) * CFrame.Angles(0, math.rad(45), 0),
				Color = if i % 4 == 0 then Color3.fromRGB(0, 255, 255) else style.Trim,
				Material = Enum.Material.Neon,
				Transparency = 0.1,
				CanCollide = false,
				Parent = folder,
			})
			if i % 4 == 0 then
				pointLight(crystal, crystal.Color, 12, 1)
			end
		end
	end
end

-- Zwei Lichterbögen über Kreuz (Stufe 3)
local function buildArcs(cf: CFrame, style, folder: Instance)
	local t0 = math.asin(-ARC_Y / ARC_R)
	local steps = 14
	for _, yaw in { math.rad(45), math.rad(-45) } do
		local dir = Vector3.new(math.sin(yaw), 0, -math.cos(yaw))
		local points = {}
		for i = 0, steps do
			local t = t0 + (math.pi - 2 * t0) * i / steps
			points[i] = dir * (math.cos(t) * ARC_R) + Vector3.new(0, ARC_Y + math.sin(t) * ARC_R, 0)
		end
		for i = 0, steps - 1 do
			local a, b = points[i], points[i + 1]
			part({
				Name = "Bogen",
				Size = Vector3.new(0.5, 0.5, (b - a).Magnitude + 0.1),
				CFrame = cf * CFrame.lookAt((a + b) / 2, b),
				Color = Color3.fromRGB(255, 255, 255),
				CanCollide = false,
				CanQuery = false,
				Parent = folder,
			})
		end
		for i = 1, steps - 1 do
			local bulb = part({
				Name = "Bogenlicht",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(1.1, 1.1, 1.1),
				CFrame = cf * CFrame.new(points[i]),
				Color = if i % 2 == 0 then style.Bulb else Color3.fromRGB(255, 150, 200),
				Material = Enum.Material.Neon,
				CanCollide = false,
				CanQuery = false,
				Parent = folder,
			})
			if i == math.floor(steps / 2) then
				pointLight(bulb, style.Bulb, 30, 1.5)
			end
		end
	end
end

function Map.BuildDecor(plot, level: number)
	local style = STYLES[level] or STYLES[1]
	local cf = plot.CFrame
	local folder = plot.Decor
	folder:ClearAllChildren()

	plot.Floor.Color = style.Floor
	plot.Floor.Material = style.FloorMat

	-- Leuchtender Rand unter dem Boden (Podest-Look)
	part({
		Name = "Rand",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.3, S + 2, S + 2),
		CFrame = cf * CFrame.new(0, -0.95, 0) * UPRIGHT,
		Color = style.Rim,
		Material = style.RimMat,
		CanCollide = false,
		Parent = folder,
	})

	-- Tor in Stufen-Farbe
	for _, gatePart in plot.Gate do
		gatePart.Color = style.Gate
		gatePart.Material = style.GateMat
		gatePart.Reflectance = if style.GateMat == Enum.Material.Metal then 0.3 else 0
	end
	if style.GateTrim then
		part({
			Name = "Torleuchte",
			Size = Vector3.new(GAP + 3.2, 0.5, 1.7),
			CFrame = cf * CFrame.new(0, 13.9, GATE_Z),
			Color = style.GateTrim,
			Material = Enum.Material.Neon,
			CanCollide = false,
			Parent = folder,
		})
	end

	local villaHalf = buildVilla(cf, level, style, folder)
	buildFence(cf, style, folder, villaHalf)
	if style.Arcs and not villaHalf then
		buildArcs(cf, style, folder)
	end

	-- Runde Podeste für die Kreaturen, mit Leuchtring (färbt Bases.RenderSlot nach Seltenheit)
	local slots = Config.BaseLevels[level].Slots
	for slot = 1, slots do
		local base = cf * slotOffset(slot)
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

	-- Glaskuppel ab Stufe 4 (nur ohne Villa, sie würde mitten durchs Gebäude gehen)
	if style.Dome and not villaHalf then
		part({
			Name = "Kuppel",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(DOME_R * 2, DOME_R * 2, DOME_R * 2),
			CFrame = cf * CFrame.new(0, DOME_Y, 0),
			Color = style.Dome,
			Material = Enum.Material.Glass,
			Transparency = 0.86,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
			Parent = folder,
		})
	end

	-- Kristalle rundherum und Lichtsäule für die höchste Stufe
	if style.Crystals then
		for i = 1, 5 do
			if villaHalf and i == 3 then
				continue -- hinten steht die Villa
			end
			local a = math.rad(i * 60) -- vorne (0°) bleibt frei
			local color = if i % 2 == 0 then Color3.fromRGB(0, 255, 255) else Color3.fromRGB(200, 100, 255)
			local crystal = part({
				Name = "Kristall",
				Size = Vector3.new(3, 12, 3),
				CFrame = ringCFrame(cf, a, RADIUS + 3, 4) * CFrame.Angles(math.rad(15), 0, 0) * CFrame.Angles(0, math.rad(45), 0),
				Color = color,
				Material = Enum.Material.Neon,
				Transparency = 0.15,
				CanCollide = false,
				Parent = folder,
			})
			sparkle(crystal, color, 10)
		end
		local beam = part({
			Name = "Lichtsaeule",
			Size = Vector3.new(3, 120, 3),
			CFrame = cf * CFrame.new(0, DOME_Y + DOME_R + 60, 0),
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

-- Prüft, ob eine Position in einer (runden) Base liegt
function Map.IsInside(plot, position: Vector3): boolean
	local localPos = plot.CFrame:PointToObjectSpace(position)
	return localPos.X * localPos.X + localPos.Z * localPos.Z <= RADIUS * RADIUS and localPos.Y < 40
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
		local offset = Vector3.new(-3, 4, (i - (#Config.Packs + 1) / 2) * 2.5)
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
			chest:ScaleTo(0.58)
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

	-- Bases: 4 oben, 4 unten, Eingang zur Straße
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

		-- Runder Boden (Podest)
		local floor = part({
			Name = "Boden",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1, S, S),
			CFrame = cf * CFrame.new(0, -0.5, 0) * UPRIGHT,
			Parent = model,
		})

		-- Torbogen mit Schild, sitzt vorne im Zaun-Ring
		local gate = {}
		for _, side in { -1, 1 } do
			table.insert(gate, part({
				Name = "Torpfosten",
				Size = Vector3.new(1.5, 14, 1.5),
				CFrame = cf * CFrame.new(side * GATE_HALF, 7, GATE_Z),
				Color = Color3.fromRGB(60, 60, 70),
				Parent = model,
			}))
		end
		local arch = part({
			Name = "Torbogen",
			Size = Vector3.new(GAP + 3, 2, 1.5),
			CFrame = cf * CFrame.new(0, 15, GATE_Z),
			Color = Color3.fromRGB(60, 60, 70),
			Parent = model,
		})
		table.insert(gate, arch)
		-- Schild nur aus der Nähe sichtbar, sonst ist die Map voller "Freie Base"-Schilder
		local _, signLabels = billboard(arch, UDim2.fromOffset(300, 110), Vector3.new(0, 4.5, 0), 3, 170)

		-- Laserwand (sichtbar, wenn die Base abgeschlossen ist)
		local laser = part({
			Name = "Laserwand",
			Size = Vector3.new(GAP, 13, 0.4),
			CFrame = cf * CFrame.new(0, 6.5, GATE_Z),
			Color = Color3.fromRGB(255, 30, 30),
			Material = Enum.Material.Neon,
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
			CastShadow = false,
			Parent = model,
		})

		-- Knöpfe: Schloss (links) und Upgrade (rechts)
		local function pedestal(px: number, color: Color3, title: string)
			part({
				Name = "Sockel",
				Size = Vector3.new(3, 3, 3),
				CFrame = cf * CFrame.new(px, 1.5, -20),
				Color = Color3.fromRGB(70, 70, 80),
				Parent = model,
			})
			local button = part({
				Name = "Knopf",
				Size = Vector3.new(2.4, 0.6, 2.4),
				CFrame = cf * CFrame.new(px, 3.3, -20),
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
			Gate = gate,
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
