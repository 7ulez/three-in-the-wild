extends Node3D
## Baut die Welt: Himmel, Boden, Wald, See mit drei Stegen, Parkplatz mit drei Autos, Spieler.

const PIER_X: Array = [-12.0, 0.0, 12.0]

## Alles rund um den See hängt an diesem Knoten und liegt 15 m weiter vorne.
var lake_root: Node3D
var sun: DirectionalLight3D
var moon: DirectionalLight3D
var sky_mat: ProceduralSkyMaterial
var env: Environment
var player: Player
var time_scale: float = 1.0
var tree_spots: Array = []
var nutria_timer: float = 40.0
var nutria_active: Nutria = null


func _ready() -> void:
	if Game.dedicated:
		# Dedizierter Server: keine Welt, keine Figur - nur Zeit und Netzwerk.
		var dnet := Net.new()
		add_child(dnet)
		dnet.start(self)
		return
	_setup_environment()
	lake_root = Node3D.new()
	lake_root.position = Vector3(0, 0, 15)
	add_child(lake_root)

	_build_ground()
	_build_boundary()
	_build_mountains()
	_build_trees()
	_build_hammock_trees()
	_build_lake()
	_build_pickups()
	var hide := Hideouts.new()
	hide.name = "Hideouts"
	add_child(hide)
	hide.build(self)
	var massif := Massif.new()
	add_child(massif)
	massif.build(self)
	_build_piers()
	_build_cars()
	_build_signs()

	var fauna := Fauna.new()
	fauna.name = "Fauna"
	add_child(fauna)
	fauna.start(self)
	var sfx := Sfx.new()
	sfx.name = "Sfx"
	add_child(sfx)
	Batcher.run(self)
	player = Player.new()
	player.character_name = Game.start_char
	add_child(player)
	player.global_position = Vector3(0, 1.0, 10)
	if Game.net_mode != "solo":
		var net := Net.new()
		add_child(net)
		net.start(self)


func _process(delta: float) -> void:
	if Game.dedicated:
		var dday := Game.hour >= 6.0 and Game.hour < 18.0
		Game.hour += delta * (1.2 if dday else 1.7) / 60.0
		if Game.hour >= 24.0:
			Game.hour -= 24.0
			Game.day_count += 1
		return
	_nutria_logic(delta)
	# Wie Minecraft: ca. 10 Minuten Tag, 7 Minuten Nacht (Zeit läuft nachts schneller)
	var is_day := Game.hour >= 6.0 and Game.hour < 18.0
	var rate: float = 1.2 if is_day else 1.7
	Game.hour += delta * rate / 60.0 * time_scale
	if Game.hour >= 24.0:
		Game.hour -= 24.0
		Game.day_count += 1
	_in_cave = player != null and is_in_cave(player.global_position)
	_update_sky()


## Sonne, Mond, Himmel und Nebel je nach Uhrzeit
func _update_sky() -> void:
	var a := (Game.hour - 6.0) / 24.0 * TAU
	var elev := sin(a)               # +1 Mittag, -1 Mitternacht
	var day := clampf(elev * 2.5 + 0.35, 0.0, 1.0)
	var night := 1.0 - day
	sun.rotation = Vector3(-asin(clampf(elev, -1.0, 1.0)) - 0.12, deg_to_rad(40.0) + cos(a) * 0.9, 0)
	sun.light_energy = lerpf(0.0, 1.05, day)
	sun.shadow_enabled = elev > 0.02 and not Game.low
	var warm := clampf(1.0 - absf(elev) * 2.5, 0.0, 1.0)   # Abend-/Morgenrot
	sun.light_color = Color(1.0, 0.95, 0.85).lerp(Color(1.0, 0.55, 0.3), warm)
	moon.light_energy = lerpf(0.0, 0.35, night)
	var top := Color(0.25, 0.55, 0.85).lerp(Color(0.02, 0.03, 0.1), night)
	var hor := Color(0.95, 0.8, 0.62).lerp(Color(1.0, 0.45, 0.25), warm * day).lerp(Color(0.06, 0.07, 0.16), night)
	sky_mat.sky_top_color = top
	sky_mat.sky_horizon_color = hor
	sky_mat.ground_horizon_color = hor
	sky_mat.ground_bottom_color = Color(0.3, 0.45, 0.3).lerp(Color(0.02, 0.03, 0.05), night)
	env.ambient_light_energy = lerpf(0.25, 0.85, day)
	if _in_cave:
		env.ambient_light_energy = 0.04
	env.fog_light_color = Color(0.95, 0.82, 0.65).lerp(Color(0.05, 0.06, 0.12), night)
	env.fog_density = 0.002 + 0.0015 * night


var _in_cave: bool = false
var cave_boxes: Array = []     # AABB-Liste (Weltkoordinaten) der Höhlen-Innenräume


func is_in_cave(p: Vector3) -> bool:
	for b in cave_boxes:
		if (b as AABB).has_point(p):
			return true
	return false


func _setup_environment() -> void:
	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.25, 0.55, 0.85)
	sky_mat.sky_horizon_color = Color(1.0, 0.8, 0.6)
	sky_mat.ground_horizon_color = Color(1.0, 0.8, 0.6)
	sky_mat.ground_bottom_color = Color(0.3, 0.45, 0.3)
	var sky := Sky.new()
	sky.sky_material = sky_mat

	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(1.0, 0.85, 0.65)
	env.fog_density = 0.002
	env.glow_enabled = not Game.low

	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 40, 0)
	sun.light_color = Color(1.0, 0.9, 0.75)
	sun.light_energy = 1.2
	sun.shadow_enabled = not Game.low
	add_child(sun)
	moon = DirectionalLight3D.new()
	moon.light_color = Color(0.55, 0.65, 1.0)
	moon.light_energy = 0.0
	moon.rotation_degrees = Vector3(-50, -120, 0)
	add_child(moon)
	env.ssao_enabled = true
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.92
	_update_sky()


func _build_ground() -> void:
	var ground := StaticBody3D.new()
	ground.add_to_group("ground")
	add_child(ground)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1400, 1, 1400)
	cs.shape = bs
	cs.position = Vector3(0, -0.5, 0)
	ground.add_child(cs)
	Util.add_box(ground, Vector3(1400, 1, 1400), Color(0.36, 0.55, 0.22), Vector3(0, -0.5, 0))
	# Kiesfläche als Parkplatz
	Util.add_box(self, Vector3(26, 0.04, 12), Color(0.72, 0.64, 0.5), Vector3(0, 0.02, 1))


func _add_wall(size: Vector3, pos: Vector3, parent: Node = null) -> void:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	body.add_child(cs)
	body.position = pos
	if parent == null:
		parent = self
	parent.add_child(body)


func _build_lake() -> void:
	LakeShape.build()
	# Sandufer, Wasser, tieferes Wasser in der Mitte
	var sand := Util.mat(Color(0.55, 0.47, 0.3))
	lake_root.add_child(LakeShape.poly_mesh(LakeShape.scaled(1.14), 0.015, sand))
	var wm := Util.mat(Color(0.08, 0.3, 0.42, 0.88), 0.2)
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wm.metallic = 0.1
	var water := LakeShape.poly_mesh(LakeShape.points, 0.03, wm)
	water.name = "Water"
	lake_root.add_child(water)
	var dm := Util.mat(Color(0.03, 0.15, 0.25, 0.55), 0.2)
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	lake_root.add_child(LakeShape.poly_mesh(LakeShape.scaled(0.62), 0.035, dm))

	var pts := LakeShape.points

	# Schilf, Steine und Seerosen
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var reed_col := Color(0.45, 0.55, 0.22)
	for i in range(0, pts.size(), 2):
		var p := pts[i]
		var near_spot := false
		for gx in PIER_X:
			if absf(p.x - gx - 1.0) < 3.0 and p.y > -46.0:
				near_spot = true
		if near_spot:
			continue
		var out := (p - LakeShape.CENTER).normalized()
		if rng.randf() < 0.65:
			for k in range(rng.randi_range(3, 6)):
				var q := p + out * rng.randf_range(-0.3, 0.9) + Vector2(rng.randf_range(-0.6, 0.6), rng.randf_range(-0.6, 0.6))
				var h := rng.randf_range(1.0, 1.9)
				var r := Util.add_cone(lake_root, 0.07, h, reed_col.darkened(rng.randf() * 0.2), Vector3(q.x, h / 2.0, q.y))
				r.rotation_degrees = Vector3(rng.randf_range(-8, 8), 0, rng.randf_range(-8, 8))
		if rng.randf() < 0.45:
			var q2 := p + out * rng.randf_range(0.8, 2.0)
			var rs := rng.randf_range(0.25, 0.7)
			var rock := Util.add_sphere(lake_root, rs, Color(0.5, 0.5, 0.52).lightened(rng.randf() * 0.15), Vector3(q2.x, rs * 0.3, q2.y))
			rock.scale = Vector3(1.0, 0.6, rng.randf_range(0.8, 1.3))
	for i in range(14):
		var lp := LakeShape.CENTER + Vector2(rng.randf_range(-20, 20), rng.randf_range(-12, 12))
		if LakeShape.contains(lp) and LakeShape.contains(LakeShape.CENTER + (lp - LakeShape.CENTER) * 1.1):
			var pad := Util.add_cylinder(lake_root, rng.randf_range(0.35, 0.6), 0.02, Color(0.2, 0.5, 0.2), Vector3(lp.x, 0.05, lp.y))
			pad.name = "Seerose"


## Keine Stege mehr: geangelt wird vom Ufer. Hier stehen nur die Pflöcke zur Lagerwahl.
func _build_piers() -> void:
	pass


func _loot(p_name: String, weight: float, size: Vector3, color: Color, owner: String = "") -> Dictionary:
	var d := {"name": p_name, "weight": weight, "size": size, "color": color}
	if owner != "":
		d["owner"] = owner
	return d


func _build_cars() -> void:
	var rod_cols := [Color(0.15, 0.55, 0.3), Color(0.8, 0.25, 0.2), Color(0.2, 0.4, 0.8), Color(0.85, 0.65, 0.15)]
	var defs := [
		{
			"name": "Schwarzer VW Lupo", "x": -6.5, "color": Color(0.06, 0.06, 0.07),
			"length": 3.5, "width": 1.65,
			"loot": [
				_loot("Zeltpaket", 12.0, Vector3(0.9, 0.35, 0.35), Color(0.95, 0.5, 0.15)),
				_loot("Bierkasten", 14.0, Vector3(0.5, 0.3, 0.35), Color(0.9, 0.75, 0.2)),
				_loot("Hammer", 2.0, Vector3(0.4, 0.12, 0.1), Color(0.45, 0.3, 0.15)),
				_loot("Feuerstahl", 0.3, Vector3(0.16, 0.05, 0.05), Color(0.7, 0.7, 0.74)),
				_loot("Hängematte", 3.0, Vector3(0.5, 0.3, 0.3), Color(0.8, 0.3, 0.3)),
				_loot("Angelrute", 3.0, Vector3(1.4, 0.1, 0.1), rod_cols[0], "Marian"),
				_loot("Rutenständer", 2.0, Vector3(0.4, 1.0, 0.3), Color(0.45, 0.3, 0.16)),
			],
		},
		{
			"name": "Schwarzer VW Passat", "x": 0.0, "color": Color(0.05, 0.05, 0.06),
			"length": 4.7, "width": 1.8,
			"loot": [
				_loot("Kühlbox", 10.0, Vector3(0.6, 0.4, 0.4), Color(0.2, 0.45, 0.85)),
				_loot("Gasgrill", 18.0, Vector3(0.7, 0.9, 0.5), Color(0.3, 0.3, 0.33)),
				_loot("Dutch Oven", 8.0, Vector3(0.4, 0.3, 0.4), Color(0.08, 0.08, 0.08)),
				_loot("Angelrute", 3.0, Vector3(1.4, 0.1, 0.1), rod_cols[1], "Steffen"),
				_loot("Angelrute", 3.0, Vector3(1.4, 0.1, 0.1), rod_cols[2], "Julian"),
				_loot("Rutenständer", 2.0, Vector3(0.4, 1.0, 0.3), Color(0.45, 0.3, 0.16)),
				_loot("Rutenständer", 2.0, Vector3(0.4, 1.0, 0.3), Color(0.45, 0.3, 0.16)),
			],
		},
		{
			"name": "Weißer VW Polo", "x": 6.5, "color": Color(0.93, 0.93, 0.92),
			"length": 4.0, "width": 1.7,
			"loot": [
				_loot("Campingstühle", 6.0, Vector3(0.8, 0.2, 0.2), Color(0.15, 0.4, 0.2)),
				_loot("Wasserkanister", 12.0, Vector3(0.3, 0.4, 0.2), Color(0.25, 0.6, 0.9)),
				_loot("Brennholz", 8.0, Vector3(0.6, 0.25, 0.3), Color(0.5, 0.33, 0.18)),
				_loot("Feuerschale", 5.0, Vector3(0.8, 0.3, 0.8), Color(0.5, 0.5, 0.52)),
				_loot("Rucksack mit Proviant", 7.0, Vector3(0.4, 0.5, 0.25), Color(0.75, 0.2, 0.15)),
				_loot("Angelrute", 3.0, Vector3(1.4, 0.1, 0.1), rod_cols[3], "Gast"),
				_loot("Rutenständer", 2.0, Vector3(0.4, 1.0, 0.3), Color(0.45, 0.3, 0.16)),
			],
		},
	]
	for d in defs:
		var car := Car.new()
		add_child(car)
		car.position = Vector3(d["x"], 0, 0)
		car.build(d["name"], d["color"], d["length"], d["width"], d["loot"])


func _add_mountain(pos: Vector3, r: float, h: float, color: Color, rng: RandomNumberGenerator) -> void:
	var root := Node3D.new()
	root.name = "Mountain"
	root.position = pos
	root.rotation.y = rng.randf_range(0.0, TAU)
	add_child(root, true)

	# Hauptgipfel und zwei Nebengipfel
	Util.add_cone(root, r, h, color, Vector3(0, h / 2.0, 0))
	Util.add_cone(root, r * 0.55, h * 0.62, color.darkened(0.08), Vector3(r * 0.55, h * 0.31, r * 0.1))
	Util.add_cone(root, r * 0.45, h * 0.5, color.lightened(0.05), Vector3(-r * 0.5, h * 0.25, -r * 0.15))
	# Waldgürtel am Fuß
	var skirt := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.bottom_radius = r * 1.03
	cm.top_radius = r * 0.65 * 1.03
	cm.height = h * 0.35
	cm.radial_segments = 7
	skirt.mesh = cm
	skirt.material_override = Util.mat(Color(0.15, 0.38, 0.22))
	skirt.position = Vector3(0, h * 0.175, 0)
	root.add_child(skirt)
	# Schneekappe
	Util.add_cone(root, r * 0.31, h * 0.3, Color(0.96, 0.97, 1.0), Vector3(0, h * 0.85, 0))


func _build_signs() -> void:
	# Am Start: zeigt nach Norden (-Z) zum See
	var start_sign := Signpost.new()
	add_child(start_sign)
	start_sign.position = Vector3(3.5, 0, 6)
	start_sign.build([
		{"text": "See · 30 m (angeln geht überall)", "yaw": 90.0, "y": 2.2},
		{"text": "Parkplatz (Autos)", "yaw": 270.0, "y": 1.7},
	])


func _build_boundary() -> void:
	# Unsichtbare Spielfeldgrenze: x von -150 bis 150, z von -130 bis 90
	_add_wall(Vector3(304, 30, 2), Vector3(0, 15, -131))
	_add_wall(Vector3(304, 30, 2), Vector3(0, 15, 91))
	_add_wall(Vector3(2, 30, 224), Vector3(-151, 15, -20))
	_add_wall(Vector3(2, 30, 224), Vector3(151, 15, -20))


func _tree_blocked(pos: Vector3) -> bool:
	# Parkplatz und Lagerflächen bleiben frei
	if absf(pos.x) < 27.0 and pos.z > -22.0 and pos.z < 30.0:
		return true
	if Hideouts.in_zone(pos):
		return true
	for hp in HAMMOCK_PAIRS:
		if Vector2(pos.x - hp.x, pos.z - hp.y).length() < 5.0:
			return true
	# Felsmassiv mit Klippenpfad
	if pos.x > 56.0 and pos.x < 138.0 and pos.z > -103.0 and pos.z < -38.0:
		return true
	# See samt Rand (Ellipse um die Seemitte)
	var ex := pos.x / 29.0
	var ez := (pos.z + 35.0) / 21.0
	if ex * ex + ez * ez < 1.0 and pos.z <= -22.0:
		return true
	return false


## Zu jedem der drei Lager gehören zwei kräftige Bäume (4,8 m auseinander) für die Hängematte.
const HAMMOCK_PAIRS: Array = [
	Vector2(-9.4, -4.7), Vector2(2.6, -4.7), Vector2(14.6, -4.7),
	Vector2(-22, -12), Vector2(22, -12), Vector2(-36, -24), Vector2(36, -24),
	Vector2(-34, -50), Vector2(34, -50), Vector2(-14, -66), Vector2(14, -66),
]


## Überall um den See stehen Baumpaare (4,8 m auseinander) für die Hängematte.
func _build_hammock_trees() -> void:
	var idx := 0
	for c in HAMMOCK_PAIRS:
		var t1 := HammockTree.new()
		var t2 := HammockTree.new()
		add_child(t1)
		add_child(t2)
		t1.position = Vector3(c.x - 2.4, 0, c.y)
		t2.position = Vector3(c.x + 2.4, 0, c.y)
		t1.build(idx)
		t2.build(idx)
		t1.partner = t2
		t2.partner = t1
		idx += 1


func _build_trees() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var spots: Array = []
	# Echter Wald: Zellen von 4,3 m mit Zufallsversatz
	var gx := -148.0
	while gx < 148.0:
		var gz := -127.0
		while gz < 88.0:
			var pos := Vector3(gx + rng.randf_range(0.0, 6.2), 0.0, gz + rng.randf_range(0.0, 6.2))
			if rng.randf() < 0.93 and not _tree_blocked(pos):
				spots.append(pos)
			gz += 6.2
		gx += 6.2
	# Extra dichter Waldgürtel rund um den See (Zellen von 3 m)
	gx = -56.0
	while gx < 56.0:
		var gz := -84.0
		while gz < -16.0:
			var pos := Vector3(gx + rng.randf_range(0.0, 4.6), 0.0, gz + rng.randf_range(0.0, 4.6))
			if rng.randf() < 0.8 and not _tree_blocked(pos):
				spots.append(pos)
			gz += 4.6
		gx += 4.6

	tree_spots = spots
	var forest := Node3D.new()
	forest.name = "Forest"
	add_child(forest)

	var parts := {}
	for key in ["bush", "s_trunk", "s_c1", "s_c2", "s_c3", "b_trunk", "b_c1", "b_c2", "l_trunk", "l_c1", "l_c2"]:
		parts[key] = {"x": [], "c": []}

	var shape := CylinderShape3D.new()
	shape.radius = 0.4
	shape.height = 4.0
	var autumn: Array = [Color(0.2, 0.5, 0.2), Color(0.9, 0.5, 0.15), Color(0.85, 0.7, 0.2), Color(0.25, 0.55, 0.25)]

	for spot in spots:
		var pos: Vector3 = spot
		var sc := rng.randf_range(0.8, 1.6)
		if rng.randf() < 0.12:
			sc = rng.randf_range(2.0, 2.8)   # Riesenbaum
		var yaw := rng.randf_range(0.0, TAU)
		var base := Transform3D(Basis.from_euler(Vector3(0, yaw, 0)).scaled(Vector3(sc, sc, sc)), pos)
		var kind := rng.randf()
		if kind < 0.55:
			# Fichte
			var g := rng.randf_range(0.0, 0.08)
			_part(parts, "s_trunk", base, 1.0, Color(0.35, 0.22, 0.12))
			_part(parts, "s_c1", base, 2.2, Color(0.12 + g, 0.42, 0.25))
			_part(parts, "s_c2", base, 3.2, Color(0.14 + g, 0.46, 0.27))
			_part(parts, "s_c3", base, 4.1, Color(0.16 + g, 0.5, 0.3))
		elif kind < 0.8:
			# Birke mit goldener Krone
			_part(parts, "b_trunk", base, 2.0, Color(0.92, 0.92, 0.88))
			_part(parts, "b_c1", base, 4.3, Color(0.75, 0.8, 0.25))
			_part(parts, "b_c2", base, 3.6, Color(0.85, 0.75, 0.2), Vector3(0.6, 0, 0.3))
		else:
			# Laubbaum in Herbstfarben
			var crown: Color = autumn[rng.randi() % autumn.size()]
			_part(parts, "l_trunk", base, 1.5, Color(0.4, 0.26, 0.14))
			_part(parts, "l_c1", base, 3.8, crown)
			_part(parts, "l_c2", base, 3.0, crown.darkened(0.12), Vector3(0.9, 0, 0.4))

		# Unterholz: Büsche (ohne Kollision)
		if rng.randf() < 0.55 and not Game.low:
			var bp := pos + Vector3(rng.randf_range(-2.0, 2.0), 0.0, rng.randf_range(-2.0, 2.0))
			if not _tree_blocked(bp):
				var bs := rng.randf_range(0.6, 1.2)
				var bb := Transform3D(Basis.IDENTITY.scaled(Vector3(bs, bs * 0.7, bs)), bp)
				_part(parts, "bush", bb, 0.4, Color(0.15 + rng.randf() * 0.1, 0.4 + rng.randf() * 0.15, 0.18))
		var body := StaticBody3D.new()
		body.position = pos
		var cs := CollisionShape3D.new()
		cs.shape = shape
		cs.position.y = 2.0
		body.add_child(cs)
		forest.add_child(body)

	_add_multimesh(_sphere_mesh(0.7), parts["bush"])
	_add_multimesh(_cyl_mesh(0.25, 2.0), parts["s_trunk"])
	_add_multimesh(_cone_mesh(1.5, 1.8), parts["s_c1"])
	_add_multimesh(_cone_mesh(1.1, 1.8), parts["s_c2"])
	_add_multimesh(_cone_mesh(0.7, 1.6), parts["s_c3"])
	_add_multimesh(_cyl_mesh(0.2, 4.0), parts["b_trunk"])
	_add_multimesh(_sphere_mesh(1.4), parts["b_c1"])
	_add_multimesh(_sphere_mesh(1.0), parts["b_c2"])
	_add_multimesh(_cyl_mesh(0.3, 3.0), parts["l_trunk"])
	_add_multimesh(_sphere_mesh(1.8), parts["l_c1"])
	_add_multimesh(_sphere_mesh(1.2), parts["l_c2"])


func _part(parts: Dictionary, key: String, base: Transform3D, y: float, color: Color, offset: Vector3 = Vector3.ZERO) -> void:
	var d: Dictionary = parts[key]
	d["x"].append(base * Transform3D(Basis.IDENTITY, Vector3(offset.x, y, offset.z)))
	d["c"].append(color)


func _add_multimesh(mesh: Mesh, d: Dictionary) -> void:
	var xforms: Array = d["x"]
	var colors: Array = d["c"]
	if xforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in range(xforms.size()):
		mm.set_instance_transform(i, xforms[i])
		mm.set_instance_color(i, colors[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.9
	mi.material_override = m
	add_child(mi)


func _cyl_mesh(r: float, h: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = r
	m.bottom_radius = r
	m.height = h
	m.radial_segments = 7
	return m


func _cone_mesh(r: float, h: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = 0.0
	m.bottom_radius = r
	m.height = h
	m.radial_segments = 7
	return m


func _sphere_mesh(r: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 8
	m.rings = 5
	return m


func _rect_distance(p: Vector3) -> float:
	# Abstand zum Spielfeld-Rechteck (x -151..151, z -131..91)
	var dx := maxf(absf(p.x) - 151.0, 0.0)
	var dz := maxf(maxf(p.z - 91.0, -131.0 - p.z), 0.0)
	return sqrt(dx * dx + dz * dz)


func _mountain_ring(count: int, hmin: float, hmax: float, extra: float, rock: Array, rng: RandomNumberGenerator) -> void:
	for i in range(count):
		var ang := TAU * float(i) / count + rng.randf_range(-0.1, 0.1)
		var h := rng.randf_range(hmin, hmax)
		var r := h * 0.65
		var dir := Vector3(cos(ang), 0, sin(ang))
		var origin := Vector3(0, 0, -20)
		var d := 100.0
		var pos := origin + dir * d
		while _rect_distance(pos) < r + 6.0 + extra:
			d += 10.0
			pos = origin + dir * d
		_add_mountain(pos, r, h, rock[rng.randi() % rock.size()], rng)


func _build_mountains() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var rock: Array = [Color(0.5, 0.47, 0.45), Color(0.42, 0.42, 0.46), Color(0.55, 0.5, 0.42), Color(0.46, 0.5, 0.55)]
	# Innerer Ring: nah und mittelhoch
	_mountain_ring(34, 60.0, 120.0, 0.0, rock, rng)
	# Äußerer Ring: weit weg, riesig, im Dunst
	_mountain_ring(22, 130.0, 220.0, 120.0, rock, rng)
	# Hohe Bergkette hinter dem See (Norden)
	for i in range(12):
		var h := rng.randf_range(110.0, 190.0)
		var r := h * 0.6
		var x := -190.0 + float(i) * 34.0 + rng.randf_range(-10.0, 10.0)
		var z := -131.0 - r - 6.0 - rng.randf_range(0.0, 40.0)
		_add_mountain(Vector3(x, 0, z), r, h, rock[rng.randi() % rock.size()], rng)


# ---------- Zunder und Äste ----------

func _build_pickups() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var made := 0
	var tries := 0
	while made < 190 and tries < 4000:
		tries += 1
		var p: Vector3
		if made % 3 != 0:
			# Am Waldrand der Lichtung, nahe der Angelplätze
			p = Vector3(rng.randf_range(-44.0, 44.0), 0.0, rng.randf_range(-30.0, 14.0))
		else:
			p = Vector3(rng.randf_range(-70.0, 70.0), 0.0, rng.randf_range(-70.0, 40.0))
		var lp := p - lake_root.global_position
		if LakeShape.contains(LakeShape.CENTER + (Vector2(lp.x, lp.z) - LakeShape.CENTER) * 0.82):
			continue
		if absf(p.x) < 14.0 and p.z > -3.0 and p.z < 9.0:
			continue   # Parkplatz
		var ok := true
		for t in tree_spots:
			if (t as Vector3).distance_squared_to(p) < 2.5:
				ok = false
				break
		if not ok:
			continue
		var pk := Pickup.new()
		add_child(pk)
		pk.build("Zunder" if made % 2 == 0 else "Ast")
		pk.position = p
		pk.rotation.y = rng.randf_range(0.0, TAU)
		made += 1


# ---------- Nutria ----------

func _nutria_logic(delta: float) -> void:
	if player == null or not Game.camp_claimed:
		return
	if nutria_active != null and not is_instance_valid(nutria_active):
		nutria_active = null
	if nutria_active != null:
		return
	var dusk := Game.hour >= 18.0 or Game.hour < 6.5
	if not dusk:
		return
	nutria_timer -= delta
	if nutria_timer <= 0.0:
		nutria_timer = randf_range(70.0, 140.0)
		var a := randf() * TAU
		var pos := Game.camp_center + Vector3(cos(a), 0, sin(a)) * 40.0
		spawn_nutria_at(pos)
		if player != null:
			player.toast("Im Gebüsch raschelt es...", 3.0)


func spawn_nutria_at(pos: Vector3) -> void:
	if nutria_active != null and is_instance_valid(nutria_active):
		return
	var n := Nutria.new()
	add_child(n)
	n.setup(self, Vector3(pos.x, 0.0, pos.z))
	nutria_active = n
