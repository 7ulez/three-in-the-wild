class_name Sfx
extends Node
## Alle Geräusche werden beim Spielstart per Code erzeugt (keine Audiodateien nötig).
## Sfx.play("splash", position) spielt 3D, Sfx.play("pop") ohne Position spielt "im Kopf".

const RATE: int = 22050
static var inst: Sfx = null
static var cache: Dictionary = {}
var _amb_wind: AudioStreamPlayer
var _amb_birds_t: float = 4.0
var _amb_night_t: float = 3.0
var _amb_water: AudioStreamPlayer3D
var _player: Node3D = null
var enabled: bool = true


func _ready() -> void:
	inst = self
	_amb_wind = AudioStreamPlayer.new()
	_amb_wind.stream = get_stream("wind")
	_amb_wind.volume_db = -26.0
	add_child(_amb_wind)
	_amb_wind.play()


func _exit_tree() -> void:
	if inst == self:
		inst = null


func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("local_player") as Node3D
		return
	var night := Game.is_night()
	_amb_birds_t -= delta
	if _amb_birds_t <= 0.0:
		_amb_birds_t = randf_range(2.5, 7.0)
		if not night:
			var a := randf() * TAU
			play("chirp", _player.global_position + Vector3(cos(a), 0, sin(a)) * randf_range(8.0, 25.0) + Vector3(0, 6, 0), -4.0)
	_amb_night_t -= delta
	if _amb_night_t <= 0.0:
		_amb_night_t = randf_range(0.5, 1.6)
		if night:
			var a2 := randf() * TAU
			play("cricket", _player.global_position + Vector3(cos(a2), 0, sin(a2)) * randf_range(4.0, 20.0), -10.0)
			if randf() < 0.12:
				play("owl", _player.global_position + Vector3(cos(a2), 0, sin(a2)) * 30.0 + Vector3(0, 5, 0), -6.0)
	_amb_wind.volume_db = lerpf(_amb_wind.volume_db, -26.0 if not night else -30.0, 0.02)


static func play(sound: String, pos: Vector3 = Vector3.INF, vol_db: float = 0.0, pitch: float = 1.0) -> void:
	if inst == null or not inst.enabled:
		return
	var st := get_stream(sound)
	if st == null:
		return
	if pos == Vector3.INF:
		var p := AudioStreamPlayer.new()
		p.stream = st
		p.volume_db = vol_db
		p.pitch_scale = pitch
		inst.add_child(p)
		p.finished.connect(p.queue_free)
		p.play()
	else:
		var p3 := AudioStreamPlayer3D.new()
		p3.stream = st
		p3.volume_db = vol_db
		p3.pitch_scale = pitch
		p3.unit_size = 8.0
		p3.max_distance = 70.0
		inst.add_child(p3)
		p3.global_position = pos
		p3.finished.connect(p3.queue_free)
		p3.play()


## Dauerhaft laufender Ton an einem Ort (z. B. Lagerfeuer). Der Aufrufer räumt auf.
static func loop_at(parent: Node, sound: String, vol_db: float = -6.0, unit: float = 6.0) -> AudioStreamPlayer3D:
	var p3 := AudioStreamPlayer3D.new()
	p3.stream = get_stream(sound)
	p3.volume_db = vol_db
	p3.unit_size = unit
	p3.max_distance = 40.0
	parent.add_child(p3)
	p3.play()
	return p3


static func get_stream(sound: String) -> AudioStreamWAV:
	if cache.has(sound):
		return cache[sound]
	var s := _generate(sound)
	cache[sound] = s
	return s


static func _wav(samples: PackedFloat32Array, loop: bool = false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in range(samples.size()):
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w


## Rauschen mit Tiefpass (k klein = dumpf), Hüllkurve exp(-decay*t)
static func _noise(dur: float, k: float, decay: float, attack: float = 0.0) -> PackedFloat32Array:
	var n := int(RATE * dur)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in range(n):
		var t := float(i) / RATE
		lp += (randf_range(-1.0, 1.0) - lp) * k
		var env := exp(-decay * t)
		if attack > 0.0:
			env *= minf(t / attack, 1.0)
		out[i] = lp * env
	return out


static func _tone(dur: float, f0: float, f1: float, decay: float, wave: int = 0, vol: float = 0.6) -> PackedFloat32Array:
	var n := int(RATE * dur)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	for i in range(n):
		var t := float(i) / RATE
		var f := lerpf(f0, f1, t / dur)
		ph += TAU * f / RATE
		var v := sin(ph)
		if wave == 1:
			v = fposmod(ph / TAU, 1.0) * 2.0 - 1.0     # Säge
		elif wave == 2:
			v = 1.0 if sin(ph) > 0.0 else -1.0         # Rechteck
		out[i] = v * vol * exp(-decay * t)
	return out


static func _mix(a: PackedFloat32Array, b: PackedFloat32Array, offset: int = 0) -> PackedFloat32Array:
	var n := maxi(a.size(), b.size() + offset)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in range(a.size()):
		out[i] += a[i]
	for j in range(b.size()):
		out[j + offset] += b[j]
	return out


static func _generate(sound: String) -> AudioStreamWAV:
	match sound:
		"step":
			return _wav(_noise(0.14, 0.18, 30.0))
		"step_gravel":
			return _wav(_noise(0.12, 0.5, 38.0))
		"splash":
			return _wav(_mix(_noise(0.7, 0.35, 5.0, 0.01), _tone(0.25, 400.0, 120.0, 12.0, 0, 0.3)))
		"splash_small":
			return _wav(_mix(_noise(0.3, 0.4, 12.0, 0.005), _tone(0.12, 600.0, 250.0, 25.0, 0, 0.25)))
		"pop":
			return _wav(_tone(0.1, 500.0, 250.0, 30.0, 0, 0.5))
		"thunk":
			return _wav(_mix(_tone(0.25, 110.0, 60.0, 14.0, 0, 0.8), _noise(0.1, 0.3, 40.0)))
		"whoosh":
			return _wav(_noise(0.5, 0.12, 4.0, 0.15))
		"plop":
			return _wav(_tone(0.25, 320.0, 70.0, 9.0, 0, 0.7))
		"gulp":
			return _wav(_mix(_tone(0.12, 300.0, 150.0, 18.0, 0, 0.6), _tone(0.12, 260.0, 120.0, 18.0, 0, 0.6), 4000))
		"crunch":
			return _wav(_mix(_noise(0.08, 0.7, 40.0), _noise(0.08, 0.7, 40.0), 2200))
		"snap":
			return _wav(_mix(_noise(0.15, 0.9, 30.0), _tone(0.3, 160.0, 50.0, 10.0, 1, 0.5)))
		"click":
			return _wav(_noise(0.04, 0.9, 80.0))
		"spark":
			return _wav(_noise(0.12, 0.9, 25.0))
		"ignite":
			return _wav(_noise(0.9, 0.15, 3.0, 0.1))
		"chirp":
			return _wav(_mix(_tone(0.09, 2600.0, 3800.0, 14.0, 0, 0.3), _tone(0.09, 3200.0, 2400.0, 14.0, 0, 0.3), 3500))
		"cricket":
			var c := PackedFloat32Array()
			for k in range(4):
				c = _mix(c, _tone(0.05, 4300.0, 4300.0, 20.0, 0, 0.18), k * 2000)
			return _wav(c)
		"owl":
			return _wav(_mix(_tone(0.4, 380.0, 330.0, 4.0, 0, 0.4), _tone(0.5, 380.0, 300.0, 3.5, 0, 0.4), 12000))
		"croak":
			return _wav(_mix(_tone(0.18, 170.0, 120.0, 8.0, 2, 0.25), _tone(0.14, 190.0, 130.0, 10.0, 2, 0.25), 5000))
		"quack":
			return _wav(_tone(0.22, 520.0, 300.0, 8.0, 1, 0.35))
		"burp":
			return _wav(_tone(0.5, 130.0, 70.0, 3.0, 1, 0.5))
		"rumble":
			return _wav(_noise(1.6, 0.05, 1.5, 0.1))
		"buzz":
			return _wav(_mix(_tone(1.0, 210.0, 230.0, 0.8, 1, 0.3), _noise(1.0, 0.5, 0.8)))
		"trickle":
			return _wav(_noise(0.8, 0.3, 1.0, 0.1))
		"toast":
			return _wav(_tone(0.18, 880.0, 1100.0, 10.0, 0, 0.25))
		"wind":
			return _wav(_loopable_noise(3.0, 0.02), true)
		"fire":
			var f := _loopable_noise(2.0, 0.25)
			for i in range(f.size()):
				if randf() < 0.002:
					for j in range(mini(300, f.size() - i)):
						f[i + j] += randf_range(-0.6, 0.6) * (1.0 - float(j) / 300.0)
			return _wav(f, true)
		"water":
			return _wav(_loopable_noise(3.0, 0.08), true)
	return null


static func _loopable_noise(dur: float, k: float) -> PackedFloat32Array:
	var n := int(RATE * dur)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in range(n):
		lp += (randf_range(-1.0, 1.0) - lp) * k
		out[i] = lp * 2.2
	# weich ausblenden, damit die Schleife nicht knackt
	var fade := 1500
	for i in range(fade):
		var w := float(i) / fade
		out[i] *= w
		out[n - 1 - i] *= w
	return out
