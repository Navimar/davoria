extends CanvasLayer

signal hero_selected(index: int)
signal picker_toggled(open: bool)

var _variants: Array
var _selected_index := 0
var _overlay: ColorRect
var _panel: PanelContainer
var _buttons: Array[Button] = []


func _init(variants: Array = [], selected_index := 0) -> void:
	_variants = variants
	_selected_index = selected_index


func _ready() -> void:
	layer = 40
	var root := Control.new()
	root.name = "HeroChoiceUI"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var toggle_button := Button.new()
	toggle_button.name = "ChooseHeroButton"
	toggle_button.text = "Герой [H]"
	toggle_button.pressed.connect(toggle)
	root.add_child(toggle_button)
	toggle_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	toggle_button.offset_left = -158.0
	toggle_button.offset_right = -18.0
	toggle_button.offset_top = -62.0
	toggle_button.offset_bottom = -18.0

	_overlay = ColorRect.new()
	_overlay.name = "HeroChoiceOverlay"
	_overlay.color = Color(0.0, 0.0, 0.0, 0.72)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.gui_input.connect(_on_background_input)
	root.add_child(_overlay)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_panel = PanelContainer.new()
	_panel.name = "HeroChoices"
	_panel.custom_minimum_size = Vector2(536.0, 560.0)
	_panel.add_theme_stylebox_override("panel", _panel_style())
	_overlay.add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	_panel.add_child(column)
	var heading := HBoxContainer.new()
	column.add_child(heading)
	var title := Label.new()
	title.text = "Выберите героя"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 24)
	heading.add_child(title)
	var close_button := Button.new()
	close_button.text = "Закрыть"
	close_button.pressed.connect(hide_picker)
	heading.add_child(close_button)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 8)
	column.add_child(grid)
	var group := ButtonGroup.new()
	for index in range(_variants.size()):
		var cell := VBoxContainer.new()
		cell.custom_minimum_size.x = 112.0
		cell.add_theme_constant_override("separation", 4)
		grid.add_child(cell)
		var button := Button.new()
		button.name = "HeroChoice_%d" % index
		button.custom_minimum_size = Vector2(96.0, 96.0)
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		button.icon = load(str(_variants[index]["path"])) as Texture2D
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		button.toggle_mode = true
		button.button_group = group
		button.tooltip_text = str(_variants[index]["name"])
		button.pressed.connect(_on_selected.bind(index))
		cell.add_child(button)
		_buttons.append(button)
		var label := Label.new()
		label.text = str(_variants[index]["name"])
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 14)
		cell.add_child(label)
	set_selected(_selected_index)
	_overlay.visible = false
	get_viewport().size_changed.connect(_center_panel)
	_center_panel.call_deferred()


func is_open() -> bool:
	return _overlay != null and _overlay.visible


func toggle() -> void:
	if is_open():
		hide_picker()
	else:
		_overlay.visible = true
		_center_panel()
		picker_toggled.emit(true)


func hide_picker() -> void:
	if not is_open():
		return
	_overlay.visible = false
	picker_toggled.emit(false)


func set_selected(index: int) -> void:
	_selected_index = index
	for i in range(_buttons.size()):
		_buttons[i].set_pressed_no_signal(i == index)


func _on_selected(index: int) -> void:
	set_selected(index)
	hide_picker()
	hero_selected.emit(index)


func _on_background_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		hide_picker()


func _center_panel() -> void:
	_panel.size = _panel.get_combined_minimum_size()
	_panel.position = (get_viewport().get_visible_rect().size - _panel.size) * 0.5


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.075, 0.09, 0.98)
	style.border_color = Color(0.32, 0.28, 0.2)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 16.0
	style.content_margin_bottom = 16.0
	return style
