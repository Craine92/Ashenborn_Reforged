extends SceneTree

const TacticDatabase = preload("res://scripts/tactic_database.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_phase_transition_and_values()
	_test_defensive_stance_and_blood_shield()
	_test_ritual_breaker_once_for_group()
	_test_storm_strike_risk_and_expiry()
	_test_offer_rules_and_privacy()
	await _test_tv_phase_and_tactic_feedback()
	if _failures.is_empty():
		print("PASS: Bossphasen, Taktikkarten, temporäre Effekte, Datenschutz und Doppeltipp-Schutz")
		quit(0)
	else:
		for failure in _failures:
			printerr("FAIL: " + failure)
		quit(1)


func _test_phase_transition_and_values() -> void:
	var game := _game(501, ["player_1"])
	game.set_health_for_tests(34, 20)
	game.force_boss_intent_for_tests("soul_lance", "player_1")
	game.force_hand_for_tests(["ash_blade", "life_steal", "bone_guard"])
	game.select_upgrade(0)
	_check(game.boss_phase == 1 and game.combat_result["boss_intent"]["damage"] == 4, "50-%-Schwelle verändert einen bereits angekündigten Phase-1-Angriff nicht")
	_check(game.players["player_1"]["hp"] == 12, "Der laufende Phase-1-Angriff behält exakt 4 Schaden")
	game.finish_resolution_for_tests()
	_check(game.boss_phase == 2 and game.boss_phase_transition.get("to", 0) == 2, "Phase 2 aktiviert sich zu Beginn der nächsten Runde")
	_check(game.boss_intent.get("boss_phase", 0) == 2, "Der neue Runden-Intent wird bereits mit Phase-2-Werten angekündigt")
	game.force_boss_intent_for_tests("skull_storm")
	_check(game.boss_intent["damage"] == 3, "Phase-2-Schädelsturm ist zentral auf 3 Schaden konfiguriert")
	game.force_boss_intent_for_tests("soul_lance", "player_1")
	_check(game.boss_intent["damage"] == 6, "Phase-2-Seelenlanze ist zentral auf 6 Schaden konfiguriert")
	game.force_boss_intent_for_tests("dark_ritual")
	_check(game.boss_intent["damage"] == 2 and game.boss_intent["healing"] == 4, "Phase-2-Ritual kündigt 2 Schaden und bis zu 4 Heilung an")
	game.free()


func _test_tv_phase_and_tactic_feedback() -> void:
	var game := _game(506, ["player_1"])
	var view := BattleView.new()
	root.add_child(view)
	view.set_pc_test_mode(false)
	var animation_events: Array[String] = []
	var animator: BossAnimator = view.get("_boss_animator")
	animator.animation_started.connect(func(animation_name: String) -> void: animation_events.append(animation_name))
	view.set_state(game.get_public_snapshot(false))
	game.set_health_for_tests(34, 16)
	game.force_boss_intent_for_tests("soul_lance", "player_1")
	game.force_hand_for_tests(["ash_blade", "life_steal", "bone_guard"])
	game.select_upgrade(0)
	game.finish_resolution_for_tests()
	view.set_state(game.get_public_snapshot(false))
	await process_frame
	_check(view.get("_phase_overlay").visible, "TV blendet das vorhandene Phase-2-Overlay ein")
	_check(String(view.get("_boss_phase_label").text).contains("PHASE 2"), "TV kennzeichnet Zorn der Asche dauerhaft als Phase 2")
	_check(String(view.get("_result_label").text).contains("MORVATH ERWACHT"), "TV meldet den Phasenwechsel deutlich")
	_check(animation_events.has("energy_charge"), "Phasenwechsel verwendet Morvaths vorhandene Energie-Animation")
	view.free()
	game.free()

	game = _game(507, ["player_1"])
	view = BattleView.new()
	root.add_child(view)
	view.set_pc_test_mode(false)
	view.set_state(game.get_public_snapshot(false))
	game.force_boss_intent_for_tests("skull_storm")
	game.force_hand_for_tests(["defensive_stance", "ash_blade", "rune_bolt"])
	game.select_upgrade(0)
	view.set_state(game.get_public_snapshot(false))
	await process_frame
	_check(String(view.get("_attacker_name").text).contains("ABWEHRHALTUNG"), "Ausgespielte Taktik wird in der TV-Kampfauflösung benannt")
	view.free()
	game.free()


func _test_defensive_stance_and_blood_shield() -> void:
	var game := _game(502, ["player_1"])
	game.set_boss_phase_for_tests(2)
	game.set_ability_rank_for_tests("life_steal", 1)
	game.set_ability_rank_for_tests("bone_guard", 2)
	game.set_counters_for_tests(0, 1)
	game.set_health_for_tests(60, 10)
	game.force_boss_intent_for_tests("soul_lance", "player_1")
	game.force_hand_for_tests(["defensive_stance", "ash_blade", "rune_bolt"])
	_check(game.select_upgrade(0), "Abwehrhaltung wird mit einem Tipp verbindlich gewählt")
	_check(not game.select_upgrade(1), "Doppeltipp löst keine zweite Karte aus")
	var target: Dictionary = game.combat_result["boss_targets"][0]
	_check(target["base_damage"] == 6 and target["stance_blocked"] == 3 and target["bone_blocked"] == 2 and target["boss_damage"] == 1, "Abwehrhaltung und Knochenschutz reduzieren Phase-2-Schaden additiv ohne negative Werte")
	_check(target["synergy_healing"] == 1, "Blutschild reagiert nur auf den tatsächlichen Knochenschutz-Anteil")
	_check(game.players["player_1"]["ability_ranks"].get("defensive_stance", 0) == 0, "Taktikkarte erhöht keinen permanenten Rang")
	game.free()


func _test_ritual_breaker_once_for_group() -> void:
	var game := _game(503, ["player_1", "player_2"])
	game.set_boss_phase_for_tests(2)
	game.set_health_for_tests(100, 20, "player_1")
	game.force_boss_intent_for_tests("dark_ritual")
	game.force_hand_for_tests(["ritual_breaker", "ash_blade", "life_steal"], "player_1")
	game.force_hand_for_tests(["ritual_breaker", "bone_guard", "rune_bolt"], "player_2")
	game.select_upgrade("player_1", 0)
	game.select_upgrade("player_2", 0)
	_check(game.combat_result["ritual_interrupted"] and game.combat_result["boss_healing"] == 0, "Ein oder mehrere Ritualbrecher verhindern die Heilung genau einmal")
	_check(game.boss_hp == 92, "Ritualbrecher verändert weder beide Heldenangriffe noch erzeugt er Zusatzschaden")
	_check(game.players["player_1"]["hp"] == 14 and game.players["player_2"]["hp"] == 14, "Der normale Phase-2-Ritualschaden bleibt trotz Unterbrechung erhalten")
	game.free()


func _test_storm_strike_risk_and_expiry() -> void:
	var game := _game(504, ["player_1"])
	game.set_boss_phase_for_tests(2)
	game.force_boss_intent_for_tests("soul_lance", "player_1")
	game.force_hand_for_tests(["storm_strike", "life_steal", "bone_guard"])
	game.select_upgrade(0)
	_check(game.combat_result["hero_damage"] == 8 and game.combat_result["tactic_damage"] == 4, "Sturmstoß gewährt einmalig exakt +4 Heldenschaden")
	_check(game.combat_result["boss_targets"][0]["risk_damage"] == 2 and game.combat_result["boss_damage"] == 8, "Sturmstoß-Risiko erhöht nur den auf diesen Helden gerichteten Angriff um 2")
	game.finish_resolution_for_tests()
	game.force_boss_intent_for_tests("soul_lance", "player_1")
	game.force_hand_for_tests(["life_steal", "bone_guard", "ash_blade"])
	game.select_upgrade(0)
	_check(game.combat_result["tactic_damage"] == 0 and game.combat_result["boss_targets"][0]["risk_damage"] == 0, "Sturmstoß-Bonus und Risiko sind in der nächsten Runde vollständig entfernt")
	game.free()


func _test_offer_rules_and_privacy() -> void:
	var game := _game(505, ["player_1", "player_2"])
	game.set_round_for_tests(3)
	game.force_boss_intent_for_tests("soul_lance", "player_2")
	var untargeted_eligible := TacticDatabase.eligible_tactics(game.boss_intent, "player_1")
	var targeted_eligible := TacticDatabase.eligible_tactics(game.boss_intent, "player_2")
	_check(not _ids(untargeted_eligible).has("defensive_stance") and _ids(targeted_eligible).has("defensive_stance"), "Abwehrhaltung ist nur für tatsächlich angegriffene Helden zulässig")
	game.force_boss_intent_for_tests("dark_ritual")
	_check(_ids(TacticDatabase.eligible_tactics(game.boss_intent, "player_1")).has("ritual_breaker"), "Ritualbrecher ist nur beim angekündigten Ritual sinnvoll verfügbar")
	var saw_tactic := false
	for _draw in 80:
		var offers: Array = game.call("_draw_hand_for_player", "player_1", game.players["player_1"])
		var tactic_count := 0
		var ids := {}
		for offer: Dictionary in offers:
			ids[offer["id"]] = true
			if offer.get("card_kind", "upgrade") == "tactic":
				tactic_count += 1
				saw_tactic = true
		_check(tactic_count <= 1 and ids.size() == offers.size(), "Angebot enthält höchstens eine Taktik und keine doppelten Karten")
		_check(tactic_count == 0 or offers.size() >= 3, "Taktik verdrängt nicht die zwei regulären Upgrade-Plätze")
	_check(saw_tactic, "Situative Taktiken erscheinen ab Runde 3 gelegentlich, aber nicht garantiert")
	game.force_hand_for_tests(["ritual_breaker", "ash_blade", "life_steal"], "player_1")
	var private_state := game.get_private_snapshot("player_1")
	var public_state := game.get_public_snapshot()
	_check(private_state["hand"][0]["kind_label"] == "NUR DIESE RUNDE" and public_state["hand"].is_empty(), "Taktikart ist privat klar markiert und bleibt aus dem öffentlichen Zustand entfernt")
	_check(private_state["player"]["hero"].get("abilities", []).is_empty(), "Taktikkarten werden nicht im permanenten Build gespeichert")
	game.free()


func _ids(definitions: Array) -> Array[String]:
	var result: Array[String] = []
	for definition: Dictionary in definitions:
		result.append(definition["id"])
	return result


func _game(seed_value: int, player_ids: Array) -> GameState:
	var game := GameState.new()
	root.add_child(game)
	game.resolution_delay = 99.0
	game.start_game(seed_value, player_ids)
	return game


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
