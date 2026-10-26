class_name HideoutDeco
extends RefCounted
## Ausschmückung der fünf Verstecke: Felsmantel und Bäumchen auf den Höhlen, Wurzelbogen,
## Farne, Blumen, Laub, Totholz, Bachlauf, Gartenzaun, Vogelhaus, Trockengestell ...
##
## Wichtig wegen der 1000-Objekte-Grenze im Browser: Alles landet in einem eigenen Behälter
## ("Deko", hat ein Skript) je Versteck und benutzt schlichte Materialien ohne Textur.
## Der Batcher fasst den Inhalt so je Versteck zu wenigen Meshes zusammen, und die
## Entfernungs-Ausblendung des Verstecks (main.gd) gilt weiter.

class Box:
	extends Node3D


static func box_for(root: Node3D) -> Node3D:
	var b := root.get_node_or_null("Deko") as Node3D
	if b == null:
		b = Box.new()
		b.name = "Deko"
		root.add_child(b)
	return b


static func _flat(mi: MeshInstance3D, shadow: bool) -> MeshInstance3D:
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Felsbrocken mit schlichtem Material (wird zusammengefasst, keine Kollision).
static func stone(p: Node3D, pos: Vector3, radii: Vector3, seed_v: int, col: Color, rough: float = 0.28) -> MeshInstance3D:
	var mi := HideoutArt.rock(p, pos, radii, seed_v, col, false, rough)
	mi.material_override = Util.mat(col, 0.95)
	return mi


## Schräg stehendes Blatt/Brett: Fuß bei pos, zeigt in Richtung yaw, um tilt (Grad) angehoben.
static func _blade(p: Node3D, pos: Vector3, size: Vector3, yaw: float, tilt_deg: float, col: Color) -> MeshInstance3D:
	var mi := Util.add_box(p, size, col)
	var t := deg_to_rad(tilt_deg)
	mi.basis = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -t)
	var d := Vector3(sin(yaw), 0.0, cos(yaw))
	mi.position = pos + d * cos(t) * size.z * 0.5 + Vector3.UP * sin(t) * size.z * 0.5
	return _flat(mi, false)


static func fern(p: Node3D, pos: Vector3, s: float, rng: RandomNumberGenerator) -> void:
	var base := Color(0.22, 0.45, 0.18).lerp(Color(0.34, 0.55, 0.2), rng.randf())
	var n := 6 + rng.randi() % 3
	for i in range(n):
		var yaw := TAU * float(i) / float(n) + rng.randf_range(-0.25, 0.25)
		_blade(p, pos, Vector3(0.16 * s, 0.02, 0.85 * s * rng.randf_range(0.8, 1.15)), yaw, rng.randf_range(28.0, 55.0), base.lerp(Color(0.45, 0.6, 0.25), rng.randf() * 0.3))


static func flowers(p: Node3D, pos: Vector3, n: int, rng: RandomNumberGenerator, palette: Array = []) -> void:
	var cols: Array = palette if not palette.is_empty() else [Color(0.95, 0.95, 0.9), Color(0.98, 0.85, 0.25), Color(0.65, 0.45, 0.9), Color(0.95, 0.45, 0.55)]
	var head_col: Color = cols[rng.randi() % cols.size()]
	for i in range(n):
		var o := Vector3(rng.randf_range(-0.45, 0.45), 0.0, rng.randf_range(-0.45, 0.45))
		var h := rng.randf_range(0.18, 0.38)
		_flat(Util.add_cylinder(p, 0.012, h, Color(0.3, 0.5, 0.2), pos + o + Vector3(0, h * 0.5, 0)), false)
		_flat(Util.add_sphere(p, rng.randf_range(0.04, 0.06), head_col, pos + o + Vector3(0, h, 0)), false)


## Verstreutes Laub in Herbstfarben.
static func leaves(p: Node3D, center: Vector3, radius: float, n: int, rng: RandomNumberGenerator) -> void:
	var cols := [Color(0.85, 0.5, 0.15), Color(0.75, 0.3, 0.12), Color(0.9, 0.72, 0.2), Color(0.5, 0.35, 0.18)]
	for i in range(n):
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * radius
		var lf := Util.add_box(p, Vector3(0.16, 0.012, 0.11), cols[i % cols.size()], center + Vector3(cos(a) * r, 0.02, sin(a) * r))
		lf.rotation = Vector3(rng.randf_range(-0.15, 0.15), rng.randf() * TAU, rng.randf_range(-0.15, 0.15))
		_flat(lf, false)


## Umgestürzter, bemooster Stamm mit Baumpilzen.
static func dead_log(p: Node3D, a: Vector3, b: Vector3, r: float, rng: RandomNumberGenerator) -> void:
	var bark := Color(0.36, 0.26, 0.17)
	HideoutArt.beam(p, a, b, r, bark)
	for e in [a, b]:
		var cap := Util.add_cylinder(p, r * 0.9, 0.02, Color(0.72, 0.58, 0.38), e)
		cap.basis = Basis(Quaternion(Vector3.UP, (b - a).normalized()))
		_flat(cap, false)
	var m := Util.add_sphere(p, r * 1.05, Color(0.28, 0.48, 0.2), a.lerp(b, rng.randf_range(0.3, 0.6)) + Vector3(0, r * 0.55, 0))
	m.scale = Vector3(1.6, 0.35, 1.0)
	for i in range(3):
		var f := Util.add_cylinder(p, r * 0.5, 0.05, Color(0.92, 0.85, 0.7), a.lerp(b, 0.2 + 0.25 * i) + Vector3(0, r * 0.2, r * 0.95))
		_flat(f, false)


## Kleiner Baum (Stamm + Laubkugeln).
static func little_tree(p: Node3D, pos: Vector3, h: float, rng: RandomNumberGenerator) -> void:
	HideoutArt.beam(p, pos, pos + Vector3(rng.randf_range(-0.2, 0.2), h, rng.randf_range(-0.2, 0.2)), 0.12 * h / 2.5, Color(0.35, 0.25, 0.16))
	var cols := [Color(0.3, 0.52, 0.2), Color(0.4, 0.58, 0.2), Color(0.82, 0.55, 0.18)]
	for i in range(3):
		var s := Util.add_sphere(p, h * rng.randf_range(0.26, 0.36), cols[rng.randi() % cols.size()], pos + Vector3(rng.randf_range(-0.4, 0.4), h * rng.randf_range(0.85, 1.1), rng.randf_range(-0.4, 0.4)))
		s.scale = Vector3(1.0, 0.8, 1.0)


## Felsmantel über dem Höhlenhügel (Ellipsoid wie in Hideouts._cave), Eingang bleibt frei.
static func rock_shell(p: Node3D, size: Vector3, tunnel: Vector3, tint: Color, rng: RandomNumberGenerator, n: int) -> void:
	var rad := Vector3(size.x * 0.56, size.y * 0.9, size.z * 0.58)
	var cy := size.y * 0.1
	var front := -size.z / 2.0
	var placed := 0
	var tries := 0
	while placed < n and tries < n * 6:
		tries += 1
		var th := rng.randf() * TAU
		var el := rng.randf_range(0.12, 1.25)          # Höhenwinkel (rad)
		var dir := Vector3(cos(th) * cos(el), sin(el), sin(th) * cos(el))
		var sp := Vector3(dir.x * rad.x, cy + dir.y * rad.y, dir.z * rad.z)
		if sp.z < front + tunnel.z * 0.55 and absf(sp.x) < tunnel.x * 0.5 + 1.6 and sp.y < tunnel.y + 1.4:
			continue      # Eingang frei lassen
		var r := rng.randf_range(1.0, 1.8) * lerpf(1.0, 0.65, el / 1.25)
		var c := tint.lerp(Color(0.42, 0.4, 0.36), rng.randf() * 0.35).lightened(rng.randf() * 0.1)
		# Flache Felsplatte, die sich an den Hang schmiegt (Hochachse = Flächennormale)
		var nrm := Vector3(sp.x / (rad.x * rad.x), (sp.y - cy) / (rad.y * rad.y), sp.z / (rad.z * rad.z)).normalized()
		var out := sp + nrm * r * 0.12
		var mi := stone(p, out, Vector3.ONE, rng.randi(), c, 0.32)
		mi.transform = Transform3D(Basis(Quaternion(Vector3.UP, nrm)) * Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(r * 1.15, r * 0.55, r)), out)
		placed += 1
		if el > 0.55 and rng.randf() < 0.45:
			var moss := Util.add_sphere(p, r * 0.7, Color(0.27, 0.47, 0.2).lerp(Color(0.38, 0.55, 0.22), rng.randf()), out + nrm * r * 0.45)
			moss.scale = Vector3(1.2, 0.28, 1.0)
			_flat(moss, false)


## Gebogener Bogen aus dicken Wurzeln über dem Eingang.
static func root_arch(p: Node3D, z: float, half_w: float, h: float, rng: RandomNumberGenerator) -> void:
	var col := Color(0.32, 0.22, 0.13)
	for strand in range(3):
		var off := Vector3(rng.randf_range(-0.08, 0.08), 0.0, -0.12 * strand)
		var rr := 0.17 - strand * 0.035
		var prev := Vector3(-half_w - 0.25, 0.0, z) + off
		var segs := 7
		for i in range(1, segs + 1):
			var t := float(i) / float(segs)
			var a := PI * (1.0 - t)
			var pt := Vector3(cos(a) * (half_w + 0.25), sin(a) * h + rng.randf_range(-0.06, 0.06), z) + off
			pt.y = maxf(pt.y, 0.0)
			HideoutArt.beam(p, prev, pt, rr, col.lerp(Color(0.42, 0.3, 0.18), rng.randf() * 0.4))
			prev = pt
	# Wurzelfüße, die in den Boden greifen
	for sgn in [-1.0, 1.0]:
		for k in range(2):
			var s := Vector3(sgn * (half_w + 0.25), 0.25, z)
			HideoutArt.beam(p, s, s + Vector3(sgn * rng.randf_range(0.5, 0.9), -0.25, rng.randf_range(-0.6, -0.1)), 0.09, col)


# ---------------------------------------------------------------------------
# Die fünf Verstecke
# ---------------------------------------------------------------------------

static func fuchsbau(root: Node3D, size: Vector3, tunnel: Vector3) -> void:
	var p := box_for(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4401
	var front := -size.z / 2.0
	rock_shell(p, size, tunnel, Color(0.52, 0.45, 0.37), rng, 24)
	root_arch(p, front - 0.75, tunnel.x / 2.0, tunnel.y + 0.25, rng)
	# Ein krummes Bäumchen und Gras oben auf dem Bau
	little_tree(p, Vector3(1.4, size.y * 0.95, 1.0), 2.4, rng)
	for i in range(4):
		fern(p, Vector3(rng.randf_range(-2.0, 2.0), size.y * 0.92, rng.randf_range(-0.8, 2.0)), rng.randf_range(0.6, 0.9), rng)
	# Ausgescharrte Erde vor dem Eingang
	var dirt := Util.add_sphere(p, 1.0, Color(0.36, 0.26, 0.17), Vector3(0, -0.05, front - 2.2))
	dirt.scale = Vector3(2.0, 0.18, 1.5)
	_flat(dirt, false)
	# Farne, Blumen, Laub, Totholz rundum
	for i in range(9):
		var a := TAU * float(i) / 9.0 + rng.randf() * 0.4
		var fp := Vector3(cos(a) * size.x * 0.62, 0.0, sin(a) * size.z * 0.66)
		if fp.z < front + 1.0 and absf(fp.x) < tunnel.x:
			fp.x += signf(fp.x if fp.x != 0.0 else 1.0) * tunnel.x
		fern(p, fp, rng.randf_range(0.8, 1.3), rng)
	for i in range(4):
		flowers(p, Vector3(rng.randf_range(-6.0, 6.0), 0.0, front - rng.randf_range(1.5, 4.5)), 5, rng)
	leaves(p, Vector3(0, 0, front - 2.0), 4.5, 45, rng)
	dead_log(p, Vector3(-5.6, 0.25, front - 1.5), Vector3(-3.4, 0.22, front - 3.6), 0.25, rng)


static func tropf(root: Node3D, size: Vector3, tunnel: Vector3) -> void:
	var p := box_for(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4402
	var front := -size.z / 2.0
	rock_shell(p, size, tunnel, Color(0.45, 0.48, 0.54), rng, 34)
	# Herabhängendes Moos/Efeu über dem Eingang
	for i in range(9):
		var x := rng.randf_range(-tunnel.x * 0.75, tunnel.x * 0.75)
		var l := rng.randf_range(0.6, 1.6)
		var top := tunnel.y + 0.7
		var strand := Util.add_box(p, Vector3(0.09, l, 0.04), Color(0.26, 0.46, 0.2).lerp(Color(0.4, 0.56, 0.22), rng.randf()), Vector3(x, top - l * 0.5, front - 0.55 - rng.randf() * 0.2))
		_flat(strand, false)
	# Bächlein, das aus der Höhle rinnt
	var water := Color(0.36, 0.55, 0.68)
	var z := front - 0.3
	var x := 0.3
	for i in range(10):
		var seg := Util.add_box(p, Vector3(rng.randf_range(0.5, 0.8), 0.02, 0.9), water, Vector3(x, 0.025, z))
		seg.material_override = Util.mat(water, 0.06)
		seg.rotation.y = rng.randf_range(-0.25, 0.25)
		_flat(seg, false)
		if rng.randf() < 0.7:
			stone(p, Vector3(x + rng.randf_range(0.45, 0.7) * (1.0 if i % 2 == 0 else -1.0), 0.05, z), Vector3(0.18, 0.12, 0.15), rng.randi(), Color(0.55, 0.56, 0.58), 0.2)
		z -= 0.8
		x += rng.randf_range(-0.35, 0.35)
	# Üppig: Farne, Moospolster, Blumen, Totholz
	for i in range(12):
		var a := TAU * float(i) / 12.0 + rng.randf() * 0.3
		var fp := Vector3(cos(a) * size.x * 0.6, 0.0, sin(a) * size.z * 0.62)
		if fp.z < front + 1.5 and absf(fp.x) < tunnel.x + 0.5:
			continue
		fern(p, fp, rng.randf_range(0.9, 1.4), rng)
	for i in range(5):
		var m := Util.add_sphere(p, rng.randf_range(0.5, 0.9), Color(0.28, 0.5, 0.22), Vector3(rng.randf_range(-7.0, 7.0), 0.0, front - rng.randf_range(0.5, 4.0)))
		m.scale = Vector3(1.4, 0.25, 1.1)
		_flat(m, false)
	for i in range(3):
		flowers(p, Vector3(rng.randf_range(-6.0, 6.0), 0.0, front - rng.randf_range(2.0, 5.0)), 5, rng, [Color(0.95, 0.95, 0.9), Color(0.6, 0.7, 1.0)])
	little_tree(p, Vector3(-3.0, size.y * 0.85, 1.5), 2.8, rng)
	little_tree(p, Vector3(3.5, size.y * 0.7, 2.6), 2.2, rng)
	dead_log(p, Vector3(5.5, 0.25, front - 1.0), Vector3(7.4, 0.3, front + 1.2), 0.28, rng)


static func huette(root: Node3D) -> void:
	var p := box_for(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4403
	var wood := Color(0.42, 0.28, 0.16)
	var dk := Color(0.3, 0.2, 0.11)
	# Trittsteine von der Stufe Richtung See
	for i in range(6):
		var st := stone(p, Vector3(rng.randf_range(-0.25, 0.25), 0.0, -3.0 - i * 0.85), Vector3(0.38, 0.09, 0.32), rng.randi(), Color(0.58, 0.56, 0.52), 0.15)
		st.position.y = 0.02
	# Bank vor der Hütte
	Util.add_box(p, Vector3(0.95, 0.06, 0.32), wood, Vector3(-1.7, 0.45, -2.15))
	for bx in [-2.08, -1.32]:
		Util.add_box(p, Vector3(0.07, 0.43, 0.26), dk, Vector3(bx, 0.21, -2.15))
	# Blumenkästen unter den Fenstern
	for sx in [-1.0, 1.0]:
		Util.add_box(p, Vector3(0.22, 0.16, 0.8), dk, Vector3(sx * 2.5, 1.02, 0.3))
		for k in range(5):
			var col: Color = [Color(0.95, 0.4, 0.45), Color(0.98, 0.85, 0.3), Color(0.95, 0.95, 0.9)][k % 3]
			_flat(Util.add_sphere(p, 0.07, col, Vector3(sx * 2.5, 1.16, 0.0 + k * 0.15)), false)
			_flat(Util.add_sphere(p, 0.06, Color(0.3, 0.52, 0.22), Vector3(sx * 2.5 + 0.03, 1.12, 0.07 + k * 0.15)), false)
	# Lattenzaun um den Vorgarten (vorn offen für den Weg)
	for sx in [-1.0, 1.0]:
		var posts: Array = []
		for k in range(5):
			posts.append(Vector3(sx * 3.9, 0.0, -0.8 - k * 1.1))
		posts.append(Vector3(sx * 2.9, 0.0, -5.2))
		posts.append(Vector3(sx * 1.6, 0.0, -5.2))
		for k in range(posts.size()):
			var pp: Vector3 = posts[k]
			Util.add_box(p, Vector3(0.09, 0.95, 0.09), wood.darkened(0.1), pp + Vector3(0, 0.47, 0))
			if k > 0:
				var q: Vector3 = posts[k - 1]
				for ry in [0.35, 0.75]:
					HideoutArt.beam(p, q + Vector3(0, ry, 0), pp + Vector3(0, ry, 0), 0.03, wood)
	# Kräuterbeet hinter der Hütte
	Util.add_box(p, Vector3(1.6, 0.12, 1.2), Color(0.28, 0.2, 0.13), Vector3(-4.2, 0.06, 2.3))
	for r in range(3):
		for k in range(4):
			_flat(Util.add_sphere(p, 0.12, Color(0.3, 0.55, 0.22).lerp(Color(0.45, 0.62, 0.25), rng.randf()), Vector3(-4.7 + k * 0.33, 0.18, 1.95 + r * 0.35)), false)
	# Wäscheleine
	Util.add_box(p, Vector3(0.08, 1.9, 0.08), wood, Vector3(3.6, 0.95, 2.6))
	HideoutArt.beam(p, Vector3(2.25, 1.85, 1.9), Vector3(3.6, 1.85, 2.6), 0.008, Color(0.9, 0.88, 0.8))
	for k in range(3):
		var c: Color = [Color(0.75, 0.25, 0.2), Color(0.3, 0.45, 0.7), Color(0.92, 0.9, 0.82)][k]
		var t := 0.25 + 0.25 * k
		var cl := Util.add_box(p, Vector3(0.32, 0.4, 0.02), c, Vector3(2.25, 1.65, 1.9).lerp(Vector3(3.6, 1.65, 2.6), t))
		cl.rotation.y = atan2(1.35, 0.7)
		_flat(cl, false)
	# Grün rundum
	for i in range(8):
		var a := TAU * float(i) / 8.0 + rng.randf() * 0.4
		var fp := Vector3(cos(a) * 5.0, 0.0, sin(a) * 4.4)
		if fp.z < -2.5 and absf(fp.x) < 1.6:
			continue
		fern(p, fp, rng.randf_range(0.7, 1.1), rng)
	for i in range(4):
		flowers(p, Vector3(rng.randf_range(-3.4, 3.4), 0.0, rng.randf_range(-4.8, -3.2)), 4, rng)
	leaves(p, Vector3(0, 0, -1.0), 6.0, 30, rng)


static func baum(root: Node3D) -> void:
	var p := box_for(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4404
	var bark := Color(0.33, 0.23, 0.15)
	# Mächtige, geschwungene Wurzeln (zwei Glieder je Wurzel)
	for i in range(8):
		var a := TAU * float(i) / 8.0 + 0.1
		if sin(a) < -0.55 and absf(cos(a)) < 0.6:
			continue    # vorn bleibt der Eingang frei
		var d := Vector3(cos(a), 0, sin(a))
		var p0 := d * 1.3 + Vector3(0, 1.1, 0)
		var p1 := d * 2.3 + Vector3(0, 0.35, 0) + Vector3(-d.z, 0, d.x) * rng.randf_range(-0.3, 0.3)
		var p2 := d * rng.randf_range(3.3, 4.0) + Vector3(0, -0.05, 0) + Vector3(-d.z, 0, d.x) * rng.randf_range(-0.5, 0.5)
		HideoutArt.beam(p, p0, p1, 0.32, bark)
		HideoutArt.beam(p, p1, p2, 0.2, bark.lightened(0.04))
	# Efeu, das sich den Stamm hochrankt
	var y := 0.4
	var ang := 2.2
	while y < 5.2:
		var pos := Vector3(cos(ang) * 1.45, y, sin(ang) * 1.45)
		var leaf := Util.add_box(p, Vector3(0.22, 0.18, 0.05), Color(0.2, 0.42, 0.18).lerp(Color(0.32, 0.52, 0.2), rng.randf()), pos)
		leaf.rotation = Vector3(rng.randf_range(-0.3, 0.3), -ang + PI / 2.0, rng.randf_range(-0.5, 0.5))
		_flat(leaf, false)
		y += 0.17
		ang += rng.randf_range(-0.12, 0.2)
	# Weitere Baumpilz-Konsolen (hell) in Stufen
	for i in range(5):
		var fa := 0.6 + float(i) * 0.25
		var fy := 0.9 + float(i) * 0.22
		var f := Util.add_cylinder(p, 0.26 - i * 0.02, 0.06, Color(0.9, 0.84, 0.66), Vector3(cos(fa) * 1.45, fy, sin(fa) * 1.45))
		f.rotation = Vector3(0.0, -fa, PI / 2.0)
		f.scale = Vector3(1.0, 1.0, 0.6)
		_flat(f, false)
	# Vogelhäuschen am Stamm
	var bh := Vector3(cos(4.0) * 1.15, 4.3, sin(4.0) * 1.15)
	var house := Util.add_box(p, Vector3(0.36, 0.42, 0.34), Color(0.62, 0.42, 0.24), bh)
	house.rotation.y = -4.0 + PI / 2.0
	for sgn in [-1.0, 1.0]:
		var rf := Util.add_box(p, Vector3(0.44, 0.04, 0.3), Color(0.7, 0.2, 0.15), bh + Vector3(0, 0.27, 0))
		rf.rotation = Vector3(0.0, -4.0 + PI / 2.0, 0.0)
		rf.rotate_object_local(Vector3.FORWARD, sgn * 0.6)
		rf.translate_object_local(Vector3(sgn * 0.12, 0.0, 0.0))
	var hole := Util.add_cylinder(p, 0.06, 0.02, Color(0.08, 0.06, 0.05), bh + Vector3(cos(4.0), 0, sin(4.0)) * 0.18 + Vector3(0, 0.05, 0))
	hole.basis = Basis(Quaternion(Vector3.UP, Vector3(cos(4.0), 0, sin(4.0))))
	# Boden: Laub, Farne, Blumen, Totholz
	leaves(p, Vector3.ZERO, 5.5, 60, rng)
	for i in range(7):
		var a2 := TAU * float(i) / 7.0 + 0.3
		var fp := Vector3(cos(a2) * 4.3, 0.0, sin(a2) * 4.3)
		if sin(a2) < -0.6 and absf(cos(a2)) < 0.6:
			continue
		fern(p, fp, rng.randf_range(0.8, 1.2), rng)
	for i in range(3):
		flowers(p, Vector3(rng.randf_range(-3.0, 3.0), 0.0, -rng.randf_range(2.5, 4.5)), 5, rng)
	dead_log(p, Vector3(3.2, 0.22, -2.2), Vector3(5.0, 0.25, -0.4), 0.22, rng)


static func lager(root: Node3D) -> void:
	var p := box_for(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4405
	var wood := Color(0.4, 0.27, 0.15)
	# Dreibein mit Kessel über der alten Feuerstelle
	var top := Vector3(0, 1.55, 0.2)
	for i in range(3):
		var a := TAU * float(i) / 3.0 + 0.4
		HideoutArt.beam(p, Vector3(cos(a) * 0.95, 0.0, sin(a) * 0.95 + 0.2), top, 0.035, wood)
	HideoutArt.beam(p, top, top - Vector3(0, 0.75, 0), 0.01, Color(0.25, 0.25, 0.27))
	Util.add_cylinder(p, 0.22, 0.26, Color(0.16, 0.16, 0.17), top - Vector3(0, 0.9, 0))
	_flat(Util.add_cylinder(p, 0.2, 0.02, Color(0.45, 0.25, 0.12), top - Vector3(0, 0.76, 0)), false)
	# Trockengestell mit Fischen
	var r0 := Vector3(-3.2, 0, 1.2)
	for sx in [-0.7, 0.7]:
		HideoutArt.beam(p, r0 + Vector3(sx, 0, 0), r0 + Vector3(sx, 1.5, 0), 0.04, wood)
	HideoutArt.beam(p, r0 + Vector3(-0.8, 1.45, 0), r0 + Vector3(0.8, 1.45, 0), 0.03, wood)
	for k in range(3):
		var fx := r0 + Vector3(-0.4 + k * 0.4, 1.15, 0)
		var body := Util.add_sphere(p, 0.18, Color(0.62, 0.64, 0.6), fx)
		body.scale = Vector3(0.35, 1.2, 0.6)
		var tail := Util.add_cone(p, 0.09, 0.14, Color(0.5, 0.52, 0.5), fx - Vector3(0, 0.25, 0))
		tail.rotation_degrees.x = 180.0
		_flat(Util.add_cylinder(p, 0.006, 0.12, Color(0.85, 0.78, 0.55), fx + Vector3(0, 0.25, 0)), false)
	# Holzstapel neben der Plane
	for row in range(3):
		for k in range(4 - row):
			var lg := HideoutArt.beam(p, Vector3(3.4, 0.12 + row * 0.22, 3.0 + k * 0.24 + row * 0.12), Vector3(3.4 + 0.01, 0.12 + row * 0.22, 3.0 + k * 0.24 + row * 0.12), 0.1, Color(0.5, 0.34, 0.18).lerp(Color(0.32, 0.22, 0.12), rng.randf()))
			lg.rotation_degrees = Vector3(0, 0, 90)
			(lg.mesh as CylinderMesh).height = 0.65
	# Grün rundum
	for i in range(9):
		var a2 := TAU * float(i) / 9.0 + rng.randf() * 0.4
		var fp := Vector3(cos(a2) * 6.0, 0.0, sin(a2) * 5.0 + 2.0)
		fern(p, fp, rng.randf_range(0.8, 1.2), rng)
	for i in range(4):
		flowers(p, Vector3(rng.randf_range(-5.0, 5.0), 0.0, rng.randf_range(-3.5, -1.5)), 5, rng)
	leaves(p, Vector3(0, 0, 1.5), 5.0, 35, rng)
	dead_log(p, Vector3(-5.0, 0.24, -1.0), Vector3(-6.3, 0.22, 1.4), 0.24, rng)
	little_tree(p, Vector3(5.6, 0.0, 6.4), 3.0, rng)


## Glühwürmchen um den hohlen Baum (ein einziges Partikel-Objekt).
static func fireflies(root: Node3D, center: Vector3, radius: float) -> void:
	var ff := CPUParticles3D.new()
	ff.amount = 18
	ff.lifetime = 5.0
	ff.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	ff.emission_box_extents = Vector3(radius, 1.0, radius)
	ff.direction = Vector3(0, 1, 0)
	ff.spread = 180.0
	ff.initial_velocity_min = 0.05
	ff.initial_velocity_max = 0.25
	ff.gravity = Vector3.ZERO
	var m := SphereMesh.new()
	m.radius = 0.03
	m.height = 0.06
	m.radial_segments = 4
	m.rings = 2
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.9, 1.0, 0.5)
	mat.emission_enabled = true
	mat.emission = Color(0.8, 1.0, 0.4)
	mat.emission_energy_multiplier = 3.0
	m.material = mat
	ff.mesh = m
	ff.position = center
	ff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ff)
