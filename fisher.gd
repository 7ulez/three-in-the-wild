class_name Fisher
extends Node
## Angeln: Rute tragen, T = Methode wechseln (Grund / Pose / Spinn), Linksklick = auswerfen,
## beim Biss Linksklick = anschlagen, dann Linksklick halten = einholen (Schnurspannung beachten!).

enum S { IDLE, WAITING, BITE, FIGHT, RETRIEVE }
const MODES: Array = ["Grundangeln (Karpfen, Aal, Nacht!)", "Posenangeln (Friedfisch)", "Spinnangeln (Hecht)"]

const FISH: Dictionary = {
	"Karpfen": {"kg": [2.0, 14.0], "strength": 1.0, "color": Color(0.6, 0.5, 0.22)},
	"Hecht": {"kg": [1.5, 9.0], "strength": 1.2, "color": Color(0.3, 0.46, 0.25)},
	"Rotauge": {"kg": [0.1, 0.5], "strength": 0.3, "color": Color(0.75, 0.75, 0.8)},
	"Barsch": {"kg": [0.2, 1.2], "strength": 0.5, "color": Color(0.5, 0.55, 0.25)},
	"Brasse": {"kg": [0.5, 2.5], "strength": 0.6, "color": Color(0.7, 0.62, 0.45)},
	"Riesenwels": {"kg": [30.0, 130.0], "strength": 1.5, "color": Color(0.24, 0.24, 0.2)},
	"Aal": {"kg": [0.4, 3.0], "strength": 0.9, "color": Color(0.14, 0.16, 0.08)},
}

var player: Player
var state: int = S.IDLE
var mode: int = 0
var target: Vector3 = Vector3.ZERO
var cast_dist: float = 10.0
var wait_left: float = 0.0
var bite_left: float = 0.0
var retrieve_t: float = 0.0
var fish_name: String = ""
var fish_kg: float = 0.0
var distance: float = 0.0
var tension: float = 0.0
var running: bool = false
var run_timer: float = 1.5
var wait_scale: float = 1.0          # für Tests
var test_reel: int = -1              # für Tests: 1 = Einholen simulieren, 0 = nicht
var _alarm_cd: float = 0.0
var _t: float = 0.0

var bobber: MeshInstance3D
var _ripple_cd: float = 0.0
var line: MeshInstance3D
var alarm: AudioStreamPlayer
var panel: VBoxContainer
var status: Label
var tension_bar: ProgressBar
var led: OmniLight3D
var hud: MiniHud
var stamina: float = 1.0             # Kraft des Fisches (1 = frisch, 0 = erschöpft)
var pull: int = 0                    # Zugrichtung beim Fluchtlauf: -1 links, +1 rechts
var jump_t: float = 0.0              # >0: Fisch springt, Maustaste loslassen!
var jump_cd: float = 6.0
var perfect_hook: bool = false
var bite_el: float = 0.0
var _reel_cd: float = 0.0
var _leap: Node3D = null
var _leap_t: float = 0.0
var _good_t: float = 0.0             # Zeit im grünen Bereich (für Bonus)


func setup(p: Player, layer: CanvasLayer) -> void:
	player = p
	bobber = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.07
	sm.height = 0.14
	sm.radial_segments = 8
	sm.rings = 4
	bobber.mesh = sm
	bobber.material_override = Util.mat(Color(0.95, 0.2, 0.15))
	bobber.visible = false
	bobber.top_level = true
	add_child(bobber)

	line = MeshInstance3D.new()
	line.mesh = ImmediateMesh.new()
	var lm := StandardMaterial3D.new()
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lm.albedo_color = Color(0.9, 0.9, 0.9)
	line.material_override = lm
	line.top_level = true
	add_child(line)

	led = OmniLight3D.new()
	led.light_color = Color(1, 0.1, 0.1)
	led.omni_range = 4.0
	led.light_energy = 0.0
	player.add_child(led)
	led.position = Vector3(0.3, 1.4, -1.0)

	alarm = AudioStreamPlayer.new()
	alarm.stream = _make_beep()
	alarm.volume_db = -4.0
	add_child(alarm)

	panel = VBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	panel.position = Vector2(-170, -230)
	panel.custom_minimum_size = Vector2(340, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.theme = UI.theme()
	layer.add_child(panel)
	status = Label.new()
	status.add_theme_font_size_override("font_size", 22)
	status.add_theme_color_override("font_color", UI.PAPER)
	status.add_theme_constant_override("outline_size", 7)
	status.add_theme_color_override("font_outline_color", UI.SHADOW)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(status)
	tension_bar = ProgressBar.new()
	tension_bar.max_value = 1.0
	tension_bar.show_percentage = false
	tension_bar.custom_minimum_size = Vector2(340, 18)
	tension_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(tension_bar)
	panel.visible = false
	tension_bar.visible = false
	hud = MiniHud.new()
	layer.add_child(hud)


## Zustand der ausgeworfenen Rute (für den Rutenständer). Leer, wenn man sie nicht ablegen kann.
func export_state() -> Dictionary:
	if state == S.RETRIEVE or state == S.FIGHT:
		return {}
	return {"mode": mode, "st": state, "target": target, "cast_dist": cast_dist,
		"wait_left": wait_left, "bite_left": bite_left, "fish_name": fish_name, "fish_kg": fish_kg}


func import_state(d: Dictionary) -> void:
	mode = int(d.get("mode", mode))
	var st: int = int(d.get("st", S.IDLE))
	if st == S.IDLE:
		return
	target = d["target"]
	cast_dist = d["cast_dist"]
	bobber.visible = true
	bobber.global_position = target
	if st == S.BITE:
		fish_name = d["fish_name"]
		fish_kg = d["fish_kg"]
		state = S.BITE
		bite_el = 0.0
		bite_left = maxf(float(d["bite_left"]), 3.0)
		player.toast("Es hängt etwas an der Rute! Linksklick = anschlagen!", 3.0)
	else:
		state = S.WAITING
		wait_left = d["wait_left"]


static func make_beep() -> AudioStreamWAV:
	return new()._make_beep()


func _make_beep() -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * 0.18)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in range(n):
		var v := int(sin(TAU * 1100.0 * float(i) / float(rate)) * 12000.0 * (1.0 - float(i) / float(n)))
		data.encode_s16(i * 2, v)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.data = data
	return w


func has_rod() -> bool:
	return player.held != null and player.held.item_name == "Angelrute"


func rod_tip() -> Vector3:
	var fwd := -player.head.global_transform.basis.z
	return player.head.global_position + fwd * 1.5 + player.head.global_transform.basis.x * 0.35 + Vector3(0, -0.15, 0)


func cycle_mode() -> void:
	if state != S.IDLE:
		player.toast("Erst die Schnur einholen (Rechtsklick).", 2.0)
		return
	mode = (mode + 1) % MODES.size()
	player.toast("Methode: %s" % MODES[mode], 2.5)


## Wasserpunkt, auf den man zielt (Ebene y = Wasserhöhe) oder Vector3.INF
func aim_point() -> Vector3:
	var o := player.head.global_position
	var f := -player.head.global_transform.basis.z
	var p: Vector3
	if f.y < -0.02:
		var t := (0.05 - o.y) / f.y
		t = minf(t, 30.0)
		p = o + f * t
	else:
		var fxz := Vector3(f.x, 0, f.z).normalized()
		p = o + fxz * 30.0
		p.y = 0.05
	var main := player.get_parent()
	if main.get("lake_root") == null:
		return Vector3.INF
	var lp: Vector3 = p - (main.lake_root as Node3D).global_position
	if LakeShape.contains(Vector2(lp.x, lp.z)):
		return p
	return Vector3.INF


func _unhandled_input(event: InputEvent) -> void:
	if player == null or player.placing or player.seat != null or player.sleeping:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if Game.is_captured() and (event as InputEventKey).keycode == KEY_T and has_rod():
			cycle_mode()
	elif event is InputEventMouseButton and event.pressed and has_rod():
		var mb := event as InputEventMouseButton
		# Anschlag auch dann, wenn die Maus gerade nicht eingefangen ist (z.B. nach Esc oder Fischereiaufseher)
		if mb.button_index == MOUSE_BUTTON_LEFT and (Game.is_captured() or state == S.BITE):
			_left_click()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and state != S.IDLE and state != S.FIGHT:
			reel_in("Schnur eingeholt.")


func _left_click() -> void:
	match state:
		S.IDLE:
			if Game.fish_ban_day == Game.day_count:
				player.toast("Angelverbot bis morgen früh - der Fischereiaufseher hat es so entschieden.", 4.0)
				return
			if Game.beer_debt:
				player.toast("Erst die neue Kiste Bier vom Parkplatz ins Camp tragen und abstellen - dann darfst du wieder angeln.", 4.0)
				return
			var p := aim_point()
			if p == Vector3.INF:
				player.toast("Ziel auf das Wasser, um auszuwerfen.", 2.0)
				return
			cast(p)
		S.BITE:
			hook()
		S.RETRIEVE, S.WAITING, S.FIGHT:
			pass


func cast(p: Vector3) -> void:
	player.fish_cast_t = 0.8
	Sfx.play("whoosh", player.global_position, -2.0)
	get_tree().create_timer(0.5).timeout.connect(func() -> void:
		Sfx.play("splash_small", p)
		Fx.ripple(get_tree().current_scene, p, 0.8))
	target = p
	cast_dist = player.head.global_position.distance_to(p)
	bobber.visible = true
	bobber.global_position = p
	wait_scale = wait_scale
	if mode == 2:
		state = S.RETRIEVE
		retrieve_t = 0.0
		player.toast("Kunstköder ausgeworfen. Linksklick halten = einholen.", 3.0)
	else:
		state = S.WAITING
		wait_left = _roll_wait()
		if mode == 0:
			player.toast("Grundblei liegt. Der Bissanzeiger ist scharf.", 3.0)
		else:
			player.toast("Pose treibt. Warte auf den Biss.", 3.0)


func _roll_wait() -> float:
	var w := 10.0
	match mode:
		0:
			w = randf_range(8.0, 20.0) if Game.is_night() else randf_range(22.0, 50.0)
		1:
			w = randf_range(8.0, 18.0)
	if Game.fish_penalty_until > Game.now():
		w *= 3.0
	if Game.treasure_found:
		w *= 0.6
	if Game.lure_until > Game.now():
		w *= 0.55
	return w * wait_scale * Weather.bite_factor()


func reel_in(msg: String) -> void:
	state = S.IDLE
	bobber.visible = false
	tension = 0.0
	led.light_energy = 0.0
	panel.visible = false
	if hud != null:
		hud.clear()
	_end_leap()
	jump_t = 0.0
	pull = 0
	var m := line.mesh as ImmediateMesh
	m.clear_surfaces()
	if msg != "":
		player.toast(msg, 2.0)


func _pick_species() -> String:
	var r := randf()
	var night := Game.is_night()
	# Ganz selten: der Riesenwels (nachts am Grund etwas wahrscheinlicher, nicht beim Spinnfischen)
	if mode != 2 and randf() < (0.012 if (night and mode == 0) else 0.004):
		return "Riesenwels"
	match mode:
		0:
			# Aale beißen vor allem nachts am Grund
			if night:
				if r < 0.15:
					return "Aal"
				return "Karpfen" if r < 0.85 else "Brasse"
			if r < 0.07:
				return "Aal"
			return "Karpfen" if r < 0.35 else ("Brasse" if r < 0.75 else "Rotauge")
		1:
			if r < 0.03:
				return "Aal"
			if r < 0.45:
				return "Rotauge"
			if r < 0.75:
				return "Barsch"
			if r < 0.9:
				return "Brasse"
			return "Karpfen"
		_:
			var pike_p := 0.3 if night else 0.55
			if player != null and player.character_name == "Marian":
				pike_p *= 1.2      # Marian hat beim Hechtangeln 20 % mehr Glück
			return "Hecht" if r < pike_p else "Barsch"
	return "Rotauge"


func _start_bite() -> void:
	fish_name = _pick_species()
	var d: Dictionary = FISH[fish_name]
	var kg_range: Array = d["kg"]
	fish_kg = snappedf(randf_range(kg_range[0], kg_range[1]) * randf_range(0.6, 1.0), 0.1)
	state = S.BITE
	bite_el = 0.0
	bite_left = 4.0 if mode == 0 else 2.0
	player.shake = 1.2
	Sfx.play("splash_small", bobber.global_position)
	if mode == 0:
		player.toast("BISSANZEIGER! Linksklick zum Anschlagen!", 3.0)
		_alarm_cd = 0.0
	elif mode == 1:
		player.toast("Die Pose taucht ab! Linksklick = anschlagen!", 3.0)
	else:
		player.toast("Ein Fisch hat auf den Köder gebissen! Linksklick = anschlagen!", 3.0)


func bite_phase() -> float:
	return fposmod(bite_el, 1.0) / 1.0


func hook() -> void:
	perfect_hook = state == S.BITE and bite_phase() > 0.72
	state = S.FIGHT
	distance = maxf(cast_dist, 6.0)
	tension = 0.2 if perfect_hook else 0.35
	stamina = 0.75 if perfect_hook else 1.0
	running = false
	pull = 0
	jump_t = 0.0
	jump_cd = randf_range(4.0, 7.0)
	_good_t = 0.0
	run_timer = randf_range(0.8, 1.6)
	led.light_energy = 0.0
	player.shake = 2.5
	Sfx.play("whoosh", player.global_position, -4.0)
	if perfect_hook:
		hud.card("PERFEKTER ANSCHLAG!", "Der Haken sitzt - der Fisch ist angeschlagen", Color(0.5, 1.0, 0.55), 1.8)
		hud.flash(Color(0.3, 1.0, 0.4, 0.8))
		Sfx.play("ding", Vector3.INF, -2.0)
	else:
		hud.card("ANGESCHLAGEN!", "Maustaste halten = kurbeln", UI.FIRE, 1.4)


func _strength() -> float:
	var d: Dictionary = FISH[fish_name]
	var kg_range: Array = d["kg"]
	var rel := fish_kg / maxf(kg_range[1], 0.1)
	return float(d["strength"]) * (0.7 + 0.5 * rel)


func _process(delta: float) -> void:
	if player == null:
		return
	_t += delta
	if state != S.IDLE and not has_rod():
		reel_in("Rute weggelegt - Schnur eingeholt.")
	_update_visuals(delta)
	match state:
		S.WAITING:
			wait_left -= delta
			if wait_left <= 0.0:
				_start_bite()
		S.RETRIEVE:
			var reeling := _reeling()
			if reeling:
				retrieve_t += delta
				var pene := 0.2 if Game.is_night() else 0.28
				if Game.fish_penalty_until > Game.now():
					pene *= 0.3
				if randf() < pene * delta * (1.0 / maxf(wait_scale, 0.05)) * 1.0:
					_start_bite()
					state = S.FIGHT
					distance = maxf(cast_dist * (1.0 - retrieve_t / 12.0), 6.0)
					tension = 0.4
					player.toast("RUMMS! Etwas Schweres hängt am Kunstköder! Einholen!", 3.0)
				elif retrieve_t >= 12.0:
					reel_in("Nichts gebissen. Nochmal auswerfen.")
		S.BITE:
			bite_left -= delta
			var prev_ph := bite_phase()
			bite_el += delta
			if bite_phase() < prev_ph:
				Sfx.play("click", Vector3.INF, -8.0, 1.4)
			bobber.scale = Vector3.ONE * (1.0 + 0.25 * sin(_t * 30.0))
			_ripple_cd -= delta
			if _ripple_cd <= 0.0:
				_ripple_cd = 0.7
				Fx.ripple(get_tree().current_scene, bobber.global_position, 0.6)
			_alarm_cd -= delta
			if mode == 0:
				led.light_energy = 3.0 if int(_t * 6.0) % 2 == 0 else 0.0
				if _alarm_cd <= 0.0:
					_alarm_cd = 0.5
					alarm.play()
			if bite_left <= 0.0:
				player.toast("Zu spät! Der Fisch hat ausgespuckt.", 2.5)
				if mode == 2:
					reel_in("")
				else:
					state = S.WAITING
					wait_left = _roll_wait()
					led.light_energy = 0.0
		S.FIGHT:
			_fight(delta)
	_update_hud()


func _reeling() -> bool:
	if test_reel >= 0:
		return test_reel == 1
	if Game.touch:
		return Game.touch_reel
	return Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED


func _counter_axis() -> int:
	# Rute neigen per Blickrichtung (Maus): -1 = nach links, +1 = nach rechts, 0 = gerade auf den Fisch.
	if player == null:
		return 0
	var to_t := target - player.global_position
	to_t.y = 0.0
	if to_t.length() < 0.5:
		return 0
	var fwd := -player.global_transform.basis.z
	fwd.y = 0.0
	if fwd.length() < 0.01:
		return 0
	var ang := fwd.signed_angle_to(to_t.normalized(), Vector3.UP)   # >0: Ziel links vom Blick -> Rute zeigt nach rechts
	if ang > 0.14:
		return 1
	if ang < -0.14:
		return -1
	return 0


func _fight(delta: float) -> void:
	var s := _strength()
	var reeling := _reeling()
	var tired := stamina < 0.25
	var counter := _counter_axis()
	if Game.touch:
		counter = -pull          # Touch: Gegenhalten klappt automatisch
	# --- Fluchtläufe ---
	run_timer -= delta
	if run_timer <= 0.0:
		running = not running
		if running:
			run_timer = randf_range(0.8, 1.6) * (0.6 if tired else 1.0)
			pull = 1 if randf() < 0.5 else -1
			player.shake = 1.5
			Sfx.play("whoosh", player.global_position, -8.0, 0.8)
		else:
			run_timer = randf_range(1.0, 2.4) * (0.7 if tired else 1.0)
			pull = 0
	var countering := running and pull != 0 and counter == -pull
	var ignoring := false
	# --- Sprung ---
	if jump_t > 0.0:
		jump_t -= delta
		if reeling:
			tension += 1.1 * delta               # Kurbeln beim Sprung = Schnur reißt
		else:
			tension -= 0.4 * delta
		if jump_t <= 0.0:
			_end_leap(true)
	else:
		jump_cd -= delta
		if jump_cd <= 0.0 and distance < cast_dist + 6.0 and distance > 3.0 and not tired:
			_start_leap()
			jump_cd = randf_range(6.0, 10.0)
	# --- Zug und Kurbeln ---
	if running:
		var pull_f := 0.55 if countering else (1.3 if ignoring else 1.0)
		tension += (0.9 if reeling else 0.1) * s * pull_f * delta
		distance += (0.2 if reeling else 0.9 + s) * s * (0.5 if countering else 1.0) * delta
		if countering:
			stamina -= 0.1 * delta
	elif jump_t <= 0.0:
		if reeling:
			var sweet := tension >= 0.3 and tension <= 0.7
			distance -= 2.3 * (1.3 if sweet else 1.0) * delta
			tension += 0.14 * delta
			stamina -= (0.075 if sweet else 0.045) * delta
			if sweet:
				_good_t += delta
		else:
			tension -= 0.45 * delta
			stamina = minf(stamina + 0.02 * delta, 1.0)
	if reeling:
		_reel_cd -= delta
		if _reel_cd <= 0.0:
			if Sfx.has_file("reel"):
				_reel_cd = 1.7      # echte Aufnahme dauert ~2 s
				Sfx.play("reel", player.global_position, -6.0)
			else:
				_reel_cd = 0.2
				Sfx.play("reel", player.global_position, -10.0, 0.9 + tension * 0.5)
	stamina = clampf(stamina, 0.0, 1.0)
	tension = clampf(tension, 0.0, 1.05)
	if tension > 0.85:
		player.shake = maxf(player.shake, 0.8)
	_update_leap(delta)
	if tension >= 1.0:
		Sfx.play("fail", Vector3.INF, -4.0)
		hud.card("SCHNUR GERISSEN!", "Der Fisch ist weg.", UI.DANGER, 2.5)
		hud.flash(Color(1, 0.2, 0.15, 0.8))
		player.shake = 4.0
		reel_in("")
	elif distance > cast_dist + 10.0:
		Sfx.play("fail", Vector3.INF, -4.0)
		hud.card("LOSGERISSEN!", "Der Fisch hat sich befreit.", UI.DANGER, 2.5)
		reel_in("")
	elif distance <= 1.5:
		_catch()


# ---------- Fischsprung ----------

func _start_leap() -> void:
	jump_t = 1.1
	_leap_t = 0.0
	var d: Dictionary = FISH[fish_name]
	var cm := clampf(24.0 * pow(fish_kg, 0.36) * 2.0, 12.0, 130.0) / 100.0
	_leap = Node3D.new()
	get_tree().current_scene.add_child(_leap)
	ItemModels.add_visual(_leap, "Fisch 1.0 kg", Vector3(cm, cm * 0.28, cm * 0.2), Color(0.45, 0.47, 0.42))
	_leap.global_position = bobber.global_position
	Sfx.play("fish_jump", bobber.global_position)
	Fx.splash(get_tree().current_scene, Vector3(bobber.global_position.x, 0.05, bobber.global_position.z), 1.2)
	player.shake = 3.0
	hud.flash(Color(1.0, 0.9, 0.2, 0.6))


func _update_leap(delta: float) -> void:
	if _leap == null:
		return
	_leap_t += delta
	var k := clampf(_leap_t / 1.1, 0.0, 1.0)
	var base := bobber.global_position
	var to_p := player.global_position - base
	to_p.y = 0
	var fwd := to_p.normalized()
	_leap.global_position = Vector3(base.x, 0.05 + sin(k * PI) * 1.3, base.z) + fwd * k * 1.2
	_leap.rotation.y = atan2(-fwd.x, -fwd.z) + PI / 2.0
	_leap.rotation.z = sin(_t * 28.0) * 0.4 + (k - 0.5) * 2.0


func _end_leap(splash: bool = false) -> void:
	if _leap == null:
		return
	if splash:
		var p := _leap.global_position
		Sfx.play("splash", p, -3.0)
		Fx.splash(get_tree().current_scene, Vector3(p.x, 0.05, p.z), 1.0)
	_leap.queue_free()
	_leap = null


func _catch() -> void:
	Sfx.play("splash", player.global_position + (-player.global_transform.basis.z) * 2.0)
	var cm := int(clampf(24.0 * pow(fish_kg, 0.36) * 2.0, 12.0, 300.0 if fish_name == "Riesenwels" else 130.0))
	Game.catches.append({"name": fish_name, "kg": fish_kg, "cm": cm})
	var d: Dictionary = FISH[fish_name]
	var len_m := cm / 100.0
	var item := Item.new().setup("%s %.1f kg" % [fish_name, fish_kg], fish_kg, Vector3(len_m, len_m * 0.28, len_m * 0.2), d["color"])
	player.get_parent().add_child(item)
	item.global_position = player.global_position + (-player.global_transform.basis.z) * 1.0 + Vector3(0, 1.0, 0)
	reel_in("")
	var rank := Leaderboard.rank_for(fish_kg)
	Leaderboard.report(fish_name, fish_kg, cm)
	var extra := ""
	if fish_name == "Karpfen" and fish_kg >= 10.0:
		extra = "  Ein Prachtkarpfen!"
	if fish_name == "Hecht" and fish_kg >= 6.0:
		extra = "  Ein Monsterhecht!"
	if fish_name == "Riesenwels":
		extra = "  EIN RIESENWELS!!!"
	if rank >= 0:
		extra += "  Platz %d auf der Bestenliste am Parkplatz!" % (rank + 1)
	player.toast("GEFANGEN! %s, %.1f kg, %d cm.%s" % [fish_name, fish_kg, cm, extra], 7.0)
	Sfx.play("fanfare", Vector3.INF, -3.0)
	Fx.splash(get_tree().current_scene, Vector3(player.global_position.x, 0.05, player.global_position.z) + (-player.global_transform.basis.z) * 2.0, 1.4)
	player.shake = 2.0
	hud.flash(Color(1.0, 0.85, 0.3, 0.8))
	var sub := "%d cm%s" % [cm, ("  ·  PLATZ %d auf der Bestenliste!" % (rank + 1)) if rank >= 0 else ""]
	hud.card("%s  %.1f kg" % [fish_name.to_upper(), fish_kg], sub, Color(1.0, 0.85, 0.3), 4.5)
	hud.burst(hud.size / 2.0, Color(1.0, 0.85, 0.3), 40, 420.0)
	if rank >= 0:
		hud.burst(hud.size / 2.0, Color(0.6, 1.0, 0.7), 30, 500.0)
	if _good_t > 5.0:
		hud.card("%s  %.1f kg" % [fish_name.to_upper(), fish_kg], sub + "  ·  sauber gedrillt!", Color(1.0, 0.85, 0.3), 4.5)


## Beim Schlafen: Hat in der Nacht etwas an der Grundrute gebissen?
func bite_during_sleep() -> bool:
	if state == S.WAITING and mode == 0 and has_rod():
		_start_bite()
		return true
	return false


func _update_visuals(delta: float) -> void:
	var m := line.mesh as ImmediateMesh
	m.clear_surfaces()
	if state == S.IDLE:
		return
	var bpos := target
	if state == S.RETRIEVE:
		bpos = target.lerp(player.global_position, clampf(retrieve_t / 12.0, 0.0, 0.95))
	elif state == S.FIGHT:
		var dir := (target - player.global_position)
		dir.y = 0
		bpos = player.global_position + dir.normalized() * distance
	bpos.y = 0.05 + (sin(_t * 3.0) * 0.015)
	if state == S.BITE:
		bpos.y = -0.04 + sin(_t * 18.0) * 0.03
	if state == S.FIGHT and running:
		bpos.y = 0.0
	bobber.global_position = bpos
	m.surface_begin(Mesh.PRIMITIVE_LINES)
	var tip := rod_tip()
	var sag := (tip + bpos) / 2.0 - Vector3(0, 0.4 * clampf(1.0 - tension, 0.0, 1.0), 0)
	var prev := tip
	for i in range(1, 9):
		var t2 := float(i) / 8.0
		var q := tip.lerp(sag, t2 * 2.0) if t2 < 0.5 else sag.lerp(bpos, (t2 - 0.5) * 2.0)
		m.surface_add_vertex(prev)
		m.surface_add_vertex(q)
		prev = q
	m.surface_end()


func _update_hud() -> void:
	panel.visible = (state == S.IDLE or state == S.WAITING or state == S.RETRIEVE) and has_rod()
	tension_bar.visible = false
	if state != S.BITE:
		bobber.scale = Vector3.ONE
	var t := ""
	match state:
		S.IDLE:
			t = "%s\nLinksklick: auswerfen · T: Methode" % MODES[mode]
			hud.clear()
		S.WAITING:
			t = "%s - warte auf Biss...\nRechtsklick: einholen" % MODES[mode]
			hud.clear()
		S.RETRIEVE:
			t = "Linksklick halten = Köder einholen (%d%%)" % int(retrieve_t / 12.0 * 100.0)
			hud.clear()
		S.BITE:
			hud.kind = "bite"
			hud.d = {"phase": bite_phase(), "left": bite_left / (4.0 if mode == 0 else 2.0)}
		S.FIGHT:
			hud.kind = "fight"
			hud.d = {"tension": tension, "stamina": stamina, "dist01": clampf((distance - 1.5) / maxf(cast_dist + 8.5, 1.0), 0.0, 1.0),
				"dist": distance, "pull": pull if running else 0, "jump": jump_t, "reeling": _reeling(),
				"counter": _counter_axis()}
	status.text = Game.touchify(t)
