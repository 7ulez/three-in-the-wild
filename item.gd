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


func _process(delta: float) -> void:
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


var _sunk: bool = false


func _physics_process(_delta: float) -> void:
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
	var col := CollisionShape3D.new()
	col.shape = shape
	add_child(col)

	var model := ItemModels.add_visual(self, p_name, size, color)
	if model.has("bottles"):
		bottle_nodes = model["bottles"]

	label = Label3D.new()
	label.text = p_name
	label.font_size = 48
	label.pixel_size = 0.004
	label.outline_size = 10
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0, size.y / 2.0 + 0.45, 0)
	add_child(label)

	hold_extra = size.z * 0.5
	return self


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
	return ""


func drinks_left() -> int:
	if item_name == "Bierkasten":
		return beers_left()
	return water_left


func take_drink() -> bool:
	if item_name == "Bierkasten":
		return take_bottle()
	if item_name == "Wasserflasche":
		if water_left <= 0:
			return false
		water_left -= 1
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
	return "E: %s aufheben (%d kg)" % [display_name(), int(weight)]


func interact(player: Node) -> void:
	player.pick_up(self)
