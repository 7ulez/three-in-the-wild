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
var hammock: Hammock = null
var stones: int = 0
var crouching: bool = false
var _air_t: float = 0.0
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
var lamp: SpotLight3D
var fire_bowl: PlacedItem = null
var fire_t: float = 0.0
var fire_dur: float = 4.0
var _curses_done: int = 0
var sparks: CPUParticles3D = null
var fade_rect: ColorRect
var needs: Needs
var goals_label: Label
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


## Baut die Figur (auch für die Avatare der Mitspieler).
static func build_body(parent: Node3D, char_name: String) -> void:
	# Fertiges, animiertes Modell (aus Blender), falls vorhanden.
	var path := "res://assets/chars/%s.glb" % char_name.to_lower()
	if ResourceLoader.exists(path):
		var ps: PackedScene = load(path)
		var inst := ps.instantiate() as Node3D
		inst.rotation.y = PI          # Modell schaut nach +Z, das Spiel nach -Z
		inst.scale = Vector3.ONE * 0.92
		parent.add_child(inst)
		var ap := _find_anim(inst)
		if ap != null:
			for n in ap.get_animation_list():
				ap.get_animation(n).loop_mode = Animation.LOOP_NONE if n == "Jump" else Animation.LOOP_LINEAR
			if ap.has_animation("Idle"):
				ap.play("Idle")
			parent.set_meta("ap", ap)
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
static func animate_body(parent: Node3D, speed: float, crouch: bool = false, air: bool = false) -> void:
	var ap: AnimationPlayer = parent.get_meta("ap", null) as AnimationPlayer
	if ap == null:
		return
	var want := "Idle"
	var sc := 1.0
	if air and ap.has_animation("Jump"):
		if not parent.get_meta("jumping", false):
			parent.set_meta("jumping", true)
			ap.play("Jump", 0.08)
		ap.speed_scale = 1.0
		return
	parent.set_meta("jumping", false)
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


func _apply_view() -> void:
	if third_person:
		camera.position = Vector3(0.6, 0.4, 3.2)
		ray.target_position = Vector3(0, 0, -11.2)
	else:
		camera.position = Vector3.ZERO
		ray.target_position = Vector3(0, 0, -8.0)
	body_visual.visible = third_person


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

	var cross := _make_label(layer, 28)
	cross.text = "+"
	cross.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cross.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cross.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


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
	toast_label.text = text
	toast_label.modulate.a = 1.0
	toast_tween = create_tween()
	toast_tween.tween_interval(seconds)
	toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.8)


func _update_goals() -> void:
	var lines := PackedStringArray(["ZIELE"])
	var all := true
	for g in Game.goals():
		lines.append("%s %s" % ["[x]" if g[1] else "[ ]", g[0]])
		if not g[1]:
			all = false
	goals_label.text = "\n".join(lines)
	if all and not Game.all_done_shown:
		Game.all_done_shown = true
		toast("ALLE ZIELE GESCHAFFT! Ein perfekter Angelausflug. Du darfst weitercampen (und noch ein Bier trinken).", 10.0)


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
	if h >= 5.0 and h < 8.0:
		return "Morgen"
	if h >= 8.0 and h < 12.0:
		return "Vormittag"
	if h >= 12.0 and h < 14.0:
		return "Mittag"
	if h >= 14.0 and h < 18.0:
		return "Nachmittag"
	if h >= 18.0 and h < 21.0:
		return "Abend"
	return "Nacht"


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
	help_label.text = "%s  |  trägt: %s  |  Lager: %s  |  %s Tag %d  |  Promille: %.2f%s\nZunder %d · Äste %d · Holz %d · Steine %d  |  Bier %d · Wasser %d  |  Fänge: %d  |  Chili: %d\nWASD laufen · Shift rennen · Space springen · E benutzen · F trinken · R aufstellen · X abbauen · G werfen/Stein flitschen · C ducken · L Kopflampe\nP pinkeln (halten) · H großes Geschäft · Q Vape (Julian) · T Angelmethode · Z Zutat wechseln · V Ansicht · 1/2/3 Charakter · Esc Maus frei" % [character_name, carrying, camp, Game.clock_text(), Game.day_count, promille, net_txt, tinder, sticks, logs, stones, beers_drunk, water_drunk, Game.catches.size(), Game.chili_served]
	if Game.touch:
		var hl: PackedStringArray = help_label.text.split("\n")
		help_label.text = hl[0] + "\n" + hl[1] + "\nLinks: Joystick laufen (ganz raus = rennen) · Rechts wischen: umschauen · Mehr: alle weiteren Aktionen"


func _unhandled_input(event: InputEvent) -> void:
	if sleeping:
		return
	if event is InputEventMouseMotion and Game.is_captured():
		var mm := event as InputEventMouseMotion
		rotate_y(-mm.screen_relative.x * MOUSE_SENS)
		pitch = clampf(pitch - mm.screen_relative.y * MOUSE_SENS, -1.45, 1.45)
		head.rotation.x = pitch
	elif event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if not Game.is_captured():
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif placing:
			match mb.button_index:
				MOUSE_BUTTON_WHEEL_UP:
					_rotate_ghost(0.25)
				MOUSE_BUTTON_WHEEL_DOWN:
					_rotate_ghost(-0.25)
				MOUSE_BUTTON_LEFT:
					_confirm_placement()
	elif event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		match key.keycode:
			KEY_ESCAPE:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			KEY_V:
				third_person = not third_person
				_apply_view()
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
			KEY_Z:
				var zc: Object = _reach_target()
				if zc != null and zc.has_method("cycle_selection"):
					zc.cycle_selection()
			KEY_R:
				if placing:
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
	if sleeping:
		velocity = Vector3.ZERO
		return
	if seat != null:
		velocity = Vector3.ZERO
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
	if hammock != null:
		velocity = Vector3.ZERO
		_drink_cd = maxf(_drink_cd - delta, 0.0)
		promille = maxf(promille - delta * 0.01, 0.0)
		if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_A) \
				or Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_D) \
				or Input.is_physical_key_pressed(KEY_SPACE):
			unlie()
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
	var target := dir * speed
	if drunk > 0.0:
		# Schwammige Steuerung: die Figur reagiert verzögert
		var k := 1.0 - exp(-delta * lerpf(14.0, 2.2, minf(drunk, 1.0)))
		velocity.x = lerpf(velocity.x, target.x, k)
		velocity.z = lerpf(velocity.z, target.z, k)
	else:
		velocity.x = target.x
		velocity.z = target.z
	move_and_slide()
	_air_t = 0.0 if is_on_floor() else _air_t + delta
	Player.animate_body(body_visual, Vector2(velocity.x, velocity.z).length(), crouching, _air_t > 0.18)
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
	var t := Time.get_ticks_msec() / 1000.0
	var drunk := clampf(promille / 1.5, 0.0, 1.5)
	head.rotation.x = clampf(pitch + drink_tilt + sin(t * 0.7) * 0.06 * drunk, -1.55, 1.55)
	camera.rotation.z = sin(t * 0.9) * 0.12 * drunk + sin(t * 2.3) * 0.04 * drunk
	camera.fov = 75.0 + sin(t * 0.5) * 8.0 * drunk
	blur_rect.visible = drunk > 0.05
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
	var src: Object = null
	if held != null and held.drink_kind() != "":
		src = held
	else:
		var c: Object = _reach_target()
		if c != null and c.has_method("drink_kind") and c.drink_kind() != "":
			src = c
	if src == null:
		toast("Zum Trinken: Bierkasten oder Wasserkanister anschauen oder tragen, dann F.", 2.5)
		return
	var kind: String = src.drink_kind()
	if not src.take_drink():
		toast("Leer!", 2.5)
		return
	_drink_cd = 1.4
	var msg := ""
	if kind == "beer":
		beers_drunk += 1
		promille += 0.3
		needs.drank_beer()
		msg = _drink_message()
	else:
		water_drunk += 1
		needs.drank_water()
		promille = maxf(promille - 0.12, 0.0)
		msg = "Ahh, frisches Wasser." if promille < 0.3 else "Wasser hilft. Ein bisschen."
	Sfx.play("gulp" if kind == "water" else "pop", Vector3.INF, -2.0)
	if kind == "beer" and randf() < 0.3:
		get_tree().create_timer(1.2).timeout.connect(func() -> void: Sfx.play("burp", global_position, -3.0, randf_range(0.8, 1.2)))
	var tw := create_tween()
	tw.tween_property(self, "drink_tilt", 0.55, 0.35)
	tw.tween_interval(0.5)
	tw.tween_property(self, "drink_tilt", 0.0, 0.35)
	toast("%s  (noch %d)" % [msg, src.drinks_left()], 3.0)
	_update_help()


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
	if seat != null:
		stand_up()
		return
	if hammock != null:
		unlie()
		return
	var c: Object = _reach_target()
	if held != null:
		if c != null and c.has_method("interact_with_held") and c.interact_with_held(self, held):
			return
		_drop()
		return
	if c != null and c.has_method("interact"):
		c.interact(self)


func pick_up(item: Item) -> void:
	if held != null:
		return
	held = item
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
		psize = Vector3(1.6, 0.95, 0.5)
	item_ghost = Node3D.new()
	get_parent().add_child(item_ghost)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = psize
	mi.mesh = bm
	mi.position.y = psize.y / 2.0
	item_ghost_mat = StandardMaterial3D.new()
	item_ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	item_ghost_mat.albedo_color = Color(0.3, 1.0, 0.3, 0.45)
	mi.material_override = item_ghost_mat
	item_ghost.add_child(mi)
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
	Sfx.play("thunk", pos)
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
	if it.item_name == "Wasserkanister":
		state["water"] = it.water_left
	if it.extra.has("wood"):
		state["wood"] = it.extra["wood"]
	if it.extra.has("pack"):
		state["pack"] = it.extra["pack"]
	if it.item_name == "Campingstühle":
		var right := Vector3(cos(yaw), 0, -sin(yaw))
		for sgn in [-1.0, 1.0]:
			_spawn_placed("Campingstuhl", it.weight / 2.0, Vector3(0.3, 0.9, 0.5), it.item_color, pos + right * 0.55 * sgn, yaw, {})
	else:
		var placed := _spawn_placed(it.item_name, it.weight, it.item_size, it.item_color, pos, yaw, state)
		if snap != null:
			snap.oven = placed
			placed.on_grill = snap
	var nm := it.item_name
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
	global_position = chair.global_position + Vector3(0, 0.5, 0)
	head.position.y = 0.6
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
var strike_zone_w: float = 0.13
var strike_zone_x: float = 0.5
var strike_ui: Control = null
var strike_cursor: ColorRect = null
var strike_zone: ColorRect = null
var strike_label: Label = null
var _strike_speed: float = 1.0


func start_firemaking(bowl: PlacedItem) -> void:
	if fire_bowl != null:
		return
	fire_bowl = bowl
	fire_t = 0.0
	strike_hits = 0
	strike_pos = 0.0
	strike_dir = 1.0
	_curses_done = 0
	strike_zone_w = 0.13 * (0.8 if character_name == "Marian" else 1.0)   # Marian: 20 % schwieriger
	_strike_speed = 0.95
	_new_strike_zone()
	toast("Feuerstahl: E drücken, wenn der Strich im grünen Feld ist! %d Treffer nötig." % STRIKE_NEEDED, 4.0)
	if strike_ui == null:
		strike_ui = Control.new()
		strike_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var bg := ColorRect.new()
		bg.color = Color(0, 0, 0, 0.6)
		bg.size = Vector2(420, 30)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		strike_ui.add_child(bg)
		strike_zone = ColorRect.new()
		strike_zone.color = Color(0.3, 0.9, 0.3, 0.9)
		strike_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
		strike_ui.add_child(strike_zone)
		strike_cursor = ColorRect.new()
		strike_cursor.color = Color(1.0, 0.9, 0.3)
		strike_cursor.size = Vector2(6, 30)
		strike_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
		strike_ui.add_child(strike_cursor)
		strike_label = Label.new()
		strike_label.position = Vector2(0, -34)
		strike_label.add_theme_font_size_override("font_size", 20)
		strike_label.add_theme_constant_override("outline_size", 6)
		strike_label.add_theme_color_override("font_outline_color", Color.BLACK)
		strike_ui.add_child(strike_label)
		strike_ui.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		strike_ui.position = Vector2(-210, 120)
		help_label.get_parent().add_child(strike_ui)
	strike_ui.visible = true
	_update_strike_ui()
	if sparks == null:
		sparks = CPUParticles3D.new()
		sparks.amount = 30
		sparks.lifetime = 0.5
		sparks.one_shot = false
		sparks.direction = Vector3(0, 1, 0)
		sparks.spread = 60.0
		sparks.initial_velocity_min = 1.0
		sparks.initial_velocity_max = 2.5
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


func _update_strike_ui() -> void:
	if strike_ui == null:
		return
	strike_zone.position = Vector2(420.0 * strike_zone_x, 0)
	strike_zone.size = Vector2(420.0 * strike_zone_w, 30)
	strike_cursor.position = Vector2(420.0 * strike_pos - 3.0, 0)
	strike_label.text = "Funken schlagen: %d / %d    (E im grünen Feld)" % [strike_hits, STRIKE_NEEDED]


## E während des Funkenschlagens: trifft der Strich das grüne Feld?
func strike() -> void:
	if fire_bowl == null:
		return
	var in_zone := strike_pos >= strike_zone_x and strike_pos <= strike_zone_x + strike_zone_w
	if in_zone:
		Sfx.play("spark", global_position, -2.0)
		strike_hits += 1
		sparks.emitting = true
		get_tree().create_timer(0.35).timeout.connect(func() -> void:
			if sparks != null:
				sparks.emitting = false)
		_strike_speed += 0.2
		_new_strike_zone()
		if strike_hits >= STRIKE_NEEDED:
			var bowl := fire_bowl
			_stop_firemaking()
			bowl.ignite(self)
			toast("Das Feuer brennt! Nachlegen: Holzscheit vom Brennholz-Bündel nehmen (E) und ins Feuer (E).", 5.0)
			return
		toast("Funke! (%d/%d)" % [strike_hits, STRIKE_NEEDED], 1.2)
	else:
		Sfx.play("click", global_position, -2.0)
		strike_hits = maxi(strike_hits - 1, 0)
		_strike_speed = maxf(_strike_speed - 0.1, 0.95)
		toast("Daneben - der Stahl rutscht ab. Treffer: %d/%d" % [strike_hits, STRIKE_NEEDED], 1.5)
		if character_name == "Marian":
			var curses := ["Verdammte Axt!", "Scheiße, warum zündet das nicht?!", "Komm schon, du blödes Ding!", "Himmel, Arsch und Zwirn!"]
			toast("Marian: " + curses.pick_random(), 2.0)
	_update_strike_ui()


func _stop_firemaking() -> void:
	fire_bowl = null
	if sparks != null:
		sparks.emitting = false
	if strike_ui != null:
		strike_ui.visible = false


func _update_firemaking(delta: float) -> void:
	if fire_bowl == null:
		return
	if not is_instance_valid(fire_bowl) or held == null or held.item_name != "Feuerstahl" \
			or global_position.distance_to(fire_bowl.global_position) > 4.5:
		toast("Abgebrochen.", 1.5)
		_stop_firemaking()
		return
	fire_t += delta
	strike_pos += strike_dir * _strike_speed * delta
	if strike_pos >= 1.0:
		strike_pos = 1.0
		strike_dir = -1.0
	elif strike_pos <= 0.0:
		strike_pos = 0.0
		strike_dir = 1.0
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
	teleport_to(tent.global_transform * Vector3(0, 0.1, -2.1))
	_peak_y = global_position.y
	sleeping = false
	var tw2 := create_tween()
	tw2.tween_property(fade_rect, "color:a", 0.0, 1.0)
	Game.slept = true
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


func _footsteps(delta: float) -> void:
	var sp := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and sp > 1.0:
		_step_dist += sp * delta
		if _step_dist > 2.1:
			_step_dist = 0.0
			if water_d > 0.15:
				Sfx.play("splash_small", global_position, -8.0, randf_range(0.9, 1.2))
			else:
				Sfx.play("step", global_position, -8.0, randf_range(0.85, 1.15))
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
