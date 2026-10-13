class_name Tent
extends Node3D
## Zelt: erst durchsichtige Vorschau, dann ausgelegte Plane mit 4 Heringen,
## nach dem vierten Hering richtet es sich auf. Der Eingang zeigt nach -Z.

const WIDTH: float = 2.4
const HEIGHT: float = 1.5
const DEPTH: float = 3.1
const FABRIC: Color = Color(0.95, 0.5, 0.15)

var shell: MeshInstance3D
var model: Node3D = null
var door: MeshInstance3D
var mat_flat: MeshInstance3D
var pegs_driven: int = 0
var finished: bool = false
var _last_valid: int = -1
var smelly: bool = false
var _shake_t: float = 0.0


## Eingang zum Zelt: hier kann man schlafen.
class TentDoor:
	extends StaticBody3D
	var tent: Tent

	func get_prompt() -> String:
		if Game.hour >= 19.0 or Game.hour < 6.0:
			return "E: im Zelt schlafen (spult die Nacht vor)"
		return "Noch zu hell zum Schlafen (ab 19:00 Uhr, jetzt %s)" % Game.clock_text()

	func interact(player: Node) -> void:
		if Game.hour >= 19.0 or Game.hour < 6.0:
			player.sleep(tent)
		else:
			player.toast("Du bist noch nicht müde. Es ist erst %s." % Game.clock_text(), 3.0)


var lamp: OmniLight3D = null


func shake() -> void:
	_shake_t = 0.4


func _process(delta: float) -> void:
	if lamp != null:
		lamp.light_energy = lerpf(lamp.light_energy, 0.9 if Game.is_night() else 0.0, minf(delta * 1.5, 1.0))
	var vis: Node3D = model if model != null else shell
	if _shake_t > 0.0 and vis != null:
		_shake_t -= delta
		vis.rotation.z = sin(Time.get_ticks_msec() / 25.0) * 0.04
		if _shake_t <= 0.0:
			vis.rotation.z = 0.0


func build_ghost() -> void:
	shell = MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(WIDTH, HEIGHT, DEPTH)
	shell.mesh = pm
	shell.position.y = HEIGHT / 2.0
	add_child(shell)

	door = Util.add_box(self, Vector3(0.7, 1.0, 0.04), Color(0.05, 0.05, 0.06), Vector3(0, 0.5, -DEPTH / 2.0 - 0.01))
	door.visible = false
	mat_flat = Util.add_box(self, Vector3(WIDTH + 0.3, 0.05, DEPTH + 0.3), FABRIC.darkened(0.2), Vector3(0, 0.03, 0))
	mat_flat.visible = false
	set_ghost_valid(false)


func set_ghost_valid(valid: bool) -> void:
	var v := 1 if valid else 0
	if v == _last_valid:
		return
	_last_valid = v
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.2, 0.9, 0.3, 0.5) if valid else Color(0.95, 0.2, 0.2, 0.5)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shell.material_override = m


## Aus der Vorschau wird die ausgelegte Plane mit vier Heringen.
func begin_site() -> void:
	shell.material_override = Util.mat(FABRIC)
	shell.visible = false
	mat_flat.visible = true
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var peg := TentPeg.new()
			peg.tent = self
			peg.build()
			peg.position = Vector3(sx * 1.55, 0.0, sz * 1.75)
			add_child(peg)


func peg_driven(player: Node) -> void:
	pegs_driven += 1
	if pegs_driven >= 4:
		_finish(player)


func _finish(player: Node) -> void:
	finished = true
	if player != null and Net.instance != null:
		Net.instance.send_tent(global_position, rotation.y)
	mat_flat.visible = false
	var tw := create_tween()
	if ResourceLoader.exists("res://assets/zelt.glb"):
		shell.visible = false
		model = (load("res://assets/zelt.glb") as PackedScene).instantiate() as Node3D
		model.scale = Vector3(1, 0.05, 1)
		add_child(model)
		tw.tween_property(model, "scale:y", 1.0, 1.2)
	else:
		shell.visible = true
		shell.scale = Vector3(1, 0.05, 1)
		shell.position.y = HEIGHT * 0.05 / 2.0
		tw.tween_method(_grow, 0.05, 1.0, 1.2)
	tw.tween_callback(_on_grown)
	if player != null and player.has_method("toast"):
		player.toast("Das Zelt steht!", 5.0)


func _grow(s: float) -> void:
	shell.scale.y = s
	shell.position.y = HEIGHT * s / 2.0


func _on_grown() -> void:
	door.visible = model == null
	lamp = OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.72, 0.4)
	lamp.light_energy = 0.0
	lamp.omni_range = 4.5
	lamp.position = Vector3(0, 1.0, 0)
	add_child(lamp)
	# Vorerst massiv; den Eingang zum Schlafen bauen wir später.
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(WIDTH, 1.2, DEPTH)
	cs.shape = bs
	cs.position.y = 0.6
	body.add_child(cs)
	add_child(body)
	var door_body := TentDoor.new()
	door_body.tent = self
	var dcs := CollisionShape3D.new()
	var dbs := BoxShape3D.new()
	dbs.size = Vector3(0.9, 1.1, 0.3)
	dcs.shape = dbs
	dcs.position = Vector3(0, 0.55, -DEPTH / 2.0 - 0.45)
	door_body.add_child(dcs)
	add_child(door_body)
