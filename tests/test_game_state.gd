extends SceneTree

var _failures: Array[String] = []
var _simulated_average := 0.0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_legacy_cards_are_preserved()
	_test_ability_data_and_offers()
	_test_stacking_and_max_rank()
	_test_authoritative_effects()
	_test_authoritative_build_tracking()
	_test_round_double_tap_victory_and_defeat()
	_test_solo_duration()
	if _failures.is_empty():
		print("SIMULATION: 80 Solo-Partien, durchschnittlich %.2f Runden" % _simulated_average)
		print("PASS: Held, Upgrade-Angebote, Stacking, Effekte, Kampf und Solo-Balancing")
		quit(0)
	else:
		for failure in _failures:
			printerr("FAIL: " + failure)
		quit(1)


func _test_legacy_cards_are_preserved() -> void:
	_check(CardDatabase.CARDS.size() == 8, "Die acht alten Kreaturenkarten bleiben erhalten")
	for card: Dictionary in CardDatabase.CARDS:
		_check(FileAccess.file_exists(card["artwork"]), "Altes Kreaturenartwork existiert: " + card["id"])


func _test_ability_data_and_offers() -> void:
	_check(AbilityDatabase.ABILITIES.size() == 6, "Genau sechs Upgrade-Fähigkeiten sind definiert")
	var ids := {}
	for ability: Dictionary in AbilityDatabase.ABILITIES:
		ids[ability["id"]] = true
		_check(int(ability["max_rank"]) == 3, "Fähigkeit besitzt drei Ränge: " + ability["id"])
		_check(FileAccess.file_exists(ability["artwork"]), "Upgrade-Artwork existiert: " + ability["id"])
	_check(ids.size() == 6, "Alle Fähigkeits-IDs sind eindeutig")

	var game := _new_game(10)
	_check(game.hero["name"] == "Aschenritter" and game.player_hp == 20, "Partie startet mit dem Aschenritter")
	_check(game.hand.size() == 3 and _unique_offer_count(game.hand) == 3, "Drei unterschiedliche Upgrade-Karten erscheinen")
	_check(game.get_public_snapshot(false)["hand"].is_empty(), "Öffentlicher TV-Zustand enthält keine private Hand")
	_check(game.get_snapshot()["hand"].size() == 3, "Privater Controller-Zustand enthält die drei Angebote")
	game.free()

	var rng := RandomNumberGenerator.new()
	rng.seed = 1501
	var counts := {"ash_blade": 0, "soul_fire": 0}
	for _draw in 4000:
		var offers := AbilityDatabase.draw_hand(rng, {}, 1, 3)
		for offer: Dictionary in offers:
			if counts.has(offer["id"]):
				counts[offer["id"]] += 1
	_check(counts["soul_fire"] < counts["ash_blade"] / 3, "Seelenfeuer wird deutlich seltener als gewöhnliche Fähigkeiten angeboten")


func _test_stacking_and_max_rank() -> void:
	var game := _new_game(20)
	for expected_rank in [1, 2, 3]:
		game.force_hand_for_tests(["ash_blade", "life_steal", "bone_guard"])
		_check(game.select_upgrade(0, "pc"), "Aschenklinge Rang %d kann gewählt werden" % expected_rank)
		_check(int(game.ability_ranks.get("ash_blade", 0)) == expected_rank, "Aschenklinge erreicht exakt Rang %d" % expected_rank)
		if game.phase == "resolving":
			game.finish_resolution_for_tests()
	if game.phase == "awaiting_selection":
		_check(not _offer_ids(game.hand).has("ash_blade"), "Fähigkeit auf Rang 3 wird nicht erneut angeboten")
	game.force_hand_for_tests(["ash_blade", "life_steal", "bone_guard"])
	_check(not game.select_upgrade(0, "pc"), "Erzwungenes Angebot kann Rang 3 nicht überschreiten")
	_check(int(game.ability_ranks["ash_blade"]) == 3, "Maximalrang bleibt bei 3")
	game.free()

	game = _new_game(21)
	game.force_hand_for_tests(["life_steal", "bone_guard", "rune_bolt"])
	game.select_upgrade(0)
	game.finish_resolution_for_tests()
	_check(_offer_ids(game.hand).has("life_steal"), "Ab Runde 2 wird ein vorhandenes aufwertbares Upgrade erneut angeboten")
	_check(_unique_offer_count(game.hand) == game.hand.size(), "Ein Angebot enthält keine doppelten Fähigkeiten")
	game.free()


func _test_authoritative_effects() -> void:
	var game := _new_game(30)
	game.set_ability_rank_for_tests("ash_blade", 2)
	game.set_ability_rank_for_tests("rune_bolt", 2)
	game.set_ability_rank_for_tests("blood_frenzy", 3)
	game.set_ability_rank_for_tests("soul_fire", 2)
	game.set_health_for_tests(60, 9)
	game.set_round_for_tests(3)
	game.set_counters_for_tests(2, 0)
	game.force_hand_for_tests(["bone_guard", "life_steal", "ash_blade"])
	game.select_upgrade(0)
	_check(game.combat_result["hero_damage"] == 22, "Basisangriff, Aschenklinge, Blutrausch, Runenblitz und Seelenfeuer addieren sich exakt")
	_check(game.boss_hp == 38, "Zusatzschaden wird genau einmal auf Morvath angewendet")
	var triggers: Array = game.combat_result["triggered_effects"]
	_check(triggers.has("BLUTRAUSCH +5 SCHADEN") and triggers.has("RUNENBLITZ +4 SCHADEN") and triggers.has("SEELENFEUER +7 SCHADEN"), "Ausgelöste Fähigkeiten werden aus dem bestätigten Kampfergebnis gemeldet")
	game.free()


	game = _new_game(31)
	game.set_ability_rank_for_tests("life_steal", 1)
	game.set_health_for_tests(60, 10)
	game.force_hand_for_tests(["life_steal", "ash_blade", "bone_guard"])
	game.select_upgrade(0)
	_check(game.combat_result["healing"] == 2 and game.player_hp == 10, "Lebensraub Rang 2 heilt vor dem Gegenschlag exakt 2 LP")
	game.free()

	game = _new_game(311)
	game.set_ability_rank_for_tests("life_steal", 2)
	game.set_health_for_tests(60, 19)
	game.force_hand_for_tests(["ash_blade", "bone_guard", "rune_bolt"])
	game.select_upgrade(0)
	_check(game.combat_result["healing"] == 1 and game.combat_result["hero_hp_after_heal"] == 20, "Lebensraub wird exakt am maximalen Leben gedeckelt")
	game.free()

	game = _new_game(32)
	game.set_ability_rank_for_tests("bone_guard", 2)
	game.set_counters_for_tests(0, 1)
	game.force_hand_for_tests(["ash_blade", "life_steal", "rune_bolt"])
	game.select_upgrade(0)
	_check(game.combat_result["blocked"] == 2 and game.combat_result["boss_damage"] == 0, "Knochenschutz Rang 2 blockt den zweiten Bossangriff vollständig")
	game.free()

	game = _new_game(33)
	game.set_ability_rank_for_tests("bone_guard", 3)
	game.set_counters_for_tests(0, 0)
	game.force_hand_for_tests(["ash_blade", "life_steal", "rune_bolt"])
	game.select_upgrade(0)
	_check(game.combat_result["blocked"] == 1 and game.combat_result["boss_damage"] == 1, "Knochenschutz Rang 3 reduziert auch ungerade Bossangriffe um 1")
	game.free()


func _test_authoritative_build_tracking() -> void:
	var game := _new_game(34)
	game.set_ability_rank_for_tests("ash_blade", 2)
	game.set_ability_rank_for_tests("rune_bolt", 1)
	game.set_ability_rank_for_tests("blood_frenzy", 1)
	game.set_ability_rank_for_tests("soul_fire", 1)
	game.set_round_for_tests(4)
	game.set_counters_for_tests(4, 0)
	game.set_health_for_tests(60, 9)
	var abilities: Array = game.get_private_snapshot("player_1")["player"]["hero"]["abilities"]
	var by_id := {}
	for ability: Dictionary in abilities:
		by_id[ability["id"]] = ability
	_check(by_id["ash_blade"]["effect_text"] == "Dauerhaft +2 Angriff.", "Build-Menü zeigt die tatsächliche Aschenklingenwirkung")
	_check(by_id["rune_bolt"]["trigger_text"] == "Nächste Auslösung: Runde 6", "Runenblitz berechnet seine nächste Runde aus dem GameState")
	_check(by_id["soul_fire"]["trigger_text"] == "Nächste Auslösung in 2 Angriffen", "Seelenfeuer berechnet verbleibende Angriffe aus dem persönlichen Zähler")
	_check(by_id["blood_frenzy"]["condition_met"] and by_id["blood_frenzy"]["trigger_text"].contains("AKTIV"), "Blutrausch meldet die aktuell erfüllte Lebensbedingung")
	game.set_health_for_tests(60, 12)
	abilities = game.get_private_snapshot("player_1")["player"]["hero"]["abilities"]
	for ability: Dictionary in abilities:
		if ability["id"] == "blood_frenzy":
			_check(not ability["condition_met"] and ability["trigger_text"].contains("nicht aktiv"), "Blutrausch aktualisiert den Bedingungsstatus nach Lebensänderung")
	game.free()


func _test_round_double_tap_victory_and_defeat() -> void:
	var game := _new_game(40)
	game.force_hand_for_tests(["ash_blade", "life_steal", "bone_guard"])
	_check(game.select_upgrade(0, "web"), "Ein Smartphone-Tipp wird angenommen")
	_check(not game.select_upgrade(0, "web"), "Ein schneller zweiter Tipp wird abgewiesen")
	_check(game.ability_ranks["ash_blade"] == 1 and game.boss_hp == 55 and game.player_hp == 18, "Doppeltipp erzeugt weder zweite Aufwertung noch zweiten Angriff")
	game.finish_resolution_for_tests()
	_check(game.round_number == 2 and game.hand.size() == 3, "Nächste Runde startet automatisch mit drei Upgrades")
	game.free()

	game = _new_game(41)
	game.set_health_for_tests(4, 20)
	game.force_hand_for_tests(["life_steal", "bone_guard", "rune_bolt"])
	game.select_upgrade(1)
	_check(game.phase == "victory" and game.boss_hp == 0 and game.player_hp == 20, "Tödlicher Heldenangriff gewinnt ohne Boss-Gegenschlag")
	game.free()

	game = _new_game(42)
	game.set_health_for_tests(60, 2)
	game.force_hand_for_tests(["ash_blade", "rune_bolt", "blood_frenzy"])
	game.select_upgrade(0)
	_check(game.phase == "defeat" and game.player_hp == 0, "Morvaths Gegenschlag kann den Aschenritter besiegen")
	game.free()


func _test_solo_duration() -> void:
	var total_rounds := 0.0
	var completed := 0
	for seed_value in 80:
		var game := _new_game(1000 + seed_value)
		var chooser := RandomNumberGenerator.new()
		chooser.seed = 9000 + seed_value
		while game.phase == "awaiting_selection" and game.round_number <= 20:
			game.select_upgrade(chooser.randi_range(0, game.hand.size() - 1), "simulation")
			if game.phase == "resolving":
				game.finish_resolution_for_tests()
		if game.phase in ["victory", "defeat"]:
			total_rounds += game.round_number
			completed += 1
		game.free()
	var average := total_rounds / float(maxi(1, completed))
	_simulated_average = average
	_check(completed == 80, "Alle simulierten Solokämpfe enden mit Sieg oder Niederlage")
	_check(average >= 8.0 and average <= 12.0, "Durchschnittlicher Solokampf dauert 8–12 Runden (%.2f)" % average)


func _new_game(seed_value: int) -> GameState:
	var game := GameState.new()
	root.add_child(game)
	game.resolution_delay = 99.0
	game.start_game(seed_value)
	return game


func _offer_ids(offers: Array[Dictionary]) -> Array[String]:
	var ids: Array[String] = []
	for offer: Dictionary in offers:
		ids.append(offer["id"])
	return ids


func _unique_offer_count(offers: Array[Dictionary]) -> int:
	var unique := {}
	for offer: Dictionary in offers:
		unique[offer["id"]] = true
	return unique.size()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
