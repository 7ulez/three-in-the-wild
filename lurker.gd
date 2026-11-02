class_name Lurker
extends Node3D
## Das Wesen der Katakomben: ein riesiges, dürres Nutria. Man darf ihm nicht in die Augen sehen
## (siehe GazeWatcher). Es streift durchs Labyrinth, hört Schritte und wird vom Licht der Kopflampe
## angelockt. Simuliert wird es beim Welt-Verantwortlichen, bei den anderen ist es eine Puppe.

enum S { WANDER, HUNT }

const WANDER_SPEED: float = 1.5
const HUNT_SPEED: float = 4.2          # Gehen ist 4.5, Rennen 7.0: wer rennt, entkommt
const HEAD_Y: float = 2.75
const HEAR_NEAR: float = 14.0          # so nah hört es dich immer
const HEAR_LAMP: float = 24.0          # mit Kopflampe schon weiter weg

var cata: Catacombs
var puppet: bool = false
var net_pos: Vector3 = Vector3.ZERO
var net_yaw: float = 0.0
var net_anim: String = ""
var state: int = S.WANDER
var anim: String = "walk"

var _body: Node3D
var _hip: Node3D
var _torso: Node3D
var _neck: Node3D
var _head: Node3D
var _jaw: Node3D
var _legs: Array = []         # [{"thigh": Node3D, "knee": Node3D}]
var _arms: Array = []         # [{"sh": Node3D, "elbow": Node3D, "hand": Node3D}]
var _tail: Array = []
var _eye_light: OmniLight3D
var _vmat: StandardMaterial3D
var _path: Array = []
var _repath: float = 0.0
var _lose_t: float = 0.0
var _step_t: float = 0.0
var _rumble_t: float = 2.0
var _t: float = 0.0
var _q: float = -1.0          # Zeitstufe: Stop-Motion mit 14 Bildern pro Sekunde
var _tw_t: float = 0.0
var _tw_roll: float = 0.0
var _tw_yaw: float = 0.0
var _hyaw: float = 0.0
var _hpitch: float = 0.0


## Dünnes, riesiges Nutria: kohlschwarzes Fell, sichtbare Rippen, endlos lange Arme mit Fingern,
## bleiches Gesicht mit grossen leuchtenden Augen, orange Nagezähne. Bewegt sich ruckartig (Stop-Motion),
## und der Kopf folgt dir immer mit dem Blick.
func setup(p_cata: Catacombs) -> void:
	cata = p_cata
	_body = Node3D.new()
	add_child(_body)
	_vmat = StandardMaterial3D.new()
	_vmat.vertex_color_use_as_albedo = true
	_vmat.roughness = 1.0
	var fur := Color(0.085, 0.06, 0.045)
	var fur2 := Color(0.15, 0.11, 0.08)
	var skin := Color(0.5, 0.53, 0.46)
	var bone := Color(0.82, 0.8, 0.7)
	var orange := Color(0.98, 0.5, 0.06)
	_hip = Node3D.new()
	_hip.position = Vector3(0, 1.52, 0)
	_body.add_child(_hip)
	# Beine: Oberschenkel, Knie, Unterschenkel mit Fuss und Krallen
	for sx in [-1.0, 1.0]:
		var thigh := Node3D.new()
		thigh.position = Vector3(sx * 0.15, 0, 0)
		_hip.add_child(thigh)
		Util.add_box(thigh, Vector3(0.12, 0.78, 0.13), fur, Vector3(0, -0.39, 0))
		var knee := Node3D.new()
		knee.position = Vector3(0, -0.78, 0)
		thigh.add_child(knee)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_qbox(st, Vector3(0, -0.36, 0), Vector3(0.085, 0.72, 0.09), fur)
		_qbox(st, Vector3(0, -0.74, -0.1), Vector3(0.13, 0.05, 0.34), skin.darkened(0.3))
		for cx in [-0.04, 0.0, 0.04]:
			_qbox(st, Vector3(cx, -0.74, -0.32), Vector3(0.015, 0.02, 0.16), bone)
		_mesh_to(knee, st)
		_legs.append({"thigh": thigh, "knee": knee})
	# Oberkörper: knochiger Brustkorb, Wirbelsäule, zerfetzte Fellstreifen
	_torso = Node3D.new()
	_hip.add_child(_torso)
	var tm := Util.add_sphere(_torso, 0.5, fur, Vector3(0, 0.62, 0))
	tm.scale = Vector3(0.62, 1.25, 0.42)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var dst := SurfaceTool.new()
	dst.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in range(6):
		_qbox(dst, Vector3(0, 0.45 + k * 0.115, -0.205 + k * 0.004), Vector3(0.44 - k * 0.02, 0.022, 0.03), bone)
	for k in range(8):
		_qbox(dst, Vector3(0, 0.12 + k * 0.14, 0.2), Vector3(0.05, 0.07, 0.05), bone)
	for k in range(14):
		var ang := rng.randf() * TAU
		var rx := cos(ang) * 0.3
		var rz := sin(ang) * 0.2
		var ln := rng.randf_range(0.4, 0.8)
		_qbox(dst, Vector3(rx, 0.95 - ln / 2.0 - rng.randf() * 0.3, rz), Vector3(0.05, ln, 0.02), fur2, Basis(Vector3(0, 0, 1), rng.randf_range(-0.25, 0.25)))
	_mesh_to(_torso, dst)
	# Arme: so lang, dass die Finger fast den Boden streifen
	for sx in [-1.0, 1.0]:
		var sh := Node3D.new()
		sh.position = Vector3(sx * 0.34, 1.12, 0)
		_torso.add_child(sh)
		Util.add_box(sh, Vector3(0.09, 0.95, 0.09), fur, Vector3(0, -0.475, 0))
		var elbow := Node3D.new()
		elbow.position = Vector3(0, -0.95, 0)
		sh.add_child(elbow)
		Util.add_box(elbow, Vector3(0.065, 0.98, 0.065), skin.darkened(0.45), Vector3(0, -0.49, 0))
		var hand := Node3D.new()
		hand.position = Vector3(0, -0.98, 0)
		elbow.add_child(hand)
		var hst := SurfaceTool.new()
		hst.begin(Mesh.PRIMITIVE_TRIANGLES)
		_qbox(hst, Vector3(0, -0.065, 0), Vector3(0.09, 0.13, 0.035), skin.darkened(0.3))
		var fi := 0
		for fx in [-0.035, -0.012, 0.012, 0.035]:
			var fl := 0.4 + float(fi % 2) * 0.07 + rng.randf() * 0.04
			_qbox(hst, Vector3(fx, -0.13 - fl / 2.0, 0), Vector3(0.013, fl, 0.013), bone, Basis(Vector3(0, 0, 1), fx * 1.6))
			fi += 1
		_mesh_to(hand, hst)
		_arms.append({"sh": sh, "elbow": elbow, "hand": hand, "side": sx})
	# Hals und Kopf
	_neck = Node3D.new()
	_neck.position = Vector3(0, 1.2, -0.03)
	_neck.rotation.x = -0.4
	_torso.add_child(_neck)
	Util.add_cylinder(_neck, 0.055, 0.62, skin.darkened(0.35), Vector3(0, 0.31, 0))
	_head = Node3D.new()
	_head.position = Vector3(0, 0.64, 0)
	_neck.add_child(_head)
	var skull := Util.add_sphere(_head, 0.5, skin, Vector3.ZERO)
	skull.scale = Vector3(0.34, 0.32, 0.5)
	var snout := Util.add_sphere(_head, 0.5, skin.lightened(0.06), Vector3(0, -0.05, -0.3))
	snout.scale = Vector3(0.2, 0.18, 0.3)
	Util.add_sphere(_head, 0.035, Color(0.12, 0.05, 0.05), Vector3(0, -0.02, -0.46))
	_jaw = Node3D.new()
	_jaw.position = Vector3(0, -0.1, -0.12)
	_head.add_child(_jaw)
	var jst := SurfaceTool.new()
	jst.begin(Mesh.PRIMITIVE_TRIANGLES)
	_qbox(jst, Vector3(0, 0, -0.17), Vector3(0.16, 0.045, 0.34), skin.darkened(0.25))
	for k in range(5):
		for sx in [-1.0, 1.0]:
			_qbox(jst, Vector3(sx * 0.065, 0.04, -0.07 - k * 0.06), Vector3(0.011, 0.05, 0.011), bone)
	_mesh_to(_jaw, jst)
	var ust := SurfaceTool.new()
	ust.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in range(6):
		for sx in [-1.0, 1.0]:
			_qbox(ust, Vector3(sx * 0.07, -0.13, -0.15 - k * 0.05), Vector3(0.012, 0.055, 0.012), bone)
	for sx in [-1.0, 1.0]:
		_qbox(ust, Vector3(sx * 0.032, -0.2, -0.47), Vector3(0.05, 0.17, 0.035), orange)      # die Nagezähne
	for side2 in [-1.0, 1.0]:
		for wk in range(3):
			_qbox(ust, Vector3(side2 * 0.26, -0.06 + wk * 0.025, -0.4), Vector3(0.5, 0.005, 0.005), bone.darkened(0.2), Basis(Vector3.UP, side2 * (0.25 + wk * 0.18)))
	_mesh_to(_head, ust)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(0.85, 1.0, 0.75)
	glow.emission_enabled = true
	glow.emission = Color(0.8, 1.0, 0.65)
	glow.emission_energy_multiplier = 5.0
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for sx in [-1.0, 1.0]:
		var sock := Util.add_sphere(_head, 0.085, Color(0.02, 0.02, 0.02), Vector3(sx * 0.125, 0.05, -0.2))
		sock.scale = Vector3(1.0, 1.0, 0.6)
		var eye := Util.add_sphere(_head, 0.055, Color.WHITE, Vector3(sx * 0.125, 0.05, -0.235))
		eye.material_override = glow
		Util.add_sphere(_head, 0.02, Color.BLACK, Vector3(sx * 0.125, 0.05, -0.285)).material_override = Util.mat(Color.BLACK)
		var ear := Util.add_sphere(_head, 0.06, fur2, Vector3(sx * 0.15, 0.2, 0.08))
		ear.scale = Vector3(1.0, 1.4, 0.4)
	_eye_light = OmniLight3D.new()
	_eye_light.light_color = Color(0.7, 1.0, 0.6)
	_eye_light.light_energy = 0.35
	_eye_light.omni_range = 4.5
	_eye_light.shadow_enabled = false
	_eye_light.position = Vector3(0, 0.05, -0.4)
	_head.add_child(_eye_light)
	# Langer, peitschender Schwanz aus fünf Gliedern
	var parent: Node3D = _hip
	for k in range(5):
		var seg := Node3D.new()
		seg.position = Vector3(0, 0.05, 0.12) if k == 0 else Vector3(0, -0.44, 0)
		seg.rotation.x = -0.9 if k == 0 else -0.2
		parent.add_child(seg)
		Util.add_cylinder(seg, 0.045 - k * 0.007, 0.46, skin.darkened(0.5), Vector3(0, -0.22, 0))
		_tail.append(seg)
		parent = seg
	_set_layers(_body)


## Box mit beliebiger Drehung in einen SurfaceTool (Vertexfarbe, flache Flächen)
func _qbox(st: SurfaceTool, c: Vector3, size: Vector3, col: Color, rot: Basis = Basis()) -> void:
	var h := size / 2.0
	var v: Array = []
	for z in [-1.0, 1.0]:
		for pair in [[-1.0, -1.0], [1.0, -1.0], [1.0, 1.0], [-1.0, 1.0]]:
			v.append(c + rot * Vector3(pair[0] * h.x, pair[1] * h.y, z * h.z))
	var faces := [[0, 3, 2, 1], [5, 6, 7, 4], [4, 7, 3, 0], [1, 2, 6, 5], [3, 7, 6, 2], [4, 0, 1, 5]]
	for f in faces:
		st.set_smooth_group(-1)
		st.set_color(col)
		for t in [0, 2, 1, 0, 3, 2]:
			st.add_vertex(v[f[t]])


func _mesh_to(parent: Node3D, st: SurfaceTool) -> void:
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _vmat
	parent.add_child(mi)


func _set_layers(n: Node) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).layers = 1 | Catacombs.CATA_LAYER
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.get_children():
		_set_layers(c)


## Augenhöhe: dorthin muss man schauen, um ihm in die Augen zu sehen
func head_pos() -> Vector3:
	if _head != null and _head.is_inside_tree():
		return _head.global_position + _head.global_transform.basis * Vector3(0, 0.05, -0.2)
	return global_position + Vector3(0, HEAD_Y + 0.05, 0)


## Startet weit weg vom Spieler (mindestens 8 Zellen)
func place_far_from(p: Vector3) -> void:
	var pc := cata.cell_of(p)
	var best := -1
	var bd := -1
	var tries := 0
	while tries < 60:
		tries += 1
		var c := randi() % (Catacombs.N * Catacombs.N)
		if cata.is_hub(c):
			continue
		var d := absi(c % Catacombs.N - pc % Catacombs.N) + absi(c / Catacombs.N - pc / Catacombs.N) if pc >= 0 else 20
		if d > bd:
			bd = d
			best = c
		if d >= 10:
			break
	global_position = cata.cell_center(best if best >= 0 else 0)


func _process(delta: float) -> void:
	_t += delta
	if puppet:
		if net_pos != Vector3.ZERO:
			global_position = global_position.lerp(net_pos, minf(delta * 10.0, 1.0))
			rotation.y = lerp_angle(rotation.y, net_yaw, minf(delta * 10.0, 1.0))
		anim = net_anim
		_animate(delta, global_position.distance_to(net_pos) > 0.05)
		return
	var targets := Bunker.underground_targets()
	var near_d := 1e9
	var near_p := Vector3.ZERO
	var hear := false
	for t in targets:
		var d: float = (t["p"] as Vector3).distance_to(global_position)
		if d < near_d:
			near_d = d
			near_p = t["p"]
			hear = d < (HEAR_LAMP if t["lamp"] else HEAR_NEAR)
	if hear:
		state = S.HUNT
		_lose_t = 0.0
	elif state == S.HUNT:
		_lose_t += delta
		if _lose_t > 6.0:
			state = S.WANDER
			_path.clear()
	anim = "hunt" if state == S.HUNT else "walk"
	_repath -= delta
	var speed := WANDER_SPEED
	if state == S.HUNT and not targets.is_empty():
		speed = HUNT_SPEED
		if _repath <= 0.0:
			_repath = 0.4
			_path = cata.path(cata.cell_of(global_position), cata.cell_of(near_p))
			if _path.is_empty():
				_path = [-2]          # gleiche Zelle: direkt auf den Spieler zu
	else:
		if _path.is_empty():
			_pick_wander()
	var goal := Vector3.ZERO
	var has_goal := false
	if not _path.is_empty():
		var wp: int = _path[0]
		if wp == -2:
			goal = Vector3(near_p.x, global_position.y, near_p.z)
			if _repath <= 0.0 or global_position.distance_to(goal) < 0.3:
				_path.clear()
		else:
			goal = cata.cell_center(wp)
		has_goal = true
	var moving := false
	if has_goal:
		var to := goal - global_position
		to.y = 0.0
		if to.length() < 0.35 and not _path.is_empty() and _path[0] != -2:
			_path.pop_front()
		else:
			var dir := to.normalized()
			global_position += dir * speed * delta
			global_position.y = Catacombs.FLOOR_Y
			rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), minf(delta * 6.0, 1.0))
			moving = true
	_animate(delta, moving)
	# Geräusche: schwere Schritte und ein tiefes Grollen
	if moving:
		_step_t -= delta
		if _step_t <= 0.0:
			_step_t = 0.55 if state == S.WANDER else 0.34
			Sfx.play("step_gravel", global_position, 3.0, 0.5)
	_rumble_t -= delta
	if _rumble_t <= 0.0:
		_rumble_t = randf_range(5.0, 11.0)
		Sfx.play("rumble", global_position, -4.0, 0.7)


func _pick_wander() -> void:
	var here := cata.cell_of(global_position)
	for k in range(6):
		var c := randi() % (Catacombs.N * Catacombs.N)
		if randf() < 0.3:
			c = Catacombs.idx(Catacombs.MID + randi_range(-1, 1), Catacombs.MID + randi_range(-1, 1))   # gern auch mal zum Hub
		var p := cata.path(here, c)
		if not p.is_empty():
			_path = p
			return


## Stop-Motion: die Pose ändert sich nur 14 Mal pro Sekunde, das wirkt ruckelig und falsch.
## Beim Jagen rennt es tief geduckt mit ausgestreckten Armen und klapperndem Kiefer.
func _animate(delta: float, moving: bool) -> void:
	if _body == null or _hip == null:
		return
	var q := floorf(_t * 14.0) / 14.0
	if q == _q:
		return
	_q = q
	var hunt := anim == "hunt"
	var amp := 1.0 if moving else 0.0
	var ph := q * (9.5 if hunt else 3.4)
	_hip.position.y = 1.52 - (0.34 if hunt and moving else 0.0) - absf(sin(ph)) * (0.07 if hunt else 0.03) * amp
	_torso.rotation.x = -((0.8 if hunt else 0.16) if moving else 0.12 + sin(q * 1.3) * 0.02)
	for i in range(2):
		var s := sin(ph + (0.0 if i == 0 else PI))
		var lg: Dictionary = _legs[i]
		(lg["thigh"] as Node3D).rotation.x = s * (0.95 if hunt else 0.3) * amp + (0.45 if hunt and moving else 0.0)
		(lg["knee"] as Node3D).rotation.x = -(maxf(0.0, -s) * (1.3 if hunt else 0.5) * amp + (0.55 if hunt and moving else 0.06))
		var ar: Dictionary = _arms[i]
		var side: float = ar["side"]
		if hunt and moving:
			(ar["sh"] as Node3D).rotation.x = 1.45 + s * 0.35
			(ar["sh"] as Node3D).rotation.z = side * 0.18
			(ar["elbow"] as Node3D).rotation.x = 0.35
		else:
			(ar["sh"] as Node3D).rotation.x = -s * 0.22 * amp + 0.04
			(ar["sh"] as Node3D).rotation.z = side * (0.07 + sin(q * 1.7 + i) * 0.02)
			(ar["elbow"] as Node3D).rotation.x = 0.12 + sin(q * 6.0 + float(i) * 2.0) * 0.05
		(ar["hand"] as Node3D).rotation.x = sin(q * 9.0 + float(i)) * 0.12
	# Kopf: schaut dir immer ins Gesicht, dazu zuckt er ab und zu schief
	_tw_t -= 1.0 / 14.0
	if _tw_t <= 0.0:
		_tw_t = randf_range(0.3, 1.5)
		_tw_roll = randf_range(-0.55, 0.55) if randf() < 0.65 else 0.0
		_tw_yaw = randf_range(-0.5, 0.5)
	var want_yaw := _tw_yaw
	var want_pitch := 0.1
	var viewer: Node3D = Bunker.instance.main.get("player") if Bunker.instance != null and Bunker.instance.main != null else null
	if viewer != null and viewer.global_position.y < -10.0 and viewer.global_position.distance_to(global_position) < 28.0:
		var lp := _body.to_local(viewer.global_position + Vector3(0, 1.55, 0))
		want_yaw = clampf(atan2(-lp.x, -lp.z), -1.6, 1.6)
		want_pitch = clampf(atan2(lp.y - 2.9, Vector2(lp.x, lp.z).length()), -0.75, 0.75)
	_hyaw = lerp_angle(_hyaw, want_yaw, 0.6)
	_hpitch = lerpf(_hpitch, want_pitch, 0.6)
	_head.rotation = Vector3(_hpitch + 0.4 - (0.5 if hunt and moving else 0.0), _hyaw, _tw_roll * (0.4 if hunt else 1.0))
	_jaw.rotation.x = -((0.55 + sin(q * 28.0) * 0.2) if hunt else (0.06 + (0.25 if _tw_t < 0.12 else 0.0)))
	for k in range(_tail.size()):
		var sg := _tail[k] as Node3D
		sg.rotation.z = sin(q * (8.0 if hunt else 2.6) - float(k) * 0.9) * (0.45 if hunt else 0.25)
	if _eye_light != null:
		_eye_light.light_energy = 0.35 + (0.4 if randf() < 0.12 else 0.0)
