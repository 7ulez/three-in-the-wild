class_name LeaderboardBoard
extends Node3D
## Holztafel auf dem Parkplatz mit den zehn größten Fängen (beidseitig lesbar).

const PAPER: Color = Color(0.957, 0.937, 0.894)
const INK: Color = Color(0.114, 0.122, 0.102)
const PANEL: Color = Color(0.09, 0.13, 0.10)
const FIRE: Color = Color(0.6, 0.36, 0.12)
const WOOD: Color = Color(0.36, 0.24, 0.13)

var _labels: Array[Label3D] = []
var _ver: int = -1


func build() -> void:
	UI.fonts()
	for sx in [-2.25, 2.25]:
		Util.add_box(self, Vector3(0.16, 3.0, 0.16), WOOD, Vector3(sx, 1.5, 0))
	Util.add_box(self, Vector3(4.2, 2.45, 0.1), WOOD, Vector3(0, 2.0, 0))
	Util.add_box(self, Vector3(3.95, 2.2, 0.12), PANEL, Vector3(0, 2.0, 0))
	Util.add_box(self, Vector3(3.95, 0.42, 0.14), FIRE, Vector3(0, 2.9, 0))
	Util.add_box(self, Vector3(4.5, 0.12, 0.45), WOOD, Vector3(0, 3.22, 0))
	for side in [1.0, -1.0]:
		var z: float = side * 0.075
		var title := Label3D.new()
		title.text = "GRÖSSTE FÄNGE"
		title.font = UI.f_head
		title.font_size = 64
		title.pixel_size = 0.0045
		title.modulate = INK
		title.outline_size = 0
		title.position = Vector3(0, 2.9, z * 1.1)
		var body := Label3D.new()
		body.font = UI.f_mono
		body.font_size = 34
		body.pixel_size = 0.0029
		body.modulate = PAPER
		body.outline_size = 0
		body.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		body.position = Vector3(-1.78, 2.66, z * 1.1)
		body.offset = Vector2(0, 0)
		body.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		if side < 0.0:
			title.rotation_degrees.y = 180.0
			body.rotation_degrees.y = 180.0
			body.position.x = 1.78
		add_child(title)
		add_child(body)
		_labels.append(body)
	_refresh()


func _process(_delta: float) -> void:
	if _ver != Leaderboard.version:
		_refresh()


func _refresh() -> void:
	_ver = Leaderboard.version
	var lines: Array[String] = []
	lines.append("#  Name      Fisch       cm    kg    Datum")
	for i in range(Leaderboard.MAX_ENTRIES):
		if i < Leaderboard.entries.size():
			var e: Dictionary = Leaderboard.entries[i]
			var d := str(e["date"])
			d = d.left(6) + d.right(2)
			lines.append("%-2d %-9s %-11s %3d %6.1f  %s" % [i + 1, str(e["user"]).left(9), str(e["fish"]).left(11), int(e["cm"]), float(e["kg"]), d])
		else:
			lines.append("%-2d -" % (i + 1))
	var txt := "\n".join(lines)
	for l in _labels:
		l.text = txt
		l.pixel_size = 0.0029
		var wd := 0.0
		for ln in lines:
			wd = maxf(wd, UI.f_mono.get_string_size(ln, HORIZONTAL_ALIGNMENT_LEFT, -1, l.font_size).x * l.pixel_size)
		if wd > 3.6:
			l.pixel_size *= 3.6 / wd
