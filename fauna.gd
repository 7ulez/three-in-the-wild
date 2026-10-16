class_name Fauna
extends Node3D
## Tiere im Spiel: Enten und Fische im See, Frösche am Ufer, Rehe und Hasen im Wald, Vögel am Himmel,
## nachts Glühwürmchen. Alles Low-Poly und per Code gebaut.

var main: Node
var player: Node3D
var lake_off: Vector3 = Vector3(0, 0, 15)
var animals: Array = []
var fireflies: Array = []
var _fish_t: float = 8.0
var _t: float = 0.0


func start(p_main: Node) -> void:
	main = p_main
	lake_off = (main.lake_root as Node3D).global_position
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	for i in range(5):
		_add("duck", _lake_point(rng, 0.8))
	for i in range(2):
		_add("swan", _lake_point(rng, 0.7))
	for i in range(4):
		_add("frog", _shore_point(rng))
	for i in range(4):
		_add("deer", _forest_point(rng))
	for i in range(6):
		_add("hare", _meadow_point(rng))
	for i in range(4):
		_add("bird", Vector3(rng.randf_range(-40, 40), 0, rng.randf_range(-90, -10)))
	for i in range(26):
		var fl := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.04
		sm.height = 0.08
		sm.radial_segments = 4
		sm.rings = 2
		fl.mesh = sm
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(0.85, 1.0, 0.35)
		fl.material_override = m
		var sp := _shore_point(rng) + Vector3(rng.randf_range(-3, 3), 0, rng.randf_range(-3, 3))
		fl.position = sp + Vector3(0, rng.randf_range(0.6, 1.8), 0)
		fl.set_meta("base", fl.position)
		fl.set_meta("ph", rng.randf() * TAU)
		fl.visible = false
		add_child(fl)
		fireflies.append(fl)


func _in_lake(world: Vector3, factor: float = 1.0) -> bool:
	var lp := world - lake_off
	var v := Vector2(lp.x, lp.z)
	if factor == 1.0:
		return LakeShape.contains(v)
	return LakeShape.contains(LakeShape.CENTER + (v - LakeShape.CENTER) / factor)


func _lake_point(rng: RandomNumberGenerator, factor: float) -> Vector3:
	for i in range(200):
		var v := LakeShape.CENTER + Vector2(rng.randf_range(-24, 24), rng.randf_range(-15, 15))
		if LakeShape.contains(LakeShape.CENTER + (v - LakeShape.CENTER) / factor):
			return Vector3(v.x, 0.0, v.y) + lake_off
	return Vector3(0, 0, -35) + lake_off


func _shore_point(rng: RandomNumberGenerator) -> Vector3:
	var a := rng.randf() * TAU
	var dir := Vector2(cos(a), sin(a))
	var r := 8.0
	while r < 60.0 and LakeShape.contains(LakeShape.CENTER + dir * r * Vector2(1.0, 0.66)):
		r += 0.4
	var v := LakeShape.CENTER + dir * (r + 0.5) * Vector2(1.0, 0.66)
	return Vector3(v.x, 0.0, v.y) + lake_off


func _forest_point(rng: RandomNumberGenerator) -> Vector3:
	for i in range(300):
		var p := Vector3(rng.randf_range(-60, 60), 0, rng.randf_range(-100, -20))
		if not main.call("_tree_blocked", p):
			return p
	return Vector3(-45, 0, -60)


func _meadow_point(rng: RandomNumberGenerator) -> Vector3:
	for i in range(300):
		var p := Vector3(rng.randf_range(-45, 45), 0, rng.randf_range(-10, 45))
		if not _in_lake(p, 1.15):
			return p
	return Vector3(20, 0, 25)


func _add(kind: String, pos: Vector3) -> void:
	var a := Animal.new()
	add_child(a)
	a.setup(self, kind)
	a.global_position = pos
	a.home = pos
	animals.append(a)


## Vom Netz: Ein Mitspieler hat ein Tier erschossen. Das nächste lebende Tier gleicher Art in der Nähe
## stirbt hier ebenfalls; gibt es keins (jeder Spieler simuliert die Tiere für sich), entsteht dort ein totes.
func kill_near(kind: String, pos: Vector3) -> void:
	var best: Animal = null
	var bd := 18.0
	for a in animals:
		if not is_instance_valid(a) or a.dead or a.kind != kind:
			continue
		var d: float = a.global_position.distance_to(pos)
		if d < bd:
			bd = d
			best = a
	if best == null:
		_add(kind, pos)
		best = animals[animals.size() - 1]
		best.global_position = pos
	best.die()


func _process(delta: float) -> void:
	_t += delta
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("local_player") as Node3D
	var night := Game.is_night()
	for fl in fireflies:
		var f: MeshInstance3D = fl
		f.visible = night
		if night:
			var b: Vector3 = f.get_meta("base")
			var ph: float = f.get_meta("ph")
			f.position = b + Vector3(sin(_t * 0.7 + ph) * 0.8, sin(_t * 1.3 + ph * 2.0) * 0.3, cos(_t * 0.5 + ph) * 0.8)
	_fish_t -= delta
	if _fish_t <= 0.0:
		_fish_t = randf_range(10.0, 28.0)
		_fish_jump()


func _fish_jump() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var p := _lake_point(rng, 0.85)
	var fish := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.45, 0.13, 0.1)
	fish.mesh = bm
	fish.material_override = Util.mat(Color(0.7, 0.72, 0.65))
	add_child(fish)
	fish.global_position = p
	var dir := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
	fish.look_at(fish.global_position + dir, Vector3.UP)
	var tw := create_tween()
	tw.tween_method(func(t: float) -> void:
		fish.global_position = p + dir * t * 1.2 + Vector3(0, sin(t * PI) * 0.9, 0)
		fish.rotation.x = cos(t * PI) * 0.8, 0.0, 1.0, 0.8)
	tw.tween_callback(func() -> void:
		Sfx.play("splash_small", p, -2.0)
		Fx.ripple(self, fish.global_position, 1.1)
		Fx.ripple(self, fish.global_position, 0.7, 0.25)
		fish.queue_free())
	Sfx.play("splash_small", p, -4.0)
	Fx.ripple(self, p, 0.9)


class Animal extends Node3D:
	var fauna: Fauna
	var kind: String = ""
	var target: Vector3 = Vector3.ZERO
	var wait: float = 0.0
	var speed: float = 1.0
	var _t: float = 0.0
	var hidden_until: float = 0.0
	var body: Node3D
	var wing_l: Node3D
	var wing_r: Node3D
	var orbit_c: Vector3
	var orbit_r: float = 10.0
	var orbit_a: float = 0.0
	var hop: float = 0.0
	var _snd_cd: float = 0.0
	var ap: AnimationPlayer = null
	var _cur: String = ""
	var dead: bool = false
	var home: Vector3 = Vector3.ZERO

	## Trefferzone (Mittelpunkt über dem Boden und Radius) für das Luftgewehr
	func hit_center_y() -> float:
		match kind:
			"deer": return 0.95
			"hare": return 0.22
			"duck": return 0.18
			"swan": return 0.4
			"frog": return 0.06
		return 0.0

	func hit_radius() -> float:
		match kind:
			"deer": return 0.65
			"hare": return 0.3
			"duck": return 0.3
			"swan": return 0.5
			"frog": return 0.18
		return 0.3

	func display_name() -> String:
		match kind:
			"deer": return "Reh"
			"hare": return "Hase"
			"duck": return "Ente"
			"swan": return "Schwan"
			"frog": return "Frosch"
		return "Vogel"

	## Abgeschossen: kippt um, bleibt kurz liegen und kommt später als neues Tier wieder.
	## Blutlache unter dem toten Tier: mehrere überlappende, flache Scheiben, die langsam größer werden
	func _blood(delay: float) -> void:
		var space := get_world_3d().direct_space_state
		var q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 1.5, 0), global_position + Vector3(0, -40.0, 0))
		q.collision_mask = 1
		var hit := space.intersect_ray(q)
		var gp: Vector3 = hit["position"] if not hit.is_empty() else Vector3(global_position.x, 0.0, global_position.z)
		var r := clampf(hit_radius() * 1.4, 0.25, 1.0)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.28, 0.0, 0.01, 0.95)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.roughness = 0.22
		mat.metallic_specular = 0.4
		var root := Node3D.new()
		root.top_level = true
		root.scale = Vector3(0.05, 1.0, 0.05)
		fauna.add_child(root)
		root.global_position = gp + Vector3(randf_range(-0.05, 0.05), 0.07, randf_range(-0.05, 0.05))
		for i in range(4):
			var mi := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			var rr := r * (1.0 if i == 0 else randf_range(0.45, 0.75))
			cm.top_radius = rr
			cm.bottom_radius = rr
			cm.height = 0.006
			cm.radial_segments = 14
			mi.mesh = cm
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.position = Vector3(randf_range(-0.3, 0.3) * r, 0.002 * i, randf_range(-0.3, 0.3) * r) if i > 0 else Vector3.ZERO
			mi.scale = Vector3(randf_range(0.8, 1.25), 1.0, randf_range(0.8, 1.25))
			root.add_child(mi)
		var tw := root.create_tween()
		tw.tween_interval(delay)
		tw.tween_property(root, "scale", Vector3.ONE, 3.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_interval(70.0)
		tw.tween_property(mat, "albedo_color:a", 0.0, 8.0)
		tw.tween_callback(root.queue_free)

	func die() -> void:
		if dead:
			return
		dead = true
		if ap != null:
			ap.stop()
		fauna.animals.erase(self)
		visible = true
		var tw := create_tween()
		if kind == "bird":
			tw.tween_property(self, "global_position:y", 0.1, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.parallel().tween_property(self, "rotation:z", 2.6, 0.9)
		else:
			tw.tween_property(body, "rotation:z", deg_to_rad(88.0) * (1.0 if randf() < 0.5 else -1.0), 0.35).set_trans(Tween.TRANS_QUAD)
		match kind:
			"duck": Sfx.play("quack", global_position, 0.0, 0.7)
			"swan": Sfx.play("quack", global_position, 0.0, 0.45)
			"frog": Sfx.play("croak", global_position, -2.0, 1.4)
			_: Sfx.play("thunk", global_position, 0.0, 0.8)
		_blood(0.9 if kind == "bird" else 0.35)
		var f := fauna
		var k := kind
		var spawn := home if home != Vector3.ZERO else global_position
		get_tree().create_timer(25.0).timeout.connect(func() -> void:
			if is_instance_valid(self):
				queue_free()
			if is_instance_valid(f):
				f.get_tree().create_timer(20.0).timeout.connect(func() -> void:
					if is_instance_valid(f):
						f._add(k, spawn)))

	func setup(f: Fauna, k: String) -> void:
		fauna = f
		kind = k
		_t = randf() * 10.0
		body = Node3D.new()
		add_child(body)
		match kind:
			"duck":
				if ResourceLoader.exists("res://assets/fauna/ente.glb"):
					var dk := (load("res://assets/fauna/ente.glb") as PackedScene).instantiate() as Node3D
					dk.scale = Vector3.ONE * 1.25
					_darken(dk, 0.15)
					dk.position.y = 0.03
					body.add_child(dk)
					speed = 0.7
					target = global_position
					return
				Util.add_sphere(body, 0.22, Color(0.55, 0.4, 0.25)).scale = Vector3(1.0, 0.7, 1.4)
				Util.add_sphere(body, 0.11, Color(0.1, 0.45, 0.3), Vector3(0, 0.22, -0.22))
				Util.add_box(body, Vector3(0.07, 0.03, 0.12), Color(0.95, 0.65, 0.1), Vector3(0, 0.2, -0.36))
				Util.add_box(body, Vector3(0.12, 0.05, 0.12), Color(0.5, 0.36, 0.22), Vector3(0, 0.12, 0.28))
				speed = 0.7
			"swan":
				if ResourceLoader.exists("res://assets/fauna/schwan.glb"):
					var sw := (load("res://assets/fauna/schwan.glb") as PackedScene).instantiate() as Node3D
					_darken(sw, 0.04)
					sw.position.y = -0.09
					body.add_child(sw)
					ap = _find_ap(sw)
					if ap != null:
						for an in ap.get_animation_list():
							ap.get_animation(an).loop_mode = Animation.LOOP_NONE if an == "Preen" else Animation.LOOP_LINEAR
						ap.play("Idle")
					speed = 0.55
					target = global_position
					return
				Util.add_sphere(body, 0.3, Color(0.95, 0.95, 0.95)).scale = Vector3(1.0, 0.7, 1.8)
				speed = 0.55
			"frog":
				Util.add_sphere(body, 0.1, Color(0.25, 0.6, 0.2)).scale = Vector3(1.0, 0.6, 1.2)
				Util.add_sphere(body, 0.03, Color(0.9, 0.9, 0.3), Vector3(0.05, 0.08, -0.07))
				Util.add_sphere(body, 0.03, Color(0.9, 0.9, 0.3), Vector3(-0.05, 0.08, -0.07))
				speed = 2.0
			"deer":
				if ResourceLoader.exists("res://assets/fauna/reh.glb"):
					var dr := (load("res://assets/fauna/reh.glb") as PackedScene).instantiate() as Node3D
					dr.scale = Vector3.ONE * 1.2
					_darken(dr, 0.3)
					body.add_child(dr)
					ap = _find_ap(dr)
					if ap != null:
						for an in ap.get_animation_list():
							ap.get_animation(an).loop_mode = Animation.LOOP_LINEAR
						ap.play("Idle")
					speed = 1.2
					target = global_position
					return
				var c := Color(0.62, 0.42, 0.24)
				Util.add_box(body, Vector3(0.45, 0.5, 1.0), c, Vector3(0, 0.95, 0))
				Util.add_box(body, Vector3(0.22, 0.5, 0.25), c, Vector3(0, 1.3, -0.5)).rotation_degrees.x = -25.0
				Util.add_box(body, Vector3(0.22, 0.24, 0.35), c.lightened(0.05), Vector3(0, 1.6, -0.68))
				Util.add_box(body, Vector3(0.04, 0.2, 0.04), Color(0.3, 0.2, 0.1), Vector3(0.07, 1.8, -0.62))
				Util.add_box(body, Vector3(0.04, 0.2, 0.04), Color(0.3, 0.2, 0.1), Vector3(-0.07, 1.8, -0.62))
				Util.add_box(body, Vector3(0.14, 0.14, 0.08), Color(0.95, 0.95, 0.9), Vector3(0, 1.0, 0.52))
				for lx in [-0.15, 0.15]:
					for lz in [-0.35, 0.35]:
						Util.add_box(body, Vector3(0.09, 0.7, 0.09), c.darkened(0.15), Vector3(lx, 0.35, lz))
				speed = 1.2
			"hare":
				if ResourceLoader.exists("res://assets/fauna/hase.glb"):
					var inst := (load("res://assets/fauna/hase.glb") as PackedScene).instantiate() as Node3D
					inst.scale = Vector3.ONE * 1.25
					body.add_child(inst)
					ap = _find_ap(inst)
					if ap != null:
						for an in ap.get_animation_list():
							ap.get_animation(an).loop_mode = Animation.LOOP_LINEAR
					speed = 1.5
					target = global_position
					return
				var hc := Color(0.62, 0.52, 0.42)
				Util.add_sphere(body, 0.17, hc, Vector3(0, 0.17, 0)).scale = Vector3(0.8, 0.8, 1.3)
				Util.add_sphere(body, 0.1, hc, Vector3(0, 0.27, -0.2))
				Util.add_box(body, Vector3(0.04, 0.2, 0.03), hc.darkened(0.1), Vector3(0.04, 0.45, -0.2))
				Util.add_box(body, Vector3(0.04, 0.2, 0.03), hc.darkened(0.1), Vector3(-0.04, 0.45, -0.2))
				Util.add_sphere(body, 0.05, Color(0.95, 0.95, 0.95), Vector3(0, 0.2, 0.22))
				speed = 1.5
			"bird":
				var bpath := "res://assets/fauna/%s.glb" % ("rotkehlchen" if randf() < 0.5 else "meise")
				if ResourceLoader.exists(bpath):
					var bi := (load(bpath) as PackedScene).instantiate() as Node3D
					bi.scale = Vector3.ONE * 4.0     # am Himmel sonst kaum zu sehen
					body.add_child(bi)
					ap = _find_ap(bi)
					if ap != null:
						for an in ap.get_animation_list():
							ap.get_animation(an).loop_mode = Animation.LOOP_LINEAR
						ap.play("Fly")
						ap.speed_scale = randf_range(0.9, 1.15)
				else:
					Util.add_sphere(body, 0.12, Color(0.12, 0.12, 0.14)).scale = Vector3(0.8, 0.8, 1.6)
					wing_l = Node3D.new()
					wing_r = Node3D.new()
					body.add_child(wing_l)
					body.add_child(wing_r)
					Util.add_box(wing_l, Vector3(0.5, 0.02, 0.18), Color(0.2, 0.2, 0.24), Vector3(-0.25, 0, 0))
					Util.add_box(wing_r, Vector3(0.5, 0.02, 0.18), Color(0.2, 0.2, 0.24), Vector3(0.25, 0, 0))
				orbit_c = Vector3(randf_range(-40, 40), 0, randf_range(-90, -10))
				orbit_r = randf_range(8.0, 22.0)
				orbit_a = randf() * TAU
		target = global_position

	## Modellfarben im hellen Spiellicht etwas abdunkeln
	func _darken(root: Node, amount: float) -> void:
		for mi in root.find_children("*", "MeshInstance3D", true, false):
			var m3 := mi as MeshInstance3D
			for i in range(m3.mesh.get_surface_count()):
				var sm := m3.mesh.surface_get_material(i) as BaseMaterial3D
				if sm != null:
					var dm := sm.duplicate() as BaseMaterial3D
					dm.albedo_color = dm.albedo_color.darkened(amount)
					dm.metallic = 0.0
					m3.set_surface_override_material(i, dm)

	func _find_ap(n: Node) -> AnimationPlayer:
		if n is AnimationPlayer:
			return n as AnimationPlayer
		for c in n.get_children():
			var r := _find_ap(c)
			if r != null:
				return r
		return null

	func _play(a: String, sc: float = 1.0) -> void:
		if ap == null or not ap.has_animation(a):
			return
		if a != _cur:
			_cur = a
			ap.play(a, 0.2)
		ap.speed_scale = sc

	func _pdist() -> float:
		if fauna.player == null or not is_instance_valid(fauna.player):
			return 999.0
		return Vector2(fauna.player.global_position.x - global_position.x, fauna.player.global_position.z - global_position.z).length()

	func _away_from_player(dist: float) -> Vector3:
		var d := global_position - fauna.player.global_position
		d.y = 0
		return global_position + d.normalized() * dist

	func _valid(p: Vector3) -> bool:
		match kind:
			"swan":
				return fauna._in_lake(p, 0.85)
			"duck":
				return fauna._in_lake(p, 0.92)
			"frog":
				return true
			"deer":
				return not fauna.main.call("_tree_blocked", p) and not fauna._in_lake(p, 1.2) and absf(p.x) < 100.0 and p.z > -110.0
			"hare":
				return not fauna._in_lake(p, 1.2) and absf(p.x) < 70.0 and p.z > -105.0 and p.z < 60.0 and not (p.x > 50.0 and p.z < -35.0)
		return true

	func _step_to(delta: float, spd: float) -> bool:
		var d := target - global_position
		d.y = 0
		if d.length() < 0.15:
			return true
		var dir := d.normalized()
		var np := global_position + dir * spd * delta
		if not _valid(np):
			# Nicht ins Wasser (oder in den Sperrbereich) laufen: Ziel verwerfen
			target = global_position
			wait = randf_range(0.5, 2.0)
			return true
		global_position = np
		var ang := atan2(-dir.x, -dir.z)
		rotation.y = lerp_angle(rotation.y, ang, minf(delta * 8.0, 1.0))
		return false

	func _process(delta: float) -> void:
		if dead:
			return
		_t += delta
		_snd_cd -= delta
		var night := Game.is_night()
		var pd := _pdist()
		match kind:
			"swan":
				var sflee := pd < 6.0
				if sflee and fauna.player != null:
					var saway := _away_from_player(6.0)
					if _valid(saway):
						target = saway
				elif wait > 0.0:
					wait -= delta
				elif _step_to(delta, speed):
					wait = randf_range(4.0, 12.0)
					for i in range(20):
						var scand := global_position + Vector3(randf_range(-10, 10), 0, randf_range(-7, 7))
						if _valid(scand):
							target = scand
							break
				var moving := sflee or wait <= 0.0
				if moving:
					_step_to(delta, speed * (2.5 if sflee else 1.0))
				global_position.y = 0.0
				if ap != null:
					if moving:
						_play("Swim", 1.6 if sflee else 1.0)
					elif int(_t / 11.0) % 3 == 2:
						_play("Preen", 1.0)
					else:
						_play("Idle", 1.0)
			"duck":
				var flee := pd < 7.0
				if flee and fauna.player != null:
					var away := _away_from_player(6.0)
					if _valid(away):
						target = away
					if _snd_cd <= 0.0 and pd < 5.0:
						_snd_cd = 4.0
						Sfx.play("quack", global_position, -2.0, randf_range(0.9, 1.3))
				elif wait > 0.0:
					wait -= delta
				elif _step_to(delta, speed):
					wait = randf_range(2.0, 7.0)
					for i in range(20):
						var cand := global_position + Vector3(randf_range(-9, 9), 0, randf_range(-6, 6))
						if _valid(cand):
							target = cand
							break
				if flee or wait <= 0.0:
					_step_to(delta, speed * (3.5 if flee else 1.0))
				global_position.y = 0.0
				body.position.y = sin(_t * 2.0) * 0.015
				body.rotation.z = sin(_t * 1.3) * 0.04
			"frog":
				if hidden_until > 0.0:
					hidden_until -= delta
					if hidden_until <= 0.0:
						visible = true
						global_position = fauna._shore_point(RandomNumberGenerator.new())
				elif pd < 3.2:
					var lp := global_position - fauna.lake_off
					var to_lake := (Vector3(LakeShape.CENTER.x, 0, LakeShape.CENTER.y) - Vector3(lp.x, 0, lp.z)).normalized()
					Sfx.play("splash_small", global_position, -3.0)
					global_position += to_lake * 1.6
					visible = false
					hidden_until = 40.0
				else:
					hop = maxf(hop - delta, 0.0)
					wait -= delta
					if wait <= 0.0:
						wait = randf_range(2.0, 6.0)
						hop = 0.35
					body.position.y = sin(hop / 0.35 * PI) * 0.08 if hop > 0.0 else 0.0
					if night and _snd_cd <= 0.0 and pd < 22.0:
						_snd_cd = randf_range(15.0, 40.0)
						Sfx.play("croak", global_position, -8.0, randf_range(0.8, 1.2))
			"deer", "hare":
				var flee_d := 14.0 if kind == "deer" else 8.0
				var fleeing := pd < flee_d
				if fleeing and fauna.player != null:
					var tries := 0
					var away := _away_from_player(18.0)
					while not _valid(away) and tries < 8:
						away = _away_from_player(18.0).rotated(Vector3.UP, 0.0)
						away = global_position + (away - global_position).rotated(Vector3.UP, randf_range(-1.4, 1.4))
						tries += 1
					if _valid(away):
						target = away
					_step_to(delta, speed * (5.0 if kind == "deer" else 4.0))
				elif wait > 0.0:
					wait -= delta
				elif _step_to(delta, speed):
					wait = randf_range(3.0, 9.0)
					for i in range(20):
						var cand2 := global_position + Vector3(randf_range(-10, 10), 0, randf_range(-10, 10))
						if _valid(cand2):
							target = cand2
							break
				if kind == "hare":
					var moving := fleeing or wait <= 0.0
					if ap != null:
						if fleeing:
							_play("Run", 1.0)
						elif moving:
							_play("Hop", 1.0)
						else:
							_play("Eat" if int(_t / 7.0) % 2 == 0 else "Idle")
					else:
						body.position.y = absf(sin(_t * (9.0 if fleeing else 5.0))) * 0.25 if moving else 0.0
					if moving and not fleeing:
						_step_to(delta, speed)
				else:
					if not fleeing and wait <= 0.0:
						_step_to(delta, speed)
					if ap != null:
						if fleeing:
							_play("Run", 1.0)
						elif wait <= 0.0:
							_play("Walk", 1.0)
						else:
							_play("Eat" if int(_t / 9.0) % 2 == 0 else "Idle")
					else:
						body.rotation.z = sin(_t * (12.0 if fleeing else 4.0)) * 0.03
			"bird":
				visible = not night
				orbit_a += delta * (0.35 + 1.0 / orbit_r)
				var p := orbit_c + Vector3(cos(orbit_a) * orbit_r, 0, sin(orbit_a) * orbit_r)
				p.y = 14.0 + sin(_t * 0.4) * 2.0
				global_position = p
				rotation.y = -orbit_a + PI
				if wing_l != null:
					wing_l.rotation.z = sin(_t * 12.0) * 0.6
					wing_r.rotation.z = -sin(_t * 12.0) * 0.6
