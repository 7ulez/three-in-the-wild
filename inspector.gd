class_name Inspector
extends Node3D
## Zufaelliger naechtlicher Besuch: ein russischer Fischereiaufseher fragt fuenf Fragen aus der Angelpruefung ab.
## Zwei richtige reichen. Sonst gilt ein Tag Angelverbot. Laeuft nur auf dem eigenen Bildschirm (kein Netz).
## Die Fragen sind allgemeines Anglerwissen, nicht die offizielle Pruefung.

const POOL: Array = [
	{"q": "Frage numma eins: Was ist ein Raubfisch, bitte?", "a": ["Rotauge", "Hecht", "Brasse", "Karausche"], "c": 1},
	{"q": "Frage zwei: Welcher Fisch gehört zu den Weißfischen?", "a": ["Zander", "Hecht", "Rotauge", "Wels"], "c": 2},
	{"q": "Frage drei: Darf man ohne gültigen Fischereischein angeln?", "a": ["Ja, immer", "Nein, nur mit Fischereischein oder Urlaubsfischereischein", "Nur am Sonntag", "Nur mit Wodka"], "c": 1},
	{"q": "Frage vier: Was bedeutet Schonzeit?", "a": ["Pause vom Angeln für den Angler", "Zeit, in der bestimmte Fische nicht entnommen werden dürfen", "Ruhezeit am Ufer", "Zeit zum Schlafen im Zelt"], "c": 1},
	{"q": "Frage fünf: Was macht man mit einem Fisch unter dem Mindestmaß?", "a": ["Mitnehmen", "Verkaufen", "Schonend zurücksetzen", "Im Eimer lassen"], "c": 2},
	{"q": "Frage sechs: Welcher dieser Fische ist ein Friedfisch?", "a": ["Hecht", "Zander", "Karpfen", "Wels"], "c": 2},
	{"q": "Frage sieben: Was ist ein Kunstköder?", "a": ["Ein Wurm", "Ein Blinker", "Eine Made", "Ein Maiskorn"], "c": 1},
	{"q": "Frage acht: Woran erkennt man einen Karpfen am sichersten?", "a": ["Er hat Barteln am Maul", "Er hat drei Rückenflossen", "Er hat keine Schuppen", "Er hat einen Schnabel"], "c": 0},
	{"q": "Frage neun: Was ist das Mindestmaß?", "a": ["Die kleinste Länge, ab der ein Fisch entnommen werden darf", "Das maximale Gewicht", "Die Anzahl Fische pro Tag", "Der Mindestabstand zum Ufer"], "c": 0},
	{"q": "Frage zehn: Wozu dient ein Kescher?", "a": ["Zum Kochen", "Zum sicheren Landen des Fisches", "Als Köderbox", "Zum Wassermessen"], "c": 1},
]

const WALK_SPEED: float = 2.2
const STOP_DIST: float = 2.6

var main: Node
var player: Player = null
var _countdown: float = 90.0
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
	_countdown = randf_range(120.0, 240.0)
	if not Game.is_night() or player.sleeping or player.seat != null or player.hammock != null or player.placing:
		return
	if randf() < 0.5:
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
	Player.build_body(_visit, "Marian")
	var clip := Util.add_box(_visit, Vector3(0.25, 0.32, 0.02), Color(0.85, 0.82, 0.7), Vector3(0.3, 1.0, -0.25))
	clip.rotation_degrees.x = -20.0
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
			if d > STOP_DIST:
				_visit.global_position += to.normalized() * minf(WALK_SPEED * delta, d - STOP_DIST)
				_visit.look_at(Vector3(player.global_position.x, _visit.global_position.y, player.global_position.z), Vector3.UP)
			else:
				_visit.look_at(Vector3(player.global_position.x, _visit.global_position.y, player.global_position.z), Vector3.UP)
				_start_quiz()
		2:
			_leave_t -= delta
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
	var pool := POOL.duplicate()
	pool.shuffle()
	_questions = []
	for i in range(5):
		var q: Dictionary = (pool[i] as Dictionary).duplicate(true)
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
	_qlabel.text = ""
	_prog.text = ""
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
	_prog.text = "Frage %d von 5" % (_qi + 1)
	_qlabel.text = String(q["q"])
	_info.text = "Konzentration, Genosse."
	_set_buttons_visible(false)
	var answers: Array = q["a"]
	for i in range(4):
		var b: Button = _btns[i + 1]
		b.text = String(answers[i])
		b.visible = true
		b.disabled = false


func _on_answer(i: int) -> void:
	if _busy:
		return
	_busy = true
	var q: Dictionary = _questions[_qi]
	for k in range(4):
		(_btns[k + 1] as Button).disabled = true
	if i == int(q["c"]):
		_score += 1
		_info.text = ["Oh, sehr gut, Genosse! Richtig.", "Da, da! Richtig.", "Ha! Sie sind kein Dummkopf."][_qi % 3]
	else:
		_info.text = ["Njet, njet! Falsch.", "Nein, nein, falsch!", "Oi, das ist nix richtig."][_qi % 3]
	get_tree().create_timer(1.6).timeout.connect(_next_question)


func _next_question() -> void:
	_busy = false
	_qi += 1
	if _qi >= 5:
		_qlabel.text = ""
		_prog.text = "Ergebnis: %d von 5 richtig" % _score
		_set_buttons_visible(false)
		_btn_next_label("Weiter")
		_info.text = _verdict()
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


func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 20
	add_child(_ui)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	_ui.add_child(root)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(560, 0)
	panel.position = Vector2(-280, -210)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.96, 0.93, 0.85)
	sb.border_color = Color(0.2, 0.2, 0.2)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", sb)
	root.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var title := Label.new()
	title.text = "Fischereikontrolle"
	title.add_theme_font_size_override("font_size", 22)
	box.add_child(title)
	_info = Label.new()
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.add_theme_font_size_override("font_size", 17)
	box.add_child(_info)
	_prog = Label.new()
	_prog.add_theme_font_size_override("font_size", 14)
	box.add_child(_prog)
	_qlabel = Label.new()
	_qlabel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_qlabel.add_theme_font_size_override("font_size", 19)
	box.add_child(_qlabel)
	_btns = []
	for i in range(5):
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 40)
		b.visible = false
		box.add_child(b)
		_btns.append(b)
	# Knopf 0: Einleitung und Ergebnis. Knoepfe 1-4: Antworten (einmal verbunden, Index fest)
	(_btns[0] as Button).pressed.connect(_on_btn0)
	for i in range(4):
		(_btns[i + 1] as Button).pressed.connect(_on_answer.bind(i))
