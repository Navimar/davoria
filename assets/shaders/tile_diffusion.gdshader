shader_type canvas_item;

uniform float overlap_width : hint_range(0.0, 0.5) = 0.1;
uniform float blend_width : hint_range(0.0, 0.5) = 0.2;
uniform float diffusion_width : hint_range(0.0, 0.5) = 0.0875;
uniform float diffusion_start : hint_range(0.0, 0.5) = 0.05625;
uniform float grain_strength : hint_range(0.0, 1.0) = 0.28;
uniform float tone_steps = 6.0;
uniform float outline_width : hint_range(0.0, 0.1) = 0.01875;
uniform float outline_jitter : hint_range(0.0, 0.1) = 0.0125;
uniform vec4 outline_color : source_color = vec4(0.03, 0.025, 0.02, 1.0);
uniform bool diffuse_left = true;
uniform bool diffuse_right = true;
uniform bool diffuse_top = true;
uniform bool diffuse_bottom = true;
uniform bool outline_left = false;
uniform bool outline_right = false;
uniform bool outline_top = false;
uniform bool outline_bottom = false;


float hash(vec2 point) {
	return fract(sin(dot(point, vec2(127.1, 311.7))) * 43758.5453123);
}


float edge_alpha(float edge_distance, vec2 grain_uv) {
	float coverage = clamp((edge_distance - diffusion_start) / diffusion_width, 0.0, 1.0);
	if (coverage <= 0.0 || coverage >= 1.0) {
		return coverage;
	}

	float smooth_coverage = smoothstep(0.0, 1.0, coverage);
	float grain = (hash(floor(grain_uv * 160.0)) - 0.5) * grain_strength;
	float edge_weight = 1.0 - abs(smooth_coverage * 2.0 - 1.0);
	float grain_coverage = clamp(smooth_coverage + grain * edge_weight, 0.0, 1.0);
	return round(grain_coverage * tone_steps) / tone_steps;
}


void apply_side(inout float alpha, bool enabled, bool in_overlap, float edge_distance, vec2 grain_uv) {
	if (!in_overlap) {
		return;
	}

	if (enabled) {
		alpha = min(alpha, edge_alpha(edge_distance, grain_uv));
	} else if (edge_distance < overlap_width) {
		alpha = 0.0;
	}
}


float outline_side(bool enabled, float distance_from_cell_edge, float along_edge) {
	if (!enabled || distance_from_cell_edge < 0.0) {
		return 0.0;
	}

	float segment = floor(along_edge * 36.0);
	float jitter_a = hash(vec2(segment, 19.0));
	float jitter_b = hash(vec2(segment + 1.0, 19.0));
	float segment_blend = smoothstep(0.0, 1.0, fract(along_edge * 36.0));
	float jitter = mix(jitter_a, jitter_b, segment_blend) * outline_jitter;
	float width = outline_width + jitter;
	if (distance_from_cell_edge > width) {
		return 0.0;
	}

	return 1.0 - smoothstep(width * 0.45, width, distance_from_cell_edge);
}


void fragment() {
	vec4 color = texture(TEXTURE, UV);
	float mask_alpha = 1.0;

	apply_side(mask_alpha, diffuse_left, UV.x < blend_width, UV.x, UV);
	apply_side(mask_alpha, diffuse_right, UV.x > 1.0 - blend_width, 1.0 - UV.x, UV);
	apply_side(mask_alpha, diffuse_top, UV.y < blend_width, UV.y, UV);
	apply_side(mask_alpha, diffuse_bottom, UV.y > 1.0 - blend_width, 1.0 - UV.y, UV);

	float outline_alpha = 0.0;
	outline_alpha = max(outline_alpha, outline_side(outline_left, UV.x - overlap_width, UV.y));
	outline_alpha = max(outline_alpha, outline_side(outline_right, 1.0 - overlap_width - UV.x, UV.y));
	outline_alpha = max(outline_alpha, outline_side(outline_top, UV.y - overlap_width, UV.x));
	outline_alpha = max(outline_alpha, outline_side(outline_bottom, 1.0 - overlap_width - UV.y, UV.x));

	float outline_mix = outline_alpha * outline_color.a;
	color.rgb = mix(color.rgb * (1.0 - outline_mix * 0.35), outline_color.rgb, outline_mix);
	color.a *= mask_alpha;
	COLOR = color;
}
