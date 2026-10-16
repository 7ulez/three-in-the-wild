class_name Game
extends RefCounted
## Gemeinsamer Spielzustand (im Multiplayer wird das Wichtigste per RPC synchronisiert).

static var camp_claimed: bool = false
static var camp_name: String = ""
static var camp_center: Vector3 = Vector3.ZERO
static var camp_radius: float = 9.5
static var tents: Array = []
static var placed: Array = []   # alle aufgestellten Gegenstände (PlacedItem)

# Tageszeit in Stunden (0..24)
static var hour: float = 15.5
static var day_count: int = 1
const HOURS_PER_REAL_MINUTE: float = 1.4

# Fänge, Schatz, Strafen
static var catches: Array = []          # {"name","kg","cm"}
static var fish_penalty_until: float = 0.0
static var lure_until: float = 0.0
static var treasure_found: bool = false
static var fire_lit_once: bool = false
static var chili_served: int = 0
static var cars_opened: int = 0
static var slept: bool = false
static var summit: bool = false
static var all_done_shown: bool = false

# Tablet/Handy: Bildschirm-Steuerung statt Maus und Tastatur
static var touch: bool = false
static var low: bool = false          # leichtere Grafik (Tablets/Handys): keine Schatten, weniger Deko, 720p-Rendering


## Schaltet die leichte Grafikstufe ein/aus (Auflösung, Schatten, Glühen).
static func apply_quality(win: Window) -> void:
	if low:
		win.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
		win.content_scale_size = Vector2i(1280, 720)
		win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	else:
		win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		win.content_scale_size = Vector2i(1280, 720)
		win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
static var touch_reel: bool = false   # "Aktion"-Knopf wird gehalten (Angel einholen)


static func is_captured() -> bool:
	return touch or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED


# Startoptionen (aus dem Menü)
static var start_char: String = "Marian"
static var player_name: String = "Spieler"
static var net_mode: String = "solo"    # "solo", "host", "join"
static var host_ip: String = "127.0.0.1"
static var port: int = 24680
static var password: String = ""
static var login_error: String = ""    # Meldung fürs Menü nach abgelehntem Login
static var dedicated: bool = false     # Server ohne Fenster/Spieler (Docker)
static var ws_url: String = ""         # vom Server vorgegebene WebSocket-Adresse (Browser)

# Rezept Chili con Carne (Reihenfolge!)
const RECIPE: Array = ["Zwiebeln", "Hackfleisch", "Knoblauch", "Tomatenmark", "Gehackte Tomaten",
	"Kidneybohnen", "Mais", "Paprika", "Gewürze"]

const INGREDIENT_COLORS: Dictionary = {
	"Zwiebeln": Color(0.92, 0.8, 0.55), "Hackfleisch": Color(0.72, 0.3, 0.3),
	"Knoblauch": Color(0.96, 0.95, 0.85), "Tomatenmark": Color(0.78, 0.15, 0.1),
	"Gehackte Tomaten": Color(0.88, 0.22, 0.15), "Kidneybohnen": Color(0.5, 0.1, 0.1),
	"Mais": Color(0.95, 0.8, 0.2), "Paprika": Color(0.2, 0.7, 0.2), "Gewürze": Color(0.85, 0.5, 0.12),
}


## Das Lager entsteht dort, wo das erste Zelt aufgestellt wird.
static func claim_camp(center: Vector3, parent: Node) -> void:
	if camp_claimed:
		return
	camp_claimed = true
	camp_name = "Lager"
	camp_center = Vector3(center.x, 0, center.z)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = camp_radius - 0.12
	tm.outer_radius = camp_radius
	tm.rings = 48
	tm.ring_segments = 8
	ring.mesh = tm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.45, 1.0, 0.55)
	ring.material_override = m
	parent.add_child(ring)
	ring.global_position = Vector3(camp_center.x, 0.05, camp_center.z)


static func now() -> float:
	return Time.get_ticks_msec() / 1000.0


static func is_night() -> bool:
	return hour >= 20.0 or hour < 5.5


static func clock_text() -> String:
	var h := int(hour) % 24
	var m := int((hour - floorf(hour)) * 60.0)
	return "%02d:%02d" % [h, m]


static func reset() -> void:
	camp_claimed = false
	camp_name = ""
	tents.clear()
	placed.clear()
	hour = 15.5
	day_count = 1
	Weather.reset()
	catches.clear()
	fish_penalty_until = 0.0
	treasure_found = false
	lure_until = 0.0
	Stash.reset()
	fire_lit_once = false
	chili_served = 0
	cars_opened = 0
	slept = false
	summit = false
	all_done_shown = false


static func has_catch(species: String) -> bool:
	for c in catches:
		if c["name"] == species:
			return true
	return false


## Alle Ziele als [Text, erledigt]
static func goals() -> Array:
	var tent_done := false
	for t in tents:
		if is_instance_valid(t) and t.finished:
			tent_done = true
	return [
		["3 Autos ausladen (%d/3)" % cars_opened, cars_opened >= 3],
		["Lager aufschlagen (Zelt irgendwo hinstellen)", camp_claimed],
		["Zelt aufbauen (Hammer + 4 Heringe)", tent_done],
		["Feuer mit dem Feuerstahl machen", fire_lit_once],
		["Einen Karpfen fangen", has_catch("Karpfen")],
		["Einen Hecht fangen", has_catch("Hecht")],
		["Chili con Carne kochen und essen", chili_served > 0],
		["Im Zelt schlafen", slept],
		["Aussichtspunkt erklimmen", summit],
		["Schatz in der Höhle finden", treasure_found],
		["Verstecke rund um den See finden (%d/5)" % Stash.found(), Stash.found() >= 5],
	]


static var _touch_re: RegEx = null

## Tablet/Handy: Tastennamen in Texten durch die Namen der Bildschirm-Knöpfe ersetzen.
static func touchify(text: String) -> String:
	if not touch or text == "":
		return text
	var t := text
	for pair in [["Linksklick", "AKTION-Knopf"], ["Rechtsklick", "SCHNUR-EIN-Knopf"], ["Maustaste", "AKTION-Knopf"], ["Mausklick", "AKTION-Knopf"],
			["Klick,", "AKTION,"], ["KLICK", "AKTION"], ["A / D: gegenhalten", "Gegenhalten klappt automatisch"], ["A / D", "automatisch"],
			["Esc", "Menü"]]:
		t = t.replace(pair[0], pair[1])
	if _touch_re == null:
		_touch_re = RegEx.create_from_string("(?<![A-Za-zÄÖÜäöü0-9])([EXRZFGTQHLCV])(?![A-Za-zÄÖÜäöü0-9])")
	var names := {"E": "BENUTZEN", "X": "ABBAUEN", "R": "AUFSTELLEN", "Z": "ZUTAT", "F": "TRINKEN", "G": "WERFEN", "T": "ANGELART", "Q": "VAPE", "H": "GESCHÄFT", "L": "LAMPE", "C": "DUCKEN", "V": "ANSICHT"}
	var out := ""
	var last := 0
	for m in _touch_re.search_all(t):
		out += t.substr(last, m.get_start() - last) + names[m.get_string(1)]
		last = m.get_end()
	out += t.substr(last)
	return out
