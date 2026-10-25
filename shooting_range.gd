class_name ShootingRange
extends Node3D
## Der geheime Schießstand im Westen. Er ist eingezäunt und das Tor bleibt zu, bis man in der
## Schatzkiste der Höhle die Schatzkarte gefunden hat (auf der Karte erscheint dann ein X).
## Drei Minispiele: Luftgewehr-Schießbude (wie auf der Kirmes), Axt-Zielwerfen und Speerwurf.
## Lokale Koordinaten: +X = Richtung Tor/Wurflinie (Osten), -X = Richtung Ziele (Westen).

const CENTER: Vector3 = Vector3(-109.0, 0.0, -10.0)
const FX0: float = -22.0     # Zaun West
const FX1: float = 18.0      # Zaun Ost (Tor)
const FZ: float = 17.0       # Zaun Nord/Süd (+/-)
const LANE_GUN: float = -11.0
const LANE_AXE: float = 0.0
const LANE_SPEAR: float = 11.0
const STAND_X_GUN: float = 13.1
const STAND_X_THROW: float = 8.6

const WOOD := Color(0.45, 0.3, 0.16)
const WOOD_L := Color(0.62, 0.45, 0.25)
const WOOD_D := Color(0.3, 0.2, 0.11)
const METAL := Color(0.55, 0.57, 0.6)
const RED := Color(0.78, 0.14, 0.12)
const WHITE := Color(0.95, 0.93, 0.88)

# Axt
const AXE_G: float = 4.0
const AXE_W: float = 10.0         # Drehung der Axt in rad/s
const AXE_V0: float = 7.0
const AXE_V1: float = 17.0
const AXE_THROWS: int = 5
const AXE_BOARD_X: float = 0.6
const AXE_BACK_X: float = -2.4
# Speer
const SP_G: float = 6.0
const SP_V0: float = 14.0
const SP_V1: float = 32.0
const SP_THROWS: int = 5
const SP_BACK_X: float = -20.8
# Luftgewehr
const GUN_SHOTS: int = 20
const GUN_TIME: float = 60.0

static var bests: Dictionary = {"gun": 0, "axe": 0, "spear": 0}
static var best_names: Dictionary = {"gun": "", "axe": "", "spear": ""}

var main: Node
var gate_body: StaticBody3D = null
var gate_pivot: Node3D = null
var gate_open: bool = false
var gate_labels: Array = []
var movers: Array = []          # alle bewegten/animierten Teile (Referenz, damit der Batcher sie in Ruhe lässt)
var gun_targets: Array = []     # [{node, kind, pts, r, home}]
var board_labels: Dictionary = {}
var _held_refs: Array = []

# --- Minispiel-Zustand ---
var mode: String = ""
var phase: String = ""          # intro | play | result
var pl: Player = null
var _t_phase: float = 0.0
var score: int = 0
var shots_left: int = 0
var time_left: float = 0.0
var charging: bool = false
var power: float = 0.0
var _power_dir: float = 1.0
var _busy: bool = false
var _gun_cd: float = 0.0
var _saved_third: bool = false
var _vm: Node3D = null
var _vm_base: Vector3 = Vector3.ZERO
var _proj: Array = []
var _stuck: Dictionary = {"axe": [], "spear": []}
var _plane_targets: Array = []
var _preview: Node3D = null
var _zone: Array = []           # grüne Bereiche im Kraftbalken [[a,b], ...]
var _stand_pos: Vector3 = Vector3.ZERO
var _end_t: float = 0.0


## Rechteck um den Schießstand (mit Rand): Bäume, Tiere und Pilze bleiben draußen.
static func in_zone(p: Vector3) -> bool:
	var lx := p.x - CENTER.x
	var lz := p.z - CENTER.z
	return lx > FX0 - 6.0 and lx < FX1 + 6.0 and absf(lz) < FZ + 6.0


func build(p_main: Node) -> void:
	main = p_main
	position = CENTER
	_build_floor()
	_build_fence()
	_build_gun_lane()
	_build_axe_lane()
	_build_spear_lane()
	_build_decor()


# ---------------------------------------------------------------------------
# Bauen
# ---------------------------------------------------------------------------

func _solid(size: Vector3, col: Color, pos: Vector3, rot_y: float = 0.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation.y = rot_y
	add_child(body)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	body.add_child(cs)
	Util.add_box(body, size, col)
	return body


func _label(parent: Node, text: String, pos: Vector3, px: float, col: Color, yaw_deg: float = 0.0, fs: int = 48) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = fs
	l.pixel_size = px
	l.modulate = col
	l.outline_size = 0
	l.position = pos
	l.rotation_degrees.y = yaw_deg
	l.double_sided = false
	parent.add_child(l)
	return l


func _build_floor() -> void:
	var fl := Util.add_box(self, Vector3(FX1 - FX0 + 2.0, 0.04, FZ * 2.0 + 2.0), Color(0.6, 0.52, 0.38), Vector3((FX0 + FX1) / 2.0, 0.02, 0.0))
	fl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Wurflinien
	for lane in [LANE_AXE, LANE_SPEAR]:
		Util.add_box(self, Vector3(0.12, 0.05, 3.4), WHITE, Vector3(STAND_X_THROW + 0.6, 0.05, lane))
	Util.add_box(self, Vector3(0.12, 0.05, 3.4), WHITE, Vector3(STAND_X_GUN + 0.7, 0.05, LANE_GUN))


func _build_fence() -> void:
	var h := 2.4
	var segs: Array = [
		[Vector3(FX0, 0, -FZ), Vector3(FX1, 0, -FZ)],          # Nord
		[Vector3(FX0, 0, FZ), Vector3(FX1, 0, FZ)],            # Süd
		[Vector3(FX0, 0, -FZ), Vector3(FX0, 0, FZ)],           # West
		[Vector3(FX1, 0, -FZ), Vector3(FX1, 0, -1.7)],         # Ost, Nordteil
		[Vector3(FX1, 0, 1.7), Vector3(FX1, 0, FZ)],           # Ost, Südteil
	]
	for s in segs:
		var a: Vector3 = s[0]
		var b: Vector3 = s[1]
		var d := b - a
		var len := d.length()
		var mid := (a + b) * 0.5
		var yaw := atan2(-d.z, d.x)
		var body := StaticBody3D.new()
		body.position = mid + Vector3(0, h / 2.0, 0)
		body.rotation.y = yaw
		add_child(body)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(len, h, 0.2)
		cs.shape = bs
		body.add_child(cs)
		# Zaunlatten (nur Optik): Rahmen + senkrechte Latten
		var vis := Node3D.new()
		vis.position = Vector3(0, -h / 2.0, 0)
		body.add_child(vis)
		Util.add_box(vis, Vector3(len, 0.1, 0.06), WOOD_D, Vector3(0, 0.5, 0))
		Util.add_box(vis, Vector3(len, 0.1, 0.06), WOOD_D, Vector3(0, 1.4, 0))
		Util.add_box(vis, Vector3(len, 0.1, 0.06), WOOD_D, Vector3(0, 2.2, 0))
		var n := int(len / 0.42)
		for i in range(n):
			var x := -len / 2.0 + (float(i) + 0.5) * (len / float(n))
			var lh := 2.15 + 0.18 * sin(float(i) * 1.7)
			Util.add_box(vis, Vector3(0.26, lh, 0.05), WOOD if i % 2 == 0 else WOOD_L, Vector3(x, lh / 2.0, 0.045))
	# Eckpfosten
	for c in [Vector2(FX0, -FZ), Vector2(FX0, FZ), Vector2(FX1, -FZ), Vector2(FX1, FZ), Vector2(FX1, -1.7), Vector2(FX1, 1.7)]:
		Util.add_box(self, Vector3(0.3, 2.9, 0.3), WOOD_D, Vector3(c.x, 1.45, c.y))
	# Tor: Flügel an Angeln bei z=-1.7, schwingt nach außen auf
	gate_pivot = Node3D.new()
	gate_pivot.position = Vector3(FX1, 0, -1.7)
	add_child(gate_pivot)
	gate_body = StaticBody3D.new()
	gate_body.position = Vector3(0, 1.1, 1.7)
	gate_pivot.add_child(gate_body)
	var gcs := CollisionShape3D.new()
	var gbs := BoxShape3D.new()
	gbs.size = Vector3(0.25, 2.2, 3.4)
	gcs.shape = gbs
	gate_body.add_child(gcs)
	Util.add_box(gate_body, Vector3(0.12, 0.14, 3.4), WOOD_D, Vector3(0, 0.85, 0))
	Util.add_box(gate_body, Vector3(0.12, 0.14, 3.4), WOOD_D, Vector3(0, -0.85, 0))
	for i in range(8):
		Util.add_box(gate_body, Vector3(0.1, 2.1, 0.32), WOOD if i % 2 == 0 else WOOD_L, Vector3(0.05, 0, -1.5 + float(i) * 0.43))
	# Vorhängeschloss
	var lock := Node3D.new()
	lock.name = "Schloss"
	lock.position = Vector3(0.16, -0.05, 1.45)
	gate_body.add_child(lock)
	Util.add_box(lock, Vector3(0.1, 0.22, 0.2), Color(0.85, 0.7, 0.15), Vector3.ZERO)
	var bow := Util.add_cylinder(lock, 0.07, 0.04, METAL, Vector3(0, 0.15, 0))
	bow.rotation_degrees.x = 90.0
	gate_labels.append(lock)
	movers.append(lock)
	movers.append(gate_pivot)
	# Schild über dem Tor (von außen lesbar)
	Util.add_box(self, Vector3(0.12, 0.7, 4.2), WOOD_D, Vector3(FX1, 3.2, 0.0))
	_label(self, "SCHIESSSTAND", Vector3(FX1 + 0.08, 3.2, 0.0), 0.0075, Color(0.95, 0.85, 0.5), 90.0, 72)
	var gate_script := GateHandle.new()
	gate_script.range_ref = self
	gate_script.collision_layer = 1
	gate_script.position = Vector3(0, 0, 0)
	gate_body.add_child(gate_script)
	var hcs := CollisionShape3D.new()
	var hbs := BoxShape3D.new()
	hbs.size = Vector3(0.5, 2.2, 3.4)
	hcs.shape = hbs
	gate_script.add_child(hcs)
	_held_refs.append(gate_script)


func open_gate() -> void:
	if gate_open:
		return
	gate_open = true
	Game.range_open = true
	if gate_pivot != null:
		create_tween().tween_property(gate_pivot, "rotation_degrees:y", 105.0, 1.1).set_trans(Tween.TRANS_QUAD)
	gate_body.collision_layer = 0
	for c in gate_body.get_children():
		if c is Area3D or (c is StaticBody3D):
			(c as CollisionObject3D).collision_layer = 0
	for l in gate_labels:
		(l as Node3D).visible = false
	Sfx.play("crate", global_position + Vector3(FX1, 1.0, 0.0), 0.0, 0.7)


# ---------------------------------------------------------------------------
# Luftgewehr-Schießbude (Kirmes)
# ---------------------------------------------------------------------------

func _stripes(parent: Node, size: Vector3, pos: Vector3, n: int, tilt_deg: float = 0.0) -> void:
	var node := Node3D.new()
	node.position = pos
	node.rotation_degrees.z = tilt_deg
	parent.add_child(node)
	for i in range(n):
		var w := size.z / float(n)
		Util.add_box(node, Vector3(size.x, size.y, w), RED if i % 2 == 0 else WHITE, Vector3(0, 0, -size.z / 2.0 + (float(i) + 0.5) * w))


func _build_booth(lane: float, x: float, mode_id: String, title: String, sub: String) -> void:
	# Tresen
	var counter := Booth.new()
	counter.range_ref = self
	counter.mode_id = mode_id
	counter.position = Vector3(x, 0.0, lane)
	counter.collision_layer = 1
	add_child(counter)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.9, 1.05, 3.2)
	cs.shape = bs
	cs.position.y = 0.525
	counter.add_child(cs)
	Util.add_box(counter, Vector3(0.9, 1.0, 3.2), WOOD, Vector3(0, 0.5, 0))
	Util.add_box(counter, Vector3(1.0, 0.07, 3.3), WOOD_L, Vector3(0, 1.04, 0))
	# Pfosten + Dach mit Streifen + Schild
	for sz in [-1.6, 1.6]:
		Util.add_box(self, Vector3(0.14, 2.5, 0.14), WOOD_D, Vector3(x - 0.3, 1.25, lane + sz))
	_stripes(self, Vector3(1.9, 0.08, 3.5), Vector3(x - 0.35, 2.55, lane), 7)
	var sign_back := Util.add_box(self, Vector3(0.1, 0.62, 3.0), WOOD_D, Vector3(x + 0.02, 2.95, lane))
	sign_back.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_label(self, title, Vector3(x + 0.09, 2.98, lane), 0.0055, Color(0.98, 0.88, 0.45), 90.0, 64)
	var bl := _label(self, sub, Vector3(x, 1.1, lane), 0.003, Color(1, 0.95, 0.75), 0.0, 40)
	bl.rotation_degrees = Vector3(-90, 90, 0)
	board_labels[mode_id] = bl
	_update_board(mode_id)


func _update_board(mode_id: String) -> void:
	var bl: Label3D = board_labels.get(mode_id, null) as Label3D
	if bl == null:
		return
	var best: int = int(bests.get(mode_id, 0))
	var who: String = String(best_names.get(mode_id, ""))
	var base: String = {"gun": "20 Schuss in 60 s", "axe": "5 Würfe", "spear": "5 Würfe"}.get(mode_id, "")
	bl.text = "%s\nRekord: %s\n[E] spielen" % [base, ("%d  (%s)" % [best, who]) if best > 0 else "noch keiner"]


func _build_gun_lane() -> void:
	_build_booth(LANE_GUN, 12.0, "gun", "LUFTGEWEHR", "")
	# Rückwand
	_solid(Vector3(0.4, 3.6, 9.4), Color(0.33, 0.19, 0.11), Vector3(-2.0, 1.8, LANE_GUN))
	_stripes(self, Vector3(0.05, 0.4, 9.4), Vector3(-1.78, 3.35, LANE_GUN), 14)
	# Regal mit Dosen (10 Punkte)
	Util.add_box(self, Vector3(0.6, 0.08, 7.4), WOOD_L, Vector3(-1.45, 1.45, LANE_GUN))
	var can_cols: Array = [Color(0.85, 0.2, 0.18), Color(0.2, 0.55, 0.85), Color(0.95, 0.75, 0.2), Color(0.3, 0.7, 0.3)]
	for i in range(8):
		var can := Node3D.new()
		var home := Vector3(-1.4, 1.49 + 0.0, LANE_GUN - 3.3 + float(i) * 0.94)
		can.position = home
		add_child(can)
		Util.add_cylinder(can, 0.1, 0.26, can_cols[i % 4], Vector3(0, 0.13, 0))
		Util.add_cylinder(can, 0.102, 0.03, METAL, Vector3(0, 0.27, 0))
		gun_targets.append({"node": can, "kind": "can", "pts": 10, "r": 0.17, "home": home, "up": true, "off_t": 0.0})
		movers.append(can)
	# Entenreihe (wandert, 20 Punkte)
	Util.add_box(self, Vector3(0.1, 0.06, 8.2), METAL, Vector3(0.6, 0.98, LANE_GUN))
	for i in range(5):
		var duck := Node3D.new()
		var dhome := Vector3(0.6, 1.2, LANE_GUN - 3.6 + float(i) * 1.8)
		duck.position = dhome
		add_child(duck)
		var pivot := Node3D.new()
		duck.add_child(pivot)
		Util.add_sphere(pivot, 0.14, Color(0.98, 0.85, 0.2), Vector3(0, 0, 0)).scale = Vector3(1.0, 0.85, 1.2)
		Util.add_sphere(pivot, 0.09, Color(0.98, 0.85, 0.2), Vector3(-0.02, 0.17, 0.0))
		Util.add_box(pivot, Vector3(0.1, 0.03, 0.05), Color(0.95, 0.5, 0.1), Vector3(-0.1, 0.16, 0.0))
		Util.add_box(pivot, Vector3(0.03, 0.6, 0.03), METAL, Vector3(0, -0.4, 0))
		gun_targets.append({"node": duck, "kind": "duck", "pts": 20, "r": 0.2, "home": dhome, "up": true, "off_t": 0.0, "dir": 1.0 if i % 2 == 0 else -1.0, "pivot": pivot, "speed": 1.2 + 0.25 * float(i % 3)})
		movers.append(duck)
		movers.append(pivot)
	# Zielscheiben (30/50 Punkte), pendeln hoch und runter
	for i in range(2):
		var disc := Node3D.new()
		var chome := Vector3(-1.55, 2.5, LANE_GUN - 2.4 + float(i) * 4.8)
		disc.position = chome
		add_child(disc)
		_bull(disc, 0.3, [[0.3, RED], [0.22, WHITE], [0.15, RED], [0.08, WHITE]], true)
		gun_targets.append({"node": disc, "kind": "disc", "pts": 30, "r": 0.3, "home": chome, "up": true, "off_t": 0.0, "phase": float(i) * PI})
		movers.append(disc)


## Runde Scheibe, flach zum Schützen (+X). rings: [[radius, farbe], ...] von außen nach innen.
func _bull(parent: Node3D, _radius: float, rings: Array, _with_post: bool = false) -> void:
	var x := 0.0
	for r in rings:
		var cyl := Util.add_cylinder(parent, float(r[0]), 0.06, r[1], Vector3(x, 0, 0))
		cyl.rotation_degrees.z = 90.0
		x += 0.006


# ---------------------------------------------------------------------------
# Axt-Zielwerfen
# ---------------------------------------------------------------------------

func _target_rings() -> Array:
	# [Radius relativ zum Außenradius, Punkte]
	return [[0.15, 100], [0.35, 50], [0.58, 30], [0.8, 20], [1.0, 10]]


func _target_disc(parent: Node3D, radius: float) -> void:
	var radii: Array = [1.0, 0.8, 0.58, 0.35, 0.15]
	var cols: Array = [Color(0.8, 0.65, 0.4), Color(0.12, 0.12, 0.12), WHITE, RED, Color(0.96, 0.82, 0.15)]
	var outer := Util.add_cylinder(parent, radius * 1.07, 0.14, WOOD_D, Vector3(-0.08, 0, 0))
	outer.rotation_degrees.z = 90.0
	var x := 0.0
	for i in range(radii.size()):
		var cyl := Util.add_cylinder(parent, radius * float(radii[i]), 0.05, cols[i], Vector3(x, 0, 0))
		cyl.rotation_degrees.z = 90.0
		x += 0.012


func _build_axe_lane() -> void:
	_build_booth_table(LANE_AXE, "axe", "AXT-ZIELWERFEN")
	# Rückwand aus Baumstämmen
	_solid(Vector3(0.5, 3.4, 8.0), Color(0.36, 0.24, 0.13), Vector3(-2.8, 1.7, LANE_AXE))
	for i in range(16):
		Util.add_cylinder(self, 0.26, 3.3, WOOD if i % 2 == 0 else WOOD_L, Vector3(-2.5, 1.65, LANE_AXE - 3.75 + float(i) * 0.5))
	# Scheibenpfosten + Scheibe
	for sz in [-0.6, 0.6]:
		Util.add_box(self, Vector3(0.18, 2.6, 0.18), WOOD_D, Vector3(AXE_BOARD_X - 0.2, 1.3, LANE_AXE + sz))
	var board := Node3D.new()
	board.position = Vector3(AXE_BOARD_X, 1.5, LANE_AXE)
	add_child(board)
	_target_disc(board, 0.8)


func _build_booth_table(lane: float, mode_id: String, title: String) -> void:
	var tb := Booth.new()
	tb.range_ref = self
	tb.mode_id = mode_id
	tb.position = Vector3(10.6, 0.0, lane)
	tb.collision_layer = 1
	add_child(tb)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.9, 1.0, 1.9)
	cs.shape = bs
	cs.position.y = 0.5
	tb.add_child(cs)
	Util.add_box(tb, Vector3(0.9, 0.1, 1.9), WOOD_L, Vector3(0, 0.95, 0))
	for sz in [-0.8, 0.8]:
		for sx in [-0.35, 0.35]:
			Util.add_box(tb, Vector3(0.1, 0.95, 0.1), WOOD_D, Vector3(sx, 0.47, sz))
	# Deko auf dem Tisch
	if mode_id == "axe":
		for i in range(2):
			var ax := Node3D.new()
			ax.position = Vector3(0.05, 1.03, -0.4 + float(i) * 0.8)
			ax.rotation_degrees = Vector3(90, 0, 90 + 14.0 * float(i))
			tb.add_child(ax)
			_axe_model(ax)
	else:
		for i in range(2):
			var sp := Node3D.new()
			sp.position = Vector3(-0.15 + 0.3 * float(i), 1.06, -0.95)
			sp.rotation_degrees.y = 0.0
			tb.add_child(sp)
			_spear_model(sp)
	Util.add_box(self, Vector3(0.1, 0.9, 0.12), WOOD_D, Vector3(12.0, 1.9, lane - 1.1))
	Util.add_box(self, Vector3(0.1, 0.9, 0.12), WOOD_D, Vector3(12.0, 1.9, lane + 1.1))
	Util.add_box(self, Vector3(0.1, 0.7, 2.6), WOOD_D, Vector3(12.0, 2.55, lane))
	_label(self, title, Vector3(12.08, 2.56, lane), 0.0042, Color(0.98, 0.88, 0.45), 90.0, 64)
	var bl := _label(self, "", Vector3(10.6, 1.02, lane), 0.003, Color(1, 0.95, 0.75), 0.0, 40)
	bl.rotation_degrees = Vector3(-90, 90, 0)
	board_labels[mode_id] = bl
	_update_board(mode_id)


# ---------------------------------------------------------------------------
# Speerwurf
# ---------------------------------------------------------------------------

const SPEAR_TARGETS: Array = [
	{"x": -4.0, "z": 8.4, "r": 0.95, "mult": 1},
	{"x": -11.0, "z": 11.0, "r": 1.15, "mult": 2},
	{"x": -17.5, "z": 13.8, "r": 1.35, "mult": 3},
]


func _build_spear_lane() -> void:
	_build_booth_table(LANE_SPEAR, "spear", "SPEERWURF")
	# Rückwand aus Strohballen
	_solid(Vector3(0.8, 3.0, 12.0), Color(0.82, 0.7, 0.3), Vector3(-21.2, 1.5, LANE_SPEAR + 1.0))
	for i in range(8):
		for j in range(2):
			Util.add_box(self, Vector3(0.9, 1.0, 1.4), Color(0.86, 0.74, 0.34).darkened(0.05 * float((i + j) % 3)), Vector3(-20.7, 0.5 + float(j), LANE_SPEAR - 4.6 + float(i) * 1.5))
	for t in SPEAR_TARGETS:
		var tx: float = t["x"]
		var tz: float = LANE_SPEAR + (float(t["z"]) - 11.0)
		var r: float = t["r"]
		for sz in [-r * 0.5, r * 0.5]:
			Util.add_box(self, Vector3(0.2, 1.8, 0.2), WOOD_D, Vector3(tx - 0.25, 0.9, tz + sz))
		var disc := Node3D.new()
		disc.position = Vector3(tx, 1.6, tz)
		add_child(disc)
		_target_disc(disc, r)
		_label(self, "x%d" % int(t["mult"]), Vector3(tx + 0.12, 1.6 + r + 0.35, tz), 0.01, Color(1, 0.9, 0.3), 90.0, 64)


func _build_decor() -> void:
	# Strohballen, Fässer, Wimpelkette
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for i in range(5):
		var bale := Util.add_box(self, Vector3(1.3, 0.7, 0.8), Color(0.86, 0.74, 0.34), Vector3(14.5 + rng.randf() * 1.2, 0.35, -15.0 + float(i) * 6.2 + rng.randf()))
		bale.rotation.y = rng.randf() * 0.4
	for i in range(3):
		Util.add_cylinder(self, 0.34, 0.9, Color(0.4, 0.26, 0.14), Vector3(15.8, 0.45, -5.5 + float(i) * 5.6))
	var cols: Array = [RED, Color(0.95, 0.8, 0.2), Color(0.25, 0.55, 0.85), Color(0.3, 0.7, 0.3)]
	for zz in [-FZ + 0.1, FZ - 0.1]:
		for i in range(14):
			var tri := MeshInstance3D.new()
			var pm := PrismMesh.new()
			pm.size = Vector3(0.4, 0.5, 0.02)
			tri.mesh = pm
			tri.material_override = Util.mat(cols[i % 4])
			tri.rotation_degrees.z = 180.0
			tri.position = Vector3(FX0 + 1.5 + float(i) * 2.7, 2.75 - 0.15 * sin(float(i) * 0.9), zz)
			add_child(tri)


# ---------------------------------------------------------------------------
# Modelle (Axt, Speer)
# ---------------------------------------------------------------------------

## Ursprung = Klingenmitte. Griff zeigt nach -Y (unten), Schneide nach -X (vorn).
func _axe_model(parent: Node3D) -> void:
	Util.add_box(parent, Vector3(0.045, 0.62, 0.045), Color(0.5, 0.33, 0.16), Vector3(0, -0.31, 0))
	Util.add_box(parent, Vector3(0.12, 0.13, 0.06), Color(0.42, 0.44, 0.48), Vector3(0.0, 0.0, 0))
	var blade := Util.add_box(parent, Vector3(0.14, 0.2, 0.025), Color(0.72, 0.74, 0.78), Vector3(-0.1, 0.0, 0))
	blade.rotation_degrees.z = 0.0


## Ursprung = Spitze, Schaft zeigt nach +Z (hinten).
func _spear_model(parent: Node3D) -> void:
	var shaft := Util.add_cylinder(parent, 0.016, 1.9, Color(0.52, 0.36, 0.18), Vector3(0, 0, 0.95))
	shaft.rotation_degrees.x = 90.0
	var tip := Util.add_cone(parent, 0.035, 0.24, Color(0.78, 0.8, 0.84), Vector3(0, 0, 0.0))
	tip.rotation_degrees.x = -90.0
	for a in [0.0, 90.0]:
		var f := Util.add_box(parent, Vector3(0.004, 0.09, 0.2), Color(0.85, 0.2, 0.15), Vector3(0, 0, 1.8))
		f.rotation_degrees.z = a


# ---------------------------------------------------------------------------
# Interaktion
# ---------------------------------------------------------------------------

class GateHandle:
	extends StaticBody3D
	var range_ref: ShootingRange = null

	func get_prompt() -> String:
		if Game.range_open:
			return ""
		if Game.map_found:
			return "E: Tor aufschließen (Schatzkarte)"
		return "Das Tor ist mit einem alten Vorhängeschloss verschlossen."

	func interact(player: Node) -> void:
		if Game.range_open:
			return
		if not Game.map_found:
			player.toast("Verschlossen. Das rostige Schloss geht nicht auf. Ohne Hinweis kommt hier keiner rein.", 4.0)
			Sfx.play("click", global_position, -2.0, 0.7)
			return
		range_ref.open_gate()
		player.toast("Das Schloss springt auf! Willkommen am geheimen Schießstand.", 5.0)
		if player.has_method("get_minihud"):
			player.get_minihud().card("SCHIESSSTAND ENTDECKT!", "Luftgewehr · Axtwurf · Speerwurf", Color(0.95, 0.8, 0.3), 4.0)

	func interact_with_held(_player: Node, _item: Node) -> bool:
		return false


class Booth:
	extends StaticBody3D
	var range_ref: ShootingRange = null
	var mode_id: String = ""

	func get_prompt() -> String:
		var nm: String = {"gun": "Luftgewehr-Schießbude", "axe": "Axt-Zielwerfen", "spear": "Speerwurf"}.get(mode_id, "")
		return "E: %s spielen" % nm

	func interact(player: Node) -> void:
		range_ref.begin(mode_id, player as Player)

	func interact_with_held(player: Node, _item: Node) -> bool:
		player.toast("Hände frei machen: erst den Gegenstand ablegen (E), dann spielen.", 3.0)
		return true


# ---------------------------------------------------------------------------
# Minispiel: Ablauf
# ---------------------------------------------------------------------------

func _stand_for(m: String) -> Vector3:
	match m:
		"gun":
			return to_global(Vector3(STAND_X_GUN, 0.0, LANE_GUN))
		"axe":
			return to_global(Vector3(STAND_X_THROW, 0.0, LANE_AXE))
	return to_global(Vector3(STAND_X_THROW, 0.0, LANE_SPEAR))


func begin(m: String, player: Player) -> void:
	if mode != "" or player == null or player.minigame != null:
		return
	if player.held != null:
		player.toast("Hände frei machen: erst den Gegenstand ablegen.", 3.0)
		return
	mode = m
	pl = player
	player.minigame = self
	_saved_third = player.third_person
	player.third_person = false
	player._apply_view()
	_stand_pos = _stand_for(m)
	player.global_position = _stand_pos + Vector3(0, 0.05, 0)
	player.velocity = Vector3.ZERO
	player.rotation.y = PI / 2.0
	player.pitch = 0.0
	player.head.rotation.x = 0.0
	score = 0
	charging = false
	power = 0.0
	_busy = false
	_gun_cd = 0.0
	_end_t = 0.0
	_clear_projectiles()
	if m != "gun":
		_clear_stuck(m)
	for tg in gun_targets:
		_reset_gun_target(tg)
	match m:
		"gun":
			shots_left = GUN_SHOTS
			time_left = GUN_TIME
		"axe":
			shots_left = AXE_THROWS
			_plane_targets = [{"x": to_global(Vector3(AXE_BOARD_X, 0, 0)).x, "c": to_global(Vector3(AXE_BOARD_X, 1.5, LANE_AXE)), "R": 0.8, "mult": 1}]
		"spear":
			shots_left = SP_THROWS
			_plane_targets = []
			for t in SPEAR_TARGETS:
				_plane_targets.append({"x": to_global(Vector3(float(t["x"]), 0, 0)).x, "c": to_global(Vector3(float(t["x"]), 1.6, LANE_SPEAR + float(t["z"]) - 11.0)), "R": float(t["r"]), "mult": int(t["mult"])})
	_build_viewmodel()
	phase = "intro"
	_t_phase = 1.6
	var title: String = {"gun": "LUFTGEWEHR", "axe": "AXT-ZIELWERFEN", "spear": "SPEERWURF"}[m]
	var subt: String = {"gun": "20 Schuss in 60 Sekunden", "axe": "5 Würfe · Kraft-Balken im grünen Bereich loslassen", "spear": "5 Würfe · Ziele: x1, x2, x3"}[m]
	pl.get_minihud().card(title, subt, Color(0.95, 0.8, 0.3), 1.6)
	Sfx.play("pop", Vector3.INF, -3.0, 0.9)
	_push_hud()


func exit_game(silent: bool = false) -> void:
	if mode == "":
		return
	if pl != null and is_instance_valid(pl):
		pl.minigame = null
		pl.third_person = _saved_third
		pl._apply_view()
		var mh := pl.get_minihud()
		if mh != null:
			mh.kind = ""
			mh.queue_redraw()
		if not silent:
			pl.toast("Spiel beendet.", 1.5)
	if _vm != null and is_instance_valid(_vm):
		_vm.queue_free()
	_vm = null
	_clear_preview()
	_clear_projectiles()
	mode = ""
	phase = ""
	charging = false
	pl = null


func _finish() -> void:
	phase = "result"
	_end_t = 5.0
	charging = false
	_clear_preview()
	var best: int = int(bests.get(mode, 0))
	var rec := score > best
	if rec:
		bests[mode] = score
		best_names[mode] = Game.player_name
		_update_board(mode)
	var gold: int = {"gun": 300, "axe": 260, "spear": 330}[mode]
	var silver: int = {"gun": 180, "axe": 140, "spear": 180}[mode]
	var bronze: int = {"gun": 80, "axe": 60, "spear": 70}[mode]
	var rating := "Übung macht den Meister"
	var col := Color(0.8, 0.8, 0.75)
	if score >= gold:
		rating = "GOLD - Meisterschütze!" if mode == "gun" else "GOLD - Meisterwerfer!"
		col = Color(1.0, 0.85, 0.25)
	elif score >= silver:
		rating = "SILBER - stark!"
		col = Color(0.85, 0.88, 0.95)
	elif score >= bronze:
		rating = "BRONZE - ordentlich"
		col = Color(0.85, 0.55, 0.3)
	var mh := pl.get_minihud()
	mh.card("%d PUNKTE" % score, rating + ("  ·  NEUER REKORD!" if rec else ""), col, 4.5)
	mh.burst(Vector2(mh.size.x / 2.0, mh.size.y * 0.3), col, 30, 380.0)
	Sfx.play("pop", Vector3.INF, -2.0, 1.3)
	Sfx.play("chirp", Vector3.INF, -6.0, 1.6)
	_push_hud()


func _push_hud() -> void:
	if pl == null or not is_instance_valid(pl):
		return
	var mh := pl.get_minihud()
	mh.kind = "range"
	var info := ""
	match mode:
		"gun":
			info = "Schuss %d / %d  ·  %d s" % [GUN_SHOTS - shots_left, GUN_SHOTS, int(ceil(time_left))]
		"axe", "spear":
			var total := AXE_THROWS if mode == "axe" else SP_THROWS
			info = "Wurf %d / %d" % [mini(total - shots_left + (0 if phase == "result" else 1), total), total]
	mh.d = {"mode": mode, "phase": phase, "score": score, "info": info, "best": int(bests.get(mode, 0)),
		"power": power if (charging and (mode == "axe" or mode == "spear")) else -1.0, "zone": _zone,
		"hint": "Linksklick: schießen   ·   E: beenden" if mode == "gun" else "Maustaste halten und loslassen   ·   E: beenden"}


# ---------------------------------------------------------------------------
# Eingabe
# ---------------------------------------------------------------------------

func handle_input(event: InputEvent) -> bool:
	if mode == "" or pl == null:
		return false
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if not Game.is_captured():
			return false     # erster Klick fängt nur die Maus ein
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mode == "gun":
				if mb.pressed:
					_fire()
			elif phase == "play" and not _busy and shots_left > 0:
				if mb.pressed:
					charging = true
					power = 0.0
					_power_dir = 1.0
				elif charging:
					_release()
		return true
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		match (event as InputEventKey).keycode:
			KEY_E:
				exit_game()
				return true
			KEY_G, KEY_R, KEY_F, KEY_H, KEY_Q, KEY_X, KEY_L, KEY_V:
				return true
	return false


# ---------------------------------------------------------------------------
# Viewmodel (Waffe vor der Kamera)
# ---------------------------------------------------------------------------

func _build_viewmodel() -> void:
	if _vm != null and is_instance_valid(_vm):
		_vm.queue_free()
	_vm = Node3D.new()
	pl.camera.add_child(_vm)
	match mode:
		"gun":
			_vm.position = Vector3(0.2, -0.2, -0.45)
			_vm.scale = Vector3.ONE * 0.75
			ItemModels.add_visual(_vm, "Luftgewehr", Vector3(0.12, 0.16, 0.95), Color(0.3, 0.3, 0.33))
		"axe":
			_vm.position = Vector3(0.3, -0.02, -0.75)
			_vm.rotation_degrees.y = -90.0
			_vm.scale = Vector3.ONE * 0.6
			_axe_model(_vm)
		"spear":
			_vm.position = Vector3(0.22, -0.2, -0.55)
			_vm.rotation_degrees.x = 4.0
			_spear_model(_vm)
	_vm_base = _vm.position


# ---------------------------------------------------------------------------
# Luftgewehr
# ---------------------------------------------------------------------------

func _reset_gun_target(tg: Dictionary) -> void:
	var n: Node3D = tg["node"]
	n.position = tg["home"]
	n.visible = true
	n.rotation = Vector3.ZERO
	n.scale = Vector3.ONE
	tg["up"] = true
	tg["off_t"] = 0.0
	if tg.has("pivot"):
		(tg["pivot"] as Node3D).rotation = Vector3.ZERO


func _fire() -> void:
	if phase != "play" or _gun_cd > 0.0 or shots_left <= 0:
		return
	_gun_cd = 0.28
	shots_left -= 1
	var cb := pl.camera.global_transform.basis
	var origin := pl.camera.global_position
	var dir := (-cb.z + cb.x * randf_range(-0.0025, 0.0025) + cb.y * randf_range(-0.0025, 0.0025)).normalized()
	var best_t := 40.0
	var best_tg: Dictionary = {}
	for tg in gun_targets:
		if not bool(tg["up"]):
			continue
		var n: Node3D = tg["node"]
		var c := n.global_position + Vector3(0, 0.1 if tg["kind"] == "can" else 0.0, 0.0)
		var t := (c - origin).dot(dir)
		if t > 0.5 and t < best_t and (origin + dir * t).distance_to(c) < float(tg["r"]):
			best_t = t
			best_tg = tg
	# Rückwand-Ebene
	var wall_x := to_global(Vector3(-1.8, 0, 0)).x
	var tw := best_t
	if best_tg.is_empty() and dir.x < -0.01:
		tw = (wall_x - origin.x) / dir.x
		if tw < 0.5 or tw > 40.0:
			tw = 40.0
	var end := origin + dir * (best_t if not best_tg.is_empty() else tw)
	var muzzle := origin + dir * 0.7 + cb.x * 0.14 - cb.y * 0.14
	Sfx.play("airgun", muzzle, 0.0)
	Fx.tracer(main, muzzle, end)
	pl.pitch = clampf(pl.pitch + 0.02, -1.45, 1.45)
	pl.head.rotation.x = pl.pitch
	if _vm != null:
		_vm.position = _vm_base + Vector3(0, 0.01, 0.08)
		create_tween().tween_property(_vm, "position", _vm_base, 0.18)
	if not best_tg.is_empty():
		var pts: int = int(best_tg["pts"])
		var kind: String = best_tg["kind"]
		var n2: Node3D = best_tg["node"]
		if kind == "disc":
			var d := (end - n2.global_position).length()
			pts = 50 if d < 0.1 else 30
		score += pts
		_popup(end, "+%d" % pts, Color(1, 0.9, 0.3) if pts < 50 else Color(1, 0.4, 0.2))
		Sfx.play("thunk", end, 0.0, 1.5 if kind != "can" else 1.2)
		_knock(best_tg)
	else:
		Sfx.play("click", end, -8.0, 1.8)
	if shots_left <= 0:
		_end_t = 0.9
	_push_hud()


func _knock(tg: Dictionary) -> void:
	var n: Node3D = tg["node"]
	tg["up"] = false
	tg["off_t"] = 2.6
	match tg["kind"]:
		"can":
			var tw := n.create_tween()
			tw.tween_property(n, "position", (tg["home"] as Vector3) + Vector3(-0.7, -0.3, randf_range(-0.5, 0.5)), 0.35)
			tw.parallel().tween_property(n, "rotation_degrees:x", 90.0 * (1.0 if randf() < 0.5 else -1.0), 0.35)
			tw.tween_callback(func() -> void: n.visible = false)
		"duck":
			var pv: Node3D = tg["pivot"]
			create_tween().tween_property(pv, "rotation_degrees:x", 100.0, 0.18)
		"disc":
			var tw2 := n.create_tween()
			tw2.tween_property(n, "scale", Vector3(1, 0.1, 1), 0.12)


func _popup(pos: Vector3, text: String, col: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 64
	l.pixel_size = 0.004
	l.modulate = col
	l.outline_size = 10
	l.outline_modulate = Color(0, 0, 0, 0.9)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	main.add_child(l)
	l.global_position = pos + Vector3(0.4, 0.2, 0)
	var tw := l.create_tween()
	tw.tween_property(l, "global_position:y", pos.y + 1.1, 0.9)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.3)
	tw.tween_callback(l.queue_free)


# ---------------------------------------------------------------------------
# Würfe (Axt, Speer)
# ---------------------------------------------------------------------------

func _throw_dir() -> Vector3:
	return -pl.camera.global_transform.basis.z


func _throw_origin() -> Vector3:
	var cb := pl.camera.global_transform.basis
	return pl.camera.global_position + (-cb.z) * 0.45 + cb.x * 0.12 - cb.y * 0.08


func _speed(p: float) -> float:
	return lerpf(AXE_V0, AXE_V1, p) if mode == "axe" else lerpf(SP_V0, SP_V1, p)


func _grav() -> float:
	return AXE_G if mode == "axe" else SP_G


## Flug bis zur Brettebene simulieren: {"t": Flugzeit, "reached": bool, "pts": Array[Vector3]}
func _sim(origin: Vector3, dir: Vector3, v: float, want_pts: bool) -> Dictionary:
	var pos := origin
	var vel := dir * v
	var g := _grav()
	var t := 0.0
	var plane_x: float = _plane_targets[0]["x"]
	var pts: Array = []
	var reached := false
	var dt := 0.02
	for i in range(160):
		if want_pts and i % 2 == 0:
			pts.append(pos)
		vel.y -= g * dt
		var np := pos + vel * dt
		t += dt
		if mode == "spear":
			# bis zum fernsten Ziel verfolgen
			if np.y <= 0.03:
				break
			if np.x <= (_plane_targets[_plane_targets.size() - 1]["x"] as float):
				reached = true
				pos = np
				break
		else:
			if np.y <= 0.03:
				break
			if np.x <= plane_x and pos.x > plane_x:
				reached = true
				pos = np
				break
		pos = np
	if want_pts:
		pts.append(pos)
	return {"t": t, "reached": reached, "pts": pts}


func _stick_ok(t: float) -> bool:
	return fposmod(AXE_W * t + 0.7, TAU) < 1.4


func _update_zone(origin: Vector3, dir: Vector3) -> void:
	_zone = []
	if mode != "axe":
		return
	var start := -1.0
	for i in range(0, 51):
		var p := float(i) / 50.0
		var s := _sim(origin, dir, _speed(p), false)
		var ok: bool = bool(s["reached"]) and _stick_ok(float(s["t"]))
		if ok and start < 0.0:
			start = p
		if (not ok or i == 50) and start >= 0.0:
			_zone.append([start, p if not ok else 1.0])
			start = -1.0


func _draw_preview(pts: Array, good: bool) -> void:
	if _preview == null:
		_preview = Node3D.new()
		main.add_child(_preview)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.no_depth_test = true
		m.albedo_color = Color.WHITE
		m.vertex_color_use_as_albedo = false
		for i in range(26):
			var dot := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.03
			sm.height = 0.06
			sm.radial_segments = 6
			sm.rings = 3
			dot.mesh = sm
			dot.material_override = m.duplicate()
			dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_preview.add_child(dot)
	var col := Color(0.4, 1.0, 0.45) if good else Color(1.0, 0.45, 0.35)
	if mode == "spear":
		col = Color(1, 1, 1)
	var n := _preview.get_child_count()
	for i in range(n):
		var dot := _preview.get_child(i) as MeshInstance3D
		if pts.size() < 2:
			dot.visible = false
			continue
		var f := float(i) / float(n - 1)
		var idx := int(f * float(pts.size() - 1))
		dot.visible = i > 1
		dot.global_position = pts[idx] as Vector3
		(dot.material_override as StandardMaterial3D).albedo_color = col


func _clear_preview() -> void:
	if _preview != null and is_instance_valid(_preview):
		_preview.queue_free()
	_preview = null


func _release() -> void:
	charging = false
	_clear_preview()
	if shots_left <= 0 or _busy:
		return
	shots_left -= 1
	_busy = true
	var origin := _throw_origin()
	var dir := _throw_dir()
	var v := _speed(power)
	var node := Node3D.new()
	main.add_child(node)
	node.global_position = origin
	if mode == "axe":
		_axe_model(node)
	else:
		_spear_model(node)
	var s := _sim(origin, dir, v, false)
	_proj.append({"node": node, "pos": origin, "vel": dir * v, "t": 0.0, "bounce": false, "ft": float(s["t"])})
	if _vm != null:
		_vm.visible = false
	Sfx.play("airgun", origin, -6.0, 0.5)
	_push_hud()


func _physics_process(delta: float) -> void:
	_gun_cd = maxf(_gun_cd - delta, 0.0)
	_animate_targets(delta)
	if mode == "":
		return
	if pl == null or not is_instance_valid(pl) or pl.global_position.distance_to(_stand_pos) > 3.5:
		exit_game(true)
		return
	_t_phase -= delta
	match phase:
		"intro":
			if _t_phase <= 0.0:
				phase = "play"
				_push_hud()
		"play":
			if mode == "gun":
				time_left -= delta
				if shots_left <= 0:
					_end_t -= delta
				if time_left <= 0.0 or (shots_left <= 0 and _end_t <= 0.0):
					time_left = maxf(time_left, 0.0)
					_finish()
			else:
				_update_throw(delta)
			_push_hud_light()
		"result":
			_end_t -= delta
			if _end_t <= 0.0:
				exit_game(true)


var _hud_cd: float = 0.0


func _push_hud_light() -> void:
	_hud_cd -= get_physics_process_delta_time()
	if _hud_cd <= 0.0:
		_hud_cd = 0.05
		_push_hud()


func _update_throw(delta: float) -> void:
	# Projektile fliegen lassen
	for p in _proj.duplicate():
		_step_proj(p, delta)
	# Aufladen
	if charging:
		power += _power_dir * delta * 1.35
		if power >= 1.0:
			power = 1.0
			_power_dir = -1.0
		elif power <= 0.0:
			power = 0.0
			_power_dir = 1.0
		var origin := _throw_origin()
		var dir := _throw_dir()
		_update_zone(origin, dir)
		var s := _sim(origin, dir, _speed(power), true)
		_draw_preview(s["pts"], mode == "spear" or (bool(s["reached"]) and _stick_ok(float(s["t"]))))
		if _vm != null and _vm.visible:
			_vm.position = _vm_base + Vector3(0.0, 0.02, 0.1 * power)
	elif _vm != null and _vm.visible:
		_vm.position = _vm_base
	if not _busy and shots_left <= 0 and _proj.is_empty() and phase == "play":
		_finish()


func _step_proj(p: Dictionary, delta: float) -> void:
	var node: Node3D = p["node"]
	if not is_instance_valid(node):
		_proj.erase(p)
		return
	var dt := minf(delta, 0.03)
	var steps := 2
	for k in range(steps):
		var h := dt / float(steps)
		var pos: Vector3 = p["pos"]
		var vel: Vector3 = p["vel"]
		vel.y -= _grav() * h
		var np := pos + vel * h
		p["t"] = float(p["t"]) + h
		var bouncing: bool = p["bounce"]
		if not bouncing:
			for tg in _plane_targets:
				var tx: float = tg["x"]
				if pos.x > tx and np.x <= tx:
					var f := (pos.x - tx) / maxf(pos.x - np.x, 0.0001)
					var hp := pos.lerp(np, f)
					var c: Vector3 = tg["c"]
					var d := Vector2(hp.y - c.y, hp.z - c.z).length()
					if d <= float(tg["R"]):
						_hit_target(p, hp, d, tg)
						return
		var back_x := to_global(Vector3(AXE_BACK_X if mode == "axe" else SP_BACK_X, 0, 0)).x
		if not bouncing and np.x <= back_x:
			_land(p, Vector3(back_x, np.y, np.z), "Fehlwurf", false)
			return
		if np.y <= 0.04:
			if bouncing:
				_land(p, Vector3(np.x, 0.04, np.z), "", true)
			else:
				var first_x: float = _plane_targets[0]["x"]
				_land(p, Vector3(np.x, 0.04, np.z), "Zu kurz!" if np.x > first_x else "Daneben", false)
			return
		p["pos"] = np
		p["vel"] = vel
		node.global_position = np
		if mode == "axe":
			node.rotation = Vector3(0, 0, AXE_W * float(p["t"]) * (1.0 if not bouncing else 0.5))
		else:
			if vel.length() > 0.1:
				node.look_at(np + vel, Vector3.UP)


func _ring_pts(d: float, r: float) -> int:
	var rel := d / r
	for ring in _target_rings():
		if rel <= float(ring[0]):
			return int(ring[1])
	return 10


func _hit_target(p: Dictionary, hp: Vector3, d: float, tg: Dictionary) -> void:
	var node: Node3D = p["node"]
	var mult: int = tg["mult"]
	if mode == "axe":
		var ok := _stick_ok(float(p["t"]))
		if not ok:
			# Axt prallt ab
			p["bounce"] = true
			p["pos"] = hp + Vector3(0.12, 0, 0)
			p["vel"] = Vector3(randf_range(1.5, 2.5), randf_range(1.0, 2.0), randf_range(-1.0, 1.0))
			node.global_position = p["pos"]
			Sfx.play("thunk", hp, 2.0, 0.6)
			pl.get_minihud().card("ABGEPRALLT!", "Die Schneide steckt nicht", Color(1.0, 0.45, 0.35), 1.2)
			_after_throw(0)
			return
		var pts := _ring_pts(d, float(tg["R"]))
		node.global_position = hp
		node.rotation = Vector3(0, 0, randf_range(-0.12, 0.12))
		_stuck["axe"].append(node)
		_proj.erase(p)
		Sfx.play("thunk", hp, 3.0, 0.7)
		Sfx.play("crate", hp, -6.0, 1.3)
		_popup(hp, "+%d" % pts, Color(1.0, 0.85, 0.3) if pts < 100 else Color(1.0, 0.4, 0.2))
		_score_card(pts)
		_after_throw(pts)
		return
	# Speer
	var pts2 := _ring_pts(d, float(tg["R"])) * mult
	var vel2: Vector3 = p["vel"]
	node.global_position = hp
	node.look_at(hp + vel2, Vector3.UP)
	node.rotate_object_local(Vector3(0, 0, 1), randf_range(0, TAU))
	_stuck["spear"].append(node)
	_proj.erase(p)
	Sfx.play("thunk", hp, 3.0, 0.6)
	_popup(hp, "+%d" % pts2, Color(1.0, 0.85, 0.3) if pts2 < 100 else Color(1.0, 0.4, 0.2))
	_score_card(pts2)
	_after_throw(pts2)


func _score_card(pts: int) -> void:
	var mh := pl.get_minihud()
	var txt := "TREFFER! +%d" % pts
	var col := Color(1.0, 0.85, 0.3)
	if pts >= 100:
		txt = "VOLLTREFFER! +%d" % pts
		col = Color(1.0, 0.4, 0.2)
	mh.card(txt, "", col, 1.1)
	mh.burst(Vector2(mh.size.x / 2.0, mh.size.y * 0.3), col, 18, 280.0)


func _land(p: Dictionary, at: Vector3, msg: String, was_bounce: bool) -> void:
	var node: Node3D = p["node"]
	node.global_position = at
	if was_bounce:
		node.rotation = Vector3(0, 0, PI / 2.0)
	elif mode == "spear":
		node.global_position.y = maxf(at.y, 0.1)
	_stuck[mode].append(node)
	_proj.erase(p)
	Sfx.play("thunk", at, -2.0, 0.5)
	if not was_bounce:
		pl.get_minihud().card(msg, "0 Punkte", Color(0.9, 0.5, 0.4), 1.0)
		_after_throw(0)


func _after_throw(pts: int) -> void:
	score += pts
	_busy = false
	# Nach einer kleinen Pause liegt die nächste Waffe wieder in der Hand
	var weak: WeakRef = weakref(self)
	get_tree().create_timer(0.9).timeout.connect(func() -> void:
		var o: Object = weak.get_ref()
		if o != null and (o as ShootingRange).mode != "" and (o as ShootingRange)._vm != null:
			var me: ShootingRange = o as ShootingRange
			if me.shots_left > 0:
				me._vm.visible = true)
	_push_hud()


func _clear_projectiles() -> void:
	for p in _proj:
		var n: Node = p["node"]
		if is_instance_valid(n):
			n.queue_free()
	_proj.clear()


func _clear_stuck(m: String) -> void:
	for n in _stuck[m]:
		if is_instance_valid(n):
			(n as Node).queue_free()
	_stuck[m] = []


# ---------------------------------------------------------------------------
# Ziele bewegen (Luftgewehr-Bude läuft immer, auch ohne Spiel)
# ---------------------------------------------------------------------------

var _anim_t: float = 0.0


func _animate_targets(delta: float) -> void:
	_anim_t += delta
	var lane := LANE_GUN
	for tg in gun_targets:
		var n: Node3D = tg["node"]
		if not is_instance_valid(n):
			continue
		var kind: String = tg["kind"]
		if not bool(tg["up"]):
			tg["off_t"] = float(tg["off_t"]) - delta
			if float(tg["off_t"]) <= 0.0:
				_reset_gun_target(tg)
			continue
		match kind:
			"duck":
				var dir: float = tg["dir"]
				var sp: float = tg["speed"]
				n.position.z += dir * sp * delta
				if n.position.z > lane + 4.0:
					tg["dir"] = -1.0
				elif n.position.z < lane - 4.0:
					tg["dir"] = 1.0
			"disc":
				n.position.y = 2.5 + sin(_anim_t * 1.4 + float(tg["phase"])) * 0.35
