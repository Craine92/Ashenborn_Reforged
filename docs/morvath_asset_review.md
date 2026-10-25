# Morvath-Assetprüfung – Alpha 0.1.4

Die neuen Dateien unter `assets/bosses/morvath` wurden inventarisiert und stichprobenartig visuell geprüft. In Alpha 0.1.4 erfolgt bewusst keine umfassende Animationsintegration.

| Sequenz | Frames | Format | Empfohlene Rate | Einschätzung |
|---|---:|---:|---:|---|
| Idle | 8 | 444 × 444 | 8 FPS | Für einen ruhigen Arena-Loop geeignet |
| Energy Charge | 8 | 444 × 444 | 10 FPS | Als Vorbereitung eines Bossangriffs geeignet |
| Skull Swarm | 8 | 444 × 444 | 10 FPS | Als düsterer Gegenangriff geeignet |
| Spell Blast | 8 | 444 × 444 | 12 FPS | Als klar lesbarer Zauberangriff geeignet |
| Hit Reaction | 6 | 512 × 512 | 12 FPS | Für eine direkte Trefferreaktion geeignet |
| Death | 8 | 444 × 444 | 10 FPS | Für eine spätere Siegsequenz geeignet |

Die Einzelbilder besitzen konsistente quadratische Abmessungen innerhalb ihrer jeweiligen Sequenz und einen Alphakanal. Dateinamen, Reihenfolge und die Angaben in `manifest.json` sind für eine spätere Godot-Integration brauchbar. Vor einer Integration sollten die Übergänge zwischen vorhandenem Portrait und den stilistisch teils abweichenden Frame-Sätzen gemeinsam im Spielkontext geprüft werden.
