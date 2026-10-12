shader_type canvas_item;

uniform float blend_width : hint_range(0.0, 0.5) = 0.0875;
uniform float grain_strength : hint_range(0.0, 1.0) = 0.28;
uniform float grain_scale = 160.0;
uniform float tone_steps = 6.0;
uniform vec4 fog_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);


float hash(vec2 point) {
	return fract(sin(dot(point, vec2(127.1, 311.7))) * 43758.5453123);
}


float edge_alpha(float edge_distance, vec2 grain_uv) {
	float coverage = clamp(edge_distance / blend_width, 0.0, 1.0);
	if (coverage <= 0.0 || coverage >= 1.0) {
		return coverage;
	}

	float smooth_coverage = smoothstep(0.0, 1.0, coverage);
	float grain = (hash(floor(grain_uv * grain_scale)) - 0.5) * grain_strength;
	float edge_weight = 1.0 - abs(smooth_coverage * 2.0 - 1.0);
	float grain_coverage = clamp(smooth_coverage + grain * edge_weight, 0.0, 1.0);
	return round(grain_coverage * tone_steps) / tone_steps;
}


void fragment() {
	float fade_alpha = COLOR.a;
	float edge_distance = min(min(UV.x, UV.y), min(1.0 - UV.x, 1.0 - UV.y));
	float alpha = edge_alpha(edge_distance, UV);
	COLOR = vec4(fog_color.rgb, fog_color.a * alpha * fade_alpha);
}
