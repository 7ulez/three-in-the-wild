class_name Massif
extends Node3D
## Der Berg im Osten: ein echter Gipfel mit Schichtenfels, ein Geröllpfad windet sich einmal
## rund um den Berg hinauf zum Aussichtsplatz (29 m hoch). Die Hänge sind zu steil zum Laufen,
## nur der Pfad führt hinauf. Dazu eine Höhle mit zwei Eingängen, Kristallen, einem Loch im
## Boden und einer Schatzkiste.
##
## Der Berg selbst (Fels + herausgeschnittener Pfad + Höhlen) wird einmal vorberechnet
## (tools/bake_mountain.gd) und als Datei geladen - das spart beim Spielstart Rechenzeit.

const C: Vector3 = Vector3(100, 0, -72)     # Mitte des Bergs
const R: float = 30.0                        # Radius am Boden
const H: float = 38.0                        # Höhe der (gedachten) Spitze
const CUT: float = 29.0                      # Höhe der abgeflachten Gipfelfläche
const TOP_Y: float = CUT
const SIDES: int = 36
const RINGS: int = 14
const PATH_TH0: float = 2.4                  # Startwinkel des Pfads (Südwest)
const PATH_Y0: float = 0.0
const PATH_Y1: float = 29.0
const PATH_K: int = 170

const MESH_FILE := "res://assets/mountain_mesh.res"
const SHAPE_FILE := "res://assets/mountain_shape.res"

const ROCK_SHADER: String = """
shader_type spatial;
render_mode shadows_disabled;
varying vec3 wp;
varying vec3 wn;
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1.0, 0.0)), f.x), mix(h(i + vec2(0.0, 1.0)), h(i + vec2(1.0, 1.0)), f.x), f.y);
}
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
	vec2 q = vec2(wp.x + wp.z, wp.y);
	float n = vn(q * vec2(0.5, 1.6)) * 0.6 + vn(q * vec2(1.7, 4.0)) * 0.4;
	float band = fract(floor(wp.y * 0.9 + n * 1.6) * 0.618);
	vec3 col = mix(vec3(0.50, 0.45, 0.40), vec3(0.38, 0.34, 0.32), step(0.5, band));
	col = mix(col, vec3(0.60, 0.53, 0.44), step(0.8, band));
	col *= 0.85 + 0.3 * n;
	float crack = smoothstep(0.04, 0.0, abs(vn(vec2(q.x * 1.3, q.y * 0.12) + 7.0) - 0.5));
	col *= 1.0 - crack * 0.0;
	float moss = smoothstep(3.0, 0.0, wp.y + n * 2.0);
	col = mix(col, vec3(0.28, 0.40, 0.20), moss * 0.6);
	float snow = smoothstep(21.0, 25.0, wp.y + n * 3.0) * smoothstep(0.2, 0.7, wn.y + n * 0.3);
	col = mix(col, vec3(0.95, 0.96, 0.98), snow);
	ALBEDO = col;
	ROUGHNESS = 0.95;
}
"""

const GRAVEL_SHADER: String = """
shader_type spatial;
render_mode shadows_disabled;
varying vec3 wp;
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1.0, 0.0)), f.x), mix(h(i + vec2(0.0, 1.0)), h(i + vec2(1.0, 1.0)), f.x), f.y);
}
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float s = h(floor(wp.xz * 7.0) + floor(wp.y * 7.0));
	vec3 col = mix(vec3(0.66, 0.61, 0.54), vec3(0.42, 0.39, 0.37), s);
	col *= 0.88 + 0.24 * vn(wp.xz * 0.9);
	ALBEDO = col;
	ROUGHNESS = 1.0;
}
"""

const FLOOR_SHADER: String = """
shader_type spatial;
render_mode shadows_disabled;
varying vec3 wp;
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1.0, 0.0)), f.x), mix(h(i + vec2(0.0, 1.0)), h(i + vec2(1.0, 1.0)), f.x), f.y);
}
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = wp.xz;
	float cell = h(floor(p * 3.0));
	float n = vn(p * 0.7) * 0.6 + vn(p * 2.3) * 0.4;
	vec3 col = mix(vec3(0.28, 0.25, 0.22), vec3(0.38, 0.34, 0.3), cell * 0.25 + n * 0.75);
	float crack = smoothstep(0.05, 0.0, abs(fract(p.x * 0.6 + n * 0.8) - 0.5) - 0.44);
	col *= 1.0 - crack * 0.5;
	float damp = smoothstep(0.55, 0.8, vn(p * 0.35 + 5.0));
	col = mix(col, vec3(0.16, 0.24, 0.2), damp * 0.5);
	ALBEDO = col;
	EMISSION = col * 0.08;
	ROUGHNESS = 0.95;
}
"""

const CAVE_SHADER: String = """
shader_type spatial;
render_mode shadows_disabled;
varying vec3 wp;
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1.0, 0.0)), f.x), mix(h(i + vec2(0.0, 1.0)), h(i + vec2(1.0, 1.0)), f.x), f.y);
}
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 q = vec2(wp.x + wp.z, wp.y);
	float n = vn(q * vec2(0.9, 1.4)) * 0.6 + vn(q * vec2(3.1, 5.0)) * 0.4;
	float strata = step(0.5, fract(wp.y * 1.3 + n * 1.2));
	vec3 col = mix(vec3(0.37, 0.32, 0.29), vec3(0.31, 0.27, 0.25), strata * 0.8);
	float streak = smoothstep(0.55, 0.9, vn(vec2((wp.x + wp.z) * 2.6, wp.y * 0.15)));
	col = mix(col, vec3(0.50, 0.46, 0.40), streak * 0.4);
	float moss = smoothstep(1.3, 0.0, wp.y + n) * 0.55;
	col = mix(col, vec3(0.20, 0.32, 0.22), moss);
	float vein = smoothstep(0.02, 0.0, abs(vn(q * vec2(0.5, 0.35) + 3.0) - 0.5)) * smoothstep(0.5, 0.7, vn(q * 0.2 + 9.0));
	col *= 0.8 + 0.4 * n;
	ALBEDO = col + vec3(0.1, 0.3, 0.4) * vein * 0.4;
	EMISSION = col * 0.12 + vec3(0.1, 0.3, 0.4) * vein * 0.35;
	ROUGHNESS = 0.9;
}
"""

var main: Node
var summit_reached: bool = false
var pit_area: Area3D
var cave_entry: Vector3 = Vector3(63, 0.6, -74)
var path_pts: Array = []     # [Vector3] Mitte des begehbaren Pfads (für Tests und Deko)


class Chest:
	extends StaticBody3D
	var opened: bool = false
	var lid: Node3D
	var glow: OmniLight3D = null
	var gold: Node3D = null

	func get_prompt() -> String:
		return "E: Schatzkiste öffnen" if not opened else "Die Kiste ist leer"

	func interact_with_held(player: Node, _item: Node) -> bool:
		# Auch mit etwas in der Hand soll die Kiste aufgehen
		interact(player)
		return true

	func interact(player: Node) -> void:
		if opened:
			return
		opened = true
		Game.treasure_found = true
		create_tween().tween_property(lid, "rotation_degrees:x", 112.0, 0.85).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if glow != null:
			create_tween().tween_property(glow, "light_energy", 2.2, 0.8)
		if gold != null:
			gold.visible = true
		player.toast("SCHATZ! Ein goldener Glücksköder - die Fische beißen jetzt schneller! Und eine alte Schatzkarte: Auf der Karte (M) ist ein X eingezeichnet.", 8.0)
		Game.map_found = true
		if player.has_method("get_minihud"):
			player.get_minihud().card("SCHATZKARTE!", "Schau auf die Karte (M) - da ist ein X", Color(0.95, 0.8, 0.3), 5.0)
		Sfx.play("chest_open", global_position, 0.0)
		Sfx.play("pop", Vector3.INF, -2.0, 1.2)


# ---------------------------------------------------------------------------
# Form des Bergs
# ---------------------------------------------------------------------------

## Radius der Bergoberfläche in Höhe y beim Winkel theta (Grundform, ohne Zacken).
static func surf_r(theta: float, y: float) -> float:
	var f := 1.0 + 0.07 * sin(3.0 * theta + 1.3) + 0.04 * sin(5.0 * theta + 0.4) + 0.03 * sin(9.0 * theta + 2.0)
	return R * f * (1.0 - y / H)


static func at_polar(theta: float, r: float, y: float) -> Vector3:
	return Vector3(C.x + cos(theta) * r, y, C.z + sin(theta) * r)


## Pfadhöhe an einem Winkel (der Pfad umrundet den Berg genau einmal, gegen den Uhrzeigersinn
## der Winkel-Zählung, also mit abnehmendem Winkel).
static func path_t(theta: float) -> float:
	return fposmod(PATH_TH0 - theta, TAU) / TAU


static var _ytab: PackedFloat32Array = PackedFloat32Array()


## Pfadhöhe: steigt gleichmäßig pro Meter Weg (nicht pro Winkel), damit es oben,
## wo der Kreis klein ist, nicht steiler wird als unten.
static func path_y(t: float) -> float:
	var n := 400
	if _ytab.is_empty():
		var ys := PackedFloat32Array()
		ys.resize(n + 1)
		for k in range(n + 1):
			ys[k] = lerpf(PATH_Y0, PATH_Y1, float(k) / n)
		for _it in range(6):
			var acc := PackedFloat32Array()
			acc.resize(n + 1)
			for k in range(1, n + 1):
				var tm := (float(k) - 0.5) / n
				var th := PATH_TH0 - TAU * tm
				var r := surf_r(th, ys[k]) - 1.3
				acc[k] = acc[k - 1] + r * TAU / n
			for k in range(n + 1):
				ys[k] = PATH_Y0 + (PATH_Y1 - PATH_Y0) * acc[k] / acc[n]
		_ytab = ys
	var f := clampf(t, 0.0, 1.0) * n
	var k0 := mini(int(f), n - 1)
	return lerpf(_ytab[k0], _ytab[k0 + 1], f - k0)


static func _flip_if_needed(verts: PackedVector3Array, idx: PackedInt32Array) -> PackedInt32Array:
	# Godot: Vorderseite = im Uhrzeigersinn. Ein nach außen gerichteter Körper hat dann negatives Volumen.
	var vol := 0.0
	for i in range(0, idx.size(), 3):
		var a := verts[idx[i]]
		var b := verts[idx[i + 1]]
		var c := verts[idx[i + 2]]
		vol += a.dot(b.cross(c)) / 6.0
	if vol > 0.0:
		var out := PackedInt32Array()
		for i in range(0, idx.size(), 3):
			out.append(idx[i])
			out.append(idx[i + 2])
			out.append(idx[i + 1])
		return out
	return idx


static func _mesh_from(verts: PackedVector3Array, idx: PackedInt32Array) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = _flip_if_needed(verts, idx)
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return am


## Geschlossener Bergkörper (Stumpf mit zerklüfteter Oberfläche).
static func mountain_mesh() -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150
	var ys: Array = [-0.6]
	for k in range(RINGS + 1):
		ys.append(CUT * float(k) / float(RINGS))
	var verts := PackedVector3Array()
	for j in range(ys.size()):
		for i in range(SIDES):
			var th := TAU * float(i) / float(SIDES)
			var y: float = ys[j]
			var jit := 0.0
			if j > 0 and j < ys.size() - 1:
				jit = rng.randf_range(-0.5, 0.5)
			verts.append(at_polar(th, surf_r(th, y) + jit, y))
	var bottom := verts.size()
	verts.append(Vector3(C.x, ys[0], C.z))
	var top := verts.size()
	verts.append(Vector3(C.x, CUT, C.z))
	var idx := PackedInt32Array()
	for j in range(ys.size() - 1):
		for i in range(SIDES):
			var i2 := (i + 1) % SIDES
			var a := j * SIDES + i
			var b := j * SIDES + i2
			var c := (j + 1) * SIDES + i2
			var d := (j + 1) * SIDES + i
			idx.append_array([a, b, c, a, c, d])
	for i in range(SIDES):
		var i2 := (i + 1) % SIDES
		idx.append_array([bottom, i2, i])
		var last := (ys.size() - 1) * SIDES
		idx.append_array([top, last + i, last + i2])
	return _mesh_from(verts, idx)


## Der Pfad als Körper, der aus dem Berg herausgeschnitten wird: eine Stufe, die einmal
## um den Berg läuft und dabei langsam steigt.
static func path_cut_mesh() -> ArrayMesh:
	var verts := PackedVector3Array()
	var idx := PackedInt32Array()
	for i in range(PATH_K + 1):
		var t := float(i) / float(PATH_K)
		var th := PATH_TH0 - TAU * t
		var y := path_y(t)
		var rs := surf_r(th, y)
		var win := lerpf(2.4, 3.4, smoothstep(0.0, 0.04, t))
		var ht := 2.2 * win + 1.2
		var pts: Array = [[rs - win, y], [rs + 2.4, y], [rs + 2.4, y + ht], [rs - win, y + ht]]
		for p in pts:
			verts.append(at_polar(th, p[0], p[1]))
	for i in range(PATH_K):
		for k in range(4):
			var k2 := (k + 1) % 4
			var a := i * 4 + k
			var b := i * 4 + k2
			var c := (i + 1) * 4 + k2
			var d := (i + 1) * 4 + k
			idx.append_array([a, b, c, a, c, d])
	idx.append_array([0, 1, 2, 0, 2, 3])
	var e := PATH_K * 4
	idx.append_array([e, e + 2, e + 1, e, e + 3, e + 2])
	return _mesh_from(verts, idx)


## Der ganze Berg als CSG-Körper (wird nur beim Vorberechnen oder als Notlösung genutzt).
static func make_csg() -> CSGCombiner3D:
	var rock := ShaderMaterial.new()
	rock.shader = Shader.new()
	rock.shader.code = ROCK_SHADER
	var gravel := ShaderMaterial.new()
	gravel.shader = Shader.new()
	gravel.shader.code = GRAVEL_SHADER
	var dark := ShaderMaterial.new()
	dark.shader = Shader.new()
	dark.shader.code = CAVE_SHADER

	var comb := CSGCombiner3D.new()
	var body := CSGMesh3D.new()
	body.mesh = mountain_mesh()
	body.material = rock
	comb.add_child(body)
	for c in cave_cuts():
		var cut := CSGBox3D.new()
		cut.operation = CSGShape3D.OPERATION_SUBTRACTION
		cut.position = c[0]
		cut.size = c[1]
		cut.material = dark
		comb.add_child(cut)
	var pc := CSGMesh3D.new()
	pc.operation = CSGShape3D.OPERATION_SUBTRACTION
	pc.mesh = path_cut_mesh()
	pc.material = gravel
	comb.add_child(pc)
	return comb


## Höhlenräume: [Mitte, Größe]
static func cave_cuts() -> Array:
	return [
		[Vector3(76, 1.75, -74), Vector3(28, 3.5, 3.8)],        # Westtunnel (offen zum Hang)
		[Vector3(95, 2.5, -74), Vector3(14, 5, 14)],             # Kammer
		[Vector3(95, 1.75, -94.5), Vector3(3.8, 3.5, 27)],       # Nordtunnel (offen zum Hang)
		[Vector3(105.5, 1.5, -74), Vector3(7, 3, 4)],            # Schatznische
	]


# ---------------------------------------------------------------------------
# Aufbau
# ---------------------------------------------------------------------------
func build(p_main: Node) -> void:
	main = p_main
	_build_mountain()
	_build_caves()
	_build_secret_entrances()
	_build_path_decor()
	_build_boulders()
	_build_summit()
	_build_signs()


func _build_mountain() -> void:
	if ResourceLoader.exists(MESH_FILE) and ResourceLoader.exists(SHAPE_FILE):
		var mi := MeshInstance3D.new()
		mi.mesh = load(MESH_FILE)
		add_child(mi)
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		cs.shape = load(SHAPE_FILE)
		body.add_child(cs)
		body.set_meta("surface", "massif")
		add_child(body)
	else:
		var comb := make_csg()
		comb.use_collision = true
		comb.set_meta("surface", "massif")
		add_child(comb)


func _build_caves() -> void:
	for c in cave_cuts():
		var half: Vector3 = (c[1] as Vector3) / 2.0
		var box := AABB((c[0] as Vector3) - half, c[1])
		main.cave_boxes.append(box)
		var flm := ShaderMaterial.new()
		flm.shader = Shader.new()
		flm.shader.code = FLOOR_SHADER
		# Bodenplatte nur im Berginneren (die Tunnel ragen nach aussen ueber den Hang hinaus)
		var fb := box
		if (c[1] as Vector3).x > 20.0:
			fb = AABB(Vector3(74.0, box.position.y, box.position.z), Vector3(box.end.x - 74.0, box.size.y, box.size.z))
		elif (c[1] as Vector3).z > 20.0:
			fb = AABB(Vector3(box.position.x, box.position.y, -101.5), Vector3(box.size.x, box.size.y, -81.0 + 101.5))
		var flb := BoxMesh.new()
		flb.size = Vector3(fb.size.x, 0.06, fb.size.z)
		var fli := _add_mesh(flb, flm, Vector3(fb.get_center().x, 0.03, fb.get_center().z))
		fli.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Kristalle (leuchten) in der Höhle
	var crystal_cols: Array = [Color(0.3, 0.9, 1.0), Color(0.8, 0.4, 1.0), Color(0.4, 1.0, 0.6)]
	var spots: Array = [Vector3(78, 0, -75.5), Vector3(85, 0, -72.3), Vector3(89.5, 0, -78), Vector3(101, 0, -80),
		Vector3(91, 0, -68), Vector3(95.8, 0, -84), Vector3(94, 0, -94), Vector3(96.5, 0, -99), Vector3(107, 0, -75.5)]
	for i in range(spots.size()):
		var sp: Vector3 = spots[i]
		var col: Color = crystal_cols[i % crystal_cols.size()]
		var cm := StandardMaterial3D.new()
		cm.albedo_color = col
		cm.emission_enabled = true
		cm.emission = col
		cm.emission_energy_multiplier = 1.4
		for k in range(3):
			var cr := MeshInstance3D.new()
			var pm := PrismMesh.new()
			pm.size = Vector3(0.25, 0.7 + 0.25 * k, 0.2)
			cr.mesh = pm
			cr.material_override = cm
			cr.position = sp + Vector3(0.15 * k - 0.15, 0.4 + 0.1 * k, 0.1 * k)
			cr.rotation_degrees = Vector3(10 * k - 10, 40 * k, 12 - 12 * k)
			add_child(cr)
		var l := OmniLight3D.new()
		l.light_color = col
		l.light_energy = 1.6
		l.omni_range = 7.0
		l.position = sp + Vector3(0, 1.0, 0)
		add_child(l)

	# Loch im Kammerboden
	var pit := Util.add_box(self, Vector3(4.0, 0.04, 4.0), Color(0.0, 0.0, 0.0), Vector3(96.5, 0.06, -74.0))
	pit.name = "Pit"
	for i in range(14):
		var a := TAU * float(i) / 14.0
		Util.add_sphere(self, 0.35, Color(0.4, 0.38, 0.36), Vector3(96.5 + cos(a) * 2.3, 0.15, -74.0 + sin(a) * 2.3))
	pit_area = Area3D.new()
	var pcs := CollisionShape3D.new()
	var pbs := BoxShape3D.new()
	pbs.size = Vector3(3.6, 2.0, 3.6)
	pcs.shape = pbs
	pit_area.add_child(pcs)
	pit_area.position = Vector3(96.5, 1.0, -74.0)
	add_child(pit_area)
	pit_area.body_entered.connect(_on_pit)

	_build_treasure()
	_build_cave_decor()


## Die schöne Truhe (wie in den Verstecken) auf einem Steinsockel in der Nische, mit Goldschatz.
func _build_treasure() -> void:
	var chest := Chest.new()
	chest.collision_layer = 1
	var ccs := CollisionShape3D.new()
	var cbs := BoxShape3D.new()
	cbs.size = Vector3(1.4, 0.9, 1.0)
	ccs.shape = cbs
	ccs.position.y = 0.45
	chest.add_child(ccs)
	var vis := Node3D.new()
	vis.scale = Vector3.ONE * 1.4
	chest.add_child(vis)
	var body_ok := ItemModels._glb(vis, "truhe_korpus") != null
	var lid := Node3D.new()
	lid.position = Vector3(0, 0.32, 0.25)
	vis.add_child(lid)
	if body_ok and ItemModels._glb(lid, "truhe_deckel") != null:
		pass
	else:
		Util.add_box(vis, Vector3(0.8, 0.35, 0.5), Color(0.5, 0.33, 0.16), Vector3(0, 0.18, 0))
		Util.add_box(lid, Vector3(0.82, 0.14, 0.52), Color(0.42, 0.27, 0.12), Vector3(0, 0.07, -0.25))
		Util.add_box(vis, Vector3(0.1, 0.12, 0.04), Color(0.85, 0.7, 0.2), Vector3(0, 0.3, -0.26))
	chest.lid = lid
	# Goldhaufen in der Truhe (erst nach dem Öffnen sichtbar)
	var gold := Node3D.new()
	gold.visible = false
	vis.add_child(gold)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(1.0, 0.8, 0.2)
	gm.metallic = 0.4
	gm.roughness = 0.35
	gm.emission_enabled = true
	gm.emission = Color(1.0, 0.7, 0.1)
	gm.emission_energy_multiplier = 0.5
	var coin_m := CylinderMesh.new()
	coin_m.top_radius = 0.045
	coin_m.bottom_radius = 0.045
	coin_m.height = 0.012
	coin_m.radial_segments = 8
	var coin_xf: Array = []
	for i in range(26):
		var rr := rng.randf() * 0.26
		var an := rng.randf() * TAU
		var cb := Basis.from_euler(Vector3(deg_to_rad(rng.randf_range(-25, 25)), 0, deg_to_rad(rng.randf_range(-25, 25))))
		coin_xf.append(Transform3D(cb, Vector3(cos(an) * rr, 0.26 + 0.07 * (1.0 - rr / 0.26) + rng.randf() * 0.02, sin(an) * rr * 0.7)))
	_multi(gold, coin_m, gm, coin_xf)
	chest.gold = gold
	var gl := OmniLight3D.new()
	gl.light_color = Color(1.0, 0.8, 0.35)
	gl.light_energy = 0.0
	gl.omni_range = 5.0
	gl.position = Vector3(0, 0.9, 0)
	chest.add_child(gl)
	chest.glow = gl
	chest.position = Vector3(107.2, 0.14, -74.0)
	chest.rotation.y = PI / 2.0
	add_child(chest)
	# Sockel
	Util.add_box(self, Vector3(1.9, 0.14, 1.5), Color(0.42, 0.4, 0.38), Vector3(107.2, 0.07, -74.0))
	Util.add_box(self, Vector3(2.2, 0.05, 1.8), Color(0.3, 0.28, 0.27), Vector3(107.2, 0.025, -74.0))


func _glow_mat(col: Color, energy: float = 1.6) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = energy
	return m


var _deco: Node3D = null   # Container der Höhlen-Deko (wird ausgeblendet, wenn der Spieler weit weg ist)


func _add_mesh(mesh: Mesh, mat: Material, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(_deco if _deco != null else self).add_child(mi)
	return mi


## Viele gleiche Teile als ein einziges MultiMesh (im Browser zählen Einzel-Meshes teuer).
func _multi(parent: Node, mesh: Mesh, mat: Material, xf: Array) -> void:
	if xf.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xf.size()
	for i in range(xf.size()):
		mm.set_instance_transform(i, xf[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


func _cone_mesh(r: float, h: float, seg: int = 6) -> CylinderMesh:
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = seg
	cm.rings = 1
	return cm


## Die Höhle schön machen: Boden, Tropfsteine, Stützbalken, Gleise mit Lore, Teich,
## Leuchtpilze, Fackeln, Schatznische mit Gold, Edelsteinen und Knochen.
func _build_cave_decor() -> void:
	_deco = CaveDecor.new()
	_deco.name = "CaveDecor"
	add_child(_deco)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.58, 0.54, 0.5)
	stone.roughness = 1.0
	var stone_d := StandardMaterial3D.new()
	stone_d.albedo_color = Color(0.42, 0.39, 0.37)
	stone_d.roughness = 1.0
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.4, 0.27, 0.15)
	wood.roughness = 1.0
	var wood_l := StandardMaterial3D.new()
	wood_l.albedo_color = Color(0.5, 0.35, 0.2)
	wood_l.roughness = 1.0
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.3, 0.3, 0.33)
	iron.metallic = 0.3
	iron.roughness = 0.6

	# --- Tropfsteine: Stalaktiten von der Decke, Stalagmiten vom Boden ---
	for i in range(34):
		var px := rng.randf_range(89.0, 101.0)
		var pz := rng.randf_range(-80.0, -68.0)
		var r := rng.randf_range(0.14, 0.42)
		var hh := rng.randf_range(0.7, 2.0)
		_add_mesh(_cone_mesh(r, hh), stone if i % 2 == 0 else stone_d, Vector3(px, 5.0 - hh * 0.5 + 0.02, pz), Vector3(180, rng.randf() * 90.0, 0))
	for i in range(12):
		var px2 := rng.randf_range(89.0, 101.0)
		var pz2 := rng.randf_range(-80.0, -68.0)
		if Vector2(px2 - 96.5, pz2 + 74.0).length() < 3.6 or (absf(pz2 + 74.0) < 2.6 and px2 < 91.0):
			continue
		var r2 := rng.randf_range(0.18, 0.4)
		var h2 := rng.randf_range(0.5, 1.5)
		_add_mesh(_cone_mesh(r2, h2), stone, Vector3(px2, h2 * 0.5, pz2), Vector3(0, rng.randf() * 90.0, 0))
	for i in range(14):
		var tx := rng.randf_range(77.0, 88.0)
		var h3 := rng.randf_range(0.3, 0.9)
		_add_mesh(_cone_mesh(rng.randf_range(0.08, 0.2), h3), stone_d, Vector3(tx, 3.5 - h3 * 0.5 + 0.02, -74.0 + rng.randf_range(-1.6, 1.6)), Vector3(180, 0, 0))
	for i in range(10):
		var tz := rng.randf_range(-99.0, -83.0)
		var h4 := rng.randf_range(0.3, 0.9)
		_add_mesh(_cone_mesh(rng.randf_range(0.08, 0.2), h4), stone_d, Vector3(95.0 + rng.randf_range(-1.5, 1.5), 3.5 - h4 * 0.5 + 0.02, tz), Vector3(180, 0, 0))

	# --- Stützbalken (alter Minenstollen) ---
	for fx in [78.0, 82.0, 86.0]:
		_support_frame(Vector3(fx, 0, -74.0), false, wood, wood_l)
	for fz in [-86.0, -90.0, -94.0, -97.5]:
		_support_frame(Vector3(95.0, 0, fz), true, wood, wood_l)

	# --- Gleise + Lore im Weststollen ---
	for gz in [-73.35, -74.65]:
		_add_mesh(BoxMesh.new(), iron, Vector3(85.0, 0.11, gz)).scale = Vector3(18.0, 0.05, 0.07)
	var sx := 76.5
	while sx < 94.0:
		var sl := BoxMesh.new()
		sl.size = Vector3(0.16, 0.06, 1.9)
		_add_mesh(sl, wood_l, Vector3(sx, 0.05, -74.0))
		sx += 0.9
	_build_cart(Vector3(80.0, 0.0, -74.0), wood, iron)

	# --- Teich in der Kammer ---
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.15, 0.45, 0.62, 0.75)
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wm.metallic = 0.4
	wm.roughness = 0.08
	wm.emission_enabled = true
	wm.emission = Color(0.05, 0.25, 0.35)
	wm.emission_energy_multiplier = 0.6
	var pool := CylinderMesh.new()
	pool.top_radius = 1.9
	pool.bottom_radius = 1.9
	pool.height = 0.03
	pool.radial_segments = 14
	var pm := _add_mesh(pool, wm, Vector3(99.4, 0.07, -69.2))
	pm.scale = Vector3(1.0, 1.0, 0.7)
	for i in range(12):
		var a := TAU * float(i) / 12.0
		var rs := rng.randf_range(0.18, 0.34)
		var sph := SphereMesh.new()
		sph.radius = rs
		sph.height = rs * 1.4
		sph.radial_segments = 6
		sph.rings = 3
		_add_mesh(sph, stone, Vector3(99.4 + cos(a) * 2.0, 0.08, -69.2 + sin(a) * 1.45))

	# --- Leuchtpilze ---
	var shroom_cols: Array = [Color(0.3, 1.0, 0.7), Color(0.4, 0.7, 1.0), Color(0.9, 0.5, 1.0)]
	var shroom_spots: Array = [Vector3(90.0, 0, -79.2), Vector3(100.8, 0, -78.5), Vector3(89.2, 0, -69.0), Vector3(94.3, 0, -85.5),
		Vector3(95.8, 0, -97.0), Vector3(79.0, 0, -72.4), Vector3(84.0, 0, -75.6), Vector3(101.3, 0, -69.4)]
	var cap_xf: Array = [[], [], []]
	var stem_mat := StandardMaterial3D.new()
	stem_mat.albedo_color = Color(0.85, 0.85, 0.8)
	for i in range(shroom_spots.size()):
		var spt: Vector3 = shroom_spots[i]
		for k in range(4):
			var off := Vector3(rng.randf_range(-0.3, 0.3), 0, rng.randf_range(-0.3, 0.3))
			var sh := rng.randf_range(0.12, 0.34)
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.02
			cyl.bottom_radius = 0.03
			cyl.height = sh
			cyl.radial_segments = 5
			_add_mesh(cyl, stem_mat, spt + off + Vector3(0, sh * 0.5, 0))
			var cr := rng.randf_range(0.07, 0.14)
			(cap_xf[i % 3] as Array).append(Transform3D(Basis().scaled(Vector3(cr, cr * 0.6, cr)), spt + off + Vector3(0, sh, 0)))
	var cap_mesh := SphereMesh.new()
	cap_mesh.radius = 1.0
	cap_mesh.height = 2.0
	cap_mesh.radial_segments = 6
	cap_mesh.rings = 3
	for ci in range(3):
		_multi(_deco, cap_mesh, _glow_mat(shroom_cols[ci], 1.8), cap_xf[ci])

	# --- Fackeln (nur leuchtende Flamme, kein Licht) ---
	var torch_spots: Array = [Vector3(79.2, 1.9, -75.6), Vector3(79.2, 1.9, -72.4), Vector3(88.3, 2.0, -70.0), Vector3(88.3, 2.0, -78.0),
		Vector3(101.7, 2.0, -70.0), Vector3(101.7, 2.0, -78.0), Vector3(93.3, 1.9, -84.0), Vector3(96.7, 1.9, -84.0), Vector3(108.7, 1.8, -75.5), Vector3(108.7, 1.8, -72.5)]
	var flame_xf: Array = []
	var core_xf: Array = []
	for tsp in torch_spots:
		_torch(tsp as Vector3, wood, iron)
		flame_xf.append(Transform3D(Basis().scaled(Vector3(1, 1.6, 1)), (tsp as Vector3) + Vector3(0, 0.34, 0)))
		core_xf.append(Transform3D(Basis().scaled(Vector3(1, 1.6, 1)), (tsp as Vector3) + Vector3(0, 0.33, 0)))
	var fl_mesh := SphereMesh.new()
	fl_mesh.radius = 0.1
	fl_mesh.height = 0.2
	fl_mesh.radial_segments = 6
	fl_mesh.rings = 3
	var co_mesh := SphereMesh.new()
	co_mesh.radius = 0.055
	co_mesh.height = 0.11
	co_mesh.radial_segments = 6
	co_mesh.rings = 3
	_multi(_deco, fl_mesh, _glow_mat(Color(1.0, 0.55, 0.15), 2.4), flame_xf)
	_multi(_deco, co_mesh, _glow_mat(Color(1.0, 0.9, 0.5), 3.0), core_xf)
	var nl := OmniLight3D.new()
	nl.light_color = Color(1.0, 0.7, 0.35)
	nl.light_energy = 1.4
	nl.omni_range = 6.5
	nl.position = Vector3(106.0, 2.3, -74.0)
	_deco.add_child(nl)

	# --- Schatznische: Münzen, Edelsteine, Knochen, Wächter-Schädel ---
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(1.0, 0.8, 0.2)
	gmat.metallic = 0.4
	gmat.roughness = 0.35
	gmat.emission_enabled = true
	gmat.emission = Color(1.0, 0.7, 0.1)
	gmat.emission_energy_multiplier = 0.5
	var cm2 := CylinderMesh.new()
	cm2.top_radius = 0.08
	cm2.bottom_radius = 0.08
	cm2.height = 0.02
	cm2.radial_segments = 8
	var ncoin_xf: Array = []
	for i in range(28):
		var a2 := rng.randf() * TAU
		var rr := rng.randf_range(0.9, 2.1)
		var nb := Basis.from_euler(Vector3(deg_to_rad(rng.randf_range(-12, 12)), 0, deg_to_rad(rng.randf_range(-12, 12))))
		ncoin_xf.append(Transform3D(nb, Vector3(107.2 + cos(a2) * rr * 0.9 - 0.3, 0.025, -74.0 + sin(a2) * rr * 0.55)))
	_multi(_deco, cm2, gmat, ncoin_xf)
	var gem_cols: Array = [Color(1.0, 0.2, 0.3), Color(0.2, 0.6, 1.0), Color(0.3, 1.0, 0.5), Color(0.9, 0.3, 1.0)]
	for i in range(6):
		var gem := PrismMesh.new()
		gem.size = Vector3(0.14, 0.2, 0.14)
		var ga := rng.randf() * TAU
		var gr := rng.randf_range(1.0, 1.8)
		_add_mesh(gem, _glow_mat(gem_cols[i % 4], 1.8), Vector3(106.6 + cos(ga) * gr * 0.7, 0.1, -74.0 + sin(ga) * gr * 0.5), Vector3(rng.randf_range(-20, 20), rng.randf() * 360.0, rng.randf_range(-20, 20)))
	# Schädel + Knochen am Nischeneingang
	var bone := StandardMaterial3D.new()
	bone.albedo_color = Color(0.88, 0.85, 0.75)
	bone.roughness = 0.9
	var skull := SphereMesh.new()
	skull.radius = 0.15
	skull.height = 0.28
	skull.radial_segments = 8
	skull.rings = 4
	_add_mesh(skull, bone, Vector3(103.6, 0.14, -75.1), Vector3(0, 30, 0))
	var jaw := BoxMesh.new()
	jaw.size = Vector3(0.14, 0.05, 0.1)
	_add_mesh(jaw, bone, Vector3(103.5, 0.05, -75.0), Vector3(0, 30, 0))
	var eye := StandardMaterial3D.new()
	eye.albedo_color = Color(0.05, 0.04, 0.04)
	for ez in [-0.06, 0.06]:
		var es := SphereMesh.new()
		es.radius = 0.04
		es.height = 0.07
		es.radial_segments = 6
		es.rings = 3
		_add_mesh(es, eye, Vector3(103.47, 0.17, -75.1 + ez), Vector3(0, 30, 0))
	for i in range(6):
		var bb := BoxMesh.new()
		bb.size = Vector3(0.5, 0.05, 0.05)
		_add_mesh(bb, bone, Vector3(103.7 + rng.randf_range(-0.5, 0.5), 0.03, -75.5 + rng.randf_range(-0.5, 0.4)), Vector3(0, rng.randf() * 180.0, 0))
	# Rippen: Bogen aus Zylindern wäre zu viel - ein paar schräge Knochen genügen

	# --- Bodenschotter ---
	var pebble_t: Array = []
	var pebble_c: Array = []
	var cuts: Array = cave_cuts()
	for i in range(240):
		var c: Array = cuts[rng.randi() % cuts.size()]
		var cc: Vector3 = c[0]
		var sz: Vector3 = c[1]
		var pp := Vector3(cc.x + rng.randf_range(-0.48, 0.48) * sz.x, 0.0, cc.z + rng.randf_range(-0.48, 0.48) * sz.z)
		if Vector2(pp.x - 96.5, pp.z + 74.0).length() < 2.5:
			continue
		var ps := rng.randf_range(0.05, 0.16)
		pp.y = ps * 0.2
		pebble_t.append(Transform3D(Basis.from_euler(Vector3(rng.randf() * 3.0, rng.randf() * 6.0, 0)).scaled(Vector3(ps, ps * 0.6, ps)), pp))
		var g := rng.randf_range(0.28, 0.5)
		pebble_c.append(Color(g, g * 0.95, g * 0.9))
	_add_stones(pebble_t, pebble_c)


func _support_frame(pos: Vector3, along_z: bool, wood: Material, wood_l: Material) -> void:
	# Zwei Pfosten + Querbalken + Schrägstreben. along_z = Stollen läuft in Z-Richtung
	var half := 1.72
	var h := 3.3
	for sgn in [-1.0, 1.0]:
		var post := BoxMesh.new()
		post.size = Vector3(0.22, h, 0.22)
		var pp := pos + (Vector3(sgn * half, h * 0.5, 0) if along_z else Vector3(0, h * 0.5, sgn * half))
		_add_mesh(post, wood, pp)
		var brace := BoxMesh.new()
		brace.size = Vector3(0.14, 0.9, 0.14)
		var bp := pos + (Vector3(sgn * (half - 0.35), h - 0.45, 0) if along_z else Vector3(0, h - 0.45, sgn * (half - 0.35)))
		var br := _add_mesh(brace, wood_l, bp)
		if along_z:
			br.rotation_degrees.z = -sgn * 45.0
		else:
			br.rotation_degrees.x = sgn * 45.0
	var beam := BoxMesh.new()
	beam.size = Vector3(0.24, 0.24, half * 2.0 + 0.5) if not along_z else Vector3(half * 2.0 + 0.5, 0.24, 0.24)
	_add_mesh(beam, wood, pos + Vector3(0, h + 0.05, 0))


func _build_cart(pos: Vector3, wood: Material, iron: Material) -> void:
	var cart := Node3D.new()
	cart.position = pos
	_deco.add_child(cart)
	var floor_b := BoxMesh.new()
	floor_b.size = Vector3(1.3, 0.08, 1.0)
	var parts: Array = [
		[floor_b, Vector3(0, 0.42, 0)],
	]
	var sw := BoxMesh.new()
	sw.size = Vector3(1.3, 0.5, 0.08)
	var ew := BoxMesh.new()
	ew.size = Vector3(0.08, 0.5, 1.0)
	parts.append([sw, Vector3(0, 0.7, 0.5)])
	parts.append([sw, Vector3(0, 0.7, -0.5)])
	parts.append([ew, Vector3(0.65, 0.7, 0)])
	parts.append([ew, Vector3(-0.65, 0.7, 0)])
	for pr in parts:
		var mi := MeshInstance3D.new()
		mi.mesh = pr[0]
		mi.material_override = wood
		mi.position = pr[1]
		cart.add_child(mi)
	for wx in [-0.4, 0.4]:
		for wz in [-0.62, 0.62]:
			var wh := CylinderMesh.new()
			wh.top_radius = 0.17
			wh.bottom_radius = 0.17
			wh.height = 0.06
			wh.radial_segments = 8
			var wi := MeshInstance3D.new()
			wi.mesh = wh
			wi.material_override = iron
			wi.position = Vector3(wx, 0.2, wz)
			wi.rotation_degrees.x = 90.0
			cart.add_child(wi)
	# Ladung: Erzbrocken (glitzernd)
	var ore := _glow_mat(Color(0.9, 0.75, 0.3), 0.7)
	for i in range(7):
		var os := SphereMesh.new()
		os.radius = 0.16
		os.height = 0.26
		os.radial_segments = 5
		os.rings = 3
		var oi := MeshInstance3D.new()
		oi.mesh = os
		oi.material_override = ore if i % 2 == 0 else iron
		oi.position = Vector3(-0.4 + 0.14 * float(i), 0.62 + 0.04 * float(i % 3), -0.2 + 0.13 * float(i % 4))
		cart.add_child(oi)
	cart.rotation_degrees.y = 8.0


func _torch(pos: Vector3, wood: Material, iron: Material) -> void:
	var stick := BoxMesh.new()
	stick.size = Vector3(0.07, 0.55, 0.07)
	_add_mesh(stick, wood, pos + Vector3(0, -0.05, 0))
	var holder := BoxMesh.new()
	holder.size = Vector3(0.14, 0.06, 0.14)
	_add_mesh(holder, iron, pos + Vector3(0, 0.1, 0))


## Geheimeingänge: beide Tunnelmünder sind mit Fels, Gestrüpp und Brocken zugewachsen.
## Nur eine niedrige Lücke am Boden bleibt (1,25 m hoch): man muss sich ducken (C) und durchkriechen.
func _build_secret_entrances() -> void:
	# Westeingang (Tunnel läuft in X-Richtung, Mund bei x ~ 74)
	_secret_plug(Vector3(74.7, 0.0, -74.0), false)
	# Nordeingang (Tunnel läuft in Z-Richtung, Mund bei z ~ -102)
	_secret_plug(Vector3(95.0, 0.0, -101.0), true)


func _secret_plug(pos: Vector3, along_z: bool) -> void:
	var gap := 1.25
	var body := StaticBody3D.new()
	body.position = pos + Vector3(0, (gap + 3.8) * 0.5, 0)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(4.2, 3.8 - gap, 1.7) if along_z else Vector3(1.7, 3.8 - gap, 4.2)
	bs.size = Vector3(bs.size.x, bs.size.y, bs.size.z)
	cs.shape = bs
	body.add_child(cs)
	body.set_meta("surface", "massif")
	add_child(body)
	var rng := RandomNumberGenerator.new()
	rng.seed = 909 + (1 if along_z else 0)
	# Felsen-Verschluss über der Lücke
	var outward := Vector3(0, 0, -1) if along_z else Vector3(-1, 0, 0)
	var side := Vector3(1, 0, 0) if along_z else Vector3(0, 0, 1)
	var base := pos + outward * 0.5
	for i in range(9):
		var u := rng.randf_range(-1.9, 1.9)
		var v := rng.randf_range(gap + 0.35, 3.5)
		var rad := rng.randf_range(0.8, 1.3)
		var cpos := base + side * u + Vector3(0, v, 0) + outward * rng.randf_range(-0.2, 0.5)
		_rock(cpos, Vector3(rad, rad * 0.8, rad), rng.randi(), 0.4, false)
	# Brocken und Moos beiderseits der Lücke (nicht darin)
	for sgn in [-1.0, 1.0]:
		var r2 := rng.randf_range(0.7, 1.0)
		_rock(base + side * (1.7 * float(sgn)) + outward * 0.9 + Vector3(0, r2 * 0.4, 0), Vector3(r2, r2 * 0.7, r2), rng.randi(), 0.38, true)
	# Gestrüpp vor dem Spalt (Büsche ohne Kollision, man kriecht hindurch)
	for i in range(8):
		var bp := base + outward * rng.randf_range(0.6, 1.6) + side * rng.randf_range(-2.0, 2.0)
		var br := rng.randf_range(0.35, 0.65)
		var gcol := Color(0.2, 0.42, 0.18).lerp(Color(0.3, 0.5, 0.2), rng.randf())
		var bsp := Util.add_sphere(self, br, gcol, Vector3(bp.x, br * 0.8, bp.z))
		bsp.scale = Vector3(1.0, 0.8, 1.0)
	# Hinweis-Zone
	var zone := SecretZone.new()
	var zcs := CollisionShape3D.new()
	var zbs := BoxShape3D.new()
	zbs.size = Vector3(4.6, 2.0, 5.5) if along_z else Vector3(5.5, 2.0, 4.6)
	zcs.shape = zbs
	zone.add_child(zcs)
	zone.position = pos + outward * 1.2 + Vector3(0, 1.0, 0)
	zone.collision_mask = 0xFFFFF
	add_child(zone)
	zone.body_entered.connect(zone.on_enter)


class SecretZone:
	extends Area3D
	var _last: float = -100.0

	func on_enter(body: Node) -> void:
		if not (body is Player):
			return
		var now := Time.get_ticks_msec() / 1000.0
		if now - _last < 25.0:
			return
		_last = now
		var p := body as Player
		if p.crouching:
			p.toast("Du kriechst durch einen versteckten Spalt...", 3.0)
		else:
			p.toast("Zwischen den Felsen ist unten eine niedrige Lücke. Ducken (C) und durchkriechen?", 4.5)


## Mitte des begehbaren Pfads (Fläche zwischen Schnittwand und Hangkante).
func _build_path_decor() -> void:
	path_pts.clear()
	for i in range(PATH_K + 1):
		var t := float(i) / float(PATH_K)
		var th := PATH_TH0 - TAU * t
		var y := path_y(t)
		path_pts.append(at_polar(th, surf_r(th, y) - 1.3, y))
	# Kleine Steine verstreut auf dem Pfad + größere Randsteine
	var rng := RandomNumberGenerator.new()
	rng.seed = 808
	var small_t: Array = []
	var small_c: Array = []
	var big_t: Array = []
	var big_c: Array = []
	for i in range(0, PATH_K + 1):
		var t := float(i) / float(PATH_K)
		var th := PATH_TH0 - TAU * t
		var y := path_y(t)
		var rs := surf_r(th, y)
		var width := 3.0 * smoothstep(0.0, 0.06, t)
		for k in range(5):
			var rr := rs - rng.randf_range(0.5, maxf(width - 0.6, 0.6))
			var s := rng.randf_range(0.07, 0.2)
			var pos := at_polar(th + rng.randf_range(-0.01, 0.01), rr, y + s * 0.25)
			small_t.append(Transform3D(Basis.from_euler(Vector3(rng.randf() * 3.0, rng.randf() * 6.0, 0)).scaled(Vector3(s, s * 0.7, s)), pos))
			var g := rng.randf_range(0.42, 0.7)
			small_c.append(Color(g, g * 0.95, g * 0.88))
		if i % 2 == 0 and width > 1.5:
			var s2 := rng.randf_range(0.28, 0.5)
			var pos2 := at_polar(th, rs - rng.randf_range(0.1, 0.5), y + s2 * 0.2)
			big_t.append(Transform3D(Basis.from_euler(Vector3(rng.randf() * 3.0, rng.randf() * 6.0, 0)).scaled(Vector3(s2 * 1.3, s2, s2 * 1.1)), pos2))
			var g2 := rng.randf_range(0.35, 0.58)
			big_c.append(Color(g2, g2 * 0.95, g2 * 0.9))
	_add_stones(small_t, small_c)
	_add_stones(big_t, big_c)


func _add_stones(xf: Array, cols: Array) -> void:
	if xf.is_empty():
		return
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 5
	sm.rings = 3
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = sm
	mm.instance_count = xf.size()
	for i in range(xf.size()):
		mm.set_instance_transform(i, xf[i])
		mm.set_instance_color(i, cols[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 1.0
	mi.material_override = m
	add_child(mi)


## Felsbrocken am Fuß und ein paar Zacken am Hang, nicht auf dem Pfad und nicht vor den Höhlen.
func _build_boulders() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 321
	for i in range(30):
		var th := TAU * float(i) / 30.0 + rng.randf_range(-0.08, 0.08)
		if _near_angle(th, PATH_TH0, 0.28) or _near_angle(th, 3.27, 0.3) or _near_angle(th, -2.02, 0.26):
			continue
		var r := rng.randf_range(1.0, 2.3)
		var rr := surf_r(th, 0.5) + rng.randf_range(0.0, 2.0)
		_rock(at_polar(th, rr, r * 0.15), Vector3(r, r * rng.randf_range(0.6, 0.9), r), rng.randi(), 0.38, true)
	for i in range(14):
		var th2 := rng.randf_range(0.0, TAU)
		var y := rng.randf_range(5.0, 21.0)
		var py := path_y(path_t(th2))
		if absf(y - py) < 5.0:
			continue
		var s := rng.randf_range(1.2, 2.2)
		_rock(at_polar(th2, surf_r(th2, y) + s * 0.1, y), Vector3(s * 1.2, s * 1.0, s * 1.2), rng.randi(), 0.42, false)


static func _near_angle(a: float, b: float, w: float) -> bool:
	return absf(wrapf(a - b, -PI, PI)) < w


func _build_summit() -> void:
	# Aussichtsbank, Fahne am Gipfel
	var y := TOP_Y
	Util.add_box(self, Vector3(1.6, 0.1, 0.5), Color(0.5, 0.34, 0.2), Vector3(C.x + 2.6, y + 0.45, C.z + 2.8))
	Util.add_box(self, Vector3(0.1, 0.45, 0.4), Color(0.4, 0.27, 0.15), Vector3(C.x + 1.9, y + 0.22, C.z + 2.8))
	Util.add_box(self, Vector3(0.1, 0.45, 0.4), Color(0.4, 0.27, 0.15), Vector3(C.x + 3.3, y + 0.22, C.z + 2.8))
	Util.add_cylinder(self, 0.05, 3.0, Color(0.8, 0.8, 0.8), Vector3(C.x - 1.0, y + 1.5, C.z - 1.0))
	Util.add_box(self, Vector3(1.0, 0.6, 0.03), Color(0.9, 0.2, 0.15), Vector3(C.x - 0.5, y + 2.6, C.z - 1.0))
	# Steinhaufen (Gipfelmarke)
	for i in range(9):
		var a := TAU * float(i) / 9.0
		var rr := 0.5 + 0.35 * float(i % 3)
		Util.add_sphere(self, 0.3 + 0.1 * float(i % 2), Color(0.55, 0.53, 0.5), Vector3(C.x - 1.0 + cos(a) * rr, y + 0.15, C.z - 1.0 + sin(a) * rr))


func _build_signs() -> void:
	var start := at_polar(PATH_TH0, surf_r(PATH_TH0, 0.0) + 4.5, 0.0)
	var sp1 := Signpost.new()
	add_child(sp1)
	sp1.position = start
	sp1.build([
		{"text": "Gipfelpfad: steil, Absturzgefahr!", "yaw": 0.0, "y": 2.2},
		{"text": "Aussichtspunkt 29 m", "yaw": 0.0, "y": 1.7},
		{"text": "Parkplatz", "yaw": 180.0, "y": 1.2},
	])


## Ein kantiger Felsbrocken (zerbeulte Kugel, flach schattiert, Farbe nach Höhe).
func _rock(center: Vector3, radii: Vector3, seed_v: int, rough: float, collide: bool) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var segs := 9
	var rings := 6
	var grid: Array = []
	for r in range(rings + 1):
		var row: Array = []
		var phi := PI * float(r) / float(rings)
		for sg in range(segs):
			var th := TAU * float(sg) / float(segs)
			var d := 1.0 + rough * (rng.randf() - 0.5)
			if r == 0 or r == rings:
				d = 1.0
			var v := Vector3(sin(phi) * cos(th), cos(phi), sin(phi) * sin(th)) * d
			row.append(center + Vector3(v.x * radii.x, v.y * radii.y, v.z * radii.z))
		grid.append(row)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in range(rings):
		for sg in range(segs):
			var s2 := (sg + 1) % segs
			var a: Vector3 = grid[r][sg]
			var b: Vector3 = grid[r][s2]
			var c: Vector3 = grid[r + 1][sg]
			var e: Vector3 = grid[r + 1][s2]
			_tri(st, a, c, b, rng)
			_tri(st, b, c, e, rng)
	st.generate_normals()
	var mesh := st.commit()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.95
	mi.material_override = m
	add_child(mi)
	if collide:
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		cs.shape = mesh.create_trimesh_shape()
		body.add_child(cs)
		add_child(body)


func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, rng: RandomNumberGenerator) -> void:
	var cr := (b - a).cross(c - a)
	if cr.length() < 0.0001:
		return
	var n := cr.normalized()
	var cy := (a.y + b.y + c.y) / 3.0
	var col := Color(0.5, 0.45, 0.4).lerp(Color(0.36, 0.33, 0.31), rng.randf())
	if cy > 20.0 and n.y > 0.3:
		col = col.lerp(Color(0.95, 0.96, 0.98), 0.8)
	elif n.y > 0.55 and cy < 4.0:
		col = col.lerp(Color(0.3, 0.45, 0.22), 0.6)
	col = col.darkened(clampf(0.25 - n.y * 0.25, 0.0, 0.25))
	for v in [a, b, c]:
		st.set_color(col)
		st.add_vertex(v)


func _on_pit(body: Node) -> void:
	if body is Player:
		var p := body as Player
		p.needs.damage(35.0, "In ein Loch gefallen.")
		p.teleport_to(cave_entry)


func _process(_delta: float) -> void:
	if main == null or main.player == null:
		return
	if summit_reached and not Game.summit_sunrise:
		var sp: Vector3 = main.player.global_position
		if sp.y > TOP_Y - 1.5 and Vector2(sp.x - C.x, sp.z - C.z).length() < 11.0 and Game.hour >= 5.0 and Game.hour < 7.5:
			Game.summit_sunrise = true
			main.player._update_help()
	if summit_reached:
		return
	var p: Vector3 = main.player.global_position
	if p.y > TOP_Y - 0.8 and Vector2(p.x - C.x, p.z - C.z).length() < 9.0:
		summit_reached = true
		Game.summit = true
		main.player.toast("Aussichtspunkt erreicht! Was für ein Blick über den See und die Wälder.", 6.0)


## Höhlen-Deko: im Browser ist die Zahl gleichzeitig sichtbarer Objekte begrenzt,
## darum wird sie nur gezeichnet, wenn der Spieler in der Nähe ist.
class CaveDecor extends Node3D:
	var _t: float = 0.0

	func _process(delta: float) -> void:
		_t -= delta
		if _t > 0.0:
			return
		_t = 0.5
		var main: Node = get_parent().get_parent()
		var pl: Variant = main.get("player") if main != null else null
		if pl is Node3D:
			visible = (pl as Node3D).global_position.distance_to(Vector3(95.0, 0.0, -74.0)) < 90.0
