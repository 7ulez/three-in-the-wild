class_name Net
extends Node
## Mehrspieler über WebSocket (läuft im Browser und am PC): Einer hostet, bis zu 3 treten bei (Platz 4 heißt "Gast").
## Für das Internet: Alle installieren Tailscale (VPN), der Host gibt seine Tailscale-IP weiter.
## Synchronisiert: Spielerpositionen/Figuren, Tageszeit, Lagerwahl, Zelte, aufgestellte Gegenstände.
## (Nicht synchronisiert: herumliegende Gegenstände, Feuer/Kochtopf-Zustand, Fische.)

static var instance: Net = null

var main: Node
var avatars: Dictionary = {}     # peer_id -> RemoteAvatar
var slot: int = 1
var _timer: float = 0.0
var _time_timer: float = 0.0
var connected: bool = false
var status: String = ""


class RemoteAvatar:
	extends Node3D
	var label: Label3D
	var target_pos: Vector3
	var target_yaw: float = 0.0
	var char_name: String = ""
	var anim: int = 0
	var _pee: CPUParticles3D = null
	var _pee_on: bool = false
	var _vape: CPUParticles3D = null
	var _vape_on: bool = false
	var _wet_cd: float = 0.0
	var _vom: CPUParticles3D = null
	var _vom_on: bool = false
	var _vom_cd: float = 0.0

	var ghost: Node3D = null
	var _ghost_name: String = ""
	var _ghost_t: float = 0.0

	## Blaupause des Mitspielers: gleiche Form wie bei mir, halbdurchsichtig. Verschwindet, wenn keine Nachricht mehr kommt.
	func show_ghost(n: String, pos: Vector3, yaw: float, size: Vector3, on: bool) -> void:
		if not on:
			if ghost != null:
				ghost.visible = false
			return
		if ghost == null:
			ghost = Node3D.new()
			get_parent().add_child(ghost)
		if _ghost_name != n:
			_ghost_name = n
			for c in ghost.get_children():
				c.queue_free()
			var holder := Node3D.new()
			holder.position.y = size.y / 2.0
			ghost.add_child(holder)
			ItemModels.add_placed_visual(holder, n, size, Color(0.6, 0.9, 0.6))
			var gm := StandardMaterial3D.new()
			gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			gm.albedo_color = Color(0.3, 1.0, 0.3, 0.45)
			for k in holder.find_children("*", "", true, false):
				if k is Light3D or k is CPUParticles3D or k is GPUParticles3D:
					k.queue_free()
				elif k is MeshInstance3D:
					(k as MeshInstance3D).material_override = gm
					(k as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ghost.global_position = pos
		ghost.rotation.y = yaw
		ghost.visible = true
		_ghost_t = 0.5

	func puff_vape() -> void:
		if _vape == null or not is_instance_valid(_vape):
			_vape = Needs.make_vape_particles()
			add_child(_vape)
		_vape.restart()
		_vape.emitting = true
		Sfx.play("joint", global_position, -6.0, 1.0)

	func _exit_tree() -> void:
		if ghost != null and is_instance_valid(ghost):
			ghost.queue_free()

	func set_look(p_char: String, p_name: String) -> void:
		if p_char == char_name:
			# Nur bei Aenderung: jedes Setzen baut das Schild neu auf (kam bei jedem Positionspaket)
			if label != null and label.text != p_name:
				label.text = p_name
			return
		char_name = p_char
		for c in get_children():
			c.queue_free()
		Player.build_body(self, p_char)
		label = Label3D.new()
		label.text = p_name
		label.font_size = 48
		label.pixel_size = 0.005
		label.outline_size = 10
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = Vector3(0, 2.25, 0)
		add_child(label)

	var _last_pos: Vector3 = Vector3.ZERO

	func _process(delta: float) -> void:
		if ghost != null and ghost.visible:
			_ghost_t -= delta
			if _ghost_t <= 0.0:
				ghost.visible = false
		if not global_position.is_finite():
			global_position = target_pos if target_pos.is_finite() else Vector3.ZERO
		global_position = global_position.lerp(target_pos, minf(delta * 12.0, 1.0))
		if Game.dedicated:
			return
		if delta > 0.0:
			var sp := Vector2(global_position.x - _last_pos.x, global_position.z - _last_pos.z).length() / delta
			Player.animate_body(self, minf(sp, 9.0), (anim & 1) != 0, (anim & 2) != 0, (anim >> 2) & 3, (anim & 16) != 0, (anim & 32) != 0, (anim & 64) != 0, 1 if (anim & 256) != 0 else (2 if (anim & 512) != 0 else 0), (anim & 128) != 0)
		# Kotzen der anderen: gebeugte Haltung, Strahl, Lache
		Player.set_pants(self, 1 if (anim & 4096) != 0 else (2 if (anim & 8192) != 0 else 0))
		var vom_now := (anim & 1024) != 0
		Player.vomit_pose(self, vom_now, delta)
		if vom_now != _vom_on:
			_vom_on = vom_now
			if vom_now:
				if _vom == null or not is_instance_valid(_vom):
					_vom = Fx.vomit_stream()
					add_child(_vom)
				Sfx.play("retch", global_position, 2.0)
				get_tree().create_timer(1.0).timeout.connect(func() -> void:
					if _vom_on:
						Sfx.play("vomit", global_position, 4.0))
			if _vom != null and is_instance_valid(_vom):
				_vom.emitting = vom_now
		if vom_now:
			_vom_cd -= delta
			if _vom_cd <= 0.0:
				_vom_cd = 0.25
				var vp := global_position - global_transform.basis.z * 1.5
				Fx.vomit_puddle(get_parent(), Vector3(vp.x, 0.0, vp.z))
		# Vape der anderen: Rauchwolke am Kopf (Flag 64 = Vape-Animation laeuft)
		var vape_now := (anim & 64) != 0
		if vape_now != _vape_on:
			_vape_on = vape_now
			if vape_now:
				puff_vape()
		# Pinkeln der anderen: Strahl + nasse Stelle
		var pee_now := (anim & 128) != 0
		if pee_now != _pee_on:
			_pee_on = pee_now
			if pee_now and (_pee == null or not is_instance_valid(_pee)):
				_pee = Fx.pee_stream()
				add_child(_pee)
			if _pee != null and is_instance_valid(_pee):
				_pee.emitting = pee_now
				Fx.pee_show(_pee, pee_now)
			if pee_now:
				Sfx.play("trickle", global_position)
		if pee_now:
			_wet_cd -= delta
			if _wet_cd <= 0.0:
				_wet_cd = 0.1
				var tp := global_position - global_transform.basis.z * 1.8
				Fx.wet_spot(get_parent(), Vector3(tp.x, 0.0, tp.z))
		_last_pos = global_position
		rotation.y = lerp_angle(rotation.y, target_yaw, minf(delta * 12.0, 1.0))


func start(p_main: Node) -> void:
	main = p_main
	instance = self
	name = "Net"
	var peer := WebSocketMultiplayerPeer.new()
	peer.handshake_timeout = 30.0   # langsame Geräte brauchen beim Start länger
	var err := OK
	if Game.net_mode == "host":
		err = peer.create_server(Game.port)
		status = "Host (Port %d)" % Game.port
		slot = 1
		_join_ms = Time.get_ticks_msec()
	else:
		var url: String = Game.host_ip
		if Game.ws_url != "":
			url = Game.ws_url
		if not url.contains("://"):
			url = "ws://%s:%d" % [url, Game.port]
		err = peer.create_client(url)
		status = "verbinde mit %s ..." % url
	if err != OK:
		status = "Netzwerkfehler %d" % err
		return
	multiplayer.multiplayer_peer = peer
	if Game.net_mode == "host":
		Leaderboard.load_file()
	if Game.net_mode == "host" and not OS.has_feature("web"):
		var wh := WebHost.new()
		add_child(wh)
		if wh.start():
			status += " · Browser-Adresse: http://<deine-IP>:%d" % WebHost.http_port
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(func() -> void: status = "Verbindung fehlgeschlagen")
	multiplayer.server_disconnected.connect(func() -> void:
		if not (status.begins_with("Falsches") or status.begins_with("Das Spiel ist voll") or status.begins_with("Der Server ist noch nicht")):
			status = "Host hat das Spiel verlassen")


@rpc("any_peer", "reliable")
func submit_catch(e: Dictionary) -> void:
	if not is_host():
		return
	if not avatars.has(multiplayer.get_remote_sender_id()):
		return    # nur eingeloggte Spieler
	server_add(e)


## Nach einem Server-Reset: Spieler melden ihre gemerkten Bestfänge erneut (Duplikate werden ignoriert).
@rpc("any_peer", "reliable")
func submit_history(list: Array) -> void:
	if not is_host() or not avatars.has(multiplayer.get_remote_sender_id()):
		return
	var changed := false
	for e in list.slice(0, Leaderboard.MY_MAX):
		if not (e is Dictionary):
			continue
		var c := Leaderboard.sanitize(e)
		if c.is_empty() or Leaderboard.has_entry(c):
			continue
		if Leaderboard.rank_for(float(c["kg"])) < 0:
			continue
		Leaderboard.add(c)
		changed = true
	if changed:
		rpc("lb_sync", Leaderboard.entries)


func server_add(e: Dictionary) -> void:
	var c := Leaderboard.sanitize(e)
	if c.is_empty():
		return
	Leaderboard.add(c)
	rpc("lb_sync", Leaderboard.entries)


@rpc("authority", "reliable")
func lb_sync(list: Array) -> void:
	Leaderboard.set_entries(list)


func is_host() -> bool:
	return multiplayer.multiplayer_peer != null and multiplayer.is_server()


func _on_connected() -> void:
	connected = true
	status = "verbunden"
	rpc_id(1, "login", Game.password)
	get_tree().create_timer(2.5).timeout.connect(func() -> void:
		var mine := Leaderboard.my_load()
		if connected and not mine.is_empty() and multiplayer.multiplayer_peer != null:
			rpc_id(1, "submit_history", mine))


@rpc("authority", "reliable")
func denied(msg: String) -> void:
	status = msg
	Game.login_error = msg
	if main.player != null:
		main.player.toast(msg, 6.0)
	# Zurück zum Anmeldebildschirm, dort steht der Grund.
	get_tree().create_timer(1.5).timeout.connect(func() -> void:
		if is_inside_tree():
			multiplayer.multiplayer_peer = null
			get_tree().change_scene_to_file("res://menu.tscn"))


## Der Server prüft das Passwort und vergibt erst dann einen Platz.
@rpc("any_peer", "reliable")
func login(pw: String) -> void:
	if not is_host():
		return
	var id := multiplayer.get_remote_sender_id()
	if Game.password == "" or pw != Game.password:
		rpc_id(id, "denied", "Falsches Passwort." if Game.password != "" else "Der Server ist noch nicht eingerichtet (kein Passwort gesetzt).")
		get_tree().create_timer(0.5).timeout.connect(func() -> void:
			if multiplayer.multiplayer_peer != null:
				multiplayer.multiplayer_peer.disconnect_peer(id))
		return
	_admit(id)


func _on_peer_connected(_id: int) -> void:
	pass    # Platz gibt es erst nach dem Login (Passwort)


func _admit(id: int) -> void:
	# Platz vergeben: Host = 1 (nur ohne dedizierten Server), dann 2, 3, 4 (= Gast)
	var used: Array = []
	for k in avatars.keys():
		used.append(avatars[k].get_meta("slot", 0))
	var first := 1 if Game.dedicated else 2
	var s := first
	while used.has(s):
		s += 1
	if s > 4:
		rpc_id(id, "denied", "Das Spiel ist voll (4 Spieler).")
		get_tree().create_timer(0.5).timeout.connect(func() -> void:
			if multiplayer.multiplayer_peer != null:
				multiplayer.multiplayer_peer.disconnect_peer(id))
		return
	var av := _get_avatar(id)
	av.set_meta("slot", s)
	rpc_id(id, "assign_slot", s, _snapshot())
	rpc_id(id, "lb_sync", Leaderboard.entries)
	if main.player != null:
		main.player.toast("Mitspieler %d ist beigetreten." % s, 3.0)


func _on_peer_disconnected(id: int) -> void:
	_release_items_of(id)
	if Game.bench_owner == id:
		Game.bench_owner = 0
		_apply_bench()
	if nutria_puppet != null and is_instance_valid(nutria_puppet):
		nutria_puppet.queue_free()
	nutria_puppet = null
	if avatars.has(id):
		avatars[id].queue_free()
		avatars.erase(id)
		if main.player != null:
			main.player.toast("Ein Mitspieler hat das Spiel verlassen.", 3.0)


func _get_avatar(id: int) -> RemoteAvatar:
	if avatars.has(id):
		return avatars[id]
	var a := RemoteAvatar.new()
	main.add_child(a)
	avatars[id] = a
	# Neu aufgebaute Figur: Gegenstaende, die dieser Spieler gerade traegt, wieder in die Hand geben
	for nid in item_db.keys():
		if int(item_db[nid].get("h", 0)) == id:
			var it: Item = Item.find(int(nid))
			if it != null and is_instance_valid(it):
				it.attach_to(a)
	return a


## Wächter: alle Mitspieler-Figuren verwerfen und beim naechsten Positionspaket frisch aufbauen.
## (Wenn ein Spieler das Spiel verlaesst, ist der Bildfehler weg - das ahmt das nach.)
func rebuild_avatars() -> void:
	if is_host():
		return
	for id in avatars.keys():
		var a: RemoteAvatar = avatars[id]
		if a == null or not is_instance_valid(a):
			continue
		for c in a.get_children():
			if c is Item:
				(c as Item).detach_to(main, (c as Item).global_position, (c as Item).global_transform.basis.get_rotation_quaternion())
		a.queue_free()
	avatars.clear()


func _snapshot() -> Dictionary:
	var pl: Array = []
	for p in Game.placed:
		if is_instance_valid(p):
			pl.append({"n": p.item_name, "w": p.weight, "s": p.item_size, "c": p.item_color,
				"p": p.global_position, "y": p.rotation.y, "st": p.get_state()})
	var tents: Array = []
	for t in Game.tents:
		if is_instance_valid(t) and t.finished:
			tents.append({"p": t.global_position, "y": t.rotation.y})
	var cars: Array = []
	for k in Game.cars_state.keys():
		cars.append({"i": int(k), "o": bool(Game.cars_state[k])})
	return {"hour": Game.hour, "day": Game.day_count, "camp": Game.camp_name if Game.camp_claimed else "",
		"placed": pl, "tents": tents, "cars": cars, "goals": Game.goal_shared.duplicate(),
		"items": item_db.values(), "stashes": Game.stashes_opened.keys(),
		"stats": Game.stats_all.duplicate(true), "finale": Game.all_done_shown,
		"flag": Game.flag_hoisted, "bench": maxi(Game.bench_owner, 0)}


@rpc("authority", "reliable")
func assign_slot(s: int, snap: Dictionary) -> void:
	slot = s
	_join_ms = Time.get_ticks_msec()
	if s == 4:
		Game.player_name = "Gast"
	status = "Platz %d%s" % [s, " (Gast)" if s == 4 else ""]
	Game.hour = snap["hour"]
	Game.day_count = snap["day"]
	if snap["camp"] != "":
		_claim_by_name(snap["camp"])
	for d in snap["placed"]:
		_create_placed(d["n"], d["w"], d["s"], d["c"], d["p"], d["y"], d["st"])
	for t in snap["tents"]:
		_create_tent(t["p"], t["y"])
	# Autos, die schon ausgeladen wurden, bleiben leer; erledigte Ziele gelten auch fuer den Neuen
	for cd in snap.get("cars", []):
		for c in main.get_tree().get_nodes_in_group("cars"):
			if c.car_index == int(cd["i"]):
				c.restore_emptied(bool(cd["o"]))
	for si in snap.get("stashes", []):
		_open_stash(int(si))
	Game.flag_hoisted = bool(snap.get("flag", false))
	for f in main.get_tree().get_nodes_in_group("flagpole"):
		f.set_hoisted(Game.flag_hoisted, false)
	Game.bench_owner = int(snap.get("bench", 0))
	_apply_bench()
	for d in snap.get("items", []):
		item_db[int(d["id"])] = d
		_item_create(d)
	var st: Dictionary = snap.get("stats", {})
	for k in st.keys():
		Game.stats_all[str(k)] = st[k]
	if bool(snap.get("finale", false)):
		Game.all_done_shown = true
	var sg: Dictionary = snap.get("goals", {})
	for k in sg.keys():
		Game.goal_shared[int(k)] = sg[k]
	Game.goals_done_prev = Game.goals().map(func(g): return g[1])
	if main.player != null:
		main.player.toast("Verbunden - du bist Spieler %d%s." % [s, " (Gast)" if s == 4 else ""], 4.0)


func _process(delta: float) -> void:
	if multiplayer.multiplayer_peer == null or main == null:
		return
	if main.player == null and not Game.dedicated:
		return
	if multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	_timer += delta
	if _timer >= 0.066 and Game.dedicated:
		_timer = 0.0
	elif _timer >= 0.066:
		_timer = 0.0
		var p: Player = main.player
		rpc("sync_state", p.global_position, p.rotation.y, p.character_name, Game.player_name, p.sleeping or p.tent_lying != null, p.anim_flags())
	_authority_tick(delta)
	if is_host():
		_skip_t += delta
		if _skip_t > 0.5:
			_skip_t = 0.0
			_check_night_skip()
		_time_timer += delta
		if _time_timer > 3.0:
			_time_timer = 0.0
			rpc("sync_time", Game.hour, Game.day_count, Weather.kind)


var _skip_t: float = 0.0


## Host: liegen alle (Zelt/Hängematte) und ist es Nacht, wird bis zum Morgen übersprungen.
func _check_night_skip() -> void:
	if not Game.is_night():
		return
	var n := 0
	var p: Player = main.player
	if p != null and not Game.dedicated:
		if not p.is_lying():
			return
		n += 1
	for id in avatars.keys():
		var a = avatars[id]
		if not is_instance_valid(a):
			continue
		if (int(a.anim) & 2048) == 0:
			return
		n += 1
	if n == 0:
		return
	if Game.hour >= 12.0:
		Game.day_count += 1
	Game.hour = 6.5
	if main.get("weather") != null:
		(main.weather as Weather).set_kind(Weather.K.CLEAR, false)
	rpc("sync_time", Game.hour, Game.day_count, Weather.kind)
	rpc("remote_night_skipped")


@rpc("authority", "reliable", "call_local")
func remote_night_skipped() -> void:
	if main != null and main.player != null:
		main.player.night_skipped()


@rpc("any_peer", "unreliable_ordered")
func sync_state(pos: Vector3, yaw: float, char_name: String, p_name: String, sleeping: bool, anim: int = 0) -> void:
	if not pos.is_finite() or not is_finite(yaw) or pos.length() > 5000.0:
		return
	var id := multiplayer.get_remote_sender_id()
	if is_host() and not (avatars.has(id) and avatars[id].has_meta("slot")):
		return
	var av := _get_avatar(id)
	if av.char_name == "":
		av.global_position = pos
	av.target_pos = pos
	av.target_yaw = yaw
	av.anim = anim
	av.set_look(char_name, p_name)
	av.visible = not sleeping


@rpc("authority", "unreliable")
func sync_time(h: float, d: int, w: int = 0) -> void:
	Game.hour = h
	Game.day_count = d
	_apply_weather(w)


func _apply_weather(w: int) -> void:
	if main != null and main.get("weather") != null:
		(main.weather as Weather).remote_set(w)
	else:
		Weather.kind = w


@rpc("authority", "reliable")
func remote_weather(w: int) -> void:
	_apply_weather(w)


func send_weather(w: int) -> void:
	rpc("remote_weather", w)


# ---------- Ereignisse senden ----------

func send_trunk(i: int, open: bool) -> void:
	rpc("remote_trunk", i, open)


@rpc("any_peer", "reliable")
func remote_trunk(i: int, open: bool) -> void:
	if open or Game.cars_state.has(i):
		Game.cars_state[i] = open
	# Nur diese eine Klappe geht bei den anderen auf; das Gepaeck kommt ueber die Gegenstands-Meldungen
	if main == null or Game.dedicated:
		return
	for c in main.get_tree().get_nodes_in_group("cars"):
		if c.car_index == i:
			c.set_trunk(open, true)


func send_flag(h: bool) -> void:
	rpc("remote_flag", h)


@rpc("any_peer", "reliable")
func remote_flag(h: bool) -> void:
	Game.flag_hoisted = h
	if main == null or Game.dedicated:
		return
	for f in main.get_tree().get_nodes_in_group("flagpole"):
		f.set_hoisted(h, true)


func send_bench(taken: bool) -> void:
	rpc("remote_bench", taken)


@rpc("any_peer", "reliable")
func remote_bench(taken: bool) -> void:
	Game.bench_owner = multiplayer.get_remote_sender_id() if taken else 0
	_apply_bench()


## Gipfelbank bei allen als besetzt/frei markieren (besetzt = seated_by zeigt auf die Bank selbst).
func _apply_bench() -> void:
	if main == null or Game.dedicated:
		return
	for b in main.get_tree().get_nodes_in_group("summit_bench"):
		if Game.bench_owner > 0:
			b.seated_by = b
		elif Game.bench_owner == 0 and b.seated_by == b:
			b.seated_by = null


func send_goal(i: int, who: String) -> void:
	rpc("remote_goal", i, who)


@rpc("any_peer", "reliable")
func remote_goal(i: int, who: String) -> void:
	if not Game.goal_shared.has(i):
		Game.goal_shared[i] = who


func send_camp(spot_name: String) -> void:
	rpc("remote_camp", spot_name)


func send_tent(pos: Vector3, yaw: float) -> void:
	rpc("remote_tent", pos, yaw)


## Blaupause eines Gegenstands, der gerade aufgestellt wird (fuer alle Mitspieler sichtbar).
func send_ghost(n: String, pos: Vector3, yaw: float, size: Vector3, on: bool) -> void:
	if multiplayer.multiplayer_peer == null or multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	rpc("remote_ghost", n, pos, yaw, size, on)


@rpc("any_peer", "unreliable")
func remote_ghost(n: String, pos: Vector3, yaw: float, size: Vector3, on: bool) -> void:
	var id := multiplayer.get_remote_sender_id()
	if Game.dedicated:
		return
	var av := _get_avatar(id)
	av.show_ghost(n, pos, yaw, size, on)


func send_placed(p: PlacedItem, state: Dictionary) -> void:
	rpc("remote_placed", p.item_name, p.weight, p.item_size, p.item_color, p.global_position, p.rotation.y, state)


func send_poop(pos: Vector3, variant: int = 0) -> void:
	rpc("remote_poop", pos, variant)


@rpc("any_peer", "reliable")
func remote_poop(pos: Vector3, variant: int = 0) -> void:
	if main == null or main.player == null:
		return
	var pile := Poop.new()
	pile.variant = variant
	main.add_child(pile)
	pile.build()
	pile.global_position = pos
	Sfx.play("plop", pos)


## Luftgewehr: Schuss für alle sichtbar und hörbar machen
func send_shot(from: Vector3, to: Vector3) -> void:
	rpc("remote_shot", from, to)


@rpc("any_peer", "unreliable")
func remote_shot(from: Vector3, to: Vector3) -> void:
	if main == null or main.player == null:
		return
	Sfx.play("airgun", from, 0.0)
	Fx.tracer(main, from, to)


## Treffer auf einen Mitspieler: nur dessen Spiel zieht die Gesundheit ab
func send_hit(victim: String, dmg: float, shooter: String) -> void:
	rpc("remote_hit", victim, dmg, shooter)


@rpc("any_peer", "reliable")
func remote_hit(victim: String, dmg: float, shooter: String) -> void:
	if main == null or main.player == null:
		return
	if victim != Game.player_name:
		return
	var pl: Player = main.player
	if pl.needs != null:
		pl.shake = 2.0
		pl.needs.damage(dmg, "%s hat dich mit dem Luftgewehr getroffen." % shooter)


## Radio: an/aus und Sender für alle
func send_radio(on: bool, idx: int, vol: float = 0.7) -> void:
	rpc("remote_radio", on, idx, vol)


@rpc("any_peer", "reliable")
func remote_radio(on: bool, idx: int, vol: float = 0.7) -> void:
	if main != null and main.get("radio") != null:
		(main.radio as Radio).remote_set(on, idx, vol)


## Erschossenes Tier: bei allen Mitspielern fällt das nächstgelegene Tier derselben Art um (samt Blutlache)
func send_kill(kind: String, pos: Vector3) -> void:
	rpc("remote_kill", kind, pos)


@rpc("any_peer", "reliable")
func remote_kill(kind: String, pos: Vector3) -> void:
	if main == null:
		return
	var fa := main.get_node_or_null("Fauna")
	if fa != null:
		fa.kill_near(kind, pos)


func send_removed(pos: Vector3, item_name: String) -> void:
	rpc("remote_removed", pos, item_name)


@rpc("any_peer", "reliable")
func remote_camp(spot_name: String) -> void:
	_claim_by_name(spot_name)


@rpc("any_peer", "reliable")
func remote_tent(pos: Vector3, yaw: float) -> void:
	var site := _find_tent_site(pos)
	if site != null:
		_finish_site(site)
	elif _find_in_group("tent_done", pos) == null:
		_create_tent(pos, yaw)


## Zelt steht (von einem Mitspieler gemeldet oder durch seine vier Heringe)
func _finish_site(t: Tent) -> void:
	if t.finished:
		return
	Game.tents.append(t)
	if not Game.camp_claimed:
		Game.claim_camp(t.global_position, main)
	t._finish(null)


## Zelt-Aufbau: die ausgelegte Plane mit den Heringen sehen alle Mitspieler.
func send_tent_site(pos: Vector3, yaw: float) -> void:
	rpc("remote_tent_site", pos, yaw)


@rpc("any_peer", "reliable")
func remote_tent_site(pos: Vector3, yaw: float) -> void:
	if Game.dedicated or main == null or _find_tent_site(pos) != null:
		return
	var t := Tent.new()
	main.add_child(t)
	t.build_ghost()
	t.global_position = pos
	t.rotation.y = yaw
	t.begin_site()


## Ein Hering wurde eingeschlagen (Anzahl Schläge).
func send_peg(tent_pos: Vector3, idx: int, hits: int) -> void:
	rpc("remote_peg", tent_pos, idx, hits)


@rpc("any_peer", "reliable")
func remote_peg(tent_pos: Vector3, idx: int, hits: int) -> void:
	if Game.dedicated:
		return
	var t := _find_tent_site(tent_pos)
	if t == null or idx < 0 or idx >= t.peg_list.size():
		return
	var peg := t.peg_list[idx] as TentPeg
	if peg == null or peg.is_driven():
		return
	peg.hits = hits
	if peg.visual != null:
		create_tween().tween_property(peg.visual, "position:y", 0.17 - 0.1 * hits, 0.12)
	if peg.is_driven() and t.peg_driven_count() >= 4:
		_finish_site(t)


func _find_tent_site(pos: Vector3) -> Tent:
	return _find_in_group("tent_site", pos)


func _find_in_group(g: String, pos: Vector3) -> Tent:
	if main == null:
		return null
	for n in get_tree().get_nodes_in_group(g):
		var t := n as Tent
		if t != null and is_instance_valid(t) and t.global_position.distance_to(pos) < 0.6:
			return t
	return null


@rpc("any_peer", "reliable")
func remote_placed(n: String, w: float, s: Vector3, c: Color, pos: Vector3, yaw: float, state: Dictionary) -> void:
	_create_placed(n, w, s, c, pos, yaw, state)


@rpc("any_peer", "reliable")
func remote_removed(pos: Vector3, n: String) -> void:
	for p in Game.placed:
		if is_instance_valid(p) and p.item_name == n and p.global_position.distance_to(pos) < 0.3:
			if p.on_grill != null:
				p.on_grill.oven = null
			Game.placed.erase(p)
			p.queue_free()
			return



func _exit_tree() -> void:
	if instance == self:
		instance = null


# ---------- Gegenstaende: jeder existiert nur einmal fuer alle ----------

var item_db: Dictionary = {}       # net_id -> Beschreibung (Name, Zustand, Ort, wer traegt)
var _item_ctr: int = 0


func alloc_item_id() -> int:
	if multiplayer.multiplayer_peer == null or multiplayer.get_unique_id() <= 0:
		return 0
	_item_ctr += 1
	return multiplayer.get_unique_id() * 100000 + _item_ctr


func item_desc(it: Item) -> Dictionary:
	var d := {"id": it.net_id, "n": it.item_name, "w": it.weight, "s": it.item_size, "c": it.item_color,
		"x": it.extra.duplicate(true), "p": it.global_position, "q": it.global_transform.basis.get_rotation_quaternion(),
		"h": 0, "b": -1, "wa": -1}
	if it.item_name == "Bierkasten":
		d["b"] = it.beers_left()
	if it.item_name == "Wasserflasche" or it.item_name == "Jack-Cola-Kiste":
		d["wa"] = it.water_left
	return d


## Neuer Gegenstand: den Mitspielern melden (einmalig).
func item_announce(it: Item) -> void:
	if it.net_id == 0 or it.net_announced or it.remote_created:
		return
	it.net_announced = true
	var d := item_desc(it)
	item_db[it.net_id] = d
	rpc("remote_item_spawn", d)


@rpc("any_peer", "reliable")
func remote_item_spawn(d: Dictionary) -> void:
	d["h"] = 0
	item_db[int(d["id"])] = d
	if Game.dedicated or main == null or Item.find(int(d["id"])) != null:
		return
	_item_create(d)


func _item_create(d: Dictionary) -> void:
	if main == null or Game.dedicated:
		return
	var id := int(d["id"])
	if Item.find(id) != null:
		return
	var it := Item.new().setup(d["n"], d["w"], d["s"], d["c"])
	it.net_id = id
	it.remote_created = true
	it.net_announced = true
	main.add_child(it)
	it.apply_net_state(d["x"], int(d["b"]), int(d["wa"]))
	it.global_position = d["p"]
	it.global_transform.basis = Basis(d["q"])
	it.make_remote()
	it._tgt_pos = d["p"]
	it._tgt_q = d["q"]
	it._has_tgt = true
	var h := int(d["h"])
	if h != 0 and h != multiplayer.get_unique_id():
		it.attach_to(_get_avatar(h))


func item_grab(it: Item) -> void:
	if it.net_id == 0:
		return
	item_announce(it)
	if item_db.has(it.net_id):
		item_db[it.net_id]["h"] = multiplayer.get_unique_id()
	rpc("remote_item_grab", it.net_id)


@rpc("any_peer", "reliable")
func remote_item_grab(id: int) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if item_db.has(id):
		item_db[id]["h"] = sender
	if Game.dedicated or main == null:
		return
	var it: Item = Item.find(id)
	if it == null:
		return
	if main.player != null and main.player.held == it:
		# Beide haben gleichzeitig zugegriffen: der Kleinere gewinnt
		if sender < multiplayer.get_unique_id():
			main.player.lose_held(it)
		else:
			return
	it.attach_to(_get_avatar(sender))


func item_release(it: Item) -> void:
	if it.net_id == 0:
		return
	item_announce(it)
	var q := it.global_transform.basis.get_rotation_quaternion()
	if item_db.has(it.net_id):
		item_db[it.net_id]["h"] = 0
		item_db[it.net_id]["p"] = it.global_position
		item_db[it.net_id]["q"] = q
		item_db[it.net_id]["x"] = it.extra.duplicate(true)
		if it.item_name == "Bierkasten":
			item_db[it.net_id]["b"] = it.beers_left()
		if it.item_name == "Wasserflasche" or it.item_name == "Jack-Cola-Kiste":
			item_db[it.net_id]["wa"] = it.water_left
	it._rest_sent = false
	rpc("remote_item_release", it.net_id, it.global_position, q, item_desc(it))


@rpc("any_peer", "reliable")
func remote_item_release(id: int, pos: Vector3, q: Quaternion, d: Dictionary) -> void:
	if item_db.has(id):
		item_db[id]["h"] = 0
		item_db[id]["p"] = pos
		item_db[id]["q"] = q
		item_db[id]["x"] = d["x"]
		item_db[id]["b"] = d["b"]
		item_db[id]["wa"] = d["wa"]
	else:
		d["h"] = 0
		item_db[id] = d
	if Game.dedicated or main == null:
		return
	var it: Item = Item.find(id)
	if it == null:
		_item_create(item_db[id])
		return
	it.apply_net_state(d["x"], int(d["b"]), int(d["wa"]))
	it.detach_to(main, pos, q)


func item_pos(it: Item) -> void:
	rpc("remote_item_pos", it.net_id, it.global_position, it.global_transform.basis.get_rotation_quaternion())


@rpc("any_peer", "unreliable_ordered")
func remote_item_pos(id: int, pos: Vector3, q: Quaternion) -> void:
	if item_db.has(id):
		item_db[id]["p"] = pos
		item_db[id]["q"] = q
	if Game.dedicated or main == null:
		return
	var it: Item = Item.find(id)
	if it != null and it.remote and not it.net_attached:
		it._tgt_pos = pos
		it._tgt_q = q
		it._has_tgt = true


func item_rest(it: Item) -> void:
	var q := it.global_transform.basis.get_rotation_quaternion()
	if item_db.has(it.net_id):
		item_db[it.net_id]["p"] = it.global_position
		item_db[it.net_id]["q"] = q
	rpc("remote_item_rest", it.net_id, it.global_position, q)


@rpc("any_peer", "reliable")
func remote_item_rest(id: int, pos: Vector3, q: Quaternion) -> void:
	if item_db.has(id):
		item_db[id]["p"] = pos
		item_db[id]["q"] = q
	if Game.dedicated or main == null:
		return
	var it: Item = Item.find(id)
	if it != null and it.remote and not it.net_attached:
		it._tgt_pos = pos
		it._tgt_q = q
		it._has_tgt = true


func item_gone(id: int) -> void:
	item_db.erase(id)
	if multiplayer.multiplayer_peer != null:
		rpc("remote_item_gone", id)


@rpc("any_peer", "reliable")
func remote_item_gone(id: int) -> void:
	item_db.erase(id)
	if Game.dedicated or main == null:
		return
	var it: Item = Item.find(id)
	if it == null:
		return
	it.net_silent = true
	if main.player != null and main.player.held == it:
		main.player.lose_held(it)
	it.queue_free()


func item_state(it: Item) -> void:
	if it.net_id == 0:
		return
	item_announce(it)
	var d := item_desc(it)
	if item_db.has(it.net_id):
		item_db[it.net_id]["x"] = d["x"]
		item_db[it.net_id]["b"] = d["b"]
		item_db[it.net_id]["wa"] = d["wa"]
	rpc("remote_item_state", it.net_id, d["x"], d["b"], d["wa"])


@rpc("any_peer", "reliable")
func remote_item_state(id: int, x: Dictionary, beers: int, water: int) -> void:
	if item_db.has(id):
		item_db[id]["x"] = x
		item_db[id]["b"] = beers
		item_db[id]["wa"] = water
	if Game.dedicated or main == null:
		return
	var it: Item = Item.find(id)
	if it != null:
		it.apply_net_state(x, beers, water)


## Ein Mitspieler geht: was er getragen hat, bleibt an seiner letzten Stelle liegen.
func _release_items_of(peer: int) -> void:
	var av: Node3D = avatars.get(peer, null)
	var at: Vector3 = av.global_position + Vector3(0, 0.4, 0) if av != null else Vector3(0, 1, 10)
	for k in item_db.keys():
		var d: Dictionary = item_db[k]
		if int(d["h"]) == peer:
			d["h"] = 0
			d["p"] = at
			if not Game.dedicated and main != null:
				var it: Item = Item.find(int(k))
				if it != null:
					it.detach_to(main, at, d["q"])


## Aufgestellter Gegenstand hat sich veraendert (Feuer, Topf, Grill, Behaelter, Rute): allen melden.
func send_placed_state(p: PlacedItem) -> void:
	if multiplayer.multiplayer_peer == null or multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	rpc("remote_placed_state", p.global_position, p.item_name, p.get_state())


@rpc("any_peer", "reliable")
func remote_placed_state(pos: Vector3, n: String, st: Dictionary) -> void:
	for p in Game.placed:
		if is_instance_valid(p) and p.item_name == n and p.global_position.distance_to(pos) < 0.3:
			if p.stirrer != null:
				st.erase("oven")     # ich ruehre gerade selbst: meinen Stand behalten
			p.apply_state(st)
			return


# ---------- Welt-Verantwortung: einer simuliert Tiere, Nutria und Zufall fuer alle ----------

var _join_ms: int = -1
var _auth_t: float = 0.0
var _fauna_t: float = 0.0
var _nutria_t: float = 0.0
var nutria_puppet: Nutria = null


## Der Spieler mit der kleinsten Netz-ID simuliert die gemeinsame Welt (Tiere, Nutria, Bisse am Ständer).
func is_world_authority() -> bool:
	if multiplayer.multiplayer_peer == null:
		return true
	if Game.dedicated or _join_ms < 0:
		return false
	if not is_host() and Time.get_ticks_msec() - _join_ms < 6000:
		return false
	var me := multiplayer.get_unique_id()
	for k in avatars.keys():
		if int(k) < me:
			return false
	return true


func _authority_tick(delta: float) -> void:
	if not is_world_authority():
		return
	# Feuer, Topf und Ruten regelmaessig abgleichen (kleine Abweichungen der Zeit ausgleichen)
	_auth_t += delta
	if _auth_t > 4.0:
		_auth_t = 0.0
		for p in Game.placed:
			if not is_instance_valid(p):
				continue
			if (p.item_name == "Feuerschale" and p.burning) or (p.item_name == "Dutch Oven" and not p.added.is_empty()) or (p.item_name == "Rutenständer" and p.rod_in) or (p.item_name == "Gasgrill" and p.open):
				send_placed_state(p)
	# Tiere
	_fauna_t += delta
	if _fauna_t > 0.2:
		_fauna_t = 0.0
		var fa: Fauna = main.get_node_or_null("Fauna")
		if fa != null:
			rpc("remote_fauna", fa.export_net())
	# Nutria
	_nutria_t += delta
	if _nutria_t > 0.12:
		_nutria_t = 0.0
		var nv: Variant = main.get("nutria_active")
		var on := nv != null and is_instance_valid(nv) and not (nv as Nutria).is_queued_for_deletion()
		if on:
			var nu := nv as Nutria
			rpc("remote_nutria", true, nu.global_position, nu.rotation.y, nu._cur_anim)
		elif _nutria_was_on:
			rpc("remote_nutria", false, Vector3.ZERO, 0.0, "")
		_nutria_was_on = on


var _nutria_was_on: bool = false


@rpc("any_peer", "unreliable_ordered")
func remote_fauna(list: Array) -> void:
	if Game.dedicated or main == null or is_world_authority():
		return
	var fa: Fauna = main.get_node_or_null("Fauna")
	if fa != null:
		fa.import_net(list)


@rpc("any_peer", "unreliable_ordered")
func remote_nutria(on: bool, pos: Vector3, yaw: float, anim: String) -> void:
	if Game.dedicated or main == null or is_world_authority():
		return
	if not on:
		if nutria_puppet != null and is_instance_valid(nutria_puppet):
			nutria_puppet.queue_free()
		nutria_puppet = null
		return
	if nutria_puppet == null or not is_instance_valid(nutria_puppet):
		nutria_puppet = Nutria.new()
		nutria_puppet.puppet = true
		main.add_child(nutria_puppet)
		nutria_puppet.setup(main, pos)
		nutria_puppet.rotation.y = yaw
	nutria_puppet.net_pos = pos
	nutria_puppet.net_yaw = yaw
	nutria_puppet.net_anim = anim


func send_fish_jump(p: Vector3, dir: Vector3, sp: int = 0) -> void:
	rpc("remote_fish_jump", p, dir, sp)


@rpc("any_peer", "reliable")
func remote_fish_jump(p: Vector3, dir: Vector3, sp: int = 0) -> void:
	if Game.dedicated or main == null:
		return
	var fa: Fauna = main.get_node_or_null("Fauna")
	if fa != null:
		fa.fish_jump_at(p, dir, sp)


## Meldung fuer alle, die in der Naehe sind (z.B. das Nutria klaut etwas).
func send_toast_near(pos: Vector3, msg: String, radius: float = 35.0) -> void:
	rpc("remote_toast_near", pos, msg, radius)


@rpc("any_peer", "reliable")
func remote_toast_near(pos: Vector3, msg: String, radius: float) -> void:
	if Game.dedicated or main == null or main.player == null:
		return
	if main.player.global_position.distance_to(pos) < radius:
		main.player.toast(msg, 3.0)


# ---------- Finale / Statistik ----------

func send_stats(who: String, d: Dictionary) -> void:
	Game.stats_all[who] = d
	rpc("remote_stats", who, d)


@rpc("any_peer", "reliable")
func remote_stats(who: String, d: Dictionary) -> void:
	Game.stats_all[who] = d


## Das Finale hat begonnen (Server merkt es sich fuer spaeter Dazukommende).
func send_finale_flag() -> void:
	rpc("remote_finale_flag")


@rpc("any_peer", "reliable")
func remote_finale_flag() -> void:
	Game.all_done_shown = true


## Fuers Feuerwerk: Abend machen. Die Uhr gehoert dem Host/Server.
func request_evening() -> void:
	if is_host():
		_set_evening()
	else:
		rpc("remote_evening")


@rpc("any_peer", "reliable")
func remote_evening() -> void:
	if is_host():
		_set_evening()


func _set_evening() -> void:
	if Game.hour >= 20.5 or Game.hour < 5.0:
		return
	Game.hour = 21.0
	rpc("sync_time", Game.hour, Game.day_count, Weather.kind)


# ---------- Verstecke ----------

func send_stash(i: int) -> void:
	Game.stashes_opened[i] = true
	rpc("remote_stash", i)


@rpc("any_peer", "reliable")
func remote_stash(i: int) -> void:
	_open_stash(i)


func _open_stash(i: int) -> void:
	Game.stashes_opened[i] = true
	for st in Stash.all:
		if is_instance_valid(st) and (st as Stash).index == i:
			(st as Stash).open_remote()


# ---------- Ereignisse empfangen ----------

func _claim_by_name(spot_name: String) -> void:
	return    # Lager entsteht jetzt mit dem ersten Zelt


func _create_tent(pos: Vector3, yaw: float) -> void:
	var t := Tent.new()
	main.add_child(t)
	t.build_ghost()
	t.global_position = pos
	t.rotation.y = yaw
	t.begin_site()
	t._finish(null)
	Game.tents.append(t)
	Game.claim_camp(pos, main)


func _create_placed(n: String, w: float, s: Vector3, c: Color, pos: Vector3, yaw: float, state: Dictionary) -> void:
	var p := PlacedItem.new()
	main.add_child(p)
	p.build(n, w, s, c, state)
	p.global_position = pos
	p.rotation.y = yaw
	Game.placed.append(p)
	if n == "Dutch Oven":
		for g in Game.placed:
			if g != p and is_instance_valid(g) and g.item_name == "Gasgrill" and Vector2(g.global_position.x - pos.x, g.global_position.z - pos.z).length() < 0.2:
				g.oven = p
				p.on_grill = g
