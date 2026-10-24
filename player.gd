class_name Player
extends CharacterBody3D
## Spielfigur: Ego-Ansicht (Standard) oder Third Person (Taste V).

const WALK_SPEED: float = 4.5
const SPRINT_SPEED: float = 7.0
const JUMP_VELOCITY: float = 4.5
const GRAVITY: float = 12.0
const MOUSE_SENS: float = 0.0025
const REACH: float = 3.2
const BLUR_SHADER: String = """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float amount = 0.0;
uniform float time_s = 0.0;
void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 off = vec2(sin(time_s * 1.3), cos(time_s * 1.7)) * 0.02 * amount;
	vec3 c = texture(screen_tex, uv).rgb;
	vec3 a = textureLod(screen_tex, uv + off, 2.0 * amount).rgb;
	vec3 b = textureLod(screen_tex, uv - off, 2.0 * amount).rgb;
	vec3 col = mix(c, (a + b + c) / 3.0, clamp(amount, 0.0, 1.0) * 0.85);
	float v = smoothstep(0.3, 0.85, length(uv - vec2(0.5)) * 1.3);
	col *= 1.0 - v * 0.7 * clamp(amount, 0.0, 1.0);
	COLOR = vec4(col, 1.0);
}
"""
const SKIN: Color = Color(0.9, 0.72, 0.6)

const CHARS: Dictionary = {
	"Marian": {
		"shirt": Color(0.15, 0.17, 0.26), "pants": Color(0.2, 0.36, 0.26),
		"hair": Color(0.7, 0.5, 0.3), "cap": true, "glasses": true, "beard": false,
		"pack": Color(0.55, 0.55, 0.5),
	},
	"Steffen": {
		"shirt": Color(0.5, 0.65, 0.8), "pants": Color(0.2, 0.2, 0.22),
		"hair": Color(0.2, 0.14, 0.1), "cap": false, "glasses": false, "beard": true,
		"pack": Color(0.1, 0.1, 0.12),
	},
	"Julian": {
		"shirt": Color(0.08, 0.08, 0.1), "pants": Color(0.12, 0.13, 0.2),
		"hair": Color(0.6, 0.45, 0.28), "cap": false, "glasses": true, "beard": true,
		"pack": Color(0.0, 0.0, 0.0),
	},
}

var character_name: String = "Marian"
var third_person: bool = false
var held: Item = null
var pitch: float = 0.0

# Bier und Betrunkenheit
var promille: float = 0.0
var vomit_t: float = 0.0           # >0: gerade am Übergeben
var sober_t: float = 0.0           # >0: nach dem Kotzen baut sich der Alkohol schneller ab
var vomit_tilt: float = 0.0
var trip_t: float = 0.0              # Restdauer der Joint-Wirkung (Sekunden)
var trip_i: float = 0.0              # aktuelle Stärke 0..1 (blendet weich ein und aus)
var _trip_fx: TripFx = null
var _gun_cd: float = 0.0
const GUN_MAG: int = 5               # Patronen im Magazin des Luftgewehrs
const GUN_RELOAD: float = 1.7        # Nachladedauer in Sekunden
const GUN_SIGHT_Z: float = 0.097     # Höhe der Visierlinie (Kimme/Korn) über dem Modellmittelpunkt
var crosshair: Label = null
var aiming: bool = false             # Rechtsklick: über Kimme und Korn zielen
var _aim_f: float = 0.0              # 0 = Hüfte, 1 = Visier
var _reload_t: float = 0.0
var _gun_kick: float = 0.0
const USE_VM_HAMMER: bool = false     # false = alter Hammer: schwebt vor dir, keine Hand- und Schlag-Animation
var vm_hand: Node3D = null         # Hand mit Werkzeug in der Ego-Ansicht
var _vm_swing: float = 0.0
var _vomit_fx: CPUParticles3D = null
var _vomit_cd: float = 0.0
var beers_drunk: int = 0
var drink_tilt: float = 0.0
var _drink_cd: float = 0.0
var _help_timer: float = 0.0

# Zelt-Platzierung
var placing: bool = false
var ghost: Tent = null
var ghost_valid: bool = false
var ghost_reason: String = ""
var place_item: bool = false          # true: normaler Gegenstand wird platziert (kein Zelt)
var item_ghost: Node3D = null
var item_ghost_mat: StandardMaterial3D = null
var item_snap: PlacedItem = null      # Grill, auf den der Dutch Oven gesetzt wird

# Sitzen
var seat: PlacedItem = null
var vape_t: float = 0.0          # Dauer der Vape-Animation
var drink_t: float = 0.0         # Dauer der Trink-Animation
var drink_kind: int = 0          # 1 Bier, 2 Wasser
var hammock: Hammock = null
var stones: int = 0
var crouching: bool = false
var _air_t: float = 0.0
var fish_cast_t: float = 0.0
var shake: float = 0.0              # Kamerawackeln (Angelkampf, Funken ...)

var crouch_f: float = 0.0
var col_shape: CapsuleShape3D = null
var col_node: CollisionShape3D = null
var clock_label: Label
var stink_t: float = 0.0
var stink_fx: CPUParticles3D = null
var trapped_t: float = 0.0
var trap_head: float = 1.6

# Rucksack-Inhalt des Spielers (gesammelt)
var tinder: int = 0
var sticks: int = 0
var logs: int = 0

# Schlafen, Feuer machen, Kopflampe
var sleeping: bool = false
var tent_lying: Tent = null     # Multiplayer: liegt im Zelt (wartet auf die anderen)
var lamp: SpotLight3D
var fire_bowl: PlacedItem = null
var fire_t: float = 0.0
var fire_dur: float = 4.0
var _curses_done: int = 0
var sparks: CPUParticles3D = null
var fade_rect: ColorRect
var needs: Needs
var goals_label: Label
var hud: Hud
var _dark_hint: bool = false
var water_d: float = 0.0              # 0 = an Land, 1 = tief im See (schwimmen)
var wake: CPUParticles3D = null
var fisher: Fisher
var _peak_y: float = 0.0
var _airborne: bool = false

# Wasser / Rausch-Effekt
var water_drunk: int = 0
var blur_rect: ColorRect = null
var blur_mat: ShaderMaterial = null
var _stumble_cd: float = 4.0

var head: Node3D
var camera: Camera3D
var ray: RayCast3D
var body_visual: Node3D
var help_label: Label
var prompt_label: Label
var toast_label: Label
var toast_tween: Tween
var _last_camp: String = ""


func _ready() -> void:
	var shape := CapsuleShape3D.new()
	shape.radius = 0.35
	shape.height = 1.8
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position.y = 0.9
	add_child(col)
	col_shape = shape
	col_node = col

	head = Node3D.new()
	head.position.y = 1.6
	add_child(head)

	camera = Camera3D.new()
	camera.current = true
	camera.fov = 75.0
	head.add_child(camera)

	ray = RayCast3D.new()
	ray.add_exception(self)
	ray.collision_mask = 3
	camera.add_child(ray)

	body_visual = Node3D.new()
	add_child(body_visual)

	add_to_group("local_player")
	lamp = SpotLight3D.new()
	lamp.spot_range = 35.0
	lamp.spot_angle = 38.0
	lamp.spot_attenuation = 0.6
	lamp.light_energy = 7.0
	lamp.shadow_enabled = not Game.low
	lamp.visible = false
	head.add_child(lamp)

	_build_hud()
	set_character(character_name)
	_apply_view()
	if Game.touch:
		add_child(TouchControls.new())
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func set_character(p_name: String) -> void:
	character_name = p_name
	_build_visual()
	_update_help()


func _build_visual() -> void:
	for c in body_visual.get_children():
		c.queue_free()
	Player.build_body(body_visual, character_name)
	call_deferred("_apply_view")
	vm_hand = null


## Baut die Figur (auch für die Avatare der Mitspieler).
static func build_body(parent: Node3D, char_name: String) -> void:
	Fx.blob_shadow(parent, 0.5)
	# Fertiges, animiertes Modell (aus Blender), falls vorhanden.
	var path := "res://assets/chars/%s.glb" % char_name.to_lower()
	if ResourceLoader.exists(path):
		var ps: PackedScene = load(path)
		var inst := ps.instantiate() as Node3D
		inst.rotation.y = PI          # Modell schaut nach +Z, das Spiel nach -Z
		inst.scale = Vector3.ONE * 0.92
		parent.add_child(inst)
		parent.set_meta("inst", inst)
		var ap := _find_anim(inst)
		if ap != null:
			for n in ap.get_animation_list():
				ap.get_animation(n).loop_mode = Animation.LOOP_NONE if (n == "Jump" or n == "FishCast" or n == "Squat" or n == "Vape") else Animation.LOOP_LINEAR
			if ap.has_animation("Idle"):
				ap.play("Idle")
			parent.set_meta("ap", ap)
			var sk := inst.find_child("Skeleton3D", true, false) as Skeleton3D
			if sk != null and sk.find_bone("Hand.R") >= 0:
				var att := BoneAttachment3D.new()
				att.bone_name = "Hand.R"
				sk.add_child(att)
				var bt := Node3D.new()
				bt.visible = false
				bt.rotation_degrees.z = -90.0
				bt.position = Vector3(-0.12, 0.05, 0.04)
				att.add_child(bt)
				# Flasche liegt in der Faust: Hals zeigt zum Mund (Bone-Achse Y)
				var gl := Util.add_cylinder(bt, 0.03, 0.16, Color(0.3, 0.16, 0.05), Vector3(0, 0.07, 0.0))
				gl.name = "glass"
				var ne := Util.add_cylinder(bt, 0.0125, 0.08, Color(0.3, 0.16, 0.05), Vector3(0, 0.19, 0.0))
				ne.name = "glass"
				Util.add_cylinder(bt, 0.0135, 0.012, Color(0.85, 0.7, 0.2), Vector3(0, 0.236, 0.0))
				Util.add_cylinder(bt, 0.031, 0.05, Color(0.93, 0.88, 0.7), Vector3(0, 0.06, 0.0))
				parent.set_meta("bottle", bt)
			var hd := inst.find_child("HoseDown", true, false) as Node3D
			var hs := inst.find_child("Hose", true, false) as Node3D
			if hd != null and hs != null:
				hd.visible = false
				parent.set_meta("hose", hs)
				parent.set_meta("hose_down", hd)
		return
	var d: Dictionary = CHARS[char_name]
	var shirt: Color = d["shirt"]
	Util.add_box(parent, Vector3(0.42, 0.8, 0.26), d["pants"], Vector3(0, 0.4, 0))
	Util.add_box(parent, Vector3(0.55, 0.7, 0.3), shirt, Vector3(0, 1.15, 0))
	Util.add_box(parent, Vector3(0.14, 0.65, 0.14), shirt, Vector3(-0.36, 1.1, 0))
	Util.add_box(parent, Vector3(0.14, 0.65, 0.14), shirt, Vector3(0.36, 1.1, 0))
	Util.add_sphere(parent, 0.19, SKIN, Vector3(0, 1.65, 0))
	if d["cap"]:
		Util.add_cylinder(parent, 0.2, 0.09, Color(0.05, 0.05, 0.07), Vector3(0, 1.82, 0))
		Util.add_box(parent, Vector3(0.22, 0.02, 0.18), Color(0.05, 0.05, 0.07), Vector3(0, 1.78, -0.2))
	else:
		Util.add_box(parent, Vector3(0.34, 0.1, 0.34), d["hair"], Vector3(0, 1.8, 0))
	if d["glasses"]:
		Util.add_box(parent, Vector3(0.1, 0.07, 0.02), Color(0.1, 0.1, 0.1), Vector3(-0.08, 1.67, -0.18))
		Util.add_box(parent, Vector3(0.1, 0.07, 0.02), Color(0.1, 0.1, 0.1), Vector3(0.08, 1.67, -0.18))
	if d["beard"]:
		Util.add_box(parent, Vector3(0.26, 0.1, 0.08), d["hair"].darkened(0.1), Vector3(0, 1.55, -0.14))
	var pack: Color = d["pack"]
	if pack != Color(0.0, 0.0, 0.0):
		Util.add_box(parent, Vector3(0.4, 0.5, 0.2), pack, Vector3(0, 1.15, 0.25))


static func _find_anim(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n as AnimationPlayer
	for c in n.get_children():
		var r := _find_anim(c)
		if r != null:
			return r
	return null


## Wählt die passende Animation für das Lauftempo (Stehen / Gehen / Rennen).
static func _paint_bottle(b: Node3D, kind: int) -> void:
	var glass: Color = Color(0.3, 0.16, 0.05) if kind == 1 else Color(0.55, 0.78, 0.92)
	for mi in b.find_children("*", "MeshInstance3D", true, false):
		if mi.name == "glass":
			(mi as MeshInstance3D).material_override = Util.mat(glass, 0.2)


## Vornübergebeugt kotzen: Oberkörper kippt nach vorn, im Rhythmus des Würgens.
## Nasse/braune Hose: Fleck am Schritt und an den Oberschenkeln, Stoff verfärbt sich.
static func set_pants(parent: Node3D, kind: int) -> void:
	if int(parent.get_meta("pants", 0)) == kind:
		return
	parent.set_meta("pants", kind)
	if parent.has_meta("stain"):
		var old: Node = parent.get_meta("stain") as Node
		if old != null and is_instance_valid(old):
			old.queue_free()
		parent.remove_meta("stain")
	var inst: Node3D = parent.get_meta("inst", null) as Node3D
	if inst == null:
		return
	for mi in inst.find_children("Hose*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if kind == 0:
			m.material_override = null
		else:
			var base := m.get_active_material(0) as StandardMaterial3D
			if base != null:
				var nm := base.duplicate() as StandardMaterial3D
				var tint := Color(0.7, 0.58, 0.12) if kind == 1 else Color(0.3, 0.18, 0.08)
				nm.albedo_color = base.albedo_color.lerp(tint, 0.45)
				m.material_override = nm
	if kind == 0:
		return
	var col := Color(0.72, 0.6, 0.08) if kind == 1 else Color(0.27, 0.16, 0.07)
	var st := Node3D.new()
	st.name = "Stain"
	inst.add_child(st)
	parent.set_meta("stain", st)
	var mat := Util.mat(col, 0.9)
	var patch := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	patch.mesh = sm
	patch.material_override = mat
	patch.scale = Vector3(0.3, 0.24, 0.09)
	patch.position = Vector3(0, 0.86, 0.11)
	st.add_child(patch)
	for sx in [-1.0, 1.0]:
		var dr := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.07, 0.4, 0.03)
		dr.mesh = bm
		dr.material_override = mat
		dr.position = Vector3(sx * 0.1, 0.66, 0.12)
		st.add_child(dr)


static func vomit_pose(parent: Node3D, on: bool, delta: float) -> void:
	var inst: Node3D = parent.get_meta("inst", null) as Node3D
	if inst == null:
		return
	var target := 0.0
	if on:
		var t := Time.get_ticks_msec() / 1000.0
		target = deg_to_rad(26.0 + 10.0 * maxf(sin(t * 7.0), 0.0))
	inst.rotation.x = lerp_angle(inst.rotation.x, target, minf(delta * 9.0, 1.0))


static func animate_body(parent: Node3D, speed: float, crouch: bool = false, air: bool = false, fish: int = 0, squat: bool = false, sit: bool = false, vape: bool = false, drink: int = 0, pee: bool = false) -> void:
	var ap: AnimationPlayer = parent.get_meta("ap", null) as AnimationPlayer
	if ap == null:
		return
	var want := "Idle"
	var sc := 1.0
	var bottle: Node3D = parent.get_meta("bottle", null) as Node3D
	if drink > 0 and speed < 0.5 and not sit and ap.has_animation("Drink"):
		if not parent.get_meta("drinking", false):
			parent.set_meta("drinking", true)
			if bottle != null:
				bottle.set_meta("kind", drink)
				_paint_bottle(bottle, drink)
			ap.play("Drink", 0.12)
		if ap.current_animation == "Drink" and ap.is_playing():
			if bottle != null:
				bottle.visible = true
			ap.speed_scale = 1.0
			return
	else:
		parent.set_meta("drinking", false)
	if bottle != null:
		bottle.visible = false
	if vape and speed < 0.5 and ap.has_animation("Vape"):
		if not parent.get_meta("vaping", false):
			parent.set_meta("vaping", true)
			ap.play("Vape", 0.15)
		ap.speed_scale = 1.0
		return
	parent.set_meta("vaping", false)
	if pee and speed < 0.5 and not sit and ap.has_animation("Pee"):
		if ap.current_animation != "Pee":
			ap.play("Pee", 0.2)
		ap.speed_scale = 1.0
		return
	if sit and ap.has_animation("Sit"):
		if ap.current_animation != "Sit":
			ap.play("Sit", 0.2)
		ap.speed_scale = 1.0
		return
	var hose: Node3D = parent.get_meta("hose", null) as Node3D
	var hose_down: Node3D = parent.get_meta("hose_down", null) as Node3D
	if squat and ap.has_animation("Squat"):
		if not parent.get_meta("squatting", false):
			parent.set_meta("squatting", true)
			ap.play("Squat", 0.1)
			if hose != null and hose_down != null:
				var tw := parent.create_tween()
				tw.tween_interval(0.25)
				tw.tween_callback(func() -> void:
					hose.visible = false
					hose_down.visible = true)
		ap.speed_scale = 1.0
		return
	if parent.get_meta("squatting", false):
		parent.set_meta("squatting", false)
		if hose != null and hose_down != null:
			hose.visible = true
			hose_down.visible = false
	if air and ap.has_animation("Jump"):
		if not parent.get_meta("jumping", false):
			parent.set_meta("jumping", true)
			ap.play("Jump", 0.08)
		ap.speed_scale = 1.0
		return
	parent.set_meta("jumping", false)
	if fish > 0 and not crouch and speed < 0.3:
		var fa := "FishCast" if fish == 3 else ("FishReel" if fish == 2 else "FishWait")
		if ap.has_animation(fa):
			if ap.current_animation != fa:
				ap.play(fa, 0.15)
			ap.speed_scale = 1.0
			return
	if crouch:
		want = "CrouchWalk" if speed > 0.3 else "Crouch"
		sc = clampf(speed / 0.9, 0.6, 1.6) if speed > 0.3 else 1.0
	elif speed > 2.8:
		want = "Run"
		sc = clampf(speed / 3.4, 0.7, 2.2)
	elif speed > 0.3:
		want = "Walk"
		sc = clampf(speed / 1.8, 0.6, 1.8)
	if not ap.has_animation(want):
		return
	if ap.current_animation != want:
		ap.play(want, 0.2)
	ap.speed_scale = sc



## Animationszustand als Bitmaske für die anderen Spieler (Bit0 ducken, Bit1 Luft, Bit2-3 Angeln, Bit4 Hocke).
func anim_flags() -> int:
	var f := 0
	if crouching or (needs != null and needs.accident_t > 0.0):
		f |= 1
	if needs != null and needs.pants == 1:
		f |= 4096
	if needs != null and needs.pants == 2:
		f |= 8192
	if _air_t > 0.18:
		f |= 2
	f |= (_fish_anim() & 3) << 2
	if needs != null and needs.squatting:
		f |= 16
	if seat != null:
		f |= 32
	if vape_t > 0.0:
		f |= 64
	if needs != null and needs.peeing:
		f |= 128
	if vomit_t > 0.0:
		f |= 1024
	if drink_t > 0.0:
		f |= 256 if drink_kind == 1 else 512
	if is_lying():
		f |= 2048
	return f


func _fish_anim() -> int:
	if fisher == null or not fisher.has_rod():
		return 0
	if fish_cast_t > 0.0:
		return 3
	match fisher.state:
		Fisher.S.WAITING, Fisher.S.BITE:
			return 1
		Fisher.S.RETRIEVE, Fisher.S.FIGHT:
			return 2
	return 0


## Erste Person: eigener Körper und Füße sind sichtbar (ohne Kopf), Blick nach unten zeigt Oberkörper und Schuhe.
func _apply_view() -> void:
	body_visual.position.z = 0.0 if third_person else 0.16
	for nm in ["Kopf_Gruppe", "Hals"]:
		var hn := body_visual.find_child(nm, true, false) as Node3D
		if hn != null:
			# Kopf bleibt für den Schatten da, ist aber in der Ego-Ansicht unsichtbar
			hn.visible = true
			var mode := GeometryInstance3D.SHADOW_CASTING_SETTING_ON if third_person else GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
			var meshes: Array = hn.find_children("*", "MeshInstance3D", true, false)
			if hn is MeshInstance3D:
				meshes.append(hn)
			for m in meshes:
				(m as MeshInstance3D).cast_shadow = mode
	if third_person:
		camera.position = Vector3(0.6, 0.4, 3.2)
		ray.target_position = Vector3(0, 0, -11.2)
	else:
		camera.position = Vector3.ZERO
		ray.target_position = Vector3(0, 0, -8.0)
	body_visual.visible = true


func _build_hud() -> void:
	var blur_layer := CanvasLayer.new()
	blur_layer.layer = 1
	add_child(blur_layer)
	blur_rect = ColorRect.new()
	blur_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	blur_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = BLUR_SHADER
	blur_mat = ShaderMaterial.new()
	blur_mat.shader = sh
	blur_rect.material = blur_mat
	blur_rect.visible = false
	blur_layer.add_child(blur_rect)

	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)

	hud = Hud.new()
	layer.add_child(hud)

	help_label = _make_label(layer, 16)
	help_label.position = Vector2(14, 10)

	clock_label = _make_label(layer, 30)
	clock_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clock_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	clock_label.offset_top = 8
	clock_label.offset_left = -150
	clock_label.offset_right = 150
	clock_label.custom_minimum_size = Vector2(300, 0)

	prompt_label = _make_label(layer, 24)
	prompt_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	prompt_label.offset_bottom = -90

	toast_label = _make_label(layer, 28)
	toast_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	toast_label.offset_top = 90
	toast_label.modulate.a = 0.0

	needs = Needs.new()
	needs.name = "Needs"
	add_child(needs)
	needs.setup(self, layer)
	fisher = Fisher.new()
	fisher.name = "Fisher"
	add_child(fisher)
	fisher.setup(self, layer)

	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 5
	add_child(fade_layer)
	fade_rect = ColorRect.new()
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_rect.color = Color(0, 0, 0, 0)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_layer.add_child(fade_rect)

	goals_label = _make_label(layer, 15)
	goals_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	goals_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	goals_label.offset_left = -330.0
	goals_label.offset_top = 150.0
	goals_label.offset_right = -10.0

	for old in [help_label, clock_label, prompt_label, toast_label, goals_label]:
		old.visible = false

	crosshair = _make_label(layer, 28)
	crosshair.text = "+"
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crosshair.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


func _make_label(parent: Node, font_size: int) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	parent.add_child(l)
	return l


func toast(text: String, seconds: float = 4.0) -> void:
	if toast_tween != null and toast_tween.is_valid():
		toast_tween.kill()
	if hud != null:
		hud.toast(text, seconds)


func _update_goals() -> void:
	var lines := PackedStringArray(["ZIELE"])
	var all := true
	for g in Game.goals():
		lines.append("%s %s" % ["[x]" if g[1] else "[ ]", g[0]])
		if not g[1]:
			all = false
	goals_label.text = "\n".join(lines)
	# Selbst geschaffte Ziele an die Gruppe melden (gelten dann fuer alle)
	var loc: Array = Game.goals_local()
	for i in loc.size():
		if loc[i][1] and not Game.goal_shared.has(i):
			Game.goal_shared[i] = Game.player_name
			if Net.instance != null:
				Net.instance.send_goal(i, Game.player_name)
	var gl: Array = Game.goals()
	if Game.goals_done_prev.size() == gl.size():
		for i in gl.size():
			if gl[i][1] and not Game.goals_done_prev[i]:
				var by: String = str(Game.goal_shared.get(i, ""))
				var txt := str(gl[i][0])
				if by != "" and by != Game.player_name:
					txt += " (von %s)" % by
				_goal_done(txt)
	Game.goals_done_prev = gl.map(func(g): return g[1])
	if hud != null:
		hud.set_goals(gl)
	if all and not Game.all_done_shown:
		Game.all_done_shown = true
		Finale.start(get_parent(), self)


func _goal_done(text: String) -> void:
	Sfx.play("pop", Vector3.INF, -2.0, 1.3)
	Sfx.play("chirp", Vector3.INF, -6.0, 1.6)
	var mh := get_minihud()
	if mh != null:
		mh.card("ZIEL GESCHAFFT!", "✓ " + text, Color(0.45, 0.85, 0.4), 4.5)
	toast("✓ Ziel geschafft: %s" % text, 5.0)


func step_in_poop() -> void:
	stink_t = 90.0
	toast("PLATSCH! Du bist in einen Haufen getreten. Iiih... das stinkt. (Im See abwaschen!)", 5.0)
	if stink_fx == null:
		stink_fx = CPUParticles3D.new()
		stink_fx.amount = 8
		stink_fx.lifetime = 1.2
		stink_fx.direction = Vector3(0, 1, 0)
		stink_fx.spread = 180.0
		stink_fx.initial_velocity_min = 0.2
		stink_fx.initial_velocity_max = 0.6
		stink_fx.gravity = Vector3.ZERO
		var m := SphereMesh.new()
		m.radius = 0.012
		m.height = 0.024
		m.radial_segments = 4
		m.rings = 2
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(0.1, 0.12, 0.05)
		m.material = mat
		stink_fx.mesh = m
		stink_fx.position = Vector3(0, 0.3, 0)
		add_child(stink_fx)
	stink_fx.emitting = true


func _day_phase() -> String:
	var h := Game.hour
	var ph := "Nacht"
	if h >= 5.0 and h < 8.0:
		ph = "Morgen"
	elif h >= 8.0 and h < 12.0:
		ph = "Vormittag"
	elif h >= 12.0 and h < 14.0:
		ph = "Mittag"
	elif h >= 14.0 and h < 18.0:
		ph = "Nachmittag"
	elif h >= 18.0 and h < 21.0:
		ph = "Abend"
	var w := Weather.word()
	return ph if w == "" else "%s · %s" % [ph, w]


func _update_help() -> void:
	if clock_label != null:
		clock_label.text = "%s Uhr  ·  %s  ·  Tag %d" % [Game.clock_text(), _day_phase(), Game.day_count]
	_update_goals()
	var carrying := "nichts"
	if held != null:
		carrying = "%s (%d kg)" % [held.item_name, int(held.weight)]
	var camp := Game.camp_name if Game.camp_claimed else "noch keins"
	var net_txt := ""
	if Net.instance != null:
		net_txt = "  |  Netz: %s, %d Mitspieler" % [Net.instance.status, Net.instance.avatars.size()]
	help_label.text = "%s  |  trägt: %s  |  Lager: %s  |  %s Tag %d  |  Promille: %.2f%s\nZunder %d · Äste %d · Holz %d · Steine %d  |  Bier %d · Wasser %d  |  Fänge: %d  |  Chili: %d\nWASD laufen · Shift rennen · Space springen · E benutzen · F trinken · R aufstellen · X abbauen · G werfen/Stein flitschen · C ducken · L Kopflampe · M Karte\nP pinkeln (halten) · H großes Geschäft · Q Vape (Julian) · T Angelmethode · Z Zutat wechseln · V Ansicht · 1/2/3 Charakter · Esc Maus frei" % [character_name, carrying, camp, Game.clock_text(), Game.day_count, promille, net_txt, tinder, sticks, logs, stones, beers_drunk, water_drunk, Game.catches.size(), Game.chili_served]
	if hud != null:
		var others: Array = []
		if Net.instance != null:
			for k in Net.instance.avatars.keys():
				var av: Node = Net.instance.avatars[k]
				var lb = av.get("label")
				others.append([lb.text if lb != null else "?", str(av.get("char_name"))])
		hud.update_info(Game.player_name, character_name, carrying, camp, Game.hour, Game.day_count, Game.clock_text(), _day_phase(), promille,
			[tinder, sticks, logs, stones, beers_drunk, water_drunk, Game.catches.size(), Game.chili_served], others)
	if Game.touch:
		var hl: PackedStringArray = help_label.text.split("\n")
		help_label.text = hl[0] + "\n" + hl[1] + "\nLinks: Joystick laufen (ganz raus = rennen) · Rechts wischen: umschauen · BENUTZEN: Tür, Kiste, Feuer ... · Mehr: alles andere"


func _unhandled_input(event: InputEvent) -> void:
	if sleeping:
		return
	if event is InputEventMouseMotion and Game.is_captured():
		var mm := event as InputEventMouseMotion
		var sens := MOUSE_SENS * (1.0 - 0.45 * _aim_f)
		rotate_y(-mm.screen_relative.x * sens)
		pitch = clampf(pitch - mm.screen_relative.y * sens, -1.45, 1.45)
		head.rotation.x = pitch
	elif event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if not Game.is_captured():
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN) and not placing and Radio.target_of(self) != null and get_parent().get("radio") != null:
			(get_parent().radio as Radio).change_volume(1 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else -1)
		elif placing:
			match mb.button_index:
				MOUSE_BUTTON_WHEEL_UP:
					_rotate_ghost(0.25)
				MOUSE_BUTTON_WHEEL_DOWN:
					_rotate_ghost(-0.25)
				MOUSE_BUTTON_LEFT:
					_confirm_placement()
		elif mb.button_index == MOUSE_BUTTON_LEFT and held != null and held.item_name == "Luftgewehr":
			_shoot()
	elif event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		match key.keycode:
			KEY_ESCAPE:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			KEY_V:
				third_person = not third_person
				_apply_view()
			KEY_I, KEY_F1:
				hud.toggle_info()
			KEY_TAB, KEY_O:
				hud.toggle_goals()
			KEY_M:
				hud.toggle_map()
			KEY_F3:
				hud.toggle_debug()
			KEY_F4:
				repair_view()
			KEY_E:
				_interact()
			KEY_G:
				_throw()
			KEY_F:
				_drink()
			KEY_X:
				_dismantle()
			KEY_L:
				lamp.visible = not lamp.visible
			KEY_H:
				needs.try_big_business()
			KEY_Q:
				needs.vape()
			KEY_PLUS, KEY_KP_ADD, KEY_MINUS, KEY_KP_SUBTRACT, KEY_EQUAL, KEY_SLASH:
				if Radio.target_of(self) != null and get_parent().get("radio") != null:
					var up: bool = key.keycode == KEY_PLUS or key.keycode == KEY_KP_ADD or key.keycode == KEY_EQUAL
					(get_parent().radio as Radio).change_volume(1 if up else -1)
			KEY_Z:
				var zc: Object = _reach_target()
				if Radio.target_of(self) != null and get_parent().get("radio") != null:
					(get_parent().radio as Radio).next_station()
					return
				if zc != null and zc.has_method("cycle_selection"):
					zc.cycle_selection()
			KEY_R:
				if held != null and held.item_name == "Luftgewehr" and not placing:
					_reload()
				elif placing:
					_cancel_placement()
				else:
					_start_placement()
			KEY_1:
				set_character("Marian")
			KEY_2:
				set_character("Steffen")
			KEY_3:
				set_character("Julian")


func _physics_process(delta: float) -> void:
	_gun_cd = maxf(_gun_cd - delta, 0.0)
	_reload_t = maxf(_reload_t - delta, 0.0)
	_gun_kick = lerpf(_gun_kick, 0.0, minf(delta * 9.0, 1.0))
	var gun_ready := held != null and held.item_name == "Luftgewehr" and not placing and not sleeping
	aiming = gun_ready and Game.is_captured() and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and _reload_t <= 0.0
	_aim_f = move_toward(_aim_f, 1.0 if aiming else 0.0, delta * 7.0)
	if crosshair != null:
		crosshair.visible = _aim_f < 0.3
	_update_trip(delta)
	vape_t = maxf(vape_t - delta, 0.0)
	drink_t = maxf(drink_t - delta, 0.0)
	if sober_t > 0.0:
		sober_t -= delta
		promille = maxf(promille - delta * 0.03, 0.0)
	if vomit_t > 0.0:
		_vomit_tick(delta)
	elif promille > 2.2 and seat == null and hammock == null and not sleeping and randf() < delta * 0.06:
		start_vomit()
	vomit_tilt = lerpf(vomit_tilt, 0.85 if vomit_t > 0.0 else 0.0, minf(delta * 6.0, 1.0))
	Player.vomit_pose(body_visual, vomit_t > 0.0, delta)
	if sleeping:
		velocity = Vector3.ZERO
		return
	if seat != null:
		velocity = Vector3.ZERO
		Player.animate_body(body_visual, 0.0, false, false, 0, false, true, vape_t > 0.0, drink_kind if drink_t > 0.0 else 0, needs != null and needs.peeing)
		_drink_cd = maxf(_drink_cd - delta, 0.0)
		promille = maxf(promille - delta * 0.005, 0.0)
		if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_A) \
				or Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_D) \
				or Input.is_physical_key_pressed(KEY_SPACE):
			stand_up()
		_update_prompt()
		return
	if trapped_t > 0.0:
		velocity = Vector3(0, velocity.y, 0)
		velocity.y -= GRAVITY * delta
		move_and_slide()
		trapped_t -= delta * 0.25
		head.position.y = lerpf(head.position.y, trap_head, minf(delta * 8.0, 1.0))
		if trapped_t <= 0.0:
			free_from_trap()
		_update_prompt()
		return
	if hammock != null or tent_lying != null:
		velocity = Vector3.ZERO
		_drink_cd = maxf(_drink_cd - delta, 0.0)
		promille = maxf(promille - delta * 0.01, 0.0)
		if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_A) \
				or Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_D) \
				or Input.is_physical_key_pressed(KEY_SPACE):
			unlie()
			unlie_tent()
		_update_prompt()
		return
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif Input.is_physical_key_pressed(KEY_SPACE) and water_d < 0.6:
		velocity.y = JUMP_VELOCITY

	var dir := Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W):
		dir.z -= 1.0
	if Input.is_physical_key_pressed(KEY_S):
		dir.z += 1.0
	if Input.is_physical_key_pressed(KEY_A):
		dir.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		dir.x += 1.0
	_drink_cd = maxf(_drink_cd - delta, 0.0)
	promille = maxf(promille - delta * 0.005, 0.0)
	var drunk := clampf(promille / 1.5, 0.0, 1.5)
	_stumble(delta, drunk)
	if drunk > 0.0 and dir != Vector3.ZERO:
		# Torkeln: die Laufrichtung pendelt hin und her
		var t := Time.get_ticks_msec() / 1000.0
		dir = dir.rotated(Vector3.UP, sin(t * 1.1) * 0.7 * drunk + sin(t * 2.7) * 0.3 * drunk)
	dir = (transform.basis * dir).normalized()

	var want_crouch := Input.is_physical_key_pressed(KEY_C) or Input.is_physical_key_pressed(KEY_CTRL)
	if want_crouch != crouching:
		if want_crouch:
			crouching = true
		elif not test_move(global_transform, Vector3(0, 0.75, 0)):
			crouching = false      # nur aufstehen, wenn darüber Platz ist
	crouch_f = lerpf(crouch_f, 1.0 if crouching else 0.0, minf(delta * 10.0, 1.0))
	col_shape.height = lerpf(1.8, 1.1, crouch_f)
	col_node.position.y = col_shape.height / 2.0
	var sprinting := Input.is_physical_key_pressed(KEY_SHIFT) and held == null and not crouching
	var speed := SPRINT_SPEED if sprinting else WALK_SPEED
	speed *= _carry_factor()
	if crouching:
		speed *= 0.5
	speed *= 1.0 - 0.45 * water_d
	speed *= 1.0 - 0.25 * minf(drunk, 1.0)
	speed *= 1.0 - 0.4 * _aim_f
	var target := dir * speed
	if vomit_t > 0.0:
		target = Vector3.ZERO
		velocity.x = 0.0
		velocity.z = 0.0
	if drunk > 0.0 and vomit_t <= 0.0:
		# Schwammige Steuerung: die Figur reagiert verzögert
		var k := 1.0 - exp(-delta * lerpf(14.0, 2.2, minf(drunk, 1.0)))
		velocity.x = lerpf(velocity.x, target.x, k)
		velocity.z = lerpf(velocity.z, target.z, k)
	else:
		velocity.x = target.x
		velocity.z = target.z
	move_and_slide()
	_rescue_check(delta)
	fish_cast_t = maxf(fish_cast_t - delta, 0.0)
	_air_t = 0.0 if is_on_floor() else _air_t + delta
	Player.set_pants(body_visual, needs.pants if needs != null else 0)
	Player.animate_body(body_visual, Vector2(velocity.x, velocity.z).length(), crouching or (needs != null and needs.accident_t > 0.0), _air_t > 0.18, _fish_anim(), needs != null and needs.squatting, false, vape_t > 0.0, drink_kind if drink_t > 0.0 else 0, needs != null and needs.peeing)
	if is_on_floor():
		var drop := _peak_y - global_position.y
		if _airborne and drop > 5.0:
			needs.damage((drop - 5.0) * 9.0, "Du bist %d m tief gefallen." % int(drop))
		_peak_y = global_position.y
		_airborne = false
	else:
		_airborne = true
		_peak_y = maxf(_peak_y, global_position.y)
	_update_firemaking(delta)
	_update_water(delta)
	_footsteps(delta)

	_update_held()
	if placing:
		_update_placement()
	_update_prompt()


func _process(delta: float) -> void:
	if stink_t > 0.0:
		stink_t -= delta * (8.0 if water_d > 0.3 else 1.0)
		if stink_t <= 0.0:
			stink_t = 0.0
			if stink_fx != null:
				stink_fx.emitting = false
			toast("Der Gestank ist weg.", 2.5)
	_update_vm(delta)
	var t := Time.get_ticks_msec() / 1000.0
	var drunk := clampf(promille / 1.5, 0.0, 1.5)
	head.rotation.x = clampf(pitch + drink_tilt + vomit_tilt + sin(t * 0.7) * 0.06 * drunk, -1.55, 1.55)
	camera.rotation.z = sin(t * 0.9) * 0.12 * drunk + sin(t * 2.3) * 0.04 * drunk
	if shake > 0.001:
		camera.rotation.z += sin(t * 61.0) * shake * 0.03
		camera.h_offset = sin(t * 47.0) * shake * 0.012
		camera.v_offset = cos(t * 53.0) * shake * 0.012
		shake = lerpf(shake, 0.0, minf(delta * 6.0, 1.0))
	elif camera.h_offset != 0.0:
		camera.h_offset = 0.0
		camera.v_offset = 0.0
	camera.fov = 75.0 + sin(t * 0.5) * 8.0 * drunk + sin(t * 1.3) * 4.0 * trip_i - 15.0 * _aim_f
	blur_rect.visible = drunk > 0.05 and not no_screen_fx
	if blur_rect.visible:
		blur_mat.set_shader_parameter("amount", minf(drunk * 0.8, 1.0))
		blur_mat.set_shader_parameter("time_s", t)
	if Game.hour >= 19.5 and Game.hour < 22.0 and not _dark_hint:
		_dark_hint = true
		toast("Es wird dunkel. L schaltet die Kopflampe ein. Nachts beißen die Karpfen!", 6.0)
	if seat == null and hammock == null and trapped_t <= 0.0 and not sleeping and not needs.squatting:
		head.position.y = lerpf(head.position.y, 1.6 - 0.85 * water_d - 0.6 * crouch_f, minf(delta * 8.0, 1.0))
	body_visual.position.y = -0.95 * water_d
	body_visual.scale.y = 1.0 if body_visual.has_meta("ap") else 1.0 - 0.35 * crouch_f
	_help_timer -= delta
	if _help_timer <= 0.0:
		_help_timer = 0.25
		_update_help()


func _drink() -> void:
	if _drink_cd > 0.0 or placing:
		return
	if Radio.target_of(self) != null and get_parent().get("radio") != null:
		_drink_cd = 0.3
		(get_parent().radio as Radio).toggle()
		return
	if held != null and held.item_name == "Joint":
		_smoke()
		return
	var src: Object = null
	if held != null and held.drink_kind() != "":
		src = held
	else:
		var c: Object = _reach_target()
		if c != null and c.has_method("drink_kind") and c.drink_kind() != "":
			src = c
	if src == null:
		toast("Zum Trinken: Bierkasten oder Wasserflasche anschauen oder tragen, dann F.", 2.5)
		return
	var kind: String = src.drink_kind()
	if not src.take_drink():
		toast("Leer!", 2.5)
		return
	_drink_cd = 1.4
	drink_t = 1.25
	drink_kind = 1 if kind == "beer" else 2
	var msg := ""
	if kind == "beer":
		beers_drunk += 1
		Game.stat_beers += 1
		promille += 0.3
		needs.drank_beer()
		msg = _drink_message()
	else:
		water_drunk += 1
		needs.drank_water()
		promille = maxf(promille - 0.12, 0.0)
		msg = "Ahh, frisches Wasser." if promille < 0.3 else "Wasser hilft. Ein bisschen."
	Sfx.play("gulp" if kind == "water" else "bottle", Vector3.INF, -2.0)
	if kind == "beer" and promille > 1.4 and randf() < clampf((promille - 1.4) * 0.6, 0.0, 1.0):
		get_tree().create_timer(1.7).timeout.connect(start_vomit)
	if kind == "beer" and randf() < 0.3:
		get_tree().create_timer(1.2).timeout.connect(func() -> void: Sfx.play("burp", global_position, -3.0, randf_range(0.8, 1.2)))
	var tw := create_tween()
	tw.tween_property(self, "drink_tilt", 0.55, 0.35)
	tw.tween_interval(0.5)
	tw.tween_property(self, "drink_tilt", 0.0, 0.35)
	toast("%s  (noch %d)" % [msg, src.drinks_left()], 3.0)
	_update_help()


## Übergeben: kurz vornübergebeugt würgen, dann kommt es raus. Danach geht es einem besser.
func start_vomit() -> void:
	if vomit_t > 0.0 or seat != null or hammock != null or sleeping or trapped_t > 0.0 or (needs != null and needs.squatting):
		return
	vomit_t = 3.6
	Game.stat_vomit += 1
	_vomit_cd = 0.0
	toast("Oh nein ... dir wird schlecht!", 3.0)
	Sfx.play("retch", global_position, 2.0)


func _vomit_tick(delta: float) -> void:
	var before := vomit_t
	vomit_t -= delta
	if _vomit_fx == null:
		_vomit_fx = Fx.vomit_stream()
		add_child(_vomit_fx)
	var spewing := vomit_t < 2.6 and vomit_t > 0.4
	_vomit_fx.emitting = spewing
	if before >= 2.6 and vomit_t < 2.6:
		Sfx.play("vomit", global_position, 4.0)
	if spewing:
		_vomit_cd -= delta
		if _vomit_cd <= 0.0:
			_vomit_cd = 0.25
			var tp := global_position - global_transform.basis.z * 1.5
			Fx.vomit_puddle(get_parent(), Vector3(tp.x, 0.0, tp.z))
	if vomit_t <= 0.0:
		vomit_t = 0.0
		_vomit_fx.emitting = false
		promille *= 0.55
		sober_t = 90.0
		if needs != null:
			needs.hunger = minf(needs.hunger + 0.15, 1.0)
		toast("Puh ... jetzt geht es dir schon besser.", 4.0)


## Zufälliges Stolpern bei starker Trunkenheit
func _stumble(delta: float, drunk: float) -> void:
	if drunk < 0.5 or not is_on_floor():
		return
	_stumble_cd -= delta
	if _stumble_cd > 0.0:
		return
	_stumble_cd = randf_range(2.5, 6.0) / drunk
	var side := transform.basis.x * randf_range(-1.0, 1.0)
	velocity += (side * 3.0 + transform.basis.z * randf_range(-1.0, 1.0)) * drunk


func _drink_message() -> String:
	if promille < 0.5:
		return "Prost! *Zisch*"
	if promille < 1.0:
		return "Ahh, das tut gut."
	if promille < 1.5:
		return "Noch eins geht noch..."
	if promille < 2.5:
		return "Der Boden wackelt ein bisschen."
	return "Vielleicht jetzt ein Wasser?"


func _carry_factor() -> float:
	if held == null:
		return 1.0
	# Jedes Teil bremst, schwere Teile mehr (Bierkasten ca. 45 %, Grill ca. 35 %)
	return clampf(0.8 - held.weight / 40.0, 0.2, 0.8)


## Hammer in der Ego-Ansicht: sichtbare Hand mit Ärmel hält den Hammer vor dem Körper.
func _update_vm(delta: float) -> void:
	var want := USE_VM_HAMMER and held != null and held.item_name == "Hammer" and not third_person and not sleeping and not placing
	if want and vm_hand == null:
		_build_vm()
	if vm_hand != null:
		vm_hand.visible = want
		if want:
			var sp := Vector2(velocity.x, velocity.z).length()
			var t := Time.get_ticks_msec() / 1000.0
			vm_hand.position = Vector3(0.2, -0.22, -0.55) + Vector3(sin(t * 6.0) * 0.008, absf(sin(t * 6.0)) * 0.012, 0.0) * clampf(sp / 3.0, 0.0, 1.5)
			vm_hand.rotation_degrees.x = -_vm_swing * 70.0
	if USE_VM_HAMMER and held != null and held.item_name == "Hammer":
		held.visible = not want


func swing_hammer() -> void:
	if USE_VM_HAMMER:
		var tw := create_tween()
		tw.tween_property(self, "_vm_swing", 1.0, 0.1)
		tw.tween_property(self, "_vm_swing", 0.0, 0.18)
	Sfx.play("thunk", global_position - global_transform.basis.z * 1.5, 0.0, 1.4)


func _build_vm() -> void:
	vm_hand = Node3D.new()
	camera.add_child(vm_hand)
	var d: Dictionary = CHARS.get(character_name, CHARS["Julian"])
	var sleeve: Color = d["shirt"]
	# Unterarm kommt von rechts unten ins Bild
	var arm := Util.add_box(vm_hand, Vector3(0.1, 0.1, 0.5), sleeve, Vector3(0.06, -0.12, 0.32))
	arm.rotation_degrees = Vector3(-18.0, -8.0, 0.0)
	var cuff := Util.add_box(vm_hand, Vector3(0.11, 0.11, 0.05), sleeve.darkened(0.15), Vector3(0.03, -0.03, 0.06))
	cuff.rotation_degrees = Vector3(-18.0, -8.0, 0.0)
	var fist := Util.add_box(vm_hand, Vector3(0.1, 0.09, 0.1), SKIN, Vector3(0.0, 0.0, 0.0))
	fist.rotation_degrees = Vector3(-18.0, -8.0, 0.0)
	Util.add_box(vm_hand, Vector3(0.025, 0.03, 0.1), SKIN.darkened(0.08), Vector3(-0.05, 0.03, -0.02))
	var tool_holder := Node3D.new()
	tool_holder.position = Vector3(0.0, 0.0, 0.0)
	tool_holder.rotation_degrees = Vector3(-20.0, 0.0, 78.0)
	tool_holder.scale = Vector3.ONE * 1.5
	vm_hand.add_child(tool_holder)
	var hv := Node3D.new()
	hv.position = Vector3(0.15, 0.0, 0.0)    # Griffende des Stiels liegt in der Faust
	tool_holder.add_child(hv)
	ItemModels.add_visual(hv, "Hammer", Vector3(0.4, 0.12, 0.1), Color(0.45, 0.3, 0.15))
	for n in vm_hand.find_children("*", "MeshInstance3D", true, false):
		(n as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Joint rauchen: Zug für Zug, danach wird das Bild für einen Moment ganz bunt.
func _smoke() -> void:
	if _drink_cd > 0.0:
		return
	_drink_cd = 2.4
	var left: int = int(held.extra.get("puffs", 4)) - 1
	held.extra["puffs"] = left
	vape_t = 2.2
	Game.joint_smoked = true
	_update_help()
	if needs != null and needs.vape_particles != null:
		needs.vape_particles.restart()
		needs.vape_particles.emitting = true
	if Sfx.has_file("joint"):
		Sfx.play("joint", Vector3.INF, -2.0, 1.0)
	else:
		Sfx.play("whoosh", Vector3.INF, -10.0, 0.5)
	trip_t = minf(trip_t + 10.0, 24.0)
	var lines := ["Pfffff... das zieht.", "Die Farben werden... lauter.", "Alles leuchtet. Wow.", "Die Bäume atmen."]
	toast(lines[left % lines.size()] if left >= 0 else lines[0], 3.0)
	if left <= 0:
		var it := held
		_drop()
		it.queue_free()
		toast("Der Joint ist aufgeraucht. Die Welt ist bunt.", 3.5)
		_update_help()


## Stärke der Joint-Wirkung weich ein- und ausblenden; Bild wellt und leuchtet bunt.
func _update_trip(delta: float) -> void:
	if trip_t > 0.0:
		trip_t = maxf(trip_t - delta, 0.0)
	trip_i = move_toward(trip_i, 1.0 if trip_t > 0.0 else 0.0, delta * (1.1 if trip_t > 0.0 else 0.3))
	if trip_i > 0.0 and _trip_fx == null:
		_trip_fx = TripFx.new()
		add_child(_trip_fx)
	if _trip_fx != null:
		_trip_fx.set_intensity(0.0 if no_screen_fx else trip_i)


## Luftgewehr: trifft Tiere (sie fallen um) und Mitspieler (verletzt sie).
func _shoot() -> void:
	if _gun_cd > 0.0 or placing or held == null or _reload_t > 0.0:
		return
	var ammo := int(held.extra.get("ammo", GUN_MAG))
	if ammo <= 0:
		_gun_cd = 0.35
		Sfx.play("click", global_position, -2.0, 0.8)
		toast("Magazin leer - R: nachladen", 1.5)
		return
	held.extra["ammo"] = ammo - 1
	_gun_cd = 0.6
	_gun_kick = 1.0
	var spr := lerpf(0.012, 0.0015, _aim_f)
	var cb := camera.global_transform.basis
	var origin := camera.global_position
	var dir := (-cb.z + cb.x * randf_range(-spr, spr) + cb.y * randf_range(-spr, spr)).normalized()
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(origin, origin + dir * 120.0)
	q.exclude = [get_rid(), held.get_rid()]
	var hit := space.intersect_ray(q)
	var end := origin + dir * 120.0
	var best := 120.0
	if not hit.is_empty():
		end = hit["position"]
		best = origin.distance_to(end)
	var target_animal: Object = null
	var target_name := ""
	var dmg := 0.0
	var fauna := get_parent().get_node_or_null("Fauna")
	if fauna != null:
		for a in fauna.animals:
			if not is_instance_valid(a) or a.dead:
				continue
			var c: Vector3 = a.global_position + Vector3(0, a.hit_center_y(), 0)
			var t := (c - origin).dot(dir)
			if t > 0.5 and t < best and (origin + dir * t).distance_to(c) < a.hit_radius():
				best = t
				target_animal = a
				target_name = ""
	if Net.instance != null:
		for k in Net.instance.avatars.keys():
			var av: Node3D = Net.instance.avatars[k]
			if not is_instance_valid(av) or not av.visible or av.get("label") == null:
				continue
			for h in [0.35, 0.95, 1.55]:
				var c2: Vector3 = av.global_position + Vector3(0, h, 0)
				var t2 := (c2 - origin).dot(dir)
				if t2 > 0.5 and t2 < best and (origin + dir * t2).distance_to(c2) < 0.34:
					best = t2
					target_animal = null
					target_name = (av.label as Label3D).text
					dmg = 35.0 if h > 1.4 else 16.0
	end = origin + dir * best
	var muzzle := origin + dir * 0.7 + cb.x * 0.2 - cb.y * 0.18
	Sfx.play("airgun", muzzle, 0.0)
	Fx.tracer(get_parent(), muzzle, end)
	if Net.instance != null:
		Net.instance.send_shot(muzzle, end)
	pitch = clampf(pitch + 0.025, -1.45, 1.45)
	head.rotation.x = pitch
	shake = maxf(shake, 0.9)
	if target_animal != null:
		var an: Object = target_animal
		toast("%s getroffen!" % an.display_name(), 2.0)
		var ak: String = an.kind
		var apos: Vector3 = an.global_position
		an.die()
		if Net.instance != null:
			Net.instance.send_kill(ak, apos)
	elif target_name != "":
		Net.instance.send_hit(target_name, dmg, Game.player_name)
		toast("Treffer: %s%s" % [target_name, " (Kopf!)" if dmg > 20.0 else ""], 2.0)
		Sfx.play("thunk", Vector3.INF, -4.0, 1.6)


func _reload() -> void:
	if held == null or held.item_name != "Luftgewehr" or _reload_t > 0.0:
		return
	if int(held.extra.get("ammo", GUN_MAG)) >= GUN_MAG:
		toast("Magazin ist voll (%d/%d)" % [GUN_MAG, GUN_MAG], 1.5)
		return
	_reload_t = GUN_RELOAD
	_gun_cd = maxf(_gun_cd, GUN_RELOAD)
	Sfx.play("reload", global_position, -2.0)
	toast("Nachladen...", GUN_RELOAD)
	var weak: WeakRef = weakref(held)
	get_tree().create_timer(GUN_RELOAD).timeout.connect(func() -> void:
		var o: Object = weak.get_ref()
		if o != null and held == o:
			(o as Item).extra["ammo"] = GUN_MAG
			toast("Geladen: %d/%d" % [GUN_MAG, GUN_MAG], 1.5))


func _update_held() -> void:
	if held == null:
		return
	var forward := -head.global_transform.basis.z
	var target := head.global_position + forward * (1.6 + held.hold_extra) + Vector3(0, -0.3, 0)
	var diff := target - held.global_position
	if diff.length() > 4.0:
		_drop()
		return
	held.linear_velocity = (diff * 12.0).limit_length(14.0)
	held.angular_velocity *= 0.8
	if held.item_name == "Joint":
		# Joint hängt zwischen den Fingern rechts unten im Bild, Glut zeigt nach oben-vorn
		var jb := head.global_transform.basis
		var jt := head.global_position + (-jb.z) * 0.5 + jb.x * 0.14 - jb.y * 0.13
		held.linear_velocity = ((jt - held.global_position) * 20.0).limit_length(20.0)
		held.angular_velocity = Vector3.ZERO
		held.global_transform.basis = jb * Basis.from_euler(Vector3(0.0, deg_to_rad(-30.0), deg_to_rad(50.0)))
	elif held.item_name == "Luftgewehr":
		# Gewehr liegt rechts unten im Bild und zeigt immer dorthin, wohin man schaut
		var hb := head.global_transform.basis
		var hip := head.global_position + (-hb.z) * 0.85 + hb.x * 0.3 - hb.y * 0.28
		var ads := head.global_position + (-hb.z) * 0.52 - hb.y * GUN_SIGHT_Z
		var gt := hip.lerp(ads, _aim_f)
		gt += hb.z * 0.05 * _gun_kick
		var gb := hb.rotated(hb.x, 0.05 * _gun_kick)
		if _reload_t > 0.0:
			var rp := sin((1.0 - _reload_t / GUN_RELOAD) * PI)
			gt += -hb.y * 0.22 * rp - hb.x * 0.08 * rp
			gb = gb.rotated(hb.z, 0.5 * rp)
		held.linear_velocity = ((gt - held.global_position) * 20.0).limit_length(20.0)
		held.angular_velocity = Vector3.ZERO
		held.global_transform.basis = gb


## Das Objekt, auf das man zielt, wenn es nah genug ist (sonst null).
func _reach_target() -> Object:
	if not ray.is_colliding():
		return null
	if head.global_position.distance_to(ray.get_collision_point()) > REACH:
		return null
	return ray.get_collider()


func _update_prompt() -> void:
	if Game.camp_name != _last_camp:
		_last_camp = Game.camp_name
		_update_help()

	var text := ""
	if fire_bowl != null:
		text = "E: Funken schlagen (im grünen Feld!)"
	elif sleeping:
		text = "Zzz..."
	elif placing:
		text = "%s platzieren: E / Klick bestätigen · Mausrad drehen · R abbrechen" % ("Zelt" if not place_item else held.item_name)
		if not ghost_valid:
			text += "\n(%s)" % ghost_reason
	else:
		var c: Object = _reach_target()
		if seat != null:
			text = "Zum Aufstehen: E oder WASD"
		elif held != null:
			text = "E: %s ablegen   G: werfen" % held.item_name
			if held.item_name == "Zeltpaket":
				text += "   R: Zelt aufstellen"
			elif held.item_name == "Luftgewehr":
				text += "   LINKS: schießen  RECHTS: zielen  R: nachladen [%d/%d]" % [int(held.extra.get("ammo", GUN_MAG)), GUN_MAG]
			elif held.item_name == "Joint":
				text += "   F: rauchen (%d Züge)" % int(held.extra.get("puffs", 4))
			elif held.item_name == "Radio":
				text += "   F: an/aus   Z: Sender  +/-: Lautstärke  [%s]" % (Radio.station_name() if Radio.on else "aus")
			elif held.item_name != "Hammer":
				text += "   R: aufstellen"
			if held.drink_kind() == "beer":
				text += "   F: Bier trinken (%d übrig)" % held.drinks_left()
			elif held.drink_kind() == "water":
				text += "   F: Wasser trinken (%d Schluck)" % held.drinks_left()
			if c != null and c.has_method("get_held_prompt"):
				var hp: String = c.get_held_prompt(held)
				if hp != "":
					text = hp
		elif c != null and c.has_method("get_prompt"):
			text = c.get_prompt()
	prompt_label.text = text
	if hud != null:
		hud.set_prompt(text)


func _interact() -> void:
	if placing:
		_confirm_placement()
		return
	if trapped_t > 0.0:
		trapped_t -= 0.8
		Sfx.play("click", global_position, -4.0)
		if trapped_t <= 0.0:
			free_from_trap()
		else:
			toast("Du windest dich... (noch %d)" % int(ceil(trapped_t / 0.8)), 1.0)
		return
	if fire_bowl != null:
		strike()
		return
	if stir_oven != null:
		stir_oven.stir_press(self)
		return
	if seat != null:
		stand_up()
		return
	if hammock != null:
		unlie()
		return
	if tent_lying != null:
		unlie_tent()
		return
	var c: Object = _reach_target()
	if held != null:
		if c != null and c.has_method("interact_with_held") and c.interact_with_held(self, held):
			return
		_drop()
		return
	if c != null and c.has_method("interact"):
		c.interact(self)


## Ein Mitspieler war schneller: der Gegenstand wandert aus meiner Hand.
func lose_held(item: Item) -> void:
	if held != item:
		return
	ray.remove_exception(item)
	held = null
	toast("%s war schneller." % item.item_name, 2.5)
	_update_help()


func pick_up(item: Item) -> void:
	if held != null:
		return
	held = item
	if item.remote:
		item.take_local()
	if Net.instance != null:
		Net.instance.item_grab(item)
	Sfx.play("pop", Vector3.INF, -6.0)
	item.gravity_scale = 0.0
	item.add_collision_exception_with(self)
	ray.add_exception(item)
	_update_help()


func _skip_stone() -> void:
	if stones <= 0:
		return
	var tgt: Vector3 = fisher.aim_point()
	stones -= 1
	var start := head.global_position + Vector3(0, -0.3, 0)
	Sfx.play("whoosh", global_position, -6.0, 1.6)
	if tgt == Vector3.INF:
		toast("Du wirfst den Stein weg. (Auf den See zielen zum Flitschen)  Steine: %d" % stones, 2.5)
		return
	var hops := randi_range(1, 7) + (1 if promille < 0.5 else 0)
	for i in range(hops):
		var f := float(i + 1) / float(hops + 1)
		var p := start.lerp(tgt, 0.25 + 0.75 * f)
		p.y = 0.05
		get_tree().create_timer(0.25 + i * 0.18).timeout.connect(func() -> void: Sfx.play("splash_small", p, -4.0, 1.5 - f * 0.5))
	var msg := "Plitsch! %d Hüpfer." % hops
	if hops >= 6:
		msg = "WAHNSINN! %d Hüpfer - Rekord!" % hops
	toast(msg + "  Steine: %d" % stones, 3.0)


func _throw() -> void:
	if placing:
		return
	if held == null:
		_skip_stone()
		return
	var forward := -head.global_transform.basis.z
	_drop(forward * clampf(10.0 - held.weight * 0.4, 2.0, 8.0))


## Der gehaltene Gegenstand wandert in einen Behälter (wird danach freigegeben).
func release_held_for_storage() -> void:
	if held == null:
		return
	ray.remove_exception(held)
	held = null
	_update_help()


func _drop(impulse: Vector3 = Vector3.ZERO) -> void:
	if held == null:
		return
	if placing:
		_cancel_placement()
	var it := held
	held = null
	ray.remove_exception(it)
	it.gravity_scale = 1.0
	it.linear_velocity = impulse
	if Net.instance != null:
		Net.instance.item_release(it)
	var weak: WeakRef = weakref(it)
	get_tree().create_timer(0.6).timeout.connect(func() -> void:
		var o: Object = weak.get_ref()
		if o != null:
			(o as Item).remove_collision_exception_with(self)
	)
	_update_help()


# ---------- Zelt platzieren ----------

func _start_placement() -> void:
	if held == null or seat != null:
		return
	if Game.INGREDIENT_COLORS.has(held.item_name) or held.item_name.ends_with("kg") or held.item_name == "Feuerstahl":
		toast("Das kannst du nicht aufstellen.", 2.0)
		return
	if held.item_name == "Hängematte":
		toast("Die Hängematte hängst du an zwei Bäumen im Lager auf: vor einen der dicken Bäume stellen, E.", 4.0)
		return
	if held.item_name == "Hammer":
		toast("Den Hammer brauchst du für die Zeltheringe - der bleibt in der Hand.", 3.0)
		return
	if held.item_name == "Joint" or held.item_name == "Luftgewehr" or held.item_name == "Radio":
		toast("Das stellt man nicht auf - einfach in der Hand behalten.", 2.5)
		return
	if not Game.camp_claimed and held.item_name != "Zeltpaket":
		toast("Stell zuerst das Zelt auf - dort ist dann dein Lager (Angelplatz ist überall).", 4.0)
		return
	if held.item_name != "Zeltpaket":
		_start_item_placement()
		return
	place_item = false
	placing = true
	held.visible = false
	held.collision_layer = 0
	held.collision_mask = 0
	ghost = Tent.new()
	get_parent().add_child(ghost)
	ghost.build_ghost()
	ghost.visible = false
	ghost_valid = false


func _cancel_placement() -> void:
	placing = false
	place_item = false
	item_snap = null
	if item_ghost != null:
		item_ghost.queue_free()
		item_ghost = null
	if ghost != null:
		ghost.queue_free()
		ghost = null
	if held != null:
		held.visible = true
		held.collision_layer = 1
		held.collision_mask = 1


func _update_placement() -> void:
	if place_item:
		_update_item_placement()
		return
	ghost_valid = false
	ghost_reason = "Ziele auf den Boden"
	if ray.is_colliding():
		var c := ray.get_collider() as Node
		var p := ray.get_collision_point()
		if c != null and (c.is_in_group("ground") or c is Pickup):
			ghost.visible = true
			ghost.global_position = p
			var d := Vector2(p.x - Game.camp_center.x, p.z - Game.camp_center.z).length()
			var in_water := false
			var mn := get_parent()
			if mn.get("lake_root") != null:
				var lq: Vector3 = p - (mn.lake_root as Node3D).global_position
				in_water = LakeShape.contains(Vector2(lq.x, lq.z))
			if head.global_position.distance_to(p) > 7.5:
				ghost_reason = "zu weit weg"
			elif in_water:
				ghost_reason = "nicht im Wasser"
			elif Game.camp_claimed and d > Game.camp_radius:
				ghost_reason = "außerhalb des Lagerbereichs (grüner Ring)"
			else:
				ghost_valid = true
				for t in Game.tents:
					if t.global_position.distance_to(p) < 3.6:
						ghost_valid = false
						ghost_reason = "zu nah am anderen Zelt"
	ghost.set_ghost_valid(ghost_valid)


func _confirm_placement() -> void:
	if not ghost_valid:
		toast(ghost_reason, 2.0)
		return
	if place_item:
		_confirm_item_placement()
		return
	var item := held
	held = null
	ray.remove_exception(item)
	item.queue_free()
	placing = false
	if not Game.camp_claimed:
		Game.claim_camp(ghost.global_position, get_parent())
		toast("Hier ist jetzt euer Lager (grüner Ring)!", 3.0)
	ghost.begin_site()
	Game.tents.append(ghost)
	ghost = null
	toast("Zelt ausgelegt! Hammer in die Hand nehmen und die 4 Heringe einschlagen (je 3x E).", 6.0)
	_update_help()


# ---------- Gegenstände aufstellen ----------

func _rotate_ghost(a: float) -> void:
	if place_item and item_ghost != null:
		item_ghost.rotation.y += a
	elif ghost != null:
		ghost.rotation.y += a


func _start_item_placement() -> void:
	place_item = true
	placing = true
	held.visible = false
	held.collision_layer = 0
	held.collision_mask = 0
	var psize := ItemModels.placed_size(held.item_name, held.item_size)
	if held.item_name == "Campingstühle":
		psize = Vector3(1.8, 0.95, 0.5)
	item_ghost = Node3D.new()
	get_parent().add_child(item_ghost)
	item_ghost_mat = StandardMaterial3D.new()
	item_ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	item_ghost_mat.albedo_color = Color(0.3, 1.0, 0.3, 0.45)
	# Blaupause = das echte aufgestellte Modell, durchsichtig eingefärbt (man erkennt vorne/hinten)
	var holder := Node3D.new()
	holder.position.y = psize.y / 2.0
	item_ghost.add_child(holder)
	ItemModels.add_placed_visual(holder, held.item_name, psize, held.item_color)
	for n in holder.find_children("*", "", true, false):
		if n is MeshInstance3D:
			(n as MeshInstance3D).material_override = item_ghost_mat
			(n as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		elif n is Light3D or n is CPUParticles3D or n is GPUParticles3D:
			n.queue_free()
	if holder.get_child_count() == 0:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = psize
		mi.mesh = bm
		mi.material_override = item_ghost_mat
		holder.add_child(mi)
	item_ghost.visible = false
	ghost_valid = false


func _update_item_placement() -> void:
	ghost_valid = false
	item_snap = null
	ghost_reason = "Ziele auf den Boden im Lagerbereich"
	if ray.is_colliding():
		var c := ray.get_collider() as Node
		var p := ray.get_collision_point()
		if held.item_name == "Dutch Oven" and c is PlacedItem and (c as PlacedItem).item_name == "Gasgrill":
			var g := c as PlacedItem
			if g.oven != null:
				ghost_reason = "Auf dem Grill steht schon ein Topf"
			elif head.global_position.distance_to(g.global_position) < 7.5:
				item_snap = g
				var psize := ItemModels.placed_size(held.item_name, held.item_size)
				item_ghost.visible = true
				item_ghost.global_position = g.global_position + Vector3(0, ItemModels.GRILL_TOP + 0.15 - psize.y / 2.0, 0)
				ghost_valid = true
		elif c != null and (c.is_in_group("ground") or c is Pickup):
			item_ghost.visible = true
			item_ghost.global_position = p
			var d := Vector2(p.x - Game.camp_center.x, p.z - Game.camp_center.z).length()
			if head.global_position.distance_to(p) > 7.5:
				ghost_reason = "zu weit weg"
			elif d > Game.camp_radius:
				ghost_reason = "außerhalb des Lagerbereichs (grüner Ring)"
			else:
				ghost_valid = true
				for t in Game.tents:
					if t.global_position.distance_to(p) < 2.6:
						ghost_valid = false
						ghost_reason = "zu nah am Zelt"
				for o in Game.placed:
					if is_instance_valid(o) and (o as Node3D).global_position.distance_to(p) < 1.1:
						ghost_valid = false
						ghost_reason = "da steht schon etwas"
	item_ghost_mat.albedo_color = Color(0.3, 1.0, 0.3, 0.45) if ghost_valid else Color(1.0, 0.25, 0.25, 0.45)


func _spawn_placed(p_name: String, weight: float, size: Vector3, color: Color, pos: Vector3, yaw: float, state: Dictionary) -> PlacedItem:
	var p := PlacedItem.new()
	get_parent().add_child(p)
	p.build(p_name, weight, size, color, state)
	p.global_position = pos
	p.rotation.y = yaw
	Game.placed.append(p)
	Sfx.play("crate" if p_name == "Bierkasten" else "thunk", pos, 2.0 if p_name == "Bierkasten" else 0.0)
	if Net.instance != null:
		Net.instance.send_placed(p, state)
	return p


func _confirm_item_placement() -> void:
	var it := held
	var pos := item_ghost.global_position
	var yaw := item_ghost.rotation.y
	var snap := item_snap
	var state := {}
	if it.item_name == "Bierkasten":
		state["beers"] = it.beers_left()
	if it.item_name == "Wasserflasche":
		state["water"] = it.water_left
	if it.extra.has("wood"):
		state["wood"] = it.extra["wood"]
	if it.extra.has("pack"):
		state["pack"] = it.extra["pack"]
	if it.extra.has("contents"):
		state["contents"] = it.extra["contents"]
	if it.extra.has("fish"):
		state["fish"] = it.extra["fish"]
	if it.item_name == "Campingstühle":
		var right := Vector3(cos(yaw), 0, -sin(yaw))
		for sgn in [-1.0, 0.0, 1.0]:
			_spawn_placed("Campingstuhl", it.weight / 3.0, Vector3(0.3, 0.9, 0.5), it.item_color, pos + right * 0.6 * sgn, yaw, {})
	else:
		var placed := _spawn_placed(it.item_name, it.weight, it.item_size, it.item_color, pos, yaw, state)
		if snap != null:
			snap.oven = placed
			placed.on_grill = snap
	var nm := it.item_name
	if nm == "Bierkasten" and Game.beer_debt:
		var in_camp := not Game.camp_claimed or Vector2(pos.x - Game.camp_center.x, pos.z - Game.camp_center.z).length() < 25.0
		if in_camp and not (absf(pos.x) < 27.0 and pos.z > -22.0 and pos.z < 30.0 and not Game.camp_claimed):
			Game.beer_debt = false
			toast("Das Bier steht im Camp - du darfst wieder angeln!", 5.0)
	held = null
	ray.remove_exception(it)
	it.queue_free()
	_cancel_placement()
	toast("%s aufgestellt. (X zum Abbauen)" % nm, 3.0)
	_update_help()


func _dismantle() -> void:
	if placing or seat != null:
		return
	if held != null:
		toast("Hände voll - erst ablegen.", 2.0)
		return
	var c: Object = _reach_target()
	if c != null and c.has_method("dismantle"):
		c.dismantle(self)


# ---------- Sitzen ----------

func sit(chair: PlacedItem) -> void:
	if seat != null or chair.seated_by != null:
		return
	if held != null:
		toast("Hände voll - erst ablegen.", 2.0)
		return
	seat = chair
	chair.seated_by = self
	collision_layer = 0
	collision_mask = 0
	global_position = chair.global_position + Vector3(0, 0.45, 0)
	head.position.y = 0.65
	toast("Du sitzt. E oder WASD zum Aufstehen.", 2.5)


func free_from_trap() -> void:
	trapped_t = 0.0
	trap_head = 1.6
	head.position.y = 1.6
	toast("Frei! Ab jetzt aufpassen, wohin du trittst.", 3.0)


func lie(h: Hammock) -> void:
	if hammock != null or seat != null:
		return
	if held != null:
		toast("Hände voll - erst ablegen.", 2.0)
		return
	hammock = h
	h.occupant = self
	collision_layer = 0
	collision_mask = 0
	global_position = h.lie_pos()
	head.position.y = 0.45
	toast("Du liegst in der Hängematte und baumelst. Gesundheit erholt sich. E oder WASD: aufstehen.", 4.0)


func is_lying() -> bool:
	return hammock != null or tent_lying != null


## Multiplayer: im Zelt hinlegen, die Nacht wird übersprungen sobald alle liegen.
func lie_in_tent(tent: Tent) -> void:
	if is_lying() or seat != null or sleeping:
		return
	if held != null and held.item_name != "Angelrute":
		_drop()
	tent_lying = tent
	collision_layer = 0
	collision_mask = 0
	teleport_to(tent.global_position + Vector3(0, 0.2, 0))
	head.position.y = 0.35
	toast("Du liegst im Zelt. Die Nacht vergeht, sobald ALLE im Zelt oder in der Hängematte liegen. E oder WASD: aufstehen.", 5.0)


func unlie_tent() -> void:
	if tent_lying == null:
		return
	var t := tent_lying
	tent_lying = null
	if is_instance_valid(t):
		global_position = t.global_transform * Vector3(0, 0.1, 2.1)
	head.position.y = 1.6
	collision_layer = 1
	collision_mask = 1


## Alle liegen: die Nacht ist vorbei (vom Host ausgelöst).
func night_skipped() -> void:
	var was_tent := tent_lying != null
	if hammock != null:
		unlie()
	unlie_tent()
	Game.slept = true
	if needs != null:
		needs.hunger = minf(needs.hunger + 0.2, 1.0)
		needs.bladder = minf(needs.bladder + 0.3, 1.0)
		needs.health = minf(needs.health + 25.0, 100.0)
	promille = maxf(promille - 0.8, 0.0)
	fade_rect.color.a = 1.0
	create_tween().tween_property(fade_rect, "color:a", 0.0, 1.5)
	toast("Alle schlafen - die Nacht wird übersprungen. Guten Morgen! Tag %d, %s Uhr." % [Game.day_count, Game.clock_text()], 5.0)


func unlie() -> void:
	if hammock == null:
		return
	var h := hammock
	hammock = null
	if is_instance_valid(h):
		h.occupant = null
		global_position = h.global_position + Vector3(0, 0.1, 1.2)
	head.position.y = 1.6
	collision_layer = 1
	collision_mask = 1


func stand_up() -> void:
	if seat == null:
		return
	var chair := seat
	seat = null
	if is_instance_valid(chair):
		chair.seated_by = null
		var fwd := -transform.basis.z
		global_position = chair.global_position + fwd * 0.9 + Vector3(0, 0.1, 0)
	head.position.y = 1.6
	collision_layer = 1
	collision_mask = 1


# ---------- Neue Fähigkeiten ----------

## Setzt den Spieler um und nimmt den getragenen Gegenstand mit.
var _repair_step: int = 0
var no_screen_fx: bool = false


## F4: Bildfehler beheben. Jeder Druck schaltet einen weiteren Verdaechtigen aus.
func repair_view() -> void:
	var m := get_parent()
	var env: Environment = m.get("env") as Environment
	_repair_step += 1
	match _repair_step:
		1:
			if env != null:
				env.glow_enabled = false
			toast("F4 (1): Glühen aus.", 3.0)
		2:
			no_screen_fx = true
			blur_rect.visible = false
			if _trip_fx != null:
				_trip_fx.rect.visible = false
			toast("F4 (2): Unschärfe- und Rausch-Effekte aus.", 3.0)
		3:
			Weather.flash = 0.0
			Weather.fog = 0.0
			Weather.rain = 0.0
			if env != null:
				env.fog_enabled = false
				env.adjustment_enabled = false
				env.tonemap_exposure = 0.82
			toast("F4 (3): Nebel, Farbkorrektur, Blitzlicht zurückgesetzt.", 3.0)
		_:
			_repair_step = 0
			get_viewport().scaling_3d_scale = 1.0
			toast("F4 (4): Bildauflösung zurückgesetzt. Nochmal F4 beginnt von vorn.", 3.0)


var _safe_pos: Vector3 = Vector3(0, 1.0, 10)
var _safe_t: float = 0.0


## Notfall: durch den Boden gefallen (man sieht dann nur noch Himmel) -> zurueck zum letzten sicheren Ort.
func _rescue_check(delta: float) -> void:
	if is_on_floor() and global_position.y > -0.5 and is_finite(global_position.y):
		_safe_t += delta
		if _safe_t > 1.0:
			_safe_t = 0.0
			_safe_pos = global_position + Vector3(0, 0.3, 0)
	if global_position.y < -1.2 or not is_finite(global_position.y) or not is_finite(global_position.x) or not is_finite(global_position.z):
		teleport_to(_safe_pos)
		_peak_y = _safe_pos.y
		_airborne = false
		toast("Du bist durch den Boden gefallen - zurück an den letzten sicheren Ort.", 4.0)


func teleport_to(pos: Vector3) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	if held != null:
		held.global_position = pos + Vector3(0, 1.2, -1.2)
		held.linear_velocity = Vector3.ZERO


func consume_held() -> void:
	if held == null:
		return
	var it := held
	held = null
	ray.remove_exception(it)
	it.queue_free()
	_update_help()


func respawn() -> void:
	if held != null:
		_drop()
	if seat != null:
		stand_up()
	if hammock != null:
		unlie()
	teleport_to(Vector3(0, 1.0, 10))
	_peak_y = 1.0
	_airborne = false


const STRIKE_NEEDED: int = 4

var strike_pos: float = 0.0
var strike_dir: float = 1.0
var strike_hits: int = 0
var strike_combo: int = 0
var strike_zone_w: float = 0.13
var strike_zone_x: float = 0.5
var strike_zone_dir: float = 1.0
var strike_flash: float = 0.0
var strike_flash_good: bool = true
var _strike_speed: float = 1.0
var _ember_t: float = 0.0
var _ember_light: OmniLight3D = null
var minihud: MiniHud = null
var stir_oven: PlacedItem = null


func get_minihud() -> MiniHud:
	if minihud == null:
		minihud = MiniHud.new()
		help_label.get_parent().add_child(minihud)
	return minihud


func start_firemaking(bowl: PlacedItem) -> void:
	if fire_bowl != null:
		return
	fire_bowl = bowl
	fire_t = 0.0
	strike_hits = 0
	strike_combo = 0
	strike_pos = 0.0
	strike_dir = 1.0
	strike_flash = 0.0
	_ember_t = 0.0
	_curses_done = 0
	strike_zone_w = 0.15 * (0.8 if character_name == "Marian" else 1.0)   # Marian: 20 % schwieriger
	_strike_speed = 0.9
	_new_strike_zone()
	get_minihud().card("FEUERSTAHL!", "E drücken, wenn der Strich im grünen Feld ist", UI.FIRE, 2.2)
	if _ember_light == null:
		_ember_light = OmniLight3D.new()
		_ember_light.light_color = Color(1.0, 0.5, 0.15)
		_ember_light.omni_range = 3.5
		_ember_light.light_energy = 0.0
		get_parent().add_child(_ember_light)
	_ember_light.global_position = bowl.global_position + Vector3(0, 0.5, 0)
	_ember_light.light_energy = 0.0
	_update_strike_ui()
	if sparks == null:
		sparks = CPUParticles3D.new()
		sparks.amount = 40
		sparks.lifetime = 0.6
		sparks.one_shot = false
		sparks.direction = Vector3(0, 1, 0)
		sparks.spread = 70.0
		sparks.initial_velocity_min = 1.0
		sparks.initial_velocity_max = 3.2
		sparks.gravity = Vector3(0, -6, 0)
		var m := SphereMesh.new()
		m.radius = 0.015
		m.height = 0.03
		m.radial_segments = 4
		m.rings = 2
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(1.0, 0.8, 0.3)
		m.material = mat
		sparks.mesh = m
		get_parent().add_child(sparks)
	sparks.global_position = bowl.global_position + Vector3(0, 0.45, 0)
	sparks.emitting = false


func _new_strike_zone() -> void:
	strike_zone_x = randf_range(0.1, 0.9 - strike_zone_w)
	strike_zone_dir = 1.0 if randf() < 0.5 else -1.0


func _update_strike_ui() -> void:
	var h := get_minihud()
	h.kind = "fire"
	h.d = {"pos": strike_pos, "dir": strike_dir, "zone_x": strike_zone_x, "zone_w": strike_zone_w, "hits": strike_hits,
		"needed": STRIKE_NEEDED, "combo": strike_combo, "flash": strike_flash, "flash_good": strike_flash_good}


## E während des Funkenschlagens: trifft der Strich das grüne Feld?
func strike() -> void:
	if fire_bowl == null:
		return
	var h := get_minihud()
	var in_zone := strike_pos >= strike_zone_x and strike_pos <= strike_zone_x + strike_zone_w
	_ember_t = 0.0
	strike_flash = 1.0
	if in_zone:
		strike_flash_good = true
		var centre := absf(strike_pos - (strike_zone_x + strike_zone_w * 0.5)) < strike_zone_w * 0.18
		Sfx.play("spark", global_position, -2.0)
		strike_hits += 1
		strike_combo += 1
		shake = 1.6
		sparks.amount = 40 + strike_hits * 10
		sparks.emitting = true
		get_tree().create_timer(0.4).timeout.connect(func() -> void:
			if sparks != null:
				sparks.emitting = false)
		h.burst(Vector2(h.size.x / 2.0 + (strike_pos - 0.5) * 520.0, h.size.y * 0.72), Color(1.0, 0.8, 0.3), 16 + strike_combo * 4, 300.0)
		h.flash(Color(1.0, 0.6, 0.15, 0.45))
		if centre:
			h.card("VOLLTREFFER!", "", Color(1.0, 0.9, 0.3), 0.7)
			Sfx.play("ding", Vector3.INF, -8.0)
		_strike_speed += 0.22
		strike_zone_w = maxf(strike_zone_w * 0.9, 0.07)
		_new_strike_zone()
		if _ember_light != null:
			_ember_light.light_energy = float(strike_hits) * 0.9
		if strike_hits >= STRIKE_NEEDED:
			var bowl := fire_bowl
			_stop_firemaking()
			bowl.ignite(self)
			shake = 2.5
			h.card("DAS FEUER BRENNT!", "Holzscheit vom Bündel (E) holen und ins Feuer legen (E)", Color(1.0, 0.7, 0.2), 4.0)
			h.burst(h.size / 2.0, Color(1.0, 0.6, 0.15), 50, 450.0)
			h.flash(Color(1.0, 0.5, 0.1, 0.8))
			return
	else:
		strike_flash_good = false
		strike_combo = 0
		Sfx.play("click", global_position, -2.0)
		strike_hits = maxi(strike_hits - 1, 0)
		_strike_speed = maxf(_strike_speed - 0.12, 0.9)
		h.flash(Color(1.0, 0.2, 0.15, 0.4))
		if _ember_light != null:
			_ember_light.light_energy = float(strike_hits) * 0.9
		if character_name == "Marian":
			var curses := ["Verdammte Axt!", "Scheiße, warum zündet das nicht?!", "Komm schon, du blödes Ding!", "Himmel, Arsch und Zwirn!"]
			toast("Marian: " + curses.pick_random(), 2.0)
	_update_strike_ui()


func _stop_firemaking() -> void:
	fire_bowl = null
	if sparks != null:
		sparks.emitting = false
	if _ember_light != null:
		var l := _ember_light
		var tw := create_tween()
		tw.tween_property(l, "light_energy", 0.0, 0.8)
	if minihud != null and minihud.kind == "fire":
		minihud.clear()


func _update_firemaking(delta: float) -> void:
	if fire_bowl == null:
		return
	if not is_instance_valid(fire_bowl) or held == null or held.item_name != "Feuerstahl" \
			or global_position.distance_to(fire_bowl.global_position) > 4.5:
		toast("Abgebrochen.", 1.5)
		_stop_firemaking()
		return
	fire_t += delta
	strike_flash = maxf(strike_flash - delta * 3.0, 0.0)
	strike_pos += strike_dir * _strike_speed * delta
	if strike_pos >= 1.0:
		strike_pos = 1.0
		strike_dir = -1.0
	elif strike_pos <= 0.0:
		strike_pos = 0.0
		strike_dir = 1.0
	# Das Zielfeld wandert ab dem zweiten Treffer hin und her
	if strike_hits >= 1:
		strike_zone_x += strike_zone_dir * (0.12 + 0.06 * strike_hits) * delta
		if strike_zone_x <= 0.05:
			strike_zone_x = 0.05
			strike_zone_dir = 1.0
		elif strike_zone_x + strike_zone_w >= 0.95:
			strike_zone_x = 0.95 - strike_zone_w
			strike_zone_dir = -1.0
	# Die Glut erlischt, wenn man zu lange trödelt
	if strike_hits > 0:
		_ember_t += delta
		if _ember_t > 6.0:
			_ember_t = 0.0
			strike_hits -= 1
			strike_combo = 0
			if _ember_light != null:
				_ember_light.light_energy = float(strike_hits) * 0.9
			get_minihud().flash(Color(0.6, 0.6, 0.7, 0.4))
			toast("Die Glut wird kalt ...", 1.5)
	_update_strike_ui()


# ---------- Schlafen ----------

func sleep(tent: Tent) -> void:
	if sleeping:
		return
	if held != null and held.item_name != "Angelrute":
		_drop()
	sleeping = true
	var tw := create_tween()
	tw.tween_property(fade_rect, "color:a", 1.0, 1.0)
	await tw.finished
	teleport_to(tent.global_position + Vector3(0, 0.2, 0))
	var start := Game.hour
	var total := fposmod(6.5 - start, 24.0)
	var dur := 6.0
	var bite_at := -1.0
	if fisher.state == Fisher.S.WAITING and fisher.mode == 0 and randf() < 0.7:
		bite_at = randf_range(0.3, 0.85)
	var rustle_at := randf_range(0.15, 0.7) if randf() < 0.5 else -1.0
	var elapsed := 0.0
	var by_fish := false
	var prev := start
	while elapsed < dur:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		var f := minf(elapsed / dur, 1.0)
		var nh := fposmod(start + total * f, 24.0)
		if nh < prev:
			Game.day_count += 1
		prev = nh
		Game.hour = nh
		if rustle_at >= 0.0 and f >= rustle_at:
			rustle_at = -1.0
			get_parent().call("spawn_nutria_at", tent.global_position)
			toast("Zzz... Etwas raschelt am Zelt.", 3.0)
		if bite_at >= 0.0 and f >= bite_at:
			if fisher.bite_during_sleep():
				by_fish = true
				break
			bite_at = -1.0
	if not by_fish:
		Game.hour = 6.5
	teleport_to(tent.global_transform * Vector3(0, 0.1, 2.1))
	_peak_y = global_position.y
	sleeping = false
	var tw2 := create_tween()
	tw2.tween_property(fade_rect, "color:a", 0.0, 1.0)
	Game.slept = true
	if Net.instance == null and get_parent().get("weather") != null:
		(get_parent().weather as Weather).set_kind(Weather.K.CLEAR, false)   # Wie in Minecraft: Schlafen vertreibt das Wetter
	needs.hunger = minf(needs.hunger + 0.2, 1.0)
	needs.bladder = minf(needs.bladder + 0.3, 1.0)
	needs.health = minf(needs.health + (10.0 if tent.smelly else 30.0), 100.0)
	promille = maxf(promille - 0.8, 0.0)
	if by_fish:
		toast("BISSANZEIGER! Ein Fisch hat angebissen - raus aus dem Zelt, LINKSKLICK zum Anschlagen!", 6.0)
	else:
		var msg := "Guten Morgen! Tag %d, %s Uhr." % [Game.day_count, Game.clock_text()]
		if tent.smelly:
			msg += " (Das Zelt riecht nach Pipi - nur halb erholt.)"
		toast(msg, 5.0)
	_update_help()


var _step_dist: float = 0.0
var _was_in_water: bool = false


## Sandstreifen rund um den See (der Sandrand ist der See 1,14-fach vergrößert).
func _on_sand(gp: Vector3) -> bool:
	var main := get_parent()
	if main.get("lake_root") == null:
		return false
	var lp: Vector3 = gp - (main.lake_root as Node3D).global_position
	var v := Vector2(lp.x, lp.z)
	return LakeShape.contains(LakeShape.CENTER + (v - LakeShape.CENTER) / 1.14)


## Welcher Untergrund liegt unter den Füßen? Gibt den Namen des Schritt-Sounds zurück.
## Erst ein Strahl nach unten (Holzboden, Fels, Berg), sonst nach Lage (Parkplatz-Kies, Sandufer, Gras).
func _surface_sound(gp: Vector3) -> String:
	var kind := ""
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(gp + Vector3(0, 0.4, 0), gp + Vector3(0, -1.2, 0))
	q.exclude = [get_rid()]
	var hit := space.intersect_ray(q)
	if not hit.is_empty():
		var col: Object = hit.get("collider")
		var node := col as Node
		while node != null and not node.has_meta("surface"):
			node = node.get_parent()
			if node == get_parent():
				node = null
		if node != null:
			kind = str(node.get_meta("surface"))
	if kind == "massif":
		kind = "snow" if gp.y > 23.5 else "gravel"
	if kind == "":
		if pow(gp.x / 13.0, 2.0) + pow((gp.z - 1.0) / 7.0, 2.0) < 1.0:
			kind = "gravel"
		elif gp.y < 1.0 and _on_sand(gp):
			kind = "sand"
		else:
			kind = "grass"
	var snd := "step_" + kind
	if Sfx.has_file(snd):
		return snd
	return "step_gravel" if kind in ["gravel", "rock", "sand", "snow"] else "step"


func _footsteps(delta: float) -> void:
	var sp := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and sp > 1.0:
		_step_dist += sp * delta
		if _step_dist > 2.1:
			_step_dist = 0.0
			if water_d > 0.15:
				Sfx.play("step_wade" if Sfx.has_file("step_wade") else "splash_small", global_position, -8.0, randf_range(0.9, 1.2))
			else:
				var gp := global_position
				Sfx.play(_surface_sound(gp), gp, -6.0, randf_range(0.92, 1.08))
	var wet := water_d > 0.3
	if wet and not _was_in_water:
		Sfx.play("splash", global_position, 0.0)
	_was_in_water = wet


# ---------- Wasser: waten und schwimmen ----------

func _update_water(delta: float) -> void:
	var main := get_parent()
	if main.get("lake_root") == null:
		return
	var lp: Vector3 = global_position - (main.lake_root as Node3D).global_position
	var v := Vector2(lp.x, lp.z)
	var target := 0.0
	if LakeShape.contains(v) and global_position.y < 1.0:
		target = 0.25
		for k in [0.9, 0.75, 0.6]:
			if LakeShape.contains(LakeShape.CENTER + (v - LakeShape.CENTER) * k):
				target += 0.25
	water_d = lerpf(water_d, target, minf(delta * 4.0, 1.0))
	var moving := Vector2(velocity.x, velocity.z).length() > 0.5
	if wake == null:
		wake = CPUParticles3D.new()
		wake.emitting = false
		wake.amount = 24
		wake.lifetime = 0.8
		wake.direction = Vector3(0, 1, 0)
		wake.spread = 70.0
		wake.initial_velocity_min = 0.8
		wake.initial_velocity_max = 1.8
		wake.gravity = Vector3(0, -6, 0)
		var m := SphereMesh.new()
		m.radius = 0.04
		m.height = 0.08
		m.radial_segments = 4
		m.rings = 2
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(0.85, 0.95, 1.0, 0.8)
		m.material = mat
		wake.mesh = m
		wake.position = Vector3(0, 0.05, 0)
		add_child(wake)
	wake.emitting = water_d > 0.2 and moving
	if water_d > 0.5 and moving:
		Game.fish_penalty_until = maxf(Game.fish_penalty_until, Game.now() + 25.0)
