class_name Stash
extends StaticBody3D
## Ein Versteck mit Beute (Kiste, Baumhöhle, ...). Jedes Versteck zählt für das Ziel "Verstecke finden".

const LOOT: Array = ["Notration", "Verbandskasten", "Goldköder", "Alte Karte", "Bier-Vorrat"]
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
		Util.add_box(self, Vector3(0.8, 0.35, 0.5), Color(0.5, 0.33, 0.16), Vector3(0, 0.18, 0))
		lid = Node3D.new()
		lid.position = Vector3(0, 0.36, 0.25)
		add_child(lid)
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


func interact(player: Node) -> void:
	if opened:
		return
	opened = true
	if lid != null:
		create_tween().tween_property(lid, "rotation_degrees:x", -105.0, 0.5)
	Sfx.play("thunk", global_position, -4.0)
	var n := player.get_node_or_null("Needs") as Needs
	var found_n := found()
	var kind: String = LOOT[index % LOOT.size()]
	var msg := ""
	match kind:
		"Notration":
			if n != null:
				n.eat(0.5)
			msg = "Eine Notration Dosenbrot und Würstchen! Hunger gestillt."
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
