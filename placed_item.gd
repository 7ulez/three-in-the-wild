class_name PlacedItem
extends StaticBody3D
## Ein aufgestellter Gegenstand im Lager. Je nach Art kann man ihn benutzen:
## Stuhl (hinsetzen), Grill (an/aus), Kühlbox (öffnen), Dutch Oven (Chili kochen), Rucksack (Zutaten),
## Feuerschale (Feuer machen), Brennholz (Holz nehmen), Bierkasten / Wasserkanister (trinken). X baut ab.

var item_name: String = ""
var weight: float = 5.0
var item_size: Vector3 = Vector3.ONE
var item_color: Color = Color.WHITE
var parts: Dictionary = {}
var open: bool = false              # Deckel offen, beim Grill: an
var water_left: int = 10
var seated_by: Node = null
var oven: PlacedItem = null         # Dutch Oven, der auf diesem Grill steht
var on_grill: PlacedItem = null     # der Grill, auf dem dieser Topf steht
var light: OmniLight3D = null
var holder: Node3D = null

# Feuerschale
var tinder: int = 0
var sticks: int = 0
var logs_in: int = 0
var burning: bool = false
var burn_left: float = 0.0
var smoke: CPUParticles3D = null
var _flicker: float = 0.0
var _fire_snd: AudioStreamPlayer3D = null
var _psize: Vector3 = Vector3.ONE

# Brennholz
var wood_left: int = 8

# Kiste mit Proviant
var pack: Array = []
# Rucksack (beliebiger Inhalt)
var contents: Array = []
var sel: int = 0

# Rutenständer
var rod_in: bool = false
var rod_owner: String = ""
var rod_st: Dictionary = {}
var rod_color: Color = Color(0.15, 0.55, 0.3)
var _rbob: MeshInstance3D = null
var _rline: MeshInstance3D = null
var _rbeep: AudioStreamPlayer3D = null
var _rled: MeshInstance3D = null
var _rled_light: OmniLight3D = null
var _beep_cd: float = 0.0
var _rt: float = 0.0

# Dutch Oven / Chili
var added: Array = []
var wrong: int = 0
var cook_t: float = 0.0
var burn: float = 0.0
var done: bool = false
var burnt: bool = false
var portions: int = 0
var quality: float = 100.0
var cook_char: String = ""
var food: MeshInstance3D = null
var steam: CPUParticles3D = null
var fire_sparks: CPUParticles3D = null
var fire_glow: MeshInstance3D = null


func build(p_name: String, p_weight: float, p_size: Vector3, p_color: Color, state: Dictionary = {}) -> void:
	item_name = p_name
	weight = p_weight
	item_size = p_size
	item_color = p_color
	var psize := ItemModels.placed_size(p_name, p_size)
	_psize = psize

	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = psize
	cs.shape = bs
	cs.position.y = psize.y / 2.0
	add_child(cs)

	holder = Node3D.new()
	holder.position.y = psize.y / 2.0
	add_child(holder)
	parts = ItemModels.add_placed_visual(holder, p_name, p_size, p_color)

	if state.has("beers") and parts.has("bottles"):
		var bottles: Array = parts["bottles"]
		while bottles.size() > int(state["beers"]):
			var b: Node = bottles.pop_back()
			b.queue_free()
	if state.has("water"):
		water_left = int(state["water"])
	if state.has("wood"):
		wood_left = int(state["wood"])

	if p_name == "Rucksack" and state.has("contents"):
		contents = (state["contents"] as Array).duplicate(true)

	if p_name == "Kiste mit Proviant":
		pack = (state["pack"] as Array).duplicate() if state.has("pack") else Game.RECIPE.duplicate()

	if p_name == "Gasgrill":
		light = OmniLight3D.new()
		light.light_color = Color(1.0, 0.6, 0.25)
		light.light_energy = 1.5
		light.omni_range = 5.0
		light.position = Vector3(0, psize.y + 0.3, 0)
		light.visible = false
		add_child(light)

	if p_name == "Feuerschale":
		light = OmniLight3D.new()
		light.light_color = Color(1.0, 0.55, 0.2)
		light.light_energy = 0.0
		light.omni_range = 14.0
		light.position = Vector3(0, 0.75, 0)
		light.shadow_enabled = not Game.low
		add_child(light)
		smoke = _make_smoke(Color(0.35, 0.35, 0.37, 0.4), 0.7, 2.0)
		smoke.position = Vector3(0, 0.7, 0)
		add_child(smoke)
		fire_sparks = Fx.sparks(self, Vector3(0, 0.7, 0))
		fire_glow = Fx.glow_disc(self, 9.0, Color(1.0, 0.55, 0.18, 1.0), 0.0, 0.035, 2.2)
		fire_glow.visible = false

	if p_name == "Dutch Oven":
		food = Util.add_cylinder(holder, 0.17, 0.03, Color(0.6, 0.18, 0.1), Vector3(0, 0.03, 0))
		food.visible = false
		steam = _make_smoke(Color(0.95, 0.95, 0.95, 0.3), 0.5, 1.4)
		steam.position = Vector3(0, 0.5, 0)
		add_child(steam)


func _make_smoke(col: Color, size: float, life: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.amount = 18
	p.lifetime = life
	p.direction = Vector3(0, 1, 0)
	p.spread = 12.0
	p.initial_velocity_min = 0.4
	p.initial_velocity_max = 0.9
	p.gravity = Vector3(0, 0.3, 0)
	p.scale_amount_min = size * 0.6
	p.scale_amount_max = size
	var m := SphereMesh.new()
	m.radius = 0.12
	m.height = 0.24
	m.radial_segments = 6
	m.rings = 3
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = col
	m.material = mat
	p.mesh = m
	return p


# ---------- Trinken ----------

func drink_kind() -> String:
	if item_name == "Bierkasten":
		return "beer"
	if item_name == "Wasserkanister":
		return "water"
	return ""


func drinks_left() -> int:
	if item_name == "Bierkasten":
		var bottles: Array = parts.get("bottles", [])
		return bottles.size()
	return water_left


func take_drink() -> bool:
	if item_name == "Bierkasten":
		var bottles: Array = parts.get("bottles", [])
		if bottles.is_empty():
			return false
		var b: Node = bottles.pop_back()
		b.queue_free()
		return true
	if water_left <= 0:
		return false
	water_left -= 1
	return true


# ---------- Eingabe-Texte ----------

func _next_ingredient() -> String:
	if added.size() >= Game.RECIPE.size():
		return ""
	return Game.RECIPE[added.size()]


func fire_ready() -> bool:
	return tinder >= 3 and sticks >= 4


func get_prompt() -> String:
	var t := ""
	match item_name:
		"Campingstuhl":
			t = "E: hinsetzen" if seated_by == null else "Der Stuhl ist besetzt"
		"Gasgrill":
			t = "E: Grill %s" % ("ausmachen" if open else "anzünden")
		"Kühlbox":
			t = "E: Kühlbox %s" % ("schließen" if open else "öffnen")
		"Dutch Oven":
			t = _oven_prompt()
		"Rucksack":
			if contents.is_empty():
				t = "Der Rucksack ist leer   (X: abbauen)"
			else:
				var c: Dictionary = contents[sel % contents.size()]
				t = "E: auspacken: %s   (Z: anderes Teil, %d drin)" % [_pack_label(c), contents.size()]
		"Kiste mit Proviant":
			if pack.is_empty():
				t = "Die Kiste ist leer"
			else:
				t = "E: Zutat nehmen: %s   (Z: andere Zutat, %d übrig)" % [pack[sel % pack.size()], pack.size()]
		"Bierkasten":
			t = "F: Bier trinken (%d übrig)" % drinks_left()
		"Wasserkanister":
			t = "F: Wasser trinken (%d Schluck)" % drinks_left()
		"Brennholz":
			t = "E: Holzscheit nehmen (%d übrig)" % wood_left if wood_left > 0 else "Das Brennholz ist aufgebraucht"
		"Feuerschale":
			t = _fire_prompt()
		"Rutenständer":
			if not rod_in:
				t = "Rutenständer - Rute (ausgeworfen oder nicht) in die Hand nehmen und E: einhängen"
			elif int(rod_st.get("st", 0)) == Fisher.S.BITE:
				t = "BISS an der Rute von %s!   E: Rute nehmen und anschlagen" % rod_owner
			else:
				t = ("Rute von %s hängt im Ständer   E: Rute nehmen" % rod_owner) if rod_owner != "" else "Rute hängt im Ständer   E: Rute nehmen"
		"Angelrute":
			t = "Angelrute - E hat nichts zu tun, aufheben mit X"
		_:
			t = item_name
	if seated_by == null:
		t += "   X: abbauen"
	return t


func _fire_prompt() -> String:
	if burning:
		return "Feuer brennt (noch %d s)   E: Holzscheit nachlegen" % int(burn_left)
	var s := "Feuerschale: Zunder %d/3 · Äste %d/4" % [tinder, sticks]
	if fire_ready():
		return s + "\nBereit! Feuerstahl in die Hand nehmen und E drücken"
	return s + "   E: hineinlegen (was du dabei hast)"


func _oven_prompt() -> String:
	var s := ""
	if burnt:
		return "ANGEBRANNT!   E: Topf ausleeren"
	if done:
		return "Chili con Carne fertig! (%d Portionen)   E: essen" % portions
	if added.is_empty():
		s = "Dutch Oven leer. Rezept: " + " > ".join(PackedStringArray(Game.RECIPE))
	else:
		s = "Chili %d/9 · als Nächstes: %s\nAnbrennen: %s   E: umrühren" % [added.size(), _next_ingredient() if _next_ingredient() != "" else "köcheln lassen", _bar(burn)]
		if on_grill == null:
			s += "\n(auf den angezündeten Grill stellen!)"
		elif not on_grill.open:
			s += "\n(der Grill ist aus)"
	return s


func _bar(v: float) -> String:
	var n := int(clampf(v, 0.0, 1.0) * 10.0)
	return "[" + "#".repeat(n) + "-".repeat(10 - n) + "]"


func get_held_prompt(held: Node) -> String:
	if item_name == "Rutenständer" and held.item_name == "Angelrute":
		if rod_in:
			return "Im Ständer hängt schon eine Rute"
		return "E: Rute in den Ständer hängen (die Schnur bleibt draußen)"
	if item_name == "Feuerschale" and held.item_name == "Feuerstahl":
		if burning:
			return "Das Feuer brennt schon"
		if fire_ready():
			return "E: Funken schlagen (Feuerstahl)"
		return "Erst Zunder (%d/3) und Äste (%d/4) hineinlegen (ohne Gegenstand in der Hand)" % [tinder, sticks]
	if item_name == "Dutch Oven" and Game.INGREDIENT_COLORS.has(held.item_name) and not done and not burnt:
		var nxt := _next_ingredient()
		return "E: %s in den Topf   (laut Rezept dran: %s)" % [held.item_name, nxt if nxt != "" else "nichts mehr"]
	return ""


func interact_with_held(player: Node, held: Node) -> bool:
	if item_name == "Rutenständer" and held.item_name == "Angelrute":
		_park_rod(player, held)
		return true
	if item_name == "Feuerschale" and held.item_name == "Feuerstahl" and not burning:
		if not fire_ready():
			player.toast("Zuerst Zunder (3) und Äste (4) hineinlegen.", 3.0)
			return true
		player.start_firemaking(self)
		return true
	if item_name == "Dutch Oven" and Game.INGREDIENT_COLORS.has(held.item_name):
		add_ingredient(player, held)
		return true
	return false


# ---------- Benutzen ----------

func interact(player: Node) -> void:
	match item_name:
		"Campingstuhl":
			player.sit(self)
		"Gasgrill", "Kühlbox":
			_toggle_open()
		"Dutch Oven":
			_oven_use(player)
		"Rucksack":
			_unpack(player)
		"Kiste mit Proviant":
			_take_ingredient(player)
		"Brennholz":
			if wood_left > 0:
				wood_left -= 1
				player.logs += 1
				player.toast("Holzscheit genommen (du trägst %d). Ins Feuer legen mit E." % player.logs, 2.5)
		"Feuerschale":
			_fire_use(player)
		"Rutenständer":
			_take_rod(player)
		"Angelrute":
			player.toast("Rute mit X abbauen, dann in die Hand nehmen und angeln.", 3.0)
		_:
			pass


func cycle_selection() -> void:
	if item_name == "Rucksack" and not contents.is_empty():
		sel = (sel + 1) % contents.size()
	if item_name == "Kiste mit Proviant" and not pack.is_empty():
		sel = (sel + 1) % pack.size()


func _toggle_open() -> void:
	open = not open
	Sfx.play("click", global_position)
	var pivot: Node3D = parts.get("lid", null)
	if pivot != null:
		var tw := create_tween()
		tw.tween_property(pivot, "rotation_degrees:x", 105.0 if open else 0.0, 0.4)
	var contents: Node3D = parts.get("contents", null)
	if contents != null:
		contents.visible = open
	if item_name == "Gasgrill":
		var flames: Node3D = parts.get("flames", null)
		if flames != null:
			flames.visible = open
		if light != null:
			light.visible = open


# ---------- Rutenständer ----------

func _park_rod(player: Node, held: Node) -> void:
	if rod_in:
		player.toast("Im Ständer hängt schon eine Rute.", 2.0)
		return
	var f: Fisher = player.fisher
	var st: Dictionary = f.export_state()
	if st.is_empty():
		player.toast("Erst die Schnur einholen oder den Fisch drillen.", 3.0)
		return
	rod_owner = String(held.extra.get("owner", ""))
	rod_color = held.item_color
	rod_st = st
	if int(st["st"]) != Fisher.S.IDLE:
		f.reel_in("")
		_ensure_rod_visuals()
		_rbob.visible = true
		_rbob.global_position = st["target"]
		if int(st["st"]) == Fisher.S.BITE:
			rod_st["bite_left"] = 12.0
	else:
		f.reel_in("")
	player.consume_held()
	rod_in = true
	var rn: Node3D = parts.get("rod", null)
	if rn != null:
		rn.visible = true
	if int(st["st"]) == Fisher.S.WAITING:
		player.toast("Rute im Ständer. Der Bissanzeiger meldet sich, wenn etwas beißt - bau in Ruhe das Lager auf.", 4.5)
	else:
		player.toast("Rute im Ständer.", 2.5)


func _take_rod(player: Node) -> void:
	if not rod_in:
		player.toast("Der Ständer ist leer. Rute in die Hand nehmen und E.", 3.0)
		return
	if player.held != null:
		player.toast("Hände voll - erst ablegen.", 2.0)
		return
	var it := Item.new().setup("Angelrute", 3.0, Vector3(1.4, 0.1, 0.1), rod_color)
	if rod_owner != "":
		it.set_owner_name(rod_owner)
	get_parent().add_child(it)
	it.global_position = global_position + Vector3(0, 1.2, 0)
	player.pick_up(it)
	var st := rod_st
	rod_in = false
	rod_st = {}
	var rn: Node3D = parts.get("rod", null)
	if rn != null:
		rn.visible = false
	if _rbob != null:
		_rbob.visible = false
		(_rline.mesh as ImmediateMesh).clear_surfaces()
		_rled.visible = false
		_rled_light.visible = false
	(player.fisher as Fisher).import_state(st)


func _ensure_rod_visuals() -> void:
	if _rbob != null:
		return
	_rbob = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.07
	sm.height = 0.14
	sm.radial_segments = 8
	sm.rings = 4
	_rbob.mesh = sm
	_rbob.material_override = Util.mat(Color(0.95, 0.2, 0.15))
	_rbob.top_level = true
	add_child(_rbob)
	_rline = MeshInstance3D.new()
	_rline.mesh = ImmediateMesh.new()
	var lm := StandardMaterial3D.new()
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lm.albedo_color = Color(0.9, 0.9, 0.9)
	_rline.material_override = lm
	_rline.top_level = true
	add_child(_rline)
	# Biss-Leuchte: blinkt rot auf dem Ständer, damit man sofort sieht, welche Rute beißt
	_rled = MeshInstance3D.new()
	var lsm := SphereMesh.new()
	lsm.radius = 0.055
	lsm.height = 0.11
	lsm.radial_segments = 10
	lsm.rings = 6
	_rled.mesh = lsm
	var lmat := StandardMaterial3D.new()
	lmat.albedo_color = Color(1.0, 0.1, 0.08)
	lmat.emission_enabled = true
	lmat.emission = Color(1.0, 0.1, 0.05)
	lmat.emission_energy_multiplier = 4.0
	_rled.material_override = lmat
	_rled.position = Vector3(0.12, 1.0, -0.2)
	_rled.visible = false
	add_child(_rled)
	_rled_light = OmniLight3D.new()
	_rled_light.light_color = Color(1.0, 0.15, 0.1)
	_rled_light.light_energy = 2.5
	_rled_light.omni_range = 5.0
	_rled_light.position = _rled.position
	_rled_light.visible = false
	add_child(_rled_light)
	_rbeep = AudioStreamPlayer3D.new()
	_rbeep.stream = Fisher.make_beep()
	_rbeep.unit_size = 12.0
	_rbeep.max_distance = 60.0
	add_child(_rbeep)


func _rod_process(delta: float) -> void:
	_rt += delta
	var st: int = int(rod_st.get("st", Fisher.S.IDLE))
	if st == Fisher.S.IDLE:
		return
	if _rled != null:
		var on := st == Fisher.S.BITE and fmod(_rt, 0.6) < 0.3
		_rled.visible = on
		_rled_light.visible = on
	var tgt: Vector3 = rod_st["target"]
	var mode: int = int(rod_st["mode"])
	var bpos := tgt
	bpos.y = 0.05 + sin(_rt * 3.0) * 0.015
	if st == Fisher.S.WAITING:
		rod_st["wait_left"] = float(rod_st["wait_left"]) - delta
		if float(rod_st["wait_left"]) <= 0.0:
			var kgs: Array = [["Karpfen", 2.0, 14.0], ["Brasse", 0.5, 2.5], ["Rotauge", 0.1, 0.5], ["Barsch", 0.2, 1.2]]
			var pick: Array = kgs[0] if (mode == 0 and Game.is_night()) else kgs.pick_random()
			rod_st["fish_name"] = pick[0]
			rod_st["fish_kg"] = snappedf(randf_range(pick[1], pick[2]) * randf_range(0.6, 1.0), 0.1)
			rod_st["st"] = Fisher.S.BITE
			rod_st["bite_left"] = 12.0
			var pl := get_tree().get_first_node_in_group("local_player")
			if pl != null:
				pl.toast("BISS! An der Rute im Ständer%s hat etwas angebissen!" % (" von " + rod_owner if rod_owner != "" else ""), 4.0)
	elif st == Fisher.S.BITE:
		rod_st["bite_left"] = float(rod_st["bite_left"]) - delta
		bpos.y = -0.04 + sin(_rt * 18.0) * 0.03
		_beep_cd -= delta
		if _beep_cd <= 0.0 and mode == 0:
			_beep_cd = 0.5
			if _rbeep != null:
				_rbeep.play()
		if float(rod_st["bite_left"]) <= 0.0:
			rod_st["st"] = Fisher.S.WAITING
			rod_st["wait_left"] = randf_range(15.0, 40.0)
	if _rbob != null:
		_rbob.global_position = bpos
		var tip := global_position + global_transform.basis * Vector3(0, 1.45, -1.19)
		var m := _rline.mesh as ImmediateMesh
		m.clear_surfaces()
		m.surface_begin(Mesh.PRIMITIVE_LINES)
		m.surface_add_vertex(tip)
		m.surface_add_vertex(bpos)
		m.surface_end()


## Beim Schlafen: beißt es an einer Rute im Ständer?
func rod_bite_while_sleeping() -> bool:
	if rod_in and int(rod_st.get("st", 0)) == Fisher.S.WAITING and int(rod_st.get("mode", 0)) == 0:
		rod_st["wait_left"] = 0.0
		return true
	return false


# ---------- Rucksack (Auspacken) ----------

func _pack_label(c: Dictionary) -> String:
	var n: String = c["name"]
	if c.has("owner"):
		n += " (%s)" % c["owner"]
	return n


func _unpack(player: Node) -> void:
	if contents.is_empty():
		player.toast("Der Rucksack ist leer.", 2.0)
		return
	var idx := sel % contents.size()
	var d: Dictionary = contents[idx]
	contents.remove_at(idx)
	sel = 0
	var pivot: Node3D = parts.get("lid", null)
	if pivot != null and not open:
		open = true
		create_tween().tween_property(pivot, "rotation_degrees:x", 100.0, 0.3)
	var it := Item.new().setup(d["name"], d["weight"], d["size"], d["color"])
	get_parent().add_child(it)
	if d.has("owner"):
		it.set_owner_name(d["owner"])
	Sfx.play("click", global_position)
	if player.held == null:
		it.global_position = global_position + Vector3(0, 1.0, 0)
		player.pick_up(it)
	else:
		# Hände voll: das Teil landet neben dem Rucksack auf dem Boden
		var a := randf() * TAU
		it.global_position = global_position + Vector3(cos(a) * 0.8, 0.8, sin(a) * 0.8)
		player.toast("%s liegt jetzt neben dem Rucksack." % d["name"], 2.0)


# ---------- Kiste mit Proviant ----------

func _take_ingredient(player: Node) -> void:
	if pack.is_empty():
		player.toast("Die Kiste ist leer. (Hat ein Nutria etwas geklaut?)", 3.0)
		return
	if player.held != null:
		player.toast("Hände voll - erst ablegen.", 2.0)
		return
	var idx := sel % pack.size()
	var nm: String = pack[idx]
	pack.remove_at(idx)
	sel = 0
	var pivot: Node3D = parts.get("lid", null)
	if pivot != null and not open:
		open = true
		create_tween().tween_property(pivot, "rotation_degrees:x", 100.0, 0.3)
	var it := Item.new().setup(nm, 0.5, Vector3(0.18, 0.14, 0.18), Game.INGREDIENT_COLORS[nm])
	get_parent().add_child(it)
	it.global_position = global_position + Vector3(0, 1.0, 0)
	player.pick_up(it)


func steal_one() -> String:
	if pack.is_empty():
		return ""
	var idx := randi() % pack.size()
	var nm: String = pack[idx]
	pack.remove_at(idx)
	sel = 0
	return nm


# ---------- Feuer ----------

func _fire_use(player: Node) -> void:
	if burning:
		if player.logs > 0:
			player.logs -= 1
			logs_in += 1
			burn_left += 240.0 * (1.5 if player.character_name == "Marian" else 1.0)
			burn_left = minf(burn_left, 1500.0)
			_update_fire_visual()
			player.toast("Holzscheit nachgelegt. Das Feuer knistert.", 2.0)
		else:
			player.toast("Du hast kein Holz dabei. Nimm Scheite vom Brennholz-Bündel (E).", 3.0)
		return
	var did := false
	if tinder < 3 and player.tinder > 0:
		var n := mini(3 - tinder, player.tinder)
		tinder += n
		player.tinder -= n
		did = true
	if sticks < 4 and player.sticks > 0:
		var n2 := mini(4 - sticks, player.sticks)
		sticks += n2
		player.sticks -= n2
		did = true
	if did:
		_update_fire_visual()
		if fire_ready():
			player.toast("Zunder und Äste liegen bereit. Jetzt den Feuerstahl in die Hand und E!", 4.0)
		else:
			player.toast("Hineingelegt: Zunder %d/3, Äste %d/4." % [tinder, sticks], 3.0)
	else:
		player.toast("Du brauchst Zunder (trockenes Gras, gelbe Büschel) und Äste aus dem Wald. (Zunder %d/3, Äste %d/4)" % [tinder, sticks], 4.5)


func ignite(player: Node) -> void:
	burning = true
	Sfx.play("ignite", global_position)
	if _fire_snd == null:
		_fire_snd = Sfx.loop_at(self, "fire", -4.0)
	elif not _fire_snd.playing:
		_fire_snd.play()
	var boost := 1.5 if player != null and player.character_name == "Marian" else 1.0
	burn_left = (tinder * 20.0 + sticks * 55.0) * boost
	tinder = 0
	sticks = 0
	Game.fire_lit_once = true
	_update_fire_visual()


func extinguish(msg: String = "") -> void:
	burning = false
	if _fire_snd != null:
		_fire_snd.stop()
	burn_left = 0.0
	_update_fire_visual()


func _update_fire_visual() -> void:
	var kin: Node3D = parts.get("kindling", null)
	var lg: Node3D = parts.get("logs", null)
	var fl: Node3D = parts.get("flames", null)
	if kin != null:
		kin.visible = (tinder > 0 or sticks > 0 or burning)
	if lg != null:
		lg.visible = logs_in > 0 and burning
	if fl != null:
		fl.visible = burning
	if smoke != null:
		smoke.emitting = burning
	if fire_sparks != null:
		fire_sparks.emitting = burning
	if fire_glow != null:
		fire_glow.visible = burning
	if light != null and item_name == "Feuerschale":
		light.light_energy = 3.0 if burning else 0.0


# ---------- Kochen ----------

func add_ingredient(player: Node, held: Node) -> void:
	var nm: String = held.item_name
	if done or burnt:
		player.toast("Der Topf ist schon fertig/ruiniert.", 2.0)
		return
	var expected := _next_ingredient()
	if nm == expected:
		player.toast("%s hinzugefügt. Passt zum Rezept!" % nm, 2.5)
	else:
		wrong += 1
		quality -= 12.0
		player.toast("Hm, %s gehört laut Rezept noch nicht dazu (dran: %s). Geschmack leidet." % [nm, expected], 4.0)
	added.append(nm)
	cook_char = player.character_name
	if nm == "Gehackte Tomaten":
		pass
	player.consume_held()
	if food != null:
		food.visible = true
	if nm == "Zwiebeln" and on_grill != null and on_grill.open:
		player.toast("Zssssch! Die Zwiebeln brutzeln.", 2.0)
	_update_food_color()
	if added.size() >= Game.RECIPE.size():
		cook_t = 0.0   # ab jetzt zählt die Köchelzeit


func _oven_use(player: Node) -> void:
	if burnt:
		added.clear()
		wrong = 0
		burn = 0.0
		cook_t = 0.0
		burnt = false
		done = false
		quality = 100.0
		if food != null:
			food.visible = false
		player.toast("Topf ausgekratzt. Das war's mit dem Chili. Zutaten sind weg...", 3.5)
		return
	if done:
		if portions > 0:
			portions -= 1
			Game.chili_served += 1
			var n := player.get_node_or_null("Needs") as Needs
			if n != null:
				n.eat(0.4)
				n.ate_chili()
			player.toast("Mmmh, Chili con Carne! %s (%d Portionen übrig)" % [_rating(), portions], 4.0)
			if portions == 0:
				added.clear()
				done = false
				if food != null:
					food.visible = false
		return
	if added.is_empty():
		player.toast("Leer. Hol die Zutaten aus der Kiste und kipp sie nacheinander hinein: " + ", ".join(PackedStringArray(Game.RECIPE)), 6.0)
		return
	# Umrühren
	var bonus := 1.6 if player.character_name == "Steffen" else 1.0
	burn = maxf(burn - 0.3 * bonus, 0.0)
	cook_char = player.character_name
	var pivot: Node3D = parts.get("lid", null)
	if pivot != null:
		var tw := create_tween()
		tw.tween_property(pivot, "rotation_degrees:x", 100.0, 0.2)
		tw.tween_interval(0.8)
		tw.tween_property(pivot, "rotation_degrees:x", 0.0, 0.3)
	player.toast("Umgerührt.%s" % (" (Steffen rührt wie ein Profi)" if bonus > 1.0 else ""), 1.5)


func _rating() -> String:
	if quality >= 90.0:
		return "Fantastisch!"
	if quality >= 70.0:
		return "Richtig lecker."
	if quality >= 45.0:
		return "Geht so, aber satt."
	return "Naja... man hat schon Schlimmeres gegessen."


func _update_food_color() -> void:
	if food == null:
		return
	var base := Color(0.62, 0.2, 0.1).lerp(Color(0.45, 0.12, 0.06), clampf(float(added.size()) / 9.0, 0.0, 1.0))
	var m := Util.mat(base.lerp(Color(0.05, 0.03, 0.02), clampf(burn, 0.0, 1.0)))
	food.material_override = m


func _process(delta: float) -> void:
	if rod_in:
		_rod_process(delta)
	if item_name == "Feuerschale" and burning:
		burn_left -= delta
		_flicker += delta
		var fl: Node3D = parts.get("flames", null)
		var frac := clampf(burn_left / 120.0, 0.35, 1.0)
		if fl != null:
			fl.scale = Vector3(1, 1, 1) * frac * (1.0 + sin(_flicker * 13.0) * 0.12 + sin(_flicker * 7.3) * 0.1)
		if light != null:
			light.light_energy = (2.5 + sin(_flicker * 17.0) * 0.5 + sin(_flicker * 9.1) * 0.4) * frac
		if burn_left <= 0.0:
			burning = false
			if _fire_snd != null:
				_fire_snd.stop()
			logs_in = 0
			_update_fire_visual()
			var pl := get_tree().get_first_node_in_group("local_player")
			if pl != null:
				pl.toast("Das Feuer ist heruntergebrannt. Neues Holz nötig (und neuer Zunder!).", 4.0)
	if item_name == "Dutch Oven":
		_cook(delta)


func _cook(delta: float) -> void:
	var heated := on_grill != null and on_grill.open and not added.is_empty() and not done and not burnt
	if steam != null:
		steam.emitting = heated
	if not heated:
		return
	var steffen := cook_char == "Steffen"
	var speed := 1.25 if steffen else 1.0
	if added.size() >= Game.RECIPE.size():
		cook_t += delta * speed
	var rate := 0.016
	if added.has("Gehackte Tomaten"):
		rate = 0.007
	if steffen:
		rate *= 0.6
	burn = minf(burn + rate * delta, 1.0)
	_update_food_color()
	if burn >= 1.0:
		burnt = true
		quality = 0.0
		if steam != null:
			steam.emitting = false
		var pl := get_tree().get_first_node_in_group("local_player")
		if pl != null:
			pl.toast("ANGEBRANNT! Es stinkt nach Rauch. Das Chili ist hin.", 5.0)
		return
	if added.size() >= Game.RECIPE.size() and cook_t >= 30.0:
		done = true
		portions = 4
		quality = clampf(quality - burn * 40.0 + (10.0 if steffen else 0.0), 5.0, 100.0)
		var pl2 := get_tree().get_first_node_in_group("local_player")
		if pl2 != null:
			pl2.toast("Das Chili con Carne ist FERTIG! Riecht fantastisch. E zum Essen.", 5.0)


func get_state() -> Dictionary:
	var st := {}
	if item_name == "Bierkasten":
		st["beers"] = drinks_left()
	if item_name == "Wasserkanister":
		st["water"] = water_left
	if item_name == "Brennholz":
		st["wood"] = wood_left
	if item_name == "Kiste mit Proviant":
		st["pack"] = pack.duplicate()
	if item_name == "Rucksack":
		st["contents"] = contents.duplicate(true)
	return st


# ---------- Abbauen ----------

## Baut den Gegenstand ab und gibt ihn dem Spieler in die Hand.
func dismantle(player: Node) -> void:
	if seated_by != null:
		player.toast("Der Stuhl ist besetzt.", 2.0)
		return
	if oven != null:
		player.toast("Erst den Dutch Oven vom Grill nehmen.", 2.5)
		return
	if rod_in:
		player.toast("Erst die Rute aus dem Ständer nehmen.", 2.5)
		return
	if burning:
		player.toast("Das Feuer brennt noch!", 2.0)
		return
	if item_name == "Dutch Oven" and (not added.is_empty()):
		player.toast("Erst den Topf leeren/aufessen.", 2.5)
		return
	var it := Item.new().setup(item_name, weight, item_size, item_color)
	get_parent().add_child(it)
	it.global_position = global_position + Vector3(0, item_size.y / 2.0 + 0.2, 0)
	if item_name == "Bierkasten":
		while it.beers_left() > drinks_left():
			it.take_bottle()
	if item_name == "Wasserkanister":
		it.water_left = water_left
	if item_name == "Brennholz":
		it.extra["wood"] = wood_left
	if item_name == "Kiste mit Proviant":
		it.extra["pack"] = pack.duplicate()
	if item_name == "Rucksack":
		it.extra["contents"] = contents.duplicate(true)
		var w := 1.0
		for c in contents:
			w += float((c as Dictionary)["weight"])
		it.weight = w
		it.mass = w
	if on_grill != null:
		on_grill.oven = null
	Game.placed.erase(self)
	if Net.instance != null:
		Net.instance.send_removed(global_position, item_name)
	player.pick_up(it)
	queue_free()
