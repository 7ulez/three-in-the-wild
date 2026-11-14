class_name Kettcar
extends StaticBody3D
## Rotes Tret-Kettcar mitten im Wald. E = aufsteigen, WASD fahren, Shift schneller, E = absteigen.
## Das Fahren selbst steuert der Spieler (player.gd::_drive_kart); das Kettcar folgt ihm nur.
## Nur 4 Objekte: Rahmen, Hinterräder, Vorderachse (lenkt) und Lenkrad - jeweils zu einem Mesh verschmolzen.

const SPOT: Vector3 = Vector3(-92.0, 0.0, 34.0)
const CLEAR_R: float = 6.0

var rider: Node = null
var remote_t: float = 99.0                  # Sekunden seit der letzten Fahrt-Meldung eines Mitspielers
var _front: Node3D
var _front_wheels: Node3D
var _rear: Node3D
var _bar: Node3D
var _spin: float = 0.0
var _steer: float = 0.0
var _target_pos: Vector3 = Vector3.ZERO
var _target_yaw: float = 0.0
var _remote_riding: bool = false


static func in_zone(p: Vector3) -> bool:
	return Vector2(p.x - SPOT.x, p.z - SPOT.z).length() < CLEAR_R


func build() -> void:
	add_to_group("kettcar")
	collision_layer = 2
	collision_mask = 0
	var red := Color(0.78, 0.1, 0.08)
	var dark := Color(0.08, 0.08, 0.09)
	var grey := Color(0.55, 0.56, 0.58)
	var yellow := Color(0.95, 0.78, 0.15)

	# Rahmen: Längsrohr, Heck, Sitzschale, Pedalkurbel
	var st := _begin()
	_box(st, Vector3(0, 0.26, 0.0), Vector3(0.34, 0.06, 1.1), red)
	_box(st, Vector3(0, 0.3, 0.52), Vector3(0.7, 0.06, 0.1), red)
	_box(st, Vector3(0, 0.2, -0.42), Vector3(0.5, 0.05, 0.08), red)
	_box(st, Vector3(0, 0.36, 0.3), Vector3(0.34, 0.07, 0.3), dark)          # Sitz
	_box(st, Vector3(0, 0.56, 0.44), Vector3(0.34, 0.34, 0.07), dark)        # Lehne
	_box(st, Vector3(0, 0.2, 0.52), Vector3(0.06, 0.12, 0.06), grey)         # Hinterachsträger
	_box(st, Vector3(0, 0.36, -0.28), Vector3(0.06, 0.2, 0.06), grey)        # Lenksäule
	_box(st, Vector3(0.2, 0.2, -0.1), Vector3(0.05, 0.05, 0.22), grey)       # Kurbel rechts
	_box(st, Vector3(-0.2, 0.2, -0.1), Vector3(0.05, 0.05, 0.22), grey)      # Kurbel links
	_box(st, Vector3(0.26, 0.2, -0.2), Vector3(0.14, 0.04, 0.08), dark)      # Pedal
	_box(st, Vector3(-0.26, 0.2, 0.0), Vector3(0.14, 0.04, 0.08), dark)
	_box(st, Vector3(0, 0.45, 0.58), Vector3(0.2, 0.05, 0.02), yellow)       # Kennzeichen
	_add_mesh(self, st, Vector3.ZERO)

	# Hinterräder samt Achse (drehen beim Fahren)
	_rear = Node3D.new()
	_rear.position = Vector3(0, 0.19, 0.52)
	add_child(_rear)
	var sr := _begin()
	_cyl(sr, Vector3(-0.32, 0, 0), 0.19, 0.09, dark)
	_cyl(sr, Vector3(0.32, 0, 0), 0.19, 0.09, dark)
	_cyl(sr, Vector3(-0.32, 0, 0), 0.09, 0.11, grey)
	_cyl(sr, Vector3(0.32, 0, 0), 0.09, 0.11, grey)
	_cyl(sr, Vector3.ZERO, 0.025, 0.64, grey)
	_add_mesh(_rear, sr, Vector3.ZERO)

	# Vorderachse (lenkt) mit zwei kleineren Rädern
	_front = Node3D.new()
	_front.position = Vector3(0, 0.15, -0.52)
	add_child(_front)
	_front_wheels = Node3D.new()
	_front.add_child(_front_wheels)
	var sf := _begin()
	_cyl(sf, Vector3(-0.28, 0, 0), 0.15, 0.08, dark)
	_cyl(sf, Vector3(0.28, 0, 0), 0.15, 0.08, dark)
	_cyl(sf, Vector3(-0.28, 0, 0), 0.07, 0.1, grey)
	_cyl(sf, Vector3(0.28, 0, 0), 0.07, 0.1, grey)
	_cyl(sf, Vector3.ZERO, 0.02, 0.56, grey)
	_add_mesh(_front_wheels, sf, Vector3.ZERO)
	var sx := _begin()
	_box(sx, Vector3(0, 0.11, 0.0), Vector3(0.62, 0.04, 0.1), red)           # Achsbrücke
	_add_mesh(_front, sx, Vector3.ZERO)

	# Lenkrad mit gelben Griffen
	_bar = Node3D.new()
	_bar.position = Vector3(0, 0.6, -0.3)
	add_child(_bar)
	var sb := _begin()
	_box(sb, Vector3(0, 0, 0), Vector3(0.46, 0.035, 0.035), grey)
	_box(sb, Vector3(0.25, 0, 0), Vector3(0.1, 0.05, 0.05), yellow)
	_box(sb, Vector3(-0.25, 0, 0), Vector3(0.1, 0.05, 0.05), yellow)
	_box(sb, Vector3(0, -0.14, 0), Vector3(0.04, 0.3, 0.04), grey)
	_add_mesh(_bar, sb, Vector3.ZERO)

	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.9, 0.9, 1.5)
	cs.shape = bs
	cs.position = Vector3(0, 0.45, 0)
	add_child(cs)


func get_prompt() -> String:
	if rider != null or remote_t < 0.8:
		return "Das Kettcar ist besetzt"
	return "E: Kettcar fahren"


func interact(player: Node) -> void:
	if rider != null or remote_t < 0.8:
		return
	player.mount_kart(self)


## Vom fahrenden Spieler jeden Physik-Schritt aufgerufen: Rad- und Lenkungsanimation.
func ride_visual(speed: float, steer: float, delta: float) -> void:
	_steer = lerpf(_steer, steer, minf(delta * 10.0, 1.0))
	_spin += speed * delta / 0.17
	_apply_visual()


func _apply_visual() -> void:
	_front.rotation.y = -_steer * 0.5
	_bar.rotation.y = -_steer * 0.7
	_front_wheels.rotation.x = _spin * 1.1
	_rear.rotation.x = _spin


## Meldung eines Mitspielers: Kettcar folgt dessen Fahrt (oder bleibt dort stehen, wenn er abgestiegen ist).
func remote_pose(pos: Vector3, yaw: float, riding: bool) -> void:
	if rider != null:
		return
	_target_pos = pos
	_target_yaw = yaw
	_remote_riding = riding
	remote_t = 0.0 if riding else 99.0
	if not riding:
		global_position = pos
		rotation.y = yaw


func _process(delta: float) -> void:
	if rider != null:
		return
	remote_t += delta
	if _remote_riding and remote_t < 0.8:
		var k := minf(delta * 12.0, 1.0)
		var old := global_position
		global_position = global_position.lerp(_target_pos, k)
		rotation.y = lerp_angle(rotation.y, _target_yaw, k)
		var mv := (global_position - old).length()
		_spin += mv / 0.17 * (1.0 if mv > 0.0 else 0.0)
		_steer = lerpf(_steer, 0.0, minf(delta * 6.0, 1.0))
		_apply_visual()


# ---------- Mesh-Helfer (Vertexfarben, flach schattiert) ----------

func _begin() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	return st


func _add_mesh(parent: Node3D, st: SurfaceTool, pos: Vector3) -> void:
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.75
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
	# a,b,c,d gegen den Uhrzeigersinn von außen gesehen
	for v in [a, c, b, a, d, c]:
		st.set_color(col)
		st.add_vertex(v)


func _box(st: SurfaceTool, ctr: Vector3, size: Vector3, col: Color) -> void:
	var h := size / 2.0
	var faces := [
		[Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)],
		[Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0)],
		[Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(1, 0, 0)],
		[Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)],
		[Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)],
		[Vector3(0, 0, -1), Vector3(0, 1, 0), Vector3(1, 0, 0)],
	]
	for f in faces:
		var n: Vector3 = f[0]
		var u: Vector3 = f[1]
		var v: Vector3 = f[2]
		var fc := ctr + Vector3(n.x * h.x, n.y * h.y, n.z * h.z)
		var uu := Vector3(u.x * h.x, u.y * h.y, u.z * h.z)
		var vv := Vector3(v.x * h.x, v.y * h.y, v.z * h.z)
		_quad(st, fc - uu - vv, fc + uu - vv, fc + uu + vv, fc - uu + vv, col)


## Zylinder mit der Achse entlang X (Rad); length = Gesamtbreite
func _cyl(st: SurfaceTool, ctr: Vector3, r: float, length: float, col: Color) -> void:
	var segs := 10
	var h := length / 2.0
	for k in range(segs):
		var a0 := TAU * float(k) / segs
		var a1 := TAU * float(k + 1) / segs
		var p0 := Vector3(0, cos(a0) * r, sin(a0) * r)
		var p1 := Vector3(0, cos(a1) * r, sin(a1) * r)
		var hx := Vector3(h, 0, 0)
		_quad(st, ctr + p0 - hx, ctr + p1 - hx, ctr + p1 + hx, ctr + p0 + hx, col)
		# Kappen
		for tri in [[ctr + hx, ctr + hx + p1, ctr + hx + p0], [ctr - hx, ctr - hx + p0, ctr - hx + p1]]:
			for v in tri:
				st.set_color(col)
				st.add_vertex(v)
