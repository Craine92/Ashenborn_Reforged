extends SceneTree

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	_check(packed != null, "Hauptszene kann geladen werden")
	if packed == null:
		_finish()
		return
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var game: GameState = main.get("_game")
	var menu: MainMenu = main.get("_menu")
	var lobby: ConnectionLobby = main.get("_lobby")
	var battle: BattleView = main.get("_battle")
	var connection_overlay: ConnectionLobby = main.get("_connection_overlay")
	var server: WebControllerServer = main.get("_server")
	_check(game != null and menu != null and lobby != null and battle != null and connection_overlay != null, "Menü, Lobby, Kampfansicht und Spiellogik werden aufgebaut")
	if game == null or menu == null or lobby == null or battle == null or connection_overlay == null:
		if server:
			server.stop()
		main.queue_free()
		_finish()
		return
	_check(menu.visible and not battle.visible, "Spiel startet im Hauptmenü")
	main.call("_show_lobby")
	await process_frame
	_check(lobby.visible and not menu.visible and not battle.visible, "SPIELEN öffnet vor dem Kampf die Verbindungslobby")
	lobby.start_requested.emit()
	await process_frame
	_check(battle.visible and not battle.is_pc_test_mode(), "Smartphone-Start öffnet die öffentliche TV-Arena")
	_check(not battle.get("_hand_section").visible, "Private Handkarten bleiben in der normalen TV-Ansicht verborgen")
	main.call("_show_lobby")
	await process_frame
	lobby.solo_requested.emit()
	await process_frame
	_check(battle.is_pc_test_mode() and battle.get("_hand_section").visible, "PC-Testmodus zeigt die private Hand als markierte Testansicht")
	_check(battle.get("_test_mode_label").text.contains("PC-TESTANSICHT"), "Test-Hand ist ausdrücklich als PC-Testansicht gekennzeichnet")
	_check(battle.get("_connection_button").text.contains("PC-TEST") and not battle.get("_connection_button").text.contains("FEHLER"), "Offline-PC-Test wird nicht irreführend als Netzwerkfehler angezeigt")
	_check(not lobby.visible and battle.visible, "OHNE SMARTPHONE TESTEN startet den PC-Testmodus")
	_check(game.phase == "awaiting_selection" and game.hand.size() == 3 and game.hero["name"] == "Aschenritter", "Solo-Raid beginnt mit Held und drei Upgrades")
	battle.connection_menu_requested.emit()
	_check(connection_overlay.visible, "Verbindungsmenü ist während des Kampfes erreichbar")
	connection_overlay.close_requested.emit()
	_check(not connection_overlay.visible, "Verbindungsmenü lässt sich wieder schließen")
	game.resolution_delay = 0.0
	game.force_boss_intent_for_tests("skull_storm")
	game.force_hand_for_tests(["ash_blade", "life_steal", "bone_guard"])
	var cards: Array = battle.get("_cards")
	var feedback_events: Array = []
	battle.combat_sequence_started.connect(func(card_name: String, boss_damage: int, player_damage: int) -> void: feedback_events.append([card_name, boss_damage, player_damage]))
	battle.call("_on_card_pressed", cards[0])
	_check(game.boss_hp == 55 and game.player_hp == 14 and game.ability_ranks["ash_blade"] == 1, "Ein PC-Klick wertet auf und startet den autoritativen Heldenangriff")
	_check(feedback_events.size() == 1 and feedback_events[0] == ["Aschenklinge", 5, 2], "TV-Feedback übernimmt exakt die bestätigten Schadenswerte")
	if server:
		server.stop()
	main.free()
	for _frame in 3:
		await process_frame
	_finish()
func _finish() -> void:
	if _failures.is_empty():
		print("PASS: Hauptmenü, Lobby, PC-Testmodus, autoritativer Angriff und TV-Feedback")
		call_deferred("_quit_cleanly", 0)
	else:
		for failure in _failures:
			printerr("FAIL: " + failure)
		call_deferred("_quit_cleanly", 1)


func _quit_cleanly(exit_code: int) -> void:
	quit(exit_code)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
