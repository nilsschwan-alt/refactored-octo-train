-- Wiedergeburt (Rebirth): Fenster mit Fortschritt, Belohnung und dem großen Knopf.
-- Wird von Main geladen. Main gibt seine Hilfsfunktionen und den Fenster-Stil mit (ctx).
-- Liegt in Studio unter: StarterPlayer > StarterPlayerScripts > Client > Wiedergeburt

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)

local WHITE = Color3.new(1, 1, 1)
local PURPLE = Color3.fromRGB(170, 90, 255)
local W = 640 -- Breite des Fensters

return function(ctx)
	local player = Players.LocalPlayer
	local Remotes = ReplicatedStorage:WaitForChild("Remotes")
	local label, tween, playSound = ctx.Label, ctx.Tween, ctx.PlaySound
	local Stil = ctx.Stil

	local rebirthButton, rebirthButtonScale = ctx.HudButton(2, PURPLE, "🔄", "Rebirth", "R")
	local panel, showPanel = Stil.Window(W, 432, PURPLE, "🔄 Wiedergeburt")

	-- Zwei Karten oben: wie oft schon, und was das Einkommen davon hat
	local function infoCard(x: number, caption: string): TextLabel
		local card = Stil.Panel(panel, UDim2.fromOffset(298, 66), UDim2.fromOffset(x, 76))
		label({
			Size = UDim2.new(1, -20, 0, 16),
			Position = UDim2.fromOffset(10, 7),
			Font = Enum.Font.FredokaOne,
			TextColor3 = Stil.Dim,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = caption,
			Parent = card,
		})
		return label({
			Size = UDim2.new(1, -20, 0, 32),
			Position = UDim2.fromOffset(10, 26),
			Font = Enum.Font.FredokaOne,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = "",
			Parent = card,
		})
	end
	local countText = infoCard(16, "DEINE WIEDERGEBURTEN")
	local incomeText = infoCard(326, "EINKOMMEN FÜR IMMER")
	incomeText.TextColor3 = Color3.fromRGB(130, 255, 150)

	-- Was die nächste Wiedergeburt freischaltet
	local unlockCard, unlockLine = Stil.Panel(panel, UDim2.fromOffset(W - 32, 50), UDim2.fromOffset(16, 152))
	local unlockText = label({
		Size = UDim2.new(1, -24, 1, -16),
		Position = UDim2.fromOffset(12, 8),
		Font = Enum.Font.FredokaOne,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
		Parent = unlockCard,
	})
	local desc = label({
		Size = UDim2.fromOffset(W - 40, 44),
		Position = UDim2.fromOffset(20, 210),
		Font = Enum.Font.GothamMedium,
		TextScaled = false,
		TextSize = 16,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = Stil.Dim,
		Text = "",
		Parent = panel,
	})
	local costBar = Stil.Bar(panel, UDim2.fromOffset(W - 32, 30), UDim2.fromOffset(16, 260), PURPLE)
	local doRebirth = Stil.Button(panel, "WIEDERGEBURT!", PURPLE, UDim2.fromOffset(W - 32, 62), UDim2.fromOffset(16, 298))
	local _, tokenText = Stil.Pill(panel, "", Stil.Dark, UDim2.fromOffset(190, 42), UDim2.fromOffset(16, 372))
	tokenText.TextColor3 = Stil.Token
	local skillLink = Stil.Button(panel, "🧠 Tokens im Skill-Baum ausgeben", Stil.Blue, UDim2.fromOffset(W - 32 - 200, 46), UDim2.fromOffset(216, 370))

	local function update()
		local rebirths = player:GetAttribute("Rebirths") or 0
		local money = player:GetAttribute("Money") or 0
		local tokens = player:GetAttribute("Tokens") or 0
		local cost = Config.RebirthCost(rebirths)
		countText.Text = tostring(rebirths)
		incomeText.Text = `x{Config.RebirthMultiplier(rebirths)}  →  x{Config.RebirthMultiplier(rebirths + 1)}`
		local keep = Config.Rebirth.KeepCreatures + (player:GetAttribute("Sk_Heritage") or 0)
		desc.Text = `Du behältst deine {keep} besten Kreaturen. Geld und Base-Stufe starten neu. Dafür bekommst du für immer mehr Einkommen und +{Config.Rebirth.TokensPerRebirth} Tokens für den Skill-Baum.`
		local unlock = Config.RebirthUnlock(rebirths)
		if unlock then
			unlockText.Text = `🎁 Schaltet frei: {unlock.Name} mit neuen, stärkeren Kreaturen!`
			unlockText.TextColor3 = unlock.Color:Lerp(WHITE, 0.35)
			unlockLine.Color = unlock.Color
		else
			unlockText.Text = "⭐ Alle Kisten freigeschaltet. Jede Wiedergeburt macht dich weiter reicher!"
			unlockText.TextColor3 = Stil.Gold
			unlockLine.Color = Stil.Gold
		end
		costBar.Set(money / cost, `{Config.FormatNumber(money)} / {Config.FormatNumber(cost)} $`, if money >= cost then Stil.Green else PURPLE)
		doRebirth.SetEnabled(money >= cost, PURPLE)
		tokenText.Text = `💠 Tokens: {tokens}`
	end
	for _, attr in { "Money", "Rebirths", "Tokens" } do
		player:GetAttributeChangedSignal(attr):Connect(function()
			if panel.Visible then
				update()
			end
		end)
	end

	-- Sicherheitsabfrage: zweimal klicken
	local confirmUntil = 0
	doRebirth.Button.Activated:Connect(function()
		local rebirths = player:GetAttribute("Rebirths") or 0
		if (player:GetAttribute("Money") or 0) < Config.RebirthCost(rebirths) then
			playSound("Click", 0.6)
			return
		end
		if os.clock() > confirmUntil then
			confirmUntil = os.clock() + 3
			doRebirth.SetText("SICHER? NOCHMAL KLICKEN!")
			doRebirth.Pop()
			playSound("Click")
			task.delay(3, function()
				if os.clock() >= confirmUntil then
					doRebirth.SetText("WIEDERGEBURT!")
				end
			end)
			return
		end
		confirmUntil = 0
		doRebirth.SetText("WIEDERGEBURT!")
		Remotes.Rebirth:FireServer()
		panel.Visible = false
	end)
	skillLink.Button.Activated:Connect(function()
		ctx.OpenSkills()
	end)

	local function toggle()
		if ctx.Busy() then
			return
		end
		if panel.Visible then
			panel.Visible = false
		else
			update()
			showPanel()
		end
		playSound("Click")
	end
	rebirthButton.Activated:Connect(toggle)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.R then
			toggle()
		end
	end)

	-- Der Knopf pulsiert, sobald man sich die Wiedergeburt leisten kann
	task.spawn(function()
		while true do
			local cost = Config.RebirthCost(player:GetAttribute("Rebirths") or 0)
			if (player:GetAttribute("Money") or 0) >= cost and not panel.Visible then
				tween(rebirthButtonScale, 0.35, { Scale = 1.15 }).Completed:Wait()
				tween(rebirthButtonScale, 0.35, { Scale = 1 }).Completed:Wait()
			else
				task.wait(0.5)
			end
		end
	end)

	return { Panel = panel, Toggle = toggle }
end
