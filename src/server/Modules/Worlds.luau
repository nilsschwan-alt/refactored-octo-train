-- Welten: baut die vier Inseln und den Portal-Platz hinter dem Kisten-Shop, lässt Spieler
-- hin- und zurückreisen und sorgt in jeder Welt für wilde Monster.
-- Alle Werte (ab welcher Wiedergeburt, Klick-Bonus, wie oft ein Monster kommt) stehen in
-- Config.Worlds. Wie die Inseln aussehen, steht in WorldIslands.luau.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Bases = require(script.Parent.Bases)
local Steal = require(script.Parent.Steal)
local Events = require(script.Parent.Events)
local Map = require(script.Parent.Map)
local Islands = require(script.Parent.WorldIslands)

local Worlds = {}

local W = Config.Worlds
local DISTANCE = 2100 -- so weit liegen die Welten von der Hauptinsel weg

local RED = Color3.fromRGB(255, 90, 90)
local GREEN = Color3.fromRGB(110, 235, 140)

local remotes
local islands = {} -- [Welt-Id] = Rückgabe von Islands.Build
local portals = {} -- { CFrame, World (Ziel) oder From (Welt, aus der man heimkommt) }
local hubSpawn = {} -- [Welt-Id] = hier kommt man auf der Hauptinsel wieder an
local hubCenter: CFrame -- Mitte des Portal-Platzes (Ziel für den Knopf "Welten")
local wildNext = {} -- [Welt-Id] = os.clock(), ab wann das nächste wilde Monster kommen darf
local lastTravel = {} -- [player] = os.clock()
local lastNotice = {}
local lastHome = {}
local traveling = {} -- [player] = true, solange die Reise läuft

-- In welcher Welt liegt dieser Punkt? (nil = Hauptinsel)
function Worlds.At(position: Vector3)
	for id, island in islands do
		local offset = (position - island.Center) * Vector3.new(1, 0, 1)
		if offset.Magnitude < island.Radius + 80 then
			return Config.WorldById[id]
		end
	end
	return nil
end

-- Hinweis höchstens alle paar Sekunden, sonst füllt sich der Bildschirm
local function notice(player: Player, text: string, color: Color3)
	local now = os.clock()
	if not lastNotice[player] or now - lastNotice[player] > 4 then
		lastNotice[player] = now
		Bases.Notify(player, text, color)
	end
end

-- Spieler an einen anderen Ort bringen. world = Welt, in der er ankommt (nil = Hauptinsel)
local function travel(player: Player, target: CFrame, world, after: (() -> ())?)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not char or not root or traveling[player] then
		return
	end
	traveling[player] = true
	lastTravel[player] = os.clock()
	remotes.Travel:FireClient(player, world and world.Id or nil)
	task.spawn(function()
		-- Falls das Spiel die Karte stückweise lädt: Zielgebiet vorher anfordern
		pcall(function()
			player:RequestStreamAroundAsync(target.Position, 4)
		end)
		if player.Character == char and char.Parent then
			char:PivotTo(target)
			root.AssemblyLinearVelocity = Vector3.zero
			if after then
				after()
			end
		end
		lastTravel[player] = os.clock()
		traveling[player] = nil
	end)
end

-- In eine Welt reisen (prüft Wiedergeburt und Beute). Gibt true zurück, wenn es losgeht.
local function toWorld(player: Player, state, world): boolean
	if not Config.WorldUnlocked(world, state.Data.Rebirths) then
		notice(player, `🔒 {world.Name}: erst ab Wiedergeburt {world.Rebirths}.`, RED)
		return false
	end
	if Steal.IsCarrying(player) then
		notice(player, "Mit Beute geht es nicht in eine Welt. Bring sie erst nach Hause!", RED)
		return false
	end
	travel(player, islands[world.Id].Spawn, world, function()
		Bases.BigText(player, `{world.Icon} {Config.Upper(world.Name)}`, world.Color, nil, false)
		Bases.Notify(player, `Jeder Klick bringt hier x{world.ClickFactor} Geld. Halte Ausschau nach wilden Monstern!`, world.Color)
	end)
	return true
end

-- Jemand steht in einem Portal
local function enter(player: Player, state, portal)
	local world = portal.World
	if world then
		toWorld(player, state, world)
	else
		travel(player, hubSpawn[portal.From.Id], nil, function()
			if Steal.IsCarrying(player) then
				local seconds = W.ArrivalShield + Bases.Skill(state, "PortalShield")
				Steal.Shield(player, seconds)
				Bases.Notify(player, `🛡️ {seconds} Sekunden Schutz. Lauf nach Hause!`, GREEN)
			end
		end)
	end
end

-- Knopf "Nach Hause": bringt einen direkt vor die eigene Base (nur ohne Beute)
function Worlds.GoHome(player: Player)
	local state = Bases.GetState(player)
	if not state then
		return
	end
	local now = os.clock()
	if lastHome[player] and now - lastHome[player] < W.HomeCooldown then
		return
	end
	if Steal.IsCarrying(player) then
		Bases.Notify(player, "Mit Beute musst du durchs Portal und zu Fuß nach Hause!", RED)
		return
	end
	lastHome[player] = now
	travel(player, Bases.SpawnCFrame(state), nil)
end

-- Knopf "Welten": von überall direkt in eine offene Welt oder auf den Portal-Platz
-- (id = Welt-Id oder "Hub"). Nur ohne Beute, mit kurzer Pause zwischen zwei Reisen.
function Worlds.TravelTo(player: Player, id: any)
	local state = Bases.GetState(player)
	if not state or type(id) ~= "string" or traveling[player] then
		return
	end
	local world = Config.WorldById[id]
	if id ~= "Hub" and not (world and islands[id]) then
		return
	end
	local now = os.clock()
	if lastHome[player] and now - lastHome[player] < W.HomeCooldown then
		notice(player, "Einen Moment, du bist gerade erst gereist.", RED)
		return
	end
	if Steal.IsCarrying(player) then
		notice(player, "Mit Beute kannst du nicht reisen. Bring sie erst zu Fuß nach Hause!", RED)
		return
	end
	if world then
		if toWorld(player, state, world) then
			lastHome[player] = now
		end
	else
		lastHome[player] = now
		travel(player, hubCenter, nil)
	end
end

-- Läuft ständig: Wer steht in welcher Welt, wer steht in einem Portal?
local function update()
	local now = os.clock()
	for _, player in Players:GetPlayers() do
		local state = Bases.GetState(player)
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if state and root and hum and hum.Health > 0 then
			local position = root.Position
			local here = Worlds.At(position)
			local id = if here then here.Id else nil
			if player:GetAttribute("World") ~= id then
				player:SetAttribute("World", id)
			end
			if not traveling[player] and now - (lastTravel[player] or 0) > W.PortalCooldown then
				for _, portal in portals do
					local p = portal.CFrame:PointToObjectSpace(position)
					if math.abs(p.X) < 5.5 and p.Y > -2 and p.Y < 16 and p.Z > -3.4 and p.Z < 7 then
						if p.Z < 0.3 then
							enter(player, state, portal)
						elseif portal.World and not Config.WorldUnlocked(portal.World, state.Data.Rebirths) then
							notice(player, `🔒 {portal.World.Name}: erst ab Wiedergeburt {portal.World.Rebirths}.`, RED)
						end
						break
					end
				end
			end
		end
	end
end

-- Wildes Monster aus der Kiste dieser Welt irgendwo auf die Insel setzen
local function spawnWild(world)
	local cfg = W.Wild
	local pack = Config.PackById[world.Pack]
	local def = Config.RandomCreatureOfRarity(Config.RollWeighted(cfg.Weights), pack)
	local entry = Config.MakeEntry(def.Id, Config.RollWeighted(cfg.MutationWeights))
	local rarity = Config.Rarities[def.Rarity]
	local loud = Config.RarityRank(def.Rarity) >= Config.RarityRank(cfg.AnnounceFrom)
	local name = Config.EntryName(entry)

	Events.PlaceWild(entry, islands[world.Id].RandomPoint(), cfg.Lifetime, {
		Tag = world.Id,
		Silent = true,
		How = "ein wildes Monster heimgebracht",
		OnGrab = function(player: Player)
			wildNext[world.Id] = os.clock() + cfg.Interval
			if loud then
				Bases.Announce(`{world.Icon} {player.DisplayName} trägt ein wildes {name} nach Hause! Haut den Dieb!`, rarity.Color)
			end
		end,
	})

	for _, player in Players:GetPlayers() do
		local state = Bases.GetState(player)
		if state then
			if player:GetAttribute("World") == world.Id then
				Bases.BigText(player, "WILDES MONSTER!", rarity.Color, "Announce", false)
				Bases.Notify(player, `Ein wildes {name} ist aufgetaucht. Schnapp es und trag es nach Hause!`, rarity.Color)
			elseif loud and Config.WorldUnlocked(world, state.Data.Rebirths) then
				Bases.Notify(player, `{world.Icon} {world.Name}: {Config.Upper(rarity.Name)} {name} aufgetaucht!`, world.Color)
			end
		end
	end
end

function Worlds.Start(mapFolder: Instance, remoteFolder: Instance)
	remotes = remoteFolder
	local folder = Instance.new("Folder")
	folder.Name = "Welten"
	folder.Parent = mapFolder

	local shop = Map.PackShopPosition
	local count = #W.List
	-- Ankunft für den Knopf "Welten": hinter der Theke, Blick auf die vier Portale
	local middle = shop + Vector3.new(17, 3.5, 0)
	hubCenter = CFrame.lookAt(middle, middle + Vector3.xAxis)
	for i, world in W.List do
		-- Die Insel, weit draußen im Himmel
		local angle = math.rad(45 + (i - 1) * 90)
		local center = Vector3.new(math.cos(angle) * DISTANCE, 0, math.sin(angle) * DISTANCE)
		local island = Islands.Build(folder, world, center, shop.Y)
		islands[world.Id] = island
		table.insert(portals, { CFrame = island.Portal.CFrame, From = world })

		-- Das Portal dorthin: im Halbkreis hinter dem Kisten-Shop
		local a = math.rad((i - (count + 1) / 2) * 36)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local pos = shop + dir * 30
		local cf = CFrame.lookAt(pos, pos + dir)
		Islands.Portal(folder, cf, {
			Color = world.Color,
			Title = `{world.Icon} {world.Name}`,
			Subtitle = `ab Wiedergeburt {world.Rebirths}`,
			Rebirths = world.Rebirths,
		})
		table.insert(portals, { CFrame = cf, World = world })
		local back = pos - dir * 9 + Vector3.new(0, 3.5, 0)
		hubSpawn[world.Id] = CFrame.lookAt(back, back - dir)

		wildNext[world.Id] = os.clock() + W.Wild.FirstAfter
	end

	Players.PlayerRemoving:Connect(function(player)
		lastTravel[player] = nil
		lastNotice[player] = nil
		lastHome[player] = nil
		traveling[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(0.1)
			update()
		end
	end)

	-- Wilde Monster: in jeder Welt liegt höchstens eines. Wird es geschnappt, kommt nach
	-- einer Pause das nächste. Bleibt es liegen, taucht es später woanders neu auf.
	task.spawn(function()
		while true do
			task.wait(1)
			local now = os.clock()
			for _, world in W.List do
				if now >= wildNext[world.Id] and Events.CountWild(world.Id) == 0 then
					wildNext[world.Id] = now + W.Wild.Lifetime
					spawnWild(world)
				end
			end
		end
	end)
end

return Worlds
