class_name FoxModel
extends RefCounted
## Rotfuchs aus einfachen Formen: oranges Fell, weisse Brust und Schwanzspitze, dunkle Pfoten und Ohren.
## Blickrichtung ist -Z. Gibt die beweglichen Teile zurueck: legs (vorne links/rechts, hinten links/rechts), tail, head.

const FUR := Color(0.84, 0.38, 0.1)
const FUR_LIGHT := Color(0.92, 0.55, 0.22)
const CREAM := Color(0.97, 0.92, 0.82)
const DARK := Color(0.11, 0.08, 0.06)


static func _ell(parent: Node3D, r: float, color: Color, pos: Vector3, scl: Vector3) -> MeshInstance3D:
	var m := Util.add_sphere(parent, r, color, pos)
	m.scale = scl
	return m


static func build(parent: Node3D) -> Dictionary:
	# Rumpf, Brust, Hals
	_ell(parent, 1.0, FUR, Vector3(0, 0.38, 0.05), Vector3(0.19, 0.18, 0.36))
	_ell(parent, 1.0, CREAM, Vector3(0, 0.3, -0.1), Vector3(0.14, 0.11, 0.2))
	_ell(parent, 1.0, FUR_LIGHT, Vector3(0, 0.46, 0.22), Vector3(0.15, 0.1, 0.18))
	_ell(parent, 1.0, FUR, Vector3(0, 0.5, -0.27), Vector3(0.1, 0.12, 0.14))

	# Kopf
	var head := Node3D.new()
	head.position = Vector3(0, 0.56, -0.4)
	parent.add_child(head)
	_ell(head, 1.0, FUR, Vector3.ZERO, Vector3(0.1, 0.09, 0.12))
	_ell(head, 1.0, FUR_LIGHT, Vector3(0, -0.025, -0.13), Vector3(0.045, 0.04, 0.1))
	_ell(head, 1.0, DARK, Vector3(0, -0.012, -0.235), Vector3(0.022, 0.018, 0.022))
	for sx in [-1.0, 1.0]:
		_ell(head, 1.0, CREAM, Vector3(sx * 0.065, -0.045, -0.07), Vector3(0.04, 0.035, 0.06))
		_ell(head, 1.0, DARK, Vector3(sx * 0.05, 0.025, -0.1), Vector3(0.014, 0.014, 0.014))
		var ear := Util.add_cone(head, 0.045, 0.14, FUR, Vector3(sx * 0.065, 0.12, 0.0))
		ear.rotation_degrees.z = -sx * 12.0
		var ear_in := Util.add_cone(head, 0.03, 0.1, DARK, Vector3(sx * 0.065, 0.115, -0.015))
		ear_in.rotation_degrees.z = -sx * 12.0
		ear_in.scale = Vector3(0.9, 0.9, 0.5)

	# Beine: Drehpunkt oben, oberer Teil orange, unterer Teil und Pfote dunkel
	var legs: Array = []
	for lz in [-0.22, 0.26]:
		for lx in [-0.1, 0.1]:
			var pivot := Node3D.new()
			pivot.position = Vector3(lx, 0.31, lz)
			parent.add_child(pivot)
			Util.add_box(pivot, Vector3(0.07, 0.14, 0.08), FUR, Vector3(0, -0.06, 0))
			Util.add_box(pivot, Vector3(0.05, 0.17, 0.05), DARK, Vector3(0, -0.18, 0))
			_ell(pivot, 1.0, DARK, Vector3(0, -0.28, -0.015), Vector3(0.035, 0.025, 0.055))
			legs.append(pivot)

	# Schwanz: buschig, weisse Spitze
	var tail := Node3D.new()
	tail.position = Vector3(0, 0.4, 0.38)
	tail.rotation_degrees.x = 25.0
	parent.add_child(tail)
	_ell(tail, 1.0, FUR, Vector3(0, 0, 0.2), Vector3(0.1, 0.1, 0.32))
	_ell(tail, 1.0, CREAM, Vector3(0, 0, 0.5), Vector3(0.08, 0.08, 0.13))

	return {"legs": legs, "tail": tail, "head": head}
