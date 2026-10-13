shader_type canvas_item;

// The sprite moves down by this many native pixels. Trim the same rows from
// its bottom so that the surface stays fixed. Labels and shadows are separate.
uniform float submerged_pixels = 0.0;
uniform bool petrified = false;
uniform vec4 potion_flash_color : source_color = vec4(1.0);
uniform float potion_flash_strength = 0.0;

void fragment() {
	float sprite_height = 1.0 / TEXTURE_PIXEL_SIZE.y;
	float row = floor(UV.y * sprite_height);
	COLOR.a *= 1.0 - step(sprite_height - submerged_pixels, row);
	if (petrified) {
		float grey = dot(COLOR.rgb, vec3(0.299, 0.587, 0.114));
		COLOR.rgb = vec3(grey * 0.88, grey * 0.91, grey);
	} else {
		COLOR.rgb = mix(COLOR.rgb, potion_flash_color.rgb, potion_flash_strength);
	}
}
