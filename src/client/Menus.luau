-- Skill-Baum als Karten mit Reitern (Geld & Klick, Glück, Dieb & Schutz) und die Liste der Erfolge.
-- Lädt außerdem das Inventar (Inventar.luau).
-- Wird von Main geladen. Main gibt seine Hilfsfunktionen mit (ctx), damit hier nichts doppelt steht.
-- Liegt in Studio unter: StarterPlayer > StarterPlayerScripts > Client > Menus

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local CENTER = Vector2.new(0.5, 0.5)
local BRANCHES = { "Geld", "Glueck", "Dieb" }

return function(ctx)
	local player = Players.LocalPlayer
	local Remotes = ReplicatedStorage:WaitForChild("Remotes")
	local corner, label, tween, playSound = ctx.Corner, ctx.Label, ctx.Tween, ctx.PlaySound
	local hudButton = ctx.HudButton
	local Stil = ctx.Stil -- gemeinsamer Fenster-Stil (Stil.luau), Main lädt ihn einmal für alle

	-- Skill-Baum ----------------------------------------------------------------------
	local SKILL_COLOR = Color3.fromRGB(70, 130, 245)
	local CARD_W, CARD_H, GAP = 218, 142, 12
	local ROW_NEED = Config.Skills.RowNeed

	local skillButton, skillButtonScale, skillBadge = hudButton(3, Color3.fromRGB(90, 160, 255), "🧠", "Skills", "K")
	local skillPanel, showSkillPanel, skillHead = Stil.Window(940, 600, SKILL_COLOR, "🧠 Skill-Baum")
	local tokenPill, tokenText = Stil.Pill(skillHead, "", Stil.Dark, UDim2.fromOffset(200, 40), UDim2.new(1, -272, 0, 11))
	tokenText.TextColor3 = Stil.Token
	local tokenScale = Instance.new("UIScale")
	tokenScale.Parent = tokenPill

	-- Reiter: drei Bereiche und die Erfolge
	local tabs = {} -- [id] = { Button (Stil.Button), Dot, Page, Color, Name }
	local currentTab = "Geld"
	local refreshSkills, refreshAchievements

	local function makeTab(index: number, id: string, name: string, color: Color3)
		local button = Stil.Button(skillPanel, name, color, UDim2.fromOffset(219, 46), UDim2.fromOffset(16 + (index - 1) * 229, 74))
		button.Label.TextScaled = false -- alle Reiter gleich groß beschriftet
		button.Label.TextSize = 16
		-- grüner Punkt: hier gibt es gerade etwas zu holen
		local dot = label({
			Size = UDim2.fromOffset(22, 22),
			Position = UDim2.new(1, -16, 0, -6),
			BackgroundTransparency = 0,
			BackgroundColor3 = Stil.Green,
			Font = Enum.Font.FredokaOne,
			ZIndex = 4,
			Text = "!",
			Visible = false,
			Parent = button.Holder,
		})
		corner(dot, 11)
		local page = Instance.new("Frame")
		page.Size = UDim2.fromOffset(908, 450)
		page.Position = UDim2.fromOffset(16, 134)
		page.BackgroundTransparency = 1
		page.Visible = false
		page.Parent = skillPanel
		tabs[id] = { Button = button, Dot = dot, Page = page, Color = color, Name = name }
		return tabs[id]
	end

	local function showTab(id: string)
		currentTab = id
		for tabId, tab in tabs do
			local on = tabId == id
			tab.Page.Visible = on
			tab.Button.SetColor(if on then tab.Color:Lerp(BLACK, 0.12) else Color3.fromRGB(58, 63, 112))
			tab.Button.Label.TextColor3 = if on then WHITE else tab.Color:Lerp(WHITE, 0.35)
		end
	end

	-- Karten ----------------------------------------------------------------------------
	local cards = {} -- [skillId] = Karte
	local locks = {} -- [bereich][reihe] = { Frame, Label, Open }
	local lastLevels = {} -- zum Erkennen, was gerade gelernt wurde

	-- Stufen aller Fähigkeiten (der Server schreibt sie als Attribute an den Spieler)
	local function levels()
		local t = {}
		for _, skill in Config.Skills.List do
			t[skill.Id] = player:GetAttribute("Sk_" .. skill.Id) or 0
		end
		return t
	end

	local function makeCard(page: Frame, skill, index: number, color: Color3)
		local col, row = (index - 1) % 4, math.floor((index - 1) / 4)
		local card, line = Stil.Panel(
			page,
			UDim2.fromOffset(CARD_W, CARD_H),
			UDim2.fromOffset(col * (CARD_W + GAP) + CARD_W / 2, row * (CARD_H + GAP) + CARD_H / 2)
		)
		card.AnchorPoint = CENTER -- damit die Karte beim Lernen aus der Mitte aufspringt
		local scale = Instance.new("UIScale")
		scale.Parent = card
		local circle = Instance.new("Frame")
		circle.Size = UDim2.fromOffset(46, 46)
		circle.Position = UDim2.fromOffset(10, 10)
		circle.BackgroundColor3 = color:Lerp(Stil.Dark, 0.6)
		circle.BorderSizePixel = 0
		circle.Parent = card
		corner(circle, 23)
		local icon = label({
			AnchorPoint = CENTER,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(32, 32),
			Text = skill.Icon,
			Parent = circle,
		})
		local name = label({
			Size = UDim2.fromOffset(146, 24),
			Position = UDim2.fromOffset(64, 9),
			Font = Enum.Font.FredokaOne,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = skill.Name,
			Parent = card,
		})
		local nameLimit = Instance.new("UITextSizeConstraint")
		nameLimit.MaxTextSize = 18
		nameLimit.Parent = name
		-- Stufen als kleine Striche
		local pips = {}
		local pipWidth = math.min(34, math.floor((146 - (skill.Max - 1) * 4) / skill.Max))
		for i = 1, skill.Max do
			local pip = Instance.new("Frame")
			pip.Size = UDim2.fromOffset(pipWidth, 9)
			pip.Position = UDim2.fromOffset(64 + (i - 1) * (pipWidth + 4), 40)
			pip.BackgroundColor3 = Stil.Dark
			pip.BorderSizePixel = 0
			pip.Parent = card
			corner(pip, 4)
			pips[i] = pip
		end
		local text = label({
			Size = UDim2.fromOffset(198, 36),
			Position = UDim2.fromOffset(10, 60),
			Font = Enum.Font.GothamMedium,
			RichText = true,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = "",
			Parent = card,
		})
		local limit = Instance.new("UITextSizeConstraint")
		limit.MaxTextSize = 14
		limit.MinTextSize = 10
		limit.Parent = text
		local button = Stil.Button(card, "", Stil.Green, UDim2.fromOffset(198, 38), UDim2.fromOffset(10, 98))
		local entry = { Frame = card, Line = line, Scale = scale, Icon = icon, Name = name, Pips = pips, Text = text, Button = button, CanBuy = false, Color = color }
		cards[skill.Id] = entry
		button.Button.Activated:Connect(function()
			if entry.CanBuy then
				button.Pop()
				Remotes.BuySkill:FireServer(skill.Id)
			else
				playSound("Click", 0.6)
			end
		end)
	end

	for index, id in BRANCHES do
		local branch = Config.Skills.Branches[id]
		local tab = makeTab(index, id, `{branch.Icon} {branch.Name}`, branch.Color)
		for i, skill in Config.SkillsByBranch[id] do
			makeCard(tab.Page, skill, i, branch.Color)
		end
		-- Schloss über Reihe 2 und 3, solange sie noch zu sind
		locks[id] = {}
		for row = 2, #ROW_NEED do
			local cover = Instance.new("TextButton") -- Knopf, damit er Klicks auf die Karten darunter abfängt
			cover.Size = UDim2.fromOffset(908, CARD_H)
			cover.Position = UDim2.fromOffset(0, (row - 1) * (CARD_H + GAP))
			cover.BackgroundColor3 = Stil.Back
			cover.BackgroundTransparency = 0.22
			cover.AutoButtonColor = false
			cover.BorderSizePixel = 0
			cover.Text = ""
			cover.ZIndex = 6
			cover.Parent = tab.Page
			corner(cover, 14)
			local lockPill, lockText = Stil.Pill(cover, "", Stil.Dark, UDim2.fromOffset(560, 46), UDim2.new(0.5, -280, 0.5, -23), 7)
			lockPill.BackgroundTransparency = 0.05
			lockText.TextColor3 = branch.Color:Lerp(WHITE, 0.4)
			locks[id][row] = { Frame = cover, Label = lockText, Open = nil }
		end
	end

	-- Erfolge ---------------------------------------------------------------------------
	local ACH_W = 294
	local achTab = makeTab(4, "Erfolge", "🏆 Erfolge", Stil.Gold)
	local achCards = {} -- [id] = Karte
	local achStats, achTiers = {}, {} -- vom Server: Zähler und erreichte Stufen
	for index, achievement in Config.Achievements do
		local col, row = (index - 1) % 3, math.floor((index - 1) / 3)
		local card, line = Stil.Panel(
			achTab.Page,
			UDim2.fromOffset(ACH_W, CARD_H),
			UDim2.fromOffset(col * (ACH_W + 13), row * (CARD_H + GAP)),
			Stil.Card:Lerp(Stil.Gold, 0.08)
		)
		local circle = Instance.new("Frame")
		circle.Size = UDim2.fromOffset(46, 46)
		circle.Position = UDim2.fromOffset(10, 10)
		circle.BackgroundColor3 = Stil.Gold:Lerp(Stil.Dark, 0.65)
		circle.BorderSizePixel = 0
		circle.Parent = card
		corner(circle, 23)
		label({ AnchorPoint = CENTER, Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(32, 32), Text = achievement.Icon, Parent = circle })
		local title = label({
			Size = UDim2.fromOffset(220, 26),
			Position = UDim2.fromOffset(64, 8),
			Font = Enum.Font.FredokaOne,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = "",
			Parent = card,
		})
		local titleLimit = Instance.new("UITextSizeConstraint")
		titleLimit.MaxTextSize = 18
		titleLimit.Parent = title
		local pips = {}
		for i = 1, #achievement.Goals do
			local pip = Instance.new("Frame")
			pip.Size = UDim2.fromOffset(30, 9)
			pip.Position = UDim2.fromOffset(64 + (i - 1) * 34, 40)
			pip.BackgroundColor3 = Stil.Dark
			pip.BorderSizePixel = 0
			pip.Parent = card
			corner(pip, 4)
			pips[i] = pip
		end
		local bar = Stil.Bar(card, UDim2.fromOffset(274, 24), UDim2.fromOffset(10, 62), Stil.Gold)
		local _, reward = Stil.Pill(card, "", Stil.Dark, UDim2.fromOffset(274, 34), UDim2.fromOffset(10, 97))
		achCards[achievement.Id] = { Line = line, Title = title, Pips = pips, Bar = bar, Reward = reward }
	end

	function refreshAchievements()
		local done, total = 0, 0
		for _, achievement in Config.Achievements do
			local card = achCards[achievement.Id]
			local tier = math.clamp(achTiers[achievement.Id] or 0, 0, #achievement.Goals)
			local value = achStats[achievement.Kind] or 0
			done += tier
			total += #achievement.Goals
			for i, pip in card.Pips do
				pip.BackgroundColor3 = if i <= tier then Stil.Gold else Stil.Dark
			end
			local goal = achievement.Goals[tier + 1]
			if goal then
				card.Title.Text = string.gsub(achievement.Text, "{n}", Config.FormatNumber(goal))
				card.Bar.Set(value / goal, `{Config.FormatNumber(math.floor(math.min(value, goal)))} / {Config.FormatNumber(goal)}`, Stil.Gold)
				card.Reward.Text = `Belohnung: +{achievement.Tokens[tier + 1] or 1} 💠`
				card.Reward.TextColor3 = Stil.Token
				card.Line.Color = Stil.CardLine
			else
				card.Title.Text = string.gsub(achievement.Text, "{n}", Config.FormatNumber(achievement.Goals[tier]))
				card.Bar.Set(1, "Geschafft!", Stil.Green)
				card.Reward.Text = "★ ALLES GEHOLT"
				card.Reward.TextColor3 = Stil.Gold
				card.Line.Color = Stil.Gold
			end
		end
		achTab.Button.SetText(`🏆 Erfolge {done}/{total}`)
	end

	Remotes.Achievements.OnClientEvent:Connect(function(stats, tiers)
		if type(stats) == "table" and type(tiers) == "table" then
			achStats, achTiers = stats, tiers
			refreshAchievements()
		end
	end)

	-- Anzeige ---------------------------------------------------------------------------
	-- Gibt es gerade etwas zu lernen? Gibt den ersten Bereich zurück, in dem das geht.
	local function learnableBranch(): string?
		local lv = levels()
		local tokens = player:GetAttribute("Tokens") or 0
		for _, id in BRANCHES do
			for _, skill in Config.SkillsByBranch[id] do
				local level = lv[skill.Id]
				if level < skill.Max and tokens >= skill.Costs[level + 1] and Config.SkillReachable(lv, skill) then
					return id
				end
			end
		end
		return nil
	end

	local function refreshBadge()
		skillBadge.Visible = learnableBranch() ~= nil
		skillBadge.Text = tostring(player:GetAttribute("Tokens") or 0)
	end

	-- Sterne an der Stelle eines Elements (die Sterne liegen in einer Ebene ohne Rand oben)
	local function burstAt(object: GuiObject, color: Color3, amount: number)
		local middle = object.AbsolutePosition + object.AbsoluteSize / 2 + GuiService:GetGuiInset()
		ctx.StarBurst(UDim2.fromOffset(middle.X, middle.Y), color, amount, 130)
	end

	function refreshSkills()
		local lv = levels()
		local tokens = player:GetAttribute("Tokens") or 0
		tokenText.Text = if tokens == 1 then "💠 1 Token" else `💠 {tokens} Tokens`

		for _, id in BRANCHES do
			local branch = Config.Skills.Branches[id]
			local tab = tabs[id]
			local have, most = Config.BranchLevels(lv, id), 0
			local anyBuy = false
			for _, skill in Config.SkillsByBranch[id] do
				local card = cards[skill.Id]
				local level = lv[skill.Id]
				local open = Config.SkillReachable(lv, skill)
				most += skill.Max
				for i, pip in card.Pips do
					pip.BackgroundColor3 = if i <= level then branch.Color else Stil.Dark
				end
				local effect = Config.SkillText(skill, math.min(level + 1, skill.Max))
				card.CanBuy = false
				if level >= skill.Max then
					card.Text.Text = effect
					card.Text.TextColor3 = Stil.Gold
					card.Line.Color = Stil.Gold
					card.Frame.BackgroundColor3 = Stil.Card:Lerp(branch.Color, 0.26)
					card.Button.SetEnabled(true, Stil.Gold)
					card.Button.SetText("★ MAXIMAL")
				else
					local cost = skill.Costs[level + 1]
					card.Text.Text = if level > 0 then `<font color="#aab4de">Stufe {level + 1}:</font> {effect}` else effect
					card.Text.TextColor3 = WHITE
					card.Line.Color = if level > 0 then branch.Color:Lerp(BLACK, 0.2) else Stil.CardLine
					card.Frame.BackgroundColor3 = Stil.Card:Lerp(branch.Color, if level > 0 then 0.18 else 0.09)
					if open and tokens >= cost then
						card.CanBuy = true
						anyBuy = true
						card.Button.SetEnabled(true, Stil.Green)
						card.Button.SetText(`{if level > 0 then "Verbessern" else "Lernen"} · {cost} 💠`)
					else
						card.Button.SetEnabled(false)
						card.Button.SetText(if open then `{cost} 💠 · dir fehlen {cost - tokens}` else `{cost} 💠`)
					end
				end

				-- gerade gelernt? Dann springt die Karte auf und sprüht Sterne
				if lastLevels[skill.Id] and level > lastLevels[skill.Id] and skillPanel.Visible then
					card.Scale.Scale = 1.14
					tween(card.Scale, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
					if tab.Page.Visible then
						burstAt(card.Frame, branch.Color, 16)
					end
				end
				lastLevels[skill.Id] = level
			end

			-- Reihe 2 und 3: Schloss weg, sobald genug Stufen gelernt sind
			for row, lock in locks[id] do
				local need = ROW_NEED[row]
				local isOpen = have >= need
				if lock.Open == false and isOpen and skillPanel.Visible and tab.Page.Visible then
					burstAt(lock.Frame, branch.Color, 26)
					burstAt(lock.Frame, WHITE, 12)
					playSound("Upgrade")
				end
				lock.Open = isOpen
				lock.Frame.Visible = not isOpen
				lock.Label.Text = `🔒 Reihe {row} ab {need} Stufen in diesem Bereich · noch {math.max(0, need - have)}`
			end
			tab.Button.SetText(`{tab.Name} {have}/{most}`)
			tab.Dot.Visible = anyBuy
		end
	end

	player.AttributeChanged:Connect(function(name)
		if name == "Tokens" or string.sub(name, 1, 3) == "Sk_" then
			refreshBadge()
			if skillPanel.Visible then
				refreshSkills()
			end
		end
	end)
	refreshBadge()

	-- Neue Tokens: "+1 💠" steigt neben dem Skill-Knopf auf, der Knopf hüpft
	local lastTokens: number? = player:GetAttribute("Tokens")
	player:GetAttributeChangedSignal("Tokens"):Connect(function()
		local tokens = player:GetAttribute("Tokens") or 0
		local gained = if lastTokens then tokens - lastTokens else 0
		lastTokens = tokens
		if gained <= 0 then
			return
		end
		local holder = skillButton.Parent
		if holder and holder:IsA("GuiObject") then
			local float = label({
				Size = UDim2.fromOffset(110, 34),
				Position = UDim2.new(1, 4, 0, 14),
				Font = Enum.Font.FredokaOne,
				TextColor3 = Stil.Token,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextStrokeTransparency = 0,
				ZIndex = 20,
				Text = `+{gained} 💠`,
				Parent = holder,
			})
			tween(float, 1.3, { Position = UDim2.new(1, 4, 0, -36), TextTransparency = 1, TextStrokeTransparency = 1 })
			task.delay(1.4, function()
				float:Destroy()
			end)
		end
		skillButtonScale.Scale = 1.3
		tween(skillButtonScale, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
		if skillPanel.Visible then
			tokenScale.Scale = 1.25
			tween(tokenScale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
		end
	end)

	for id, tab in tabs do
		tab.Button.Button.Activated:Connect(function()
			playSound("Click")
			showTab(id)
			if id == "Erfolge" then
				Remotes.Achievements:FireServer()
			end
		end)
	end
	showTab(currentTab)
	refreshAchievements()

	local function toggleSkills()
		if ctx.Busy() then
			return
		end
		if skillPanel.Visible then
			skillPanel.Visible = false
		else
			-- gleich dorthin, wo es etwas zu lernen gibt
			local target = learnableBranch()
			if target and currentTab ~= "Erfolge" then
				local here = false
				local lv, tokens = levels(), player:GetAttribute("Tokens") or 0
				for _, skill in Config.SkillsByBranch[currentTab] or {} do
					local level = lv[skill.Id]
					if level < skill.Max and tokens >= skill.Costs[level + 1] and Config.SkillReachable(lv, skill) then
						here = true
						break
					end
				end
				if not here then
					showTab(target)
				end
			end
			lastLevels = levels()
			for _, id in BRANCHES do
				for _, lock in locks[id] do
					lock.Open = nil -- beim Öffnen nichts feiern, was schon länger offen ist
				end
			end
			refreshSkills()
			Remotes.Achievements:FireServer()
			showSkillPanel()
		end
		playSound("Click")
	end
	skillButton.Activated:Connect(toggleSkills)

	-- Was man sich gerade leisten kann, pulsiert leicht. Der Knopf in der Leiste auch.
	task.spawn(function()
		local ticks = 0
		while true do
			if skillPanel.Visible then
				for _, card in cards do
					if card.CanBuy then
						tween(card.Button.Scale, 0.45, { Scale = 1.05 })
					end
				end
				task.wait(0.45)
				for _, card in cards do
					if card.Button.Scale.Scale > 1 then
						tween(card.Button.Scale, 0.45, { Scale = 1 })
					end
				end
				task.wait(0.5)
				-- die Erfolge laufen mit, solange man sie anschaut
				ticks += 1
				if currentTab == "Erfolge" and ticks % 2 == 0 then
					Remotes.Achievements:FireServer()
				end
			elseif skillBadge.Visible then
				tween(skillButtonScale, 0.4, { Scale = 1.12 }).Completed:Wait()
				tween(skillButtonScale, 0.4, { Scale = 1 }).Completed:Wait()
			else
				task.wait(0.5)
			end
		end
	end)

	-- Inventar (eigene Datei: Inventar.luau) ----------------------------------------------
	local inventar = require(script.Parent:WaitForChild("Inventar"))(ctx, Stil)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.K then
			toggleSkills()
		elseif input.KeyCode == Enum.KeyCode.V or input.KeyCode == Enum.KeyCode.B then
			inventar.Toggle()
		end
	end)

	return {
		SkillPanel = skillPanel,
		BagPanel = inventar.Panel,
		ToggleSkills = toggleSkills,
		ToggleBag = inventar.Toggle,
	}
end
