-- Tragen & Klauen: Kreatur aus fremder Base nehmen (oder wilde Kreatur vom Meteor schnappen),
-- tragen (langsam, leuchtet) und in die eigene Base bringen.
-- Wer getroffen wird, stirbt oder das Spiel verlässt, verliert die Beute:
--   geklaut -> zurück zum Besitzer, wild -> fällt auf den Boden.
-- Eine geklaute Kreatur gehört im Spielstand so lange dem Besitzer, bis sie angekommen ist.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local CreatureModels = require(script.Parent.CreatureModels)
local Bases = require(script.Parent.Bases)
local FX = require(script.Parent.FX)

local Steal = {}

-- Werden von der Diebes-Nacht verändert
Steal.WalkSpeed = Config.WalkSpeed
Steal.CarrySpeed = Config.Steal.CarrySpeed
-- Hier hängt sich das Events-Modul ein: function(hitter, position, range): boolean
-- (die Klatsche trifft damit auch Schatten-Diebe)
Steal.ExtraHit = nil :: ((Player, Vector3, number) -> boolean)?

local carrying = {} -- [thief] = info
local lastHit = {} -- [player] = os.clock()
local shielded = {} -- [player] = os.clock(), bis wann die Klatsche nicht trifft

local RED = Color3.fromRGB(255, 90, 90)
local YELLOW = Color3.fromRGB(255, 220, 90)
local GREEN = Color3.fromRGB(100, 255, 130)

local function getHumanoid(player: Player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if hum and root and hum.Health > 0 then
		return hum, root, char
	end
	return nil
end

function Steal.IsCarrying(player: Player): boolean
	return carrying[player] ~= nil
end

-- Was trägt der Spieler gerade? "base" (geklaut), "wild" (Meteor oder Welt) oder nil
function Steal.CarrySource(player: Player): string?
	local info = carrying[player]
	return info and info.Source
end

-- Kurzer Schutz vor der Klatsche (z.B. direkt nach dem Portal), mit sichtbarer Schutzblase
function Steal.Shield(player: Player, seconds: number)
	shielded[player] = os.clock() + seconds
	local char = player.Character
	if char then
		local field = Instance.new("ForceField")
		field.Name = "PortalSchutz"
		field.Parent = char
		task.delay(seconds, function()
			field:Destroy()
		end)
	end
end

-- Tempo mit Beute für diesen Spieler (Fähigkeit "Schnelle Beine" macht schneller,
-- die "Klebefalle" des Beklauten macht langsamer)
local function carrySpeed(player: Player): number
	local state = Bases.GetState(player)
	local info = carrying[player]
	local slow = if info and info.Slow then info.Slow else 0
	return (Steal.CarrySpeed + (if state then Bases.Skill(state, "CarrySpeed") else 0)) * (1 - slow)
end

-- Normales Lauftempo für diesen Spieler (Fähigkeit "Flitzer" macht schneller)
function Steal.SpeedFor(player: Player): number
	local state = Bases.GetState(player)
	return Steal.WalkSpeed + (if state then Bases.Skill(state, "WalkSpeed") else 0)
end

-- Tempo für alle Spieler neu setzen (z.B. Start/Ende der Diebes-Nacht)
function Steal.ApplySpeeds()
	for _, player in Players:GetPlayers() do
		local hum = getHumanoid(player)
		if hum and hum.WalkSpeed > 0 then
			hum.WalkSpeed = if carrying[player] then carrySpeed(player) else Steal.SpeedFor(player)
		end
	end
end

-- Entfernt Träger-Optik und stellt Tempo wieder her
local function cleanup(thief: Player, info)
	carrying[thief] = nil
	if info.Model then
		info.Model:Destroy()
	end
	if info.Highlight then
		info.Highlight:Destroy()
	end
	local hum = info.Humanoid
	if hum and hum.Parent then
		hum.WalkSpeed = Steal.SpeedFor(thief)
		hum.UseJumpPower = info.OldUseJumpPower
		hum.JumpPower = info.OldJumpPower
	end
	thief:SetAttribute("Carrying", nil)
end

-- Gemeinsamer Teil: Kreatur auf den Kopf, langsam machen, leuchten
local function startCarry(thief: Player, entry: string, info)
	local hum, _, char = getHumanoid(thief)
	local head = char and char:FindFirstChild("Head")
	if not hum or not head then
		return false
	end
	local def, mutation, stars = Config.ParseEntry(entry)
	local carried = CreatureModels.Build(def, { Scale = 0.55, Anchored = false, Mutation = mutation, Stars = stars })
	carried:PivotTo(head.CFrame * CFrame.new(0, 0.8, 0))
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = head
	weld.Part1 = carried.PrimaryPart
	weld.Parent = carried.PrimaryPart
	carried.Name = "Beute"
	carried.Parent = char

	local highlight = Instance.new("Highlight")
	highlight.FillColor = Color3.fromRGB(255, 220, 40)
	highlight.OutlineColor = Color3.fromRGB(255, 80, 0)
	highlight.FillTransparency = 0.5
	highlight.Parent = char

	info.Entry = entry
	info.Model = carried
	info.Highlight = highlight
	info.Character = char
	info.Humanoid = hum
	info.OldUseJumpPower = hum.UseJumpPower
	info.OldJumpPower = hum.JumpPower
	carrying[thief] = info

	hum.WalkSpeed = carrySpeed(thief)
	if not Config.Steal.CanJumpWhileCarrying then
		hum.UseJumpPower = true
		hum.JumpPower = 0
	end
	thief:SetAttribute("Carrying", entry)
	return true
end

-- Aus fremder Base klauen
function Steal.TryStart(thief: Player, plotIndex: number, slot: number)
	local tState = Bases.GetState(thief)
	local plot = Bases.Plots[plotIndex]
	if not tState or not plot or type(slot) ~= "number" then
		return
	end
	local owner = plot.Owner
	if not owner or owner == thief then
		return
	end
	local oState = Bases.GetState(owner)
	if not oState then
		return
	end
	if carrying[thief] then
		Bases.Notify(thief, "Du trägst schon etwas!", RED)
		return
	end
	if oState.Locked then
		Bases.Notify(thief, "Diese Base ist abgeschlossen!", RED)
		return
	end
	local entry = oState.Data.Slots[tostring(slot)]
	if not entry or plot.Stolen[slot] then
		return
	end
	if Bases.Skill(oState, "Vault") > 0 and Bases.BestSlot(oState) == slot then
		Bases.Notify(thief, `🏦 {Config.EntryName(entry)} liegt im Tresor und kann nicht geklaut werden!`, RED)
		return
	end
	local _, root = getHumanoid(thief)
	local model = plot.SlotModels[slot]
	if not root or not model or (model:GetPivot().Position - root.Position).Magnitude > Config.Steal.MaxStealDistance then
		return
	end

	-- Slow: Fähigkeit "Klebefalle" des Besitzers bremst den Dieb zusätzlich
	local info = { Source = "base", Owner = owner, Plot = plot, Slot = slot, Slow = Bases.Skill(oState, "ThiefSlow") }
	if not startCarry(thief, entry, info) then
		return
	end
	-- Kreatur aus der Base nehmen (bleibt im Spielstand des Besitzers!)
	plot.Stolen[slot] = thief
	Bases.RenderSlot(oState, slot)

	local name = Config.EntryName(entry)
	Bases.Notify(thief, `Du hast {name}! Schnell in deine Base!`, YELLOW)
	Bases.BigText(owner, "DU WIRST BEKLAUT!", RED, "Stolen", true)
	Bases.Notify(owner, `{thief.DisplayName} klaut deinen {name}! Hau den Dieb mit der Klatsche!`, RED)
end

-- Wilde Kreatur (Meteor, Welt) schnappen. onDrop(position) wird aufgerufen, wenn sie wieder runterfällt.
-- how = Text für die große Ansage bei seltenen Funden (z.B. "im Lava-Krater gefangen")
function Steal.StartWild(thief: Player, entry: string, onDrop, how: string?): boolean
	local tState = Bases.GetState(thief)
	if not tState or carrying[thief] then
		return false
	end
	local ok = startCarry(thief, entry, { Source = "wild", OnDrop = onDrop, How = how })
	if ok then
		Bases.Notify(thief, `Du hast {Config.EntryName(entry)}! Bring es nach Hause!`, YELLOW)
	end
	return ok
end

-- Beute verlieren
function Steal.Return(thief: Player, reason: string?)
	local info = carrying[thief]
	if not info then
		return
	end
	local _, root = getHumanoid(thief)
	local dropPos = if root then root.Position elseif info.Model and info.Model.PrimaryPart then info.Model.PrimaryPart.Position else nil
	cleanup(thief, info)
	local name = Config.EntryName(info.Entry)

	if info.Source == "wild" then
		if info.OnDrop then
			info.OnDrop(dropPos)
		end
	else
		local plot = info.Plot
		if plot.Stolen[info.Slot] == thief then
			plot.Stolen[info.Slot] = nil
		end
		local oState = Bases.GetState(info.Owner)
		if oState and oState.Plot == plot then
			Bases.RenderSlot(oState, info.Slot)
			if reason == "hit" then
				Bases.Notify(info.Owner, `{name} ist zurück!`, GREEN)
			end
		end
	end

	if reason == "hit" then
		Bases.BigText(thief, "ERWISCHT!", RED, "Hit")
	elseif reason == "died" then
		Bases.Notify(thief, "Beute verloren!", RED)
	end
end

function Steal.Deliver(thief: Player)
	local info = carrying[thief]
	local tState = Bases.GetState(thief)
	if not info or not tState then
		return
	end
	local entry = info.Entry
	-- Ist die Base voll, tauscht die Beute mit der schwächsten Kreatur oder landet im Inventar.
	local function receive()
		local got = Bases.Receive(tState, entry)
		local text = Bases.ReceiveText(got, entry)
		if text then
			Bases.Notify(thief, text, YELLOW)
		end
	end

	if info.Source == "base" then
		local oState = Bases.GetState(info.Owner)
		local key = tostring(info.Slot)
		if not oState or oState.Data.Slots[key] ~= entry then
			cleanup(thief, info) -- Besitzer weg oder Kreatur verkauft: Beute verfällt
			return
		end
		cleanup(thief, info)
		oState.Data.Slots[key] = nil
		info.Plot.Stolen[info.Slot] = nil
		Bases.RenderSlot(oState, info.Slot)
		receive()
		Bases.BigText(thief, "GEKLAUT!", GREEN, "Epic")
		Bases.Notify(thief, `{Config.EntryName(entry)} gehört jetzt dir!`, GREEN)
		Bases.BigText(info.Owner, "DU WURDEST BEKLAUT!", RED, "Stolen", true)
		Bases.Notify(info.Owner, `{thief.DisplayName} hat deinen {Config.EntryName(entry)} geklaut!`, RED)
		Bases.FillFree(oState) -- der leere Platz wird aus dem Inventar besetzt
		Bases.AnnounceIfRare(thief, entry, "geklaut")
		Bases.Track(tState, "Steal", 1)
		-- Skill-Baum: Beute-Bonus für den Dieb, Trostpflaster für den Beklauten
		local loot = math.floor(Config.EntryIncome(entry) * Bases.Multiplier(tState) * Bases.Skill(tState, "LootBonus"))
		if loot > 0 then
			Bases.AddMoney(tState, loot)
			Bases.Notify(thief, `💎 Beute-Bonus: +{Config.FormatNumber(loot)} $`, GREEN)
		end
		local comfort = math.floor(Config.EntryValue(entry) * Bases.Skill(oState, "Comfort"))
		if comfort > 0 then
			Bases.AddMoney(oState, comfort)
			Bases.Notify(info.Owner, `💝 Trostpflaster: +{Config.FormatNumber(comfort)} $`, YELLOW)
		end
	else
		cleanup(thief, info)
		receive()
		Bases.Track(tState, "Wild", 1)
		Bases.BigText(thief, "GESCHNAPPT!", GREEN, "Epic")
		Bases.AnnounceIfRare(thief, entry, info.How or "den Meteor geschnappt")
	end
end

-- Läuft ständig: Ist ein Träger zu Hause angekommen oder gestorben?
function Steal.Update()
	for thief, info in carrying do
		local hum, root, char = getHumanoid(thief)
		if not hum or char ~= info.Character then
			Steal.Return(thief, "died")
		else
			local tState = Bases.GetState(thief)
			if tState and Bases.IsInsideOwnBase(tState, root.Position) then
				Steal.Deliver(thief)
			end
		end
	end
end

-- Schlag mit der Klatsche: Träger in der Nähe verlieren ihre Beute
function Steal.Hit(hitter: Player): boolean
	local now = os.clock()
	local hState = Bases.GetState(hitter)
	local cooldown = Config.Steal.HitCooldown * (1 - (if hState then Bases.Skill(hState, "HitCooldown") else 0))
	if lastHit[hitter] and now - lastHit[hitter] < cooldown then
		return false
	end
	lastHit[hitter] = now
	local _, myRoot = getHumanoid(hitter)
	if not myRoot then
		return false
	end
	local range = Config.Steal.HitRange + (if hState then Bases.Skill(hState, "HitRange") else 0)
	local hitSomeone = false
	-- Schatten-Diebe der Diebes-Nacht (das Events-Modul hängt sich hier ein)
	if Steal.ExtraHit and Steal.ExtraHit(hitter, myRoot.Position, range) then
		hitSomeone = true
	end
	for thief, _ in carrying do
		if thief ~= hitter and not (shielded[thief] and now < shielded[thief]) then
			local hum, root = getHumanoid(thief)
			if hum and (root.Position - myRoot.Position).Magnitude <= range then
				Steal.Return(thief, "hit")
				hitSomeone = true
				FX.Burst(root.Position, Color3.fromRGB(255, 220, 60), 50)
				-- Kurz betäubt + Schubs
				hum.WalkSpeed = 0
				local push = (root.Position - myRoot.Position) * Vector3.new(1, 0, 1)
				if push.Magnitude > 0 then
					root.AssemblyLinearVelocity = push.Unit * 45 + Vector3.new(0, 25, 0)
				end
				task.delay(Config.Steal.StunTime + (if hState then Bases.Skill(hState, "StunTime") else 0), function()
					if hum.Parent and hum.WalkSpeed == 0 then
						hum.WalkSpeed = if carrying[thief] then carrySpeed(thief) else Steal.SpeedFor(thief)
					end
				end)
			end
		end
	end
	return hitSomeone
end

-- Spieler verlässt das Spiel
function Steal.OnPlayerLeaving(player: Player)
	if carrying[player] then
		Steal.Return(player, "left")
	end
	for thief, info in carrying do
		if info.Source == "base" and info.Owner == player then
			cleanup(thief, info)
			info.Plot.Stolen[info.Slot] = nil
			Bases.Notify(thief, "Der Besitzer ist weg, die Beute hat sich in Luft aufgelöst.", YELLOW)
		end
	end
	lastHit[player] = nil
	shielded[player] = nil
end

return Steal
