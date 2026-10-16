class_name Hideouts
extends Node3D
## Höhlen und Verstecke rund um den See, mit Beute - und Fallen.
## Die Plätze (x, z, Radius) sind für Bäume gesperrt.

const SPOTS: Array = [
	{"id": "fuchsbau", "x": -105.0, "z": 50.0, "r": 9.0},     # Südwesten, hinter dem Parkplatz
	{"id": "huette", "x": -115.0, "z": -75.0, "r": 10.0},     # Nordwesten
	{"id": "tropf", "x": 95.0, "z": 55.0, "r": 13.0},         # Südosten
	{"id": "baum", "x": 10.0, "z": 72.0, "r": 7.0},           # Süden, direkt hinter dem Parkplatz
	{"id": "lager", "x": 20.0, "z": -112.0, "r": 8.0},        # Norden, hinter dem See
]

var main: Node


static func in_zone(pos: Vector3) -> bool:
	for s in SPOTS:
		var d := Vector2(pos.x - float(s["x"]), pos.z - float(s["z"])).length()
		if d < float(s["r"]):
			return true
	return false


func build(p_main: Node) -> void:
	main = p_main
	var lake_c := Vector3(0, 0, -35)
	for s in SPOTS:
		var root := Node3D.new()
		root.name = String(s["id"])
		add_child(root)
		root.position = Vector3(float(s["x"]), 0, float(s["z"]))
		root.look_at(Vector3(lake_c.x, 0, lake_c.z), Vector3.UP)   # lokales -Z zeigt zum See
		match String(s["id"]):
			"fuchsbau":
				_cave(root, Vector3(9, 4.2, 8), Vector3(2.4, 2.4, 6), Vector3(4.4, 2.8, 4.2), "Fuchsbau")
				_trap(root, "pit", Vector3(0.4, 0, -8.2))
				_trap(root, "bear", Vector3(-3.5, 0, -6.5))
				_mush(root, "gut", Vector3(5.5, 0, -3))
				_mush(root, "gift", Vector3(-5.5, 0, -2))
			"huette":
				_hut(root)
				_trap(root, "bear", Vector3(1.2, 0, -5.0))
				_trap(root, "wasp", Vector3(-3.0, 0, -2.0))
				_mush(root, "gift", Vector3(4.5, 0, 1))
				_mush(root, "gut", Vector3(-5, 0, 3))
			"tropf":
				_cave(root, Vector3(15, 6.2, 12), Vector3(3.2, 3.0, 8), Vector3(8.4, 4.2, 7.0), "Tropfsteinhöhle", true)
				_trap(root, "rocks", Vector3(0, 0, -6.5))
				_trap(root, "pit", Vector3(-2.6, 0, -10.0))
				_mush(root, "gift", Vector3(7.5, 0, -6))
				_mush(root, "beere", Vector3(-8.5, 0, -4))
			"baum":
				_hollow_tree(root)
				_trap(root, "wasp", Vector3(2.5, 0, -1.0))
				_trap(root, "bear", Vector3(-1.5, 0, -4.0))
				_mush(root, "beere", Vector3(3.5, 0, 3))
			"lager":
				_stone_camp(root)
				_trap(root, "bear", Vector3(2.0, 0, -5.0))
				_trap(root, "rocks", Vector3(-4.0, 0, -3.0))
				_mush(root, "gift", Vector3(4.5, 0, 2.5))
				_mush(root, "gut", Vector3(-4.5, 0, 3))
				_mush(root, "beere", Vector3(0, 0, 4.5))
	_scatter_forest_traps()
	_pebbles()


func _solid(parent: Node3D, size: Vector3, color: Color, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO) -> StaticBody3D:
	var b := StaticBody3D.new()
	parent.add_child(b)
	b.position = pos
	b.rotation_degrees = rot_deg
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	b.add_child(cs)
	Util.add_box(b, size, color)
	return b


func _trap(root: Node3D, kind: String, local: Vector3) -> void:
	var t := Trap.new()
	root.add_child(t)
	t.build(kind)
	t.position = local
	if kind == "rocks":
		pass


func _mush(root: Node3D, kind: String, local: Vector3) -> void:
	var m := Mushroom.new()
	root.add_child(m)
	m.build(kind)
	m.position = local


func _stash(root: Node3D, label: String, local: Vector3, chest: bool = true) -> Stash:
	var s := Stash.new()
	root.add_child(s)
	s.build(label, chest)
	s.position = local
	return s


## Höhle: knubbeliger Hügel mit gewölbtem Gang und runder Kammer (Eingang zum See = lokal -Z)
func _cave(root: Node3D, size: Vector3, tunnel: Vector3, chamber: Vector3, label: String, drip: bool = false) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(size.x * 13.0)
	var tint := Color(0.43, 0.46, 0.52) if drip else Color(0.5, 0.44, 0.38)
	var rmat := HideoutArt.rock_mat(tint)
	var comb := CSGCombiner3D.new()
	comb.use_collision = true
	root.add_child(comb)
	var hill := CSGSphere3D.new()
	hill.radial_segments = 14
	hill.rings = 8
	hill.radius = 1.0
	hill.smooth_faces = false
	hill.scale = Vector3(size.x * 0.56, size.y * 0.9, size.z * 0.58)
	hill.position = Vector3(0, size.y * 0.1, 0)
	hill.material = rmat
	comb.add_child(hill)
	var front := -size.z / 2.0
	var zc := front + tunnel.z / 2.0 - 1.2
	# Gewölbter Gang: Kasten (Boden) + liegender Zylinder (Decke)
	var tun := CSGCombiner3D.new()
	tun.operation = CSGShape3D.OPERATION_SUBTRACTION
	comb.add_child(tun)
	var tbox := CSGBox3D.new()
	tbox.size = Vector3(tunnel.x, tunnel.y * 0.5, tunnel.z)
	tbox.position = Vector3(0, tunnel.y * 0.25, zc)
	tbox.material = rmat
	tun.add_child(tbox)
	var tcy := CSGCylinder3D.new()
	tcy.radius = tunnel.x / 2.0
	tcy.height = tunnel.z
	tcy.sides = 12
	tcy.rotation_degrees.x = 90.0
	tcy.position = Vector3(0, tunnel.y * 0.5, zc)
	tcy.material = rmat
	tun.add_child(tcy)
	# Runde Kammer
	var cham := CSGSphere3D.new()
	cham.operation = CSGShape3D.OPERATION_SUBTRACTION
	cham.radial_segments = 12
	cham.rings = 7
	cham.smooth_faces = false
	cham.radius = 1.0
	cham.scale = Vector3(chamber.x * 0.5, chamber.y * 0.68, chamber.z * 0.5)
	var cz := size.z / 2.0 - 1.2 - chamber.z / 2.0
	cham.position = Vector3(0, chamber.y * 0.32, cz)
	cham.material = rmat
	comb.add_child(cham)
	# Innenräume merken (Welt-AABB) - dort wird es dunkel
	root.force_update_transform()
	var tun_aabb := AABB(Vector3(-tunnel.x / 2.0, 0, zc - tunnel.z / 2.0), Vector3(tunnel.x, tunnel.y, tunnel.z))
	var cham_aabb := AABB(Vector3(-chamber.x / 2.0, 0, cz - chamber.z / 2.0), Vector3(chamber.x, chamber.y, chamber.z))
	main.cave_boxes.append(root.global_transform * tun_aabb)
	main.cave_boxes.append(root.global_transform * cham_aabb)
	# Boden
	Util.add_box(root, Vector3(tunnel.x * 0.9, 0.05, tunnel.z), Color(0.2, 0.18, 0.17), Vector3(0, 0.03, zc))
	var fl := Util.add_cylinder(root, 0.5, 0.05, Color(0.2, 0.18, 0.17), Vector3(0, 0.03, cz))
	(fl.mesh as CylinderMesh).radial_segments = 14
	fl.scale = Vector3(chamber.x * 0.82, 1.0, chamber.z * 0.82)
	_stash(root, label + "-Kiste", Vector3(chamber.x * 0.2, 0, cz + chamber.z * 0.22))
	# ---- Außen: Felsen, Moos, Büsche ----
	for sgn in [-1.0, 1.0]:
		HideoutArt.rock(root, Vector3(sgn * (tunnel.x / 2.0 + 1.3), 0.7, front - 0.1), Vector3(1.5, 1.4, 1.3), rng.randi(), tint, true)
		HideoutArt.rock(root, Vector3(sgn * (tunnel.x / 2.0 + 2.8), 0.6, front + 0.9), Vector3(1.2, 1.1, 1.2), rng.randi(), tint.darkened(0.08), true)
	HideoutArt.rock(root, Vector3(0, tunnel.y + 0.85, front + 0.3), Vector3(tunnel.x * 1.1, 0.9, 1.3), rng.randi(), tint.lightened(0.04), false)
	for i in range(11):
		var ba := TAU * float(i) / 11.0 + rng.randf() * 0.3
		var bpos := Vector3(cos(ba) * size.x * 0.56, 0.3, sin(ba) * size.z * 0.58)
		if bpos.z < front + 2.0 and absf(bpos.x) < tunnel.x + 3.0:
			continue
		var br := rng.randf_range(0.7, 1.5)
		HideoutArt.rock(root, bpos, Vector3(br, br * 0.75, br), rng.randi(), tint.lightened(rng.randf() * 0.1), true)
	for i in range(5):
		HideoutArt.moss(root, Vector3(rng.randf_range(-size.x * 0.3, size.x * 0.3), size.y * rng.randf_range(0.82, 0.98), rng.randf_range(-size.z * 0.25, size.z * 0.3)), rng.randf_range(1.0, 1.8))
	for i in range(6):
		var a2 := rng.randf() * TAU
		HideoutArt.bush(root, Vector3(cos(a2) * size.x * rng.randf_range(0.3, 0.7), size.y * rng.randf_range(0.0, 0.5) * 0.4, sin(a2) * size.z * rng.randf_range(0.3, 0.7)), rng.randf_range(0.5, 0.9), rng)
	var wood := Color(0.34, 0.22, 0.12)
	if not drip:
		# Fuchsbau: Holzrahmen am Eingang, Wurzeln, Knochen, Laterne
		var hw := tunnel.x / 2.0
		HideoutArt.beam(root, Vector3(-hw - 0.15, 0, front - 0.9), Vector3(-hw - 0.15, tunnel.y + 0.25, front - 0.9), 0.13, wood, true)
		HideoutArt.beam(root, Vector3(hw + 0.15, 0, front - 0.9), Vector3(hw + 0.15, tunnel.y + 0.25, front - 0.9), 0.13, wood, true)
		HideoutArt.beam(root, Vector3(-hw - 0.4, tunnel.y + 0.2, front - 0.9), Vector3(hw + 0.4, tunnel.y + 0.2, front - 0.9), 0.12, wood.darkened(0.1))
		for i in range(6):
			var rx := rng.randf_range(-hw - 0.2, hw + 0.2)
			var rl := rng.randf_range(0.4, 1.1)
			HideoutArt.beam(root, Vector3(rx, tunnel.y + 0.9, front - 0.35), Vector3(rx + rng.randf_range(-0.2, 0.2), tunnel.y + 0.9 - rl, front - 0.4), 0.025, Color(0.3, 0.2, 0.12))
		HideoutArt.lantern(root, Vector3(hw + 0.1, tunnel.y - 0.35, front - 0.95), 0.9)
		for i in range(4):
			var bn := Util.add_cylinder(root, 0.03, 0.22, Color(0.9, 0.88, 0.8), Vector3(rng.randf_range(-1.2, 1.2), 0.04, front - 1.3 - rng.randf() * 1.0))
			bn.rotation_degrees = Vector3(90, rng.randf() * 180.0, 0)
		Util.add_sphere(root, 0.12, Color(0.92, 0.9, 0.82), Vector3(1.4, 0.1, front - 1.6))
		# Innen: Wurzeln von der Decke und Fackelschein
		for i in range(5):
			var ix := rng.randf_range(-chamber.x * 0.3, chamber.x * 0.3)
			var iz := cz + rng.randf_range(-chamber.z * 0.3, chamber.z * 0.3)
			HideoutArt.beam(root, Vector3(ix, chamber.y * 0.95, iz), Vector3(ix + rng.randf_range(-0.3, 0.3), chamber.y * 0.95 - rng.randf_range(0.6, 1.3), iz), 0.03, Color(0.3, 0.2, 0.12))
		HideoutArt.moss(root, Vector3(-chamber.x * 0.25, 0.04, cz - chamber.z * 0.2), 0.7)
		var l2 := OmniLight3D.new()
		l2.light_color = Color(1.0, 0.65, 0.3)
		l2.light_energy = 0.9
		l2.omni_range = 6.0
		l2.position = Vector3(0, 1.8, cz - 1.0)
		root.add_child(l2)
	else:
		# Tropfsteinhöhle: Zapfen am Eingang, Zapfen und Säulen innen, Pfützen, Kristalle
		for i in range(7):
			var sx := lerpf(-tunnel.x / 2.0, tunnel.x / 2.0, float(i) / 6.0)
			HideoutArt.spike(root, Vector3(sx, tunnel.y - 0.1, front - 0.5 + rng.randf() * 0.4), rng.randf_range(0.08, 0.16), rng.randf_range(0.4, 0.9), Color(0.7, 0.72, 0.76), true)
		for i in range(14):
			var sx2 := rng.randf_range(-chamber.x * 0.38, chamber.x * 0.38)
			var sz2 := cz + rng.randf_range(-chamber.z * 0.38, chamber.z * 0.38)
			HideoutArt.spike(root, Vector3(sx2, chamber.y * 0.88, sz2), rng.randf_range(0.1, 0.25), rng.randf_range(0.6, 1.6), Color(0.68, 0.7, 0.76), true)
		for i in range(8):
			var gx := rng.randf_range(-chamber.x * 0.36, chamber.x * 0.36)
			var gz := cz + rng.randf_range(-chamber.z * 0.36, chamber.z * 0.36)
			HideoutArt.spike(root, Vector3(gx, 0.4, gz), rng.randf_range(0.12, 0.26), rng.randf_range(0.5, 1.1), Color(0.62, 0.64, 0.7), false)
		for i in range(3):
			HideoutArt.puddle(root, Vector3(rng.randf_range(-chamber.x * 0.3, chamber.x * 0.3), 0.0, cz + rng.randf_range(-chamber.z * 0.3, chamber.z * 0.3)), rng.randf_range(0.6, 1.3))
		var cols := [Color(0.3, 0.9, 1.0), Color(0.8, 0.4, 1.0), Color(0.4, 1.0, 0.6)]
		for i in range(6):
			var ang := TAU * float(i) / 6.0 + 0.4
			HideoutArt.crystal_cluster(root, Vector3(cos(ang) * chamber.x * 0.38, 0.0, cz + sin(ang) * chamber.z * 0.38), cols[i % 3], rng, i % 2 == 0)
		for sgn in [-1.0, 1.0]:
			HideoutArt.crystal_cluster(root, Vector3(sgn * (tunnel.x / 2.0 + 0.6), 0.0, front - 0.8), cols[1 if sgn > 0 else 0], rng, false)


func _hut(root: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var wood := Color(0.42, 0.28, 0.16)
	var dk := Color(0.33, 0.22, 0.12)
	var lr := 0.15
	_solid(root, Vector3(4.6, 0.12, 3.8), dk, Vector3(0, 0.06, 0)).set_meta("surface", "wood")           # Boden
	# Kollisionswände (unsichtbar) - die Optik sind Blockhaus-Stämme
	HideoutArt.hidden_wall(root, Vector3(4.4, 2.3, 0.18), Vector3(0, 1.2, 1.8))
	HideoutArt.hidden_wall(root, Vector3(0.18, 2.3, 3.6), Vector3(-2.2, 1.2, 0))
	HideoutArt.hidden_wall(root, Vector3(0.18, 2.3, 3.6), Vector3(2.2, 1.2, 0))
	HideoutArt.hidden_wall(root, Vector3(1.6, 2.3, 0.18), Vector3(-1.4, 1.2, -1.8))
	HideoutArt.hidden_wall(root, Vector3(1.6, 2.3, 0.18), Vector3(1.4, 1.2, -1.8))
	var n := 8
	for k in range(n):
		var y := 0.2 + float(k) * 0.285
		var ov := 0.2 if k % 2 == 0 else 0.0
		var c := wood.lerp(dk, rng.randf() * 0.6)
		HideoutArt.beam(root, Vector3(-2.2 - 0.2 + ov, y, 1.8), Vector3(2.2 + 0.2 - ov, y, 1.8), lr, c)             # hinten
		HideoutArt.beam(root, Vector3(-2.2, y, -1.8 - 0.2 + ov), Vector3(-2.2, y, 1.8 + 0.2 - ov), lr, c)           # links
		HideoutArt.beam(root, Vector3(2.2, y, -1.8 - 0.2 + ov), Vector3(2.2, y, 1.8 + 0.2 - ov), lr, c)             # rechts
		HideoutArt.beam(root, Vector3(-2.2 - 0.2 + ov, y, -1.8), Vector3(-0.62, y, -1.8), lr, c)                     # vorn links
		HideoutArt.beam(root, Vector3(0.62, y, -1.8), Vector3(2.2 + 0.2 - ov, y, -1.8), lr, c)                      # vorn rechts
		if y > 1.75:
			HideoutArt.beam(root, Vector3(-0.62, y, -1.8), Vector3(0.62, y, -1.8), lr, c)                           # über der Tür
	# Dach: zwei Schrägen mit Schindelreihen, Firstbalken, Moos
	var roof_col := Color(0.3, 0.2, 0.15)
	_solid(root, Vector3(3.0, 0.15, 4.6), roof_col, Vector3(-1.25, 2.85, 0), Vector3(0, 0, 28))
	_solid(root, Vector3(3.0, 0.15, 4.6), roof_col, Vector3(1.25, 2.85, 0), Vector3(0, 0, -28))
	for sgn in [-1.0, 1.0]:
		for r in range(7):
			var t := float(r) / 6.0
			var px: float = sgn * (0.2 + t * 2.35)
			var py := 3.45 - t * 1.25
			var sh := Util.add_box(root, Vector3(0.5, 0.05, 4.7), roof_col.lightened(0.05 + 0.04 * (r % 2)), Vector3(px, py + 0.1, 0))
			sh.rotation_degrees.z = -sgn * 28.0
	HideoutArt.beam(root, Vector3(0, 3.55, -2.4), Vector3(0, 3.55, 2.4), 0.12, dk)
	for i in range(4):
		var sgn2 := 1.0 if i % 2 == 0 else -1.0
		HideoutArt.moss(root, Vector3(sgn2 * rng.randf_range(0.6, 1.8), 3.0 - rng.randf() * 0.5, rng.randf_range(-1.8, 1.8)), rng.randf_range(0.4, 0.7))
	# Giebel vorne/hinten (Dreieck aus Brettern)
	for gz in [-2.25, 2.25]:
		for r in range(4):
			var w := 4.0 - float(r) * 0.9
			Util.add_box(root, Vector3(w, 0.2, 0.1), wood.darkened(0.1), Vector3(0, 2.4 + float(r) * 0.28, gz * 0.8))
	# Tür (angelehnt) und Rahmen
	HideoutArt.beam(root, Vector3(-0.66, 0, -1.9), Vector3(-0.66, 2.0, -1.9), 0.07, dk)
	HideoutArt.beam(root, Vector3(0.66, 0, -1.9), Vector3(0.66, 2.0, -1.9), 0.07, dk)
	HideoutArt.beam(root, Vector3(-0.7, 2.0, -1.9), Vector3(0.7, 2.0, -1.9), 0.07, dk)
	var door := Util.add_box(root, Vector3(0.6, 1.95, 0.07), Color(0.36, 0.25, 0.14), Vector3(0.95, 1.0, -2.15))
	door.rotation_degrees.y = 60.0
	# Vordach mit Pfosten, Stufe
	_solid(root, Vector3(2.8, 0.1, 1.5), roof_col, Vector3(0, 2.55, -2.65), Vector3(-12, 0, 0))
	HideoutArt.beam(root, Vector3(-1.2, 0, -3.3), Vector3(-1.2, 2.55, -3.3), 0.1, wood)
	HideoutArt.beam(root, Vector3(1.2, 0, -3.3), Vector3(1.2, 2.55, -3.3), 0.1, wood)
	Util.add_box(root, Vector3(2.2, 0.14, 0.8), dk, Vector3(0, 0.07, -2.3))
	HideoutArt.lantern(root, Vector3(-1.0, 2.2, -3.05), 0.7)
	# Fenster mit Läden an der Seite
	for sx in [-1.0, 1.0]:
		Util.add_box(root, Vector3(0.06, 0.55, 0.7), Color(0.05, 0.06, 0.08), Vector3(sx * 2.38, 1.4, 0.3))
		Util.add_box(root, Vector3(0.08, 0.6, 0.3), dk, Vector3(sx * 2.4, 1.4, -0.25))
		Util.add_box(root, Vector3(0.08, 0.6, 0.3), dk, Vector3(sx * 2.4, 1.4, 0.85))
	# Schornstein aus Steinen mit Rauch
	for i in range(5):
		HideoutArt.rock(root, Vector3(1.55, 3.0 + float(i) * 0.4, 1.25), Vector3(0.5, 0.3, 0.5), 200 + i, Color(0.5, 0.47, 0.44), false, 0.15)
	var smoke := CPUParticles3D.new()
	smoke.amount = 14
	smoke.lifetime = 4.0
	smoke.direction = Vector3(0.2, 1, 0)
	smoke.spread = 10.0
	smoke.initial_velocity_min = 0.5
	smoke.initial_velocity_max = 0.9
	smoke.gravity = Vector3(0.1, 0.1, 0)
	smoke.scale_amount_min = 0.5
	smoke.scale_amount_max = 1.2
	var smesh := SphereMesh.new()
	smesh.radius = 0.25
	smesh.height = 0.5
	smesh.radial_segments = 6
	smesh.rings = 3
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(0.75, 0.75, 0.78, 0.35)
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smesh.material = smat
	smoke.mesh = smesh
	smoke.position = Vector3(1.55, 5.1, 1.25)
	root.add_child(smoke)
	# Brennholzstapel, Hackklotz mit Axt, Fass
	for row in range(3):
		for k in range(4 - row):
			var lg := HideoutArt.beam(root, Vector3(2.6 + row * 0.0, 0.15 + row * 0.27, -0.2 + k * 0.3 + row * 0.15), Vector3(2.6, 0.15 + row * 0.27, -0.2 + k * 0.3 + row * 0.15), 0.12, Color(0.5, 0.33, 0.18).lerp(dk, rng.randf() * 0.5))
			lg.position = Vector3(2.9, 0.15 + row * 0.27, -1.2 + k * 0.3 + row * 0.15)
			lg.rotation_degrees = Vector3(0, 0, 90)
			(lg.mesh as CylinderMesh).height = 0.7
	var stump := Util.add_cylinder(root, 0.28, 0.45, Color(0.45, 0.3, 0.17), Vector3(-3.2, 0.22, -0.8))
	stump.material_override = HideoutArt.rock_mat(Color(0.5, 0.34, 0.2))
	Util.add_box(root, Vector3(0.05, 0.05, 0.55), Color(0.4, 0.27, 0.15), Vector3(-3.2, 0.62, -0.8)).rotation_degrees.x = -25.0
	Util.add_box(root, Vector3(0.05, 0.14, 0.12), Color(0.6, 0.6, 0.64), Vector3(-3.2, 0.72, -1.02)).rotation_degrees.x = -25.0
	var barrel := Util.add_cylinder(root, 0.32, 0.85, Color(0.4, 0.27, 0.14), Vector3(-2.8, 0.43, 1.9))
	for hy in [0.15, 0.7]:
		Util.add_cylinder(root, 0.335, 0.05, Color(0.2, 0.2, 0.22), Vector3(-2.8, hy, 1.9))
	barrel.scale = Vector3(1, 1, 1)
	# Innenleben
	_solid(root, Vector3(1.3, 0.12, 0.8), dk, Vector3(-1.2, 0.78, 1.2))        # Tischplatte
	for bx in [-1.7, -0.7]:
		Util.add_box(root, Vector3(0.1, 0.7, 0.1), dk, Vector3(bx, 0.4, 1.35))
	_solid(root, Vector3(0.9, 0.4, 2.0), Color(0.5, 0.35, 0.3), Vector3(1.5, 0.3, 0.6))     # Pritsche
	Util.add_box(root, Vector3(0.85, 0.08, 1.2), Color(0.6, 0.25, 0.2), Vector3(1.5, 0.52, 0.4))   # Decke
	Util.add_box(root, Vector3(0.7, 0.1, 0.4), Color(0.85, 0.82, 0.7), Vector3(1.5, 0.52, 1.35))   # Kissen
	Util.add_box(root, Vector3(1.4, 0.06, 0.3), wood, Vector3(-1.5, 1.7, 1.65))                     # Regal
	for i in range(3):
		Util.add_cylinder(root, 0.07, 0.18, Color(0.3 + 0.2 * i, 0.4, 0.5 - 0.1 * i), Vector3(-1.9 + i * 0.5, 1.82, 1.65))
	# Fell an der Wand
	var pelt := Util.add_sphere(root, 0.4, Color(0.55, 0.4, 0.26), Vector3(0, 1.6, 1.68))
	pelt.scale = Vector3(1.0, 1.4, 0.15)
	_stash(root, "Jägerkiste", Vector3(-1.6, 0, -0.6))
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.7, 0.35)
	l.light_energy = 0.9
	l.omni_range = 5.0
	l.position = Vector3(0, 1.8, 0)
	root.add_child(l)
	var lab := Label3D.new()
	lab.text = "Betreten\nauf eigene Gefahr"
	lab.font_size = 36
	lab.pixel_size = 0.005
	lab.modulate = Color(0.95, 0.9, 0.75)
	lab.position = Vector3(1.55, 1.4, -2.0)
	lab.rotation_degrees.y = 180.0
	root.add_child(lab)
	root.force_update_transform()
	main.cave_boxes.append(root.global_transform * AABB(Vector3(-2.1, 0, -1.7), Vector3(4.2, 2.3, 3.4)))


func _hollow_tree(root: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 91
	var bark := Color(0.38, 0.27, 0.17)
	var bmat := HideoutArt.rock_mat(bark)
	var comb := CSGCombiner3D.new()
	comb.use_collision = true
	root.add_child(comb)
	var lower := CSGCylinder3D.new()
	lower.radius = 1.4
	lower.height = 5.0
	lower.sides = 12
	lower.smooth_faces = false
	lower.position = Vector3(0, 2.5, 0)
	lower.material = bmat
	comb.add_child(lower)
	var flare := CSGCylinder3D.new()
	flare.radius = 1.85
	flare.height = 1.0
	flare.sides = 12
	flare.smooth_faces = false
	flare.position = Vector3(0, 0.5, 0)
	flare.material = bmat
	comb.add_child(flare)
	var upper := CSGCylinder3D.new()
	upper.radius = 1.0
	upper.height = 3.0
	upper.sides = 10
	upper.smooth_faces = false
	upper.position = Vector3(0, 6.3, 0)
	upper.material = bmat
	comb.add_child(upper)
	# Höhlung (Torbogen vorne zum See, Hohlraum innen)
	var cut := CSGCombiner3D.new()
	cut.operation = CSGShape3D.OPERATION_SUBTRACTION
	comb.add_child(cut)
	var hb := CSGBox3D.new()
	hb.size = Vector3(1.0, 0.8, 2.0)
	hb.position = Vector3(0, 0.4, -1.2)
	hb.material = bmat
	cut.add_child(hb)
	var ha := CSGCylinder3D.new()
	ha.radius = 0.5
	ha.height = 2.0
	ha.sides = 10
	ha.rotation_degrees.x = 90.0
	ha.position = Vector3(0, 0.8, -1.2)
	ha.material = bmat
	cut.add_child(ha)
	var hi := CSGCylinder3D.new()
	hi.radius = 0.8
	hi.height = 2.2
	hi.sides = 10
	hi.position = Vector3(0, 1.1, -0.1)
	hi.material = bmat
	cut.add_child(hi)
	# Wurzeln
	for i in range(6):
		var a := TAU * float(i) / 6.0 + 0.3
		var a_pos := Vector3(cos(a) * 1.2, 0.7, sin(a) * 1.2)
		var b_pos := Vector3(cos(a) * 2.9, 0.05, sin(a) * 2.9)
		if sin(a) < -0.6 and absf(cos(a)) < 0.5:
			continue
		HideoutArt.beam(root, a_pos, b_pos, 0.28, bark.darkened(0.1), false)
	HideoutArt.moss(root, Vector3(1.0, 0.9, 0.9), 0.8)
	HideoutArt.moss(root, Vector3(-1.1, 1.0, 0.6), 0.6)
	# Baumpilze am Stamm (orange Konsolen)
	for i in range(4):
		var fa := rng.randf_range(0.6, 2.4) + PI
		var fy := rng.randf_range(1.5, 4.0)
		var fungus := Util.add_cylinder(root, 0.3, 0.08, Color(0.9, 0.5, 0.18), Vector3(cos(fa) * 1.38, fy, sin(fa) * 1.38))
		fungus.rotation = Vector3(0.2, -fa, PI / 2.0 - 0.2)
	# Äste und Krone
	var cols := [Color(0.3, 0.55, 0.22), Color(0.42, 0.58, 0.2), Color(0.85, 0.55, 0.15)]
	for i in range(5):
		var ba := TAU * float(i) / 5.0 + 0.5
		var tip := Vector3(cos(ba) * 2.6, 7.0 + rng.randf() * 0.8, sin(ba) * 2.6)
		HideoutArt.beam(root, Vector3(0, 5.6, 0), tip, 0.2, bark)
		var lf := Util.add_sphere(root, rng.randf_range(1.5, 2.2), cols[i % 3], tip + Vector3(0, 0.6, 0))
		lf.scale = Vector3(1.0, 0.7, 1.0)
	var top := Util.add_sphere(root, 2.4, cols[1], Vector3(0, 8.0, 0))
	top.scale = Vector3(1.0, 0.75, 1.0)
	# Wespennest am Ast
	var nest := Util.add_sphere(root, 0.28, Color(0.75, 0.68, 0.5), Vector3(1.9, 6.1, 0.4))
	nest.scale = Vector3(1.0, 1.4, 1.0)
	HideoutArt.beam(root, Vector3(1.9, 6.7, 0.4), Vector3(1.9, 6.35, 0.4), 0.02, Color(0.4, 0.3, 0.2))
	# Pilze und warmes Licht im Hohlraum
	var gl := OmniLight3D.new()
	gl.light_color = Color(1.0, 0.7, 0.4)
	gl.light_energy = 0.5
	gl.omni_range = 3.0
	gl.position = Vector3(0, 1.0, -1.3)
	root.add_child(gl)
	_stash(root, "Baumhöhle", Vector3(0, 0, -1.5), false)


func _stone_camp(root: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var stone := Color(0.52, 0.49, 0.46)
	# Felswand hinten mit Nische
	HideoutArt.rock(root, Vector3(-2.3, 1.2, 5.0), Vector3(2.0, 1.7, 1.7), 11, stone, true)
	HideoutArt.rock(root, Vector3(2.4, 1.1, 5.1), Vector3(1.9, 1.6, 1.6), 12, stone.darkened(0.05), true)
	HideoutArt.rock(root, Vector3(0.0, 2.2, 6.0), Vector3(3.0, 2.3, 1.8), 13, stone.lightened(0.04), true)
	HideoutArt.rock(root, Vector3(-4.4, 0.8, 3.6), Vector3(1.4, 1.1, 1.3), 14, stone, true)
	HideoutArt.rock(root, Vector3(4.5, 0.7, 3.4), Vector3(1.3, 1.0, 1.2), 15, stone, true)
	HideoutArt.moss(root, Vector3(0, 4.2, 6.0), 1.6)
	HideoutArt.moss(root, Vector3(-2.3, 2.7, 5.0), 1.0)
	# Plane als Unterstand (olivgrün), Pfosten, Heringe und Spannseile
	var tarp_col := Color(0.28, 0.36, 0.2)
	var tarp := _solid(root, Vector3(3.6, 0.05, 2.8), tarp_col, Vector3(0, 2.2, 3.7), Vector3(-30, 0, 0))
	for sx in [-1.0, 1.0]:
		HideoutArt.beam(root, Vector3(sx * 1.7, 0, 2.55), Vector3(sx * 1.7, 1.6, 2.55), 0.06, Color(0.4, 0.28, 0.16))
		HideoutArt.beam(root, Vector3(sx * 1.7, 1.6, 2.55), Vector3(sx * 2.4, 0.05, 1.7), 0.01, Color(0.85, 0.75, 0.5))
		Util.add_cone(root, 0.03, 0.2, Color(0.5, 0.5, 0.52), Vector3(sx * 2.4, 0.08, 1.7))
	HideoutArt.lantern(root, Vector3(0.0, 1.55, 2.9), 0.8)
	# Schlafplatz, Kisten, Fass
	var bedroll := Util.add_cylinder(root, 0.22, 1.5, Color(0.55, 0.2, 0.18), Vector3(-1.2, 0.2, 3.9))
	bedroll.rotation_degrees.x = 90.0
	Util.add_box(root, Vector3(0.7, 0.45, 0.5), Color(0.45, 0.32, 0.18), Vector3(1.4, 0.23, 3.6))
	Util.add_box(root, Vector3(0.6, 0.35, 0.45), Color(0.4, 0.28, 0.15), Vector3(1.5, 0.63, 3.6)).rotation_degrees.y = 20.0
	Util.add_cylinder(root, 0.3, 0.8, Color(0.4, 0.27, 0.14), Vector3(2.0, 0.4, 2.7))
	_stash(root, "Schmugglerkiste", Vector3(0, 0, 3.4))
	# Alte Feuerstelle: Steinring, Asche, Sitzstämme
	for i in range(10):
		var a := TAU * float(i) / 10.0
		HideoutArt.rock(root, Vector3(cos(a) * 1.0, 0.1, sin(a) * 1.0 + 0.2), Vector3(0.28, 0.2, 0.28), 30 + i, stone, false, 0.2)
	Util.add_cylinder(root, 0.7, 0.04, Color(0.1, 0.09, 0.08), Vector3(0, 0.03, 0.2))
	for i in range(3):
		var sa := TAU * float(i) / 3.0 + 0.7
		var seat := HideoutArt.beam(root, Vector3(cos(sa) * 2.0 - 0.6, 0.18, sin(sa) * 2.0 + 0.2 - 0.6), Vector3(cos(sa) * 2.0 + 0.6, 0.18, sin(sa) * 2.0 + 0.2 + 0.6), 0.17, Color(0.42, 0.28, 0.16))
		seat.rotation.y += 0.0
	# Verstreute Felsen und Büsche
	for i in range(7):
		var r := rng.randf_range(0.5, 1.1)
		HideoutArt.rock(root, Vector3(rng.randf_range(-6, 6), r * 0.25, rng.randf_range(-3, 7)), Vector3(r, r * 0.7, r), 60 + i, stone.lightened(rng.randf() * 0.1), true)
	for i in range(4):
		HideoutArt.bush(root, Vector3(rng.randf_range(-6, 6), 0, rng.randf_range(-1, 7)), rng.randf_range(0.5, 0.9), rng)


func _scatter_forest_traps() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var kinds := ["bear", "bear", "pit", "rocks", "wasp"]
	var n := 0
	var tries := 0
	while n < 8 and tries < 400:
		tries += 1
		var p := Vector3(rng.randf_range(-70.0, 70.0), 0, rng.randf_range(-100.0, -45.0))
		if main.call("_tree_blocked", p):
			continue
		var t := Trap.new()
		add_child(t)
		t.build(kinds[n % kinds.size()])
		t.position = p
		t.rotation.y = rng.randf() * TAU
		n += 1
	# Beeren, Pilze und Äpfel auf der ganzen Karte (wachsen nach, siehe _process)
	for i in range(FOOD_TARGET):
		_spawn_food(true)


const FOOD_TARGET: int = 70
const FOOD_KINDS: Array = ["gut", "beere", "apfel", "gut", "gift", "beere", "apfel"]
var _food_t: float = 0.0
var _food_n: int = 0


func _spawn_food(initial: bool = false) -> bool:
	for k in range(40):
		var p := Vector3(randf_range(-110.0, 110.0), 0, randf_range(-110.0, 62.0))
		if main.call("_tree_blocked", p) or Hideouts.in_zone(p):
			continue
		var pl: Node3D = main.get("player") as Node3D
		if not initial and pl != null and pl.global_position.distance_to(p) < 14.0:
			continue      # nicht vor den Augen des Spielers aufpoppen
		var m := Mushroom.new()
		m.add_to_group("food")
		add_child(m)
		m.build(FOOD_KINDS[_food_n % FOOD_KINDS.size()])
		_food_n += 1
		m.position = p
		return true
	return false


func _process(delta: float) -> void:
	_food_t += delta
	if _food_t < 12.0:
		return
	_food_t = 0.0
	if get_tree().get_nodes_in_group("food").size() < FOOD_TARGET:
		_spawn_food()


func _signs() -> void:
	var defs := [
		{"pos": Vector3(-34, 0, -26), "text": "Fuchsbau →", "yaw": 180.0},
		{"pos": Vector3(-20, 0, -52), "text": "Alte Jagdhütte", "yaw": 150.0},
		{"pos": Vector3(0, 0, -60), "text": "Tropfsteinhöhle\nVORSICHT: Steinschlag", "yaw": 90.0},
		{"pos": Vector3(24, 0, -56), "text": "Hohler Baum", "yaw": 60.0},
		{"pos": Vector3(35, 0, -34), "text": "Steinlager\n(Fallen!)", "yaw": 0.0},
	]
	for d in defs:
		var sp := Signpost.new()
		add_child(sp)
		sp.position = d["pos"]
		sp.build([{"text": String(d["text"]).replace("\n", " "), "yaw": float(d["yaw"]), "y": 2.0}])


func _pebbles() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 8
	for cx in [-9.4, 2.6, 14.6]:
		for k in range(3):
			var it0 := Pickup.new()
			main.add_child(it0)
			it0.build("Stein")
			it0.global_position = Vector3(cx + rng.randf_range(-4.0, 4.0), 0.0, -16.6 - rng.randf_range(0.0, 0.8))
	var placed := 0
	var tries := 0
	while placed < 10 and tries < 300:
		tries += 1
		var a := rng.randf() * TAU
		var r := 1.0
		var v := LakeShape.CENTER + Vector2(cos(a) * 25.0 * 1.0, sin(a) * 16.5) * 1.12
		var wp := Vector3(v.x, 0.12, v.y + 15.0)
		if LakeShape.contains(v):
			continue
		var it := Pickup.new()
		main.add_child(it)
		it.build("Stein")
		it.global_position = Vector3(wp.x, 0.0, wp.z)
		placed += 1
