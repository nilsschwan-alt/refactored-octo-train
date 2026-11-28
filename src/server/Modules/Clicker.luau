-- Der Klicker: Überall in die Welt klicken oder tippen gibt sofort Geld.
-- Der Client meldet jeden Klick, der Server rechnet (Wert, Combo, Volltreffer) und antwortet,
-- damit der Client die Zahl und die Effekte zeigen kann.
-- Alle Werte stehen in Config.Click, die Fähigkeiten dazu im Skill-Baum (Ast "Geld & Klick").

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Bases = require(script.Parent.Bases)

local Clicker = {}

-- Klick-Fieber (Event): solange gesetzt, reißt die Combo nicht ab, sie wächst schneller und
-- Volltreffer kommen öfter. Das Events-Modul setzt { ComboSpeed, CritFactor, Clicks = {}, Money = {} }
-- (Clicks und Money zählen für die Bilanz am Ende mit).
Clicker.Fever = nil :: { ComboSpeed: number, CritFactor: number, Clicks: { [Player]: number }, Money: { [Player]: number } }?

local C = Config.Click
local BURST = 4 -- so viele Klicks dürfen auf einmal ankommen (Netz-Ruckler)
local GOLD = Color3.fromRGB(255, 215, 60)

local remotes
local clickers = {} -- [player] = { Last, Combo, Budget, BudgetAt, Rest }

-- Merkzettel je Spieler (Combo, Tempo-Bremse, Rest hinter dem Komma)
local function entry(player: Player)
	local c = clickers[player]
	if not c then
		c = { Last = 0, Combo = 0, Budget = BURST, BudgetAt = os.clock(), Rest = 0 }
		clickers[player] = c
	end
	return c
end

-- Macht aus einem krummen Betrag ganze Dollar. Was hinter dem Komma steht, geht nicht
-- verloren, sondern zählt beim nächsten Klick mit (so wirkt "Klick-Kraft" auch bei 1 $).
local function whole(c, value: number): number
	local total = value + c.Rest
	local dollars = math.floor(total)
	c.Rest = total - dollars
	return dollars
end

-- Wert eines einzelnen Klicks ohne Combo und Volltreffer
function Clicker.BaseValue(state): number
	-- Der Goldrausch zählt erst nach dem Mindestwert, damit er auch bei 1 $ pro Klick wirkt
	local rush = Bases.RushFactor(state)
	local value = math.max(C.MinValue, Bases.Income(state) / rush * C.IncomeSeconds) * rush * (1 + Bases.Skill(state, "ClickPower"))
	local world = Config.WorldById[state.Player:GetAttribute("World") or ""]
	if world then
		value *= world.ClickFactor * (1 + Bases.Skill(state, "WorldClick"))
	end
	return value
end

-- Combo-Stufe (0 = keine) und Geld-Faktor für so viele Klicks am Stück
local function comboFor(state, count: number): (number, number)
	local step, mult = 0, 1
	for i, info in C.Combo.Steps do
		if count >= info[1] then
			step, mult = i, info[2]
		end
	end
	if step > 0 then
		mult = 1 + (mult - 1) * (1 + Bases.Skill(state, "ComboPower"))
	end
	return step, mult
end

function Clicker.Click(player: Player)
	local state = Bases.GetState(player)
	if not state then
		return
	end
	local now = os.clock()
	local c = entry(player)
	-- Tempo-Bremse: Das Guthaben füllt sich mit MaxPerSecond wieder auf
	c.Budget = math.min(BURST, c.Budget + (now - c.BudgetAt) * C.MaxPerSecond)
	c.BudgetAt = now
	if c.Budget < 1 then
		return
	end
	c.Budget -= 1

	-- Combo: reißt ab, wenn man zu lange nicht klickt (im Klick-Fieber nie)
	local fever = Clicker.Fever
	if not fever and now - c.Last > C.Combo.Timeout + Bases.Skill(state, "ComboTime") then
		c.Combo = 0
	end
	c.Last = now
	c.Combo += if fever then fever.ComboSpeed else 1
	local step, mult = comboFor(state, c.Combo)

	local value = Clicker.BaseValue(state) * mult
	local kind = "normal"
	if math.random() < Bases.Skill(state, "Jackpot") then
		kind = "jackpot"
		value *= C.JackpotFactor
	elseif math.random() < (C.CritChance + Bases.Skill(state, "Crit")) * (if fever then fever.CritFactor else 1) then
		kind = "crit"
		value *= C.CritFactor + Bases.Skill(state, "CritPower")
	end
	value = math.max(C.MinValue, whole(c, value))

	Bases.AddMoney(state, value)
	Bases.Track(state, "Clicks", 1)
	if fever then
		fever.Clicks[player] = (fever.Clicks[player] or 0) + 1
		fever.Money[player] = (fever.Money[player] or 0) + value
	end
	remotes.Clicked:FireClient(player, value, kind, c.Combo, step, mult)
	if kind == "jackpot" then
		Bases.BigText(player, `🎰 JACKPOT! +{Config.FormatNumber(value)} $`, GOLD, "Legendary", true)
	end
end

function Clicker.Start(remoteFolder: Instance)
	remotes = remoteFolder
	remotes.Click.OnServerEvent:Connect(function(player)
		Clicker.Click(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		clickers[player] = nil
	end)

	-- Auto-Klicker (Fähigkeit): klickt jede Sekunde ein paar Mal von allein, ohne Combo
	task.spawn(function()
		while true do
			task.wait(1)
			for player, state in Bases.States do
				local perSecond = Bases.Skill(state, "AutoClick")
				if perSecond > 0 and player.Parent then
					local value = whole(entry(player), Clicker.BaseValue(state) * perSecond)
					if value > 0 then
						Bases.AddMoney(state, value)
						remotes.Clicked:FireClient(player, value, "auto", 0, 0, 1)
					end
				end
			end
		end
	end)
end

return Clicker
