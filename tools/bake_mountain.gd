extends SceneTree
## Backt den Berg (CSG) einmalig zu einem normalen Mesh + Kollisionsform.
## Aufruf: godot --headless --path . -s tools/bake_mountain.gd
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
		ResourceSaver.save(m, Massif.MESH_FILE)
		var sh := m.create_trimesh_shape()
		ResourceSaver.save(sh, Massif.SHAPE_FILE)
	quit()
