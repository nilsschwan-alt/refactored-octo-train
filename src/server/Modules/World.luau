-- Die Welt um die Bases herum im Stil "Bunte Simulator-Insel":
-- eine schwebende Insel im Himmel mit bunt gefliestem Leuchtweg, Promenaden mit Laternen
-- und Bänken, Kristall-Brunnen, Pack-Shop-Platz, Riesen-Statue, bunten Bäumen, Teich mit
-- Wasserfall, kleinen Schwebe-Inseln drumherum und einem Wolkenmeer darunter.
-- Alles wird beim Start per Skript gebaut. Zufall mit festem Startwert,
-- damit die Bäume jedes Mal an derselben Stelle stehen.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local CreatureModels = require(script.Parent.CreatureModels)

local World = {}

-- Farben ---------------------------------------------------------------------------
local LEAF_COLORS = {
	Color3.fromRGB(90, 200, 80),
	Color3.fromRGB(120, 220, 90),
	Color3.fromRGB(60, 180, 100),
	Color3.fromRGB(160, 225, 70),
}
local BLOSSOM_COLORS = {
	Color3.fromRGB(255, 170, 210),
	Color3.fromRGB(255, 130, 190),
	Color3.fromRGB(230, 170, 255),
	Color3.fromRGB(255, 200, 120),
}
local FLOWER_COLORS = {
	Color3.fromRGB(255, 90, 120),
	Color3.fromRGB(255, 220, 60),
	Color3.fromRGB(180, 110, 255),
	Color3.fromRGB(255, 255, 255),
	Color3.fromRGB(90, 180, 255),
}
local LAMP_COLORS = {
	Color3.fromRGB(0, 230, 255),
	Color3.fromRGB(255, 90, 210),
	Color3.fromRGB(255, 220, 80),
}
local CRYSTAL_COLORS = {
	Color3.fromRGB(0, 240, 255),
	Color3.fromRGB(200, 110, 255),
	Color3.fromRGB(255, 120, 220),
}
local TILE_COLORS = { Color3.fromRGB(255, 165, 210), Color3.fromRGB(150, 200, 255) } -- rosa / hellblau
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90)) -- dreht Zylinder so, dass sie stehen

-- Insel-Maße -------------------------------------------------------------------------
-- Terrain-Füllungen landen in Roblox etwa einen halben Block (2 Studs) höher als angegeben.
-- Darum füllen wir alles 2 Studs tiefer: Die Terrain-Oberkante liegt dann bei ca. 0, also
-- unter der Spielwiese (0 bis 1) und den Base-Böden (Oberkante 2). Sonst flackert es.
local TERRAIN_DROP = 2
local ISLAND_CORE_X, ISLAND_CORE_Z = 275, 125 -- Kern-Rechteck der Insel
local ISLAND_ROUND = 60 -- so weit ragt der runde Rand über das Kern-Rechteck hinaus
local BARRIER_X, BARRIER_Z = 310, 170 -- unsichtbare Wände, damit niemand runterfällt
local WIESE_HALF_X, WIESE_HALF_Z = 290, 108 -- glatte Spielwiese (Part) rund um Bases und Weg
-- Ausbuchtungen am Rand, damit die Insel von oben nicht wie ein Rechteck aussieht: X, Z, Radius
local LOBES = {
	{ -320, 120, 70 },
	{ -345, -40, 75 },
	{ -250, -175, 65 },
	{ -60, -190, 70 },
	{ 300, -150, 65 },
	{ 345, 40, 70 },
	{ 250, 175, 70 },
	{ 40, 195, 75 },
	{ -150, 200, 60 },
}

-- Teich hinter der unteren Reihe, ein Bach läuft zur Inselkante und fällt als Wasserfall runter.
-- Je Eintrag: Versatz X, Versatz Z, Radius
local LAKE_CENTER = Vector3.new(90, 0, -152) -- zwischen zwei Villen, etwas dahinter
local LAKE_BLOBS = {
	{ 0, 0, 15 },
	{ -13, 6, 10 },
	{ 13, -4, 11 },
}
local LAKE_WATER_Y = -1 - TERRAIN_DROP -- angegebene Wasser-Oberkante
local EDGE_Z = -(ISLAND_CORE_Z + ISLAND_ROUND) -- Inselkante hinter dem Teich (dort ist der Wasserfall)

-- Misst mit einem Strahl von oben, wo das Terrain an einer Stelle wirklich ist.
-- Klappt erst kurz nach dem Füllen (die Kollision vom Terrain wird einen Moment später fertig).
local function terrainY(x: number, z: number, ignoreWater: boolean): number?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	params.IgnoreWater = ignoreWater
	local hit = workspace:Raycast(Vector3.new(x, 150, z), Vector3.new(0, -300, 0), params)
	return hit and hit.Position.Y
end

-- Liegt ein Punkt im Teich oder am Ufer?
local function inLake(x: number, z: number, margin: number): boolean
	for _, blob in LAKE_BLOBS do
		local dx = x - (LAKE_CENTER.X + blob[1])
		local dz = z - (LAKE_CENTER.Z + blob[2])
		if dx * dx + dz * dz < (blob[3] + margin) ^ 2 then
			return true
		end
	end
	return false
end

-- Liegt ein Punkt auf dem Bach zum Wasserfall?
local function onStream(x: number, z: number): boolean
	return math.abs(x - LAKE_CENTER.X) < 8 and z < LAKE_CENTER.Z - 8
end

-- Bodenhöhe für Deko: auf der Spielwiese 1, draußen gemessen auf dem Terrain
local function groundY(x: number, z: number): number
	if math.abs(x) <= WIESE_HALF_X and math.abs(z) <= WIESE_HALF_Z then
		return 1
	end
	local y = terrainY(x, z, true)
	return if y then y - 0.25 else 1 -- etwas einsinken lassen, damit nichts schwebt
end

-- Licht & Stimmung: hell, bunt, sonnig ------------------------------------------------
local function setupLighting()
	Lighting.ClockTime = 13.5
	Lighting.Brightness = 2.6
	Lighting.GlobalShadows = true
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 150, 175)
	Lighting.Ambient = Color3.fromRGB(80, 80, 105)

	local function effect(className: string, name: string)
		local old = Lighting:FindFirstChild(name)
		if old then
			old:Destroy()
		end
		local e = Instance.new(className)
		e.Name = name
		e.Parent = Lighting
		return e
	end

	-- Alte Dunst-, Leucht- und Sonnenstrahl-Effekte aus dem Place entfernen. Roblox nimmt sonst irgendeinen
	-- der beiden Dunst-Effekte, und zwei Leucht-Effekte addieren sich.
	for _, old in Lighting:GetChildren() do
		if
			(old:IsA("Atmosphere") and old.Name ~= "SpielDunst")
			or (old:IsA("BloomEffect") and old.Name ~= "SpielLeuchten")
			or (old:IsA("SunRaysEffect") and old.Name ~= "SpielSonnenstrahlen")
		then
			old:Destroy()
		end
	end

	local atmosphere = effect("Atmosphere", "SpielDunst") :: Atmosphere
	atmosphere.Density = 0.22
	atmosphere.Offset = 0.1
	atmosphere.Haze = 0.6
	atmosphere.Glare = 0.3
	atmosphere.Color = Color3.fromRGB(215, 230, 255)
	atmosphere.Decay = Color3.fromRGB(160, 175, 230)

	-- Leuchten etwas zurückgedreht: vorher waren Münzen riesige gelbe Flecken
	local bloom = effect("BloomEffect", "SpielLeuchten") :: BloomEffect
	bloom.Intensity = 0.4
	bloom.Size = 18
	bloom.Threshold = 1.3

	local rays = effect("SunRaysEffect", "SpielSonnenstrahlen") :: SunRaysEffect
	rays.Intensity = 0.06
	rays.Spread = 0.5

	local color = effect("ColorCorrectionEffect", "SpielFarben") :: ColorCorrectionEffect
	color.Saturation = 0.3
	color.Contrast = 0.1
	color.Brightness = 0

	local terrain = workspace.Terrain
	local clouds = terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	clouds.Cover = 0.5
	clouds.Density = 0.55
	clouds.Color = Color3.fromRGB(255, 245, 255)
	clouds.Parent = terrain
end

-- Insel aus Terrain --------------------------------------------------------------------
-- Ruft fn(x, z) für Punkte rund um das Kern-Rechteck auf (dort sitzen die runden Rand-Scheiben)
local function aroundCore(step: number, fn: (number, number) -> ())
	local nx = math.ceil(ISLAND_CORE_X * 2 / step)
	local nz = math.ceil(ISLAND_CORE_Z * 2 / step)
	for i = 0, nx do
		local x = -ISLAND_CORE_X + i * (ISLAND_CORE_X * 2 / nx)
		fn(x, -ISLAND_CORE_Z)
		fn(x, ISLAND_CORE_Z)
	end
	for i = 1, nz - 1 do
		local z = -ISLAND_CORE_Z + i * (ISLAND_CORE_Z * 2 / nz)
		fn(-ISLAND_CORE_X, z)
		fn(ISLAND_CORE_X, z)
	end
end

-- Fläche aus Kern-Rechteck + runden Rand-Scheiben füllen (für Gras- und Erdschicht)
local function fillIslandLayer(yTop: number, height: number, inset: number, material: Enum.Material)
	local terrain = workspace.Terrain
	local cy = yTop - height / 2 - TERRAIN_DROP
	terrain:FillBlock(CFrame.new(0, cy, 0), Vector3.new(ISLAND_CORE_X * 2, height, ISLAND_CORE_Z * 2), material)
	aroundCore(40, function(x, z)
		terrain:FillCylinder(CFrame.new(x, cy, z), height, ISLAND_ROUND - inset, material)
	end)
	for _, lobe in LOBES do
		terrain:FillCylinder(CFrame.new(lobe[1], cy, lobe[2]), height, lobe[3] - inset, material)
	end
end

local function buildIsland(info, rng: Random)
	local terrain = workspace.Terrain
	terrain:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(110, 205, 90))
	terrain:SetMaterialColor(Enum.Material.Ground, Color3.fromRGB(160, 110, 75))
	terrain:SetMaterialColor(Enum.Material.Rock, Color3.fromRGB(150, 135, 175))
	terrain:SetMaterialColor(Enum.Material.Sand, Color3.fromRGB(255, 230, 170))
	terrain.WaterColor = Color3.fromRGB(40, 170, 220)
	terrain.WaterTransparency = 0.5
	terrain.WaterWaveSize = 0.15
	terrain.WaterWaveSpeed = 8
	terrain.WaterReflectance = 0.35

	-- 1. Felsige Unterseite: viele Felskugeln, in der Mitte tiefer als am Rand
	for x = -ISLAND_CORE_X - 20, ISLAND_CORE_X + 20, 55 do
		for z = -ISLAND_CORE_Z - 20, ISLAND_CORE_Z + 20, 55 do
			local fx = 1 - math.abs(x) / (ISLAND_CORE_X + ISLAND_ROUND)
			local fz = 1 - math.abs(z) / (ISLAND_CORE_Z + ISLAND_ROUND)
			local f = math.clamp(math.min(fx, fz) * 2.2, 0.15, 1)
			local depth = 25 + f * 75
			local r = rng:NextNumber(34, 44)
			local top = -22 - TERRAIN_DROP
			terrain:FillBall(Vector3.new(x, top - r, z), r, Enum.Material.Rock)
			terrain:FillBall(
				Vector3.new(x + rng:NextNumber(-10, 10), top - depth * 0.6 - r * 0.4, z + rng:NextNumber(-10, 10)),
				r * 0.7,
				Enum.Material.Rock
			)
			terrain:FillBall(
				Vector3.new(x + rng:NextNumber(-8, 8), top - depth - r * 0.2, z + rng:NextNumber(-8, 8)),
				r * 0.4,
				Enum.Material.Rock
			)
		end
	end

	-- Fels auch unter den Ausbuchtungen
	for _, lobe in LOBES do
		local r = lobe[3] * 0.8
		local top = -22 - TERRAIN_DROP
		terrain:FillBall(Vector3.new(lobe[1], top - r, lobe[2]), r, Enum.Material.Rock)
		terrain:FillBall(
			Vector3.new(lobe[1] + rng:NextNumber(-10, 10), top - r * 1.3, lobe[2] + rng:NextNumber(-10, 10)),
			r * 0.5,
			Enum.Material.Rock
		)
	end

	-- 2. Braune Erdschicht direkt unter dem Gras (sieht man an der Inselkante)
	fillIslandLayer(-6, 18, 2, Enum.Material.Ground)
	-- 3. Grasdecke oben
	fillIslandLayer(0, 6, 0, Enum.Material.Grass)

	-- Unter Weg, Promenaden, Bases und Plätzen kein Terrain-Gras: dessen Halme wachsen
	-- sonst durch die Bauteile durch. "Ground" hat keine Halme und liegt unsichtbar darunter.
	-- Am Inselrand (runde Füllungen) liegt das Gras zwei Studs höher als in der Mitte und würde
	-- die Böden überdecken. Darum dort erst alles ab -4 wegnehmen und die Schicht neu einfüllen:
	-- so liegt die Oberkante überall bei ca. 0.
	-- (Am Rand so einer Fläche steigt das Terrain über etwa 4 Studs wieder an.)
	local function flatten(cx: number, cz: number, sizeX: number, sizeZ: number, material: Enum.Material)
		terrain:FillBlock(CFrame.new(cx, 4, cz), Vector3.new(sizeX, 16, sizeZ), Enum.Material.Air)
		terrain:FillBlock(CFrame.new(cx, -3 - TERRAIN_DROP, cz), Vector3.new(sizeX, 6, sizeZ), material)
	end
	local hardX = info.StreetHalf + 76
	local hardZ = info.BaseZ + info.BaseSize / 2 + 6
	-- die ganze Spielwiese (außen herum Gras)
	flatten(0, 0, WIESE_HALF_X * 2 + 2, WIESE_HALF_Z * 2 + 2, Enum.Material.Grass)
	-- innen "Ground" ohne Halme: unter Weg, Häusern und Plätzen
	flatten(0, 0, hardX * 2, hardZ * 2, Enum.Material.Ground)

	-- Teich: Sandufer, ausheben, Sandboden, Wasser rein
	for _, blob in LAKE_BLOBS do
		local center = LAKE_CENTER + Vector3.new(blob[1], 0, blob[2])
		terrain:FillCylinder(CFrame.new(center + Vector3.new(0, -3 - TERRAIN_DROP, 0)), 6, blob[3] + 5, Enum.Material.Sand)
	end
	for _, blob in LAKE_BLOBS do
		local center = LAKE_CENTER + Vector3.new(blob[1], 0, blob[2])
		terrain:FillCylinder(CFrame.new(center + Vector3.new(0, -5 - TERRAIN_DROP, 0)), 10, blob[3], Enum.Material.Air)
	end
	for _, blob in LAKE_BLOBS do
		local center = LAKE_CENTER + Vector3.new(blob[1], 0, blob[2])
		terrain:FillCylinder(CFrame.new(center + Vector3.new(0, -10 - TERRAIN_DROP, 0)), 4, blob[3], Enum.Material.Sand)
		local bottom = -8 - TERRAIN_DROP
		terrain:FillCylinder(
			CFrame.new(center + Vector3.new(0, (LAKE_WATER_Y + bottom) / 2, 0)),
			LAKE_WATER_Y - bottom,
			blob[3],
			Enum.Material.Water
		)
	end

	-- Bach vom Teich bis zur Inselkante: Rinne ausheben, Sandboden, Wasser auf Teich-Höhe
	local streamFrom = LAKE_CENTER.Z - 10
	local streamTo = EDGE_Z + 2
	local streamLen = streamFrom - streamTo
	local streamCF = CFrame.new(LAKE_CENTER.X, 0, (streamFrom + streamTo) / 2)
	terrain:FillBlock(streamCF * CFrame.new(0, -3 - TERRAIN_DROP, 0), Vector3.new(8, 18, streamLen + 4), Enum.Material.Air)
	terrain:FillBlock(streamCF * CFrame.new(0, -10.5 - TERRAIN_DROP, 0), Vector3.new(8, 7, streamLen + 4), Enum.Material.Sand)
	-- Wasser genauso wie im Teich füllen (mit Zylindern), damit es exakt gleich hoch steht
	local bottom = -8 - TERRAIN_DROP
	for z = streamFrom, streamTo, -3 do
		terrain:FillCylinder(
			CFrame.new(LAKE_CENTER.X, (LAKE_WATER_Y + bottom) / 2, z),
			LAKE_WATER_Y - bottom,
			4,
			Enum.Material.Water
		)
	end
end

-- Unsichtbare Wände am Inselrand
local function buildBarrier(info, parent: Instance)
	local h = 80
	for _, side in { -1, 1 } do
		info.Part({
			Name = "Inselrand",
			Size = Vector3.new(2, h, BARRIER_Z * 2),
			CFrame = CFrame.new(side * BARRIER_X, h / 2 - 5, 0),
			Transparency = 1,
			CanQuery = false,
			CastShadow = false,
			Parent = parent,
		})
		info.Part({
			Name = "Inselrand",
			Size = Vector3.new(BARRIER_X * 2, h, 2),
			CFrame = CFrame.new(0, h / 2 - 5, side * BARRIER_Z),
			Transparency = 1,
			CanQuery = false,
			CastShadow = false,
			Parent = parent,
		})
	end
end

-- Natur-Bausteine -----------------------------------------------------------------------
local function ball(info, parent: Instance, name: string, size: number, pos: Vector3, color: Color3, material: Enum.Material?)
	return info.Part({
		Name = name,
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(size, size, size),
		CFrame = CFrame.new(pos),
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
		Parent = parent,
	})
end

local function cylinderUp(info, parent: Instance, name: string, radius: number, height: number, pos: Vector3, color: Color3, material: Enum.Material?, props: { [string]: any }?)
	local p = info.Part({
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, radius * 2, radius * 2),
		CFrame = CFrame.new(pos) * UPRIGHT,
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
		Parent = parent,
	})
	if props then
		for k, v in props do
			(p :: any)[k] = v
		end
	end
	return p
end

-- Runder Laubbaum (grün) oder Blütenbaum (rosa/lila)
local function roundTree(info, parent: Instance, pos: Vector3, scale: number, rng: Random, blossom: boolean)
	local trunkHeight = 8 * scale
	info.Part({
		Name = "Stamm",
		Size = Vector3.new(1.6 * scale, trunkHeight, 1.6 * scale),
		CFrame = CFrame.new(pos + Vector3.new(0, trunkHeight / 2, 0)),
		Color = Color3.fromRGB(140, 95, 60),
		Material = Enum.Material.Wood,
		Parent = parent,
	})
	local colors = if blossom then BLOSSOM_COLORS else LEAF_COLORS
	local leafColor = colors[rng:NextInteger(1, #colors)]
	ball(info, parent, "Krone", 9 * scale, pos + Vector3.new(0, trunkHeight + 2 * scale, 0), leafColor)
	for _ = 1, 3 do
		local offset = Vector3.new(rng:NextNumber(-3, 3), rng:NextNumber(0, 3), rng:NextNumber(-3, 3)) * scale
		ball(info, parent, "Krone", rng:NextNumber(5, 7) * scale, pos + Vector3.new(0, trunkHeight + 1.5 * scale, 0) + offset, leafColor)
	end
end

-- Stufen-Tanne aus Scheiben, die nach oben kleiner werden
local function tieredTree(info, parent: Instance, pos: Vector3, scale: number, rng: Random)
	local color = LEAF_COLORS[rng:NextInteger(1, #LEAF_COLORS)]
	cylinderUp(info, parent, "Stamm", 0.8 * scale, 5 * scale, pos + Vector3.new(0, 2.5 * scale, 0), Color3.fromRGB(140, 95, 60), Enum.Material.Wood)
	for i = 0, 3 do
		local r = (5 - i * 1.1) * scale
		cylinderUp(info, parent, "Ebene", r, 2.2 * scale, pos + Vector3.new(0, (5 + i * 2.6) * scale, 0), color)
	end
	ball(info, parent, "Spitze", 1.6 * scale, pos + Vector3.new(0, 15.6 * scale, 0), color)
end

local function bush(info, parent: Instance, pos: Vector3, rng: Random)
	local color = LEAF_COLORS[rng:NextInteger(1, #LEAF_COLORS)]
	for _ = 1, rng:NextInteger(2, 3) do
		local s = rng:NextNumber(3, 5)
		ball(info, parent, "Busch", s, pos + Vector3.new(rng:NextNumber(-1.5, 1.5), s * 0.35, rng:NextNumber(-1.5, 1.5)), color)
	end
	if rng:NextNumber() < 0.5 then
		local berry = ball(info, parent, "Beere", 0.8, pos + Vector3.new(rng:NextNumber(-1, 1), 2.4, rng:NextNumber(-1, 1)), FLOWER_COLORS[rng:NextInteger(1, #FLOWER_COLORS)])
		berry.CanCollide = false
	end
end

local function flower(info, parent: Instance, pos: Vector3, rng: Random, big: boolean)
	local s = if big then 2.5 else 1
	info.Part({
		Name = "Stiel",
		Size = Vector3.new(0.2 * s, 1.2 * s, 0.2 * s),
		CFrame = CFrame.new(pos + Vector3.new(0, 0.6 * s, 0)),
		Color = Color3.fromRGB(60, 160, 60),
		CanCollide = false,
		Parent = parent,
	})
	local color = FLOWER_COLORS[rng:NextInteger(1, #FLOWER_COLORS)]
	local head = pos + Vector3.new(0, 1.3 * s, 0)
	for i = 0, 4 do
		local a = i / 5 * math.pi * 2
		local petal = ball(info, parent, "Bluetenblatt", 0.55 * s, head + Vector3.new(math.cos(a) * 0.35 * s, 0, math.sin(a) * 0.35 * s), color)
		petal.CanCollide = false
	end
	local middle = ball(info, parent, "Bluetenmitte", 0.4 * s, head + Vector3.new(0, 0.12 * s, 0), Color3.fromRGB(255, 230, 80))
	middle.CanCollide = false
end

local function mushroom(info, parent: Instance, pos: Vector3, rng: Random)
	local s = rng:NextNumber(1, 1.8)
	cylinderUp(info, parent, "Pilzstiel", 0.6 * s, 2 * s, pos + Vector3.new(0, s, 0), Color3.fromRGB(250, 240, 220))
	local capColor = if rng:NextNumber() < 0.6 then Color3.fromRGB(240, 60, 70) else Color3.fromRGB(170, 100, 255)
	cylinderUp(info, parent, "Pilzhut", 1.8 * s, 0.9 * s, pos + Vector3.new(0, 2.3 * s, 0), capColor)
	for i = 0, 3 do
		local a = i / 4 * math.pi * 2 + rng:NextNumber(0, 1)
		local dot = ball(info, parent, "Punkt", 0.5 * s, pos + Vector3.new(math.cos(a) * 1.1 * s, 2.75 * s, math.sin(a) * 1.1 * s), Color3.new(1, 1, 1))
		dot.CanCollide = false
	end
end

local function crystalCluster(info, parent: Instance, pos: Vector3, rng: Random, scale: number?)
	local s = scale or 1
	local color = CRYSTAL_COLORS[rng:NextInteger(1, #CRYSTAL_COLORS)]
	for i = 1, rng:NextInteger(3, 5) do
		local h = rng:NextNumber(3, 7) * s * (if i == 1 then 1.4 else 1)
		local crystal = info.Part({
			Name = "Kristall",
			Size = Vector3.new(1.4 * s, h, 1.4 * s),
			CFrame = CFrame.new(pos + Vector3.new(rng:NextNumber(-1.5, 1.5) * s, h * 0.4, rng:NextNumber(-1.5, 1.5) * s))
				* CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 6), rng:NextNumber(-0.4, 0.4)),
			Color = color,
			Material = Enum.Material.Neon,
			Transparency = 0.15,
			CanCollide = false,
			Parent = parent,
		})
		if i == 1 then
			local light = Instance.new("PointLight")
			light.Color = color
			light.Range = 12
			light.Brightness = 1
			light.Parent = crystal
		end
	end
end

-- Felsbrocken aus Terrain: 1-3 runde Steine, halb im Boden
local function rock(pos: Vector3, rng: Random)
	local terrain = workspace.Terrain
	for i = 1, rng:NextInteger(1, 3) do
		local r = rng:NextNumber(3, 5) / i
		local offset = if i == 1 then Vector3.zero else Vector3.new(rng:NextNumber(-4, 4), 0, rng:NextNumber(-4, 4))
		terrain:FillBall(pos + offset + Vector3.new(0, -r * 0.35, 0), math.max(r, 2.5), Enum.Material.Rock)
	end
end

-- Zufälliger Baum (Mischung aus allen Sorten)
local function anyTree(info, parent: Instance, pos: Vector3, scale: number, rng: Random)
	local roll = rng:NextNumber()
	if roll < 0.45 then
		roundTree(info, parent, pos, scale, rng, false)
	elseif roll < 0.7 then
		roundTree(info, parent, pos, scale, rng, true)
	else
		tieredTree(info, parent, pos, scale, rng)
	end
end

-- Seerosen und Schilf am Teich, Bach und Wasserfall über die Inselkante
local function lakeDecor(info, parent: Instance, rng: Random)
	local part = info.Part
	local LAKE_SURFACE_Y = terrainY(LAKE_CENTER.X, LAKE_CENTER.Z, false) or (LAKE_WATER_Y + TERRAIN_DROP)
	local padColors = { Color3.fromRGB(80, 185, 80), Color3.fromRGB(110, 205, 90) }
	local placed = 0
	for _ = 1, 200 do
		if placed >= 8 then
			break
		end
		local x = LAKE_CENTER.X + rng:NextNumber(-25, 25)
		local z = LAKE_CENTER.Z + rng:NextNumber(-18, 18)
		if inLake(x, z, -4) then
			local size = rng:NextNumber(2.5, 4)
			local pad = part({
				Name = "Seerose",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.2, size, size),
				CFrame = CFrame.new(x, LAKE_SURFACE_Y + 0.1, z) * CFrame.Angles(0, rng:NextNumber(0, 6), math.rad(90)),
				Color = padColors[rng:NextInteger(1, #padColors)],
				CanCollide = false,
				Parent = parent,
			})
			if rng:NextNumber() < 0.5 then
				part({
					Name = "Bluete",
					Shape = Enum.PartType.Ball,
					Size = Vector3.new(1, 1, 1),
					CFrame = pad.CFrame * CFrame.new(0.45, 0, 0),
					Color = Color3.fromRGB(255, 150, 200),
					CanCollide = false,
					Parent = parent,
				})
			end
			placed += 1
		end
	end
	for _, blob in LAKE_BLOBS do
		for _ = 1, 4 do
			local a = rng:NextNumber(0, math.pi * 2)
			local dist = blob[3] - rng:NextNumber(0.5, 2)
			local x = LAKE_CENTER.X + blob[1] + math.cos(a) * dist
			local z = LAKE_CENTER.Z + blob[2] + math.sin(a) * dist
			-- nur am Rand, nicht mitten im Teich und nicht im Bach
			if inLake(x, z, -4) or onStream(x, z) then
				continue
			end
			for i = 1, 3 do
				local h = rng:NextNumber(3.5, 6)
				part({
					Name = "Schilf",
					Size = Vector3.new(0.3, h, 0.3),
					CFrame = CFrame.new(x + rng:NextNumber(-1, 1), LAKE_SURFACE_Y - 0.5 + h / 2, z + rng:NextNumber(-1, 1))
						* CFrame.Angles(rng:NextNumber(-0.15, 0.15), 0, rng:NextNumber(-0.15, 0.15)),
					Color = if i == 1 then Color3.fromRGB(150, 110, 60) else Color3.fromRGB(90, 160, 60),
					CanCollide = false,
					Parent = parent,
				})
			end
		end
	end

end

-- Wasserfall an der Inselkante: zwei schräge Wasserbahnen, fallende Tropfen, Gischt und eine Wolke unten
local function buildWaterfall(info, parent: Instance)
	local part = info.Part
	local x = LAKE_CENTER.X
	local topY = terrainY(x, EDGE_Z + 4, false) or (LAKE_WATER_Y + TERRAIN_DROP)
	local bottomY = -120
	local height = topY - bottomY
	local drift = 16 -- unten so weit von der Kante weg (fällt im Bogen)
	local mid = Vector3.new(x, (topY + bottomY) / 2, EDGE_Z - 1 - drift / 2)
	local tilt = CFrame.Angles(math.atan(drift / height), 0, 0)
	-- zwei leicht schräge Seitenbahnen, damit er nicht wie ein einzelnes Brett aussieht
	for _, side in { -1, 1 } do
		part({
			Name = "Wasserfallrand",
			Size = Vector3.new(5, height * 0.92, 0.8),
			CFrame = CFrame.new(mid + Vector3.new(side * 5, -height * 0.04, 0.6)) * CFrame.Angles(0, math.rad(side * 12), 0) * tilt,
			Color = Color3.fromRGB(150, 220, 255),
			Material = Enum.Material.Glass,
			Transparency = 0.55,
			CanCollide = false,
			CanQuery = false,
			CastShadow = false,
			Parent = parent,
		})
	end
	part({
		Name = "Wasserfall",
		Size = Vector3.new(9, height, 1),
		CFrame = CFrame.new(mid) * tilt,
		Color = Color3.fromRGB(110, 205, 255),
		Material = Enum.Material.Glass,
		Transparency = 0.45,
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
		Parent = parent,
	})
	part({
		Name = "Wasserfallschaum",
		Size = Vector3.new(6, height, 0.4),
		CFrame = CFrame.new(mid) * tilt * CFrame.new(0, 0, -0.8),
		Color = Color3.fromRGB(235, 250, 255),
		Material = Enum.Material.Neon,
		Transparency = 0.8,
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
		Parent = parent,
	})
	-- fallende Tropfen oben an der Kante
	local source = part({
		Name = "WasserfallQuelle",
		Size = Vector3.new(12, 0.5, 0.5),
		CFrame = CFrame.new(x, topY - 0.3, EDGE_Z - 1),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		Parent = parent,
	})
	local drops = Instance.new("ParticleEmitter")
	drops.Color = ColorSequence.new(Color3.fromRGB(220, 245, 255))
	drops.Size = NumberSequence.new(1.5, 5)
	drops.Transparency = NumberSequence.new(0.3, 1)
	drops.Lifetime = NumberRange.new(2.5, 3)
	drops.Rate = 70
	drops.Speed = NumberRange.new(4, 7)
	drops.SpreadAngle = Vector2.new(10, 10)
	drops.Acceleration = Vector3.new(0, -45, 0)
	drops.EmissionDirection = Enum.NormalId.Front -- Front = -Z = von der Insel weg
	drops.Parent = source
	-- Gischt und Wolke unten
	local mist = part({
		Name = "Gischt",
		Size = Vector3.new(10, 1, 10),
		CFrame = CFrame.new(x, bottomY + 18, EDGE_Z - 1 - drift), -- knapp über der Wolke
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		Parent = parent,
	})
	local spray = Instance.new("ParticleEmitter")
	spray.Color = ColorSequence.new(Color3.fromRGB(240, 250, 255))
	spray.Size = NumberSequence.new(8, 18)
	spray.Transparency = NumberSequence.new(0.5, 1)
	spray.Lifetime = NumberRange.new(2.5, 4)
	spray.Rate = 12
	spray.Speed = NumberRange.new(2, 5)
	spray.SpreadAngle = Vector2.new(60, 60)
	spray.Parent = mist
	local cloud = ball(info, parent, "Wolke", 110, Vector3.new(x, bottomY - 40, EDGE_Z - 1 - drift), Color3.fromRGB(250, 245, 255))
	cloud.CanCollide = false
	cloud.CanQuery = false
	cloud.CastShadow = false
end

-- Kleine Schwebe-Inseln rund um die große Insel
local MINI_ISLANDS = {
	Vector3.new(-430, 10, -270),
	Vector3.new(440, 30, -250),
	Vector3.new(-470, -15, 250),
	Vector3.new(470, 5, 270),
	Vector3.new(0, 45, -330),
	Vector3.new(-60, -10, 345),
	Vector3.new(-570, 35, 0),
	Vector3.new(570, 20, 30),
}
local miniRadius = {}
local function buildMiniIslandTerrain(rng: Random)
	local terrain = workspace.Terrain
	for i, pos in MINI_ISLANDS do
		local r = rng:NextNumber(20, 32)
		miniRadius[i] = r
		terrain:FillBall(pos + Vector3.new(0, -r * 0.7 - TERRAIN_DROP, 0), r * 0.85, Enum.Material.Rock)
		terrain:FillBall(pos + Vector3.new(rng:NextNumber(-5, 5), -r * 1.5 - TERRAIN_DROP, rng:NextNumber(-5, 5)), r * 0.45, Enum.Material.Rock)
		terrain:FillCylinder(CFrame.new(pos + Vector3.new(0, -4 - TERRAIN_DROP, 0)), 4, r, Enum.Material.Ground)
		terrain:FillCylinder(CFrame.new(pos + Vector3.new(0, -1.5 - TERRAIN_DROP, 0)), 3, r, Enum.Material.Grass)
	end
end

local function decorateMiniIslands(info, parent: Instance, rng: Random)
	local function on(x: number, z: number, fallback: number): Vector3
		local y = terrainY(x, z, true)
		return Vector3.new(x, if y then y - 0.25 else fallback, z)
	end
	for i, pos in MINI_ISLANDS do
		local r = miniRadius[i] or 20
		if i % 3 == 0 then
			crystalCluster(info, parent, on(pos.X, pos.Z, pos.Y), rng, 2)
		else
			anyTree(info, parent, on(pos.X, pos.Z, pos.Y), rng:NextNumber(1.3, 1.8), rng)
			local bx, bz = pos.X + r * 0.5, pos.Z + rng:NextNumber(-4, 4)
			bush(info, parent, on(bx, bz, pos.Y), rng)
		end
	end
	-- Bäume und Kristalle auf den Ausbuchtungen der großen Insel
	for _, lobe in LOBES do
		for _ = 1, 3 do
			local a = rng:NextNumber(0, math.pi * 2)
			local d = rng:NextNumber(0, lobe[3] * 0.55)
			local x, z = lobe[1] + math.cos(a) * d, lobe[2] + math.sin(a) * d
			if rng:NextNumber() < 0.75 then
				anyTree(info, parent, on(x, z, 1), rng:NextNumber(1.2, 1.8), rng)
			else
				crystalCluster(info, parent, on(x, z, 1), rng, rng:NextNumber(1.2, 1.8))
			end
		end
	end
end

-- Wolkenmeer unter der Insel
local function buildCloudSea(info, parent: Instance, rng: Random)
	for _ = 1, 80 do
		local r = rng:NextNumber(35, 80)
		local p = ball(
			info,
			parent,
			"Wolke",
			r * 2,
			Vector3.new(rng:NextNumber(-900, 900), -175 + rng:NextNumber(-15, 15), rng:NextNumber(-700, 700)),
			Color3.fromRGB(250, 245, 255)
		)
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
	end
end

-- Weg ------------------------------------------------------------------------------------
local function streetLamp(info, parent: Instance, x: number, z: number, index: number)
	local part = info.Part
	local y = info.FloorY
	part({
		Name = "Laternenmast",
		Size = Vector3.new(0.8, 13, 0.8),
		CFrame = CFrame.new(x, y + 6.5, z),
		Color = Color3.fromRGB(255, 255, 255),
		Parent = parent,
	})
	-- bunte Ringe am Mast (Zuckerstangen-Look)
	for i = 1, 3 do
		part({
			Name = "Laternenring",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.5, 1.1, 1.1),
			CFrame = CFrame.new(x, y + 2 + i * 3, z) * UPRIGHT,
			Color = Color3.fromRGB(255, 110, 180),
			CanCollide = false,
			Parent = parent,
		})
	end
	local color = LAMP_COLORS[(index % #LAMP_COLORS) + 1]
	local lamp = part({
		Name = "Laterne",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(2.6, 2.6, 2.6),
		CFrame = CFrame.new(x, y + 14.2, z),
		Color = color,
		Material = Enum.Material.Neon,
		Transparency = 0.1,
		CanCollide = false,
		Parent = parent,
	})
	local light = Instance.new("PointLight")
	light.Range = 22
	light.Brightness = 1.5
	light.Color = color
	light.Parent = lamp
end

local function bench(info, parent: Instance, x: number, z: number, color: Color3)
	local part = info.Part
	local y = info.FloorY + 0.2
	local back = if z > 0 then 1 else -1
	part({
		Name = "Bank",
		Size = Vector3.new(6, 0.5, 1.8),
		CFrame = CFrame.new(x, y + 1.6, z),
		Color = color,
		Parent = parent,
	})
	part({
		Name = "Lehne",
		Size = Vector3.new(6, 1.6, 0.4),
		CFrame = CFrame.new(x, y + 2.6, z + back * 0.8),
		Color = color,
		Parent = parent,
	})
	for _, dx in { -2.5, 2.5 } do
		part({
			Name = "Bankbein",
			Size = Vector3.new(0.4, 1.6, 1.6),
			CFrame = CFrame.new(x + dx, y + 0.8, z),
			Color = Color3.fromRGB(255, 255, 255),
			Parent = parent,
		})
	end
end

-- Kristall-Brunnen in der Mitte, oben schwebt ein drehender Kristall
local function fountain(info, parent: Instance)
	local y = info.FloorY
	local rim = Color3.fromRGB(255, 150, 210)
	cylinderUp(info, parent, "Brunnenrand", 15, 2.6, Vector3.new(0, y + 0.3, 0), rim, Enum.Material.SmoothPlastic)
	cylinderUp(info, parent, "Brunnenleuchte", 15.3, 0.4, Vector3.new(0, y + 1.5, 0), Color3.fromRGB(0, 230, 255), Enum.Material.Neon, {
		CanCollide = false,
	})
	cylinderUp(info, parent, "Wasser", 13.5, 0.4, Vector3.new(0, y + 1.3, 0), Color3.fromRGB(40, 200, 255), Enum.Material.Glass, {
		Transparency = 0.2,
		CanCollide = false,
	})
	cylinderUp(info, parent, "Brunnensaeule", 2, 8, Vector3.new(0, y + 4.5, 0), Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic)
	local top = cylinderUp(info, parent, "Brunnenschale", 5.5, 1.2, Vector3.new(0, y + 8.8, 0), rim, Enum.Material.SmoothPlastic)
	local spray = Instance.new("ParticleEmitter")
	spray.Color = ColorSequence.new(Color3.fromRGB(180, 235, 255))
	spray.Size = NumberSequence.new(0.7, 0.2)
	spray.Transparency = NumberSequence.new(0.2, 1)
	spray.Lifetime = NumberRange.new(1.2, 1.6)
	spray.Rate = 70
	spray.Speed = NumberRange.new(11, 15)
	spray.SpreadAngle = Vector2.new(25, 25)
	spray.Acceleration = Vector3.new(0, -25, 0)
	spray.EmissionDirection = Enum.NormalId.Right -- beim gedrehten Zylinder ist "Right" oben
	spray.Parent = top

	local tilt = CFrame.Angles(0, 0, math.rad(45)) * CFrame.Angles(math.rad(45), 0, 0)
	local crystal = info.Part({
		Name = "Brunnenkristall",
		Size = Vector3.new(6, 6, 6),
		CFrame = CFrame.new(0, y + 17, 0) * tilt,
		Color = Color3.fromRGB(190, 90, 255),
		Material = Enum.Material.Neon,
		Transparency = 0.05,
		CanCollide = false,
		Parent = parent,
	})
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(210, 150, 255)
	light.Range = 34
	light.Brightness = 2
	light.Parent = crystal
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkles.Color = ColorSequence.new(Color3.fromRGB(230, 190, 255))
	sparkles.LightEmission = 1
	sparkles.Size = NumberSequence.new(1, 0)
	sparkles.Lifetime = NumberRange.new(1, 2)
	sparkles.Rate = 20
	sparkles.Speed = NumberRange.new(1, 3)
	sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.Parent = crystal
	-- langsam auf und ab schweben und dabei drehen
	TweenService:Create(
		crystal,
		TweenInfo.new(3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ CFrame = CFrame.new(0, y + 19.5, 0) * CFrame.Angles(0, math.rad(180), 0) * tilt }
	):Play()
end

local function buildStreet(info, parent: Instance)
	local part = info.Part
	local y = info.FloorY
	local half = info.StreetHalf
	local length = half * 2 + 20

	-- Bunt gefliester Weg (Schachbrett rosa/hellblau), 40 breit
	local tile = 10
	local count = math.floor(length / tile)
	for i = 0, count - 1 do
		local x = -length / 2 + tile / 2 + i * tile
		for j = 0, 3 do
			part({
				Name = "Wegfliese",
				Size = Vector3.new(tile, 1, tile),
				CFrame = CFrame.new(x, y - 0.7, -20 + tile / 2 + j * tile),
				Color = TILE_COLORS[(i + j) % 2 + 1],
				Parent = parent,
			})
		end
	end
	-- Leuchtkanten links und rechts am Bordstein
	for i, side in { -1, 1 } do
		part({
			Name = "Leuchtkante",
			Size = Vector3.new(length, 0.3, 0.8),
			CFrame = CFrame.new(0, y - 0.05, side * 19.6),
			Color = if i == 1 then Color3.fromRGB(0, 230, 255) else Color3.fromRGB(255, 90, 210),
			Material = Enum.Material.Neon,
			CanCollide = false,
			Parent = parent,
		})
	end
	-- Leuchtende Pfeile Richtung Pack-Shop (nicht im Brunnen)
	for x = -half + 20, half - 20, 40 do
		if math.abs(x) > 20 then
			for k, a in { -35, 35 } do
				part({
					Name = "Pfeil",
					Size = Vector3.new(4, 0.1, 0.9),
					-- zweiter Strich minimal höher, damit die Spitze nicht flackert
					CFrame = CFrame.new(x, y - 0.15 + k * 0.02, 0) * CFrame.Angles(0, math.rad(a), 0) * CFrame.new(-1.6, 0, 0),
					Color = Color3.fromRGB(255, 230, 90),
					Material = Enum.Material.Neon,
					CanCollide = false,
					Parent = parent,
				})
			end
		end
	end

	-- Promenaden mit Bordstein, Laternen und Bänken
	local walkInner = 20
	local walkOuter = Config.Map.StreetWidth / 2
	local walkWidth = walkOuter - walkInner
	local benchColors = { Color3.fromRGB(255, 150, 190), Color3.fromRGB(140, 200, 255), Color3.fromRGB(255, 210, 110) }
	for _, side in { -1, 1 } do
		part({
			Name = "Promenade",
			Size = Vector3.new(length, 1, walkWidth),
			CFrame = CFrame.new(0, y - 0.3, side * (walkInner + walkWidth / 2)),
			Color = Color3.fromRGB(255, 215, 150), -- warmes Sand-Orange, hebt sich vom Weg ab
			Parent = parent,
		})
		part({
			Name = "Bordstein",
			Size = Vector3.new(length, 0.5, 1),
			CFrame = CFrame.new(0, y + 0.35, side * (walkInner + 0.5)),
			Color = Color3.fromRGB(255, 255, 255),
			Parent = parent,
		})
		local index = 0
		for x = -half + 20, half - 20, 40 do
			index += 1
			streetLamp(info, parent, x, side * (walkInner + 3), index)
		end
		local b = 0
		for x = -half + 40, half - 40, 80 do
			b += 1
			bench(info, parent, x, side * (walkOuter - 3), benchColors[(b % #benchColors) + 1])
		end
	end

	-- Wege von den Promenaden zu den Base-Eingängen
	local perRow = math.ceil(Config.Map.BaseCount / 2)
	for col = 1, perRow do
		local x = (col - (perRow + 1) / 2) * Config.Map.BaseSpacing
		for _, side in { -1, 1 } do
			-- endet genau an der Veranda des Hauses und liegt minimal tiefer, damit nichts flackert
			local len = (info.BaseFront or (info.BaseZ - info.BaseSize / 2)) - walkOuter
			part({
				Name = "Eingangsweg",
				Size = Vector3.new(16, 1, len),
				CFrame = CFrame.new(x, y - 0.55, side * (walkOuter + len / 2)),
				Color = Color3.fromRGB(255, 200, 135),
				Parent = parent,
			})
		end
	end

	fountain(info, parent)
end

-- Plätze an den Enden ------------------------------------------------------------------
local function plaza(info, parent: Instance, center: Vector3, radius: number, color: Color3, ringColor: Color3)
	cylinderUp(info, parent, "Platz", radius, 1, Vector3.new(center.X, info.FloorY - 0.45, center.Z), color)
	cylinderUp(info, parent, "Platzrand", radius + 1, 0.6, Vector3.new(center.X, info.FloorY - 0.7, center.Z), ringColor, Enum.Material.Neon, {
		CanCollide = false,
	})
end

local function buildPackShopArea(info, parent: Instance)
	local part = info.Part
	local y = info.FloorY
	local shop = info.PackShop
	plaza(info, parent, shop, 36, Color3.fromRGB(255, 238, 210), Color3.fromRGB(255, 170, 40))

	-- Großer Torbogen über dem Weg
	local archX = info.StreetHalf + 2
	for _, z in { -22, 22 } do
		part({
			Name = "Torsaeule",
			Size = Vector3.new(4, 26, 4),
			CFrame = CFrame.new(archX, y + 13, z),
			Color = Color3.fromRGB(255, 170, 40),
			Parent = parent,
		})
		part({
			Name = "Torkugel",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(5, 5, 5),
			CFrame = CFrame.new(archX, y + 28, z),
			Color = Color3.fromRGB(255, 80, 200),
			Material = Enum.Material.Neon,
			Parent = parent,
		})
	end
	part({
		Name = "Torbalken",
		Size = Vector3.new(4, 4, 48),
		CFrame = CFrame.new(archX, y + 24, 0),
		Color = Color3.fromRGB(255, 170, 40),
		Parent = parent,
	})
	part({
		Name = "Torleuchte",
		Size = Vector3.new(4.2, 0.6, 48.2),
		CFrame = CFrame.new(archX, y + 22, 0),
		Color = Color3.fromRGB(0, 230, 255),
		Material = Enum.Material.Neon,
		Parent = parent,
	})

	-- Fahnen rund um den Platz
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		local pos = shop + Vector3.new(math.cos(a) * 32, 0, math.sin(a) * 32)
		if pos.X > archX + 6 then
			part({
				Name = "Fahnenmast",
				Size = Vector3.new(0.5, 14, 0.5),
				CFrame = CFrame.new(pos + Vector3.new(0, 7, 0)),
				Color = Color3.new(1, 1, 1),
				Parent = parent,
			})
			part({
				Name = "Fahne",
				Size = Vector3.new(0.2, 3, 5),
				CFrame = CFrame.new(pos + Vector3.new(0, 12.5, 2.5)),
				Color = Config.Packs[i % #Config.Packs + 1].Color,
				CanCollide = false,
				Parent = parent,
			})
		end
	end
end

local function buildStatue(info, parent: Instance)
	local part = info.Part
	local pos = info.Statue
	plaza(info, parent, pos, 36, Color3.fromRGB(230, 225, 255), Color3.fromRGB(200, 120, 255))
	local pedestal = part({
		Name = "Sockel",
		Size = Vector3.new(22, 6, 22),
		CFrame = CFrame.new(pos + Vector3.new(0, 3, 0)),
		Color = Color3.fromRGB(245, 240, 255),
		Material = Enum.Material.Marble,
		Parent = parent,
	})
	part({
		Name = "Sockelleuchte",
		Size = Vector3.new(22.4, 0.6, 22.4),
		CFrame = CFrame.new(pos + Vector3.new(0, 6, 0)),
		Color = Color3.fromRGB(200, 120, 255),
		Material = Enum.Material.Neon,
		Parent = parent,
	})
	local def = Config.CreatureById.KosmoKrake
	if def then
		local statue = CreatureModels.Build(def, { Scale = 3.5, Mutation = "Regenbogen" })
		statue.Name = "RiesenStatue"
		statue:PivotTo(CFrame.lookAt(pos + Vector3.new(0, 6.3, 0), pos + Vector3.new(1, 6.3, 0)))
		for _, p in statue:GetDescendants() do
			if p:IsA("BasePart") then
				p.CanCollide = true
			end
		end
		statue.Parent = parent
	end
	local _, labels = info.Billboard(pedestal, UDim2.fromOffset(420, 80), Vector3.new(0, 34, 0), 1, 600)
	labels[1].Text = Config.GameName
	labels[1].TextColor3 = Color3.fromRGB(255, 140, 240)
	-- Scheinwerfer auf die Statue
	for _, z in { -14, 14 } do
		local spot = part({
			Name = "Scheinwerfer",
			Size = Vector3.new(2, 2, 2),
			CFrame = CFrame.lookAt(pos + Vector3.new(16, 1.5, z), pos + Vector3.new(0, 14, 0)),
			Color = Color3.fromRGB(40, 40, 50),
			Parent = parent,
		})
		local light = Instance.new("SpotLight")
		light.Face = Enum.NormalId.Front
		light.Angle = 45
		light.Range = 40
		light.Brightness = 4
		light.Color = Color3.fromRGB(255, 200, 255)
		light.Parent = spot
	end
end

-- Bäume, Büsche, Blumen, Pilze, Kristalle verteilen -----------------------------------------
local function buildNature(info, parent: Instance, rng: Random)
	local half = info.StreetHalf
	local baseZ = info.BaseZ
	local S = info.BaseSize
	local perRow = math.ceil(Config.Map.BaseCount / 2)
	local spacing = Config.Map.BaseSpacing

	local function at(x: number, z: number): Vector3
		return Vector3.new(x, groundY(x, z), z)
	end
	-- Direkt hinter einem Haus wächst nichts (das größte Haus reicht bis etwa 30 Studs hinter die Base-Mitte)
	local function nearHouse(x: number, z: number, margin: number): boolean
		if math.abs(z) - baseZ > 42 + margin then
			return false
		end
		for col = 1, perRow do
			if math.abs(x - (col - (perRow + 1) / 2) * spacing) < 40 + margin then
				return true
			end
		end
		return false
	end
	local function blocked(x: number, z: number, margin: number): boolean
		return inLake(x, z, margin) or onStream(x, z) or nearHouse(x, z, margin)
	end

	-- Zwischen den Bases (Lücken) je ein Baum und Büsche
	for col = 0, perRow do
		local x = (col + 0.5 - (perRow + 1) / 2) * spacing
		for _, side in { -1, 1 } do
			anyTree(info, parent, at(x + rng:NextNumber(-2, 2), side * (baseZ + 6)), rng:NextNumber(0.9, 1.1), rng)
			bush(info, parent, at(x + rng:NextNumber(-3, 3), side * (baseZ - 16)), rng)
			bush(info, parent, at(x + rng:NextNumber(-3, 3), side * (baseZ + 22)), rng)
		end
	end

	-- Wald hinter den Bases (bis zum Inselrand)
	local backStart = baseZ + S / 2 + 8
	local backEnd = BARRIER_Z - 8
	local trees = 0
	local tries = 0
	while trees < 60 and tries < 1000 do
		tries += 1
		local side = if rng:NextNumber() < 0.5 then -1 else 1
		local x, z = rng:NextNumber(-half - 80, half + 80), side * rng:NextNumber(backStart, backEnd)
		if not blocked(x, z, 10) then
			anyTree(info, parent, at(x, z), rng:NextNumber(0.9, 1.6), rng)
			trees += 1
		end
	end

	-- Büsche, Pilze und große Blumen dazwischen
	for _ = 1, 40 do
		local side = if rng:NextNumber() < 0.5 then -1 else 1
		local x, z = rng:NextNumber(-half - 80, half + 80), side * rng:NextNumber(backStart - 4, backEnd)
		if not blocked(x, z, 5) then
			local roll = rng:NextNumber()
			if roll < 0.45 then
				bush(info, parent, at(x, z), rng)
			elseif roll < 0.75 then
				mushroom(info, parent, at(x, z), rng)
			else
				flower(info, parent, at(x, z), rng, true)
			end
		end
	end
	for _ = 1, 90 do
		local side = if rng:NextNumber() < 0.5 then -1 else 1
		local x, z = rng:NextNumber(-half - 80, half + 80), side * rng:NextNumber(backStart - 4, backEnd)
		if not blocked(x, z, 3) then
			flower(info, parent, at(x, z), rng, false)
		end
	end

	-- Bäume, Kristalle und Felsen außen am Inselrand (hinter den unsichtbaren Wänden)
	aroundCore(34, function(x, z)
		local dir = Vector3.new(x, 0, z).Unit
		local pos = Vector3.new(x, 0, z) + dir * rng:NextNumber(25, 45)
		if blocked(pos.X, pos.Z, 12) then
			return
		end
		local ground = at(pos.X, pos.Z)
		local roll = rng:NextNumber()
		if roll < 0.55 then
			anyTree(info, parent, ground, rng:NextNumber(1.1, 1.7), rng)
		elseif roll < 0.75 then
			crystalCluster(info, parent, ground, rng, rng:NextNumber(1, 1.6))
		elseif roll < 0.9 then
			rock(ground, rng)
		else
			bush(info, parent, ground, rng)
		end
	end)

	lakeDecor(info, parent, rng)
end

function World.Build(root: Instance, info)
	local rng = Random.new(42)
	-- Die graue Standard-Baseplate aus der Studio-Vorlage liegt auf Höhe 0 und stört
	-- die Insel. Unser Terrain liegt sowieso unter der ganzen Map.
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate and baseplate:IsA("BasePart") then
		baseplate:Destroy()
	end
	setupLighting()
	buildIsland(info, rng)

	local folder = Instance.new("Folder")
	folder.Name = "Welt"
	folder.Parent = root

	-- Glatte Spielwiese rund um Weg und Bases (liegt etwas über dem Terrain).
	-- Hinten (Wald, Teich) ist der Boden das Terrain selbst.
	info.Part({
		Name = "Wiese",
		Size = Vector3.new(WIESE_HALF_X * 2, 1, WIESE_HALF_Z * 2),
		CFrame = CFrame.new(0, info.FloorY - 1.5, 0),
		Color = Color3.fromRGB(110, 205, 90),
		Material = Enum.Material.Grass,
		Parent = folder,
	})

	buildBarrier(info, folder)
	buildStreet(info, folder)
	buildPackShopArea(info, folder)
	buildStatue(info, folder)
	buildMiniIslandTerrain(rng)

	local sky = Instance.new("Folder")
	sky.Name = "Himmel"
	sky.Parent = folder
	buildCloudSea(info, sky, rng)

	-- Natur kommt einen Moment später: Erst dann kann man die echte Terrain-Höhe messen,
	-- damit Bäume, Blumen und Wasserfall genau auf dem Boden stehen statt drin oder drüber.
	local nature = Instance.new("Folder")
	nature.Name = "Natur"
	nature.Parent = folder
	task.spawn(function()
		local start = os.clock()
		repeat
			task.wait(0.25)
		until terrainY(0, 150, true) ~= nil or os.clock() - start > 6
		buildNature(info, nature, rng)
		decorateMiniIslands(info, nature, rng)
		buildWaterfall(info, nature)
	end)
end

return World
