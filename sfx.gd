class_name Sfx
extends Node
## Geräusche: Liegt unter res://assets/sounds/ eine Datei <name>_1.ogg, <name>_2.ogg ... (oder <name>.ogg),
## wird sie (zufällige Variante) benutzt. Sonst wird das Geräusch wie früher per Code erzeugt.
## Sfx.play("splash", position) spielt 3D, Sfx.play("pop") ohne Position spielt "im Kopf".

static var SR: float = 32000.0
const VARIANTS: Dictionary = {"step": 4, "step_gravel": 4, "splash": 2, "splash_small": 3, "chirp": 5, "cricket": 3, "crunch": 3, "thunk": 3, "plop": 2, "quack": 3, "croak": 3, "gulp": 2, "burp": 2, "click": 3, "sizzle": 2, "pop": 2, "spark": 2, "crate": 3, "trunk_close": 2, "retch": 2, "vomit": 2, "airgun": 2, "reload": 1, "chest_open": 1, "thunder": 2}
const LOWRATE: Array = ["rain", "thunder", "wind", "fire", "water", "rumble", "owl", "burp", "plop", "thunk", "ignite", "trickle", "croak", "trunk_open", "trunk_close", "retch", "vomit"]
var _warm: Array = []
var _warm_t: float = 2.0
static var inst: Sfx = null
static var cache: Dictionary = {}
static var _files: Dictionary = {}     # Name -> Array von AudioStream (leer = keine Dateien)
var _amb_wind: AudioStreamPlayer
var _amb_birds_t: float = 4.0
var _amb_night_t: float = 3.0
var _amb_water: AudioStreamPlayer
var _water_near: float = 0.0
var _player: Node3D = null
var enabled: bool = true


func _ready() -> void:
	inst = self
	if has_file("water"):
		_amb_water = AudioStreamPlayer.new()
		_amb_water.stream = get_stream("water")
		_amb_water.volume_db = -60.0
		add_child(_amb_water)
		_amb_water.play()
	_amb_wind = AudioStreamPlayer.new()
	_amb_wind.stream = get_stream("wind")
	_amb_wind.volume_db = -22.0
	add_child(_amb_wind)
	_amb_wind.play()
	for k in VARIANTS:
		for v in range(int(VARIANTS[k])):
			_warm.append([k, v])


func _exit_tree() -> void:
	if inst == self:
		inst = null


func _process(delta: float) -> void:
	# Geräusche nach und nach im Hintergrund vorbereiten (ein Stück pro Bild, kein Ruckeln)
	if not _warm.is_empty():
		_warm_t -= delta
		if _warm_t <= 0.0:
			var w: Array = _warm.pop_back()
			_variant(w[0], w[1])
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("local_player") as Node3D
		return
	var night := Game.is_night()
	_amb_birds_t -= delta
	if _amb_birds_t <= 0.0:
		_amb_birds_t = randf_range(2.5, 7.0)
		if not night and Weather.rain < 0.15:
			var a := randf() * TAU
			play("chirp", _player.global_position + Vector3(cos(a), 0, sin(a)) * randf_range(8.0, 25.0) + Vector3(0, 6, 0), -6.0, randf_range(0.85, 1.2))
	_amb_night_t -= delta
	if _amb_night_t <= 0.0:
		_amb_night_t = randf_range(0.5, 1.6)
		if night:
			var a2 := randf() * TAU
			play("cricket", _player.global_position + Vector3(cos(a2), 0, sin(a2)) * randf_range(4.0, 20.0), -10.0)
			if randf() < 0.12:
				play("owl", _player.global_position + Vector3(cos(a2), 0, sin(a2)) * 30.0 + Vector3(0, 5, 0), -6.0)
	_amb_wind.volume_db = lerpf(_amb_wind.volume_db, -22.0 if not night else -27.0, 0.02)
	if _amb_water != null:
		# Wellenplätschern: nur in Ufernähe, mit weichem Ein-/Ausblenden
		var lake: Variant = get_tree().current_scene.get("lake_root") if get_tree().current_scene != null else null
		var near := 0.0
		if lake is Node3D:
			var lp: Vector3 = _player.global_position - (lake as Node3D).global_position
			for k in range(9):
				var a3 := TAU * float(k) / 8.0
				var off := Vector2.ZERO if k == 8 else Vector2(cos(a3), sin(a3)) * 7.0
				if LakeShape.contains(Vector2(lp.x, lp.z) + off):
					near += 1.0
			near = clampf(near / 4.0, 0.0, 1.0)
		_water_near = lerpf(_water_near, near, minf(delta * 1.5, 1.0))
		_amb_water.volume_db = lerpf(-60.0, -13.0, _water_near)


static func play(sound: String, pos: Vector3 = Vector3.INF, vol_db: float = 0.0, pitch: float = 1.0) -> void:
	if inst == null or not inst.enabled:
		return
	var st := get_stream(sound)
	if st == null:
		return
	if VARIANTS.has(sound) or has_file(sound):
		pitch *= randf_range(0.96, 1.04)
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
		p3.attenuation_filter_cutoff_hz = 9000.0
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


## Gibt es echte Aufnahmen für dieses Geräusch?
static func has_file(sound: String) -> bool:
	return not _file_streams(sound).is_empty()


static func _file_streams(sound: String) -> Array:
	if _files.has(sound):
		return _files[sound]
	var list: Array = []
	var base := "res://assets/sounds/%s" % sound
	if ResourceLoader.exists(base + ".ogg"):
		list.append(load(base + ".ogg"))
	for i in range(1, 9):
		var path := "%s_%d.ogg" % [base, i]
		if ResourceLoader.exists(path):
			list.append(load(path))
	if sound == "water" or sound == "fire":
		for st in list:
			(st as AudioStreamOggVorbis).loop = true
	_files[sound] = list
	return list


static func get_stream(sound: String) -> AudioStream:
	var fl := _file_streams(sound)
	if not fl.is_empty():
		return fl[randi() % fl.size()]
	var n: int = int(VARIANTS.get(sound, 1))
	return _variant(sound, randi() % n)


static func _variant(sound: String, v: int) -> AudioStreamWAV:
	var key := "%s#%d" % [sound, v]
	if cache.has(key):
		return cache[key]
	SR = 16000.0 if LOWRATE.has(sound) else 32000.0
	var alias := {"fish_jump": "splash", "bottle": "pop", "bubble": "plop"}
	var s := _generate(alias.get(sound, sound), v)
	if s != null:
		cache[key] = s
	return s


# ---------- Bausteine ----------

static func _wav(samples: PackedFloat32Array, peak: float = 0.8, loop: bool = false) -> AudioStreamWAV:
	var mx := 0.0001
	for x in samples:
		mx = maxf(mx, absf(x))
	var g := peak / mx
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in range(samples.size()):
		data.encode_s16(i * 2, int(clampf(samples[i] * g, -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = int(SR)
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w


static func _white(dur: float) -> PackedFloat32Array:
	var n := int(SR * dur)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in range(n):
		out[i] = randf_range(-1.0, 1.0)
	return out


## Zustandsvariablenfilter: mode 0 = Tiefpass, 1 = Bandpass, 2 = Hochpass. q klein = schmal/resonant.
static func _filt(x: PackedFloat32Array, mode: int, fc: float, q: float = 0.7) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(x.size())
	var f := 2.0 * sin(PI * minf(fc, SR * 0.2) / SR)
	var damp := 1.0 / maxf(q, 0.05)
	var low := 0.0
	var band := 0.0
	for i in range(x.size()):
		low += f * band
		var high := x[i] - low - damp * band
		band += f * high
		out[i] = low if mode == 0 else (band * damp * 0.5 if mode == 1 else high)
	return out


## Gefiltertes Rauschen, auf gleiche Lautheit normiert (damit Tiefpass-Rauschen nicht im Hochton-Rauschen untergeht)
static func _nf(x: PackedFloat32Array, mode: int, fc: float, q: float = 0.7) -> PackedFloat32Array:
	var y := _filt(x, mode, fc, q)
	var e := 0.0001
	for v in y:
		e += v * v
	var g := 0.3 / sqrt(e / y.size())
	for i in range(y.size()):
		y[i] *= g
	return y


## Bandpass-Rauschen, dessen Mittenfrequenz von f0 nach f1 wandert (Wind, Zischen, Wusch).
static func _sweep(dur: float, f0: float, f1: float, q: float) -> PackedFloat32Array:
	var n := int(SR * dur)
	var out := PackedFloat32Array()
	out.resize(n)
	var low := 0.0
	var band := 0.0
	var damp := 1.0 / q
	for i in range(n):
		var fc := lerpf(f0, f1, float(i) / n)
		var f := 2.0 * sin(PI * minf(fc, SR * 0.2) / SR)
		low += f * band
		var high := randf_range(-1.0, 1.0) - low - damp * band
		band += f * high
		out[i] = band * damp * 0.5
	var e := 0.0001
	for v in out:
		e += v * v
	var g := 0.3 / sqrt(e / out.size())
	for i in range(out.size()):
		out[i] *= g
	return out


## Hüllkurve: Einschwingen (attack) und exponentielles Ausklingen (decay)
static func _env(x: PackedFloat32Array, attack: float, decay: float, vol: float = 1.0) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(x.size())
	for i in range(x.size()):
		var t := float(i) / SR
		var e := exp(-decay * t)
		if attack > 0.0:
			e *= minf(t / attack, 1.0)
		out[i] = x[i] * e * vol
	return out


static func _sine(dur: float, f0: float, f1: float, decay: float, vol: float = 0.6, attack: float = 0.002, harm: float = 0.0) -> PackedFloat32Array:
	var n := int(SR * dur)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	for i in range(n):
		var t := float(i) / SR
		ph += TAU * lerpf(f0, f1, t / dur) / SR
		var v := sin(ph) + harm * sin(2.0 * ph) + harm * 0.4 * sin(3.0 * ph)
		out[i] = v * vol * exp(-decay * t) * minf(t / maxf(attack, 0.0001), 1.0)
	return out


## Wasserblase: kurzer Sinus, dessen Tonhöhe schnell ansteigt
static func _bubble(f: float, vol: float) -> PackedFloat32Array:
	var d := 0.012 + 3.0 / f
	return _sine(d * 2.5, f, f * randf_range(1.5, 2.2), 38.0 + f * 0.012, vol, 0.001)


static func _add(dst: PackedFloat32Array, src: PackedFloat32Array, offset_s: float = 0.0, gain: float = 1.0) -> PackedFloat32Array:
	var off := int(offset_s * SR)
	if dst.size() < src.size() + off:
		dst.resize(src.size() + off)
	for i in range(src.size()):
		dst[i + off] += src[i] * gain
	return dst


static func _sat(x: PackedFloat32Array, drive: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(x.size())
	for i in range(x.size()):
		out[i] = tanh(x[i] * drive)
	return out


## Kleiner Hall aus vier Kammfiltern (für Eule, Höhle, Donnern).
static func _reverb(x: PackedFloat32Array, wet: float, tail: float = 0.5) -> PackedFloat32Array:
	var n := x.size() + int(SR * tail)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in range(x.size()):
		out[i] = x[i]
	for d in [0.0297, 0.0371, 0.0411, 0.0533]:
		var dl := int(SR * d)
		var buf := PackedFloat32Array()
		buf.resize(n)
		for i in range(n):
			var inp := x[i] if i < x.size() else 0.0
			buf[i] = inp + (buf[i - dl] * 0.62 if i >= dl else 0.0)
			out[i] += buf[i] * wet * 0.35
	return out


## Macht aus einem längeren Stück eine nahtlose Schleife (Überblenden von Ende und Anfang).
static func _loopify(x: PackedFloat32Array, fade_s: float) -> PackedFloat32Array:
	var fade := int(SR * fade_s)
	var n := x.size() - fade
	var out := PackedFloat32Array()
	out.resize(n)
	for i in range(n):
		out[i] = x[i]
	for i in range(fade):
		var w := float(i) / fade
		out[i] = x[i] * sin(w * PI * 0.5) + x[n + i] * cos(w * PI * 0.5)
	return out


static func _lfo(i: int, n: int, cycles: float, phase: float = 0.0) -> float:
	return 0.5 + 0.5 * sin(TAU * (cycles * float(i) / n + phase))


# ---------- die Geräusche ----------

static func _generate(sound: String, v: int) -> AudioStreamWAV:
	match sound:
		"step":
			# Schritt auf Gras/Waldboden: dumpfer Tritt + raschelndes Laub
			var thud := _env(_nf(_white(0.2), 0, randf_range(220.0, 320.0), 0.8), 0.004, 28.0, 1.0)
			thud = _add(thud, _sine(0.12, randf_range(95.0, 130.0), 55.0, 34.0, 0.5, 0.003))
			var leaf := _env(_nf(_white(0.25), 1, randf_range(1800.0, 2800.0), 1.5), 0.012, 16.0, 0.7)
			return _wav(_add(thud, leaf, randf_range(0.01, 0.035)), 0.6)
		"reload":
			# Nachladen: Magazin raus (Klick), Patronen (Ticks), Verschluss (Klack)
			var s := _env(_nf(_white(0.05), 1, 3500.0, 1.2), 0.0005, 90.0, 0.8)
			s = _add(s, _env(_nf(_white(0.04), 0, 700.0, 1.0), 0.0005, 110.0, 0.6), 0.0)
			for k in range(5):
				s = _add(s, _env(_nf(_white(0.02), 1, randf_range(2500.0, 3500.0), 1.5), 0.0003, 200.0, 0.5), 0.45 + k * 0.1)
			s = _add(s, _env(_nf(_white(0.07), 1, 2200.0, 1.0), 0.0005, 70.0, 0.9), 1.15)
			s = _add(s, _env(_nf(_white(0.08), 0, 500.0, 0.9), 0.0008, 60.0, 0.9), 1.15)
			return _wav(s, 0.8)
		"airgun":
			# Luftgewehr: scharfes Pfff, kurzer Knack und metallisches Nachklingen
			var s := _env(_nf(_white(0.18), 1, randf_range(3500.0, 5000.0), 0.9), 0.0008, 32.0, 1.0)
			s = _add(s, _env(_nf(_white(0.08), 0, 900.0, 0.8), 0.0005, 70.0, 0.9))
			s = _add(s, _sine(0.12, randf_range(1500.0, 1900.0), 600.0, 30.0, 0.35, 0.0005), 0.004)
			return _wav(s, 0.8)
		"step_gravel":
			var s := _env(_nf(_white(0.15), 0, 400.0, 0.8), 0.004, 40.0, 0.7)
			var grains := int(randf_range(7, 12))
			for k in range(grains):
				var gr := _env(_nf(_white(0.02), 1, randf_range(2000.0, 5500.0), 1.2), 0.001, 150.0, randf_range(0.3, 1.0) * (1.0 - float(k) / grains * 0.6))
				s = _add(s, gr, randf_range(0.0, 0.13))
			return _wav(s, 0.6)
		"splash":
			var s := _env(_nf(_white(1.2), 1, 800.0, 1.0), 0.02, 4.5, 1.2)
			s = _add(s, _env(_sweep(0.6, 3000.0, 1200.0, 1.5), 0.004, 9.0, 0.5))
			s = _add(s, _sine(0.3, 150.0, 45.0, 11.0, 0.9, 0.004))
			for k in range(18):
				s = _add(s, _bubble(randf_range(320.0, 1500.0), randf_range(0.15, 0.4)), randf_range(0.04, 0.8))
			return _wav(s, 0.85)
		"splash_small":
			var s := _env(_nf(_white(0.5), 1, 1500.0, 1.2), 0.004, 13.0, 0.6)
			s = _add(s, _sine(0.14, 260.0, 110.0, 24.0, 0.5, 0.003))
			for k in range(int(randf_range(3, 6))):
				s = _add(s, _bubble(randf_range(500.0, 1800.0), randf_range(0.2, 0.45)), randf_range(0.02, 0.3))
			return _wav(s, 0.7)
		"pop":
			# Flasche öffnen: Plopp + feines Zischen
			var s := _sine(0.12, 520.0, 260.0, 45.0, 0.9, 0.001, 0.2)
			s = _add(s, _env(_nf(_white(0.05), 0, 1600.0, 0.7), 0.0005, 70.0, 0.9))
			s = _add(s, _env(_nf(_white(0.6), 2, 4500.0, 0.7), 0.01, 5.5, 0.18), 0.03)
			return _wav(s, 0.75)
		"chest_open":
			# Schloss klackt, altes Scharnier knarzt (Haft-Gleit-Impulse), Deckel schlägt an, Münzen klimpern
			var s := _env(_nf(_white(0.05), 1, 2600.0, 2.0), 0.0003, 100.0, 0.9)
			s = _add(s, _env(_nf(_white(0.04), 0, 600.0, 1.0), 0.0005, 90.0, 0.6))
			var f := 260.0
			var t := 0.12
			while t < 0.78:
				f *= randf_range(1.02, 1.09)
				var seg := _env(_nf(_white(0.07), 1, f, 9.0), 0.004, 30.0, randf_range(0.5, 0.9))
				seg = _add(seg, _sine(0.07, f * 1.5, f * 1.6, 28.0, 0.25, 0.003))
				s = _add(s, seg, t)
				t += randf_range(0.035, 0.06)
			s = _add(s, _sine(0.3, 105.0, 52.0, 14.0, 0.8, 0.002, 0.2), 0.82)
			s = _add(s, _env(_nf(_white(0.12), 0, 700.0, 0.8), 0.001, 45.0, 0.7), 0.82)
			for k in range(9):
				var fr := randf_range(2300.0, 4600.0)
				s = _add(s, _sine(0.28, fr, fr * 0.98, 13.0, 0.28, 0.0005, 0.35), 0.86 + k * randf_range(0.03, 0.07))
			return _wav(s, 0.85)
		"thunk":
			var s := _sine(0.4, randf_range(95.0, 115.0), 48.0, 15.0, 0.9, 0.002, 0.15)
			s = _add(s, _env(_nf(_white(0.15), 0, 650.0, 0.8), 0.001, 40.0, 1.0))
			s = _add(s, _env(_nf(_white(0.3), 1, randf_range(380.0, 520.0), 5.0), 0.001, 22.0, 0.6))
			return _wav(s, 0.85)
		"trunk_open":
			# Entriegeln (Klack), Scharnier-Quietschen, sanftes Anschlagen der Dämpfer
			var s := _env(_nf(_white(0.06), 1, 2800.0, 2.5), 0.0003, 100.0, 1.0)
			s = _add(s, _sine(0.05, 900.0, 700.0, 80.0, 0.5, 0.0005))
			s = _add(s, _env(_nf(_white(0.12), 0, 250.0, 0.8), 0.002, 30.0, 0.9), 0.06)
			var creak := _sine(0.45, 330.0, 470.0, 3.0, 0.16, 0.05, 0.6)
			for i in range(creak.size()):
				creak[i] *= 0.6 + 0.4 * sin(i * 0.03)
			s = _add(s, creak, 0.08)
			s = _add(s, _env(_nf(_white(0.4), 1, 1400.0, 3.0), 0.1, 4.0, 0.12), 0.1)
			s = _add(s, _sine(0.25, 85.0, 50.0, 18.0, 0.55, 0.002), 0.55)
			s = _add(s, _env(_nf(_white(0.1), 0, 500.0, 0.8), 0.002, 40.0, 0.6), 0.55)
			return _wav(s, 0.8)
		"trunk_close":
			# Schwung, dumpfer Schlag der Klappe, Schlossfalle rastet ein
			var s := _env(_sweep(0.4, 300.0, 900.0, 1.5), 0.15, 5.0, 0.25)
			s = _add(s, _sine(0.3, 95.0, 45.0, 14.0, 0.95, 0.002, 0.2), 0.3)
			s = _add(s, _env(_nf(_white(0.15), 0, 700.0, 0.8), 0.001, 30.0, 0.9), 0.3)
			s = _add(s, _env(_nf(_white(0.2), 1, 1700.0, 4.0), 0.001, 30.0, 0.3), 0.3)
			s = _add(s, _env(_nf(_white(0.06), 1, 3000.0, 2.5), 0.0003, 120.0, 0.55), 0.38)
			s = _add(s, _sine(0.05, 1000.0, 800.0, 90.0, 0.35, 0.0005), 0.38)
			return _wav(s, 0.9)
		"crate":
			# Bierkasten abstellen: Plastikkasten-Knall, Flaschen klirren aneinander
			var s := _sine(0.25, 105.0, 55.0, 18.0, 0.8, 0.002, 0.2)
			s = _add(s, _env(_nf(_white(0.12), 0, 900.0, 0.8), 0.001, 38.0, 0.9))
			s = _add(s, _env(_nf(_white(0.2), 1, randf_range(420.0, 560.0), 4.0), 0.001, 24.0, 0.45))
			for k in range(int(randf_range(5, 9))):
				var f := randf_range(2600.0, 5200.0)
				var o := randf_range(0.0, 0.3)
				s = _add(s, _sine(0.25, f, f, randf_range(14.0, 28.0), randf_range(0.08, 0.22), 0.0003), o)
				s = _add(s, _sine(0.18, f * 1.62, f * 1.62, 30.0, 0.07, 0.0003), o)
				s = _add(s, _env(_nf(_white(0.01), 2, 3000.0, 0.8), 0.0002, 250.0, 0.4), o)
			return _wav(s, 0.85)
		"retch":
			# Würgen: drei raue, tiefe Anläufe
			var s := PackedFloat32Array()
			for k in range(3):
				var o := k * randf_range(0.34, 0.42)
				var n := int(SR * 0.28)
				var raw := PackedFloat32Array()
				raw.resize(n)
				var ph := 0.0
				for i in range(n):
					var t := float(i) / SR
					ph += TAU * (115.0 + 30.0 * t / 0.28 + 8.0 * sin(t * 50.0)) / SR
					var saw := fposmod(ph / TAU, 1.0) * 2.0 - 1.0
					raw[i] = saw * sin(PI * t / 0.28) * (0.6 + 0.4 * sin(t * TAU * 24.0))
				var f1 := _filt(raw, 1, 650.0, 2.0)
				s = _add(s, f1, o, 0.5 + 0.2 * k)
				s = _add(s, _env(_nf(_white(0.25), 1, 900.0, 1.5), 0.05, 8.0, 0.3), o)
			return _wav(_sat(s, 2.0), 0.8)
		"vomit":
			# Schwall: nasses Rauschen mit Gurgeln und Platschen
			var s := _env(_nf(_white(1.8), 1, 600.0, 0.9), 0.08, 1.8, 1.0)
			s = _add(s, _env(_sweep(1.2, 1800.0, 700.0, 1.2), 0.1, 3.0, 0.5))
			for k in range(22):
				s = _add(s, _bubble(randf_range(180.0, 700.0), randf_range(0.2, 0.5)), randf_range(0.0, 1.5))
			s = _add(s, _sine(0.3, 120.0, 60.0, 10.0, 0.5, 0.01), 0.0)
			s = _add(s, _env(_nf(_white(0.3), 1, 1100.0, 1.0), 0.002, 14.0, 0.8), 1.2)
			s = _add(s, _bubble(300.0, 0.4), 1.3)
			return _wav(s, 0.85)
		"whoosh":
			var s := _filt(_sweep(0.65, 500.0, 2400.0, 2.0), 0, 3200.0, 0.7)
			var out := PackedFloat32Array()
			out.resize(s.size())
			for i in range(s.size()):
				var w := float(i) / s.size()
				out[i] = s[i] * sin(w * PI) * sin(w * PI)
			return _wav(out, 0.6)
		"plop":
			var s := _sine(0.3, 300.0, 120.0, 13.0, 0.8, 0.003, 0.1)
			s = _add(s, _env(_nf(_white(0.12), 0, 500.0, 0.8), 0.002, 30.0, 0.8))
			s = _add(s, _bubble(randf_range(260.0, 420.0), 0.4), 0.07)
			s = _add(s, _bubble(randf_range(500.0, 800.0), 0.25), 0.13)
			return _wav(s, 0.8)
		"gulp":
			var s := PackedFloat32Array()
			for k in range(2):
				var o := k * randf_range(0.2, 0.28)
				var body := _sine(0.14, randf_range(170.0, 210.0), 90.0, 16.0, 0.8, 0.012, 0.3)
				s = _add(s, body, o)
				s = _add(s, _env(_nf(_white(0.14), 1, 750.0, 2.0), 0.01, 18.0, 0.6), o)
				s = _add(s, _bubble(randf_range(500.0, 900.0), 0.2), o + 0.05)
			return _wav(s, 0.75)
		"crunch":
			var s := PackedFloat32Array()
			for k in range(int(randf_range(4, 7))):
				var o := randf_range(0.0, 0.28)
				s = _add(s, _env(_nf(_white(0.04), 2, randf_range(1200.0, 2800.0), 0.8), 0.001, randf_range(70.0, 130.0), randf_range(0.5, 1.0)), o)
				s = _add(s, _env(_nf(_white(0.05), 0, 700.0, 0.8), 0.001, 70.0, 0.5), o)
			return _wav(s, 0.8)
		"snap":
			var s := _env(_nf(_white(0.12), 2, 1800.0, 0.7), 0.0003, 60.0, 1.2)
			for pair in [[1180.0, 22.0, 0.35], [2310.0, 30.0, 0.25], [3470.0, 42.0, 0.15]]:
				s = _add(s, _sine(0.4, pair[0], pair[0], pair[1], pair[2], 0.0005))
			s = _add(s, _sine(0.3, 150.0, 60.0, 16.0, 0.4, 0.001), 0.003)
			s = _add(s, _sine(0.5, 640.0, 560.0, 11.0, 0.12, 0.001), 0.02)
			return _wav(s, 0.9)
		"reel":
			# Angelrolle: schnelles Ratschen
			var s := PackedFloat32Array()
			for k in range(4):
				s = _add(s, _env(_nf(_white(0.02), 1, 3200.0 + k * 150.0, 2.5), 0.0003, 160.0, 0.9), k * 0.035)
			return _wav(s, 0.5)
		"fanfare":
			var s := PackedFloat32Array()
			var k := 0
			for f in [523.0, 659.0, 784.0, 1047.0]:
				s = _add(s, _sine(0.4, f, f, 5.0, 0.5, 0.004, 0.25), k * 0.11)
				k += 1
			s = _add(s, _sine(0.9, 1047.0, 1047.0, 3.0, 0.4, 0.004, 0.3), 0.44)
			return _wav(s, 0.7)
		"fail":
			var s := _sine(0.5, 330.0, 140.0, 4.0, 0.7, 0.004, 0.3)
			s = _add(s, _sine(0.5, 247.0, 100.0, 4.0, 0.5, 0.004, 0.2), 0.12)
			return _wav(s, 0.7)
		"ding":
			var s := _sine(0.6, 1568.0, 1568.0, 6.0, 0.5, 0.001, 0.2)
			s = _add(s, _sine(0.5, 2349.0, 2349.0, 9.0, 0.25, 0.001))
			return _wav(s, 0.6)
		"sizzle":
			var s := _env(_nf(_white(0.7), 2, 5200.0, 0.7), 0.02, 3.0, 0.8)
			for k in range(14):
				s = _add(s, _env(_nf(_white(0.01), 1, randf_range(3000.0, 8000.0), 2.0), 0.0003, 250.0, randf_range(0.3, 1.0)), randf_range(0.0, 0.6))
			return _wav(s, 0.55)
		"click":
			var s := _env(_nf(_white(0.05), 1, randf_range(2600.0, 3600.0), 2.5), 0.0003, 110.0, 1.0)
			s = _add(s, _sine(0.04, 1700.0, 1500.0, 140.0, 0.4, 0.0003))
			s = _add(s, _env(_nf(_white(0.06), 1, 1200.0, 2.0), 0.0003, 90.0, 0.4), 0.03)
			return _wav(s, 0.6)
		"spark":
			# Feuerstahl: kratzendes Schaben mit hellen Funken
			var s := _env(_nf(_white(0.3), 2, 3500.0, 0.7), 0.01, 9.0, 0.35)
			s = _add(s, _env(_nf(_white(0.28), 1, 5500.0, 1.5), 0.02, 12.0, 0.25))
			for k in range(22):
				s = _add(s, _env(_nf(_white(0.012), 1, randf_range(4500.0, 9000.0), 2.0), 0.0003, 200.0, randf_range(0.3, 1.0)), randf_range(0.0, 0.26))
			return _wav(s, 0.65)
		"ignite":
			var s := _env(_nf(_white(1.6), 0, 550.0, 0.7), 0.12, 2.4, 1.4)
			s = _add(s, _env(_nf(_white(1.2), 1, 1600.0, 0.6), 0.05, 4.0, 0.4))
			for k in range(14):
				s = _add(s, _env(_nf(_white(0.02), 1, randf_range(1500.0, 4000.0), 1.5), 0.0003, 160.0, randf_range(0.3, 0.9)), randf_range(0.15, 1.3))
			return _wav(s, 0.8)
		"chirp":
			return _wav(_bird(v), 0.6)
		"cricket":
			var s := PackedFloat32Array()
			var f := randf_range(4300.0, 4900.0)
			for burst in range(2 + v % 2):
				for k in range(3):
					var pulse := _sine(0.016, f, f, 0.0, 0.5, 0.004)
					for i in range(pulse.size()):
						pulse[i] *= sin(PI * float(i) / pulse.size())
					s = _add(s, pulse, burst * 0.21 + k * 0.032)
			return _wav(s, 0.45)
		"owl":
			var s := PackedFloat32Array()
			s = _add(s, _hoot(0.16, 430.0, 400.0), 0.0)
			s = _add(s, _hoot(0.55, 420.0, 340.0), 0.3)
			s = _add(s, _hoot(0.16, 430.0, 400.0), 1.3)
			s = _add(s, _hoot(0.55, 420.0, 340.0), 1.6)
			return _wav(_reverb(s, 0.8, 0.9), 0.7)
		"croak":
			var s := PackedFloat32Array()
			for k in range(1 + v % 2 + 1):
				s = _add(s, _croak(), k * 0.3)
			return _wav(s, 0.7)
		"quack":
			var s := PackedFloat32Array()
			for k in range(2 if v == 2 else 1):
				s = _add(s, _quack(), k * 0.28)
			return _wav(s, 0.75)
		"burp":
			var n := int(SR * 0.7)
			var raw := PackedFloat32Array()
			raw.resize(n)
			var ph := 0.0
			for i in range(n):
				var t := float(i) / SR
				ph += TAU * (95.0 - 40.0 * t + 6.0 * sin(t * 40.0)) / SR
				var saw := fposmod(ph / TAU, 1.0) * 2.0 - 1.0
				raw[i] = saw * minf(t / 0.06, 1.0) * exp(-2.8 * t)
			var f1 := _filt(raw, 1, 520.0, 2.5)
			var f2 := _filt(raw, 1, 1000.0, 3.0)
			var s := _add(f1, f2, 0.0, 0.5)
			s = _add(s, _env(_nf(_white(0.5), 0, 400.0, 0.7), 0.05, 5.0, 0.3))
			return _wav(_sat(s, 1.8), 0.8)
		"rumble":
			var s := _env(_nf(_white(2.2), 0, 110.0, 0.7), 0.25, 1.4, 5.0)
			s = _add(s, _env(_nf(_white(2.0), 0, 260.0, 0.7), 0.1, 2.0, 1.2))
			s = _add(s, _sine(2.0, 42.0, 34.0, 1.6, 0.5, 0.2))
			return _wav(_reverb(s, 0.4, 0.5), 0.85)
		"buzz":
			var n := int(SR * 1.2)
			var raw := PackedFloat32Array()
			raw.resize(n)
			var ph := 0.0
			for i in range(n):
				var t := float(i) / SR
				ph += TAU * (190.0 + 12.0 * sin(t * 9.0) + 25.0 * sin(t * 2.3)) / SR
				var saw := fposmod(ph / TAU, 1.0) * 2.0 - 1.0
				raw[i] = saw * (0.65 + 0.35 * sin(t * TAU * 38.0)) * minf(t / 0.1, 1.0) * minf((1.2 - t) / 0.2, 1.0)
			var s := _filt(raw, 1, 900.0, 0.9)
			s = _add(s, _filt(raw, 2, 2400.0, 0.7), 0.0, 0.3)
			return _wav(s, 0.7)
		"trickle":
			var n := 1.4
			var s := _env(_nf(_white(n), 1, 2600.0, 0.8), 0.12, 0.0, 0.6)
			var wob := _nf(_white(n), 0, 12.0, 0.7)
			for i in range(s.size()):
				s[i] *= 0.6 + 2.5 * wob[i]
			for k in range(26):
				s = _add(s, _bubble(randf_range(500.0, 2000.0), randf_range(0.1, 0.3)), randf_range(0.1, n - 0.2))
			for i in range(s.size()):
				s[i] *= minf(float(s.size() - i) / (SR * 0.25), 1.0)
			return _wav(s, 0.55)
		"toast":
			var s := _sine(0.7, 880.0, 880.0, 7.0, 0.6, 0.003)
			s = _add(s, _sine(0.5, 1760.0, 1760.0, 11.0, 0.25, 0.003))
			s = _add(s, _sine(0.3, 2640.0, 2640.0, 18.0, 0.1, 0.003))
			return _wav(s, 0.5)
		"rain":
			# Gleichmäßiges Prasseln: gefiltertes Rauschen plus vieler kleiner Tropfen
			var d := 5.0
			var s := _nf(_white(d + 0.6), 1, 2600.0, 0.5)
			s = _add(s, _nf(_white(d + 0.6), 0, 900.0, 0.6), 0.0, 0.8)
			for i in range(s.size()):
				s[i] *= 0.55 + 0.45 * _lfo(i, s.size(), 6.0, 0.2)
			for k in range(int(d * 60)):
				s = _add(s, _env(_nf(_white(0.012), 1, randf_range(3500.0, 7000.0), 1.5), 0.0003, 260.0, randf_range(0.2, 0.7)), randf_range(0.0, d + 0.5))
			s.resize(int(SR * (d + 0.6)))
			return _wav(_loopify(s, 0.6), 0.55, true)
		"thunder":
			# Erst ein knackender Schlag, dann langes Grollen
			var s := _env(_nf(_white(0.5), 1, 1500.0, 0.6), 0.002, 9.0, 0.9)
			var rum := _env(_nf(_white(4.0), 0, randf_range(110.0, 170.0), 0.7), 0.35, 1.0, 1.0)
			for i in range(rum.size()):
				rum[i] *= 0.6 + 0.4 * _lfo(i, rum.size(), 9.0, randf())
			s = _add(s, rum, 0.05)
			s = _add(s, _sine(1.2, 62.0, 38.0, 2.2, 0.8, 0.05), 0.1)
			return _wav(s, 0.9)
		"wind":
			var d := 6.0
			var raw := _white(d + 0.8)
			var n := raw.size()
			var out := PackedFloat32Array()
			out.resize(n)
			var low := 0.0
			var band := 0.0
			for i in range(n):
				var fc := 260.0 + 380.0 * _lfo(i, n, 3.0) + 160.0 * _lfo(i, n, 7.0, 0.3)
				var f := 2.0 * sin(PI * fc / SR)
				low += f * band
				var high := raw[i] - low - 0.9 * band
				band += f * high
				out[i] = band * (0.35 + 0.65 * _lfo(i, n, 2.0, 0.1) * _lfo(i, n, 5.0, 0.6))
			return _wav(_loopify(_filt(out, 0, 1100.0, 0.7), 0.8), 0.7, true)
		"fire":
			var d := 4.0
			var s := _env(_nf(_white(d + 0.5), 0, 420.0, 0.7), 0.0, 0.0, 1.2)
			s = _add(s, _env(_nf(_white(d + 0.5), 1, 1200.0, 0.5), 0.0, 0.0, 0.18))
			for k in range(int(d * 22)):
				var fz := randf_range(900.0, 4500.0)
				var c := _env(_nf(_white(0.03), 1, fz, 1.5), 0.0004, randf_range(90.0, 220.0), randf_range(0.3, 1.4))
				s = _add(s, c, randf_range(0.0, d + 0.4))
			s.resize(int(SR * (d + 0.5)))
			return _wav(_loopify(s, 0.5), 0.7, true)
		"water":
			var d := 5.0
			var s := _nf(_white(d + 0.6), 0, 700.0, 0.7)
			for i in range(s.size()):
				s[i] *= 0.4 + 0.6 * _lfo(i, s.size(), 4.0)
			for k in range(int(d * 5)):
				s = _add(s, _bubble(randf_range(400.0, 1200.0), 0.1), randf_range(0.0, d + 0.4))
			s.resize(int(SR * (d + 0.6)))
			return _wav(_loopify(s, 0.6), 0.6, true)
	return null


## Vogelgesang: ein paar Töne mit Vibrato und Glissando, je Variante ein anderer Vogel.
static func _bird(v: int) -> PackedFloat32Array:
	var s := PackedFloat32Array()
	var base := randf_range(2600.0, 3800.0)
	var notes: int = [3, 2, 4, 5, 3][v % 5]
	var gap: float = [0.11, 0.2, 0.08, 0.06, 0.15][v % 5]
	for k in range(notes):
		var dur := randf_range(0.05, 0.1)
		var n := int(SR * dur)
		var note := PackedFloat32Array()
		note.resize(n)
		var f0 := base * randf_range(0.8, 1.3)
		var f1 := f0 * randf_range(0.7, 1.5)
		var vib := randf_range(0.0, 0.08) if v != 1 else 0.0
		var ph := 0.0
		for i in range(n):
			var t := float(i) / n
			var fr := lerpf(f0, f1, t) * (1.0 + vib * sin(TAU * 38.0 * t * dur))
			ph += TAU * fr / SR
			note[i] = (sin(ph) + 0.25 * sin(2.0 * ph)) * sin(PI * t) * 0.6
		s = _add(s, note, k * (dur + gap))
	return s


static func _hoot(dur: float, f0: float, f1: float) -> PackedFloat32Array:
	var n := int(SR * dur)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	for i in range(n):
		var t := float(i) / n
		ph += TAU * lerpf(f0, f1, t) / SR
		var e := sin(PI * pow(t, 0.6))
		out[i] = (sin(ph) + 0.35 * sin(2.0 * ph) + 0.1 * sin(3.0 * ph)) * e * 0.6
	return out


static func _croak() -> PackedFloat32Array:
	var dur := 0.22
	var n := int(SR * dur)
	var raw := PackedFloat32Array()
	raw.resize(n)
	var ph := 0.0
	for i in range(n):
		var t := float(i) / SR
		ph += TAU * (230.0 - 70.0 * t / dur) / SR
		var pulse := maxf(0.0, sin(TAU * 52.0 * t))
		raw[i] = sin(ph) * pulse * sin(PI * t / dur)
	var s := _filt(raw, 1, 900.0, 1.2)
	return _add(s, _filt(raw, 1, 1700.0, 1.5), 0.0, 0.4)


static func _quack() -> PackedFloat32Array:
	var dur := 0.2
	var n := int(SR * dur)
	var raw := PackedFloat32Array()
	raw.resize(n)
	var ph := 0.0
	for i in range(n):
		var t := float(i) / SR
		ph += TAU * (470.0 - 120.0 * t / dur + 18.0 * sin(t * 60.0)) / SR
		var saw := fposmod(ph / TAU, 1.0) * 2.0 - 1.0
		raw[i] = saw * minf(t / 0.012, 1.0) * exp(-7.0 * t)
	var s := _filt(raw, 1, 1100.0, 3.0)
	s = _add(s, _filt(raw, 1, 2300.0, 3.5), 0.0, 0.6)
	return _add(s, _filt(raw, 1, 600.0, 2.5), 0.0, 0.5)
