extends Sprite2D

signal finished

const WATER_SHADER := preload("res://assets/shaders/water_submerge.gdshader")
const SINK_DURATION := 0.45

var _base_offset := Vector2.ZERO
var _sink_material: ShaderMaterial
var _sink_tween: Tween


func begin(source: Sprite2D, destination: Vector2, travel_duration: float) -> void:
	# Only the picture survives logical death. No strength label or shadow.
	texture = source.texture
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	position = source.position
	offset = source.offset
	_base_offset = offset
	scale = source.scale
	flip_h = source.flip_h
	flip_v = source.flip_v
	z_index = source.z_index
	_sink_material = ShaderMaterial.new()
	_sink_material.shader = WATER_SHADER
	material = _sink_material
	_set_depth(0.0)
	_sink_tween = create_tween()
	_sink_tween.tween_property(self, "position", destination, travel_duration)
	_sink_tween.tween_method(_set_depth, 0.0, 1.0, SINK_DURATION)
	_sink_tween.finished.connect(_finish)


func _set_depth(fraction: float) -> void:
	var pixels := roundf(texture.get_height() * fraction)
	offset = _base_offset + Vector2(0.0, pixels)
	_sink_material.set_shader_parameter("submerged_pixels", pixels)


func _finish() -> void:
	finished.emit()
	queue_free()
