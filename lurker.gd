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
var _path: Array = []
var _repath: float = 0.0
var _lose_t: float = 0.0
var _step_t: float = 0.0
var _rumble_t: float = 2.0
var _t: float = 0.0


func setup(p_cata: Catacombs) -> void:
	cata = p_cata
	_body = Node3D.new()
	add_child(_body)
	var fur := Color(0.11, 0.075, 0.055)
	var skin := Color(0.07, 0.055, 0.045)
	for sx in [-1.0, 1.0]:
		Util.add_box(_body, Vector3(0.11, 1.35, 0.13), fur.darkened(0.15), Vector3(sx * 0.13, 0.68, 0.0))     # Beine
		var arm := Util.add_box(_body, Vector3(0.08, 1.6, 0.08), skin, Vector3(sx * 0.42, 1.55, -0.05))        # lange Arme
		arm.rotation_degrees.z = sx * 7.0
	var torso := Util.add_sphere(_body, 0.5, fur, Vector3(0, 1.95, 0))
	torso.scale = Vector3(0.62, 1.0, 0.42)
	Util.add_cylinder(_body, 0.06, 0.55, skin, Vector3(0, 2.55, -0.04))        # Hals
	var head := Util.add_sphere(_body, 0.5, fur.lightened(0.05), Vector3(0, HEAD_Y, -0.1))
	head.scale = Vector3(0.5, 0.46, 0.7)
	var snout := Util.add_sphere(_body, 0.5, fur.lightened(0.1), Vector3(0, HEAD_Y - 0.07, -0.34))
	snout.scale = Vector3(0.3, 0.26, 0.34)
	for sx in [-1.0, 1.0]:
		Util.add_box(_body, Vector3(0.045, 0.12, 0.03), Color(0.98, 0.5, 0.08), Vector3(sx * 0.03, HEAD_Y - 0.2, -0.47))   # orange Nagezähne
		Util.add_sphere(_body, 0.045, fur.darkened(0.2), Vector3(sx * 0.14, HEAD_Y + 0.18, 0.0))                           # Ohren
		var eye := Util.add_sphere(_body, 0.05, Color(1, 1, 0.9), Vector3(sx * 0.1, HEAD_Y + 0.05, -0.27))
		var em := eye.material_override as StandardMaterial3D
		em.emission_enabled = true
		em.emission = Color(1.0, 0.95, 0.8)
		em.emission_energy_multiplier = 4.0
		em.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var tail := Util.add_cylinder(_body, 0.045, 1.2, skin, Vector3(0, 0.25, 0.55))     # langer Schwanz
	tail.rotation_degrees.x = 78.0
	_set_layers(_body)


func _set_layers(n: Node) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).layers = 1 | Catacombs.CATA_LAYER
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.get_children():
		_set_layers(c)


func head_pos() -> Vector3:
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


## Ruckeliges, unheimliches Wiegen; beim Jagen geduckt nach vorn gebeugt
func _animate(delta: float, moving: bool) -> void:
	if _body == null:
		return
	var hunt := anim == "hunt"
	var sway := sin(_t * (7.0 if hunt else 3.2)) * (0.08 if moving else 0.02)
	_body.rotation.z = lerpf(_body.rotation.z, sway, minf(delta * 8.0, 1.0))
	_body.rotation.x = lerpf(_body.rotation.x, 0.28 if hunt else 0.0, minf(delta * 4.0, 1.0))
	_body.position.y = absf(sin(_t * (7.0 if hunt else 3.2))) * 0.05 if moving else 0.0
