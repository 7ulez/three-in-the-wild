class_name Massif
extends Node3D
## Das Felsmassiv im Osten: eine SEHR schwere Kletterroute (Plattformen, Lücken, schmale Balken,
## Hindernisse) rund um den Fels hinauf zur Aussichtsplattform (15 m hoch, Absturzgefahr!), dazu eine Höhle mit zwei Eingängen, Kristallen, einem Loch
## im Boden und einer Schatzkiste.

const BASE: Vector3 = Vector3(105, 7.5, -72)    # Mitte des Felsblocks
const SIZE: Vector3 = Vector3(50, 15, 50)
const TOP_Y: float = 15.0

var main: Node
var summit_reached: bool = false
var pit_area: Area3D
var cave_entry: Vector3 = Vector3(75, 0.6, -70)


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


func build(p_main: Node) -> void:
	main = p_main
	var rock := Util.mat(Color(0.46, 0.41, 0.37), 0.95)
	var dark := Util.mat(Color(0.3, 0.27, 0.25), 0.95)

	# Felsblock mit Höhlen (CSG: Block minus Tunnel)
	var comb := CSGCombiner3D.new()
	comb.use_collision = true
	add_child(comb)
	var block := CSGBox3D.new()
	block.size = SIZE
	block.position = BASE
	block.material = rock
	comb.add_child(block)
	var cuts: Array = [
		[Vector3(87.4, 1.75, -70), Vector3(15.2, 3.5, 3.8)],     # Westtunnel
		[Vector3(100, 2.5, -70), Vector3(14, 5, 14)],              # Kammer
		[Vector3(100, 1.75, -87), Vector3(3.8, 3.5, 20.4)],        # Nordtunnel
		[Vector3(110.5, 1.5, -70), Vector3(7, 3, 4)],              # Schatznische
	]
	for c in cuts:
		var cut := CSGBox3D.new()
		cut.operation = CSGShape3D.OPERATION_SUBTRACTION
		cut.position = c[0]
		cut.size = c[1]
		cut.material = dark
		comb.add_child(cut)
		var half: Vector3 = (c[1] as Vector3) / 2.0
		var box := AABB((c[0] as Vector3) - half, c[1])
		main.cave_boxes.append(box)
		# Bodenplatte (dunkler Fels)
		Util.add_box(self, Vector3(box.size.x, 0.06, box.size.z), Color(0.22, 0.2, 0.19), Vector3(box.get_center().x, 0.03, box.get_center().z))

	# Grasdecke oben (nur Optik)
	Util.add_box(self, Vector3(49.6, 0.04, 49.6), Color(0.33, 0.5, 0.24), Vector3(BASE.x, TOP_Y + 0.02, BASE.z))

	_build_climb()

	# Boulder am Fuß und Aussichtsplattform-Dekoration
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for i in range(26):
		var side := rng.randi() % 4
		var p := Vector3.ZERO
		match side:
			0: p = Vector3(rng.randf_range(78.0, 132.0), 0, rng.randf_range(-49.0, -46.0))
			1: p = Vector3(rng.randf_range(78.0, 132.0), 0, rng.randf_range(-99.0, -95.0))
			2: p = Vector3(rng.randf_range(76.0, 79.0), 0, rng.randf_range(-97.0, -50.0))
			3: p = Vector3(rng.randf_range(130.0, 134.0), 0, rng.randf_range(-97.0, -50.0))
		if absf(p.x - 100.0) < 4.0 and p.z < -94.0:
			continue
		if p.z > -50.0 and p.x > 60.0 and p.x < 125.0 and p.z < -42.0:
			continue
		var r := rng.randf_range(0.6, 1.6)
		var b := Util.add_sphere(self, r, Color(0.5, 0.48, 0.45).lightened(rng.randf() * 0.15), p + Vector3(0, r * 0.4, 0))
		b.scale = Vector3(1.0, 0.7, rng.randf_range(0.8, 1.3))
	for i in range(9):
		var tx := rng.randf_range(84.0, 126.0)
		var tz := rng.randf_range(-93.0, -52.0)
		var h := rng.randf_range(2.5, 4.5)
		Util.add_cylinder(self, 0.18, h * 0.4, Color(0.35, 0.22, 0.12), Vector3(tx, TOP_Y + h * 0.2, tz))
		Util.add_cone(self, 1.0, h, Color(0.12, 0.42, 0.25), Vector3(tx, TOP_Y + h * 0.5 + 0.3, tz))
	# Aussichtsbank und Fahne
	Util.add_box(self, Vector3(1.6, 0.1, 0.5), Color(0.5, 0.34, 0.2), Vector3(105, TOP_Y + 0.45, -50.5))
	Util.add_box(self, Vector3(0.1, 0.45, 0.4), Color(0.4, 0.27, 0.15), Vector3(104.3, TOP_Y + 0.22, -50.5))
	Util.add_box(self, Vector3(0.1, 0.45, 0.4), Color(0.4, 0.27, 0.15), Vector3(105.7, TOP_Y + 0.22, -50.5))
	Util.add_cylinder(self, 0.05, 3.0, Color(0.8, 0.8, 0.8), Vector3(110, TOP_Y + 1.5, -52))
	Util.add_box(self, Vector3(1.0, 0.6, 0.03), Color(0.9, 0.2, 0.15), Vector3(110.5, TOP_Y + 2.6, -52))

	# Kristalle (leuchten) in Höhle
	var crystal_cols: Array = [Color(0.3, 0.9, 1.0), Color(0.8, 0.4, 1.0), Color(0.4, 1.0, 0.6)]
	var spots: Array = [Vector3(83, 0, -71.5), Vector3(90, 0, -68.3), Vector3(94.5, 0, -74), Vector3(106, 0, -76),
		Vector3(96, 0, -64), Vector3(100.8, 0, -80), Vector3(99, 0, -90), Vector3(101.5, 0, -95), Vector3(112, 0, -71.5)]
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
	var pit := Util.add_box(self, Vector3(4.0, 0.04, 4.0), Color(0.0, 0.0, 0.0), Vector3(101.5, 0.06, -70.0))
	pit.name = "Pit"
	for i in range(14):
		var a := TAU * float(i) / 14.0
		Util.add_sphere(self, 0.35, Color(0.4, 0.38, 0.36), Vector3(101.5 + cos(a) * 2.3, 0.15, -70.0 + sin(a) * 2.3))
	pit_area = Area3D.new()
	var pcs := CollisionShape3D.new()
	var pbs := BoxShape3D.new()
	pbs.size = Vector3(3.6, 2.0, 3.6)
	pcs.shape = pbs
	pit_area.add_child(pcs)
	pit_area.position = Vector3(101.5, 1.0, -70.0)
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
	chest.position = Vector3(112.2, 0.0, -70.0)
	chest.rotation.y = PI / 2.0
	add_child(chest)

	# Wegweiser
	var sp1 := Signpost.new()
	add_child(sp1)
	sp1.position = Vector3(58, 0, -41)
	sp1.build([
		{"text": "Kletterroute: SEHR SCHWER!", "yaw": 0.0, "y": 2.2},
		{"text": "Absturz = Lebensgefahr", "yaw": 0.0, "y": 1.7},
		{"text": "Parkplatz", "yaw": 180.0, "y": 1.2},
	])
	var sp2 := Signpost.new()
	add_child(sp2)
	sp2.position = Vector3(76, 0, -66)
	sp2.build([
		{"text": "Höhle - Kopflampe (L)!", "yaw": 0.0, "y": 2.1},
		{"text": "Vorsicht Loch", "yaw": 0.0, "y": 1.6},
	])
	var sp3 := Signpost.new()
	add_child(sp3)
	sp3.position = Vector3(125, TOP_Y, -49)
	sp3.build([{"text": "Aussichtspunkt - nicht zu nah an die Kante!", "yaw": 180.0, "y": 2.0}])


var route: Array = []     # [{pos: Vector3 (Mitte der Oberseite), size: Vector3 (Länge x Breite in x/z), kind}]


func _slab(center_top: Vector3, size: Vector3, color: Color, yaw: float = 0.0) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.position = center_top - Vector3(0, 0.2, 0)
	b.rotation.y = yaw
	add_child(b)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(size.x, 0.4, size.z)
	cs.shape = bs
	b.add_child(cs)
	Util.add_box(b, Vector3(size.x, 0.4, size.z), color)
	return b


## Die Kletterroute: Südwand (nach Osten) -> Ostwand (nach Norden) -> Nordwand (nach Westen).
## Zwischen den Plattformen liegen Lücken; Sprünge sind nur mit Anlauf (Shift) zu schaffen.
func _build_climb() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var x_lo := BASE.x - SIZE.x / 2.0     # 80
	var x_hi := BASE.x + SIZE.x / 2.0     # 130
	var z_hi := BASE.z + SIZE.z / 2.0     # -47 (Südwand)
	var z_lo := BASE.z - SIZE.z / 2.0     # -97 (Nordwand)
	var cgap := 2.4                        # Lücke vor/hinter den Eckplattformen
	# Wandabschnitte: Start (Laufachse), Richtung, Wandnormale, Länge bis zur nächsten Ecke
	var faces: Array = [
		{"from": Vector3(x_lo + 2.0, 0, z_hi), "dir": Vector3(1, 0, 0), "out": Vector3(0, 0, 1), "len": (x_hi - cgap) - (x_lo + 2.0)},
		{"from": Vector3(x_hi, 0, z_hi - cgap), "dir": Vector3(0, 0, -1), "out": Vector3(1, 0, 0), "len": (z_hi - cgap) - (z_lo + cgap)},
		{"from": Vector3(x_hi - cgap, 0, z_lo), "dir": Vector3(-1, 0, 0), "out": Vector3(0, 0, -1), "len": (x_hi - cgap) - (x_lo + 4.0)},
	]
	var nodes: Array = []
	var fi := 0
	for f in faces:
		var total: float = f["len"]
		var out: Vector3 = f["out"]
		var dir: Vector3 = f["dir"]
		var yaw := atan2(-dir.z, dir.x)
		# Platten zufällig wählen, bis die mittlere Lücke 2,2 - 3,3 m beträgt
		var kinds: Array = []
		var lens: Array = []
		var gap := 0.0
		for attempt in range(60):
			kinds.clear()
			lens.clear()
			var sum := 0.0
			var cnt := 0
			while true:
				var r := rng.randf()
				var kind := "slab"
				var pl := 2.2
				if r < 0.25:
					kind = "stone"
					pl = 1.0
				elif r < 0.45:
					kind = "beam"
					pl = 3.0
				elif r < 0.55:
					kind = "rest"
					pl = 3.6
				if sum + pl + 2.2 * cnt > total:
					break
				kinds.append(kind)
				lens.append(pl)
				sum += pl
				cnt += 1
			if cnt >= 2:
				gap = (total - sum) / float(cnt - 1)
				if gap >= 2.2 and gap <= 3.3:
					break
		var u := 0.0
		for k in range(kinds.size()):
			var plen: float = lens[k]
			var kind2: String = kinds[k]
			var pwid := 1.5
			if kind2 == "stone":
				pwid = 1.0
			elif kind2 == "beam":
				pwid = 0.6
			elif kind2 == "rest":
				pwid = 2.4
			var along: Vector3 = (f["from"] as Vector3) + dir * (u + plen / 2.0)
			var offset := pwid / 2.0 - 0.1
			if kind2 == "beam" or kind2 == "stone":
				offset = pwid / 2.0 + 0.5
			nodes.append({"pos": along + out * offset, "size": Vector3(plen, 0.4, pwid), "yaw": yaw, "kind": kind2, "out": out, "dir": dir})
			u += plen + gap
		fi += 1
		if fi < faces.size():
			# Eckplattform außen an der Ecke
			var corner: Vector3 = Vector3(x_hi, 0, z_hi) if fi == 1 else Vector3(x_hi, 0, z_lo)
			var diag: Vector3 = Vector3(1.5, 0, 1.5) if fi == 1 else Vector3(1.5, 0, -1.5)
			nodes.append({"pos": corner + diag, "size": Vector3(3.0, 0.4, 3.0), "yaw": 0.0, "kind": "corner", "out": out, "dir": dir})
	# Höhen: gleichmäßig von 0,5 bis 14,6
	var n := nodes.size()
	var top0 := 0.5
	var top1 := TOP_Y - 0.4
	route.clear()
	for i in range(n):
		var nd: Dictionary = nodes[i]
		var y := lerpf(top0, top1, float(i) / float(maxi(n - 1, 1)))
		var p: Vector3 = nd["pos"]
		p.y = y
		nd["pos"] = p
		route.append(nd)
		var col := Color(0.55, 0.42, 0.28)
		match String(nd["kind"]):
			"stone":
				col = Color(0.5, 0.48, 0.45)
			"beam":
				col = Color(0.4, 0.27, 0.15)
			"rest":
				col = Color(0.62, 0.5, 0.32)
			"corner":
				col = Color(0.5, 0.4, 0.3)
		_slab(p, nd["size"], col, float(nd["yaw"]))
		# Hindernis: niedriger Balken quer über breiten Platten
		if String(nd["kind"]) == "slab" and i % 3 == 1:
			var lg := StaticBody3D.new()
			add_child(lg)
			lg.position = p + Vector3(0, 0.25, 0)
			lg.rotation.y = float(nd["yaw"])
			var lcs := CollisionShape3D.new()
			var lbs := BoxShape3D.new()
			lbs.size = Vector3(0.3, 0.5, (nd["size"] as Vector3).z)
			lcs.shape = lbs
			lg.add_child(lcs)
			Util.add_box(lg, lbs.size, Color(0.35, 0.22, 0.12))
		# Stützpfosten bis zum Boden (nur Optik) bei Ruheplätzen
		if String(nd["kind"]) == "rest":
			Util.add_cylinder(self, 0.08, p.y, Color(0.4, 0.28, 0.16), p + Vector3(0, -p.y / 2.0 - 0.4, 0))
	# Aufstieg: Starthilfe-Stein
	var first: Vector3 = route[0]["pos"]
	var rocks := Util.add_sphere(self, 0.7, Color(0.5, 0.48, 0.45), Vector3(first.x - 3.0, 0.0, first.z + 0.5))
	rocks.scale = Vector3(1, 0.5, 1)
	# Fahnen als Markierung alle 5 Plattformen
	for i in range(0, n, 5):
		var q: Vector3 = route[i]["pos"]
		Util.add_cylinder(self, 0.03, 1.2, Color(0.8, 0.8, 0.8), q + Vector3(0, 0.6, 0) + (route[i]["out"] as Vector3) * 0.0)
		Util.add_box(self, Vector3(0.4, 0.25, 0.02), Color(0.95, 0.25, 0.2), q + Vector3(0.2, 1.05, 0))


func _on_pit(body: Node) -> void:
	if body is Player:
		var p := body as Player
		p.needs.damage(35.0, "In ein Loch gefallen.")
		p.teleport_to(cave_entry)


func _process(_delta: float) -> void:
	if main == null or main.player == null or summit_reached:
		return
	var p: Vector3 = main.player.global_position
	if p.y > TOP_Y - 0.5 and p.x > 80.0 and p.x < 130.0 and p.z < -47.0 and p.z > -97.0:
		summit_reached = true
		Game.summit = true
		main.player.toast("Aussichtspunkt erreicht! Was für ein Blick über den See und die Wälder.", 6.0)
