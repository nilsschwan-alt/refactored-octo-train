-- Gemeinsamer Stil für alle Fenster: Kopfleiste mit Farbverlauf, dicke Knöpfe mit dunkler
-- Unterkante und Glanzstreifen, Karten, Plaketten und Balken. So sehen alle Menüs gleich aus.
-- Wird von Main und den Menü-Dateien geladen: require(Stil)(ctx) mit den Hilfsfunktionen aus Main.
-- Liegt in Studio unter: StarterPlayer > StarterPlayerScripts > Client > Stil

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local CENTER = Vector2.new(0.5, 0.5)
local HEADER = 64 -- Höhe der Kopfleiste

return function(ctx)
	local gui: ScreenGui = ctx.Gui
	local corner, label, stroke, tween, playSound = ctx.Corner, ctx.Label, ctx.Stroke, ctx.Tween, ctx.PlaySound

	local Stil = {}
	-- Farben (hier ändern = überall anders)
	Stil.Back = Color3.fromRGB(24, 27, 58) -- Fenster-Hintergrund
	Stil.Card = Color3.fromRGB(38, 42, 82) -- Karten
	Stil.CardLine = Color3.fromRGB(62, 68, 124) -- feiner Rand der Karten
	Stil.Dark = Color3.fromRGB(15, 17, 40) -- vertiefte Flächen (Balken, Listen)
	Stil.Outline = Color3.fromRGB(8, 9, 26) -- dicker Rand
	Stil.Dim = Color3.fromRGB(172, 180, 222) -- blasser Text
	Stil.Grey = Color3.fromRGB(96, 101, 140) -- Knopf, der gerade nicht geht
	Stil.Green = Color3.fromRGB(62, 198, 92)
	Stil.Gold = Color3.fromRGB(255, 196, 48)
	Stil.Red = Color3.fromRGB(232, 72, 84)
	Stil.Blue = Color3.fromRGB(58, 138, 240)
	Stil.Token = Color3.fromRGB(120, 220, 255)

	-- Dunkler Rand um einen Text (dicker als TextStroke, sieht nach Comic aus)
	function Stil.Outlined(text: TextLabel, thickness: number?)
		local s = stroke(text, Stil.Outline, thickness or 2)
		s.LineJoinMode = Enum.LineJoinMode.Round
		return s
	end

	-- Kopfleiste oben in einem Fenster (Farbverlauf, Glanzstreifen, Titel mit dunklem Rand).
	-- Die Füllung ist höher als die Leiste und wird unten abgeschnitten, so sind nur die
	-- oberen Ecken rund. Gibt die Leiste zurück (für Plaketten).
	function Stil.Header(panel: Instance, color: Color3, title: string?)
		local band = Instance.new("Frame")
		band.Name = "Kopf"
		band.Size = UDim2.new(1, 0, 0, HEADER)
		band.BackgroundTransparency = 1
		band.ClipsDescendants = true
		band.Parent = panel
		local fill = Instance.new("Frame")
		fill.Size = UDim2.new(1, 0, 0, HEADER + 30)
		fill.BackgroundColor3 = WHITE
		fill.BorderSizePixel = 0
		fill.Parent = band
		corner(fill, 22)
		local shade = Instance.new("UIGradient")
		shade.Rotation = 90
		local low = color:Lerp(BLACK, 0.32)
		shade.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, color:Lerp(WHITE, 0.22)),
			ColorSequenceKeypoint.new(0.68, low),
			ColorSequenceKeypoint.new(1, low),
		})
		shade.Parent = fill
		local shine = Instance.new("Frame") -- Glanzstreifen
		shine.Size = UDim2.new(1, -44, 0, 7)
		shine.Position = UDim2.fromOffset(22, 6)
		shine.BackgroundColor3 = WHITE
		shine.BackgroundTransparency = 0.78
		shine.BorderSizePixel = 0
		shine.Parent = band
		corner(shine, 4)
		local line = Instance.new("Frame") -- dunkle Kante unter der Leiste
		line.Size = UDim2.new(1, 0, 0, 4)
		line.Position = UDim2.new(0, 0, 1, -4)
		line.BackgroundColor3 = Stil.Outline
		line.BackgroundTransparency = 0.35
		line.BorderSizePixel = 0
		line.Parent = band
		if title then
			local titleLabel = label({
				Name = "Titel",
				Size = UDim2.new(0, 330, 0, 40),
				Position = UDim2.fromOffset(20, 10),
				Font = Enum.Font.FredokaOne,
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = title,
				Parent = band,
			})
			Stil.Outlined(titleLabel, 2.5)
		end
		return band
	end

	-- Rundes rotes X oben rechts mit dunkler Unterkante. Macht das Fenster zu.
	function Stil.Close(panel: GuiObject): TextButton
		local closeLip = Instance.new("Frame")
		closeLip.Size = UDim2.fromOffset(44, 44)
		closeLip.Position = UDim2.new(1, -56, 0, 13)
		closeLip.BackgroundColor3 = Stil.Red:Lerp(BLACK, 0.6)
		closeLip.BorderSizePixel = 0
		closeLip.ZIndex = 2
		closeLip.Parent = panel
		corner(closeLip, 22)
		local close = Instance.new("TextButton")
		close.Name = "Zu"
		close.Size = UDim2.fromOffset(44, 44)
		close.Position = UDim2.new(1, -56, 0, 9)
		close.BackgroundColor3 = Stil.Red
		close.AutoButtonColor = false
		close.Text = "X"
		close.TextColor3 = WHITE
		close.Font = Enum.Font.FredokaOne
		close.TextSize = 26
		close.ZIndex = 3
		close.Parent = panel
		corner(close, 22)
		stroke(close, Stil.Outline, 2.5).ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		close.Activated:Connect(function()
			panel.Visible = false
			playSound("Click", 0.9)
		end)
		return close
	end

	-- Fenster in der Bildschirmmitte: farbige Kopfleiste mit Titel, rundes rotes X.
	-- Gibt zurück: Fenster, Funktion zum Zeigen (mit Aufploppen), Kopfleiste (für Plaketten).
	function Stil.Window(width: number, height: number, color: Color3, title: string)
		local panel = Instance.new("Frame")
		panel.AnchorPoint = CENTER
		panel.Position = UDim2.fromScale(0.5, 0.5)
		panel.Size = UDim2.fromOffset(width, height)
		panel.BackgroundColor3 = WHITE
		panel.Visible = false
		panel.Active = true -- fängt Klicks ab, damit im Fenster kein Klick-Geld entsteht
		panel.Parent = gui
		corner(panel, 22)
		stroke(panel, Stil.Outline, 4)
		-- sanfter Verlauf: oben etwas heller und in der Farbe des Fensters getönt
		local ground = Instance.new("UIGradient")
		ground.Rotation = 90
		ground.Color = ColorSequence.new(Stil.Back:Lerp(color, 0.34), Stil.Back)
		ground.Parent = panel
		local scale = Instance.new("UIScale")
		scale.Parent = panel

		local band = Stil.Header(panel, color, title)
		Stil.Close(panel)

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
		return panel, show, band
	end

	-- Dicker Knopf: dunkle Unterkante, Farbverlauf, Glanzstreifen, drückt sich beim Tippen hinein.
	-- z = Ebene (nur nötig, wenn der Knopf über etwas anderem liegen muss).
	-- Gibt eine Tabelle zurück: .Button (zum Verbinden), .SetText, .SetEnabled, .SetColor, .Pop
	function Stil.Button(parent: Instance, text: string, color: Color3, size: UDim2, position: UDim2, z: number?)
		local zIndex = z or 1
		-- Eckenrundung nach der Höhe (bei Höhe in Prozent: die größte)
		local radius = if size.Y.Offset > 0 then math.clamp(math.floor(size.Y.Offset / 3.2), 8, 14) else 14
		local holder = Instance.new("Frame")
		holder.Size = size
		holder.Position = position
		holder.BackgroundTransparency = 1
		holder.ZIndex = zIndex
		holder.Parent = parent
		local scale = Instance.new("UIScale")
		scale.Parent = holder
		local lip = Instance.new("Frame")
		lip.Size = UDim2.new(1, 0, 1, -4)
		lip.Position = UDim2.fromOffset(0, 4)
		lip.BorderSizePixel = 0
		lip.ZIndex = zIndex
		lip.Parent = holder
		corner(lip, radius)
		local face = Instance.new("TextButton")
		face.Size = UDim2.new(1, 0, 1, -4)
		face.BackgroundColor3 = WHITE
		face.AutoButtonColor = false
		face.BorderSizePixel = 0
		face.Text = ""
		face.ZIndex = zIndex + 1
		face.Parent = holder
		corner(face, radius)
		local shade = Instance.new("UIGradient")
		shade.Rotation = 90
		shade.Parent = face
		local border = stroke(face, BLACK, 2)
		border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		local shine = Instance.new("Frame")
		shine.Size = UDim2.new(1, -14, 0.26, 0)
		shine.Position = UDim2.fromOffset(7, 3)
		shine.BackgroundColor3 = WHITE
		shine.BackgroundTransparency = 0.76
		shine.BorderSizePixel = 0
		shine.ZIndex = zIndex + 1
		shine.Parent = face
		corner(shine, 5)
		local caption = label({
			Size = UDim2.new(1, -16, 1, -12),
			Position = UDim2.fromOffset(8, 6),
			Font = Enum.Font.FredokaOne,
			TextStrokeTransparency = 0.55,
			ZIndex = zIndex + 2,
			Text = text,
			Parent = face,
		})

		local self = { Holder = holder, Button = face, Label = caption, Scale = scale, Enabled = true, Color = color }
		local function paint(c: Color3)
			lip.BackgroundColor3 = c:Lerp(BLACK, 0.55)
			shade.Color = ColorSequence.new(c:Lerp(WHITE, 0.28), c:Lerp(BLACK, 0.1))
			border.Color = c:Lerp(BLACK, 0.62)
		end
		paint(color)
		function self.SetText(newText: string)
			caption.Text = newText
		end
		function self.SetColor(c: Color3)
			self.Color = c
			if self.Enabled then
				paint(c)
			end
		end
		-- aus = grau und ohne Wirkung (.Enabled vor dem Senden prüfen)
		function self.SetEnabled(on: boolean, c: Color3?)
			self.Enabled = on
			self.Color = c or self.Color
			paint(if on then self.Color else Stil.Grey)
			caption.TextTransparency = if on then 0 else 0.2
			shine.Visible = on
		end
		-- kurzer Hüpfer, z.B. nach einem Kauf
		function self.Pop()
			scale.Scale = 0.9
			tween(scale, 0.22, { Scale = 1 }, Enum.EasingStyle.Back)
		end
		local function release()
			face.Position = UDim2.new()
		end
		face.MouseButton1Down:Connect(function()
			if self.Enabled then
				face.Position = UDim2.fromOffset(0, 3)
			end
		end)
		face.MouseButton1Up:Connect(release)
		face.MouseLeave:Connect(release)
		return self
	end

	-- Karte: abgerundete Fläche mit feinem Rand. Gibt Karte und Rand zurück.
	function Stil.Panel(parent: Instance, size: UDim2, position: UDim2, color: Color3?)
		local card = Instance.new("Frame")
		card.Size = size
		card.Position = position
		card.BackgroundColor3 = color or Stil.Card
		card.BorderSizePixel = 0
		card.Parent = parent
		corner(card, 14)
		local line = stroke(card, Stil.CardLine, 1.5)
		return card, line
	end

	-- Plakette: runde Fläche mit Text, z.B. "💠 12 Tokens". Gibt Fläche und Text zurück.
	function Stil.Pill(parent: Instance, text: string, color: Color3, size: UDim2, position: UDim2, z: number?)
		local pill = Instance.new("Frame")
		pill.Size = size
		pill.Position = position
		pill.BackgroundColor3 = color
		pill.BorderSizePixel = 0
		pill.ZIndex = z or 1
		pill.Parent = parent
		corner(pill, math.floor(size.Y.Offset / 2))
		stroke(pill, Stil.Outline, 2)
		local caption = label({
			Size = UDim2.new(1, -16, 1, -8),
			Position = UDim2.fromOffset(8, 4),
			Font = Enum.Font.FredokaOne,
			ZIndex = (z or 1) + 1,
			Text = text,
			Parent = pill,
		})
		return pill, caption
	end

	-- Fortschritts-Balken mit Text in der Mitte. .Set(Anteil 0 bis 1, Text, Farbe)
	function Stil.Bar(parent: Instance, size: UDim2, position: UDim2, color: Color3, z: number?)
		local zIndex = z or 1
		local back = Instance.new("Frame")
		back.Size = size
		back.Position = position
		back.BackgroundColor3 = Stil.Dark
		back.BorderSizePixel = 0
		back.ZIndex = zIndex
		back.Parent = parent
		corner(back, math.floor(size.Y.Offset / 2))
		local fill = Instance.new("Frame")
		fill.Size = UDim2.fromScale(0, 1)
		fill.BackgroundColor3 = color
		fill.BorderSizePixel = 0
		fill.ZIndex = zIndex
		fill.Parent = back
		corner(fill, math.floor(size.Y.Offset / 2))
		local caption = label({
			Size = UDim2.new(1, -8, 1, -2),
			Position = UDim2.fromOffset(4, 1),
			Font = Enum.Font.FredokaOne,
			TextStrokeTransparency = 0.4,
			ZIndex = zIndex + 1,
			Text = "",
			Parent = back,
		})
		local self = { Back = back, Fill = fill, Label = caption }
		function self.Set(fraction: number, text: string?, fillColor: Color3?)
			local f = math.clamp(fraction, 0, 1)
			-- ganz kleine Füllung sähe wegen der runden Ecken kaputt aus
			fill.Visible = f > 0.02
			tween(fill, 0.25, { Size = UDim2.fromScale(math.max(f, 0.08), 1) })
			if text then
				caption.Text = text
			end
			if fillColor then
				fill.BackgroundColor3 = fillColor
			end
		end
		return self
	end

	return Stil
end
