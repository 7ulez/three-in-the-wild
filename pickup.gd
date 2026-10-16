class_name Pickup
extends StaticBody3D
## Etwas zum Einsammeln im Wald: "Zunder" (trockenes Gras / Birkenrinde) oder "Ast".

var kind: String = "Zunder"


func build(p_kind: String) -> void:
	kind = p_kind
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	if kind == "Stein":
		bs.size = Vector3(0.4, 0.15, 0.4)
		cs.position.y = 0.07
		var st := Util.add_cylinder(self, 0.14, 0.04, Color(0.55, 0.55, 0.58), Vector3(0, 0.04, 0))
		st.scale = Vector3(1.0, 1.0, 0.8)
	elif kind == "Zunder":
		bs.size = Vector3(0.6, 0.5, 0.6)
		cs.position.y = 0.25
		for i in range(6):
			var a := TAU * float(i) / 6.0
			var tuft := Util.add_cone(self, 0.05, 0.4 + 0.05 * float(i % 3), Color(0.85, 0.72, 0.3).darkened(0.08 * float(i % 2)),
				Vector3(cos(a) * 0.1, 0.2, sin(a) * 0.1))
			tuft.rotation = Vector3(sin(a) * 0.3, 0, -cos(a) * 0.3)
	else:
		bs.size = Vector3(1.0, 0.25, 0.25)
		cs.position.y = 0.12
		var stick := Util.add_cylinder(self, 0.035, 0.9 + randf() * 0.3, Color(0.4, 0.28, 0.16), Vector3(0, 0.05, 0))
		stick.rotation_degrees = Vector3(0, 0, 90)
		var twig := Util.add_cylinder(self, 0.015, 0.3, Color(0.4, 0.28, 0.16), Vector3(0.15, 0.1, 0.05))
		twig.rotation_degrees = Vector3(0, 0, 50)
	cs.shape = bs
	add_child(cs)
	collision_layer = 2    # nur für den Interaktions-Strahl, man bleibt nicht hängen
	collision_mask = 0


func get_prompt() -> String:
	return "E: Flachen Stein einsammeln" if kind == "Stein" else "E: %s einsammeln" % kind


func interact(player: Node) -> void:
	if kind == "Stein":
		player.stones += 1
		player.toast("Flachen Stein eingesammelt (%d). G: auf den See flitschen." % player.stones, 2.5)
	elif kind == "Zunder":
		player.tinder += 1
		player.toast("Zunder eingesammelt (%d). In die Feuerschale legen." % player.tinder, 2.0)
	else:
		player.sticks += 1
		player.toast("Ast eingesammelt (%d)." % player.sticks, 2.0)
	queue_free()
