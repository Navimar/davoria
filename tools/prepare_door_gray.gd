extends SceneTree

const FOLDER := "res://assets/generation/door_gray_64_2026-10-12"
const WOOD_REGION := Rect2i(15, 4, 35, 54)


func _init() -> void:
	var original := Image.load_from_file(ProjectSettings.globalize_path(FOLDER.path_join("original.png")))
	var stone := Image.load_from_file(ProjectSettings.globalize_path(FOLDER.path_join("graded/door_gray.png")))
	if original == null or stone == null or original.get_size() != Vector2i(64, 64) or stone.get_size() != Vector2i(64, 64):
		push_error("Door preparation requires the original and graded native 64px tiles")
		quit(1)
		return
	original.convert(Image.FORMAT_RGBA8)
	stone.convert(Image.FORMAT_RGBA8)
	# Native composite: preserve wood, lock and metal pixels exactly. The imagegen
	# edit supplies only the requested stone frame; no final bitmap is rescaled.
	stone.blit_rect(original, WOOD_REGION, WOOD_REGION.position)
	var final_dir := FOLDER.path_join("final")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(final_dir))
	stone.save_png(ProjectSettings.globalize_path(final_dir.path_join("door.png")))
	stone.save_png(ProjectSettings.globalize_path("res://assets/tiles/dungeon/door.png"))
	print("GRAY DOOR PREPARED: native 64px, original wood/lock/metal preserved, edited cool-gray stone frame")
	quit()
