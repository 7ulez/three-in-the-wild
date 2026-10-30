class_name Stash
extends StaticBody3D
## Ein Versteck mit Beute (Kiste, Baumhöhle, ...). Jedes Versteck zählt für das Ziel "Verstecke finden".

## Inhalt der 5 Verstecke (Reihenfolge = Reihenfolge, in der sie gebaut werden).
## Das letzte Versteck enthält drei einzelne Dosen Jack Daniel's Cola (eine Dose = sehr betrunken).
const LOOT: Array = ["Bierkiste", "Joint", "Luftgewehr", "Notration", "Jack-Cola"]
static var count: int = 0
static var all: Array = []

var index: int = 0
var opened: bool = false
var label: String = "Versteck"
var lid: Node3D = null


func build(p_label: String, as_chest: bool = true) -> void:
	label = p_label
	index = count
	count += 1
	all.append(self)
	collision_layer = 1
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.8, 0.5, 0.5)
	cs.shape = bs
	cs.position.y = 0.25
	add_child(cs)
	if as_chest:
		var body_ok := ItemModels._glb(self, "truhe_korpus") != null
		lid = Node3D.new()
		lid.position = Vector3(0, 0.32, 0.25)      # Scharnier hinten oben
		add_child(lid)
		if body_ok and ItemModels._glb(lid, "truhe_deckel") != null:
			pass
		else:
			Util.add_box(self, Vector3(0.8, 0.35, 0.5), Color(0.5, 0.33, 0.16), Vector3(0, 0.18, 0))
			Util.add_box(lid, Vector3(0.82, 0.14, 0.52), Color(0.42, 0.27, 0.12), Vector3(0, 0.07, -0.25))
			Util.add_box(self, Vector3(0.1, 0.12, 0.04), Color(0.85, 0.7, 0.2), Vector3(0, 0.3, -0.26))
	else:
		Util.add_box(self, Vector3(0.7, 0.4, 0.4), Color(0.28, 0.22, 0.14), Vector3(0, 0.2, 0))


static func found() -> int:
	var n := 0
	for s in all:
		if is_instance_valid(s) and (s as Stash).opened:
			n += 1
	return n


static func reset() -> void:
	count = 0
	all.clear()


func get_prompt() -> String:
	if opened:
		return "%s - schon geplündert" % label
	return "E: %s durchsuchen" % label


## Ein Mitspieler hat das Versteck geoeffnet (Inhalt kommt als Gegenstand ueber das Netz).
func open_remote() -> void:
	if opened:
		return
	opened = true
	if lid != null:
		create_tween().tween_property(lid, "rotation_degrees:x", 112.0, 0.85).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sfx.play("chest_open", global_position, -3.0)


func interact(player: Node) -> void:
	if opened:
		return
	opened = true
	if Net.instance != null:
		Net.instance.send_stash(index)
	if lid != null:
		var tw := create_tween()
		tw.tween_property(lid, "rotation_degrees:x", 112.0, 0.85).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sfx.play("chest_open", global_position, 0.0)
	var n := player.get_node_or_null("Needs") as Needs
	var found_n := found()
	var kind: String = LOOT[index % LOOT.size()]
	var msg := ""
	match kind:
		"Bierkiste":
			_spawn_item(player, "Bierkasten", 14.0, Vector3(0.5, 0.3, 0.35), Color(0.9, 0.75, 0.2))
			msg = "Eine volle Kiste Bier! Nimm sie mit (E)."
		"Joint":
			_spawn_item(player, "Joint", 0.05, Vector3(0.12, 0.02, 0.02), Color(0.92, 0.9, 0.8))
			msg = "Ein selbstgedrehter Joint. Aufheben (E), dann F zum Rauchen."
		"Luftgewehr":
			_spawn_item(player, "Luftgewehr", 2.5, Vector3(0.12, 0.16, 0.95), Color(0.3, 0.3, 0.33))
			msg = "Ein Luftgewehr! Aufheben (E), mit Linksklick schießen."
		"Notration":
			if n != null:
				n.eat(0.5)
			msg = "Eine Notration Dosenbrot und Würstchen! Hunger gestillt."
		"Jack-Cola":
			for k in range(3):
				_spawn_item(player, "Jack-Cola-Dose", 0.35, Vector3(0.07, 0.12, 0.07), Color(0.12, 0.1, 0.09), Vector3((k - 1) * 0.32, 0.0, 0.0))
			msg = "Drei Dosen Jack Daniel's Cola. Vorsicht: eine reicht für den ganzen Abend."
		"Verbandskasten":
			if n != null:
				n.health = minf(n.health + 60.0, 100.0)
			msg = "Ein Verbandskasten. Du fühlst dich gleich besser."
		"Goldköder":
			Game.lure_until = Game.now() + 600.0
			msg = "Ein goldener Spinner! Die Fische beißen die nächsten Minuten schneller."
		"Alte Karte":
			msg = "Eine zerknitterte Karte. " + _hint(player)
		"Bier-Vorrat":
			player.promille += 0.3
			if n != null:
				n.drank_beer()
			msg = "Zwei vergessene Dosen Bier. Eine trinkst du sofort. Prost!"
	player.toast("%s: %s  (Verstecke %d/%d)" % [label, msg, found_n + 1 if found_n < all.size() else found_n, all.size()], 7.0)


## Der Inhalt liegt als echter Gegenstand auf der Kiste und fällt von dort herunter.
func _spawn_item(player: Node, item_name: String, weight: float, size: Vector3, color: Color, offset: Vector3 = Vector3.ZERO) -> void:
	var it := Item.new().setup(item_name, weight, size, color)
	player.get_parent().add_child(it)
	it.global_position = global_position + (Vector3(0, 0.75, -0.5) + offset).rotated(Vector3.UP, global_rotation.y)
	it.linear_velocity = Vector3(0, 1.5, 0)


func _hint(player: Node) -> String:
	var best: Stash = null
	var bd := 1e9
	for s in all:
		var st := s as Stash
		if is_instance_valid(st) and not st.opened and st != self:
			var d := st.global_position.distance_to(player.global_position)
			if d < bd:
				bd = d
				best = st
	if best == null:
		return "Es sind alle Verstecke gefunden."
	var v: Vector3 = best.global_position - player.global_position
	var dirs := ["Osten", "Süden", "Westen", "Norden"]
	var a := atan2(v.z, v.x)           # +x = Osten, +z = Süden
	var name: String = dirs[int(round(a / (PI / 2.0))) % 4]
	return "Das nächste Versteck liegt ca. %d m Richtung %s (%s)." % [int(bd), name, best.label]
