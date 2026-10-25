# ASHENBORN REFORGED – Alpha 0.1.4

## Start

1. Das Verzeichnis in Godot **4.7.1** öffnen.
2. Das Projekt mit **F6/F5** beziehungsweise „Projekt ausführen“ starten.
3. Im Hauptmenü **SPIELEN** wählen. Dadurch öffnet sich die Verbindungslobby.

Das Projekt verwendet den Compatibility Renderer und startet über `scenes/main.tscn`.

## Bedienung

### PC-Testmodus

In der Verbindungslobby **OHNE SMARTPHONE TESTEN** wählen. Nur in diesem Modus erscheint auf dem TV die deutlich als **PC-TESTANSICHT · PRIVATE HAND** markierte Kartenhand. Ein Klick auf eine Kreaturenkarte ist bereits die verbindliche Auswahl und startet den dargestellten Schlagabtausch. Die Kreatur fügt Morvath ihren vorhandenen Angriffswert als Schaden zu. Falls Morvath überlebt, verursacht sein Gegenschlag weiterhin 2 Schaden.

### Smartphone-Controller

1. PC und Smartphone mit demselben lokalen Netzwerk verbinden.
2. Im Hauptmenü **SPIELEN** wählen.
3. Den angezeigten QR-Code mit der iPhone-Kamera oder einem anderen Smartphone scannen. Er enthält direkt die automatisch erkannte Adresse, beispielsweise `http://192.168.x.x:8765`.
4. Sobald der Browser verbunden ist, wechselt der Status zu **Smartphone verbunden** und **SPIEL STARTEN** wird freigeschaltet.
5. Den Raid am Host starten und auf dem Smartphone eine Karte antippen. Dieser eine Tipp ist verbindlich; danach zeigt der Controller **KAMPF LÄUFT – SCHAU AUF DEN TV**.

Über **VERBINDUNG** oben rechts in der Kampfansicht bleiben QR-Code, URL und aktueller Status während des Spiels erreichbar.

Bei einem normalen Smartphone-Spiel zeigt der Fernseher keine Handkarten. Er bleibt die öffentliche Arena für Morvath, Lebenspunkte, Runde, Statusmeldungen und Kampfanimationen. Die gewählte Kreatur erscheint dort erst während ihres bestätigten Angriffs.

Beim ersten Start kann die Windows-Firewall nach der Freigabe für private Netzwerke fragen. HTTP verwendet Port **8765**, WebSocket Port **8766**.

## Kampfinszenierung

Die Kampfansicht stellt ausschließlich bereits bestätigte Ereignisse des autoritativen Spielzustands dar:

- Die gewählte Kreaturenillustration wird groß eingeblendet und bewegt sich auf Morvath zu.
- Ein vorhandener Runeneffekt, ein kurzer Boss-Impuls und eine Schadenszahl zeigen den bestätigten Kreaturenschaden.
- Morvath antwortet mit vorhandener Angriffspose, Schädelenergie, Vorwärtsimpuls und einem eigenen Soundeffekt.
- Spieler-Schadenszahl, roter Trefferimpuls und animierte Lebensleiste machen den Gegenschlag sichtbar.
- Eine kurze Rundenanzeige leitet zur nächsten Hand über; die drei neuen Karten blenden gemeinsam ein.
- Die vorhandenen Sounds für Angriff, Magie, Gegenschlag, Kartenwechsel, Sieg und Niederlage sind mit den sichtbaren Momenten synchronisiert.

Animationen berechnen keinen Schaden und lösen keine zusätzlichen Angriffe aus. Lebenswerte, Sieg, Niederlage, Kartenziehung und Rundentakt bleiben vollständig im bestehenden `GameState`.

Die neu hinzugekommenen Morvath-Frame-Sätze wurden nur erfasst und auf technische Verwendbarkeit geprüft: [Morvath-Assetprüfung](docs/morvath_asset_review.md). Eine weitergehende Integration ist bewusst nicht Teil dieser Version.

## Funktionsumfang

- Hauptmenü mit Spielen, Spielregeln und Lautstärke
- Verbindungslobby mit automatisch erkannter WLAN-Adresse und echtem QR-Code
- Live-Status für verbundene beziehungsweise getrennte Smartphone-WebSockets
- Gesperrter Smartphone-Start bis zum erfolgreichen Handshake sowie separater PC-Teststart
- Solo-Bosskampf gegen Morvath (30 Leben) mit Spielerleben (20)
- Acht Kreaturen mit vorhandenen Originalillustrationen
- Seltenheiten und Ziehgewichte: Gewöhnlich 65 %, Selten 25 %, Episch 9 %, Legendär 1 %
- Drei unabhängige Ziehungen pro Runde; Duplikate sind erlaubt
- Vollständiger Angriff, Morvaths Gegenschlag und automatischer Rundenwechsel
- Sichtbarer Kreaturenangriff, Boss-Treffer, Schadenszahlen und inszenierter Gegenangriff
- Klare Trennung zwischen öffentlicher TV-Arena und privater Smartphone-Hand
- Separat gekennzeichnete Kartenhand ausschließlich im PC-Testmodus
- Zuverlässige Sieg-/Niederlage-Zustände mit Neustart
- Identische autoritative Auswahlroutine für PC und Smartphone
- Serverseitige Sperre gegen Doppelangriffe
- Hochformat-Webcontroller mit drei Karten im 2:3-Format und ohne Bestätigungsbutton
- Zur Laufzeit verkleinerte und gecachte Ableitungen der Originalartworks für schnellere WLAN-Übertragung
- Dunkle High-Fantasy-Oberfläche mit Gold-, Bronze-, Cyan- und Gefahrenakzenten

## Screenshots

- [TV – öffentliche Arena ohne Handkarten](docs/screenshots/alpha_014_tv_arena.png)
- [TV – ausgewählte Kreatur greift an](docs/screenshots/alpha_014_tv_attack.png)
- [TV – ausdrücklich markierter PC-Testmodus](docs/screenshots/alpha_014_pc_test.png)
- [Smartphone – drei vollständige 2:3-Karten](docs/screenshots/alpha_014_smartphone.png)

## Testergebnisse

Ausgeführt mit Godot 4.7.1 unter Windows:

- **PASS:** 25 Prüfungen für Kartenpool, Artwork-Pfade, Ziehgewichte, Schaden, Gegenschlag, neue Runde, Sieg, Niederlage und Doppeltipp-Schutz
- **PASS:** Hauptmenü, Verbindungslobby, PC-Testmodus und autoritativer Angriff
- **PASS:** Normale TV-Arena enthält keine private Kartenhand; PC-Testmodus blendet sie markiert ein
- **PASS:** Ein Kartenklick startet genau einen Angriff; zwei schnelle Klicks erzeugen kein zweites Schadensereignis
- **PASS:** Das visuelle Ereignis übernimmt exakt den bestätigten Boss- und Spielerschaden
- **PASS:** Kreaturenangriff, Boss-Treffer, Gegenangriff und Rundeneinstieg laufen in der vorgesehenen Reihenfolge
- **PASS:** Lebensleisten enden auf den autoritativen Werten des Spielzustands
- **PASS:** Sieg erscheint nach dem Boss-Treffer und Niederlage nach Morvaths sichtbarem Gegenangriff
- **PASS:** QR-Code enthält exakt die automatisch gebildete Controller-URL und ist rücklesbar
- **PASS:** Smartphone-Verbindung schaltet **SPIEL STARTEN** frei; Trennung sperrt ihn wieder
- **PASS:** QR-Code, URL und Status sind während des Kampfes erneut erreichbar
- **PASS:** echte HTTP-Anfrage, Status-API, Kartenbilder und WebSocket-Handshake
- **PASS:** Smartphone-HTML bietet direkte Ein-Tipp-Auswahl ohne zusätzlichen Angriffsbutton
- **PASS:** Smartphone-Artworks verwenden unverzerrtes `contain`-Scaling; Karten bleiben responsiv und Namen können umbrechen
- **PASS:** echtes Edge-Rendering bei 320 × 568 zeigt alle drei Karten vollständig im sichtbaren Bereich
- **PASS:** TV-Kampfphasen bei 1280 × 720 visuell kontrolliert

Testbefehle (bei global verfügbarem Godot-Befehl):

```powershell
godot --headless --path . --script res://tests/test_game_state.gd
godot --headless --path . --script res://tests/test_web_controller.gd
godot --headless --path . --script res://tests/test_connection_lobby.gd
godot --headless --path . --script res://tests/test_combat_feedback.gd
godot --headless --path . --script res://tests/test_main_scene.gd
```

## Bekannte Einschränkungen

- Der Controller kann Kämpfe bedienen, aber nicht starten oder neu starten. Das geschieht am Host.
- HTTP und WebSocket sind für das vertrauenswürdige lokale Netzwerk unverschlüsselt und ohne Anmeldung.
- Bei mehreren aktiven Netzwerkadaptern (zum Beispiel VPN) kann die zuerst erkannte Adresse ungeeignet sein. Dann die tatsächliche LAN-IP des PCs mit Port 8765 verwenden.
- Noch kein Export-Paket und kein automatischer Firewall-Eintrag.
- Beim erzwungenen Ende eines isolierten UI-Testprozesses kann Godot 4.7.1 Aufräumwarnungen für noch gecachte Ressourcen melden. Der reguläre Projektstart zeigt keine Skript- oder Szenenfehler.
- Die QR-Lobby verwendet bewusst eine lokale IPv4-Adresse. Reine IPv6-Netze werden in Alpha 0.1.4 nicht unterstützt.
- Bewusst keine neuen Mechaniken, Kartenfähigkeiten, Relikte, Ereignisse oder Zufallsereignisse in Alpha 0.1.4.
