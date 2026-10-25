extends SceneTree

var _failures: Array[String] = []
var _game: GameState
var _server: WebControllerServer


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_game = GameState.new()
	root.add_child(_game)
	_game.resolution_delay = 99.0
	_game.start_game(7)
	_game.force_hand_for_tests(["ash_blade", "life_steal", "bone_guard"])
	_server = WebControllerServer.new()
	root.add_child(_server)
	_server.state_provider = Callable(_game, "get_snapshot")
	_server.card_selected.connect(func(index: int) -> void: _game.select_upgrade(index, "web"))
	_game.state_changed.connect(func(_snapshot: Dictionary) -> void: _server.broadcast_state())
	_check(_server.start(18765, 18766), "Testserver startet")
	await create_timer(0.1).timeout
	await _test_http()
	await _test_websocket()
	_server.stop()
	if _failures.is_empty():
		print("PASS: HTTP-Seite, Status-API, WebSocket-Auswahl und Doppeltipp-Schutz")
		quit(0)
	else:
		for failure in _failures:
			printerr("FAIL: " + failure)
		quit(1)


func _test_http() -> void:
	var request := HTTPRequest.new()
	root.add_child(request)
	var error := request.request("http://127.0.0.1:18765/")
	_check(error == OK, "HTTP-Anfrage kann gestartet werden")
	if error == OK:
		var response: Array = await request.request_completed
		_check(response[1] == 200, "Controller-HTML antwortet mit HTTP 200")
		var body: String = response[3].get_string_from_utf8()
		_check(body.contains("ASHENBORN") and body.contains("new WebSocket"), "Controller enthält Oberfläche und WebSocket-Client")
		_check(body.contains("function choose") and body.contains("UPGRADE ERHALTEN") and body.contains("SCHAU AUF DEN TV"), "Controller wählt mit einem Tap und zeigt Upgrade- sowie Kampfzustand")
		_check(not body.contains("id=\"attack\""), "Controller besitzt keinen zusätzlichen Bestätigungsbutton")
		_check(body.contains("object-fit:contain") and not body.contains(".card img{width:100%;height:100%;object-fit:cover"), "Kartenartwork wird vollständig und unverzerrt dargestellt")
		_check(body.contains("aspect-ratio:2/3") and body.contains("overflow-wrap:anywhere") and body.contains("c.description") and body.contains("c.rank_label"), "Drei responsive 2:3-Karten zeigen Namen, Beschreibung und Rang")
	error = request.request("http://127.0.0.1:18765/asset/ash_blade")
	_check(error == OK, "Kartenbild-Anfrage kann gestartet werden")
	if error == OK:
		var image_response: Array = await request.request_completed
		var image_bytes: PackedByteArray = image_response[3]
		_check(image_response[1] == 200 and image_bytes.size() > 1000, "Originalartwork wird als Controller-Bild ausgeliefert")
		_check(image_bytes.size() < 1000000 and image_bytes[0] == 255 and image_bytes[1] == 216, "Controller-Artwork ist als schlankes JPEG optimiert")
		var decoded := Image.new()
		_check(decoded.load_jpg_from_buffer(image_bytes) == OK and decoded.get_width() * 3 == decoded.get_height() * 2, "Server bewahrt das ursprüngliche 2:3-Seitenverhältnis")
	request.queue_free()


func _test_websocket() -> void:
	var socket := WebSocketPeer.new()
	var error := socket.connect_to_url("ws://127.0.0.1:18766")
	_check(error == OK, "WebSocket-Verbindung kann gestartet werden")
	for _frame in 180:
		socket.poll()
		if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
			break
		await process_frame
	_check(socket.get_ready_state() == WebSocketPeer.STATE_OPEN, "WebSocket-Handshake wird abgeschlossen")
	if socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	socket.send_text(JSON.stringify({"type": "select", "index": 0}))
	socket.send_text(JSON.stringify({"type": "select", "index": 0}))
	for _frame in 120:
		socket.poll()
		if _game.phase == "resolving":
			break
		await process_frame
	_check(_game.boss_hp == 55 and _game.ability_ranks["ash_blade"] == 1, "WebSocket-Tipp schaltet Aschenklinge frei und verursacht genau einen Heldenangriff")
	_check(_game.player_hp == 18, "WebSocket-Auswahl löst Morvaths Gegenschlag aus")
	_check(_game.phase == "resolving", "Doppelte WebSocket-Pakete erzeugen keinen zweiten Angriff")
	socket.close()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
