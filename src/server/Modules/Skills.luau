-- Skill-Baum: Fähigkeiten mit Tokens lernen. Drei Bereiche mit je 3 Reihen: Die zweite und
-- dritte Reihe gehen auf, sobald man genug Stufen in dem Bereich gelernt hat (Config.Skills.RowNeed).
-- Alle Fähigkeiten, Kosten und Wirkungen stehen in Config.Skills.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Bases = require(script.Parent.Bases)
local Steal = require(script.Parent.Steal)

local Skills = {}

local RED = Color3.fromRGB(255, 90, 90)

function Skills.Buy(player: Player, id: string)
	local state = Bases.GetState(player)
	local skill = Config.SkillById[id]
	if not state or not skill then
		return
	end
	local data = state.Data
	local level = data.Skills[id] or 0
	if level >= skill.Max then
		Bases.Notify(player, `{skill.Name} ist schon auf Maximum!`, RED)
		return
	end
	if not Config.SkillReachable(data.Skills, skill) then
		Bases.Notify(player, `🔒 Dafür brauchst du erst {Config.SkillNeed(skill)} Stufen in diesem Bereich.`, RED)
		return
	end
	local cost = skill.Costs[level + 1] or math.huge
	if data.Tokens < cost then
		Bases.Notify(player, `Du brauchst {cost} Tokens. Tokens gibt es für Wiedergeburten und Aufgaben.`, RED)
		return
	end
	data.Tokens -= cost
	data.Skills[id] = level + 1
	Bases.RefreshStats(state)
	Steal.ApplySpeeds()
	if id == "SellBonus" then
		Bases.RenderAll(state) -- Verkaufspreise an den Kreaturen neu schreiben
	end
	Bases.RefreshPlot(state.Plot) -- Schild mit dem Einkommen
	local color = Config.Skills.Branches[skill.Branch].Color
	local text = if skill.Max > 1 then `{skill.Icon} {Config.Upper(skill.Name)} STUFE {level + 1}!` else `{skill.Icon} {Config.Upper(skill.Name)} GELERNT!`
	Bases.BigText(player, text, color, "Skill")
	Bases.Notify(player, `{skill.Icon} {Config.SkillText(skill, level + 1)}`, color)
end

return Skills
