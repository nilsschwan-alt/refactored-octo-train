-- Der Klicker auf dem Client: Überall in die Welt klicken oder tippen gibt Geld.
-- Hier entstehen nur die Effekte (Ring am Finger, fliegende Zahl, Combo-Anzeige, Töne).
-- Wie viel ein Klick wert ist, rechnet der Server (Clicker.luau), die Werte stehen in Config.Click.
-- Wird von Main geladen. Main gibt seine Hilfsfunktionen mit (ctx).
-- Liegt in Studio unter: StarterPlayer > StarterPlayerScripts > Client > Klicker

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)

local C = Config.Click
local WHITE = Color3.new(1, 1, 1)
local GREEN = Color3.fromRGB(140, 255, 140)
local GOLD = Color3.fromRGB(255, 215, 60)
local CENTER = Vector2.new(0.5, 0.5)
-- Farbe je Combo-Stufe (0 = noch keine Stufe)
local STEP_COLORS = {
	[0] = Color3.fromRGB(235, 235, 245),
	Color3.fromRGB(255, 225, 90),
	Color3.fromRGB(255, 160, 60),
	Color3.fromRGB(255, 95, 60),
	Color3.fromRGB(255, 80, 200),
}
local MAX_NUMBERS = 30 -- so viele fliegende Zahlen gleichzeitig (schont schwache Handys)

return function(ctx)
	local player = Players.LocalPlayer
	local Remotes = ReplicatedStorage:WaitForChild("Remotes")
	local corner, label, stroke, tween, playSound = ctx.Corner, ctx.Label, ctx.Stroke, ctx.Tween, ctx.PlaySound

	-- eigene Ebene, damit Klick-Positionen genau passen
	local fx = Instance.new("ScreenGui")
	fx.Name = "KlickEffekte"
	fx.ResetOnSpawn = false
	fx.DisplayOrder = 5
	fx.Parent = player:WaitForChild("PlayerGui")

	local function skill(id: string): number
		local info = Config.SkillById[id]
		return if info then (player:GetAttribute("Sk_" .. id) or 0) * info.PerLevel else 0
	end

	-- Combo-Anzeige unten in der Mitte -----------------------------------------------
	local comboBox = Instance.new("Frame")
	comboBox.AnchorPoint = Vector2.new(0.5, 1)
	comboBox.Position = UDim2.new(0.5, 0, 1, -130)
	comboBox.Size = UDim2.fromOffset(250, 78)
	comboBox.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
	comboBox.BackgroundTransparency = 0.25
	comboBox.Visible = false
	comboBox.Parent = fx
	corner(comboBox, 14)
	local comboStroke = stroke(comboBox, WHITE, 3)
	local comboScale = Instance.new("UIScale")
	comboScale.Parent = comboBox
	local comboCount = label({
		Size = UDim2.new(1, -16, 0, 40),
		Position = UDim2.fromOffset(8, 2),
		Font = Enum.Font.FredokaOne,
		TextStrokeTransparency = 0.2,
		Text = "",
		Parent = comboBox,
	})
	local comboName = label({
		Size = UDim2.new(1, -16, 0, 20),
		Position = UDim2.fromOffset(8, 42),
		Font = Enum.Font.FredokaOne,
		Text = "",
		Parent = comboBox,
	})
	local barBack = Instance.new("Frame")
	barBack.Size = UDim2.new(1, -24, 0, 6)
	barBack.Position = UDim2.fromOffset(12, 66)
	barBack.BackgroundColor3 = Color3.fromRGB(60, 60, 75)
	barBack.BorderSizePixel = 0
	barBack.Parent = comboBox
	corner(barBack, 3)
	local bar = Instance.new("Frame")
	bar.Size = UDim2.fromScale(1, 1)
	bar.BackgroundColor3 = WHITE
	bar.BorderSizePixel = 0
	bar.Parent = barBack
	corner(bar, 3)

	local combo = 0 -- so viele Klicks am Stück (vom Server bestätigt)
	local comboStep = 0
	local comboUntil = 0 -- bis dahin muss der nächste Klick kommen
	local comboSpan = C.Combo.Timeout

	local function showCombo(count: number, step: number, mult: number)
		local stepped = step > comboStep
		combo, comboStep = count, step
		comboSpan = C.Combo.Timeout + skill("ComboTime")
		comboUntil = os.clock() + comboSpan
		if count < C.Combo.ShowFrom then
			return
		end
		local color = STEP_COLORS[math.min(step, #STEP_COLORS)]
		comboCount.Text = `COMBO x{count}`
		comboCount.TextColor3 = color
		comboStroke.Color = color
		bar.BackgroundColor3 = color
		if step > 0 then
			local shown = if math.abs(mult * 10 - math.floor(mult * 10 + 0.5)) < 0.01 then string.format("%.1f", mult) else string.format("%.2f", mult)
			comboName.Text = `{C.Combo.Steps[step][3]}! Geld x{(string.gsub(shown, "%.", ","))}`
			comboName.TextColor3 = color
		else
			comboName.Text = `noch {C.Combo.Steps[1][1] - count} bis zum Bonus`
			comboName.TextColor3 = Color3.fromRGB(200, 200, 215)
		end
		if not comboBox.Visible then
			comboBox.Visible = true
			comboScale.Scale = 0.6
			tween(comboScale, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
		elseif stepped then
			-- neue Stufe: Anzeige springt, Sterne, höherer Ton
			comboScale.Scale = 1.35
			tween(comboScale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
			playSound("ComboUp", 1 + (step - 1) * 0.15)
			if ctx.StarBurst then
				local inset = GuiService:GetGuiInset()
				local at = comboBox.AbsolutePosition + comboBox.AbsoluteSize / 2 + inset
				ctx.StarBurst(UDim2.fromOffset(at.X, at.Y), color, 8 + step * 3, 130)
			end
		else
			comboScale.Scale = 1.06
			tween(comboScale, 0.1, { Scale = 1 })
		end
	end

	RunService.RenderStepped:Connect(function()
		if combo == 0 then
			return
		end
		local left = comboUntil - os.clock()
		if left <= 0 then
			combo, comboStep = 0, 0
			if comboBox.Visible then
				tween(comboScale, 0.2, { Scale = 0 }, Enum.EasingStyle.Quad)
				task.delay(0.2, function()
					if combo == 0 then
						comboBox.Visible = false
					end
				end)
			end
			return
		end
		bar.Size = UDim2.fromScale(math.clamp(left / comboSpan, 0, 1), 1)
	end)

	-- Effekte am Klick ----------------------------------------------------------------
	local numbers = 0
	local function floatText(position: Vector2, text: string, color: Color3, size: number, rise: number, time: number)
		if numbers >= MAX_NUMBERS then
			return
		end
		numbers += 1
		local l = label({
			AnchorPoint = CENTER,
			Position = UDim2.fromOffset(position.X, position.Y),
			Size = UDim2.fromOffset(size * 9, size),
			Font = Enum.Font.FredokaOne,
			TextColor3 = color,
			TextStrokeTransparency = 0,
			Rotation = math.random(-8, 8),
			Text = text,
			Parent = fx,
		})
		local scale = Instance.new("UIScale")
		scale.Scale = 0.5
		scale.Parent = l
		tween(scale, 0.15, { Scale = 1 }, Enum.EasingStyle.Back)
		tween(l, time, { Position = UDim2.fromOffset(position.X + math.random(-30, 30), position.Y - rise) }, Enum.EasingStyle.Quad)
		task.delay(time * 0.55, function()
			tween(l, time * 0.45, { TextTransparency = 1, TextStrokeTransparency = 1 })
		end)
		task.delay(time, function()
			numbers -= 1
			l:Destroy()
		end)
	end

	-- Ring, der am Finger aufgeht
	local function ring(position: Vector2, color: Color3, size: number)
		local r = Instance.new("Frame")
		r.AnchorPoint = CENTER
		r.Position = UDim2.fromOffset(position.X, position.Y)
		r.Size = UDim2.fromOffset(14, 14)
		r.BackgroundTransparency = 1
		r.Parent = fx
		corner(r, 999)
		local s = stroke(r, color, 4)
		tween(r, 0.3, { Size = UDim2.fromOffset(size, size) }, Enum.EasingStyle.Quad)
		tween(s, 0.3, { Transparency = 1, Thickness = 1 }, Enum.EasingStyle.Quad)
		task.delay(0.32, function()
			r:Destroy()
		end)
	end

	-- Hinweis für Neue, bis zum ersten Klick
	local hint: TextLabel? = label({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -140),
		Size = UDim2.fromOffset(420, 34),
		Font = Enum.Font.FredokaOne,
		TextColor3 = GOLD,
		TextStrokeTransparency = 0.2,
		Text = "👆 Klick irgendwo hin: Jeder Klick gibt Geld!",
		Parent = fx,
	})
	task.spawn(function()
		local scale = Instance.new("UIScale")
		scale.Parent = hint
		while hint do
			tween(scale, 0.5, { Scale = 1.08 })
			task.wait(0.5)
			tween(scale, 0.5, { Scale = 1 })
			task.wait(0.5)
		end
	end)

	-- Klicken ---------------------------------------------------------------------------
	local lastSent = 0
	local lastPosition = Vector2.new(400, 300)
	local minGap = 1 / C.MaxPerSecond

	local function click(position: Vector2)
		if ctx.Busy and ctx.Busy() then
			return
		end
		local now = os.clock()
		if now - lastSent < minGap then
			return
		end
		lastSent = now
		lastPosition = position
		if hint then
			hint:Destroy()
			hint = nil
		end
		Remotes.Click:FireServer()
		-- sofort etwas zeigen, die Zahl kommt gleich vom Server
		ring(position, STEP_COLORS[math.min(comboStep, #STEP_COLORS)], 60 + comboStep * 12)
		playSound("ClickTick", 1 + math.min(combo, 120) / 120 * 0.6)
	end

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			click(Vector2.new(input.Position.X, input.Position.Y))
		elseif input.KeyCode == Enum.KeyCode.ButtonR2 then
			local camera = workspace.CurrentCamera
			local view = if camera then camera.ViewportSize else Vector2.new(800, 600)
			click(view / 2)
		end
	end)
	UserInputService.TouchTapInWorld:Connect(function(position, processed)
		if not processed then
			click(position)
		end
	end)

	-- Antwort vom Server: so viel war der Klick wert
	Remotes.Clicked.OnClientEvent:Connect(function(value: number, kind: string, count: number, step: number, mult: number)
		local amount = `+{Config.FormatNumber(value)} $`
		if kind == "auto" then
			-- Auto-Klicker: kleine Zahl neben der Geld-Anzeige
			local view = fx.AbsoluteSize
			floatText(Vector2.new(330, view.Y / 2 + 16), `🤖 {amount}`, Color3.fromRGB(150, 220, 255), 22, 26, 0.9)
			return
		end
		showCombo(count, step, mult)
		local at = lastPosition + Vector2.new(math.random(-24, 24), -26)
		if kind == "jackpot" then
			floatText(at, `🎰 {amount}`, GOLD, 54, 150, 1.8)
			ring(lastPosition, GOLD, 320)
			playSound("Crit", 0.8)
			if ctx.StarBurst then
				local inset = GuiService:GetGuiInset()
				ctx.StarBurst(UDim2.fromOffset(lastPosition.X + inset.X, lastPosition.Y + inset.Y), GOLD, 26, 260)
			end
		elseif kind == "crit" then
			floatText(at, `💥 {amount}`, GOLD, 38, 110, 1.2)
			ring(lastPosition, GOLD, 170)
			playSound("Crit", 0.95 + math.random() * 0.15)
			if ctx.StarBurst then
				local inset = GuiService:GetGuiInset()
				ctx.StarBurst(UDim2.fromOffset(lastPosition.X + inset.X, lastPosition.Y + inset.Y), GOLD, 8, 110)
			end
		else
			local color = if step > 0 then STEP_COLORS[math.min(step, #STEP_COLORS)] else GREEN
			floatText(at, amount, color, 24 + math.min(step, 4) * 2, 70, 0.8)
		end
	end)
end
