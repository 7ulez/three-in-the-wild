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
			var scol: Color = ([Color(0.12, 0.25, 0.95), Color(0.1, 0.8, 0.25), Color(0.75, 0.75, 0.8), Color(0.9, 0.2, 0.15), Color(0.12, 0.25, 0.95), Color(0.1, 0.8, 0.25)][seat_i % 6] as Color)
			cata._box(sc, Vector3(px, FY + 1.1, sz + sg * 0.0275), Vector3(0.56, 0.32, 0.006), scol, 0.0, rng)
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
	# Schild an der Nordwand
	var lb := Label3D.new()
	lb.text = "ZOMBIE LAN PARTY\nseit 2003 ununterbrochen online"
	lb.font_size = 64
	lb.pixel_size = 0.0045
	lb.modulate = Color(0.85, 0.12, 0.1)
	lb.outline_size = 12
	lb.outline_modulate = Color(0.02, 0.0, 0.0)
	lb.position = Vector3(c.x, FY + 2.4, c.z - 5.42)
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
