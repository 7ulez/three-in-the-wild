class_name Fisher
extends Node
## Angeln: Rute tragen, T = Methode wechseln (Grund / Pose / Spinn), Linksklick = auswerfen,
## beim Biss Linksklick = anschlagen, dann Linksklick halten = einholen (Schnurspannung beachten!).

enum S { IDLE, WAITING, BITE, FIGHT, RETRIEVE }
const MODES: Array = ["Grundangeln (Karpfen, Nacht!)", "Posenangeln (Friedfisch)", "Spinnangeln (Hecht)"]

const FISH: Dictionary = {
	"Karpfen": {"kg": [2.0, 14.0], "strength": 1.0, "color": Color(0.6, 0.5, 0.22)},
	"Hecht": {"kg": [1.5, 9.0], "strength": 1.2, "color": Color(0.3, 0.46, 0.25)},
	"Rotauge": {"kg": [0.1, 0.5], "strength": 0.3, "color": Color(0.75, 0.75, 0.8)},
	"Barsch": {"kg": [0.2, 1.2], "strength": 0.5, "color": Color(0.5, 0.55, 0.25)},
	"Brasse": {"kg": [0.5, 2.5], "strength": 0.6, "color": Color(0.7, 0.62, 0.45)},
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
var line: MeshInstance3D
var alarm: AudioStreamPlayer
var panel: VBoxContainer
var status: Label
var tension_bar: ProgressBar
var led: OmniLight3D


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
	layer.add_child(panel)
	status = Label.new()
	status.add_theme_font_size_override("font_size", 22)
	status.add_theme_constant_override("outline_size", 6)
	status.add_theme_color_override("font_outline_color", Color.BLACK)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(status)
	tension_bar = ProgressBar.new()
	tension_bar.max_value = 1.0
	tension_bar.show_percentage = false
	tension_bar.custom_minimum_size = Vector2(340, 18)
	tension_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(tension_bar)
	panel.visible = false


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
	if not Game.is_captured():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).keycode == KEY_T and has_rod():
			cycle_mode()
	elif event is InputEventMouseButton and event.pressed and has_rod():
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_left_click()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and state != S.IDLE and state != S.FIGHT:
			reel_in("Schnur eingeholt.")


func _left_click() -> void:
	match state:
		S.IDLE:
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
	get_tree().create_timer(0.5).timeout.connect(func() -> void: Sfx.play("splash_small", p))
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
	return w * wait_scale


func reel_in(msg: String) -> void:
	state = S.IDLE
	bobber.visible = false
	tension = 0.0
	led.light_energy = 0.0
	panel.visible = false
	var m := line.mesh as ImmediateMesh
	m.clear_surfaces()
	if msg != "":
		player.toast(msg, 2.0)


func _pick_species() -> String:
	var r := randf()
	var night := Game.is_night()
	match mode:
		0:
			if night:
				return "Karpfen" if r < 0.85 else "Brasse"
			return "Karpfen" if r < 0.35 else ("Brasse" if r < 0.75 else "Rotauge")
		1:
			if r < 0.45:
				return "Rotauge"
			if r < 0.75:
				return "Barsch"
			if r < 0.9:
				return "Brasse"
			return "Karpfen"
		_:
			var pike_p := 0.3 if night else 0.55
			return "Hecht" if r < pike_p else "Barsch"
	return "Rotauge"


func _start_bite() -> void:
	fish_name = _pick_species()
	var d: Dictionary = FISH[fish_name]
	var kg_range: Array = d["kg"]
	fish_kg = snappedf(randf_range(kg_range[0], kg_range[1]) * randf_range(0.6, 1.0), 0.1)
	state = S.BITE
	bite_left = 4.0 if mode == 0 else 2.0
	if mode == 0:
		player.toast("BISSANZEIGER! Linksklick zum Anschlagen!", 3.0)
		_alarm_cd = 0.0
	elif mode == 1:
		player.toast("Die Pose taucht ab! Linksklick = anschlagen!", 3.0)
	else:
		player.toast("Ein Fisch hat auf den Köder gebissen! Linksklick = anschlagen!", 3.0)


func hook() -> void:
	state = S.FIGHT
	distance = maxf(cast_dist, 6.0)
	tension = 0.35
	running = false
	run_timer = randf_range(0.8, 1.6)
	led.light_energy = 0.0
	player.toast("Angeschlagen! Linksklick halten = einholen, bei Fluchten loslassen!", 3.5)


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
					player.toast("RUMMS! Hecht oder Barsch hängt am Kunstköder! Einholen!", 3.0)
				elif retrieve_t >= 12.0:
					reel_in("Nichts gebissen. Nochmal auswerfen.")
		S.BITE:
			bite_left -= delta
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


func _fight(delta: float) -> void:
	var s := _strength()
	var reeling := _reeling()
	run_timer -= delta
	if run_timer <= 0.0:
		running = not running
		run_timer = randf_range(0.8, 1.6) if running else randf_range(1.0, 2.4)
	if running:
		tension += (0.9 if reeling else 0.1) * s * delta
		distance += (0.2 if reeling else 0.9 + s) * s * delta
	else:
		if reeling:
			distance -= 2.3 * delta
			tension += 0.14 * delta
		else:
			tension -= 0.45 * delta
	tension = clampf(tension, 0.0, 1.05)
	if tension >= 1.0:
		player.toast("Schnur gerissen! Der %s ist weg." % fish_name, 3.5)
		reel_in("")
	elif distance > cast_dist + 10.0:
		player.toast("Der %s hat sich losgerissen." % fish_name, 3.5)
		reel_in("")
	elif distance <= 1.5:
		_catch()


func _catch() -> void:
	Sfx.play("splash", player.global_position + (-player.global_transform.basis.z) * 2.0)
	var cm := int(clampf(24.0 * pow(fish_kg, 0.36) * 2.0, 12.0, 130.0))
	Game.catches.append({"name": fish_name, "kg": fish_kg, "cm": cm})
	var d: Dictionary = FISH[fish_name]
	var len_m := cm / 100.0
	var item := Item.new().setup("%s %.1f kg" % [fish_name, fish_kg], fish_kg, Vector3(len_m, len_m * 0.28, len_m * 0.2), d["color"])
	player.get_parent().add_child(item)
	item.global_position = player.global_position + (-player.global_transform.basis.z) * 1.0 + Vector3(0, 1.0, 0)
	reel_in("")
	var extra := ""
	if fish_name == "Karpfen" and fish_kg >= 10.0:
		extra = "  Ein Prachtkarpfen!"
	if fish_name == "Hecht" and fish_kg >= 6.0:
		extra = "  Ein Monsterhecht!"
	player.toast("GEFANGEN! %s, %.1f kg, %d cm.%s" % [fish_name, fish_kg, cm, extra], 6.0)


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
	panel.visible = state != S.IDLE or has_rod()
	tension_bar.visible = state == S.FIGHT
	var t := ""
	match state:
		S.IDLE:
			t = "%s\nLinksklick: auswerfen · T: Methode" % MODES[mode]
		S.WAITING:
			t = "%s - warte auf Biss...\nRechtsklick: einholen" % MODES[mode]
		S.RETRIEVE:
			t = "Linksklick halten = Köder einholen (%d%%)" % int(retrieve_t / 12.0 * 100.0)
		S.BITE:
			t = "BISS!!! LINKSKLICK!"
		S.FIGHT:
			t = "%s! Distanz %.0f m%s" % [fish_name, distance, "\nFISCH RENNT - LOSLASSEN!" if running else "\nEinholen (halten)"]
			tension_bar.value = tension
			tension_bar.modulate = Color(1, 0.3, 0.2) if tension > 0.75 else Color(0.5, 1, 0.5)
	status.text = t
