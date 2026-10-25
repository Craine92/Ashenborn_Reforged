extends SceneTree

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_waits_for_both_and_resolves_once()
	_test_personal_healing_and_defense()
	_test_disconnect_policy_and_reconnect_state()
	_test_group_outcomes_and_six_player_model()
	if _failures.is_empty():
		print("PASS: Koop-Spielzustände, Bereitschaft, Einzel-Builds, gemeinsamer Gegenschlag und Wiederverbindung")
		quit(0)
	else:
		for failure in _failures:
			printerr("FAIL: " + failure)
		quit(1)


func _test_waits_for_both_and_resolves_once() -> void:
	var game := _new_coop_game(201)
	game.force_hand_for_tests(["ash_blade", "life_steal", "bone_guard"], "player_1")
	game.force_hand_for_tests(["rune_bolt", "blood_frenzy", "soul_fire"], "player_2")
	var private_one := game.get_private_snapshot("player_1")
	var private_two := game.get_private_snapshot("player_2")
	_check(private_one["hand"][0]["id"] == "ash_blade" and private_two["hand"][0]["id"] == "rune_bolt", "Jeder Spieler erhält seine eigene private Hand")
	_check(game.get_public_snapshot()["hand"].is_empty() and not JSON.stringify(game.get_public_snapshot()).contains("artwork_url"), "Öffentlicher Zustand enthält keine privaten Angebote")
	_check(game.select_upgrade("player_1", 0, "web"), "Spieler 1 kann sein Upgrade vormerken")
	_check(game.phase == "awaiting_selection" and game.ready_count() == 1 and game.boss_hp == 120, "Erste Auswahl startet die Kampfrunde noch nicht")
	_check(game.players["player_1"]["ability_ranks"].is_empty(), "Vorgemerktes Upgrade wird vor gemeinsamer Bereitschaft nicht aktiviert")
	_check(not game.select_upgrade("player_1", 1, "web"), "Doppeltipp von Spieler 1 wird abgewiesen")
	_check(game.select_upgrade("player_2", 0, "web"), "Spieler 2 kann unabhängig wählen")
	_check(game.phase == "resolving" and game.boss_hp == 111, "Beide Helden greifen nach 2/2 Bereitschaft genau einmal an")
	_check(game.combat_result["attacks"].size() == 2 and game.combat_result["boss_attack_count"] == 1, "Zwei Heldenangriffe führen zu genau einem gemeinsamen Bossangriff")
	_check(game.players["player_1"]["hp"] == 18 and game.players["player_2"]["hp"] == 18, "Morvath trifft beide lebenden Helden einmal")
	_check(game.players["player_1"]["ability_ranks"].get("ash_blade", 0) == 1 and game.players["player_2"]["ability_ranks"].get("rune_bolt", 0) == 1, "Jeder Held erhält exakt sein eigenes Upgrade")
	game.free()


func _test_personal_healing_and_defense() -> void:
	var game := _new_coop_game(202)
	game.set_ability_rank_for_tests("life_steal", 1, "player_1")
	game.set_ability_rank_for_tests("bone_guard", 2, "player_2")
	game.set_counters_for_tests(0, 0, "player_1")
	game.set_counters_for_tests(0, 1, "player_2")
	game.set_health_for_tests(120, 10, "player_1")
	game.set_health_for_tests(120, 10, "player_2")
	game.force_hand_for_tests(["life_steal", "ash_blade", "rune_bolt"], "player_1")
	game.force_hand_for_tests(["ash_blade", "life_steal", "rune_bolt"], "player_2")
	game.select_upgrade("player_1", 0)
	game.select_upgrade("player_2", 0)
	var targets: Array = game.combat_result["boss_targets"]
	_check(game.players["player_1"]["hp"] == 10 and game.combat_result["attacks"][0]["healing"] == 2, "Lebensraub heilt nur Spieler 1 und wird danach korrekt verrechnet")
	_check(game.players["player_2"]["hp"] == 10 and targets[1]["blocked"] == 2 and targets[1]["boss_damage"] == 0, "Persönlicher Knochenschutz blockt nur für Spieler 2")
	_check(game.players["player_1"]["ability_ranks"] != game.players["player_2"]["ability_ranks"], "Unterschiedliche Builds bleiben getrennt")
	game.free()


func _test_disconnect_policy_and_reconnect_state() -> void:
	var game := _new_coop_game(203)
	game.force_hand_for_tests(["ash_blade", "life_steal", "bone_guard"], "player_1")
	game.force_hand_for_tests(["rune_bolt", "blood_frenzy", "soul_fire"], "player_2")
	game.select_upgrade("player_1", 0)
	game.set_player_connected("player_2", false)
	_check(game.phase == "resolving" and game.combat_result["attacks"].size() == 1, "Abbruch eines noch nicht bereiten Spielers blockiert die Runde nicht und wählt nichts für ihn")
	_check(game.players["player_2"]["ability_ranks"].is_empty(), "Für getrennten Spieler wird kein Upgrade erfunden")
	_check(game.players["player_2"]["hp"] == 18, "Gemeinsamer Bossangriff trifft den weiterhin aktiven getrennten Helden")
	game.finish_resolution_for_tests()
	var hand_before: Array = game.players["player_2"]["hand"].duplicate(true)
	game.set_player_connected("player_2", true)
	_check(game.players["player_2"]["connected"] and game.players["player_2"]["hp"] == 18, "Wiederverbundener Spieler erhält Identität und Lebenspunkte zurück")
	_check(game.players["player_2"]["hand"] == hand_before, "Wiederverbindung bewahrt die private Hand")
	game.free()


func _test_group_outcomes_and_six_player_model() -> void:
	var game := _new_coop_game(204)
	game.set_health_for_tests(4, 20, "player_1")
	game.force_hand_for_tests(["ash_blade", "life_steal", "bone_guard"], "player_1")
	game.force_hand_for_tests(["rune_bolt", "blood_frenzy", "soul_fire"], "player_2")
	game.select_upgrade("player_1", 0)
	game.select_upgrade("player_2", 0)
	_check(game.phase == "victory" and game.boss_hp == 0 and game.combat_result["boss_targets"].is_empty(), "Gruppe gewinnt sofort bei besiegtem Morvath ohne Gegenangriff")
	game.free()

	game = _new_coop_game(205)
	game.set_health_for_tests(120, 2, "player_1")
	game.set_health_for_tests(120, 2, "player_2")
	game.force_hand_for_tests(["ash_blade", "life_steal", "bone_guard"], "player_1")
	game.force_hand_for_tests(["rune_bolt", "blood_frenzy", "soul_fire"], "player_2")
	game.select_upgrade("player_1", 0)
	game.select_upgrade("player_2", 0)
	_check(game.phase == "defeat" and not game.players["player_1"]["alive"] and not game.players["player_2"]["alive"], "Gruppe verliert erst, wenn alle Helden gefallen sind")
	game.free()

	game = GameState.new()
	root.add_child(game)
	game.start_game(206, ["p1", "p2", "p3", "p4", "p5", "p6"])
	_check(game.active_player_ids.size() == 6 and game.boss_max_hp == 360, "Datenmodell skaliert auf sechs getrennte Spielerzustände")
	game.free()

	game = GameState.new()
	root.add_child(game)
	game.start_game(207, ["player_2"])
	_check(game.players["player_2"]["display_name"] == "Spieler 2" and game.boss_max_hp == 60, "Allein verbundener zweiter Controller behält seine stabile Identität im Solo-Kampf")
	game.free()


func _new_coop_game(seed_value: int) -> GameState:
	var game := GameState.new()
	root.add_child(game)
	game.resolution_delay = 99.0
	game.start_game(seed_value, ["player_1", "player_2"])
	return game


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
