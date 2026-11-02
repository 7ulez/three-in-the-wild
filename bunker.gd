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

static var open: bool = false
static var instance: Bunker = null
static var pad: Node = null              # Zahlenfeld, an dem gerade der Code getippt wird
static var typed: String = ""

var main: Node
var cata: Catacombs
var lurker: Lurker = null
var door: StaticBody3D
var door_col: CollisionShape3D
var led: MeshInstance3D
var _under_t: float = 0.0
var _cull_t: float = 0.0
var _lur_msg_t: float = 0.0


## Quadratisches Loch im Boden (Weltkoordinaten x, z, Breite, Tiefe)
static func hole_rect() -> Rect2:
	return Rect2(Vector2(SHAFT.x - SHAFT_HALF, SHAFT.z - SHAFT_HALF), Vector2(SHAFT_HALF * 2.0, SHAFT_HALF * 2.0))


static func in_zone(p: Vector3) -> bool:
	return Vector2(p.x - POS.x, p.z - POS.z).length() < 9.0


static func on_ladder(p: Vector3) -> bool:
	return absf(p.x - SHAFT.x) < 0.5 and absf(p.z - SHAFT.z) < 0.5 and p.y > Catacombs.FLOOR_Y - 0.1 and p.y < 0.7


## Ist die Position in den Katakomben (Grundriss unter dem Labyrinth, nicht tiefer als der Boden)?
static func in_underground(p: Vector3) -> bool:
	if instance == null or not is_instance_valid(instance) or instance.cata == null:
		return false
	var a: AABB = instance.cata.aabb
	return p.y > Catacombs.FLOOR_Y - 2.0 and p.x > a.position.x and p.x < a.end.x and p.z > a.position.z and p.z < a.end.z


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
	if pl != null and pl.global_position.y < -10.0:
		var lamp: bool = pl.get("lamp") != null and (pl.get("lamp") as Light3D).visible
		out.append({"p": pl.global_position, "lamp": lamp})
	if Net.instance != null and is_instance_valid(Net.instance):
		for k in Net.instance.avatars.keys():
			var av: Node3D = Net.instance.avatars[k]
			if is_instance_valid(av) and av.global_position.y < -10.0:
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
	_build_hut()
	_build_shaft()
	_apply_door(false)


func _solid(size: Vector3, pos: Vector3, col: Color, layers: int = 1) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.position = pos
	add_child(b)
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


func _build_shaft() -> void:
	var y1 := Catacombs.CEIL_Y
	var h := -y1
	var cy := y1 / 2.0
	var hs := SHAFT_HALF
	var col := Color(0.26, 0.26, 0.25)
	_solid(Vector3(hs * 2.0, h, 0.1), Vector3(SHAFT.x, cy, SHAFT.z - hs + 0.05), col, CATA)
	_solid(Vector3(hs * 2.0, h, 0.1), Vector3(SHAFT.x, cy, SHAFT.z + hs - 0.05), col, CATA)
	_solid(Vector3(0.1, h, hs * 2.0), Vector3(SHAFT.x - hs + 0.05, cy, SHAFT.z), col, CATA)
	_solid(Vector3(0.1, h, hs * 2.0), Vector3(SHAFT.x + hs - 0.05, cy, SHAFT.z), col, CATA)
	# Leiter: zwei Holme und Sprossen als ein einziges Mesh, von der Hub-Sohle bis kurz über den Boden
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	var lz := SHAFT.z - hs + 0.16
	var y0 := Catacombs.FLOOR_Y
	var top := 0.9
	cata._box(st, Vector3(SHAFT.x - 0.42, (y0 + top) / 2.0, lz), Vector3(0.06, top - y0, 0.06), Color(0.4, 0.28, 0.16), 0.0, rng)
	cata._box(st, Vector3(SHAFT.x + 0.42, (y0 + top) / 2.0, lz), Vector3(0.06, top - y0, 0.06), Color(0.4, 0.28, 0.16), 0.0, rng)
	var y := y0 + 0.3
	while y < top:
		cata._box(st, Vector3(SHAFT.x, y, lz), Vector3(0.84, 0.04, 0.04), Color(0.45, 0.32, 0.18), 0.0, rng)
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
	add_child(mi)


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
				(c as Node3D).visible = pl.global_position.distance_to(POS) < 80.0
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
