extends SceneTree

var _failures: Array[String] = []
var _server: WebControllerServer
var _lobby: ConnectionLobby


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := GameState.new()
	root.add_child(game)
	game.start_game(11)
	_server = WebControllerServer.new()
	root.add_child(_server)
	_server.state_provider = Callable(game, "get_snapshot")
	_lobby = ConnectionLobby.new()
	root.add_child(_lobby)
	_server.connection_changed.connect(_lobby.set_smartphone_connected)
	var server_ok := _server.start(18775, 18776)
	var url := _server.controller_url()
	if url.is_empty():
		url = "http://192.168.1.50:18775"
	_lobby.configure(url, server_ok, true)
	_check(server_ok, "Bestehender HTTP-/WebSocket-Server startet für die Lobby")
	_check(_lobby.displayed_url() == url, "Lobby zeigt exakt die URL des Controllers")
	_check(_lobby.qr_texture() != null, "Lobby erzeugt einen QR-Code aus der Controller-URL")
	_check(not _lobby.is_start_enabled(), "SPIEL STARTEN ist ohne Smartphone gesperrt")
	_check(_lobby.status_text() == "Warte auf Smartphone", "Lobby wartet zunächst auf das Smartphone")
	if _lobby.qr_texture() != null:
		var qr_image := _lobby.qr_texture().get_image()
		_check(qr_image.get_width() == 330 and qr_image.get_height() == 330, "QR-Code besitzt eine scharf skalierte Modulmatrix mit Ruhezone")
		_check(qr_image.get_pixel(0, 0).is_equal_approx(Color.WHITE), "QR-Code besitzt eine weiße Ruhezone")
		qr_image.save_png(OS.get_temp_dir().path_join("ashenborn-qr-test.png"))

	var socket := WebSocketPeer.new()
	var connect_error := socket.connect_to_url("ws://127.0.0.1:18776")
	_check(connect_error == OK, "Smartphone-WebSocket kann die Verbindung beginnen")
	for _frame in 240:
		socket.poll()
		if _server.is_smartphone_connected():
			break
		await process_frame
	_check(_server.is_smartphone_connected(), "Server erkennt den geöffneten Smartphone-WebSocket")
	_check(_lobby.status_text() == "Smartphone verbunden", "Lobby zeigt den verbundenen Status")
	_check(_lobby.is_start_enabled(), "SPIEL STARTEN wird nach dem Handshake freigeschaltet")

	socket.close(1000, "test complete")
	for _frame in 240:
		socket.poll()
		if not _server.is_smartphone_connected():
			break
		await process_frame
	_check(not _server.is_smartphone_connected(), "Lobby erkennt auch das Trennen des Smartphones")
	_check(not _lobby.is_start_enabled(), "SPIEL STARTEN wird nach dem Trennen wieder gesperrt")
	_lobby.configure("", true, false)
	_check(_lobby.qr_texture() == null and _lobby.displayed_url().contains("Keine geeignete lokale WLAN-Adresse"), "Fehlende Netzwerkadresse wird verständlich erklärt")
	_lobby.configure(url, false, true)
	_check(_lobby.qr_texture() == null and _lobby.displayed_url().contains("Verbindungsserver konnte nicht gestartet"), "Serverstartfehler wird verständlich erklärt")
	_server.stop()
	_lobby.free()
	game.free()
	if _failures.is_empty():
		print("PASS: QR-Lobby, URL, Verbindungsstatus und Startfreigabe")
		quit(0)
	else:
		for failure in _failures:
			printerr("FAIL: " + failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
