class_name Batcher
extends RefCounted
## Fasst viele kleine, unbewegliche Einzelteile (Kisten, Kegel, Kugeln) zu wenigen
## großen Meshes zusammen. Die Welt sieht genauso aus, braucht aber nur einen
## Bruchteil der Zeichenaufrufe. Im Browser (WebGL) ist das nötig, weil dort ab
## etwa 1500 Einzel-Meshes gar nichts mehr gezeichnet wird.
##
## Sicherheitsregeln: Teile, auf die ein Skript eine Referenz hält (z. B. ein Deckel,
## der auf- und zugeht), die unsichtbar sind, in einer Gruppe stecken oder ein
## besonderes Material haben (leuchtend, durchsichtig, Textur), bleiben unangetastet.


static func run(world: Node) -> int:
	var refs := {}
	_collect_refs(world, refs)
	var groups := {}   # target node -> { key -> Array[MeshInstance3D] }
	var stack: Array = [world]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		if n is CharacterBody3D:
			continue   # Spielerfiguren & Co. nie anfassen
		for c in n.get_children():
			stack.append(c)
		if n is MeshInstance3D and _eligible(n as MeshInstance3D, refs):
			var target := _target_for(n, world, refs)
			if target == null:
				continue
			var mi := n as MeshInstance3D
			var m := mi.material_override as StandardMaterial3D
			var key := "%.2f|%d" % [m.roughness, mi.cast_shadow]
			if not groups.has(target):
				groups[target] = {}
			var g: Dictionary = groups[target]
			if not g.has(key):
				g[key] = []
			(g[key] as Array).append(mi)
	var removed := 0
	for target in groups:
		var g: Dictionary = groups[target]
		for key in g:
			var list: Array = g[key]
			if list.size() < 2:
				continue
			removed += _merge(target as Node3D, list)
	return removed


## Kleine Dinge weit weg gar nicht erst zeichnen (spart Zeichenaufrufe). Grosse Teile
## (Berg, See, Boden) bleiben, ebenso Spielerfiguren.
static func apply_ranges(world: Node, mesh_end: float = 110.0, label_end: float = 28.0) -> int:
	var n_set := 0
	var stack: Array = [world]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		if n is CharacterBody3D:
			continue
		for c in n.get_children():
			stack.append(c)
		if n is Label3D:
			(n as Label3D).visibility_range_end = label_end
			n_set += 1
		elif n is MeshInstance3D or n is MultiMeshInstance3D:
			var g := n as GeometryInstance3D
			var bb: AABB = g.get_aabb()
			if maxf(bb.size.x, maxf(bb.size.y, bb.size.z)) < 30.0 and g.visibility_range_end <= 0.0:
				g.visibility_range_end = mesh_end
				n_set += 1
	return n_set


static func _collect_refs(world: Node, refs: Dictionary) -> void:
	var stack: Array = [world]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if n.get_script() == null:
			continue
		for p in n.get_property_list():
			if not (int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE):
				continue
			_add_ref(n.get(p["name"]), refs, 0)


static func _add_ref(v: Variant, refs: Dictionary, depth: int) -> void:
	if depth > 3:
		return
	if v is Node:
		refs[v] = true
	elif v is Array:
		for e in v:
			_add_ref(e, refs, depth + 1)
	elif v is Dictionary:
		for k in v:
			_add_ref(k, refs, depth + 1)
			_add_ref(v[k], refs, depth + 1)


static func _eligible(mi: MeshInstance3D, refs: Dictionary) -> bool:
	if refs.has(mi) or mi.get_script() != null or not mi.visible:
		return false
	if mi.get_groups().size() > 0 or mi.get_child_count() > 0:
		return false
	if mi.mesh == null or mi.mesh.get_surface_count() != 1 or mi.material_overlay != null:
		return false
	if mi.get_surface_override_material_count() > 0 and mi.get_surface_override_material(0) != null:
		return false
	var m := mi.material_override as StandardMaterial3D
	if m == null or m.get_class() != "StandardMaterial3D":
		return false
	if m.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or m.emission_enabled:
		return false
	if m.albedo_texture != null or m.vertex_color_use_as_albedo or m.metallic > 0.0:
		return false
	if m.shading_mode != BaseMaterial3D.SHADING_MODE_PER_PIXEL or m.cull_mode != BaseMaterial3D.CULL_BACK:
		return false
	if m.albedo_color.a < 0.999 or m.no_depth_test or m.billboard_mode != BaseMaterial3D.BILLBOARD_DISABLED:
		return false
	if m.next_pass != null or m.normal_enabled or m.rim_enabled:
		return false
	var prim: int = mi.mesh.surface_get_primitive_type(0) if mi.mesh is ArrayMesh else Mesh.PRIMITIVE_TRIANGLES
	if prim != Mesh.PRIMITIVE_TRIANGLES:
		return false
	return true


## Der Knoten, der sich als Ganzes bewegt / entfernt wird: nächster Vorfahre mit
## Skript, Physik-Körper oder Referenz. Dort wird das zusammengefasste Mesh angehängt.
static func _target_for(mi: Node, world: Node, refs: Dictionary) -> Node3D:
	var a: Node = mi.get_parent()
	while a != null:
		if a == world or a.get_script() != null or a is CollisionObject3D or refs.has(a):
			return a as Node3D
		if not (a is Node3D) or not (a as Node3D).visible:
			return null
		a = a.get_parent()
	return null


static func _merge(target: Node3D, list: Array) -> int:
	var inv := target.global_transform.affine_inverse()
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var first := list[0] as MeshInstance3D
	var rough := (first.material_override as StandardMaterial3D).roughness
	var shadow := first.cast_shadow
	for e in list:
		var mi := e as MeshInstance3D
		var arr: Array = mi.mesh.surface_get_arrays(0)
		var pv: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var pn: PackedVector3Array = arr[Mesh.ARRAY_NORMAL] if arr[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		var pi: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var xf: Transform3D = inv * mi.global_transform
		var nb: Basis = xf.basis.inverse().transposed()
		var flip := xf.basis.determinant() < 0.0
		var col: Color = (mi.material_override as StandardMaterial3D).albedo_color
		var base := verts.size()
		for i in range(pv.size()):
			verts.append(xf * pv[i])
			norms.append((nb * pn[i]).normalized() if i < pn.size() else Vector3.UP)
			cols.append(col)
		if pi.is_empty():
			for i in range(0, pv.size() - 2, 3):
				if flip:
					idx.append_array([base + i, base + i + 2, base + i + 1])
				else:
					idx.append_array([base + i, base + i + 1, base + i + 2])
		else:
			for i in range(0, pi.size() - 2, 3):
				if flip:
					idx.append_array([base + pi[i], base + pi[i + 2], base + pi[i + 1]])
				else:
					idx.append_array([base + pi[i], base + pi[i + 1], base + pi[i + 2]])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = rough
	var out := MeshInstance3D.new()
	out.name = "Batched"
	out.mesh = am
	out.material_override = mat
	out.cast_shadow = shadow
	target.add_child(out)
	for e in list:
		var mi := e as MeshInstance3D
		mi.get_parent().remove_child(mi)
		mi.free()
	return list.size() - 1
