class_name Weather
extends Node
## Tageszeit-Ereignisse und Wetter wie in Minecraft: Sonnenauf-/untergang, Wolken, Regen, Gewitter mit
## Blitz und Donner, Nebel. Der Gastgeber (oder Solo-Spieler) würfelt das Wetter, Mitspieler bekommen es per Netz.

enum K { CLEAR, CLOUDY, RAIN, STORM, FOG }

const NAMES: Array = ["klar", "bewölkt", "Regen", "Gewitter", "Nebel"]
# Zielwerte je Wetter: Regen, Wolken (Himmels-Shader), Nebel, Gewitter
const T_RAIN: Array = [0.0, 0.0, 0.7, 1.0, 0.0]
const T_CLOUD: Array = [0.5, 1.0, 1.4, 1.7, 0.7]
const T_FOG: Array = [0.0, 0.0, 0.25, 0.4, 1.0]
const T_STORM: Array = [0.0, 0.0, 0.0, 1.0, 0.0]

static var kind: int = K.CLEAR
static var rain: float = 0.0
static var cloud: float = 0.5
static var fog: float = 0.0
static var storm: float = 0.0
static var flash: float = 0.0        # Blitzhelligkeit 0..1

var main: Node
var player: Player
var _left: float = 200.0             # Sekunden bis zum nächsten Wetterwechsel
var _prev_hour: float = -1.0
var _bolt_t: float = 8.0
var _rain_a: CPUParticles3D
var _rain_b: CPUParticles3D
var _rain_snd: AudioStreamPlayer
var _flash_seq: Array = []
var _flash_i: float = 0.0


static func reset() -> void:
	kind = K.CLEAR
	rain = 0.0
	cloud = 0.5
	fog = 0.0
	storm = 0.0
	flash = 0.0


## 0 = Sonnenschein, 1 = ganz dicht und düster
static func dark() -> float:
	return clampf((cloud - 0.5) / 1.2, 0.0, 1.0) * 0.7 + storm * 0.15


## Fische beißen bei Regen besser
static func bite_factor() -> float:
	return 1.0 - 0.3 * rain


static func word() -> String:
	return "" if kind == K.CLEAR else NAMES[kind]


func start(p_main: Node, p_player: Player) -> void:
	main = p_main
	player = p_player
	if Game.dedicated:
		return
	_build_rain()
	_rain_snd = AudioStreamPlayer.new()
	_rain_snd.stream = Sfx.get_stream("rain")
	_rain_snd.volume_db = -60.0
	add_child(_rain_snd)
	_rain_snd.play()


func _is_authority() -> bool:
	return Net.instance == null or Net.instance.is_host()


func _build_rain() -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.8, 0.86, 0.95, 0.7)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var q := QuadMesh.new()
	q.size = Vector2(0.02, 0.7)
	q.material = mat
	for i in range(2):
		var p := CPUParticles3D.new()
		p.amount = (140 if Game.low else 320) if i == 0 else (200 if Game.low else 520)
		p.lifetime = 0.8
		p.preprocess = 0.8
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		p.emission_box_extents = Vector3(13, 0.2, 13)
		p.direction = Vector3(0.12, -1, 0.05)
		p.spread = 3.0
		p.initial_velocity_min = 17.0
		p.initial_velocity_max = 21.0
		p.gravity = Vector3.ZERO
		p.mesh = q
		p.emitting = false
		p.top_level = true
		p.visibility_aabb = AABB(Vector3(-20, -20, -20), Vector3(40, 40, 40))
		add_child(p)
		if i == 0:
			_rain_a = p
		else:
			_rain_b = p


func _process(delta: float) -> void:
	if (kind == K.RAIN or kind == K.STORM) and not Game.rain_fire:
		for o in Game.placed:
			if is_instance_valid(o) and o.item_name == "Feuerschale" and o.burning:
				Game.rain_fire_t += delta
				if Game.rain_fire_t >= 30.0:
					Game.rain_fire = true
					if player != null and is_instance_valid(player):
						player._update_help()
				break
	if _is_authority():
		_left -= delta
		if _left <= 0.0:
			_roll_next()
	# weich zum Zielwert
	var k := 1.0 - exp(-delta * 0.3)
	rain = lerpf(rain, T_RAIN[kind], k)
	cloud = lerpf(cloud, T_CLOUD[kind], k)
	fog = lerpf(fog, T_FOG[kind], k)
	storm = lerpf(storm, T_STORM[kind], k)
	if Game.dedicated:
		return
	_day_events()
	_update_flash(delta)
	if player == null or not is_instance_valid(player):
		return
	var cave: bool = main != null and main.get("_in_cave") == true
	var pp := player.global_position
	for p in [_rain_a, _rain_b]:
		(p as CPUParticles3D).global_position = pp + Vector3(0, 11, 0)
	_rain_a.emitting = rain > 0.04 and not cave
	_rain_b.emitting = rain > 0.55 and not cave
	var vol := -60.0
	if rain > 0.02:
		vol = lerpf(-34.0, -9.0, rain) - (18.0 if cave else 0.0)
	_rain_snd.volume_db = lerpf(_rain_snd.volume_db, vol, minf(delta * 2.0, 1.0))
	if storm > 0.5 and _is_authority_or_client():
		_bolt_t -= delta
		if _bolt_t <= 0.0:
			_bolt_t = randf_range(14.0, 30.0)
			_lightning()


func _is_authority_or_client() -> bool:
	return true


# ---------- Wetterwechsel ----------

func _roll_next() -> void:
	var w: Array
	match kind:
		K.CLEAR:
			w = [0.0, 0.5, 0.2, 0.0, 0.0]
			if Game.hour > 4.0 and Game.hour < 9.5:
				w[K.FOG] = 0.3
		K.CLOUDY:
			w = [0.45, 0.0, 0.5, 0.05, 0.0]
		K.RAIN:
			w = [0.35, 0.4, 0.0, 0.08, 0.0]
		K.STORM:
			w = [0.0, 0.4, 0.6, 0.0, 0.0]
		_:
			w = [0.7, 0.3, 0.0, 0.0, 0.0]
	var total := 0.0
	for x in w:
		total += x
	var r := randf() * total
	var nk: int = K.CLEAR
	for i in range(w.size()):
		r -= w[i]
		if r <= 0.0:
			nk = i
			break
	set_kind(nk, true)


func set_kind(nk: int, announce: bool = true) -> void:
	if nk == kind:
		_left = _duration(nk)
		return
	kind = nk
	_left = _duration(nk)
	if Net.instance != null and _is_authority():
		Net.instance.send_weather(nk)
	if announce and player != null and is_instance_valid(player):
		player.toast(["Der Himmel klart auf.", "Wolken ziehen auf ...", "Es fängt an zu regnen.", "Ein Gewitter zieht auf!", "Nebel steigt vom See auf."][nk], 4.0)
		player._update_help()


func _duration(k: int) -> float:
	match k:
		K.CLEAR:
			return randf_range(240.0, 480.0)
		K.CLOUDY:
			return randf_range(60.0, 150.0)
		K.RAIN:
			return randf_range(120.0, 240.0)
		K.STORM:
			return randf_range(40.0, 80.0)
	return randf_range(120.0, 200.0)


## Vom Netz: Gastgeber hat das Wetter gewechselt
func remote_set(nk: int) -> void:
	if nk != kind:
		kind = nk
		_left = 60.0
		if player != null and is_instance_valid(player):
			player.toast(["Der Himmel klart auf.", "Wolken ziehen auf ...", "Es fängt an zu regnen.", "Ein Gewitter zieht auf!", "Nebel steigt vom See auf."][nk], 4.0)
			player._update_help()


# ---------- Sonnenauf- und -untergang ----------

func _day_events() -> void:
	var h := Game.hour
	if _prev_hour >= 0.0 and player != null and is_instance_valid(player):
		if _prev_hour < 6.0 and h >= 6.0:
			player.toast("Die Sonne geht auf. Ein neuer Tag beginnt.", 4.0)
		elif _prev_hour < 18.0 and h >= 18.0:
			player.toast("Die Sonne geht unter ...", 4.0)
		elif _prev_hour < 20.0 and h >= 20.0:
			player.toast("Die Nacht bricht an. Zeit fürs Lagerfeuer.", 4.0)
	_prev_hour = h


# ---------- Blitz und Donner ----------

func _lightning() -> void:
	var a := randf() * TAU
	var dist := randf_range(35.0, 110.0)
	var pos := (player.global_position if player != null else Vector3.ZERO) + Vector3(cos(a), 0, sin(a)) * dist
	pos.y = 0.0
	_spawn_bolt(pos)
	_flash_seq = [1.0, 0.15, 0.7, 0.0]
	_flash_i = 0.0
	var delay := dist / 120.0 + randf_range(0.1, 0.6)    # Schall braucht länger als Licht
	get_tree().create_timer(delay).timeout.connect(func() -> void:
		Sfx.play("thunder", Vector3.INF, lerpf(-2.0, -12.0, dist / 110.0), randf_range(0.85, 1.1)))


func _update_flash(delta: float) -> void:
	if _flash_seq.is_empty():
		flash = maxf(flash - delta * 6.0, 0.0)
		return
	_flash_i += delta * 14.0
	var i := int(_flash_i)
	if i >= _flash_seq.size():
		_flash_seq = []
		return
	flash = lerpf(flash, float(_flash_seq[i]), 0.6)


func _spawn_bolt(pos: Vector3) -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.92, 0.95, 1.0)
	mat.no_depth_test = false
	var root := Node3D.new()
	root.top_level = true
	add_child(root)
	var cur := pos + Vector3(0, 130.0, 0)
	var segs := 12
	for i in range(segs):
		var nxt := pos + Vector3(randf_range(-4.0, 4.0), 130.0 * (1.0 - float(i + 1) / segs), randf_range(-4.0, 4.0))
		if i == segs - 1:
			nxt = pos
		var len := cur.distance_to(nxt)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.35, len, 0.35)
		mi.mesh = bm
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
		mi.global_position = (cur + nxt) * 0.5
		mi.look_at(nxt, Vector3.RIGHT if absf((nxt - cur).normalized().dot(Vector3.UP)) > 0.99 else Vector3.UP)
		mi.rotate_object_local(Vector3.RIGHT, PI / 2.0)
		cur = nxt
	get_tree().create_timer(0.3).timeout.connect(root.queue_free)
