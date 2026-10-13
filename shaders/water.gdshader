shader_type spatial;
render_mode cull_disabled, specular_schlick_ggx;

uniform sampler2D shore_tex : filter_linear, repeat_disable;
uniform sampler2D wave_n : filter_linear_mipmap, repeat_enable;
uniform vec4 bounds = vec4(-40.0, -80.0, 80.0, 60.0); // minx, minz, sizex, sizez (lokal)
uniform float max_dist = 9.0;
uniform vec3 shallow_col : source_color = vec3(0.12, 0.42, 0.45);
uniform vec3 deep_col : source_color = vec3(0.02, 0.12, 0.2);
uniform vec3 foam_col : source_color = vec3(0.95, 0.97, 0.95);
uniform vec3 sky_col : source_color = vec3(0.5, 0.7, 0.9);
uniform float light_amt = 1.0;

varying vec2 loc;

void vertex() {
	loc = VERTEX.xz;
}

void fragment() {
	vec2 suv = (loc - bounds.xy) / bounds.zw;
	float d = texture(shore_tex, suv).r * max_dist; // Abstand zum Ufer in Metern
	vec2 w1 = loc * 0.11 + vec2(TIME * 0.020, TIME * 0.012);
	vec2 w2 = loc * 0.27 + vec2(-TIME * 0.025, TIME * 0.018);
	vec3 n1 = texture(wave_n, w1).xyz * 2.0 - 1.0;
	vec3 n2 = texture(wave_n, w2).xyz * 2.0 - 1.0;
	vec3 nm = normalize(vec3(n1.xy + n2.xy * 0.6, 1.0));
	NORMAL_MAP = nm * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 0.9;

	float deep = smoothstep(0.0, 7.0, d);
	vec3 col = mix(shallow_col, deep_col, deep);
	// Uferschaum: wabernde Kante
	float wob = (n1.x + n2.y) * 0.25;
	float edge = d + wob * 0.5 + sin(TIME * 1.3 + loc.x * 0.6 + loc.y * 0.4) * 0.12;
	float foam = smoothstep(0.75, 0.15, edge);
	foam *= 0.65 + 0.35 * sin(TIME * 1.7 - d * 7.0);
	// Glitzerpunkte
	float spark = smoothstep(0.86, 1.0, n1.x * 0.5 + n2.y * 0.5 + 0.5);
	float fres = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 4.0);
	col = mix(col, sky_col, clamp(fres * 0.5, 0.0, 0.5));
	ALBEDO = mix(col, foam_col, clamp(foam * 0.8, 0.0, 1.0)) * light_amt * 0.8;
	ALPHA = clamp(mix(0.62, 0.95, deep) + foam * 0.5 + fres * 0.15, 0.0, 1.0);
	ROUGHNESS = mix(0.14, 0.6, foam);
	SPECULAR = 0.45;
	EMISSION = sky_col * fres * 0.08 * light_amt + vec3(spark) * 0.08 * light_amt;
}
