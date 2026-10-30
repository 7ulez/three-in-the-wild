shader_type sky;

uniform vec3 top_col : source_color = vec3(0.25, 0.55, 0.85);
uniform vec3 hor_col : source_color = vec3(0.95, 0.8, 0.62);
uniform vec3 ground_col : source_color = vec3(0.3, 0.45, 0.3);
uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform vec3 sun_col : source_color = vec3(1.0, 0.95, 0.85);
uniform vec3 moon_dir = vec3(0.0, -1.0, 0.0);
uniform float night = 0.0;
uniform float moon_phase = 0.5;   // 0 Neumond, 0.5 Vollmond
uniform float cloud_amt = 0.5;
uniform vec3 cloud_lit : source_color = vec3(1.0, 0.97, 0.92);
uniform vec3 cloud_shade : source_color = vec3(0.62, 0.68, 0.78);
uniform sampler2D cloud_tex : filter_linear_mipmap, repeat_enable;

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void sky() {
	vec3 d = normalize(EYEDIR);
	float h = d.y;
	vec3 col;
	if (h > 0.0) {
		col = mix(hor_col, top_col, pow(h, 0.55));
	} else {
		col = mix(hor_col, ground_col, smoothstep(0.0, 0.25, -h));
	}
	// Sonnenschein am Horizont
	float sd = max(dot(d, normalize(sun_dir)), 0.0);
	col += sun_col * pow(sd, 6.0) * 0.18 * (1.0 - night);
	col += sun_col * pow(sd, 48.0) * 0.4 * (1.0 - night);
	float disc = smoothstep(0.9990, 0.9996, sd);
	col = mix(col, sun_col * 3.0, disc * (1.0 - night));
	// Mond
	float md = max(dot(d, normalize(moon_dir)), 0.0);
	vec3 mn = normalize(moon_dir);
	vec3 mr = normalize(cross(mn, vec3(0.0, 1.0, 0.0)));
	vec3 mu = cross(mr, mn);
	vec2 mp = vec2(dot(d - mn, mr), dot(d - mn, mu)) / 0.036;     // Mondscheibe: Radius 1
	float mdisc = (1.0 - smoothstep(0.85, 1.0, length(mp))) * step(0.0, dot(d, mn));
	float illum = 0.5 - 0.5 * cos(moon_phase * 6.2831853);
	float side = moon_phase < 0.5 ? 1.0 : -1.0;                       // zunehmend rechts, abnehmend links hell
	float lit_m = smoothstep(0.9, 1.1, length(mp - vec2(side * 2.2 * illum, 0.0)));
	if (illum > 0.97) { lit_m = 1.0; }
	vec3 mcol = mix(vec3(0.05, 0.06, 0.1), vec3(0.92, 0.95, 1.0), lit_m);
	col = mix(col, mcol, mdisc * night);
	col += vec3(0.3, 0.4, 0.7) * pow(md, 60.0) * 0.25 * night * illum;
	// Sterne
	if (h > 0.02 && night > 0.05) {
		vec2 sp = d.xz / (d.y + 0.4) * 90.0;
		vec2 cell = floor(sp);
		float r = hash(cell);
		float star = step(0.985, r) * smoothstep(0.35, 0.0, length(fract(sp) - 0.5));
		col += vec3(star) * night * (0.6 + 0.4 * sin(TIME * 2.0 + r * 40.0));
	}
	// Wolken
	if (h > 0.02) {
		vec2 cuv = d.xz / (h + 0.25) * 0.35 + vec2(TIME * 0.004, TIME * 0.0015);
		float c = texture(cloud_tex, cuv).r * 0.65 + texture(cloud_tex, cuv * 2.7 + 3.1).r * 0.35;
		float dens = smoothstep(1.0 - cloud_amt * 0.65, 1.0 - cloud_amt * 0.65 + 0.2, c);
		dens *= smoothstep(0.02, 0.2, h);
		float lit = clamp(0.35 + 0.65 * sd + (c - 0.5), 0.0, 1.0);
		vec3 cc = mix(cloud_shade, cloud_lit, lit);
		cc = mix(cc, hor_col * 1.1, 0.25 * (1.0 - smoothstep(0.0, 0.4, h)));
		cc *= mix(1.0, 0.12, night);
		col = mix(col, cc, dens * 0.9);
	}
	COLOR = col;
}
