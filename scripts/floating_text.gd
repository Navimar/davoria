extends Node2D

signal finished

const DURATION := 1.1
const HOLD_DURATION := 0.25
const RISE_PIXELS := 24.0
const DRAW_LAYER := 70
const FONT_SIZE := 24
const BOTTOM_OFFSET := -112.0
const LANE_HEIGHT := 64.0

var text := ""
var lane := 0
var lane_count := 1
var _origin := Vector2.ZERO
var _label: Label
var _bottom_offset := BOTTOM_OFFSET
var _rise := 0.0
var _tween: Tween
var _finished := false


func begin(screen_origin: Vector2, message: String, color: Color, bottom_offset: float) -> void:
	_origin = screen_origin
	text = message
	_bottom_offset = bottom_offset
	z_as_relative = false
	z_index = DRAW_LAYER
	_label = Label.new()
	_label.text = message
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_label.add_theme_color_override("font_color", color)
	_label.add_theme_color_override("font_outline_color", Color(0.025, 0.02, 0.025))
	_label.add_theme_constant_override("outline_size", 4)
	add_child(_label)
	_label.size = Vector2(280.0, _label.get_combined_minimum_size().y)
	_label.position = Vector2(-_label.size.x * 0.5, -_label.size.y)
	lane_count = ceili((_label.size.y + RISE_PIXELS + 6.0) / LANE_HEIGHT)
	_update_position()
	_tween = create_tween().set_parallel(true)
	_tween.tween_method(_set_progress, 0.0, 1.0, DURATION)
	_tween.tween_property(self, "modulate:a", 0.0, DURATION - HOLD_DURATION).set_delay(HOLD_DURATION)
	_tween.finished.connect(_finish)


func top_offset() -> float:
	return _bottom_offset - _rise - _label.size.y


func set_bottom_offset(value: float) -> void:
	_bottom_offset = value
	_update_position()


func _set_progress(progress: float) -> void:
	_rise = roundf(progress * RISE_PIXELS)
	_update_position()


func _update_position() -> void:
	position = _origin + Vector2(0.0, _bottom_offset - _rise)


func cancel() -> void:
	if _tween != null:
		_tween.kill()
	_finish()


func _finish() -> void:
	if _finished:
		return
	_finished = true
	finished.emit()
	queue_free()
