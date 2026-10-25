extends SceneTree

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_intents()
	_test_rune_blade()
	_test_blood_shield()
	_test_discovery_and_privacy()
	if _failures.is_empty():
		print("PASS: Boss-Intents, faire Zielwahl, Runenklinge, Blutschild und Entdeckungen")
		quit(0)
	else:
		for failure in _failures:
			printerr("FAIL: " + failure)
		quit(1)


func _test_intents() -> void:
	var game := _game(401, ["player_1", "player_2"])
	game.force_boss_intent_for_tests("skull_storm")
	_resolve_two(game)
	_check(game.players["player_1"]["hp"] == 18 and game.players["player_2"]["hp"] == 18, "Schädelsturm trifft alle Lebenden genau einmal für 2")
	_check(game.combat_result["boss_intent"]["animation"] == "skull_swarm", "Schädelsturm fordert die richtige Animation an")
	game.free()

	game = _game(402, ["player_1", "player_2"])
	game.force_boss_intent_for_tests("soul_lance", "player_2")
	_resolve_two(game)
	_check(game.players["player_1"]["hp"] == 20 and game.players["player_2"]["hp"] == 16, "Seelenlanze trifft nur das vorher angekündigte Ziel für 4")
	_check(game.combat_result["boss_targets"].size() == 1, "Seelenlanze erzeugt kein überraschendes Zusatzziel")
	game.free()

	game = _game(410, ["player_1", "player_2"])
	var announced_targets: Array[String] = []
	for test_round in range(1, 7):
		game.set_round_for_tests(test_round)
		if game.boss_intent.get("id", "") == "soul_lance":
			announced_targets.append(game.boss_intent.get("target_player_id", ""))
	_check(announced_targets.size() == 2 and announced_targets[0] != announced_targets[1], "Seelenlanze wechselt ihr angekündigtes Ziel fair und deterministisch")
	game.free()

	game = _game(411, ["player_1", "player_2"])
	game.force_boss_intent_for_tests("soul_lance", "player_2")
	var announced := game.boss_intent.duplicate(true)
	game.force_hand_for_tests(["life_steal", "bone_guard", "blood_frenzy"], "player_1")
	game.set_player_connected("player_2", false)
	game.select_upgrade("player_1", 0)
	_check(game.combat_result["boss_intent"] == announced and game.players["player_2"]["hp"] == 16, "Verbindungsabbruch ändert weder angekündigte Aktion noch lebendes Ziel")
	game.free()

	game = _game(403, ["player_1", "player_2"])
	game.set_health_for_tests(100, 20, "player_1")
	game.force_boss_intent_for_tests("dark_ritual")
	_resolve_two(game)
	_check(game.boss_hp == 95, "Dunkles Ritual heilt nach 8 Heldenschaden exakt 3 LP")
	_check(game.players["player_1"]["hp"] == 19 and game.players["player_2"]["hp"] == 19, "Dunkles Ritual trifft alle Lebenden für 1")
	_check(game.combat_result["boss_healing"] == 3, "Ritualheilung wird autoritativ dokumentiert")
	game.free()

	game = _game(412, ["player_1"])
	game.force_boss_intent_for_tests("dark_ritual")
	game.force_hand_for_tests(["life_steal", "bone_guard", "blood_frenzy"])
	game.select_upgrade(0)
	_check(game.boss_hp == game.boss_max_hp - 1, "Dunkles Ritual überschreitet auch nahe am Maximum niemals Morvaths Start-LP")
	game.free()

	game = _game(404, ["player_1"])
	game.set_health_for_tests(4, 20)
	game.force_boss_intent_for_tests("dark_ritual")
	game.force_hand_for_tests(["life_steal", "bone_guard", "rune_bolt"])
	game.select_upgrade(0)
	_check(game.phase == "victory" and game.boss_hp == 0 and game.combat_result["boss_healing"] == 0, "Ein besiegter Boss führt das Ritual nicht mehr aus")
	game.free()


func _test_rune_blade() -> void:
	var game := _game(405, ["player_1"])
	game.set_ability_rank_for_tests("ash_blade", 1)
	game.set_ability_rank_for_tests("rune_bolt", 1)
	game.set_round_for_tests(3)
	game.force_boss_intent_for_tests("skull_storm")
	game.force_hand_for_tests(["life_steal", "bone_guard", "blood_frenzy"])
	game.select_upgrade(0)
	var attack: Dictionary = game.combat_result["attacks"][0]
	_check(attack["hero_damage"] == 9 and attack["synergy_damage"] == 2, "Runenklinge addiert beim Runenblitz genau einmal +2 Schaden")
	_check(attack["triggered_effects"].count("RUNENKLINGE +2 SCHADEN") == 1, "Runenklinge wird genau einmal als Auslöser gemeldet")
	game.free()

	game = _game(406, ["player_1"])
	game.set_ability_rank_for_tests("ash_blade", 1)
	game.set_ability_rank_for_tests("rune_bolt", 1)
	game.set_round_for_tests(2)
	game.force_boss_intent_for_tests("skull_storm")
	game.force_hand_for_tests(["life_steal", "bone_guard", "blood_frenzy"])
	game.select_upgrade(0)
	_check(game.combat_result["synergy_damage"] == 0, "Runenklinge verursacht ohne Runenblitz keinen passiven Zusatzschaden")
	game.free()

	game = _game(413, ["player_1"])
	game.set_ability_rank_for_tests("rune_bolt", 1)
	game.set_round_for_tests(3)
	game.force_boss_intent_for_tests("skull_storm")
	game.force_hand_for_tests(["life_steal", "bone_guard", "blood_frenzy"])
	game.select_upgrade(0)
	_check(game.combat_result["rune_damage"] == 2 and game.combat_result["synergy_damage"] == 0, "Runenklinge bleibt ohne Aschenklinge trotz Runenblitz inaktiv")
	game.free()


func _test_blood_shield() -> void:
	var game := _game(407, ["player_1"])
	game.set_ability_rank_for_tests("life_steal", 1)
	game.set_ability_rank_for_tests("bone_guard", 1)
	game.set_counters_for_tests(0, 1)
	game.set_health_for_tests(60, 10)
	game.force_boss_intent_for_tests("soul_lance", "player_1")
	game.force_hand_for_tests(["ash_blade", "rune_bolt", "blood_frenzy"])
	game.select_upgrade(0)
	var target: Dictionary = game.combat_result["boss_targets"][0]
	_check(target["blocked"] == 1 and target["boss_damage"] == 3 and target["synergy_healing"] == 1, "Blutschild heilt genau 1 LP, wenn Knochenschutz wirklich reduziert")
	_check(game.players["player_1"]["hp"] == 9, "Lebensraub und Blutschild werden getrennt, nach Schaden und mit Max-LP-Grenze verrechnet")
	game.free()

	game = _game(408, ["player_1"])
	game.set_ability_rank_for_tests("life_steal", 1)
	game.set_ability_rank_for_tests("bone_guard", 1)
	game.set_counters_for_tests(0, 0)
	game.set_health_for_tests(60, 10)
	game.force_boss_intent_for_tests("soul_lance", "player_1")
	game.force_hand_for_tests(["ash_blade", "rune_bolt", "blood_frenzy"])
	game.select_upgrade(0)
	_check(game.combat_result["boss_targets"][0]["synergy_healing"] == 0, "Blutschild heilt ohne Block nicht")
	game.free()


func _test_discovery_and_privacy() -> void:
	var game := _game(409, ["player_1"])
	game.set_ability_rank_for_tests("ash_blade", 1)
	game.force_hand_for_tests(["rune_bolt", "life_steal", "bone_guard"])
	game.force_boss_intent_for_tests("skull_storm")
	game.select_upgrade(0)
	var attack: Dictionary = game.combat_result["attacks"][0]
	_check(attack["new_synergies"].size() == 1 and attack["new_synergies"][0]["id"] == "rune_blade", "Eine neu vervollständigte Synergie wird einmal entdeckt")
	var hero_state: Dictionary = game.get_private_snapshot("player_1")["player"]["hero"]
	_check(hero_state["synergies"].size() == 1 and hero_state["synergies"][0].has("requirements_text"), "Buildzustand enthält aktive Synergie mit Voraussetzung und Effekt")
	_check(game.get_public_snapshot()["hand"].is_empty(), "Öffentlicher Intent- und Buildzustand gibt keine private Hand preis")
	game.free()

	game = _game(414, ["player_1", "player_2"])
	game.set_ability_rank_for_tests("ash_blade", 1, "player_1")
	game.set_ability_rank_for_tests("rune_bolt", 1, "player_1")
	game.set_ability_rank_for_tests("life_steal", 1, "player_2")
	game.set_ability_rank_for_tests("bone_guard", 1, "player_2")
	var one_synergies: Array = game.get_private_snapshot("player_1")["player"]["hero"]["synergies"]
	var two_synergies: Array = game.get_private_snapshot("player_2")["player"]["hero"]["synergies"]
	_check(one_synergies[0]["id"] == "rune_blade" and two_synergies[0]["id"] == "blood_shield", "Zwei Spieler besitzen unabhängig unterschiedliche Synergien")
	game.free()


func _resolve_two(game: GameState) -> void:
	game.force_hand_for_tests(["life_steal", "bone_guard", "blood_frenzy"], "player_1")
	game.force_hand_for_tests(["life_steal", "bone_guard", "blood_frenzy"], "player_2")
	game.select_upgrade("player_1", 0)
	game.select_upgrade("player_2", 0)


func _game(seed_value: int, player_ids: Array) -> GameState:
	var game := GameState.new()
	root.add_child(game)
	game.resolution_delay = 99.0
	game.start_game(seed_value, player_ids)
	return game


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
