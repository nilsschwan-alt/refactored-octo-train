-- Test-Objekt: baut beim Spielstart einen bunten Turm vor dem Spawn,
-- oben drauf ein leuchtender Würfel, der sich dreht.
-- Nur zum Testen. Wenn du ihn nicht mehr brauchst, einfach diese Datei löschen.

local RunService = game:GetService("RunService")

local STANDORT = Vector3.new(0, 0, -25) -- 25 Studs vor dem Spawn
local STOCKWERKE = 6
local FARBEN = {
	Color3.fromRGB(255, 70, 70), -- rot
	Color3.fromRGB(255, 160, 40), -- orange
	Color3.fromRGB(255, 230, 60), -- gelb
	Color3.fromRGB(80, 220, 100), -- grün
	Color3.fromRGB(60, 150, 255), -- blau
	Color3.fromRGB(170, 90, 255), -- lila
}

local turm = Instance.new("Model")
turm.Name = "TestTurm"

-- Stockwerke stapeln, jedes etwas kleiner als das darunter
local hoehe = 0
for i = 1, STOCKWERKE do
	local groesse = 12 - i * 1.2
	local block = Instance.new("Part")
	block.Name = "Stockwerk" .. i
	block.Size = Vector3.new(groesse, 4, groesse)
	block.Position = STANDORT + Vector3.new(0, hoehe + 2, 0)
	block.Color = FARBEN[i]
	block.Material = Enum.Material.SmoothPlastic
	block.Anchored = true
	block.Parent = turm
	hoehe += 4
end

-- Leuchtender Würfel oben drauf
local wuerfel = Instance.new("Part")
wuerfel.Name = "DrehWuerfel"
wuerfel.Size = Vector3.new(4, 4, 4)
wuerfel.Position = STANDORT + Vector3.new(0, hoehe + 4, 0)
wuerfel.Color = Color3.fromRGB(0, 255, 255)
wuerfel.Material = Enum.Material.Neon
wuerfel.Anchored = true
wuerfel.CanCollide = false
wuerfel.Parent = turm

local licht = Instance.new("PointLight")
licht.Color = wuerfel.Color
licht.Range = 20
licht.Brightness = 2
licht.Parent = wuerfel

turm.Parent = workspace
print("[Server] TestTurm gebaut. Schau nach vorne!")

-- Würfel drehen und leicht auf und ab schweben lassen
local mitte = wuerfel.Position
local zeit = 0
RunService.Heartbeat:Connect(function(dt)
	zeit += dt
	local schweben = math.sin(zeit * 2) * 0.75
	wuerfel.CFrame = CFrame.new(mitte + Vector3.new(0, schweben, 0))
		* CFrame.Angles(zeit * 0.7, zeit * 1.5, 0)
end)
