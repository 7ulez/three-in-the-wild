class_name Fx
extends RefCounted
## Kleine visuelle Helfer: Wellenringe, weiche Schatten, Lichtflecken.

static var _ring_shader: Shader = null
static var _glow_shader: Shader = null


static func _flat_quad(size: float) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.orientation = PlaneMesh.FACE_Y
	return q


## Wellenring auf dem Wasser (wächst und blendet aus).
static func ripple(parent: Node, pos: Vector3, size: float = 1.0, delay: float = 0.0) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	if _ring_shader == null:
		_ring_shader = load("res://shaders/ring.gdshader")
	var mi := MeshInstance3D.new()
	mi.mesh = _flat_quad(3.0 * size)
	var m := ShaderMaterial.new()
	m.shader = _ring_shader
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = Vector3(pos.x, 0.05, pos.z)
	var tw := mi.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_method(func(t: float) -> void: m.set_shader_parameter("progress", t), 0.0, 1.0, 1.6)
	tw.tween_callback(mi.queue_free)


## Weicher Lichtfleck / Schatten am Boden (flach, y knapp über dem Boden).
static func glow_disc(parent: Node3D, size: float, color: Color, strength: float, y: float = 0.03, power: float = 2.0) -> MeshInstance3D:
	if _glow_shader == null:
		_glow_shader = load("res://shaders/glow.gdshader")
	var mi := MeshInstance3D.new()
	mi.mesh = _flat_quad(size)
	var m := ShaderMaterial.new()
	m.shader = _glow_shader
	m.set_shader_parameter("col", color)
	m.set_shader_parameter("strength", strength)
	m.set_shader_parameter("power", power)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(0, y, 0)
	parent.add_child(mi)
	return mi


static func blob_shadow(parent: Node3D, radius: float = 0.5) -> MeshInstance3D:
	return glow_disc(parent, radius * 2.0, Color(0, 0, 0, 1), 0.38, 0.03, 1.2)


static func sparks(parent: Node3D, pos: Vector3) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.amount = 14 if Game.low else 28
	p.lifetime = 1.6
	p.direction = Vector3(0, 1, 0)
	p.spread = 25.0
	p.initial_velocity_min = 0.8
	p.initial_velocity_max = 2.2
	p.gravity = Vector3(0.15, 0.4, 0.0)
	p.damping_min = 0.3
	p.damping_max = 0.8
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve
	var m := SphereMesh.new()
	m.radius = 0.02
	m.height = 0.04
	m.radial_segments = 4
	m.rings = 2
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.7, 0.25)
	m.material = mat
	p.mesh = m
	p.position = pos
	parent.add_child(p)
	return p


## Pinkelstrahl (für den eigenen Spieler und die Figuren der anderen).
static func pee_stream() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.amount = 60
	p.lifetime = 0.7
	p.direction = Vector3(0, 0.25, -1)
	p.spread = 4.0
	p.initial_velocity_min = 2.6
	p.initial_velocity_max = 3.0
	p.gravity = Vector3(0, -9.8, 0)
	var pm := SphereMesh.new()
	pm.radius = 0.02
	pm.height = 0.04
	pm.radial_segments = 4
	pm.rings = 2
	var pmat := StandardMaterial3D.new()
	pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pmat.albedo_color = Color(0.95, 0.9, 0.2)
	pm.material = pmat
	p.mesh = pm
	p.position = Vector3(0, 0.95, -0.25)
	return p


## Nasse Stelle am Boden: wird größer, wenn man weiter hinpinkelt, und trocknet nach einer Weile wieder.
static func wet_spot(parent: Node, pos: Vector3) -> void:
	var last: Variant = parent.get_meta("wet_last", null)
	if last != null and is_instance_valid(last):
		var ls := last as MeshInstance3D
		if Vector2(ls.global_position.x - pos.x, ls.global_position.z - pos.z).length() < 0.5:
			var now := Time.get_ticks_msec()
			if now - int(ls.get_meta("grown", 0)) < 250:
				return
			ls.set_meta("grown", now)
			var s := minf(ls.scale.x + 0.04, 1.7)
			ls.scale = Vector3(s, 1.0, s)
			var old: Tween = ls.get_meta("tw", null)
			if old != null:
				old.kill()
			(ls.material_override as StandardMaterial3D).albedo_color.a = 0.6
			ls.set_meta("tw", _dry(ls))
			return
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.3
	cm.bottom_radius = 0.3
	cm.height = 0.01
	cm.radial_segments = 20
	mi.mesh = cm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.12, 0.09, 0.05, 0.6)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.3
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.scale = Vector3(0.45, 1.0, 0.45)
	parent.add_child(mi)
	mi.global_position = Vector3(pos.x, 0.05, pos.z)
	parent.set_meta("wet_last", mi)
	mi.set_meta("tw", _dry(mi))


static func _dry(mi: MeshInstance3D) -> Tween:
	var tw := mi.create_tween()
	tw.tween_interval(30.0)
	tw.tween_property(mi.material_override, "albedo_color:a", 0.0, 40.0)
	tw.tween_callback(mi.queue_free)
	return tw


## Kotzstrahl (eigener Spieler und die Figuren der anderen). Der Mund ist beim Vorbeugen vorn und tiefer.
static func vomit_stream() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.amount = 70
	p.lifetime = 0.8
	p.direction = Vector3(0, -0.5, -1)
	p.spread = 14.0
	p.initial_velocity_min = 1.4
	p.initial_velocity_max = 2.6
	p.gravity = Vector3(0, -9.8, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.6
	var pm := SphereMesh.new()
	pm.radius = 0.035
	pm.height = 0.07
	pm.radial_segments = 5
	pm.rings = 3
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.62, 0.58, 0.18)
	pmat.roughness = 0.4
	pm.material = pmat
	p.mesh = pm
	var g := Gradient.new()
	g.set_color(0, Color(0.78, 0.7, 0.2))
	g.set_color(1, Color(0.9, 0.5, 0.2))
	p.color_ramp = g
	p.position = Vector3(0, 1.2, -0.75)
	return p


## Kotzlache: wächst, solange man weiter kotzt, bleibt eine Weile liegen und trocknet dann ein.
static func vomit_puddle(parent: Node, pos: Vector3) -> void:
	var last: Variant = parent.get_meta("vom_last", null)
	if last != null and is_instance_valid(last):
		var ls := last as MeshInstance3D
		if Vector2(ls.global_position.x - pos.x, ls.global_position.z - pos.z).length() < 0.8:
			var s := minf(ls.scale.x + 0.14, 1.7)
			ls.scale = Vector3(s, 1.0, s)
			var old: Tween = ls.get_meta("tw", null)
			if old != null:
				old.kill()
			ls.set_meta("tw", _vomit_dry(ls))
			return
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.3
	cm.bottom_radius = 0.3
	cm.height = 0.014
	cm.radial_segments = 18
	mi.mesh = cm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.55, 0.52, 0.16)
	m.roughness = 0.2
	m.metallic_specular = 0.8
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.scale = Vector3(0.4, 1.0, 0.4)
	parent.add_child(mi)
	mi.global_position = Vector3(pos.x, 0.055, pos.z)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in range(7):
		var b := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = rng.randf_range(0.025, 0.05)
		sm.height = sm.radius * 1.2
		sm.radial_segments = 5
		sm.rings = 3
		b.mesh = sm
		var bm := StandardMaterial3D.new()
		bm.albedo_color = [Color(0.85, 0.5, 0.2), Color(0.5, 0.35, 0.18), Color(0.75, 0.7, 0.3), Color(0.9, 0.85, 0.6)].pick_random()
		bm.roughness = 0.5
		b.material_override = bm
		b.position = Vector3(rng.randf_range(-0.22, 0.22), 0.012, rng.randf_range(-0.22, 0.22))
		b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.add_child(b)
	parent.set_meta("vom_last", mi)
	mi.set_meta("tw", _vomit_dry(mi))


static func _vomit_dry(mi: MeshInstance3D) -> Tween:
	var tw := mi.create_tween()
	tw.tween_interval(22.0)
	tw.tween_property(mi, "scale", Vector3(0.02, 1.0, 0.02), 6.0)
	tw.tween_callback(mi.queue_free)
	return tw
