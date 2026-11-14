class_name Catacombs
extends Node3D
## Katakomben tief unter der Map: Hub (3x3 Zellen) direkt unter dem Schacht, darum ein Labyrinth.
## Alles ist ein paar grosse Meshes (Wände, Böden) plus zwei MultiMeshes (Knochen, Fackeln):
## wenige Objekte, damit das Limit von 1000 sichtbaren Objekten nie gefährdet ist.

const N: int = 19                  # Zellen pro Seite (ungerade, Hub in der Mitte)
const PITCH: float = 4.0           # Zellabstand (Gang 3 m + Wand 1 m)
const WALL_T: float = 1.0
const FLOOR_Y: float = -30.0
const H: float = 3.5               # Ganghöhe
const CEIL_Y: float = FLOOR_Y + H
const MID: int = 9                 # Hub-Mitte (Zellindex)
const CATA_LAYER: int = 1 << 10    # Render-Ebene 11: Sonne und Mond beleuchten die Katakomben nicht
const SHAFT_HALF: float = 0.7      # halbe Schachtbreite

# Zweiter Ausgang: langer Tunnel nach Süden zur Tropfsteinhöhle (Schacht EXIT_X/EXIT_Z)
const TUNNEL_X: float = 93.0       # Tunnel-Mitte (Spalte 16 des Labyrinths)
const EXIT_X: float = 94.0
const EXIT_Z: float = 56.5
const ROOM_X0: float = 91.0
const ROOM_X1: float = 97.0
const ROOM_Z0: float = 52.0
const ROOM_Z1: float = 59.0

var under_rects: Array = []           # Grundrisse (Rect2 x,z) aller unterirdischen Bereiche
var extra_aabbs: Array = []           # Dunkelzonen ausser dem Labyrinth (Tunnel, Raum)
var center: Vector3 = Vector3.ZERO     # Boden unter dem Schacht (Mitte des Hubs)
var east: PackedByteArray = PackedByteArray()    # 1 = Durchgang von Zelle (i,j) nach (i+1,j)
var south: PackedByteArray = PackedByteArray()   # 1 = Durchgang von Zelle (i,j) nach (i,j+1)
var aabb: AABB = AABB()
var dead_ends: Array = []
var _torch_all: Array = []             # Fackelpositionen (für Halter und Lichtschein)


static func idx(i: int, j: int) -> int:
	return j * N + i


func cell_center(c: int) -> Vector3:
	return center + Vector3(float(c % N - MID) * PITCH, 0.0, float(c / N - MID) * PITCH)


## Zelle unter einer Weltposition (-1 ausserhalb)
func cell_of(p: Vector3) -> int:
	var i := int(round((p.x - center.x) / PITCH)) + MID
	var j := int(round((p.z - center.z) / PITCH)) + MID
	if i < 0 or j < 0 or i >= N or j >= N:
		return -1
	return idx(i, j)


const LAN_I0: int = 14          # LAN-Party-Raum: 3x3 Zellen, Innenwände weg
const LAN_I1: int = 16
const LAN_J0: int = 3
const LAN_J1: int = 5


func is_lan(c: int) -> bool:
	var i := c % N
	var j := c / N
	return i >= LAN_I0 and i <= LAN_I1 and j >= LAN_J0 and j <= LAN_J1


func lan_center() -> Vector3:
	return cell_center(idx((LAN_I0 + LAN_I1) / 2, (LAN_J0 + LAN_J1) / 2))


## Mitte der Nordwest-Eckzelle: hier steht die dritte Leiter nach oben
func exit3_pos() -> Vector3:
	return cell_center(idx(0, 5))


## Raum öffnen und der Ausgangs-Ecke einen Zugang von Süden geben (nur zusätzliche Verbindungen, bleibt zusammenhängend)
func _carve_extras() -> void:
	for j in range(LAN_J0, LAN_J1 + 1):
		for i in range(LAN_I0, LAN_I1 + 1):
			var c := idx(i, j)
			if i < LAN_I1:
				east[c] = 1
			if j < LAN_J1:
				south[c] = 1
	south[idx(0, 5)] = 1


func is_hub(c: int) -> bool:
	var i := c % N
	var j := c / N
	return absi(i - MID) <= 1 and absi(j - MID) <= 1


## Offene Nachbarzellen
func links(c: int) -> Array:
	var i := c % N
	var j := c / N
	var r: Array = []
	if i < N - 1 and east[c] == 1:
		r.append(c + 1)
	if i > 0 and east[c - 1] == 1:
		r.append(c - 1)
	if j < N - 1 and south[c] == 1:
		r.append(c + N)
	if j > 0 and south[c - N] == 1:
		r.append(c - N)
	return r


func _carve(a: int, b: int) -> void:
	if b == a + 1:
		east[a] = 1
	elif b == a - 1:
		east[b] = 1
	elif b == a + N:
		south[a] = 1
	elif b == a - N:
		south[b] = 1


## Wachsender Baum (75 % neueste Zelle = lange Gänge): vom Hub aus in alle Richtungen
func generate(seed_v: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	east = PackedByteArray()
	south = PackedByteArray()
	east.resize(N * N)
	south.resize(N * N)
	var visited := PackedByteArray()
	visited.resize(N * N)
	var active: Array = []
	for j in range(MID - 1, MID + 2):
		for i in range(MID - 1, MID + 2):
			var c := idx(i, j)
			visited[c] = 1
			active.append(c)
			if i < MID + 1:
				east[c] = 1
			if j < MID + 1:
				south[c] = 1
	while not active.is_empty():
		var ai: int = active.size() - 1 if rng.randf() < 0.75 else rng.randi() % active.size()
		var c: int = active[ai]
		var ci := c % N
		var cj := c / N
		var nb: Array = []
		if ci < N - 1 and visited[c + 1] == 0:
			nb.append(c + 1)
		if ci > 0 and visited[c - 1] == 0:
			nb.append(c - 1)
		if cj < N - 1 and visited[c + N] == 0:
			nb.append(c + N)
		if cj > 0 and visited[c - N] == 0:
			nb.append(c - N)
		if nb.is_empty():
			active.remove_at(ai)
			continue
		var n: int = nb[rng.randi() % nb.size()]
		_carve(c, n)
		visited[n] = 1
		active.append(n)
	# Schleifen: einen Teil der Sackgassen aufbrechen
	for c in range(N * N):
		if links(c).size() == 1 and rng.randf() < 0.28:
			var ci2 := c % N
			var cj2 := c / N
			var cand: Array = []
			if ci2 < N - 1 and east[c] == 0:
				cand.append(c + 1)
			if ci2 > 0 and east[c - 1] == 0:
				cand.append(c - 1)
			if cj2 < N - 1 and south[c] == 0:
				cand.append(c + N)
			if cj2 > 0 and south[c - N] == 0:
				cand.append(c - N)
			if not cand.is_empty():
				_carve(c, cand[rng.randi() % cand.size()])
	dead_ends.clear()
	for c in range(N * N):
		if links(c).size() == 1:
			dead_ends.append(c)


## Kürzester Weg (Zellliste von a nach b, ohne a)
func path(a: int, b: int) -> Array:
	if a < 0 or b < 0 or a == b:
		return []
	var prev := {}
	prev[a] = -1
	var q: Array = [a]
	var qi := 0
	while qi < q.size():
		var c: int = q[qi]
		qi += 1
		if c == b:
			break
		for n in links(c):
			if not prev.has(n):
				prev[n] = c
				q.append(n)
	if not prev.has(b):
		return []
	var out: Array = []
	var cur: int = b
	while cur != a:
		out.push_front(cur)
		cur = prev[cur]
	return out


# ---------- Aufbau ----------

func build(p_center: Vector3, seed_v: int = 4711) -> void:
	center = p_center
	generate(seed_v)
	_carve_extras()
	var half := float(N) * PITCH / 2.0
	aabb = AABB(Vector3(center.x - half, FLOOR_Y - 1.0, center.z - half), Vector3(half * 2.0, H + 2.0, half * 2.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v + 7
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var stone := Color(0.30, 0.28, 0.25)
	# Boden und Decke (Decke mit quadratischem Loch für den Schacht)
	var ext := half + 1.0
	_box(st, Vector3(center.x, FLOOR_Y - 0.5, center.z), Vector3(ext * 2.0, 1.0, ext * 2.0), Color(0.19, 0.17, 0.15), 0.0, rng)
	var ceil_y := CEIL_Y + 0.5
	var hs := SHAFT_HALF
	var cc_col := Color(0.2, 0.19, 0.17)
	# Löcher in der Decke von West nach Ost: Nordwest-Ausgang und der Hub-Schacht
	var e3 := exit3_pos()
	var chs: Array = [Vector2(e3.x, e3.z), Vector2(center.x, center.z)]
	var prev := center.x - ext
	for hp in chs:
		var hv: Vector2 = hp
		_box(st, Vector3((prev + hv.x - hs) / 2.0, ceil_y, center.z), Vector3(hv.x - hs - prev, 1.0, ext * 2.0), cc_col, 0.0, rng)
		_box(st, Vector3(hv.x, ceil_y, (center.z - ext + hv.y - hs) / 2.0), Vector3(hs * 2.0, 1.0, hv.y - hs - (center.z - ext)), cc_col, 0.0, rng)
		_box(st, Vector3(hv.x, ceil_y, (hv.y + hs + center.z + ext) / 2.0), Vector3(hs * 2.0, 1.0, center.z + ext - (hv.y + hs)), cc_col, 0.0, rng)
		prev = hv.x + hs
	_box(st, Vector3((prev + center.x + ext) / 2.0, ceil_y, center.z), Vector3(center.x + ext - prev, 1.0, ext * 2.0), cc_col, 0.0, rng)
	var wy := FLOOR_Y + H / 2.0
	# Aussenwand rundum
	_box(st, Vector3(center.x, wy, center.z - half - 0.5), Vector3(ext * 2.0, H, 1.0), stone, 0.1, rng)
	var dx0 := TUNNEL_X - (PITCH - WALL_T) / 2.0         # Türöffnung im Südwall (zwischen zwei Pfeilern)
	var dx1 := TUNNEL_X + (PITCH - WALL_T) / 2.0
	var sx0 := center.x - ext
	var sx1 := center.x + ext
	_box(st, Vector3((sx0 + dx0) / 2.0, wy, center.z + half + 0.5), Vector3(dx0 - sx0, H, 1.0), stone, 0.1, rng)
	_box(st, Vector3((dx1 + sx1) / 2.0, wy, center.z + half + 0.5), Vector3(sx1 - dx1, H, 1.0), stone, 0.1, rng)
	_box(st, Vector3(center.x - half - 0.5, wy, center.z), Vector3(1.0, H, ext * 2.0), stone, 0.1, rng)
	_box(st, Vector3(center.x + half + 0.5, wy, center.z), Vector3(1.0, H, ext * 2.0), stone, 0.1, rng)
	# Pfeiler an jeder Gitterecke (im Hub werden das Säulen)
	for j in range(N + 1):
		for i in range(N + 1):
			var gx := center.x + (float(i - MID) - 0.5) * PITCH
			var gz := center.z + (float(j - MID) - 0.5) * PITCH
			_box(st, Vector3(gx, wy, gz), Vector3(WALL_T, H, WALL_T), stone, 0.12, rng)
	# Wandstücke zwischen den Pfeilern, wo kein Durchgang ist
	var seg := PITCH - WALL_T
	for j in range(N):
		for i in range(N):
			var c := idx(i, j)
			var cc := cell_center(c)
			if i < N - 1 and east[c] == 0:
				_box(st, Vector3(cc.x + PITCH / 2.0, wy, cc.z), Vector3(WALL_T, H, seg), stone, 0.12, rng)
			if j < N - 1 and south[c] == 0:
				_box(st, Vector3(cc.x, wy, cc.z + PITCH / 2.0), Vector3(seg, H, WALL_T), stone, 0.12, rng)
	st.generate_normals()
	var mesh := st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.layers = 1 | CATA_LAYER
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = mesh.create_trimesh_shape()
	body.add_child(cs)
	add_child(body)
	_build_shaft_cage()
	_build_deco(rng)
	under_rects.append(Rect2(center.x - half - 1.0, center.z - half - 1.0, half * 2.0 + 2.0, half * 2.0 + 2.0))
	_build_tunnel(rng)
	_build_detail()


## Fügt eine Box mit leichter Farbstreuung in den SurfaceTool-Mesh ein.
func _box(st: SurfaceTool, c: Vector3, size: Vector3, col: Color, jitter: float, rng: RandomNumberGenerator) -> void:
	var h := size / 2.0
	var v := [
		c + Vector3(-h.x, -h.y, -h.z), c + Vector3(h.x, -h.y, -h.z), c + Vector3(h.x, h.y, -h.z), c + Vector3(-h.x, h.y, -h.z),
		c + Vector3(-h.x, -h.y, h.z), c + Vector3(h.x, -h.y, h.z), c + Vector3(h.x, h.y, h.z), c + Vector3(-h.x, h.y, h.z)]
	# Flächen (Außenseite zeigt nach außen; gegen den Uhrzeigersinn von außen)
	var faces := [[0, 3, 2, 1], [5, 6, 7, 4], [4, 7, 3, 0], [1, 2, 6, 5], [3, 7, 6, 2], [4, 0, 1, 5]]
	for f in faces:
		var k := 1.0 + rng.randf_range(-jitter, jitter)
		st.set_smooth_group(-1)         # flache Flächen
		st.set_color(Color(col.r * k, col.g * k, col.b * k))
		for t in [0, 2, 1, 0, 3, 2]:    # Godot: Vorderseite im Uhrzeigersinn
			st.add_vertex(v[f[t]])


## Leiterkäfig im Hub: drei Wände (Süden offen), die Leiter hängt an der Nordwand.
func _build_shaft_cage() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var steel := Color(0.28, 0.27, 0.26)
	var y0 := FLOOR_Y
	var y1 := CEIL_Y
	var hs := SHAFT_HALF
	var mid := (y0 + y1) / 2.0
	var hh := y1 - y0
	_box(st, Vector3(center.x, mid, center.z - hs + 0.05), Vector3(hs * 2.0, hh, 0.1), steel, 0.05, rng)
	_box(st, Vector3(center.x - hs + 0.05, mid, center.z), Vector3(0.1, hh, hs * 2.0), steel, 0.05, rng)
	_box(st, Vector3(center.x + hs - 0.05, mid, center.z), Vector3(0.1, hh, hs * 2.0), steel, 0.05, rng)
	st.generate_normals()
	var mesh := st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.layers = 1 | CATA_LAYER
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = mesh.create_trimesh_shape()
	body.add_child(cs)
	add_child(body)


func _build_deco(rng: RandomNumberGenerator) -> void:
	# Knochen und Schädel (zwei MultiMeshes) in Sackgassen und verstreut
	var spots: Array = []
	for c in dead_ends:
		for k in range(4):
			spots.append(cell_center(c) + Vector3(rng.randf_range(-1.2, 1.2), 0.0, rng.randf_range(-1.2, 1.2)))
	for c in range(N * N):
		if rng.randf() < 0.18:
			spots.append(cell_center(c) + Vector3(rng.randf_range(-1.2, 1.2), 0.0, rng.randf_range(-1.2, 1.2)))
	for k in range(14):
		spots.append(center + Vector3(rng.randf_range(-5.5, 5.5), 0.0, rng.randf_range(-5.5, 5.5)))
	var bone_mm := MultiMesh.new()
	bone_mm.transform_format = MultiMesh.TRANSFORM_3D
	var bm := BoxMesh.new()
	bm.size = Vector3(0.45, 0.07, 0.07)
	bone_mm.mesh = bm
	bone_mm.instance_count = spots.size()
	var skull_mm := MultiMesh.new()
	skull_mm.transform_format = MultiMesh.TRANSFORM_3D
	var sm := SphereMesh.new()
	sm.radius = 0.12
	sm.height = 0.24
	sm.radial_segments = 7
	sm.rings = 4
	skull_mm.mesh = sm
	var skull_n := 0
	var skull_t: Array = []
	for i in range(spots.size()):
		var p: Vector3 = spots[i]
		var t := Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.2, 0.2)), Vector3(p.x, FLOOR_Y + 0.05, p.z))
		bone_mm.set_instance_transform(i, t)
		if rng.randf() < 0.35:
			skull_t.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(1.0, 1.1, 1.2)), Vector3(p.x + 0.2, FLOOR_Y + 0.12, p.z + 0.1)))
	skull_n = skull_t.size()
	skull_mm.instance_count = skull_n
	for i in range(skull_n):
		skull_mm.set_instance_transform(i, skull_t[i])
	var bone_mat := Util.mat(Color(0.78, 0.74, 0.62))
	bone_mat.vertex_color_use_as_albedo = false
	var bmi := MultiMeshInstance3D.new()
	bmi.multimesh = bone_mm
	bmi.material_override = bone_mat
	bmi.layers = 1 | CATA_LAYER
	bmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bmi)
	var smi := MultiMeshInstance3D.new()
	smi.multimesh = skull_mm
	smi.material_override = bone_mat
	smi.layers = 1 | CATA_LAYER
	smi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(smi)
	# Fackeln: ein MultiMesh mit leuchtenden Flammen (nur Licht-Optik, keine echten Lichter)
	var torch_pos: Array = []
	for k in range(16):
		var cx := rng.randi_range(0, N - 1)
		var cy := rng.randi_range(0, N - 1)
		var cc := cell_center(idx(cx, cy))
		torch_pos.append(Vector3(cc.x + 1.45, FLOOR_Y + 2.1, cc.z + 1.45))
	for q in [Vector3(1, 0, 1), Vector3(-1, 0, 1), Vector3(1, 0, -1), Vector3(-1, 0, -1)]:
		torch_pos.append(center + Vector3(q.x * 5.7, 2.1, q.z * 5.7))
	for tp in torch_pos:
		_torch_all.append(tp)
	var fl_mm := MultiMesh.new()
	fl_mm.transform_format = MultiMesh.TRANSFORM_3D
	var fm := BoxMesh.new()
	fm.size = Vector3(0.16, 0.26, 0.16)
	fl_mm.mesh = fm
	fl_mm.instance_count = torch_pos.size()
	for i in range(torch_pos.size()):
		fl_mm.set_instance_transform(i, Transform3D(Basis(), torch_pos[i]))
	var flame := StandardMaterial3D.new()
	flame.albedo_color = Color(1.0, 0.55, 0.15)
	flame.emission_enabled = true
	flame.emission = Color(1.0, 0.5, 0.12)
	flame.emission_energy_multiplier = 3.0
	flame.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var fmi := MultiMeshInstance3D.new()
	fmi.multimesh = fl_mm
	fmi.material_override = flame
	fmi.layers = 1 | CATA_LAYER
	fmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(fmi)
	# Ein schwaches, warmes Licht in der Hub-Mitte
	var hub_l := OmniLight3D.new()
	hub_l.light_color = Color(1.0, 0.6, 0.3)
	hub_l.light_energy = 0.4
	hub_l.omni_range = 9.0
	hub_l.shadow_enabled = false
	hub_l.position = center + Vector3(0, 2.6, 3.0)
	add_child(hub_l)


# ---------- Tunnel zum zweiten Ausgang ----------

func _mm_instance(mesh: Mesh, mat: Material, xf: Array) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xf.size()
	for i in range(xf.size()):
		mm.set_instance_transform(i, xf[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mat
	mi.layers = 1 | CATA_LAYER
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


## Langer gerader Gang von der Südtür des Labyrinths bis unter die Tropfsteinhöhle, dort ein Raum mit Leiterkäfig.
func _build_tunnel(rng: RandomNumberGenerator) -> void:
	var half := float(N) * PITCH / 2.0
	var tz0 := center.z + half            # Innenkante der Südwand des Labyrinths
	var tz1 := ROOM_Z0 - 1.0              # bis zur Nordwand des Raums
	var tlen := tz1 - tz0
	var tmid := (tz0 + tz1) / 2.0
	var wy := FLOOR_Y + H / 2.0
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var stone := Color(0.28, 0.26, 0.23)
	var flo := Color(0.19, 0.17, 0.15)
	var cei := Color(0.2, 0.19, 0.17)
	_box(st, Vector3(TUNNEL_X, FLOOR_Y - 0.5, tmid), Vector3(5.0, 1.0, tlen), flo, 0.0, rng)
	_box(st, Vector3(TUNNEL_X, CEIL_Y + 0.5, tmid), Vector3(5.0, 1.0, tlen), cei, 0.0, rng)
	_box(st, Vector3(TUNNEL_X - 2.0, wy, tmid), Vector3(1.0, H, tlen), stone, 0.12, rng)
	_box(st, Vector3(TUNNEL_X + 2.0, wy, tmid), Vector3(1.0, H, tlen), stone, 0.12, rng)
	# Stützbalken-Pfeiler alle 16 m (Abwechslung für den langen Gang)
	var zz := tz0 + 12.0
	while zz < tz1 - 6.0:
		_box(st, Vector3(TUNNEL_X - 1.35, wy, zz), Vector3(0.3, H, 0.4), Color(0.3, 0.2, 0.12), 0.1, rng)
		_box(st, Vector3(TUNNEL_X + 1.35, wy, zz), Vector3(0.3, H, 0.4), Color(0.3, 0.2, 0.12), 0.1, rng)
		_box(st, Vector3(TUNNEL_X, CEIL_Y - 0.15, zz), Vector3(3.0, 0.3, 0.4), Color(0.3, 0.2, 0.12), 0.1, rng)
		zz += 16.0
	# Raum unter der Höhle
	var rcx := (ROOM_X0 + ROOM_X1) / 2.0
	var rcz := (ROOM_Z0 + ROOM_Z1) / 2.0
	_box(st, Vector3(rcx, FLOOR_Y - 0.5, rcz), Vector3(8.0, 1.0, 9.0), flo, 0.0, rng)
	var hs := SHAFT_HALF
	var hx0 := EXIT_X - hs
	var hx1 := EXIT_X + hs
	var hz0 := EXIT_Z - hs
	var hz1 := EXIT_Z + hs
	var cy := CEIL_Y + 0.5
	_box(st, Vector3(rcx, cy, (ROOM_Z0 - 1.0 + hz0) / 2.0), Vector3(8.0, 1.0, hz0 - (ROOM_Z0 - 1.0)), cei, 0.0, rng)
	_box(st, Vector3(rcx, cy, (hz1 + ROOM_Z1 + 1.0) / 2.0), Vector3(8.0, 1.0, ROOM_Z1 + 1.0 - hz1), cei, 0.0, rng)
	_box(st, Vector3((ROOM_X0 - 1.0 + hx0) / 2.0, cy, EXIT_Z), Vector3(hx0 - (ROOM_X0 - 1.0), 1.0, hs * 2.0), cei, 0.0, rng)
	_box(st, Vector3((hx1 + ROOM_X1 + 1.0) / 2.0, cy, EXIT_Z), Vector3(ROOM_X1 + 1.0 - hx1, 1.0, hs * 2.0), cei, 0.0, rng)
	_box(st, Vector3(ROOM_X0 - 0.5, wy, rcz), Vector3(1.0, H, 9.0), stone, 0.12, rng)
	_box(st, Vector3(ROOM_X1 + 0.5, wy, rcz), Vector3(1.0, H, 9.0), stone, 0.12, rng)
	_box(st, Vector3(rcx, wy, ROOM_Z1 + 0.5), Vector3(8.0, H, 1.0), stone, 0.12, rng)
	var ox0 := TUNNEL_X - (PITCH - WALL_T) / 2.0
	var ox1 := TUNNEL_X + (PITCH - WALL_T) / 2.0
	_box(st, Vector3((ROOM_X0 - 1.0 + ox0) / 2.0, wy, ROOM_Z0 - 0.5), Vector3(ox0 - (ROOM_X0 - 1.0), H, 1.0), stone, 0.12, rng)
	_box(st, Vector3((ox1 + ROOM_X1 + 1.0) / 2.0, wy, ROOM_Z0 - 0.5), Vector3((ROOM_X1 + 1.0) - ox1, H, 1.0), stone, 0.12, rng)
	# Leiterkäfig: Westen, Osten, Süden (Norden zum Tunnel hin offen), Leiter an der Südwand
	var steel := Color(0.28, 0.27, 0.26)
	_box(st, Vector3(hx0 + 0.05, wy, EXIT_Z), Vector3(0.1, H, hs * 2.0), steel, 0.05, rng)
	_box(st, Vector3(hx1 - 0.05, wy, EXIT_Z), Vector3(0.1, H, hs * 2.0), steel, 0.05, rng)
	_box(st, Vector3(EXIT_X, wy, hz1 - 0.05), Vector3(hs * 2.0, H, 0.1), steel, 0.05, rng)
	st.generate_normals()
	var mesh := st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.layers = 1 | CATA_LAYER
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = mesh.create_trimesh_shape()
	body.add_child(cs)
	add_child(body)
	# Fackeln im Tunnel (leuchtende Flammen als ein MultiMesh) und ein paar Knochen
	var torches: Array = []
	var tz := tz0 + 9.0
	var side := 1.0
	while tz < tz1 - 3.0:
		torches.append(Transform3D(Basis(), Vector3(TUNNEL_X + side * 1.38, FLOOR_Y + 2.1, tz)))
		side = -side
		tz += 14.0
	torches.append(Transform3D(Basis(), Vector3(ROOM_X0 + 0.3, FLOOR_Y + 2.1, ROOM_Z0 + 1.5)))
	torches.append(Transform3D(Basis(), Vector3(ROOM_X1 - 0.3, FLOOR_Y + 2.1, ROOM_Z1 - 1.5)))
	for tt in torches:
		_torch_all.append((tt as Transform3D).origin)
	var fm := BoxMesh.new()
	fm.size = Vector3(0.16, 0.26, 0.16)
	var flame := StandardMaterial3D.new()
	flame.albedo_color = Color(1.0, 0.55, 0.15)
	flame.emission_enabled = true
	flame.emission = Color(1.0, 0.5, 0.12)
	flame.emission_energy_multiplier = 3.0
	flame.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mm_instance(fm, flame, torches)
	var bones: Array = []
	for k in range(28):
		var bx := TUNNEL_X + rng.randf_range(-1.2, 1.2)
		var bz := rng.randf_range(tz0 + 3.0, tz1 - 2.0)
		bones.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(bx, FLOOR_Y + 0.05, bz)))
	var bm := BoxMesh.new()
	bm.size = Vector3(0.45, 0.07, 0.07)
	_mm_instance(bm, Util.mat(Color(0.78, 0.74, 0.62)), bones)
	under_rects.append(Rect2(ROOM_X0 - 1.0, tz0 - 0.5, (ROOM_X1 - ROOM_X0) + 2.0, ROOM_Z1 + 1.0 - tz0 + 0.5))
	extra_aabbs.append(AABB(Vector3(ROOM_X0 - 1.0, FLOOR_Y - 1.0, tz0 - 0.5), Vector3(ROOM_X1 - ROOM_X0 + 2.0, H + 2.0, ROOM_Z1 + 1.0 - tz0 + 0.5)))


# ---------- Feinarbeit: Sockel, Gesimse, Fugen, Holzrahmen, Pfützen, Wurzeln, Schutt ----------

const C_PLINTH := Color(0.15, 0.14, 0.125)
const C_MORTAR := Color(0.1, 0.095, 0.09)
const C_BLOCK := Color(0.25, 0.23, 0.2)
const C_TIMBER := Color(0.2, 0.125, 0.07)
const C_MOSS := Color(0.08, 0.15, 0.06)


## Kachel auf einer Wandfläche. u = Versatz entlang der Wand, y = Höhe über dem Boden, side = +1 oder -1 (welche Seite).
func _fb(st: SurfaceTool, p: Vector3, along_x: bool, side: float, u: float, y: float, w: float, h: float, depth: float, col: Color, rng: RandomNumberGenerator) -> void:
	var n := WALL_T / 2.0 + depth / 2.0 - 0.004
	var c := Vector3(0, FLOOR_Y + y, 0)
	var size := Vector3.ONE
	if along_x:
		c.x = p.x + u
		c.z = p.z + side * n
		size = Vector3(w, h, depth)
	else:
		c.x = p.x + side * n
		c.z = p.z + u
		size = Vector3(depth, h, w)
	_box(st, c, size, col, 0.06, rng)


func _tint(c: Color, k: float) -> Color:
	return Color(c.r * k, c.g * k, c.b * k)


func _wall_detail(st: SurfaceTool, p: Vector3, along_x: bool, rng: RandomNumberGenerator, sides: Array) -> void:
	var seg := PITCH - WALL_T
	for side in sides:
		var sd: float = side
		_fb(st, p, along_x, sd, 0.0, 0.18, seg, 0.36, 0.16, C_PLINTH, rng)
		_fb(st, p, along_x, sd, 0.0, H - 0.12, seg, 0.24, 0.12, C_PLINTH, rng)
		_fb(st, p, along_x, sd, 0.0, 1.25, seg, 0.05, 0.03, C_MORTAR, rng)
		_fb(st, p, along_x, sd, 0.0, 2.35, seg, 0.05, 0.03, C_MORTAR, rng)
		for k in range(rng.randi_range(1, 3)):
			_fb(st, p, along_x, sd, rng.randf_range(-1.1, 1.1), rng.randf_range(0.7, 2.9), rng.randf_range(0.5, 1.1), rng.randf_range(0.35, 0.7), 0.05, _tint(C_BLOCK, rng.randf_range(0.75, 1.3)), rng)
		if rng.randf() < 0.16:
			_fb(st, p, along_x, sd, rng.randf_range(-1.0, 1.0), rng.randf_range(1.2, 2.6), 0.04, rng.randf_range(0.7, 1.5), 0.035, Color(0.04, 0.04, 0.04), rng)
		if rng.randf() < 0.32:
			_fb(st, p, along_x, sd, rng.randf_range(-1.0, 1.0), 0.55, rng.randf_range(0.8, 1.6), rng.randf_range(0.3, 0.7), 0.06, _tint(C_MOSS, rng.randf_range(0.8, 1.4)), rng)


## Zackiger Pfützenfleck (glänzend, wirft das Lampenlicht zurück)
func _puddle(pd: SurfaceTool, c: Vector3, r: float, rng: RandomNumberGenerator) -> void:
	var n := 9
	var pts: Array = []
	for k in range(n):
		var a := TAU * float(k) / float(n)
		var rr := r * rng.randf_range(0.7, 1.1)
		pts.append(Vector3(c.x + cos(a) * rr, FLOOR_Y + 0.02, c.z + sin(a) * rr * 0.8))
	pd.set_color(Color(0.04, 0.06, 0.08))
	for k in range(n):
		var q: Vector3 = pts[k]
		var q2: Vector3 = pts[(k + 1) % n]
		for v in [Vector3(c.x, FLOOR_Y + 0.02, c.z), q, q2]:
			pd.set_normal(Vector3.UP)
			pd.add_vertex(v)


func _build_detail() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9137
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pd := SurfaceTool.new()
	pd.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := float(N) * PITCH / 2.0
	var both := [-1.0, 1.0]
	# Pfeiler: Sockel und Kapitell
	for j in range(N + 1):
		for i in range(N + 1):
			var gx := center.x + (float(i - MID) - 0.5) * PITCH
			var gz := center.z + (float(j - MID) - 0.5) * PITCH
			_box(st, Vector3(gx, FLOOR_Y + 0.18, gz), Vector3(WALL_T + 0.2, 0.36, WALL_T + 0.2), C_PLINTH, 0.04, rng)
			_box(st, Vector3(gx, CEIL_Y - 0.12, gz), Vector3(WALL_T + 0.16, 0.24, WALL_T + 0.16), C_PLINTH, 0.04, rng)
	for j in range(N):
		for i in range(N):
			var c := idx(i, j)
			var cc := cell_center(c)
			var hub := is_hub(c) or is_lan(c)
			# Innenwände
			if i < N - 1 and east[c] == 0:
				_wall_detail(st, Vector3(cc.x + PITCH / 2.0, 0, cc.z), false, rng, both)
			if j < N - 1 and south[c] == 0:
				_wall_detail(st, Vector3(cc.x, 0, cc.z + PITCH / 2.0), true, rng, both)
			# Außenwand, nur die Innenseite
			if j == 0:
				_wall_detail(st, Vector3(cc.x, 0, cc.z - PITCH / 2.0), true, rng, [1.0])
			if j == N - 1 and absf(cc.x - TUNNEL_X) > 0.1:
				_wall_detail(st, Vector3(cc.x, 0, cc.z + PITCH / 2.0), true, rng, [-1.0])
			if i == 0:
				_wall_detail(st, Vector3(cc.x - PITCH / 2.0, 0, cc.z), false, rng, [1.0])
			if i == N - 1:
				_wall_detail(st, Vector3(cc.x + PITCH / 2.0, 0, cc.z), false, rng, [-1.0])
			# Boden: Fugenraster (2-m-Platten), ein paar hellere/dunklere Platten
			for o in [-1.0, 1.0]:
				_box(st, Vector3(cc.x, FLOOR_Y + 0.006, cc.z + o), Vector3(PITCH, 0.012, 0.05), C_MORTAR, 0.0, rng)
				_box(st, Vector3(cc.x + o, FLOOR_Y + 0.006, cc.z), Vector3(0.05, 0.012, PITCH), C_MORTAR, 0.0, rng)
			if rng.randf() < 0.45:
				_box(st, Vector3(cc.x, FLOOR_Y + 0.007, cc.z), Vector3(1.9, 0.014, 1.9), _tint(Color(0.19, 0.17, 0.15), rng.randf_range(0.7, 1.35)), 0.0, rng)
			if hub:
				continue
			# Holzrahmen in Durchgängen
			if i < N - 1 and east[c] == 1 and rng.randf() < 0.3:
				var fx := cc.x + PITCH / 2.0
				for o in both:
					_box(st, Vector3(fx, FLOOR_Y + H / 2.0, cc.z + o * 1.35), Vector3(0.5, H, 0.22), C_TIMBER, 0.12, rng)
				_box(st, Vector3(fx, CEIL_Y - 0.4, cc.z), Vector3(0.45, 0.3, 3.0), C_TIMBER, 0.12, rng)
			if j < N - 1 and south[c] == 1 and rng.randf() < 0.3:
				var fz := cc.z + PITCH / 2.0
				for o in both:
					_box(st, Vector3(cc.x + o * 1.35, FLOOR_Y + H / 2.0, fz), Vector3(0.22, H, 0.5), C_TIMBER, 0.12, rng)
				_box(st, Vector3(cc.x, CEIL_Y - 0.4, fz), Vector3(3.0, 0.3, 0.45), C_TIMBER, 0.12, rng)
			# Pfütze, Wurzeln, Schutt
			if rng.randf() < 0.13:
				_puddle(pd, Vector3(cc.x + rng.randf_range(-0.8, 0.8), 0, cc.z + rng.randf_range(-0.8, 0.8)), rng.randf_range(0.5, 1.1), rng)
			if rng.randf() < 0.22:
				for k in range(rng.randi_range(2, 4)):
					var rl := rng.randf_range(0.5, 1.5)
					_box(st, Vector3(cc.x + rng.randf_range(-1.3, 1.3), CEIL_Y - rl / 2.0, cc.z + rng.randf_range(-1.3, 1.3)), Vector3(0.05, rl, 0.05), Color(0.17, 0.11, 0.07), 0.2, rng)
			if rng.randf() < 0.25:
				for k in range(rng.randi_range(2, 4)):
					var rs := rng.randf_range(0.12, 0.38)
					_box(st, Vector3(cc.x + rng.randf_range(-1.3, 1.3), FLOOR_Y + rs / 2.0, cc.z + rng.randf_range(-1.3, 1.3)), Vector3(rs, rs * 0.8, rs * 1.2), _tint(C_BLOCK, rng.randf_range(0.7, 1.1)), 0.1, rng)
	# Hub: Bodenringe um den Schacht
	for rd in [3.0, 4.0, 5.0]:
		var rc := Color(0.1, 0.09, 0.08) if rd != 4.0 else Color(0.27, 0.22, 0.15)
		var rw := 0.14 if rd != 4.0 else 0.08
		_box(st, Vector3(center.x, FLOOR_Y + 0.008, center.z - rd), Vector3(rd * 2.0 + rw, 0.016, rw), rc, 0.0, rng)
		_box(st, Vector3(center.x, FLOOR_Y + 0.008, center.z + rd), Vector3(rd * 2.0 + rw, 0.016, rw), rc, 0.0, rng)
		_box(st, Vector3(center.x - rd, FLOOR_Y + 0.008, center.z), Vector3(rw, 0.016, rd * 2.0 - rw), rc, 0.0, rng)
		_box(st, Vector3(center.x + rd, FLOOR_Y + 0.008, center.z), Vector3(rw, 0.016, rd * 2.0 - rw), rc, 0.0, rng)
	_tunnel_detail(st, pd, rng, center.z + half, ROOM_Z0 - 1.0)
	# Fackelhalter
	for tp in _torch_all:
		var t: Vector3 = tp
		_box(st, Vector3(t.x, t.y - 0.38, t.z), Vector3(0.07, 0.55, 0.07), Color(0.12, 0.09, 0.07), 0.0, rng)
		_box(st, Vector3(t.x, t.y - 0.14, t.z), Vector3(0.22, 0.05, 0.22), Color(0.1, 0.1, 0.1), 0.0, rng)
	st.generate_normals()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.layers = 1 | CATA_LAYER
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var pmat := StandardMaterial3D.new()
	pmat.vertex_color_use_as_albedo = true
	pmat.roughness = 0.05
	pmat.metallic_specular = 1.0
	pmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var pmi := MeshInstance3D.new()
	pmi.mesh = pd.commit()
	pmi.material_override = pmat
	pmi.layers = 1 | CATA_LAYER
	pmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(pmi)
	# Lichtschein um die Fackeln (ein MultiMesh, additiv, immer zur Kamera gedreht)
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(0.5, 0.26, 0.09, 1.0), Color(0.0, 0.0, 0.0, 1.0)])
	grad.offsets = PackedFloat32Array([0.0, 1.0])
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 64
	gt.height = 64
	var hm := StandardMaterial3D.new()
	hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	hm.albedo_texture = gt
	hm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	hm.cull_mode = BaseMaterial3D.CULL_DISABLED
	var q := QuadMesh.new()
	q.size = Vector2(3.0, 3.0)
	var hx: Array = []
	for tp in _torch_all:
		hx.append(Transform3D(Basis(), tp))
	_mm_instance(q, hm, hx)


## Tunnel: Sockel, Gesims, Fugen an beiden Wänden, Bodenraster, Pfützen, Wurzeln, Schutt
func _tunnel_detail(st: SurfaceTool, pd: SurfaceTool, rng: RandomNumberGenerator, tz0: float, tz1: float) -> void:
	var tlen := tz1 - tz0
	var tmid := (tz0 + tz1) / 2.0
	for sx in [-1.0, 1.0]:
		var sg: float = sx
		var fx := TUNNEL_X + sg * 1.5
		_box(st, Vector3(fx - sg * 0.08, FLOOR_Y + 0.18, tmid), Vector3(0.16, 0.36, tlen), C_PLINTH, 0.04, rng)
		_box(st, Vector3(fx - sg * 0.06, CEIL_Y - 0.12, tmid), Vector3(0.12, 0.24, tlen), C_PLINTH, 0.04, rng)
		_box(st, Vector3(fx - sg * 0.015, FLOOR_Y + 1.25, tmid), Vector3(0.03, 0.05, tlen), C_MORTAR, 0.0, rng)
		_box(st, Vector3(fx - sg * 0.015, FLOOR_Y + 2.35, tmid), Vector3(0.03, 0.05, tlen), C_MORTAR, 0.0, rng)
		var zz := tz0 + 1.0
		while zz < tz1 - 1.0:
			if rng.randf() < 0.6:
				_box(st, Vector3(fx - sg * 0.025, FLOOR_Y + rng.randf_range(0.7, 2.9), zz), Vector3(0.05, rng.randf_range(0.35, 0.7), rng.randf_range(0.5, 1.1)), _tint(C_BLOCK, rng.randf_range(0.75, 1.3)), 0.06, rng)
			if rng.randf() < 0.18:
				_box(st, Vector3(fx - sg * 0.03, FLOOR_Y + 0.55, zz + 0.5), Vector3(0.06, rng.randf_range(0.3, 0.7), rng.randf_range(0.8, 1.6)), _tint(C_MOSS, rng.randf_range(0.8, 1.4)), 0.1, rng)
			zz += 2.2
	var z := tz0 + 1.0
	while z < tz1:
		_box(st, Vector3(TUNNEL_X, FLOOR_Y + 0.006, z), Vector3(3.0, 0.012, 0.05), C_MORTAR, 0.0, rng)
		if rng.randf() < 0.07:
			_puddle(pd, Vector3(TUNNEL_X + rng.randf_range(-0.8, 0.8), 0, z), rng.randf_range(0.5, 1.0), rng)
		if rng.randf() < 0.12:
			var rl := rng.randf_range(0.5, 1.4)
			_box(st, Vector3(TUNNEL_X + rng.randf_range(-1.2, 1.2), CEIL_Y - rl / 2.0, z), Vector3(0.05, rl, 0.05), Color(0.17, 0.11, 0.07), 0.2, rng)
		if rng.randf() < 0.1:
			var rs := rng.randf_range(0.12, 0.35)
			_box(st, Vector3(TUNNEL_X + rng.randf_range(-1.2, 1.2), FLOOR_Y + rs / 2.0, z), Vector3(rs, rs * 0.8, rs * 1.2), _tint(C_BLOCK, rng.randf_range(0.7, 1.1)), 0.1, rng)
		z += 2.0
