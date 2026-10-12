class_name Hammock
extends StaticBody3D
## Hängematte zwischen zwei Bäumen. E = reinlegen und ausruhen (Gesundheit regeneriert), X = abbauen.

var a: HammockTree
var b: HammockTree
var occupant: Node = null
var mid: Vector3 = Vector3.ZERO
var _sway: float = 0.0
var cloth: MeshInstance3D


func build(t1: HammockTree, t2: HammockTree) -> void:
	a = t1
	b = t2
	collision_layer = 2
	collision_mask = 0
	var pa := t1.global_position + Vector3(0, 1.55, 0)
	var pb := t2.global_position + Vector3(0, 1.55, 0)
	mid = (pa + pb) / 2.0
	var span := pb - pa
	var length := Vector3(span.x, 0, span.z).length()
	global_position = Vector3(mid.x, 0, mid.z)
	rotation.y = atan2(-span.z, span.x)   # lokale X-Achse zeigt von a nach b
	var half := length / 2.0
	var sag := 0.6
	var width := 0.55

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 12
	for i in range(n):
		var x0 := -half + length * float(i) / n
		var x1 := -half + length * float(i + 1) / n
		var y0 := 1.55 - sag * (1.0 - pow(x0 / half, 2.0))
		var y1 := 1.55 - sag * (1.0 - pow(x1 / half, 2.0))
		var col := Color(0.85, 0.3, 0.25) if i % 2 == 0 else Color(0.95, 0.85, 0.7)
		st.set_color(col)
		for v in [Vector3(x0, y0, -width), Vector3(x1, y1, -width), Vector3(x1, y1, width),
				Vector3(x0, y0, -width), Vector3(x1, y1, width), Vector3(x0, y0, width)]:
			st.add_vertex(v)
	st.generate_normals()
	cloth = MeshInstance3D.new()
	cloth.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 1.0
	cloth.material_override = m
	add_child(cloth)
	# Seile zu den Bäumen
	for sgn in [-1.0, 1.0]:
		Util.add_box(self, Vector3(0.03, 0.03, 0.03), Color(0.3, 0.25, 0.2), Vector3(sgn * half, 1.55, 0))
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(length * 0.8, 0.5, width * 2.0)
	cs.shape = bs
	cs.position = Vector3(0, 1.1, 0)
	add_child(cs)


func get_prompt() -> String:
	if occupant != null:
		return "Die Hängematte ist besetzt"
	return "E: in die Hängematte legen   X: abbauen"


func interact(player: Node) -> void:
	if occupant != null:
		return
	player.lie(self)


func lie_pos() -> Vector3:
	return global_position + Vector3(0, 0.98, 0)


func dismantle(player: Node) -> void:
	if occupant != null:
		return
	if player.held != null:
		player.toast("Hände voll - erst ablegen.", 2.0)
		return
	var it := Item.new().setup("Hängematte", 3.0, Vector3(0.5, 0.3, 0.3), Color(0.8, 0.3, 0.3))
	get_parent().add_child(it)
	it.global_position = global_position + Vector3(0, 1.0, 0)
	player.pick_up(it)
	if a != null:
		a.hammock = null
	if b != null:
		b.hammock = null
	queue_free()


func _process(delta: float) -> void:
	if occupant != null and is_instance_valid(occupant):
		_sway += delta
		var nd = occupant.get("needs")
		if nd != null:
			nd.health = minf(nd.health + 1.5 * delta, 100.0)
		cloth.rotation.x = sin(_sway * 1.1) * 0.03
