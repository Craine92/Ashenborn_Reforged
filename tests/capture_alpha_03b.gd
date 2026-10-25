extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var screenshot_dir := ProjectSettings.globalize_path("res://docs/screenshots")
	DirAccess.make_dir_recursive_absolute(screenshot_dir)

	var game := GameState.new()
	root.add_child(game)
	game.resolution_delay = 99.0
	var view := BattleView.new()
	root.add_child(view)
	view.set_pc_test_mode(false)
	view.set_connection_info("http://192.168.1.50:18875", true)
	view.set_smartphone_connected(true)
	game.state_changed.connect(func(_snapshot: Dictionary) -> void: view.set_state(game.get_public_snapshot(false)))

	game.start_game(603, ["player_1", "player_2"])
	game.set_round_for_tests(6)
	game.set_boss_phase_for_tests(2)
	game.force_boss_intent_for_tests("dark_ritual")
	for _frame in 20:
		await process_frame
	root.get_texture().get_image().save_png(screenshot_dir.path_join("alpha_03b_phase2_arena.png"))

	game.force_hand_for_tests(["ritual_breaker", "ash_blade", "life_steal"], "player_1")
	game.force_hand_for_tests(["storm_strike", "bone_guard", "rune_bolt"], "player_2")
	game.select_upgrade("player_1", 0, "capture")
	game.select_upgrade("player_2", 0, "capture")
	for _frame in 10:
		await process_frame
	root.get_texture().get_image().save_png(screenshot_dir.path_join("alpha_03b_tactic_resolution.png"))

	view.visible = false
	game.start_game(604, ["player_1"])
	game.set_round_for_tests(4)
	game.set_boss_phase_for_tests(2)
	game.force_boss_intent_for_tests("dark_ritual")
	game.force_hand_for_tests(["ritual_breaker", "ash_blade", "life_steal"])
	var server := WebControllerServer.new()
	root.add_child(server)
	server.public_state_provider = Callable(game, "get_public_snapshot")
	server.private_state_provider = Callable(game, "get_private_snapshot")
	server.player_selected.connect(func(player_id: String, index: int) -> void: game.select_upgrade(player_id, index, "web"))
	server.player_connection_changed.connect(game.set_player_connected)
	game.state_changed.connect(func(_snapshot: Dictionary) -> void: server.broadcast_state())
	if not server.start(18875, 18876):
		printerr("Screenshot-Server konnte nicht gestartet werden")
		quit(1)
		return
	server.broadcast_state()
	print("CAPTURE_READY http://127.0.0.1:18875/")
	await create_timer(25.0).timeout
	server.stop()
	view.free()
	game.free()
	quit(0)
