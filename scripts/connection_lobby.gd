class_name ConnectionLobby
extends Control

signal start_requested
signal solo_requested
signal back_requested
signal close_requested

var _board_background: TextureRect
var _shade: ColorRect
var _panel: PanelContainer
var _title: Label
var _instructions: Label
var _qr: TextureRect
var _qr_message: Label
var _url_label: Label
var _status_label: Label
var _start_button: Button
var _solo_button: Button
var _back_button: Button
var _close_button: Button
var _connection_ready := false
var _smartphone_connected := false
var _ingame_mode := false


func _ready() -> void:
	_build()


func set_ingame_mode() -> void:
	_ingame_mode = true
	_board_background.visible = false
	_shade.color = Color("060910d9")
	_title.text = "SMARTPHONE-VERBINDUNG"
	_instructions.text = "Scanne den QR-Code mit einem Smartphone im selben WLAN."
	_start_button.visible = false
	_solo_button.visible = false
	_back_button.visible = false
	_close_button.visible = true
	_panel.custom_minimum_size = Vector2(790, 540)


func configure(controller_url: String, server_started: bool, has_network_address: bool) -> void:
	_connection_ready = server_started and has_network_address and not controller_url.is_empty()
	_qr.texture = null
	_qr_message.visible = false
	if not server_started:
		_show_error("Der Verbindungsserver konnte nicht gestartet werden.\nDie Ports 8765 oder 8766 sind möglicherweise bereits belegt.")
	elif not has_network_address or controller_url.is_empty():
		_show_error("Keine geeignete lokale WLAN-Adresse gefunden.\nBitte Netzwerkverbindung prüfen oder ohne Smartphone testen.")
	else:
		_url_label.text = controller_url
		_url_label.add_theme_color_override("font_color", UIStyle.CYAN)
		var texture := QRCodeGenerator.make_texture(controller_url)
		if texture == null:
			_connection_ready = false
			_show_error("Für diese Netzwerkadresse konnte kein QR-Code erzeugt werden.")
		else:
			_qr.texture = texture
	_update_status()


func set_smartphone_connected(connected: bool) -> void:
	_smartphone_connected = connected
	_update_status()


func is_start_enabled() -> bool:
	return not _start_button.disabled


func status_text() -> String:
	return _status_label.text


func qr_texture() -> Texture2D:
	return _qr.texture


func displayed_url() -> String:
	return _url_label.text


func _show_error(message: String) -> void:
	_url_label.text = message
	_url_label.add_theme_color_override("font_color", UIStyle.RED)
	_qr_message.text = "QR-CODE NICHT VERFÜGBAR"
	_qr_message.visible = true


func _update_status() -> void:
	if not _connection_ready:
		_status_label.text = "VERBINDUNG NICHT VERFÜGBAR"
		_status_label.add_theme_color_override("font_color", UIStyle.RED)
	elif _smartphone_connected:
		_status_label.text = "Smartphone verbunden"
		_status_label.add_theme_color_override("font_color", Color("55c271"))
	else:
		_status_label.text = "Warte auf Smartphone"
		_status_label.add_theme_color_override("font_color", UIStyle.GOLD)
	_start_button.disabled = not (_connection_ready and _smartphone_connected)


func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_board_background = TextureRect.new()
	_board_background.texture = load("res://assets/environments/board/board_main.png")
	_board_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_board_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_board_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_board_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_board_background)

	_shade = ColorRect.new()
	_shade.color = Color("060910c9")
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_shade)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(center)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(920, 590)
	_panel.add_theme_stylebox_override("panel", UIStyle.box(Color("111722fa"), Color("69ddec80"), 2, 14))
	center.add_child(_panel)

	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	_panel.add_child(page)
	_title = Label.new()
	_title.text = "VERBINDUNGSLOBBY"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 30)
	_title.add_theme_color_override("font_color", UIStyle.GOLD)
	page.add_child(_title)

	_instructions = Label.new()
	_instructions.text = "Scanne den QR-Code mit einem Smartphone im selben WLAN."
	_instructions.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_instructions.add_theme_font_size_override("font_size", 17)
	_instructions.add_theme_color_override("font_color", UIStyle.MUTED)
	page.add_child(_instructions)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_theme_constant_override("separation", 24)
	page.add_child(body)

	var qr_frame := PanelContainer.new()
	qr_frame.custom_minimum_size = Vector2(350, 350)
	qr_frame.add_theme_stylebox_override("panel", UIStyle.box(Color.WHITE, Color("b8c2ccff"), 2, 6))
	body.add_child(qr_frame)
	var qr_layers := Control.new()
	qr_frame.add_child(qr_layers)
	_qr = TextureRect.new()
	_qr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_qr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_qr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_qr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	qr_layers.add_child(_qr)
	_qr_message = Label.new()
	_qr_message.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_qr_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_qr_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_qr_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_qr_message.add_theme_font_size_override("font_size", 17)
	_qr_message.add_theme_color_override("font_color", UIStyle.RED)
	qr_layers.add_child(_qr_message)

	var details := VBoxContainer.new()
	details.custom_minimum_size.x = 450
	details.alignment = BoxContainer.ALIGNMENT_CENTER
	details.add_theme_constant_override("separation", 14)
	body.add_child(details)
	var url_title := Label.new()
	url_title.text = "CONTROLLER-ADRESSE"
	url_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	url_title.add_theme_font_size_override("font_size", 15)
	url_title.add_theme_color_override("font_color", UIStyle.MUTED)
	details.add_child(url_title)
	_url_label = Label.new()
	_url_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_url_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_url_label.custom_minimum_size = Vector2(430, 58)
	_url_label.add_theme_font_size_override("font_size", 20)
	_url_label.add_theme_color_override("font_color", UIStyle.CYAN)
	details.add_child(_url_label)
	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 22)
	details.add_child(_status_label)
	_start_button = Button.new()
	_start_button.text = "SPIEL STARTEN"
	UIStyle.style_button(_start_button, Color("55c271"))
	_start_button.pressed.connect(func() -> void: start_requested.emit())
	details.add_child(_start_button)
	_solo_button = Button.new()
	_solo_button.text = "OHNE SMARTPHONE TESTEN"
	UIStyle.style_button(_solo_button, UIStyle.CYAN)
	_solo_button.pressed.connect(func() -> void: solo_requested.emit())
	details.add_child(_solo_button)
	_back_button = Button.new()
	_back_button.text = "ZURÜCK"
	UIStyle.style_button(_back_button, UIStyle.GOLD)
	_back_button.pressed.connect(func() -> void: back_requested.emit())
	details.add_child(_back_button)
	_close_button = Button.new()
	_close_button.text = "SCHLIESSEN"
	UIStyle.style_button(_close_button, UIStyle.CYAN)
	_close_button.visible = false
	_close_button.pressed.connect(func() -> void: close_requested.emit())
	details.add_child(_close_button)
