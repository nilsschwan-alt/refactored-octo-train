-- Events alle paar Minuten: Meteor, Goldrausch, Diebes-Nacht.
-- Vorher läuft ein Countdown. Der Client liest die Attribute an workspace:
--   EventTitle (Text), EventPhase ("warn" / "active" / nil), EventEndsAt (Serverzeit)

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local CreatureModels = require(script.Parent.CreatureModels)
local Map = require(script.Parent.Map)
local Bases = require(script.Parent.Bases)
local Steal = require(script.Parent.Steal)

local Events = {}

local TITLES = {
	Meteor = "☄️ METEOR",
	Goldrausch = "💰 GOLDRAUSCH",
	Diebesnacht = "🌙 DIEBES-NACHT",
}
local COLORS = {
	Meteor = Color3.fromRGB(255, 140, 40),
	Goldrausch = Color3.fromRGB(255, 215, 50),
	Diebesnacht = Color3.fromRGB(150, 120, 255),
}

local folder
local wildItems = {} -- [id] = { Entry, Model, ExpiresAt, Opts }
local nextWildId = 0

local function setPhase(name: string?, phase: string?, seconds: number?)
	workspace:SetAttribute("EventTitle", name and TITLES[name] or nil)
	workspace:SetAttribute("EventPhase", phase)
	workspace:SetAttribute("EventEndsAt", seconds and workspace:GetServerTimeNow() + seconds or nil)
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
local function placeWild(entry: string, position: Vector3, lifetime: number, opts: { [string]: any }?)
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
		if opts and opts.OnGrab then
			opts.OnGrab(player, entry)
		else
			Bases.Announce(`{player.DisplayName} hat die Meteor-Kreatur! Haut den Dieb!`, COLORS.Meteor)
		end
	end
end

-- Event-Abläufe ---------------------------------------------------------------
local function runMeteor()
	local cfg = Config.Events.Meteor
	local target = Map.RandomStreetPoint()

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

	local boom = Instance.new("Explosion")
	boom.Position = target
	boom.BlastPressure = 0 -- nur Optik, kein Schaden
	boom.DestroyJointRadiusPercent = 0
	boom.BlastRadius = 15
	boom.Parent = workspace

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
	placeWild(entry, target, cfg.Duration)
	Bases.Announce(`☄️ Meteor gelandet: {Config.Upper(Config.Rarities[rarity].Name)} {Config.EntryName(entry)}! Schnell hin!`,
		Config.Rarities[rarity].Color)
	setPhase("Meteor", "active", cfg.Duration)
	task.wait(cfg.Duration)
end

local function runGoldrausch()
	local cfg = Config.Events.Goldrausch
	Bases.IncomeMultiplier = cfg.IncomeMultiplier
	Bases.Announce(`💰 GOLDRAUSCH! {cfg.Duration} Sekunden x{cfg.IncomeMultiplier} Geld!`, COLORS.Goldrausch)
	setPhase("Goldrausch", "active", cfg.Duration)
	task.wait(cfg.Duration)
	Bases.IncomeMultiplier = 1
end

local function runDiebesnacht()
	local cfg = Config.Events.Diebesnacht
	local oldTime = Lighting.ClockTime
	Lighting.ClockTime = 0
	Bases.LocksDisabled = true
	Bases.UnlockAll()
	Steal.WalkSpeed = cfg.WalkSpeed
	Steal.CarrySpeed = cfg.CarrySpeed
	Steal.ApplySpeeds()
	Bases.Announce("🌙 DIEBES-NACHT! Alle Schlösser aus, alle sind schneller!", COLORS.Diebesnacht)
	setPhase("Diebesnacht", "active", cfg.Duration)
	task.wait(cfg.Duration)
	Lighting.ClockTime = oldTime
	Bases.LocksDisabled = false
	Steal.WalkSpeed = Config.WalkSpeed
	Steal.CarrySpeed = Config.Steal.CarrySpeed
	Steal.ApplySpeeds()
	Bases.Announce("☀️ Die Nacht ist vorbei.", COLORS.Diebesnacht)
end

local RUNNERS = { Meteor = runMeteor, Goldrausch = runGoldrausch, Diebesnacht = runDiebesnacht }

function Events.Run(name: string)
	local warnTime = Config.Events.Warning
	Bases.Announce(`{TITLES[name]} in {warnTime} Sekunden!`, COLORS[name])
	setPhase(name, "warn", warnTime)
	task.wait(warnTime)
	RUNNERS[name]()
	setPhase(nil, nil, nil)
end

function Events.Start(parentFolder: Instance)
	folder = Instance.new("Folder")
	folder.Name = "EventSachen"
	folder.Parent = parentFolder

	-- Wilde Kreaturen verschwinden nach Ablauf
	task.spawn(function()
		while true do
			task.wait(1)
			local now = os.clock()
			for id, item in wildItems do
				if now >= item.ExpiresAt then
					wildItems[id] = nil
					item.Model:Destroy()
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
