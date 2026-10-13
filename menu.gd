extends Control
## Startmenü / Login: Name, Figur, Passwort - dann geht es auf den Server.
## Alles wird per Code gebaut (kein Editor nötig).

const ACCENT := Color(0.98, 0.62, 0.22)
const ACCENT_DARK := Color(0.82, 0.44, 0.1)
const PANEL_BG := Color(0.04, 0.055, 0.07, 0.84)
const FIELD_BG := Color(0.0, 0.0, 0.0, 0.38)
const TEXT_DIM := Color(0.72, 0.76, 0.8)
const ERR := Color(1.0, 0.42, 0.38)
const OKC := Color(0.55, 0.9, 0.6)

const ROLES := {"Marian": "Feuer", "Steffen": "Koch", "Julian": "Vape"}
const ORDER := ["Marian", "Steffen", "Julian"]

var name_edit: LineEdit
var pw_edit: LineEdit
var show_btn: Button
var join_btn: Button
var solo_btn: Button
var status: Label
var server_dot: Label
var cards: Array = []
var selected: int = 0
var _busy: bool = false
var _server_ready: bool = not OS.has_feature("web")
var _adv_edit: LineEdit = null
var _check: HTTPRequest = null


# ---------------------------------------------------------------------------
# Hintergrund: Abendstimmung mit Bergen, Wald und Lagerfeuer
# ---------------------------------------------------------------------------
class Backdrop:
	extends Control
	var t: float = 0.0
	var stars: Array = []
	var layers: Array = []
	var trees: Array = []
	var embers: Array = []

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var rng := RandomNumberGenerator.new()
		rng.seed = 77
		for i in 90:
			stars.append([rng.randf(), rng.randf() * 0.5, rng.randf() * TAU, rng.randf_range(0.8, 2.0)])
		var specs := [[0.46, 0.2, Color(0.30, 0.22, 0.40)], [0.55, 0.16, Color(0.17, 0.15, 0.28)], [0.66, 0.12, Color(0.08, 0.10, 0.16)]]
		for sp in specs:
			var pts: Array = []
			var n := 16
			for i in n + 1:
				pts.append(Vector2(float(i) / n, sp[0] - rng.randf() * sp[1] * (1.0 if i % 2 == 0 else 0.45)))
			layers.append({"pts": pts, "col": sp[2]})
		var x := -0.02
		while x < 1.04:
			trees.append([x, rng.randf_range(0.07, 0.16), rng.randf_range(0.8, 1.2)])
			x += rng.randf_range(0.018, 0.04)
		for i in 26:
			embers.append([rng.randf(), rng.randf(), rng.randf_range(0.04, 0.12), rng.randf_range(-0.03, 0.03)])

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		# Himmel
		var top := Color(0.05, 0.07, 0.17)
		var mid := Color(0.42, 0.22, 0.38)
		var low := Color(0.98, 0.58, 0.30)
		var strips := 48
		var hy := h * 0.72
		for i in strips:
			var f := float(i) / (strips - 1)
			var c := top.lerp(mid, clampf(f * 1.7, 0.0, 1.0)) if f < 0.59 else mid.lerp(low, (f - 0.59) / 0.41)
			draw_rect(Rect2(0, hy * float(i) / strips, w, hy / strips + 1.0), c)
		for s in stars:
			var a: float = 0.35 + 0.35 * sin(t * s[3] + float(s[2]))
			draw_circle(Vector2(s[0] * w, s[1] * h), 1.3, Color(1, 1, 1, a * (1.0 - float(s[1]) * 1.4)))
		# Sonne mit Schein
		var sun := Vector2(w * 0.3, h * 0.6)
		for i in 8:
			draw_circle(sun, h * (0.07 + 0.035 * i), Color(1.0, 0.7, 0.35, 0.05))
		draw_circle(sun, h * 0.065, Color(1.0, 0.86, 0.6))
		# Berge
		for l in layers:
			var poly := PackedVector2Array()
			for p in l["pts"]:
				poly.append(Vector2(p.x * w, p.y * h))
			poly.append(Vector2(w, h))
			poly.append(Vector2(0, h))
			draw_colored_polygon(poly, l["col"])
		# Wald
		var tc := Color(0.025, 0.04, 0.05)
		for tr in trees:
			var bx: float = tr[0] * w
			var th: float = tr[1] * h * tr[2]
			var by := h * 1.01
			for k in 3:
				var ww := th * (0.36 - 0.07 * k)
				var y0 := by - th * (0.18 + 0.27 * k)
				draw_colored_polygon(PackedVector2Array([Vector2(bx - ww, y0), Vector2(bx + ww, y0), Vector2(bx, y0 - th * 0.42)]), tc)
		draw_rect(Rect2(0, h * 0.965, w, h * 0.04), tc)
		# Lagerfeuer
		var fp := Vector2(w * 0.17, h * 0.93)
		var fl := 1.0 + 0.12 * sin(t * 11.0) + 0.08 * sin(t * 17.3)
		for i in 6:
			draw_circle(fp, h * (0.03 + 0.03 * i) * fl, Color(1.0, 0.5, 0.15, 0.06))
		draw_colored_polygon(PackedVector2Array([fp + Vector2(-9, 0), fp + Vector2(9, 0), fp + Vector2(0, -26 * fl)]), Color(1.0, 0.55, 0.12))
		draw_colored_polygon(PackedVector2Array([fp + Vector2(-5, 0), fp + Vector2(5, 0), fp + Vector2(0, -15 * fl)]), Color(1.0, 0.88, 0.4))
		for e in embers:
			var ph: float = fmod(t * float(e[2]) + float(e[1]), 1.0)
			var ep := fp + Vector2(sin(ph * 6.0 + float(e[0]) * 9.0) * 22.0 + float(e[3]) * ph * 300.0, -ph * h * 0.38 - 20.0)
			draw_circle(ep, 1.8 * (1.0 - ph) + 0.4, Color(1.0, 0.7, 0.3, 0.9 * (1.0 - ph)))


# ---------------------------------------------------------------------------
# Figurenkarte mit gezeichnetem Porträt
# ---------------------------------------------------------------------------
class CharCard:
	extends Control
	signal picked(idx: int)
	var idx: int = 0
	var char_name: String = ""
	var role: String = ""
	var selected: bool = false
	var hover: bool = false
	var t: float = 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(176, 216)
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		mouse_entered.connect(func() -> void: hover = true)
		mouse_exited.connect(func() -> void: hover = false)

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			picked.emit(idx)

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		var accent := Color(0.98, 0.62, 0.22)
		var r := Rect2(Vector2.ZERO, size)
		var lift := -4.0 if (selected or hover) else 0.0
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(14)
		sb.bg_color = Color(0.1, 0.12, 0.15, 0.95) if selected else Color(0.06, 0.08, 0.1, 0.8)
		sb.border_color = accent if selected else (Color(1, 1, 1, 0.3) if hover else Color(1, 1, 1, 0.09))
		sb.set_border_width_all(3 if selected else 1)
		if selected:
			sb.shadow_color = Color(accent.r, accent.g, accent.b, 0.35)
			sb.shadow_size = 14
		draw_style_box(sb, Rect2(0, lift, r.size.x, r.size.y))
		# Porträtfläche
		var pr := Rect2(8, 8 + lift, r.size.x - 16, r.size.y - 74)
		var d: Dictionary = Player.CHARS[char_name]
		draw_portrait(pr, d, selected, t)
		# Name
		var font := ThemeDB.fallback_font
		var nc := Color(1, 1, 1) if selected else Color(0.85, 0.88, 0.9)
		draw_string(font, Vector2(0, r.size.y - 38 + lift), char_name.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 22, nc)
		draw_string(font, Vector2(0, r.size.y - 16 + lift), role, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 15, accent if selected else Color(0.6, 0.65, 0.7))

	func draw_portrait(pr: Rect2, d: Dictionary, active: bool, time: float) -> void:
		# Hintergrund des Porträts (Abendhimmel + Hügel), pro Figur leicht getönt
		var tint: Color = d["shirt"]
		var bgc := Color(0.2, 0.2, 0.32).lerp(tint, 0.25)
		for i in 10:
			var f := float(i) / 9.0
			draw_rect(Rect2(pr.position.x, pr.position.y + pr.size.y * f * 0.9, pr.size.x, pr.size.y * 0.1 + 1.0),
				bgc.lerp(Color(0.95, 0.55, 0.3), f * f * 0.8))
		draw_circle(Vector2(pr.get_center().x, pr.position.y + pr.size.y * 0.5), pr.size.x * 0.42, Color(1, 0.8, 0.5, 0.12 if active else 0.06))
		# Figur
		var u := minf(pr.size.x / 176.0, pr.size.y / 152.0)
		var cx := pr.get_center().x
		var bob := sin(time * 2.0 + float(char_name.length())) * 2.0 * u if active else 0.0
		var base := pr.end.y
		var ysh := base - 62.0 * u + bob      # Schulterlinie
		var yh := ysh - 50.0 * u              # Kopfmitte
		var skin: Color = Player.SKIN
		var shirt: Color = d["shirt"]
		var packc: Color = d["pack"]
		if packc.get_luminance() < 0.12:
			packc = Color(0.2, 0.2, 0.24)
		# Rucksack hinter den Schultern
		draw_rect(Rect2(cx - 62 * u, ysh - 4 * u, 124 * u, 60 * u), packc)
		draw_rect(Rect2(cx - 62 * u, ysh - 4 * u, 124 * u, 60 * u), Color(0, 0, 0, 0.25), false, 1.5)
		# Oberkörper
		var torso := PackedVector2Array([
			Vector2(cx - 74 * u, base + 2), Vector2(cx - 66 * u, ysh + 14 * u), Vector2(cx - 40 * u, ysh + 1 * u),
			Vector2(cx + 40 * u, ysh + 1 * u), Vector2(cx + 66 * u, ysh + 14 * u), Vector2(cx + 74 * u, base + 2)])
		draw_colored_polygon(torso, shirt)
		draw_colored_polygon(PackedVector2Array([Vector2(cx - 74 * u, base + 2), Vector2(cx - 66 * u, ysh + 14 * u), Vector2(cx - 56 * u, ysh + 10 * u), Vector2(cx - 58 * u, base + 2)]), shirt.lightened(0.12))
		# Rucksackgurte
		draw_line(Vector2(cx - 30 * u, ysh + 2 * u), Vector2(cx - 36 * u, base), packc.lightened(0.15), 4.0 * u)
		draw_line(Vector2(cx + 30 * u, ysh + 2 * u), Vector2(cx + 36 * u, base), packc.lightened(0.15), 4.0 * u)
		# Hals
		draw_rect(Rect2(cx - 11 * u, yh + 22 * u, 22 * u, ysh - yh - 18 * u), skin.darkened(0.12))
		draw_colored_polygon(PackedVector2Array([Vector2(cx - 15 * u, ysh + 1 * u), Vector2(cx + 15 * u, ysh + 1 * u), Vector2(cx, ysh + 17 * u)]), skin.darkened(0.18))
		# Ohren + Kopf
		draw_circle(Vector2(cx - 36 * u, yh + 2 * u), 7 * u, skin.darkened(0.08))
		draw_circle(Vector2(cx + 36 * u, yh + 2 * u), 7 * u, skin.darkened(0.08))
		draw_circle(Vector2(cx, yh), 38 * u, skin)
		var hair: Color = d["hair"]
		# Haare / Kappe
		if d["cap"]:
			var cap := Color(0.06, 0.06, 0.08)
			var dome := PackedVector2Array()
			for i in 21:
				var a := PI + PI * float(i) / 20.0
				dome.append(Vector2(cx + cos(a) * 41 * u, yh - 15 * u + sin(a) * 38 * u))
			draw_colored_polygon(dome, cap)
			draw_colored_polygon(PackedVector2Array([Vector2(cx - 41 * u, yh - 16 * u), Vector2(cx + 41 * u, yh - 16 * u), Vector2(cx + 39 * u, yh - 10 * u), Vector2(cx - 39 * u, yh - 10 * u)]), cap.lightened(0.1))
			draw_colored_polygon(PackedVector2Array([Vector2(cx - 36 * u, yh - 10 * u), Vector2(cx + 36 * u, yh - 10 * u), Vector2(cx + 46 * u, yh - 5 * u), Vector2(cx - 46 * u, yh - 5 * u)]), cap.lightened(0.18))
			draw_circle(Vector2(cx - 37 * u, yh + 8 * u), 5 * u, hair)
			draw_circle(Vector2(cx + 37 * u, yh + 8 * u), 5 * u, hair)
		else:
			var hp := PackedVector2Array()
			for i in 23:
				var a := PI * 1.02 + PI * 0.96 * float(i) / 22.0
				hp.append(Vector2(cx + cos(a) * 40 * u, yh - 2 * u + sin(a) * 41 * u))
			hp.append(Vector2(cx + 34 * u, yh + 8 * u))
			hp.append(Vector2(cx + 20 * u, yh - 14 * u))
			hp.append(Vector2(cx - 22 * u, yh - 12 * u))
			hp.append(Vector2(cx - 34 * u, yh + 8 * u))
			draw_colored_polygon(hp, hair)
		# Bart
		if d["beard"]:
			var bp := PackedVector2Array()
			for i in 15:
				var a := deg_to_rad(18.0 + 144.0 * float(i) / 14.0)
				bp.append(Vector2(cx + cos(a) * 40 * u, yh + 2 * u + sin(a) * 40 * u))
			for i in 15:
				var a2 := deg_to_rad(162.0 - 144.0 * float(i) / 14.0)
				bp.append(Vector2(cx + cos(a2) * 24 * u, yh + 15 * u + sin(a2) * 11 * u))
			draw_colored_polygon(bp, hair.darkened(0.2))
			draw_rect(Rect2(cx - 11 * u, yh + 12 * u, 22 * u, 4 * u), hair.darkened(0.2))
		# Gesicht
		var ey := yh - 2 * u
		draw_circle(Vector2(cx - 14 * u, ey), 3.2 * u, Color(0.1, 0.08, 0.08))
		draw_circle(Vector2(cx + 14 * u, ey), 3.2 * u, Color(0.1, 0.08, 0.08))
		draw_arc(Vector2(cx, yh + 20 * u), 8 * u, deg_to_rad(20), deg_to_rad(160), 8, Color(0.45, 0.2, 0.2), 2.0 * u)
		if d["glasses"]:
			var gc := Color(0.08, 0.08, 0.1)
			draw_arc(Vector2(cx - 14 * u, ey), 10.5 * u, 0, TAU, 20, gc, 2.4 * u)
			draw_arc(Vector2(cx + 14 * u, ey), 10.5 * u, 0, TAU, 20, gc, 2.4 * u)
			draw_line(Vector2(cx - 3.5 * u, ey - 1 * u), Vector2(cx + 3.5 * u, ey - 1 * u), gc, 2.2 * u)
		if not d["cap"]:
			draw_arc(Vector2(cx - 14 * u, ey - 9 * u), 9 * u, deg_to_rad(200), deg_to_rad(330), 6, Color(0, 0, 0, 0.35), 2.0 * u)
			draw_arc(Vector2(cx + 14 * u, ey - 9 * u), 9 * u, deg_to_rad(210), deg_to_rad(340), 6, Color(0, 0, 0, 0.35), 2.0 * u)


# ---------------------------------------------------------------------------
# Aufbau
# ---------------------------------------------------------------------------
func _ready() -> void:
	if "--server" in OS.get_cmdline_user_args():
		_start_dedicated()
		return
	if OS.has_feature("web"):
		Game.touch = bool(JavaScriptBridge.eval("window.matchMedia('(pointer: coarse)').matches || window.location.search.includes('touch')"))
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	theme = _make_theme()

	var bd := Backdrop.new()
	bd.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bd)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + s, 64)
	for s in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + s, 24)
	add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 40)
	margin.add_child(row)

	# Linke Seite: Titel
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(left)
	var t1 := Label.new()
	t1.text = "THREE"
	t1.add_theme_font_size_override("font_size", 104)
	t1.add_theme_color_override("font_color", Color(1, 0.96, 0.9))
	_outline(t1)
	left.add_child(t1)
	var t2 := Label.new()
	t2.text = "IN THE WILD"
	t2.add_theme_font_size_override("font_size", 56)
	t2.add_theme_color_override("font_color", ACCENT)
	_outline(t2)
	left.add_child(t2)
	var bar := ColorRect.new()
	bar.color = ACCENT
	bar.custom_minimum_size = Vector2(120, 5)
	bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	left.add_child(bar)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 200)
	left.add_child(spacer)

	# Rechte Seite: Login-Karte
	var right := VBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(right)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(620, 0)
	var ps := StyleBoxFlat.new()
	ps.bg_color = PANEL_BG
	ps.set_corner_radius_all(20)
	ps.border_color = Color(1, 1, 1, 0.12)
	ps.set_border_width_all(1)
	ps.shadow_color = Color(0, 0, 0, 0.5)
	ps.shadow_size = 24
	ps.content_margin_left = 30
	ps.content_margin_right = 30
	ps.content_margin_top = 26
	ps.content_margin_bottom = 22
	panel.add_theme_stylebox_override("panel", ps)
	right.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 9)
	panel.add_child(box)

	var head := HBoxContainer.new()
	box.add_child(head)
	var login_l := Label.new()
	login_l.text = "ANMELDEN"
	login_l.add_theme_font_size_override("font_size", 26)
	login_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(login_l)
	server_dot = Label.new()
	server_dot.add_theme_font_size_override("font_size", 15)
	head.add_child(server_dot)

	box.add_child(_caption("NAME"))
	name_edit = LineEdit.new()
	name_edit.placeholder_text = "Dein Spielername"
	name_edit.max_length = 16
	name_edit.text = Game.player_name if Game.player_name != "Spieler" else ""
	name_edit.custom_minimum_size = Vector2(0, 46)
	name_edit.text_submitted.connect(func(_t: String) -> void: pw_edit.grab_focus())
	box.add_child(name_edit)

	box.add_child(_caption("FIGUR"))
	var cr := HBoxContainer.new()
	cr.add_theme_constant_override("separation", 12)
	box.add_child(cr)
	selected = maxi(ORDER.find(Game.start_char), 0)
	for i in ORDER.size():
		var c := CharCard.new()
		c.idx = i
		c.char_name = ORDER[i]
		c.role = ROLES[ORDER[i]]
		c.selected = i == selected
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.picked.connect(_pick)
		cr.add_child(c)
		cards.append(c)

	box.add_child(_caption("PASSWORT"))
	var pr := HBoxContainer.new()
	pr.add_theme_constant_override("separation", 8)
	box.add_child(pr)
	pw_edit = LineEdit.new()
	pw_edit.secret = true
	pw_edit.placeholder_text = "Passwort eingeben"
	pw_edit.custom_minimum_size = Vector2(0, 46)
	pw_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pw_edit.text_submitted.connect(func(_t: String) -> void: _on_join())
	pw_edit.text_changed.connect(func(_t: String) -> void: _set_status("", false))
	pr.add_child(pw_edit)
	show_btn = Button.new()
	show_btn.text = "Zeigen"
	show_btn.toggle_mode = true
	show_btn.custom_minimum_size = Vector2(96, 46)
	show_btn.toggled.connect(func(on: bool) -> void:
		pw_edit.secret = not on
		show_btn.text = "Verbergen" if on else "Zeigen")
	pr.add_child(show_btn)

	join_btn = Button.new()
	join_btn.text = "SPIEL BETRETEN"
	join_btn.custom_minimum_size = Vector2(0, 58)
	join_btn.add_theme_font_size_override("font_size", 22)
	join_btn.add_theme_stylebox_override("normal", _btn_style(ACCENT, ACCENT.lightened(0.25)))
	join_btn.add_theme_stylebox_override("hover", _btn_style(ACCENT.lightened(0.12), Color(1, 1, 1, 0.6)))
	join_btn.add_theme_stylebox_override("pressed", _btn_style(ACCENT_DARK, ACCENT))
	join_btn.add_theme_stylebox_override("disabled", _btn_style(Color(0.35, 0.3, 0.25), Color(1, 1, 1, 0.1)))
	join_btn.add_theme_stylebox_override("focus", _btn_style(ACCENT, Color(1, 1, 1, 0.9)))
	join_btn.add_theme_color_override("font_color", Color(0.1, 0.06, 0.02))
	join_btn.add_theme_color_override("font_hover_color", Color(0.1, 0.06, 0.02))
	join_btn.add_theme_color_override("font_pressed_color", Color(0.1, 0.06, 0.02))
	join_btn.add_theme_color_override("font_disabled_color", Color(0.75, 0.7, 0.65))
	join_btn.pressed.connect(_on_join)
	box.add_child(join_btn)

	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.custom_minimum_size = Vector2(0, 22)
	status.add_theme_font_size_override("font_size", 16)
	box.add_child(status)

	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(bottom)
	solo_btn = Button.new()
	solo_btn.text = "Allein spielen (ohne Server)"
	solo_btn.flat = true
	solo_btn.add_theme_color_override("font_color", TEXT_DIM)
	solo_btn.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	solo_btn.pressed.connect(_on_solo)
	bottom.add_child(solo_btn)

	# Nur in der PC-Version: Server-Adresse / Hosten (im Browser kommt die Adresse vom Server)
	if not OS.has_feature("web"):
		var adv := HBoxContainer.new()
		adv.add_theme_constant_override("separation", 8)
		adv.visible = false
		box.add_child(adv)
		var adv_btn := Button.new()
		adv_btn.text = "Erweitert"
		adv_btn.flat = true
		adv_btn.add_theme_color_override("font_color", TEXT_DIM)
		adv_btn.pressed.connect(func() -> void: adv.visible = not adv.visible)
		bottom.add_child(adv_btn)
		_adv_edit = LineEdit.new()
		_adv_edit.placeholder_text = "Server-Adresse"
		_adv_edit.text = Game.host_ip
		_adv_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		adv.add_child(_adv_edit)
		var hb := Button.new()
		hb.text = "Hosten"
		hb.pressed.connect(_on_host)
		adv.add_child(hb)

	if Game.login_error != "":
		_set_status(Game.login_error, true)
		Game.login_error = ""
	if OS.has_feature("web"):
		_probe_server()
	else:
		_update_dot()
	name_edit.grab_focus()


func _make_theme() -> Theme:
	var th := Theme.new()
	th.set_font_size("font_size", "Label", 17)
	th.set_font_size("font_size", "LineEdit", 18)
	th.set_font_size("font_size", "Button", 17)
	th.set_color("font_color", "Label", Color(0.93, 0.95, 0.97))
	th.set_color("font_color", "LineEdit", Color(1, 1, 1))
	th.set_color("font_placeholder_color", "LineEdit", Color(1, 1, 1, 0.35))
	th.set_color("caret_color", "LineEdit", ACCENT)
	th.set_color("selection_color", "LineEdit", Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.4))
	th.set_stylebox("normal", "LineEdit", _field_style(Color(1, 1, 1, 0.14)))
	th.set_stylebox("focus", "LineEdit", _field_style(ACCENT))
	th.set_stylebox("read_only", "LineEdit", _field_style(Color(1, 1, 1, 0.08)))
	th.set_stylebox("normal", "Button", _btn_style(Color(1, 1, 1, 0.1), Color(1, 1, 1, 0.16)))
	th.set_stylebox("hover", "Button", _btn_style(Color(1, 1, 1, 0.18), Color(1, 1, 1, 0.3)))
	th.set_stylebox("pressed", "Button", _btn_style(Color(1, 1, 1, 0.26), ACCENT))
	th.set_stylebox("focus", "Button", _btn_style(Color(1, 1, 1, 0.1), ACCENT))
	th.set_stylebox("disabled", "Button", _btn_style(Color(1, 1, 1, 0.05), Color(1, 1, 1, 0.08)))
	var flat := StyleBoxEmpty.new()
	th.set_stylebox("normal", "FlatButton", flat)
	return th


func _field_style(border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = FIELD_BG
	s.set_corner_radius_all(10)
	s.border_color = border
	s.set_border_width_all(2)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s


func _btn_style(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(12)
	s.border_color = border
	s.set_border_width_all(2)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s


func _caption(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", TEXT_DIM)
	return l


func _outline(l: Label) -> void:
	l.add_theme_constant_override("outline_size", 10)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.06, 0.85))
	l.add_theme_constant_override("shadow_offset_y", 4)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))


# ---------------------------------------------------------------------------
# Logik
# ---------------------------------------------------------------------------
func _pick(i: int) -> void:
	selected = i
	for c in cards:
		c.selected = c.idx == i


func _set_status(text: String, error: bool) -> void:
	status.text = text
	status.add_theme_color_override("font_color", ERR if error else TEXT_DIM)


func _update_dot() -> void:
	if not OS.has_feature("web"):
		server_dot.text = ""
		return
	if _server_ready:
		server_dot.text = "● Server online"
		server_dot.add_theme_color_override("font_color", OKC)
	else:
		server_dot.text = "● Verbinde …"
		server_dot.add_theme_color_override("font_color", TEXT_DIM)


## Im Browser: beim Server nachfragen, unter welcher Adresse das Spiel läuft.
func _probe_server() -> void:
	_update_dot()
	var req := HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(func(_r: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
		var t: String = body.get_string_from_utf8().strip_edges()
		if code == 200:
			_server_ready = true
			if t.begins_with("ws"):
				Game.ws_url = t
			else:
				var hn: Variant = JavaScriptBridge.eval("window.location.hostname")
				Game.host_ip = str(hn)
			_update_dot()
		else:
			server_dot.text = "● Server nicht erreichbar"
			server_dot.add_theme_color_override("font_color", ERR))
	var origin: Variant = JavaScriptBridge.eval("window.location.origin")
	req.request(str(origin) + "/wsurl")


func _validate() -> bool:
	if name_edit.text.strip_edges() == "":
		_set_status("Bitte gib einen Namen ein.", true)
		name_edit.grab_focus()
		_shake(name_edit)
		return false
	if pw_edit.text == "":
		_set_status("Bitte gib das Passwort ein.", true)
		pw_edit.grab_focus()
		_shake(pw_edit)
		return false
	return true


func _shake(c: Control) -> void:
	var tw := create_tween()
	for i in 4:
		tw.tween_property(c, "position:x", c.position.x + (8 if i % 2 == 0 else -8), 0.04)
	tw.tween_property(c, "position:x", c.position.x, 0.04)


func _on_join() -> void:
	if _busy or not _validate():
		return
	if not OS.has_feature("web"):
		_start("join")
		return
	if not _server_ready:
		_set_status("Der Server ist nicht erreichbar. Bitte kurz warten und neu laden.", true)
		return
	# Passwort beim Server prüfen, bevor die Welt geladen wird.
	_busy = true
	join_btn.disabled = true
	_set_status("Passwort wird geprüft …", false)
	if _check == null:
		_check = HTTPRequest.new()
		add_child(_check)
		_check.request_completed.connect(_on_checked)
	var origin: Variant = JavaScriptBridge.eval("window.location.origin")
	var err := _check.request(str(origin) + "/check", PackedStringArray(["X-Game-Pw: " + pw_edit.text.uri_encode()]))
	if err != OK:
		_check_failed("Der Server ist nicht erreichbar.")


func _on_checked(_r: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
	var t: String = body.get_string_from_utf8().strip_edges()
	if code != 200:
		_check_failed("Der Server ist nicht erreichbar.")
	elif t == "ok":
		_set_status("Willkommen!", false)
		_start("join")
	elif t == "nopw":
		_check_failed("Der Server ist noch nicht eingerichtet (kein Passwort gesetzt).")
	else:
		_check_failed("Falsches Passwort.")
		pw_edit.grab_focus()
		pw_edit.select_all()
		_shake(pw_edit)


func _check_failed(msg: String) -> void:
	_busy = false
	join_btn.disabled = false
	_set_status(msg, true)


func _on_solo() -> void:
	if name_edit.text.strip_edges() == "":
		_set_status("Bitte gib einen Namen ein.", true)
		name_edit.grab_focus()
		_shake(name_edit)
		return
	_start("solo")


func _on_host() -> void:
	if not _validate():
		return
	_start("host")


func _start(mode: String) -> void:
	Game.reset()
	Game.net_mode = mode
	Game.player_name = name_edit.text.strip_edges() if name_edit.text.strip_edges() != "" else "Spieler"
	Game.start_char = ORDER[selected]
	if _adv_edit != null and _adv_edit.text.strip_edges() != "":
		Game.host_ip = _adv_edit.text.strip_edges()
	Game.password = pw_edit.text
	get_tree().change_scene_to_file("res://main.tscn")


## Start ohne Fenster: godot --headless -- --server  (Einstellungen per Umgebungsvariablen)
func _start_dedicated() -> void:
	Game.reset()
	Game.dedicated = true
	Game.net_mode = "host"
	Game.password = OS.get_environment("GAME_PASSWORD")
	Game.port = int(OS.get_environment("GAME_PORT")) if OS.get_environment("GAME_PORT") != "" else 24680
	if OS.get_environment("HTTP_PORT") != "":
		WebHost.http_port = int(OS.get_environment("HTTP_PORT"))
	WebHost.ws_url = OS.get_environment("WS_URL")
	print("Server startet: Spiel-Port %d, Web-Port %d, Passwort %s, WS_URL '%s'" % [Game.port, WebHost.http_port, "gesetzt" if Game.password != "" else "FEHLT", WebHost.ws_url])
	if Game.password == "":
		push_warning("GAME_PASSWORD ist nicht gesetzt - niemand kann beitreten, bis ein Passwort eingetragen ist!")
	get_tree().change_scene_to_file.call_deferred("res://main.tscn")
