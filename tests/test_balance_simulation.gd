extends SceneTree

const RUNS := 200
const STRATEGIES := ["zufall", "offensiv", "defensiv"]

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var solo := _simulate(false)
	var coop := _simulate(true)
	_print_metrics("SOLO", solo)
	_print_metrics("KOOP", coop)
	_check(int(solo["completed"]) == RUNS and int(coop["completed"]) == RUNS, "Alle 400 Simulationen enden regulär")
	_check(float(solo["average_rounds"]) >= 8.0 and float(solo["average_rounds"]) <= 14.0, "Solo-Durchschnitt liegt im Zielkorridor 8–14")
	_check(float(coop["average_rounds"]) >= 8.0 and float(coop["average_rounds"]) <= 14.0, "Koop-Durchschnitt liegt im Zielkorridor 8–14")
	if _failures.is_empty():
		print("PASS: 200 Solo- und 200 Koop-Kämpfe über Zufalls-, Offensiv- und Defensivstrategie")
		quit(0)
	else:
		for failure in _failures:
			printerr("FAIL: " + failure)
		quit(1)


func _simulate(coop: bool) -> Dictionary:
	var wins := 0
	var completed := 0
	var total_rounds := 0
	var abilities := {}
	var synergies := {"rune_blade": 0, "blood_shield": 0}
	var intents := {"skull_storm": 0, "soul_lance": 0, "dark_ritual": 0}
	var profiles := {}
	for run_index in RUNS:
		var game := GameState.new()
		root.add_child(game)
		game.resolution_delay = 99.0
		var player_ids: Array[String] = ["player_1"]
		if coop:
			player_ids.append("player_2")
		game.start_game(30000 + run_index + (1000 if coop else 0), player_ids)
		var seen_synergies := {}
		var base_strategy_index := run_index % STRATEGIES.size()
		var profile_name: String = STRATEGIES[base_strategy_index]
		if coop:
			profile_name += "+" + STRATEGIES[(base_strategy_index + 1) % STRATEGIES.size()]
		while game.phase == "awaiting_selection" and game.round_number <= 30:
			for player_index in player_ids.size():
				var player_id := player_ids[player_index]
				var player: Dictionary = game.players[player_id]
				if not player.get("alive", false):
					continue
				var strategy: String = STRATEGIES[(base_strategy_index + player_index) % STRATEGIES.size()]
				var choice: int = _choose(player.get("hand", []), strategy, run_index + game.round_number + player_index)
				var ability_id := String(player.get("hand", [])[choice].get("id", ""))
				abilities[ability_id] = int(abilities.get(ability_id, 0)) + 1
				game.select_upgrade(player_id, choice, "simulation")
			if game.phase == "resolving":
				var intent_id := String(game.combat_result.get("boss_intent", {}).get("id", ""))
				intents[intent_id] = int(intents.get(intent_id, 0)) + 1
				for player_id in player_ids:
					for synergy: Dictionary in game.get_private_snapshot(player_id).get("player", {}).get("hero", {}).get("synergies", []):
						seen_synergies[synergy["id"]] = true
				game.finish_resolution_for_tests()
		if game.phase in ["victory", "defeat"]:
			completed += 1
			total_rounds += game.round_number
			if game.phase == "victory":
				wins += 1
			var profile: Dictionary = profiles.get(profile_name, {"runs": 0, "wins": 0, "rounds": 0})
			profile["runs"] = int(profile["runs"]) + 1
			profile["rounds"] = int(profile["rounds"]) + game.round_number
			if game.phase == "victory":
				profile["wins"] = int(profile["wins"]) + 1
			profiles[profile_name] = profile
		for synergy_id in seen_synergies:
			synergies[synergy_id] = int(synergies.get(synergy_id, 0)) + 1
		game.free()
	return {
		"completed": completed,
		"wins": wins,
		"win_rate": 100.0 * float(wins) / float(maxi(1, completed)),
		"average_rounds": float(total_rounds) / float(maxi(1, completed)),
		"abilities": abilities,
		"synergies": synergies,
		"intents": intents,
		"profiles": profiles,
	}


func _choose(hand: Array, strategy: String, salt: int) -> int:
	if strategy == "zufall":
		return posmod(salt * 17 + 5, hand.size())
	var priority := ["ash_blade", "rune_bolt", "soul_fire", "blood_frenzy", "life_steal", "bone_guard"]
	if strategy == "defensiv":
		priority = ["bone_guard", "life_steal", "ash_blade", "rune_bolt", "blood_frenzy", "soul_fire"]
	for wanted in priority:
		for index in hand.size():
			if hand[index].get("id", "") == wanted:
				return index
	return 0


func _print_metrics(label: String, metrics: Dictionary) -> void:
	print("BALANCE %s: Siege %d/%d (%.1f %%), Ø Runden %.2f" % [label, metrics["wins"], metrics["completed"], metrics["win_rate"], metrics["average_rounds"]])
	print("BALANCE %s: Fähigkeiten %s" % [label, JSON.stringify(metrics["abilities"])])
	print("BALANCE %s: Synergie-Partien %s" % [label, JSON.stringify(metrics["synergies"])])
	print("BALANCE %s: Intents %s" % [label, JSON.stringify(metrics["intents"])])
	for profile_name in metrics["profiles"]:
		var profile: Dictionary = metrics["profiles"][profile_name]
		print("BALANCE %s %s: Siege %d/%d, Ø Runden %.2f" % [label, profile_name, profile["wins"], profile["runs"], float(profile["rounds"]) / float(profile["runs"])])


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
