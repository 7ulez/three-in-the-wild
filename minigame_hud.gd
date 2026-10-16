class_name MiniHud
extends Control
## Gemeinsame Anzeige für die Minispiele: Angeln (Anschlag-Ring + Kampf-Tacho), Funkenschlagen, Chili-Rühren.
## Gezeichnet wird alles per _draw; die Spiele füllen nur `kind` und `d`.

var kind: String = ""
var d: Dictionary = {}

var _card_text: String = ""
var _card_sub: String = ""
var _card_col: Color = Color.WHITE
var _card_t: float = 0.0
var _flash: Color = Color(1, 1, 1, 0)
var _bits: Array = []      # Funken/Konfetti im UI: {p, v, life, col}
var _t: float = 0.0


func _ready() -> void:
	UI.fonts()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## Große Karte in der Bildschirmmitte (z. B. "PERFEKT!", "KARPFEN 12 kg").
func card(text: String, sub: String = "", col: Color = UI.FIRE, seconds: float = 2.0) -> void:
	_card_text = text
	_card_sub = sub
	_card_col = col
	_card_t = seconds
	_card_len = seconds


var _card_len: float = 2.0


func flash(col: Color) -> void:
	_flash = col


func burst(pos: Vector2, col: Color, n: int = 14, speed: float = 260.0) -> void:
	for i in range(n):
		var a := randf() * TAU
		_bits.append({"p": pos, "v": Vector2(cos(a), sin(a)) * randf_range(0.3, 1.0) * speed + Vector2(0, -60), "life": randf_range(0.4, 0.9), "col": col})


func clear() -> void:
	kind = ""
	d = {}
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	var need := kind != "" or _card_t > 0.0 or _flash.a > 0.01 or not _bits.is_empty()
	if not need:
		return
	_card_t = maxf(_card_t - delta, 0.0)
	_flash.a = maxf(_flash.a - delta * 2.5, 0.0)
	for b in _bits:
		b["life"] = float(b["life"]) - delta
		b["v"] = (b["v"] as Vector2) + Vector2(0, 500.0 * delta)
		b["p"] = (b["p"] as Vector2) + (b["v"] as Vector2) * delta
	_bits = _bits.filter(func(b: Dictionary) -> bool: return float(b["life"]) > 0.0)
	queue_redraw()


func _draw() -> void:
	if _flash.a > 0.01:
		var c := _flash
		var w := 26.0
		draw_rect(Rect2(0, 0, size.x, w), Color(c.r, c.g, c.b, c.a * 0.5))
		draw_rect(Rect2(0, size.y - w, size.x, w), Color(c.r, c.g, c.b, c.a * 0.5))
		draw_rect(Rect2(0, 0, w, size.y), Color(c.r, c.g, c.b, c.a * 0.4))
		draw_rect(Rect2(size.x - w, 0, w, size.y), Color(c.r, c.g, c.b, c.a * 0.4))
	match kind:
		"bite":
			_draw_bite()
		"fight":
			_draw_fight()
		"fire":
			_draw_fire()
		"stir":
			_draw_stir()
	for b in _bits:
		var cc: Color = b["col"]
		cc.a = clampf(float(b["life"]) * 2.0, 0.0, 1.0)
		draw_circle(b["p"], 3.5, cc)
	if _card_t > 0.0:
		_draw_card()


# ---------- Bausteine ----------

func _text(pos: Vector2, text: String, fs: int, col: Color, align: int = HORIZONTAL_ALIGNMENT_CENTER, _width: float = -1.0) -> void:
	var s := Game.touchify(text)
	var f: Font = UI.f_head
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var p := pos
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		p.x -= w / 2.0
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		p.x -= w
	draw_string_outline(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 7, UI.SHADOW)
	draw_string(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _panel(r: Rect2, bg: Color = Color(0.08, 0.1, 0.09, 0.82)) -> void:
	draw_rect(Rect2(r.position + Vector2(4, 4), r.size), Color(0, 0, 0, 0.35))
	draw_rect(r, bg)
	draw_rect(r, UI.INK, false, 2.0)


func _keycap(center: Vector2, key: String, lit: bool) -> void:
	var s := key
	var wd := 36.0
	if Game.touch:
		s = {"E": "BENUTZEN", "A": "<", "D": ">"}.get(key, key)
		wd = 118.0 if s.length() > 2 else 36.0
	var r := Rect2(center - Vector2(wd / 2.0, 18), Vector2(wd, 36))
	draw_rect(Rect2(r.position + Vector2(2, 3), r.size), Color(0, 0, 0, 0.5))
	draw_rect(r, UI.FIRE if lit else UI.PAPER)
	draw_rect(r, UI.INK, false, 2.0)
	draw_string(UI.f_head, center + Vector2(-wd / 2.0, 8), s, HORIZONTAL_ALIGNMENT_CENTER, wd, 20 if wd > 40.0 else 22, UI.INK)


func _draw_card() -> void:
	var k := clampf(_card_t / 0.35, 0.0, 1.0)
	var pop := 1.0 + maxf(0.0, 1.0 - (_card_len - _card_t) * 6.0) * 0.5
	var c := _card_col
	c.a = k
	var p := Vector2(size.x / 2.0, size.y * 0.3)
	var fs := int(52.0 * pop)
	var f: Font = UI.f_head
	var w := f.get_string_size(_card_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string_outline(f, p - Vector2(w / 2.0, 0), _card_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 12, Color(0, 0, 0, k))
	draw_string(f, p - Vector2(w / 2.0, 0), _card_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c)
	if _card_sub != "":
		var cs := UI.PAPER
		cs.a = k
		var w2 := f.get_string_size(_card_sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
		var q := p + Vector2(-w2 / 2.0, 40)
		draw_string_outline(f, q, _card_sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, 8, Color(0, 0, 0, k))
		draw_string(f, q, _card_sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, cs)


# ---------- Angeln: Anschlag ----------

func _draw_bite() -> void:
	var c := Vector2(size.x / 2.0, size.y * 0.5)
	var ph: float = d.get("phase", 0.0)        # 0..1: Ring schrumpft
	var ring := lerpf(150.0, 46.0, ph)
	var perfect_ok: bool = ph > 0.72
	draw_circle(c, 46.0, Color(0.1, 0.9, 0.3, 0.12 + (0.25 if perfect_ok else 0.0)))
	draw_arc(c, 46.0, 0, TAU, 48, Color(0.3, 1.0, 0.4) if perfect_ok else UI.PAPER, 4.0, true)
	draw_arc(c, ring, 0, TAU, 64, UI.DANGER if ph < 0.72 else Color(1.0, 0.9, 0.2), 7.0, true)
	var pulse := 1.0 + sin(_t * 22.0) * 0.08
	_text(c + Vector2(0, -190), "BISS!", int(60 * pulse), UI.DANGER)
	_text(c + Vector2(0, 8), "KLICK", 26, UI.PAPER)
	_text(c + Vector2(0, 205), "Klick, wenn der Ring das grüne Feld trifft = perfekter Anschlag", 18, UI.PAPER)
	var left: float = d.get("left", 1.0)
	draw_rect(Rect2(c.x - 100, c.y + 170, 200, 8), Color(0, 0, 0, 0.5))
	draw_rect(Rect2(c.x - 100, c.y + 170, 200 * clampf(left, 0, 1), 8), UI.DANGER)


# ---------- Angeln: Drill ----------

func _draw_fight() -> void:
	var cx := size.x / 2.0
	var base := size.y - 280.0
	var tension: float = d.get("tension", 0.0)
	var stamina: float = d.get("stamina", 1.0)
	var dist01: float = d.get("dist01", 0.5)
	var pull: int = d.get("pull", 0)
	var jump: float = d.get("jump", 0.0)
	var reeling: bool = d.get("reeling", false)
	var counter: int = d.get("counter", 0)
	var fname: String = d.get("name", "")
	var kg: float = d.get("kg", 0.0)

	# Tacho
	var gc := Vector2(cx, base)
	var r := 105.0
	_panel(Rect2(cx - 150, base - 135, 300, 170))
	draw_arc(gc, r, PI, TAU, 40, Color(0.25, 0.25, 0.25), 18.0, true)
	draw_arc(gc, r, PI + 0.0, PI + PI * 0.3, 12, Color(0.8, 0.45, 0.2), 18.0, true)
	draw_arc(gc, r, PI + PI * 0.3, PI + PI * 0.7, 16, Color(0.3, 0.85, 0.35), 18.0, true)
	draw_arc(gc, r, PI + PI * 0.7, PI + PI * 0.9, 8, Color(1.0, 0.7, 0.2), 18.0, true)
	draw_arc(gc, r, PI + PI * 0.9, TAU, 6, Color(0.9, 0.2, 0.15), 18.0, true)
	var shake_v := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * maxf(tension - 0.8, 0.0) * 14.0
	var ang := PI + clampf(tension, 0.0, 1.0) * PI
	var tip := gc + Vector2(cos(ang), sin(ang)) * (r - 6.0) + shake_v
	draw_line(gc, tip, UI.PAPER, 5.0, true)
	draw_circle(gc, 9.0, UI.PAPER)
	_text(gc + Vector2(0, -r * 0.45), "SCHNUR", 15, Color(1, 1, 1, 0.7))
	if tension > 0.82:
		var a := 0.5 + 0.5 * sin(_t * 30.0)
		_text(gc + Vector2(0, 28), "REISST GLEICH!", 20, Color(1, 0.3 + a * 0.2, 0.2))
	elif tension >= 0.3 and tension <= 0.7 and reeling:
		_text(gc + Vector2(0, 28), "Optimal - kurbeln!", 18, Color(0.5, 1, 0.55))

	# Fisch: Name, Ausdauer
	_text(Vector2(cx, base - 148), "%s  %.1f kg" % [fname, kg], 24, UI.PAPER)
	var sw := 220.0
	var sx := cx - sw / 2.0
	var sy := base + 52.0
	draw_rect(Rect2(sx, sy, sw, 14), Color(0, 0, 0, 0.55))
	var sc := Color(0.95, 0.75, 0.25).lerp(Color(0.5, 0.8, 1.0), 1.0 - stamina)
	draw_rect(Rect2(sx, sy, sw * clampf(stamina, 0, 1), 14), sc)
	draw_rect(Rect2(sx, sy, sw, 14), UI.INK, false, 2.0)
	_text(Vector2(sx - 6, sy + 12), "Kraft", 15, UI.PAPER, HORIZONTAL_ALIGNMENT_RIGHT, 1.0)

	# Distanz-Strecke
	var tx0 := cx - 260.0
	var tx1 := cx + 260.0
	var ty := base + 92.0
	draw_line(Vector2(tx0, ty), Vector2(tx1, ty), Color(0, 0, 0, 0.6), 8.0)
	draw_line(Vector2(tx0, ty), Vector2(tx1, ty), Color(0.55, 0.78, 0.9), 3.0)
	draw_circle(Vector2(tx0, ty), 9.0, UI.FIRE)
	var fx := lerpf(tx0 + 14.0, tx1, clampf(dist01, 0.0, 1.0))
	var wob := sin(_t * (18.0 if pull != 0 else 6.0)) * (4.0 if pull != 0 else 1.5)
	var fpos := Vector2(fx, ty + wob)
	var body := PackedVector2Array([fpos + Vector2(-16, 0), fpos + Vector2(-4, -7), fpos + Vector2(10, 0), fpos + Vector2(-4, 7)])
	draw_colored_polygon(body, Color(0.95, 0.8, 0.35))
	draw_colored_polygon(PackedVector2Array([fpos + Vector2(10, 0), fpos + Vector2(20, -7), fpos + Vector2(20, 7)]), Color(0.9, 0.6, 0.2))
	draw_circle(fpos + Vector2(-9, -2), 1.6, Color.BLACK)
	_text(Vector2(tx0, ty + 26), "du", 14, UI.PAPER, HORIZONTAL_ALIGNMENT_LEFT, 1.0)
	_text(Vector2(tx1, ty + 26), "%.0f m" % d.get("dist", 0.0), 14, UI.PAPER, HORIZONTAL_ALIGNMENT_RIGHT, 1.0)

	# Zugrichtung
	if pull != 0:
		var flash_on := int(_t * 8.0) % 2 == 0
		var side := 1.0 if pull > 0 else -1.0
		var ax := cx + side * 300.0
		var ay := base - 20.0
		var col := UI.DANGER if flash_on else Color(1, 0.65, 0.2)
		for i in range(3):
			var o := side * (float(i) * 26.0 + fmod(_t * 90.0, 26.0))
			var p0 := Vector2(ax + o, ay)
			var arrow := PackedVector2Array([p0 + Vector2(side * 18, 0), p0 + Vector2(-side * 6, -22), p0 + Vector2(-side * 6, 22)])
			var cc := col
			cc.a = 1.0 - float(i) * 0.3
			draw_colored_polygon(arrow, cc)
		_text(Vector2(ax, ay - 40), "Fisch zieht %s!" % ("RECHTS" if pull > 0 else "LINKS"), 22, col)
		var need_key := "D" if pull > 0 else "A"      # in Fischrichtung mitgehen
		_keycap(Vector2(ax, ay + 50), need_key, counter == pull)
		_text(Vector2(ax, ay + 98), "gleiche Richtung drücken", 15, UI.PAPER)
	else:
		_text(Vector2(cx - 300, base - 20), "A / D: in Zugrichtung drücken", 16, Color(1, 1, 1, 0.55))

	# Sprung
	if jump > 0.0:
		var a2 := 0.6 + 0.4 * sin(_t * 28.0)
		_text(Vector2(cx, size.y * 0.42), "FISCH SPRINGT!", 54, Color(1.0, 0.9, 0.2, a2))
		_text(Vector2(cx, size.y * 0.42 + 38), "Maustaste LOSLASSEN - Rute senken!", 26, UI.PAPER)
	else:
		var hint := "Maustaste halten: einholen" if not reeling else "Einholen..."
		_text(Vector2(cx, base + 140), hint, 17, Color(1, 1, 1, 0.7))


# ---------- Feuerstahl ----------

func _draw_fire() -> void:
	var cx := size.x / 2.0
	var cy := size.y * 0.72
	var w := 520.0
	var h := 38.0
	var x0 := cx - w / 2.0
	var pos: float = d.get("pos", 0.0)
	var zx: float = d.get("zone_x", 0.4)
	var zw: float = d.get("zone_w", 0.13)
	var hits: int = d.get("hits", 0)
	var need: int = d.get("needed", 4)
	var combo: int = d.get("combo", 0)
	var fl: float = d.get("flash", 0.0)
	var good: bool = d.get("flash_good", true)

	_panel(Rect2(x0 - 22, cy - 118, w + 44, 190))
	# Flammen-Leiste: jede Flamme = ein Treffer
	for i in range(need):
		var fx := cx + (float(i) - float(need - 1) / 2.0) * 58.0
		var lit := i < hits
		var base := Vector2(fx, cy - 52.0)
		var hgt := 44.0 + (sin(_t * 9.0 + float(i)) * 4.0 if lit else 0.0)
		var col_o := Color(1.0, 0.45, 0.1) if lit else Color(0.25, 0.25, 0.25)
		var col_i := Color(1.0, 0.9, 0.35) if lit else Color(0.32, 0.32, 0.32)
		draw_colored_polygon(PackedVector2Array([base + Vector2(-16, 0), base + Vector2(-9, -hgt * 0.55), base + Vector2(0, -hgt), base + Vector2(10, -hgt * 0.5), base + Vector2(16, 0), base + Vector2(0, 8)]), col_o)
		draw_colored_polygon(PackedVector2Array([base + Vector2(-8, 0), base + Vector2(0, -hgt * 0.6), base + Vector2(8, 0), base + Vector2(0, 5)]), col_i)
	# Leiste
	draw_rect(Rect2(x0, cy, w, h), Color(0.12, 0.12, 0.13))
	# Zielfeld mit Glühen
	var zr := Rect2(x0 + w * zx, cy, w * zw, h)
	var gl := 0.35 + 0.25 * sin(_t * 8.0)
	draw_rect(Rect2(zr.position - Vector2(5, 5), zr.size + Vector2(10, 10)), Color(0.3, 1.0, 0.4, gl * 0.5))
	draw_rect(zr, Color(0.3, 0.9, 0.35))
	draw_rect(Rect2(zr.position + Vector2(zr.size.x * 0.5 - 2, 0), Vector2(4, h)), Color(1, 1, 1, 0.5))
	# Strich + Nachleuchten
	for k in range(5):
		var pp: float = pos - float(k) * 0.012 * float(d.get("dir", 1.0))
		draw_rect(Rect2(x0 + w * pp - 3, cy - 4, 6, h + 8), Color(1.0, 0.85, 0.3, 0.55 - float(k) * 0.1))
	draw_rect(Rect2(x0 + w * pos - 4, cy - 8, 8, h + 16), Color(1.0, 0.95, 0.6))
	draw_rect(Rect2(x0, cy, w, h), UI.INK, false, 3.0)
	if fl > 0.0:
		var fc := Color(0.3, 1.0, 0.4, fl * 0.5) if good else Color(1.0, 0.25, 0.2, fl * 0.5)
		draw_rect(Rect2(x0, cy, w, h), fc)
	var cap_y := cy + 62.0
	_keycap(Vector2(cx - 150, cap_y), "E", fl > 0.5)
	_text(Vector2(cx + 20, cap_y + 8), "Funken schlagen!  %d / %d" % [hits, need], 22, UI.PAPER)
	if combo >= 2:
		_text(Vector2(cx, cy - 128), "COMBO x%d" % combo, 28, UI.FIRE)


# ---------- Chili rühren ----------

func _draw_stir() -> void:
	var c := Vector2(size.x / 2.0, size.y * 0.52)
	var R := 120.0
	var bubbles: Array = d.get("bubbles", [])
	var score: int = d.get("score", 0)
	var combo: int = d.get("combo", 0)
	var tl: float = d.get("time_left", 0.0)
	var burn: float = d.get("burn", 0.0)
	var spin: float = d.get("spin", 0.0)
	# Topf von oben
	draw_circle(c + Vector2(4, 6), R + 16.0, Color(0, 0, 0, 0.4))
	draw_circle(c, R + 14.0, Color(0.12, 0.12, 0.13))
	draw_circle(c, R + 14.0, UI.INK)
	draw_circle(c, R + 10.0, Color(0.16, 0.16, 0.18))
	var chili := Color(0.62, 0.2, 0.1).lerp(Color(0.12, 0.05, 0.03), clampf(burn, 0, 1))
	draw_circle(c, R, chili)
	draw_arc(c, R * 0.62, spin, spin + 3.4, 24, chili.lightened(0.18), 10.0, true)
	draw_arc(c, R * 0.3, spin + 2.0, spin + 5.0, 20, chili.lightened(0.12), 8.0, true)
	# Löffel
	var sp := c + Vector2(cos(spin + 0.4), sin(spin + 0.4)) * R * 0.55
	draw_line(c + Vector2(cos(spin + 0.4), sin(spin + 0.4)) * R * 1.3, sp, Color(0.75, 0.55, 0.3), 9.0, true)
	draw_circle(sp, 13.0, Color(0.8, 0.6, 0.34))
	# Blasen
	for b in bubbles:
		var bc := c + Vector2(cos(float(b["a"])), sin(float(b["a"]))) * R * float(b["rad"])
		var p: float = b["p"]            # 1 -> 0: Ring zieht sich zusammen
		var rr := 14.0 + 52.0 * maxf(p, 0.0)
		var hit_zone: bool = p < 0.22
		draw_circle(bc, 14.0, Color(1.0, 0.8, 0.4, 0.85) if hit_zone else Color(1.0, 0.55, 0.3, 0.6))
		draw_arc(bc, rr, 0, TAU, 32, Color(1, 1, 1, 0.9) if not hit_zone else Color(0.4, 1.0, 0.5), 4.0, true)
		if b.get("res", "") != "":
			_text(bc + Vector2(0, -26), str(b["res"]), 20, Color(0.5, 1, 0.55) if b["res"] == "PERFEKT" else UI.FIRE)
	# Kopfzeile
	_text(Vector2(c.x, c.y - R - 54), "RÜHREN!", 40, UI.FIRE)
	_text(Vector2(c.x, c.y - R - 24), "E drücken, wenn der Ring die Blase trifft", 18, UI.PAPER)
	_text(Vector2(c.x - R - 90, c.y - 6), "%d" % score, 46, UI.PAPER)
	_text(Vector2(c.x - R - 90, c.y + 22), "Punkte", 15, Color(1, 1, 1, 0.7))
	if combo >= 2:
		_text(Vector2(c.x + R + 90, c.y - 6), "x%d" % combo, 46, UI.FIRE)
		_text(Vector2(c.x + R + 90, c.y + 22), "Combo", 15, Color(1, 1, 1, 0.7))
	draw_rect(Rect2(c.x - 100, c.y + R + 34, 200, 10), Color(0, 0, 0, 0.55))
	draw_rect(Rect2(c.x - 100, c.y + R + 34, 200 * clampf(tl, 0, 1), 10), UI.FIRE)
	_keycap(Vector2(c.x, c.y + R + 78), "E", false)
