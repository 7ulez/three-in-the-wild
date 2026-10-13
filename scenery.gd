class_name Scenery
extends RefCounted
## Optik: Himmel mit Wolken, Wasser-Shader, Gras/Schilf/Blumen mit Wind, Steine, Totholz.

static var sky_shader_mat: ShaderMaterial = null
static var water_mat: ShaderMaterial = null


static func _noise_tex(seed_v: int, freq: float, size: int, normal: bool, bump: float = 4.0) -> ImageTexture:
	var n := FastNoiseLite.new()
	n.seed = seed_v
	n.frequency = freq
	n.fractal_octaves = 3
	var img := n.get_seamless_image(size, size)
	if normal:
		img.convert(Image.FORMAT_RGBA8)
		img.bump_map_to_normal_map(bump)
	else:
		img.convert(Image.FORMAT_RGBA8)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


# ---------------------------------------------------------------- Himmel

static func make_sky() -> Sky:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/sky.gdshader")
	m.set_shader_parameter("cloud_tex", _noise_tex(11, 0.012, 256, false))
	sky_shader_mat = m
	var sky := Sky.new()
	sky.sky_material = m
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	return sky


# ---------------------------------------------------------------- Wasser

## Abstand jedes Rasterpunkts zum Ufer in einer Textur (Rot = Meter / max_dist).
static func make_water(lake_root: Node3D, mesh_pts: PackedVector2Array) -> MeshInstance3D:
	var low := Game.low
	var res := 64 if low else 112
	var min_p := Vector2(1e9, 1e9)
	var max_p := Vector2(-1e9, -1e9)
	for p in mesh_pts:
		min_p = min_p.min(p)
		max_p = max_p.max(p)
	min_p -= Vector2(6, 6)
	max_p += Vector2(6, 6)
	var size_v := max_p - min_p
	var max_dist := 9.0
	var img := Image.create(res, res, false, Image.FORMAT_R8)
	var n := mesh_pts.size()
	for y in res:
		for x in res:
			var p := min_p + Vector2((x + 0.5) / res, (y + 0.5) / res) * size_v
			var inside := Geometry2D.is_point_in_polygon(p, mesh_pts)
			var best := 1e9
			for i in n:
				var a := mesh_pts[i]
				var b := mesh_pts[(i + 1) % n]
				var cp := Geometry2D.get_closest_point_to_segment(p, a, b)
				best = minf(best, p.distance_squared_to(cp))
			var dist := sqrt(best) if inside else 0.0
			img.set_pixel(x, y, Color(clampf(dist / max_dist, 0.0, 1.0), 0, 0))
	var tex := ImageTexture.create_from_image(img)

	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/water.gdshader")
	m.set_shader_parameter("shore_tex", tex)
	m.set_shader_parameter("wave_n", _noise_tex(5, 0.03, 256, true, 6.0))
	m.set_shader_parameter("bounds", Vector4(min_p.x, min_p.y, size_v.x, size_v.y))
	m.set_shader_parameter("max_dist", max_dist)
	water_mat = m
	var mi := LakeShape.poly_mesh(mesh_pts, 0.03, Util.mat(Color.WHITE))
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.name = "Water"
	lake_root.add_child(mi)
	return mi


## Wird jeden Frame/Tag aktualisiert: Himmelsfarbe spiegelt sich im Wasser.
static func update_sky(top: Color, hor: Color, ground: Color, sun_dir: Vector3, sun_col: Color, moon_dir: Vector3, night: float, day: float) -> void:
	if sky_shader_mat != null:
		var m := sky_shader_mat
		m.set_shader_parameter("top_col", top)
		m.set_shader_parameter("hor_col", hor)
		m.set_shader_parameter("ground_col", ground)
		m.set_shader_parameter("sun_dir", sun_dir)
		m.set_shader_parameter("sun_col", sun_col)
		m.set_shader_parameter("moon_dir", moon_dir)
		m.set_shader_parameter("night", night)
		m.set_shader_parameter("cloud_lit", Color(1.0, 0.97, 0.92).lerp(sun_col, 0.3))
	if water_mat != null:
		water_mat.set_shader_parameter("sky_col", top.lerp(hor, 0.5))
		water_mat.set_shader_parameter("light_amt", lerpf(0.22, 1.0, day))


# ---------------------------------------------------------------- Boden

static func ground_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/ground.gdshader")
	return m


# ---------------------------------------------------------------- Gras

## Ein Büschel aus mehreren Halmen. UV.y = 0 am Boden, 1 an der Spitze.
static func tuft_mesh(blades: int, h: float, w: float, seed_v: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var norms := PackedVector3Array()
	for i in blades:
		var ang := rng.randf() * TAU
		var dir := Vector3(cos(ang), 0, sin(ang))
		var side := Vector3(-dir.z, 0, dir.x)
		var off := dir * rng.randf_range(0.0, 0.16)
		var bh := h * rng.randf_range(0.6, 1.2)
		var lean := dir * rng.randf_range(0.05, 0.25) * bh
		verts.append(off - side * w)
		verts.append(off + side * w)
		verts.append(off + lean + Vector3(0, bh, 0))
		uvs.append(Vector2(0, 0))
		uvs.append(Vector2(1, 0))
		uvs.append(Vector2(0.5, 1))
		for k in 3:
			norms.append(Vector3.UP)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_NORMAL] = norms
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh


static func grass_material(base: Color, sway: float, fade_start: float, fade_end: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/grass.gdshader")
	m.set_shader_parameter("base_col", base)
	m.set_shader_parameter("sway", sway)
	m.set_shader_parameter("fade_start", fade_start)
	m.set_shader_parameter("fade_end", fade_end)
	return m


## Teilt Instanzen in 40-m-Zellen und legt je Zelle ein MultiMesh an (Sichtweite begrenzt).
static func add_chunked(parent: Node, mesh: Mesh, mat: Material, xf: Array, cols: Array, vis_end: float) -> void:
	var cells := {}
	for i in xf.size():
		var p: Vector3 = (xf[i] as Transform3D).origin
		var key := Vector2i(floori(p.x / 40.0), floori(p.z / 40.0))
		if not cells.has(key):
			cells[key] = []
		cells[key].append(i)
	for key in cells:
		var ids: Array = cells[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = mesh
		mm.instance_count = ids.size()
		for j in ids.size():
			mm.set_instance_transform(j, xf[ids[j]])
			mm.set_instance_color(j, cols[ids[j]])
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = vis_end
		mi.custom_aabb = AABB(Vector3(key.x * 40.0, -1, key.y * 40.0), Vector3(40, 4, 40))
		parent.add_child(mi)


## Gras, Blumen, Schilf, Steine und Totholz. blocked: Callable(Vector3) -> bool
static func build_ground_cover(main: Node3D, lake_root: Node3D, blocked: Callable, rng: RandomNumberGenerator) -> void:
	var low := Game.low
	var root := Node3D.new()
	root.name = "Bodendeko"
	main.add_child(root)

	# --- Gras ---
	var grass_n := 5200 if low else 15000
	var gx: Array = []
	var gc: Array = []
	var greens: Array = [Color(0.38, 0.62, 0.2), Color(0.45, 0.68, 0.22), Color(0.32, 0.55, 0.18), Color(0.55, 0.7, 0.25)]
	var flowers: Array = [Color(0.95, 0.85, 0.25), Color(0.95, 0.95, 0.9), Color(0.85, 0.45, 0.75), Color(0.6, 0.55, 0.95), Color(0.95, 0.5, 0.3)]
	var tries := 0
	while gx.size() < grass_n and tries < grass_n * 4:
		tries += 1
		var p := Vector3(rng.randf_range(-148.0, 148.0), 0.0, rng.randf_range(-128.0, 88.0))
		if blocked.call(p):
			continue
		var s := rng.randf_range(0.7, 1.5)
		var b := Basis.from_euler(Vector3(0, rng.randf() * TAU, 0)).scaled(Vector3(s, s * rng.randf_range(0.8, 1.4), s))
		gx.append(Transform3D(b, p))
		if rng.randf() < 0.05:
			gc.append(flowers[rng.randi() % flowers.size()])
		else:
			gc.append(greens[rng.randi() % greens.size()])
	add_chunked(root, tuft_mesh(7, 0.55, 0.045, 3), grass_material(Color(0.12, 0.26, 0.08), 0.16, 45.0, 75.0), gx, gc, 80.0)

	# --- Schilf am Ufer ---
	var pts := LakeShape.points
	var rx: Array = []
	var rc: Array = []
	var cat_x: Array = []
	var cat_c: Array = []
	for i in range(0, pts.size()):
		var p := pts[i]
		var near_spot := false
		for gxx in [-12.0, 0.0, 12.0]:
			if absf(p.x - gxx - 1.0) < 3.0 and p.y > -46.0:
				near_spot = true
		if near_spot:
			continue
		var out := (p - LakeShape.CENTER).normalized()
		if rng.randf() < 0.75:
			for k in range(rng.randi_range(3, 6)):
				var q := p + out * rng.randf_range(-0.6, 1.1) + Vector2(rng.randf_range(-0.7, 0.7), rng.randf_range(-0.7, 0.7))
				var h := rng.randf_range(1.0, 1.9)
				var b := Basis.from_euler(Vector3(0, rng.randf() * TAU, 0)).scaled(Vector3(1.2, h * 1.5, 1.2))
				rx.append(Transform3D(b, Vector3(q.x, 0.0, q.y) + lake_root.position))
				rc.append(Color(0.62, 0.7, 0.28).lerp(Color(0.75, 0.68, 0.35), rng.randf() * 0.6))
				if rng.randf() < 0.3:
					var tr := Transform3D(Basis.from_euler(Vector3(0, 0, rng.randf_range(-0.1, 0.1))), Vector3(q.x, h * 0.78, q.y) + lake_root.position)
					cat_x.append(tr)
					cat_c.append(Color(0.33, 0.2, 0.1))
	add_chunked(root, tuft_mesh(6, 1.0, 0.06, 9), grass_material(Color(0.18, 0.3, 0.1), 0.22, 60.0, 90.0), rx, rc, 100.0)
	var cat := CylinderMesh.new()
	cat.top_radius = 0.045
	cat.bottom_radius = 0.045
	cat.height = 0.3
	cat.radial_segments = 5
	var catm := StandardMaterial3D.new()
	catm.vertex_color_use_as_albedo = true
	add_chunked(root, cat, catm, cat_x, cat_c, 70.0)

	# --- Steine ---
	var sx: Array = []
	var sc: Array = []
	var rock_n := 120 if low else 340
	tries = 0
	while sx.size() < rock_n and tries < rock_n * 6:
		tries += 1
		var p := Vector3(rng.randf_range(-148.0, 148.0), 0.0, rng.randf_range(-128.0, 88.0))
		if blocked.call(p):
			continue
		var s := rng.randf_range(0.15, 0.55)
		var b := Basis.from_euler(Vector3(rng.randf() * 0.3, rng.randf() * TAU, rng.randf() * 0.3)).scaled(Vector3(s * rng.randf_range(1.0, 1.6), s * 0.6, s))
		sx.append(Transform3D(b, p + Vector3(0, s * 0.18, 0)))
		sc.append(Color(0.5, 0.5, 0.5).lerp(Color(0.62, 0.58, 0.5), rng.randf()))
	var rock := SphereMesh.new()
	rock.radius = 0.5
	rock.height = 1.0
	rock.radial_segments = 6
	rock.rings = 3
	var rm := StandardMaterial3D.new()
	rm.vertex_color_use_as_albedo = true
	rm.roughness = 1.0
	add_chunked(root, rock, rm, sx, sc, 110.0)

	# --- Totholz ---
	var lx: Array = []
	var lc: Array = []
	var log_n := 30 if low else 80
	tries = 0
	while lx.size() < log_n and tries < log_n * 8:
		tries += 1
		var p := Vector3(rng.randf_range(-148.0, 148.0), 0.0, rng.randf_range(-128.0, 88.0))
		if blocked.call(p):
			continue
		var len_s := rng.randf_range(0.6, 1.6)
		var b := Basis.from_euler(Vector3(0, rng.randf() * TAU, PI * 0.5)).scaled(Vector3(1.0, len_s, 1.0))
		lx.append(Transform3D(b, p + Vector3(0, 0.14, 0)))
		lc.append(Color(0.34, 0.23, 0.14).lerp(Color(0.5, 0.4, 0.3), rng.randf() * 0.5))
	var logm := CylinderMesh.new()
	logm.top_radius = 0.13
	logm.bottom_radius = 0.16
	logm.height = 2.0
	logm.radial_segments = 6
	var lm := StandardMaterial3D.new()
	lm.vertex_color_use_as_albedo = true
	lm.roughness = 1.0
	add_chunked(root, logm, lm, lx, lc, 110.0)


static func foliage_material(sway: float = 0.06) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/foliage.gdshader")
	m.set_shader_parameter("sway", sway)
	return m
