class_name Trap
extends StaticBody3D
## Fallen im Wald und in den Verstecken: Bärenfalle, Fallgrube, Steinschlag (Stolperdraht), Wespennest.
## Mit E kann man Bärenfalle, Grube und Stolperdraht entschärfen, wenn man sie rechtzeitig sieht.

var kind: String = "bear"
var armed: bool = true
var _near_t: float = 0.0
var _jaw_l: Node3D = null
var _jaw_r: Node3D = null
var _cover: Node3D = null
var _hole: Node3D = null
var _player: Node3D = null


func build(p_kind: String) -> void:
	kind = p_kind
	collision_layer = 2
	collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	cs.shape = bs
	match kind:
		"bear":
			bs.size = Vector3(0.8, 0.25, 0.8)
			cs.position.y = 0.12
			Util.add_cylinder(self, 0.4, 0.04, Color(0.25, 0.25, 0.27), Vector3(0, 0.02, 0))
			_jaw_l = Node3D.new()
			_jaw_r = Node3D.new()
			_jaw_l.position = Vector3(-0.38, 0.05, 0)
			_jaw_r.position = Vector3(0.38, 0.05, 0)
			add_child(_jaw_l)
			add_child(_jaw_r)
			_jaw_l.rotation_degrees.z = -75.0      # offen
			_jaw_r.rotation_degrees.z = 75.0
			for jaw in [_jaw_l, _jaw_r]:
				var sgn := 1.0 if jaw == _jaw_l else -1.0
				Util.add_box(jaw, Vector3(0.38, 0.04, 0.5), Color(0.35, 0.35, 0.38), Vector3(sgn * 0.19, 0, 0))
				for k in range(5):
					var tooth := Util.add_cone(jaw, 0.025, 0.08, Color(0.6, 0.6, 0.62), Vector3(sgn * 0.36, 0.04, -0.2 + k * 0.1))
			# Laub teilweise darüber (schlecht sichtbar)
			Util.add_cylinder(self, 0.3, 0.015, Color(0.45, 0.32, 0.12), Vector3(0.1, 0.045, 0.15))
		"pit":
			bs.size = Vector3(1.6, 0.1, 1.6)
			cs.position.y = 0.04
			_hole = Util.add_cylinder(self, 0.9, 0.02, Color(0.02, 0.02, 0.02), Vector3(0, 0.01, 0))
			_hole.visible = false
			_cover = Node3D.new()
			add_child(_cover)
			Util.add_cylinder(_cover, 0.95, 0.04, Color(0.42, 0.3, 0.14), Vector3(0, 0.03, 0))
			for k in range(7):
				Util.add_box(_cover, Vector3(0.05, 0.03, 1.1), Color(0.35, 0.24, 0.1), Vector3(-0.5 + k * 0.17, 0.06, 0))
			Util.add_sphere(_cover, 0.2, Color(0.5, 0.4, 0.15), Vector3(0.3, 0.07, 0.2)).scale = Vector3(1, 0.2, 1)
		"rocks":
			bs.size = Vector3(3.0, 0.2, 0.2)
			cs.position.y = 0.2
			Util.add_box(self, Vector3(3.0, 0.015, 0.015), Color(0.7, 0.65, 0.55), Vector3(0, 0.2, 0))
			Util.add_cylinder(self, 0.04, 0.5, Color(0.4, 0.3, 0.2), Vector3(-1.5, 0.25, 0))
			Util.add_cylinder(self, 0.04, 0.5, Color(0.4, 0.3, 0.2), Vector3(1.5, 0.25, 0))
		"wasp":
			bs.size = Vector3(0.7, 0.8, 0.7)
			cs.position.y = 2.0
			Util.add_sphere(self, 0.35, Color(0.72, 0.62, 0.42), Vector3(0, 2.0, 0)).scale = Vector3(1, 1.3, 1)
			Util.add_cylinder(self, 0.04, 0.5, Color(0.4, 0.3, 0.2), Vector3(0, 2.6, 0))
			Util.add_sphere(self, 0.05, Color(0.1, 0.1, 0.1), Vector3(0.1, 1.75, 0.3))
	add_child(cs)


func get_prompt() -> String:
	if not armed:
		return ""
	match kind:
		"bear":
			return "Eine Bärenfalle!   E: entschärfen"
		"pit":
			return "Morsche Äste über einem Loch...   E: Abdeckung wegziehen"
		"rocks":
			return "Ein dünner Draht - Stolperdraht!   E: durchschneiden"
		"wasp":
			return "Ein Wespennest! Lieber Abstand halten."
	return ""


func interact(player: Node) -> void:
	if not armed:
		return
	match kind:
		"bear", "pit", "rocks":
			armed = false
			Sfx.play("click", global_position)
			player.toast("Entschärft. Gut gesehen!", 2.5)
			if kind == "pit":
				_cover.visible = false
				_hole.visible = true
				collision_layer = 0
			elif kind == "bear":
				_jaw_l.rotation_degrees.z = 0.0
				_jaw_r.rotation_degrees.z = 0.0
			else:
				queue_free()
		"wasp":
			player.toast("Sssss... das Summen wird lauter. Weg hier!", 3.0)
			_near_t = 1.2


func _process(delta: float) -> void:
	if not armed and kind != "wasp":
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("local_player") as Node3D
		return
	var pp := _player.global_position
	var flat := Vector2(pp.x - global_position.x, pp.z - global_position.z)
	match kind:
		"bear":
			if flat.length() < 0.7 and pp.y < 1.0:
				_trigger_bear()
		"pit":
			if flat.length() < 0.8 and pp.y < 1.0:
				_trigger_pit()
		"rocks":
			# Draht liegt quer in lokaler X-Richtung, Spieler muss ihn kreuzen
			var local := global_transform.affine_inverse() * pp
			if absf(local.z) < 0.25 and absf(local.x) < 1.5 and pp.y < 1.2:
				_trigger_rocks()
		"wasp":
			var d := Vector2(pp.x - global_position.x, pp.z - global_position.z).length()
			if d < 3.0:
				_near_t += delta
				if _near_t > 1.6 and armed:
					_trigger_wasps()
			else:
				_near_t = maxf(_near_t - delta, 0.0)


func _trigger_bear() -> void:
	armed = false
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_jaw_l, "rotation_degrees:z", 0.0, 0.08)
	tw.tween_property(_jaw_r, "rotation_degrees:z", 0.0, 0.08)
	Sfx.play("snap", global_position, 4.0)
	_player.trapped_t = 4.0
	_player.trap_head = 1.4
	(_player.needs as Needs).damage(22.0, "Die Bärenfalle hat zugeschnappt!")
	_player.toast("KLACK! Bärenfalle! Dein Bein klemmt fest. E mehrfach drücken zum Befreien!", 6.0)


func _trigger_pit() -> void:
	armed = false
	_cover.visible = false
	_hole.visible = true
	collision_layer = 0
	Sfx.play("rumble", global_position, -6.0, 2.0)
	_player.trapped_t = 3.0
	_player.trap_head = 0.6
	(_player.needs as Needs).damage(9.0, "Du bist in eine Fallgrube gestürzt!")
	_player.toast("Die Äste brechen! Du steckst in einer Fallgrube. E mehrfach drücken: herausklettern!", 6.0)


func _trigger_rocks() -> void:
	armed = false
	Sfx.play("rumble", global_position, 2.0)
	_player.toast("Klick! Der Draht... über dir poltert es!", 3.0)
	var spot := _player.global_position + Vector3(_player.velocity.x, 0, _player.velocity.z) * 0.5
	spot.y = 0.0
	var rocks: Array = []
	for i in range(6):
		var r := Util.add_sphere(get_parent(), randf_range(0.2, 0.5), Color(0.45, 0.43, 0.4), spot + Vector3(randf_range(-1.0, 1.0), 7.0 + i, randf_range(-1.0, 1.0)))
		rocks.append(r)
		var end := Vector3(r.position.x, 0.2, r.position.z)
		create_tween().tween_property(r, "position", end, 0.8 + i * 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	get_tree().create_timer(0.85).timeout.connect(func() -> void:
		Sfx.play("thunk", spot, 4.0)
		if is_instance_valid(_player) and Vector2(_player.global_position.x - spot.x, _player.global_position.z - spot.z).length() < 2.0:
			(_player.needs as Needs).damage(24.0, "Ein Steinschlag hat dich erwischt!")
		else:
			_player.toast("Puh, rechtzeitig weg!", 2.0))
	get_tree().create_timer(25.0).timeout.connect(func() -> void:
		for r in rocks:
			if is_instance_valid(r):
				(r as Node).queue_free()
		queue_free())
	visible = false
	collision_layer = 0


var _wasp_left: float = 0.0
var _wasp_fx: CPUParticles3D = null


func _trigger_wasps() -> void:
	armed = false
	_wasp_left = 6.0
	Sfx.play("buzz", global_position, 4.0)
	_player.toast("Die Wespen greifen an! RENN WEG (Shift)!", 4.0)
	_wasp_fx = CPUParticles3D.new()
	_wasp_fx.amount = 24
	_wasp_fx.lifetime = 0.8
	_wasp_fx.direction = Vector3(0, 0, 0)
	_wasp_fx.spread = 180.0
	_wasp_fx.initial_velocity_min = 0.5
	_wasp_fx.initial_velocity_max = 1.6
	_wasp_fx.gravity = Vector3.ZERO
	var m := SphereMesh.new()
	m.radius = 0.02
	m.height = 0.04
	m.radial_segments = 4
	m.rings = 2
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.9, 0.75, 0.1)
	m.material = mat
	_wasp_fx.mesh = m
	_player.add_child(_wasp_fx)
	_wasp_fx.position = Vector3(0, 1.4, 0)
	_wasp_fx.emitting = true
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if _wasp_left <= 0.0:
		return
	_wasp_left -= delta
	if is_instance_valid(_player):
		var d := Vector2(_player.global_position.x - global_position.x, _player.global_position.z - global_position.z).length()
		if d > 14.0:
			_wasp_left = 0.0
		elif int(_wasp_left * 4.0) != int((_wasp_left + delta) * 4.0):
			(_player.needs as Needs).damage(1.4, "Wespenstiche")
	if _wasp_left <= 0.0:
		if _wasp_fx != null:
			_wasp_fx.queue_free()
		if is_instance_valid(_player):
			_player.toast("Die Wespen lassen von dir ab.", 2.5)
		_near_t = -30.0       # beruhigt sich
		await get_tree().create_timer(40.0).timeout
		armed = true
