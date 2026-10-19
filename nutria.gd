class_name Nutria
extends Node3D
## Wildes Nutria: kommt nachts ins Lager, klaut Zutaten aus dem Rucksack, plündert die Kühlbox
## oder raschelt am Zelt. Wer ihm nahe kommt, verscheucht es (es lässt dann die Beute fallen).

enum S { APPROACH, EAT, FLEE }

var main: Node
var state: int = S.APPROACH
var target: Node3D = null
var action: String = "rustle"       # "steal", "rustle"
var carried: String = ""
var eat_t: float = 0.0
var steal_pos: Vector3 = Vector3.ZERO
var life: float = 0.0
var _anim: float = 0.0
var _rustles: int = 0
var _body: Node3D
var flee_dir: Vector3 = Vector3.ZERO
var _ap: AnimationPlayer = null
var _cur_anim: String = ""
# Netz: bei Mitspielern nur Anzeige (Puppe), simuliert wird beim Welt-Verantwortlichen
var puppet: bool = false
var net_pos: Vector3 = Vector3.ZERO
var net_yaw: float = 0.0
var net_anim: String = ""


func setup(p_main: Node, pos: Vector3) -> void:
	main = p_main
	position = pos
	_body = Node3D.new()
	add_child(_body)
	if ResourceLoader.exists("res://assets/fauna/nutria.glb"):
		var inst := (load("res://assets/fauna/nutria.glb") as PackedScene).instantiate() as Node3D
		_body.add_child(inst)
		_ap = _find_ap(inst)
		if _ap != null:
			for n in _ap.get_animation_list():
				_ap.get_animation(n).loop_mode = Animation.LOOP_LINEAR
			_play("Idle")
		Fx.blob_shadow(_body, 0.45)
		_choose_target()
		return
	var fur := Color(0.42, 0.28, 0.16)
	var b := Util.add_sphere(_body, 0.5, fur, Vector3(0, 0.3, 0))
	b.scale = Vector3(0.55, 0.34, 0.34)
	var h := Util.add_sphere(_body, 0.5, fur.lightened(0.05), Vector3(0, 0.34, -0.36))
	h.scale = Vector3(0.3, 0.26, 0.28)
	Util.add_box(_body, Vector3(0.1, 0.05, 0.04), Color(0.95, 0.5, 0.1), Vector3(-0.04, 0.27, -0.5))
	Util.add_box(_body, Vector3(0.1, 0.05, 0.04), Color(0.95, 0.5, 0.1), Vector3(0.04, 0.27, -0.5))
	Util.add_sphere(_body, 0.03, Color.BLACK, Vector3(-0.1, 0.4, -0.5))
	Util.add_sphere(_body, 0.03, Color.BLACK, Vector3(0.1, 0.4, -0.5))
	Util.add_sphere(_body, 0.05, fur.darkened(0.2), Vector3(-0.12, 0.5, -0.32))
	Util.add_sphere(_body, 0.05, fur.darkened(0.2), Vector3(0.12, 0.5, -0.32))
	var tail := Util.add_cylinder(_body, 0.04, 0.5, fur.darkened(0.35), Vector3(0, 0.2, 0.55))
	tail.rotation_degrees.x = 80.0
	for sx in [-1.0, 1.0]:
		for sz in [-0.15, 0.2]:
			Util.add_box(_body, Vector3(0.07, 0.14, 0.09), fur.darkened(0.25), Vector3(sx * 0.14, 0.07, sz))
	_choose_target()


func _find_ap(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n as AnimationPlayer
	for c in n.get_children():
		var r := _find_ap(c)
		if r != null:
			return r
	return null


func _play(a: String) -> void:
	if _ap == null or a == _cur_anim or not _ap.has_animation(a):
		return
	_cur_anim = a
	_ap.play(a, 0.15)


func _choose_target() -> void:
	# Beute: Rucksack mit Zutaten oder offene/volle Kühlbox, sonst am Zelt rascheln
	var cands: Array = []
	for o in Game.placed:
		if not is_instance_valid(o):
			continue
		if o.item_name == "Kiste mit Proviant" and not o.pack.is_empty():
			cands.append(o)
		elif o.item_name == "Kühlbox":
			cands.append(o)
	var fires: Array = Game.placed.filter(func(p): return is_instance_valid(p) and p.item_name == "Feuerschale" and p.burning)
	cands = cands.filter(func(c): return fires.all(func(f): return f.global_position.distance_to(c.global_position) > 6.0))
	if not cands.is_empty():
		target = cands.pick_random()
		action = "steal"
		return
	for t in Game.tents:
		if is_instance_valid(t):
			target = t
			action = "rustle"
			return
	target = null
	action = "leave"


## Naechster Spieler (ich oder ein Mitspieler) - vor dem flieht das Nutria.
func _nearest_player_pos() -> Vector3:
	var best := Vector3(9999, 0, 9999)
	var bd := 1e9
	var player: Node3D = main.player if main != null else null
	if player != null:
		best = player.global_position
		bd = best.distance_to(global_position)
	if Net.instance != null and is_instance_valid(Net.instance):
		for k in Net.instance.avatars.keys():
			var av: Node3D = Net.instance.avatars[k]
			if is_instance_valid(av):
				var d := av.global_position.distance_to(global_position)
				if d < bd:
					bd = d
					best = av.global_position
	return best


func _process(delta: float) -> void:
	if puppet:
		if net_pos != Vector3.ZERO:
			global_position = global_position.lerp(net_pos, minf(delta * 10.0, 1.0))
			rotation.y = lerp_angle(rotation.y, net_yaw, minf(delta * 10.0, 1.0))
		if net_anim != "":
			_play(net_anim)
		return
	life += delta
	_anim += delta * 9.0
	var ppos: Vector3 = _nearest_player_pos()
	var dir := Vector3.ZERO
	var speed := 2.6
	match state:
		S.APPROACH:
			if target == null or not is_instance_valid(target):
				_start_flee(ppos)
			else:
				var tp := target.global_position
				var to := tp - global_position
				to.y = 0
				if to.length() < (1.6 if action == "rustle" else 1.0):
					state = S.EAT
					eat_t = 0.0
					if action == "steal":
						_toast_near(ppos, "Ein Nutria schleicht sich an die Vorräte heran!")
				else:
					dir = to.normalized()
			if global_position.distance_to(ppos) < 4.5 and state == S.APPROACH:
				_start_flee(ppos)
		S.EAT:
			eat_t += delta
			if _ap == null:
				_body.rotation.z = sin(_anim * 1.5) * 0.12
			if action == "rustle":
				if target is Tent:
					(target as Tent).shake()
				if eat_t > 3.5 and _rustles < 2:
					_rustles += 1
					eat_t = 0.0
					_toast_near(ppos, "Es raschelt am Zelt...")
				if _rustles >= 2 and eat_t > 3.0:
					_start_flee(ppos)
			else:
				if eat_t > 2.5:
					_do_steal(ppos)
			if global_position.distance_to(ppos) < 4.0:
				_start_flee(ppos)
		S.FLEE:
			speed = 5.0
			dir = flee_dir
			if carried != "" and (global_position.distance_to(steal_pos) > 14.0 or global_position.distance_to(ppos) < 6.0 and life > 0.0 and global_position.distance_to(steal_pos) > 2.0):
				_drop_loot(ppos)
			if global_position.distance_to(ppos) > 45.0 or global_position.distance_to(Game.camp_center) > 70.0:
				_drop_loot(ppos)
				queue_free()
	if dir != Vector3.ZERO:
		dir = _dry_dir(dir, speed * delta)
	if dir != Vector3.ZERO:
		global_position += dir * speed * delta
		global_position.y = 0.0
		var yaw := atan2(-dir.x, -dir.z)
		rotation.y = lerp_angle(rotation.y, yaw, minf(delta * 8.0, 1.0))
		if _ap == null:
			_body.position.y = absf(sin(_anim)) * 0.05
	if _ap != null:
		if dir != Vector3.ZERO:
			_play("Run" if state == S.FLEE else "Walk")
		elif state == S.EAT:
			_play("Eat")
		else:
			_play("Idle")
	if life > 240.0:
		_drop_loot(ppos)
		queue_free()


## Liegt der Punkt im See? (Nutrias laufen nicht übers Wasser)
func _in_water(p: Vector3) -> bool:
	if main == null or main.get("lake_root") == null:
		return false
	var lp: Vector3 = p - (main.lake_root as Node3D).global_position
	return LakeShape.contains(Vector2(lp.x, lp.z))


## Richtung, die nicht ins Wasser führt: sonst am Ufer entlang ausweichen, im Zweifel stehen bleiben.
func _dry_dir(dir: Vector3, step: float) -> Vector3:
	if not _in_water(global_position + dir * (step + 0.6)):
		return dir
	for ang in [0.45, -0.45, 0.9, -0.9, 1.35, -1.35]:
		var d := dir.rotated(Vector3.UP, ang)
		if not _in_water(global_position + d * (step + 0.6)):
			return d
	return Vector3.ZERO


func _toast_near(_ppos: Vector3, msg: String) -> void:
	if main.player != null and global_position.distance_to(main.player.global_position) < 35.0:
		main.player.toast(msg, 3.0)
	if Net.instance != null and is_instance_valid(Net.instance):
		Net.instance.send_toast_near(global_position, msg)


func _do_steal(ppos: Vector3) -> void:
	steal_pos = global_position
	if target != null and is_instance_valid(target):
		if target.item_name == "Kiste mit Proviant":
			carried = target.steal_one()
			if carried != "":
				_toast_near(ppos, "Das Nutria hat %s aus der Kiste geklaut! Verjag es!" % carried)
		else:
			_toast_near(ppos, "Das Nutria knabbert an den Würstchen in der Kühlbox. Frechheit!")
	_start_flee(ppos)


func _start_flee(ppos: Vector3) -> void:
	state = S.FLEE
	var away := global_position - ppos
	away.y = 0
	if away.length() < 1.0:
		away = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
	flee_dir = (away.normalized() + Vector3(randf_range(-0.4, 0.4), 0, randf_range(-0.4, 0.4))).normalized()


func _drop_loot(ppos: Vector3) -> void:
	if carried == "":
		return
	var it := Item.new().setup(carried, 0.5, Vector3(0.18, 0.14, 0.18), Game.INGREDIENT_COLORS[carried])
	main.add_child(it)
	it.global_position = global_position + Vector3(0, 0.5, 0)
	_toast_near(ppos, "Das Nutria hat %s fallen lassen!" % carried)
	carried = ""
