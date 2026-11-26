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

Nach Play solltest du im **Output**-Fenster (Ansicht > Output) `[Server] Bereit!` sehen und in deiner eigenen Base stehen.

## Das Spiel: Kreaturen-Klau

- **Map:** Zwei Reihen mit je 4 Bases an einer breiten Straße mit Gehwegen, Laternen und Brunnen. Am einen Ende der **Pack-Shop**, am anderen eine Riesen-Statue. Drumherum Wald, Hügel, See und Berge (Welt-Deko in `src/server/Modules/World.luau`).
- **Start:** Neue Spieler bekommen 300 $ und einen Blubbo geschenkt.
- **Packs:** Über den **Packs-Knopf** links (oder Taste **P**) von überall öffnen. Es gibt 3 Packs mit angezeigten Chancen, jeweils als **1x, 3x oder 10x** (10x mit 10 % Rabatt). Ist die Base voll, bleiben die besten Kreaturen, die schwächsten werden automatisch verkauft. Mit Öffnungs-Animation und Pity: Nach 20 Packs ohne Legendär ist das nächste garantiert Legendär oder besser.
- **Mutationen:** Jede Kreatur kann Gold (x2), Diamant (x3) oder Regenbogen (x5) sein.
- **Kasse:** Deine Kreaturen füllen die grüne Kasse in deiner Base. Drüberlaufen = einsammeln.
- **Events** alle 3 bis 5 Minuten (das erste schon nach 45 Sekunden): Meteor (seltene Kreatur auf der Straße, wer sie heimträgt, behält sie), Goldrausch (doppeltes Geld), Diebes-Nacht (dunkel, keine Schlösser, alle schneller).
- **Klauen:** In einer fremden Base E an einer Kreatur halten. Beim Tragen bist du langsam, kannst nicht springen und leuchtest. Erst in deiner Base gehört sie dir.
- **Klatsche** (Taste 1): Träger hauen, dann ist die Beute weg.
- **Schloss** (roter Knopf) und **Upgrade** (grüner Knopf, 5 Stufen) in deiner Base. **Verkaufen:** E an einer eigenen Kreatur.
- **Tagesbonus** beim ersten Joinen am Tag.
- **Selbst Geld machen:** Auf der Straße liegen **Münzen** (drüberlaufen, manchmal eine Riesen-Münze). **Klick auf deine eigenen Kreaturen** gibt sofort Geld.
- **Aufgaben** (rechts): immer 3 gleichzeitig, z.B. "Sammle 20 Münzen". Geschafft = Geld, dann kommt sofort eine neue.
- **Bestenlisten** neben der Riesen-Statue: Top 10 aller Zeiten (nur im veröffentlichten Spiel) und dieser Server.
- **Wiedergeburt** (lila Knopf oder Taste **R**): Kostet Geld, setzt Geld und Base-Stufe zurück, deine 4 besten Kreaturen bleiben. Dafür +50 % Einkommen für immer und Tokens für den Rebirth-Shop (Glück, Münz-Magnet, Klick-Kraft).

**Balancen:** Alle Zahlen und **alle Drop-Raten** (Packs, Mutationen, Meteor, Events) stehen in `src/shared/Config.luau`.

### Klauen testen (mit 2 Spielern)

In Studio oben im Tab **Test** bei „Clients and Servers“ **2 Players** einstellen und **Start** drücken. Dann öffnen sich zwei Spieler-Fenster, und du kannst dich selbst beklauen.

### Speichern einschalten

Damit Geld und Kreaturen gespeichert werden:
1. Spiel einmal veröffentlichen: **File > Publish to Roblox**.
2. **Home > Game Settings > Security** > **Enable Studio Access to API Services** einschalten > Save.

Ohne das läuft das Spiel trotzdem, es wird nur nichts gespeichert (steht dann auch als Hinweis im Spiel).

### Spieler pro Server

Im Creator Dashboard bzw. in **Game Settings > Places** die **Server-Größe auf 8** stellen, passend zu den 8 Bases.

## Wichtig

- **Skripte nur im Repo ändern, nicht in Studio.** Rojo überschreibt Skripte in Studio mit dem Stand aus den Dateien.
- **Map und Modelle in Studio speichern** (Datei > Speichern bzw. „Publish to Roblox“). Die stehen nicht im Repo.
- Wenn Rojo keine Verbindung bekommt: Läuft der Server in VS Code noch? Ist der Port bei beiden gleich (Standard 34872)?
