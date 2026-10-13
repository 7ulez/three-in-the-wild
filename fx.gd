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
