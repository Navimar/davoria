@tool
extends Sprite2D

const GRID := preload("res://scripts/grid_config.gd")
const SHADOW_TEXTURE := preload("res://assets/effects/contact_shadow.png")


func _init() -> void:
	name = "ContactShadow"
	texture = SHADOW_TEXTURE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	centered = true
	self_modulate = Color(1.0, 1.0, 1.0, 0.5)
	position = Vector2(0.0, GRID.PIXEL_BASELINE - GRID.TILE_SIZE * 0.5 - 1.0) + GRID.ACTOR_DRAW_OFFSET
	z_as_relative = false
	z_index = 5
