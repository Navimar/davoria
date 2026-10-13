extends Sprite2D

signal finished

const DURATION := 0.32
const STAT_ICON_SIZE := 24.0

var _target: Control
var _clip: Control
var _start_position := Vector2.ZERO
var _start_scale := Vector2.ONE
var _progress := 0.0
var _tween: Tween
var _finished := false


func begin(image: Texture2D, start_position: Vector2, start_scale: Vector2, target: Control, clip: Control = null) -> void:
	texture = image
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_start_position = start_position
	_start_scale = start_scale
	position = start_position
	scale = start_scale
	_target = target
	_clip = clip
	# Labels and containers may rearrange after the immediate pickup. Capture
	# the field position now, but let the HUD finish layout before the flight.
	_start_tween.call_deferred()


func _start_tween() -> void:
	if _finished:
		return
	if not is_instance_valid(_target):
		cancel()
		return
	_tween = create_tween()
	_tween.tween_method(_animate, 0.0, 1.0, DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.finished.connect(_finish)


func _process(_delta: float) -> void:
	if not is_instance_valid(_target) or _target.is_queued_for_deletion():
		cancel()
	elif _tween != null:
		_animate(_progress)


func _destination() -> Vector2:
	var center := _target.get_global_transform_with_canvas() * (_target.size * 0.5)
	if is_instance_valid(_clip):
		var clip_transform := _clip.get_global_transform_with_canvas()
		var clip_rect := Rect2(clip_transform * Vector2.ZERO, _clip.size * clip_transform.get_scale())
		if not clip_rect.has_point(center):
			# An offscreen slot still belongs to the backpack. Use its visible
			# scrolling area without scrolling or flying beyond the panel.
			return clip_rect.get_center()
	return center


func _animate(progress: float) -> void:
	if _finished or not is_instance_valid(_target):
		return
	_progress = progress
	position = _start_position.lerp(_destination(), progress)
	var size_in_hud := _target.size if _target is TextureRect else Vector2.ONE * STAT_ICON_SIZE
	var target_scale := size_in_hud / texture.get_size() * _target.get_global_transform_with_canvas().get_scale().abs()
	scale = _start_scale.lerp(target_scale, progress)


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
