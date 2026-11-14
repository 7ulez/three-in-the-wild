class_name LanParty
extends Node3D
## Zombie-LAN-Party in einem offenen Raum (3x3 Zellen) im Labyrinth: lange Tische mit leuchtenden Monitoren,
## Stühlen und toten Spielern, die noch vor ihren Rechnern sitzen. Möbel sind ein einziges Mesh, die
## Monitore ein zweites (unbeleuchtet, flackern leicht); dazu sechs Figuren.

const LAYERS: int = 1 | Catacombs.CATA_LAYER
const FY: float = Catacombs.FLOOR_Y
const SEATED_Y: float = 0.5      # Höhe der Sitzfläche
const NAMES: Array = ["Marian", "Steffen", "Julian", "Steffen", "Julian", "Marian"]

var _screen_mat: StandardMaterial3D
var _flick_t: float = 0.0
var _screens: Array = []


func build(cata: Catacombs) -> void:
	var c := cata.lan_center()
	var rng := RandomNumberGenerator.new()
	rng.seed = 2003
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sc := SurfaceTool.new()
	sc.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wood := Color(0.27, 0.19, 0.12)
	var dark := Color(0.07, 0.07, 0.08)
	var seat_i := 0
	for dx in [-4.0, 0.0, 4.0]:
		var tx: float = c.x + dx
		# Tisch: Platte und vier Beine
		cata._box(st, Vector3(tx, FY + 0.74, c.z), Vector3(2.8, 0.05, 0.8), wood, 0.06, rng)
		for lx in [-1.3, 1.3]:
			for lz in [-0.35, 0.35]:
				cata._box(st, Vector3(tx + lx, FY + 0.36, c.z + lz), Vector3(0.05, 0.72, 0.05), dark, 0.0, rng)
		# Mehrfachsteckdose und Kabel unter dem Tisch zum Rechner
		cata._box(st, Vector3(tx, FY + 0.012, c.z), Vector3(2.6, 0.012, 0.03), dark, 0.0, rng)
		for side in [-1.0, 1.0]:
			var sg: float = side
			var sz: float = c.z + sg * 0.2                       # Monitor
			var px: float = tx
			# Monitor mit Fuß, Bildschirm zeigt zur Sitzseite
			cata._box(st, Vector3(px, FY + 0.78, sz), Vector3(0.14, 0.03, 0.14), dark, 0.0, rng)
			cata._box(st, Vector3(px, FY + 0.9, sz), Vector3(0.06, 0.2, 0.05), dark, 0.0, rng)
			cata._box(st, Vector3(px, FY + 1.1, sz), Vector3(0.62, 0.38, 0.05), dark, 0.0, rng)
			_screens.append([Vector3(px, FY + 1.1, sz + sg * 0.0275), sg, (seat_i + int(dx / 4.0) + 1) % 4])
			# Tastatur, Maus, Getränkedose
			cata._box(st, Vector3(px, FY + 0.77, c.z + sg * 0.3), Vector3(0.42, 0.02, 0.14), Color(0.12, 0.12, 0.13), 0.0, rng)
			cata._box(st, Vector3(px + 0.4, FY + 0.77, c.z + sg * 0.3), Vector3(0.06, 0.02, 0.1), Color(0.12, 0.12, 0.13), 0.0, rng)
			cata._box(st, Vector3(px - 0.55, FY + 0.83, c.z + sg * 0.15), Vector3(0.065, 0.12, 0.065), Color(0.75, 0.1, 0.08) if seat_i % 2 == 0 else Color(0.1, 0.55, 0.2), 0.05, rng)
			# Rechnerturm neben dem Tisch auf dem Boden
			cata._box(st, Vector3(px + 1.0, FY + 0.23, c.z + sg * 0.6), Vector3(0.22, 0.46, 0.45), Color(0.15, 0.15, 0.16), 0.0, rng)
			cata._box(sc, Vector3(px + 1.0, FY + 0.38, c.z + sg * 0.6 + sg * 0.226), Vector3(0.1, 0.012, 0.004), Color(0.1, 0.9, 0.2), 0.0, rng)
			# Stuhl
			var chz: float = c.z + sg * 1.05
			cata._box(st, Vector3(px, FY + SEATED_Y, chz), Vector3(0.46, 0.06, 0.46), Color(0.1, 0.1, 0.12), 0.0, rng)
			cata._box(st, Vector3(px, FY + 0.78, chz + sg * 0.22), Vector3(0.46, 0.55, 0.06), Color(0.1, 0.1, 0.12), 0.0, rng)
			cata._box(st, Vector3(px, FY + 0.25, chz), Vector3(0.06, 0.5, 0.06), Color(0.3, 0.3, 0.32), 0.0, rng)
			for k in range(4):
				var a := TAU * float(k) / 4.0 + 0.4
				cata._box(st, Vector3(px + cos(a) * 0.22, FY + 0.03, chz + sin(a) * 0.22), Vector3(0.05, 0.05, 0.05), Color(0.2, 0.2, 0.22), 0.0, rng)
			# Fleck unter dem Stuhl
			cata._box(st, Vector3(px + rng.randf_range(-0.1, 0.1), FY + 0.006, chz + sg * 0.2), Vector3(rng.randf_range(0.7, 1.1), 0.012, rng.randf_range(0.6, 0.9)), Color(0.25, 0.03, 0.03), 0.0, rng)
			_seat_figure(NAMES[seat_i % NAMES.size()], Vector3(px, FY, chz), sg, seat_i)
			seat_i += 1
	# Pizzakartons und leere Dosen auf dem Boden
	for k in range(7):
		var pxx: float = c.x + rng.randf_range(-5.0, 5.0)
		var pzz: float = c.z + (rng.randf_range(2.0, 4.8) if rng.randf() < 0.5 else rng.randf_range(-4.8, -2.0))
		cata._box(st, Vector3(pxx, FY + 0.03, pzz), Vector3(0.4, 0.05, 0.4), Color(0.55, 0.4, 0.22), 0.1, rng)
		cata._box(st, Vector3(pxx + 0.5, FY + 0.05, pzz + 0.2), Vector3(0.065, 0.1, 0.065), Color(0.7, 0.7, 0.72), 0.1, rng)
	# Switch-Rack in der Westecke mit blinkenden LEDs
	cata._box(st, Vector3(c.x - 5.0, FY + 0.9, c.z + 3.4), Vector3(0.6, 1.8, 0.6), Color(0.1, 0.1, 0.11), 0.0, rng)
	for k in range(8):
		var lc := Color(0.1, 0.9, 0.2) if k % 3 else Color(1.0, 0.6, 0.1)
		cata._box(sc, Vector3(c.x - 4.69, FY + 0.5 + 0.15 * float(k), c.z + 3.4 + (0.14 if k % 2 else -0.14)), Vector3(0.012, 0.03, 0.03), lc, 0.0, rng)
	# Kabelsalat zum Rack
	for k in range(4):
		cata._box(st, Vector3(c.x - 2.5, FY + 0.01, c.z + 1.5 + 0.12 * float(k)), Vector3(5.0, 0.014, 0.03), dark, 0.0, rng)
	st.generate_normals()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
	_add_mesh(st.commit(), mat)
	_screen_mat = StandardMaterial3D.new()
	_screen_mat.vertex_color_use_as_albedo = true
	_screen_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_add_mesh(sc.commit(), _screen_mat)
	_build_screens()
	# Wandflächen des Raums (dort, wo wirklich eine Wand steht): [Position, Blickrichtung (Yaw)]
	var slots: Array = []
	for i in range(cata.LAN_I0, cata.LAN_I1 + 1):
		var cx: float = cata.cell_center(cata.idx(i, cata.LAN_J0)).x
		if cata.south[cata.idx(i, cata.LAN_J0 - 1)] == 0:
			slots.append([Vector3(cx, FY, c.z - 5.42), 0.0])
		if cata.south[cata.idx(i, cata.LAN_J1)] == 0:
			slots.append([Vector3(cx, FY, c.z + 5.42), PI])
	for j in range(cata.LAN_J0, cata.LAN_J1 + 1):
		var cz: float = cata.cell_center(cata.idx(cata.LAN_I0, j)).z
		if cata.east[cata.idx(cata.LAN_I0 - 1, j)] == 0:
			slots.append([Vector3(c.x - 5.42, FY, cz), PI / 2.0])
		if cata.east[cata.idx(cata.LAN_I1, j)] == 0:
			slots.append([Vector3(c.x + 5.42, FY, cz), -PI / 2.0])
	# Poster erfundener Grunge-Bands
	var posters := _poster_atlas()
	var bands := ["GRAUWOLF", "STILLE TIEFE", "NEBELKIND", "ABGRUND"]
	var cols := [Color(0.05, 0.05, 0.05), Color(0.98, 0.9, 0.55), Color(0.05, 0.05, 0.05), Color(0.95, 0.2, 0.15)]
	for k in range(mini(slots.size(), 5)):
		var sl: Array = slots[k]
		var t: int = k % 4
		var pm := StandardMaterial3D.new()
		pm.albedo_texture = posters
		pm.uv1_scale = Vector3(0.25, 1.0, 1.0)
		pm.uv1_offset = Vector3(0.25 * float(t), 0.0, 0.0)
		pm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		pm.roughness = 1.0
		pm.cull_mode = BaseMaterial3D.CULL_DISABLED
		var q := QuadMesh.new()
		q.size = Vector2(0.9, 1.35)
		var pmi := MeshInstance3D.new()
		pmi.mesh = q
		pmi.material_override = pm
		pmi.layers = LAYERS
		pmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var sp: Vector3 = sl[0]
		var yw: float = sl[1]
		pmi.position = Vector3(sp.x, FY + 1.5, sp.z) + Vector3(sin(yw), 0.0, cos(yw)) * 0.0
		pmi.rotation.y = yw
		add_child(pmi)
		var bl := Label3D.new()
		bl.text = bands[t]
		bl.font_size = 40
		bl.pixel_size = 0.0035
		bl.modulate = cols[t]
		bl.outline_size = 0
		bl.position = Vector3(0, -0.5, 0.01)
		bl.layers = LAYERS
		pmi.add_child(bl)
	# Schild über dem ersten Poster
	if not slots.is_empty():
		var s0: Array = slots[0]
		var lb := Label3D.new()
		lb.text = "ZOMBIE LAN PARTY\nseit 2003 ununterbrochen online"
		lb.font_size = 64
		lb.pixel_size = 0.0035
		lb.modulate = Color(0.85, 0.12, 0.1)
		lb.outline_size = 12
		lb.outline_modulate = Color(0.02, 0.0, 0.0)
		var sp0: Vector3 = s0[0]
		lb.position = Vector3(sp0.x, FY + 2.6, sp0.z)
		lb.rotation.y = s0[1]
		lb.layers = LAYERS
		add_child(lb)
	# Blaues Monitorlicht
	var li := OmniLight3D.new()
	li.light_color = Color(0.45, 0.6, 1.0)
	li.light_energy = 0.9
	li.omni_range = 10.0
	li.position = Vector3(c.x, FY + 2.4, c.z)
	add_child(li)


func _add_mesh(m: ArrayMesh, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.layers = LAYERS
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


## Tote Spielerfigur: sitzt auf dem Stuhl, Oberkörper auf der Tastatur, grünlich-fahl
func _seat_figure(char_name: String, chair: Vector3, sg: float, idx: int) -> void:
	var pivot := Node3D.new()
	pivot.position = Vector3(chair.x, chair.y + SEATED_Y + 0.03, chair.z)
	# Figuren schauen standardmäßig nach -Z; Sitzseite Süd (sg>0) blickt zum Tisch = -Z
	pivot.rotation.y = 0.0 if sg > 0.0 else PI
	add_child(pivot)
	var lean := Node3D.new()
	lean.rotation.x = deg_to_rad(-62.0 - float(idx % 3) * 8.0)       # nach vorn gesackt
	lean.rotation.z = deg_to_rad(float((idx % 3) - 1) * 10.0)
	pivot.add_child(lean)
	var fig := Node3D.new()
	fig.position = Vector3(0, -0.5, 0.05)
	lean.add_child(fig)
	Player.build_body(fig, char_name)
	var ap := fig.get_meta("ap", null) as AnimationPlayer
	if ap != null and ap.has_animation("Sit"):
		ap.play("Sit")
		ap.seek(0.3, true)
		ap.speed_scale = 0.0
	var tint := StandardMaterial3D.new()
	tint.albedo_color = Color(0.35, 0.6, 0.3, 0.38)
	tint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tint.roughness = 1.0
	for n in fig.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		g.layers = LAYERS
		if g is MeshInstance3D and (g as MeshInstance3D).mesh != null and not String(g.name).begins_with("Blob"):
			g.material_overlay = tint


func _process(delta: float) -> void:
	_flick_t -= delta
	if _flick_t <= 0.0 and _screen_mat != null and visible:
		_flick_t = randf_range(0.05, 0.4)
		var k := randf_range(0.7, 1.0)
		_screen_mat.albedo_color = Color(k, k, k)


# ---------- Bildschirminhalt: eigener Retro-Shooter (4 Pixelbilder in einem Atlas) ----------

func _px(img: Image, x: int, y: int, col: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, col)


func _rect(img: Image, x0: int, y0: int, w: int, h: int, col: Color) -> void:
	for y in range(y0, y0 + h):
		for x in range(x0, x0 + w):
			_px(img, x, y, col)


func _build_screens() -> void:
	var img := Image.create(512, 80, false, Image.FORMAT_RGBA8)
	for t in range(4):
		_draw_screen(img, t * 128, t)
	var tex := ImageTexture.create_from_image(img)
	_screen_mat = StandardMaterial3D.new()
	_screen_mat.albedo_texture = tex
	_screen_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_screen_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_screen_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for e in _screens:
		var p: Vector3 = e[0]
		var sg: float = e[1]
		var t: int = e[2]
		var u0 := float(t) / 4.0
		var u1 := float(t + 1) / 4.0
		var hw := 0.28
		var hh := 0.16
		# Ecken: links-oben, rechts-oben, rechts-unten, links-unten (von der Sitzseite aus gesehen)
		var dxs: float = sg                      # Blick nach +Z: rechts = +X; Blick nach -Z: rechts = -X
		var tl := p + Vector3(-hw * dxs, hh, 0)
		var tr := p + Vector3(hw * dxs, hh, 0)
		var br := p + Vector3(hw * dxs, -hh, 0)
		var bl := p + Vector3(-hw * dxs, -hh, 0)
		var uv := [Vector2(u0, 0), Vector2(u1, 0), Vector2(u1, 1), Vector2(u0, 1)]
		var vs := [tl, tr, br, bl]
		for idx in [0, 1, 2, 0, 2, 3]:
			st.set_normal(Vector3(0, 0, sg))
			st.set_uv(uv[idx])
			st.add_vertex(vs[idx])
	_add_mesh(st.commit(), _screen_mat)


func _draw_screen(img: Image, ox: int, t: int) -> void:
	var w := 128
	var h := 80
	match t:
		0:
			# Gang in Schrägsicht mit Tür am Ende
			for y in range(0, 66):
				for x in range(w):
					var dx := float(x - 64)
					var dy := float(y - 34)
					var a := absf(dx) / 40.0
					var b := absf(dy) / 28.0
					var m := maxf(a, b)
					var shade := clampf(0.12 + 0.55 * m, 0.0, 0.9)
					var stripe := 1.0 if int(floorf(6.0 / maxf(m, 0.05))) % 2 == 0 else 0.82
					var col: Color
					if a > b:
						col = Color(0.55, 0.42, 0.3)
					elif dy > 0.0:
						col = Color(0.4, 0.4, 0.38)
					else:
						col = Color(0.25, 0.28, 0.32)
					_px(img, ox + x, y, Color(col.r * shade * stripe, col.g * shade * stripe, col.b * shade * stripe))
			_rect(img, ox + 58, 28, 12, 14, Color(0.02, 0.02, 0.03))
			_rect(img, ox + 60, 31, 8, 11, Color(0.8, 0.7, 0.3))
		1:
			# Draußen: Himmel, Sand, Kisten
			for y in range(0, 66):
				for x in range(w):
					var c: Color
					if y < 30:
						c = Color(0.35, 0.55, 0.85).lerp(Color(0.8, 0.88, 0.95), float(y) / 30.0)
					else:
						c = Color(0.72, 0.6, 0.38).lerp(Color(0.5, 0.4, 0.25), float(y - 30) / 36.0)
					_px(img, ox + x, y, c)
			for cr in [[20, 24, 18, 14], [90, 26, 14, 11], [52, 28, 10, 8], [100, 44, 22, 20], [8, 46, 26, 18]]:
				_rect(img, ox + cr[0], cr[1], cr[2], cr[3], Color(0.5, 0.33, 0.15))
				_rect(img, ox + cr[0], cr[1], cr[2], 2, Color(0.65, 0.45, 0.22))
				_rect(img, ox + cr[0], cr[1] + cr[3] - 2, cr[2], 2, Color(0.3, 0.2, 0.1))
		2:
			# Punktetafel
			_rect(img, ox, 0, w, 66, Color(0.08, 0.09, 0.12))
			_rect(img, ox + 4, 4, w - 8, 9, Color(0.9, 0.75, 0.2))
			for r in range(7):
				var yy := 17 + r * 7
				_rect(img, ox + 4, yy, w - 8, 6, Color(0.14, 0.16, 0.2) if r % 2 == 0 else Color(0.1, 0.11, 0.15))
				var blue := r < 4
				_rect(img, ox + 6, yy + 1, 3, 4, Color(0.3, 0.55, 0.95) if blue else Color(0.95, 0.55, 0.2))
				_rect(img, ox + 12, yy + 2, 20 + (r * 13) % 28, 2, Color(0.8, 0.82, 0.85))
				_rect(img, ox + 90, yy + 2, 3 + (r * 5) % 9, 2, Color(0.6, 0.9, 0.6))
				_rect(img, ox + 108, yy + 2, 3 + (r * 7) % 10, 2, Color(0.9, 0.5, 0.5))
		3:
			# Verbinde mit Server...
			_rect(img, ox, 0, w, 66, Color(0.02, 0.02, 0.04))
			_rect(img, ox + 20, 36, 88, 8, Color(0.3, 0.3, 0.35))
			_rect(img, ox + 21, 37, 86, 6, Color(0.02, 0.02, 0.04))
			_rect(img, ox + 22, 38, 52, 4, Color(0.3, 0.85, 0.4))
			for k in range(3):
				_rect(img, ox + 52 + k * 10, 24, 5, 5, Color(0.8, 0.8, 0.85) if k < 2 else Color(0.35, 0.35, 0.4))
	if t < 2:
		# Fadenkreuz und Waffensilhouette (nur Spielbilder)
		var gc := Color(0.2, 1.0, 0.3)
		_rect(img, ox + 60, 33, 3, 1, gc)
		_rect(img, ox + 66, 33, 3, 1, gc)
		_rect(img, ox + 64, 29, 1, 3, gc)
		_rect(img, ox + 64, 35, 1, 3, gc)
		_rect(img, ox + 84, 52, 28, 14, Color(0.12, 0.12, 0.14))
		_rect(img, ox + 74, 50, 14, 4, Color(0.18, 0.18, 0.2))
	# Statusleiste unten
	_rect(img, ox, 66, w, 14, Color(0.04, 0.04, 0.05))
	if t < 2:
		_rect(img, ox + 6, 70, 34, 6, Color(0.25, 0.05, 0.05))
		_rect(img, ox + 6, 70, 26 + t * 6, 6, Color(0.9, 0.2, 0.15))
		_rect(img, ox + 90, 70, 32, 6, Color(0.25, 0.18, 0.03))
		_rect(img, ox + 90, 70, 22, 6, Color(0.95, 0.7, 0.15))
	else:
		_rect(img, ox + 6, 71, 116, 4, Color(0.15, 0.16, 0.2))


## Vier erfundene Poster (je 64x96) nebeneinander: Wolfsauge, Wellenringe, Spirale, Streifen
func _poster_atlas() -> ImageTexture:
	var img := Image.create(256, 96, false, Image.FORMAT_RGBA8)
	# 0: Wolfsauge auf Kopierpapier
	_rect(img, 0, 0, 64, 96, Color(0.85, 0.83, 0.76))
	for y in range(96):
		for x in range(64):
			var d := Vector2(x - 32, y - 40).length()
			if d < 22.0:
				_px(img, x, y, Color(0.05, 0.05, 0.05))
			if d < 13.0:
				_px(img, x, y, Color(0.9, 0.88, 0.8))
			if d < 7.0:
				_px(img, x, y, Color(0.05, 0.05, 0.05))
	for k in range(10):
		_rect(img, 4 + k * 6, 4, 3, 5, Color(0.1, 0.1, 0.1))
	# 1: Wellenringe, Blitz
	for y in range(96):
		for x in range(64):
			var tt := float(y) / 96.0
			var c := Color(0.05, 0.25, 0.3).lerp(Color(0.02, 0.1, 0.15), tt)
			var d2 := Vector2(x - 32, y - 40).length()
			if int(d2 / 5.0) % 2 == 0 and d2 < 28.0:
				c = Color(0.15, 0.55, 0.6)
			_px(img, 64 + x, y, c)
	for k in range(30):
		var zx := 36 + (k % 6) * 2 - (k / 6) * 3
		_rect(img, 64 + clampi(zx, 2, 60), 18 + k * 2, 4, 3, Color(0.98, 0.9, 0.5))
	# 2: Spirale aus Quadraten auf Orange
	_rect(img, 128, 0, 64, 96, Color(0.9, 0.45, 0.12))
	for r in range(1, 12):
		var half := 3 * r
		var col := Color(0.05, 0.05, 0.05) if r % 2 == 1 else Color(0.9, 0.45, 0.12)
		_rect(img, 128 + 32 - half, 40 - half, half * 2, half * 2, col)
	_rect(img, 128 + 29, 37, 6, 6, Color(0.95, 0.85, 0.3))
	# 3: schwarz mit roten Streifen
	_rect(img, 192, 0, 64, 96, Color(0.04, 0.04, 0.05))
	for k in range(7):
		_rect(img, 192, 8 + k * 12, 64, 4 + k % 3, Color(0.8, 0.12, 0.1))
	for k in range(5):
		_rect(img, 192 + 8 + k * 11, 78, 6, 12, Color(0.9, 0.9, 0.85))
	return ImageTexture.create_from_image(img)
