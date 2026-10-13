class_name Ambient
extends Node3D
## Leben in der Welt: Laub im Wind, Libellen, Mücken am Ufer und ein leichter Kamera-Look (Vignette).

var player: Player
var main: Node
var leaves: CPUParticles3D
var dragonflies: Array = []
var midges: Array = []
var vig_mat: ShaderMaterial
var _t: float = 0.0
var _focus: float = 0.0
var _hurt: float = 0.0
var _last_health: float = 100.0


func start(p_main: Node, p_player: Player) -> void:
	main = p_main
	player = p_player
	_build_leaves()
	_build_dragonflies()
	_build_midges()
	_build_vignette()


func _build_leaves() -> void:
	leaves = CPUParticles3D.new()
	leaves.amount = 14 if Game.low else 36
	leaves.lifetime = 9.0
	leaves.preprocess = 9.0
	leaves.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	leaves.emission_box_extents = Vector3(16, 0.5, 16)
	leaves.direction = Vector3(1, -0.2, 0.3)
	leaves.spread = 25.0
	leaves.initial_velocity_min = 0.6
	leaves.initial_velocity_max = 1.4
	leaves.gravity = Vector3(0, -0.55, 0)
	leaves.angular_velocity_min = -180.0
	leaves.angular_velocity_max = 180.0
	leaves.angle_max = 360.0
	leaves.color_ramp = null
	var q := QuadMesh.new()
	q.size = Vector2(0.14, 0.1)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.vertex_color_use_as_albedo = true
	q.material = mat
	leaves.mesh = q
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	g.colors = PackedColorArray([Color(0.9, 0.55, 0.15), Color(0.85, 0.7, 0.2), Color(0.7, 0.35, 0.12)])
	leaves.color_initial_ramp = g
	leaves.top_level = true
	add_child(leaves)


func _build_dragonflies() -> void:
	if Game.low:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 91
	for i in 5:
		var d := Node3D.new()
		var body := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.012, 0.012, 0.11)
		body.mesh = bm
		var bmat := StandardMaterial3D.new()
		bmat.albedo_color = Color(0.1, 0.45, 0.8)
		bmat.emission_enabled = true
		bmat.emission = Color(0.05, 0.3, 0.6)
		body.material_override = bmat
		d.add_child(body)
		for s in [-1.0, 1.0]:
			var w := MeshInstance3D.new()
			var wq := QuadMesh.new()
			wq.size = Vector2(0.09, 0.025)
			wq.orientation = PlaneMesh.FACE_Y
			var wm := StandardMaterial3D.new()
			wm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			wm.albedo_color = Color(0.85, 0.95, 1.0, 0.45)
			wm.cull_mode = BaseMaterial3D.CULL_DISABLED
			wq.material = wm
			w.mesh = wq
			w.position = Vector3(s * 0.055, 0.0, -0.02)
			w.set_meta("side", s)
			d.add_child(w)
		d.set_meta("ph", rng.randf() * TAU)
		d.set_meta("sp", rng.randf_range(0.18, 0.32))
		d.set_meta("cx", rng.randf_range(-16.0, 16.0))
		d.set_meta("cz", rng.randf_range(-8.0, 8.0))
		d.top_level = true
		add_child(d)
		dragonflies.append(d)


func _build_midges() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 33
	var n := 2 if Game.low else 4
	for i in n:
		var a := rng.randf() * TAU
		var pos := Vector3(LakeShape.CENTER.x + cos(a) * 29.0, 1.4, LakeShape.CENTER.y + 15.0 + sin(a) * 20.0)
		var p := CPUParticles3D.new()
		p.amount = 18
		p.lifetime = 3.0
		p.preprocess = 3.0
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		p.emission_sphere_radius = 1.0
		p.direction = Vector3.ZERO
		p.spread = 180.0
		p.initial_velocity_min = 0.2
		p.initial_velocity_max = 0.7
		p.gravity = Vector3.ZERO
		p.damping_min = 0.4
		p.damping_max = 0.8
		var sm := SphereMesh.new()
		sm.radius = 0.012
		sm.height = 0.024
		sm.radial_segments = 4
		sm.rings = 2
		var mt := StandardMaterial3D.new()
		mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mt.albedo_color = Color(0.1, 0.1, 0.1)
		sm.material = mt
		p.mesh = sm
		p.emitting = false
		p.position = pos
		add_child(p)
		midges.append(p)


func _build_vignette() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 0
	add_child(layer)
	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vig_mat = ShaderMaterial.new()
	vig_mat.shader = load("res://shaders/vignette.gdshader")
	vig_mat.set_shader_parameter("strength", 0.2 if Game.low else 0.3)
	rect.material = vig_mat
	layer.add_child(rect)


func _process(delta: float) -> void:
	_t += delta
	if player == null or not is_instance_valid(player):
		return
	var pp := player.global_position
	var night := Game.is_night()
	var hour := Game.hour
	var dusk := (hour > 17.0 and hour < 21.5) or (hour > 4.5 and hour < 7.5)

	leaves.global_position = pp + Vector3(0, 7, 0)
	leaves.emitting = not _in_cave()

	for d in dragonflies:
		var n: Node3D = d
		n.visible = not night
		if night:
			continue
		var ph: float = n.get_meta("ph")
		var sp: float = n.get_meta("sp")
		var cx: float = n.get_meta("cx")
		var cz: float = n.get_meta("cz")
		var tt := _t * sp + ph
		# Achterbahn über dem See (Seemitte liegt bei z = -35 in Weltkoordinaten)
		var pos := Vector3(cx + sin(tt * 1.3) * 9.0, 0.9 + sin(tt * 2.1) * 0.35 + 0.35, -35.0 + cz + sin(tt * 2.6) * 6.0)
		var prev := n.global_position
		n.global_position = pos
		if prev.distance_to(pos) > 0.001:
			n.look_at(pos + (pos - prev), Vector3.UP)
		for c in n.get_children():
			if c.has_meta("side"):
				var s: float = c.get_meta("side")
				(c as Node3D).rotation.z = s * sin(_t * 70.0) * 0.5

	for p in midges:
		(p as CPUParticles3D).emitting = dusk

	# Kamera-Look: Vignette stärker beim Angeln, rot bei Schaden
	var fishing := player.fisher != null and player.fisher.state != Fisher.S.IDLE
	_focus = lerpf(_focus, 1.0 if fishing else 0.0, minf(delta * 2.0, 1.0))
	var needs: Node = player.get("needs") as Node
	if needs != null:
		var h: float = needs.get("health")
		if h < _last_health - 0.5:
			_hurt = 1.0
		_last_health = h
		if h < 30.0:
			_hurt = maxf(_hurt, (30.0 - h) / 60.0)
	_hurt = maxf(_hurt - delta * 1.5, 0.0) if (needs == null or float(needs.get("health")) >= 30.0) else _hurt
	vig_mat.set_shader_parameter("focus", _focus)
	vig_mat.set_shader_parameter("hurt", _hurt)
	# Abendstimmung: etwas wärmer
	var warm := clampf(1.0 - absf(sin((hour - 6.0) / 24.0 * TAU)) * 2.5, 0.0, 1.0)
	vig_mat.set_shader_parameter("tint_amt", 0.03 + warm * 0.07)


func _in_cave() -> bool:
	return main != null and main.get("_in_cave") == true
