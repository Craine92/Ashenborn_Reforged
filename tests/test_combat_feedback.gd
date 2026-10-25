extends SceneTree

var _failures: Array[String] = []
var _game: GameState
var _view: BattleView
var _events: Array = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_game = GameState.new()
	root.add_child(_game)
	_game.resolution_delay = 99.0
	_view = BattleView.new()
	root.add_child(_view)
	_view.set_pc_test_mode(true)
	_game.state_changed.connect(_view.set_state)
	_view.card_selected.connect(func(index: int) -> void: _game.select_upgrade(index, "pc"))
	_view.combat_sequence_started.connect(func(upgrade_name: String, boss_damage: int, player_damage: int) -> void: _events.append([upgrade_name, boss_damage, player_damage]))

	_game.start_game(13)
	_game.force_hand_for_tests(["ash_blade", "life_steal", "bone_guard"])
	var cards: Array = _view.get("_cards")
	_view.call("_on_card_pressed", cards[0])
	_view.call("_on_card_pressed", cards[1])
	_check(_game.boss_hp == 55 and _game.player_hp == 18, "Schneller Doppelklick verursacht nur einen bestätigten Heldenangriff")
	_check(_events.size() == 1 and _events[0] == ["Aschenklinge", 5, 2], "Feedback übernimmt exakt 5 Helden- und 2 Bossschaden")
	_check(String(_view.get("_abilities_label").text).contains("Aschenklinge R1"), "TV zeigt die aktive Fähigkeit mit Rang")
	await create_timer(0.82).timeout
	_check(_view.get("_displayed_boss_hp") == 55, "Boss-Lebensanzeige erreicht den autoritativen Wert")
	_check(String(_view.get("_result_label").text).contains("MORVATH SCHLÄGT ZURÜCK"), "Morvaths Gegenangriff wird sichtbar angekündigt")
	await create_timer(0.40).timeout
	_check(_view.get("_displayed_player_hp") == 18, "Helden-Lebensanzeige erreicht den autoritativen Wert")

	_game.finish_resolution_for_tests()
	await create_timer(0.45).timeout
	_check(_game.round_number == 2 and String(_view.get("_result_label").text) == "WÄHLE EIN UPGRADE", "Rundenübergang endet in der nächsten Upgrade-Auswahl")

	_game.start_game(21)
	_game.set_ability_rank_for_tests("life_steal", 1)
	_game.set_health_for_tests(60, 10)
	_game.force_hand_for_tests(["life_steal", "ash_blade", "bone_guard"])
	_view.call("_on_card_pressed", cards[0])
	await create_timer(0.72).timeout
	_check(_view.get("_hero_heal_label").text == "+2", "Lebensraub wird als sichtbare Heilung dargestellt")

	_game.start_game(22)
	_game.set_ability_rank_for_tests("bone_guard", 2)
	_game.set_counters_for_tests(0, 1)
	_game.force_hand_for_tests(["ash_blade", "life_steal", "rune_bolt"])
	_view.call("_on_card_pressed", cards[0])
	await create_timer(0.90).timeout
	_check(String(_view.get("_block_label").text).contains("SCHUTZ"), "Knochenschutz wird beim Bossangriff sichtbar dargestellt")

	_game.start_game(23)
	_game.set_health_for_tests(5, 20)
	_game.force_hand_for_tests(["ash_blade", "life_steal", "bone_guard"])
	_view.call("_on_card_pressed", cards[0])
	await create_timer(0.72).timeout
	_check(_game.phase == "victory" and _view.get("_end_panel").visible, "Sieg erscheint nach dem sichtbaren Heldenangriff")

	_game.start_game(24)
	_game.set_health_for_tests(60, 2)
	_game.force_hand_for_tests(["ash_blade", "rune_bolt", "blood_frenzy"])
	_view.call("_on_card_pressed", cards[0])
	await create_timer(1.30).timeout
	_check(_game.phase == "defeat" and _view.get("_end_panel").visible, "Niederlage erscheint nach Morvaths sichtbarem Gegenangriff")

	_view.free()
	_game.free()
	if _failures.is_empty():
		print("PASS: Upgrade, Heldenangriff, Heilung, Schutz, Gegenangriff und Rundenübergang")
		quit(0)
	else:
		for failure in _failures:
			printerr("FAIL: " + failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
