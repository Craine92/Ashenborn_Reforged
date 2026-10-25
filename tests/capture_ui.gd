extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var screenshot_dir: String = ProjectSettings.globalize_path("res://docs/screenshots")
	DirAccess.make_dir_recursive_absolute(screenshot_dir)
	var packed: PackedScene = load("res://scenes/main.tscn")
	var main: Node = packed.instantiate()
	root.add_child(main)
	for _frame in 10:
		await process_frame
	var server: WebControllerServer = main.get("_server")
	if "--controller-preview" in OS.get_cmdline_user_args():
		server.stop()
		server.start(18875, 18876)
	root.get_texture().get_image().save_png(OS.get_temp_dir().path_join("ashenborn-menu.png"))
	main.call("_show_lobby")
	for _frame in 10:
		await process_frame
	root.get_texture().get_image().save_png(OS.get_temp_dir().path_join("ashenborn-lobby.png"))
	main.call("_start_battle", false)
	var battle: BattleView = main.get("_battle")
	var game: GameState = main.get("_game")
	battle.set_connection_info("http://192.168.1.50:8765", true)
	battle.set_smartphone_connected(true)
	game.start_game(77, ["player_1", "player_2"])
	if "--controller-preview" in OS.get_cmdline_user_args():
		server.end_match()
	for _frame in 10:
		await process_frame
	if "--controller-preview" in OS.get_cmdline_user_args():
		await create_timer(30.0).timeout
	root.get_texture().get_image().save_png(OS.get_temp_dir().path_join("ashenborn-battle.png"))
	root.get_texture().get_image().save_png(screenshot_dir.path_join("alpha_02a_coop_arena.png"))
	game.select_upgrade("player_1", 0, "capture")
	game.select_upgrade("player_2", 0, "capture")
	for _frame in 90:
		if battle.get("_attacker_card").modulate.a >= 0.95:
			break
		await process_frame
	root.get_texture().get_image().save_png(OS.get_temp_dir().path_join("ashenborn-attack-intro.png"))
	root.get_texture().get_image().save_png(screenshot_dir.path_join("alpha_02a_coop_attack.png"))
	for _frame in 90:
		if battle.get("_boss_damage_label").modulate.a >= 0.5:
			break
		await process_frame
	root.get_texture().get_image().save_png(OS.get_temp_dir().path_join("ashenborn-hit.png"))
	for _frame in 120:
		if battle.get("_player_damage_label").modulate.a >= 0.5:
			break
		await process_frame
	root.get_texture().get_image().save_png(OS.get_temp_dir().path_join("ashenborn-counterattack.png"))
	main.call("_show_lobby")
	await process_frame
	main.call("_start_battle", true)
	for _frame in 10:
		await process_frame
	root.get_texture().get_image().save_png(OS.get_temp_dir().path_join("ashenborn-pc-test.png"))
	server.stop()
	main.queue_free()
	await process_frame
	quit(0)
