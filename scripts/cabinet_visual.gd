extends RefCounted

# Only the shelf interiors change; shelf boards, frame and silhouette remain
# exactly the same pixels of the original filled cabinet in every state.
const SHELF_AREAS := [Rect2i(17, 12, 30, 11), Rect2i(17, 29, 30, 11), Rect2i(17, 45, 30, 11)]
const BACKGROUND_PIXEL := Vector2i(28, 14)


static func empty_shelf_textures(full: Texture2D, areas: Array = SHELF_AREAS, background_pixel: Vector2i = BACKGROUND_PIXEL) -> Array[Texture2D]:
	var background := full.get_image().get_pixelv(background_pixel)
	var textures: Array[Texture2D] = []
	for area: Rect2i in areas:
		var interior := Image.create(area.size.x, area.size.y, false, Image.FORMAT_RGBA8)
		interior.fill(background)
		textures.append(ImageTexture.create_from_image(interior))
	return textures


static func empty_preview(full: Texture2D, interiors: Array[Texture2D], areas: Array = SHELF_AREAS) -> Texture2D:
	var image: Image = full.get_image().duplicate()
	image.convert(Image.FORMAT_RGBA8)
	for row in range(areas.size()):
		var interior := interiors[row].get_image()
		image.blit_rect(interior, Rect2i(Vector2i.ZERO, interior.get_size()), areas[row].position)
	return ImageTexture.create_from_image(image)
