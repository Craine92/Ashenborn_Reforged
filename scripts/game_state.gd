class_name GameState
extends Node

signal state_changed(snapshot: Dictionary)
signal audio_cue(cue: String)

const BOSS_MAX_HP := 30
const PLAYER_MAX_HP := 20
const BOSS_DAMAGE := 2
const HAND_SIZE := 3

var boss_hp := BOSS_MAX_HP
var player_hp := PLAYER_MAX_HP
var round_number := 1
var hand: Array[Dictionary] = []
var selected_card: Dictionary = {}
var result_text := "Wähle eine Kreatur."
var phase := "menu"
var resolution_delay := 1.35

var _rng := RandomNumberGenerator.new()
var _game_sequence := 0


func start_game(seed_value: int = -1) -> void:
	_game_sequence += 1
	if seed_value >= 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()
	boss_hp = BOSS_MAX_HP
	player_hp = PLAYER_MAX_HP
	round_number = 1
	selected_card = {}
	result_text = "Wähle eine Kreatur für den Angriff."
	phase = "awaiting_selection"
	_draw_new_hand()
	audio_cue.emit("start")
	_emit_state()


func return_to_menu() -> void:
	_game_sequence += 1
	phase = "menu"
	hand.clear()
	selected_card = {}
	result_text = ""
	_emit_state()


func select_card(index: int, _source: String = "pc") -> bool:
	if phase != "awaiting_selection":
		return false
	if index < 0 or index >= hand.size():
		return false

	phase = "resolving"
	selected_card = hand[index].duplicate(true)
	var damage: int = selected_card["attack"]
	boss_hp = maxi(0, boss_hp - damage)
	audio_cue.emit("attack")

	if boss_hp <= 0:
		phase = "victory"
		result_text = "%s trifft Morvath für %d Schaden. Morvath ist besiegt!" % [selected_card["name"], damage]
		audio_cue.emit("victory")
		_emit_state()
		return true

	player_hp = maxi(0, player_hp - BOSS_DAMAGE)
	if player_hp <= 0:
		phase = "defeat"
		result_text = "%s verursacht %d Schaden. Morvaths Gegenschlag besiegt dich." % [selected_card["name"], damage]
		audio_cue.emit("defeat")
		_emit_state()
		return true

	result_text = "%s trifft für %d. Morvath schlägt zurück: %d Schaden." % [selected_card["name"], damage, BOSS_DAMAGE]
	_emit_state()
	var sequence := _game_sequence
	if resolution_delay <= 0.0:
		_finish_round(sequence)
	else:
		get_tree().create_timer(resolution_delay).timeout.connect(
			func() -> void: _finish_round(sequence), CONNECT_ONE_SHOT
		)
	return true


func get_snapshot() -> Dictionary:
	var public_hand: Array[Dictionary] = []
	for card: Dictionary in hand:
		public_hand.append(CardDatabase.public_card(card))
	var public_selected := {}
	if not selected_card.is_empty():
		public_selected = CardDatabase.public_card(selected_card)
	return {
		"boss_hp": boss_hp,
		"boss_max_hp": BOSS_MAX_HP,
		"player_hp": player_hp,
		"player_max_hp": PLAYER_MAX_HP,
		"round": round_number,
		"hand": public_hand,
		"selected_card": public_selected,
		"result": result_text,
		"phase": phase,
		"can_select": phase == "awaiting_selection",
	}


func force_hand_for_tests(card_ids: Array[String]) -> void:
	hand.clear()
	for card_id in card_ids:
		hand.append(CardDatabase.get_card(card_id))
	phase = "awaiting_selection"
	_emit_state()


func set_health_for_tests(new_boss_hp: int, new_player_hp: int) -> void:
	boss_hp = clampi(new_boss_hp, 0, BOSS_MAX_HP)
	player_hp = clampi(new_player_hp, 0, PLAYER_MAX_HP)


func finish_resolution_for_tests() -> void:
	_finish_round(_game_sequence)


func _draw_new_hand() -> void:
	hand.clear()
	for _slot in HAND_SIZE:
		hand.append(CardDatabase.draw_card(_rng))


func _finish_round(sequence: int) -> void:
	if sequence != _game_sequence or phase != "resolving":
		return
	round_number += 1
	selected_card = {}
	result_text = "Neue Kreaturen sind bereit."
	phase = "awaiting_selection"
	_draw_new_hand()
	audio_cue.emit("new_round")
	_emit_state()


func _emit_state() -> void:
	state_changed.emit(get_snapshot())
