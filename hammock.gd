class_name Hammock
extends StaticBody3D
## Hängematte zwischen zwei Bäumen. E = reinlegen und ausruhen (Gesundheit regeneriert), X = abbauen.

var a: HammockTree
var b: HammockTree
var occupant: Node = null
var mid: Vector3 = Vector3.ZERO
var _sway: float = 0.0
var cloth: Node3D


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

	cloth = Node3D.new()
	add_child(cloth)
	var hm := ItemModels._glb(cloth, "haengematte")
	if hm != null:
		hm.scale = Vector3(length / 3.24, 1.0, 1.0)
	else:
		Util.add_box(cloth, Vector3(length, 0.04, width * 2.0), Color(0.05, 0.05, 0.06), Vector3(0, 0.95, 0))
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
	var it := Item.new().setup("Hängematte", 3.0, Vector3(0.5, 0.3, 0.3), Color(0.05, 0.05, 0.06))
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
