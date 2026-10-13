extends PanelContainer

signal clicked(button: int)
var payload_provider: Callable
var accepts_payload: Callable
var receives_payload: Callable
var icon: TextureRect
var _pressed := false
var _drag_started := false


func _gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		clicked.emit(MOUSE_BUTTON_RIGHT)
		accept_event()
	elif event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pressed = true
			_drag_started = false
		else:
			if _pressed and not _drag_started and Rect2(Vector2.ZERO, size).has_point(event.position):
				clicked.emit(MOUSE_BUTTON_LEFT)
			_pressed = false
		accept_event()


func _get_drag_data(_position: Vector2) -> Variant:
	if not payload_provider.is_valid():
		return null
	var payload: Variant = payload_provider.call()
	if payload == null:
		return null
	_drag_started = true
	var preview := TextureRect.new()
	preview.texture = icon.texture
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview.custom_minimum_size = Vector2(64, 64)
	preview.modulate.a = 0.8
	set_drag_preview(preview)
	return payload


func _can_drop_data(_position: Vector2, payload: Variant) -> bool:
	return accepts_payload.is_valid() and accepts_payload.call(payload)


func _drop_data(_position: Vector2, payload: Variant) -> void:
	if receives_payload.is_valid():
		receives_payload.call(payload)
