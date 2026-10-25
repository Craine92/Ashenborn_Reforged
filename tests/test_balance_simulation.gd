extends SceneTree

const RUNS_PER_STRATEGY := 200
const STRATEGIES := ["zufall", "offensiv", "defensiv", "taktisch"]

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var all_results := {}
	for coop in [false, true]:
		var mode := "KOOP" if coop else "SOLO"
		all_results[mode] = {}
		for strategy in STRATEGIES:
			var metrics := _simulate_strategy(coop, strategy)
			all_results[mode][strategy] = metrics
			_print_metrics(mode, strategy, metrics)
			_check(int(metrics["completed"]) == RUNS_PER_STRATEGY, "%s/%s: alle 200 Partien enden regulär" % [mode, strategy])
	_check(float(all_results["SOLO"]["taktisch"]["win_rate"]) > float(all_results["SOLO"]["zufall"]["win_rate"]), "Bewusste Solo-Taktik verbessert die Siegesquote gegenüber Zufall")
	_check(float(all_results["KOOP"]["taktisch"]["win_rate"]) >= float(all_results["KOOP"]["zufall"]["win_rate"]), "Bewusste Koop-Taktik ist nicht schlechter als Zufall")
	if _failures.is_empty():
		print("PASS: 1.600 Partien · je 200 pro Modus und Strategie · Ergebnisse vollständig erfasst")
		quit(0)
	else:
		for failure in _failures:
			printerr("FAIL: " + failure)
		quit(1)


func _simulate_strategy(coop: bool, strategy: String) -> Dictionary:
	var wins := 0
	var completed := 0
	var total_rounds := 0
	var card_use := {}
	var synergies := {"rune_blade": 0, "blood_shield": 0}
	var intents := {"phase_1": {}, "phase_2": {}}
	var phase_two_games := 0
	for run_index in RUNS_PER_STRATEGY:
		var game := GameState.new()
		root.add_child(game)
		game.resolution_delay = 99.0
		var player_ids: Array[String] = ["player_1"]
		if coop:
			player_ids.append("player_2")
		game.start_game(40000 + run_index + (10000 if coop else 0) + STRATEGIES.find(strategy) * 1000, player_ids)
		var seen_synergies := {}
		var reached_phase_two := false
		while game.phase == "awaiting_selection" and game.round_number <= 30:
			for player_index in player_ids.size():
				var player_id := player_ids[player_index]
				var player: Dictionary = game.players[player_id]
				if not player.get("alive", false) or not player.get("connected", false):
					continue
				var player_hand: Array = player.get("hand", [])
				var choice := _choose(player_hand, strategy, run_index * 31 + game.round_number * 7 + player_index, game, player_id)
				var card_id := String(player_hand[choice].get("id", ""))
				card_use[card_id] = int(card_use.get(card_id, 0)) + 1
				game.select_upgrade(player_id, choice, "simulation")
			if game.phase == "resolving":
				var combat_intent: Dictionary = game.combat_result.get("boss_intent", {})
				var phase_key := "phase_%d" % int(game.combat_result.get("boss_phase", 1))
				var intent_id := String(combat_intent.get("id", ""))
				intents[phase_key][intent_id] = int(intents[phase_key].get(intent_id, 0)) + 1
				for player_id in player_ids:
					for synergy: Dictionary in game.get_private_snapshot(player_id).get("player", {}).get("hero", {}).get("synergies", []):
						seen_synergies[synergy["id"]] = true
				game.finish_resolution_for_tests()
				if game.boss_phase == 2:
					reached_phase_two = true
		if reached_phase_two:
			phase_two_games += 1
		if game.phase in ["victory", "defeat"]:
			completed += 1
			total_rounds += game.round_number
			if game.phase == "victory":
				wins += 1
		for synergy_id in seen_synergies:
			synergies[synergy_id] = int(synergies.get(synergy_id, 0)) + 1
		game.free()
	return {
		"completed": completed,
		"wins": wins,
		"win_rate": 100.0 * float(wins) / float(maxi(1, completed)),
		"average_rounds": float(total_rounds) / float(maxi(1, completed)),
		"card_use": card_use,
		"synergies": synergies,
		"intents": intents,
		"phase_two_games": phase_two_games,
	}


func _choose(hand: Array, strategy: String, salt: int, game: GameState, player_id: String) -> int:
	if strategy == "zufall":
		return posmod(salt * 17 + 5, hand.size())
	if strategy == "taktisch":
		var intent: Dictionary = game.boss_intent
		var targeted: bool = intent.get("target_mode", "all") == "all" or intent.get("target_player_id", "") == player_id
		if intent.get("id", "") == "dark_ritual":
			var breaker := _index_of(hand, "ritual_breaker")
			if breaker >= 0:
				return breaker
		if targeted and (game.boss_phase == 2 or int(game.players[player_id]["hp"]) <= int(intent.get("damage", 0)) + 4):
			var stance := _index_of(hand, "defensive_stance")
			if stance >= 0:
				return stance
		var storm := _index_of(hand, "storm_strike")
		if storm >= 0 and (not targeted or game.boss_hp <= _estimated_attack(game.players[player_id]) + 4):
			return storm
		return _priority_choice(hand, ["bone_guard", "life_steal", "ash_blade", "rune_bolt", "soul_fire", "blood_frenzy", "storm_strike"])
	if strategy == "defensiv":
		return _priority_choice(hand, ["bone_guard", "life_steal", "ash_blade", "rune_bolt", "blood_frenzy", "soul_fire"])
	return _priority_choice(hand, ["storm_strike", "ash_blade", "rune_bolt", "soul_fire", "blood_frenzy", "ritual_breaker", "life_steal", "bone_guard", "defensive_stance"])


func _priority_choice(hand: Array, priority: Array) -> int:
	for wanted in priority:
		var index := _index_of(hand, wanted)
		if index >= 0:
			return index
	return 0


func _index_of(hand: Array, card_id: String) -> int:
	for index in hand.size():
		if hand[index].get("id", "") == card_id:
			return index
	return -1


func _estimated_attack(player: Dictionary) -> int:
	return int(player["hero"]["base_attack"]) + AbilityDatabase.effect_value("ash_blade", "attack_bonus", int(player["ability_ranks"].get("ash_blade", 0)))


func _print_metrics(mode: String, strategy: String, metrics: Dictionary) -> void:
	print("BALANCE %s/%s: Siege %d/%d (%.1f %%), Ø Runden %.2f, Phase 2 %d" % [mode, strategy, metrics["wins"], metrics["completed"], metrics["win_rate"], metrics["average_rounds"], metrics["phase_two_games"]])
	print("BALANCE %s/%s: Karten %s" % [mode, strategy, JSON.stringify(metrics["card_use"])])
	print("BALANCE %s/%s: Synergien %s" % [mode, strategy, JSON.stringify(metrics["synergies"])])
	print("BALANCE %s/%s: Intents %s" % [mode, strategy, JSON.stringify(metrics["intents"]),])


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
