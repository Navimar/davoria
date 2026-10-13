shader_type canvas_item;

// The sprite moves down by this many native pixels. Trim the same rows from
// its bottom so that the surface stays fixed. Labels and shadows are separate.
uniform float submerged_pixels = 0.0;

void fragment() {
	float sprite_height = 1.0 / TEXTURE_PIXEL_SIZE.y;
	float row = floor(UV.y * sprite_height);
	COLOR.a *= 1.0 - step(sprite_height - submerged_pixels, row);
}
