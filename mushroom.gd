class_name Mushroom
extends StaticBody3D
## Pilze und Beeren zum Sammeln. Rote Pilze sind giftig, braune sind lecker. Beeren sind harmlos.

var kind: String = "gut"    # "gut", "gift", "beere"


func build(p_kind: String) -> void:
	kind = p_kind
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.5, 0.4, 0.5)
	cs.shape = bs
	cs.position.y = 0.2
	add_child(cs)
	match kind:
		"gut":
			for i in range(3):
				var o := Vector3(randf_range(-0.2, 0.2), 0, randf_range(-0.2, 0.2))
				var h := randf_range(0.14, 0.24)
				Util.add_cylinder(self, 0.03, h, Color(0.9, 0.85, 0.7), o + Vector3(0, h / 2.0, 0))
				Util.add_sphere(self, 0.09, Color(0.5, 0.32, 0.16), o + Vector3(0, h, 0)).scale = Vector3(1, 0.55, 1)
		"gift":
			for i in range(3):
				var o2 := Vector3(randf_range(-0.2, 0.2), 0, randf_range(-0.2, 0.2))
				var h2 := randf_range(0.12, 0.2)
				Util.add_cylinder(self, 0.025, h2, Color(0.95, 0.95, 0.9), o2 + Vector3(0, h2 / 2.0, 0))
				var cap := Util.add_sphere(self, 0.095, Color(0.85, 0.12, 0.1), o2 + Vector3(0, h2, 0))
				cap.scale = Vector3(1, 0.55, 1)
				Util.add_sphere(self, 0.02, Color(1, 1, 1), o2 + Vector3(0.03, h2 + 0.045, 0.02))
				Util.add_sphere(self, 0.02, Color(1, 1, 1), o2 + Vector3(-0.04, h2 + 0.03, -0.03))
		"apfel":
			for i in range(2):
				var ao := Vector3(randf_range(-0.12, 0.12), 0, randf_range(-0.12, 0.12))
				Util.add_sphere(self, 0.075, Color(0.78, 0.12, 0.1) if i == 0 else Color(0.55, 0.7, 0.15), ao + Vector3(0, 0.07, 0))
				Util.add_cylinder(self, 0.006, 0.05, Color(0.3, 0.2, 0.1), ao + Vector3(0, 0.15, 0))
		"beere":
			Util.add_sphere(self, 0.28, Color(0.15, 0.4, 0.18), Vector3(0, 0.22, 0)).scale = Vector3(1, 0.7, 1)
			for i in range(9):
				Util.add_sphere(self, 0.035, Color(0.2, 0.2, 0.6), Vector3(randf_range(-0.2, 0.2), randf_range(0.2, 0.4), randf_range(-0.2, 0.2)))


func get_prompt() -> String:
	match kind:
		"gut":
			return "E: Pilz essen (brauner Steinpilz)"
		"gift":
			return "E: Pilz essen (ein roter Pilz... mutig?)"
		"apfel":
			return "E: Apfel essen"
		_:
			return "E: Beeren pflücken und essen"


func interact(player: Node) -> void:
	var n := player.get_node_or_null("Needs") as Needs
	Sfx.play("crunch", Vector3.INF, -4.0)
	match kind:
		"gut":
			if n != null:
				n.eat(0.12)
			player.toast("Lecker, ein Steinpilz.", 2.5)
		"apfel":
			if n != null:
				n.eat(0.10)
			player.toast("Knackiger Apfel!", 2.5)
		"beere":
			if n != null:
				n.eat(0.08)
			player.toast("Süße Waldbeeren!", 2.5)
		"gift":
			if n != null:
				n.damage(14.0, "Der rote Pilz war giftig!")
				n.bowel = minf(n.bowel + 0.5, 1.0)
			player.promille += 1.0
			player.toast("Bäh! Das war ein Giftpilz. Alles dreht sich, und dein Magen rumort...", 6.0)
	queue_free()
