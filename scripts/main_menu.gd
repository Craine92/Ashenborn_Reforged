class_name MainMenu
extends Control

signal play_requested
signal volume_changed(value: float)

var _pages: Control
var _home: Control
var _rules: Control
var _settings: Control


func _ready() -> void:
	_build()
	show_home()


func show_home() -> void:
	_set_page(_home)


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
	shade.color = Color("060910c5")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	_pages = Control.new()
	_pages.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_pages)

	_home = _build_home()
	_rules = _build_rules()
	_settings = _build_settings()
	_pages.add_child(_home)
	_pages.add_child(_rules)
	_pages.add_child(_settings)


func _build_home() -> Control:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 14)
	center.add_child(column)

	var logo := TextureRect.new()
	logo.texture = load("res://assets/ui/Logo/ashenborn_logo.png")
	logo.custom_minimum_size = Vector2(560, 210)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	column.add_child(logo)

	var subtitle := Label.new()
	subtitle.text = "ALPHA 0.2A  ·  CO-OP FOUNDATION"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", UIStyle.CYAN)
	column.add_child(subtitle)

	var play := _menu_button("SPIELEN")
	play.pressed.connect(func() -> void: play_requested.emit())
	column.add_child(play)
	var rules := _menu_button("SPIELREGELN")
	rules.pressed.connect(func() -> void: _set_page(_rules))
	column.add_child(rules)
	var settings := _menu_button("EINSTELLUNGEN")
	settings.pressed.connect(func() -> void: _set_page(_settings))
	column.add_child(settings)
	return center


func _build_rules() -> Control:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(680, 440)
	panel.add_theme_stylebox_override("panel", UIStyle.box(UIStyle.PANEL_SOLID, Color("637a9280"), 1, 12))
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	panel.add_child(column)
	var title := _title("SPIELREGELN")
	column.add_child(title)
	var rules := RichTextLabel.new()
	rules.bbcode_enabled = true
	rules.fit_content = true
	rules.custom_minimum_size = Vector2(620, 270)
	rules.add_theme_font_size_override("normal_font_size", 20)
	rules.add_theme_color_override("default_color", UIStyle.TEXT)
	rules.text = "[color=#56d8ec]1.[/color] Ein oder zwei Spieler erhalten je drei private Upgrades.\n\n[color=#56d8ec]2.[/color] Jeder tippt genau eine Karte an und wartet auf den Mitspieler.\n\n[color=#56d8ec]3.[/color] Beide Aschenritter greifen nacheinander mit ihren eigenen Builds an.\n\n[color=#56d8ec]4.[/color] Morvath schlägt einmal gegen alle lebenden Helden zurück.\n\nBesiegt Morvaths 60 Leben solo oder 120 Leben im Koop."
	column.add_child(rules)
	var back := _menu_button("ZURÜCK")
	back.pressed.connect(show_home)
	column.add_child(back)
	return center


func _build_settings() -> Control:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 300)
	panel.add_theme_stylebox_override("panel", UIStyle.box(UIStyle.PANEL_SOLID, Color("637a9280"), 1, 12))
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 22)
	panel.add_child(column)
	column.add_child(_title("EINSTELLUNGEN"))
	var label := Label.new()
	label.text = "GESAMTLAUTSTÄRKE"
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", UIStyle.MUTED)
	column.add_child(label)
	var volume := HSlider.new()
	volume.min_value = 0.0
	volume.max_value = 100.0
	volume.value = 75.0
	volume.custom_minimum_size = Vector2(500, 34)
	volume.value_changed.connect(func(value: float) -> void: volume_changed.emit(value))
	column.add_child(volume)
	var back := _menu_button("ZURÜCK")
	back.pressed.connect(show_home)
	column.add_child(back)
	return center


func _set_page(page: Control) -> void:
	for child in _pages.get_children():
		child.visible = child == page


func _menu_button(text_value: String) -> Button:
	var button := Button.new()
	button.text = text_value
	UIStyle.style_button(button)
	return button


func _title(text_value: String) -> Label:
	var label := Label.new()
	label.text = text_value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_color", UIStyle.GOLD)
	return label
