shader_type canvas_item;

uniform float strength = 0.28;
uniform float focus = 0.0;
uniform float hurt = 0.0;
uniform vec3 tint : source_color = vec3(1.0, 0.8, 0.5);
uniform float tint_amt = 0.05;

void fragment() {
	vec2 p = UV - 0.5;
	p.x *= 1.15;
	float v = smoothstep(0.45, 1.15, length(p) * 1.45);
	float a_v = v * (strength + focus * 0.3 + hurt * 0.25);
	vec3 c_v = mix(vec3(0.02, 0.03, 0.04), vec3(0.55, 0.0, 0.0), hurt);
	float a_t = tint_amt * (1.0 - v);
	float a = a_v + a_t;
	vec3 c = (c_v * a_v + tint * a_t) / max(a, 0.0001);
	COLOR = vec4(c, clamp(a, 0.0, 1.0));
}
