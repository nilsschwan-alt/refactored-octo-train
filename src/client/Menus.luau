-- Skill-Baum (Waben-Netz) und Fusion (3 gleiche Kreaturen zu einer mit Stern verschmelzen).
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

	-- Fusion ----------------------------------------------------------------------------
	local MERGE_COLOR = GOLD
	local mergeButton, mergeButtonScale, mergeBadge = hudButton(4, Color3.fromRGB(235, 150, 40), "✨", "Fusion", "V")
	local mergePanel, showMergePanel = window(600, 500, MERGE_COLOR, "✨ Fusion")
	label({
		Size = UDim2.new(1, -32, 0, 64),
		Position = UDim2.fromOffset(16, 52),
		TextScaled = false,
		TextSize = 17,
		TextWrapped = true,
		Font = Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = Color3.fromRGB(205, 200, 225),
		Text = `{Config.Stars.Need} gleiche Kreaturen (gleiche Mutation, gleiche Sterne) verschmelzen zu einer mit einem Stern mehr, bis zu {Config.Stars.Max} Sterne. Bei voller Base werden doppelte eingelagert statt verkauft und zählen hier mit.`,
		Parent = mergePanel,
	})
	local mergeScroll = Instance.new("ScrollingFrame")
	mergeScroll.Size = UDim2.new(1, -24, 1, -136)
	mergeScroll.Position = UDim2.fromOffset(12, 124)
	mergeScroll.BackgroundTransparency = 1
	mergeScroll.BorderSizePixel = 0
	mergeScroll.ScrollBarThickness = 8
	mergeScroll.CanvasSize = UDim2.new()
	mergeScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	mergeScroll.Parent = mergePanel
	local mergeLayout = Instance.new("UIListLayout")
	mergeLayout.Padding = UDim.new(0, 8)
	mergeLayout.SortOrder = Enum.SortOrder.LayoutOrder
	mergeLayout.Parent = mergeScroll
	local mergeEmpty = label({
		Size = UDim2.new(1, -60, 0, 120),
		Position = UDim2.fromOffset(30, 190),
		TextScaled = false,
		TextSize = 20,
		TextWrapped = true,
		TextColor3 = Color3.fromRGB(170, 165, 195),
		Text = `Gerade gibt es nichts zu verschmelzen.\nSammle {Config.Stars.Need} gleiche Kreaturen, dann tauchen sie hier auf. Doppelte landen bei voller Base im Lager und zählen mit.`,
		Parent = mergePanel,
	})

	local mergeList = {} -- vom Server: { { Entry, Count, Result, Ready }, ... } (Ready = false: es fehlen noch welche)
	local mergeShown = "" -- was gerade in der Liste steht (damit nicht unnötig neu gebaut wird)

	-- Kreatur-Bild mit Sternen darunter
	local function entryIcon(parent: GuiObject, x: number, entry: string)
		local def, mutation, stars = Config.ParseEntry(entry)
		local holder = Instance.new("Frame")
		holder.Size = UDim2.fromOffset(76, 76)
		holder.Position = UDim2.fromOffset(x, 6)
		holder.BackgroundColor3 = Color3.fromRGB(28, 25, 42)
		holder.Parent = parent
		corner(holder, 10)
		if def then
			stroke(holder, Config.Rarities[def.Rarity].Color, 2)
			local _, iconScale = ctx.CreatureIcon(holder, def, mutation, 64, 2)
			iconScale.Scale = 1
		end
		if stars > 0 then
			local starLabel = label({
				Size = UDim2.new(1, 0, 0, 18),
				Position = UDim2.new(0, 0, 1, -19),
				Font = Enum.Font.FredokaOne,
				TextColor3 = GOLD,
				TextStrokeTransparency = 0,
				ZIndex = 3,
				Text = Config.StarText(stars),
				Parent = holder,
			})
			starLabel.TextStrokeColor3 = BLACK
		end
	end

	local function rebuildMerges()
		local parts = {}
		for _, item in mergeList do
			table.insert(parts, `{item.Entry}:{item.Count}:{tostring(item.Ready)}`)
		end
		local signature = table.concat(parts, ";")
		mergeEmpty.Visible = #mergeList == 0
		if signature == mergeShown then
			return
		end
		mergeShown = signature
		for _, child in mergeScroll:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		for i, item in mergeList do
			local row = Instance.new("Frame")
			row.Size = UDim2.new(1, -12, 0, 88)
			row.BackgroundColor3 = Color3.fromRGB(44, 40, 64)
			row.LayoutOrder = i
			row.Parent = mergeScroll
			corner(row, 12)
			entryIcon(row, 6, item.Entry)
			label({
				Size = UDim2.fromOffset(40, 22),
				Position = UDim2.fromOffset(44, 6),
				Font = Enum.Font.FredokaOne,
				TextStrokeTransparency = 0,
				TextXAlignment = Enum.TextXAlignment.Right,
				ZIndex = 3,
				Text = `x{item.Count}`,
				Parent = row,
			})
			label({ Size = UDim2.fromOffset(26, 30), Position = UDim2.fromOffset(86, 29), TextColor3 = GOLD, Font = Enum.Font.FredokaOne, Text = ">", Parent = row })
			entryIcon(row, 116, item.Result)
			local before = Config.EntryIncome(item.Entry) * Config.Stars.Need
			local after = Config.EntryIncome(item.Result)
			label({
				Size = UDim2.fromOffset(206, 26),
				Position = UDim2.fromOffset(202, 8),
				Font = Enum.Font.FredokaOne,
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = Config.EntryName(item.Result),
				Parent = row,
			})
			label({
				Size = UDim2.fromOffset(206, 20),
				Position = UDim2.fromOffset(202, 36),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = Color3.fromRGB(130, 255, 150),
				Text = `+{Config.FormatRate(after)} $/s`,
				Parent = row,
			})
			label({
				Size = UDim2.fromOffset(206, 18),
				Position = UDim2.fromOffset(202, 60),
				Font = Enum.Font.Gotham,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = Color3.fromRGB(190, 185, 215),
				Text = `statt +{Config.FormatRate(before)} $/s für {Config.Stars.Need} Stück`,
				Parent = row,
			})
			local go = Instance.new("TextButton")
			go.Size = UDim2.fromOffset(142, 60)
			go.Position = UDim2.new(1, -150, 0, 14)
			go.BackgroundColor3 = GREEN
			go.TextColor3 = WHITE
			go.Font = Enum.Font.FredokaOne
			go.TextScaled = true
			go.Text = "Verschmelzen"
			go.Parent = row
			corner(go, 12)
			if not item.Ready then
				-- noch nicht genug: zeigt nur, wie viele im Lager und in der Base schon da sind
				go.Active = false
				go.AutoButtonColor = false
				go.BackgroundColor3 = GREY
				go.Text = `Noch {math.max(1, Config.Stars.Need - item.Count)}`
			end
			local pad = Instance.new("UIPadding")
			pad.PaddingLeft = UDim.new(0, 8)
			pad.PaddingRight = UDim.new(0, 8)
			pad.Parent = go
			go.Activated:Connect(function()
				if not go.Active then
					return
				end
				go.Active = false
				go.BackgroundColor3 = GREY
				go.Text = "..."
				Remotes.Merge:FireServer(item.Entry)
				-- falls der Server nichts ändert (z.B. gerade geklaut): Knopf wieder freigeben
				task.delay(1.5, function()
					if go.Parent then
						go.Active = true
						go.BackgroundColor3 = GREEN
						go.Text = "Verschmelzen"
					end
				end)
			end)
		end
	end

	Remotes.Merges.OnClientEvent:Connect(function(list)
		mergeList = if type(list) == "table" then list else {}
		-- die Plakette zählt nur, was man sofort verschmelzen kann
		local ready = 0
		for _, item in mergeList do
			if item.Ready then
				ready += 1
			end
		end
		mergeBadge.Visible = ready > 0
		mergeBadge.Text = tostring(ready)
		if mergePanel.Visible then
			rebuildMerges()
		end
	end)

	local function toggleMerge()
		if ctx.Busy() then
			return
		end
		if mergePanel.Visible then
			mergePanel.Visible = false
		else
			rebuildMerges()
			showMergePanel()
		end
		playSound("Click")
	end
	mergeButton.Activated:Connect(toggleMerge)

	task.spawn(function()
		while true do
			if mergeBadge.Visible and not mergePanel.Visible then
				tween(mergeButtonScale, 0.35, { Scale = 1.15 }).Completed:Wait()
				tween(mergeButtonScale, 0.35, { Scale = 1 }).Completed:Wait()
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
		elseif input.KeyCode == Enum.KeyCode.V then
			toggleMerge()
		end
	end)

	return {
		SkillPanel = skillPanel,
		MergePanel = mergePanel,
		ToggleSkills = toggleSkills,
		ToggleMerge = toggleMerge,
	}
end
