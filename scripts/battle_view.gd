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
var _hero_art: TextureRect
var _hero_name_label: Label
var _abilities_label: Label
var _result_label: Label
var _hand_section: VBoxContainer
var _hand: HBoxContainer
var _test_mode_label: Label
var _end_panel: PanelContainer
var _end_title: Label
var _boss_visual: Control
var _boss_portrait: TextureRect
var _boss_animator: BossAnimator
var _boss_fx: TextureRect
var _boss_damage_label: Label
var _player_panel: PanelContainer
var _secondary_player_panel: PanelContainer
var _secondary_name_label: Label
var _secondary_hp_label: Label
var _secondary_bar: ProgressBar
var _secondary_abilities_label: Label
var _secondary_status_label: Label
var _player_status_label: Label
var _player_damage_label: Label
var _hero_heal_label: Label
var _block_label: Label
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
var _smartphone_connected := false
var _displayed_boss_hp := -1
var _displayed_player_hp := -1
var _displayed_player_hps: Dictionary = {}
var _primary_display_player_id := GameState.DEFAULT_PLAYER_ID
var _sequence_id := 0
var _active_tweens: Array[Tween] = []


func _ready() -> void:
	_build()
	_apply_view_mode()


func set_pc_test_mode(enabled: bool) -> void:
	_pc_test_mode = enabled
	if is_node_ready():
		_apply_view_mode()
		_refresh_connection_button()


func is_pc_test_mode() -> bool:
	return _pc_test_mode


func set_connection_info(url: String, web_ok: bool) -> void:
	_connection_available = web_ok and not url.is_empty()
	_connection_button.tooltip_text = "%s\nQR-Code und Status anzeigen" % url if _connection_available else "Netzwerkserver oder WLAN-Adresse nicht verfügbar"
	_refresh_connection_button()


func set_smartphone_connected(connected: bool) -> void:
	_smartphone_connected = connected
	_refresh_connection_button()


func _refresh_connection_button() -> void:
	if not is_instance_valid(_connection_button):
		return
	if _pc_test_mode:
		_connection_button.text = "PC-TEST · OFFLINE BEREIT"
		_connection_button.add_theme_color_override("font_color", UIStyle.CYAN)
	elif not _connection_available:
		_connection_button.text = "!  NETZWERKFEHLER"
		_connection_button.add_theme_color_override("font_color", UIStyle.RED)
	elif _smartphone_connected:
		_connection_button.text = "●  SMARTPHONE VERBUNDEN"
		_connection_button.add_theme_color_override("font_color", Color("55c271"))
	else:
		_connection_button.text = "○  KEIN SMARTPHONE"
		_connection_button.add_theme_color_override("font_color", UIStyle.GOLD)


func set_state(state: Dictionary) -> void:
	var round_number: int = state.get("round", 1)
	var phase: String = state.get("phase", "")
	var previous_round := _current_round
	_current_round = round_number
	_can_select = state.get("can_select", false)
	_current_hand = state.get("hand", [])
	_round_label.text = "RUNDE  %d" % round_number

	var boss_hp: int = state.get("boss_hp", 0)
	var state_players: Array = state.get("players", [])
	if state_players.is_empty():
		state_players = [{
			"id": GameState.DEFAULT_PLAYER_ID,
			"display_name": "Spieler 1",
			"hp": state.get("player_hp", 0),
			"max_hp": state.get("player_max_hp", 20),
			"connected": true,
			"alive": state.get("player_hp", 0) > 0,
			"ready": false,
			"hero": state.get("hero", {}),
		}]
	var primary_player: Dictionary = state_players[0]
	var hero_state: Dictionary = primary_player.get("hero", state.get("hero", {}))
	var player_hp: int = primary_player.get("hp", state.get("player_hp", 0))
	_boss_bar.max_value = state.get("boss_max_hp", 30)
	_update_player_displays(state_players)

	for index in _cards.size():
		_cards[index].visible = index < _current_hand.size()
		if index < _current_hand.size():
			_cards[index].set_card(index, _current_hand[index], _can_select)
			_cards[index].set_selected(false)

	if _displayed_boss_hp < 0:
		_displayed_boss_hp = boss_hp
		_displayed_player_hp = player_hp
		_set_boss_health(boss_hp)
		for player: Dictionary in state_players:
			_set_player_health_for_id(String(player.get("id", "")), int(player.get("hp", 0)))

	var selected: Dictionary = state.get("selected_upgrade", {})
	var combat_attacks: Array = state.get("combat", {}).get("attacks", [])
	var is_combat_event := phase in ["resolving", "victory", "defeat"] and (not selected.is_empty() or not combat_attacks.is_empty())
	if is_combat_event:
		var old_boss_hp := _displayed_boss_hp
		var old_player_hp := _displayed_player_hp
		_end_panel.visible = false
		if state_players.size() > 1:
			_play_coop_combat_sequence(state, old_boss_hp)
		else:
			_play_combat_sequence(state, old_boss_hp, old_player_hp)
	elif phase == "awaiting_selection":
		_sequence_id += 1
		_reset_combat_visuals()
		_set_boss_health(boss_hp)
		for player: Dictionary in state_players:
			_set_player_health_for_id(String(player.get("id", "")), int(player.get("hp", 0)))
		_hand.visible = _pc_test_mode
		if previous_round > 0 and round_number != previous_round:
			_play_round_intro(round_number, _sequence_id)
		else:
			_show_ready_status(state)
		_end_panel.visible = false
	else:
		_sequence_id += 1
		_reset_combat_visuals()
		_set_boss_health(boss_hp)
		for player: Dictionary in state_players:
			_set_player_health_for_id(String(player.get("id", "")), int(player.get("hp", 0)))
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
	_secondary_player_panel = _build_secondary_player_panel()
	_secondary_player_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_secondary_player_panel.visible = false
	balance.add_child(_secondary_player_panel)

	var boss_group := HBoxContainer.new()
	boss_group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boss_group.add_theme_constant_override("separation", 12)
	row.add_child(boss_group)
	_boss_visual = Control.new()
	_boss_visual.custom_minimum_size = Vector2(250, 210)
	_boss_visual.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_boss_visual.pivot_offset = Vector2(125, 105)
	boss_group.add_child(_boss_visual)
	_boss_animator = BossAnimator.new()
	_boss_portrait = _boss_animator
	_boss_portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_boss_visual.add_child(_boss_portrait)
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
	_hero_name_label = Label.new()
	_hero_name_label.text = "ASCHENRITTER"
	_hero_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hero_name_label.add_theme_font_size_override("font_size", 18)
	_hero_name_label.add_theme_color_override("font_color", UIStyle.GOLD)
	player_info.add_child(_hero_name_label)
	_hero_art = TextureRect.new()
	_hero_art.texture = load(HeroDatabase.ASH_KNIGHT["artwork"])
	_hero_art.custom_minimum_size = Vector2(120, 145)
	_hero_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hero_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_hero_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player_info.add_child(_hero_art)
	_player_hp_label = _health_label(27)
	player_info.add_child(_player_hp_label)
	_player_bar = _health_bar(UIStyle.RED, Vector2(190, 15))
	player_info.add_child(_player_bar)
	_abilities_label = Label.new()
	_abilities_label.text = "NOCH KEINE UPGRADES"
	_abilities_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_abilities_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_abilities_label.custom_minimum_size = Vector2(205, 62)
	_abilities_label.add_theme_font_size_override("font_size", 12)
	_abilities_label.add_theme_color_override("font_color", UIStyle.MUTED)
	player_info.add_child(_abilities_label)
	_player_status_label = Label.new()
	_player_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_player_status_label.add_theme_font_size_override("font_size", 12)
	_player_status_label.add_theme_color_override("font_color", UIStyle.CYAN)
	player_info.add_child(_player_status_label)
	_player_damage_label = _damage_label(UIStyle.RED.lightened(0.18))
	_player_damage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_player_panel.add_child(_player_damage_label)
	_hero_heal_label = _damage_label(Color("61d884"))
	_hero_heal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_player_panel.add_child(_hero_heal_label)
	_block_label = _damage_label(UIStyle.CYAN)
	_block_label.add_theme_font_size_override("font_size", 24)
	_player_panel.add_child(_block_label)
	return row


func _build_secondary_player_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIStyle.box(UIStyle.PANEL_SOFT, Color("526d8540"), 1, 10))
	var info := VBoxContainer.new()
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 7)
	panel.add_child(info)
	_secondary_name_label = Label.new()
	_secondary_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_secondary_name_label.add_theme_font_size_override("font_size", 18)
	_secondary_name_label.add_theme_color_override("font_color", UIStyle.GOLD)
	info.add_child(_secondary_name_label)
	var art := TextureRect.new()
	art.texture = load(HeroDatabase.ASH_KNIGHT["artwork"])
	art.custom_minimum_size = Vector2(120, 112)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(art)
	_secondary_hp_label = _health_label(25)
	info.add_child(_secondary_hp_label)
	_secondary_bar = _health_bar(UIStyle.RED, Vector2(190, 15))
	info.add_child(_secondary_bar)
	_secondary_abilities_label = Label.new()
	_secondary_abilities_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_secondary_abilities_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_secondary_abilities_label.custom_minimum_size = Vector2(205, 48)
	_secondary_abilities_label.add_theme_font_size_override("font_size", 11)
	_secondary_abilities_label.add_theme_color_override("font_color", UIStyle.MUTED)
	info.add_child(_secondary_abilities_label)
	_secondary_status_label = Label.new()
	_secondary_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_secondary_status_label.add_theme_font_size_override("font_size", 12)
	_secondary_status_label.add_theme_color_override("font_color", UIStyle.CYAN)
	info.add_child(_secondary_status_label)
	return panel


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
	_test_mode_label.text = "PC-TESTANSICHT  ·  PRIVATE UPGRADE-HAND"
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
	_hero_art.custom_minimum_size = Vector2(70, 58) if _pc_test_mode else Vector2(120, 145)
	_abilities_label.custom_minimum_size.y = 38 if _pc_test_mode else 62


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
	_attacker_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
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
	var selected: Dictionary = state["selected_upgrade"]
	var combat: Dictionary = state.get("combat", {})
	var target_boss_hp: int = state["boss_hp"]
	var target_player_hp: int = state["player_hp"]
	var boss_damage := int(combat.get("hero_damage", maxi(0, old_boss_hp - target_boss_hp)))
	var player_damage := int(combat.get("boss_damage", maxi(0, old_player_hp - target_player_hp)))
	var healing := int(combat.get("healing", 0))
	var blocked := int(combat.get("blocked", 0))
	var hp_after_heal := int(combat.get("hero_hp_after_heal", old_player_hp))
	combat_sequence_started.emit(selected["name"], boss_damage, player_damage)
	for card in _cards:
		card.set_interactable(false)
	_hand.modulate = Color(1, 1, 1, 0.28)

	_attacker_art.texture = load(HeroDatabase.ASH_KNIGHT["artwork"])
	var rarity_color: Color = AbilityDatabase.RARITY_COLORS.get(selected["rarity"], UIStyle.CYAN)
	_attacker_card.add_theme_stylebox_override("panel", UIStyle.card_box(rarity_color, true, false))
	_attacker_name.text = "ASCHENRITTER"
	var viewport_size := get_viewport_rect().size
	var attacker_start := Vector2(viewport_size.x * 0.08, viewport_size.y * 0.22)
	var attacker_ready := attacker_start + Vector2(50, 0)
	var attacker_impact := Vector2(viewport_size.x * 0.26, attacker_start.y)
	_attacker_card.position = attacker_start
	_attacker_card.scale = Vector2(0.88, 0.88)
	_attacker_card.modulate = Color(1, 1, 1, 0)
	_attacker_card.visible = true
	var upgrade_message := "%s FREIGESCHALTET" % String(selected["name"]).to_upper()
	if not selected.get("unlocked", false):
		upgrade_message = "%s – RANG %d" % [String(selected["name"]).to_upper(), int(selected.get("acquired_rank", 1))]
	_show_status(upgrade_message, rarity_color)

	var reveal := _new_tween()
	reveal.set_parallel(true)
	reveal.tween_property(_attacker_card, "modulate:a", 1.0, 0.16)
	reveal.tween_property(_attacker_card, "position", attacker_ready, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	reveal.tween_property(_attacker_card, "scale", Vector2.ONE, 0.16)
	await reveal.finished
	if sequence != _sequence_id:
		return
	_show_status("ASCHENRITTER GREIFT AN", UIStyle.GOLD)

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
	await _boss_animator.play_once("hit_reaction")
	if sequence != _sequence_id:
		return
	_attacker_card.visible = false
	_show_triggered_effects(combat.get("triggered_effects", []), "")
	if healing > 0:
		_show_status("LEBENSRAUB  +%d LP" % healing, Color("61d884"))
		_show_value(_hero_heal_label, "+%d" % healing, Vector2(-18, -20))
		var healing_tween := _new_tween()
		healing_tween.tween_method(_set_player_health_float, float(old_player_hp), float(hp_after_heal), 0.16)
		await healing_tween.finished
		if sequence != _sequence_id:
			return

	if state["phase"] == "victory":
		_show_status("MORVATH ZERFÄLLT", UIStyle.GOLD)
		await _boss_animator.play_death()
		if sequence != _sequence_id:
			return
		_finish_outcome("victory", sequence)
		return

	_show_status("MORVATH LÄDT SEINE MAGIE", UIStyle.RED.lightened(0.2))
	await _boss_animator.play_once("energy_charge", false)
	if sequence != _sequence_id:
		return
	_show_status("MORVATH SCHLÄGT ZURÜCK", UIStyle.RED.lightened(0.2))
	combat_audio.emit("boss_attack")
	await _boss_animator.play_once("skull_swarm" if int(state.get("round", 1)) % 2 == 0 else "spell_blast")
	if sequence != _sequence_id:
		return

	if blocked > 0:
		_show_value(_block_label, "SCHUTZ −%d" % blocked, Vector2(0, 46))
	if player_damage > 0:
		_show_damage(_player_damage_label, player_damage, Vector2(18, -26))
	else:
		_show_value(_player_damage_label, "BLOCKIERT", Vector2(16, -26))
	var player_origin := _player_panel.position
	var retaliation := _new_tween()
	retaliation.set_parallel(true)
	retaliation.tween_method(_set_player_health_float, float(hp_after_heal), float(target_player_hp), 0.22)
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
	recover.tween_property(_boss_fx, "modulate:a", 0.0, 0.10)
	recover.tween_property(_boss_visual, "scale", Vector2.ONE, 0.10)
	await recover.finished
	if sequence != _sequence_id:
		return
	if state["phase"] == "defeat":
		_finish_outcome("defeat", sequence)


func _play_coop_combat_sequence(state: Dictionary, old_boss_hp: int) -> void:
	_sequence_id += 1
	var sequence := _sequence_id
	_kill_active_tweens()
	for card in _cards:
		card.set_interactable(false)
	_hand.modulate = Color(1, 1, 1, 0.28)
	var combat: Dictionary = state.get("combat", {})
	var attacks: Array = combat.get("attacks", [])
	for attack: Dictionary in attacks:
		if sequence != _sequence_id:
			return
		var upgrade: Dictionary = attack.get("selected_upgrade", {})
		var player_name := String(attack.get("display_name", "ASCHENRITTER")).to_upper()
		var player_color := _player_color_for_id(state.get("players", []), String(attack.get("player_id", "")))
		var damage := int(attack.get("hero_damage", 0))
		combat_sequence_started.emit(String(upgrade.get("name", "Upgrade")), damage, 0)
		_attacker_art.texture = load(HeroDatabase.ASH_KNIGHT["artwork"])
		_attacker_card.add_theme_stylebox_override("panel", UIStyle.card_box(player_color, true, false))
		_attacker_name.text = "%s · ASCHENRITTER" % player_name
		var viewport_size := get_viewport_rect().size
		var start := Vector2(viewport_size.x * 0.08, viewport_size.y * 0.22)
		var impact_position := Vector2(viewport_size.x * 0.27, start.y)
		_attacker_card.position = start
		_attacker_card.scale = Vector2(0.9, 0.9)
		_attacker_card.modulate = Color(1, 1, 1, 0)
		_attacker_card.visible = true
		var rank_text := "FREIGESCHALTET" if upgrade.get("unlocked", false) else "RANG %d" % int(upgrade.get("acquired_rank", 1))
		_show_status("%s · %s %s" % [player_name, String(upgrade.get("name", "UPGRADE")).to_upper(), rank_text], player_color)
		var reveal := _new_tween()
		reveal.set_parallel(true)
		reveal.tween_property(_attacker_card, "modulate:a", 1.0, 0.12)
		reveal.tween_property(_attacker_card, "scale", Vector2.ONE, 0.12)
		await reveal.finished
		if sequence != _sequence_id:
			return
		_show_status("%s GREIFT AN" % player_name, UIStyle.GOLD)
		var dash := _new_tween()
		dash.tween_property(_attacker_card, "position", impact_position, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await dash.finished
		if sequence != _sequence_id:
			return
		combat_audio.emit("attack")
		_show_damage(_boss_damage_label, damage)
		var boss_before := int(attack.get("boss_hp_before", old_boss_hp))
		var boss_after := int(attack.get("boss_hp_after", boss_before - damage))
		var impact := _new_tween()
		impact.set_parallel(true)
		impact.tween_method(_set_boss_health_float, float(boss_before), float(boss_after), 0.20)
		impact.tween_property(_attacker_card, "modulate:a", 0.0, 0.18)
		await _boss_animator.play_once("hit_reaction")
		if sequence != _sequence_id:
			return
		_attacker_card.visible = false
		_show_triggered_effects(attack.get("triggered_effects", []), player_name)
		var healing := int(attack.get("healing", 0))
		if healing > 0:
			_show_status("%s · LEBENSRAUB +%d LP" % [player_name, healing], Color("61d884"))
			_set_player_health_for_id(String(attack.get("player_id", "")), int(attack.get("hero_hp_after_heal", 0)))
			await get_tree().create_timer(0.12).timeout

	if state.get("phase", "") == "victory":
		_show_status("MORVATH ZERFÄLLT", UIStyle.GOLD)
		await _boss_animator.play_death()
		if sequence != _sequence_id:
			return
		_finish_outcome("victory", sequence)
		return
	_show_status("MORVATH LÄDT SEINE MAGIE", UIStyle.RED.lightened(0.2))
	await _boss_animator.play_once("energy_charge", false)
	if sequence != _sequence_id:
		return
	_show_status("MORVATH SCHLÄGT EINMAL ZURÜCK", UIStyle.RED.lightened(0.2))
	combat_audio.emit("boss_attack")
	await _boss_animator.play_once("skull_swarm" if int(state.get("round", 1)) % 2 == 0 else "spell_blast")
	if sequence != _sequence_id:
		return
	for target: Dictionary in combat.get("boss_targets", []):
		if sequence != _sequence_id:
			return
		var player_id := String(target.get("player_id", ""))
		var damage := int(target.get("boss_damage", 0))
		var blocked := int(target.get("blocked", 0))
		var message := "%s · −%d LP" % [String(target.get("display_name", "SPIELER")).to_upper(), damage]
		if blocked > 0:
			message += " · SCHUTZ −%d" % blocked
		_show_status(message, UIStyle.RED.lightened(0.2))
		_set_player_health_for_id(player_id, int(target.get("hp_after", 0)))
		var target_panel: Control = _player_panel if player_id == GameState.DEFAULT_PLAYER_ID else _secondary_player_panel
		var flash := _new_tween()
		flash.tween_property(target_panel, "modulate", Color(1, 0.42, 0.42, 1), 0.06)
		flash.tween_property(target_panel, "modulate", Color.WHITE, 0.10)
		await flash.finished
	var recover := _new_tween()
	recover.set_parallel(true)
	recover.tween_property(_boss_fx, "modulate:a", 0.0, 0.10)
	await recover.finished
	if state.get("phase", "") == "defeat":
		_finish_outcome("defeat", sequence)


func _play_round_intro(round_number: int, sequence: int) -> void:
	_hand.modulate = Color(1, 1, 1, 0)
	_show_status("RUNDE %d" % round_number, UIStyle.GOLD)
	var reveal := _new_tween()
	reveal.tween_property(_hand, "modulate:a", 1.0, 0.28)
	await get_tree().create_timer(0.42).timeout
	if sequence == _sequence_id:
		_show_status("WÄHLT EURE UPGRADES" if _secondary_player_panel.visible else "WÄHLE EIN UPGRADE", UIStyle.CYAN)


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
		_end_title.text = "DIE GRUPPE IST GEFALLEN"
		_end_title.add_theme_color_override("font_color", UIStyle.RED)
		_show_status("NIEDERLAGE", UIStyle.RED)
		combat_audio.emit("defeat")
	_end_panel.visible = true


func _show_status(message: String, color: Color) -> void:
	_result_label.text = message
	_result_label.add_theme_color_override("font_color", color)


func _show_ready_status(state: Dictionary) -> void:
	var required := int(state.get("required_ready_count", 1))
	var ready := int(state.get("ready_count", 0))
	if required > 1 or ready > 0:
		_show_status("%d/%d BEREIT · WÄHLT EURE UPGRADES" % [ready, required], UIStyle.CYAN)
	elif required == 1:
		_show_status("WÄHLE EIN UPGRADE", UIStyle.CYAN)
	else:
		_show_status("WARTE AUF SMARTPHONE-VERBINDUNG", UIStyle.GOLD)


func _update_player_displays(state_players: Array) -> void:
	if state_players.is_empty():
		return
	var primary: Dictionary = state_players[0]
	_primary_display_player_id = String(primary.get("id", GameState.DEFAULT_PLAYER_ID))
	var primary_hero: Dictionary = primary.get("hero", {})
	var primary_color := Color(String(primary.get("color", "4b91e2")))
	_hero_name_label.text = "%s · %s" % [String(primary.get("display_name", "Spieler 1")).to_upper(), String(primary_hero.get("name", "Aschenritter")).to_upper()]
	_hero_name_label.add_theme_color_override("font_color", primary_color)
	_player_panel.add_theme_stylebox_override("panel", UIStyle.box(UIStyle.PANEL_SOFT, primary_color.darkened(0.2), 2, 10))
	_player_bar.max_value = primary.get("max_hp", 20)
	_player_bar.add_theme_stylebox_override("fill", UIStyle.box(primary_color.darkened(0.16), primary_color.lightened(0.15), 1, 6))
	_update_active_abilities(primary_hero.get("abilities", []))
	_player_status_label.text = _player_status(primary)
	_player_status_label.add_theme_color_override("font_color", _player_status_color(primary))
	_secondary_player_panel.visible = state_players.size() > 1
	if state_players.size() > 1:
		var secondary: Dictionary = state_players[1]
		var secondary_color := Color(String(secondary.get("color", "a868e8")))
		_secondary_name_label.text = "%s · ASCHENRITTER" % String(secondary.get("display_name", "Spieler 2")).to_upper()
		_secondary_name_label.add_theme_color_override("font_color", secondary_color)
		_secondary_player_panel.add_theme_stylebox_override("panel", UIStyle.box(UIStyle.PANEL_SOFT, secondary_color.darkened(0.2), 2, 10))
		_secondary_bar.max_value = secondary.get("max_hp", 20)
		_secondary_bar.add_theme_stylebox_override("fill", UIStyle.box(secondary_color.darkened(0.16), secondary_color.lightened(0.15), 1, 6))
		_secondary_abilities_label.text = _abilities_text(secondary.get("hero", {}).get("abilities", []))
		_secondary_status_label.text = _player_status(secondary)
		_secondary_status_label.add_theme_color_override("font_color", _player_status_color(secondary))


func _player_status(player: Dictionary) -> String:
	if not player.get("alive", false):
		return "GEFALLEN"
	if not player.get("connected", false):
		return "VERBINDUNG GETRENNT"
	return "BEREIT" if player.get("ready", false) else "WÄHLT"


func _player_status_color(player: Dictionary) -> Color:
	if not player.get("alive", false):
		return UIStyle.RED
	if not player.get("connected", false):
		return UIStyle.GOLD
	return Color(String(player.get("color", "55cfe4")))


func _abilities_text(abilities: Array) -> String:
	if abilities.is_empty():
		return "NOCH KEINE UPGRADES"
	var entries: PackedStringArray = []
	for ability: Dictionary in abilities:
		entries.append("%s R%d" % [ability.get("name", ""), int(ability.get("rank", 0))])
	return "AKTIVE UPGRADES\n" + "  ·  ".join(entries)


func _update_active_abilities(abilities: Array) -> void:
	_abilities_label.text = _abilities_text(abilities)


func _show_triggered_effects(effects: Array, player_name: String) -> void:
	if effects.is_empty():
		return
	var prefix := "" if player_name.is_empty() else player_name + " · "
	_show_status(prefix + " · ".join(PackedStringArray(effects)), UIStyle.CYAN)


func _player_color_for_id(state_players: Array, player_id: String) -> Color:
	for player: Dictionary in state_players:
		if player.get("id", "") == player_id:
			return Color(String(player.get("color", "55cfe4")))
	return UIStyle.CYAN


func _show_value(label: Label, value: String, start_offset := Vector2.ZERO) -> void:
	label.text = value
	label.position = start_offset
	label.modulate = Color.WHITE
	var tween := _new_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", start_offset.y - 26.0, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.42).set_delay(0.12)


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
	_displayed_player_hps[_primary_display_player_id] = value
	_player_bar.value = value
	_player_hp_label.text = "%d / %d" % [value, int(_player_bar.max_value)]


func _set_player_health_for_id(player_id: String, value: int) -> void:
	_displayed_player_hps[player_id] = value
	if player_id == _primary_display_player_id or player_id.is_empty():
		_set_player_health(value)
		return
	_secondary_bar.value = value
	_secondary_hp_label.text = "%d / %d" % [value, int(_secondary_bar.max_value)]


func _set_boss_health_float(value: float) -> void:
	_set_boss_health(roundi(value))


func _set_player_health_float(value: float) -> void:
	_set_player_health(roundi(value))


func _reset_combat_visuals() -> void:
	_kill_active_tweens()
	_attacker_card.visible = false
	_boss_fx.modulate.a = 0.0
	_boss_portrait.modulate = Color.WHITE
	_boss_animator.cancel_and_idle()
	_boss_visual.scale = Vector2.ONE
	_player_panel.modulate = Color.WHITE
	_secondary_player_panel.modulate = Color.WHITE
	_boss_damage_label.modulate.a = 0.0
	_player_damage_label.modulate.a = 0.0
	_hero_heal_label.modulate.a = 0.0
	_block_label.modulate.a = 0.0
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
