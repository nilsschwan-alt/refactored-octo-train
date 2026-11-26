# Roblox-Spiel

Der Code für das Spiel liegt hier als normale Dateien. **Rojo** überträgt sie live in Roblox Studio.
Claude schreibt Skripte und Logik hier ins Repo, du baust Maps, Parts und Modelle direkt in Studio.

## Ordner

| Ordner | Landet in Studio unter | Wofür |
|---|---|---|
| `src/server` | ServerScriptService > Server | Server-Logik (Punkte, Daten speichern, Spielregeln) |
| `src/client` | StarterPlayer > StarterPlayerScripts > Client | Alles, was der Spieler sieht (UI, Kamera, Eingaben) |
| `src/shared` | ReplicatedStorage > Shared | Module, die beide Seiten nutzen (Einstellungen, Hilfsfunktionen) |

Dateinamen bestimmen den Skript-Typ:
- `Name.server.luau` → Script (Server)
- `Name.client.luau` → LocalScript (Client)
- `Name.luau` → ModuleScript

## Einmalig einrichten

1. **Programme installieren**
   - Git: https://git-scm.com
   - VS Code: https://code.visualstudio.com
   - Roblox Studio (hast du wahrscheinlich schon)

2. **Repo auf den PC holen**
   Terminal öffnen (Windows: „Git Bash“ oder PowerShell) und eingeben:
   ```
   git clone https://github.com/nilsschwan-alt/refactored-octo-train.git
   ```

3. **In VS Code öffnen**
   VS Code starten, „Datei“ > „Ordner öffnen“ und den Ordner `refactored-octo-train` wählen.
   Unten rechts schlägt VS Code die empfohlenen Erweiterungen vor (Rojo und Luau). Auf „Installieren“ klicken.

4. **Studio-Plugin installieren**
   In VS Code `Strg+Shift+P` drücken, „Rojo: Install Roblox Studio plugin“ eintippen und Enter.
   Danach Roblox Studio einmal neu starten.

## Jedes Mal zum Arbeiten

1. **Neuesten Code holen:** In VS Code links auf das Verzweigungs-Symbol (Source Control) und dann auf „Sync“ bzw. „Pull“ klicken. Oder im Terminal `git pull`.
2. **Rojo-Server starten:** `Strg+Shift+P` > „Rojo: Open menu“ > `default.project.json` anklicken. Unten in der Leiste steht dann, dass Rojo läuft.
3. **Studio verbinden:** Roblox Studio öffnen, ein Spiel öffnen (z. B. „Baseplate“), oben im Tab **Plugins** auf **Rojo** und dann auf **Connect** klicken.
4. **Testen:** Auf **Play** drücken.

### Hat es geklappt?

Nach Play solltest du sehen:
- Im **Output**-Fenster (Ansicht > Output): `[Server] Mein Roblox-Spiel v0.1.0 läuft. Rojo-Verbindung klappt!`
- Oben im Bild ein Schild „Willkommen, DeinName!“, das nach 5 Sekunden verschwindet.

## Wichtig

- **Skripte nur im Repo ändern, nicht in Studio.** Rojo überschreibt Skripte in Studio mit dem Stand aus den Dateien.
- **Map und Modelle in Studio speichern** (Datei > Speichern bzw. „Publish to Roblox“). Die stehen nicht im Repo.
- Wenn Rojo keine Verbindung bekommt: Läuft der Server in VS Code noch? Ist der Port bei beiden gleich (Standard 34872)?
