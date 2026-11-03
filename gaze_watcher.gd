class_name GazeWatcher
extends Node
## "Nicht in die Augen schauen": Sieht man dem Wesen der Katakomben ins Gesicht, füllt sich ein
## Blick-Balken (Herzschlag, dunkle Ränder). Ist er voll oder kommt es zu nah, wacht man am Spawn auf.
## Lokal pro Spieler berechnet (jede Kamera schaut für sich), das Wesen selbst kommt aus dem Netz.

const CONE: float = 0.9              # cos des Blickkegels (ca. 25 Grad)
const SEE_RANGE: float = 26.0
const CATCH_DIST: float = 1.4

var player: Player
var gaze: float = 0.0
var _mat: ShaderMaterial
var _hb: float = 0.0
var _cd: float = 0.0
var _flash: float = 0.0
var _lamp_base: float = -1.0

const SHADER: String = """
shader_type canvas_item;
uniform float amt = 0.0;
uniform float flash = 0.0;
void fragment() {
	vec2 uv = UV - 0.5;
	float d = length(uv) * 1.45;
	float v = smoothstep(0.2, 0.95, d);
	float a = clamp(v * amt * 1.5 + amt * 0.22 + flash, 0.0, 0.97);
	COLOR = vec4(0.07 * amt, 0.0, 0.0, a);
}
"""


func setup(p: Player) -> void:
	player = p
	var layer := CanvasLayer.new()
	layer.layer = 60
	add_child(layer)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	rect.material = _mat
	layer.add_child(rect)


func _process(delta: float) -> void:
	_cd = maxf(_cd - delta, 0.0)
	_flash = maxf(_flash - delta * 1.2, 0.0)
	var lu := Bunker.active_lurker()
	if lu == null or player == null or player.camera == null or player.global_position.y > -10.0 or not lu.is_visible_in_tree():
		gaze = move_toward(gaze, 0.0, delta)
		_lamp_flicker(0.0)
		_apply()
		return
	var cam := player.camera
	var head := lu.head_pos()
	var to := head - cam.global_position
	var d := to.length()
	var looking := false
	if d < SEE_RANGE and d > 0.1:
		var fwd := -cam.global_transform.basis.z
		if fwd.dot(to / d) > CONE:
			var q := PhysicsRayQueryParameters3D.create(cam.global_position, head)
			var ex: Array = [player.get_rid()]
			if player.held != null:
				ex.append(player.held.get_rid())
			q.exclude = ex
			var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
			looking = hit.is_empty() or cam.global_position.distance_to(hit["position"]) > d - 0.6
	if looking:
		gaze += delta * clampf(0.9 / (0.6 + d * 0.15), 0.2, 1.6)
	else:
		gaze -= delta * 0.5
	gaze = clampf(gaze, 0.0, 1.0)
	# Herzschlag: je näher das Wesen (auch ohne Blick) und je voller der Balken, desto schneller
	var prox := clampf(1.0 - d / 18.0, 0.0, 1.0)
	_lamp_flicker(prox)
	var pulse := maxf(prox * 0.8, gaze)
	if pulse > 0.05:
		_hb -= delta
		if _hb <= 0.0:
			_hb = lerpf(1.1, 0.38, pulse)
			Sfx.play("thunk", Vector3.INF, lerpf(-9.0, 0.0, pulse), 0.4)
			player.shake = maxf(player.shake, 0.15 + gaze * 0.5)
	if _cd <= 0.0 and (gaze >= 1.0 or d < CATCH_DIST):
		_caught()
	_apply()


## Je näher das Wesen, desto öfter flackert die Kopflampe
func _lamp_flicker(prox: float) -> void:
	if player == null or player.lamp == null:
		return
	# Unten ist die Stirnlampe schwächer und kürzer: dunkle Gänge statt Flutlicht
	var deep := player.global_position.y < -6.0
	_lamp_base = 2.6 if deep else 7.0
	player.lamp.spot_range = 17.0 if deep else 35.0
	player.lamp.spot_angle = 30.0 if deep else 38.0
	if prox > 0.3 and player.lamp.visible:
		player.lamp.light_energy = _lamp_base * (0.1 if randf() < prox * 0.3 else 1.0)
	else:
		player.lamp.light_energy = _lamp_base


func _apply() -> void:
	if _mat != null:
		_mat.set_shader_parameter("amt", gaze)
		_mat.set_shader_parameter("flash", _flash)


## Erwischt: schwarz, dann am Spawn wieder zu sich kommen
func _caught() -> void:
	_cd = 3.0
	gaze = 0.0
	_flash = 1.0
	Sfx.play("boom", Vector3.INF, 0.0, 0.4)
	player.respawn()
	player.toast("Du hast ihm in die Augen gesehen ... Du kommst am Spawn wieder zu dir.", 6.0)
