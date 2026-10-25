extends SceneTree

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := GameState.new()
	root.add_child(game)
	var view := BattleView.new()
	root.add_child(view)
	view.set_pc_test_mode(false)
	game.state_changed.connect(func(_snapshot: Dictionary) -> void: view.set_state(game.get_public_snapshot(false)))
	view.combat_sequence_finished.connect(game.confirm_visual_resolution)
	var animation_events: Array[String] = []
	var animator: BossAnimator = view.get("_boss_animator")
	animator.animation_started.connect(func(animation_name: String) -> void: animation_events.append(animation_name))
	game.start_game(301, ["player_1", "player_2"])
	game.force_boss_intent_for_tests("soul_lance", "player_1")
	game.force_hand_for_tests(["ash_blade", "life_steal", "bone_guard"], "player_1")
	game.force_hand_for_tests(["rune_bolt", "blood_frenzy", "soul_fire"], "player_2")
	game.select_upgrade("player_1", 0, "test")
	game.select_upgrade("player_2", 0, "test")
	var authoritative_boss_hp := game.boss_hp
	var authoritative_one_hp := int(game.players["player_1"]["hp"])
	var authoritative_two_hp := int(game.players["player_2"]["hp"])
	_check(authoritative_boss_hp == 111 and authoritative_one_hp == 12 and authoritative_two_hp == 16, "Autoritativer Koop-Schaden und angekündigtes Einzelziel werden vor der Darstellung exakt einmal berechnet")
	await create_timer(3.8).timeout
	_check(game.phase == "resolving" and game.round_number == 1, "Runde bleibt bis nach der vollständigen Kampfanimation unverändert")
	_check(game.boss_hp == authoritative_boss_hp and int(game.players["player_1"]["hp"]) == authoritative_one_hp and int(game.players["player_2"]["hp"]) == authoritative_two_hp, "Frame-Animationen verändern keinerlei Kampfwerte")
	await view.combat_sequence_finished
	_check(_ordered(animation_events, ["hit_reaction", "hit_reaction", "energy_charge", "spell_blast"]), "Zwei Trefferreaktionen folgen auf zwei Heldenangriffe, danach Aufladung und Bosszauber")
	await process_frame
	_check(game.phase == "awaiting_selection" and game.round_number == 2, "Neue Runde beginnt erst nach dem begrenzten Auflösungsfenster")
	view.free()
	game.free()
	if _failures.is_empty():
		print("PASS: Koop-Animationsreihenfolge, Rundenbarriere und unveränderte Kampfwerte")
		quit(0)
	else:
		for failure in _failures:
			printerr("FAIL: " + failure)
		quit(1)


func _ordered(events: Array[String], expected: Array[String]) -> bool:
	var cursor := 0
	for event in events:
		if cursor < expected.size() and event == expected[cursor]:
			cursor += 1
	return cursor == expected.size()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
