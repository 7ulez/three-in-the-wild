class_name Hud
extends Control
## Spiel-HUD im Sticker-Design: Spielerliste, Uhr mit Tagesbalken, Ziele, Meldungen, Prompt-Chip, Steuerung.

var _tl: VBoxContainer
var _players: VBoxContainer
var _pack_l1: Label
var _pack_l2: Label
var _clock_day: Label
var _clock: Label
var _phase: Label
var _bar: DayBar
var _goals_box: VBoxContainer
var _prompt_wrap: PanelContainer
var _prompt_row: HBoxContainer
var _prompt_text: String = "\u0001"
var _toast_wrap: PanelContainer
var _toast_label: Label
var _toast_tween: Tween
var _drunk: PanelContainer
var _drunk_l: Label
var _help: PanelContainer
var _help_t: float = 28.0
var _info: Control
var _touch: bool = false
var _goals_sig: String = ""
var _prev_done: Array = []
var _last_done: int = -1
var _goals_full: PanelContainer = null
var _goals_full_box: VBoxContainer = null


class DayBar:
	extends Control
	var hour: float = 12.0

	func _init() -> void:
		custom_minimum_size = Vector2(170, 10)

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, UI.FOREST)
		var x0 := r.size.x * 6.0 / 24.0
		var x1 := r.size.x * 18.0 / 24.0
		draw_rect(Rect2(x0, 0, x1 - x0, r.size.y), Color("e8c547"))
		draw_rect(r, UI.INK, false, 2.0)
		var mx := r.size.x * hour / 24.0
		draw_rect(Rect2(mx - 1.5, -2, 3, r.size.y + 4), UI.DANGER)


func _ready() -> void:
	UI.fonts()
	theme = UI.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_touch = Game.touch
	_build_top_left()
	_build_clock()
	_build_goals()
	_build_prompt()
	_build_toast()
	_build_drunk()
	_build_help()
	_build_info()


func _process(delta: float) -> void:
	_dbg_update(delta)
	if _help != null:
		_help_t -= delta
		_help.visible = (_help_t > 0.0 or Input.is_physical_key_pressed(KEY_F1)) and not _touch


# ---------------------------------------------------------------- Bausteine

func _lbl(text: String, size: int, color: Color = UI.INK, font: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if font != null:
		l.add_theme_font_override("font", font)
	return l


func _panel(bg: Color = UI.PAPER, radius: int = 14, shadow: float = 4.0, pad: Vector4 = Vector4(12, 8, 12, 8)) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", UI.sticker(bg, radius, shadow, pad))
	return p


func _dot(color: Color) -> Control:
	var d := Panel.new()
	d.custom_minimum_size = Vector2(14, 14)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.border_color = UI.INK
	s.set_border_width_all(2)
	s.set_corner_radius_all(8)
	d.add_theme_stylebox_override("panel", s)
	return d


func key_chip(key: String, valid: bool = true) -> Control:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s := UI.sticker(UI.PAPER if valid else Color("8a8f86"), 6, 2.0, Vector4(6, 1, 6, 1))
	p.add_theme_stylebox_override("panel", s)
	p.custom_minimum_size = Vector2(26, 26)
	var l := _lbl(key, 15, UI.INK, UI.f_mono)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p


# ---------------------------------------------------------------- oben links

func _build_top_left() -> void:
	_tl = VBoxContainer.new()
	_tl.position = Vector2(14, 12)
	_tl.add_theme_constant_override("separation", 8)
	_tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tl)
	var pl := _panel(UI.PAPER, 12, 3.0, Vector4(12, 8, 14, 8))
	_players = VBoxContainer.new()
	_players.add_theme_constant_override("separation", 3)
	pl.add_child(_players)
	_tl.add_child(pl)
	var pk := _panel(UI.PAPER, 12, 3.0, Vector4(12, 6, 12, 6))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	_pack_l1 = _lbl("", 13, UI.INK, UI.f_mono)
	_pack_l2 = _lbl("", 13, UI.TEXT_LOW, UI.f_mono)
	v.add_child(_pack_l1)
	v.add_child(_pack_l2)
	pk.add_child(v)
	_tl.add_child(pk)


# ---------------------------------------------------------------- Uhr

func _build_clock() -> void:
	var wrap := CenterContainer.new()
	wrap.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	wrap.offset_top = 10
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wrap)
	var p := _panel(UI.PAPER, 14, 4.0, Vector4(16, 6, 16, 8))
	wrap.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	p.add_child(v)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	_clock_day = _lbl("Tag 1", 13, UI.TEXT_LOW, UI.f_mono)
	_clock = _lbl("12:00", 30, UI.INK, UI.f_mono)
	row.add_child(_clock_day)
	row.add_child(_clock)
	v.add_child(row)
	_bar = DayBar.new()
	v.add_child(_bar)
	_phase = _lbl("", 12, UI.TEXT_LOW)
	_phase.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_phase)


# ---------------------------------------------------------------- Ziele

func _build_goals() -> void:
	var p := _panel(UI.PAPER, 16, 4.0, Vector4(14, 10, 14, 12))
	p.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	p.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	p.offset_left = -300
	p.offset_right = -14
	p.offset_top = 12
	add_child(p)
	_goals_box = VBoxContainer.new()
	_goals_box.add_theme_constant_override("separation", 4)
	p.add_child(_goals_box)


func set_goals(goals: Array) -> void:
	var sig := ""
	for g in goals:
		sig += "%s%s|" % [g[0], g[1]]
	if sig == _goals_sig:
		return
	_goals_sig = sig
	for c in _goals_box.get_children():
		c.queue_free()
	var done := 0
	var cur := -1
	for i in goals.size():
		if goals[i][1]:
			done += 1
			if _prev_done.size() == goals.size() and not _prev_done[i]:
				_last_done = i
		elif cur < 0:
			cur = i
	_prev_done = goals.map(func(g): return g[1])
	var head := HBoxContainer.new()
	var t := _lbl("Ziele", 18, UI.INK, UI.f_head)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(_lbl("%d / %d" % [done, goals.size()], 13, UI.TEXT_LOW, UI.f_mono))
	_goals_box.add_child(head)
	_goals_box.add_child(_progress_bar(done, goals.size(), 8.0))
	_build_goals_full(goals, done)
	# zuletzt erledigt (eins), aktuelles Ziel hervorgehoben, nächste zwei
	var shown_done := _last_done if _last_done >= 0 and goals[_last_done][1] else cur - 1
	if shown_done >= 0:
		_goal_row(goals[shown_done][0], true, false)
	if cur >= 0:
		_goal_row(goals[cur][0], false, true)
		var shown := 0
		for j in range(cur + 1, goals.size()):
			if shown >= 2:
				break
			_goal_row(goals[j][0], goals[j][1], false)
			shown += 1
		var rest := goals.size() - cur - 1 - shown
		if rest > 0:
			_goals_box.add_child(_lbl("+ %d weitere" % rest, 12, UI.TEXT_LOW, UI.f_mono))
	else:
		_goals_box.add_child(_lbl("Alles geschafft!", 15, UI.INK, UI.f_head))
	_goals_box.add_child(_lbl("Tab / O: alle Ziele", 11, UI.TEXT_LOW, UI.f_mono))


func _progress_bar(done: int, total: int, h: float) -> Control:
	var bg := Panel.new()
	bg.custom_minimum_size = Vector2(0, h)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.15)
	sb.set_corner_radius_all(int(h / 2.0))
	bg.add_theme_stylebox_override("panel", sb)
	var fill := Panel.new()
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fb := StyleBoxFlat.new()
	fb.bg_color = UI.FIRE
	fb.set_corner_radius_all(int(h / 2.0))
	fill.add_theme_stylebox_override("panel", fb)
	bg.add_child(fill)
	var frac := float(done) / maxf(float(total), 1.0)
	fill.anchor_right = frac
	fill.anchor_bottom = 1.0
	return bg


## Vollständige Übersicht aller Ziele (Tab / O)
func _build_goals_full(goals: Array, done: int) -> void:
	var was_visible := _goals_full != null and _goals_full.visible
	if _goals_full != null:
		_goals_full.queue_free()
	_goals_full = _panel(UI.PAPER, 18, 6.0, Vector4(22, 16, 22, 18))
	_goals_full.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_goals_full.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_goals_full.grow_vertical = Control.GROW_DIRECTION_BOTH
	_goals_full.visible = was_visible
	add_child(_goals_full)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_goals_full.add_child(box)
	var head := HBoxContainer.new()
	var t := _lbl("Alle Ziele", 24, UI.INK, UI.f_head)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(_lbl("%d / %d  (%d %%)" % [done, goals.size(), int(round(100.0 * done / maxf(goals.size(), 1.0)))], 15, UI.TEXT_LOW, UI.f_mono))
	box.add_child(head)
	var pb := _progress_bar(done, goals.size(), 12.0)
	pb.custom_minimum_size = Vector2(420, 12)
	box.add_child(pb)
	var first_open := true
	for g in goals:
		var is_done: bool = g[1]
		var cur := not is_done and first_open
		if not is_done:
			first_open = false
		var l := _lbl(("✓  " if is_done else ("▶  " if cur else "○  ")) + str(g[0]), 15,
			UI.INK if cur else (Color(UI.TEXT_LOW, 0.75) if is_done else UI.TEXT_LOW), UI.f_head if cur else UI.f_label)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(420, 0)
		box.add_child(l)
	box.add_child(_lbl("Tab / O: schließen", 12, UI.TEXT_LOW, UI.f_mono))


var _map: MapView = null


func toggle_map() -> void:
	if _map == null:
		# eigene Ebene ganz oben, damit keine HUD-Fenster darueber liegen
		var layer := CanvasLayer.new()
		layer.layer = 60
		add_child(layer)
		_map = MapView.new()
		layer.add_child(_map)
	_map.toggle()


var _dbg: Label = null
var _dbg_t: float = 0.0


## F3: Diagnose bei Bildfehlern (Position, Bodenkontakt, Zeichenobjekte, Spieleranzahl).
func toggle_debug() -> void:
	if _dbg == null:
		var layer := CanvasLayer.new()
		layer.layer = 61
		add_child(layer)
		_dbg = Label.new()
		_dbg.position = Vector2(12, 150)
		_dbg.add_theme_font_size_override("font_size", 15)
		_dbg.add_theme_color_override("font_color", Color(1, 1, 0.5))
		_dbg.add_theme_constant_override("outline_size", 6)
		_dbg.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		_dbg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_dbg.visible = false
		layer.add_child(_dbg)
	_dbg.visible = not _dbg.visible
	_dbg_t = 0.0


func _dbg_update(delta: float) -> void:
	if _dbg == null or not _dbg.visible:
		return
	_dbg_t -= delta
	if _dbg_t > 0.0:
		return
	_dbg_t = 0.4
	var pl := get_tree().get_first_node_in_group("local_player") as Player
	if pl == null:
		return
	var cam := get_viewport().get_camera_3d()
	var others := 0
	if Net.instance != null and is_instance_valid(Net.instance):
		others = Net.instance.avatars.size()
	_dbg.text = "F3  pos %.1f / %.1f / %.1f  Boden:%s\nFPS %d  Objekte %d  Drawcalls %d\nNodes %d  Mitspieler %d  Items %d\nKamera y %.1f  far %.0f\nglow %s  fog %.4f  exp %.2f  amb %.2f  sonne %.2f\nflash %.2f  nebel %.2f  regen %.2f  wolken %.2f  blur %s  promille %.2f  scale3d %.2f" % [
		pl.global_position.x, pl.global_position.y, pl.global_position.z, str(pl.is_on_floor()),
		Engine.get_frames_per_second(),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		get_tree().get_node_count(), others, Item.registry.size(),
		cam.global_position.y if cam != null else -999.0, cam.far if cam != null else 0.0,
		str(_env().glow_enabled), _env().fog_density, _env().tonemap_exposure, _env().ambient_light_energy, _sun_e(),
		Weather.flash, Weather.fog, Weather.rain, Weather.cloud, str(pl.blur_rect.visible), pl.promille, get_viewport().scaling_3d_scale]


func _world() -> Node:
	var pl := get_tree().get_first_node_in_group("local_player")
	return pl.get_parent() if pl != null else self


func _env() -> Environment:
	var e: Environment = _world().get("env") as Environment
	return e if e != null else Environment.new()


func _sun_e() -> float:
	var sn: Variant = _world().get("sun")
	return (sn as DirectionalLight3D).light_energy if sn != null else -1.0


func toggle_goals() -> void:
	if _goals_full != null:
		_goals_full.visible = not _goals_full.visible


func _goal_row(text: String, done: bool, current: bool) -> void:
	if current:
		var p := _panel(Color("f8dcc0"), 10, 0.0, Vector4(10, 6, 10, 6))
		(p.get_theme_stylebox("panel") as StyleBoxFlat).border_color = UI.FIRE
		var l := _lbl(text, 14, UI.INK, UI.f_head)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(230, 0)
		p.add_child(l)
		_goals_box.add_child(p)
		return
	var l2 := _lbl(("✓ " if done else "○ ") + text, 13, UI.TEXT_LOW if not done else Color(UI.TEXT_LOW, 0.7))
	l2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l2.custom_minimum_size = Vector2(250, 0)
	_goals_box.add_child(l2)


# ---------------------------------------------------------------- Prompt

func _build_prompt() -> void:
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	c.offset_top = -150
	c.offset_bottom = -88
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	_prompt_wrap = PanelContainer.new()
	_prompt_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s := UI.pill(Color(UI.FOREST, 0.92), UI.PAPER)
	_prompt_wrap.add_theme_stylebox_override("panel", s)
	_prompt_row = HBoxContainer.new()
	_prompt_row.add_theme_constant_override("separation", 8)
	_prompt_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_prompt_wrap.add_child(_prompt_row)
	_prompt_wrap.visible = false
	c.add_child(_prompt_wrap)


## Text wie "E: Heckklappe öffnen   G: werfen" -> Taste-Chips und Text. Zweite Zeile (nach \n) = Hinweis.
func set_prompt(text: String) -> void:
	text = Game.touchify(text)
	if text == _prompt_text:
		return
	_prompt_text = text
	for c in _prompt_row.get_children():
		c.queue_free()
	_prompt_wrap.visible = text != ""
	if text == "":
		return
	var lines := text.split("\n")
	var segs := lines[0].split("   ")
	for sg in segs:
		var s: String = sg.strip_edges()
		if s == "":
			continue
		var ci := s.find(": ")
		if ci > 0 and ci <= (12 if _touch else 8) and s.substr(0, ci) == s.substr(0, ci).to_upper():
			_prompt_row.add_child(key_chip(s.substr(0, ci)))
			_prompt_row.add_child(_lbl(s.substr(ci + 2), 17, UI.PAPER, UI.f_label))
		else:
			_prompt_row.add_child(_lbl(s, 17, UI.PAPER, UI.f_label))
	if lines.size() > 1:
		_prompt_row.add_child(_lbl(lines[1].strip_edges().trim_prefix("(").trim_suffix(")"), 15, Color("ef7c63"), UI.f_label))


# ---------------------------------------------------------------- Meldung

func _build_toast() -> void:
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	c.offset_top = 108
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	_toast_wrap = PanelContainer.new()
	_toast_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_label = _lbl("", 18, UI.PAPER, UI.f_label)
	_toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast_label.custom_minimum_size = Vector2(0, 0)
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_wrap.add_child(_toast_label)
	_toast_wrap.modulate.a = 0.0
	c.add_child(_toast_wrap)


func toast(text: String, seconds: float = 4.0) -> void:
	text = Game.touchify(text)
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	var alarm := text.begins_with("ALLE") or text.contains("RUMMS") or text.contains("Zu spät") or text.contains("PLATSCH") or text.contains("Achtung") or text.contains("!!")
	var s := UI.pill(UI.FIRE if alarm else UI.FOREST, UI.INK if alarm else UI.PAPER)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 9
	s.content_margin_bottom = 9
	s.set_corner_radius_all(16)
	_toast_wrap.add_theme_stylebox_override("panel", s)
	_toast_label.add_theme_color_override("font_color", UI.INK if alarm else UI.PAPER)
	_toast_label.text = text
	_toast_label.custom_minimum_size.x = clampf(text.length() * 9.5, 120.0, 640.0)
	_toast_wrap.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(seconds)
	_toast_tween.tween_property(_toast_wrap, "modulate:a", 0.0, 0.8)


# ---------------------------------------------------------------- Promille

func _build_drunk() -> void:
	_drunk = _panel(Color("e8c547"), 10, 3.0, Vector4(10, 3, 10, 3))
	_drunk.position = Vector2(14, 0)
	_drunk.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_drunk.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_drunk.offset_left = 14
	_drunk.offset_bottom = -152
	_drunk_l = _lbl("", 13, UI.INK, UI.f_head)
	_drunk.add_child(_drunk_l)
	_drunk.visible = false
	add_child(_drunk)


# ---------------------------------------------------------------- Steuerung

func _build_help() -> void:
	_help = _panel(Color(UI.PAPER, 0.95), 14, 4.0, Vector4(14, 10, 14, 10))
	_help.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_help.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_help.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_help.offset_right = -14
	_help.offset_bottom = -14
	add_child(_help)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	_help.add_child(v)
	var hd := HBoxContainer.new()
	var t := _lbl("Steuerung", 16, UI.INK, UI.f_head)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hd.add_child(t)
	hd.add_child(_lbl("I = alle Tasten", 12, UI.TEXT_LOW, UI.f_mono))
	v.add_child(hd)
	var g := GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override("h_separation", 8)
	g.add_theme_constant_override("v_separation", 4)
	v.add_child(g)
	var rows := [["WASD", "laufen"], ["⇧", "rennen"], ["␣", "springen"], ["E", "benutzen"], ["F", "trinken"], ["R", "aufstellen"],
		["X", "abbauen"], ["G", "werfen"], ["C", "ducken"], ["L", "Kopflampe"], ["P", "pinkeln"], ["H", "Geschäft"],
		["Q", "Vape"], ["T", "Angelart"], ["Z", "Zutat"], ["V", "Ansicht"], ["Esc", "Maus frei"]]
	for r in rows:
		var kc := key_chip(r[0])
		g.add_child(kc)
		g.add_child(_lbl(r[1], 13, UI.INK, UI.f_label))


func toggle_info() -> void:
	if _info != null:
		_info.visible = not _info.visible


func _build_info() -> void:
	_info = Control.new()
	_info.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info.visible = false
	add_child(_info)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info.add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info.add_child(cc)
	var panel := _panel(Color(UI.PAPER, 0.98), 16, 4.0, Vector4(22, 16, 22, 16))
	cc.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	var hd := HBoxContainer.new()
	var t := _lbl("Tastenbelegung", 22, UI.INK, UI.f_head)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hd.add_child(t)
	hd.add_child(_lbl("I oder F1 schließt", 13, UI.TEXT_LOW, UI.f_mono))
	v.add_child(hd)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 34)
	v.add_child(cols)
	var sections := [
		["Bewegen", [["WASD", "laufen"], ["⇧", "rennen"], ["␣", "springen"], ["C", "ducken"], ["V", "Ansicht wechseln"], ["1 2 3", "Charakter"], ["Esc", "Maus frei"]]],
		["Handeln", [["E", "benutzen / auspacken"], ["F", "trinken"], ["G", "werfen"], ["R", "aufstellen"], ["X", "abbauen"], ["Z", "Auswahl wechseln"], ["L", "Kopflampe"]]],
		["Körper & Angeln", [["P", "pinkeln (halten)"], ["H", "großes Geschäft"], ["Q", "Vape (Julian)"], ["T", "Angelart"], ["Klick", "auswerfen / anschlagen"]]],
	]
	for sec in sections:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 5)
		cols.add_child(col)
		col.add_child(_lbl(sec[0], 15, UI.TEXT_LOW, UI.f_head))
		for r in sec[1]:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			var kc := key_chip(r[0])
			kc.custom_minimum_size = Vector2(46, 26)
			row.add_child(kc)
			row.add_child(_lbl(r[1], 14, UI.INK, UI.f_label))
			col.add_child(row)
	v.add_child(_lbl("Tipps: Rucksack mit R aufstellen und mit E auspacken · Rute in den Rutenständer: E, rotes Blinken = Fisch am Haken · Wasser hilft gegen Rausch", 13, UI.TEXT_LOW, UI.f_label))


# ---------------------------------------------------------------- Daten

func update_info(p_name: String, char_name: String, carrying: String, camp: String, hour: float, day: int, clock: String, phase: String, \
		promille: float, stats: Array, others: Array) -> void:
	_clock_day.text = "Tag %d" % day
	_clock.text = clock
	_phase.text = phase
	_bar.hour = hour
	_bar.queue_redraw()
	for c in _players.get_children():
		c.queue_free()
	var me := HBoxContainer.new()
	me.add_theme_constant_override("separation", 8)
	me.add_child(_dot(UI.CHAR_COLORS.get(char_name, UI.CHAR_COLORS["Gast"])))
	me.add_child(_lbl(p_name, 15, UI.INK, UI.f_head))
	me.add_child(_lbl("(du)", 12, UI.TEXT_LOW))
	_players.add_child(me)
	for o in others:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.add_child(_dot(UI.CHAR_COLORS.get(o[1], UI.CHAR_COLORS["Gast"])))
		row.add_child(_lbl(o[0], 15, UI.INK, UI.f_head))
		_players.add_child(row)
	var st := _lbl("Hand: %s · Lager: %s" % [carrying, camp], 12, UI.TEXT_LOW)
	_players.add_child(st)
	_pack_l1.text = "Zunder %d  Äste %d  Holz %d  Steine %d" % [stats[0], stats[1], stats[2], stats[3]]
	_pack_l2.text = "Bier %d  Wasser %d  Fänge %d  Chili %d" % [stats[4], stats[5], stats[6], stats[7]]
	_drunk.visible = promille > 0.04
	_drunk_l.text = "Angetrunken · %.2f ‰" % promille
