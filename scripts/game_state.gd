class_name GameState
extends Node

signal state_changed(snapshot: Dictionary)
signal audio_cue(cue: String)

const SOLO_BOSS_HP := 60
const BOSS_DAMAGE := 2
const HAND_SIZE := 3
const MAX_SUPPORTED_PLAYERS := 6
const DEFAULT_PLAYER_ID := "player_1"
const PLAYER_COLORS := {
	"player_1": "4b91e2",
	"player_2": "a868e8",
}

var hero: Dictionary = HeroDatabase.default_hero()
var players: Dictionary = {}
var active_player_ids: Array[String] = []
var boss_hp := SOLO_BOSS_HP
var boss_max_hp := SOLO_BOSS_HP
var player_hp := int(HeroDatabase.ASH_KNIGHT["max_hp"])
var round_number := 1
var hand: Array[Dictionary] = []
var selected_upgrade: Dictionary = {}
var ability_ranks: Dictionary = {}
var combat_result: Dictionary = {}
var result_text := "Wähle ein Upgrade."
var phase := "menu"
var resolution_delay := 4.0

var _rng := RandomNumberGenerator.new()
var _game_sequence := 0


func start_game(seed_value: int = -1, requested_player_ids: Array = []) -> void:
	_game_sequence += 1
	if seed_value >= 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()
	hero = HeroDatabase.default_hero()
	players.clear()
	active_player_ids.clear()
	var unique_ids := {}
	for raw_id in requested_player_ids:
		var player_id := String(raw_id).strip_edges()
		if player_id.is_empty() or unique_ids.has(player_id) or active_player_ids.size() >= MAX_SUPPORTED_PLAYERS:
			continue
		unique_ids[player_id] = true
		active_player_ids.append(player_id)
	if active_player_ids.is_empty():
		active_player_ids.append(DEFAULT_PLAYER_ID)
	for index in active_player_ids.size():
		var player_id := active_player_ids[index]
		players[player_id] = _new_player(player_id, index)
	boss_max_hp = SOLO_BOSS_HP * active_player_ids.size()
	boss_hp = boss_max_hp
	round_number = 1
	combat_result = {}
	result_text = "Wählt eure Upgrades."
	phase = "awaiting_selection"
	_draw_new_hands()
	_sync_legacy_fields()
	audio_cue.emit("start")
	_emit_state()


func return_to_menu() -> void:
	_game_sequence += 1
	phase = "menu"
	players.clear()
	active_player_ids.clear()
	hand.clear()
	selected_upgrade = {}
	ability_ranks.clear()
	combat_result = {}
	result_text = ""
	_emit_state()


func select_upgrade(player_or_index: Variant, index_or_source: Variant = "pc", _source: String = "pc") -> bool:
	var player_id := _primary_player_id()
	var index := -1
	if typeof(player_or_index) == TYPE_INT:
		index = int(player_or_index)
	else:
		player_id = String(player_or_index)
		index = int(index_or_source)
	if phase != "awaiting_selection" or not players.has(player_id):
		return false
	var player: Dictionary = players[player_id]
	if not player.get("alive", false) or not player.get("connected", false) or player.get("ready", false):
		return false
	var player_hand: Array = player.get("hand", [])
	if index < 0 or index >= player_hand.size():
		return false
	var offer: Dictionary = player_hand[index]
	var ability_id: String = offer["id"]
	var ranks: Dictionary = player["ability_ranks"]
	var previous_rank := int(ranks.get(ability_id, 0))
	var definition := AbilityDatabase.get_ability(ability_id)
	if definition.is_empty() or previous_rank >= int(definition["max_rank"]):
		return false
	player["pending_upgrade"] = offer.duplicate(true)
	player["ready"] = true
	result_text = "%d/%d BEREIT" % [ready_count(), required_ready_count()]
	_sync_legacy_fields()
	_emit_state()
	if _all_reachable_players_ready():
		_resolve_round()
	return true


func select_card(index: int, source: String = "pc") -> bool:
	return select_upgrade(index, source)


func set_player_connected(player_id: String, connected: bool) -> void:
	if not players.has(player_id):
		return
	var player: Dictionary = players[player_id]
	if bool(player.get("connected", false)) == connected:
		return
	player["connected"] = connected
	_sync_legacy_fields()
	_emit_state()
	if phase == "awaiting_selection" and _all_reachable_players_ready():
		_resolve_round()


func ready_count() -> int:
	var count := 0
	for player_id in active_player_ids:
		var player: Dictionary = players.get(player_id, {})
		if player.get("alive", false) and player.get("connected", false) and player.get("ready", false):
			count += 1
	return count


func required_ready_count() -> int:
	var count := 0
	for player_id in active_player_ids:
		var player: Dictionary = players.get(player_id, {})
		if player.get("alive", false) and player.get("connected", false):
			count += 1
	return count


func get_snapshot() -> Dictionary:
	return get_private_snapshot(_primary_player_id())


func get_private_snapshot(player_id: String) -> Dictionary:
	var snapshot := get_public_snapshot(false)
	if not players.has(player_id):
		snapshot["role"] = "spectator"
		snapshot["can_select"] = false
		snapshot["hand"] = []
		return snapshot
	var player: Dictionary = players[player_id]
	var private_player := _serialize_player(player, true)
	snapshot["role"] = "player"
	snapshot["player_id"] = player_id
	snapshot["player"] = private_player
	snapshot["hero"] = private_player["hero"]
	snapshot["player_hp"] = private_player["hp"]
	snapshot["player_max_hp"] = private_player["max_hp"]
	snapshot["hand"] = private_player["hand"]
	snapshot["selected_upgrade"] = private_player["selected_upgrade"]
	snapshot["combat"] = _private_combat(player_id)
	snapshot["can_select"] = phase == "awaiting_selection" and player.get("alive", false) and player.get("connected", false) and not player.get("ready", false)
	return snapshot


func get_public_snapshot(include_private_hand: bool = false) -> Dictionary:
	var public_players: Array[Dictionary] = []
	for player_id in active_player_ids:
		public_players.append(_serialize_player(players[player_id], false))
	var primary: Dictionary = public_players[0] if not public_players.is_empty() else {}
	var snapshot := {
		"boss_hp": boss_hp,
		"boss_max_hp": boss_max_hp,
		"round": round_number,
		"players": public_players,
		"active_player_count": active_player_ids.size(),
		"ready_count": ready_count(),
		"required_ready_count": required_ready_count(),
		"combat": combat_result.duplicate(true),
		"result": result_text,
		"phase": phase,
		"can_select": false,
		"hand": [],
		"selected_upgrade": primary.get("selected_upgrade", {}),
		"hero": primary.get("hero", {}),
		"player_hp": primary.get("hp", 0),
		"player_max_hp": primary.get("max_hp", 20),
	}
	if include_private_hand and not active_player_ids.is_empty():
		var private_player: Dictionary = players[active_player_ids[0]]
		snapshot["hand"] = _duplicate_dictionary_array(private_player.get("hand", []))
		snapshot["can_select"] = phase == "awaiting_selection" and private_player.get("alive", false) and not private_player.get("ready", false)
	return snapshot


func force_hand_for_tests(ability_ids: Array[String], player_id: String = "") -> void:
	var target_id := _primary_player_id() if player_id.is_empty() else player_id
	if not players.has(target_id):
		return
	var player: Dictionary = players[target_id]
	var forced: Array[Dictionary] = []
	for ability_id in ability_ids:
		var ability := AbilityDatabase.get_ability(ability_id)
		if not ability.is_empty():
			forced.append(AbilityDatabase.make_offer(ability, _rank(player, ability_id)))
	player["hand"] = forced
	player["pending_upgrade"] = {}
	player["selected_upgrade"] = {}
	player["ready"] = false
	phase = "awaiting_selection"
	combat_result = {}
	_sync_legacy_fields()
	_emit_state()


func set_health_for_tests(new_boss_hp: int, new_player_hp: int, player_id: String = "") -> void:
	boss_hp = clampi(new_boss_hp, 0, boss_max_hp)
	var target_id := _primary_player_id() if player_id.is_empty() else player_id
	if players.has(target_id):
		var player: Dictionary = players[target_id]
		player["hp"] = clampi(new_player_hp, 0, int(player["hero"]["max_hp"]))
		player["alive"] = int(player["hp"]) > 0
	_sync_legacy_fields()
	_emit_state()


func set_ability_rank_for_tests(ability_id: String, rank: int, player_id: String = "") -> void:
	var target_id := _primary_player_id() if player_id.is_empty() else player_id
	if players.has(target_id):
		var player: Dictionary = players[target_id]
		var ranks: Dictionary = player["ability_ranks"]
		ranks[ability_id] = clampi(rank, 0, AbilityDatabase.MAX_RANK)
	_sync_legacy_fields()
	_emit_state()


func set_counters_for_tests(hero_attacks: int, boss_attacks: int, player_id: String = "") -> void:
	var target_id := _primary_player_id() if player_id.is_empty() else player_id
	if players.has(target_id):
		players[target_id]["hero_attack_count"] = maxi(0, hero_attacks)
		players[target_id]["boss_attack_count"] = maxi(0, boss_attacks)


func set_round_for_tests(value: int) -> void:
	round_number = maxi(1, value)


func finish_resolution_for_tests() -> void:
	_finish_round(_game_sequence)


func _new_player(player_id: String, index: int) -> Dictionary:
	var player_hero := HeroDatabase.default_hero()
	var display_number := index + 1
	if player_id.begins_with("player_") and player_id.trim_prefix("player_").is_valid_int():
		display_number = int(player_id.trim_prefix("player_"))
	return {
		"id": player_id,
		"display_name": "Spieler %d" % display_number,
		"color": PLAYER_COLORS.get(player_id, "55cfe4"),
		"hero": player_hero,
		"hp": int(player_hero["max_hp"]),
		"ability_ranks": {},
		"hand": [],
		"pending_upgrade": {},
		"selected_upgrade": {},
		"ready": false,
		"connected": true,
		"alive": true,
		"hero_attack_count": 0,
		"boss_attack_count": 0,
	}


func _resolve_round() -> void:
	if phase != "awaiting_selection":
		return
	var selected_players: Array[String] = []
	for player_id in active_player_ids:
		var player: Dictionary = players[player_id]
		if player.get("alive", false) and not Dictionary(player.get("pending_upgrade", {})).is_empty():
			selected_players.append(player_id)
	if selected_players.is_empty():
		return
	phase = "resolving"
	var attacks: Array[Dictionary] = []
	var boss_targets: Array[Dictionary] = []
	for player_id in selected_players:
		var player: Dictionary = players[player_id]
		var pending: Dictionary = player["pending_upgrade"]
		var ability_id: String = pending["id"]
		var ranks: Dictionary = player["ability_ranks"]
		var previous_rank := int(ranks.get(ability_id, 0))
		var acquired_rank := previous_rank + 1
		ranks[ability_id] = acquired_rank
		var acquired := pending.duplicate(true)
		acquired["acquired_rank"] = acquired_rank
		acquired["unlocked"] = previous_rank == 0
		player["selected_upgrade"] = acquired
		player["pending_upgrade"] = {}
		player["hero_attack_count"] = int(player["hero_attack_count"]) + 1

		var hp_before := int(player["hp"])
		var base_damage := int(player["hero"]["base_attack"])
		var attack_bonus := AbilityDatabase.effect_value("ash_blade", "attack_bonus", _rank(player, "ash_blade"))
		var conditional_bonus := 0
		if hp_before * 2 < int(player["hero"]["max_hp"]):
			conditional_bonus = AbilityDatabase.effect_value("blood_frenzy", "low_health_bonus", _rank(player, "blood_frenzy"))
		var rune_damage := AbilityDatabase.effect_value("rune_bolt", "periodic_damage", _rank(player, "rune_bolt")) if round_number % 3 == 0 else 0
		var soul_damage := AbilityDatabase.effect_value("soul_fire", "periodic_damage", _rank(player, "soul_fire")) if int(player["hero_attack_count"]) % 3 == 0 else 0
		var hero_damage := base_damage + attack_bonus + conditional_bonus + rune_damage + soul_damage
		var boss_before := boss_hp
		boss_hp = maxi(0, boss_hp - hero_damage)
		var healing_power := AbilityDatabase.effect_value("life_steal", "healing", _rank(player, "life_steal"))
		var healing := mini(healing_power, int(player["hero"]["max_hp"]) - hp_before)
		player["hp"] = hp_before + healing
		var triggered_effects: Array[String] = []
		if conditional_bonus > 0:
			triggered_effects.append("BLUTRAUSCH +%d SCHADEN" % conditional_bonus)
		if rune_damage > 0:
			triggered_effects.append("RUNENBLITZ +%d SCHADEN" % rune_damage)
		if soul_damage > 0:
			triggered_effects.append("SEELENFEUER +%d SCHADEN" % soul_damage)
		if healing > 0:
			triggered_effects.append("LEBENSRAUB +%d LP" % healing)
		attacks.append({
			"player_id": player_id,
			"display_name": player["display_name"],
			"selected_upgrade": acquired.duplicate(true),
			"hero_damage": hero_damage,
			"base_damage": base_damage,
			"attack_bonus": attack_bonus,
			"conditional_bonus": conditional_bonus,
			"rune_damage": rune_damage,
			"soul_damage": soul_damage,
			"healing": healing,
			"hero_hp_before": hp_before,
			"hero_hp_after_heal": int(player["hp"]),
			"boss_hp_before": boss_before,
			"boss_hp_after": boss_hp,
			"triggered_effects": triggered_effects,
		})
		if boss_hp <= 0:
			break

	if boss_hp > 0:
		for player_id in active_player_ids:
			var player: Dictionary = players[player_id]
			if not player.get("alive", false):
				continue
			player["boss_attack_count"] = int(player["boss_attack_count"]) + 1
			var hp_before_hit := int(player["hp"])
			var blocked := _bone_guard_reduction(player, int(player["boss_attack_count"]))
			var incoming_damage := maxi(0, BOSS_DAMAGE - blocked)
			player["hp"] = maxi(0, hp_before_hit - incoming_damage)
			player["alive"] = int(player["hp"]) > 0
			boss_targets.append({
				"player_id": player_id,
				"display_name": player["display_name"],
				"hp_before": hp_before_hit,
				"hp_after": int(player["hp"]),
				"boss_damage": incoming_damage,
				"blocked": blocked,
				"boss_attack_count": int(player["boss_attack_count"]),
			})

	combat_result = {"attacks": attacks, "boss_targets": boss_targets, "boss_attack_count": 1 if boss_hp > 0 else 0}
	if not attacks.is_empty():
		combat_result.merge(attacks[0], true)
	if not boss_targets.is_empty():
		combat_result["boss_damage"] = boss_targets[0]["boss_damage"]
		combat_result["blocked"] = boss_targets[0]["blocked"]
	else:
		combat_result["boss_damage"] = 0
		combat_result["blocked"] = 0
	_sync_legacy_fields()
	audio_cue.emit("attack")

	if boss_hp <= 0:
		phase = "victory"
		result_text = "Morvath ist besiegt!"
		audio_cue.emit("victory")
		_emit_state()
		return
	if _all_players_defeated():
		phase = "defeat"
		result_text = "Alle Aschenritter sind gefallen."
		audio_cue.emit("defeat")
		_emit_state()
		return
	result_text = "Die Aschenritter greifen an. Morvath schlägt einmal zurück."
	_emit_state()
	var sequence := _game_sequence
	var delay := resolution_delay if active_player_ids.size() == 1 else maxf(resolution_delay, 5.0)
	if delay <= 0.0:
		_finish_round(sequence)
	else:
		get_tree().create_timer(delay).timeout.connect(func() -> void: _finish_round(sequence), CONNECT_ONE_SHOT)


func _finish_round(sequence: int) -> void:
	if sequence != _game_sequence or phase != "resolving":
		return
	round_number += 1
	combat_result = {}
	for player_id in active_player_ids:
		var player: Dictionary = players[player_id]
		player["pending_upgrade"] = {}
		player["selected_upgrade"] = {}
		player["ready"] = false
	result_text = "Wählt eure nächsten Upgrades."
	phase = "awaiting_selection"
	_draw_new_hands()
	_sync_legacy_fields()
	audio_cue.emit("new_round")
	_emit_state()


func _draw_new_hands() -> void:
	for player_id in active_player_ids:
		var player: Dictionary = players[player_id]
		if player.get("alive", false):
			player["hand"] = AbilityDatabase.draw_hand(_rng, player["ability_ranks"], round_number, HAND_SIZE)
		else:
			player["hand"] = []


func _serialize_player(player: Dictionary, include_hand: bool) -> Dictionary:
	var player_hero: Dictionary = player["hero"]
	var result := {
		"id": player["id"],
		"display_name": player["display_name"],
		"color": player["color"],
		"hp": player["hp"],
		"max_hp": player_hero["max_hp"],
		"connected": player["connected"],
		"alive": player["alive"],
		"ready": player["ready"],
		"selected_upgrade": Dictionary(player.get("selected_upgrade", {})).duplicate(true),
		"hero": {
			"id": player_hero["id"],
			"name": player_hero["name"],
			"hp": player["hp"],
			"max_hp": player_hero["max_hp"],
			"base_attack": player_hero["base_attack"],
			"artwork": player_hero["artwork"],
			"abilities": AbilityDatabase.active_abilities(player["ability_ranks"], {
				"round": round_number,
				"hp": player["hp"],
				"max_hp": player_hero["max_hp"],
				"hero_attack_count": player["hero_attack_count"],
			}),
		},
	}
	if include_hand:
		result["hand"] = _duplicate_dictionary_array(player.get("hand", []))
	return result


func _private_combat(player_id: String) -> Dictionary:
	if combat_result.is_empty():
		return {}
	var private_result := {"boss_attack_count": combat_result.get("boss_attack_count", 0)}
	var own_attacks: Array[Dictionary] = []
	for attack: Dictionary in combat_result.get("attacks", []):
		if attack.get("player_id", "") == player_id:
			own_attacks.append(attack.duplicate(true))
	var own_targets: Array[Dictionary] = []
	for target: Dictionary in combat_result.get("boss_targets", []):
		if target.get("player_id", "") == player_id:
			own_targets.append(target.duplicate(true))
	private_result["attacks"] = own_attacks
	private_result["boss_targets"] = own_targets
	if not own_attacks.is_empty():
		private_result.merge(own_attacks[0], true)
	if not own_targets.is_empty():
		private_result["boss_damage"] = own_targets[0].get("boss_damage", 0)
		private_result["blocked"] = own_targets[0].get("blocked", 0)
	return private_result


func _all_reachable_players_ready() -> bool:
	var required := required_ready_count()
	return required > 0 and ready_count() == required


func _all_players_defeated() -> bool:
	for player_id in active_player_ids:
		if players[player_id].get("alive", false):
			return false
	return true


func _rank(player: Dictionary, ability_id: String) -> int:
	return int(Dictionary(player["ability_ranks"]).get(ability_id, 0))


func _bone_guard_reduction(player: Dictionary, attack_number: int) -> int:
	var rank := _rank(player, "bone_guard")
	if rank <= 0:
		return 0
	if rank == 1:
		return 1 if attack_number % 2 == 0 else 0
	if rank == 2:
		return 2 if attack_number % 2 == 0 else 0
	return 2 if attack_number % 2 == 0 else 1


func _primary_player_id() -> String:
	return active_player_ids[0] if not active_player_ids.is_empty() else DEFAULT_PLAYER_ID


func _sync_legacy_fields() -> void:
	var primary_id := _primary_player_id()
	if not players.has(primary_id):
		player_hp = 0
		hand = []
		selected_upgrade = {}
		ability_ranks = {}
		return
	var primary: Dictionary = players[primary_id]
	player_hp = int(primary["hp"])
	hand = primary["hand"]
	selected_upgrade = primary["selected_upgrade"]
	ability_ranks = primary["ability_ranks"]


func _duplicate_dictionary_array(source: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item: Dictionary in source:
		result.append(item.duplicate(true))
	return result


func _emit_state() -> void:
	state_changed.emit(get_snapshot())
