class_name Util
extends RefCounted
## Kleine Helfer zum Bauen von Low-Poly-Formen per Code.
## Später ersetzen wir diese Platzhalter durch Blender-Modelle (.glb).


static func mat(color: Color, rough: float = 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	return m


static func add_box(parent: Node, size: Vector3, color: Color, pos: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat(color)
	mi.position = pos
	parent.add_child(mi)
	return mi


static func add_cylinder(parent: Node, radius: float, height: float, color: Color, pos: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = 8
	mi.mesh = cm
	mi.material_override = mat(color)
	mi.position = pos
	parent.add_child(mi)
	return mi


static func add_cone(parent: Node, radius: float, height: float, color: Color, pos: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = 7
	mi.mesh = cm
	mi.material_override = mat(color)
	mi.position = pos
	parent.add_child(mi)
	return mi


static func add_sphere(parent: Node, radius: float, color: Color, pos: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	sm.radial_segments = 10
	sm.rings = 6
	mi.mesh = sm
	mi.material_override = mat(color)
	mi.position = pos
	parent.add_child(mi)
	return mi
