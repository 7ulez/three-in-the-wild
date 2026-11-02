class_name Bunker
extends Node3D
## Geheimer Bunker im Nordosten: verfallene Betonhütte mit Code-Tür, Schacht mit Leiter nach unten
## in die Katakomben. Der 5-stellige Code steckt in den 5 Verstecken (je Versteck eine Ziffer).
## Die Hütte steht achsenparallel; die Tür zeigt nach Süden (+Z), zum Lager hin.

const POS: Vector3 = Vector3(65.0, 0.0, -100.0)       # Mitte der Hütte
const SHAFT: Vector3 = Vector3(65.0, 0.0, -101.0)     # Mitte des Schachts
const SHAFT_HALF: float = 0.7
const CODE: Array = [3, 7, 1, 9, 4]                   # Ziffer des Verstecks 0..4
const WALL_C: Color = Color(0.40, 0.40, 0.37)
const CATA: int = Catacombs.CATA_LAYER

const EXIT: Vector3 = Vector3(Catacombs.EXIT_X, 0.0, Catacombs.EXIT_Z)      # zweiter Schacht in der Tropfsteinhöhle
const EXIT_OUT: Vector3 = Vector3(95.8, 0.05, 56.1)                           # hier steigt man in der Höhle aus dem Loch

static var open: bool = false
static var exit_open: bool = false       # Bodenluke in der Tropfsteinhöhle offen?
static var instance: Bunker = null
static var pad: Node = null              # Zahlenfeld, an dem gerade der Code getippt wird
static var typed: String = ""

var main: Node
var cata: Catacombs
var lurker: Lurker = null
var _exit_root: Node3D
var lid: StaticBody3D
var lid_col: CollisionShape3D
var door: StaticBody3D
var door_col: CollisionShape3D
var led: MeshInstance3D
var _under_t: float = 0.0
var _cull_t: float = 0.0
var _lur_msg_t: float = 0.0


## Quadratisches Loch im Boden (Weltkoordinaten x, z, Breite, Tiefe)
static func hole_rect() -> Rect2:
	return Rect2(Vector2(SHAFT.x - SHAFT_HALF, SHAFT.z - SHAFT_HALF), Vector2(SHAFT_HALF * 2.0, SHAFT_HALF * 2.0))


static func holes() -> Array:
	return [hole_rect(), Rect2(Vector2(EXIT.x - SHAFT_HALF, EXIT.z - SHAFT_HALF), Vector2(SHAFT_HALF * 2.0, SHAFT_HALF * 2.0))]


static func in_zone(p: Vector3) -> bool:
	return Vector2(p.x - POS.x, p.z - POS.z).length() < 9.0


## 0 = Bunker-Schacht, 1 = Schacht in der Tropfsteinhöhle, -1 = an keiner Leiter
static func ladder_id(p: Vector3) -> int:
	if p.y < Catacombs.FLOOR_Y - 0.1 or p.y > 0.7:
		return -1
	if absf(p.x - SHAFT.x) < 0.5 and absf(p.z - SHAFT.z) < 0.5:
		return 0
	if absf(p.x - EXIT.x) < 0.5 and absf(p.z - EXIT.z) < 0.5:
		return 1
	return -1


static func on_ladder(p: Vector3) -> bool:
	return ladder_id(p) >= 0


## Beim Hochklettern: gibt die Ausstiegsposition zurück, sobald man oben ist (sonst Vector3.INF).
## Die Bodenluke der Höhle öffnet sich, wenn man von unten dagegen klettert.
static func ladder_climb(p: Vector3) -> Vector3:
	var id := ladder_id(p)
	if id == 1 and not exit_open and p.y > -2.6:
		set_exit_open(true)
	if p.y > -0.05 and (id == 0 or (id == 1 and exit_open)):
		return exit_pos() if id == 0 else EXIT_OUT
	return Vector3.INF


## Ist die Position in den Katakomben (Grundriss unter dem Labyrinth, nicht tiefer als der Boden)?
static func in_underground(p: Vector3) -> bool:
	if instance == null or not is_instance_valid(instance) or instance.cata == null:
		return false
	if p.y <= Catacombs.FLOOR_Y - 2.0:
		return false
	for r in instance.cata.under_rects:
		if (r as Rect2).has_point(Vector2(p.x, p.z)):
			return true
	return false


## Wohin man oben aus dem Schacht steigt (in der Hütte, Richtung Tür)
static func exit_pos() -> Vector3:
	return Vector3(SHAFT.x, 0.05, SHAFT.z + 1.6)


## Welche Ziffern kennt man (aus gefundenen Verstecken)? z. B. "3 _ _ 9 _"
static func known_digits() -> String:
	var parts: Array = []
	for i in range(CODE.size()):
		parts.append(str(CODE[i]) if Game.stashes_opened.has(i) else "_")
	return " ".join(parts)


static func set_open(v: bool, send: bool = true) -> void:
	if open == v:
		return
	open = v
	if instance != null and is_instance_valid(instance):
		instance._apply_door(true)
	if send and v and Net.instance != null and is_instance_valid(Net.instance):
		Net.instance.send_bunker_open()


static func set_exit_open(v: bool, send: bool = true) -> void:
	if exit_open == v:
		return
	exit_open = v
	if instance != null and is_instance_valid(instance):
		instance._apply_exit(true)
	if send and v and Net.instance != null and is_instance_valid(Net.instance):
		Net.instance.send_exit_open()


## Wesen, das ich gerade sehe (selbst simuliert oder Puppe vom Verantwortlichen)
static func active_lurker() -> Lurker:
	if instance == null or not is_instance_valid(instance):
		return null
	var l: Lurker = instance.lurker
	if l != null and is_instance_valid(l) and not l.is_queued_for_deletion():
		return l
	return null


## Spieler, die unten in den Katakomben sind: [{"p": Vector3, "lamp": bool}]
static func underground_targets() -> Array:
	var out: Array = []
	if instance == null or not is_instance_valid(instance) or instance.main == null:
		return out
	var pl: Node3D = instance.main.get("player")
	if pl != null and pl.global_position.y < -10.0 and instance.cata.cell_of(pl.global_position) >= 0:
		var lamp: bool = pl.get("lamp") != null and (pl.get("lamp") as Light3D).visible
		out.append({"p": pl.global_position, "lamp": lamp})
	if Net.instance != null and is_instance_valid(Net.instance):
		for k in Net.instance.avatars.keys():
			var av: Node3D = Net.instance.avatars[k]
			if is_instance_valid(av) and av.global_position.y < -10.0 and instance.cata.cell_of(av.global_position) >= 0:
				out.append({"p": av.global_position, "lamp": false})
	return out


## Puppe des Wesens bei Mitspielern (vom Netz aufgerufen)
static func net_lurker(on: bool, pos: Vector3, yaw: float, anim: String) -> void:
	if instance == null or not is_instance_valid(instance):
		return
	instance._net_lurker(on, pos, yaw, anim)


func _net_lurker(on: bool, pos: Vector3, yaw: float, anim: String) -> void:
	if not on:
		if lurker != null and is_instance_valid(lurker) and lurker.puppet:
			lurker.queue_free()
		lurker = null
		return
	if lurker == null or not is_instance_valid(lurker):
		lurker = Lurker.new()
		lurker.puppet = true
		cata.add_child(lurker)
		lurker.setup(cata)
		lurker.global_position = pos
	lurker.net_pos = pos
	lurker.net_yaw = yaw
	lurker.net_anim = anim


func _is_authority() -> bool:
	return Net.instance == null or not is_instance_valid(Net.instance) or Net.instance.is_world_authority()


# ---------- Aufbau ----------

func build(p_main: Node) -> void:
	main = p_main
	instance = self
	cata = Catacombs.new()
	cata.name = "Catacombs"
	add_child(cata)
	cata.build(Vector3(SHAFT.x, Catacombs.FLOOR_Y, SHAFT.z))
	main.cave_boxes.append(cata.aabb)
	# Schacht und Hütteninnenraum sind "Höhle": dunkel, kein Wetter
	main.cave_boxes.append(AABB(Vector3(SHAFT.x - 0.8, Catacombs.CEIL_Y, SHAFT.z - 0.8), Vector3(1.6, -Catacombs.CEIL_Y + 1.0, 1.6)))
	main.cave_boxes.append(AABB(Vector3(POS.x - 2.7, 0.0, POS.z - 2.3), Vector3(5.4, 2.7, 4.6)))
	for ab in cata.extra_aabbs:
		main.cave_boxes.append(ab)
	main.cave_boxes.append(AABB(Vector3(EXIT.x - 0.8, Catacombs.CEIL_Y, EXIT.z - 0.8), Vector3(1.6, -Catacombs.CEIL_Y + 1.0, 1.6)))
	_build_hut()
	_build_hut_details()
	_build_shaft(SHAFT, false, self)
	_build_exit()
	_apply_door(false)
	_apply_exit(false)
	_exit_sign(Vector3(SHAFT.x, Catacombs.FLOOR_Y + 2.9, SHAFT.z + 0.9), 0.0, self)
	_exit_sign(Vector3(EXIT.x, Catacombs.FLOOR_Y + 2.9, EXIT.z - 0.9), PI, _exit_root)


func _solid(size: Vector3, pos: Vector3, col: Color, layers: int = 1, parent: Node = null) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.position = pos
	(parent if parent != null else self).add_child(b)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	b.add_child(cs)
	var mi := Util.add_box(b, size, col)
	mi.layers = layers
	return b


func _build_hut() -> void:
	var x := POS.x
	var z := POS.z
	_solid(Vector3(6.0, 2.8, 0.4), Vector3(x, 1.4, z - 2.3), WALL_C)                  # Rückwand
	_solid(Vector3(0.4, 2.8, 5.0), Vector3(x - 2.8, 1.4, z), WALL_C.darkened(0.05))   # links
	_solid(Vector3(0.4, 2.8, 5.0), Vector3(x + 2.8, 1.4, z), WALL_C.darkened(0.05))   # rechts
	_solid(Vector3(2.3, 2.8, 0.4), Vector3(x - 1.85, 1.4, z + 2.3), WALL_C)           # vorn links
	_solid(Vector3(2.3, 2.8, 0.4), Vector3(x + 1.85, 1.4, z + 2.3), WALL_C)           # vorn rechts
	_solid(Vector3(1.4, 0.6, 0.4), Vector3(x, 2.5, z + 2.3), WALL_C.darkened(0.1))    # Sturz über der Tür
	_solid(Vector3(6.4, 0.4, 5.4), Vector3(x, 3.0, z), WALL_C.darkened(0.12))         # Dach
	Util.add_box(self, Vector3(6.0, 0.5, 5.0), Color(0.22, 0.31, 0.15), Vector3(x, 3.45, z))   # Moos und Erde
	Util.add_box(self, Vector3(1.6, 0.3, 1.2), Color(0.25, 0.33, 0.17), Vector3(x - 1.2, 3.85, z - 0.8))
	var vent := Util.add_cylinder(self, 0.18, 1.0, Color(0.3, 0.22, 0.18), Vector3(x + 1.7, 3.95, z + 0.9))   # Lüftungsrohr
	vent.rotation_degrees.z = 8.0
	# Tür (schiebt sich nach rechts) und Zahlenfeld links daneben
	door = StaticBody3D.new()
	door.position = Vector3(x, 1.1, z + 2.5)
	add_child(door)
	door_col = CollisionShape3D.new()
	var dbs := BoxShape3D.new()
	dbs.size = Vector3(1.4, 2.2, 0.2)
	door_col.shape = dbs
	door.add_child(door_col)
	Util.add_box(door, Vector3(1.4, 2.2, 0.16), Color(0.33, 0.2, 0.13))
	Util.add_box(door, Vector3(1.2, 0.12, 0.2), Color(0.2, 0.2, 0.2), Vector3(0, 0.3, 0))
	var pad_body := Pad.new()
	pad_body.position = Vector3(x - 1.2, 1.2, z + 2.55)
	add_child(pad_body)
	var pcs := CollisionShape3D.new()
	var pbs := BoxShape3D.new()
	pbs.size = Vector3(0.4, 0.5, 0.2)
	pcs.shape = pbs
	pad_body.add_child(pcs)
	Util.add_box(pad_body, Vector3(0.3, 0.42, 0.1), Color(0.12, 0.12, 0.14))
	for r in range(4):
		for c in range(3):
			Util.add_box(pad_body, Vector3(0.06, 0.04, 0.02), Color(0.6, 0.6, 0.55), Vector3(-0.08 + c * 0.08, -0.12 + r * 0.06, 0.055))
	led = Util.add_box(pad_body, Vector3(0.07, 0.04, 0.02), Color(0.9, 0.1, 0.05), Vector3(0, 0.17, 0.055))
	var lm := led.material_override as StandardMaterial3D
	lm.emission_enabled = true
	lm.emission = Color(0.9, 0.1, 0.05)
	lm.emission_energy_multiplier = 1.5
	# Schriftzug über der Tür, schon halb verwittert
	var sign_l := Label3D.new()
	sign_l.text = "SCHUTZRAUM 3"
	sign_l.font_size = 40
	sign_l.pixel_size = 0.0035
	sign_l.modulate = Color(0.75, 0.7, 0.45, 0.8)
	sign_l.outline_size = 0
	sign_l.position = Vector3(x, 2.5, z + 2.52)
	add_child(sign_l)
	# Innen: Notlicht, Pritsche, Kiste (dunkel, Sonne und Mond erreichen den Raum nicht)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.45, 0.25)
	lamp.light_energy = 0.7
	lamp.omni_range = 5.5
	lamp.shadow_enabled = false
	lamp.position = Vector3(x + 1.6, 2.4, z - 0.6)
	add_child(lamp)
	Util.add_box(self, Vector3(0.18, 0.1, 0.18), Color(0.9, 0.3, 0.15), Vector3(x + 1.6, 2.7, z - 0.6)).layers = CATA
	_solid(Vector3(0.9, 0.45, 2.0), Vector3(x - 2.1, 0.22, z - 0.9), Color(0.25, 0.3, 0.22), CATA)
	_solid(Vector3(0.7, 0.6, 0.6), Vector3(x + 2.2, 0.3, z + 1.3), Color(0.3, 0.22, 0.14), CATA)


## Schachtwände von der Decke der Katakomben bis zum Boden, dazu die Leiter (ein Mesh)
func _build_shaft(sp: Vector3, ladder_south: bool, parent: Node) -> void:
	var y1 := Catacombs.CEIL_Y
	var h := -y1
	var cy := y1 / 2.0
	var hs := SHAFT_HALF
	var col := Color(0.26, 0.26, 0.25)
	_solid(Vector3(hs * 2.0, h, 0.1), Vector3(sp.x, cy, sp.z - hs + 0.05), col, CATA, parent)
	_solid(Vector3(hs * 2.0, h, 0.1), Vector3(sp.x, cy, sp.z + hs - 0.05), col, CATA, parent)
	_solid(Vector3(0.1, h, hs * 2.0), Vector3(sp.x - hs + 0.05, cy, sp.z), col, CATA, parent)
	_solid(Vector3(0.1, h, hs * 2.0), Vector3(sp.x + hs - 0.05, cy, sp.z), col, CATA, parent)
	_shaft_details(sp, ladder_south, parent)
	# Leiter: zwei Holme und Sprossen als ein einziges Mesh, von der Hub-Sohle bis kurz über den Boden
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	var lz := sp.z + hs - 0.16 if ladder_south else sp.z - hs + 0.16
	var y0 := Catacombs.FLOOR_Y
	var top := -0.12 if ladder_south else 1.1      # in der Höhle endet die Leiter unter der Luke
	cata._box(st, Vector3(sp.x - 0.42, (y0 + top) / 2.0, lz), Vector3(0.06, top - y0, 0.06), Color(0.4, 0.28, 0.16), 0.0, rng)
	cata._box(st, Vector3(sp.x + 0.42, (y0 + top) / 2.0, lz), Vector3(0.06, top - y0, 0.06), Color(0.4, 0.28, 0.16), 0.0, rng)
	var y := y0 + 0.3
	while y < top:
		cata._box(st, Vector3(sp.x, y, lz), Vector3(0.84, 0.04, 0.04), Color(0.45, 0.32, 0.18), 0.0, rng)
		y += 0.35
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	mi.material_override = mat
	mi.layers = CATA
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


## Zweiter Ausgang: Schacht mit Leiter im Boden der Tropfsteinhöhle, oben unter einer Holzluke
func _build_exit() -> void:
	_exit_root = Node3D.new()
	_exit_root.name = "ExitRoot"
	add_child(_exit_root)
	_build_shaft(EXIT, true, _exit_root)
	Util.add_box(_exit_root, Vector3(1.4, 0.01, 1.4), Color(0.015, 0.015, 0.015), Vector3(EXIT.x, 0.067, EXIT.z))     # schwarzes Loch
	var l := Lid.new()
	l.position = Vector3(EXIT.x, 0.1, EXIT.z - 0.75)        # Scharnier am Nordrand
	_exit_root.add_child(l)
	lid = l
	lid_col = CollisionShape3D.new()
	var lbs := BoxShape3D.new()
	lbs.size = Vector3(1.5, 0.14, 1.5)
	lid_col.shape = lbs
	lid_col.position = Vector3(0, -0.02, 0.75)
	l.add_child(lid_col)
	var wood := Color(0.34, 0.22, 0.12)
	Util.add_box(l, Vector3(1.5, 0.07, 1.5), wood, Vector3(0, -0.03, 0.75))
	for bz in [0.35, 1.15]:
		Util.add_box(l, Vector3(1.5, 0.03, 0.1), wood.darkened(0.3), Vector3(0, 0.02, bz))
	Util.add_box(l, Vector3(0.18, 0.04, 0.05), Color(0.35, 0.3, 0.25), Vector3(0, 0.03, 1.25))      # Griff


class Lid extends StaticBody3D:
	func get_prompt() -> String:
		if Bunker.exit_open:
			return ""
		return "E: Bodenluke öffnen"

	func interact(_player: Node) -> void:
		Bunker.set_exit_open(true)


func _apply_exit(animate: bool) -> void:
	if lid == null:
		return
	var rot := -105.0 if exit_open else 0.0
	if animate:
		create_tween().tween_property(lid, "rotation_degrees:x", rot, 0.9).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		Sfx.play("trunk_close", lid.global_position, 0.0, 0.7)
	else:
		lid.rotation_degrees.x = rot
	lid_col.set_deferred("disabled", exit_open)


func _apply_door(animate: bool) -> void:
	if door == null:
		return
	var tx: float = POS.x + (1.6 if open else 0.0)
	if animate:
		create_tween().tween_property(door, "position:x", tx, 1.4).set_trans(Tween.TRANS_SINE)
		Sfx.play("chest_open", door.global_position, 2.0, 0.6)
	else:
		door.position.x = tx
	door_col.set_deferred("disabled", open)
	if led != null:
		var lm := led.material_override as StandardMaterial3D
		var c := Color(0.1, 0.9, 0.2) if open else Color(0.9, 0.1, 0.05)
		lm.albedo_color = c
		lm.emission = c


# ---------- Zahlenfeld ----------

class Pad extends StaticBody3D:
	func get_prompt() -> String:
		if Bunker.open:
			return "Bunker-Tür: offen"
		if Bunker.pad == self:
			var shown := ""
			for i in range(5):
				shown += (Bunker.typed[i] if i < Bunker.typed.length() else "_") + " "
			return "Code: %s  (Ziffern tippen, Rücktaste löscht, Esc/E bricht ab)\nBekannte Ziffern der Verstecke: %s" % [shown.strip_edges(), Bunker.known_digits()]
		return "E: Zahlenfeld benutzen (5-stelliger Code)"

	func interact(player: Node) -> void:
		if Bunker.open:
			return
		if Bunker.pad == self:
			Bunker.pad = null
			Bunker.typed = ""
			return
		Bunker.pad = self
		Bunker.typed = ""
		player.toast("Zahlenfeld: 5 Ziffern tippen. Jedes der 5 Verstecke trägt eine Ziffer.", 5.0)


## Taste fürs Zahlenfeld: true = verbraucht
static func pad_key(key: InputEventKey, player: Node) -> bool:
	if pad == null:
		return false
	var d := -1
	if key.keycode >= KEY_0 and key.keycode <= KEY_9:
		d = key.keycode - KEY_0
	elif key.keycode >= KEY_KP_0 and key.keycode <= KEY_KP_9:
		d = key.keycode - KEY_KP_0
	if d >= 0:
		typed += str(d)
		if typed.length() >= 5:
			var ok := true
			for i in range(5):
				if int(typed[i]) != int(CODE[i]):
					ok = false
			typed = ""
			pad = null
			if ok:
				player.toast("Klack ... das Schloss springt auf.", 4.0)
				set_open(true)
			else:
				Sfx.play("click", Vector3.INF, 0.0, 0.5)
				player.toast("Falscher Code. Das Feld piept.", 3.0)
		else:
			Sfx.play("click", Vector3.INF, -6.0, 1.3)
		return true
	if key.keycode == KEY_BACKSPACE:
		typed = typed.left(maxi(typed.length() - 1, 0))
		return true
	if key.keycode == KEY_ESCAPE or key.keycode == KEY_E:
		pad = null
		typed = ""
		return key.keycode == KEY_E
	return false


# ---------- laufende Logik ----------

func _process(delta: float) -> void:
	var pl: Node3D = main.get("player") if main != null else null
	if pl == null:
		return
	if pad != null and (not is_instance_valid(pad) or (pad as Node3D).global_position.distance_to(pl.global_position) > 4.0):
		pad = null
		typed = ""
	_cull_t -= delta
	if _cull_t <= 0.0:
		_cull_t = 0.4
		# Katakomben nur zeichnen, wenn man (fast) unten ist; die Hütte nur in der Nähe
		cata.visible = pl.global_position.y < -6.0
		for c in get_children():
			if c != cata and c is Node3D:
				var cc: Vector3 = EXIT if c == _exit_root else POS
				(c as Node3D).visible = pl.global_position.distance_to(cc) < 80.0
	_lurker_logic(delta)


## Der Welt-Verantwortliche lässt das Wesen erscheinen, solange jemand unten ist.
func _lurker_logic(delta: float) -> void:
	if not _is_authority():
		return
	var targets := underground_targets()
	if lurker != null and (not is_instance_valid(lurker) or lurker.puppet):
		lurker = null
	if targets.is_empty():
		_under_t += delta
		if lurker != null and _under_t > 5.0:
			lurker.queue_free()
			lurker = null
		return
	_under_t = 0.0
	if lurker == null:
		lurker = Lurker.new()
		cata.add_child(lurker)
		lurker.setup(cata)
		lurker.place_far_from(targets[0]["p"])


# ---------- Verschönerung: Eingang, Innenraum, Schacht ----------

var _vcmat: StandardMaterial3D = null


## Viele Boxen als ein einziges Mesh (Vertexfarben): parts = [[Mitte, Grösse, Farbe, Streuung]]
func _merged(parts: Array, parent: Node, layers: int = 1) -> MeshInstance3D:
	if _vcmat == null:
		_vcmat = StandardMaterial3D.new()
		_vcmat.vertex_color_use_as_albedo = true
		_vcmat.roughness = 1.0
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for p in parts:
		cata._box(st, p[0], p[1], p[2], p[3] if p.size() > 3 else 0.0, rng)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _vcmat
	mi.layers = layers
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _emissive(col: Color, energy: float = 2.5) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = energy
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


func _build_hut_details() -> void:
	var x := POS.x
	var z := POS.z
	var green := Color(0.2, 0.33, 0.14)
	var concrete := Color(0.45, 0.44, 0.40)
	# --- außen: Vorplatz, Moos, Efeu (alles ein Mesh)
	var ext: Array = [
		[Vector3(x, 0.03, z + 3.8), Vector3(3.4, 0.06, 2.6), concrete, 0.08],
		[Vector3(x - 1.8, 0.2, z + 2.46), Vector3(1.4, 0.4, 0.05), green, 0.15],
		[Vector3(x + 1.9, 0.15, z + 2.46), Vector3(1.1, 0.3, 0.05), green, 0.15],
		[Vector3(x - 3.03, 0.25, z + 0.5), Vector3(0.05, 0.5, 1.8), green, 0.15],
		[Vector3(x + 3.03, 0.3, z - 0.5), Vector3(0.05, 0.6, 2.2), green, 0.15],
		[Vector3(x - 1.0, 0.3, z - 2.53), Vector3(2.4, 0.6, 0.05), green, 0.15],
	]
	for vx in [2.0, 2.25, 2.5, 2.9, -2.0, -2.3, -2.6]:
		var vl := 1.1 + fmod(absf(vx) * 7.3, 1.0)
		ext.append([Vector3(x + vx, 2.8 - vl / 2.0, z + 2.47), Vector3(0.05, vl, 0.02), green.darkened(0.15 + fmod(absf(vx), 0.3)), 0.2])
	_merged(ext, self, 1)
	# Flügelwände links und rechts vom Vorplatz (mit Moos oben)
	for sx in [-1.0, 1.0]:
		_solid(Vector3(0.35, 1.3, 1.8), Vector3(x + sx * 1.9, 0.65, z + 3.4), concrete.darkened(0.08))
		Util.add_box(self, Vector3(0.42, 0.09, 1.86), green, Vector3(x + sx * 1.9, 1.33, z + 3.4))
	# Tür: Warnstreifen, Handrad und Nummer
	for k in range(6):
		Util.add_box(door, Vector3(0.12, 0.2, 0.02), Color(0.92, 0.75, 0.1) if k % 2 == 0 else Color(0.08, 0.08, 0.08), Vector3(-0.55 + k * 0.22, -0.9, 0.085))
	var wheel := Util.add_cylinder(door, 0.17, 0.04, Color(0.18, 0.18, 0.18), Vector3(0, 0.05, 0.1))
	wheel.rotation_degrees.x = 90.0
	Util.add_box(door, Vector3(0.36, 0.04, 0.03), Color(0.18, 0.18, 0.18), Vector3(0, 0.05, 0.12))
	Util.add_box(door, Vector3(0.04, 0.36, 0.03), Color(0.18, 0.18, 0.18), Vector3(0, 0.05, 0.12))
	# Käfiglampe neben der Tür (leuchtet nur schwach)
	var lamp := Util.add_box(self, Vector3(0.22, 0.14, 0.14), Color(1.0, 0.7, 0.3), Vector3(x + 1.9, 2.5, z + 2.58))
	lamp.material_override = _emissive(Color(1.0, 0.68, 0.28), 2.0)
	for bx in [-0.09, 0.0, 0.09]:
		Util.add_box(self, Vector3(0.015, 0.17, 0.17), Color(0.12, 0.12, 0.12), Vector3(x + 1.9 + bx, 2.5, z + 2.58))
	# --- innen (Ebene der Katakomben: Sonne und Mond erreichen den Raum nicht)
	var slab := Color(0.33, 0.33, 0.31)
	var yel := Color(0.9, 0.72, 0.08)
	var steel := Color(0.3, 0.3, 0.28)
	var inner: Array = [
		# Betonboden mit Loch für den Schacht
		[Vector3(x - 1.75, 0.03, z), Vector3(2.1, 0.06, 4.6), slab, 0.06],
		[Vector3(x + 1.75, 0.03, z), Vector3(2.1, 0.06, 4.6), slab, 0.06],
		[Vector3(x, 0.03, z - 2.0), Vector3(1.4, 0.06, 0.6), slab, 0.06],
		[Vector3(x, 0.03, z + 1.0), Vector3(1.4, 0.06, 2.6), slab, 0.06],
		# gelber Rahmen um das Loch, schwarz-gelbe Warnmarkierung
		[Vector3(x, 0.066, SHAFT.z - 0.76), Vector3(1.64, 0.012, 0.12), yel],
		[Vector3(x, 0.066, SHAFT.z + 0.76), Vector3(1.64, 0.012, 0.12), yel],
		[Vector3(x - 0.76, 0.066, SHAFT.z), Vector3(0.12, 0.012, 1.4), yel],
		[Vector3(x + 0.76, 0.066, SHAFT.z), Vector3(0.12, 0.012, 1.4), yel],
		# Rohre, Kabel und Sicherungskasten an der Rückwand
		[Vector3(x, 2.35, z - 2.06), Vector3(5.0, 0.08, 0.08), Color(0.36, 0.26, 0.18)],
		[Vector3(x, 2.1, z - 2.06), Vector3(5.0, 0.06, 0.06), Color(0.25, 0.27, 0.3)],
		[Vector3(x + 1.9, 1.2, z - 2.06), Vector3(0.08, 2.5, 0.08), Color(0.36, 0.26, 0.18)],
		[Vector3(x - 2.0, 1.5, z - 2.08), Vector3(0.5, 0.7, 0.12), Color(0.4, 0.4, 0.38)],
		[Vector3(x - 2.0, 1.78, z - 2.0), Vector3(0.07, 0.07, 0.03), Color(0.8, 0.15, 0.1)],
		[Vector3(x - 2.0, 2.15, z - 2.06), Vector3(0.03, 0.8, 0.03), Color(0.05, 0.05, 0.05)],
	]
	for k in range(5):      # schwarze Streifen der Warnmarkierung
		inner.append([Vector3(x - 0.6 + k * 0.3, 0.07, SHAFT.z - 0.76), Vector3(0.07, 0.014, 0.12), Color(0.06, 0.06, 0.06)])
		inner.append([Vector3(x - 0.6 + k * 0.3, 0.07, SHAFT.z + 0.76), Vector3(0.07, 0.014, 0.12), Color(0.06, 0.06, 0.06)])
	# Geländer um das Loch (Süden offen): Pfosten und zwei Stangen
	for px in [-0.9, 0.9]:
		for pz in [-1.0, 0.8]:
			inner.append([Vector3(x + px, 0.5, SHAFT.z + pz), Vector3(0.05, 1.0, 0.05), yel.darkened(0.1)])
	for ry in [1.0, 0.55]:
		inner.append([Vector3(x - 0.9, ry, SHAFT.z - 0.1), Vector3(0.04, 0.04, 1.8), yel.darkened(0.1)])
		inner.append([Vector3(x + 0.9, ry, SHAFT.z - 0.1), Vector3(0.04, 0.04, 1.8), yel.darkened(0.1)])
		inner.append([Vector3(x, ry, SHAFT.z - 1.0), Vector3(1.8, 0.04, 0.04), yel.darkened(0.1)])
	_merged(inner, self, CATA)
	for rs in [[Vector3(-0.9, 0.5, -0.1), Vector3(0.08, 1.0, 1.8)], [Vector3(0.9, 0.5, -0.1), Vector3(0.08, 1.0, 1.8)], [Vector3(0.0, 0.5, -1.0), Vector3(1.8, 1.0, 0.08)]]:
		var rb := StaticBody3D.new()
		rb.position = Vector3(x + rs[0].x, rs[0].y, SHAFT.z + rs[0].z)
		var rc := CollisionShape3D.new()
		var rbx := BoxShape3D.new()
		rbx.size = rs[1]
		rc.shape = rbx
		rb.add_child(rc)
		add_child(rb)


## Betonringe, Tiefenschilder und kleine Lampen im Schacht
func _shaft_details(sp: Vector3, ladder_south: bool, parent: Node) -> void:
	var hs := SHAFT_HALF
	var y1 := Catacombs.CEIL_Y
	var band := Color(0.19, 0.19, 0.18)
	var parts: Array = []
	var yy := -4.0
	while yy > y1 + 1.0:
		parts.append([Vector3(sp.x - hs + 0.12, yy, sp.z), Vector3(0.04, 0.26, 1.2), band, 0.1])
		parts.append([Vector3(sp.x + hs - 0.12, yy, sp.z), Vector3(0.04, 0.26, 1.2), band, 0.1])
		var fz: float = (sp.z - hs + 0.12) if ladder_south else (sp.z + hs - 0.12)       # Wand gegenüber der Leiter
		parts.append([Vector3(sp.x, yy, fz), Vector3(1.2, 0.26, 0.04), band, 0.1])
		yy -= 4.0
	_merged(parts, parent, CATA)
	# Tiefenschilder an der Wand gegenüber der Leiter
	for d in [6, 12, 18, 24]:
		var lb := Label3D.new()
		lb.text = "- %d m" % d
		lb.font_size = 40
		lb.pixel_size = 0.0035
		lb.modulate = Color(0.85, 0.8, 0.45, 0.85)
		lb.outline_size = 0
		lb.layers = CATA
		if ladder_south:
			lb.position = Vector3(sp.x, -float(d), sp.z - hs + 0.115)
		else:
			lb.position = Vector3(sp.x, -float(d), sp.z + hs - 0.115)
			lb.rotation.y = PI
		parent.add_child(lb)
	# Kleine Wandlampen (nur leuchtende Boxen, ein MultiMesh)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var bm := BoxMesh.new()
	bm.size = Vector3(0.09, 0.14, 0.09)
	mm.mesh = bm
	var lamps: Array = [-3.0, -9.0, -15.0, -21.0]
	mm.instance_count = lamps.size()
	for i in range(lamps.size()):
		mm.set_instance_transform(i, Transform3D(Basis(), Vector3(sp.x - hs + 0.16, lamps[i], sp.z + 0.2)))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _emissive(Color(1.0, 0.62, 0.2), 2.5)
	mmi.layers = CATA
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mmi)


## Grünes "AUSGANG"-Schild über dem Leiterkäfig im Hub / im Raum unter der Höhle
func _exit_sign(pos: Vector3, yaw: float, parent: Node) -> void:
	var lb := Label3D.new()
	lb.text = "AUSGANG"
	lb.font_size = 44
	lb.pixel_size = 0.0045
	lb.modulate = Color(0.35, 1.0, 0.45)
	lb.outline_size = 0
	lb.layers = CATA
	lb.position = pos
	lb.rotation.y = yaw
	parent.add_child(lb)
	var bar := Util.add_box(parent, Vector3(0.85, 0.02, 0.02), Color(0.3, 1.0, 0.4), pos + Vector3(0, -0.14, 0))
	bar.material_override = _emissive(Color(0.3, 1.0, 0.4), 2.0)
	bar.layers = CATA
