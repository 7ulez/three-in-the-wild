class_name Hideouts
extends Node3D
## Höhlen und Verstecke rund um den See, mit Beute - und Fallen.
## Die Plätze (x, z, Radius) sind für Bäume gesperrt.

const SPOTS: Array = [
	{"id": "fuchsbau", "x": -44.0, "z": -36.0, "r": 9.0},
	{"id": "huette", "x": -30.0, "z": -64.0, "r": 10.0},
	{"id": "tropf", "x": 0.0, "z": -76.0, "r": 13.0},
	{"id": "baum", "x": 27.0, "z": -66.0, "r": 7.0},
	{"id": "lager", "x": 43.0, "z": -38.0, "r": 8.0},
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
	_signs()
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


## Felshöhle: Block minus Tunnel und Kammer (Eingang auf der Seeseite = lokal -Z)
func _cave(root: Node3D, size: Vector3, tunnel: Vector3, chamber: Vector3, label: String, crystals: bool = false) -> void:
	var rock := Util.mat(Color(0.4, 0.38, 0.36), 0.95)
	var dark := Util.mat(Color(0.3, 0.27, 0.25), 0.95)
	var comb := CSGCombiner3D.new()
	comb.use_collision = true
	root.add_child(comb)
	var block := CSGBox3D.new()
	block.size = size
	block.position = Vector3(0, size.y / 2.0, 0)
	block.material = rock
	comb.add_child(block)
	# Abgerundete Kuppe
	var dome := CSGSphere3D.new()
	dome.radius = size.x * 0.55
	dome.radial_segments = 10
	dome.rings = 6
	dome.position = Vector3(0, size.y * 0.8, 0)
	dome.scale = Vector3(1.0, 0.55, size.z / size.x)
	dome.material = rock
	comb.add_child(dome)
	var front := -size.z / 2.0
	var tun := CSGBox3D.new()
	tun.operation = CSGShape3D.OPERATION_SUBTRACTION
	tun.size = tunnel
	tun.position = Vector3(0, tunnel.y / 2.0, front + tunnel.z / 2.0 - 1.2)
	tun.material = dark
	comb.add_child(tun)
	var cham := CSGBox3D.new()
	cham.operation = CSGShape3D.OPERATION_SUBTRACTION
	cham.size = chamber
	cham.position = Vector3(0, chamber.y / 2.0, size.z / 2.0 - 1.2 - chamber.z / 2.0)
	cham.material = dark
	comb.add_child(cham)
	# Innenräume merken (Welt-AABB) - dort wird es dunkel
	root.force_update_transform()
	for cut in [tun, cham]:
		var c := cut as CSGBox3D
		var local_aabb := AABB(c.position - c.size / 2.0, c.size)
		var world_aabb: AABB = root.global_transform * local_aabb
		main.cave_boxes.append(world_aabb)
	# Bodenplatte der Kammer + Beute
	var cp: Vector3 = cham.position
	Util.add_box(root, Vector3(chamber.x, 0.06, chamber.z), Color(0.22, 0.2, 0.19), Vector3(cp.x, 0.03, cp.z))
	_stash(root, label + "-Kiste", Vector3(chamber.x / 2.0 - 1.0, 0, cp.z + chamber.z / 2.0 - 1.0))
	# Felsbrocken rund um den Hügel
	var brng := RandomNumberGenerator.new()
	brng.seed = int(size.x * 13.0)
	for i in range(9):
		var ba := TAU * i / 9.0 + brng.randf() * 0.4
		var bpos := Vector3(cos(ba) * (size.x / 2.0 + 0.2), 0.5, sin(ba) * (size.z / 2.0 + 0.2))
		if bpos.z < -size.z / 2.0 + 1.0 and absf(bpos.x) < tunnel.x:
			continue
		var br := brng.randf_range(0.7, 1.5)
		Util.add_sphere(root, br, Color(0.5, 0.48, 0.45).lightened(brng.randf() * 0.12), bpos).scale = Vector3(1, 0.7, 1)
	for i in range(4):
		var gr := Util.add_sphere(root, 1.4, Color(0.3, 0.5, 0.25), Vector3(brng.randf_range(-size.x * 0.3, size.x * 0.3), size.y + 0.1, brng.randf_range(-size.z * 0.2, size.z * 0.3)))
		gr.scale = Vector3(1.0, 0.45, 1.0)
	# Boulder am Eingang
	for sgn in [-1.0, 1.0]:
		var b := Util.add_sphere(root, 0.9, Color(0.5, 0.48, 0.45), Vector3(sgn * (tunnel.x / 2.0 + 1.0), 0.4, front - 0.4))
		b.scale = Vector3(1.0, 0.7, 1.0)
	if crystals:
		var cols := [Color(0.3, 0.9, 1.0), Color(0.8, 0.4, 1.0), Color(0.4, 1.0, 0.6)]
		for i in range(6):
			var col: Color = cols[i % 3]
			var cm := StandardMaterial3D.new()
			cm.albedo_color = col
			cm.emission_enabled = true
			cm.emission = col
			cm.emission_energy_multiplier = 1.5
			var cr := MeshInstance3D.new()
			var pm := PrismMesh.new()
			pm.size = Vector3(0.3, 0.9, 0.25)
			cr.mesh = pm
			cr.material_override = cm
			cr.position = Vector3(cp.x + (i - 2.5) * 1.3, 0.45, cp.z + (chamber.z / 2.0 - 0.4) * (1.0 if i % 2 == 0 else -1.0))
			root.add_child(cr)
			if i % 2 == 0:
				var l := OmniLight3D.new()
				l.light_color = col
				l.light_energy = 0.7
				l.omni_range = 5.0
				l.position = cr.position + Vector3(0, 0.6, 0)
				root.add_child(l)
	else:
		# Fackel am Eingang der Kammer
		var l2 := OmniLight3D.new()
		l2.light_color = Color(1.0, 0.65, 0.3)
		l2.light_energy = 0.8
		l2.omni_range = 6.0
		l2.position = Vector3(0, 1.8, cp.z - 1.0)
		root.add_child(l2)


func _hut(root: Node3D) -> void:
	var wood := Color(0.42, 0.29, 0.17)
	var dk := Color(0.33, 0.22, 0.12)
	_solid(root, Vector3(4.6, 0.12, 3.8), dk, Vector3(0, 0.06, 0))           # Boden
	_solid(root, Vector3(4.4, 2.3, 0.18), wood, Vector3(0, 1.2, 1.8))         # Rückwand
	_solid(root, Vector3(0.18, 2.3, 3.6), wood, Vector3(-2.2, 1.2, 0))
	_solid(root, Vector3(0.18, 2.3, 3.6), wood, Vector3(2.2, 1.2, 0))
	_solid(root, Vector3(1.6, 2.3, 0.18), wood, Vector3(-1.4, 1.2, -1.8))     # Front mit Türlücke
	_solid(root, Vector3(1.6, 2.3, 0.18), wood, Vector3(1.4, 1.2, -1.8))
	_solid(root, Vector3(1.2, 0.5, 0.18), wood, Vector3(0, 2.15, -1.8))       # Sturz über der Tür
	var rl := _solid(root, Vector3(3.0, 0.15, 4.4), Color(0.28, 0.2, 0.16), Vector3(-1.25, 2.85, 0), Vector3(0, 0, 28))
	var rr := _solid(root, Vector3(3.0, 0.15, 4.4), Color(0.28, 0.2, 0.16), Vector3(1.25, 2.85, 0), Vector3(0, 0, -28))
	# Innenleben
	_solid(root, Vector3(1.3, 0.7, 0.7), dk, Vector3(-1.2, 0.45, 1.2))       # Tisch
	_solid(root, Vector3(0.9, 0.4, 2.0), Color(0.5, 0.35, 0.3), Vector3(1.5, 0.3, 0.6))   # Pritsche
	_stash(root, "Jägerkiste", Vector3(-1.6, 0, -0.6))
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.7, 0.35)
	l.light_energy = 0.9
	l.omni_range = 5.0
	l.position = Vector3(0, 1.8, 0)
	root.add_child(l)
	# Schild an der Tür
	var lab := Label3D.new()
	lab.text = "Betreten\nauf eigene Gefahr"
	lab.font_size = 36
	lab.pixel_size = 0.005
	lab.modulate = Color(0.95, 0.9, 0.75)
	lab.position = Vector3(1.6, 1.4, -1.95)
	lab.rotation_degrees.y = 180.0
	root.add_child(lab)
	# Hütte als Innenraum (dunkler)
	root.force_update_transform()
	main.cave_boxes.append(root.global_transform * AABB(Vector3(-2.1, 0, -1.7), Vector3(4.2, 2.3, 3.4)))


func _hollow_tree(root: Node3D) -> void:
	var b := StaticBody3D.new()
	root.add_child(b)
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 1.3
	shape.height = 7.0
	cs.shape = shape
	cs.position.y = 3.5
	b.add_child(cs)
	Util.add_cylinder(b, 1.3, 7.0, Color(0.36, 0.25, 0.15), Vector3(0, 3.5, 0))
	Util.add_cylinder(b, 1.0, 1.0, Color(0.34, 0.23, 0.13), Vector3(0, 7.3, 0))
	# Dunkle Höhlung vorne (zum See)
	Util.add_box(b, Vector3(0.9, 1.3, 0.3), Color(0.03, 0.02, 0.02), Vector3(0, 1.0, -1.18))
	for i in range(3):
		Util.add_box(b, Vector3(0.12, 2.2, 0.12), Color(0.33, 0.22, 0.12), Vector3(-0.6 + i * 0.6, 8.0, 0.2)).rotation_degrees = Vector3(0, 0, -20 + i * 20)
	# Wurzeln
	for i in range(5):
		var a := TAU * i / 5.0
		Util.add_box(b, Vector3(0.35, 0.3, 1.1), Color(0.34, 0.22, 0.12), Vector3(cos(a) * 1.4, 0.12, sin(a) * 1.4)).rotation.y = -a
	_stash(root, "Baumhöhle", Vector3(0, 0, -1.85), false)
	# Wespennest hängt am Ast
	root.get_child(root.get_child_count() - 1)


func _stone_camp(root: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	# Steinring (alte Feuerstelle)
	for i in range(9):
		var a := TAU * i / 9.0
		var st := Util.add_sphere(root, 0.28, Color(0.5, 0.48, 0.46), Vector3(cos(a) * 1.0, 0.15, sin(a) * 1.0 + 1.5))
		st.scale = Vector3(1, 0.65, 1)
	Util.add_cylinder(root, 0.7, 0.05, Color(0.12, 0.1, 0.09), Vector3(0, 0.03, 1.5))
	# Großer Fels mit angelehntem Unterstand
	var rock := _solid(root, Vector3(3.4, 2.6, 2.2), Color(0.5, 0.47, 0.44), Vector3(0, 1.3, 4.6))
	_solid(root, Vector3(0.12, 2.3, 1.7), Color(0.4, 0.28, 0.16), Vector3(-1.0, 0.95, 2.6), Vector3(-38, 0, 0))
	_solid(root, Vector3(0.12, 2.3, 1.7), Color(0.4, 0.28, 0.16), Vector3(1.0, 0.95, 2.6), Vector3(-38, 0, 0))
	_stash(root, "Schmugglerkiste", Vector3(0, 0, 3.0))
	for i in range(5):
		var r := rng.randf_range(0.5, 1.1)
		var b := Util.add_sphere(root, r, Color(0.5, 0.48, 0.45).lightened(rng.randf() * 0.12), Vector3(rng.randf_range(-5, 5), r * 0.3, rng.randf_range(-3, 7)))
		b.scale = Vector3(1, 0.7, 1)


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
	# Beeren und Pilze im ganzen Wald
	n = 0
	tries = 0
	while n < 24 and tries < 600:
		tries += 1
		var p2 := Vector3(rng.randf_range(-70.0, 70.0), 0, rng.randf_range(-100.0, -22.0))
		if main.call("_tree_blocked", p2) and not Hideouts.in_zone(p2):
			continue
		if Hideouts.in_zone(p2):
			continue
		var m := Mushroom.new()
		add_child(m)
		m.build(["gut", "gift", "beere"][n % 3])
		m.position = p2
		n += 1


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
