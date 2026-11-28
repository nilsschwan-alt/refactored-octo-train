-- Skill-Baum (Waben-Netz) und Inventar (alle Kreaturen: aufstellen, verbessern, verkaufen).
-- Wird von Main geladen. Main gibt seine Hilfsfunktionen mit (ctx), damit hier nichts doppelt steht.
-- Liegt in Studio unter: StarterPlayer > StarterPlayerScripts > Client > Menus

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local GOLD = Color3.fromRGB(255, 215, 70)
local GREEN = Color3.fromRGB(60, 200, 90)
local GREY = Color3.fromRGB(90, 90, 100)
local TOKEN_BLUE = Color3.fromRGB(120, 220, 255)
local CENTER = Vector2.new(0.5, 0.5)
local SQRT3 = math.sqrt(3)

return function(ctx)
	local player = Players.LocalPlayer
	local Remotes = ReplicatedStorage:WaitForChild("Remotes")
	local gui: ScreenGui = ctx.Gui
	local corner, label, stroke, tween, playSound = ctx.Corner, ctx.Label, ctx.Stroke, ctx.Tween, ctx.PlaySound

	-- Bausteine -----------------------------------------------------------------------
	-- Quadratischer Knopf in der linken Leiste (baut Main, damit alle Knöpfe gleich aussehen)
	local hudButton = ctx.HudButton

	-- Fenster in der Bildschirmmitte mit Titel und X
	local function window(width: number, height: number, color: Color3, title: string)
		local panel = Instance.new("Frame")
		panel.AnchorPoint = CENTER
		panel.Position = UDim2.fromScale(0.5, 0.5)
		panel.Size = UDim2.fromOffset(width, height)
		panel.BackgroundColor3 = Color3.fromRGB(26, 23, 40)
		panel.Visible = false
		panel.Active = true -- fängt Klicks ab, damit im Fenster kein Klick-Geld entsteht
		panel.Parent = gui
		corner(panel, 14)
		stroke(panel, color, 3)
		local scale = Instance.new("UIScale")
		scale.Parent = panel
		label({
			Size = UDim2.new(0, 330, 0, 40),
			Position = UDim2.fromOffset(16, 8),
			Font = Enum.Font.FredokaOne,
			TextColor3 = color:Lerp(WHITE, 0.35),
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = title,
			Parent = panel,
		})
		local close = Instance.new("TextButton")
		close.Size = UDim2.fromOffset(40, 40)
		close.Position = UDim2.new(1, -50, 0, 10)
		close.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
		close.Text = "X"
		close.TextColor3 = WHITE
		close.Font = Enum.Font.GothamBold
		close.TextScaled = true
		close.Parent = panel
		corner(close, 8)
		close.Activated:Connect(function()
			panel.Visible = false
		end)
		-- Aufploppen, passend zur Bildschirmgröße
		local function show()
			local fit = 1
			local camera = workspace.CurrentCamera
			if camera then
				local size = camera.ViewportSize
				fit = math.min(1, size.X / (width + 40), size.Y / (height + 40))
			end
			scale.Scale = fit * 0.8
			tween(scale, 0.25, { Scale = fit }, Enum.EasingStyle.Back)
			panel.Visible = true
		end
		return panel, show
	end

	-- Skill-Baum ----------------------------------------------------------------------
	local S = 42 -- Größe einer Wabe (Mitte bis Spitze)
	local UNIT = SQRT3 * S -- Abstand zweier Waben nebeneinander
	local HEX_X, HEX_Y = 264, 296 -- Mitte des Netzes im Fenster (drei Ringe = 36 Waben + Mitte)
	local SKILL_COLOR = Color3.fromRGB(90, 160, 255)

	local skillButton, skillButtonScale, skillBadge = hudButton(3, SKILL_COLOR, "🧠", "Skills", "K")
	local skillPanel, showSkillPanel = window(940, 600, SKILL_COLOR, "💠 Skill-Baum")
	local tokenTitle = label({
		Size = UDim2.fromOffset(330, 34),
		Position = UDim2.fromOffset(540, 12),
		Font = Enum.Font.FredokaOne,
		TextColor3 = TOKEN_BLUE,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
		Parent = skillPanel,
	})

	-- Ein Sechseck aus drei gedrehten Balken. zIndex: Rand 2, Füllung 3, Inhalt 4, Klickfläche 5.
	local function hexagon(parent: Instance, radius: number, color: Color3, zIndex: number)
		local parts = {}
		for i = 0, 2 do
			local bar = Instance.new("Frame")
			bar.AnchorPoint = CENTER
			bar.Position = UDim2.fromScale(0.5, 0.5)
			bar.Size = UDim2.fromOffset(math.round(SQRT3 * radius), math.round(radius))
			bar.Rotation = i * 60
			bar.BackgroundColor3 = color
			bar.BorderSizePixel = 0
			bar.ZIndex = zIndex
			bar.Parent = parent
			parts[i + 1] = bar
		end
		return parts
	end
	local function paint(parts, color: Color3)
		for _, bar in parts do
			bar.BackgroundColor3 = color
		end
	end

	-- Eine Wabe an der Netz-Position (q, r)
	local function makeCell(q: number, r: number)
		local frame = Instance.new("Frame")
		frame.AnchorPoint = CENTER
		frame.Position = UDim2.fromOffset(math.round(HEX_X + UNIT * (q + r / 2)), math.round(HEX_Y + S * 1.5 * r))
		frame.Size = UDim2.fromOffset(math.round(UNIT), S * 2)
		frame.BackgroundTransparency = 1
		frame.Parent = skillPanel
		local scale = Instance.new("UIScale")
		scale.Parent = frame
		local border = hexagon(frame, S - 1, BLACK, 2)
		local fill = hexagon(frame, S - 5, BLACK, 3)
		local icon = label({
			AnchorPoint = CENTER,
			Position = UDim2.fromScale(0.5, 0.4),
			Size = UDim2.fromOffset(S * 0.9, S * 0.9),
			ZIndex = 4,
			Text = "",
			Parent = frame,
		})
		local sub = label({
			AnchorPoint = CENTER,
			Position = UDim2.fromScale(0.5, 0.76),
			Size = UDim2.fromOffset(S * 1.1, S * 0.36),
			Font = Enum.Font.FredokaOne,
			TextStrokeTransparency = 0.3,
			ZIndex = 4,
			Text = "",
			Parent = frame,
		})
		local button = Instance.new("TextButton")
		button.AnchorPoint = CENTER
		button.Position = UDim2.fromScale(0.5, 0.5)
		button.Size = UDim2.fromOffset(math.round(UNIT), math.round(S * 1.5))
		button.BackgroundTransparency = 1
		button.Text = ""
		button.ZIndex = 5
		button.Parent = frame
		return { Frame = frame, Scale = scale, Border = border, Fill = fill, Icon = icon, Sub = sub, Button = button, CanBuy = false }
	end

	-- Legende unten in einer Reihe: welche Farbe ist welcher Bereich
	for i, id in { "Geld", "Glueck", "Dieb" } do
		local branch = Config.Skills.Branches[id]
		label({
			Size = UDim2.fromOffset(164, 24),
			Position = UDim2.fromOffset(16 + (i - 1) * 168, 562),
			Font = Enum.Font.FredokaOne,
			TextColor3 = branch.Color,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = `{branch.Icon} {branch.Name}`,
			Parent = skillPanel,
		})
	end

	-- Rechts: Infos zur gewählten Wabe
	local detail = Instance.new("Frame")
	detail.Size = UDim2.fromOffset(400, 484)
	detail.Position = UDim2.fromOffset(528, 76)
	detail.BackgroundColor3 = Color3.fromRGB(40, 36, 60)
	detail.Parent = skillPanel
	corner(detail, 12)
	local detailStroke = stroke(detail, SKILL_COLOR, 2)
	local dBranch = label({
		Size = UDim2.fromOffset(368, 24),
		Position = UDim2.fromOffset(16, 12),
		Font = Enum.Font.FredokaOne,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
		Parent = detail,
	})
	local dIcon = label({ Size = UDim2.fromOffset(72, 72), Position = UDim2.fromOffset(14, 44), Text = "", Parent = detail })
	local dName = label({
		Size = UDim2.fromOffset(286, 38),
		Position = UDim2.fromOffset(98, 46),
		Font = Enum.Font.FredokaOne,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
		Parent = detail,
	})
	local dLevel = label({
		Size = UDim2.fromOffset(286, 24),
		Position = UDim2.fromOffset(98, 88),
		TextColor3 = GOLD,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
		Parent = detail,
	})
	local function textBlock(y: number, height: number, size: number, color: Color3): TextLabel
		return label({
			Size = UDim2.fromOffset(368, height),
			Position = UDim2.fromOffset(16, y),
			TextScaled = false,
			TextSize = size,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextColor3 = color,
			Text = "",
			Parent = detail,
		})
	end
	local dNow = textBlock(132, 50, 19, WHITE)
	local dNext = textBlock(186, 50, 19, Color3.fromRGB(130, 255, 150))
	local dHint = textBlock(242, 46, 16, Color3.fromRGB(205, 200, 225))
	dHint.Font = Enum.Font.Gotham
	local learn = Instance.new("TextButton")
	learn.Size = UDim2.fromOffset(368, 60)
	learn.Position = UDim2.fromOffset(16, 296)
	learn.BackgroundColor3 = GREY
	learn.TextColor3 = WHITE
	learn.Font = Enum.Font.FredokaOne
	learn.TextScaled = true
	learn.Text = ""
	learn.Parent = detail
	corner(learn, 12)
	local learnScale = Instance.new("UIScale")
	learnScale.Parent = learn
	local dHelp = textBlock(372, 100, 16, Color3.fromRGB(190, 185, 215))
	dHelp.Font = Enum.Font.Gotham
	dHelp.Text = `💠 Tokens bekommst du so:\n• +{Config.Rebirth.TokensPerRebirth} für jede Wiedergeburt\n• +{Config.Skills.TokensPerQuest} für jede {Config.Skills.QuestsPerToken}. geschaffte Aufgabe\nLernen kannst du nur Waben, die an eine gelernte grenzen.`

	local cells = {}
	local selected = nil -- gewählte Fähigkeit (nil = die Mitte)
	local lastLevels = {} -- zum Erkennen, was gerade gelernt wurde
	local refreshSkills

	-- Stufen aller Fähigkeiten (der Server schreibt sie als Attribute an den Spieler)
	local function levels()
		local t = {}
		for _, skill in Config.Skills.List do
			t[skill.Id] = player:GetAttribute("Sk_" .. skill.Id) or 0
		end
		return t
	end

	-- Mitte: Start-Wabe mit den Tokens
	local centerCell = makeCell(0, 0)
	paint(centerCell.Border, TOKEN_BLUE)
	paint(centerCell.Fill, Color3.fromRGB(36, 60, 96))
	centerCell.Icon.Text = "💠"
	centerCell.Sub.TextColor3 = TOKEN_BLUE
	centerCell.Button.Activated:Connect(function()
		selected = nil
		playSound("Click")
		refreshSkills()
	end)

	for _, skill in Config.Skills.List do
		local cell = makeCell(skill.Hex[1], skill.Hex[2])
		cell.Icon.Text = skill.Icon
		cells[skill.Id] = cell
		cell.Button.Activated:Connect(function()
			selected = skill
			playSound("Click")
			cell.Scale.Scale = 1.12
			tween(cell.Scale, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
			refreshSkills()
		end)
	end

	-- Gibt es gerade etwas zu lernen? (für den pulsierenden Knopf)
	local function canLearnAny(): boolean
		local lv = levels()
		local tokens = player:GetAttribute("Tokens") or 0
		for _, skill in Config.Skills.List do
			local level = lv[skill.Id]
			if level < skill.Max and tokens >= skill.Costs[level + 1] and Config.SkillReachable(lv, skill) then
				return true
			end
		end
		return false
	end

	local function refreshBadge()
		local tokens = player:GetAttribute("Tokens") or 0
		local show = canLearnAny()
		skillBadge.Visible = show
		skillBadge.Text = tostring(tokens)
	end

	function refreshSkills()
		local lv = levels()
		local tokens = player:GetAttribute("Tokens") or 0
		tokenTitle.Text = `💠 Deine Tokens: {tokens}`
		centerCell.Sub.Text = tostring(tokens)
		paint(centerCell.Border, if selected == nil then WHITE else TOKEN_BLUE)

		for _, skill in Config.Skills.List do
			local cell = cells[skill.Id]
			local level = lv[skill.Id]
			local color = Config.Skills.Branches[skill.Branch].Color
			local reachable = Config.SkillReachable(lv, skill)
			local fillColor, borderColor
			local dim = false
			if level >= skill.Max then
				fillColor, borderColor = color, GOLD
				cell.Sub.Text = "MAX"
			elseif level > 0 then
				fillColor, borderColor = color:Lerp(BLACK, 0.5), color
				cell.Sub.Text = `{level}/{skill.Max}`
			elseif reachable then
				fillColor, borderColor = Color3.fromRGB(58, 53, 84), color:Lerp(BLACK, 0.25)
				cell.Sub.Text = `{skill.Costs[1]} 💠`
			else
				fillColor, borderColor = Color3.fromRGB(31, 28, 44), Color3.fromRGB(64, 60, 88)
				cell.Sub.Text = "🔒"
				dim = true
			end
			cell.CanBuy = level < skill.Max and reachable and tokens >= skill.Costs[level + 1]
			paint(cell.Fill, fillColor)
			paint(cell.Border, if selected == skill then WHITE else borderColor)
			cell.Icon.TextTransparency = if dim then 0.65 else 0
			cell.Sub.TextTransparency = if dim then 0.4 else 0

			-- gerade gelernt? Dann springt die Wabe auf und sprüht Sterne
			if lastLevels[skill.Id] and level > lastLevels[skill.Id] and skillPanel.Visible then
				cell.Scale.Scale = 1.35
				tween(cell.Scale, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
				local inset = GuiService:GetGuiInset()
				local middle = cell.Frame.AbsolutePosition + cell.Frame.AbsoluteSize / 2 + inset
				ctx.StarBurst(UDim2.fromOffset(middle.X, middle.Y), color, 14, 120)
			end
			lastLevels[skill.Id] = level
		end

		-- Infos rechts
		if selected == nil then
			detailStroke.Color = SKILL_COLOR
			dBranch.Text = "Start"
			dBranch.TextColor3 = TOKEN_BLUE
			dIcon.Text = "💠"
			dName.Text = "Dein Skill-Baum"
			dLevel.Text = `{tokens} Tokens zum Ausgeben`
			dNow.Text = "Tippe eine Wabe an, um zu sehen, was sie kann."
			dNext.Text = "Fang direkt neben der Mitte an und arbeite dich nach außen vor."
			dHint.Text = "Ganz außen an den drei Spitzen warten die stärksten Fähigkeiten."
			learn.Visible = false
			return
		end
		local skill = selected
		local level = lv[skill.Id]
		local branch = Config.Skills.Branches[skill.Branch]
		local reachable = Config.SkillReachable(lv, skill)
		detailStroke.Color = branch.Color
		dBranch.Text = `{branch.Icon} {branch.Name}`
		dBranch.TextColor3 = branch.Color
		dIcon.Text = skill.Icon
		dName.Text = skill.Name
		dLevel.Text = if skill.Max > 1 then `Stufe {level} / {skill.Max}` elseif level > 0 then "Gelernt" else "Spitzen-Fähigkeit"
		dNow.Text = if level > 0 then `Jetzt: {Config.SkillText(skill, level)}` else "Noch nicht gelernt."
		learn.Visible = true
		if level >= skill.Max then
			dNext.Text = "Maximum erreicht!"
			dHint.Text = ""
			learn.Text = "MAX"
			learn.BackgroundColor3 = Color3.fromRGB(200, 160, 40)
		else
			local cost = skill.Costs[level + 1]
			dNext.Text = `{if level > 0 then "Nächste Stufe" else "Bringt dir"}: {Config.SkillText(skill, level + 1)}`
			if not reachable then
				dHint.Text = "🔒 Lerne zuerst eine Wabe direkt daneben."
				learn.Text = `GESPERRT · {cost} 💠`
				learn.BackgroundColor3 = GREY
			elseif tokens < cost then
				dHint.Text = `Dir fehlen noch {cost - tokens} Tokens.`
				learn.Text = `LERNEN · {cost} 💠`
				learn.BackgroundColor3 = GREY
			else
				dHint.Text = ""
				learn.Text = `LERNEN · {cost} 💠`
				learn.BackgroundColor3 = GREEN
			end
		end
	end

	learn.Activated:Connect(function()
		if not selected then
			return
		end
		local cell = cells[selected.Id]
		if cell.CanBuy then
			learnScale.Scale = 0.92
			tween(learnScale, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
			Remotes.BuySkill:FireServer(selected.Id)
		else
			playSound("Click", 0.6)
		end
	end)

	player.AttributeChanged:Connect(function(name)
		if name == "Tokens" or string.sub(name, 1, 3) == "Sk_" then
			refreshBadge()
			if skillPanel.Visible then
				refreshSkills()
			end
		end
	end)
	refreshBadge()

	local function toggleSkills()
		if ctx.Busy() then
			return
		end
		if skillPanel.Visible then
			skillPanel.Visible = false
		else
			lastLevels = levels()
			refreshSkills()
			showSkillPanel()
		end
		playSound("Click")
	end
	skillButton.Activated:Connect(toggleSkills)

	-- Waben, die man sich gerade leisten kann, pulsieren leicht. Der Knopf auch.
	task.spawn(function()
		while true do
			if skillPanel.Visible then
				for _, cell in cells do
					if cell.CanBuy then
						tween(cell.Scale, 0.45, { Scale = 1.07 })
					end
				end
				task.wait(0.45)
				for _, cell in cells do
					if cell.Scale.Scale > 1 then
						tween(cell.Scale, 0.45, { Scale = 1 })
					end
				end
				task.wait(0.5)
			elseif skillBadge.Visible then
				tween(skillButtonScale, 0.4, { Scale = 1.12 }).Completed:Wait()
				tween(skillButtonScale, 0.4, { Scale = 1 }).Completed:Wait()
			else
				task.wait(0.5)
			end
		end
	end)

	-- Inventar --------------------------------------------------------------------------
	-- Alle Kreaturen als Kacheln: die aktiven (stehen in der Base) zuerst, dann der Rest.
	-- Rechts die gewählte Kreatur mit den Knöpfen Aufstellen/Einpacken, Verbessern, Verkaufen.
	local BAG_COLOR = Color3.fromRGB(120, 200, 255)
	local RED = Color3.fromRGB(215, 70, 70)
	local BLUE = Color3.fromRGB(60, 140, 235)
	local TILE_W, TILE_H = 94, 126
	local bagButton, bagButtonScale, bagBadge = hudButton(4, Color3.fromRGB(70, 150, 235), "🎒", "Inventar", "V")
	local bagPanel, showBagPanel = window(830, 560, BAG_COLOR, "🎒 Inventar")
	local bagInfo = label({
		Size = UDim2.fromOffset(330, 24),
		Position = UDim2.fromOffset(215, 16),
		TextScaled = false,
		TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(190, 200, 225),
		Text = "",
		Parent = bagPanel,
	})

	-- Knopf mit Text (für die Leiste oben und die Aktionen rechts)
	local function textButton(parent: Instance, text: string, color: Color3, size: UDim2, position: UDim2): TextButton
		local button = Instance.new("TextButton")
		button.Size = size
		button.Position = position
		button.BackgroundColor3 = color
		button.TextColor3 = WHITE
		button.Font = Enum.Font.FredokaOne
		button.TextScaled = true
		button.Text = text
		button.Parent = parent
		corner(button, 10)
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 10)
		pad.PaddingRight = UDim.new(0, 10)
		pad.PaddingTop = UDim.new(0, 7)
		pad.PaddingBottom = UDim.new(0, 7)
		pad.Parent = button
		return button
	end
	local function setEnabled(button: TextButton, enabled: boolean, color: Color3)
		button.Active = enabled
		button.AutoButtonColor = enabled
		button.BackgroundColor3 = if enabled then color else GREY
		button.TextTransparency = if enabled then 0 else 0.35
	end

	local bestButton = textButton(bagPanel, "⬆ Beste aufstellen", BLUE, UDim2.fromOffset(250, 38), UDim2.fromOffset(12, 56))
	local allButton = textButton(bagPanel, "⭐ Alle verbessern", GREEN, UDim2.fromOffset(250, 38), UDim2.fromOffset(272, 56))

	local bagScroll = Instance.new("ScrollingFrame")
	bagScroll.Size = UDim2.fromOffset(530, 446)
	bagScroll.Position = UDim2.fromOffset(12, 104)
	bagScroll.BackgroundColor3 = Color3.fromRGB(20, 18, 32)
	bagScroll.BorderSizePixel = 0
	bagScroll.ScrollBarThickness = 8
	bagScroll.CanvasSize = UDim2.new()
	bagScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	bagScroll.Parent = bagPanel
	corner(bagScroll, 10)
	local bagGrid = Instance.new("UIGridLayout")
	bagGrid.CellSize = UDim2.fromOffset(TILE_W, TILE_H)
	bagGrid.CellPadding = UDim2.fromOffset(8, 8)
	bagGrid.SortOrder = Enum.SortOrder.LayoutOrder
	bagGrid.Parent = bagScroll
	local bagPad = Instance.new("UIPadding")
	bagPad.PaddingLeft = UDim.new(0, 8)
	bagPad.PaddingTop = UDim.new(0, 8)
	bagPad.PaddingBottom = UDim.new(0, 8)
	bagPad.Parent = bagScroll
	local bagEmpty = label({
		Size = UDim2.fromOffset(470, 80),
		Position = UDim2.fromOffset(42, 250),
		TextScaled = false,
		TextSize = 20,
		TextWrapped = true,
		TextColor3 = Color3.fromRGB(170, 165, 195),
		Text = "Noch keine Kreaturen.\nÖffne eine Kiste im Shop!",
		Visible = false,
		Parent = bagPanel,
	})

	-- Rechte Seite: die gewählte Kreatur
	local detail = Instance.new("Frame")
	detail.Size = UDim2.fromOffset(264, 494)
	detail.Position = UDim2.fromOffset(554, 56)
	detail.BackgroundColor3 = Color3.fromRGB(36, 32, 54)
	detail.Parent = bagPanel
	corner(detail, 12)
	local detailStroke = stroke(detail, BAG_COLOR, 2)
	local detailIcon = Instance.new("Frame")
	detailIcon.Size = UDim2.fromOffset(264, 124)
	detailIcon.BackgroundTransparency = 1
	detailIcon.Parent = detail
	local detailStars = label({
		Size = UDim2.new(1, 0, 0, 24),
		Position = UDim2.fromOffset(0, 118),
		Font = Enum.Font.FredokaOne,
		TextColor3 = GOLD,
		Text = "",
		Parent = detail,
	})
	local detailName = label({
		Size = UDim2.new(1, -16, 0, 28),
		Position = UDim2.fromOffset(8, 142),
		Font = Enum.Font.FredokaOne,
		Text = "",
		Parent = detail,
	})
	local detailRarity = label({
		Size = UDim2.new(1, -16, 0, 18),
		Position = UDim2.fromOffset(8, 171),
		TextColor3 = Color3.fromRGB(190, 185, 215),
		Text = "",
		Parent = detail,
	})
	local detailIncome = label({
		Size = UDim2.new(1, -16, 0, 26),
		Position = UDim2.fromOffset(8, 191),
		Font = Enum.Font.FredokaOne,
		TextColor3 = Color3.fromRGB(130, 255, 150),
		Text = "",
		Parent = detail,
	})
	-- Futter-Balken für den nächsten Stern
	local feedTitle = label({
		Size = UDim2.new(1, -16, 0, 18),
		Position = UDim2.fromOffset(8, 224),
		TextScaled = false,
		TextSize = 15,
		TextColor3 = GOLD,
		Text = "",
		Parent = detail,
	})
	local feedBar = Instance.new("Frame")
	feedBar.Size = UDim2.new(1, -32, 0, 20)
	feedBar.Position = UDim2.fromOffset(16, 245)
	feedBar.BackgroundColor3 = Color3.fromRGB(20, 18, 32)
	feedBar.Parent = detail
	corner(feedBar, 10)
	local feedFill = Instance.new("Frame")
	feedFill.Size = UDim2.fromScale(0, 1)
	feedFill.BackgroundColor3 = GOLD
	feedFill.BorderSizePixel = 0
	feedFill.Parent = feedBar
	corner(feedFill, 10)
	local feedText = label({
		Size = UDim2.fromScale(1, 1),
		TextScaled = false,
		TextSize = 14,
		TextStrokeTransparency = 0.4,
		ZIndex = 2,
		Text = "",
		Parent = feedBar,
	})
	local feedAfter = label({
		Size = UDim2.new(1, -16, 0, 18),
		Position = UDim2.fromOffset(8, 268),
		TextScaled = false,
		TextSize = 14,
		Font = Enum.Font.Gotham,
		TextColor3 = Color3.fromRGB(190, 185, 215),
		Text = "",
		Parent = detail,
	})
	local equipButton = textButton(detail, "Aufstellen", BLUE, UDim2.new(1, -24, 0, 42), UDim2.fromOffset(12, 294))
	local starButton = textButton(detail, "⭐ Verbessern", GREEN, UDim2.new(1, -24, 0, 42), UDim2.fromOffset(12, 342))
	local sellButton = textButton(detail, "Verkaufen", RED, UDim2.new(1, -24, 0, 38), UDim2.fromOffset(12, 390))
	local sellAllButton = textButton(detail, "Alle verkaufen", RED, UDim2.new(1, -24, 0, 34), UDim2.fromOffset(12, 432))
	label({
		Size = UDim2.new(1, -16, 0, 18),
		Position = UDim2.fromOffset(8, 471),
		Font = Enum.Font.Gotham,
		TextColor3 = Color3.fromRGB(150, 145, 175),
		Text = "Futter: gleiche Art, nur schwächere",
		Parent = detail,
	})

	local bag = { Size = Config.Inventory.Size, Count = 0, Slots = 0, Items = {} } -- vom Server
	local bagShown = "" -- was gerade als Kacheln dasteht (damit nicht unnötig neu gebaut wird)
	local selectedKey: string? = nil -- "S3" = aktive auf Platz 3, "B" .. Eintrag = im Inventar
	local selectedLike: string? = nil -- Art und Mutation der zuletzt gewählten (falls ihr Eintrag sich ändert)
	local tiles = {} -- [key] = { Frame, Stroke }
	local detailShown = "" -- welche Kreatur das große Bild gerade zeigt
	local confirm: { Button: TextButton, Until: number }? = nil -- "Sicher?" beim Verkaufen

	local function itemKey(item): string
		return if item.Slot then "S" .. item.Slot else "B" .. item.Entry
	end
	local function likeOf(entry: string): string
		local def, mutation = Config.ParseEntry(entry)
		return if def then def.Id .. "|" .. mutation else ""
	end
	local function ready(item): boolean
		return item.Cost ~= nil and item.Have >= item.Cost and not item.Stolen
	end
	local function findItem(key: string?)
		for _, item in bag.Items do
			if itemKey(item) == key then
				return item
			end
		end
		return nil
	end

	-- Kleines, stilles Bild einer Kreatur (ohne Hüpfen, damit viele Kacheln nichts kosten)
	local function staticIcon(parent: GuiObject, def, mutationId: string, size: number, y: number)
		local mutation = Config.Mutations[mutationId] or Config.Mutations.Normal
		local glow = Instance.new("Frame")
		glow.AnchorPoint = CENTER
		glow.Position = UDim2.new(0.5, 0, 0, y + size / 2)
		glow.Size = UDim2.fromOffset(size * 0.9, size * 0.9)
		glow.BackgroundColor3 = mutation.Color or Config.Rarities[def.Rarity].Color
		glow.BackgroundTransparency = 0.72
		glow.BorderSizePixel = 0
		glow.Parent = parent
		corner(glow, size)
		local folder = ReplicatedStorage:FindFirstChild("KreaturenModelle")
		local template = folder and folder:FindFirstChild(def.Id)
		if template and template:IsA("Model") then
			local vp = Instance.new("ViewportFrame")
			vp.AnchorPoint = Vector2.new(0.5, 0)
			vp.Position = UDim2.new(0.5, 0, 0, y)
			vp.Size = UDim2.fromOffset(size, size)
			vp.BackgroundTransparency = 1
			vp.Ambient = Color3.fromRGB(165, 165, 180)
			vp.LightColor = WHITE
			vp.LightDirection = Vector3.new(-0.3, -0.8, 1)
			if mutation.Color then
				vp.ImageColor3 = WHITE:Lerp(mutation.Color, 0.35)
			end
			local model = template:Clone()
			model:PivotTo(CFrame.new())
			model.Parent = vp
			local camera = Instance.new("Camera")
			camera.FieldOfView = 30
			camera.Parent = vp
			vp.CurrentCamera = camera
			local boxCF, boxSize = model:GetBoundingBox()
			local radius = math.max(boxSize.X, boxSize.Y, boxSize.Z) * 0.62
			local dist = radius / math.tan(math.rad(camera.FieldOfView / 2))
			camera.CFrame = CFrame.lookAt(boxCF.Position + Vector3.new(dist * 0.35, boxSize.Y * 0.15, -dist), boxCF.Position)
			vp.Parent = parent
			return
		end
		local swatch = Instance.new("Frame")
		swatch.AnchorPoint = CENTER
		swatch.Position = UDim2.new(0.5, 0, 0, y + size / 2)
		swatch.Size = UDim2.fromOffset(size * 0.7, size * 0.7)
		swatch.BackgroundColor3 = mutation.Color or def.Color
		swatch.Parent = parent
		corner(swatch, math.floor(size * 0.16))
	end

	local refreshDetail

	local function selectItem(key: string?)
		selectedKey = key
		local item = findItem(key)
		if item then
			selectedLike = likeOf(item.Entry)
		end
		for tileKey, tile in tiles do
			tile.Stroke.Color = if tileKey == key then WHITE else tile.Color
			tile.Stroke.Thickness = if tileKey == key then 3 else 2
		end
		confirm = nil
		refreshDetail()
	end

	local function makeTile(item, order: number)
		local def, mutation, stars = Config.ParseEntry(item.Entry)
		if not def then
			return
		end
		local key = itemKey(item)
		local color = Config.Rarities[def.Rarity].Color
		local tile = Instance.new("TextButton")
		tile.Text = ""
		tile.AutoButtonColor = false
		tile.BackgroundColor3 = if item.Slot then Color3.fromRGB(40, 58, 52) else Color3.fromRGB(44, 40, 64)
		tile.LayoutOrder = order
		tile.Parent = bagScroll
		corner(tile, 10)
		local tileStroke = stroke(tile, color, 2)
		tileStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		staticIcon(tile, def, mutation, 62, 14)
		if item.Slot then
			-- Band oben: steht in der Base
			local ribbon = label({
				Size = UDim2.new(1, 0, 0, 15),
				BackgroundTransparency = 0,
				BackgroundColor3 = if item.Stolen then RED else GREEN,
				TextScaled = false,
				TextSize = 11,
				Font = Enum.Font.GothamBold,
				ZIndex = 3,
				Text = if item.Stolen then "WIRD GEKLAUT" else "AKTIV",
				Parent = tile,
			})
			corner(ribbon, 8)
		elseif item.Count > 1 then
			local count = label({
				Size = UDim2.fromOffset(40, 18),
				Position = UDim2.new(1, -44, 0, 3),
				Font = Enum.Font.FredokaOne,
				TextXAlignment = Enum.TextXAlignment.Right,
				TextStrokeTransparency = 0,
				ZIndex = 3,
				Text = `x{item.Count}`,
				Parent = tile,
			})
			count.TextStrokeColor3 = BLACK
		end
		if stars > 0 then
			local starLabel = label({
				Size = UDim2.new(1, 0, 0, 16),
				Position = UDim2.fromOffset(0, 62),
				Font = Enum.Font.FredokaOne,
				TextColor3 = GOLD,
				TextStrokeTransparency = 0,
				ZIndex = 3,
				Text = Config.StarText(stars),
				Parent = tile,
			})
			starLabel.TextStrokeColor3 = BLACK
		end
		-- Name in der Farbe der Mutation, damit man z.B. Gold und Normal auseinanderhält
		local nameLabel = label({
			Size = UDim2.new(1, -6, 0, 14),
			Position = UDim2.fromOffset(3, 79),
			TextColor3 = Config.Mutations[mutation].Color or WHITE,
			Text = def.Name,
			Parent = tile,
		})
		if mutation == "Regenbogen" then
			nameLabel.Text = "🌈 " .. def.Name
		end
		label({
			Size = UDim2.new(1, -6, 0, 16),
			Position = UDim2.fromOffset(3, 94),
			TextColor3 = Color3.fromRGB(130, 255, 150),
			Text = `+{Config.FormatRate(Config.EntryIncome(item.Entry))} $/s`,
			Parent = tile,
		})
		if item.Cost then
			-- Futter-Balken ganz unten
			local bar = Instance.new("Frame")
			bar.Size = UDim2.new(1, -12, 0, 6)
			bar.Position = UDim2.new(0, 6, 1, -11)
			bar.BackgroundColor3 = Color3.fromRGB(20, 18, 32)
			bar.BorderSizePixel = 0
			bar.Parent = tile
			corner(bar, 3)
			local fill = Instance.new("Frame")
			fill.Size = UDim2.fromScale(math.clamp(item.Have / item.Cost, 0, 1), 1)
			fill.BackgroundColor3 = if ready(item) then GREEN else GOLD
			fill.BorderSizePixel = 0
			fill.Parent = bar
			corner(fill, 3)
		end
		if ready(item) then
			-- kann sofort verbessert werden
			local up = label({
				Size = UDim2.fromOffset(22, 22),
				Position = UDim2.fromOffset(4, if item.Slot then 18 else 4),
				BackgroundTransparency = 0,
				BackgroundColor3 = GREEN,
				Font = Enum.Font.FredokaOne,
				ZIndex = 4,
				Text = "⬆",
				Parent = tile,
			})
			corner(up, 11)
		end
		tiles[key] = { Frame = tile, Stroke = tileStroke, Color = color }
		tile.Activated:Connect(function()
			playSound("Click")
			selectItem(key)
		end)
	end

	function refreshDetail()
		local item = findItem(selectedKey)
		detail.Visible = item ~= nil
		if not item then
			detailShown = ""
			return
		end
		local def, mutation, stars = Config.ParseEntry(item.Entry)
		if not def then
			return
		end
		local rarity = Config.Rarities[def.Rarity]
		if detailShown ~= item.Entry then
			detailShown = item.Entry
			detailIcon:ClearAllChildren()
			local _, iconScale = ctx.CreatureIcon(detailIcon, def, mutation, 112, 8)
			if iconScale then
				iconScale.Scale = 0.6
				tween(iconScale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
			end
		end
		detailStroke.Color = rarity.Color
		detailStars.Text = Config.StarText(stars)
		local m = Config.Mutations[mutation]
		detailName.Text = if m.Name ~= "" then `{m.Name}-{def.Name}` else def.Name
		detailName.TextColor3 = rarity.Color
		detailRarity.Text = if item.Slot then `{rarity.Name} · steht in der Base` elseif item.Count > 1 then `{rarity.Name} · {item.Count}x im Inventar` else `{rarity.Name} · im Inventar`
		detailIncome.Text = `+{Config.FormatRate(Config.EntryIncome(item.Entry))} $/s`

		local canUse = not item.Stolen
		if item.Cost then
			feedTitle.Text = `Futter für {Config.StarText(stars + 1)}`
			feedBar.Visible = true
			feedFill.Size = UDim2.fromScale(math.clamp(item.Have / item.Cost, 0, 1), 1)
			feedFill.BackgroundColor3 = if ready(item) then GREEN else GOLD
			feedText.Text = `{item.Have} / {item.Cost}`
			feedAfter.Text = `danach +{Config.FormatRate(Config.EntryIncome(Config.MakeEntry(def.Id, mutation, stars + 1)))} $/s`
			starButton.Text = if ready(item) then "⭐ Verbessern" else `Noch {item.Cost - item.Have} Futter`
			setEnabled(starButton, ready(item), GREEN)
		else
			feedTitle.Text = "Alle Sterne erreicht!"
			feedBar.Visible = false
			feedAfter.Text = ""
			starButton.Text = "⭐ Maximal"
			setEnabled(starButton, false, GREEN)
		end
		equipButton.Text = if item.Slot then "Einpacken" else "Aufstellen"
		setEnabled(equipButton, canUse, BLUE)
		local price = item.Price or 0
		if not (confirm and confirm.Button == sellButton) then
			sellButton.Text = `Verkaufen ({Config.FormatNumber(price)} $)`
		end
		setEnabled(sellButton, canUse, RED)
		sellAllButton.Visible = not item.Slot and item.Count > 1
		if not (confirm and confirm.Button == sellAllButton) then
			sellAllButton.Text = `Alle {item.Count} verkaufen ({Config.FormatNumber(price * item.Count)} $)`
		end
	end

	local function sortedItems()
		local list = table.clone(bag.Items)
		table.sort(list, function(a, b)
			if (a.Slot ~= nil) ~= (b.Slot ~= nil) then
				return a.Slot ~= nil -- die aktiven zuerst
			end
			local ia, ib = Config.EntryIncome(a.Entry), Config.EntryIncome(b.Entry)
			if ia ~= ib then
				return ia > ib
			end
			return itemKey(a) < itemKey(b)
		end)
		return list
	end

	local function rebuildBag()
		local list = sortedItems()
		local active, readyCount = 0, 0
		local parts = {}
		for _, item in list do
			if item.Slot then
				active += 1
			end
			if ready(item) then
				readyCount += 1
			end
			table.insert(parts, `{itemKey(item)}:{item.Entry}:{item.Count}:{item.Have}:{tostring(item.Stolen)}`)
		end
		bagInfo.Text = `Aktiv {active}/{bag.Slots} · Inventar {bag.Count}/{bag.Size}`
		bagEmpty.Visible = #list == 0
		setEnabled(allButton, readyCount > 0, GREEN)
		local signature = table.concat(parts, ";")
		if signature ~= bagShown then
			bagShown = signature
			for _, child in bagScroll:GetChildren() do
				if child:IsA("TextButton") then
					child:Destroy()
				end
			end
			table.clear(tiles)
			for i, item in list do
				makeTile(item, i)
			end
		end
		-- Auswahl behalten. Gibt es sie nicht mehr (verbessert, aufgestellt, verkauft), die
		-- nächste von derselben Art nehmen, sonst die erste.
		if not findItem(selectedKey) then
			local pick = nil
			for _, item in list do
				if likeOf(item.Entry) == selectedLike then
					pick = item
					break
				end
			end
			pick = pick or list[1]
			selectedKey = if pick then itemKey(pick) else nil
		end
		selectItem(selectedKey)
	end

	Remotes.Inventory.OnClientEvent:Connect(function(data)
		if type(data) ~= "table" or type(data.Items) ~= "table" then
			return
		end
		bag = data
		-- Plakette: bei so vielen Arten kann gerade etwas verbessert werden
		local kinds, count = {}, 0
		for _, item in bag.Items do
			local def = Config.ParseEntry(item.Entry)
			if def and ready(item) and not kinds[def.Id] then
				kinds[def.Id] = true
				count += 1
			end
		end
		bagBadge.Visible = count > 0
		bagBadge.Text = tostring(count)
		if bagPanel.Visible then
			rebuildBag()
		end
	end)

	local function send(action: string, entry: string?, slot: number?)
		Remotes.InventoryAction:FireServer(action, entry, slot)
	end
	-- Verkaufen mit Nachfrage: erst beim zweiten Tippen (innerhalb von 3 Sekunden) wird verkauft
	local function confirmed(button: TextButton): boolean
		if confirm and confirm.Button == button and os.clock() < confirm.Until then
			confirm = nil
			return true
		end
		confirm = { Button = button, Until = os.clock() + 3 }
		button.Text = "Sicher? Nochmal tippen"
		task.delay(3, function()
			if confirm and confirm.Button == button and os.clock() >= confirm.Until then
				confirm = nil
				refreshDetail()
			end
		end)
		return false
	end

	equipButton.Activated:Connect(function()
		local item = findItem(selectedKey)
		if not item or not equipButton.Active then
			return
		end
		playSound("Click")
		if item.Slot then
			send("Unequip", nil, item.Slot)
		else
			send("Equip", item.Entry)
		end
	end)
	starButton.Activated:Connect(function()
		local item = findItem(selectedKey)
		if not item or not starButton.Active then
			return
		end
		send("StarUp", item.Entry, item.Slot)
		local middle = detailIcon.AbsolutePosition + detailIcon.AbsoluteSize / 2 + GuiService:GetGuiInset()
		ctx.StarBurst(UDim2.fromOffset(middle.X, middle.Y), GOLD, 14, 120)
	end)
	sellButton.Activated:Connect(function()
		local item = findItem(selectedKey)
		if not item or not sellButton.Active then
			return
		end
		-- Wertvolles (aktiv, mit Stern oder ab Episch) nur mit Nachfrage
		local def, _, stars = Config.ParseEntry(item.Entry)
		local precious = item.Slot ~= nil or stars > 0 or (def ~= nil and Config.RarityRank(def.Rarity) >= Config.RarityRank("Epic"))
		if precious and not confirmed(sellButton) then
			return
		end
		if item.Slot then
			send("SellActive", nil, item.Slot)
		else
			send("Sell", item.Entry)
		end
	end)
	sellAllButton.Activated:Connect(function()
		local item = findItem(selectedKey)
		if not item or item.Slot or not confirmed(sellAllButton) then
			return
		end
		send("SellAll", item.Entry)
	end)
	bestButton.Activated:Connect(function()
		playSound("Click")
		send("EquipBest")
	end)
	allButton.Activated:Connect(function()
		if not allButton.Active then
			return
		end
		send("StarUpAll")
	end)

	local function toggleBag()
		if ctx.Busy() then
			return
		end
		if bagPanel.Visible then
			bagPanel.Visible = false
		else
			rebuildBag()
			showBagPanel()
		end
		playSound("Click")
	end
	bagButton.Activated:Connect(toggleBag)

	task.spawn(function()
		while true do
			if bagBadge.Visible and not bagPanel.Visible then
				tween(bagButtonScale, 0.35, { Scale = 1.15 }).Completed:Wait()
				tween(bagButtonScale, 0.35, { Scale = 1 }).Completed:Wait()
			else
				task.wait(0.5)
			end
		end
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.K then
			toggleSkills()
		elseif input.KeyCode == Enum.KeyCode.V or input.KeyCode == Enum.KeyCode.B then
			toggleBag()
		end
	end)

	return {
		SkillPanel = skillPanel,
		BagPanel = bagPanel,
		ToggleSkills = toggleSkills,
		ToggleBag = toggleBag,
	}
end
