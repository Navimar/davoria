extends CanvasLayer

signal acknowledged

var _overlay: ColorRect
var _title: Label
var _picture: TextureRect
var _description: Label
var _confirm: Button


func _ready() -> void:
	layer = 60
	_overlay = ColorRect.new()
	_overlay.name = "AdventureOverlay"
	_overlay.color = Color(0.0, 0.0, 0.0, 0.78)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	_overlay.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.10, 0.13)
	style.border_color = Color(0.48, 0.46, 0.40)
	style.set_border_width_all(2)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	panel.add_child(column)
	_title = Label.new()
	_title.name = "Title"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 28)
	column.add_child(_title)
	var picture_center := CenterContainer.new()
	column.add_child(picture_center)
	_picture = TextureRect.new()
	_picture.name = "Picture"
	_picture.custom_minimum_size = Vector2(192, 192)
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	picture_center.add_child(_picture)
	_description = Label.new()
	_description.name = "Description"
	_description.custom_minimum_size = Vector2(480, 0)
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_description.add_theme_font_size_override("font_size", 20)
	column.add_child(_description)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	column.add_child(row)
	_confirm = Button.new()
	_confirm.name = "Confirm"
	_confirm.custom_minimum_size = Vector2(210, 48)
	_confirm.add_theme_font_size_override("font_size", 20)
	_confirm.pressed.connect(_accept)
	row.add_child(_confirm)
	_overlay.hide()


func is_open() -> bool:
	return _overlay != null and _overlay.visible


func show_notice(title: String, texture: Texture2D, description: String, confirmation := "", picture_material: Material = null) -> void:
	_title.text = title
	_picture.texture = texture
	_picture.material = picture_material
	_description.text = description
	_confirm.text = tr("UI_NOTICE_CONFIRM") if confirmation.is_empty() else confirmation
	_confirm.disabled = false
	_overlay.show()
	_confirm.grab_focus()


func hide_prompt() -> void:
	_overlay.hide()
	_confirm.release_focus()


func handle_key(event: InputEventKey) -> void:
	if not is_open() or not event.pressed or event.echo:
		return
	if event.physical_keycode == KEY_SPACE:
		_accept()


func _input(event: InputEvent) -> void:
	if is_open() and event is InputEventKey:
		handle_key(event)
		get_viewport().set_input_as_handled()


func _accept() -> void:
	if not is_open() or _confirm.disabled:
		return
	hide_prompt()
	acknowledged.emit()
