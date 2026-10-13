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
	col *= 1.0 - crack * 0.28;
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

var main: Node
var summit_reached: bool = false
var pit_area: Area3D
var cave_entry: Vector3 = Vector3(63, 0.6, -74)
var path_pts: Array = []     # [Vector3] Mitte des begehbaren Pfads (für Tests und Deko)


class Chest:
	extends StaticBody3D
	var opened: bool = false
	var lid: Node3D

	func get_prompt() -> String:
		return "E: Schatzkiste öffnen" if not opened else "Die Kiste ist leer"

	func interact(player: Node) -> void:
		if opened:
			return
		opened = true
		Game.treasure_found = true
		create_tween().tween_property(lid, "rotation_degrees:x", 110.0, 0.6)
		player.toast("SCHATZ! Ein goldener Glücksköder - die Fische beißen jetzt schneller!", 6.0)


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
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.3, 0.27, 0.25)
	dark.roughness = 0.95

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
		add_child(body)
	else:
		var comb := make_csg()
		comb.use_collision = true
		add_child(comb)


func _build_caves() -> void:
	for c in cave_cuts():
		var half: Vector3 = (c[1] as Vector3) / 2.0
		var box := AABB((c[0] as Vector3) - half, c[1])
		main.cave_boxes.append(box)
		Util.add_box(self, Vector3(box.size.x, 0.06, box.size.z), Color(0.22, 0.2, 0.19), Vector3(box.get_center().x, 0.03, box.get_center().z))

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

	# Schatzkiste
	var chest := Chest.new()
	var ccs := CollisionShape3D.new()
	var cbs := BoxShape3D.new()
	cbs.size = Vector3(0.9, 0.6, 0.6)
	ccs.shape = cbs
	ccs.position.y = 0.3
	chest.add_child(ccs)
	Util.add_box(chest, Vector3(0.9, 0.4, 0.6), Color(0.45, 0.28, 0.12), Vector3(0, 0.2, 0))
	var lid := Node3D.new()
	lid.position = Vector3(0, 0.4, 0.3)
	chest.add_child(lid)
	Util.add_box(lid, Vector3(0.94, 0.15, 0.64), Color(0.5, 0.32, 0.14), Vector3(0, 0.075, -0.3))
	Util.add_box(lid, Vector3(0.12, 0.1, 0.04), Color(0.95, 0.8, 0.2), Vector3(0, 0.0, -0.62))
	chest.lid = lid
	chest.position = Vector3(107.2, 0.0, -74.0)
	chest.rotation.y = PI / 2.0
	add_child(chest)


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
	var sp2 := Signpost.new()
	add_child(sp2)
	sp2.position = Vector3(65, 0, -70)
	sp2.build([
		{"text": "Höhle - Kopflampe (L)!", "yaw": 0.0, "y": 2.1},
		{"text": "Vorsicht Loch", "yaw": 0.0, "y": 1.6},
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
	if main == null or main.player == null or summit_reached:
		return
	var p: Vector3 = main.player.global_position
	if p.y > TOP_Y - 0.8 and Vector2(p.x - C.x, p.z - C.z).length() < 9.0:
		summit_reached = true
		Game.summit = true
		main.player.toast("Aussichtspunkt erreicht! Was für ein Blick über den See und die Wälder.", 6.0)
