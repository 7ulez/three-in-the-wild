class_name HideoutArt
extends RefCounted
## Bauteile für Höhlen und Verstecke: knubbelige Felsen, Baumstämme, Moos, Kristalle, Laternen.

static var _noise_tex: NoiseTexture2D = null


## Felsmaterial mit leichter Körnung (dreiflächig projiziert).
static func rock_mat(color: Color) -> StandardMaterial3D:
	if _noise_tex == null:
		var n := FastNoiseLite.new()
		n.noise_type = FastNoiseLite.TYPE_CELLULAR
		n.frequency = 0.03
		n.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
		var g := Gradient.new()
		g.set_color(0, Color(0.62, 0.62, 0.62))
		g.set_color(1, Color(1, 1, 1))
		_noise_tex = NoiseTexture2D.new()
		_noise_tex.noise = n
		_noise_tex.width = 128
		_noise_tex.height = 128
		_noise_tex.seamless = true
		_noise_tex.color_ramp = g
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.albedo_texture = _noise_tex
	m.roughness = 0.95
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(0.6, 0.6, 0.6)
	return m


## Knubbeliger Felsbrocken (flach schattierte Facetten). Mit collide = true läuft man nicht hindurch.
static func rock(parent: Node, pos: Vector3, radii: Vector3, seed_v: int, color: Color, collide: bool = false, rough: float = 0.28) -> MeshInstance3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var sm := SphereMesh.new()
	sm.radial_segments = 9
	sm.rings = 6
	var mdt := MeshDataTool.new()
	mdt.create_from_surface(_arr(sm), 0)
	var noise := FastNoiseLite.new()
	noise.seed = seed_v
	noise.frequency = 1.6
	for i in range(mdt.get_vertex_count()):
		var v := mdt.get_vertex(i)
		var n := noise.get_noise_3dv(v * 2.0 + Vector3(float(absi(seed_v) % 997), 0, 0))   # kleiner Versatz: riesige Seeds ergaben NaN-Felsen
		v *= 1.0 + n * rough
		v.y = maxf(v.y, -0.55)       # unten abgeflacht, liegt satt auf
		mdt.set_vertex(i, v * 2.0 * Vector3.ONE)
	# flach schattiert: pro Dreieck eine Normale
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for f in range(mdt.get_face_count()):
		var a := mdt.get_vertex(mdt.get_face_vertex(f, 0))
		var b := mdt.get_vertex(mdt.get_face_vertex(f, 1))
		var c := mdt.get_vertex(mdt.get_face_vertex(f, 2))
		var nrm := (b - a).cross(c - a).normalized()
		for p in [a, b, c]:
			st.set_normal(nrm)
			st.add_vertex(p)
	var mesh := st.commit()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = rock_mat(color.lightened(rng.randf() * 0.1))
	mi.scale = radii
	mi.position = pos
	mi.rotation.y = rng.randf() * TAU
	parent.add_child(mi)
	if collide:
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		cs.shape = mesh.create_convex_shape()
		body.add_child(cs)
		body.set_meta("surface", "rock")
		mi.add_child(body)
	return mi


static func _arr(sm: SphereMesh) -> ArrayMesh:
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, sm.get_mesh_arrays())
	return am


## Ein Stamm/Balken von a nach b.
static func beam(parent: Node, a: Vector3, b: Vector3, radius: float, color: Color, collide: bool = false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius * 0.92
	cm.bottom_radius = radius
	cm.height = a.distance_to(b)
	cm.radial_segments = 8
	mi.mesh = cm
	mi.material_override = Util.mat(color, 0.95)
	parent.add_child(mi)
	mi.position = (a + b) / 2.0
	var d := (b - a).normalized()
	if absf(d.dot(Vector3.UP)) < 0.999:
		mi.basis = Basis(Quaternion(Vector3.UP, d))
	elif d.y < 0.0:
		mi.rotation_degrees.x = 180.0
	if collide:
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = radius
		cyl.height = cm.height
		cs.shape = cyl
		body.add_child(cs)
		mi.add_child(body)
	return mi


static func moss(parent: Node, pos: Vector3, r: float, color: Color = Color(0.26, 0.45, 0.2)) -> void:
	var m := Util.add_sphere(parent, r, color, pos)
	m.scale = Vector3(1.0, 0.32, 1.0)


static func bush(parent: Node, pos: Vector3, r: float, rng: RandomNumberGenerator) -> void:
	for i in range(3):
		var c := Color(0.2, 0.46, 0.2).lerp(Color(0.38, 0.56, 0.2), rng.randf())
		var s := Util.add_sphere(parent, r * rng.randf_range(0.6, 0.95), c, pos + Vector3(rng.randf_range(-r, r) * 0.6, r * 0.5 + rng.randf() * 0.2, rng.randf_range(-r, r) * 0.6))
		s.scale = Vector3(1, 0.8, 1)


## Hängende (Tropfstein) oder stehende Spitze.
static func spike(parent: Node, pos: Vector3, r: float, h: float, color: Color, hanging: bool) -> void:
	var mi := Util.add_cone(parent, r, h, color, pos)
	if hanging:
		mi.rotation_degrees.x = 180.0
	mi.material_override = rock_mat(color)


static func crystal_cluster(parent: Node, pos: Vector3, col: Color, rng: RandomNumberGenerator, with_light: bool) -> void:
	var cm := StandardMaterial3D.new()
	cm.albedo_color = col
	cm.emission_enabled = true
	cm.emission = col
	cm.emission_energy_multiplier = 1.6
	cm.roughness = 0.2
	for i in range(5):
		var cr := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.0
		cyl.bottom_radius = rng.randf_range(0.07, 0.14)
		cyl.height = rng.randf_range(0.5, 1.1)
		cyl.radial_segments = 6
		cr.mesh = cyl
		cr.material_override = cm
		parent.add_child(cr)
		cr.position = pos + Vector3(rng.randf_range(-0.3, 0.3), cyl.height * 0.45, rng.randf_range(-0.3, 0.3))
		cr.rotation_degrees = Vector3(rng.randf_range(-22, 22), rng.randf() * 360.0, rng.randf_range(-22, 22))
	if with_light:
		var l := OmniLight3D.new()
		l.light_color = col
		l.light_energy = 0.8
		l.omni_range = 5.5
		l.distance_fade_enabled = true   # weit weg aus (Leistung)
		l.distance_fade_begin = 30.0
		l.distance_fade_length = 10.0
		l.position = pos + Vector3(0, 0.8, 0)
		parent.add_child(l)


static func puddle(parent: Node, pos: Vector3, r: float) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = 0.02
	cm.radial_segments = 14
	mi.mesh = cm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.2, 0.35, 0.45, 0.7)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.1
	m.metallic = 0.1
	mi.material_override = m
	mi.position = pos + Vector3(0, 0.03, 0)
	parent.add_child(mi)


static func lantern(parent: Node, pos: Vector3, energy: float = 0.9) -> void:
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(1.0, 0.75, 0.35)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.65, 0.25)
	glow.emission_energy_multiplier = 2.0
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.14, 0.2, 0.14)
	mi.mesh = bm
	mi.material_override = glow
	mi.position = pos
	parent.add_child(mi)
	Util.add_box(parent, Vector3(0.18, 0.03, 0.18), Color(0.12, 0.1, 0.08), pos + Vector3(0, 0.115, 0))
	Util.add_box(parent, Vector3(0.18, 0.03, 0.18), Color(0.12, 0.1, 0.08), pos + Vector3(0, -0.115, 0))
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.68, 0.35)
	l.light_energy = energy
	l.omni_range = 6.0
	l.distance_fade_enabled = true   # weit weg aus (Leistung)
	l.distance_fade_begin = 30.0
	l.distance_fade_length = 10.0
	l.position = pos
	parent.add_child(l)


## Massiver Kasten mit Kollision, aber gar nicht sichtbar (für Wände aus Stämmen).
static func hidden_wall(parent: Node, size: Vector3, pos: Vector3) -> void:
	var b := StaticBody3D.new()
	parent.add_child(b)
	b.position = pos
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	b.add_child(cs)
