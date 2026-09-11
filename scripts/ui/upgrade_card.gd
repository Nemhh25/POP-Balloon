extends PanelContainer

var title_label: Label
var icon_rect: TextureRect
var effect_label: Label
var detail_label: Label
var badge: Label
var progress: ProgressBar
var purchase: Button
var _tween: Tween
var _last_title := ""
var _level := -1
var _badge_tween: Tween
var _base_purchase_tooltip := ""
var _click_progress_value := 0
var _click_milestone_active := false
var _click_milestone_tween: Tween

func attach(button: Button) -> void:
	purchase = button
	_base_purchase_tooltip = button.tooltip_text
	mouse_filter = Control.MOUSE_FILTER_PASS
	var column := VBoxContainer.new()
	add_child(column)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	column.add_child(row)
	icon_rect = TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(44, 44)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_rect.hide()
	row.add_child(icon_rect)
	title_label = Label.new()
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.add_theme_font_size_override("font_size", 19)
	title_label.theme_type_variation = "ArcadeTitle"
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(title_label)
	badge = Label.new()
	badge.text = tr("NEW")
	badge.add_theme_font_size_override("font_size", 13)
	badge.theme_type_variation = "Sticker"
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.hide()
	row.add_child(badge)
	effect_label = Label.new()
	effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	effect_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(effect_label)
	detail_label = Label.new()
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_label.modulate = Color("acbbd3")
	detail_label.add_theme_font_size_override("font_size", 14)
	column.add_child(detail_label)
	progress = ProgressBar.new()
	progress.custom_minimum_size.y = 8
	progress.show_percentage = false
	progress.hide()
	column.add_child(progress)
	button.reparent(column)
	button.custom_minimum_size.y = 40
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.visibility_changed.connect(func(): visible = button.visible)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.mouse_entered.connect(func(): badge.hide())
	button.focus_entered.connect(func(): badge.hide())
	visible = button.visible

func set_icon(texture: Texture2D) -> void:
	if icon_rect == null:
		return
	icon_rect.texture = texture
	icon_rect.show()

func present(title: String, effect: String, detail: String = "") -> void:
	if not _last_title.is_empty() and _last_title != title:
		pulse()
	_last_title = title
	title_label.text = title
	effect_label.text = effect
	detail_label.text = detail
	detail_label.visible = not detail.is_empty()

func pulse() -> void:
	if _tween: _tween.kill()
	modulate = Color("a3ffe0")
	_tween = create_tween()
	_tween.tween_property(self, "modulate", Color.WHITE, 0.3)
	title_label.pivot_offset = title_label.size * 0.5
	title_label.scale = Vector2(1.025, 1.025)
	_tween.parallel().tween_property(title_label, "scale", Vector2.ONE, 0.18)

func update_level(level: int, milestones: PackedInt32Array, multipliers: PackedFloat32Array) -> void:
	if _level >= 0 and level > _level:
		for i in milestones.size():
			if milestones[i] > _level and milestones[i] <= level:
				badge.text = "MILESTONE ×%s" % multipliers[i]
				badge.show()
				pulse()
				if _badge_tween: _badge_tween.kill()
				_badge_tween = create_tween()
				_badge_tween.tween_interval(0.9)
				_badge_tween.tween_callback(badge.hide)
	_level = level

func update_state() -> void:
	var complete := purchase.text.ends_with("MAX")
	var tooltip_parts: Array[String] = [title_label.text, effect_label.text]
	if detail_label.visible and not detail_label.text.is_empty(): tooltip_parts.append(detail_label.text)
	if not _base_purchase_tooltip.is_empty(): tooltip_parts.append(_base_purchase_tooltip)
	tooltip_parts.append(purchase.text)
	var next_tooltip := "\n".join(tooltip_parts)
	if tooltip_text != next_tooltip:
		tooltip_text = next_tooltip
	if purchase.tooltip_text != next_tooltip:
		purchase.tooltip_text = next_tooltip
	add_theme_stylebox_override("panel", preload("res://scripts/ui/pop_theme.gd").card_style(not purchase.disabled, complete, purchase.text.contains("Diamonds")))
	purchase.remove_theme_color_override("font_disabled_color")
	if complete:
		purchase.text = "MAX"
		progress.hide()
		purchase.add_theme_color_override("font_disabled_color", Color("73e4bd"))

func set_click_progress(level: int, interval: int) -> void:
	_click_progress_value = level % interval
	progress.max_value = interval
	progress.show()
	if not _click_milestone_active:
		progress.value = _click_progress_value

func show_click_milestone() -> void:
	_click_milestone_active = true
	progress.value = progress.max_value
	badge.text = tr("MILESTONE!")
	badge.show()
	pulse()
	if _click_milestone_tween: _click_milestone_tween.kill()
	_click_milestone_tween = create_tween()
	_click_milestone_tween.tween_interval(0.9)
	_click_milestone_tween.tween_callback(func() -> void:
		_click_milestone_active = false
		progress.value = _click_progress_value
		badge.hide()
	)

func mark_new() -> void:
	if _badge_tween: _badge_tween.kill()
	badge.text = tr("NEW")
	badge.show()
	pulse()
	modulate.a = 0.6
