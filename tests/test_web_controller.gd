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
	_server = WebControllerServer.new()
	root.add_child(_server)
	_server.public_state_provider = Callable(_game, "get_public_snapshot")
	_server.private_state_provider = Callable(_game, "get_private_snapshot")
	_server.player_selected.connect(func(player_id: String, index: int) -> void: _game.select_upgrade(player_id, index, "web"))
	_server.player_connection_changed.connect(_game.set_player_connected)
	_game.state_changed.connect(func(_snapshot: Dictionary) -> void: _server.broadcast_state())
	_check(_server.start(18765, 18766), "Testserver startet")
	await create_timer(0.1).timeout
	await _test_http_public_surface()
	await _test_two_authenticated_clients()
	_server.stop()
	if _failures.is_empty():
		print("PASS: Öffentliche HTTP-Daten, private WebSocket-Hände, zwei Spieler, Zuschauer und Wiederverbindung")
		quit(0)
	else:
		for failure in _failures:
			printerr("FAIL: " + failure)
		quit(1)


func _test_http_public_surface() -> void:
	var request := HTTPRequest.new()
	root.add_child(request)
	var error := request.request("http://127.0.0.1:18765/")
	_check(error == OK, "Controller-HTML kann angefordert werden")
	if error == OK:
		var response: Array = await request.request_completed
		var body: String = response[3].get_string_from_utf8()
		_check(response[1] == 200 and body.contains("localStorage") and body.contains("type:'hello'"), "Controller unterstützt sitzungsgebundene Identität und Wiederverbindung")
		_check(body.contains("BEREIT – WARTE AUF MITSPIELER") and not body.contains("fetch('/api/select"), "Controller wartet nach einem Tap ohne unsicheren HTTP-Fallback")
		_check(body.contains("object-fit:contain") and body.contains("aspect-ratio:2/3"), "Mobile Karten bleiben proportional")
		_check(body.contains("MEINE FÄHIGKEITEN") and body.contains("effect_text") and body.contains("trigger_text"), "Controller besitzt ein aufklappbares, zustandsbasiertes Build-Menü")
		_check(body.contains("id=\"identity\"") and body.contains("triggered_effects"), "Controller zeigt große Identität und tatsächlich ausgelöste Fähigkeiten")
	error = request.request("http://127.0.0.1:18765/api/state")
	if error == OK:
		var state_response: Array = await request.request_completed
		var public_state = JSON.parse_string(state_response[3].get_string_from_utf8())
		_check(state_response[1] == 200 and public_state.get("hand", []).is_empty(), "Öffentliche Status-API liefert keine private Hand")
	error = request.request("http://127.0.0.1:18765/api/select?index=0")
	if error == OK:
		var select_response: Array = await request.request_completed
		_check(select_response[1] == 405, "Ungebundene HTTP-Auswahl ist gesperrt")
	error = request.request("http://127.0.0.1:18765/asset/ash_blade")
	if error == OK:
		var image_response: Array = await request.request_completed
		var image_bytes: PackedByteArray = image_response[3]
		var decoded := Image.new()
		_check(image_response[1] == 200 and decoded.load_jpg_from_buffer(image_bytes) == OK, "Upgrade-Artwork wird ausgeliefert")
		_check(decoded.get_width() * 3 == decoded.get_height() * 2, "Server bewahrt das 2:3-Seitenverhältnis")
	request.queue_free()


func _test_two_authenticated_clients() -> void:
	var socket_one := await _connect_client("")
	var welcome_one := await _wait_for_message(socket_one, "welcome")
	await _wait_for_state(socket_one)
	var socket_two := await _connect_client("")
	var welcome_two := await _wait_for_message(socket_two, "welcome")
	await _wait_for_state(socket_two)
	_check(welcome_one.get("player_id", "") == "player_1" and welcome_two.get("player_id", "") == "player_2", "Zwei WebSockets erhalten getrennte Spieleridentitäten")
	_check(welcome_one.get("token", "") != welcome_two.get("token", ""), "Spielersitzungen besitzen unterschiedliche geheime Tokens")
	var ids := _server.get_active_player_ids()
	_server.begin_match(ids)
	_game.start_game(77, ids)
	_game.force_hand_for_tests(["ash_blade", "life_steal", "bone_guard"], "player_1")
	_game.force_hand_for_tests(["rune_bolt", "blood_frenzy", "soul_fire"], "player_2")
	_server.broadcast_state()
	var state_one := await _wait_for_hand(socket_one, "ash_blade")
	var state_two := await _wait_for_hand(socket_two, "rune_bolt")
	_check(state_one.get("player_id", "") == "player_1" and state_one.get("hand", [])[0]["id"] == "ash_blade", "Client 1 erhält ausschließlich seine Hand")
	_check(state_two.get("player_id", "") == "player_2" and state_two.get("hand", [])[0]["id"] == "rune_bolt", "Client 2 erhält seine abweichende Hand")
	_check(state_one["player"]["display_name"] == "Spieler 1" and state_one["player"]["color"] == "4b91e2", "Client 1 erhält seine blaue serverseitige Identität")
	_check(state_two["player"]["display_name"] == "Spieler 2" and state_two["player"]["color"] == "a868e8", "Client 2 erhält seine violette serverseitige Identität")

	socket_one.send_text(JSON.stringify({"type": "select", "index": 0, "player_id": "player_2"}))
	socket_one.send_text(JSON.stringify({"type": "select", "index": 1}))
	await _wait_for_ready_count(1)
	_check(_game.ready_count() == 1 and _game.players["player_2"]["ability_ranks"].is_empty() and _game.boss_hp == 120, "Socket 1 kann weder fremde Identität wählen noch per Doppeltipp auflösen")
	socket_two.send_text(JSON.stringify({"type": "select", "index": 0}))
	await _wait_for_phase("resolving")
	_check(_game.boss_hp == 111 and _game.combat_result["attacks"].size() == 2, "Zweite Auswahl startet genau zwei autoritative Heldenangriffe")
	_check(_game.combat_result["boss_attack_count"] == 1 and _game.players["player_1"]["hp"] == 18 and _game.players["player_2"]["hp"] == 18, "Morvath führt genau einen gemeinsamen Gegenangriff aus")

	var spectator := await _connect_client("")
	var spectator_welcome := await _wait_for_message(spectator, "welcome")
	var spectator_state := await _wait_for_state(spectator)
	_check(spectator_welcome.get("role", "") == "spectator" and spectator_state.get("hand", []).is_empty(), "Drittes Gerät wird Zuschauer ohne private Karten")
	var boss_before := _game.boss_hp
	spectator.send_text(JSON.stringify({"type": "select", "index": 0}))
	await create_timer(0.05).timeout
	_check(_game.boss_hp == boss_before, "Zuschaueraktion verändert den Spielzustand nicht")

	var token_two := String(welcome_two.get("token", ""))
	socket_two.close(1000, "reconnect test")
	await _wait_for_connection("player_2", false)
	var reconnect := await _connect_client(token_two)
	var reconnect_welcome := await _wait_for_message(reconnect, "welcome")
	var reconnect_state := await _wait_for_state(reconnect)
	_check(reconnect_welcome.get("player_id", "") == "player_2" and reconnect_state.get("player_id", "") == "player_2", "Token stellt dieselbe Spieleridentität wieder her")
	_check(reconnect_state.get("player", {}).get("hero", {}).get("abilities", []).size() == 1 and reconnect_state.get("player_hp", 0) == 18, "Wiederverbindung stellt Build und Lebenspunkte wieder her")
	_check(reconnect_state.get("player", {}).get("color", "") == "a868e8", "Wiederverbindung bewahrt Spieler-2-Farbe und Nummer")
	socket_one.close()
	reconnect.close()
	spectator.close()


func _connect_client(token: String) -> WebSocketPeer:
	var socket := WebSocketPeer.new()
	_check(socket.connect_to_url("ws://127.0.0.1:18766") == OK, "WebSocket-Verbindung kann beginnen")
	for _frame in 240:
		socket.poll()
		if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
			socket.send_text(JSON.stringify({"type": "hello", "token": token}))
			return socket
		await process_frame
	_check(false, "WebSocket-Handshake wird abgeschlossen")
	return socket


func _wait_for_message(socket: WebSocketPeer, message_type: String) -> Dictionary:
	for _frame in 300:
		socket.poll()
		while socket.get_available_packet_count() > 0:
			var parsed = JSON.parse_string(socket.get_packet().get_string_from_utf8())
			if typeof(parsed) == TYPE_DICTIONARY and parsed.get("type", "") == message_type:
				return parsed
		await process_frame
	_check(false, "WebSocket-Nachricht fehlt: " + message_type)
	return {}


func _wait_for_state(socket: WebSocketPeer) -> Dictionary:
	var message := await _wait_for_message(socket, "state")
	return message.get("state", {})


func _wait_for_hand(socket: WebSocketPeer, first_ability_id: String) -> Dictionary:
	for _frame in 300:
		socket.poll()
		while socket.get_available_packet_count() > 0:
			var parsed = JSON.parse_string(socket.get_packet().get_string_from_utf8())
			if typeof(parsed) != TYPE_DICTIONARY or parsed.get("type", "") != "state":
				continue
			var received_state: Dictionary = parsed.get("state", {})
			var received_hand: Array = received_state.get("hand", [])
			if not received_hand.is_empty() and received_hand[0].get("id", "") == first_ability_id:
				return received_state
		await process_frame
	_check(false, "Erwartete private Hand fehlt: " + first_ability_id)
	return {}


func _wait_for_phase(expected: String) -> void:
	for _frame in 240:
		if _game.phase == expected:
			return
		await process_frame
	_check(false, "Spielphase erreicht nicht: " + expected)


func _wait_for_ready_count(expected: int) -> void:
	for _frame in 240:
		if _game.ready_count() == expected:
			return
		await process_frame
	_check(false, "Bereitschaftszähler erreicht nicht: %d" % expected)


func _wait_for_connection(player_id: String, connected: bool) -> void:
	for _frame in 240:
		if _game.players.has(player_id) and _game.players[player_id].get("connected", false) == connected:
			return
		await process_frame
	_check(false, "Verbindungsstatus wird nicht aktualisiert: " + player_id)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
