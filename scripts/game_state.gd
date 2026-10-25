class_name GameState
extends Node

signal state_changed(snapshot: Dictionary)
signal audio_cue(cue: String)

const BOSS_MAX_HP := 60
const BOSS_DAMAGE := 2
const HAND_SIZE := 3

var hero: Dictionary = HeroDatabase.default_hero()
var boss_hp := BOSS_MAX_HP
var player_hp := int(HeroDatabase.ASH_KNIGHT["max_hp"])
var round_number := 1
var hand: Array[Dictionary] = []
var selected_upgrade: Dictionary = {}
var ability_ranks: Dictionary = {}
var combat_result: Dictionary = {}
var result_text := "Wähle ein Upgrade."
var phase := "menu"
var resolution_delay := 1.55

var _hero_attack_count := 0
var _boss_attack_count := 0
var _rng := RandomNumberGenerator.new()
var _game_sequence := 0


func start_game(seed_value: int = -1) -> void:
	_game_sequence += 1
	if seed_value >= 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()
	hero = HeroDatabase.default_hero()
	boss_hp = BOSS_MAX_HP
	player_hp = int(hero["max_hp"])
	round_number = 1
	hand.clear()
	selected_upgrade = {}
	ability_ranks.clear()
	combat_result = {}
	_hero_attack_count = 0
	_boss_attack_count = 0
	result_text = "Wähle ein Upgrade für den Aschenritter."
	phase = "awaiting_selection"
	_draw_new_hand()
	audio_cue.emit("start")
	_emit_state()


func return_to_menu() -> void:
	_game_sequence += 1
	phase = "menu"
	hand.clear()
	selected_upgrade = {}
	combat_result = {}
	result_text = ""
	_emit_state()


func select_upgrade(index: int, _source: String = "pc") -> bool:
	if phase != "awaiting_selection":
		return false
	if index < 0 or index >= hand.size():
		return false

	var offer: Dictionary = hand[index]
	var ability_id: String = offer["id"]
	var previous_rank := int(ability_ranks.get(ability_id, 0))
	var definition := AbilityDatabase.get_ability(ability_id)
	if definition.is_empty() or previous_rank >= int(definition["max_rank"]):
		return false

	phase = "resolving"
	var acquired_rank := previous_rank + 1
	ability_ranks[ability_id] = acquired_rank
	selected_upgrade = AbilityDatabase.make_offer(definition, previous_rank)
	selected_upgrade["acquired_rank"] = acquired_rank
	selected_upgrade["unlocked"] = previous_rank == 0
	_hero_attack_count += 1

	var hero_hp_before := player_hp
	var base_damage := int(hero["base_attack"])
	var attack_bonus := AbilityDatabase.effect_value("ash_blade", "attack_bonus", _rank("ash_blade"))
	var conditional_bonus := 0
	if player_hp * 2 < int(hero["max_hp"]):
		conditional_bonus = AbilityDatabase.effect_value("blood_frenzy", "low_health_bonus", _rank("blood_frenzy"))
	var rune_damage := 0
	if round_number % 3 == 0:
		rune_damage = AbilityDatabase.effect_value("rune_bolt", "periodic_damage", _rank("rune_bolt"))
	var soul_damage := 0
	if _hero_attack_count % 3 == 0:
		soul_damage = AbilityDatabase.effect_value("soul_fire", "periodic_damage", _rank("soul_fire"))
	var hero_damage := base_damage + attack_bonus + conditional_bonus + rune_damage + soul_damage
	boss_hp = maxi(0, boss_hp - hero_damage)

	var healing_power := AbilityDatabase.effect_value("life_steal", "healing", _rank("life_steal"))
	var healing := mini(healing_power, int(hero["max_hp"]) - player_hp)
	player_hp += healing
	var hero_hp_after_heal := player_hp

	var blocked := 0
	var incoming_damage := 0
	if boss_hp > 0:
		_boss_attack_count += 1
		blocked = _bone_guard_reduction(_boss_attack_count)
		incoming_damage = maxi(0, BOSS_DAMAGE - blocked)
		player_hp = maxi(0, player_hp - incoming_damage)

	combat_result = {
		"hero_damage": hero_damage,
		"base_damage": base_damage,
		"attack_bonus": attack_bonus,
		"conditional_bonus": conditional_bonus,
		"rune_damage": rune_damage,
		"soul_damage": soul_damage,
		"healing": healing,
		"hero_hp_before": hero_hp_before,
		"hero_hp_after_heal": hero_hp_after_heal,
		"boss_damage": incoming_damage,
		"blocked": blocked,
		"hero_attack_count": _hero_attack_count,
		"boss_attack_count": _boss_attack_count,
	}
	audio_cue.emit("attack")

	if boss_hp <= 0:
		phase = "victory"
		result_text = "Der Aschenritter verursacht %d Schaden. Morvath ist besiegt!" % hero_damage
		audio_cue.emit("victory")
		_emit_state()
		return true

	if player_hp <= 0:
		phase = "defeat"
		result_text = "Der Aschenritter verursacht %d Schaden. Morvaths Gegenschlag besiegt dich." % hero_damage
		audio_cue.emit("defeat")
		_emit_state()
		return true

	result_text = "%s erreicht Rang %d. Angriff: %d, Gegenschlag: %d." % [selected_upgrade["name"], acquired_rank, hero_damage, incoming_damage]
	_emit_state()
	var sequence := _game_sequence
	if resolution_delay <= 0.0:
		_finish_round(sequence)
	else:
		get_tree().create_timer(resolution_delay).timeout.connect(
			func() -> void: _finish_round(sequence), CONNECT_ONE_SHOT
		)
	return true


func select_card(index: int, source: String = "pc") -> bool:
	return select_upgrade(index, source)


func get_snapshot() -> Dictionary:
	var public_hand: Array[Dictionary] = []
	for offer: Dictionary in hand:
		public_hand.append(offer.duplicate(true))
	var public_selected := selected_upgrade.duplicate(true)
	var hero_state := {
		"id": hero["id"],
		"name": hero["name"],
		"hp": player_hp,
		"max_hp": hero["max_hp"],
		"base_attack": hero["base_attack"],
		"artwork": hero["artwork"],
		"abilities": AbilityDatabase.active_abilities(ability_ranks),
	}
	return {
		"boss_hp": boss_hp,
		"boss_max_hp": BOSS_MAX_HP,
		"player_hp": player_hp,
		"player_max_hp": hero["max_hp"],
		"hero": hero_state,
		"round": round_number,
		"hand": public_hand,
		"selected_upgrade": public_selected,
		"combat": combat_result.duplicate(true),
		"result": result_text,
		"phase": phase,
		"can_select": phase == "awaiting_selection",
	}


func get_public_snapshot(include_private_hand: bool = false) -> Dictionary:
	var snapshot := get_snapshot()
	if not include_private_hand:
		snapshot["hand"] = []
	return snapshot


func force_hand_for_tests(ability_ids: Array[String]) -> void:
	hand.clear()
	for ability_id in ability_ids:
		var ability := AbilityDatabase.get_ability(ability_id)
		if not ability.is_empty():
			hand.append(AbilityDatabase.make_offer(ability, _rank(ability_id)))
	phase = "awaiting_selection"
	selected_upgrade = {}
	combat_result = {}
	_emit_state()


func set_health_for_tests(new_boss_hp: int, new_player_hp: int) -> void:
	boss_hp = clampi(new_boss_hp, 0, BOSS_MAX_HP)
	player_hp = clampi(new_player_hp, 0, int(hero["max_hp"]))
	_emit_state()


func set_ability_rank_for_tests(ability_id: String, rank: int) -> void:
	ability_ranks[ability_id] = clampi(rank, 0, AbilityDatabase.MAX_RANK)
	_emit_state()


func set_counters_for_tests(hero_attacks: int, boss_attacks: int) -> void:
	_hero_attack_count = maxi(0, hero_attacks)
	_boss_attack_count = maxi(0, boss_attacks)


func set_round_for_tests(value: int) -> void:
	round_number = maxi(1, value)


func finish_resolution_for_tests() -> void:
	_finish_round(_game_sequence)


func _draw_new_hand() -> void:
	hand = AbilityDatabase.draw_hand(_rng, ability_ranks, round_number, HAND_SIZE)


func _finish_round(sequence: int) -> void:
	if sequence != _game_sequence or phase != "resolving":
		return
	round_number += 1
	selected_upgrade = {}
	combat_result = {}
	result_text = "Wähle das nächste Upgrade."
	phase = "awaiting_selection"
	_draw_new_hand()
	audio_cue.emit("new_round")
	_emit_state()


func _rank(ability_id: String) -> int:
	return int(ability_ranks.get(ability_id, 0))


func _bone_guard_reduction(attack_number: int) -> int:
	var rank := _rank("bone_guard")
	if rank <= 0:
		return 0
	if rank == 1:
		return 1 if attack_number % 2 == 0 else 0
	if rank == 2:
		return 2 if attack_number % 2 == 0 else 0
	return 2 if attack_number % 2 == 0 else 1


func _emit_state() -> void:
	state_changed.emit(get_snapshot())
