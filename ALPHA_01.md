# ASHENBORN REFORGED – Alpha 0.2A · Co-op Multiplayer Foundation

## Start

1. Projekt mit Git LFS klonen und in Godot **4.7.1** öffnen.
2. Mit **F5** starten und **SPIELEN** wählen.
3. Den gemeinsamen QR-Code mit einem oder zwei Smartphones im selben WLAN öffnen.
4. Sobald mindestens **Spieler 1** verbunden ist, **SPIEL STARTEN** wählen.

Ein drittes oder späteres Gerät wird in Alpha 0.2A Zuschauer. **OHNE SMARTPHONE TESTEN** startet weiterhin den markierten lokalen PC-Testmodus.

## Gemeinsamer Kampfablauf

1. Jeder lebende, verbundene Spieler erhält drei eigene Upgrade-Angebote.
2. Ein Tipp merkt das Upgrade verbindlich vor; ein zweiter Tipp wird abgewiesen.
3. Das Smartphone zeigt **BEREIT – WARTE AUF MITSPIELER**, der Fernseher den gemeinsamen Bereitschaftszähler.
4. Erst wenn alle erreichbaren aktiven Spieler bereit sind, werden die Upgrades aktiviert.
5. Die Aschenritter greifen mit ihren individuellen Builds nacheinander an.
6. Morvath führt genau einen gemeinsamen Gegenangriff aus und trifft jeden lebenden Helden für zwei Basisschaden abzüglich dessen persönlichem Knochenschutz.
7. Die nächste gemeinsame Runde beginnt automatisch.

Morvath besitzt im Solo-Spiel 60 LP und bei zwei Spielern 120 LP. Jeder Aschenritter startet mit 20 LP. Die Gruppe gewinnt beim Tod Morvaths und verliert erst, wenn alle Helden gefallen sind.

## Spieler- und Verbindungsmodell

Der `GameState` verwaltet datengetriebene Spielerobjekte mit stabiler ID, Anzeigename, eigenem Helden, Leben, Hand, Fähigkeitsrängen, Bereitschaft und Verbindungsstatus. Das Modell unterstützt bis zu sechs Spielerzustände; die Alpha-0.2A-Lobby vergibt höchstens zwei aktive Plätze.

Jedes Smartphone erhält beim WebSocket-Handshake ein zufälliges Sitzungstoken. Dieses Token wird lokal im Browser gespeichert und stellt nach einem Verbindungsabbruch dieselbe Spieleridentität einschließlich Leben, Build und Hand wieder her. Neue Geräte werden während einer laufenden Partie nicht in die aktive Gruppe aufgenommen.

Wenn ein noch nicht bereiter Spieler die Verbindung verliert, wird er nicht länger für die Bereitschaftsschranke gezählt. Der Host wählt kein Upgrade für ihn. Bereits bestätigte Auswahlen bleiben gültig. Der Held verbleibt in der Partie und kann nach Wiederverbindung weiterspielen.

## Datenschutz und Autorität

- Der Host ist die einzige Autorität für Ränge, Schaden, Heilung, Schutz, Runden und Ergebnisse.
- Öffentliche Snapshots enthalten Boss, Runde, öffentliche Heldenwerte und Bereitschaft, aber keine Hände.
- Private Hände werden pro authentifizierter WebSocket-Verbindung erzeugt.
- Eine Auswahl wird aus der gebundenen Socket-Identität abgeleitet; eine vom Client behauptete fremde Spieler-ID wird ignoriert.
- `/api/state` ist öffentlich und handkartenfrei.
- Der alte ungebundene `/api/select`-Weg antwortet mit HTTP 405.
- Zuschauer können keine Auswahl auslösen.

HTTP und WebSocket bleiben bewusst lokal und unverschlüsselt; der QR-Code und die bestehende WLAN-Erkennung wurden nicht ersetzt.

## Erhaltene Hero-Progression

Aschenklinge, Lebensraub, Knochenschutz, Runenblitz, Blutrausch und Seelenfeuer besitzen weiterhin drei Ränge und dieselben Alpha-0.1.5-Effekte. Fähigkeiten, Hände, Angriffs- und Bossangriffszähler werden pro Spieler geführt. Alte Kreaturenkarten und alle bestehenden Artworks bleiben im Projekt.

## TV und Smartphone

Die öffentliche TV-Arena zeigt Morvath zentral, beide Spieler mit Name, Verbindung, Bereitschaft, LP und aktiven Fähigkeiten sowie den Zähler **1/2 BEREIT** beziehungsweise **2/2 BEREIT**. Während der Auflösung werden Spielername, Upgrade, Angriff und persönlicher Treffereffekt eindeutig nacheinander angezeigt. Private Karten erscheinen nur in der gekennzeichneten PC-Testansicht.

Der Smartphone-Controller bleibt hochkant und zeigt nur die eigene Hand, eigene LP, Runde und Boss-LP. Nach der Auswahl gibt es keinen Bestätigungsbutton. Zuschauer sehen ausschließlich öffentliche Kampfdaten.

## Tests

Automatisiert unter Godot 4.7.1 geprüft:

- Solo-Regression einschließlich 80 vollständiger Partien, Mittelwert 10,26 Runden
- Zwei getrennte Spielerzustände und 120 Boss-LP
- Unterschiedliche private Hände und Builds
- 1/2-Bereitschaft ohne vorzeitige Aufwertung oder Schaden
- Zwei Heldenangriffe und exakt ein gemeinsamer Bossangriff
- Persönlicher Lebensraub und Knochenschutz
- Doppeltipps, ungültige Aktionen und Zuschaueraktionen
- Öffentliche HTTP-Daten ohne Hand und gesperrte HTTP-Auswahl
- Zwei echte lokale WebSocket-Clients mit gebundener Identität
- Verbindungsabbruch und Wiederverbindung per Sitzungstoken
- Gruppen-Sieg und Gruppen-Niederlage
- QR-Lobby, PC-Testmodus und bestehendes Kampf-Feedback
- Sechs-Spieler-Datenmodell bei auf zwei begrenzter Alpha-Lobby

```powershell
godot --headless --path . --script res://tests/test_game_state.gd
godot --headless --path . --script res://tests/test_coop_game_state.gd
godot --headless --path . --script res://tests/test_web_controller.gd
godot --headless --path . --script res://tests/test_connection_lobby.gd
godot --headless --path . --script res://tests/test_combat_feedback.gd
godot --headless --path . --script res://tests/test_main_scene.gd
```

## Screenshots

- [Koop-TV-Arena](docs/screenshots/alpha_02a_coop_arena.png)
- [Zugeordneter Koop-Angriff](docs/screenshots/alpha_02a_coop_attack.png)

## Grenzen von Alpha 0.2A

- Maximal zwei aktive Smartphone-Spieler; weitere Geräte sind Zuschauer
- Beide Spieler verwenden den Aschenritter
- Keine neuen Bosse, Helden, Fähigkeiten, Relikte oder Animationssysteme
- Reine IPv6-Netze werden noch nicht unterstützt
