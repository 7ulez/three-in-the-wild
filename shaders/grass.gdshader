shader_type spatial;
render_mode cull_disabled;

uniform vec3 base_col : source_color = vec3(0.13, 0.28, 0.08);
uniform float sway = 0.18;
uniform float fade_start = 55.0;
uniform float fade_end = 85.0;

varying float tip;
varying float fade;

void vertex() {
	tip = UV.y;
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME * 1.6;
	float w = sin(t + wp.x * 0.35 + wp.z * 0.27) + 0.5 * sin(t * 2.3 + wp.x * 0.9 + wp.z * 0.7);
	VERTEX.x += w * sway * tip * tip;
	VERTEX.z += w * sway * 0.5 * tip * tip;
	float dist = length((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
	fade = clamp((fade_end - dist) / (fade_end - fade_start), 0.0, 1.0);
	// verschwindet im Nahen gar nicht, weit weg schrumpfen die Halme
	VERTEX.y *= mix(0.0, 1.0, smoothstep(0.0, 0.5, fade));
}

void fragment() {
	ALBEDO = mix(base_col, COLOR.rgb, tip);
	ROUGHNESS = 0.85;
	SPECULAR = 0.1;
}
