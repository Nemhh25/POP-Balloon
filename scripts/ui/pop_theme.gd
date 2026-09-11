extends RefCounted

const INK := Color("edf4ff")
const MUTED := Color("acbbd3")
const MINT := Color("73e4bd")
const GOLD := Color("ffcf6a")
const DIAMOND := Color("a8abff")
const OUTLINE := Color("10182b")
const SKY := Color("219bd3")

static func plate(color: Color, accent: Color = OUTLINE, radius: int = 14) -> StyleBoxFlat:
	var style := box(color, OUTLINE, radius)
	style.border_width_left = 4
	style.border_width_right = 4
	style.border_width_top = 3
	style.border_width_bottom = 6
	style.shadow_color = Color(0.015, 0.03, 0.07, 0.6)
	style.shadow_size = 3
	style.shadow_offset = Vector2(0, 3)
	if accent != OUTLINE:
		style.border_color = accent
	return style

static func card_style(affordable: bool, complete: bool, global: bool) -> StyleBoxFlat:
	var style := plate(Color("354067") if global else Color("264e68"))
	style.border_color = Color("62ddca") if affordable else Color("172a40")
	if complete: style.border_color = Color("d9b85e")
	style.border_width_left = 5
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 4
	return style

static func box(color: Color, border: Color = Color.TRANSPARENT, radius: int = 16) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

static func build() -> Theme:
	var result := Theme.new()
	result.default_font_size = 16
	result.set_color("font_color", "Label", INK)
	result.set_stylebox("panel", "PanelContainer", plate(Color("24465f")))
	result.set_stylebox("normal", "Button", plate(SKY, OUTLINE, 12))
	result.set_stylebox("hover", "Button", plate(Color("38bfe2"), OUTLINE, 12))
	var pressed := plate(Color("168ab9"), OUTLINE, 12)
	pressed.border_width_bottom = 3
	pressed.border_width_top = 6
	pressed.shadow_size = 0
	result.set_stylebox("pressed", "Button", pressed)
	result.set_stylebox("disabled", "Button", plate(Color("3c5267"), Color("233449"), 12))
	result.set_stylebox("focus", "Button", box(Color.TRANSPARENT, GOLD, 12))
	for state in ["font_color", "font_hover_color", "font_pressed_color"]:
		result.set_color(state, "Button", INK)
	result.set_color("font_disabled_color", "Button", MUTED)
	result.set_color("font_outline_color", "Button", OUTLINE)
	result.set_constant("outline_size", "Button", 2)
	var bold := FontVariation.new()
	bold.base_font = ThemeDB.fallback_font
	bold.variation_embolden = 0.7
	result.set_font("font", "Button", bold)
	result.set_type_variation("ArcadeTitle", "Label")
	result.set_font("font", "ArcadeTitle", bold)
	result.set_color("font_outline_color", "ArcadeTitle", OUTLINE)
	result.set_constant("outline_size", "ArcadeTitle", 5)
	result.set_color("font_shadow_color", "ArcadeTitle", OUTLINE)
	result.set_constant("shadow_offset_y", "ArcadeTitle", 3)
	result.set_type_variation("Sticker", "Label")
	var sticker := plate(GOLD, OUTLINE, 7)
	sticker.content_margin_left = 8
	sticker.content_margin_right = 8
	sticker.content_margin_top = 3
	sticker.content_margin_bottom = 5
	result.set_stylebox("normal", "Sticker", sticker)
	result.set_color("font_color", "Sticker", OUTLINE)
	result.set_font("font", "Sticker", bold)
	result.set_type_variation("ActionButton", "Button")
	result.set_stylebox("normal", "ActionButton", plate(Color("ee9d32"), OUTLINE, 12))
	result.set_stylebox("hover", "ActionButton", plate(Color("ffc95d"), OUTLINE, 12))
	result.set_constant("separation", "VBoxContainer", 10)
	result.set_constant("separation", "HBoxContainer", 12)
	var track := box(Color("101e32"), OUTLINE, 5)
	track.set_border_width_all(2)
	track.content_margin_top = 0
	track.content_margin_bottom = 0
	result.set_stylebox("background", "ProgressBar", track)
	var fill := box(MINT, Color.TRANSPARENT, 5)
	fill.set_border_width_all(1)
	fill.border_color = OUTLINE
	fill.content_margin_top = 0
	fill.content_margin_bottom = 0
	result.set_stylebox("fill", "ProgressBar", fill)
	result.set_stylebox("panel", "TabContainer", plate(Color("1c344c")))
	var selected_tab := plate(SKY, OUTLINE, 10)
	result.set_stylebox("tab_selected", "TabContainer", selected_tab)
	result.set_stylebox("tab_unselected", "TabContainer", plate(Color("39516a"), OUTLINE, 10))
	result.set_stylebox("tab_hovered", "TabContainer", plate(Color("496c86"), OUTLINE, 10))
	result.set_stylebox("tab_disabled", "TabContainer", plate(Color("2a3d52"), OUTLINE, 10))
	result.set_stylebox("tab_focus", "TabContainer", box(Color.TRANSPARENT, GOLD, 10))
	result.set_font("font", "TabContainer", bold)
	result.set_stylebox("scroll", "VScrollBar", box(OUTLINE, OUTLINE, 6))
	result.set_stylebox("grabber", "VScrollBar", box(Color("428aab"), OUTLINE, 6))
	result.set_stylebox("grabber_highlight", "VScrollBar", box(SKY, OUTLINE, 6))
	result.set_stylebox("grabber_pressed", "VScrollBar", box(MINT, OUTLINE, 6))
	for state in ["scroll", "grabber", "grabber_highlight", "grabber_pressed"]:
		var scrollbar := result.get_stylebox(state, "VScrollBar") as StyleBoxFlat
		scrollbar.content_margin_left = 7
		scrollbar.content_margin_right = 7
		scrollbar.content_margin_top = 0
		scrollbar.content_margin_bottom = 0
	result.set_color("font_selected_color", "TabContainer", INK)
	result.set_color("font_unselected_color", "TabContainer", MUTED)
	result.set_stylebox("panel", "TooltipPanel", plate(Color("263b55"), OUTLINE, 10))
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		result.set_stylebox(state, "CheckButton", plate(Color("26796d") if state.contains("pressed") else Color("354d65"), OUTLINE, 10))
	result.set_color("font_color", "TooltipLabel", INK)
	return result
