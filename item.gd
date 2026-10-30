class_name Item
extends RigidBody3D
## Ein Gegenstand, den man aufheben, tragen und im Lager aufstellen kann.

var item_name: String = "Ding"
var weight: float = 5.0
var hold_extra: float = 0.0
var item_size: Vector3 = Vector3.ONE
var item_color: Color = Color.WHITE
var bottle_nodes: Array = []   # nur beim Bierkasten: die sichtbaren Flaschen
var water_left: int = 10       # nur beim Wasserflasche: Schlucke
var label: Label3D
var extra: Dictionary = {}     # Zusatzzustand (Rucksack-Inhalt, Holzvorrat)


var _lbl_t: float = 0.0
var _pl: Node3D = null

# ---- Netzwerk: Gegenstaende gibt es nur einmal fuer alle Spieler ----
static var registry: Dictionary = {}      # net_id -> Item
var net_id: int = 0
var net_announced: bool = false           # den anderen Spielern schon gemeldet?
var remote_created: bool = false          # entstand durch eine Meldung eines Mitspielers
var net_silent: bool = false              # beim Entfernen keine Meldung senden
var remote: bool = false                  # wird bei einem Mitspieler simuliert (hier nur eingefroren, folgt dem Netz)
var net_attached: bool = false            # haengt gerade am Avatar eines Mitspielers
var _net_t: float = 0.0
var _rest_sent: bool = false
var _last_sent_pos: Vector3 = Vector3(1e9, 0, 0)
var _tgt_pos: Vector3 = Vector3.ZERO
var _tgt_q: Quaternion = Quaternion.IDENTITY
var _has_tgt: bool = false


func _ready() -> void:
	if net_id == 0 and Net.instance != null and is_instance_valid(Net.instance):
		net_id = Net.instance.alloc_item_id()
	if net_id != 0:
		registry[net_id] = self
		if not net_announced:
			_announce.call_deferred()


func _announce() -> void:
	if is_queued_for_deletion() or not is_inside_tree():
		return
	if Net.instance != null and is_instance_valid(Net.instance):
		Net.instance.item_announce(self)


func _enter_tree() -> void:
	# Auch nach dem Umhaengen (z.B. an den Avatar eines Mitspielers) wieder eintragen
	if net_id != 0:
		registry[net_id] = self


static func find(id: int) -> Item:
	var it = registry.get(id)
	if it != null and is_instance_valid(it) and not (it as Item).is_queued_for_deletion():
		return it
	return null


func _exit_tree() -> void:
	# Nur echtes Entfernen (queue_free) melden, nicht Umhaengen oder das Abraeumen beim Verlassen der Szene
	if net_id != 0 and is_queued_for_deletion():
		if registry.get(net_id) == self:
			registry.erase(net_id)
		if not net_silent and Net.instance != null and is_instance_valid(Net.instance) and Net.instance.is_inside_tree():
			Net.instance.item_gone(net_id)


## Mitspieler simuliert diesen Gegenstand: hier nur eingefroren und dem Netz folgend.
func make_remote() -> void:
	remote = true
	net_attached = false
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	freeze = true
	collision_layer = 1
	collision_mask = 1
	visible = true


## Ein Mitspieler traegt den Gegenstand: haengt vor dem Avatar.
func attach_to(node: Node3D) -> void:
	make_remote()
	net_attached = true
	collision_layer = 0
	collision_mask = 0
	if get_parent() != node:
		if get_parent() != null:
			get_parent().remove_child(self)
		node.add_child(self)
	position = Vector3(0, 1.05, -0.9)
	rotation = Vector3.ZERO


## Mitspieler hat den Gegenstand abgelegt.
func detach_to(world: Node, pos: Vector3, q: Quaternion) -> void:
	if get_parent() != world:
		if get_parent() != null:
			get_parent().remove_child(self)
		world.add_child(self)
	make_remote()
	global_position = pos
	global_transform.basis = Basis(q)
	_tgt_pos = pos
	_tgt_q = q
	_has_tgt = true


## Ich nehme einen (eingefrorenen) Gegenstand auf: ab jetzt simuliere ich ihn selbst.
func take_local() -> void:
	remote = false
	net_attached = false
	_has_tgt = false
	_rest_sent = false
	freeze = false
	collision_layer = 1
	collision_mask = 1
	sleeping = false


func net_state_changed() -> void:
	if net_id != 0 and Net.instance != null and is_instance_valid(Net.instance):
		Net.instance.item_state(self)


func apply_net_state(x: Dictionary, beers: int, water: int) -> void:
	extra = x.duplicate(true)
	if extra.has("owner") and label != null and label.text != display_name():
		label.text = display_name()
	if item_name == "Bierkasten" and beers >= 0:
		while beers_left() > beers:
			take_bottle()
	if item_name == "Wasserflasche" and water >= 0:
		water_left = water


func _process(delta: float) -> void:
	# Mitspieler traegt den Gegenstand: er liegt in der Hand (Griffhand des Mitspielers) und folgt ihr
	if net_attached and get_parent() != null and get_parent().has_meta("hand"):
		var h: Variant = get_parent().get_meta("hand")
		if h is Node3D and is_instance_valid(h):
			if item_size.x > item_size.z * 2.0:
				# lange Sachen (Rute, Gewehr): zeigen in Blickrichtung des Mitspielers, Rolle (-Y) zeigt immer nach unten
				var fwd: Vector3 = -(get_parent() as Node3D).global_transform.basis.z
				fwd.y = 0.0
				if fwd.length() < 0.01:
					fwd = Vector3.FORWARD
				var bx := fwd.normalized()
				var by := Vector3.UP
				var bz := bx.cross(by).normalized()
				global_transform = Transform3D(Basis(bx, by, bz), (h as Node3D).global_position)
			else:
				global_transform = (h as Node3D).global_transform
	if label == null:
		return
	_lbl_t -= delta
	if _lbl_t > 0.0:
		return
	_lbl_t = 0.15
	if _pl == null or not is_instance_valid(_pl):
		_pl = get_tree().get_first_node_in_group("local_player") as Node3D
		if _pl == null:
			label.visible = false
			return
	label.visible = global_position.distance_to(_pl.global_position) < 4.2
	if label.visible and (item_name == "Luftgewehr" or item_name == "Joint" or item_name == "Radio" or item_name == "Angelrute") and _pl.get("held") == self:
		label.visible = false     # in der Hand stört das Schild im Bild


var _sunk: bool = false


func _physics_process(delta: float) -> void:
	_net_physics(delta)
	# Steine, die im See landen: Platsch und weg
	if _sunk or item_name != "Flacher Stein":
		return
	var main := get_parent()
	if main == null or main.get("lake_root") == null:
		return
	var pl := get_tree().get_first_node_in_group("local_player")
	if pl != null and pl.get("held") == self:
		return
	var lp: Vector3 = global_position - (main.lake_root as Node3D).global_position
	if global_position.y < 0.35 and LakeShape.contains(Vector2(lp.x, lp.z)):
		_sunk = true
		Sfx.play("splash_small", global_position)
		visible = false
		await get_tree().create_timer(0.3).timeout
		queue_free()


func _net_physics(delta: float) -> void:
	if net_id == 0 or Net.instance == null or not is_instance_valid(Net.instance):
		return
	if remote:
		if _has_tgt and not net_attached:
			global_position = global_position.lerp(_tgt_pos, minf(delta * 14.0, 1.0))
			var cur := global_transform.basis.get_rotation_quaternion()
			global_transform.basis = Basis(cur.slerp(_tgt_q, minf(delta * 14.0, 1.0)))
		return
	if not net_announced:
		return
	if _pl == null or not is_instance_valid(_pl):
		_pl = get_tree().get_first_node_in_group("local_player") as Node3D
	if _pl != null and _pl.get("held") == self:
		return
	if sleeping:
		if not _rest_sent:
			_rest_sent = true
			Net.instance.item_rest(self)
		return
	_rest_sent = false
	_net_t += delta
	if _net_t >= 0.1:
		_net_t = 0.0
		if global_position.distance_to(_last_sent_pos) > 0.02:
			_last_sent_pos = global_position
			Net.instance.item_pos(self)


func setup(p_name: String, p_weight: float, size: Vector3, color: Color) -> Item:
	item_name = p_name
	weight = p_weight
	mass = p_weight
	item_size = size
	item_color = color
	linear_damp = 0.4
	angular_damp = 1.5

	var shape := BoxShape3D.new()
	shape.size = size
	if p_name == "Jack-Cola-Dose":
		shape.size = size.max(Vector3(0.18, 0.18, 0.18))     # Dose ist winzig: grosszuegig zielbar
	var col := CollisionShape3D.new()
	col.shape = shape
	add_child(col)

	var model := ItemModels.add_visual(self, p_name, size, color)
	if model.has("bottles"):
		bottle_nodes = model["bottles"]
	if p_name == "Bierkasten" and is_gift_color(color):
		_add_gift_bow(size)

	label = Label3D.new()
	label.text = p_name
	label.font_size = 48
	label.pixel_size = 0.004
	label.outline_size = 10
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0, size.y / 2.0 + 0.45, 0)
	add_child(label)

	if p_name == "Bierkasten" and is_gift_color(color):
		label.text = "Geschenk-Bierkasten"
	hold_extra = size.z * 0.5
	if p_name == "Radio":
		add_to_group("radio_item")
	if p_name == "Jack-Cola-Kiste":
		water_left = 3
		label.text = "Jack Daniel's Cola (3 Dosen)"
	if p_name == "Jack-Cola-Dose":
		water_left = 1
		label.text = "Jack-Cola"
	return self


## Der Finale-Bierkasten hat eine ganz leicht andere Farbe (bei Mitspielern kommt nur die Farbe an).
static func is_gift_color(c: Color) -> bool:
	return absf(c.r - 0.9) < 0.01 and absf(c.g - 0.75) < 0.01 and absf(c.b - 0.21) < 0.004


## Rote Geschenkschleife um die Flaschenhaelse.
func _add_gift_bow(size: Vector3) -> void:
	var red := Color(0.85, 0.1, 0.12)
	var y := size.y / 2.0 + 0.05
	var hx := size.x / 2.0 + 0.012
	var hz := size.z / 2.0 + 0.012
	Util.add_box(self, Vector3(size.x + 0.03, 0.04, 0.014), red, Vector3(0, y, hz))
	Util.add_box(self, Vector3(size.x + 0.03, 0.04, 0.014), red, Vector3(0, y, -hz))
	Util.add_box(self, Vector3(0.014, 0.04, size.z + 0.03), red, Vector3(hx, y, 0))
	Util.add_box(self, Vector3(0.014, 0.04, size.z + 0.03), red, Vector3(-hx, y, 0))
	# Schleife vorne: zwei Schlaufen, Knoten, zwei Enden
	var loop_l := Util.add_box(self, Vector3(0.13, 0.07, 0.02), red, Vector3(-0.07, y + 0.02, hz + 0.02))
	loop_l.rotation_degrees.z = 28.0
	var loop_r := Util.add_box(self, Vector3(0.13, 0.07, 0.02), red, Vector3(0.07, y + 0.02, hz + 0.02))
	loop_r.rotation_degrees.z = -28.0
	Util.add_box(self, Vector3(0.05, 0.05, 0.03), Color(0.65, 0.05, 0.08), Vector3(0, y, hz + 0.025))
	var tail_l := Util.add_box(self, Vector3(0.035, 0.12, 0.012), red, Vector3(-0.035, y - 0.08, hz + 0.02))
	tail_l.rotation_degrees.z = 15.0
	var tail_r := Util.add_box(self, Vector3(0.035, 0.12, 0.012), red, Vector3(0.035, y - 0.08, hz + 0.02))
	tail_r.rotation_degrees.z = -15.0


## Beim Bierkasten: wie viele Flaschen sind noch drin?
func beers_left() -> int:
	return bottle_nodes.size()


## Nimmt eine Flasche aus dem Kasten. false, wenn er leer ist.
func take_bottle() -> bool:
	if bottle_nodes.is_empty():
		return false
	var bottle: Node = bottle_nodes.pop_back()
	bottle.queue_free()
	return true


## "beer", "water" oder "" (kann man nicht trinken)
func drink_kind() -> String:
	if item_name == "Bierkasten":
		return "beer"
	if item_name == "Wasserflasche":
		return "water"
	if item_name == "Jack-Cola-Kiste" or item_name == "Jack-Cola-Dose":
		return "jack"
	return ""


func drinks_left() -> int:
	if item_name == "Bierkasten":
		return beers_left()
	return water_left


func take_drink() -> bool:
	if item_name == "Bierkasten":
		var ok := take_bottle()
		if ok:
			net_state_changed()
		return ok
	if item_name == "Wasserflasche" or item_name == "Jack-Cola-Kiste" or item_name == "Jack-Cola-Dose":
		if water_left <= 0:
			return false
		water_left -= 1
		net_state_changed()
		return true
	return false


func display_name() -> String:
	if extra.has("owner"):
		return "%s (von %s)" % [item_name, extra["owner"]]
	return item_name


func set_owner_name(owner: String) -> void:
	extra["owner"] = owner
	if label != null:
		label.text = display_name()


func get_prompt() -> String:
	if item_name == "Bierkasten":
		if beers_left() > 0:
			return "E: Bierkasten aufheben (%d kg)   F: Bier trinken (%d übrig)" % [int(weight), beers_left()]
		return "E: leeren Bierkasten aufheben (%d kg)" % int(weight)
	if item_name == "Wasserflasche":
		return "E: Wasserflasche aufheben (%d kg)   F: Wasser trinken (%d Schluck)" % [int(weight), water_left]
	if item_name == "Jack-Cola-Kiste":
		return "E: Kiste aufheben (%d kg)   F: Dose trinken (%d übrig)" % [int(weight), water_left]
	if item_name == "Jack-Cola-Dose":
		return "E: Dose Jack Daniel's Cola aufheben   F: trinken"
	if item_name == "Radio":
		return "E: Radio aufheben   F: an/aus   Z: Sender  +/- Lautstärke  [%s]" % (Radio.station_name() if Radio.on else "aus")
	return "E: %s aufheben (%d kg)" % [display_name(), int(weight)]


func interact(player: Node) -> void:
	player.pick_up(self)
