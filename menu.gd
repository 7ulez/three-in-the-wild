extends Control
## Startmenü: Name, Charakter, Solo / Hosten / Beitreten.

var name_edit: LineEdit
var char_pick: OptionButton
var ip_edit: LineEdit
var info: Label


var pw_edit: LineEdit


func _ready() -> void:
	if "--server" in OS.get_cmdline_user_args():
		_start_dedicated()
		return
	if OS.has_feature("web"):
		Game.touch = bool(JavaScriptBridge.eval("window.matchMedia('(pointer: coarse)').matches || window.location.search.includes('touch')"))
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.16, 0.12)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(460, 0)
	box.position = Vector2(-230, -280)
	box.add_theme_constant_override("separation", 10)
	add_child(box)

	var title := Label.new()
	title.text = "THREE IN THE WILD"
	title.add_theme_font_size_override("font_size", 42)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var sub := Label.new()
	sub.text = "Auto ausladen · Camp aufbauen · Feuer · Angeln · Chili kochen"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)

	name_edit = _row(box, "Name", LineEdit.new())
	name_edit.text = Game.player_name
	char_pick = _row(box, "Charakter", OptionButton.new())
	for c in ["Marian (Feuer, flucht)", "Steffen (Koch)", "Julian (Vape)"]:
		char_pick.add_item(c)

	var solo := Button.new()
	solo.text = "Solo spielen"
	solo.pressed.connect(_start.bind("solo"))
	box.add_child(solo)
	var host := Button.new()
	host.text = "Spiel hosten (bis zu 4 Spieler, Platz 4 = Gast)"
	host.pressed.connect(_start.bind("host"))
	box.add_child(host)
	host.visible = not OS.has_feature("web")
	ip_edit = _row(box, "Host-IP", LineEdit.new())
	ip_edit.text = Game.host_ip
	if OS.has_feature("web"):
		var hn: Variant = JavaScriptBridge.eval("window.location.hostname")
		if hn is String and hn != "":
			ip_edit.text = hn
	pw_edit = _row(box, "Passwort", LineEdit.new())
	pw_edit.secret = true
	pw_edit.placeholder_text = "leer = kein Passwort"
	var join := Button.new()
	join.text = "Beitreten"
	join.pressed.connect(_start.bind("join"))
	box.add_child(join)

	if OS.has_feature("web"):
		var req := HTTPRequest.new()
		add_child(req)
		req.request_completed.connect(func(_r: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
			var t: String = body.get_string_from_utf8().strip_edges()
			if code == 200 and t.begins_with("ws"):
				Game.ws_url = t
				ip_edit.text = t
				ip_edit.editable = false)
		var origin: Variant = JavaScriptBridge.eval("window.location.origin")
		req.request(str(origin) + "/wsurl")

	info = Label.new()
	info.autowrap_mode = TextServer.AUTOWRAP_WORD
	info.text = "Hosten geht nur in der PC-Version. Mitspieler können entweder die PC-Version nutzen (Host-IP eintragen) oder einfach im Browser http://HOST-IP:%d öffnen. Läuft ein Server (Docker/Cloudflare), ist die Adresse schon eingetragen - nur noch Passwort. Sonst: Tailscale-IP des Hosts. Ports (TCP): %d Spiel, %d Webseite." % [WebHost.http_port, Game.port, WebHost.http_port]
	info.custom_minimum_size = Vector2(460, 0)
	box.add_child(info)


func _row(parent: Node, label: String, ctrl: Control) -> Variant:
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(100, 0)
	h.add_child(l)
	ctrl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(ctrl)
	parent.add_child(h)
	return ctrl


func _start(mode: String) -> void:
	Game.reset()
	Game.net_mode = mode
	Game.player_name = name_edit.text.strip_edges() if name_edit.text.strip_edges() != "" else "Spieler"
	Game.start_char = ["Marian", "Steffen", "Julian"][char_pick.selected]
	Game.host_ip = ip_edit.text.strip_edges()
	Game.password = pw_edit.text
	get_tree().change_scene_to_file("res://main.tscn")


## Start ohne Fenster: godot --headless -- --server  (Einstellungen per Umgebungsvariablen)
func _start_dedicated() -> void:
	Game.reset()
	Game.dedicated = true
	Game.net_mode = "host"
	Game.password = OS.get_environment("GAME_PASSWORD")
	Game.port = int(OS.get_environment("GAME_PORT")) if OS.get_environment("GAME_PORT") != "" else 24680
	if OS.get_environment("HTTP_PORT") != "":
		WebHost.http_port = int(OS.get_environment("HTTP_PORT"))
	WebHost.ws_url = OS.get_environment("WS_URL")
	print("Server startet: Spiel-Port %d, Web-Port %d, Passwort %s, WS_URL '%s'" % [Game.port, WebHost.http_port, "ja" if Game.password != "" else "nein", WebHost.ws_url])
	get_tree().change_scene_to_file.call_deferred("res://main.tscn")
