class_name MapView
extends Control
## Karte (Taste M): See, Wald, Berg, Parkplatz, Lager, gefundene Verstecke und alle Spieler.
## Norden (-Z) ist oben. Der Hintergrund (Gelände + Bäume) wird einmal als Bild gemalt.

const XMIN := -151.0
const XMAX := 151.0
const ZMIN := -131.0
const ZMAX := 91.0
const LAKE_OFF := Vector2(0.0, 15.0)        # lake_root steht bei (0, 0, 15)
const MASSIF_C := Vector2(100.0, -72.0)
const MASSIF_R := 30.0

const C_GROUND := Color("cfd8a6")
const C_FOREST := Color("6f8f55")
const C_WATER := Color("8fc3dc")
const C_WATER_EDGE := Color("4f86a3")
const C_ROCK := Color("b4aa98")
const C_INK := Color("1d1f1a")
const C_PAPER := Color("f4efe4")

var _bg: ImageTexture = null
var _t: float = 0.0
var _rect: Rect2 = Rect2()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func toggle() -> void:
	visible = not visible
	if visible:
		if _bg == null:
			_bg = _make_background()
		queue_redraw()


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	queue_redraw()


# ---------- Koordinaten ----------

func _w2m(x: float, z: float) -> Vector2:
	return _rect.position + Vector2((x - XMIN) / (XMAX - XMIN) * _rect.size.x, (z - ZMIN) / (ZMAX - ZMIN) * _rect.size.y)


func _wv(p: Vector3) -> Vector2:
	return _w2m(p.x, p.z)


func _px_per_m() -> float:
	return _rect.size.x / (XMAX - XMIN)


# ---------- Hintergrund einmal malen: Wiese + Waldpunkte ----------

func _make_background() -> ImageTexture:
	var w := 604
	var h := 444
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(C_GROUND)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	# leichte Papier-Struktur
	for i in range(2500):
		var x := rng.randi() % w
		var y := rng.randi() % h
		img.set_pixel(x, y, C_GROUND.darkened(rng.randf_range(0.02, 0.07)))
	var main: Node = null
	var pl := get_tree().get_first_node_in_group("local_player")
	if pl != null:
		main = pl.get_parent()
	if main == null:
		main = get_tree().current_scene
	var spots: Array = main.get("tree_spots") if main != null and main.get("tree_spots") != null else []
	for t in spots:
		var p := t as Vector3
		var u := int((p.x - XMIN) / (XMAX - XMIN) * w)
		var v := int((p.z - ZMIN) / (ZMAX - ZMIN) * h)
		var c := C_FOREST.darkened(rng.randf_range(0.0, 0.18))
		for dx in range(-2, 3):
			for dy in range(-2, 3):
				if absi(dx) + absi(dy) < 3 and u + dx >= 0 and u + dx < w and v + dy >= 0 and v + dy < h:
					img.set_pixel(u + dx, v + dy, c)
	return ImageTexture.create_from_image(img)


# ---------- Zeichnen ----------

func _draw() -> void:
	var vs := size
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0.02, 0.03, 0.02, 0.6))
	# Kartengröße: passt ins Bild, Seitenverhältnis der Welt
	var aspect := (XMAX - XMIN) / (ZMAX - ZMIN)
	var mw := minf(vs.x * 0.86, vs.y * 0.8 * aspect)
	var mh := mw / aspect
	_rect = Rect2((vs - Vector2(mw, mh)) / 2.0 + Vector2(0, 14), Vector2(mw, mh))
	var frame := _rect.grow(14)
	draw_rect(Rect2(frame.position + Vector2(6, 8), frame.size), Color(0, 0, 0, 0.35))
	draw_rect(frame, C_PAPER)
	if _bg != null:
		draw_texture_rect(_bg, _rect, false)
	var f_head: Font = UI.f_head if UI.f_head != null else ThemeDB.fallback_font
	var f_lab: Font = UI.f_label if UI.f_label != null else ThemeDB.fallback_font
	var k := _px_per_m()

	# Titel
	draw_string(f_head, Vector2(frame.position.x, frame.position.y - 12), "KARTE", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, C_PAPER)
	draw_string(f_lab, Vector2(frame.end.x - 220, frame.position.y - 14), "M  schließen", HORIZONTAL_ALIGNMENT_RIGHT, 220, 15, Color(C_PAPER, 0.8))

	# Berg mit Höhenlinien
	var mc := _w2m(MASSIF_C.x, MASSIF_C.y)
	draw_circle(mc, MASSIF_R * k, C_ROCK)
	for i in range(1, 5):
		draw_arc(mc, MASSIF_R * k * (1.0 - float(i) * 0.19), 0.0, TAU, 40, C_ROCK.darkened(0.25), 1.2)
	_tri(mc, 7.0, C_INK)
	_label(f_lab, mc + Vector2(0, MASSIF_R * k + 16), "Berg", 14, true)

	# See
	if LakeShape.points.is_empty():
		LakeShape.build()
	var poly := PackedVector2Array()
	for p in LakeShape.points:
		poly.append(_w2m(p.x + LAKE_OFF.x, p.y + LAKE_OFF.y))
	draw_colored_polygon(poly, C_WATER)
	var ring := poly.duplicate()
	ring.append(poly[0])
	draw_polyline(ring, C_WATER_EDGE, 2.0, true)
	var lc := _w2m(LakeShape.CENTER.x + LAKE_OFF.x, LakeShape.CENTER.y + LAKE_OFF.y)
	_label(f_head, lc + Vector2(0, 6), "See", 20, false, C_WATER_EDGE.darkened(0.3))

	# Parkplatz und Bestenliste
	var pk1 := _w2m(-11.0, -3.0)
	var pk2 := _w2m(11.0, 5.0)
	draw_rect(Rect2(pk1, pk2 - pk1), Color(0.55, 0.55, 0.55))
	draw_rect(Rect2(pk1, pk2 - pk1), C_INK, false, 1.2)
	_label(f_lab, Vector2((pk1.x + pk2.x) / 2.0, pk2.y + 15), "Parkplatz", 13, true)

	# Lager, Zelte, Feuer
	if Game.camp_claimed:
		var cc := _wv(Game.camp_center)
		draw_arc(cc, Game.camp_radius * k, 0.0, TAU, 48, Color(UI.FIRE, 0.9), 2.0)
		_label(f_lab, cc + Vector2(0, -Game.camp_radius * k - 6), "Lager" + (" · " + Game.camp_name if Game.camp_name != "" and Game.camp_name != "Lager" else ""), 14, true)
	for t in Game.tents:
		if is_instance_valid(t):
			_tent(_wv((t as Node3D).global_position))
	for p in Game.placed:
		if is_instance_valid(p) and p.item_name == "Feuerschale" and p.burning:
			var fp := _wv(p.global_position)
			var fl := 4.0 + sin(_t * 9.0) * 1.0
			draw_circle(fp, fl + 2.0, Color(1.0, 0.5, 0.1, 0.35))
			draw_circle(fp, fl, Color(1.0, 0.6, 0.15))

	# Gefundene Verstecke
	var found := 0
	for s in Stash.all:
		if is_instance_valid(s) and (s as Stash).opened:
			found += 1
			var sp := _wv((s as Node3D).global_position)
			draw_rect(Rect2(sp - Vector2(6, 5), Vector2(12, 10)), Color(0.55, 0.36, 0.18))
			draw_rect(Rect2(sp - Vector2(6, 5), Vector2(12, 10)), C_INK, false, 1.2)
			draw_line(sp + Vector2(-3, 0), sp + Vector2(-1, 2), Color(0.9, 1.0, 0.6), 2.0)
			draw_line(sp + Vector2(-1, 2), sp + Vector2(4, -3), Color(0.9, 1.0, 0.6), 2.0)
			_label(f_lab, sp + Vector2(0, 19), (s as Stash).label, 12, true)

	# Mitspieler
	if Net.instance != null and is_instance_valid(Net.instance):
		for key in Net.instance.avatars.keys():
			var av: Node3D = Net.instance.avatars[key]
			if not is_instance_valid(av):
				continue
			var cn: String = String(av.get("char_name"))
			var col: Color = UI.CHAR_COLORS.get(cn, Color(0.9, 0.9, 0.9))
			var ap := _wv(av.global_position)
			draw_circle(ap, 7.0, C_INK)
			draw_circle(ap, 5.5, col)
			var lbl: Label3D = av.get("label")
			var nm: String = lbl.text if lbl != null else cn
			_label(f_lab, ap + Vector2(0, -11), nm, 13, true)

	# Ich selbst: Pfeil in Blickrichtung, pulsierend
	var me := get_tree().get_first_node_in_group("local_player") as Node3D
	if me != null:
		var mp := _wv(me.global_position)
		var yaw := me.rotation.y
		var fwd := Vector2(-sin(yaw), -cos(yaw))          # -Z ist vorn, auf der Karte oben
		var side := Vector2(-fwd.y, fwd.x)
		var col2: Color = UI.CHAR_COLORS.get(String(me.get("character_name")), UI.FIRE)
		draw_circle(mp, 13.0 + sin(_t * 4.0) * 2.0, Color(col2, 0.25))
		var pts := PackedVector2Array([mp + fwd * 12.0, mp - fwd * 7.0 + side * 8.0, mp - fwd * 3.0, mp - fwd * 7.0 - side * 8.0])
		draw_colored_polygon(pts, col2)
		var outline := pts.duplicate()
		outline.append(pts[0])
		draw_polyline(outline, C_INK, 1.6, true)
		_label(f_lab, mp + Vector2(0, 26), "Du", 13, true)

	# Nordpfeil und Maßstab
	var np := Vector2(_rect.end.x - 26, _rect.position.y + 34)
	draw_colored_polygon(PackedVector2Array([np + Vector2(0, -18), np + Vector2(8, 6), np + Vector2(0, 1), np + Vector2(-8, 6)]), C_INK)
	_label(f_head, np + Vector2(0, -22), "N", 15, false)
	var sb := Vector2(_rect.position.x + 18, _rect.end.y - 18)
	draw_line(sb, sb + Vector2(50.0 * k, 0), C_INK, 3.0)
	draw_line(sb + Vector2(0, -5), sb + Vector2(0, 5), C_INK, 2.0)
	draw_line(sb + Vector2(50.0 * k, -5), sb + Vector2(50.0 * k, 5), C_INK, 2.0)
	draw_string(f_lab, sb + Vector2(50.0 * k + 8, 5), "50 m", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, C_INK)

	# Legende unten
	var total := Stash.all.size()
	var leg := "Verstecke gefunden: %d/%d" % [found, total]
	if Net.instance != null and is_instance_valid(Net.instance):
		leg += "   ·   Mitspieler: %d" % Net.instance.avatars.size()
	draw_string(f_lab, Vector2(frame.position.x, frame.end.y + 26), leg, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, C_PAPER)


func _label(font: Font, pos: Vector2, text: String, fsize: int, outlined: bool, col: Color = C_INK) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
	var p := pos - Vector2(w / 2.0, 0)
	if outlined:
		draw_string_outline(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, 4, Color(C_PAPER, 0.9))
	draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, col)


func _tri(c: Vector2, r: float, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, r * 0.8), c + Vector2(-r, r * 0.8)]), col)


func _tent(c: Vector2) -> void:
	var pts := PackedVector2Array([c + Vector2(0, -7), c + Vector2(7, 5), c + Vector2(-7, 5)])
	draw_colored_polygon(pts, Color(0.95, 0.5, 0.15))
	var o := pts.duplicate()
	o.append(pts[0])
	draw_polyline(o, C_INK, 1.4, true)
