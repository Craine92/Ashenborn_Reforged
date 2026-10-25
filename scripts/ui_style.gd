class_name UIStyle
extends RefCounted

const INK := Color("06080d")
const PANEL := Color("0d121be0")
const PANEL_SOFT := Color("0d121bb3")
const PANEL_SOLID := Color("101620fa")
const TEXT := Color("f5f0e6")
const MUTED := Color("9ca8b8")
const CYAN := Color("55cfe4")
const RED := Color("d45151")
const GOLD := Color("dfb763")
const BRONZE := Color("a97842")


static func box(color: Color, border_color: Color = Color.TRANSPARENT, width: int = 0, radius: int = 10) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border_color
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	return style


static func style_button(button: Button, accent: Color = CYAN) -> void:
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color("72808f"))
	button.add_theme_stylebox_override("normal", box(Color("18202bf0"), Color("6b543980"), 1, 8))
	button.add_theme_stylebox_override("hover", box(Color("252f3dff"), accent, 2, 8))
	button.add_theme_stylebox_override("pressed", box(Color("0d121aff"), accent.lightened(0.12), 2, 8))
	button.add_theme_stylebox_override("disabled", box(Color("10151dd0"), Color("3b455140"), 1, 8))
	button.custom_minimum_size = Vector2(280, 50)


static func style_action_button(button: Button) -> void:
	button.add_theme_font_size_override("font_size", 21)
	button.add_theme_color_override("font_color", Color("171108"))
	button.add_theme_color_override("font_hover_color", Color("080604"))
	button.add_theme_stylebox_override("normal", box(GOLD, Color("e2c27aff"), 1, 8))
	button.add_theme_stylebox_override("hover", box(GOLD.lightened(0.12), Color.WHITE, 2, 8))
	button.add_theme_stylebox_override("pressed", box(BRONZE, GOLD, 2, 8))
	button.add_theme_stylebox_override("disabled", box(Color("4c433580"), Color("5a4d3d40"), 1, 8))
	button.custom_minimum_size = Vector2(250, 48)


static func card_box(color: Color, selected: bool = false, disabled: bool = false) -> StyleBoxFlat:
	var fill := Color("111721fa")
	if selected:
		fill = Color("202937ff")
	elif disabled:
		fill = Color("0d1118d0")
	var style := box(fill, color if selected else color.darkened(0.32), 4 if selected else 2, 10)
	style.content_margin_left = 7.0
	style.content_margin_right = 7.0
	style.content_margin_top = 7.0
	style.content_margin_bottom = 7.0
	style.shadow_color = Color(0, 0, 0, 0.65)
	style.shadow_size = 12 if selected else 7
	style.shadow_offset = Vector2(0, 5)
	return style
