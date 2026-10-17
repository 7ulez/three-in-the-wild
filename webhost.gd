class_name WebHost
extends Node
## Winziger HTTP-Server: Der Host liefert den Ordner "web" (Browser-Version des Spiels) aus,
## damit Mitspieler nur eine Adresse im Browser öffnen müssen.

static var http_port: int = 24681
static var ws_url: String = ""     # wird unter /wsurl an Browser verraten (für Cloudflare/HTTPS)
var server: TCPServer
var clients: Array = []   # {peer: StreamPeerTCP, buf: PackedByteArray}
var root: String = ""
var running: bool = false

const MIME := {
	"html": "text/html; charset=utf-8", "js": "application/javascript", "wasm": "application/wasm",
	"pck": "application/octet-stream", "png": "image/png", "ico": "image/x-icon",
	"json": "application/json", "css": "text/css", "svg": "image/svg+xml", "mp3": "audio/mpeg",
}


static func find_root() -> String:
	var base: String = OS.get_executable_path().get_base_dir()
	for p in [base.path_join("web"), base.path_join("../web"), "res://web"]:
		if FileAccess.file_exists(p.path_join("index.html")):
			return p
	return ""


func start() -> bool:
	root = find_root()
	if root == "":
		return false
	server = TCPServer.new()
	if server.listen(http_port) != OK:
		return false
	running = true
	return true


func _process(_d: float) -> void:
	if not running:
		return
	while server.is_connection_available():
		clients.append({"peer": server.take_connection(), "buf": PackedByteArray(), "t": 0.0})
	for c in clients.duplicate():
		var p: StreamPeerTCP = c["peer"]
		p.poll()
		if p.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			clients.erase(c)
			continue
		var n: int = p.get_available_bytes()
		if n > 0:
			var r: Array = p.get_data(n)
			if r[0] == OK:
				c["buf"].append_array(r[1])
		var text: String = c["buf"].get_string_from_ascii()
		if text.contains("\r\n\r\n"):
			_respond(p, text)
			clients.erase(c)
		else:
			c["t"] += _d
			if c["t"] > 10.0:
				p.disconnect_from_host()
				clients.erase(c)


func _respond(p: StreamPeerTCP, req: String) -> void:
	var line: String = req.get_slice("\r\n", 0)
	var parts: PackedStringArray = line.split(" ")
	var path: String = "/"
	if parts.size() >= 2:
		path = parts[1].get_slice("?", 0)
	if path == "/":
		path = "/index.html"
	path = path.uri_decode()
	if path == "/wsurl":
		_send(p, 200, "text/plain", ws_url.to_utf8_buffer(), false)
		return
	if path == "/check":
		# Passwortprüfung fürs Anmeldemenü (Passwort steht im Header, nicht in der Adresse).
		var pw: String = ""
		for hl in req.split("\r\n"):
			if hl.to_lower().begins_with("x-game-pw:"):
				pw = hl.substr(10).strip_edges().uri_decode()
		var answer := "ok"
		if Game.password == "":
			answer = "nopw"
		elif pw != Game.password:
			answer = "no"
		if answer != "ok":
			await get_tree().create_timer(1.0).timeout    # bremst Raten
		_send(p, 200, "text/plain", answer.to_utf8_buffer(), false)
		return
	if path.contains(".."):
		_send(p, 403, "text/plain", "no".to_utf8_buffer(), false)
		return
	var accepts_gz: bool = req.to_lower().contains("accept-encoding") and req.to_lower().contains("gzip")
	var ext: String = path.get_extension().to_lower()
	var full: String = root.path_join(path.trim_prefix("/"))
	var gz: bool = false
	if accepts_gz and FileAccess.file_exists(full + ".gz"):
		full += ".gz"
		gz = true
	if not FileAccess.file_exists(full):
		_send(p, 404, "text/plain", "nicht gefunden".to_utf8_buffer(), false)
		return
	var data: PackedByteArray = FileAccess.get_file_as_bytes(full)
	# Range-Anfragen (Audio-Element: Schleife/Spulen) mit 206 beantworten.
	if not gz:
		for hl in req.split("\r\n"):
			if hl.to_lower().begins_with("range:") and hl.contains("bytes="):
				var spec: String = hl.get_slice("bytes=", 1).strip_edges().get_slice(",", 0)
				var a: int = int(spec.get_slice("-", 0))
				var b: int = data.size() - 1
				if spec.get_slice("-", 1) != "":
					b = mini(int(spec.get_slice("-", 1)), data.size() - 1)
				if spec.begins_with("-"):
					a = maxi(0, data.size() - int(spec.get_slice("-", 1)))
					b = data.size() - 1
				if a > b or a >= data.size():
					_send(p, 416, "text/plain", PackedByteArray(), false)
					return
				var part: PackedByteArray = data.slice(a, b + 1)
				var h: String = "HTTP/1.1 206 Partial Content\r\nContent-Type: %s\r\nContent-Length: %d\r\nContent-Range: bytes %d-%d/%d\r\nAccept-Ranges: bytes\r\nConnection: close\r\nCache-Control: no-cache\r\n\r\n" % [MIME.get(ext, "application/octet-stream"), part.size(), a, b, data.size()]
				p.put_data(h.to_utf8_buffer())
				p.put_data(part)
				p.disconnect_from_host()
				return
	_send(p, 200, MIME.get(ext, "application/octet-stream"), data, gz)


func _send(p: StreamPeerTCP, code: int, mime: String, body: PackedByteArray, gz: bool) -> void:
	var h: String = "HTTP/1.1 %d %s\r\nContent-Type: %s\r\nContent-Length: %d\r\nAccept-Ranges: bytes\r\nConnection: close\r\nCache-Control: no-cache\r\n" % [code, "OK" if code == 200 else "Error", mime, body.size()]
	if gz:
		h += "Content-Encoding: gzip\r\n"
	h += "\r\n"
	p.put_data(h.to_utf8_buffer())
	p.put_data(body)
	p.disconnect_from_host()
