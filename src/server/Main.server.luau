-- Server-Skript. Läuft einmal auf dem Server, wenn das Spiel startet.
-- Liegt in Studio unter: ServerScriptService > Server > Main

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

print(`[Server] {Config.GameName} v{Config.Version} läuft. Rojo-Verbindung klappt!`)

Players.PlayerAdded:Connect(function(player)
	print(`[Server] {player.Name} ist dem Spiel beigetreten.`)
end)
