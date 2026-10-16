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
	var _wet_cd: float = 0.0
	var _vom: CPUParticles3D = null
	var _vom_on: bool = false
	var _vom_cd: float = 0.0

	func set_look(p_char: String, p_name: String) -> void:
		if p_char == char_name:
			if label != null:
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
		global_position = global_position.lerp(target_pos, minf(delta * 12.0, 1.0))
		if delta > 0.0:
			var sp := Vector2(global_position.x - _last_pos.x, global_position.z - _last_pos.z).length() / delta
			Player.animate_body(self, minf(sp, 9.0), (anim & 1) != 0, (anim & 2) != 0, (anim >> 2) & 3, (anim & 16) != 0, (anim & 32) != 0, (anim & 64) != 0, 1 if (anim & 256) != 0 else (2 if (anim & 512) != 0 else 0), (anim & 128) != 0)
		# Kotzen der anderen: gebeugte Haltung, Strahl, Lache
		var vom_now := (anim & 1024) != 0
		Player.vomit_pose(self, vom_now, delta)
		if _vom == null:
			_vom = Fx.vomit_stream()
			add_child(_vom)
		if vom_now != _vom_on:
			_vom_on = vom_now
			if vom_now:
				Sfx.play("retch", global_position, 2.0)
				get_tree().create_timer(1.0).timeout.connect(func() -> void:
					if _vom_on:
						Sfx.play("vomit", global_position, 4.0))
		_vom.emitting = vom_now
		if vom_now:
			_vom_cd -= delta
			if _vom_cd <= 0.0:
				_vom_cd = 0.25
				var vp := global_position - global_transform.basis.z * 1.5
				Fx.vomit_puddle(get_parent(), Vector3(vp.x, 0.0, vp.z))
		# Pinkeln der anderen: Strahl + nasse Stelle
		var pee_now := (anim & 128) != 0
		if _pee == null:
			_pee = Fx.pee_stream()
			add_child(_pee)
		if pee_now != _pee_on:
			_pee_on = pee_now
			_pee.emitting = pee_now
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
	return a


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
	return {"hour": Game.hour, "day": Game.day_count, "camp": Game.camp_name if Game.camp_claimed else "",
		"placed": pl, "tents": tents}


@rpc("authority", "reliable")
func assign_slot(s: int, snap: Dictionary) -> void:
	slot = s
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
		rpc("sync_state", p.global_position, p.rotation.y, p.character_name, Game.player_name, p.sleeping, p.anim_flags())
	if is_host():
		_time_timer += delta
		if _time_timer > 3.0:
			_time_timer = 0.0
			rpc("sync_time", Game.hour, Game.day_count, Weather.kind)


@rpc("any_peer", "unreliable_ordered")
func sync_state(pos: Vector3, yaw: float, char_name: String, p_name: String, sleeping: bool, anim: int = 0) -> void:
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

func send_camp(spot_name: String) -> void:
	rpc("remote_camp", spot_name)


func send_tent(pos: Vector3, yaw: float) -> void:
	rpc("remote_tent", pos, yaw)


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


func send_removed(pos: Vector3, item_name: String) -> void:
	rpc("remote_removed", pos, item_name)


@rpc("any_peer", "reliable")
func remote_camp(spot_name: String) -> void:
	_claim_by_name(spot_name)


@rpc("any_peer", "reliable")
func remote_tent(pos: Vector3, yaw: float) -> void:
	_create_tent(pos, yaw)


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
