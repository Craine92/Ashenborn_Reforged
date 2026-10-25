class_name CreatureCardButton
extends Button

var card_index := -1
var _art: TextureRect
var _name_label: Label
var _description_label: Label
var _rarity_label: Label
var _rank_label: Label
var _rarity_color := UIStyle.CYAN
var _selected := false


func _init() -> void:
	custom_minimum_size = Vector2(246, 294)
	clip_contents = true
	focus_mode = Control.FOCUS_ALL
	_build()


func set_card(index: int, card: Dictionary, enabled: bool) -> void:
	card_index = index
	_name_label.text = card.get("name", "Unbekannt")
	_description_label.text = String(card.get("description", "")) + ("\n" + String(card.get("risk_text", "")) if not String(card.get("risk_text", "")).is_empty() else "")
	_rarity_label.text = card.get("kind_label", "DAUERHAFTES UPGRADE")
	_rank_label.text = card.get("rarity_label", "TAKTIK") if card.get("card_kind", "upgrade") == "tactic" else card.get("rank_label", "RANG 1")
	if not String(card.get("artwork", "")).is_empty():
		_art.texture = load(card["artwork"])
	var rarity: String = card.get("rarity", "common")
	_rarity_color = AbilityDatabase.RARITY_COLORS.get(rarity, UIStyle.CYAN)
	_rarity_label.add_theme_color_override("font_color", _rarity_color)
	disabled = not enabled
	_apply_styles()
	tooltip_text = "%s – %s – %s %s" % [card.get("name", ""), card.get("kind_label", ""), card.get("description", ""), card.get("risk_text", "")]


func set_selected(selected: bool) -> void:
	_selected = selected
	_apply_styles()


func set_interactable(enabled: bool) -> void:
	disabled = not enabled
	_apply_styles()


func _apply_styles() -> void:
	add_theme_stylebox_override("normal", UIStyle.card_box(_rarity_color, _selected, disabled))
	add_theme_stylebox_override("hover", UIStyle.card_box(_rarity_color.lightened(0.12), _selected, false))
	add_theme_stylebox_override("pressed", UIStyle.card_box(_rarity_color.lightened(0.22), true, false))
	add_theme_stylebox_override("focus", UIStyle.card_box(_rarity_color.lightened(0.15), true, false))
	add_theme_stylebox_override("disabled", UIStyle.card_box(_rarity_color, _selected, true))


func _build() -> void:
	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 7)
	content.add_theme_constant_override("separation", 3)
	add_child(content)

	_art = TextureRect.new()
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.custom_minimum_size = Vector2(220, 157)
	_art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	content.add_child(_art)

	_name_label = Label.new()
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_name_label.add_theme_font_size_override("font_size", 19)
	_name_label.add_theme_color_override("font_color", UIStyle.TEXT)
	content.add_child(_name_label)

	_description_label = Label.new()
	_description_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description_label.custom_minimum_size.y = 34
	_description_label.add_theme_font_size_override("font_size", 12)
	_description_label.add_theme_color_override("font_color", UIStyle.MUTED)
	content.add_child(_description_label)

	var details := HBoxContainer.new()
	details.mouse_filter = Control.MOUSE_FILTER_IGNORE
	details.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(details)

	_rarity_label = Label.new()
	_rarity_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rarity_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rarity_label.add_theme_font_size_override("font_size", 12)
	details.add_child(_rarity_label)

	_rank_label = Label.new()
	_rank_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_rank_label.add_theme_font_size_override("font_size", 13)
	_rank_label.add_theme_color_override("font_color", UIStyle.GOLD)
	details.add_child(_rank_label)
