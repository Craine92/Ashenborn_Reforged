class_name BattleView
extends Control

signal card_selected(index: int)
signal menu_requested
signal restart_requested
signal connection_menu_requested
signal combat_audio(cue: String)
signal combat_sequence_started(card_name: String, boss_damage: int, player_damage: int)

var _round_label: Label
var _connection_button: Button
var _boss_hp_label: Label
var _boss_bar: ProgressBar
var _player_hp_label: Label
var _player_bar: ProgressBar
var _result_label: Label
var _hand_section: VBoxContainer
var _hand: HBoxContainer
var _test_mode_label: Label
var _end_panel: PanelContainer
var _end_title: Label
var _boss_visual: Control
var _boss_portrait: TextureRect
var _boss_attack_pose: TextureRect
var _boss_fx: TextureRect
var _boss_damage_label: Label
var _player_panel: PanelContainer
var _player_damage_label: Label
var _combat_overlay: Control
var _attacker_card: PanelContainer
var _attacker_art: TextureRect
var _attacker_name: Label
var _cards: Array[CreatureCardButton] = []
var _current_hand: Array = []
var _current_round := -1
var _can_select := false
var _pc_test_mode := false
var _connection_available := false
var _displayed_boss_hp := -1
var _displayed_player_hp := -1
var _sequence_id := 0
var _active_tweens: Array[Tween] = []


func _ready() -> void:
	_build()
	_apply_view_mode()


func set_pc_test_mode(enabled: bool) -> void:
	_pc_test_mode = enabled
	if is_node_ready():
		_apply_view_mode()


func is_pc_test_mode() -> bool:
	return _pc_test_mode


func set_connection_info(url: String, web_ok: bool) -> void:
	_connection_available = web_ok and not url.is_empty()
	if _connection_available:
		_connection_button.text = "○  VERBINDUNG"
		_connection_button.tooltip_text = "%s\nQR-Code und Status anzeigen" % url
	else:
		_connection_button.text = "!  VERBINDUNGSFEHLER"
		_connection_button.add_theme_color_override("font_color", UIStyle.RED)


func set_smartphone_connected(connected: bool) -> void:
	if not _connection_available:
		_connection_button.text = "!  VERBINDUNGSFEHLER"
		_connection_button.add_theme_color_override("font_color", UIStyle.RED)
		return
	if connected:
		_connection_button.text = "●  SMARTPHONE"
		_connection_button.add_theme_color_override("font_color", Color("55c271"))
	else:
		_connection_button.text = "○  VERBINDUNG"
		_connection_button.add_theme_color_override("font_color", UIStyle.TEXT)


func set_state(state: Dictionary) -> void:
	var round_number: int = state.get("round", 1)
	var phase: String = state.get("phase", "")
	var previous_round := _current_round
	_current_round = round_number
	_can_select = state.get("can_select", false)
	_current_hand = state.get("hand", [])
	_round_label.text = "RUNDE  %d" % round_number

	var boss_hp: int = state.get("boss_hp", 0)
	var player_hp: int = state.get("player_hp", 0)
	_boss_bar.max_value = state.get("boss_max_hp", 30)
	_player_bar.max_value = state.get("player_max_hp", 20)

	for index in _cards.size():
		_cards[index].visible = index < _current_hand.size()
		if index < _current_hand.size():
			_cards[index].set_card(index, _current_hand[index], _can_select)
			_cards[index].set_selected(false)

	if _displayed_boss_hp < 0:
		_displayed_boss_hp = boss_hp
		_displayed_player_hp = player_hp
		_set_boss_health(boss_hp)
		_set_player_health(player_hp)

	var selected: Dictionary = state.get("selected_card", {})
	var is_combat_event := phase in ["resolving", "victory", "defeat"] and not selected.is_empty()
	if is_combat_event:
		var old_boss_hp := _displayed_boss_hp
		var old_player_hp := _displayed_player_hp
		_end_panel.visible = false
		_play_combat_sequence(state, old_boss_hp, old_player_hp)
	elif phase == "awaiting_selection":
		_sequence_id += 1
		_reset_combat_visuals()
		_set_boss_health(boss_hp)
		_set_player_health(player_hp)
		_hand.visible = _pc_test_mode
		if previous_round > 0 and round_number != previous_round:
			_play_round_intro(round_number, _sequence_id)
		else:
			_show_status("WÄHLE DEINE KREATUR", UIStyle.CYAN)
		_end_panel.visible = false
	else:
		_sequence_id += 1
		_reset_combat_visuals()
		_set_boss_health(boss_hp)
		_set_player_health(player_hp)
		_show_status(state.get("result", ""), UIStyle.TEXT)
		_end_panel.visible = phase == "victory" or phase == "defeat"


func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := TextureRect.new()
	background.texture = load("res://assets/environments/board/board_main.png")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var shade := ColorRect.new()
	shade.color = Color("03050a78")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 8)
	margin.add_child(page)
	page.add_child(_build_top_bar())
	page.add_child(_build_encounter())
	page.add_child(_build_action_row())
	_hand_section = _build_hand()
	page.add_child(_hand_section)
	_build_combat_overlay()
	_build_end_panel()


func _build_top_bar() -> Control:
	var top := HBoxContainer.new()
	top.custom_minimum_size.y = 44
	var menu := Button.new()
	menu.text = "‹  HAUPTMENÜ"
	UIStyle.style_button(menu, UIStyle.GOLD)
	menu.custom_minimum_size = Vector2(205, 42)
	menu.pressed.connect(func() -> void: menu_requested.emit())
	top.add_child(menu)
	_round_label = Label.new()
	_round_label.text = "RUNDE  1"
	_round_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_round_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_round_label.add_theme_font_size_override("font_size", 22)
	_round_label.add_theme_color_override("font_color", UIStyle.GOLD)
	top.add_child(_round_label)
	_connection_button = Button.new()
	UIStyle.style_button(_connection_button, UIStyle.CYAN)
	_connection_button.custom_minimum_size = Vector2(225, 42)
	_connection_button.pressed.connect(func() -> void: connection_menu_requested.emit())
	top.add_child(_connection_button)
	return top


func _build_encounter() -> Control:
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.custom_minimum_size.y = 225
	row.add_theme_constant_override("separation", 18)

	var balance := Control.new()
	balance.custom_minimum_size.x = 245
	row.add_child(balance)

	var boss_group := HBoxContainer.new()
	boss_group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boss_group.add_theme_constant_override("separation", 12)
	row.add_child(boss_group)
	_boss_visual = Control.new()
	_boss_visual.custom_minimum_size = Vector2(250, 210)
	_boss_visual.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_boss_visual.pivot_offset = Vector2(125, 105)
	boss_group.add_child(_boss_visual)
	_boss_portrait = TextureRect.new()
	_boss_portrait.texture = load("res://assets/bosses/morvath/portrait.png")
	_boss_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_boss_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_boss_portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_boss_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_visual.add_child(_boss_portrait)
	_boss_attack_pose = TextureRect.new()
	_boss_attack_pose.texture = load("res://assets/bosses/morvath/phase_3_overlay1.png")
	_boss_attack_pose.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_boss_attack_pose.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_boss_attack_pose.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_boss_attack_pose.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_attack_pose.modulate.a = 0.0
	_boss_visual.add_child(_boss_attack_pose)
	_boss_fx = TextureRect.new()
	_boss_fx.texture = load("res://assets/bosses/morvath/fx_runecircle.png")
	_boss_fx.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_boss_fx.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_boss_fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_boss_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_fx.modulate.a = 0.0
	_boss_visual.add_child(_boss_fx)
	_boss_damage_label = _damage_label(UIStyle.GOLD)
	_boss_visual.add_child(_boss_damage_label)
	var boss_info := VBoxContainer.new()
	boss_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boss_info.alignment = BoxContainer.ALIGNMENT_CENTER
	boss_info.add_theme_constant_override("separation", 7)
	boss_group.add_child(boss_info)
	var name := Label.new()
	name.text = "MORVATH"
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.add_theme_font_size_override("font_size", 38)
	name.add_theme_color_override("font_color", UIStyle.CYAN)
	name.add_theme_color_override("font_shadow_color", Color("000000d0"))
	name.add_theme_constant_override("shadow_offset_x", 2)
	name.add_theme_constant_override("shadow_offset_y", 3)
	boss_info.add_child(name)
	var title := Label.new()
	title.text = "DER ASCHENKÖNIG"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", UIStyle.MUTED)
	boss_info.add_child(title)
	_boss_bar = _health_bar(UIStyle.CYAN, Vector2(390, 20))
	boss_info.add_child(_boss_bar)
	_boss_hp_label = _health_label(22)
	boss_info.add_child(_boss_hp_label)

	_player_panel = PanelContainer.new()
	_player_panel.custom_minimum_size.x = 245
	_player_panel.pivot_offset = Vector2(122, 105)
	_player_panel.add_theme_stylebox_override("panel", UIStyle.box(UIStyle.PANEL_SOFT, Color("7c654740"), 1, 10))
	row.add_child(_player_panel)
	var player_info := VBoxContainer.new()
	player_info.alignment = BoxContainer.ALIGNMENT_CENTER
	player_info.add_theme_constant_override("separation", 8)
	_player_panel.add_child(player_info)
	var you := Label.new()
	you.text = "DU"
	you.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	you.add_theme_font_size_override("font_size", 16)
	you.add_theme_color_override("font_color", UIStyle.MUTED)
	player_info.add_child(you)
	_player_hp_label = _health_label(27)
	player_info.add_child(_player_hp_label)
	_player_bar = _health_bar(UIStyle.RED, Vector2(190, 15))
	player_info.add_child(_player_bar)
	_player_damage_label = _damage_label(UIStyle.RED.lightened(0.18))
	_player_damage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_player_panel.add_child(_player_damage_label)
	return row


func _build_action_row() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = 54
	panel.add_theme_stylebox_override("panel", UIStyle.box(Color("0a0e15d0"), Color("6e5a4030"), 1, 8))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	panel.add_child(row)
	_result_label = Label.new()
	_result_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_result_label.add_theme_font_size_override("font_size", 20)
	_result_label.add_theme_color_override("font_color", UIStyle.CYAN)
	row.add_child(_result_label)
	return panel


func _build_hand() -> Control:
	var section := VBoxContainer.new()
	section.custom_minimum_size.y = 318
	section.add_theme_constant_override("separation", 4)
	_test_mode_label = Label.new()
	_test_mode_label.text = "PC-TESTANSICHT  ·  PRIVATE HAND"
	_test_mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_test_mode_label.add_theme_font_size_override("font_size", 14)
	_test_mode_label.add_theme_color_override("font_color", UIStyle.GOLD)
	section.add_child(_test_mode_label)
	_hand = HBoxContainer.new()
	_hand.alignment = BoxContainer.ALIGNMENT_CENTER
	_hand.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_hand.add_theme_constant_override("separation", 24)
	section.add_child(_hand)
	for _index in 3:
		var card := CreatureCardButton.new()
		card.pressed.connect(_on_card_pressed.bind(card))
		_cards.append(card)
		_hand.add_child(card)
	return section


func _apply_view_mode() -> void:
	if not is_instance_valid(_hand_section):
		return
	_hand_section.visible = _pc_test_mode
	_hand.visible = _pc_test_mode
	_boss_visual.custom_minimum_size = Vector2(250, 210) if _pc_test_mode else Vector2(300, 390)


func _on_card_pressed(card: CreatureCardButton) -> void:
	if not _can_select or card.card_index < 0 or card.card_index >= _current_hand.size():
		return
	var selected_index := card.card_index
	_can_select = false
	card.set_selected(true)
	for hand_card in _cards:
		hand_card.set_interactable(false)
	card_selected.emit(selected_index)


func _build_combat_overlay() -> void:
	_combat_overlay = Control.new()
	_combat_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_combat_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_combat_overlay.z_index = 20
	add_child(_combat_overlay)
	_attacker_card = PanelContainer.new()
	_attacker_card.custom_minimum_size = Vector2(230, 305)
	_attacker_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_attacker_card.modulate.a = 0.0
	_combat_overlay.add_child(_attacker_card)
	_attacker_card.size = Vector2(230, 305)
	_attacker_card.position = Vector2(100, 160)
	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_attacker_card.add_child(content)
	_attacker_art = TextureRect.new()
	_attacker_art.custom_minimum_size = Vector2(214, 250)
	_attacker_art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_attacker_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_attacker_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_attacker_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(_attacker_art)
	_attacker_name = Label.new()
	_attacker_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_attacker_name.add_theme_font_size_override("font_size", 20)
	_attacker_name.add_theme_color_override("font_color", UIStyle.TEXT)
	_attacker_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(_attacker_name)


func _play_combat_sequence(state: Dictionary, old_boss_hp: int, old_player_hp: int) -> void:
	_sequence_id += 1
	var sequence := _sequence_id
	_kill_active_tweens()
	var selected: Dictionary = state["selected_card"]
	var target_boss_hp: int = state["boss_hp"]
	var target_player_hp: int = state["player_hp"]
	var boss_damage := maxi(0, old_boss_hp - target_boss_hp)
	var player_damage := maxi(0, old_player_hp - target_player_hp)
	combat_sequence_started.emit(selected["name"], boss_damage, player_damage)
	for card in _cards:
		card.set_interactable(false)
	_hand.modulate = Color(1, 1, 1, 0.28)

	var full_card := CardDatabase.get_card(selected["id"])
	if not full_card.is_empty():
		_attacker_art.texture = load(full_card["artwork"])
	var rarity_color: Color = CardDatabase.RARITY_COLORS.get(selected["rarity"], UIStyle.CYAN)
	_attacker_card.add_theme_stylebox_override("panel", UIStyle.card_box(rarity_color, true, false))
	_attacker_name.text = String(selected["name"]).to_upper()
	var viewport_size := get_viewport_rect().size
	var attacker_start := Vector2(viewport_size.x * 0.08, viewport_size.y * 0.22)
	var attacker_ready := attacker_start + Vector2(50, 0)
	var attacker_impact := Vector2(viewport_size.x * 0.26, attacker_start.y)
	_attacker_card.position = attacker_start
	_attacker_card.scale = Vector2(0.88, 0.88)
	_attacker_card.modulate = Color(1, 1, 1, 0)
	_attacker_card.visible = true
	_show_status("%s GREIFT AN" % String(selected["name"]).to_upper(), rarity_color)

	var reveal := _new_tween()
	reveal.set_parallel(true)
	reveal.tween_property(_attacker_card, "modulate:a", 1.0, 0.16)
	reveal.tween_property(_attacker_card, "position", attacker_ready, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	reveal.tween_property(_attacker_card, "scale", Vector2.ONE, 0.16)
	await reveal.finished
	if sequence != _sequence_id:
		return

	var dash := _new_tween()
	dash.tween_property(_attacker_card, "position", attacker_impact, 0.17).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await dash.finished
	if sequence != _sequence_id:
		return
	combat_audio.emit("attack")
	_boss_fx.texture = load("res://assets/bosses/morvath/fx_runecircle.png")
	_boss_fx.modulate = Color(1.25, 1.25, 1.25, 1)
	_show_damage(_boss_damage_label, boss_damage)
	var boss_origin := _boss_visual.position
	var impact := _new_tween()
	impact.set_parallel(true)
	impact.tween_method(_set_boss_health_float, float(old_boss_hp), float(target_boss_hp), 0.24)
	impact.tween_property(_boss_fx, "modulate:a", 0.0, 0.24)
	impact.tween_property(_attacker_card, "modulate:a", 0.0, 0.20)
	var shake := _new_tween()
	shake.tween_property(_boss_visual, "position", boss_origin + Vector2(13, 0), 0.045)
	shake.tween_property(_boss_visual, "position", boss_origin - Vector2(10, 0), 0.055)
	shake.tween_property(_boss_visual, "position", boss_origin + Vector2(6, 0), 0.05)
	shake.tween_property(_boss_visual, "position", boss_origin, 0.06)
	await get_tree().create_timer(0.26).timeout
	if sequence != _sequence_id:
		return
	_attacker_card.visible = false

	if state["phase"] == "victory":
		_finish_outcome("victory", sequence)
		return

	_show_status("MORVATH SCHLÄGT ZURÜCK", UIStyle.RED.lightened(0.2))
	combat_audio.emit("boss_attack")
	_boss_fx.texture = load("res://assets/bosses/morvath/fx_skulls.png")
	_boss_fx.modulate = Color(1, 1, 1, 0)
	_boss_attack_pose.modulate = Color(1, 1, 1, 0)
	var windup := _new_tween()
	windup.set_parallel(true)
	windup.tween_property(_boss_attack_pose, "modulate:a", 1.0, 0.16)
	windup.tween_property(_boss_portrait, "modulate:a", 0.18, 0.16)
	windup.tween_property(_boss_fx, "modulate:a", 0.92, 0.16)
	windup.tween_property(_boss_visual, "scale", Vector2(1.08, 1.08), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await windup.finished
	if sequence != _sequence_id:
		return

	_show_damage(_player_damage_label, player_damage, Vector2(18, -26))
	var player_origin := _player_panel.position
	var retaliation := _new_tween()
	retaliation.set_parallel(true)
	retaliation.tween_method(_set_player_health_float, float(old_player_hp), float(target_player_hp), 0.22)
	retaliation.tween_property(_player_panel, "modulate", Color(1, 0.42, 0.42, 1), 0.07)
	var player_shake := _new_tween()
	player_shake.tween_property(_player_panel, "position", player_origin + Vector2(10, 0), 0.045)
	player_shake.tween_property(_player_panel, "position", player_origin - Vector2(8, 0), 0.055)
	player_shake.tween_property(_player_panel, "position", player_origin, 0.07)
	await get_tree().create_timer(0.23).timeout
	if sequence != _sequence_id:
		return

	var recover := _new_tween()
	recover.set_parallel(true)
	recover.tween_property(_player_panel, "modulate", Color.WHITE, 0.10)
	recover.tween_property(_boss_attack_pose, "modulate:a", 0.0, 0.10)
	recover.tween_property(_boss_portrait, "modulate:a", 1.0, 0.10)
	recover.tween_property(_boss_fx, "modulate:a", 0.0, 0.10)
	recover.tween_property(_boss_visual, "scale", Vector2.ONE, 0.10)
	await recover.finished
	if sequence != _sequence_id:
		return
	if state["phase"] == "defeat":
		_finish_outcome("defeat", sequence)


func _play_round_intro(round_number: int, sequence: int) -> void:
	_hand.modulate = Color(1, 1, 1, 0)
	_show_status("RUNDE %d" % round_number, UIStyle.GOLD)
	var reveal := _new_tween()
	reveal.tween_property(_hand, "modulate:a", 1.0, 0.28)
	await get_tree().create_timer(0.42).timeout
	if sequence == _sequence_id:
		_show_status("WÄHLE DEINE KREATUR", UIStyle.CYAN)


func _finish_outcome(phase: String, sequence: int) -> void:
	if sequence != _sequence_id:
		return
	_hand.modulate = Color(1, 1, 1, 0.25)
	if phase == "victory":
		_end_title.text = "MORVATH IST BESIEGT"
		_end_title.add_theme_color_override("font_color", UIStyle.GOLD)
		_show_status("SIEG", UIStyle.GOLD)
		combat_audio.emit("victory")
	else:
		_end_title.text = "DU BIST GEFALLEN"
		_end_title.add_theme_color_override("font_color", UIStyle.RED)
		_show_status("NIEDERLAGE", UIStyle.RED)
		combat_audio.emit("defeat")
	_end_panel.visible = true


func _show_status(message: String, color: Color) -> void:
	_result_label.text = message
	_result_label.add_theme_color_override("font_color", color)


func _show_damage(label: Label, damage: int, start_offset := Vector2.ZERO) -> void:
	label.text = "−%d" % damage
	label.position = start_offset
	label.modulate = Color.WHITE
	var tween := _new_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", start_offset.y - 34.0, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.42).set_delay(0.12)


func _set_boss_health(value: int) -> void:
	_displayed_boss_hp = value
	_boss_bar.value = value
	_boss_hp_label.text = "%d  /  %d" % [value, int(_boss_bar.max_value)]


func _set_player_health(value: int) -> void:
	_displayed_player_hp = value
	_player_bar.value = value
	_player_hp_label.text = "%d / %d" % [value, int(_player_bar.max_value)]


func _set_boss_health_float(value: float) -> void:
	_set_boss_health(roundi(value))


func _set_player_health_float(value: float) -> void:
	_set_player_health(roundi(value))


func _reset_combat_visuals() -> void:
	_kill_active_tweens()
	_attacker_card.visible = false
	_boss_fx.modulate.a = 0.0
	_boss_attack_pose.modulate.a = 0.0
	_boss_portrait.modulate = Color.WHITE
	_boss_visual.scale = Vector2.ONE
	_player_panel.modulate = Color.WHITE
	_boss_damage_label.modulate.a = 0.0
	_player_damage_label.modulate.a = 0.0
	_hand.modulate = Color.WHITE


func _new_tween() -> Tween:
	var tween := create_tween()
	_active_tweens.append(tween)
	return tween


func _kill_active_tweens() -> void:
	for tween in _active_tweens:
		if tween.is_valid():
			tween.kill()
	_active_tweens.clear()


func _damage_label(color: Color) -> Label:
	var label := Label.new()
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 40)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color("000000e0"))
	label.add_theme_constant_override("shadow_offset_x", 3)
	label.add_theme_constant_override("shadow_offset_y", 3)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.modulate.a = 0.0
	return label


func _build_end_panel() -> void:
	_end_panel = PanelContainer.new()
	_end_panel.custom_minimum_size = Vector2(500, 238)
	_end_panel.add_theme_stylebox_override("panel", UIStyle.box(UIStyle.PANEL_SOLID, UIStyle.GOLD, 2, 12))
	_end_panel.set_anchors_preset(Control.PRESET_CENTER)
	_end_panel.position = Vector2(-250, -119)
	_end_panel.visible = false
	add_child(_end_panel)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 16)
	_end_panel.add_child(column)
	_end_title = Label.new()
	_end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_title.add_theme_font_size_override("font_size", 30)
	column.add_child(_end_title)
	var restart := Button.new()
	restart.text = "ERNEUT ANTRETEN"
	UIStyle.style_button(restart, UIStyle.GOLD)
	restart.pressed.connect(func() -> void: restart_requested.emit())
	column.add_child(restart)
	var menu := Button.new()
	menu.text = "HAUPTMENÜ"
	UIStyle.style_button(menu)
	menu.pressed.connect(func() -> void: menu_requested.emit())
	column.add_child(menu)


func _health_bar(color: Color, minimum: Vector2) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = minimum
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background", UIStyle.box(Color("080b10f0"), Color("4d586750"), 1, 6))
	bar.add_theme_stylebox_override("fill", UIStyle.box(color.darkened(0.12), color.lightened(0.15), 1, 6))
	return bar


func _health_label(font_size: int) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", UIStyle.TEXT)
	return label
