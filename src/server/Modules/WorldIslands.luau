-- Baut die vier Welten als schwebende Inseln aus Blöcken (ganz ohne Terrain) und die Portale.
-- Jede Insel: runder Boden, unsichtbare Wand am Rand, Ankunftsplatz mit Rück-Portal im Süden
-- und ein großes Wahrzeichen. Islands.Build() gibt zurück, wo man ankommt und wo Münzen
-- und wilde Monster auftauchen dürfen.
-- Was man in den Welten TUT (Münzen, Monster, Freischalten), steht in Worlds.luau und Config.luau.

local CollectionService = game:GetService("CollectionService")

local Islands = {}

local M = Enum.Material
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90)) -- dreht Zylinder so, dass sie stehen
-- dreht einen Würfel so, dass er auf einer Ecke steht (Spitze für Kristalle)
local TIP = CFrame.Angles(0, math.rad(45), 0) * CFrame.Angles(0, 0, math.rad(35.264)) * CFrame.Angles(math.rad(45), 0, 0)
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local RADIUS = 105 -- Radius jeder Welt-Insel

local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"
local FADE = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.2, 0),
	NumberSequenceKeypoint.new(0.8, 0),
	NumberSequenceKeypoint.new(1, 1),
})

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

-- Bausteine -----------------------------------------------------------------------------
-- ctx = { Folder, Origin (CFrame: Inselmitte, Oberkante Boden), Rng, Blockers, Keep }
-- Alle Koordinaten sind Abstände von der Inselmitte, y = 0 ist der Boden.

-- extra: beliebige Eigenschaften, dazu Ghost = true (man läuft durch) oder
-- Glow = true (durchlaufen und kein Schatten), Rot = Drehung um den Mittelpunkt
local function finish(p: Part, parent: Instance, extra: { [string]: any }?): Part
	if extra then
		for k, v in extra do
			if k == "Ghost" or k == "Glow" then
				p.CanCollide = false
				p.CanQuery = false
				p.CanTouch = false
				if k == "Glow" then
					p.CastShadow = false
				end
			elseif k ~= "Rot" then
				(p :: any)[k] = v
			end
		end
	end
	p.Parent = parent
	return p
end

local function newPart(name: string, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Color = color
	p.Material = material or M.SmoothPlastic
	return p
end

-- Block an beliebiger Stelle und Drehung (cf = Lage relativ zur Inselmitte)
local function put(ctx, name: string, cf: CFrame, size: Vector3, color: Color3, material: Enum.Material?, extra: { [string]: any }?): Part
	local p = newPart(name, color, material)
	p.Size = size
	p.CFrame = ctx.Origin * cf
	return finish(p, ctx.Folder, extra)
end

-- Block mit Mittelpunkt (x, y, z)
local function block(ctx, name: string, x: number, y: number, z: number, sx: number, sy: number, sz: number, color: Color3, material: Enum.Material?, extra: { [string]: any }?): Part
	local rot = if extra and extra.Rot then extra.Rot else CFrame.identity
	return put(ctx, name, CFrame.new(x, y, z) * rot, Vector3.new(sx, sy, sz), color, material, extra)
end

-- Stehender Zylinder: Unterkante y0, darüber "height" hoch
local function cyl(ctx, name: string, x: number, y0: number, z: number, radius: number, height: number, color: Color3, material: Enum.Material?, extra: { [string]: any }?): Part
	local p = newPart(name, color, material)
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(height, radius * 2, radius * 2)
	local rot = if extra and extra.Rot then extra.Rot else CFrame.identity
	p.CFrame = ctx.Origin * CFrame.new(x, y0 + height / 2, z) * rot * UPRIGHT
	return finish(p, ctx.Folder, extra)
end

local function ball(ctx, name: string, x: number, y: number, z: number, diameter: number, color: Color3, material: Enum.Material?, extra: { [string]: any }?): Part
	local p = newPart(name, color, material)
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.new(diameter, diameter, diameter)
	p.CFrame = ctx.Origin * CFrame.new(x, y, z)
	return finish(p, ctx.Folder, extra)
end

local function light(p: Instance, color: Color3, range: number, brightness: number?)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness or 1
	l.Shadows = false
	l.Parent = p
end

local function emitter(p: Instance, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Parent = p
	return e
end

local function rn(ctx, a: number, b: number): number
	return ctx.Rng:NextNumber(a, b)
end

local function pick(ctx, list)
	return list[ctx.Rng:NextInteger(1, #list)]
end

-- Dreht so, dass die eigene +Z-Achse in Richtung "deg" zeigt (0° = +X, 90° = +Z)
local function facing(deg: number): CFrame
	return CFrame.Angles(0, math.rad(90 - deg), 0)
end

-- Sperrflächen: Blockers = hier steht etwas Festes (keine Münzen, keine Deko),
-- Keep = hier soll keine Deko hin (Wege, Plätze, Teiche), Münzen aber schon.
local function inAny(list, x: number, z: number, margin: number): boolean
	for _, b in list do
		local dx, dz = x - b[1], z - b[2]
		local r = b[3] + margin
		if dx * dx + dz * dz < r * r then
			return true
		end
	end
	return false
end

local function blocker(ctx, x: number, z: number, r: number)
	table.insert(ctx.Blockers, { x, z, r })
end

local function keep(ctx, x: number, z: number, r: number)
	table.insert(ctx.Keep, { x, z, r })
end

-- Ruft fn(x, z) an "count" freien Stellen zwischen minR und maxR auf.
-- clear = Platz, den ein Ding braucht. solid = true: danach für Münzen und Deko gesperrt,
-- false: nur für andere Deko gesperrt, nil: gar nicht gemerkt (Kleinkram wie Risse und Sprenkel).
local function scatter(ctx, count: number, minR: number, maxR: number, clear: number, solid: boolean?, fn: (number, number) -> ())
	local placed = 0
	for _ = 1, count * 14 do
		if placed >= count then
			break
		end
		local a = rn(ctx, 0, math.pi * 2)
		local r = math.sqrt(rn(ctx, minR * minR, maxR * maxR))
		local x, z = math.cos(a) * r, math.sin(a) * r
		if not inAny(ctx.Blockers, x, z, clear) and not inAny(ctx.Keep, x, z, clear) then
			placed += 1
			if solid then
				blocker(ctx, x, z, clear)
			elseif solid == false then
				keep(ctx, x, z, clear * 0.6)
			end
			fn(x, z)
		end
	end
end

-- Runder Inselboden mit Fels darunter und unsichtbarer Wand am Rand
local function ground(ctx, style)
	local R = ctx.R
	cyl(ctx, "Boden", 0, -6, 0, R, 6, style.Top, style.TopMat)
	cyl(ctx, "Bodenrand", 0, -3.4, 0, R + 1.6, 2.6, style.Rim, M.SmoothPlastic, { Ghost = true })
	local y = -6
	for i, f in { 0.92, 0.78, 0.6, 0.42, 0.24 } do
		local h = 10 + i * 2
		cyl(ctx, "Fels", rn(ctx, -3, 3), y - h, rn(ctx, -3, 3), R * f, h, style.Rock:Lerp(BLACK, i * 0.07), style.RockMat or M.Slate, { Glow = true })
		y -= h
	end
	local n = 32
	local width = 2 * R * math.tan(math.pi / n) + 1.5
	for i = 1, n do
		local a = i / n * math.pi * 2
		local pos = Vector3.new(math.cos(a) * (R - 1), 34, math.sin(a) * (R - 1))
		put(ctx, "Inselrand", CFrame.lookAt(pos, Vector3.new(0, 34, 0)), Vector3.new(width, 80, 2), WHITE, nil, {
			Transparency = 1,
			CanQuery = false,
			CastShadow = false,
		})
	end
end

-- Runder Platz, flach auf dem Boden, mit Leuchtring
local function plaza(ctx, x: number, z: number, radius: number, color: Color3, ringColor: Color3, material: Enum.Material?)
	cyl(ctx, "Platzrand", x, -0.42, z, radius + 0.9, 0.5, ringColor, M.Neon, { Glow = true })
	cyl(ctx, "Platz", x, -0.35, z, radius, 0.5, color, material, { Ghost = true })
	keep(ctx, x, z, radius + 1)
end

-- Gerader Weg, flach auf dem Boden
local function pathLine(ctx, x0: number, z0: number, x1: number, z1: number, width: number, color: Color3, material: Enum.Material?, lift: number?, name: string?, extra: { [string]: any }?): Part
	local a, b = Vector3.new(x0, 0, z0), Vector3.new(x1, 0, z1)
	local length = (b - a).Magnitude
	local top = lift or 0.12
	local mid = (a + b) / 2 + Vector3.new(0, top - 0.15, 0)
	local p = put(ctx, name or "Weg", CFrame.lookAt(mid, mid + (b - a)), Vector3.new(width, 0.3, length), color, material, extra or { Ghost = true })
	for i = 0, math.ceil(length / 5) do
		local point = a:Lerp(b, math.min(1, i * 5 / length))
		keep(ctx, point.X, point.Z, width / 2 + 1)
	end
	return p
end

-- Ruft fn(x, z, winkelGrad, i) für Punkte rund um den Inselrand auf (nicht am Rück-Portal)
local function rim(ctx, count: number, fn: (number, number, number, number) -> ())
	for i = 1, count do
		local a = (i + rn(ctx, -0.25, 0.25)) / count * math.pi * 2
		local r = ctx.R - 4.5
		local x, z = math.cos(a) * r, math.sin(a) * r
		if not (math.abs(x) < 16 and z > 70) and not inAny(ctx.Keep, x, z, 2) then
			fn(x, z, math.deg(a), i)
		end
	end
end

-- Kleine schwebende Inselchen rund um die große. fn(sub, radius, i) schmückt sie
-- (sub ist ein eigener ctx, dessen Mitte oben auf dem Inselchen liegt).
local function islets(ctx, list, style, fn)
	for i, info in list do
		local a = math.rad(info[1])
		local sub = {
			Folder = ctx.Folder,
			Origin = ctx.Origin * CFrame.new(math.cos(a) * info[2], info[3], math.sin(a) * info[2]),
			Rng = ctx.Rng,
			Blockers = {},
			Keep = {},
		}
		local r = info[4]
		cyl(sub, "Inselchen", 0, -2.5, 0, r, 2.5, style.Top, style.TopMat, { Ghost = true })
		cyl(sub, "Inselchen", 0, -7, 0, r * 0.78, 4.5, style.Rock, style.RockMat or M.Slate, { Glow = true })
		cyl(sub, "Inselchen", 0, -12, 0, r * 0.5, 5, style.Rock:Lerp(BLACK, 0.15), style.RockMat or M.Slate, { Glow = true })
		cyl(sub, "Inselchen", 0, -17, 0, r * 0.24, 5, style.Rock:Lerp(BLACK, 0.3), style.RockMat or M.Slate, { Glow = true })
		fn(sub, r, i)
	end
end

-- Felsnadel unter jedem Inselchen (eigener Schritt, weil crystal() erst weiter unten steht)
local function isletSpikes(ctx, list, style)
	for _, info in list do
		local a = math.rad(info[1])
		local r = info[4]
		local x, z = math.cos(a) * info[2], math.sin(a) * info[2]
		for _, o in { { 0, 0, 1 }, { 0.45, 0.2, 0.6 }, { -0.4, -0.3, 0.5 } } do
			put(ctx, "Inselchen", CFrame.new(x + o[1] * r, info[3] - 16 - r * o[3] * 0.5, z + o[2] * r) * CFrame.Angles(0, math.rad(45), 0), Vector3.new(r * 0.32 * o[3], r * o[3], r * 0.32 * o[3]), style.Rock:Lerp(BLACK, 0.35), style.RockMat or M.Slate, { Glow = true })
			put(ctx, "Inselchen", CFrame.new(x + o[1] * r, info[3] - 16 - r * o[3], z + o[2] * r) * TIP, Vector3.one * (r * 0.32 * o[3] * 0.98), style.Rock:Lerp(BLACK, 0.4), style.RockMat or M.Slate, { Glow = true })
		end
	end
end

-- Kristall mit Spitze. tilt = Neigung in Grad, lean = Richtung, in die er sich neigt (Grad).
-- Ohne "extra" leuchtet er und man läuft durch.
local function crystal(ctx, x: number, y: number, z: number, height: number, width: number, color: Color3, tilt: number?, lean: number?, extra: { [string]: any }?): Part
	local base = CFrame.new(x, y, z) * facing(lean or 0) * CFrame.Angles(math.rad(tilt or 0), 0, 0)
	local props = extra or { Glow = true, Transparency = 0.12 }
	local shaft = put(ctx, "Kristall", base * CFrame.new(0, height / 2, 0) * CFrame.Angles(0, math.rad(45), 0), Vector3.new(width, height, width), color, M.Neon, props)
	local side = width * 0.98
	put(ctx, "Kristallspitze", base * CFrame.new(0, height, 0) * TIP, Vector3.new(side, side, side), color:Lerp(WHITE, 0.25), M.Neon, props)
	return shaft
end

-- Kristall-Gruppe: ein großer in der Mitte, zwei bis drei schräge daneben
local function crystalCluster(ctx, x: number, z: number, height: number, color: Color3, extra: { [string]: any }?)
	local main = crystal(ctx, x, -0.3, z, height, height * 0.2, color, 0, rn(ctx, 0, 90), extra)
	for _ = 1, ctx.Rng:NextInteger(2, 3) do
		local a = rn(ctx, 0, 360)
		local h = height * rn(ctx, 0.4, 0.7)
		local d = height * 0.15
		crystal(ctx, x + math.cos(math.rad(a)) * d, -0.8, z + math.sin(math.rad(a)) * d, h, h * 0.2, color:Lerp(WHITE, 0.15), rn(ctx, 18, 32), a, extra)
	end
	return main
end

-- Hängende Felsnadeln unter der Insel und unter den Inselchen (sonst sieht die Unterseite
-- wie eine Torte aus). glow = Farbe für ein paar leuchtende dazwischen (oder nil)
local function hangingSpikes(ctx, style, glow: Color3?)
	local R = ctx.R
	local rock = { Glow = true, Material = style.RockMat or M.Slate }
	-- Ringe: { innen, außen, Höhe der Unterkante dort, Anzahl }
	for _, ring in { { 0.94, 0.99, -6, 16 }, { 0.8, 0.9, -18, 12 }, { 0.62, 0.76, -32, 9 }, { 0.44, 0.58, -48, 7 } } do
		for i = 1, ring[4] do
			local a = (i + rn(ctx, -0.3, 0.3)) / ring[4] * math.pi * 2
			local r = R * rn(ctx, ring[1], ring[2])
			local length = rn(ctx, 9, 22)
			local shiny = glow and i % 4 == 0
			crystal(ctx, math.cos(a) * r, ring[3] + 1, math.sin(a) * r, length, length * rn(ctx, 0.2, 0.3), if shiny then glow :: Color3 else style.Rock:Lerp(BLACK, rn(ctx, 0, 0.25)), 180 + rn(ctx, -8, 8), rn(ctx, 0, 360), if shiny then nil else rock)
		end
	end
end

-- Felsen am Inselrand: abwechselnd Brocken und spitze Nadeln
local function rimRock(ctx, x: number, z: number, i: number, color: Color3, material: Enum.Material?)
	if i % 3 == 1 then
		local solid = { Material = material or M.Slate }
		crystal(ctx, x, -1.5, z, rn(ctx, 10, 17), rn(ctx, 4, 5.5), color, rn(ctx, 0, 7), rn(ctx, 0, 360), solid)
		local a = rn(ctx, 0, 360)
		crystal(ctx, x + math.cos(math.rad(a)) * 3, -1.8, z + math.sin(math.rad(a)) * 3, rn(ctx, 5, 9), rn(ctx, 2.6, 3.6), color:Lerp(BLACK, 0.12), rn(ctx, 10, 22), a, solid)
	else
		local h = rn(ctx, 5, 13)
		block(ctx, "Randfels", x, h / 2 - 1.5, z, rn(ctx, 7, 11), h, rn(ctx, 6, 10), color, material or M.Slate, {
			Rot = CFrame.Angles(rn(ctx, -0.18, 0.18), rn(ctx, 0, math.pi), rn(ctx, -0.18, 0.18)),
		})
	end
end

-- Schwebender Glitzer über der ganzen Insel
local function ambient(ctx, y: number, height: number, props: { [string]: any })
	local plate = block(ctx, "Glitzer", 0, y, 0, 180, height, 180, WHITE, nil, { Glow = true, Transparency = 1 })
	emitter(plate, props)
end

-- Portal -----------------------------------------------------------------------------------
-- cf: steht auf dem Boden, man läuft in Blickrichtung (LookVector) hinein.
-- opts: Color, Title, Subtitle, Stone (Farbe der Steine), Rebirths (nil = immer offen)
function Islands.Portal(parent: Instance, cf: CFrame, opts)
	local model = Instance.new("Model")
	model.Name = "Portal"
	local ctx = { Folder = model, Origin = cf }
	local color: Color3 = opts.Color
	local stone: Color3 = opts.Stone or rgb(74, 68, 96)

	block(ctx, "Saeule", -6, 6.5, -1, 3, 13, 5, stone, M.Slate)
	block(ctx, "Saeule", 6, 6.5, -1, 3, 13, 5, stone, M.Slate)
	local beam = block(ctx, "Balken", 0, 14.5, -1, 15, 3, 5, stone, M.Slate)
	block(ctx, "Rueckwand", 0, 8, -3.25, 15, 16, 0.5, stone:Lerp(BLACK, 0.3), M.Slate)
	block(ctx, "Sockelstein", -6, 0.5, -1, 4, 1, 6, stone:Lerp(WHITE, 0.15), M.Slate)
	block(ctx, "Sockelstein", 6, 0.5, -1, 4, 1, 6, stone:Lerp(WHITE, 0.15), M.Slate)
	-- Leuchtstreifen am Rahmen und auf der Schwelle
	for _, x in { -6, 6 } do
		block(ctx, "Leuchte", x, 7, 1.55, 0.8, 11.5, 0.2, color, M.Neon, { Glow = true })
	end
	block(ctx, "Leuchte", 0, 14.5, 1.55, 14, 0.7, 0.2, color, M.Neon, { Glow = true })
	block(ctx, "Schwelle", 0, 0.15, -0.6, 9, 0.3, 4.2, color, M.Neon, { Glow = true, Transparency = 0.3 })

	-- Das leuchtende Feld und der Wirbel davor (den dreht der Client)
	local field = block(ctx, "Feld", 0, 6.5, -2.7, 9, 13, 0.4, color, M.Neon, { Glow = true, Transparency = 0.15 })
	light(field, color, 24, 1.6)
	emitter(field, {
		EmissionDirection = Enum.NormalId.Back,
		Rate = 16,
		Lifetime = NumberRange.new(1, 1.8),
		Speed = NumberRange.new(2, 4.5),
		SpreadAngle = Vector2.new(25, 25),
		Size = NumberSequence.new(0.55),
		Color = ColorSequence.new(color:Lerp(WHITE, 0.4)),
		Transparency = FADE,
		LightEmission = 1,
	})
	for i = 0, 2 do
		local bar = block(ctx, "Wirbel", 0, 6.5, -2.3, 8.4, 0.45, 0.15, color:Lerp(WHITE, 0.6), M.Neon, {
			Glow = true,
			Transparency = 0.35,
			Rot = CFrame.Angles(0, 0, math.rad(i * 60)),
		})
		CollectionService:AddTag(bar, "PortalWirbel")
	end
	ball(ctx, "Wirbelkern", 0, 6.5, -2.3, 2, WHITE, M.Neon, { Glow = true })

	-- Hier prüft der Server, ob jemand im Portal steht
	local trigger = block(ctx, "Ausloeser", 0, 6.5, -1.2, 9, 13, 2.4, WHITE, nil, { Glow = true, Transparency = 1 })

	-- Rote Sperre: Wer genug Wiedergeburten hat, sieht sie nicht und läuft durch (macht der Client)
	if opts.Rebirths then
		local lock = block(ctx, "Sperre", 0, 6.5, 1.2, 9, 13, 0.6, rgb(255, 40, 50), M.Neon, {
			Transparency = 0.35,
			CastShadow = false,
			CanQuery = false,
		})
		lock:SetAttribute("Rebirths", opts.Rebirths)
		CollectionService:AddTag(lock, "PortalSperre")
	end

	-- Schild über dem Tor
	local gui = Instance.new("BillboardGui")
	gui.Name = "Schild"
	gui.Size = UDim2.fromScale(16, 4.8) -- schmal genug, dass sich Nachbar-Schilder nicht überdecken
	gui.StudsOffsetWorldSpace = Vector3.new(0, 6.5, 0)
	gui.MaxDistance = 320
	gui.LightInfluence = 0
	gui.Adornee = beam
	local title = Instance.new("TextLabel")
	title.Name = "Titel"
	title.Size = UDim2.fromScale(1, 0.58)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.TextColor3 = color:Lerp(WHITE, 0.45)
	title.TextStrokeTransparency = 0.1
	title.Text = opts.Title
	title.Parent = gui
	local line = Instance.new("TextLabel")
	line.Name = "Zeile2"
	line.Size = UDim2.fromScale(1, 0.38)
	line.Position = UDim2.fromScale(0, 0.6)
	line.BackgroundTransparency = 1
	line.Font = Enum.Font.GothamBold
	line.TextScaled = true
	line.TextColor3 = WHITE
	line.TextStrokeTransparency = 0.2
	line.Text = opts.Subtitle or ""
	line.Parent = gui
	if opts.Rebirths then
		gui:SetAttribute("Rebirths", opts.Rebirths)
		CollectionService:AddTag(gui, "PortalSchild")
	end
	gui.Parent = beam

	-- Lichtsäule, damit man das Portal von weitem findet
	-- (beginnt erst über dem Schild und steht dahinter)
	block(ctx, "Lichtsaeule", 0, 67, -3, 1.6, 80, 1.6, color, M.Neon, { Glow = true, Transparency = 0.62 })

	model.Parent = parent
	return { Model = model, Trigger = trigger, CFrame = cf, Rebirths = opts.Rebirths }
end

-- Welt 1: Kristall-Tal --------------------------------------------------------------------
local CRYSTAL_COLORS = { rgb(255, 110, 220), rgb(90, 225, 255), rgb(170, 110, 255), rgb(120, 255, 200), rgb(255, 210, 90) }

local function crystalTree(ctx, x: number, z: number, s: number)
	local color = pick(ctx, CRYSTAL_COLORS)
	cyl(ctx, "Stamm", x, 0, z, 0.9 * s, 7 * s, rgb(70, 50, 110), M.Slate)
	local y = 7 * s
	for i, size in { 7, 5.4, 3.8 } do
		local side = size * s
		-- (kein Glas: dahinter würden leuchtende Teile verschwinden)
		local crown = put(ctx, "Krone", CFrame.new(x, y + side * 0.3, z) * CFrame.Angles(0, math.rad(i * 30), 0) * TIP, Vector3.new(side, side, side), color:Lerp(WHITE, 0.35 + (i - 1) * 0.15), M.Neon, {
			Glow = true,
			Transparency = 0.32,
		})
		if i == 1 then
			light(crown, color, 16, 0.8)
		end
		y += side * 0.62
	end
end

local function glowShroom(ctx, x: number, z: number, s: number, color: Color3)
	cyl(ctx, "Pilzstiel", x, 0, z, 0.45 * s, 1.8 * s, rgb(245, 235, 255), nil, { Ghost = true })
	local cap = cyl(ctx, "Pilzhut", x, 1.8 * s, z, 1.7 * s, 0.7 * s, color, M.Neon, { Glow = true })
	cyl(ctx, "Pilzhut", x, 2.5 * s, z, 1.05 * s, 0.5 * s, color:Lerp(WHITE, 0.3), M.Neon, { Glow = true })
	light(cap, color, 9, 0.7)
end

-- Leuchtender Teich, flach im Boden, mit Steinen am Ufer
local function pond(ctx, x: number, z: number, r: number, color: Color3, stone: Color3)
	local water = cyl(ctx, "Teich", x, -0.4, z, r, 0.5, color, M.Neon, { Glow = true, Transparency = 0.2 })
	light(water, color, r * 2.5, 1)
	local n = math.floor(r * 1.4)
	for i = 1, n do
		local a = (i + rn(ctx, -0.3, 0.3)) / n * math.pi * 2
		ball(ctx, "Uferstein", x + math.cos(a) * (r + 0.5), 0, z + math.sin(a) * (r + 0.5), rn(ctx, 1.8, 3.4), stone, M.Slate, { Ghost = true })
	end
	keep(ctx, x, z, r + 2)
end

local THEMES = {}

THEMES.Kristall = function(ctx)
	local style = { Top = rgb(160, 130, 230), TopMat = M.Grass, Rim = rgb(100, 75, 170), Rock = rgb(75, 60, 120) }
	ground(ctx, style)
	plaza(ctx, 0, 78, 15, rgb(245, 228, 255), rgb(255, 120, 230))
	pathLine(ctx, 0, 64, 0, 24, 9, rgb(236, 218, 252))
	plaza(ctx, 0, 0, 25, rgb(236, 218, 252), rgb(120, 225, 255))

	-- Wahrzeichen: der Riesenkristall
	cyl(ctx, "Sockel", 0, 0, 0, 13, 2.5, rgb(62, 48, 100), M.Slate)
	cyl(ctx, "Sockel", 0, 2.5, 0, 9, 2, rgb(80, 62, 125), M.Slate)
	local big = crystal(ctx, 0, 4, 0, 40, 9, rgb(190, 110, 255), 0, 0, { CastShadow = false, Transparency = 0.1 })
	light(big, rgb(200, 130, 255), 60, 2)
	emitter(big, {
		Rate = 14,
		Lifetime = NumberRange.new(2, 4),
		Speed = NumberRange.new(1, 3),
		SpreadAngle = Vector2.new(180, 180),
		Size = NumberSequence.new(0.7),
		Color = ColorSequence.new(rgb(255, 200, 255)),
		Transparency = FADE,
		LightEmission = 1,
	})
	for i = 1, 6 do
		local a = i * 60 + 20
		crystal(ctx, math.cos(math.rad(a)) * 6, 3.6, math.sin(math.rad(a)) * 6, rn(ctx, 16, 26), rn(ctx, 3.6, 5), CRYSTAL_COLORS[i % #CRYSTAL_COLORS + 1], rn(ctx, 24, 34), a)
	end
	for i = 1, 8 do
		local a = math.rad(i * 45 + 10)
		local r = rn(ctx, 17, 21)
		put(ctx, "Splitter", CFrame.new(math.cos(a) * r, rn(ctx, 16, 36), math.sin(a) * r) * CFrame.Angles(rn(ctx, -0.5, 0.5), rn(ctx, 0, 3), rn(ctx, -0.5, 0.5)), Vector3.new(1.3, 4.5, 1.3), CRYSTAL_COLORS[i % #CRYSTAL_COLORS + 1], M.Neon, {
			Glow = true,
			Transparency = 0.1,
		})
	end
	blocker(ctx, 0, 0, 14)

	-- Kristall-Bogen über dem Weg
	crystal(ctx, -9.5, -1.6, 46, 21.5, 3, rgb(255, 110, 220), 27, 0)
	crystal(ctx, 9.5, -1.6, 46, 21.5, 3, rgb(90, 225, 255), 27, 180)
	keep(ctx, -9.5, 46, 3)
	keep(ctx, 9.5, 46, 3)

	pond(ctx, -50, 22, 12, rgb(90, 230, 255), rgb(90, 70, 140))
	pond(ctx, 48, -40, 9, rgb(255, 130, 230), rgb(90, 70, 140))

	scatter(ctx, 15, 30, 92, 3.2, true, function(x, z)
		local main = crystalCluster(ctx, x, z, rn(ctx, 7, 16), pick(ctx, CRYSTAL_COLORS))
		light(main, main.Color, 14, 0.8)
	end)
	scatter(ctx, 11, 28, 90, 5, true, function(x, z)
		crystalTree(ctx, x, z, rn(ctx, 0.85, 1.35))
	end)
	scatter(ctx, 18, 20, 96, 1.5, false, function(x, z)
		glowShroom(ctx, x, z, rn(ctx, 0.7, 1.4), pick(ctx, CRYSTAL_COLORS))
	end)
	scatter(ctx, 22, 18, 96, 1.5, nil, function(x, z)
		local d = rn(ctx, 2, 4.2)
		ball(ctx, "Stein", x, -d * 0.12, z, d, rgb(95, 78, 150), M.Slate, { Ghost = true })
	end)

	rim(ctx, 30, function(x, z, _, i)
		rimRock(ctx, x, z, i, style.Rock:Lerp(WHITE, rn(ctx, 0, 0.12)))
		if i % 2 == 0 then
			crystalCluster(ctx, x * 0.93, z * 0.93, rn(ctx, 6, 10), pick(ctx, CRYSTAL_COLORS))
		end
	end)

	ambient(ctx, 16, 30, {
		Rate = 30,
		Lifetime = NumberRange.new(5, 8),
		Speed = NumberRange.new(0.4, 1.2),
		SpreadAngle = Vector2.new(180, 180),
		Size = NumberSequence.new(0.45),
		Color = ColorSequence.new(rgb(255, 190, 250), rgb(150, 230, 255)),
		Transparency = FADE,
		LightEmission = 1,
	})

	local isletList = { { 30, 152, 14, 14 }, { 125, 160, -8, 11 }, { 200, 150, 22, 16 }, { 285, 165, 4, 12 }, { 335, 140, 30, 9 } }
	islets(ctx, isletList, style, function(sub, r)
		local main = crystalCluster(sub, 0, 0, r * 0.95, pick(sub, CRYSTAL_COLORS))
		light(main, main.Color, 20, 1)
	end)
	isletSpikes(ctx, isletList, style)
	hangingSpikes(ctx, style, rgb(190, 110, 255))
	return style
end

-- Welt 2: Lava-Krater ---------------------------------------------------------------------
local LAVA = rgb(255, 105, 25)
local LAVA_HOT = rgb(255, 190, 60)

-- Lava-Bach flach auf dem Boden: dunkle Kruste, darauf der leuchtende Strom
local function lavaLine(ctx, x0: number, z0: number, x1: number, z1: number, width: number)
	pathLine(ctx, x0, z0, x1, z1, width + 2.6, rgb(30, 24, 28), M.Slate, 0.05, "Kruste")
	pathLine(ctx, x0, z0, x1, z1, width, LAVA, M.Neon, 0.1, "Lava", { Glow = true })
end

local function lavaPool(ctx, x: number, z: number, r: number)
	cyl(ctx, "Kruste", x, -0.44, z, r + 2, 0.5, rgb(30, 24, 28), M.Slate, { Ghost = true })
	local lava = cyl(ctx, "Lava", x, -0.38, z, r, 0.5, LAVA, M.Neon, { Glow = true })
	cyl(ctx, "Lava", x + r * 0.15, -0.34, z - r * 0.1, r * 0.5, 0.5, LAVA_HOT, M.Neon, { Glow = true })
	light(lava, LAVA, r * 3, 1.6)
	emitter(lava, {
		Texture = FIRE,
		Rate = 5,
		Lifetime = NumberRange.new(1, 2),
		Speed = NumberRange.new(2, 5),
		SpreadAngle = Vector2.new(20, 20),
		EmissionDirection = Enum.NormalId.Right, -- bei stehenden Zylindern zeigt "rechts" nach oben
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 0.2) }),
		Color = ColorSequence.new(LAVA_HOT, LAVA),
		Transparency = FADE,
		LightEmission = 1,
	})
	local n = math.floor(r * 1.2)
	for i = 1, n do
		local a = (i + rn(ctx, -0.3, 0.3)) / n * math.pi * 2
		ball(ctx, "Uferstein", x + math.cos(a) * (r + 1.4), 0, z + math.sin(a) * (r + 1.4), rn(ctx, 2, 4), rgb(44, 36, 40), M.Slate, { Ghost = true })
	end
	keep(ctx, x, z, r + 3)
end

-- Spitze Felsnadeln
local function rockSpikes(ctx, x: number, z: number, s: number, color: Color3)
	local solid = { Material = M.Slate }
	crystal(ctx, x, -1, z, rn(ctx, 9, 15) * s, rn(ctx, 2.6, 3.6) * s, color, rn(ctx, 0, 8), rn(ctx, 0, 360), solid)
	for _ = 1, ctx.Rng:NextInteger(1, 2) do
		local a = rn(ctx, 0, 360)
		crystal(ctx, x + math.cos(math.rad(a)) * 2.2 * s, -1.4, z + math.sin(math.rad(a)) * 2.2 * s, rn(ctx, 5, 9) * s, rn(ctx, 1.8, 2.6) * s, color:Lerp(BLACK, 0.15), rn(ctx, 12, 26), a, solid)
	end
end

local function deadTree(ctx, x: number, z: number, s: number)
	local bark = rgb(36, 28, 27)
	cyl(ctx, "Stamm", x, 0, z, 0.8 * s, 9 * s, bark, M.Slate)
	for i = 1, 3 do
		local a = i * 120 + rn(ctx, -30, 30)
		local base = CFrame.new(x, (4.5 + i * 1.3) * s, z) * facing(a) * CFrame.Angles(math.rad(rn(ctx, 40, 58)), 0, 0)
		local length = rn(ctx, 4, 6) * s
		put(ctx, "Ast", base * CFrame.new(0, length / 2, 0), Vector3.new(0.6 * s, length, 0.6 * s), bark, M.Slate, { Ghost = true })
		local tip = (ctx.Origin * base * CFrame.new(0, length, 0)).Position
		local glow = newPart("Glut", LAVA, M.Neon)
		glow.Shape = Enum.PartType.Ball
		glow.Size = Vector3.new(0.9, 0.9, 0.9) * s
		glow.CFrame = CFrame.new(tip)
		finish(glow, ctx.Folder, { Glow = true })
	end
end

THEMES.Lava = function(ctx)
	local style = { Top = rgb(64, 52, 56), TopMat = M.Basalt, Rim = rgb(40, 30, 34), Rock = rgb(54, 40, 40), RockMat = M.Basalt }
	ground(ctx, style)
	plaza(ctx, 0, 78, 15, rgb(108, 90, 86), rgb(255, 120, 30), M.Slate)
	pathLine(ctx, 0, 64, 0, 30, 9, rgb(112, 96, 92), M.Slate)
	plaza(ctx, 0, 21, 11, rgb(108, 90, 86), rgb(255, 120, 30), M.Slate)

	-- Wahrzeichen: der Vulkan (Stufen-Kegel mit Lava-Kessel oben)
	local vx, vz = 0, -30
	-- viele niedrige Stufen, unten flach und oben steil: so sieht es nach Berg aus statt nach Torte
	local tiers = { { 38, 4 }, { 33.5, 4 }, { 29.5, 4.5 }, { 25.5, 4.5 }, { 22, 4.5 }, { 19, 4.5 }, { 16.5, 4.5 }, { 14.2, 4.5 }, { 12.4, 4.5 } }
	local tops = {}
	local y = 0
	for i, t in tiers do
		cyl(ctx, "Vulkan", vx, y, vz, t[1], t[2], rgb(80, 60, 56):Lerp(rgb(44, 34, 38), (i - 1) / (#tiers - 1)), M.Slate)
		y += t[2]
		tops[i] = y
		-- Felsbrocken auf den Stufen brechen die Ringe auf
		for _ = 1, 9 - math.floor(i / 2) do
			local a = rn(ctx, 0, math.pi * 2)
			local size = rn(ctx, 3, 5.5)
			block(ctx, "Vulkanfels", vx + math.cos(a) * (t[1] - 1), y - size * 0.25, vz + math.sin(a) * (t[1] - 1), size, size, size, rgb(70, 54, 52):Lerp(rgb(40, 32, 36), rn(ctx, 0, 1)), M.Slate, {
				Ghost = true,
				Rot = CFrame.Angles(rn(ctx, 0, 3), rn(ctx, 0, 3), rn(ctx, 0, 3)),
			})
		end
	end
	local crater = cyl(ctx, "Lava", vx, y, vz, 10, 1.6, LAVA, M.Neon, { CastShadow = false })
	cyl(ctx, "Lava", vx, y + 1.2, vz, 5.5, 0.6, LAVA_HOT, M.Neon, { Glow = true })
	light(crater, LAVA, 70, 2.5)
	for i = 1, 12 do
		local a = math.rad(i * 30)
		block(ctx, "Kraterrand", vx + math.cos(a) * 11.6, y + 1.4, vz + math.sin(a) * 11.6, 4.4, rn(ctx, 3, 5.5), 4.4, rgb(44, 34, 38), M.Slate, {
			Rot = CFrame.Angles(rn(ctx, -0.2, 0.2), rn(ctx, 0, 3), rn(ctx, -0.2, 0.2)),
		})
	end
	local fire = Instance.new("Fire")
	fire.Size = 24
	fire.Heat = 18
	fire.Color = rgb(255, 130, 40)
	fire.SecondaryColor = rgb(255, 60, 20)
	fire.Parent = crater
	emitter(crater, {
		Texture = SMOKE,
		Rate = 5,
		Lifetime = NumberRange.new(7, 10),
		Speed = NumberRange.new(5, 8),
		SpreadAngle = Vector2.new(14, 14),
		EmissionDirection = Enum.NormalId.Right,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 7), NumberSequenceKeypoint.new(1, 24) }),
		Color = ColorSequence.new(rgb(70, 60, 60), rgb(30, 26, 28)),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(0.6, 0.6), NumberSequenceKeypoint.new(1, 1) }),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-20, 20),
	})
	blocker(ctx, vx, vz, 40)

	-- Lava läuft in drei Strömen die Stufen hinunter und weiter in die Lava-Seen
	local streams = { { 40, 60, 20, 12 }, { 150, -62, 6, 13 }, { 270, 0, -106.4, 0 } } -- Winkel, Ziel x, Ziel z, See-Radius
	for _, s in streams do
		local base = CFrame.new(vx, 0, vz) * facing(s[1])
		for i, t in tiers do
			local bottom = if i == 1 then 0 else tops[i - 1]
			put(ctx, "Lavastrom", base * CFrame.new(0, (bottom + tops[i]) / 2, t[1] + 0.1), Vector3.new(3.6, t[2] + 0.4, 0.5), LAVA, M.Neon, { Glow = true })
			local inner = if tiers[i + 1] then tiers[i + 1][1] else 10
			put(ctx, "Lavastrom", base * CFrame.new(0, tops[i] + 0.1, (t[1] + inner) / 2), Vector3.new(3.6, 0.4, t[1] - inner + 0.6), LAVA, M.Neon, { Glow = true })
		end
		local a = math.rad(s[1])
		local fx, fz = vx + math.cos(a) * 38, vz + math.sin(a) * 38
		lavaLine(ctx, fx, fz, s[2], s[3], 3.6)
		if s[4] > 0 then
			lavaPool(ctx, s[2], s[3], s[4])
		end
	end
	-- Im Norden stürzt die Lava über den Inselrand
	-- (unten löst er sich in Stücken auf, statt abrupt aufzuhören)
	block(ctx, "Lavafall", 0, -24.9, -107, 4.4, 50, 1.2, LAVA, M.Neon, { Glow = true, Transparency = 0.1 })
	for i, fade in { 0.4, 0.62, 0.8, 0.92 } do
		block(ctx, "Lavafall", 0, -50 - i * 9 + 4.5, -107, 4.4 - i * 0.5, 9, 1.2, LAVA, M.Neon, { Glow = true, Transparency = fade })
	end
	lavaPool(ctx, -30, 56, 9)
	lavaPool(ctx, 48, -62, 8)

	-- Glühende Risse im Boden
	-- (liegen tiefer als Wege, Plätze und Lava und halten Abstand davon, sonst flimmert es)
	scatter(ctx, 34, 16, 98, 7, nil, function(x, z)
		local yaw = rn(ctx, 0, math.pi)
		local length = rn(ctx, 4, 9)
		local cf = CFrame.new(x, 0, z) * CFrame.Angles(0, yaw, 0)
		put(ctx, "Riss", cf * CFrame.new(0, -0.1, 0), Vector3.new(0.5, 0.3, length), LAVA, M.Neon, { Glow = true })
		put(ctx, "Riss", cf * CFrame.new(0, -0.1, length / 2) * CFrame.Angles(0, 0.7, 0) * CFrame.new(0, 0, length * 0.3), Vector3.new(0.4, 0.3, length * 0.6), LAVA, M.Neon, { Glow = true })
	end)
	scatter(ctx, 18, 22, 92, 3.6, true, function(x, z)
		rockSpikes(ctx, x, z, rn(ctx, 0.8, 1.3), rgb(50, 40, 44))
	end)
	scatter(ctx, 6, 28, 88, 3, true, function(x, z)
		cyl(ctx, "Obsidian", x, 0, z, 2, 14, rgb(26, 22, 32), M.SmoothPlastic, { Reflectance = 0.2 })
		for _, ry in { 4.5, 9.5 } do
			local ring = cyl(ctx, "Glutring", x, ry, z, 2.3, 0.8, LAVA, M.Neon, { Glow = true })
			light(ring, LAVA, 12, 1)
		end
		cyl(ctx, "Obsidian", x, 14, z, 2.6, 1, rgb(26, 22, 32))
	end)
	scatter(ctx, 9, 24, 92, 2.6, true, function(x, z)
		deadTree(ctx, x, z, rn(ctx, 0.9, 1.3))
	end)
	scatter(ctx, 20, 16, 96, 1.5, nil, function(x, z)
		local d = rn(ctx, 2, 4.5)
		ball(ctx, "Stein", x, -d * 0.12, z, d, rgb(46, 38, 42), M.Slate, { Ghost = true })
	end)

	rim(ctx, 30, function(x, z, _, i)
		rimRock(ctx, x, z, i, rgb(44, 34, 38):Lerp(rgb(70, 54, 52), rn(ctx, 0, 1)))
		if i % 3 == 0 then
			local glow = block(ctx, "Glut", x * 0.94, 1, z * 0.94, 2.6, 2.6, 2.6, LAVA, M.Neon, {
				Glow = true,
				Rot = CFrame.Angles(0.5, rn(ctx, 0, 3), 0.4),
			})
			light(glow, LAVA, 14, 1)
		end
	end)

	-- Funken steigen über der ganzen Insel auf
	ambient(ctx, 2, 2, {
		Rate = 34,
		Lifetime = NumberRange.new(4, 7),
		Speed = NumberRange.new(2, 5),
		SpreadAngle = Vector2.new(25, 25),
		Size = NumberSequence.new(0.4),
		Color = ColorSequence.new(LAVA_HOT, rgb(255, 70, 20)),
		Transparency = FADE,
		LightEmission = 1,
	})

	local isletList = { { 25, 150, 10, 13 }, { 130, 158, 24, 15 }, { 205, 150, -6, 11 }, { 310, 160, 16, 12 } }
	isletSpikes(ctx, isletList, style)
	hangingSpikes(ctx, style, LAVA)
	islets(ctx, isletList, style, function(sub, r)
		rockSpikes(sub, 0, 0, r / 12, rgb(50, 40, 44))
		block(sub, "Lavatropfen", r * 0.35, -19, 0, 1.8, 30, 1.8, LAVA, M.Neon, { Glow = true, Transparency = 0.2 })
		cyl(sub, "Lava", r * 0.35, -2.42, 0, 2.6, 2.5, LAVA, M.Neon, { Glow = true })
	end)
	return style
end

-- Welt 3: Eis-Gipfel ----------------------------------------------------------------------
local ICE = rgb(165, 222, 255)
local SNOW = rgb(240, 247, 255)
local ICE_LOOK = { Material = M.Glass, Transparency = 0.3, CastShadow = false }

local function pine(ctx, x: number, z: number, s: number)
	cyl(ctx, "Stamm", x, 0, z, 0.7 * s, 3.2 * s, rgb(110, 78, 55), M.Wood)
	local y = 2.6 * s
	for i, r in { 4.3, 3.2, 2.1 } do
		cyl(ctx, "Tanne", x, y, z, r * s, 2.8 * s, rgb(40, 125, 95):Lerp(rgb(70, 160, 120), (i - 1) / 2), M.LeafyGrass, { Ghost = true })
		cyl(ctx, "Schnee", x, y + 2.8 * s, z, (r - 0.5) * s, 0.6 * s, SNOW, M.Snow, { Ghost = true })
		y += 2.6 * s
	end
	ball(ctx, "Schnee", x, y + 0.9 * s, z, 1.7 * s, SNOW, M.Snow, { Ghost = true })
end

local function snowman(ctx, x: number, z: number, yawDeg: number)
	local origin = ctx.Origin
	ctx.Origin = origin * CFrame.new(x, 0, z) * facing(yawDeg)
	local coal = rgb(30, 30, 36)
	ball(ctx, "Schneemann", 0, 1.8, 0, 4.2, SNOW, M.Snow)
	ball(ctx, "Schneemann", 0, 4.6, 0, 3.1, SNOW, M.Snow, { Ghost = true })
	ball(ctx, "Schneemann", 0, 6.8, 0, 2.2, SNOW, M.Snow, { Ghost = true })
	for _, ex in { -0.42, 0.42 } do
		ball(ctx, "Auge", ex, 7.1, 0.95, 0.32, coal, nil, { Ghost = true })
	end
	block(ctx, "Nase", 0, 6.75, 1.5, 0.32, 0.32, 1.2, rgb(255, 140, 40), nil, { Ghost = true })
	for i = 0, 2 do
		ball(ctx, "Knopf", 0, 3.9 + i * 0.75, 1.5 - i * 0.06, 0.34, coal, nil, { Ghost = true })
	end
	cyl(ctx, "Hut", 0, 7.7, 0, 1.25, 0.2, coal, nil, { Ghost = true })
	cyl(ctx, "Hut", 0, 7.9, 0, 0.85, 1.3, coal, nil, { Ghost = true })
	cyl(ctx, "Hutband", 0, 7.9, 0, 0.88, 0.35, rgb(230, 60, 70), nil, { Ghost = true })
	for _, side in { -1, 1 } do
		put(ctx, "Arm", CFrame.new(side * 2.3, 5, 0) * CFrame.Angles(0, 0, math.rad(side * -62)), Vector3.new(0.28, 3, 0.28), rgb(110, 78, 55), M.Wood, { Ghost = true })
	end
	block(ctx, "Schal", 0, 5.85, 0, 2.3, 0.5, 2.3, rgb(230, 60, 70), M.Fabric, { Ghost = true })
	ctx.Origin = origin
end

local function igloo(ctx, x: number, z: number)
	-- Tür zeigt zur Inselmitte
	local origin = ctx.Origin
	ctx.Origin = origin * CFrame.new(x, 0, z) * facing(math.deg(math.atan2(-z, -x)))
	ball(ctx, "Iglu", 0, -1, 0, 19, rgb(232, 242, 255), M.Snow)
	block(ctx, "Iglu-Eingang", 0, 2.6, 8.6, 6.4, 5.6, 4.6, rgb(222, 236, 252), M.Snow)
	block(ctx, "Iglu-Tuer", 0, 2.1, 10.95, 3.6, 4.2, 0.2, rgb(40, 50, 80), nil, { Ghost = true })
	local lamp = block(ctx, "Iglu-Licht", 0, 4.6, 10.98, 3.6, 0.4, 0.2, rgb(255, 210, 120), M.Neon, { Glow = true })
	light(lamp, rgb(255, 210, 120), 12, 1)
	for i = 1, 5 do
		local a = math.rad(i * 36 - 18)
		block(ctx, "Eisblock", math.cos(a) * 9.6, 0.6, -math.sin(a) * 9.6, 2.6, 1.6, 2.6, ICE, M.Ice, { Ghost = true, Rot = CFrame.Angles(0, rn(ctx, 0, 3), 0) })
	end
	ctx.Origin = origin
	blocker(ctx, x, z, 12)
end

local function iceSpikes(ctx, x: number, z: number, s: number)
	local main = crystal(ctx, x, -1, z, rn(ctx, 8, 13) * s, rn(ctx, 2, 3) * s, ICE, rn(ctx, 0, 8), rn(ctx, 0, 360), ICE_LOOK)
	for _ = 1, ctx.Rng:NextInteger(1, 3) do
		local a = rn(ctx, 0, 360)
		crystal(ctx, x + math.cos(math.rad(a)) * 1.9 * s, -1.4, z + math.sin(math.rad(a)) * 1.9 * s, rn(ctx, 4, 8) * s, rn(ctx, 1.4, 2.1) * s, ICE:Lerp(WHITE, 0.3), rn(ctx, 12, 24), a, ICE_LOOK)
	end
	return main
end

-- Berg aus gestapelten, verdrehten Blöcken: unten Fels, oben Schnee
local function peak(ctx, x: number, z: number, layers)
	local y = 0
	for i, l in layers do
		local t = (i - 1) / math.max(1, #layers - 1)
		local rot = CFrame.Angles(0, math.rad(l[4]), 0)
		block(ctx, "Berg", x, y + l[2] / 2, z, l[1], l[2], l[3], rgb(132, 152, 188):Lerp(SNOW, t ^ 0.8), if t > 0.6 then M.Snow else M.Slate, { Rot = rot })
		block(ctx, "Schneedecke", x, y + l[2] + 0.2, z, l[1] + 1.4, 1.6, l[3] + 1.4, SNOW, M.Snow, { Rot = rot, Ghost = true })
		y += l[2]
	end
	return y
end

-- Spitze Felszacke mit Schneehaube (unten Fels, oberes Drittel und Spitze Schnee)
local function rockPeak(ctx, x: number, y: number, z: number, height: number, width: number, tilt: number, lean: number)
	local base = CFrame.new(x, y, z) * facing(lean) * CFrame.Angles(math.rad(tilt), 0, 0)
	local turn = CFrame.Angles(0, math.rad(45), 0)
	local low = height * 0.66
	put(ctx, "Berg", base * CFrame.new(0, low / 2, 0) * turn, Vector3.new(width, low, width), rgb(140, 160, 196), M.Slate)
	put(ctx, "Berg", base * CFrame.new(0, low + (height - low) / 2, 0) * turn, Vector3.new(width * 1.03, height - low, width * 1.03), SNOW, M.Snow)
	put(ctx, "Berg", base * CFrame.new(0, height, 0) * TIP, Vector3.one * (width * 1.01), SNOW, M.Snow)
end

THEMES.Eis = function(ctx)
	local style = { Top = SNOW, TopMat = M.Snow, Rim = rgb(170, 205, 240), Rock = rgb(120, 145, 180), RockMat = M.Ice }
	ground(ctx, style)
	plaza(ctx, 0, 78, 15, rgb(200, 226, 250), rgb(120, 220, 255))
	pathLine(ctx, 0, 64, 0, 31, 9, rgb(206, 228, 248))

	-- Zugefrorener See in der Mitte, mit Eis-Zacken auf einer kleinen Insel
	cyl(ctx, "Ufer", 0, -0.45, 0, 31.5, 0.5, rgb(214, 234, 255), M.Snow, { Ghost = true })
	cyl(ctx, "See", 0, -0.4, 0, 30, 0.5, rgb(150, 210, 245), M.Ice, { Ghost = true, Reflectance = 0.12 })
	keep(ctx, 0, 0, 33)
	cyl(ctx, "See-Insel", 0, 0, 0, 7.5, 1, SNOW, M.Snow)
	local heart = crystal(ctx, 0, 0.6, 0, 24, 4.6, ICE, 0, 0, ICE_LOOK)
	light(heart, rgb(130, 220, 255), 46, 1.8)
	for i = 1, 5 do
		local a = i * 72 + 15
		crystal(ctx, math.cos(math.rad(a)) * 3.4, -0.1, math.sin(math.rad(a)) * 3.4, rn(ctx, 9, 16), rn(ctx, 2.2, 3.2), ICE:Lerp(WHITE, 0.25), rn(ctx, 16, 30), a, ICE_LOOK)
	end
	blocker(ctx, 0, 0, 8.5)

	-- Wahrzeichen: der Gipfel hinten
	-- (zwei breite Felsstufen, darauf ein Bündel spitzer Zacken mit Schneehauben)
	local top = peak(ctx, 0, -62, { { 46, 11, 40, 8 }, { 36, 9, 30, -14 } })
	rockPeak(ctx, 0, top - 2, -62, 38, 17, 0, 0)
	rockPeak(ctx, -11, top - 3, -58, 25, 12, 9, 180)
	rockPeak(ctx, 11, top - 3, -66, 28, 13, 8, 0)
	rockPeak(ctx, -2, top - 3, -72, 20, 11, 10, 270)
	rockPeak(ctx, 4, top - 3, -52, 17, 10, 9, 90)
	rockPeak(ctx, -19, 9, -66, 22, 10, 12, 200)
	rockPeak(ctx, 19, 9, -58, 20, 10, 12, 340)
	local leftTop = peak(ctx, -31, -50, { { 22, 9, 20, -12 } })
	rockPeak(ctx, -31, leftTop - 2, -50, 22, 11, 4, 150)
	rockPeak(ctx, -36, leftTop - 3, -46, 13, 7, 12, 160)
	local rightTop = peak(ctx, 29, -55, { { 20, 8, 18, 15 } })
	rockPeak(ctx, 29, rightTop - 2, -55, 20, 10, 4, 30)
	rockPeak(ctx, 34, rightTop - 3, -51, 12, 7, 12, 20)
	blocker(ctx, 0, -62, 33)
	blocker(ctx, -31, -50, 17)
	blocker(ctx, 29, -55, 16)

	igloo(ctx, -56, 38)
	igloo(ctx, 60, 30)

	scatter(ctx, 18, 36, 92, 4.2, true, function(x, z)
		pine(ctx, x, z, rn(ctx, 0.85, 1.4))
	end)
	scatter(ctx, 5, 36, 84, 3.2, true, function(x, z)
		snowman(ctx, x, z, math.deg(math.atan2(-z, -x)) + rn(ctx, -40, 40))
	end)
	scatter(ctx, 14, 34, 94, 3, true, function(x, z)
		iceSpikes(ctx, x, z, rn(ctx, 0.8, 1.3))
	end)
	scatter(ctx, 20, 34, 96, 2, nil, function(x, z)
		local d = rn(ctx, 5, 10)
		ball(ctx, "Schneehaufen", x, -d * 0.36, z, d, SNOW, M.Snow, { Ghost = true })
	end)

	rim(ctx, 30, function(x, z, _, i)
		local h = rn(ctx, 5, 12)
		local rot = CFrame.Angles(rn(ctx, -0.15, 0.15), rn(ctx, 0, math.pi), rn(ctx, -0.15, 0.15))
		if i % 3 == 1 then
			iceSpikes(ctx, x, z, rn(ctx, 1.2, 1.6))
		elseif i % 2 == 0 then
			block(ctx, "Eisblock", x, h / 2 - 1.5, z, rn(ctx, 6, 10), h, rn(ctx, 6, 9), ICE, M.Ice, { Rot = rot })
		else
			block(ctx, "Schneewehe", x, h / 2 - 2.5, z, rn(ctx, 8, 12), h * 0.7, rn(ctx, 7, 10), SNOW, M.Snow, { Rot = rot })
		end
	end)

	-- Polarlicht: drei wehende Bänder hoch am Himmel
	local AURORA = { rgb(90, 255, 170), rgb(90, 220, 255), rgb(200, 130, 255) }
	for band = 1, 3 do
		local z0 = -110 + band * 45
		for i = -5, 5 do
			local x = i * 24
			local z = z0 + math.sin(i * 0.7 + band) * 16
			local nextZ = z0 + math.sin((i + 1) * 0.7 + band) * 16
			local yaw = math.atan2(nextZ - z, 24)
			put(ctx, "Polarlicht", CFrame.new(x, 78 + band * 7 + math.cos(i * 0.9) * 4, z) * CFrame.Angles(0, -yaw, 0), Vector3.new(31, 13, 0.6), AURORA[band]:Lerp(AURORA[band % 3 + 1], (i + 5) / 10), M.Neon, {
				Glow = true,
				Transparency = 0.74,
			})
		end
	end

	-- Schneefall
	local sky = block(ctx, "Schneefall", 0, 58, 0, 190, 1, 190, WHITE, nil, { Glow = true, Transparency = 1 })
	emitter(sky, {
		EmissionDirection = Enum.NormalId.Bottom,
		Rate = 130,
		Lifetime = NumberRange.new(7, 8),
		Speed = NumberRange.new(8, 10),
		SpreadAngle = Vector2.new(8, 8),
		Acceleration = Vector3.new(1, 0, 0.5),
		Size = NumberSequence.new(0.32),
		Color = ColorSequence.new(WHITE),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.1, 0.1), NumberSequenceKeypoint.new(0.9, 0.1), NumberSequenceKeypoint.new(1, 1) }),
		LightEmission = 0.5,
	})

	local isletList = { { 20, 150, 12, 13 }, { 140, 158, 20, 14 }, { 215, 152, -6, 11 }, { 300, 162, 26, 12 } }
	isletSpikes(ctx, isletList, style)
	hangingSpikes(ctx, style, ICE)
	islets(ctx, isletList, style, function(sub, r, i)
		if i % 2 == 0 then
			iceSpikes(sub, 0, 0, r / 10)
		else
			pine(sub, 0, 0, r / 9)
		end
		-- Eiszapfen unter dem Inselchen
		crystal(sub, r * 0.3, -3, 0, 9, 1.6, ICE, 180, 0, ICE_LOOK)
	end)
	return style
end

-- Welt 4: Sternen-Insel -------------------------------------------------------------------
local STAR_COLORS = { rgb(255, 255, 255), rgb(140, 230, 255), rgb(255, 150, 240), rgb(255, 235, 130) }
local SPACE_CYAN = rgb(90, 220, 255)

-- Planet mit Ring, schwebt am Himmel
local function planet(ctx, x: number, y: number, z: number, d: number, color: Color3, ringColor: Color3?)
	-- leicht leuchtend, sonst sind sie bei Nacht nur dunkle Kugeln
	ball(ctx, "Planet", x, y, z, d, color:Lerp(BLACK, 0.5), M.Neon, { Glow = true })
	local tilt = CFrame.Angles(math.rad(rn(ctx, 12, 28)), 0, math.rad(rn(ctx, -20, 20)))
	-- heller Streifen um den Bauch
	cyl(ctx, "Planetenstreifen", x, y - d * 0.05, z, d * 0.502, d * 0.1, color:Lerp(WHITE, 0.15), M.Neon, { Glow = true, Rot = tilt })
	if ringColor then
		cyl(ctx, "Planetenring", x, y - 0.25, z, d * 0.92, 0.5, ringColor, M.Neon, { Glow = true, Transparency = 0.45, Rot = tilt })
		cyl(ctx, "Planetenring", x, y - 0.3, z, d * 0.7, 0.6, ringColor:Lerp(WHITE, 0.4), M.Neon, { Glow = true, Transparency = 0.6, Rot = tilt })
	end
end

-- Schwebender Stern über einem kleinen Sockel
local function starCrystal(ctx, x: number, z: number, color: Color3)
	cyl(ctx, "Sternsockel", x, 0, z, 1.3, 1.2, rgb(30, 26, 64), M.Slate)
	local ring = cyl(ctx, "Sternsockel", x, 1.2, z, 1.4, 0.25, color, M.Neon, { Glow = true })
	light(ring, color, 14, 1)
	put(ctx, "Stern", CFrame.new(x, 4.6, z) * TIP, Vector3.new(2.3, 2.3, 2.3), color, M.Neon, { Glow = true })
	put(ctx, "Stern", CFrame.new(x, 4.6, z) * CFrame.Angles(0, math.rad(45), 0) * TIP, Vector3.new(1.6, 1.6, 1.6), WHITE, M.Neon, { Glow = true })
end

local function alienPlant(ctx, x: number, z: number, s: number, color: Color3)
	local h = rn(ctx, 4, 7) * s
	local lean = CFrame.Angles(rn(ctx, -0.15, 0.15), 0, rn(ctx, -0.15, 0.15))
	cyl(ctx, "Stiel", x, 0, z, 0.3 * s, h, rgb(60, 220, 200), M.Neon, { Glow = true, Rot = lean })
	ball(ctx, "Leuchtknolle", x, h + 0.6 * s, z, 1.9 * s, color, M.Neon, { Glow = true })
end

local function rocket(ctx)
	local white = rgb(240, 242, 250)
	local red = rgb(255, 70, 95)
	local metal = rgb(92, 94, 118)
	cyl(ctx, "Startrampe", 0, 0, 0, 16, 1.2, metal, M.DiamondPlate)
	cyl(ctx, "Startrampe", 0, 0.4, 0, 16.6, 0.5, SPACE_CYAN, M.Neon, { Glow = true })
	cyl(ctx, "Startrampe", 0, 1.2, 0, 8, 0.4, rgb(60, 62, 84), M.Metal)
	-- Triebwerk und Flamme
	cyl(ctx, "Duese", 0, 2.4, 0, 3.2, 2, rgb(50, 52, 70), M.Metal)
	local flame = cyl(ctx, "Flamme", 0, 1.6, 0, 2.2, 1, rgb(255, 170, 60), M.Neon, { Glow = true, Transparency = 0.25 })
	light(flame, rgb(255, 170, 60), 26, 1.6)
	local fire = Instance.new("Fire")
	fire.Size = 9
	fire.Heat = -6 -- brennt nach unten weg
	fire.Parent = flame
	-- Rumpf
	local body = cyl(ctx, "Rakete", 0, 4, 0, 4.6, 25.8, white, M.SmoothPlastic)
	cyl(ctx, "Raketenstreifen", 0, 9, 0, 4.7, 1.6, red, nil, { Ghost = true })
	cyl(ctx, "Raketenstreifen", 0, 25, 0, 4.7, 1.6, red, nil, { Ghost = true })
	-- Spitze in vielen kleinen Stufen, damit sie rund wirkt
	local noseY = 29.8
	for _, r in { 4.4, 4.05, 3.6, 3.05, 2.4, 1.7 } do
		cyl(ctx, "Raketenspitze", 0, noseY, 0, r, 1.2, red)
		noseY += 1.2
	end
	ball(ctx, "Raketenspitze", 0, noseY - 0.3, 0, 3, red)
	cyl(ctx, "Antenne", 0, noseY + 0.8, 0, 0.2, 4, metal, M.Metal, { Ghost = true })
	local beacon = ball(ctx, "Antennenlicht", 0, noseY + 5, 0, 0.9, rgb(255, 80, 80), M.Neon, { Glow = true })
	light(beacon, rgb(255, 80, 80), 20, 1.5)
	-- Bullaugen rundherum
	for i = 0, 3 do
		local a = math.rad(i * 90 + 45)
		ball(ctx, "Bullauge-Rahmen", math.cos(a) * 3.9, 19, math.sin(a) * 3.9, 3.2, metal, M.Metal, { Ghost = true })
		ball(ctx, "Bullauge", math.cos(a) * 4.25, 19, math.sin(a) * 4.25, 2.6, SPACE_CYAN, M.Neon, { Glow = true })
	end
	-- Flossen und Standbeine
	for i = 0, 3 do
		local base = facing(i * 90)
		put(ctx, "Flosse", base * CFrame.new(0, 8.5, 5.9) * CFrame.Angles(math.rad(-16), 0, 0), Vector3.new(0.9, 9, 5.6), red, nil, nil)
		put(ctx, "Standbein", base * CFrame.new(0, 3.6, 8.6) * CFrame.Angles(math.rad(-34), 0, 0), Vector3.new(0.7, 6.4, 0.7), metal, M.Metal, { Ghost = true })
		put(ctx, "Standfuss", base * CFrame.new(0, 1.4, 10.4), Vector3.new(2.2, 0.4, 2.2), metal, M.Metal, { Ghost = true })
	end
	light(body, WHITE, 30, 0.6)
	blocker(ctx, 0, 0, 18)
end

local function ufo(ctx, x: number, y: number, z: number)
	local metal = rgb(196, 202, 226)
	cyl(ctx, "Ufo", x, y, z, 11, 2, metal, M.SmoothPlastic, { Glow = true })
	cyl(ctx, "Ufo", x, y + 2, z, 7, 1.3, metal:Lerp(WHITE, 0.3), M.SmoothPlastic, { Glow = true })
	cyl(ctx, "Ufo", x, y - 1.2, z, 6.5, 1.2, rgb(110, 114, 146), M.SmoothPlastic, { Glow = true })
	cyl(ctx, "Ufo-Ring", x, y + 0.75, z, 11.35, 0.5, SPACE_CYAN, M.Neon, { Glow = true })
	ball(ctx, "Ufo-Kuppel", x, y + 2.6, z, 9.5, SPACE_CYAN, M.SmoothPlastic, { Glow = true, Transparency = 0.62 })
	ball(ctx, "Ufo-Pilot", x, y + 4.4, z, 2.6, rgb(120, 255, 140), M.SmoothPlastic, { Glow = true })
	for i = 1, 10 do
		local a = math.rad(i * 36)
		ball(ctx, "Ufo-Licht", x + math.cos(a) * 10.4, y + 1, z + math.sin(a) * 10.4, 1.3, STAR_COLORS[i % #STAR_COLORS + 1], M.Neon, { Glow = true })
	end
	local beam = cyl(ctx, "Ufo-Strahl", x, 0, z, 5, y - 1.2, SPACE_CYAN, M.Neon, { Glow = true, Transparency = 0.82 })
	light(beam, SPACE_CYAN, 30, 1.2)
	cyl(ctx, "Ufo-Lichtfleck", x, -0.4, z, 5.6, 0.5, SPACE_CYAN, M.Neon, { Glow = true, Transparency = 0.4 })
end

THEMES.Galaxie = function(ctx)
	local style = { Top = rgb(50, 42, 104), TopMat = M.Slate, Rim = rgb(96, 84, 210), Rock = rgb(34, 28, 66) }
	ground(ctx, style)
	plaza(ctx, 0, 78, 15, rgb(72, 62, 150), SPACE_CYAN)
	pathLine(ctx, 0, 64, 0, 26, 9, rgb(66, 56, 138))
	for _, x in { -4.9, 4.9 } do
		pathLine(ctx, x, 62.4, x, 26.6, 0.5, SPACE_CYAN, M.Neon, 0.2, "Wegleuchte", { Glow = true })
	end
	plaza(ctx, 0, 0, 26, rgb(66, 56, 138), rgb(255, 150, 240))

	-- Wahrzeichen: die Rakete auf ihrer Startrampe
	rocket(ctx)


	-- Mond-Station: Kuppeln mit Leuchtring und Tür zur Inselmitte
	for _, spot in { { -62, -34, 13 }, { -50, 46, 10 }, { 66, 36, 12 }, { 20, -78, 10 }, { -84, 6, 9 } } do
		local x, z, d = spot[1], spot[2], spot[3]
		local origin = ctx.Origin
		ctx.Origin = origin * CFrame.new(x, 0, z) * facing(math.deg(math.atan2(-z, -x)))
		ball(ctx, "Kuppel", 0, -0.5, 0, d, rgb(232, 234, 248), M.SmoothPlastic)
		local ring = cyl(ctx, "Kuppelring", 0, 0, 0, d / 2 + 0.5, 0.6, pick(ctx, STAR_COLORS), M.Neon, { Glow = true })
		light(ring, ring.Color, d * 1.6, 1)
		block(ctx, "Kuppeltuer", 0, 1.9, d / 2 - 0.5, 3.2, 3.8, 1.6, rgb(92, 94, 118), M.Metal)
		block(ctx, "Kuppeltuer", 0, 1.8, d / 2 + 0.32, 2.2, 3, 0.1, SPACE_CYAN, M.Neon, { Glow = true })
		ball(ctx, "Kuppelfenster", d * 0.3, d * 0.22, d * 0.16, d * 0.42, SPACE_CYAN, M.Neon, { Glow = true })
		cyl(ctx, "Kuppelantenne", 0, d / 2 - 0.8, 0, 0.18, 3.4, rgb(150, 156, 180), M.Metal, { Ghost = true })
		ball(ctx, "Antennenlicht", 0, d / 2 + 2.8, 0, 0.7, rgb(255, 80, 80), M.Neon, { Glow = true })
		ctx.Origin = origin
		blocker(ctx, x, z, d / 2 + 2)
	end

	-- Sternen-Sprenkel im Boden
	scatter(ctx, 80, 12, 100, 2.5, nil, function(x, z)
		local s = rn(ctx, 0.5, 1.3)
		block(ctx, "Sprenkel", x, -0.1 + rn(ctx, 0, 0.02), z, s, 0.3, s, pick(ctx, STAR_COLORS), M.Neon, { Glow = true, Rot = CFrame.Angles(0, math.rad(45), 0) })
	end)
	-- Krater
	scatter(ctx, 8, 34, 88, 8, false, function(x, z)
		local r = rn(ctx, 5, 8)
		cyl(ctx, "Krater", x, -0.3, z, r, 0.65, rgb(84, 74, 160), M.Slate, { Ghost = true })
		cyl(ctx, "Krater", x, -0.2, z, r * 0.76, 0.6, rgb(36, 30, 78), M.Slate, { Ghost = true })
	end)
	scatter(ctx, 13, 30, 92, 2.4, true, function(x, z)
		starCrystal(ctx, x, z, pick(ctx, STAR_COLORS))
	end)
	scatter(ctx, 16, 28, 96, 1.5, false, function(x, z)
		alienPlant(ctx, x, z, rn(ctx, 0.8, 1.3), pick(ctx, { rgb(255, 150, 240), SPACE_CYAN, rgb(190, 140, 255) }))
	end)
	-- Antennen-Schüsseln
	scatter(ctx, 3, 40, 84, 3, true, function(x, z)
		cyl(ctx, "Antennenmast", x, 0, z, 0.45, 9, rgb(150, 156, 180), M.Metal)
		local tilt = facing(rn(ctx, 0, 360)) * CFrame.Angles(math.rad(48), 0, 0)
		cyl(ctx, "Antennenschuessel", x, 9, z, 3.4, 0.5, rgb(236, 238, 248), nil, { Ghost = true, Rot = tilt })
		cyl(ctx, "Antennenschuessel", x, 9.2, z, 0.5, 2.2, rgb(150, 156, 180), M.Metal, { Ghost = true, Rot = tilt })
		local tip = ball(ctx, "Antennenlicht", x, 11.6, z, 0.9, rgb(255, 80, 80), M.Neon, { Glow = true })
		light(tip, rgb(255, 80, 80), 10, 1)
	end)

	ufo(ctx, 58, 27, -44)
	keep(ctx, 58, -44, 6)
	-- Leuchtbäume: hoher Stiel mit drei Leuchtkugeln
	scatter(ctx, 10, 36, 94, 3, true, function(x, z)
		local color = pick(ctx, { rgb(255, 150, 240), SPACE_CYAN, rgb(190, 140, 255), rgb(255, 235, 130) })
		local h = rn(ctx, 10, 15)
		cyl(ctx, "Leuchtbaum", x, 0, z, 0.6, h, rgb(40, 190, 180), M.Neon, { CastShadow = false })
		for i = 1, 3 do
			local a = math.rad(i * 120 + rn(ctx, -20, 20))
			local d = rn(ctx, 2.6, 3.8)
			local bulb = ball(ctx, "Leuchtkugel", x + math.cos(a) * 1.9, h - (i - 1) * 2.4, z + math.sin(a) * 1.9, d, color:Lerp(WHITE, (i - 1) * 0.15), M.Neon, { Glow = true })
			if i == 1 then
				light(bulb, color, 20, 1.2)
			end
		end
		ball(ctx, "Leuchtkugel", x, h + 1.4, z, 3.4, color, M.Neon, { Glow = true })
	end)
	-- Mondfelsen mit leuchtendem Band
	scatter(ctx, 9, 34, 96, 4, true, function(x, z)
		local d = rn(ctx, 6, 10)
		ball(ctx, "Mondfels", x, d * 0.12, z, d, rgb(62, 54, 122), M.Slate)
		ball(ctx, "Mondfels", x + d * 0.42, d * 0.02, z + d * 0.2, d * 0.6, rgb(74, 64, 140), M.Slate, { Ghost = true })
	end)

	-- Planeten, Mond und Sterne am Himmel
	planet(ctx, -70, 62, -60, 30, rgb(255, 150, 90), rgb(255, 220, 150))
	planet(ctx, 95, 85, 30, 22, rgb(90, 200, 220), nil)
	planet(ctx, -130, 40, 70, 26, rgb(200, 120, 255), rgb(255, 170, 240))
	planet(ctx, 30, 105, -120, 38, rgb(255, 120, 170), rgb(255, 210, 230))
	planet(ctx, 150, 30, -90, 16, rgb(130, 230, 150), nil)
	planet(ctx, -40, 95, 120, 18, rgb(255, 215, 110), rgb(255, 245, 200))
	ball(ctx, "Mond", -150, 70, -150, 64, rgb(122, 120, 142), M.Neon, { Glow = true })
	for _ = 1, 70 do
		local a = rn(ctx, 0, math.pi * 2)
		local r = rn(ctx, 115, 270)
		ball(ctx, "Sternchen", math.cos(a) * r, rn(ctx, -20, 170), math.sin(a) * r, rn(ctx, 0.8, 2.2), pick(ctx, STAR_COLORS), M.Neon, { Glow = true })
	end
	-- Asteroiden rund um die Insel
	for _ = 1, 16 do
		local a = rn(ctx, 0, math.pi * 2)
		local r = rn(ctx, 122, 170)
		local d = rn(ctx, 5, 14)
		ball(ctx, "Asteroid", math.cos(a) * r, rn(ctx, -22, 34), math.sin(a) * r, d, rgb(52, 46, 88), M.Slate, { Glow = true })
	end

	rim(ctx, 30, function(x, z, _, i)
		rimRock(ctx, x, z, i, rgb(44, 38, 92):Lerp(rgb(70, 60, 140), rn(ctx, 0, 1)))
		if i % 2 == 0 then
			ball(ctx, "Randleuchte", x * 0.94, 1.2, z * 0.94, 2.2, pick(ctx, STAR_COLORS), M.Neon, { Glow = true })
		end
	end)

	-- Sternenstaub
	ambient(ctx, 18, 34, {
		Rate = 26,
		Lifetime = NumberRange.new(6, 9),
		Speed = NumberRange.new(0.3, 1),
		SpreadAngle = Vector2.new(180, 180),
		Size = NumberSequence.new(0.4),
		Color = ColorSequence.new(WHITE, rgb(160, 220, 255)),
		Transparency = FADE,
		LightEmission = 1,
	})

	local isletList = { { 35, 150, 16, 12 }, { 120, 156, -4, 14 }, { 210, 150, 26, 11 }, { 290, 164, 8, 13 } }
	isletSpikes(ctx, isletList, style)
	hangingSpikes(ctx, style, SPACE_CYAN)
	islets(ctx, isletList, style, function(sub)
		starCrystal(sub, 0, 0, pick(sub, STAR_COLORS))
	end)
	return style
end

-- Eine Welt bauen ---------------------------------------------------------------------------
-- center = Inselmitte (y wird ignoriert), floorY = Oberkante Boden
function Islands.Build(parent: Instance, world, center: Vector3, floorY: number)
	local folder = Instance.new("Folder")
	folder.Name = world.Id
	local ctx = {
		Folder = folder,
		Origin = CFrame.new(center.X, floorY, center.Z),
		R = RADIUS,
		Rng = Random.new(world.Rebirths * 97 + 5),
		Blockers = {},
		Keep = {},
	}
	-- Platz fürs Rück-Portal freihalten, bevor die Deko verteilt wird
	blocker(ctx, 0, 92, 12)
	local theme = THEMES[world.Id] or THEMES.Kristall
	local style = theme(ctx)

	-- Rück-Portal am Ankunftsplatz (man läuft nach Süden hinein)
	local portal = Islands.Portal(folder, ctx.Origin * CFrame.lookAt(Vector3.new(0, 0, 92), Vector3.new(0, 0, 100)), {
		Color = rgb(110, 235, 140),
		Title = "🏝️ Zurück zur Insel",
		Subtitle = "Hier geht's nach Hause",
		Stone = style.Rock:Lerp(WHITE, 0.12),
	})
	folder.Parent = parent

	local origin = ctx.Origin
	local blockers = ctx.Blockers
	local rng = Random.new()
	return {
		Folder = folder,
		Center = origin.Position,
		Radius = RADIUS,
		Portal = portal,
		-- hier kommt man an (Blick zur Inselmitte)
		Spawn = origin * CFrame.lookAt(Vector3.new(0, 3.5, 78), Vector3.new(0, 3.5, 0)),
		-- zufälliger freier Punkt auf dem Boden (für Münzen und wilde Monster)
		RandomPoint = function(): Vector3
			for _ = 1, 30 do
				local a = rng:NextNumber(0, math.pi * 2)
				local r = math.sqrt(rng:NextNumber(0, (RADIUS - 14) ^ 2))
				local x, z = math.cos(a) * r, math.sin(a) * r
				if not inAny(blockers, x, z, 2.5) then
					return origin * Vector3.new(x, 0, z)
				end
			end
			return origin * Vector3.new(0, 0, 70)
		end,
	}
end

return Islands
