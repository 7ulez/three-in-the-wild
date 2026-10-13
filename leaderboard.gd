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


static func _read(p: String) -> Array:
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null:
		return []
	var data: Variant = JSON.parse_string(f.get_as_text())
	var list: Array = []
	if data is Array:
		for e in data:
			if e is Dictionary:
				var c := sanitize(e)
				if not c.is_empty():
					list.append(c)
	return list


## Lädt die Bestenliste (notfalls aus der Sicherung) und schreibt ins Log, woher sie kam.
static func load_file() -> void:
	var p := path()
	var list := _read(p)
	var src := p
	if list.is_empty():
		list = _read(p + ".bak")
		src = p + ".bak"
	if list.is_empty():
		print("[Bestenliste] keine Datei gefunden (%s) - Liste startet leer. Falls das nach einem Update passiert: /data als Volume einbinden!" % p)
		return
	entries = list
	_sort()
	version += 1
	print("[Bestenliste] %d Einträge geladen aus %s" % [entries.size(), src])


## Atomar speichern: erst in .tmp schreiben, alte Datei als .bak behalten, dann umbenennen.
static func save_file() -> void:
	var p := path()
	var tmp := p + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("Leaderboard konnte nicht gespeichert werden: %s" % p)
		return
	f.store_string(JSON.stringify(entries))
	f.close()
	if FileAccess.file_exists(p):
		DirAccess.copy_absolute(p, p + ".bak")
	DirAccess.rename_absolute(tmp, p)


# ---------- Eigene Fänge (Selbstheilung nach Server-Reset) ----------
# Jeder Spieler merkt sich seine besten Fänge lokal und meldet sie beim Verbinden erneut.
# Der Server nimmt nur auf, was noch nicht in der Liste steht.

const MY_FILE: String = "user://my_catches.json"
const MY_MAX: int = 20

static func my_load() -> Array:
	var f := FileAccess.open(MY_FILE, FileAccess.READ)
	if f == null:
		return []
	var data: Variant = JSON.parse_string(f.get_as_text())
	return data if data is Array else []


static func my_remember(e: Dictionary) -> void:
	var list := my_load()
	list.append(e)
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("kg", 0)) > float(b.get("kg", 0)))
	if list.size() > MY_MAX:
		list.resize(MY_MAX)
	var f := FileAccess.open(MY_FILE, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(list))


static func has_entry(c: Dictionary) -> bool:
	for e in entries:
		if e["user"] == c["user"] and e["fish"] == c["fish"] and is_equal_approx(float(e["kg"]), float(c["kg"])) and e["date"] == c["date"]:
			return true
	return false


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
	if has_entry(e):
		return
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
	my_remember(e)
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
