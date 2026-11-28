-- Events alle paar Minuten: Meteor, Goldrausch, Diebes-Nacht, Klick-Fieber.
-- Vorher läuft ein Countdown. Der Client liest die Attribute an workspace:
--   EventName ("Meteor", "Goldrausch", ...), EventTitle (Text), EventPhase ("warn" / "active" / nil),
--   EventEndsAt (Serverzeit), EventTarget (Vector3: dorthin zeigt der Wegweiser-Pfeil)
-- Die Optik dazu (goldenes Licht, Pfeil, Nacht-Stimmung) macht der Client in EventEffekte.luau.
-- Alle Werte stehen in Config.Events.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local CreatureModels = require(script.Parent.CreatureModels)
local FX = require(script.Parent.FX)
local Map = require(script.Parent.Map)
local Bases = require(script.Parent.Bases)
local Steal = require(script.Parent.Steal)
local Clicker = require(script.Parent.Clicker)

local Events = {}

local TITLES = {
	Meteor = "☄️ METEOR",
	Goldrausch = "💰 GOLDRAUSCH",
	Diebesnacht = "🌙 DIEBES-NACHT",
	Klickfieber = "🔥 KLICK-FIEBER",
}
local COLORS = {
	Meteor = Color3.fromRGB(255, 140, 40),
	Goldrausch = Color3.fromRGB(255, 215, 50),
	Diebesnacht = Color3.fromRGB(150, 120, 255),
	Klickfieber = Color3.fromRGB(255, 110, 50),
}
local RED = Color3.fromRGB(255, 90, 90)
local GREEN = Color3.fromRGB(120, 255, 140)
local BLUE = Color3.fromRGB(120, 200, 255)

local folder
local remotes
local wildItems = {} -- [id] = { Entry, Model, ExpiresAt, Opts }
local nextWildId = 0
local meteorId: number? = nil -- die Kreatur des laufenden Meteor-Events
local targetId: number? = nil -- die wilde Kreatur, auf die der Wegweiser-Pfeil gerade zeigt

local function setPhase(name: string?, phase: string?, seconds: number?)
	workspace:SetAttribute("EventName", name)
	workspace:SetAttribute("EventTitle", name and TITLES[name] or nil)
	workspace:SetAttribute("EventPhase", phase)
	workspace:SetAttribute("EventEndsAt", seconds and workspace:GetServerTimeNow() + seconds or nil)
end

-- Wohin der Pfeil am Bildschirmrand zeigt (nil = kein Pfeil)
local function setTarget(position: Vector3?)
	workspace:SetAttribute("EventTarget", position)
end

-- Boden unter einem Punkt finden (für herunterfallende Beute)
local function groundBelow(position: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace:FindFirstChild("KreaturenMap") }
	local result = workspace:Raycast(position + Vector3.new(0, 5, 0), Vector3.new(0, -100, 0), params)
	return if result then result.Position else Vector3.new(position.X, 2, position.Z)
end

-- Wilde Kreatur auf den Boden legen, die man schnappen kann.
-- opts (für die Welten, beim Meteor leer): Tag = Kennung zum Zählen, How = Text für die große Ansage,
-- OnGrab = function(player, entry) statt der Meteor-Ansage, Silent = verschwindet ohne Ansage
local function placeWild(entry: string, position: Vector3, lifetime: number, opts: { [string]: any }?): number
	nextWildId += 1
	local id = nextWildId
	local def, mutation = Config.ParseEntry(entry)
	local model = CreatureModels.Build(def, { Label = true, Mutation = mutation })
	model:PivotTo(CFrame.new(groundBelow(position)) * CFrame.Angles(0, math.random() * math.pi * 2, 0))
	local body = model.PrimaryPart

	-- Lichtsäule, damit man sie von weit sieht
	local beam = Instance.new("Part")
	beam.Name = "Lichtsaeule"
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false
	beam.CastShadow = false
	beam.Material = Enum.Material.Neon
	beam.Color = Config.Rarities[def.Rarity].Color
	beam.Transparency = 0.5
	beam.Size = Vector3.new(2, 150, 2)
	beam.CFrame = CFrame.new(body.Position + Vector3.new(0, 75, 0))
	beam.Parent = model

	local highlight = Instance.new("Highlight")
	highlight.FillColor = Config.Rarities[def.Rarity].Color
	highlight.FillTransparency = 0.6
	highlight.Parent = model

	local p = Map.MakePrompt(body, "Wild", "Schnappen!", Config.EntryName(entry), Config.Events.Meteor.GrabTime, 10)
	p:SetAttribute("WildId", id)

	model.Parent = folder
	wildItems[id] = { Entry = entry, Model = model, ExpiresAt = os.clock() + lifetime, Opts = opts }
	if not opts then
		-- Meteor-Kreatur (auch wenn sie fallen gelassen wurde): der Pfeil zeigt dorthin
		targetId = id
		setTarget(body.Position)
	end
	return id
end
Events.PlaceWild = placeWild

-- Wie viele wilde Kreaturen mit dieser Kennung liegen gerade herum?
function Events.CountWild(tag: string): number
	local n = 0
	for _, item in wildItems do
		if item.Opts and item.Opts.Tag == tag then
			n += 1
		end
	end
	return n
end

function Events.Grab(player: Player, id: number)
	local item = wildItems[id]
	if not item then
		return
	end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root or (item.Model:GetPivot().Position - root.Position).Magnitude > 16 then
		return
	end
	local entry = item.Entry
	local opts = item.Opts
	local ok = Steal.StartWild(player, entry, function(dropPos: Vector3?)
		-- Fallen gelassen: liegt wieder rum (noch 30 Sekunden)
		placeWild(entry, dropPos or Map.RandomStreetPoint(), 30, opts)
	end, opts and opts.How)
	if ok then
		wildItems[id] = nil
		item.Model:Destroy()
		if id == meteorId then
			meteorId = nil -- geschnappt: das Meteor-Event ist vorbei
		end
		if id == targetId then
			targetId = nil
			setTarget(nil)
		end
		if opts and opts.OnGrab then
			opts.OnGrab(player, entry)
		else
			Bases.Announce(`{player.DisplayName} hat die Meteor-Kreatur! Haut den Dieb!`, COLORS.Meteor)
		end
	end
end

-- Meteor -----------------------------------------------------------------------
-- Schon während der Warnung steht fest, wo er einschlägt: roter Zielkreis am Boden.
local function prepareMeteor()
	local cfg = Config.Events.Meteor
	local target = Map.RandomStreetPoint()
	local marks = Instance.new("Folder")
	marks.Name = "MeteorZiel"

	local ring = Instance.new("Part")
	ring.Name = "Zielkreis"
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.fromRGB(255, 50, 40)
	ring.Transparency = 0.45
	ring.Size = Vector3.new(0.3, cfg.TargetRadius * 2, cfg.TargetRadius * 2)
	ring.CFrame = CFrame.new(target + Vector3.new(0, 0.25, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = marks
	TweenService:Create(ring, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Transparency = 0.8 }):Play()

	-- dünne rote Säule, damit man die Stelle von weit sieht
	local pillar = Instance.new("Part")
	pillar.Name = "Zielsaeule"
	pillar.Anchored = true
	pillar.CanCollide = false
	pillar.CanQuery = false
	pillar.CanTouch = false
	pillar.CastShadow = false
	pillar.Material = Enum.Material.Neon
	pillar.Color = Color3.fromRGB(255, 70, 50)
	pillar.Transparency = 0.6
	pillar.Size = Vector3.new(1.2, 160, 1.2)
	pillar.CFrame = CFrame.new(target + Vector3.new(0, 80, 0))
	pillar.Parent = marks

	marks.Parent = folder
	targetId = nil -- eine alte, fallen gelassene Meteor-Kreatur bestimmt den Pfeil jetzt nicht mehr
	setTarget(target)
	return { Target = target, Marks = marks }
end

local function runMeteor(prep)
	local cfg = Config.Events.Meteor
	local target: Vector3 = prep.Target

	local meteor = Instance.new("Part")
	meteor.Name = "Meteor"
	meteor.Shape = Enum.PartType.Ball
	meteor.Size = Vector3.new(8, 8, 8)
	meteor.Anchored = true
	meteor.CanCollide = false
	meteor.Material = Enum.Material.Neon
	meteor.Color = Color3.fromRGB(255, 120, 30)
	meteor.CFrame = CFrame.new(target + Vector3.new(120, 250, 40))
	local fire = Instance.new("Fire")
	fire.Size = 15
	fire.Heat = 20
	fire.Parent = meteor
	meteor.Parent = folder

	local fall = TweenService:Create(meteor, TweenInfo.new(3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ CFrame = CFrame.new(target + Vector3.new(0, 4, 0)) })
	fall:Play()
	fall.Completed:Wait()
	meteor:Destroy()
	prep.Marks:Destroy()

	local boom = Instance.new("Explosion")
	boom.Position = target
	boom.BlastPressure = 0 -- nur Optik, kein Schaden
	boom.DestroyJointRadiusPercent = 0
	boom.BlastRadius = 15
	boom.Parent = workspace
	FX.Burst(target + Vector3.new(0, 2, 0), COLORS.Meteor, 120)
	FX.Ring(target + Vector3.new(0, 0.3, 0), COLORS.Meteor, cfg.TargetRadius * 2.5)
	-- Wumms und Kamera-Wackeln macht jeder Client selbst (je näher, desto stärker)
	remotes.EventFx:FireAllClients("MeteorImpact", target)

	-- Die Kreatur kommt aus der besten Kiste, die alle Spieler auf dem Server schon kaufen dürfen
	local lowest = math.huge
	for _, player in Players:GetPlayers() do
		local state = Bases.GetState(player)
		if state then
			lowest = math.min(lowest, state.Data.Rebirths)
		end
	end
	local pack = Config.BestPack(if lowest == math.huge then 0 else lowest)
	local def = Config.RandomCreatureOfRarity(Config.RollWeighted(cfg.Weights), pack)
	local rarity = def.Rarity
	local entry = Config.MakeEntry(def.Id, Config.RollWeighted(cfg.MutationWeights))
	local id = placeWild(entry, target, cfg.Duration)
	meteorId = id
	Bases.Announce(`☄️ Meteor gelandet: {Config.Upper(Config.Rarities[rarity].Name)} {Config.EntryName(entry)}! Folge dem Pfeil!`,
		Config.Rarities[rarity].Color)
	setPhase("Meteor", "active", cfg.Duration)
	-- Läuft, bis die Zeit um ist oder jemand die Kreatur schnappt (dann ist der Countdown sofort weg)
	local endAt = os.clock() + cfg.Duration
	while meteorId == id and os.clock() < endAt do
		task.wait(0.25)
	end
	if meteorId == id then
		meteorId = nil
	end
end

-- Bilanz am Ende eines Geld-Events: jedem zeigen, was er in der Zeit verdient hat
local function showEarned(earned: { [Player]: number }?, text: string, color: Color3)
	for player, amount in earned or {} do
		if amount >= 1 then
			Bases.BigText(player, string.format(text, Config.FormatNumber(math.floor(amount))), color, "EventEnd")
		end
	end
end

-- Goldrausch ---------------------------------------------------------------------
local function runGoldrausch()
	local cfg = Config.Events.Goldrausch
	Bases.IncomeMultiplier = cfg.IncomeMultiplier
	Bases.EventEarned = {}
	Bases.Announce(`💰 GOLDRAUSCH! {cfg.Duration} Sekunden x{cfg.IncomeMultiplier} Geld, auch für jeden Klick!`, COLORS.Goldrausch)
	setPhase("Goldrausch", "active", cfg.Duration)
	task.wait(cfg.Duration)
	Bases.IncomeMultiplier = 1
	local earned = Bases.EventEarned
	Bases.EventEarned = nil
	showEarned(earned, "💰 Goldrausch vorbei: +%s $ verdient!", COLORS.Goldrausch)
end

-- Klick-Fieber -------------------------------------------------------------------
local function runKlickfieber()
	local cfg = Config.Events.Klickfieber
	local fever = { ComboSpeed = cfg.ComboSpeed, CritFactor = cfg.CritFactor, Clicks = {}, Money = {} }
	Clicker.Fever = fever
	Bases.Announce(`🔥 KLICK-FIEBER! {cfg.Duration} Sekunden: Die Combo reißt nicht ab, Volltreffer x{cfg.CritFactor}. Klick, klick, klick!`,
		COLORS.Klickfieber)
	setPhase("Klickfieber", "active", cfg.Duration)
	task.wait(cfg.Duration)
	Clicker.Fever = nil
	-- Bilanz: nur das Geld aus den Klicks
	for player, clicks in fever.Clicks do
		Bases.BigText(player, `🔥 Fieber vorbei: {clicks} Klicks, +{Config.FormatNumber(math.floor(fever.Money[player] or 0))} $!`,
			COLORS.Klickfieber, "EventEnd")
	end
end

-- Diebes-Nacht mit Schatten-Dieben -----------------------------------------------
local SHADOW_MARK = "Schatten" -- steht in plot.Stolen, solange ein Schatten das Monster hat
local SHADOW_COLOR = Color3.fromRGB(170, 120, 255)
local shadows = {} -- Liste: { Model, Owner, Plot, Slot, Phase, Position, Target, Home, Timer, Entry, Carried }
local nightStats: { [Player]: { Hits: number, Money: number } }? = nil
local kidnapped = {} -- Liste: { Plot, Slot, Owner, Entry }, kommen am Morgen zurück

local function shadowPart(model: Model, name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = offset
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

-- Kleiner dunkler Dieb mit leuchtenden Augen. Er gleitet durch Wände, darum sieht man
-- seinen Umriss auch durch das Haus hindurch.
local function buildShadow(): Model
	local model = Instance.new("Model")
	model.Name = "SchattenDieb"
	local dark = Color3.fromRGB(28, 16, 48)
	local body = shadowPart(model, "Koerper", Vector3.new(2.2, 2.8, 1.6), CFrame.new(0, 1.6, 0), dark, Enum.Material.SmoothPlastic)
	body.Transparency = 0.1
	local head = shadowPart(model, "Kopf", Vector3.new(2, 2, 2), CFrame.new(0, 3.9, 0), dark, Enum.Material.SmoothPlastic)
	head.Shape = Enum.PartType.Ball
	head.Transparency = 0.1
	shadowPart(model, "AugeL", Vector3.new(0.4, 0.3, 0.2), CFrame.new(-0.42, 4.05, -0.9), SHADOW_COLOR, Enum.Material.Neon)
	shadowPart(model, "AugeR", Vector3.new(0.4, 0.3, 0.2), CFrame.new(0.42, 4.05, -0.9), SHADOW_COLOR, Enum.Material.Neon)
	-- Sack auf dem Rücken
	local sack = shadowPart(model, "Sack", Vector3.new(1.6, 1.6, 1.6), CFrame.new(0, 2.2, 1.2), Color3.fromRGB(60, 45, 80), Enum.Material.Fabric)
	sack.Shape = Enum.PartType.Ball
	model.PrimaryPart = body

	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Color = ColorSequence.new(Color3.fromRGB(70, 40, 120), Color3.fromRGB(15, 10, 25))
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.4), NumberSequenceKeypoint.new(1, 0.2) })
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
	smoke.Lifetime = NumberRange.new(0.6, 1)
	smoke.Speed = NumberRange.new(1, 2)
	smoke.Rate = 14
	smoke.Parent = body

	local light = Instance.new("PointLight")
	light.Color = SHADOW_COLOR
	light.Range = 10
	light.Brightness = 1.5
	light.Parent = head

	local glow = Instance.new("Highlight")
	glow.FillColor = Color3.fromRGB(110, 60, 210)
	glow.FillTransparency = 0.65
	glow.OutlineColor = SHADOW_COLOR
	glow.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	glow.Parent = model

	local sign = Instance.new("BillboardGui")
	sign.Size = UDim2.fromOffset(170, 28)
	sign.StudsOffsetWorldSpace = Vector3.new(0, 4.2, 0)
	sign.AlwaysOnTop = true
	sign.MaxDistance = 140
	sign.Adornee = head
	sign.Parent = head
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextColor3 = SHADOW_COLOR
	text.TextStrokeTransparency = 0.2
	text.Text = "👤 Schatten-Dieb"
	text.Parent = sign
	return model
end

-- Schatten (und was er trägt) an seine Stelle setzen, er schaut in Laufrichtung und wippt
local function placeShadow(s, look: Vector3?)
	local bob = math.sin(os.clock() * 7 + s.Seed) * 0.25
	local at = s.Position + Vector3.new(0, bob, 0)
	local flat = if look then Vector3.new(look.X, 0, look.Z) else Vector3.zero
	local cf = if flat.Magnitude > 0.01 then CFrame.lookAt(at, at + flat) else CFrame.new(at) * s.Facing
	s.Facing = cf.Rotation
	s.Model:PivotTo(cf * CFrame.new(0, 1.6, 0))
	if s.Carried then
		s.Carried:PivotTo(cf * CFrame.new(0, 6.2, 0))
	end
end

-- Das Monster, das ein Schatten hat, steht wieder in der Base
local function giveBack(plot, slot: number, owner: Player, text: string?)
	if plot.Stolen[slot] ~= SHADOW_MARK then
		return
	end
	plot.Stolen[slot] = nil
	local oState = Bases.GetState(owner)
	if oState and oState.Plot == plot then
		Bases.RenderSlot(oState, slot)
		local entry = oState.Data.Slots[tostring(slot)]
		if text and entry then
			Bases.Notify(owner, string.format(text, Config.EntryName(entry)), GREEN)
		end
	end
end

local function removeShadow(index: number, puff: boolean)
	local s = shadows[index]
	table.remove(shadows, index)
	if puff then
		FX.Burst(s.Position + Vector3.new(0, 3, 0), SHADOW_COLOR, 45)
	end
	if s.Carried then
		s.Carried:Destroy()
	end
	s.Model:Destroy()
end

-- Welches Monster holt sich der Schatten? Ein zufälliges, aber nie das im Tresor.
local function pickSlot(state): number?
	local vault = if Bases.Skill(state, "Vault") > 0 then Bases.BestSlot(state) else nil
	local slots = {}
	for slotKey, _ in state.Data.Slots do
		local slot = tonumber(slotKey)
		if slot and slot ~= vault and not state.Plot.Stolen[slot] then
			table.insert(slots, slot)
		end
	end
	return if #slots > 0 then slots[math.random(#slots)] else nil
end

local function spawnShadows()
	local S = Config.Events.Diebesnacht.Shadows
	local floorY = Map.RandomStreetPoint().Y -- Höhe des Straßenbodens
	for player, state in Bases.States do
		local plot = state.Plot
		local count = 0
		for _, s in shadows do
			if s.Plot == plot then
				count += 1
			end
		end
		-- Wer gerade in einer Welt unterwegs ist, bleibt verschont (er könnte sich nicht wehren)
		local world = player:GetAttribute("World")
		local away = type(world) == "string" and world ~= ""
		local slot = if plot and not away and count < S.MaxPerBase then pickSlot(state) else nil
		if slot then
			local target = Map.SlotCFrame(plot, slot).Position
			-- Er kommt von der Straße vor der Base
			local street = Config.Map.StreetWidth / 2 - 3
			local home = Vector3.new(target.X + math.random(-20, 20), floorY, (math.random() * 2 - 1) * street)
			local s = {
				Model = buildShadow(),
				Owner = player,
				Plot = plot,
				Slot = slot,
				Phase = "come",
				Position = home,
				Target = Vector3.new(target.X, target.Y, target.Z),
				Home = home,
				Timer = 0,
				Seed = math.random() * 6,
				Facing = CFrame.new(),
			}
			placeShadow(s, s.Target - s.Position)
			s.Model.Parent = folder
			table.insert(shadows, s)
			FX.Burst(home + Vector3.new(0, 3, 0), SHADOW_COLOR, 25)
			Bases.Notify(player, "👤 Ein Schatten-Dieb schleicht zu deiner Base! Hau ihn mit der Klatsche!", SHADOW_COLOR)
			remotes.EventFx:FireClient(player, "Shadow")
		end
	end
end

-- Schritt Richtung Ziel. Gibt true zurück, wenn er angekommen ist.
local function glide(s, goal: Vector3, speed: number, dt: number): boolean
	local delta = goal - s.Position
	local step = speed * dt
	if delta.Magnitude <= step then
		s.Position = goal
		placeShadow(s, nil)
		return true
	end
	s.Position += delta.Unit * step
	placeShadow(s, delta)
	return false
end

local function stepShadows(dt: number)
	local S = Config.Events.Diebesnacht.Shadows
	for i = #shadows, 1, -1 do
		local s = shadows[i]
		local oState = Bases.GetState(s.Owner)
		if not oState or oState.Plot ~= s.Plot then
			-- Besitzer ist weg: der Schatten löst sich auf
			s.Plot.Stolen[s.Slot] = if s.Plot.Stolen[s.Slot] == SHADOW_MARK then nil else s.Plot.Stolen[s.Slot]
			removeShadow(i, true)
		elseif s.Phase == "come" then
			if glide(s, s.Target, S.Speed, dt) then
				s.Phase = "grab"
				s.Timer = S.GrabTime
			end
		elseif s.Phase == "grab" then
			s.Timer -= dt
			placeShadow(s, nil)
			if s.Timer <= 0 then
				local entry = oState.Data.Slots[tostring(s.Slot)]
				if entry and not s.Plot.Stolen[s.Slot] then
					s.Plot.Stolen[s.Slot] = SHADOW_MARK
					Bases.RenderSlot(oState, s.Slot)
					s.Entry = entry
					local def, mutation, stars = Config.ParseEntry(entry)
					if def then
						local carried = CreatureModels.Build(def, { Scale = 0.55, Mutation = mutation, Stars = stars })
						for _, part in carried:GetDescendants() do
							if part:IsA("BasePart") then
								part.Anchored = true
								part.CanCollide = false
								part.CanQuery = false
							end
						end
						carried.Name = "SchattenBeute"
						carried.Parent = folder
						s.Carried = carried
					end
					Bases.BigText(s.Owner, "👤 EIN SCHATTEN KLAUT!", RED, "Stolen", true)
					Bases.Notify(s.Owner, `Ein Schatten hat {Config.EntryName(entry)}! Hau ihn, bevor er entkommt!`, RED)
				end
				s.Phase = "flee"
			end
		elseif glide(s, s.Home, if s.Entry then S.FleeSpeed else S.Speed, dt) then
			-- entkommen
			if s.Entry then
				table.insert(kidnapped, { Plot = s.Plot, Slot = s.Slot, Owner = s.Owner })
				Bases.Notify(s.Owner, `{Config.EntryName(s.Entry)} ist entführt und kommt erst am Morgen zurück!`, RED)
			end
			removeShadow(i, true)
		end
	end
end

-- Die Klatsche trifft auch Schatten (eingehängt in Steal.Hit)
local function hitShadows(hitter: Player, position: Vector3, range: number): boolean
	local S = Config.Events.Diebesnacht.Shadows
	local hState = Bases.GetState(hitter)
	local hit = false
	for i = #shadows, 1, -1 do
		local s = shadows[i]
		if (s.Position - position).Magnitude <= range + 2 then
			hit = true
			if s.Entry then
				giveBack(s.Plot, s.Slot, s.Owner, "%s ist zurück!")
			end
			removeShadow(i, true)
			if hState then
				local reward = math.floor(math.max(S.RewardMin, Bases.Income(hState) * S.RewardSeconds))
				Bases.AddMoney(hState, reward)
				remotes.MoneyPopup:FireClient(hitter, reward)
				Bases.Notify(hitter, `👤 Schatten verjagt: +{Config.FormatNumber(reward)} $`, GREEN)
				if math.random() < S.TokenChance then
					hState.Data.Tokens += 1
					Bases.RefreshStats(hState)
					Bases.Notify(hitter, "💠 Der Schatten hat ein Token fallen lassen!", BLUE)
				end
				if nightStats then
					local stats = nightStats[hitter] or { Hits = 0, Money = 0 }
					stats.Hits += 1
					stats.Money += reward
					nightStats[hitter] = stats
				end
			end
		end
	end
	return hit
end

-- Alle Schatten weg, alle entführten Monster zurück
local function clearShadows(text: string?)
	for i = #shadows, 1, -1 do
		local s = shadows[i]
		if s.Entry then
			giveBack(s.Plot, s.Slot, s.Owner, text)
		end
		removeShadow(i, true)
	end
	for _, k in kidnapped do
		giveBack(k.Plot, k.Slot, k.Owner, text)
	end
	table.clear(kidnapped)
end

local dayClock: number? = nil -- Uhrzeit vor der Nacht

local function endNight()
	if dayClock then
		TweenService:Create(Lighting, TweenInfo.new(2.5, Enum.EasingStyle.Sine), { ClockTime = dayClock }):Play()
		dayClock = nil
	end
	Bases.LocksDisabled = false
	Steal.WalkSpeed = Config.WalkSpeed
	Steal.CarrySpeed = Config.Steal.CarrySpeed
	Steal.ApplySpeeds()
	clearShadows("☀️ %s ist wieder da!")
end

local function runDiebesnacht()
	local cfg = Config.Events.Diebesnacht
	local S = cfg.Shadows
	-- Es wird in zwei Sekunden dunkel (die Uhr läuft vorwärts bis Mitternacht)
	dayClock = Lighting.ClockTime
	local dusk = TweenService:Create(Lighting, TweenInfo.new(2, Enum.EasingStyle.Sine), { ClockTime = 23.99 })
	dusk:Play()
	dusk.Completed:Once(function()
		if dayClock then
			Lighting.ClockTime = 0
		end
	end)
	Bases.LocksDisabled = true
	Bases.UnlockAll()
	Steal.WalkSpeed = cfg.WalkSpeed
	Steal.CarrySpeed = cfg.CarrySpeed
	Steal.ApplySpeeds()
	nightStats = {}
	Bases.Announce("🌙 DIEBES-NACHT! Schlösser aus, alle sind schneller, und Schatten-Diebe schleichen zu den Bases!", COLORS.Diebesnacht)
	setPhase("Diebesnacht", "active", cfg.Duration)

	local started = os.clock()
	local nextSpawn = S.First
	while true do
		local dt = RunService.Heartbeat:Wait()
		local elapsed = os.clock() - started
		if elapsed >= cfg.Duration then
			break
		end
		if elapsed >= nextSpawn then
			nextSpawn += S.Interval
			if cfg.Duration - elapsed > S.StopBefore then
				spawnShadows()
			end
		end
		stepShadows(math.min(dt, 0.2))
	end

	endNight()
	local stats = nightStats or {}
	nightStats = nil
	Bases.Announce("☀️ Die Nacht ist vorbei.", COLORS.Diebesnacht)
	for player, info in stats do
		Bases.BigText(player, `🌙 Nacht vorbei: {info.Hits} Schatten verjagt, +{Config.FormatNumber(info.Money)} $!`,
			COLORS.Diebesnacht, "EventEnd")
	end
end

-- Ablauf -------------------------------------------------------------------------
local PREPARE = { Meteor = prepareMeteor }
local RUNNERS = { Meteor = runMeteor, Goldrausch = runGoldrausch, Diebesnacht = runDiebesnacht, Klickfieber = runKlickfieber }

-- Falls in einem Event ein Fehler passiert: alles wieder auf normal stellen,
-- damit nicht z.B. der Goldrausch für immer weiterläuft.
local function resetAll()
	Bases.IncomeMultiplier = 1
	Bases.EventEarned = nil
	Clicker.Fever = nil
	nightStats = nil
	meteorId = nil
	endNight()
	local marks = folder and folder:FindFirstChild("MeteorZiel")
	if marks then
		marks:Destroy()
	end
	if not targetId then
		setTarget(nil)
	end
end

function Events.Run(name: string)
	if not RUNNERS[name] then
		return
	end
	local warnTime = Config.Events.Warning
	-- Alles in einem pcall: Ein Fehler darf die Event-Schleife nicht für immer anhalten
	local ok, err = pcall(function()
		local prep = if PREPARE[name] then PREPARE[name]() else nil
		Bases.Announce(`{TITLES[name]} in {warnTime} Sekunden!`, COLORS[name])
		setPhase(name, "warn", warnTime)
		task.wait(warnTime)
		RUNNERS[name](prep)
	end)
	if not ok then
		warn(`[Events] {name} ist abgebrochen: {err}`)
		resetAll()
	end
	-- Anzeige nur löschen, wenn sie noch zu diesem Event gehört
	if workspace:GetAttribute("EventName") == name then
		setPhase(nil, nil, nil)
	end
end

function Events.Start(parentFolder: Instance, remoteFolder: Instance)
	folder = Instance.new("Folder")
	folder.Name = "EventSachen"
	folder.Parent = parentFolder
	remotes = remoteFolder
	Steal.ExtraHit = hitShadows

	-- Wilde Kreaturen verschwinden nach Ablauf
	task.spawn(function()
		while true do
			task.wait(1)
			local now = os.clock()
			for id, item in wildItems do
				if now >= item.ExpiresAt then
					wildItems[id] = nil
					item.Model:Destroy()
					if id == targetId then
						targetId = nil
						setTarget(nil)
					end
					if not (item.Opts and item.Opts.Silent) then
						Bases.Announce("Die Meteor-Kreatur hat sich in Luft aufgelöst.", COLORS.Meteor)
					end
				end
			end
		end
	end)

	task.spawn(function()
		task.wait(Config.Events.FirstEventAfter)
		while true do
			Events.Run(Config.RollWeighted(Config.Events.Weights))
			task.wait(math.random(Config.Events.MinPause, Config.Events.MaxPause))
		end
	end)
end

return Events
