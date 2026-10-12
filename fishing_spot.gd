class_name FishingSpot
extends StaticBody3D
## Pflock mit Schild am Steg. Wer ihn anklickt, wählt diesen Angelplatz als Lager.

var spot_name: String = ""
var camp_offset: Vector3 = Vector3(0, 0, 6)


func build(p_name: String) -> void:
	spot_name = p_name
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.3, 1.4, 0.3)
	cs.shape = bs
	cs.position.y = 0.7
	add_child(cs)

	Util.add_cylinder(self, 0.07, 1.4, Color(0.4, 0.26, 0.14), Vector3(0, 0.7, 0))
	Util.add_sphere(self, 0.09, Color(0.95, 0.35, 0.2), Vector3(0, 1.42, 0))


func get_prompt() -> String:
	if Game.camp_claimed:
		if Game.camp_name == spot_name:
			return "%s – hier ist euer Lager" % spot_name
		return "%s (das Lager ist bei %s)" % [spot_name, Game.camp_name]
	return "E: %s als Lager wählen" % spot_name


func interact(player: Node) -> void:
	if Game.camp_claimed:
		return
	claim(player)
	if Net.instance != null:
		Net.instance.send_camp(spot_name)


## Lager hier einrichten (auch von Mitspielern per Netzwerk aufgerufen)
func claim(player: Node) -> void:
	Game.camp_claimed = true
	Game.camp_name = spot_name
	Game.camp_center = global_position + camp_offset

	# Grüner Ring zeigt den Lagerbereich
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = Game.camp_radius - 0.12
	tm.outer_radius = Game.camp_radius
	tm.rings = 48
	tm.ring_segments = 8
	ring.mesh = tm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.45, 1.0, 0.55)
	ring.material_override = m
	get_parent().add_child(ring)
	ring.global_position = Vector3(Game.camp_center.x, 0.05, Game.camp_center.z)

	if player != null and player.has_method("toast"):
		player.toast("Lager bei %s! Zeltpaket in die Hand nehmen und R drücken." % spot_name, 6.0)
