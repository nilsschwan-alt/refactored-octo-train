-- Die Welt um die Bases herum: Boden, Straße mit Gehwegen und Laternen, Brunnen,
-- Pack-Shop-Platz, Riesen-Statue, Bäume, Felsen, Blumen, Hügel, See und Licht.
-- Alles wird beim Start per Skript gebaut. Zufall mit festem Startwert,
-- damit die Bäume jedes Mal an derselben Stelle stehen.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local CreatureModels = require(script.Parent.CreatureModels)

local World = {}

local LEAF_COLORS = {
	Color3.fromRGB(70, 160, 60),
	Color3.fromRGB(90, 180, 70),
	Color3.fromRGB(50, 140, 70),
	Color3.fromRGB(120, 190, 60),
}
local FLOWER_COLORS = {
	Color3.fromRGB(255, 90, 120),
	Color3.fromRGB(255, 220, 60),
	Color3.fromRGB(180, 110, 255),
	Color3.fromRGB(255, 255, 255),
	Color3.fromRGB(90, 180, 255),
}

-- Licht & Stimmung ------------------------------------------------------------
local function setupLighting()
	Lighting.ClockTime = 14.5
	Lighting.Brightness = 2.5
	Lighting.GlobalShadows = true
	Lighting.OutdoorAmbient = Color3.fromRGB(140, 140, 160)
	Lighting.Ambient = Color3.fromRGB(60, 60, 80)

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

	local atmosphere = effect("Atmosphere", "SpielDunst") :: Atmosphere
	atmosphere.Density = 0.3
	atmosphere.Offset = 0.2
	atmosphere.Haze = 1.2
	atmosphere.Glare = 0.4
	atmosphere.Color = Color3.fromRGB(200, 220, 255)
	atmosphere.Decay = Color3.fromRGB(110, 130, 180)

	local bloom = effect("BloomEffect", "SpielLeuchten") :: BloomEffect
	bloom.Intensity = 0.7
	bloom.Size = 28
	bloom.Threshold = 1.1

	local rays = effect("SunRaysEffect", "SpielSonnenstrahlen") :: SunRaysEffect
	rays.Intensity = 0.08
	rays.Spread = 0.6

	local color = effect("ColorCorrectionEffect", "SpielFarben") :: ColorCorrectionEffect
	color.Saturation = 0.18
	color.Contrast = 0.06
	color.Brightness = 0.02

	local terrain = workspace.Terrain
	local clouds = terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	clouds.Cover = 0.55
	clouds.Density = 0.6
	clouds.Parent = terrain
end

-- See hinter der unteren Reihe: mehrere runde Becken ergeben zusammen eine natürliche Form.
-- Je Eintrag: Versatz X, Versatz Z, Radius
local LAKE_CENTER = Vector3.new(40, 0, -240)
local LAKE_BLOBS = {
	{ 0, 0, 46 },
	{ -52, 8, 34 },
	{ 54, -6, 36 },
	{ 18, 26, 28 },
	{ -22, -24, 28 },
}
local LAKE_WATER_Y = -1 -- Wasseroberfläche (die Wiese liegt bei 0)

-- Liegt ein Punkt im See oder am Ufer? (für Bäume, Felsen, Seerosen)
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

-- Landschaft mit Terrain: Hügel, Berge, See ---------------------------------------
local function buildTerrain(info, rng: Random)
	local terrain = workspace.Terrain
	-- Kräftiges Blau, wenig Spiegelung: sonst spiegelt das Wasser nur den hellen Himmel und wirkt grau
	terrain.WaterColor = Color3.fromRGB(25, 145, 215)
	terrain.WaterTransparency = 0.35
	terrain.WaterWaveSize = 0.2
	terrain.WaterWaveSpeed = 8
	terrain.WaterReflectance = 0.25

	-- Flache Wiese überall (Oberkante y = 0, unter dem Spielbereich)
	terrain:FillBlock(CFrame.new(0, -3, 0), Vector3.new(1400, 6, 1100), Enum.Material.Grass)

	-- Unter Straße, Gehwegen, Bases und Plätzen kein Terrain-Gras: dessen Halme wachsen
	-- sonst durch die Bauteile durch. "Ground" hat keine Halme und liegt unsichtbar darunter.
	local hardX = info.StreetHalf + 76
	local hardZ = info.BaseZ + info.BaseSize / 2 + 6
	terrain:FillBlock(CFrame.new(0, -3, 0), Vector3.new(hardX * 2, 6, hardZ * 2), Enum.Material.Ground)

	-- See: erst Sandufer, dann ausheben, Sandboden, Wasser rein
	for _, blob in LAKE_BLOBS do
		local center = LAKE_CENTER + Vector3.new(blob[1], 0, blob[2])
		terrain:FillCylinder(CFrame.new(center + Vector3.new(0, -3, 0)), 6, blob[3] + 9, Enum.Material.Sand)
	end
	for _, blob in LAKE_BLOBS do
		local center = LAKE_CENTER + Vector3.new(blob[1], 0, blob[2])
		terrain:FillCylinder(CFrame.new(center + Vector3.new(0, -5, 0)), 10, blob[3], Enum.Material.Air)
	end
	for _, blob in LAKE_BLOBS do
		local center = LAKE_CENTER + Vector3.new(blob[1], 0, blob[2])
		terrain:FillCylinder(CFrame.new(center + Vector3.new(0, -10, 0)), 4, blob[3], Enum.Material.Sand)
		terrain:FillCylinder(CFrame.new(center + Vector3.new(0, (LAKE_WATER_Y - 8) / 2, 0)), 8 + LAKE_WATER_Y, blob[3], Enum.Material.Water)
	end

	-- Hügel im Kreis um die Map
	for i = 0, 31 do
		local a = i / 32 * math.pi * 2
		local x = math.cos(a) * 430
		local z = math.sin(a) * 310
		local nearLake = z < 0 and math.abs(x - 40) < 170
		if not nearLake then
			local r = rng:NextNumber(55, 95)
			terrain:FillBall(Vector3.new(x, -r * 0.55, z), r, Enum.Material.Grass)
		end
	end
	-- Berge ganz hinten
	for i = 0, 15 do
		local a = i / 16 * math.pi * 2 + 0.2
		local pos = Vector3.new(math.cos(a) * 620, -40, math.sin(a) * 480)
		local r = rng:NextNumber(110, 160)
		terrain:FillBall(pos, r, Enum.Material.Rock)
		terrain:FillBall(pos + Vector3.new(0, r * 0.85, 0), r * 0.28, Enum.Material.Snow)
	end
end

-- Natur ---------------------------------------------------------------------------
local function tree(info, parent: Instance, pos: Vector3, scale: number, rng: Random)
	local part = info.Part
	local trunkHeight = 9 * scale
	part({
		Name = "Stamm",
		Size = Vector3.new(1.6 * scale, trunkHeight, 1.6 * scale),
		CFrame = CFrame.new(pos + Vector3.new(0, trunkHeight / 2, 0)),
		Color = Color3.fromRGB(110, 75, 45),
		Material = Enum.Material.Wood,
		Parent = parent,
	})
	local leafColor = LEAF_COLORS[rng:NextInteger(1, #LEAF_COLORS)]
	for i = 1, 3 do
		local size = (8 - i * 1.5) * scale
		part({
			Name = "Blaetter",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(size, size, size),
			CFrame = CFrame.new(pos + Vector3.new(rng:NextNumber(-1, 1) * scale, trunkHeight + (i - 1) * 3 * scale, rng:NextNumber(-1, 1) * scale)),
			Color = leafColor,
			Material = Enum.Material.Grass,
			Parent = parent,
		})
	end
end

-- Felsbrocken aus Terrain: 1-3 runde Steine, halb im Boden. Sieht natürlicher aus als flache Platten.
local function rock(pos: Vector3, rng: Random)
	local terrain = workspace.Terrain
	for i = 1, rng:NextInteger(1, 3) do
		local r = rng:NextNumber(3, 5.5) / i
		local offset = if i == 1 then Vector3.zero else Vector3.new(rng:NextNumber(-5, 5), 0, rng:NextNumber(-5, 5))
		terrain:FillBall(pos + offset + Vector3.new(0, -r * 0.35, 0), math.max(r, 2.5), Enum.Material.Rock)
	end
end

-- Seerosen und Schilf, damit man sofort sieht: das ist Wasser
local function lakeDecor(info, parent: Instance, rng: Random)
	local part = info.Part
	local padColors = { Color3.fromRGB(70, 165, 70), Color3.fromRGB(95, 185, 80) }
	local placed = 0
	for _ = 1, 400 do
		if placed >= 28 then
			break
		end
		local x = LAKE_CENTER.X + rng:NextNumber(-100, 100)
		local z = LAKE_CENTER.Z + rng:NextNumber(-60, 60)
		if inLake(x, z, -8) then
			local size = rng:NextNumber(3, 5)
			local pad = part({
				Name = "Seerose",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.2, size, size),
				CFrame = CFrame.new(x, LAKE_WATER_Y + 0.1, z) * CFrame.Angles(0, rng:NextNumber(0, 6), math.rad(90)),
				Color = padColors[rng:NextInteger(1, #padColors)],
				CanCollide = false,
				Parent = parent,
			})
			if rng:NextNumber() < 0.35 then
				part({
					Name = "Bluete",
					Shape = Enum.PartType.Ball,
					Size = Vector3.new(1.2, 1.2, 1.2),
					CFrame = pad.CFrame * CFrame.new(0.5, 0, 0),
					Color = Color3.fromRGB(255, 150, 200),
					CanCollide = false,
					Parent = parent,
				})
			end
			placed += 1
		end
	end
	-- Schilf am Ufer
	for _, blob in LAKE_BLOBS do
		for _ = 1, 6 do
			local a = rng:NextNumber(0, math.pi * 2)
			local dist = blob[3] - rng:NextNumber(1, 3)
			local x = LAKE_CENTER.X + blob[1] + math.cos(a) * dist
			local z = LAKE_CENTER.Z + blob[2] + math.sin(a) * dist
			-- nur am Rand, nicht mitten im See (wenn ein anderes Becken hier schon tief ist)
			if inLake(x, z, -5) then
				continue
			end
			for i = 1, 4 do
				local h = rng:NextNumber(4, 7)
				part({
					Name = "Schilf",
					Size = Vector3.new(0.3, h, 0.3),
					CFrame = CFrame.new(x + rng:NextNumber(-1, 1), LAKE_WATER_Y - 0.5 + h / 2, z + rng:NextNumber(-1, 1))
						* CFrame.Angles(rng:NextNumber(-0.15, 0.15), 0, rng:NextNumber(-0.15, 0.15)),
					Color = if i == 1 then Color3.fromRGB(150, 110, 60) else Color3.fromRGB(90, 150, 60),
					CanCollide = false,
					Parent = parent,
				})
			end
		end
	end
end

local function flower(info, parent: Instance, pos: Vector3, rng: Random)
	info.Part({
		Name = "Stiel",
		Size = Vector3.new(0.2, 1, 0.2),
		CFrame = CFrame.new(pos + Vector3.new(0, 0.5, 0)),
		Color = Color3.fromRGB(60, 140, 50),
		CanCollide = false,
		Parent = parent,
	})
	info.Part({
		Name = "Bluete",
		Size = Vector3.new(0.8, 0.4, 0.8),
		CFrame = CFrame.new(pos + Vector3.new(0, 1.1, 0)),
		Color = FLOWER_COLORS[rng:NextInteger(1, #FLOWER_COLORS)],
		CanCollide = false,
		Parent = parent,
	})
end

-- Straße ---------------------------------------------------------------------------
local function streetLamp(info, parent: Instance, x: number, z: number)
	local part = info.Part
	local y = info.FloorY
	local side = if z > 0 then -1 else 1 -- Lampe hängt zur Fahrbahn
	part({
		Name = "Laternenmast",
		Size = Vector3.new(0.8, 16, 0.8),
		CFrame = CFrame.new(x, y + 8, z),
		Color = Color3.fromRGB(40, 40, 50),
		Material = Enum.Material.Metal,
		Parent = parent,
	})
	part({
		Name = "Laternenarm",
		Size = Vector3.new(0.5, 0.5, 4),
		CFrame = CFrame.new(x, y + 15.8, z + side * 2),
		Color = Color3.fromRGB(40, 40, 50),
		Material = Enum.Material.Metal,
		Parent = parent,
	})
	local lamp = part({
		Name = "Laterne",
		Size = Vector3.new(1.6, 0.8, 2),
		CFrame = CFrame.new(x, y + 15.2, z + side * 3.6),
		Color = Color3.fromRGB(255, 230, 160),
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = parent,
	})
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Bottom
	light.Angle = 100
	light.Range = 30
	light.Brightness = 3
	light.Color = Color3.fromRGB(255, 220, 150)
	light.Parent = lamp
end

local function bench(info, parent: Instance, x: number, z: number)
	local part = info.Part
	local y = info.FloorY + 0.2
	local back = if z > 0 then 1 else -1
	part({
		Name = "Bank",
		Size = Vector3.new(6, 0.4, 1.8),
		CFrame = CFrame.new(x, y + 1.6, z),
		Color = Color3.fromRGB(150, 95, 55),
		Material = Enum.Material.WoodPlanks,
		Parent = parent,
	})
	part({
		Name = "Lehne",
		Size = Vector3.new(6, 1.6, 0.3),
		CFrame = CFrame.new(x, y + 2.6, z + back * 0.8),
		Color = Color3.fromRGB(150, 95, 55),
		Material = Enum.Material.WoodPlanks,
		Parent = parent,
	})
	for _, dx in { -2.5, 2.5 } do
		part({
			Name = "Bankbein",
			Size = Vector3.new(0.4, 1.6, 1.6),
			CFrame = CFrame.new(x + dx, y + 0.8, z),
			Color = Color3.fromRGB(40, 40, 50),
			Material = Enum.Material.Metal,
			Parent = parent,
		})
	end
end

local function fountain(info, parent: Instance)
	local part = info.Part
	local y = info.FloorY
	local function cylinder(name: string, radius: number, height: number, yCenter: number, color: Color3, material, props)
		local p = part({
			Name = name,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(height, radius * 2, radius * 2),
			CFrame = CFrame.new(0, yCenter, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Color = color,
			Material = material,
			Parent = parent,
		})
		if props then
			for k, v in props do
				(p :: any)[k] = v
			end
		end
		return p
	end
	cylinder("Brunnenrand", 13, 2.4, y + 0.2, Color3.fromRGB(220, 215, 200), Enum.Material.Marble)
	cylinder("Wasser", 11.5, 0.4, y + 1.1, Color3.fromRGB(60, 170, 230), Enum.Material.Glass,
		{ Transparency = 0.25, CanCollide = false })
	part({
		Name = "Brunnensaeule",
		Size = Vector3.new(3, 7, 3),
		CFrame = CFrame.new(0, y + 4, 0),
		Color = Color3.fromRGB(220, 215, 200),
		Material = Enum.Material.Marble,
		Parent = parent,
	})
	local top = cylinder("Brunnenschale", 4.5, 1, y + 7.8, Color3.fromRGB(220, 215, 200), Enum.Material.Marble)
	local spray = Instance.new("ParticleEmitter")
	spray.Color = ColorSequence.new(Color3.fromRGB(180, 230, 255))
	spray.Size = NumberSequence.new(0.6, 0.2)
	spray.Transparency = NumberSequence.new(0.2, 1)
	spray.Lifetime = NumberRange.new(1.2, 1.6)
	spray.Rate = 80
	spray.Speed = NumberRange.new(12, 16)
	spray.SpreadAngle = Vector2.new(15, 15)
	spray.Acceleration = Vector3.new(0, -25, 0)
	spray.EmissionDirection = Enum.NormalId.Right -- beim gedrehten Zylinder ist "Right" oben
	spray.Parent = top
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(120, 200, 255)
	light.Range = 25
	light.Brightness = 1.5
	light.Parent = top
end

local function buildStreet(info, parent: Instance)
	local part = info.Part
	local y = info.FloorY
	local half = info.StreetHalf
	local length = half * 2 + 20

	-- Fahrbahn
	part({
		Name = "Fahrbahn",
		Size = Vector3.new(length, 1, 40),
		CFrame = CFrame.new(0, y - 0.7, 0),
		Color = Color3.fromRGB(55, 55, 62),
		Material = Enum.Material.Asphalt,
		Parent = parent,
	})
	-- Mittelstreifen (gestrichelt), nicht im Brunnen
	for x = -half, half, 12 do
		if math.abs(x) > 16 then
			for _, z in { -10, 10 } do
				part({
					Name = "Markierung",
					Size = Vector3.new(6, 0.05, 0.6),
					CFrame = CFrame.new(x, y - 0.17, z),
					Color = Color3.fromRGB(240, 240, 240),
					CanCollide = false,
					Parent = parent,
				})
			end
		end
	end
	-- Gehwege mit Bordstein
	local walkInner = 20
	local walkOuter = Config.Map.StreetWidth / 2
	local walkWidth = walkOuter - walkInner
	for _, side in { -1, 1 } do
		part({
			Name = "Gehweg",
			Size = Vector3.new(length, 1, walkWidth),
			CFrame = CFrame.new(0, y - 0.3, side * (walkInner + walkWidth / 2)),
			Color = Color3.fromRGB(190, 185, 180),
			Material = Enum.Material.Concrete,
			Parent = parent,
		})
		part({
			Name = "Bordstein",
			Size = Vector3.new(length, 0.5, 1),
			CFrame = CFrame.new(0, y + 0.35, side * (walkInner + 0.5)),
			Color = Color3.fromRGB(230, 230, 230),
			Material = Enum.Material.Concrete,
			Parent = parent,
		})
		for x = -half + 20, half - 20, 40 do
			streetLamp(info, parent, x, side * (walkInner + 3))
		end
		for x = -half + 40, half - 40, 80 do
			bench(info, parent, x, side * (walkOuter - 3))
		end
	end

	-- Wege von den Gehwegen zu den Base-Eingängen
	local perRow = math.ceil(Config.Map.BaseCount / 2)
	for col = 1, perRow do
		local x = (col - (perRow + 1) / 2) * Config.Map.BaseSpacing
		for _, side in { -1, 1 } do
			part({
				Name = "Eingangsweg",
				Size = Vector3.new(16, 1, info.BaseZ - info.BaseSize / 2 - walkOuter + 1),
				CFrame = CFrame.new(x, y - 0.5, side * (walkOuter + (info.BaseZ - info.BaseSize / 2 - walkOuter) / 2)),
				Color = Color3.fromRGB(160, 150, 140),
				Material = Enum.Material.Slate,
				Parent = parent,
			})
		end
	end

	fountain(info, parent)
end

-- Plätze an den Enden ------------------------------------------------------------
local function plaza(info, parent: Instance, center: Vector3, radius: number, color: Color3)
	info.Part({
		Name = "Platz",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1, radius * 2, radius * 2),
		CFrame = CFrame.new(center.X, info.FloorY - 0.45, center.Z) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Material = Enum.Material.Pebble,
		Parent = parent,
	})
end

local function buildPackShopArea(info, parent: Instance)
	local part = info.Part
	local y = info.FloorY
	local shop = info.PackShop
	plaza(info, parent, shop, 36, Color3.fromRGB(235, 225, 200))

	-- Großer Torbogen über der Straße
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
	local beam = part({
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
	local _, labels = info.Billboard(beam, UDim2.fromOffset(360, 70), Vector3.new(0, 6, 0), 1, 500)
	labels[1].Text = "✨ PACK-SHOP ✨"
	labels[1].TextColor3 = Color3.fromRGB(255, 220, 60)

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
	plaza(info, parent, pos, 36, Color3.fromRGB(210, 210, 225))
	local pedestal = part({
		Name = "Sockel",
		Size = Vector3.new(22, 6, 22),
		CFrame = CFrame.new(pos + Vector3.new(0, 3, 0)),
		Color = Color3.fromRGB(235, 235, 245),
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

-- Bäume, Felsen, Blumen verteilen ---------------------------------------------------
local function buildNature(info, parent: Instance, rng: Random)
	local y = info.FloorY - 1 -- Oberkante der Wiese
	local half = info.StreetHalf
	local baseZ = info.BaseZ
	local S = info.BaseSize
	local perRow = math.ceil(Config.Map.BaseCount / 2)
	local spacing = Config.Map.BaseSpacing

	-- Zwischen den Bases (Lücken) je zwei Bäume
	for col = 0, perRow do
		local x = (col + 0.5 - (perRow + 1) / 2) * spacing
		for _, side in { -1, 1 } do
			for _, dz in { -14, 14 } do
				tree(info, parent, Vector3.new(x + rng:NextNumber(-2, 2), y, side * (baseZ + dz)), rng:NextNumber(0.8, 1.1), rng)
			end
		end
	end

	-- Wald hinter den Bases
	local backStart = baseZ + S / 2 + 8
	for _ = 1, 70 do
		local side = if rng:NextNumber() < 0.5 then -1 else 1
		local pos = Vector3.new(rng:NextNumber(-half - 70, half + 70), y, side * rng:NextNumber(backStart, 158))
		tree(info, parent, pos, rng:NextNumber(0.9, 1.6), rng)
	end

	-- Bäume draußen auf der Wiese bis zu den Hügeln
	local placed = 0
	while placed < 70 do
		local pos = Vector3.new(rng:NextNumber(-380, 380), 0, rng:NextNumber(-280, 280))
		local inPlayArea = math.abs(pos.X) < 285 and math.abs(pos.Z) < 165
		if not inPlayArea and not inLake(pos.X, pos.Z, 14) then
			tree(info, parent, pos, rng:NextNumber(1, 2), rng)
			placed += 1
		end
	end

	-- Felsen (draußen auf der Wiese, nicht im See)
	local rocks = 0
	while rocks < 28 do
		local side = if rng:NextNumber() < 0.5 then -1 else 1
		local pos = Vector3.new(rng:NextNumber(-360, 360), 0, side * rng:NextNumber(172, 270))
		if not inLake(pos.X, pos.Z, 12) then
			rock(pos, rng)
			rocks += 1
		end
	end

	-- Seerosen und Schilf
	lakeDecor(info, parent, rng)

	-- Blumen hinter den Bases und zwischen den Bäumen
	for _ = 1, 90 do
		local side = if rng:NextNumber() < 0.5 then -1 else 1
		local pos = Vector3.new(rng:NextNumber(-half - 60, half + 60), y, side * rng:NextNumber(backStart - 4, 158))
		flower(info, parent, pos, rng)
	end
end

function World.Build(root: Instance, info)
	local rng = Random.new(42)
	-- Die graue Standard-Baseplate aus der Studio-Vorlage liegt auf Höhe 0 und schneidet
	-- sonst mitten durch den See. Unser Terrain liegt sowieso unter der ganzen Map.
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate and baseplate:IsA("BasePart") then
		baseplate:Destroy()
	end
	setupLighting()
	buildTerrain(info, rng)

	local folder = Instance.new("Folder")
	folder.Name = "Welt"
	folder.Parent = root

	-- Spielwiese (liegt etwas über dem Terrain, damit der Boden schön glatt ist)
	info.Part({
		Name = "Wiese",
		Size = Vector3.new(info.StreetHalf * 2 + 180, 1, 330),
		CFrame = CFrame.new(0, info.FloorY - 1.5, 0),
		Color = Color3.fromRGB(95, 175, 75),
		Material = Enum.Material.Grass,
		Parent = folder,
	})

	buildStreet(info, folder)
	buildPackShopArea(info, folder)
	buildStatue(info, folder)

	local nature = Instance.new("Folder")
	nature.Name = "Natur"
	nature.Parent = folder
	buildNature(info, nature, rng)
end

return World
