shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never, blend_mix;

uniform vec4 col : source_color = vec4(1.0, 0.55, 0.15, 1.0);
uniform float strength = 0.4;
uniform float power = 2.0;

void fragment() {
	float r = clamp(length(UV - 0.5) * 2.0, 0.0, 1.0);
	float a = pow(1.0 - r, power) * strength;
	ALBEDO = col.rgb;
	ALPHA = a * col.a;
}
