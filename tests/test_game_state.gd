extends SceneTree

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_card_pool()
	_test_rarity_weights()
	_test_round_and_double_tap()
	_test_victory()
	_test_defeat()
	if _failures.is_empty():
		print("PASS: 25 Prüfungen der Kampf- und Kartenlogik")
		quit(0)
	else:
		for failure in _failures:
			printerr("FAIL: " + failure)
		quit(1)


func _test_card_pool() -> void:
	_check(CardDatabase.CARDS.size() == 8, "Der Kartenpool enthält genau 8 Karten")
	var ids := {}
	for card: Dictionary in CardDatabase.CARDS:
		ids[card["id"]] = true
		_check(FileAccess.file_exists(card["artwork"]), "Artwork existiert: " + card["id"])
	_check(ids.size() == 8, "Alle Karten-IDs sind eindeutig")


func _test_rarity_weights() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261025
	var counts := {"common": 0, "rare": 0, "epic": 0, "legendary": 0}
	var draws := 50000
	for _index in draws:
		var card := CardDatabase.draw_card(rng)
		counts[card["rarity"]] += 1
	_check(absf(float(counts["common"]) / draws - 0.65) < 0.015, "Gewöhnlich-Gewichtung liegt nahe 65 %")
	_check(absf(float(counts["rare"]) / draws - 0.25) < 0.015, "Selten-Gewichtung liegt nahe 25 %")
	_check(absf(float(counts["epic"]) / draws - 0.09) < 0.01, "Episch-Gewichtung liegt nahe 9 %")
	_check(absf(float(counts["legendary"]) / draws - 0.01) < 0.004, "Legendär-Gewichtung liegt nahe 1 %")


func _new_game() -> GameState:
	var game := GameState.new()
	root.add_child(game)
	game.resolution_delay = 99.0
	game.start_game(42)
	return game


func _test_round_and_double_tap() -> void:
	var game := _new_game()
	_check(game.hand.size() == 3, "Eine Runde erzeugt drei Karten")
	game.force_hand_for_tests(["ash_mage", "root_beast", "sun_champion"])
	var old_hand := game.hand.duplicate(true)
	_check(game.select_card(1, "pc"), "PC-Auswahl wird angenommen")
	_check(game.boss_hp == 25, "Auswahl verursacht exakt den Kartenangriff")
	_check(game.player_hp == 18, "Morvath verursacht exakt 2 Gegenschaden")
	_check(not game.select_card(1, "web"), "Doppeltipp wird während der Auflösung abgewiesen")
	_check(game.boss_hp == 25 and game.player_hp == 18, "Doppeltipp verursacht keinen weiteren Schaden")
	game.finish_resolution_for_tests()
	_check(game.round_number == 2 and game.hand.size() == 3, "Nächste Runde erzeugt eine neue Dreierhand")
	_check(game.hand != old_hand or game.round_number == 2, "Alte Hand ist abgeschlossen")
	game.queue_free()


func _test_victory() -> void:
	var game := _new_game()
	game.force_hand_for_tests(["sun_champion", "ash_mage", "root_beast"])
	game.set_health_for_tests(10, 20)
	game.select_card(0)
	_check(game.phase == "victory" and game.boss_hp == 0, "Sieg wird zuverlässig erkannt")
	_check(game.player_hp == 20, "Nach tödlichem Treffer erfolgt kein Gegenschlag")
	game.queue_free()


func _test_defeat() -> void:
	var game := _new_game()
	game.force_hand_for_tests(["ash_mage", "root_beast", "sun_champion"])
	game.set_health_for_tests(30, 2)
	game.select_card(0)
	_check(game.phase == "defeat" and game.player_hp == 0, "Niederlage wird zuverlässig erkannt")
	game.queue_free()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
