extends CanvasLayer

signal decided(confirmed: bool)

var _overlay: ColorRect
var _buttons: Array[Button] = []
var _selected_index := 1
var _question: Label


func _ready() -> void:
	layer = 50
	_overlay = ColorRect.new()
	_overlay.name = "DoorUnlockOverlay"
	_overlay.color = Color(0.0, 0.0, 0.0, 0.72)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.name = "DoorUnlockPanel"
	panel.custom_minimum_size = Vector2(500, 180)
	panel.add_theme_stylebox_override("panel", _style(Color(0.10, 0.10, 0.13), Color(0.43, 0.45, 0.52), 18))
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	panel.add_child(column)
	_question = Label.new()
	_question.name = "DoorUnlockQuestion"
	_question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_question.add_theme_font_size_override("font_size", 22)
	column.add_child(_question)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	column.add_child(row)
	for index in range(2):
		var button := Button.new()
		button.name = "UnlockYes" if index == 0 else "UnlockNo"
		button.text = tr("UI_YES") if index == 0 else tr("UI_NO")
		button.custom_minimum_size = Vector2(160, 48)
		button.add_theme_font_size_override("font_size", 22)
		button.add_theme_stylebox_override("normal", _style(Color(0.17, 0.18, 0.22), Color(0.35, 0.36, 0.42), 8))
		button.add_theme_stylebox_override("focus", _style(Color(0.0, 0.0, 0.0, 0.0), Color(1.0, 0.78, 0.36), 8))
		button.pressed.connect(_choose.bind(index == 0))
		row.add_child(button)
		_buttons.append(button)
	var help := Label.new()
	help.text = tr("UI_CONFIRM_CONTROLS")
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_font_size_override("font_size", 14)
	help.modulate = Color(0.75, 0.76, 0.81)
	column.add_child(help)
	_overlay.hide()


func is_open() -> bool:
	return _overlay != null and _overlay.visible


func show_prompt(question := "") -> void:
	_question.text = tr("CONFIRMATION_MAGIC_KEY") if question.is_empty() else question
	_overlay.show()
	_select(1)


func hide_prompt() -> void:
	_overlay.hide()
	for button in _buttons:
		button.release_focus()


func handle_key(event: InputEventKey) -> void:
	if not is_open() or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_W, KEY_A:
			_select(0)
		KEY_S, KEY_D:
			_select(1)
		KEY_SPACE:
			_choose(_selected_index == 0)
		KEY_ESCAPE:
			_choose(false)


func _input(event: InputEvent) -> void:
	if is_open() and event is InputEventKey:
		# Consume Space before the focused Button or the game can also process it.
		handle_key(event)
		get_viewport().set_input_as_handled()


func _select(index: int) -> void:
	_selected_index = index
	_buttons[index].grab_focus()


func _choose(confirmed: bool) -> void:
	if not is_open():
		return
	hide_prompt()
	decided.emit(confirmed)


func _style(color: Color, border: Color, padding: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	return style
