shader_type spatial;

uniform float sway = 0.06;
uniform float light_top = 0.35;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float t = TIME * 1.1;
	float w = sin(t + wp.x * 0.21 + wp.z * 0.17) + 0.4 * sin(t * 2.1 + wp.x * 0.5);
	float h = max(VERTEX.y, 0.0);
	VERTEX.x += w * sway * h * 0.35;
	VERTEX.z += w * sway * h * 0.2;
}

void fragment() {
	vec3 wn = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	float up = wn.y * 0.5 + 0.5;
	ALBEDO = COLOR.rgb * (0.78 + light_top * up);
	ROUGHNESS = 0.9;
}
