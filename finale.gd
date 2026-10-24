class_name Finale
extends Node3D
## Wenn alle Ziele geschafft sind: Abend, Feuerwerk, Bierkasten mit Schleife, dann der Abspann.
## Jeder Spieler startet das bei sich selbst (die Ziele sind ja fuer alle gleich); nur die
## Weltautoritaet stellt den Bierkasten hin, damit es ihn nur einmal gibt.

const CREDITS_AT := 14.0
const PALETTE: Array = [
	Color(1.0, 0.25, 0.2), Color(1.0, 0.75, 0.2), Color(0.3, 0.8, 1.0), Color(1.0, 0.35, 0.8),
	Color(0.4, 1.0, 0.45), Color(1.0, 1.0, 0.85), Color(0.7, 0.45, 1.0), Color(1.0, 0.55, 0.15),
]

var player: Player = null
var t: float = 0.0
var _next: float = 2.5
var _center: Vector3 = Vector3.ZERO
var _credits: Credits = null
var _layer: CanvasLayer = null
var _closed_t: float = -1.0
var _stats_t: float = 0.0


static func start(main: Node, p: Player) -> void:
	var f := Finale.new()
	f.name = "Finale"
	main.add_child(f)
	f.begin(p)


func begin(p: Player) -> void:
	player = p
	_center = Game.camp_center if Game.camp_claimed else p.global_position
	Game.stats_all[Game.player_name] = Game.my_stats()
	_send_stats()
	var mh := p.get_minihud()
	if mh != null:
		mh.card("ALLE ZIELE GESCHAFFT!", "Ein perfekter Angelausflug", Color(1.0, 0.8, 0.25), 6.0)
	p.toast("ALLE ZIELE GESCHAFFT! Der Abend bricht an ... dreht euch mal zum See.", 9.0)
	Sfx.play("fanfare", Vector3.INF, 0.0, 1.0)
	var authority := Net.instance == null or not is_instance_valid(Net.instance) or Net.instance.is_world_authority()
	# Abend machen, damit das Feuerwerk leuchtet
	if Net.instance == null or not is_instance_valid(Net.instance):
		if Game.hour >= 5.0 and Game.hour < 20.5:
			Game.hour = 21.0
	else:
		Net.instance.request_evening()
		Net.instance.send_finale_flag()
	if authority:
		_spawn_gift()
	Music.play_song(self)


func _send_stats() -> void:
	Game.stats_all[Game.player_name] = Game.my_stats()
	if Net.instance != null and is_instance_valid(Net.instance) and Net.instance.multiplayer.multiplayer_peer != null:
		Net.instance.send_stats(Game.player_name, Game.stats_all[Game.player_name])


## Bierkasten mit Schleife neben dem Lagerfeuer
func _spawn_gift() -> void:
	var pos := _center + Vector3(1.8, 0.0, 1.2)
	for g in Game.placed:
		if is_instance_valid(g) and g.item_name == "Feuerschale":
			pos = g.global_position + Vector3(1.5, 0.0, 0.9)
			break
	var crate := Item.new().setup("Bierkasten", 14.0, Vector3(0.5, 0.3, 0.35), Color(0.9, 0.75, 0.21))
	get_parent().add_child(crate)
	crate.global_position = pos + Vector3(0, 1.2, 0)
	crate.rotation.y = 0.5


func _process(delta: float) -> void:
	t += delta
	if t < CREDITS_AT and t > 1.0:
		_stats_t += delta
		if _stats_t > 4.0:
			_stats_t = 0.0
			_send_stats()
	if _closed_t >= 0.0:
		_closed_t += delta
		if _closed_t > 25.0:
			queue_free()
			return
	var quiet := _credits != null and _closed_t < 0.0
	if t > 2.5 and (_closed_t < 0.0 or _closed_t < 18.0):
		_next -= delta
		if _next <= 0.0:
			_launch()
			_next = randf_range(1.0, 1.9) if quiet else randf_range(0.35, 0.85)
	if _credits == null and _closed_t < 0.0 and t >= CREDITS_AT:
		_open_credits()


func _open_credits() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 70
	add_child(_layer)
	_credits = Credits.new()
	_layer.add_child(_credits)
	_credits.closed.connect(_on_credits_closed)
	_credits.begin()


func _on_credits_closed() -> void:
	_closed_t = 0.0
	if _layer != null:
		_layer.queue_free()
	Music.stop_song(self)


# ---------- Feuerwerk ----------

func _launch() -> void:
	var a := randf() * TAU
	var r := randf_range(10.0, 32.0)
	var base := Vector3(_center.x + cos(a) * r, _center.y, _center.z + sin(a) * r)
	var top := base + Vector3(randf_range(-5.0, 5.0), randf_range(18.0, 30.0), randf_range(-5.0, 5.0))
	var rocket := Node3D.new()
	add_child(rocket)
	rocket.global_position = base
	var head := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.3
	sm.height = 0.6
	sm.radial_segments = 6
	sm.rings = 3
	var hm := StandardMaterial3D.new()
	hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hm.albedo_color = Color(1.0, 0.9, 0.6)
	sm.material = hm
	head.mesh = sm
	rocket.add_child(head)
	var trail := CPUParticles3D.new()
	trail.amount = 28
	trail.lifetime = 0.8
	trail.local_coords = false
	trail.direction = Vector3.DOWN
	trail.spread = 25.0
	trail.initial_velocity_min = 1.0
	trail.initial_velocity_max = 3.0
	trail.gravity = Vector3(0, -2.0, 0)
	trail.mesh = _dot_mesh(0.2, Color(1.0, 0.7, 0.3))
	trail.color_ramp = _ramp(Color(1.0, 0.8, 0.4), Color(1.0, 0.5, 0.15))
	rocket.add_child(trail)
	Sfx.play("whoosh", base, -2.0, randf_range(0.8, 1.2))
	var tw := create_tween()
	tw.tween_property(rocket, "global_position", top, randf_range(1.0, 1.4)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		_burst(top)
		rocket.queue_free())


func _dot_mesh(radius: float, col: Color) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = 4
	m.rings = 2
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = col
	m.material = mat
	return m


func _ramp(c0: Color, c1: Color) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 0.92, 1), c0, Color(c1.r, c1.g, c1.b, 0.0)])
	return g


func _spray(pos: Vector3, c0: Color, c1: Color, amount: int, speed: float, life: float, grav: float, size: float) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = life
	p.local_coords = false
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.55
	p.initial_velocity_max = speed
	p.damping_min = speed * 0.22
	p.damping_max = speed * 0.3
	p.gravity = Vector3(0, -grav, 0)
	p.mesh = _dot_mesh(size, c0)
	p.color_ramp = _ramp(c0, c1)
	add_child(p)
	p.global_position = pos
	p.emitting = true
	get_tree().create_timer(life + 0.6).timeout.connect(p.queue_free)


func _burst(pos: Vector3) -> void:
	var c0: Color = PALETTE[randi() % PALETTE.size()]
	var c1: Color = PALETTE[randi() % PALETTE.size()]
	var n := 45 if Game.low else 110
	var kind := randi() % 3
	match kind:
		0:
			_spray(pos, c0, c0, n, 13.0, 2.2, 4.5, 0.45)
		1:
			# Zweifarbig: grosse Kugel plus kleiner Kern
			_spray(pos, c0, c0, n, 14.0, 2.4, 4.0, 0.45)
			_spray(pos, c1, c1, n / 2, 7.0, 2.0, 4.0, 0.4)
		_:
			# Trauerweide: langsam, lange sinkend, golden
			var gold := Color(1.0, 0.78, 0.3)
			_spray(pos, gold, Color(1.0, 0.5, 0.1), n, 9.0, 3.4, 6.5, 0.38)
	Sfx.play("boom", Vector3.INF, randf_range(-9.0, -5.0), randf_range(0.8, 1.15))
	if not Game.low:
		var l := OmniLight3D.new()
		l.light_color = c0
		l.light_energy = 5.0
		l.omni_range = 70.0
		add_child(l)
		l.global_position = pos
		var tw := create_tween()
		tw.tween_property(l, "light_energy", 0.0, 0.7)
		tw.tween_callback(l.queue_free)
