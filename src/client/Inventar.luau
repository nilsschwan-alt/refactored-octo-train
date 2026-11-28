-- Inventar: oben die Kreaturen, die in der Base stehen und Geld verdienen, darunter alles,
-- was im Inventar liegt (mit Filter und Sortierung). Rechts die gewählte Kreatur mit den
-- Knöpfen Verbessern, Aufstellen/Einpacken und Verkaufen.
-- Wird von Menus geladen: require(Inventar)(ctx, Stil).
-- Liegt in Studio unter: StarterPlayer > StarterPlayerScripts > Client > Inventar

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local CENTER = Vector2.new(0.5, 0.5)
local MONEY_GREEN = Color3.fromRGB(130, 255, 150)
local SORTS = { "Stärkste", "Seltenste", "Meiste" }

return function(ctx, Stil)
	local Remotes = ReplicatedStorage:WaitForChild("Remotes")
	local corner, label, stroke, tween, playSound = ctx.Corner, ctx.Label, ctx.Stroke, ctx.Tween, ctx.PlaySound

	local BAG_COLOR = Color3.fromRGB(46, 150, 235)
	local CHIP_OFF = Color3.fromRGB(58, 63, 112)
	local SELL_COLOR = Color3.fromRGB(150, 58, 70)
	local LEFT_W = 632 -- Breite der linken Seite

	local bagButton, bagButtonScale, bagBadge = ctx.HudButton(4, Color3.fromRGB(70, 150, 235), "🎒", "Inventar", "V")
	local panel, showPanel = Stil.Window(940, 600, BAG_COLOR, "🎒 Inventar")

	-- Überschrift eines Abschnitts
	local function heading(text: string, x: number, y: number, width: number): TextLabel
		return label({
			Size = UDim2.fromOffset(width, 22),
			Position = UDim2.fromOffset(x, y),
			Font = Enum.Font.FredokaOne,
			TextScaled = false,
			TextSize = 18,
			TextColor3 = Stil.Dim,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = text,
			Parent = panel,
		})
	end

	-- Oben: in der Base
	heading("IN DER BASE", 18, 78, 126)
	local _, baseCount = Stil.Pill(panel, "", Stil.Dark, UDim2.fromOffset(84, 26), UDim2.fromOffset(146, 76))
	local bestButton = Stil.Button(panel, "⬆ Beste aufstellen", Stil.Blue, UDim2.fromOffset(204, 38), UDim2.fromOffset(16 + LEFT_W - 204, 70))
	local strip = Instance.new("Frame")
	strip.Size = UDim2.fromOffset(LEFT_W, 84)
	strip.Position = UDim2.fromOffset(16, 114)
	strip.BackgroundColor3 = Stil.Dark
	strip.BorderSizePixel = 0
	strip.Parent = panel
	corner(strip, 12)

	-- Darunter: im Inventar
	heading("INVENTAR", 18, 212, 100)
	local _, bagCount = Stil.Pill(panel, "", Stil.Dark, UDim2.fromOffset(96, 26), UDim2.fromOffset(118, 210))
	local filterAll = Stil.Button(panel, "Alle", Stil.Blue, UDim2.fromOffset(74, 36), UDim2.fromOffset(226, 204))
	local filterReady = Stil.Button(panel, "", CHIP_OFF, UDim2.fromOffset(174, 36), UDim2.fromOffset(306, 204))
	local sortButton = Stil.Button(panel, "", CHIP_OFF, UDim2.fromOffset(162, 36), UDim2.fromOffset(486, 204))
	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.fromOffset(LEFT_W, 290)
	scroll.Position = UDim2.fromOffset(16, 246)
	scroll.BackgroundColor3 = Stil.Dark
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.ScrollingDirection = Enum.ScrollingDirection.Y
	scroll.CanvasSize = UDim2.new()
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.Parent = panel
	corner(scroll, 12)
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(96, 110)
	grid.CellPadding = UDim2.fromOffset(7, 7)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = scroll
	local gridPad = Instance.new("UIPadding")
	gridPad.PaddingLeft = UDim.new(0, 8)
	gridPad.PaddingTop = UDim.new(0, 8)
	gridPad.PaddingBottom = UDim.new(0, 8)
	gridPad.Parent = scroll
	local emptyText = label({
		Size = UDim2.fromOffset(LEFT_W - 80, 80),
		Position = UDim2.fromOffset(56, 350),
		TextScaled = false,
		TextSize = 19,
		TextWrapped = true,
		TextColor3 = Stil.Dim,
		ZIndex = 2,
		Text = "",
		Visible = false,
		Parent = panel,
	})
	local allButton = Stil.Button(panel, "⭐ Alle verbessern", Stil.Gold, UDim2.fromOffset(LEFT_W, 46), UDim2.fromOffset(16, 542))

	-- Rechts: die gewählte Kreatur
	local detail, detailLine = Stil.Panel(panel, UDim2.fromOffset(264, 516), UDim2.fromOffset(660, 72))
	local statePill, stateText = Stil.Pill(detail, "", Stil.Green, UDim2.fromOffset(160, 24), UDim2.fromOffset(10, 10))
	local detailIcon = Instance.new("Frame")
	detailIcon.Size = UDim2.fromOffset(264, 118)
	detailIcon.Position = UDim2.fromOffset(0, 32)
	detailIcon.BackgroundTransparency = 1
	detailIcon.Parent = detail
	local detailStars = label({
		Size = UDim2.new(1, 0, 0, 22),
		Position = UDim2.fromOffset(0, 150),
		Font = Enum.Font.FredokaOne,
		TextColor3 = Stil.Gold,
		Text = "",
		Parent = detail,
	})
	local detailName = label({
		Size = UDim2.new(1, -16, 0, 28),
		Position = UDim2.fromOffset(8, 172),
		Font = Enum.Font.FredokaOne,
		Text = "",
		Parent = detail,
	})
	local rarityPill, rarityText = Stil.Pill(detail, "", Stil.Dark, UDim2.fromOffset(150, 22), UDim2.fromOffset(57, 203))
	local detailIncome = label({
		Size = UDim2.new(1, -16, 0, 26),
		Position = UDim2.fromOffset(8, 230),
		Font = Enum.Font.FredokaOne,
		TextColor3 = MONEY_GREEN,
		Text = "",
		Parent = detail,
	})
	local feedTitle = label({
		Size = UDim2.new(1, -16, 0, 18),
		Position = UDim2.fromOffset(8, 262),
		TextScaled = false,
		TextSize = 15,
		TextColor3 = Stil.Gold,
		Text = "",
		Parent = detail,
	})
	local feedBar = Stil.Bar(detail, UDim2.fromOffset(232, 22), UDim2.fromOffset(16, 283), Stil.Gold)
	local feedAfter = label({
		Size = UDim2.new(1, -16, 0, 16),
		Position = UDim2.fromOffset(8, 308),
		Font = Enum.Font.GothamMedium,
		TextScaled = false,
		TextSize = 13,
		TextColor3 = Stil.Dim,
		Text = "",
		Parent = detail,
	})
	local starButton = Stil.Button(detail, "", Stil.Green, UDim2.fromOffset(240, 52), UDim2.fromOffset(12, 330))
	local equipButton = Stil.Button(detail, "", Stil.Blue, UDim2.fromOffset(240, 44), UDim2.fromOffset(12, 388))
	local sellButton = Stil.Button(detail, "", SELL_COLOR, UDim2.fromOffset(240, 36), UDim2.fromOffset(12, 438))
	local sellAllButton = Stil.Button(detail, "", SELL_COLOR, UDim2.fromOffset(240, 34), UDim2.fromOffset(12, 478))

	-- Zustand ---------------------------------------------------------------------------
	local bag = { Size = Config.Inventory.Size, Count = 0, Slots = 0, Items = {} } -- vom Server
	local shownSignature = "" -- was gerade als Kacheln dasteht (damit nicht unnötig neu gebaut wird)
	local selectedKey: string? = nil -- "S3" = aktive auf Platz 3, "B" .. Eintrag = im Inventar
	local selectedLike: string? = nil -- Art und Mutation der zuletzt gewählten (falls ihr Eintrag sich ändert)
	local tiles = {} -- [key] = { Stroke, Color }
	local detailShown = "" -- welche Kreatur das große Bild gerade zeigt
	local confirm = nil -- { Button, Until }: "Sicher?" beim Verkaufen
	local onlyReady = false -- Filter "Verbesserbar"
	local sortMode = 1 -- Platz in SORTS

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
			local on = tileKey == key
			tile.Stroke.Color = if on then WHITE else tile.Color
			tile.Stroke.Thickness = if on then 3 else 2
		end
		confirm = nil
		refreshDetail()
	end

	-- Grüner Pfeil: kann sofort verbessert werden
	local function readyBadge(tile: GuiObject, size: number)
		local up = label({
			Size = UDim2.fromOffset(size, size),
			Position = UDim2.fromOffset(3, 3),
			BackgroundTransparency = 0,
			BackgroundColor3 = Stil.Green,
			Font = Enum.Font.FredokaOne,
			ZIndex = 4,
			Text = "⬆",
			Parent = tile,
		})
		corner(up, size)
		stroke(up, Stil.Outline, 1.5)
	end

	-- Kachel für beide Bereiche. small = schmale Kachel oben in der Base-Reihe.
	local function makeTile(item, parent: Instance, size: UDim2, position: UDim2?, order: number, small: boolean)
		local def, mutation, stars = Config.ParseEntry(item.Entry)
		if not def then
			return
		end
		local key = itemKey(item)
		local color = Config.Rarities[def.Rarity].Color
		local width, height = size.X.Offset, size.Y.Offset
		local tile = Instance.new("TextButton")
		tile.Text = ""
		tile.AutoButtonColor = false
		tile.Size = size
		if position then
			tile.Position = position
		end
		tile.BackgroundColor3 = Stil.Card:Lerp(color, 0.2) -- leicht in der Farbe der Seltenheit
		tile.BorderSizePixel = 0
		tile.LayoutOrder = order
		tile.Parent = parent
		corner(tile, 10)
		local tileStroke = stroke(tile, color, 2)
		tileStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		local iconSize = if small then math.min(width - 8, 48) else 62
		staticIcon(tile, def, mutation, iconSize, if small then 3 else 6)
		if stars > 0 then
			local starLabel = label({
				Size = UDim2.new(1, 0, 0, if small then 13 else 16),
				Position = UDim2.fromOffset(0, if small then iconSize - 9 else 58),
				Font = Enum.Font.FredokaOne,
				TextColor3 = Stil.Gold,
				TextStrokeTransparency = 0,
				ZIndex = 3,
				Text = Config.StarText(stars),
				Parent = tile,
			})
			starLabel.TextStrokeColor3 = BLACK
		end
		label({
			Size = UDim2.new(1, -6, 0, if small then 14 else 17),
			Position = UDim2.new(0, 3, 1, if small then -17 else -33),
			Font = Enum.Font.FredokaOne,
			TextColor3 = MONEY_GREEN,
			ZIndex = 3,
			Text = `+{Config.FormatRate(Config.EntryIncome(item.Entry))}`,
			Parent = tile,
		})
		if not small then
			if item.Count > 1 then
				local count = label({
					Size = UDim2.fromOffset(44, 19),
					Position = UDim2.new(1, -48, 0, 3),
					Font = Enum.Font.FredokaOne,
					TextXAlignment = Enum.TextXAlignment.Right,
					TextStrokeTransparency = 0,
					ZIndex = 3,
					Text = `x{item.Count}`,
					Parent = tile,
				})
				count.TextStrokeColor3 = BLACK
			end
			if item.Cost then
				-- Futter-Balken ganz unten
				local bar = Instance.new("Frame")
				bar.Size = UDim2.new(1, -14, 0, 7)
				bar.Position = UDim2.new(0, 7, 1, -13)
				bar.BackgroundColor3 = Stil.Dark
				bar.BorderSizePixel = 0
				bar.Parent = tile
				corner(bar, 4)
				local fill = Instance.new("Frame")
				fill.Size = UDim2.fromScale(math.clamp(item.Have / item.Cost, 0, 1), 1)
				fill.BackgroundColor3 = if ready(item) then Stil.Green else Stil.Gold
				fill.BorderSizePixel = 0
				fill.Visible = item.Have > 0
				fill.Parent = bar
				corner(fill, 4)
			end
		end
		if item.Stolen then
			local ribbon = label({
				Size = UDim2.new(1, 0, 0, 15),
				BackgroundTransparency = 0,
				BackgroundColor3 = Stil.Red,
				Font = Enum.Font.FredokaOne,
				ZIndex = 4,
				Text = "KLAU!",
				Parent = tile,
			})
			corner(ribbon, 8)
		elseif ready(item) then
			readyBadge(tile, if not small then 22 elseif width < 56 then 14 else 18)
		end
		tiles[key] = { Stroke = tileStroke, Color = color }
		tile.Activated:Connect(function()
			playSound("Click")
			selectItem(key)
		end)
	end

	-- Freier Platz in der Base-Reihe
	local function makeEmptySlot(width: number, x: number)
		local slot = Instance.new("Frame")
		slot.Size = UDim2.fromOffset(width, 72)
		slot.Position = UDim2.fromOffset(x, 6)
		slot.BackgroundColor3 = Stil.Back
		slot.BackgroundTransparency = 0.3
		slot.BorderSizePixel = 0
		slot.Parent = strip
		corner(slot, 10)
		stroke(slot, Stil.CardLine, 1.5)
		label({
			AnchorPoint = CENTER,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(26, 26),
			Font = Enum.Font.FredokaOne,
			TextColor3 = Stil.CardLine,
			Text = "+",
			Parent = slot,
		})
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
			local _, iconScale = ctx.CreatureIcon(detailIcon, def, mutation, 108, 6)
			if iconScale then
				iconScale.Scale = 0.6
				tween(iconScale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
			end
		end
		detailLine.Color = rarity.Color
		if item.Stolen then
			statePill.BackgroundColor3 = Stil.Red
			stateText.Text = "WIRD GEKLAUT"
		elseif item.Slot then
			statePill.BackgroundColor3 = Stil.Green:Lerp(BLACK, 0.25)
			stateText.Text = "AKTIV IN DER BASE"
		else
			statePill.BackgroundColor3 = CHIP_OFF
			stateText.Text = if item.Count > 1 then `{item.Count}x IM INVENTAR` else "IM INVENTAR"
		end
		detailStars.Text = Config.StarText(stars)
		local m = Config.Mutations[mutation]
		detailName.Text = if m.Name ~= "" then `{m.Name}-{def.Name}` else def.Name
		detailName.TextColor3 = m.Color or WHITE
		rarityPill.BackgroundColor3 = rarity.Color:Lerp(BLACK, 0.45)
		rarityText.Text = rarity.Name
		detailIncome.Text = `+{Config.FormatRate(Config.EntryIncome(item.Entry))} $/s`

		local canUse = not item.Stolen
		if item.Cost then
			feedTitle.Text = `Futter für {Config.StarText(stars + 1)}`
			feedBar.Back.Visible = true
			feedBar.Set(item.Have / item.Cost, `{item.Have} / {item.Cost}`, if ready(item) then Stil.Green else Stil.Gold)
			feedAfter.Text = `danach +{Config.FormatRate(Config.EntryIncome(Config.MakeEntry(def.Id, mutation, stars + 1)))} $/s`
			starButton.SetText(if ready(item) then "⭐ Verbessern" else `Noch {item.Cost - item.Have} Futter (gleiche Art)`)
			starButton.SetEnabled(ready(item), Stil.Green)
		else
			feedTitle.Text = "Alle Sterne erreicht!"
			feedBar.Back.Visible = false
			feedAfter.Text = ""
			starButton.SetText("★ Maximal")
			starButton.SetEnabled(false, Stil.Green)
		end
		equipButton.SetText(if item.Slot then "🎒 Einpacken" else "⬆ Aufstellen")
		equipButton.SetEnabled(canUse, Stil.Blue)
		local price = item.Price or 0
		if not (confirm and confirm.Button == sellButton) then
			sellButton.SetText(`Verkaufen · {Config.FormatNumber(price)} $`)
		end
		sellButton.SetEnabled(canUse, SELL_COLOR)
		sellAllButton.Holder.Visible = not item.Slot and item.Count > 1
		if not (confirm and confirm.Button == sellAllButton) then
			sellAllButton.SetText(`Alle {item.Count} verkaufen · {Config.FormatNumber(price * item.Count)} $`)
		end
	end

	-- Reihenfolge im Inventar je nach gewählter Sortierung
	local function sortStored(list)
		table.sort(list, function(a, b)
			if sortMode == 2 then
				local da, db = Config.ParseEntry(a.Entry), Config.ParseEntry(b.Entry)
				local ra = if da then Config.RarityRank(da.Rarity) else 0
				local rb = if db then Config.RarityRank(db.Rarity) else 0
				if ra ~= rb then
					return ra > rb
				end
			elseif sortMode == 3 and a.Count ~= b.Count then
				return a.Count > b.Count
			end
			local ia, ib = Config.EntryIncome(a.Entry), Config.EntryIncome(b.Entry)
			if ia ~= ib then
				return ia > ib
			end
			return a.Entry < b.Entry
		end)
	end

	local function rebuild()
		local active, stored = {}, {}
		local activeCount, readyCount, readyStored = 0, 0, 0
		for _, item in bag.Items do
			if item.Slot then
				active[item.Slot] = item
				activeCount += 1
			else
				table.insert(stored, item)
				if ready(item) then
					readyStored += 1
				end
			end
			if ready(item) then
				readyCount += 1
			end
		end
		sortStored(stored)
		local shown = stored
		if onlyReady then
			shown = {}
			for _, item in stored do
				if ready(item) then
					table.insert(shown, item)
				end
			end
		end

		baseCount.Text = `{activeCount} / {bag.Slots}`
		bagCount.Text = `{bag.Count} / {bag.Size}`
		filterAll.SetColor(if onlyReady then CHIP_OFF else Stil.Blue)
		filterReady.SetColor(if onlyReady then Stil.Green else CHIP_OFF)
		filterReady.SetText(`⬆ Verbesserbar {readyStored}`)
		sortButton.SetText(`Sortiert: {SORTS[sortMode]}`)
		allButton.SetText(if readyCount > 0 then `⭐ Alle verbessern ({readyCount} möglich)` else "⭐ Alle verbessern")
		allButton.SetEnabled(readyCount > 0, Stil.Gold)
		emptyText.Visible = #shown == 0
		emptyText.Text = if onlyReady
			then "Gerade kann nichts verbessert werden.\nDoppelte Kreaturen sind Futter für Sterne."
			else "Dein Inventar ist leer.\nÖffne Kisten im Shop, hier landet alles, was nicht in die Base passt."

		local parts = { `{bag.Slots}|{tostring(onlyReady)}|{sortMode}` }
		for slot = 1, bag.Slots do
			local item = active[slot]
			table.insert(parts, if item then `{slot}:{item.Entry}:{item.Have}:{tostring(item.Stolen)}` else `{slot}:-`)
		end
		for _, item in shown do
			table.insert(parts, `{item.Entry}:{item.Count}:{item.Have}`)
		end
		local signature = table.concat(parts, ";")
		if signature ~= shownSignature then
			shownSignature = signature
			strip:ClearAllChildren()
			corner(strip, 12)
			for _, child in scroll:GetChildren() do
				if child:IsA("TextButton") then
					child:Destroy()
				end
			end
			table.clear(tiles)
			-- Base-Reihe: alle Plätze nebeneinander, je mehr Plätze, desto schmaler
			local n = math.max(1, bag.Slots)
			local width = math.min(72, math.floor((LEFT_W - 12 - (n - 1) * 6) / n))
			for slot = 1, n do
				local x = 6 + (slot - 1) * (width + 6)
				local item = active[slot]
				if item then
					makeTile(item, strip, UDim2.fromOffset(width, 72), UDim2.fromOffset(x, 6), slot, true)
				else
					makeEmptySlot(width, x)
				end
			end
			for i, item in shown do
				makeTile(item, scroll, UDim2.fromOffset(96, 110), nil, i, false)
			end
		end

		-- Auswahl behalten. Gibt es sie nicht mehr (verbessert, aufgestellt, verkauft), die
		-- nächste von derselben Art nehmen, sonst die erste.
		if not findItem(selectedKey) then
			local pick = nil
			for _, item in bag.Items do
				if likeOf(item.Entry) == selectedLike then
					pick = item
					break
				end
			end
			pick = pick or active[1] or shown[1] or bag.Items[1]
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
		if panel.Visible then
			rebuild()
		end
	end)

	local function send(action: string, entry: string?, slot: number?)
		Remotes.InventoryAction:FireServer(action, entry, slot)
	end
	local function burstAt(object: GuiObject, color: Color3, amount: number)
		local middle = object.AbsolutePosition + object.AbsoluteSize / 2 + GuiService:GetGuiInset()
		ctx.StarBurst(UDim2.fromOffset(middle.X, middle.Y), color, amount, 130)
	end
	-- Verkaufen mit Nachfrage: erst beim zweiten Tippen (innerhalb von 3 Sekunden) wird verkauft
	local function confirmed(button): boolean
		if confirm and confirm.Button == button and os.clock() < confirm.Until then
			confirm = nil
			return true
		end
		confirm = { Button = button, Until = os.clock() + 3 }
		button.SetText("Sicher? Nochmal tippen")
		task.delay(3, function()
			if confirm and confirm.Button == button and os.clock() >= confirm.Until then
				confirm = nil
				refreshDetail()
			end
		end)
		return false
	end

	starButton.Button.Activated:Connect(function()
		local item = findItem(selectedKey)
		if not item or not starButton.Enabled then
			playSound("Click", 0.6)
			return
		end
		starButton.Pop()
		send("StarUp", item.Entry, item.Slot)
		burstAt(detailIcon, Stil.Gold, 18)
	end)
	equipButton.Button.Activated:Connect(function()
		local item = findItem(selectedKey)
		if not item or not equipButton.Enabled then
			return
		end
		playSound("Click")
		equipButton.Pop()
		if item.Slot then
			send("Unequip", nil, item.Slot)
		else
			send("Equip", item.Entry)
		end
	end)
	sellButton.Button.Activated:Connect(function()
		local item = findItem(selectedKey)
		if not item or not sellButton.Enabled then
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
	sellAllButton.Button.Activated:Connect(function()
		local item = findItem(selectedKey)
		if not item or item.Slot or not confirmed(sellAllButton) then
			return
		end
		send("SellAll", item.Entry)
	end)
	bestButton.Button.Activated:Connect(function()
		playSound("Click")
		bestButton.Pop()
		send("EquipBest")
	end)
	allButton.Button.Activated:Connect(function()
		if not allButton.Enabled then
			playSound("Click", 0.6)
			return
		end
		allButton.Pop()
		send("StarUpAll")
		burstAt(allButton.Holder, Stil.Gold, 24)
	end)
	filterAll.Button.Activated:Connect(function()
		playSound("Click")
		onlyReady = false
		rebuild()
	end)
	filterReady.Button.Activated:Connect(function()
		playSound("Click")
		onlyReady = not onlyReady
		rebuild()
	end)
	sortButton.Button.Activated:Connect(function()
		playSound("Click")
		sortMode = sortMode % #SORTS + 1
		rebuild()
	end)

	local function toggle()
		if ctx.Busy() then
			return
		end
		if panel.Visible then
			panel.Visible = false
		else
			rebuild()
			showPanel()
		end
		playSound("Click")
	end
	bagButton.Activated:Connect(toggle)

	-- Der Knopf in der Leiste pulsiert, solange etwas verbessert werden kann
	task.spawn(function()
		while true do
			if bagBadge.Visible and not panel.Visible then
				tween(bagButtonScale, 0.35, { Scale = 1.15 }).Completed:Wait()
				tween(bagButtonScale, 0.35, { Scale = 1 }).Completed:Wait()
			else
				task.wait(0.5)
			end
		end
	end)

	return { Panel = panel, Toggle = toggle }
end
