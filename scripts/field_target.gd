extends Node2D

const GRID := preload("res://scripts/grid_config.gd")
const DIRECTIONS := [Vector2i.UP, Vector2i.LEFT, Vector2i.DOWN, Vector2i.RIGHT]
const IDLE_COLOR := Color(0.76, 0.86, 0.90, 0.55)
const TARGET_COLOR := Color(0.35, 0.92, 1.0)
const BLOCKED_COLOR := Color(1.0, 0.46, 0.35)

var direction := Vector2i.ZERO
var _blocked := false
var _hint: Label
var _action_name := ""
var _blocked_text := ""


func _ready() -> void:
	z_index = 60
	var canvas := CanvasLayer.new()
	canvas.layer = 21
	add_child(canvas)
	_hint = Label.new()
	_hint.name = "TargetHint"
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 18)
	_hint.add_theme_color_override("font_shadow_color", Color.BLACK)
	_hint.add_theme_constant_override("shadow_offset_x", 2)
	_hint.add_theme_constant_override("shadow_offset_y", 2)
	canvas.add_child(_hint)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.offset_left = -340
	_hint.offset_right = 340
	_hint.offset_top = -48
	_hint.offset_bottom = -18
	end_target()


func is_active() -> bool:
	return visible


func begin_target(world_origin: Vector2, action_name := "", blocked_text := "") -> void:
	position = world_origin
	direction = Vector2i.ZERO
	_blocked = false
	_action_name = tr("TARGET_PUSH") if action_name.is_empty() else action_name
	_blocked_text = tr("TARGET_PUSH_BLOCKED") if blocked_text.is_empty() else blocked_text
	_update_hint()
	_hint.show()
	show()
	queue_redraw()


func select_direction(value: Vector2i) -> void:
	if not is_active() or not DIRECTIONS.has(value):
		return
	direction = value
	_blocked = false
	_update_hint()
	queue_redraw()


func mark_blocked() -> void:
	_blocked = true
	_update_hint()
	queue_redraw()


func _update_hint() -> void:
	_hint.text = tr("UI_TARGET_BLOCKED_CONTROLS").format({"reason": _blocked_text}) if _blocked else tr("UI_TARGET_CONTROLS").format({"action": _action_name})


func end_target() -> void:
	direction = Vector2i.ZERO
	_blocked = false
	hide()
	if _hint != null:
		_hint.hide()


func _draw() -> void:
	for candidate: Vector2i in DIRECTIONS:
		var center := Vector2(candidate * GRID.TILE_SIZE)
		var selected := candidate == direction
		var color := (BLOCKED_COLOR if _blocked else TARGET_COLOR) if selected else IDLE_COLOR
		_draw_corners(center, Color(0, 0, 0, color.a), 2)
		_draw_corners(center, color, 0)
		if selected:
			# Integer rectangles keep the reticle on the same pixel grid as art.
			draw_rect(Rect2(center + Vector2(-5, -1), Vector2(10, 2)), color)
			draw_rect(Rect2(center + Vector2(-1, -5), Vector2(2, 10)), color)


func _draw_corners(center: Vector2, color: Color, border: int) -> void:
	for x in [-1, 1]:
		for y in [-1, 1]:
			var corner := center + Vector2(-29 if x < 0 else 19, -29 if y < 0 else 27)
			draw_rect(Rect2(corner - Vector2.ONE * border, Vector2(10, 2) + Vector2.ONE * border * 2), color)
			corner = center + Vector2(-29 if x < 0 else 27, -29 if y < 0 else 19)
			draw_rect(Rect2(corner - Vector2.ONE * border, Vector2(2, 10) + Vector2.ONE * border * 2), color)
