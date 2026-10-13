shader_type spatial;
// Natürlicher Kiesplatz: unregelmäßige, ausgefranste Form aus Noise, Körnung aus Kieseln.
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
	vec2 p = wpos.xz - vec2(0.0, 1.0);
	float warp = vnoise(p * 0.22) * 2.0 - 1.0;
	float warp2 = vnoise(p * 1.1 + 5.0) * 2.0 - 1.0;
	float r = length(vec2(p.x / 14.0, p.y / 7.5)) + warp * 0.16 + warp2 * 0.03;
	// zum Rand hin immer weniger Kiesel
	float cover = 1.0 - smoothstep(0.78, 1.04, r);
	vec2 cell = floor(p * 9.0);
	float rnd = hash(cell + 3.0);
	if (rnd > cover) discard;
	// Kiesel: pro Zelle Form und Farbe
	vec2 f = fract(p * 9.0) - 0.5;
	float d = length(f + (vec2(hash(cell), hash(cell + 7.0)) - 0.5) * 0.3);
	float shade = hash(cell + 11.0);
	vec3 gravel = mix(vec3(0.43, 0.40, 0.35), vec3(0.62, 0.57, 0.48), shade);
	gravel = mix(gravel, vec3(0.55, 0.45, 0.35), step(0.85, hash(cell + 21.0)) * 0.7);
	float pebble = smoothstep(0.55, 0.2, d);
	vec3 dirt = vec3(0.3, 0.26, 0.2);
	// Fahrspuren / festgefahrene Stellen
	float worn = smoothstep(0.55, 0.75, vnoise(p * vec2(0.5, 0.18) + 3.0));
	vec3 base = mix(gravel, gravel * 0.8, worn * 0.5);
	ALBEDO = mix(dirt, base, pebble * 0.85 + 0.15);
	ROUGHNESS = 0.95;
}
