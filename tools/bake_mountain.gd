extends SceneTree
## Backt den Berg (CSG) einmalig zu einem normalen Mesh + Kollisionsform.
## Aufruf: godot --headless --path . -s tools/bake_mountain.gd
## Aussenfels (Flaeche 0) bekommt weiche Normalen (sonst sieht man grosse dunkle Facetten),
## Hoehlenwaende und Pfadkante bleiben kantig.
func _smooth_rock(src: Mesh) -> Mesh:
	var out := ArrayMesh.new()
	for i in range(src.get_surface_count()):
		var mat: Material = src.surface_get_material(i)
		if i == 0:
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			var arr: Array = src.surface_get_arrays(i)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			st.set_smooth_group(0)
			if idx.is_empty():
				for v in verts:
					st.add_vertex(v)
			else:
				for k in idx:
					st.add_vertex(verts[k])
			st.generate_normals()
			st.commit(out)
		else:
			var arr2: Array = src.surface_get_arrays(i)
			out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr2)
		out.surface_set_material(i, mat)
	return out


func _initialize() -> void:
	var csg := Massif.make_csg()
	root.add_child(csg)
	for i in 4:
		await process_frame
	var ms: Array = csg.get_meshes()
	print("meshes=", ms.size())
	if ms.size() >= 2 and ms[1] is Mesh:
		var m: Mesh = ms[1]
		print("surfaces=", m.get_surface_count(), " faces=", m.get_faces().size() / 3)
		m = _smooth_rock(m)
		ResourceSaver.save(m, Massif.MESH_FILE)
		var sh := m.create_trimesh_shape()
		ResourceSaver.save(sh, Massif.SHAPE_FILE)
	quit()
