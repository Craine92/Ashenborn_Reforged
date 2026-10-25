# ASHENBORN REFORGED – Alpha 0.1.5 · Hero Progression

## Start

1. Repository mit installiertem Git LFS klonen beziehungsweise das Projektverzeichnis in Godot **4.7.1** öffnen.
2. Projekt mit **F5** starten.
3. **SPIELEN** wählen und den QR-Code mit einem Smartphone im selben WLAN öffnen.
4. Nach dem Handshake **SPIEL STARTEN** wählen.

Für lokale Bedienung ohne Smartphone steht weiterhin **OHNE SMARTPHONE TESTEN** zur Verfügung.

## Neuer Kernablauf

Der Spieler führt den permanenten Helden **Aschenritter** durch einen vollständigen Bosskampf gegen Morvath:

1. Das Smartphone zeigt drei unterschiedliche Upgrade-Karten.
2. Ein Tipp wählt genau eine Karte verbindlich aus.
3. Die Fähigkeit wird freigeschaltet oder um einen Rang erhöht.
4. Der Aschenritter greift automatisch mit allen aktiven Boni an.
5. Lebensraub wird angewendet, anschließend greift Morvath unter Berücksichtigung von Knochenschutz zurück.
6. Die nächste Runde beginnt automatisch mit drei neuen Angeboten.

Fähigkeiten bleiben bis zum Sieg oder zur Niederlage aktiv. Bereits erworbene, noch nicht maximierte Fähigkeiten werden ab Runde 2 nach Möglichkeit erneut angeboten. Innerhalb einer Hand gibt es keine Duplikate; Fähigkeiten auf Rang 3 werden ausgeschlossen.

## Held und Balancing

| Wert | Aschenritter / Morvath |
|---|---:|
| Heldenleben | 20 |
| Basisangriff | 4 |
| Morvaths Leben | 60 |
| Morvaths Basisangriff | 2 |

80 deterministische, zufällig gespielte Solopartien dauerten im Mittel **10,26 Runden**. Damit liegt die erste Testkalibrierung im Zielbereich von 8–12 Runden.

## Fähigkeiten

| Fähigkeit | Seltenheit | Rangwirkung |
|---|---|---|
| Aschenklinge | Gewöhnlich | +1 / +2 / +3 Angriff insgesamt |
| Lebensraub | Gewöhnlich | Heilt nach Angriff 1 / 2 / 3 LP |
| Knochenschutz | Selten | Jeder zweite Angriff −1; dann −2; Rang 3 immer −1 und jeden zweiten insgesamt −2 |
| Runenblitz | Selten | Alle drei Runden +2 / +4 / +6 Schaden |
| Blutrausch | Episch | Unter 50 % LP +2 / +3 / +5 Angriff |
| Seelenfeuer | Legendär | Jeder dritte Angriff +4 / +7 / +10 Schaden |

Seelenfeuer besitzt ein deutlich geringeres Angebotsgewicht als normale Fähigkeiten. Seltenheit und Fähigkeitsrang werden unabhängig voneinander dargestellt.

## TV und Smartphone

Der Fernseher bleibt die öffentliche Kampfarena. Er zeigt Morvath, Aschenritter, beide Lebensleisten, Runde, aktive Fähigkeiten mit Rang sowie bestätigte Angriffe, Heilung, Block und Schadenszahlen. Private Angebote sind dort nur in der ausdrücklich markierten PC-Testansicht sichtbar.

Der Smartphone-Controller zeigt im Hochformat Heldenname, Leben, Runde und drei Upgrade-Karten mit Name, Beschreibung, Seltenheit und nächstem Rang. Die Auswahl benötigt keinen Bestätigungsbutton. Direkt danach erscheinen **UPGRADE ERHALTEN** und anschließend **KAMPF LÄUFT – SCHAU AUF DEN TV**.

Controller-Artworks werden serverseitig proportional verkleinert. Das ursprüngliche Seitenverhältnis bleibt erhalten; CSS stellt das vollständige Bild mit `object-fit: contain` dar.

## Technische Struktur

- `HeroDatabase`: datengetriebene Heldengrundwerte und Artwork
- `AbilityDatabase`: sechs Fähigkeitsdefinitionen, Ränge, Effekte, Seltenheiten und Angebotsgewichte
- `GameState`: alleinige Autorität für Aufwertung, Schaden, Heilung, Block, Sieg, Niederlage und Rundenwechsel
- Öffentlicher TV-Snapshot ohne Handkarten
- Privater Controller-Snapshot mit Upgrade-Angeboten
- Bestehende Kreaturendaten und Artworks bleiben vollständig erhalten
- Animationen lesen ausschließlich bestätigte Werte aus dem Kampfprotokoll und verändern keine Lebenspunkte

## Screenshots

- [TV – Upgrade-Auswahl](docs/screenshots/alpha_015_tv_arena.png)
- [TV – Aschenritter greift an](docs/screenshots/alpha_015_hero_attack.png)
- [TV – PC-Testansicht](docs/screenshots/alpha_015_pc_test.png)
- [Smartphone – drei Upgrade-Karten bei 320 × 568](docs/screenshots/alpha_015_smartphone.png)

## Tests

Ausgeführt mit Godot 4.7.1 unter Windows:

- **PASS:** Heldstart und drei eindeutige Upgrade-Angebote
- **PASS:** Freischaltung und Aufwertung bis Rang 3
- **PASS:** Rang 3 wird nicht überschritten und nicht erneut angeboten
- **PASS:** Ab Runde 2 wird nach Möglichkeit ein vorhandenes Upgrade angeboten
- **PASS:** Aschenklinge, Lebensraub, Knochenschutz, Runenblitz, Blutrausch und Seelenfeuer
- **PASS:** Autoritativer Heldenangriff und Morvaths Gegenschlag
- **PASS:** Heilung bleibt unter maximalem Leben; Schaden wird nie negativ
- **PASS:** Sieg, Niederlage und automatischer Rundenwechsel
- **PASS:** Doppeltipps erzeugen weder doppelte Ränge noch doppelten Schaden
- **PASS:** PC-Testmodus und öffentliche TV-Ansicht
- **PASS:** HTTP, WebSocket, QR-Lobby und Verbindungsstatus
- **PASS:** Browser-Rendering bei 320 × 568 ohne Scrollpflicht
- **PASS:** 80 vollständige Balancing-Simulationen, Mittelwert 10,26 Runden

```powershell
godot --headless --path . --script res://tests/test_game_state.gd
godot --headless --path . --script res://tests/test_web_controller.gd
godot --headless --path . --script res://tests/test_connection_lobby.gd
godot --headless --path . --script res://tests/test_combat_feedback.gd
godot --headless --path . --script res://tests/test_main_scene.gd
```

## Bewusste Grenzen

- Nur ein spielbarer Held
- Noch keine Heldenauswahl und kein Multiplayer
- Keine Relikttruhen, neuen Bosse oder zusätzlichen Zufallsereignisse
- HTTP und WebSocket bleiben für das vertrauenswürdige lokale WLAN unverschlüsselt
- Reine IPv6-Netze werden noch nicht unterstützt
- Die neuen Morvath-Frame-Sätze sind dokumentiert, aber noch nicht umfassend integriert
