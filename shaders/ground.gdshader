shader_type spatial;

uniform vec3 col_a : source_color = vec3(0.2, 0.38, 0.11);
uniform vec3 col_b : source_color = vec3(0.27, 0.45, 0.13);
uniform vec3 col_c : source_color = vec3(0.33, 0.28, 0.15);
varying vec3 wpos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz;
	float n1 = vnoise(p * 0.05) * 0.6 + vnoise(p * 0.18) * 0.3 + vnoise(p * 0.9) * 0.1;
	float n2 = vnoise(p * 0.031 + 17.0);
	vec3 c = mix(col_a, col_b, smoothstep(0.35, 0.7, n1));
	c = mix(c, col_c, smoothstep(0.62, 0.8, n2) * 0.7);
	ALBEDO = c;
	ROUGHNESS = 1.0;
}
