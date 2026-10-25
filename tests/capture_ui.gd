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
	root.get_texture().get_image().save_png(OS.get_temp_dir().path_join("ashenborn-menu.png"))
	main.call("_show_lobby")
	for _frame in 10:
		await process_frame
	root.get_texture().get_image().save_png(OS.get_temp_dir().path_join("ashenborn-lobby.png"))
	main.call("_start_battle", false)
	for _frame in 10:
		await process_frame
	root.get_texture().get_image().save_png(OS.get_temp_dir().path_join("ashenborn-battle.png"))
	root.get_texture().get_image().save_png(screenshot_dir.path_join("alpha_015_tv_arena.png"))
	var battle: BattleView = main.get("_battle")
	var game: GameState = main.get("_game")
	game.select_upgrade(0, "capture")
	for _frame in 90:
		if battle.get("_attacker_card").modulate.a >= 0.95:
			break
		await process_frame
	root.get_texture().get_image().save_png(OS.get_temp_dir().path_join("ashenborn-attack-intro.png"))
	root.get_texture().get_image().save_png(screenshot_dir.path_join("alpha_015_hero_attack.png"))
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
	root.get_texture().get_image().save_png(screenshot_dir.path_join("alpha_015_pc_test.png"))
	if "--controller-preview" in OS.get_cmdline_user_args():
		await create_timer(30.0).timeout
	var server: WebControllerServer = main.get("_server")
	server.stop()
	main.queue_free()
	await process_frame
	quit(0)
