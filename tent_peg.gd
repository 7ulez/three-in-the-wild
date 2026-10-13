class_name TentPeg
extends StaticBody3D
## Hering: Mit dem Hammer in der Hand dreimal E drücken, dann sitzt er.

const HITS_NEEDED: int = 3

var tent: Tent
var hits: int = 0
var visual: Node3D


func build() -> void:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.35, 0.6, 0.35)
	cs.shape = bs
	cs.position.y = 0.25
	add_child(cs)

	visual = Node3D.new()
	visual.position.y = 0.17
	add_child(visual)
	Util.add_cylinder(visual, 0.03, 0.4, Color(0.75, 0.75, 0.78), Vector3.ZERO)
	Util.add_cylinder(visual, 0.06, 0.04, Color(0.75, 0.75, 0.78), Vector3(0, 0.2, 0))


func is_driven() -> bool:
	return hits >= HITS_NEEDED


func get_prompt() -> String:
	if is_driven():
		return "Hering sitzt fest"
	return "Hering (Hammer in die Hand nehmen, dann E)"


func get_held_prompt(held: Item) -> String:
	if is_driven():
		return ""
	if held.item_name == "Hammer":
		return "E: Hering einschlagen (%d/%d)" % [hits, HITS_NEEDED]
	return ""


func interact_with_held(player: Node, held: Item) -> bool:
	if held.item_name != "Hammer":
		return false
	if is_driven():
		return true     # Hammer bleibt in der Hand
	hits += 1
	if player.has_method("swing_hammer"):
		player.swing_hammer()
	var tw := create_tween()
	tw.tween_property(visual, "position:y", 0.17 - 0.1 * hits, 0.12)
	if is_driven() and tent != null:
		tent.peg_driven(player)
	return true
