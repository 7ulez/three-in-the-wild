class_name HammockTree
extends StaticBody3D
## Kräftiger Baum am Camp, an dem man mit seinem Partnerbaum eine Hängematte aufspannen kann.

var partner: HammockTree = null
var hammock: Hammock = null
var camp_index: int = 0


func build(index: int) -> void:
	camp_index = index
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.45
	shape.height = 5.0
	cs.shape = shape
	cs.position.y = 2.5
	add_child(cs)
	Util.add_cylinder(self, 0.4, 5.0, Color(0.42, 0.28, 0.16), Vector3(0, 2.5, 0))
	Util.add_sphere(self, 2.3, Color(0.35, 0.62, 0.22), Vector3(0, 5.6, 0)).scale = Vector3(1, 0.8, 1)
	Util.add_sphere(self, 1.6, Color(0.42, 0.68, 0.25), Vector3(1.0, 6.4, 0.5))
	# Seilhaken
	Util.add_cylinder(self, 0.1, 0.05, Color(0.2, 0.2, 0.2), Vector3(0, 1.5, 0)).scale = Vector3(1.1, 1, 1.1)


func has_hammock() -> bool:
	return hammock != null and is_instance_valid(hammock)


func get_prompt() -> String:
	if has_hammock():
		return "Baum mit Hängematte"
	return "Kräftiger Baum - hier passt eine Hängematte (mit dem Nachbarbaum)"


func get_held_prompt(held: Node) -> String:
	if held.item_name != "Hängematte":
		return ""
	if partner == null:
		return ""
	if has_hammock():
		return "Hier hängt schon eine Hängematte"
	return "E: Hängematte zwischen diesen zwei Bäumen aufspannen"


func interact_with_held(player: Node, held: Node) -> bool:
	if held.item_name != "Hängematte":
		return false
	if partner == null or has_hammock():
		player.toast(get_held_prompt(held), 2.5)
		return true
	if player.global_position.distance_to(partner.global_position) > 14.0:
		player.toast("Der zweite Baum ist zu weit weg.", 2.5)
		return true
	spawn_hammock()
	player.consume_held()
	player.toast("Hängematte aufgespannt! E: reinlegen · X: abbauen", 4.0)
	return true


func spawn_hammock() -> void:
	var h := Hammock.new()
	get_parent().add_child(h)
	h.build(self, partner)
	hammock = h
	partner.hammock = h
