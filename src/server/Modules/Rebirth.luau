-- Wiedergeburt: Geld und Base-Stufe gehen zurück auf Anfang, die besten Kreaturen bleiben.
-- Dafür gibt's dauerhaft mehr Einkommen und Tokens für den Rebirth-Shop (Glück, Münz-Magnet, Klick-Kraft).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Bases = require(script.Parent.Bases)
local Map = require(script.Parent.Map)
local Steal = require(script.Parent.Steal)
local FX = require(script.Parent.FX)

local Rebirth = {}

local R = Config.Rebirth
local RED = Color3.fromRGB(255, 90, 90)
local PURPLE = Color3.fromRGB(200, 120, 255)

function Rebirth.Do(player: Player)
	local state = Bases.GetState(player)
	if not state then
		return
	end
	local data = state.Data
	local cost = Config.RebirthCost(data.Rebirths)
	if data.Money < cost then
		Bases.Notify(player, `Du brauchst {Config.FormatNumber(cost)} $ für die Wiedergeburt.`, RED)
		return
	end
	if Steal.IsCarrying(player) or next(state.Plot.Stolen) ~= nil then
		Bases.Notify(player, "Geht gerade nicht: Es wird noch etwas getragen.", RED)
		return
	end

	-- Die besten Kreaturen behalten (nach Einkommen)
	local entries = {}
	for _, entry in data.Slots do
		table.insert(entries, entry)
	end
	table.sort(entries, function(a, b)
		return Config.EntryIncome(a) > Config.EntryIncome(b)
	end)
	table.clear(data.Slots)
	for i = 1, math.min(R.KeepCreatures, Config.BaseLevels[1].Slots, #entries) do
		data.Slots[tostring(i)] = entries[i]
	end

	local unlocked = Config.RebirthUnlock(data.Rebirths) -- neue Kiste durch diese Wiedergeburt?
	data.Rebirths += 1
	data.Tokens += R.TokensPerRebirth
	data.Money = 0
	data.Cash = 0
	data.BaseLevel = 1
	Bases.AddMoney(state, Config.StartMoney, "quest")
	Bases.RefreshStats(state)
	Map.BuildDecor(state.Plot, 1)
	Bases.RenderAll(state)
	Bases.RefreshPlot(state.Plot)

	local mult = Config.RebirthMultiplier(data.Rebirths)
	Bases.BigText(player, `WIEDERGEBURT #{data.Rebirths}!`, PURPLE, "Rebirth", false)
	Bases.Notify(player, `Jetzt x{mult} Einkommen für immer und +{R.TokensPerRebirth} Tokens!`, PURPLE)
	Bases.Announce(`{player.DisplayName} ist wiedergeboren! (#{data.Rebirths})`, PURPLE)
	if unlocked then
		-- kurz nach dem großen Schriftzug: die neue Kiste ankündigen
		task.delay(2.6, function()
			if player.Parent then
				Bases.BigText(player, `NEU: {string.upper(unlocked.Name)}!`, unlocked.Color, "Upgrade", false)
				Bases.Notify(player, `Die {unlocked.Name} ist jetzt im Shop, mit neuen, viel stärkeren Kreaturen!`, unlocked.Color)
			end
		end)
	end
	local center = state.Plot.CFrame.Position + Vector3.new(0, 0.5, 0)
	FX.Ring(center, PURPLE, 60)
	for _, model in state.Plot.SlotModels do
		FX.PopIn(model)
		FX.Burst(model:GetPivot().Position + Vector3.new(0, 2, 0), PURPLE, 30)
	end
end

function Rebirth.BuyUpgrade(player: Player, id: string)
	local state = Bases.GetState(player)
	local info = R.Upgrades[id]
	if not state or not info then
		return
	end
	local level = state.Data.Upgrades[id] or 0
	if level >= info.Max then
		Bases.Notify(player, `{info.Name} ist schon auf Maximum!`, RED)
		return
	end
	local cost = info.Costs[level + 1] or math.huge
	if state.Data.Tokens < cost then
		Bases.Notify(player, `Du brauchst {cost} Tokens. Tokens gibt's bei jeder Wiedergeburt.`, RED)
		return
	end
	state.Data.Tokens -= cost
	state.Data.Upgrades[id] = level + 1
	Bases.RefreshStats(state)
	Bases.BigText(player, `{info.Icon} {string.upper(info.Name)} STUFE {level + 1}!`, PURPLE, "Upgrade")
end

return Rebirth
