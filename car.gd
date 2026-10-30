class_name Car
extends Node3D
## Ein Auto mit Heckklappe. Beim ersten Öffnen purzelt das Gepäck heraus.
## Das Auto schaut nach -Z, das Heck (mit Kofferraum) zeigt nach +Z.

var car_name: String = ""
var trunk_open: bool = false
var car_length: float = 4.0
var car_width: float = 1.7
var loot: Array = []
var loot_spawned: bool = false
var trunk_pivot: Node3D
var car_index: int = -1


## Unsichtbare Interaktionszone am Heck.
class TrunkButton:
	extends StaticBody3D
	var car: Car

	func get_prompt() -> String:
		return "E: Heckklappe %s (%s)" % ["schließen" if car.trunk_open else "öffnen", car.car_name]

	func interact(_player: Node) -> void:
		car.toggle_trunk()


func build(p_name: String, color: Color, length: float, width: float, p_loot: Array, model: String = "") -> void:
	car_name = p_name
	car_length = length
	car_width = width
	loot = p_loot

	var model_scene := load(model) as PackedScene if model != "" else null
	if model_scene != null:
		var m := model_scene.instantiate()
		add_child(m)
		_lights_off(m)
		trunk_pivot = m.find_child("*Heckklappe*", true, false) as Node3D
		_add_collision(width, length)
	else:
		_build_boxes(color, length, width)
		_add_collision(width, length)

	# Interaktionszone
	var button := TrunkButton.new()
	button.car = self
	var bs := CollisionShape3D.new()
	var bb := BoxShape3D.new()
	bb.size = Vector3(width * 0.9, 0.6, 0.5)
	bs.shape = bb
	button.add_child(bs)
	button.position = Vector3(0, 0.65, length / 2.0 + 0.3)
	add_child(button)



## Scheinwerfer und Rücklichter sind aus (auch nachts): Emission der Lampen-Materialien abschalten.
func _lights_off(root: Node) -> void:
	for n in root.find_children("*", "", true, false):
		if n is Light3D:
			n.queue_free()
		elif n is MeshInstance3D:
			var mi := n as MeshInstance3D
			if mi.mesh == null:
				continue
			for i in range(mi.mesh.get_surface_count()):
				var mat := mi.get_active_material(i) as BaseMaterial3D
				if mat != null and mat.emission_enabled:
					var m2 := mat.duplicate() as BaseMaterial3D
					m2.emission_enabled = false
					mi.set_surface_override_material(i, m2)


func _build_boxes(color: Color, length: float, width: float) -> void:
	Util.add_box(self, Vector3(width, 0.6, length), color, Vector3(0, 0.65, 0))
	Util.add_box(self, Vector3(width * 0.92, 0.5, length * 0.5), Color(0.12, 0.16, 0.2), Vector3(0, 1.2, -length * 0.05))

	# Räder
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var wheel := Util.add_cylinder(self, 0.32, 0.25, Color(0.05, 0.05, 0.05),
				Vector3(sx * width * 0.5, 0.32, sz * length * 0.32))
			wheel.rotation_degrees.z = 90.0

	# Scheinwerfer vorne, Rücklichter hinten, Stoßstange
	for sx in [-1.0, 1.0]:
		Util.add_box(self, Vector3(0.25, 0.12, 0.05), Color(1.0, 0.95, 0.7), Vector3(sx * width * 0.35, 0.75, -length / 2.0))
		Util.add_box(self, Vector3(0.2, 0.1, 0.05), Color(0.8, 0.05, 0.05), Vector3(sx * width * 0.38, 0.8, length / 2.0))
	Util.add_box(self, Vector3(width, 0.2, 0.12), Color(0.15, 0.15, 0.16), Vector3(0, 0.48, length / 2.0 + 0.04))

	# Heckklappe (oben angelenkt, schwingt nach hinten oben)
	trunk_pivot = Node3D.new()
	trunk_pivot.position = Vector3(0, 0.95, length / 2.0)
	add_child(trunk_pivot)
	Util.add_box(trunk_pivot, Vector3(width * 0.92, 0.55, 0.05), color.lightened(0.08), Vector3(0, -0.275, 0))


func _add_collision(width: float, length: float) -> void:
	# Kollision des Autos
	var chassis := StaticBody3D.new()
	add_child(chassis)
	var s1 := CollisionShape3D.new()
	var b1 := BoxShape3D.new()
	b1.size = Vector3(width, 0.6, length)
	s1.shape = b1
	s1.position = Vector3(0, 0.65, 0)
	chassis.add_child(s1)
	var s2 := CollisionShape3D.new()
	var b2 := BoxShape3D.new()
	b2.size = Vector3(width * 0.92, 0.5, length * 0.5)
	s2.shape = b2
	s2.position = Vector3(0, 1.2, -length * 0.05)
	chassis.add_child(s2)


func toggle_trunk() -> void:
	set_trunk(not trunk_open)
	if Net.instance != null:
		Net.instance.send_trunk(car_index, trunk_open)


## Spaet beigetretene Spieler: Das Auto wurde schon ausgeladen, der Kofferraum bleibt leer.
func restore_emptied(open: bool) -> void:
	if not loot_spawned:
		Game.cars_opened += 1
	loot_spawned = true
	trunk_open = open
	if trunk_pivot != null:
		trunk_pivot.rotation_degrees.x = -115.0 if open else 0.0


func set_trunk(open: bool, from_net: bool = false) -> void:
	trunk_open = open
	Sfx.play("trunk_open" if trunk_open else "trunk_close", global_transform * Vector3(0, 1.0, car_length / 2.0), 2.0)
	if trunk_pivot != null:
		var tw := create_tween()
		tw.tween_property(trunk_pivot, "rotation_degrees:x", -115.0 if trunk_open else 0.0, 0.5)
	if trunk_open and not loot_spawned:
		loot_spawned = true
		Game.cars_opened += 1
		if not from_net:
			_spawn_loot()
	if loot_spawned:
		Game.cars_state[car_index] = trunk_open


func _spawn_loot() -> void:
	var count := loot.size()
	for i in range(count):
		await get_tree().create_timer(0.3).timeout
		var d: Dictionary = loot[i]
		var item := Item.new().setup(d["name"], d["weight"], d["size"], d["color"])
		get_parent().add_child(item)
		if d.has("owner"):
			item.set_owner_name(d["owner"])
		if d.has("contents"):
			item.extra["contents"] = (d["contents"] as Array).duplicate(true)
		# In Reihen zu je 4 Teilen hinter dem Heck verteilen
		var row := i / 4
		var in_row := mini(4, count - row * 4)
		var col := i % 4
		var spread := (float(col) - (in_row - 1) / 2.0) * 0.95
		item.global_position = global_transform * Vector3(spread, 1.0, car_length / 2.0 + 1.0 + row * 1.0)
		item.rotation.y = randf_range(-0.4, 0.4)
