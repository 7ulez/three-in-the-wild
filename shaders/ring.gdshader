shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;

uniform float progress = 0.0;
uniform float alpha = 0.7;

void fragment() {
	float r = length(UV - 0.5) * 2.0;
	float ring_r = 0.25 + progress * 0.7;
	float band = smoothstep(0.1, 0.0, abs(r - ring_r));
	ALBEDO = vec3(0.95, 0.98, 1.0);
	ALPHA = band * alpha * (1.0 - progress);
}
