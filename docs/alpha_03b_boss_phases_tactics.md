# ASHENBORN REFORGED – Alpha 0.3B

## Bossphasen, Taktikkarten & Balancing

Alpha 0.3B erweitert den autoritativen Solo- und Koop-Kampf um Morvaths zweite Phase und drei situative Taktikkarten. Die Bedienung bleibt bei drei privaten Karten und einer verbindlichen Auswahl per Fingertipp. Netzwerkarchitektur, Helden, Boss, Kartenregeln und vorhandene Animationen wurden nicht ersetzt.

### Bossphasen

- **Phase 1 – Der Aschenkönig:** Schädelsturm 2 an alle, Seelenlanze 4 auf das angekündigte Ziel, Dunkles Ritual bis zu 3 Heilung und 1 an alle.
- **Phase 2 – Zorn der Asche:** Schädelsturm 3 an alle, Seelenlanze 6 auf das angekündigte Ziel, Dunkles Ritual bis zu 4 Heilung und 2 an alle.
- Phase 2 wird nach dem Unterschreiten von 50 % Boss-LP erst zu Beginn der nächsten Runde aktiv. Der bereits angekündigte Intent behält dadurch garantiert seine Phase-1-Werte.
- Der TV zeigt `MORVATH ERWACHT – PHASE 2`, das vorhandene Phase-2-Overlay, Rauch und Morvaths bestehende Energieaufladung. Die aktuelle Phase bleibt danach neben Morvaths Namen sichtbar.

Alle Phasen- und Intentwerte liegen zentral in `scripts/boss_intent_database.gd`.

### Taktikkarten

Ab Runde 3 kann mit 42 % Angebotswahrscheinlichkeit höchstens eine passende Taktik in einer Hand erscheinen. Damit bleiben mindestens zwei Plätze für permanente Upgrades frei.

- **Abwehrhaltung:** nur für tatsächlich betroffene Helden; blockt in dieser Runde 3 Schaden. Knochenschutz wird danach zusätzlich und ohne negative Schadenswerte verrechnet.
- **Ritualbrecher:** nur bei Dunklem Ritual; eine Auswahl in der Gruppe verhindert die Heilung genau einmal, nicht aber den Ritualschaden.
- **Sturmstoß:** +4 Heldenschaden in dieser Runde; trifft Morvath danach denselben Helden, erhöht sich der Bossangriff gegen ihn um 2.

Taktiken erhöhen keinen Rang und werden nach der Auflösung nicht gespeichert. Smartphone und PC-Testansicht kennzeichnen die Karten mit `NUR DIESE RUNDE`, permanente Karten mit `DAUERHAFTES UPGRADE`. Das TV zeigt die ausgespielte Taktik und ihre bestätigten Auswirkungen, erhält aber weiterhin keine private Hand.

### Autoritative Auflösung

Schaden, Heilung, Block, Risiko, Zielwahl und Taktikdauer werden ausschließlich im `GameState` berechnet. Animationen lesen nur das bestätigte Kampfergebnis. Bereitschaft, private Hände, Doppeltipps, Verbindungsabbruch und Wiederverbindung folgen weiterhin dem bestehenden Multiplayer-Ablauf.

### Balancing

Für den höheren Druck wurden nicht Morvaths LP erhöht, sondern drei nachvollziehbare Stellschrauben angepasst:

- Aschenritter: 16 statt 20 maximale LP.
- Lebensraub: 1 / 1 / 2 statt 1 / 2 / 3 Heilung.
- Runenblitz: 2 / 3 / 4 statt 2 / 4 / 6 Schaden.

Der finale deterministische Lauf umfasst 200 Partien je Modus und Strategie, insgesamt 1.600 Partien:

| Modus | Strategie | Siege | Ø Runden | Runenklinge | Blutschild |
|---|---|---:|---:|---:|---:|
| Solo | Zufall | 136/200 (68,0 %) | 10,39 | 140 | 124 |
| Solo | Offensiv | 0/200 (0,0 %) | 6,38 | 151 | 0 |
| Solo | Defensiv | 200/200 (100,0 %) | 12,59 | 200 | 200 |
| Solo | Taktisch | 200/200 (100,0 %) | 12,78 | 187 | 200 |
| Koop | Zufall | 199/200 (99,5 %) | 10,57 | 189 | 180 |
| Koop | Offensiv | 106/200 (53,0 %) | 8,29 | 199 | 0 |
| Koop | Defensiv | 200/200 (100,0 %) | 12,00 | 200 | 200 |
| Koop | Taktisch | 200/200 (100,0 %) | 12,07 | 167 | 200 |

Das Solo-Zufallsprofil erreicht den Orientierungskorridor von 50–75 %. Der extreme Offensivlauf zeigt das Risiko fehlender Defensive deutlich; defensive und taktische Profile sind dagegen noch zu verlässlich. Im Koop bleiben Zufall und Defensive wegen zweier getrennter Lebenspools, abwechselnder Seelenlanzen-Ziele und gemeinsamem Schaden deutlich oberhalb des Zielkorridors. Diese Abweichung wird bewusst nicht durch künstlich erhöhte Boss-LP oder von der Spezifikation abweichende Phase-2-Angriffe kaschiert.

Runenklinge wird je nach Profil weiterhin in 70–100 % der Partien entdeckt. Ursache sind ihre niedrige Voraussetzung und die reguläre Wiederholungslogik für bereits besessene Upgrades. Ihre Schadenskurve wurde reduziert; eine seltenere Freischaltung würde in einem späteren Pass eine Anpassung der Synergie-Voraussetzung oder der Angebotslogik erfordern.

### Tests und Screenshots

Die automatisierte Suite prüft Solo, Koop, Intents beider Phasen, verzögerten Phasenwechsel, alle drei Taktiken, Knochenschutz/Blutschild, temporäres Ablaufen, private Angebote, Mehrfachtipps, Wiederverbindung, Webcontroller, TV-Feedback, echte Bossanimationen, Sieg und Niederlage. Der Balancingtest enthält keine erzwungenen Siegquoten; er verlangt vollständig beendete Partien und dokumentiert die tatsächlichen Resultate.

- `docs/screenshots/alpha_03b_phase2_arena.png`: Phase-2-Arena und permanentes Overlay.
- `docs/screenshots/alpha_03b_tactic_resolution.png`: Taktikkarte in der TV-Auflösung.
- `docs/screenshots/alpha_03b_smartphone.png`: echter Browser-Render des Smartphone-Controllers mit Phase und gemischter Hand.

### Bekannte Einschränkungen

- Defensive und bewusst taktische Builds erreichen in der Simulation weiterhin 100 %; Koop-Zufall liegt bei 99,5 %. Die festen Phase-2-Werte und die unveränderte Gruppenniederlage erst nach dem Fall aller Helden begrenzen den Schwierigkeitsanstieg.
- Rang 2 von Lebensraub bleibt bei 1 Heilung und verbessert sich erst auf Rang 3 auf 2. Das reduziert den frühen Schneeballeffekt, macht den zweiten Rang aber allein betrachtet weniger attraktiv.
- Der lokale Headless-Lauf unter Windows meldet eine nicht lesbare System-Zertifikatsablage. Die lokalen HTTP- und WebSocket-Integrationstests bestehen davon unbeeinflusst.
