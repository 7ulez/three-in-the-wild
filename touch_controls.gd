class_name TouchControls
extends CanvasLayer
## Bildschirm-Steuerung für Tablets und Handys im Browser.
## Links: Joystick zum Laufen (ganz nach außen schieben = rennen).
## Rechts: Wischen zum Umschauen, Knöpfe für die Aktionen.
## Die Knöpfe "drücken" einfach die gleichen Tasten wie am PC, dadurch funktioniert
## alles im Spiel genauso wie mit Tastatur und Maus.

const LOOK_SPEED: float = 1.4
const JOY_RADIUS: float = 95.0

# id, Beschriftung, Art ("key", "hold", "lmb", "rmb", "wheel", "more", "full"), Taste
var main_buttons: Array = [
	{"id": "act", "label": "Aktion", "kind": "lmb", "r": 68.0},
	{"id": "jump", "label": "Springen", "kind": "hold", "key": KEY_SPACE, "r": 48.0},
	{"id": "use", "label": "Benutzen", "kind": "key", "key": KEY_E, "r": 60.0},
	{"id": "reel", "label": "Einholen", "kind": "rmb", "r": 40.0},
	{"id": "duck", "label": "Ducken", "kind": "hold", "key": KEY_C, "r": 40.0},
	{"id": "throw", "label": "Werfen", "kind": "key", "key": KEY_G, "r": 40.0},
	{"id": "more", "label": "Mehr", "kind": "more", "r": 34.0},
]
var more_buttons: Array = [
	{"label": "Trinken", "kind": "key", "key": KEY_F},
	{"label": "Aufstellen", "kind": "key", "key": KEY_R},
	{"label": "Abbauen", "kind": "key", "key": KEY_X},
	{"label": "Drehen", "kind": "wheel"},
	{"label": "Angelart", "kind": "key", "key": KEY_T},
	{"label": "Zutat", "kind": "key", "key": KEY_Z},
	{"label": "Lampe", "kind": "key", "key": KEY_L},
	{"label": "Karte", "kind": "key", "key": KEY_M},
	{"label": "Ansicht", "kind": "key", "key": KEY_V},
	{"label": "Pinkeln", "kind": "hold", "key": KEY_P},
	{"label": "Geschäft", "kind": "key", "key": KEY_H},
	{"label": "Vape", "kind": "key", "key": KEY_Q},
	{"label": "Vollbild", "kind": "full"},
	{"label": "Marian", "kind": "key", "key": KEY_1},
	{"label": "Steffen", "kind": "key", "key": KEY_2},
	{"label": "Julian", "kind": "key", "key": KEY_3},
]

var pad: Control
var more_open: bool = false
var joy_finger: int = -1
var joy_center: Vector2 = Vector2.ZERO
var joy_vec: Vector2 = Vector2.ZERO
var look_fingers: Dictionary = {}     # finger -> letzte Position
var held: Dictionary = {}             # finger -> Knopf (Dictionary)
var keys_down: Dictionary = {}        # keycode -> true
var font: Font
var _sig: String = ""
var _player: Player = null


func _ready() -> void:
	layer = 5
	font = ThemeDB.fallback_font
	pad = Control.new()
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.draw.connect(_draw_pad)
	add_child(pad)
	get_viewport().size_changed.connect(_layout)
	_layout()


## Passt Beschriftung und Sichtbarkeit der Knöpfe an die Lage an (Angel in der Hand, Minispiel ...).
func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("local_player") as Player
		if _player == null:
			return
	var rod := _player.held != null and _player.held.item_name == "Angelrute"
	var fst: int = _player.fisher.state if _player.fisher != null else 0
	var act := "Aktion"
	var reel_vis := false
	if rod:
		match fst:
			Fisher.S.IDLE:
				act = "Auswerfen"
			Fisher.S.WAITING:
				act = "Warten"
				reel_vis = true
			Fisher.S.BITE:
				act = "ANSCHLAG!"
				reel_vis = true
			Fisher.S.RETRIEVE:
				act = "Kurbeln"
				reel_vis = true
			Fisher.S.FIGHT:
				act = "KURBELN"
	var use := "Benutzen"
	if _player.fire_bowl != null:
		use = "Funken!"
	elif _player.stir_oven != null:
		use = "Rühren!"
	var throw_vis := _player.held != null
	var sig := "%s|%s|%s|%s" % [act, use, reel_vis, throw_vis]
	if sig == _sig:
		return
	_sig = sig
	for b in main_buttons:
		match b["id"]:
			"act":
				b["dyn"] = act
			"use":
				b["dyn"] = use
			"reel":
				b["hidden"] = not reel_vis
				b["dyn"] = "Schnur ein"
			"throw":
				b["hidden"] = not throw_vis
	pad.queue_redraw()


func _size() -> Vector2:
	return get_viewport().get_visible_rect().size


func _layout() -> void:
	var s := _size()
	var pos := {
		"act": Vector2(s.x - 115, s.y - 125),
		"jump": Vector2(s.x - 255, s.y - 80),
		"use": Vector2(s.x - 125, s.y - 280),
		"reel": Vector2(s.x - 250, s.y - 215),
		"duck": Vector2(s.x - 370, s.y - 70),
		"throw": Vector2(s.x - 270, s.y - 330),
		"more": Vector2(s.x - 60, s.y - 395),
	}
	for b in main_buttons:
		b["pos"] = pos[b["id"]]
		b["r2"] = b["r"]
	# "Mehr"-Feld: 5 Spalten in der Bildschirmmitte
	var cols := 5
	var bw := 128.0
	var bh := 64.0
	var gap := 12.0
	var rows := int(ceil(float(more_buttons.size()) / cols))
	var total := Vector2(cols * bw + (cols - 1) * gap, rows * bh + (rows - 1) * gap)
	var origin := Vector2((s.x - total.x) / 2.0, (s.y - total.y) / 2.0 - 30.0)
	for i in range(more_buttons.size()):
		var b: Dictionary = more_buttons[i]
		var c := i % cols
		var r := i / cols
		b["rect"] = Rect2(origin + Vector2(c * (bw + gap), r * (bh + gap)), Vector2(bw, bh))
	pad.queue_redraw()


func _joy_home() -> Vector2:
	return Vector2(300, _size().y - 260)


# --- Eingabe -----------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if event.has_meta("touch"):
		return   # unsere eigenen, künstlichen Tastendrücke durchlassen
	# Aus Fingern erzeugte "Maus"-Klicks schlucken, sonst schießt jeder Tipp eine Angel aus.
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			_touch_down(t.index, t.position)
		else:
			_touch_up(t.index)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		_touch_move(d.index, d.position)
		get_viewport().set_input_as_handled()


func _touch_down(f: int, p: Vector2) -> void:
	if more_open:
		for b in more_buttons:
			if (b["rect"] as Rect2).has_point(p):
				held[f] = b
				_press(b, true)
				if b["kind"] == "key":
					more_open = false   # einmalige Aktion: Feld wieder schließen
				pad.queue_redraw()
				return
	for b in main_buttons:
		if b.get("hidden", false):
			continue
		if p.distance_to(b["pos"]) <= float(b["r2"]) + 12.0:
			held[f] = b
			_press(b, true)
			pad.queue_redraw()
			return
	var s := _size()
	if joy_finger == -1 and p.x < s.x * 0.4 and p.y > s.y * 0.35:
		joy_finger = f
		joy_center = p
		joy_vec = Vector2.ZERO
		pad.queue_redraw()
		return
	look_fingers[f] = p


func _touch_move(f: int, p: Vector2) -> void:
	if f == joy_finger:
		var v := (p - joy_center) / JOY_RADIUS
		if v.length() > 1.0:
			v = v.normalized()
		joy_vec = v
		_apply_joy()
		pad.queue_redraw()
	elif look_fingers.has(f):
		var rel: Vector2 = (p - look_fingers[f]) * LOOK_SPEED
		look_fingers[f] = p
		var mm := InputEventMouseMotion.new()
		mm.relative = rel
		mm.screen_relative = rel
		mm.position = _size() / 2.0
		mm.set_meta("touch", true)
		Input.parse_input_event(mm)


func _touch_up(f: int) -> void:
	if f == joy_finger:
		joy_finger = -1
		joy_vec = Vector2.ZERO
		_apply_joy()
		pad.queue_redraw()
	if look_fingers.has(f):
		look_fingers.erase(f)
	if held.has(f):
		var b: Dictionary = held[f]
		held.erase(f)
		_press(b, false)
		pad.queue_redraw()


func _apply_joy() -> void:
	var v := joy_vec
	_set_key(KEY_W, v.y < -0.35)
	_set_key(KEY_S, v.y > 0.35)
	_set_key(KEY_A, v.x < -0.35)
	_set_key(KEY_D, v.x > 0.35)
	_set_key(KEY_SHIFT, v.length() > 0.92)


# --- Künstliche Tasten / Mausklicks -------------------------------------------

func _press(b: Dictionary, down: bool) -> void:
	match b["kind"]:
		"key":
			if down:
				_set_key(b["key"], true)
				_set_key(b["key"], false)
		"hold":
			_set_key(b["key"], down)
		"lmb":
			Game.touch_reel = down
			_mouse(MOUSE_BUTTON_LEFT, down)
		"rmb":
			_mouse(MOUSE_BUTTON_RIGHT, down)
		"wheel":
			if down:
				_mouse(MOUSE_BUTTON_WHEEL_UP, true)
				_mouse(MOUSE_BUTTON_WHEEL_UP, false)
		"more":
			if down:
				more_open = not more_open
		"full":
			if down:
				if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
					DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
				else:
					DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func _set_key(code: int, down: bool) -> void:
	if down == keys_down.has(code):
		return   # Zustand ändert sich nicht
	if down:
		keys_down[code] = true
	else:
		keys_down.erase(code)
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = down
	e.set_meta("touch", true)
	Input.parse_input_event(e)


func _mouse(btn: int, down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = btn
	e.pressed = down
	e.position = _size() / 2.0
	e.global_position = e.position
	if down:
		e.button_mask = 1 << (btn - 1)
	e.set_meta("touch", true)
	Input.parse_input_event(e)


func _exit_tree() -> void:
	for code in keys_down.keys():
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = false
		e.set_meta("touch", true)
		Input.parse_input_event(e)
	Game.touch_reel = false


# --- Zeichnen -----------------------------------------------------------------

func _is_held(b: Dictionary) -> bool:
	for f in held:
		if held[f] == b:
			return true
	return false


func _label(pos: Vector2, text: String, size: int, width: float) -> void:
	var ts := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, size)
	pad.draw_string(font, pos + Vector2(-width / 2.0, ts.y * 0.3), text, HORIZONTAL_ALIGNMENT_CENTER, width, size, Color(1, 1, 1, 0.95))


func _draw_pad() -> void:
	# Joystick
	var c := joy_center if joy_finger != -1 else _joy_home()
	pad.draw_circle(c, JOY_RADIUS, Color(0, 0, 0, 0.22))
	pad.draw_arc(c, JOY_RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.45), 3.0)
	pad.draw_circle(c + joy_vec * JOY_RADIUS, 42.0, Color(1, 1, 1, 0.45 if joy_finger != -1 else 0.3))
	# Hauptknöpfe
	for b in main_buttons:
		if b.get("hidden", false):
			continue
		var on: bool = _is_held(b) or (b["kind"] == "more" and more_open)
		var r: float = b["r2"]
		pad.draw_circle(b["pos"], r, Color(1, 1, 1, 0.42) if on else Color(0, 0, 0, 0.32))
		pad.draw_arc(b["pos"], r, 0, TAU, 40, Color(1, 1, 1, 0.55), 2.5)
		_label(b["pos"], b.get("dyn", b["label"]), 17 if r > 45.0 else 15, r * 2.4)
	# Mehr-Feld
	if more_open:
		for b in more_buttons:
			var rc: Rect2 = b["rect"]
			pad.draw_rect(rc, Color(1, 1, 1, 0.45) if _is_held(b) else Color(0, 0, 0, 0.5))
			pad.draw_rect(rc, Color(1, 1, 1, 0.55), false, 2.0)
			_label(rc.get_center(), b["label"], 17, rc.size.x)
