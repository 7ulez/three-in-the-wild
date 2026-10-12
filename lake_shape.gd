class_name LakeShape
extends RefCounted
## Umriss des Sees (lokale Koordinaten von lake_root, x/z) und Hilfsfunktionen.

const CENTER: Vector2 = Vector2(0.0, -50.0)
static var points: PackedVector2Array = PackedVector2Array()


static func build(count: int = 96) -> PackedVector2Array:
	points = PackedVector2Array()
	for i in range(count):
		var a := TAU * float(i) / float(count)
		var r := 1.0 + 0.11 * sin(3.0 * a + 1.0) + 0.07 * sin(5.0 * a + 2.0) + 0.04 * sin(9.0 * a)
		points.append(CENTER + Vector2(25.0 * r * cos(a), 16.5 * r * sin(a)))
	return points


static func contains(p: Vector2) -> bool:
	if points.is_empty():
		build()
	return Geometry2D.is_point_in_polygon(p, points)


static func scaled(factor: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(CENTER + (p - CENTER) * factor)
	return out


## Flaches Polygon als Mesh (Draufsicht, y = Höhe)
static func poly_mesh(poly: PackedVector2Array, y: float, mat: Material) -> MeshInstance3D:
	var idx := Geometry2D.triangulate_polygon(poly)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for i in range(0, idx.size(), 3):
		# Reihenfolge so, dass die Fläche nach oben zeigt
		for k in [0, 1, 2]:
			var p := poly[idx[i + k]]
			st.add_vertex(Vector3(p.x, y, p.y))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	(mat as BaseMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	return mi
