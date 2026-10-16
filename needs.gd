class_name Needs
extends Node
## Körperliche Bedürfnisse und Gesundheit: Hunger, Blase (P), großes Geschäft mit Barometer (H),
## Gesundheit (Stürze). Julians Vape (Q) steckt auch hier.

var player: Player
var health: float = 100.0
var hunger: float = 0.15          # 0 = satt, 1 = am Verhungern
var bladder: float = 0.1          # 0..1
var bowel: float = 0.05           # Barometer 0..1 (füllt sich zufällig schnell oder langsam)
var _bowel_rate: float = 0.00095
var _rate_timer: float = 20.0
var _boost_t: float = 0.0
var _urgent_time: float = 0.0
var peeing: bool = false
var squatting: bool = false
var _vape_cd: float = 0.0
var puffs: int = 0

var bars: Dictionary = {}
var panel: VBoxContainer
var pee_particles: CPUParticles3D
var vape_particles: CPUParticles3D
var dead_until: float = 0.0
var pants: int = 0                # 0 sauber, 1 nass, 2 braun
var pants_t: float = 0.0
var accident_t: float = 0.0       # >0: gerade Missgeschick (geht in die Knie)
var _bladder_full_t: float = 0.0
var _warned: int = 0


func setup(p: Player, layer: CanvasLayer) -> void:
	player = p
	var frame := PanelContainer.new()
	frame.theme = UI.theme()
	frame.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	frame.grow_vertical = Control.GROW_DIRECTION_BEGIN
	frame.offset_left = 14.0
	frame.offset_bottom = -14.0
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_stylebox_override("panel", UI.sticker(UI.PAPER, 14, 4.0, Vector4(12, 8, 12, 8)))
	layer.add_child(frame)
	panel = VBoxContainer.new()
	panel.add_theme_constant_override("separation", 4)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(panel)
	UI.fonts()
	var cols := {"Gesundheit": Color("4aa35a"), "Hunger": UI.FIRE, "Blase": Color("e8c547"), "Darm": Color("8a6a43")}
	for key in ["Gesundheit", "Hunger", "Blase", "Darm"]:
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var l := Label.new()
		l.text = key
		l.custom_minimum_size = Vector2(88, 0)
		l.add_theme_font_size_override("font_size", 14)
		l.add_theme_color_override("font_color", UI.INK)
		row.add_child(l)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(140, 12)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.show_percentage = false
		bar.max_value = 1.0
		bar.step = 0.001
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var bg := UI.sticker(Color("fffdf7"), 6, 0.0, Vector4(0, 0, 0, 0))
		var fl := UI.sticker(cols[key], 4, 0.0, Vector4(0, 0, 0, 0))
		fl.set_border_width_all(0)
		bar.add_theme_stylebox_override("background", bg)
		bar.add_theme_stylebox_override("fill", fl)
		row.add_child(bar)
		panel.add_child(row)
		bars[key] = bar

	pee_particles = Fx.pee_stream()
	player.add_child(pee_particles)

	vape_particles = CPUParticles3D.new()
	vape_particles.emitting = false
	vape_particles.one_shot = true
	vape_particles.amount = 40
	vape_particles.lifetime = 2.5
	vape_particles.explosiveness = 0.7
	vape_particles.direction = Vector3(0, 0.3, -1)
	vape_particles.spread = 25.0
	vape_particles.initial_velocity_min = 0.8
	vape_particles.initial_velocity_max = 1.6
	vape_particles.gravity = Vector3(0, 0.25, 0)
	vape_particles.scale_amount_min = 0.7
	vape_particles.scale_amount_max = 1.6
	var vm := SphereMesh.new()
	vm.radius = 0.12
	vm.height = 0.24
	vm.radial_segments = 6
	vm.rings = 3
	var vmat := StandardMaterial3D.new()
	vmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	vmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	vmat.albedo_color = Color(0.92, 0.92, 0.96, 0.35)
	vm.material = vmat
	vape_particles.mesh = vm
	vape_particles.position = Vector3(0, 1.45, -0.45)
	player.add_child(vape_particles)


func drank_beer() -> void:
	bladder = minf(bladder + 0.12, 1.0)
	bowel = minf(bowel + 0.05, 1.0)
	_boost_t += 120.0


func drank_water() -> void:
	bladder = minf(bladder + 0.05, 1.0)


func ate_chili() -> void:
	bowel = minf(bowel + 0.3, 1.0)
	_boost_t += 240.0


func eat(amount: float) -> void:
	Sfx.play("crunch", Vector3.INF, -4.0)
	hunger = maxf(hunger - amount, 0.0)
	health = minf(health + amount * 30.0, 100.0)


func damage(amount: float, reason: String) -> void:
	health -= amount
	if health <= 0.0:
		_die(reason)
	elif amount >= 5.0:
		Sfx.play("thunk", Vector3.INF, 2.0)
		player.toast("Autsch! %s (-%d)" % [reason, int(amount)], 2.5)


## Missgeschick in die Hose: Hose verfärbt sich, etwas Gesundheit weg.
func accident(kind: int) -> void:
	pants = maxi(pants, kind)
	pants_t = 300.0
	accident_t = 2.2
	var loss := 5.0 if kind == 1 else 10.0
	health = maxf(health - loss, 1.0)
	Sfx.play("trickle", player.global_position, -2.0, 0.9)
	Fx.wet_spot(player.get_parent(), Vector3(player.global_position.x, 0.0, player.global_position.z))
	if kind == 1:
		player.toast("Oh nein... in die Hose gepinkelt. (-5 Gesundheit) Im See abwaschen oder warten, bis sie trocknet.", 5.0)
	else:
		player.toast("Das war peinlich... die Hose ist hin. (-10 Gesundheit) Im See abwaschen oder warten.", 5.0)


## Tod: Holzkreuz an der Stelle, Gepäck weg, Stunden später am Parkplatz wieder wach.
func _die(reason: String) -> void:
	var pos := player.global_position
	var main := player.get_parent()
	Game.deaths += 1
	var cross := Node3D.new()
	cross.name = "Grave"
	main.add_child(cross)
	cross.global_position = Vector3(pos.x, 0.0, pos.z)
	Util.add_box(cross, Vector3(0.12, 1.2, 0.12), Color(0.4, 0.27, 0.14), Vector3(0, 0.6, 0))
	Util.add_box(cross, Vector3(0.7, 0.12, 0.12), Color(0.4, 0.27, 0.14), Vector3(0, 0.95, 0))
	Util.add_box(cross, Vector3(0.7, 0.04, 0.5), Color(0.25, 0.2, 0.15), Vector3(0, 0.02, 0.3))
	var gl := Label3D.new()
	gl.text = "† %s\n%s" % [Game.player_name if Game.player_name != "" else player.character_name, reason]
	gl.font_size = 40
	gl.pixel_size = 0.004
	gl.outline_size = 8
	gl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	gl.position = Vector3(0, 1.5, 0)
	cross.add_child(gl)
	var lost := player.logs + player.stones + player.tinder + player.sticks
	player.logs = 0
	player.stones = 0
	player.tinder = 0
	player.sticks = 0
	health = 50.0
	hunger = 0.5
	bladder = 0.2
	pants = 0
	player.promille = 0.0
	var msg := "%s - du kommst am Parkplatz wieder zu dir. Halbe Gesundheit" % reason
	if Net.instance == null:
		Game.hour = fposmod(Game.hour + 3.0, 24.0)
		msg += ", 3 Stunden vergangen"
	if lost > 0:
		msg += ", gesammeltes Material (%d) ist weg" % lost
	player.toast(msg + ". Als Strafe: trag die neue Kiste Bier am Parkplatz ins Camp!", 8.0)
	player.respawn()
	# Strafe: neuer Kasten Bier am Parkplatz, muss zum Camp getragen werden
	var beer := Item.new().setup("Bierkasten", 14.0, Vector3(0.5, 0.3, 0.35), Color(0.9, 0.75, 0.2))
	main.add_child(beer)
	beer.global_position = Vector3(1.5, 1.0, 10.0)


func _process(delta: float) -> void:
	if player == null:
		return
	# Hunger und Blase steigen langsam, das Darm-Barometer zufällig schnell oder langsam
	hunger = minf(hunger + delta * 0.0009, 1.0)
	bladder = minf(bladder + delta * 0.0016, 1.0)
	_rate_timer -= delta
	if _rate_timer <= 0.0:
		_rate_timer = randf_range(30.0, 90.0)
		_bowel_rate = 0.00095 * randf_range(0.75, 1.3)   # ca. einmal pro Spieltag (17 Minuten)
	_boost_t = maxf(_boost_t - delta, 0.0)
	bowel = minf(bowel + delta * _bowel_rate * (3.5 if _boost_t > 0.0 else 1.0), 1.0)
	if bowel >= 1.0:
		_urgent_time += delta
		if _urgent_time > 50.0:
			_urgent_time = 0.0
			bowel = 0.25
			accident(2)
			player.promille = maxf(player.promille - 0.2, 0.0)
	else:
		_urgent_time = 0.0
	if hunger >= 1.0:
		damage(delta * 0.8, "Verhungert")
	elif hunger > 0.95 and _warned < 3:
		_warned = 3
		player.toast("Du verhungerst bald! Iss etwas (Pilze, Beeren, Äpfel, Grill).", 5.0)
	elif hunger > 0.8 and _warned < 2:
		_warned = 2
		player.toast("Dein Magen knurrt. Such dir was zu essen.", 4.0)
	if hunger < 0.7:
		_warned = 0
	# Blase voll: nach einiger Zeit geht es in die Hose
	if bladder >= 1.0 and not peeing:
		_bladder_full_t += delta
		if _bladder_full_t > 25.0:
			_bladder_full_t = 0.0
			bladder = 0.15
			accident(1)
	else:
		_bladder_full_t = 0.0
	accident_t = maxf(accident_t - delta, 0.0)
	if pants != 0:
		pants_t -= delta
		if player.water_d > 0.5 or pants_t <= 0.0:
			pants = 0
			player.toast("Die Hose ist wieder sauber.", 3.0)
	_vape_cd = maxf(_vape_cd - delta, 0.0)

	# Pinkeln: P gedrückt halten
	var want_pee := Input.is_physical_key_pressed(KEY_P) and bladder > 0.02 and player.seat == null \
		and not player.placing and not squatting and player.sleeping == false
	if want_pee != peeing:
		peeing = want_pee
		pee_particles.emitting = peeing
		if peeing:
			player.toast("Sch...pläätscher.", 1.5)
			Sfx.play("trickle", player.global_position)
	if peeing:
		bladder = maxf(bladder - delta * 0.12, 0.0)
		_check_pee_target()
		if bladder <= 0.0:
			peeing = false
			pee_particles.emitting = false
			player.toast("Ahh. Besser.", 2.0)

	bars["Gesundheit"].value = health / 100.0
	bars["Hunger"].value = hunger
	bars["Blase"].value = bladder
	bars["Darm"].value = bowel
	(bars["Darm"] as ProgressBar).modulate = Color(1, 0.4, 0.3) if bowel > 0.85 else Color.WHITE
	(bars["Blase"] as ProgressBar).modulate = Color(1, 0.8, 0.3) if bladder > 0.85 else Color.WHITE
	(bars["Hunger"] as ProgressBar).modulate = Color(1, 0.5, 0.3) if hunger > 0.85 else Color.WHITE


func _check_pee_target() -> void:
	var fwd := -player.global_transform.basis.z
	var target := player.global_position + fwd * 1.8
	# Ins Feuer pinkeln
	for o in Game.placed:
		if is_instance_valid(o) and o.item_name == "Feuerschale" and o.burning and o.global_position.distance_to(target) < 1.4:
			o.extinguish("Zzzzisch! Das Feuer ist aus. Tolle Idee.")
			player.toast("Du hast das Feuer ausgepinkelt!", 3.0)
	# Ins Wasser
	var main := player.get_parent()
	if main.get("lake_root") != null:
		var lp: Vector3 = target - (main.lake_root as Node3D).global_position
		if LakeShape.contains(Vector2(lp.x, lp.z)):
			if Game.fish_penalty_until < Game.now():
				player.toast("Du pinkelst in den See. Die Fische sind nicht begeistert.", 3.5)
			Game.fish_penalty_until = Game.now() + 120.0
		else:
			Fx.wet_spot(main, Vector3(target.x, 0.0, target.z))
	# Ans Zelt
	for t in Game.tents:
		if is_instance_valid(t) and (t as Node3D).global_position.distance_to(target) < 1.8 and not t.smelly:
			t.smelly = true
			player.toast("Das Zelt riecht jetzt... nach dir.", 3.0)


func try_big_business() -> void:
	if squatting or player.seat != null or player.sleeping:
		return
	if bowel < 0.25:
		player.toast("Da kommt noch nichts. (Barometer zu niedrig)", 2.5)
		return
	var main := player.get_parent()
	var pos := player.global_position
	var in_forest: bool = not main.call("_tree_blocked", pos)
	var far_from_camp := not Game.camp_claimed or Vector2(pos.x - Game.camp_center.x, pos.z - Game.camp_center.z).length() > 22.0
	var near_lake := false
	if main.get("lake_root") != null:
		var lp: Vector3 = pos - (main.lake_root as Node3D).global_position
		var v := Vector2(lp.x, lp.z)
		near_lake = LakeShape.contains(LakeShape.CENTER + (v - LakeShape.CENTER) * 0.8)
	if not in_forest or not far_from_camp or near_lake or main.call("is_in_cave", pos):
		player.toast("Nicht hier! Geh tief in den Wald (weg vom Lager, See und Parkplatz) und drück dort H.", 4.0)
		return
	squatting = true
	player.toast("Du gehst in die Hocke...", 2.0)
	Sfx.play("trickle", player.global_position, -10.0, 0.6)
	var tw := create_tween()
	tw.tween_property(player.head, "position:y", 0.9, 0.6)
	tw.tween_interval(3.0)
	tw.tween_property(player.head, "position:y", 1.6, 0.6)
	tw.tween_callback(_finish_big)


func _finish_big() -> void:
	squatting = false
	bowel = 0.0
	_urgent_time = 0.0
	var pile := Poop.new()
	pile.variant = Poop.pick_variant(player.promille, hunger)
	player.get_parent().add_child(pile)
	pile.build()
	# Der Haufen liegt hinter dir, nicht unter deinen Füßen
	pile.global_position = player.global_position + player.global_transform.basis.z * 0.7
	if Net.instance != null and Net.instance.multiplayer.multiplayer_peer != null:
		Net.instance.send_poop(pile.global_position, pile.variant)
	Sfx.play("plop", pile.global_position)
	player.toast("Puh. Das hat gutgetan. Barometer leer. (Der Haufen bleibt liegen - E: vergraben)", 4.5)


func vape() -> void:
	if player.character_name != "Julian":
		player.toast("Nur Julian hat eine Vape dabei.", 2.0)
		return
	if _vape_cd > 0.0:
		return
	_vape_cd = 3.0
	player.vape_t = 2.7
	puffs += 1
	vape_particles.restart()
	vape_particles.emitting = true
	var flavors := ["Mango-Eis", "Blaubeere", "Wassermelone", "Cola", "Minze"]
	player.toast("Julian dampft (%s). Wolke!" % flavors[puffs % flavors.size()], 2.5)
	bladder = minf(bladder + 0.01, 1.0)
