class_name Credits
extends Control
## Abspann nach dem Finale: Titel, Auszeichnungen aus der Statistik aller Spieler, Gruppen-Summe
## und der Hinweis auf das Endziel (Riesenwels). Klick/Enter/Leertaste blaettert, Esc ueberspringt.

signal closed

const HOLD := 6.5
const GOLD := Color(1.0, 0.8, 0.25)

var _bg: ColorRect
var _holder: CenterContainer
var _slides: Array = []
var _idx: int = -1
var _cur: Control = null
var _tw: Tween = null
var _go_btn: Button
var _skip_btn: Button
var _last_click: float = 0.0
var _closing: bool = false


func begin() -> void:
	UI.fonts()
	theme = UI.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_bg = ColorRect.new()
	_bg.color = Color(0.02, 0.04, 0.03, 0.0)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_bg)
	create_tween().tween_property(_bg, "color:a", 0.74, 1.6)
	_holder = CenterContainer.new()
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_holder)

	_skip_btn = Button.new()
	_skip_btn.text = "Überspringen (Esc)"
	_skip_btn.focus_mode = Control.FOCUS_NONE
	_skip_btn.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_skip_btn.offset_left = -230
	_skip_btn.offset_top = -62
	_skip_btn.offset_right = -18
	_skip_btn.offset_bottom = -16
	_skip_btn.pressed.connect(_close)
	add_child(_skip_btn)

	_go_btn = Button.new()
	_go_btn.text = "Weiterspielen"
	_go_btn.focus_mode = Control.FOCUS_NONE
	UI.primary_button(_go_btn)
	_go_btn.add_theme_font_size_override("font_size", 24)
	_go_btn.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_go_btn.offset_left = -130
	_go_btn.offset_right = 130
	_go_btn.offset_top = -110
	_go_btn.offset_bottom = -50
	_go_btn.visible = false
	_go_btn.pressed.connect(_close)
	add_child(_go_btn)

	if not Game.touch:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_slides = [_s_title, _s_awards_1, _s_awards_2, _s_awards_3, _s_totals, _s_teaser]
	_show(0)


func _show(i: int) -> void:
	if _closing:
		return
	_idx = i
	if _tw != null and _tw.is_valid():
		_tw.kill()
	var old := _cur
	_cur = (_slides[i] as Callable).call()
	_cur.modulate.a = 0.0
	_holder.add_child(_cur)
	_tw = create_tween()
	if old != null and is_instance_valid(old):
		_tw.tween_property(old, "modulate:a", 0.0, 0.4)
		_tw.tween_callback(old.queue_free)
	_tw.tween_property(_cur, "modulate:a", 1.0, 0.7)
	if i < _slides.size() - 1:
		_tw.tween_interval(HOLD)
		_tw.tween_callback(func() -> void: _show(_idx + 1))
	else:
		_go_btn.visible = true
		_skip_btn.visible = false


func _advance() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_click < 0.5:
		return
	_last_click = now
	if _idx < _slides.size() - 1:
		_show(_idx + 1)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_advance()
	elif event is InputEventScreenTouch and event.pressed:
		_advance()


func _input(event: InputEvent) -> void:
	if _closing or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var k := (event as InputEventKey).keycode
	if k == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_close()
	elif k == KEY_ENTER or k == KEY_SPACE or k == KEY_KP_ENTER:
		get_viewport().set_input_as_handled()
		_advance()


func _close() -> void:
	if _closing:
		return
	_closing = true
	if _tw != null and _tw.is_valid():
		_tw.kill()
	if not Game.touch:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func() -> void: closed.emit())


# ---------- Bausteine ----------

func _lbl(text: String, size: int, col: Color, head: bool = true, center: bool = true) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", UI.f_head if head else UI.f_label)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 8)
	if center:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _box(sep: int = 14) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return v


func _wrap(text: String, size: int, col: Color, width: float) -> Label:
	var l := _lbl(text, size, col, false)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(width, 0)
	return l


func _names() -> Array:
	var out: Array = Game.stats_all.keys()
	if out.is_empty():
		out.append(Game.player_name)
	return out


## Gewinner einer Wertung: [Namen, Wert]
func _winners(key: String) -> Array:
	var best := 0.0
	var names: Array = []
	for n in Game.stats_all.keys():
		var v := float((Game.stats_all[n] as Dictionary).get(key, 0))
		if v > best + 0.0001:
			best = v
			names = [str(n)]
		elif v > 0.0 and absf(v - best) < 0.0001:
			names.append(str(n))
	return [names, best]


func _card(title: String, who: String, detail: String) -> Control:
	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(340, 0)
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vb := _box(4)
	pc.add_child(vb)
	var t := _lbl(title, 17, UI.TEXT_LOW)
	t.add_theme_constant_override("outline_size", 0)
	vb.add_child(t)
	var w := _lbl(who, 34, UI.INK)
	w.add_theme_constant_override("outline_size", 0)
	w.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	w.custom_minimum_size = Vector2(300, 0)
	vb.add_child(w)
	var d := _lbl(detail, 18, UI.DANGER, false)
	d.add_theme_constant_override("outline_size", 0)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(300, 0)
	vb.add_child(d)
	return pc


func _award(title: String, key: String, fmt: String, zero_who: String, zero_detail: String) -> Control:
	var w := _winners(key)
	var names: Array = w[0]
	if names.is_empty():
		return _card(title, zero_who, zero_detail)
	return _card(title, " & ".join(PackedStringArray(names)), fmt % int(w[1]))


func _row(a: Control, b: Control) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 26)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(a)
	h.add_child(b)
	return h


func _two(head: String, a: Control, b: Control) -> Control:
	var v := _box(26)
	v.add_child(_lbl(head, 40, GOLD))
	v.add_child(_row(a, b))
	return v


# ---------- Folien ----------

func _s_title() -> Control:
	var v := _box(16)
	v.add_child(_lbl("THREE IN THE WILD", 76, GOLD))
	v.add_child(_lbl("Ein perfekter Angelausflug", 30, UI.PAPER))
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 22)
	v.add_child(sp)
	v.add_child(_lbl("Mit", 20, UI.TEXT_LOW.lightened(0.5), false))
	v.add_child(_lbl("  ·  ".join(PackedStringArray(_names())), 38, UI.PAPER))
	return v


func _s_awards_1() -> Control:
	return _two("DIE AUSZEICHNUNGEN",
		_award("BIERKÖNIG", "beer", "%d Bier getrunken", "Niemand", "Alle nüchtern? Verdächtig."),
		_award("HOSEN-HELD", "pants", "%d Mal in die Hose gemacht", "Niemand", "Alle trocken geblieben. Wirklich."))


func _s_awards_2() -> Control:
	var w := _winners("best_kg")
	var angel: Control
	if (w[0] as Array).is_empty():
		angel = _card("ANGELKÖNIG", "Niemand", "Keiner hat geangelt?")
	else:
		var who: String = str((w[0] as Array)[0])
		var d: Dictionary = Game.stats_all[who]
		var extra := " (+%d weitere)" % ((w[0] as Array).size() - 1) if (w[0] as Array).size() > 1 else ""
		angel = _card("ANGELKÖNIG", who + extra, "Größter Fang: %s, %.1f kg" % [str(d.get("best", "?")), float(d.get("best_kg", 0.0))])
	return _two("DIE AUSZEICHNUNGEN", angel,
		_award("KOTZKÖNIG", "vomit", "%d Mal übergeben", "Niemand", "Magen aus Stahl."))


func _s_awards_3() -> Control:
	return _two("DIE AUSZEICHNUNGEN",
		_award("WALD-DÜNGER", "poop", "%d Haufen im Wald hinterlassen", "Niemand", "Der Wald bleibt sauber."),
		_award("ZOMBIE DES JAHRES", "deaths", "%d Mal gestorben", "Niemand", "Unsterblich. Langweilig."))


func _s_totals() -> Control:
	var tot := {"beer": 0, "fish": 0, "pants": 0, "poop": 0, "vomit": 0, "deaths": 0}
	for n in Game.stats_all.keys():
		for k in tot.keys():
			tot[k] += int((Game.stats_all[n] as Dictionary).get(k, 0))
	var v := _box(10)
	v.add_child(_lbl("DIE GANZE GRUPPE", 40, GOLD))
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 8)
	v.add_child(sp)
	var lines := [
		"%d Tage in der Wildnis" % Game.day_count,
		"%d Bier getrunken" % tot["beer"],
		"%d Fische gefangen" % tot["fish"],
		"%d Missgeschicke in der Hose" % tot["pants"],
		"%d Haufen im Wald" % tot["poop"],
		"%d Mal übergeben" % tot["vomit"],
		"%d Mal gestorben" % tot["deaths"],
	]
	for l in lines:
		v.add_child(_lbl(l, 30, UI.PAPER, false))
	return v


func _s_teaser() -> Control:
	var v := _box(18)
	v.add_child(_lbl("... UND DANN?", 40, GOLD))
	v.add_child(_wrap("Tief unten im See lauert er seit Jahrzehnten: der RIESENWELS.", 26, UI.PAPER, 700))
	v.add_child(_wrap("Die Alten erzählen, er beißt nur nachts, wenn es gewittert. Und kein Mensch zieht ihn allein an Land.", 22, UI.PAPER, 700))
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 8)
	v.add_child(sp)
	v.add_child(_lbl("ENDZIEL: FANG DEN RIESENWELS", 34, UI.FIRE))
	v.add_child(_lbl("Fortsetzung folgt ...", 20, UI.TEXT_LOW.lightened(0.5), false))
	var sp2 := Control.new()
	sp2.custom_minimum_size = Vector2(0, 70)
	v.add_child(sp2)
	return v
