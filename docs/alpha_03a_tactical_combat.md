# ASHENBORN REFORGED – Alpha 0.3A

## Tactical Combat & Build Synergies

Alpha 0.3A ergänzt den bestehenden autoritativen Kampf um vorher sichtbare Boss-Intents und zwei klar definierte Build-Synergien. Netzwerkarchitektur, Kartenangebot, Heldenbasiswerte und Animationsframes bleiben unverändert.

### Boss-Intents

- **Schädelsturm:** alle lebenden Helden, 2 Schaden, Animation `skull_swarm`.
- **Seelenlanze:** ein vorher markiertes Ziel, 4 Schaden, Animation `spell_blast`. Das Ziel wechselt deterministisch und fair zwischen lebenden Helden.
- **Dunkles Ritual:** Morvath heilt auf seinem Zug bis zu 3 LP (maximal bis zum Maximum) und fügt allen lebenden Helden 1 Schaden zu. Ein zuvor besiegter Boss führt das Ritual nicht mehr aus.

Der Intent wird zu Beginn jeder Runde serverseitig festgelegt und bleibt während der Auswahl unverändert. TV und Smartphone zeigen denselben öffentlichen Intent; private Karten bleiben ausschließlich auf dem jeweiligen Smartphone.

### Synergien

- **Runenklinge:** Aschenklinge Rang 1 + Runenblitz Rang 1. Wenn Runenblitz regulär auslöst, verursacht der Angriff einmalig 2 zusätzlichen Schaden.
- **Blutschild:** Lebensraub Rang 1 + Knochenschutz Rang 1. Wenn Knochenschutz tatsächlich Schaden reduziert, heilt der betroffene Held danach 1 LP bis zum Maximum.

Aktive Synergien werden aus dem autoritativen Build berechnet. Eine erstmalige Aktivierung erzeugt ein einmaliges Entdeckungsereignis für TV und Smartphone.

### Animation und Synchronisation

Die Manifestdatei und alle 46 Bossframes bleiben unverändert. Laufzeitmultiplikatoren steuern das Tempo:

- Idle: `0,80×`
- Kampfsequenzen und Trefferreaktion: `0,55×`
- Tod: `0,45×`

Der GameState berechnet Schaden, Heilung und Ziele genau einmal. Die Darstellung bestätigt anschließend das Ende der Sequenz; erst dann beginnt die nächste Runde. Ein 12-Sekunden-Fallback verhindert Blockaden in Tests oder bei fehlender Darstellung.

### Balancing-Simulation

Automatisiert getestet wurden 200 Solo- und 200 Koop-Partien mit wechselnden Zufalls-, Offensiv- und Defensivstrategien:

| Modus | Siege | Ø Runden | Runenklinge entdeckt | Blutschild entdeckt |
|---|---:|---:|---:|---:|
| Solo | 191/200 (95,5 %) | 10,59 | 191 | 114 |
| Koop | 200/200 (100,0 %) | 10,03 | 200 | 182 |

Strategievergleich:

| Modus / Profil | Siege | Ø Runden |
|---|---:|---:|
| Solo – Zufall | 67/67 | 10,76 |
| Solo – offensiv | 58/67 | 8,43 |
| Solo – defensiv | 66/66 | 12,59 |
| Koop – Zufall + offensiv | 67/67 | 9,09 |
| Koop – offensiv + defensiv | 67/67 | 9,57 |
| Koop – defensiv + Zufall | 66/66 | 11,45 |

Intent-Verteilung über alle nicht finalen Bosszüge:

- Solo: 659 Schädelsturm, 634 Seelenlanze, 624 Dunkles Ritual
- Koop: 616 Schädelsturm, 598 Seelenlanze, 592 Dunkles Ritual

Damit liegen beide Modi ohne zusätzliche Zahlenanpassung im Zielkorridor von 8–14 Runden.

### Abnahme

Die automatisierten Tests prüfen Intent-Schaden und -Heilung, Zielrotation, Schutzinteraktion, Synergiebedingungen, Mehrfachtipp-Sicherheit, öffentliche/private Zustände, WebSocket-Koop, echte Animationsreihenfolge, Rundenbarriere sowie Sieg und Niederlage.

### Bekannte Einschränkungen

- Die bestehende Lobby nimmt weiterhin höchstens zwei aktive Smartphone-Spieler auf; weitere Geräte bleiben Zuschauer.
- Alpha 0.3A enthält bewusst nur die zwei beschriebenen Synergien und keine zusätzlichen Karten oder Progressionssysteme.
- Wenn keine Kampfansicht die Sequenz bestätigen kann, löst nach 12 Sekunden der Sicherheits-Fallback den Rundenwechsel aus.
- Der Headless-Testlauf meldet unter Windows eine nicht verfügbare System-Zertifikatsablage; die lokalen HTTP-/WebSocket-Tests bestehen dennoch vollständig. Der Hauptszenentest meldet beim unmittelbaren Testprozess-Ende zudem bereits bekannte Godot-Ressourcenwarnungen, ohne fehlgeschlagene Assertions.
