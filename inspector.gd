class_name Inspector
extends Node3D
## Zufaelliger naechtlicher Besuch: ein russischer Fischereiaufseher fragt fuenf Fragen aus der Angelpruefung ab.
## Zwei richtige reichen. Sonst gilt ein Tag Angelverbot. Laeuft nur auf dem eigenen Bildschirm (kein Netz).
## Die Fragen sind allgemeines Anglerwissen, nicht die offizielle Pruefung.

const POOL: Array = [
	{"q": "Was ist ein Raubfisch, bitte?", "a": ["Rotauge", "Hecht", "Brasse", "Karausche"], "c": 1},
	{"q": "Welcher Fisch gehört zu den Weißfischen?", "a": ["Zander", "Hecht", "Rotauge", "Wels"], "c": 2},
	{"q": "Darf man ohne gültigen Fischereischein angeln?", "a": ["Ja, immer", "Nein, nur mit Fischereischein oder Urlaubsfischereischein", "Nur am Sonntag", "Nur mit Wodka"], "c": 1},
	{"q": "Was bedeutet Schonzeit?", "a": ["Pause vom Angeln für den Angler", "Zeit, in der bestimmte Fische nicht entnommen werden dürfen", "Ruhezeit am Ufer", "Zeit zum Schlafen im Zelt"], "c": 1},
	{"q": "Was macht man mit einem Fisch unter dem Mindestmaß?", "a": ["Mitnehmen", "Verkaufen", "Schonend zurücksetzen", "Im Eimer lassen"], "c": 2},
	{"q": "Welcher dieser Fische ist ein Friedfisch?", "a": ["Hecht", "Zander", "Karpfen", "Wels"], "c": 2},
	{"q": "Was ist ein Kunstköder?", "a": ["Ein Wurm", "Ein Blinker", "Eine Made", "Ein Maiskorn"], "c": 1},
	{"q": "Woran erkennt man einen Karpfen am sichersten?", "a": ["Er hat Barteln am Maul", "Er hat drei Rückenflossen", "Er hat keine Schuppen", "Er hat einen Schnabel"], "c": 0},
	{"q": "Was ist das Mindestmaß?", "a": ["Die kleinste Länge, ab der ein Fisch entnommen werden darf", "Das maximale Gewicht", "Die Anzahl Fische pro Tag", "Der Mindestabstand zum Ufer"], "c": 0},
	{"q": "Wozu dient ein Kescher?", "a": ["Zum Kochen", "Zum sicheren Landen des Fisches", "Als Köderbox", "Zum Wassermessen"], "c": 1},
	{"q": "Welcher dieser Fische gehört zu den Lachsartigen?", "a": ["Hecht", "Bachforelle", "Zander", "Brasse"], "c": 1},
	{"q": "Wie misst man die Länge eines Fisches fürs Mindestmaß?", "a": ["Von der Maulspitze bis zum Ende der Schwanzflosse", "Nur den Körper ohne Kopf", "Von den Kiemen bis zur Rückenflosse", "Nach Gefühl"], "c": 0},
	{"q": "Welcher Süßwasserfisch kann über zwei Meter lang werden?", "a": ["Barsch", "Wels", "Rotauge", "Schleie"], "c": 1},
	{"q": "Was ist ein Köderfisch?", "a": ["Ein kleiner Fisch, der als Köder für Raubfische dient", "Ein Fisch, der besonders gut schmeckt", "Ein geschützter Fisch", "Ein Fisch aus der Dose"], "c": 0},
	{"q": "Wozu dient ein Wirbel in der Angelschnur?", "a": ["Er verhindert, dass sich die Schnur verdrillt", "Er lockt Fische an", "Er misst die Tiefe", "Er hält den Köder warm"], "c": 0},
	{"q": "Was tut man mit einem Fisch, der gegessen werden soll?", "a": ["Ihn betäuben und sofort töten", "Ihn im Eimer liegen lassen", "Ihn trocknen lassen", "Ihn lebend nach Hause tragen"], "c": 0},
	{"q": "Welches dieser Gewässer ist ein Fließgewässer?", "a": ["Maschsee", "Steinhuder Meer", "Die Leine", "Ein Baggersee"], "c": 2},
	{"q": "Welcher Fisch laicht schon im zeitigen Frühjahr?", "a": ["Hecht", "Karpfen", "Schleie", "Wels"], "c": 0},
	{"q": "Wie heißt der Teil der Angel, auf den die Schnur aufgewickelt wird?", "a": ["Pose", "Rolle", "Blinker", "Kork"], "c": 1},
	{"q": "Wozu dient eine Pose?", "a": ["Sie zeigt Bisse an und hält den Köder in der gewünschten Tiefe", "Sie beschwert die Rute", "Sie leuchtet im Wasser für den Fisch", "Sie ersetzt den Haken"], "c": 0},
	{"q": "Was ist ein Blinker?", "a": ["Ein Metallköder, der im Wasser blinkt und glänzt", "Eine Stirnlampe", "Ein Warnsignal am Auto", "Ein Haken für Aale"], "c": 0},
	{"q": "Welcher Fisch ist ein typischer Schwarmfisch?", "a": ["Hecht", "Wels", "Rotauge", "Zander"], "c": 2},
	{"q": "Warum sollte man beim Zurücksetzen eines Fisches nasse Hände haben?", "a": ["Um die Schleimhaut des Fisches zu schonen", "Damit er nicht wegrutscht", "Damit die Hände sauber bleiben", "Das ist Pflicht beim Fotografieren"], "c": 0},
	{"q": "Wozu dient ein Hakenlöser?", "a": ["Um den Haken schonend aus dem Fischmaul zu entfernen", "Um die Schnur zu kürzen", "Um Köder zu schneiden", "Um Fische zu wiegen"], "c": 0},
	{"q": "Welcher dieser Fische gehört zu den Barschartigen?", "a": ["Hecht", "Karpfen", "Zander", "Wels"], "c": 2},
	{"q": "Welcher Fisch ist schlangenförmig und wandert zum Laichen ins Meer?", "a": ["Aal", "Hecht", "Karausche", "Barsch"], "c": 0},
	{"q": "Was gehört zum richtigen Verhalten am Wasser?", "a": ["Müll mitnehmen und die Natur schonen", "Schnurreste im Gebüsch lassen", "Lagerfeuer im Schilf", "Laute Musik für die Fische"], "c": 0},
	{"q": "Wann beißen Raubfische oft besonders gut?", "a": ["In der Morgen- und Abenddämmerung", "Nur mittags bei Sonne", "Nur bei Gewitter", "Nie nachts"], "c": 0},
	{"q": "Was zeigt ein Bissanzeiger an?", "a": ["Dass ein Fisch am Köder ist", "Die Wassertemperatur", "Die Uhrzeit", "Den Luftdruck"], "c": 0},
]

const WALK_SPEED: float = 2.2
const STOP_DIST: float = 2.6

var main: Node
var player: Player = null
var _countdown: float = 420.0
var _visit: Node3D = null
var _state: int = 0            # 0 kommt, 1 Quiz, 2 geht
var _leave_t: float = 0.0
var _questions: Array = []
var _qi: int = 0
var _score: int = 0
var _ui: CanvasLayer = null
var _info: Label = null
var _qlabel: Label = null
var _prog: Label = null
var _btns: Array = []
var _busy: bool = false
var _questions_started: bool = false
var _was_captured: bool = false
static var _recent: Array = []   # zuletzt gestellte Fragen, damit sie sich nicht wiederholen
var _pips: Array = []
var _stamp: Label = null
var _card: PanelContainer = null
var _pivots: Dictionary = {}
var _gait: float = 0.0


## Wird jeden Bildschirm-Durchlauf aufgerufen.
func tick(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("local_player") as Player
		return
	if _visit != null:
		_run_visit(delta)
		return
	_countdown -= delta
	if _countdown > 0.0:
		return
	_countdown = randf_range(300.0, 600.0)
	if not Game.is_night() or player.sleeping or player.seat != null or player.hammock != null or player.placing:
		return
	if randf() < 0.35:
		_countdown = randf_range(1500.0, 2700.0)   # nach einem Besuch lange Ruhe
		_spawn()


func _spawn() -> void:
	var pos := Vector3.ZERO
	for i in range(12):
		var a := randf() * TAU
		pos = player.global_position + Vector3(cos(a), 0, sin(a)) * 18.0
		pos.y = 0.0
		var lake: Node3D = main_node().get("lake_root") as Node3D
		if lake == null or not LakeShape.contains(Vector2(pos.x - lake.global_position.x, pos.z - lake.global_position.z)):
			break
	_visit = Node3D.new()
	main_node().add_child(_visit)
	_visit.global_position = pos
	_pivots = InspectorModel.build(_visit)
	_gait = 0.0
	_state = 0
	player.toast("Da ist jemand auf dem Weg... Sieht aus wie ein Fischereiaufseher.", 4.0)


func main_node() -> Node:
	return get_parent() if get_parent() != null else main


func _run_visit(delta: float) -> void:
	if not is_instance_valid(_visit):
		_visit = null
		_close_ui()
		return
	match _state:
		0:
			var to := player.global_position - _visit.global_position
			to.y = 0.0
			var d := to.length()
			_gait += delta * 8.0
			InspectorModel.animate(_pivots, _gait, d > STOP_DIST, delta)
			if d > STOP_DIST:
				_visit.global_position += to.normalized() * minf(WALK_SPEED * delta, d - STOP_DIST)
				_visit.look_at(Vector3(player.global_position.x, _visit.global_position.y, player.global_position.z), Vector3.UP)
			else:
				_visit.look_at(Vector3(player.global_position.x, _visit.global_position.y, player.global_position.z), Vector3.UP)
				_start_quiz()
		1:
			InspectorModel.animate(_pivots, _gait, false, delta)
		2:
			_leave_t -= delta
			_gait += delta * 8.0
			InspectorModel.animate(_pivots, _gait, true, delta)
			_visit.global_position += _visit.global_transform.basis.z * WALK_SPEED * delta
			if _leave_t <= 0.0:
				_visit.queue_free()
				_visit = null


func _start_quiz() -> void:
	_state = 1
	player.set_physics_process(false)
	_was_captured = Game.is_captured() and not Game.touch
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_questions_started = false
	var pool: Array = []
	for qq in POOL:
		if not _recent.has(String((qq as Dictionary)["q"])):
			pool.append(qq)
	if pool.size() < 5:
		_recent.clear()
		pool = POOL.duplicate()
	pool.shuffle()
	_questions = []
	for i in range(5):
		var q: Dictionary = (pool[i] as Dictionary).duplicate(true)
		_recent.append(String(q["q"]))
		var answers: Array = (q["a"] as Array).duplicate()
		var correct: String = String(answers[int(q["c"])])
		answers.shuffle()
		q["a"] = answers
		q["c"] = answers.find(correct)
		_questions.append(q)
	_qi = 0
	_score = 0
	_build_ui()
	_intro()


func _intro() -> void:
	_info.text = "Guten Abend. Inspektor Wladimir Petrowitsch, Fischereiaufsicht. Kontrolle, bitte.\nFünf Fragen. Zwei richtige müssen Sie haben. Sonst: ein Tag Angelverbot. Verstanden?"
	_qlabel.text = "Fischereikontrolle"
	_prog.text = "Einleitung"
	_set_buttons_visible(false)
	_btn_next_label("Ja, verstanden")


func _btn_next_label(txt: String) -> void:
	var b: Button = _btns[0]
	b.text = txt
	b.visible = true
	b.disabled = false


func _on_btn0() -> void:
	if _state != 1:
		return
	if _qi == 0 and _questions_started == false:
		_questions_started = true
		_show_question()
	else:
		_finish()


func _show_question() -> void:
	var q: Dictionary = _questions[_qi]
	_prog.text = "FRAGE %d VON 5" % (_qi + 1)
	_qlabel.text = String(q["q"])
	_info.text = "Konzentration, Genosse."
	_set_pip(_qi, 1)
	_set_buttons_visible(false)
	var answers: Array = q["a"]
	for i in range(4):
		var b: Button = _btns[i + 1]
		b.text = "%s   %s" % [["A", "B", "C", "D"][i], String(answers[i])]
		b.visible = true
		b.disabled = false
		_answer_style(b, null)


func _on_answer(i: int) -> void:
	if _busy:
		return
	_busy = true
	var q: Dictionary = _questions[_qi]
	for k in range(4):
		(_btns[k + 1] as Button).disabled = true
	var right := i == int(q["c"])
	# richtige Antwort gruen, eigene falsche Antwort rot
	_answer_style(_btns[int(q["c"]) + 1], true)
	if not right:
		_answer_style(_btns[i + 1], false)
	_set_pip(_qi, 2 if right else 3)
	if right:
		_score += 1
		_info.text = ["Oh, sehr gut, Genosse! Richtig.", "Da, da! Richtig.", "Ha! Sie sind kein Dummkopf."][_qi % 3]
	else:
		_info.text = ["Njet, njet! Falsch.", "Nein, nein, falsch!", "Oi, das ist nix richtig."][_qi % 3]
	get_tree().create_timer(1.6).timeout.connect(_next_question)


func _next_question() -> void:
	_busy = false
	_qi += 1
	if _qi >= 5:
		_qlabel.text = "Ergebnis"
		_prog.text = "%d VON 5 RICHTIG" % _score
		_set_buttons_visible(false)
		_btn_next_label("Weiter")
		_info.text = _verdict()
		_stamp.text = "BESTANDEN" if _score >= 2 else "DURCHGEFALLEN"
		_stamp.add_theme_color_override("font_color", Color(0.4, 0.95, 0.5) if _score >= 2 else Color(0.95, 0.35, 0.3))
		_stamp.visible = true
		return
	_show_question()


func _verdict() -> String:
	if _score >= 2:
		return "Dobro! Zwei richtig reicht. Sie dürfen angeln. Do swidanija!"
	return "Zu wenig, Kollege. Einen Tag Angelverbot. Morgen nix angeln, verstehen? Do swidanija!"


func _finish() -> void:
	if _score < 2:
		Game.fish_ban_day = Game.day_count + 1
		player.toast("Angelverbot: bis morgen darfst du nicht angeln.", 5.0)
	else:
		player.toast("Fischereiaufseher: bestanden, du darfst weiter angeln.", 4.0)
	_close_ui()
	_state = 2
	_leave_t = 6.0


func _close_ui() -> void:
	if _ui != null and is_instance_valid(_ui):
		_ui.queue_free()
	_ui = null
	if player != null and is_instance_valid(player):
		player.set_physics_process(true)
	if _was_captured and not Game.touch:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _set_buttons_visible(v: bool) -> void:
	for b in _btns:
		(b as Button).visible = v


## Fortschritt: 0 offen, 1 aktuell, 2 richtig, 3 falsch
func _set_pip(i: int, state: int) -> void:
	if i < 0 or i >= _pips.size():
		return
	var colors := [Color(0.25, 0.27, 0.3), Color(0.9, 0.75, 0.3), Color(0.35, 0.8, 0.45), Color(0.9, 0.3, 0.28)]
	(_pips[i] as PanelContainer).add_theme_stylebox_override("panel", _sb(colors[state], colors[state], 0, 4, 0))


func _sb(bg: Color, border: Color, border_w: int, radius: int, margin: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(margin)
	return s


## Antwort-Knopf faerben: correct = true (gruen), false (rot), null (neutral)
func _answer_style(b: Button, correct: Variant) -> void:
	var bg := Color(0.14, 0.17, 0.21)
	var border := Color(0.32, 0.37, 0.44)
	if correct == true:
		bg = Color(0.16, 0.42, 0.24)
		border = Color(0.4, 0.85, 0.5)
	elif correct == false:
		bg = Color(0.5, 0.16, 0.16)
		border = Color(0.95, 0.4, 0.35)
	b.add_theme_stylebox_override("disabled", _sb(bg, border, 2, 10, 10))
	b.add_theme_stylebox_override("normal", _sb(bg, border, 2, 10, 10))
	b.add_theme_stylebox_override("hover", _sb(bg.lightened(0.12), Color(0.9, 0.75, 0.3), 2, 10, 10))
	b.add_theme_stylebox_override("pressed", _sb(bg.darkened(0.1), Color(0.9, 0.75, 0.3), 2, 10, 10))
	b.add_theme_stylebox_override("focus", _sb(bg, border, 2, 10, 10))
	b.add_theme_color_override("font_color", Color(0.95, 0.94, 0.9))
	b.add_theme_color_override("font_disabled_color", Color(0.95, 0.94, 0.9))


func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 20
	add_child(_ui)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	_ui.add_child(root)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)

	_card = PanelContainer.new()
	_card.custom_minimum_size = Vector2(700, 0)
	_card.add_theme_stylebox_override("panel", _sb(Color(0.08, 0.1, 0.13, 0.97), Color(0.85, 0.7, 0.3), 3, 16, 22))
	_card.set_anchors_preset(Control.PRESET_CENTER)
	_card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_card.grow_vertical = Control.GROW_DIRECTION_BOTH
	root.add_child(_card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	_card.add_child(box)

	# Kopfzeile: Titel links, Fortschritt rechts
	var head := HBoxContainer.new()
	box.add_child(head)
	var title := Label.new()
	title.text = "FISCHEREIKONTROLLE"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.9, 0.75, 0.3))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_prog = Label.new()
	_prog.add_theme_font_size_override("font_size", 16)
	_prog.add_theme_color_override("font_color", Color(0.8, 0.82, 0.86))
	head.add_child(_prog)

	# Fortschrittsbalken: fuenf Abschnitte, einer pro Frage
	var pips := HBoxContainer.new()
	pips.add_theme_constant_override("separation", 8)
	box.add_child(pips)
	_pips = []
	for i in range(5):
		var p := PanelContainer.new()
		p.custom_minimum_size = Vector2(0, 10)
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pips.add_child(p)
		_pips.append(p)
		_set_pip(i, 0)

	# Sprechblase des Inspektors
	var bubble := PanelContainer.new()
	bubble.add_theme_stylebox_override("panel", _sb(Color(0.96, 0.93, 0.85), Color(0.2, 0.2, 0.2), 2, 12, 14))
	box.add_child(bubble)
	_info = Label.new()
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.add_theme_font_size_override("font_size", 17)
	_info.add_theme_color_override("font_color", Color(0.12, 0.1, 0.08))
	bubble.add_child(_info)

	# Frage
	_qlabel = Label.new()
	_qlabel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_qlabel.add_theme_font_size_override("font_size", 24)
	_qlabel.add_theme_color_override("font_color", Color(1, 1, 1))
	_qlabel.custom_minimum_size = Vector2(0, 64)
	box.add_child(_qlabel)

	# Antworten als Raster aus vier grossen Knoepfen
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	box.add_child(grid)
	_btns = []
	var main_btn := Button.new()
	_btns.append(main_btn)
	for i in range(4):
		var b := Button.new()
		b.custom_minimum_size = Vector2(320, 62)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 18)
		b.visible = false
		_answer_style(b, null)
		grid.add_child(b)
		_btns.append(b)

	# Stempel fuer das Ergebnis
	_stamp = Label.new()
	_stamp.visible = false
	_stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stamp.add_theme_font_size_override("font_size", 38)
	box.add_child(_stamp)

	# Hauptknopf: Einleitung, Ergebnis
	main_btn.custom_minimum_size = Vector2(0, 54)
	main_btn.add_theme_font_size_override("font_size", 19)
	main_btn.visible = false
	main_btn.add_theme_stylebox_override("normal", _sb(Color(0.85, 0.7, 0.3), Color(0.6, 0.45, 0.15), 2, 10, 10))
	main_btn.add_theme_stylebox_override("hover", _sb(Color(0.95, 0.8, 0.4), Color(0.6, 0.45, 0.15), 2, 10, 10))
	main_btn.add_theme_stylebox_override("pressed", _sb(Color(0.7, 0.56, 0.22), Color(0.6, 0.45, 0.15), 2, 10, 10))
	main_btn.add_theme_color_override("font_color", Color(0.1, 0.08, 0.05))
	box.add_child(main_btn)

	(_btns[0] as Button).pressed.connect(_on_btn0)
	for i in range(4):
		(_btns[i + 1] as Button).pressed.connect(_on_answer.bind(i))
