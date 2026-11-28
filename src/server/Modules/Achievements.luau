-- Erfolge: Meilensteine, die jeder nebenbei erreicht (Kisten öffnen, klicken, Geld verdienen,
-- Sterne verteilen ...). Jede Stufe gibt Tokens für den Skill-Baum und eine große Ansage.
-- Gezählt wird über Bases.Track, genau wie bei den Aufgaben. Die Ziele stehen in Config.Achievements.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Bases = require(script.Parent.Bases)

local Achievements = {}

local GOLD = Color3.fromRGB(255, 215, 70)
local byKind = {} -- [kind] = { erfolg, erfolg, ... }
for _, achievement in Config.Achievements do
	byKind[achievement.Kind] = byKind[achievement.Kind] or {}
	table.insert(byKind[achievement.Kind], achievement)
end

-- Fortschritt melden: kind = "OpenPacks", "Clicks", "Earn", "StarUp", ...
function Achievements.Add(state, kind: string, amount: number)
	local list = byKind[kind]
	if not list or not state or not state.Data.Stats then
		return
	end
	local data = state.Data
	local value = (data.Stats[kind] or 0) + amount
	data.Stats[kind] = value
	local player = state.Player
	for _, achievement in list do
		local tier = data.Achieved[achievement.Id] or 0
		local gained = 0
		while achievement.Goals[tier + 1] and value >= achievement.Goals[tier + 1] do
			tier += 1
			gained += achievement.Tokens[tier] or 1
		end
		if gained > 0 then
			data.Achieved[achievement.Id] = tier
			data.Tokens += gained
			Bases.RefreshStats(state)
			local text = achievement.Text:gsub("{n}", Config.FormatNumber(achievement.Goals[tier]))
			Bases.BigText(player, `🏆 ERFOLG! +{gained} 💠`, GOLD, "Achievement", true)
			Bases.Notify(player, `🏆 {achievement.Icon} {text}: +{gained} Token für den Skill-Baum!`, GOLD)
		end
	end
end

-- Hängt sich hinter die Aufgaben: Alles, was dort gezählt wird, zählt auch für die Erfolge.
-- Muss nach Quests.Init aufgerufen werden.
function Achievements.Init()
	local inner = Bases.Track
	Bases.Track = function(state, kind: string, amount: number)
		inner(state, kind, amount)
		Achievements.Add(state, kind, amount)
	end
end

return Achievements
