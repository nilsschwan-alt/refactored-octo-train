-- Aufgaben: Immer 3 gleichzeitig (z.B. "Öffne 5 Kisten"). Geschafft = Geld + Fanfare,
-- und sofort kommt eine neue. Ziele und Belohnungen wachsen mit deinem Einkommen.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Bases = require(script.Parent.Bases)

local Quests = {}

local Q = Config.Quests
local S = Config.Skills
local BLUE = Color3.fromRGB(120, 220, 255)
local remotes
local pending = {} -- [state] = true, wenn ein Update an den Client raus muss

local function kinds()
	local list = {}
	for kind in Q.Types do
		table.insert(list, kind)
	end
	table.sort(list)
	return list
end
local ALL_KINDS = kinds()

-- Text für eine Aufgabe, z.B. "Öffne 5 Kisten"
local function describe(quest): string
	local info = Q.Types[quest.Kind]
	local text = info.Text:gsub("{n}", Config.FormatNumber(quest.Goal))
	return text
end

local function newQuest(state, avoid)
	local options = {}
	for _, kind in ALL_KINDS do
		if not avoid[kind] then
			table.insert(options, kind)
		end
	end
	if #options == 0 then
		options = ALL_KINDS
	end
	local kind = options[math.random(1, #options)]
	local info = Q.Types[kind]
	-- Mindestens 1 $/s rechnen, damit neue Spieler auch faire Ziele bekommen
	local income = math.max(1, Bases.Income(state))
	local goal
	if kind == "Earn" then
		goal = math.max(info.MinGoal, math.floor(income * info.EarnSeconds))
		-- schöne runde Zahl
		local magnitude = 10 ^ math.max(0, math.floor(math.log10(goal)) - 1)
		goal = math.floor(goal / magnitude) * magnitude
	else
		goal = math.random(info.Min, info.Max)
	end
	local reward = math.floor(math.max(Q.MinReward, income * Q.RewardSeconds) * info.Factor)
	return { Kind = kind, Goal = goal, Progress = 0, Reward = reward }
end

-- Belohnung mit der Fähigkeit "Quest-Profi"
local function payout(state, quest): number
	return math.floor(quest.Reward * (1 + Bases.Skill(state, "QuestBonus")))
end

-- Schickt die Aufgaben an den Client (gebündelt, höchstens 5x pro Sekunde)
function Quests.Send(state)
	if pending[state] then
		return
	end
	pending[state] = true
	task.delay(0.2, function()
		pending[state] = nil
		if Bases.GetState(state.Player) ~= state then
			return
		end
		local list = {}
		for _, quest in state.Data.Quests do
			table.insert(list, {
				Text = describe(quest),
				Progress = math.floor(math.min(quest.Progress, quest.Goal)),
				Goal = quest.Goal,
				Reward = payout(state, quest),
			})
		end
		-- dritter Wert: in so vielen Aufgaben gibt es das nächste Token
		local tokenIn = S.QuestsPerToken - (state.Data.QuestCount % S.QuestsPerToken)
		remotes.Quests:FireClient(state.Player, list, tokenIn)
	end)
end

-- Fehlende Aufgaben auffüllen (keine doppelte Sorte)
function Quests.Fill(state)
	local quests = state.Data.Quests
	while #quests < Q.Active do
		local avoid = {}
		for _, quest in quests do
			avoid[quest.Kind] = true
		end
		table.insert(quests, newQuest(state, avoid))
	end
	Quests.Send(state)
end

-- Fortschritt: kind = "Clicks", "Earn", "OpenPacks", "Steal", "HitThief"
function Quests.Add(state, kind: string, amount: number)
	if not state or not state.Data.Quests then
		return
	end
	local changed = false
	local finished = {}
	for i, quest in state.Data.Quests do
		if quest.Kind == kind then
			quest.Progress += amount
			changed = true
			if quest.Progress >= quest.Goal then
				table.insert(finished, i)
			end
		end
	end
	if not changed then
		return
	end
	-- von hinten entfernen, damit die Nummern stimmen
	for n = #finished, 1, -1 do
		local quest = table.remove(state.Data.Quests, finished[n])
		local player = state.Player
		local reward = payout(state, quest)
		Bases.AddMoney(state, reward, "quest")
		Bases.BigText(player, `AUFGABE GESCHAFFT! +{Config.FormatNumber(reward)} $`, Color3.fromRGB(120, 255, 160), "Quest")
		remotes.MoneyPopup:FireClient(player, reward)
		Bases.Notify(player, `✅ {describe(quest)}`, Color3.fromRGB(120, 255, 160))
		-- jede x-te Aufgabe gibt Tokens für den Skill-Baum
		local data = state.Data
		data.QuestCount += 1
		if data.QuestCount % S.QuestsPerToken == 0 then
			data.Tokens += S.TokensPerQuest
			Bases.RefreshStats(state)
			Bases.Notify(player, `💠 +{S.TokensPerQuest} Token für den Skill-Baum!`, BLUE)
		end
		-- Fähigkeit "Token-Finder": manchmal liegt noch ein Token obendrauf
		if math.random() < Bases.Skill(state, "TokenLuck") then
			data.Tokens += 1
			Bases.RefreshStats(state)
			Bases.Notify(player, "💠 Glück gehabt: +1 Extra-Token!", BLUE)
		end
	end
	if #finished > 0 then
		Quests.Fill(state)
	else
		Quests.Send(state)
	end
end

function Quests.Init(remoteFolder)
	remotes = remoteFolder
	Bases.Track = Quests.Add
end

function Quests.Forget(state)
	pending[state] = nil
end

return Quests
