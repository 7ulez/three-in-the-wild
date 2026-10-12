class_name Poop
extends StaticBody3D
## Der Haufen, den man nach dem großen Geschäft hinterlässt. E = vergraben.

var _flies: CPUParticles3D = null


var stepped: bool = false


func _process(_delta: float) -> void:
	if stepped:
		return
	var pl := get_tree().get_first_node_in_group("local_player") as Node3D
	if pl == null:
		return
	if Vector2(pl.global_position.x - global_position.x, pl.global_position.z - global_position.z).length() < 0.4 and pl.global_position.y < global_position.y + 0.6:
		stepped = true
		scale = Vector3(1.5, 0.35, 1.5)
		Sfx.play("plop", global_position, 2.0, 1.3)
		pl.step_in_poop()


func build() -> void:
	collision_layer = 2      # nur anzielbar, man läuft hindurch
	var cs := CollisionShape3D.new()
	var bs := CylinderShape3D.new()
	bs.radius = 0.25
	bs.height = 0.3
	cs.shape = bs
	cs.position.y = 0.15
	add_child(cs)
	var brown := Color(0.36, 0.22, 0.1)
	Util.add_cylinder(self, 0.22, 0.12, brown, Vector3(0, 0.06, 0))
	Util.add_cylinder(self, 0.16, 0.11, brown.lightened(0.05), Vector3(0, 0.17, 0))
	Util.add_cylinder(self, 0.1, 0.1, brown.lightened(0.1), Vector3(0, 0.27, 0))
	Util.add_cone(self, 0.06, 0.12, brown.lightened(0.12), Vector3(0.01, 0.38, 0))
	_flies = CPUParticles3D.new()
	_flies.amount = 6
	_flies.lifetime = 1.4
	_flies.direction = Vector3(0, 1, 0)
	_flies.spread = 180.0
	_flies.initial_velocity_min = 0.3
	_flies.initial_velocity_max = 0.8
	_flies.gravity = Vector3.ZERO
	var m := SphereMesh.new()
	m.radius = 0.012
	m.height = 0.024
	m.radial_segments = 4
	m.rings = 2
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.05, 0.05, 0.05)
	m.material = mat
	_flies.mesh = m
	_flies.position = Vector3(0, 0.5, 0)
	add_child(_flies)


func get_prompt() -> String:
	return "Dein Haufen. Riecht... naturnah.   E: mit dem Fuß Erde drüberscharren"


func interact(player: Node) -> void:
	player.toast("Vergraben. Die Natur sagt danke.", 2.5)
	Sfx.play("step_gravel", global_position)
	queue_free()
