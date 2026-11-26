-- Klauen: Kreatur aus fremder Base nehmen, tragen (langsam, leuchtet), in die eigene Base bringen.
-- Wer getroffen wird, stirbt oder das Spiel verlässt, verliert die Beute: Sie geht zurück zum Besitzer.
-- Solange die Kreatur getragen wird, gehört sie im Spielstand noch dem Besitzer.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local CreatureModels = require(script.Parent.CreatureModels)
local Bases = require(script.Parent.Bases)

local Steal = {}

local carrying = {} -- [thief] = info
local lastHit = {} -- [player] = os.clock()

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
		hum.WalkSpeed = info.OldSpeed
		hum.UseJumpPower = info.OldUseJumpPower
		hum.JumpPower = info.OldJumpPower
	end
	thief:SetAttribute("Carrying", nil)
end

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
	local id = oState.Data.Slots[tostring(slot)]
	if not id or plot.Stolen[slot] then
		return
	end
	if not Bases.FreeSlot(tState) then
		Bases.Notify(thief, "Deine Base ist voll, du kannst nichts mehr klauen!", RED)
		return
	end
	local hum, root, char = getHumanoid(thief)
	if not hum then
		return
	end
	local model = plot.SlotModels[slot]
	if not model or (model:GetPivot().Position - root.Position).Magnitude > Config.Steal.MaxStealDistance then
		return
	end
	local head = char:FindFirstChild("Head")
	if not head then
		return
	end

	-- Kreatur aus der Base nehmen (bleibt im Spielstand des Besitzers!)
	plot.Stolen[slot] = thief
	Bases.RenderSlot(oState, slot)

	local def = Config.CreatureById[id]
	local carried = CreatureModels.Build(def, { Scale = 0.55, Anchored = false })
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

	local info = {
		Owner = owner,
		Plot = plot,
		Slot = slot,
		Id = id,
		Model = carried,
		Highlight = highlight,
		Character = char,
		Humanoid = hum,
		OldSpeed = hum.WalkSpeed,
		OldUseJumpPower = hum.UseJumpPower,
		OldJumpPower = hum.JumpPower,
	}
	carrying[thief] = info

	hum.WalkSpeed = Config.Steal.CarrySpeed
	if not Config.Steal.CanJumpWhileCarrying then
		hum.UseJumpPower = true
		hum.JumpPower = 0
	end
	thief:SetAttribute("Carrying", id)

	Bases.Notify(thief, `Du hast {def.Name}! Schnell in deine Base!`, YELLOW)
	Bases.Notify(owner, `{thief.DisplayName} klaut deinen {def.Name}! Hau den Dieb mit der Klatsche!`, RED)
end

-- Beute geht zurück zum Besitzer
function Steal.Return(thief: Player, reason: string?)
	local info = carrying[thief]
	if not info then
		return
	end
	cleanup(thief, info)
	local def = Config.CreatureById[info.Id]
	local plot = info.Plot
	if plot.Stolen[info.Slot] == thief then
		plot.Stolen[info.Slot] = nil
	end
	local oState = Bases.GetState(info.Owner)
	if oState and oState.Plot == plot then
		Bases.RenderSlot(oState, info.Slot)
		if reason == "hit" then
			Bases.Notify(info.Owner, `{def.Name} ist zurück!`, GREEN)
		end
	end
	if reason == "hit" then
		Bases.Notify(thief, "Erwischt! Die Beute ist weg.", RED)
	elseif reason == "full" then
		Bases.Notify(thief, "Deine Base ist voll, die Beute ist zurückgelaufen.", RED)
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
	local oState = Bases.GetState(info.Owner)
	local key = tostring(info.Slot)
	if not oState or oState.Data.Slots[key] ~= info.Id then
		-- Besitzer weg oder Kreatur verkauft: Beute verfällt
		cleanup(thief, info)
		return
	end
	local freeSlot = Bases.FreeSlot(tState)
	if not freeSlot then
		Steal.Return(thief, "full")
		return
	end

	cleanup(thief, info)
	oState.Data.Slots[key] = nil
	info.Plot.Stolen[info.Slot] = nil
	Bases.RenderSlot(oState, info.Slot)
	Bases.PlaceCreature(tState, freeSlot, info.Id)

	local def = Config.CreatureById[info.Id]
	Bases.Notify(thief, `Geschafft! {def.Name} gehört jetzt dir!`, GREEN)
	Bases.Notify(info.Owner, `{thief.DisplayName} hat deinen {def.Name} geklaut!`, RED)
end

-- Läuft ständig: Ist ein Dieb zu Hause angekommen oder gestorben?
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

-- Schlag mit der Klatsche: Diebe in der Nähe verlieren ihre Beute
function Steal.Hit(hitter: Player): boolean
	local now = os.clock()
	if lastHit[hitter] and now - lastHit[hitter] < Config.Steal.HitCooldown then
		return false
	end
	lastHit[hitter] = now
	local _, myRoot = getHumanoid(hitter)
	if not myRoot then
		return false
	end
	local hitSomeone = false
	for thief, _ in carrying do
		if thief ~= hitter then
			local hum, root = getHumanoid(thief)
			if hum and (root.Position - myRoot.Position).Magnitude <= Config.Steal.HitRange then
				Steal.Return(thief, "hit")
				hitSomeone = true
				-- Kurz betäubt + kleiner Schubs
				local speed = hum.WalkSpeed
				hum.WalkSpeed = 0
				local push = (root.Position - myRoot.Position) * Vector3.new(1, 0, 1)
				if push.Magnitude > 0 then
					root.AssemblyLinearVelocity = push.Unit * 45 + Vector3.new(0, 25, 0)
				end
				task.delay(Config.Steal.StunTime, function()
					if hum.Parent and hum.WalkSpeed == 0 then
						hum.WalkSpeed = speed
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
		if info.Owner == player then
			cleanup(thief, info)
			info.Plot.Stolen[info.Slot] = nil
			Bases.Notify(thief, "Der Besitzer ist weg, die Beute hat sich in Luft aufgelöst.", YELLOW)
		end
	end
	lastHit[player] = nil
end

return Steal
