# ASHENBORN REFORGED – Alpha 0.3A · Tactical Combat & Build Synergies

## Neu in Alpha 0.3A

- Drei vor der Auswahl festgelegte Boss-Intents mit öffentlicher Ziel- und Schadensanzeige
- Runenklinge und Blutschild als datengetriebene Build-Synergien
- Synergie-Entdeckung auf TV und Smartphone sowie aktive Synergien im Build-Menü
- Bossanimationen mit konfigurierbaren, verlangsamten Laufzeitfaktoren
- Darstellungsbestätigte Rundenbarriere mit sicherem Fallback
- 400 automatisierte Solo-/Koop-Balancingläufe im Zielkorridor

Die technischen Details und Messwerte stehen in `docs/alpha_03a_tactical_combat.md`.

## Start

1. Projekt mit Git LFS klonen und in Godot **4.7.1** öffnen.
2. Mit **F5** starten und **SPIELEN** wählen.
3. Den gemeinsamen QR-Code mit einem oder zwei Smartphones im selben WLAN öffnen.
4. Sobald mindestens ein Spieler verbunden ist, **SPIEL STARTEN** wählen.

**OHNE SMARTPHONE TESTEN** startet weiterhin den lokalen PC-Testmodus. Dieser wird jetzt ausdrücklich als **PC-TEST · OFFLINE BEREIT** angezeigt und nicht mehr als Netzwerkfehler behandelt.

## Stabile Spieleridentitäten

- **Spieler 1:** Blau (`#4b91e2`)
- **Spieler 2:** Violett (`#a868e8`)
- **Weitere Geräte:** Zuschauer

Nummer, Farbe und Name stammen aus der serverseitig vergebenen Spieler-ID. Das Sitzungstoken stellt bei einer Wiederverbindung dieselbe Identität, Hand, Lebenspunkte und denselben Build wieder her. Smartphone und TV verwenden dieselbe Farbe für Identitätszeile, Panel, Lebensleiste und Status.

## Autoritatives Build-Tracking

Der Smartphone-Controller besitzt den aufklappbaren Bereich **MEINE FÄHIGKEITEN**. Er zeigt ausschließlich die Fähigkeiten des zugeordneten Spielers:

- Name, Seltenheitsfarbe und aktueller Rang
- vollständige aktive Wirkung
- nächste Runenblitz-Runde
- verbleibende Angriffe bis Seelenfeuer
- aktuell erfüllte oder nicht erfüllte Blutrausch-Bedingung

Diese Angaben werden bei jedem Snapshot im `GameState` aus tatsächlicher Runde, LP, Fähigkeitsrang und persönlichem Angriffszähler berechnet. Die normale Kartenwahl bleibt bei geschlossenem Menü vollständig sichtbar und ohne Scrollpflicht. Nach bestätigten Auslösungen erscheinen Meldungen wie **RUNENBLITZ +2 SCHADEN** oder **LEBENSRAUB +1 LP**.

Private Hände und private Kampfdetails werden weiterhin pro authentifizierter WebSocket-Verbindung gefiltert. Zuschauer erhalten nur öffentliche Daten.

## Morvath-Animationskomponente

`BossAnimator` liest `assets/bosses/morvath/manifest.json`, lädt die dort gelisteten Einzelbilder und spielt sie mit den empfohlenen FPS ab. Die Komponente ist von der Kampflogik getrennt und kann später mit einem anderen Manifest wiederverwendet werden.

| Sequenz | Frames | FPS | Einsatz |
|---|---:|---:|---|
| `idle` | 8 | 8 | kontinuierlich während Auswahl und Ruhe |
| `hit_reaction` | 6 | 12 | nach jedem bestätigten Heldenangriff |
| `energy_charge` | 8 | 10 | vor Morvaths gemeinsamem Gegenangriff |
| `spell_blast` | 8 | 12 | Bossangriff in ungeraden Runden |
| `skull_swarm` | 8 | 10 | alternative Darstellung desselben Bossangriffs in geraden Runden |
| `death` | 8 | 10 | einmalig bis zum letzten Frame bei Sieg |

Die Kampfwerte werden bereits vorher autoritativ berechnet. Animationen lesen nur das bestätigte Kampfprotokoll und erzeugen keine Schadens- oder Upgrade-Ereignisse.

## Synchronisierter Ablauf

1. Spieler 1 greift an.
2. `hit_reaction` läuft vollständig.
3. Spieler 2 greift an.
4. `hit_reaction` läuft erneut vollständig.
5. `energy_charge` lädt Morvaths Angriff.
6. `spell_blast` oder `skull_swarm` wird vollständig abgespielt.
7. Die bereits berechneten Auswirkungen werden an beiden Helden dargestellt.
8. Erst danach beginnt die nächste Runde.

Ein tödlicher Heldenangriff überspringt Aufladung und Gegenangriff und spielt direkt `death`. Sequenz-IDs brechen veraltete Animationen bei Neustart oder Szenenwechsel ab. Jede Einzelanimation besitzt zusätzlich ein begrenztes Zeitfenster.

## Asset-Audit

Alle 46 Manifestdateien existieren, sind lesbar, besitzen einen Alphakanal, haben innerhalb ihrer Sequenz eindeutige Inhalte und zeigen zwischen jedem aufeinanderfolgenden Bild eine deutlich messbare Änderung.

Festgestellte Quelldatenabweichungen:

- `hit_reaction` entspricht vollständig den manifestierten 512×512 Pixeln.
- Bei den fünf als 444×444 beschriebenen Reihen sind nur jeweils zwei Frames exakt 444×444. Die übrigen liegen bei 443×444, 444×443 oder 443×443.
- `BossAnimator` gleicht diese Ein-Pixel-Abweichungen über eine gemeinsame zentrierte, seitenverhältnistreue Fläche aus.
- Die Trefferreaktion besitzt in Teilen eine schwache rechteckige Hintergrundtönung. Sie ist bereits im gelieferten Artwork vorhanden und im Treffer-Screenshot sichtbar; es wurde kein neues Artwork erzeugt oder kaschiert.

Gemessene kleinste Bildänderung zwischen aufeinanderfolgenden, auf 32×32 normalisierten Frames: `idle` 0,0956; `energy_charge` 0,1285; `skull_swarm` 0,1064; `spell_blast` 0,1055; `hit_reaction` 0,1205; `death` 0,1440.

## Visuelle Belege

- [TV-Arena mit stabilen Spielerfarben](docs/screenshots/alpha_02b_identity_arena.png)
- [Morvath-Trefferreaktion im Kampf](docs/screenshots/alpha_02b_hit_reaction.png)
- [Vier aufeinanderfolgende Spell-Blast-Frames](docs/screenshots/alpha_02b_morvath_spell_frames.png)

## Tests

Automatisiert unter Godot 4.7.1 geprüft:

- Solo-Regression und 80 vollständige Balancing-Simulationen, weiterhin 10,26 Runden im Mittel
- Zwei-Spieler-Koop, getrennte Builds, Hände und Kampfdetails
- stabile blaue/violette Identitäten einschließlich Wiederverbindung
- vollständige Wirkungs-, Auslöse- und Bedingungstexte aus dem `GameState`
- tatsächliche Fähigkeitstrigger aus dem bestätigten Kampfprotokoll
- alle Manifestdateien, Framezahlen, FPS, Alpha, Größen, Duplikate und Bildänderungen
- kontinuierlicher Idle-Loop
- vollständige Treffer-, Auflade-, Spell-Blast-, Skull-Swarm- und Todessequenzen
- Reihenfolge: zwei Angriffe, zwei Trefferreaktionen, eine Aufladung, ein Bossangriff
- Rundenbarriere bis nach der Animation
- unveränderte Kampfwerte während sämtlicher Animationen
- Sieg ohne Boss-Gegenangriff, Niederlage, Doppeltippschutz
- QR-Lobby, Zwei-WebSocket-Clients, Zuschauer und Wiederverbindung
- PC-Testmodus ohne irreführenden Netzwerkfehler

```powershell
godot --headless --path . --script res://tests/test_game_state.gd
godot --headless --path . --script res://tests/test_coop_game_state.gd
godot --headless --path . --script res://tests/test_web_controller.gd
godot --headless --path . --script res://tests/test_connection_lobby.gd
godot --headless --path . --script res://tests/test_boss_animator.gd
godot --headless --path . --script res://tests/test_animation_sync.gd
godot --headless --path . --script res://tests/test_combat_feedback.gd
godot --headless --path . --script res://tests/test_main_scene.gd
```

## Grenzen von Alpha 0.2B

- Maximal zwei aktive Smartphone-Spieler; weitere Geräte bleiben Zuschauer
- Beide Spieler verwenden weiterhin den Aschenritter
- Keine neuen Bosse, Helden, Fähigkeiten, Relikte oder Spielmechaniken
- HTTP und WebSocket bleiben für das lokale WLAN unverschlüsselt
- Reine IPv6-Netze werden noch nicht unterstützt
