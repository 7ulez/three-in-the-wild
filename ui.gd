class_name UI
extends RefCounted
## Gemeinsames Sticker-Design (Papier-Panels, Tinte, Schatten). Farben/Maße aus dem Design-System.

const PAPER := Color("f4efe4")
const INK := Color("1d1f1a")
const FOREST := Color("15201b")
const SHADOW := Color("0a0f0c")
const FIRE := Color("e29a4d")
const DANGER := Color("d9533f")
const WATER := Color("8fc3dc")
const TEXT_LOW := Color("5d6159")
const CHAR_COLORS := {"Marian": Color("4aa35a"), "Steffen": Color("d9534f"), "Julian": Color("4a86d8"), "Gast": Color("e8c547")}

static var _theme: Theme = null
static var f_head: FontFile = null
static var f_label: FontFile = null
static var f_mono: FontFile = null


static func fonts() -> void:
	if f_head != null:
		return
	f_head = load("res://assets/fonts/bricolage-grotesque-latin-800-normal.woff2")
	f_label = load("res://assets/fonts/bricolage-grotesque-latin-600-normal.woff2")
	f_mono = load("res://assets/fonts/space-mono-latin-700-normal.woff2")


## Sticker: Fläche, 2px Tintenrand, harter Schatten rechts unten.
static func sticker(bg: Color = PAPER, radius: int = 14, shadow: float = 4.0, pad: Vector4 = Vector4(14, 10, 14, 10)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = INK
	s.set_border_width_all(2)
	s.set_corner_radius_all(radius)
	s.shadow_color = SHADOW
	s.shadow_size = 0
	s.shadow_offset = Vector2(shadow, shadow)
	if shadow > 0.0:
		s.shadow_size = 1
	s.content_margin_left = pad.x
	s.content_margin_top = pad.y
	s.content_margin_right = pad.z
	s.content_margin_bottom = pad.w
	return s


static func _button_set(th: Theme, type: String, bg: Color, fg: Color) -> void:
	th.set_stylebox("normal", type, sticker(bg, 12, 4.0, Vector4(16, 8, 16, 8)))
	th.set_stylebox("hover", type, sticker(bg.lightened(0.06), 12, 6.0, Vector4(16, 8, 16, 8)))
	th.set_stylebox("pressed", type, sticker(bg.darkened(0.06), 12, 1.0, Vector4(16, 8, 16, 8)))
	th.set_stylebox("focus", type, sticker(bg, 12, 4.0, Vector4(16, 8, 16, 8)))
	th.set_stylebox("disabled", type, sticker(bg.darkened(0.25), 12, 0.0, Vector4(16, 8, 16, 8)))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		th.set_color(c, type, fg)
	th.set_color("font_disabled_color", type, fg.lerp(PAPER, 0.5))


static func theme() -> Theme:
	if _theme != null:
		return _theme
	fonts()
	var th := Theme.new()
	th.default_font = f_label
	th.default_font_size = 17
	th.set_font("font", "Button", f_head)
	th.set_font_size("font_size", "Button", 17)
	th.set_color("font_color", "Label", INK)
	th.set_font("font", "Label", f_label)
	th.set_font("font", "LineEdit", f_label)
	th.set_font_size("font_size", "LineEdit", 18)
	th.set_color("font_color", "LineEdit", INK)
	th.set_color("font_placeholder_color", "LineEdit", Color(INK, 0.4))
	th.set_color("caret_color", "LineEdit", FIRE)
	th.set_color("selection_color", "LineEdit", Color(FIRE, 0.45))
	var fld := sticker(Color("fffdf7"), 10, 0.0, Vector4(14, 8, 14, 8))
	var fld_f := sticker(Color("fffdf7"), 10, 0.0, Vector4(14, 8, 14, 8))
	fld_f.border_color = FIRE
	fld_f.set_border_width_all(3)
	th.set_stylebox("normal", "LineEdit", fld)
	th.set_stylebox("focus", "LineEdit", fld_f)
	th.set_stylebox("read_only", "LineEdit", fld)
	_button_set(th, "Button", PAPER, INK)
	th.set_stylebox("normal", "FlatButton", StyleBoxEmpty.new())
	th.set_stylebox("panel", "PanelContainer", sticker(PAPER, 18, 4.0, Vector4(22, 18, 22, 18)))
	# Balken
	var bg := sticker(PAPER, 8, 0.0, Vector4(0, 0, 0, 0))
	var fill := sticker(FIRE, 6, 0.0, Vector4(0, 0, 0, 0))
	fill.set_border_width_all(0)
	th.set_stylebox("background", "ProgressBar", bg)
	th.set_stylebox("fill", "ProgressBar", fill)
	_theme = th
	return th


static func primary_button(b: Button) -> void:
	var th := Theme.new()
	_button_set(th, "Button", FIRE, INK)
	for n in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(n, th.get_stylebox(n, "Button"))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		b.add_theme_color_override(c, th.get_color(c, "Button"))


## Meldung / HUD-Label als Pille mit Tintenrand.
static func pill(bg: Color = FOREST, fg: Color = PAPER) -> StyleBoxFlat:
	var s := sticker(bg, 14, 3.0, Vector4(12, 5, 12, 5))
	s.border_color = SHADOW if bg != FOREST else Color(PAPER, 0.35)
	return s
