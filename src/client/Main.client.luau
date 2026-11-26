-- Client-Skript. Läuft bei jedem Spieler auf dessen eigenem Gerät.
-- Liegt in Studio unter: StarterPlayer > StarterPlayerScripts > Client > Main

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local player = Players.LocalPlayer

print(`[Client] Hallo {player.Name}, willkommen bei {Config.GameName}!`)

-- Kleine Begrüßung oben auf dem Bildschirm, verschwindet nach 5 Sekunden
local gui = Instance.new("ScreenGui")
gui.Name = "Begruessung"
gui.ResetOnSpawn = false

local label = Instance.new("TextLabel")
label.Size = UDim2.new(0, 400, 0, 50)
label.Position = UDim2.new(0.5, -200, 0, 20)
label.BackgroundTransparency = 0.3
label.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
label.TextColor3 = Color3.fromRGB(255, 255, 255)
label.TextScaled = true
label.Font = Enum.Font.GothamBold
label.Text = `Willkommen, {player.DisplayName}!`
label.Parent = gui

gui.Parent = player:WaitForChild("PlayerGui")

task.delay(5, function()
	gui:Destroy()
end)
