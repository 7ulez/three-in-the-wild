class_name Leaderboard
extends RefCounted
## Bestenliste der größten Fänge. Der Server (oder Host / Einzelspieler) speichert sie in einer Datei,
## sodass sie einen Neustart überlebt. Docker: Ordner über DATA_DIR (/data) als Volume einbinden.

const MAX_ENTRIES: int = 10

static var entries: Array = []       # {"user","fish","kg","cm","date"}, nach Gewicht absteigend
static var version: int = 0          # zählt hoch, wenn sich etwas ändert (Tafel zeichnet neu)


static func path() -> String:
	var d := OS.get_environment("DATA_DIR")
	if d != "":
		DirAccess.make_dir_recursive_absolute(d)
		return d.path_join("leaderboard.json")
	return "user://leaderboard.json"


static func load_file() -> void:
	var f := FileAccess.open(path(), FileAccess.READ)
	if f == null:
		return
	var data: Variant = JSON.parse_string(f.get_as_text())
	if data is Array:
		var list: Array = []
		for e in data:
			if e is Dictionary:
				var c := sanitize(e)
				if not c.is_empty():
					list.append(c)
		entries = list
		_sort()
		version += 1


static func save_file() -> void:
	var f := FileAccess.open(path(), FileAccess.WRITE)
	if f == null:
		push_warning("Leaderboard konnte nicht gespeichert werden: %s" % path())
		return
	f.store_string(JSON.stringify(entries))


static func today() -> String:
	var t := Time.get_datetime_dict_from_system()
	return "%02d.%02d.%04d" % [t["day"], t["month"], t["year"]]


## Prüft/bereinigt einen Eintrag (der Server vertraut den Clients nicht blind). Leer = ungültig.
static func sanitize(e: Dictionary) -> Dictionary:
	var fish := str(e.get("fish", ""))
	if not Fisher.FISH.has(fish):
		return {}
	var kg := snappedf(clampf(float(e.get("kg", 0.0)), 0.0, 250.0), 0.1)
	var cm := clampi(int(e.get("cm", 0)), 0, 400)
	var user := str(e.get("user", "?")).strip_edges().left(16)
	if user == "":
		user = "?"
	var date := str(e.get("date", ""))
	var re := RegEx.create_from_string("^\\d{2}\\.\\d{2}\\.\\d{4}$")
	if re.search(date) == null:
		date = today()
	if kg <= 0.0:
		return {}
	return {"user": user, "fish": fish, "kg": kg, "cm": cm, "date": date}


static func _sort() -> void:
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["kg"]) > float(b["kg"]))
	if entries.size() > MAX_ENTRIES:
		entries.resize(MAX_ENTRIES)


## Platz (0-basiert), den ein Fang mit diesem Gewicht belegen würde; -1 = reicht nicht.
static func rank_for(kg: float) -> int:
	var r := 0
	for e in entries:
		if float(e["kg"]) >= kg:
			r += 1
	return r if r < MAX_ENTRIES else -1


static func add(e: Dictionary) -> void:
	entries.append(e)
	_sort()
	version += 1
	save_file()


static func set_entries(list: Array) -> void:
	entries = list
	version += 1


## Meldet einen Fang: Server/Host/Einzelspieler tragen direkt ein, Clients schicken ihn an den Server.
static func report(fish: String, kg: float, cm: int) -> void:
	var e := {"user": Game.player_name, "fish": fish, "kg": kg, "cm": cm, "date": today()}
	var net := Net.instance
	if net != null and net.multiplayer.multiplayer_peer != null:
		if net.is_host():
			net.server_add(e)
		else:
			net.rpc_id(1, "submit_catch", e)
		return
	var c := sanitize(e)
	if not c.is_empty():
		add(c)
