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
	_game.state_changed.connect(_view.set_state)
	_view.card_selected.connect(func(index: int) -> void: _game.select_card(index, "pc"))
	_view.combat_sequence_started.connect(func(card_name: String, boss_damage: int, player_damage: int) -> void: _events.append([card_name, boss_damage, player_damage]))

	_game.start_game(13)
	_game.force_hand_for_tests(["ash_mage", "root_beast", "sun_champion"])
	var cards: Array = _view.get("_cards")
	_view.call("_on_card_pressed", cards[0])
	_view.call("_on_card_pressed", cards[1])
	_check(_game.boss_hp == 27 and _game.player_hp == 18, "Schneller Doppelklick verursacht nur einen bestätigten Angriff")
	_check(_events.size() == 1 and _events[0] == ["Aschehexer", 3, 2], "Feedbacksequenz verwendet exakt 3 Boss- und 2 Spielerschaden")
	await create_timer(0.72).timeout
	_check(_view.get("_displayed_boss_hp") == 27, "Boss-Lebensanzeige erreicht nach dem Treffer den autoritativen Wert")
	_check(String(_view.get("_result_label").text).contains("MORVATH SCHLÄGT ZURÜCK"), "Morvaths Gegenangriff wird sichtbar angekündigt")
	await create_timer(0.48).timeout
	_check(_view.get("_displayed_player_hp") == 18, "Spieler-Lebensanzeige erreicht nach dem Gegenangriff den autoritativen Wert")

	_game.finish_resolution_for_tests()
	await create_timer(0.45).timeout
	_check(_game.round_number == 2 and String(_view.get("_result_label").text) == "WÄHLE DEINE KREATUR", "Rundenübergang endet wieder in einer spielbaren Auswahl")

	_game.start_game(21)
	_game.force_hand_for_tests(["ash_mage", "root_beast", "sun_champion"])
	_game.set_health_for_tests(3, 20)
	_view.call("_on_card_pressed", cards[0])
	await create_timer(0.72).timeout
	_check(_game.phase == "victory" and _view.get("_end_panel").visible, "Sieg erscheint nach dem sichtbaren Kreaturentreffer")

	_game.start_game(22)
	_game.force_hand_for_tests(["ash_mage", "root_beast", "sun_champion"])
	_game.set_health_for_tests(30, 2)
	_view.call("_on_card_pressed", cards[0])
	await create_timer(1.25).timeout
	_check(_game.phase == "defeat" and _view.get("_end_panel").visible, "Niederlage erscheint nach Morvaths sichtbarem Gegenangriff")

	_view.free()
	_game.free()
	if _failures.is_empty():
		print("PASS: Kreaturenangriff, Treffer, Gegenangriff, Schadensanzeigen und Rundenübergang")
		quit(0)
	else:
		for failure in _failures:
			printerr("FAIL: " + failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
