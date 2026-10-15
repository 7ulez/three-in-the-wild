class_name ItemModels
extends RefCounted
## Low-Poly-Modelle für alle Gegenstände (per Code gebaut).
## Alle Modelle sind um ihren Mittelpunkt zentriert. Später ersetzen wir sie durch Blender-Modelle.
## Teile, die man bewegen oder umschalten kann, kommen im zurückgegebenen Dictionary zurück:
##   "lid" (Deckel mit Gelenk), "contents", "flames", "bottles".

## Höhe der Grillfläche über dem Boden (für den Dutch Oven)
const GRILL_TOP: float = 0.85


static func placed_size(kind: String, size: Vector3) -> Vector3:
	if kind == "Campingstuhl" or kind == "Campingstühle":
		return Vector3(0.5, 0.95, 0.5)
	if kind == "Rutenständer":
		return Vector3(0.6, 0.9, 0.6)
	if kind == "Wasserflasche":
		return Vector3(0.084, 0.3, 0.084)
	if kind == "Gasgrill":
		return Vector3(0.66, 0.9, 0.55)
	if kind == "Kiste mit Proviant":
		return Vector3(0.5, 0.27, 0.34)
	if kind == "Feuerschale":
		return Vector3(0.46, 0.62, 0.46)
	if kind == "Brennholz":
		return Vector3(0.6, 0.3, 0.32)
	return size


## Modell, wie man es trägt.
static func add_visual(parent: Node3D, kind: String, size: Vector3, color: Color) -> Dictionary:
	match kind:
		"Zeltpaket":
			return _tent_bag(parent, size, color)
		"Bierkasten":
			return _beer_crate(parent, size, color)
		"Hammer":
			return _hammer(parent)
		"Joint":
			return _joint(parent)
		"Luftgewehr":
			return _airgun(parent)
		"Kühlbox":
			return _cooler(parent, size, color)
		"Gasgrill":
			return _grill(parent, size, color)
		"Angelrute":
			return _rod(parent, size, color)
		"Dutch Oven":
			return _oven(parent, size)
		"Campingstühle", "Campingstuhl":
			return _chair_bag(parent, size, color)
		"Wasserflasche":
			return _canister(parent, size, color)
		"Brennholz":
			return _firewood(parent, size)
		"Kiste mit Proviant":
			return _crate(parent, size, color)
		"Rucksack":
			return _backpack(parent, size, color)
		"Rutenständer":
			return _rodpod(parent)
		"Hängematte":
			return _hammock_bag(parent, size, color)
		"Feuerstahl":
			return _firesteel(parent)
		"Feuerschale":
			return _firebowl(parent, size)
	if Game.INGREDIENT_COLORS.has(kind):
		return _ingredient(parent, kind, color)
	if kind.ends_with("kg"):
		return _fish(parent, size, color, kind)
	Util.add_box(parent, size, color)
	return {}


## Modell, wie es aufgestellt aussieht (Stühle sind aufgeklappt).
static func add_placed_visual(parent: Node3D, kind: String, size: Vector3, color: Color) -> Dictionary:
	if kind == "Campingstühle":
		for x in [-0.6, 0.0, 0.6]:
			var holder := Node3D.new()
			holder.position.x = x
			parent.add_child(holder)
			_chair(holder, color)
		return {}
	if kind == "Campingstuhl":
		_chair(parent, color)
		return {}
	return add_visual(parent, kind, size, color)


## Lädt ein Blender-Modell (assets/items/NAME.glb). null, wenn es fehlt.
static func _glb(parent: Node3D, name: String) -> Node3D:
	var path := "res://assets/items/%s.glb" % name
	if not ResourceLoader.exists(path):
		return null
	var inst := (load(path) as PackedScene).instantiate() as Node3D
	parent.add_child(inst)
	# Metall ohne Spiegelungen wirkt im Spiel schwarz: Glanz etwas zurücknehmen
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var m3 := mi as MeshInstance3D
		for i in range(m3.mesh.get_surface_count()):
			var sm := m3.mesh.surface_get_material(i) as BaseMaterial3D
			if sm != null and sm.metallic > 0.2:
				sm.metallic = 0.2
				sm.roughness = maxf(sm.roughness, 0.5)
	return inst

## Stoff-Materialien eines Modells einfärben (jede Instanz bekommt eigene Kopien)
static func _tint(inst: Node3D, mat_name: String, color: Color) -> void:
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var m3 := mi as MeshInstance3D
		for i in range(m3.mesh.get_surface_count()):
			var sm := m3.mesh.surface_get_material(i) as BaseMaterial3D
			if sm != null and sm.resource_name.begins_with(mat_name):
				var c := sm.duplicate() as BaseMaterial3D
				c.albedo_color = color
				m3.set_surface_override_material(i, c)


static func _fire_mat(node: Node3D, col: Color) -> void:
	var fmat := StandardMaterial3D.new()
	fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fmat.albedo_color = col
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = fmat


static func _tent_bag(parent: Node3D, size: Vector3, color: Color) -> Dictionary:
	var roll := Util.add_cylinder(parent, size.z * 0.5, size.x, color, Vector3.ZERO)
	roll.rotation_degrees.z = 90.0
	for x in [-0.25, 0.25]:
		var strap := Util.add_cylinder(parent, size.z * 0.5 + 0.01, 0.05, Color(0.1, 0.1, 0.1), Vector3(x, 0, 0))
		strap.rotation_degrees.z = 90.0
	return {}


static func _beer_crate(parent: Node3D, size: Vector3, color: Color) -> Dictionary:
	var bm := _glb(parent, "bierkasten")
	if bm != null:
		var bl: Array = []
		var holder := bm.find_child("Bottles", true, false)
		if holder != null:
			bl = holder.get_children()
		return {"bottles": bl}
	Util.add_box(parent, size, color)
	var bottles: Array = []
	for ix in range(5):
		for iz in range(4):
			var bottle := Util.add_cylinder(parent, 0.03, 0.2, Color(0.35, 0.2, 0.08),
				Vector3(-0.2 + ix * 0.1, size.y / 2.0 + 0.1, -0.13 + iz * 0.087))
			bottles.append(bottle)
	return {"bottles": bottles}


static func _hammer(parent: Node3D) -> Dictionary:
	if _glb(parent, "hammer") != null:
		return {}
	Util.add_box(parent, Vector3(0.3, 0.035, 0.035), Color(0.5, 0.33, 0.17), Vector3(-0.05, 0, 0))
	Util.add_box(parent, Vector3(0.1, 0.09, 0.07), Color(0.4, 0.4, 0.43), Vector3(0.13, 0, 0))
	return {}


## Joint: weißes Papier, glimmende Spitze, Filter
static func _joint(parent: Node3D) -> Dictionary:
	var paper := Util.add_cylinder(parent, 0.011, 0.11, Color(0.93, 0.91, 0.82), Vector3.ZERO)
	paper.rotation_degrees.z = 90.0
	var tip := Util.add_cylinder(parent, 0.013, 0.012, Color(0.9, 0.35, 0.1), Vector3(0.056, 0, 0))
	tip.rotation_degrees.z = 90.0
	var filt := Util.add_cylinder(parent, 0.009, 0.025, Color(0.7, 0.55, 0.35), Vector3(-0.06, 0, 0))
	filt.rotation_degrees.z = 90.0
	return {}


## Luftgewehr: Lauf zeigt nach -Z (vorne), Schaft aus Holz hinten
static func _airgun(parent: Node3D) -> Dictionary:
	Util.add_box(parent, Vector3(0.03, 0.03, 0.55), Color(0.2, 0.2, 0.22), Vector3(0, 0.04, -0.2))       # Lauf
	Util.add_box(parent, Vector3(0.05, 0.07, 0.3), Color(0.25, 0.25, 0.28), Vector3(0, 0.0, 0.05))      # Gehäuse
	Util.add_box(parent, Vector3(0.05, 0.1, 0.34), Color(0.5, 0.32, 0.16), Vector3(0, -0.03, 0.33)).rotation_degrees.x = -6.0   # Schaft
	Util.add_box(parent, Vector3(0.02, 0.07, 0.04), Color(0.2, 0.2, 0.22), Vector3(0, -0.07, 0.0))      # Abzugbügel
	Util.add_box(parent, Vector3(0.02, 0.035, 0.06), Color(0.15, 0.15, 0.17), Vector3(0, 0.09, -0.05))  # Visier
	return {}


static func _cooler(parent: Node3D, size: Vector3, color: Color) -> Dictionary:
	var body_h := size.y - 0.08
	Util.add_box(parent, Vector3(size.x, body_h, size.z), color, Vector3(0, -0.04, 0))
	var top := -0.04 + body_h / 2.0
	var pivot := Node3D.new()
	pivot.position = Vector3(0, top, size.z / 2.0)
	parent.add_child(pivot)
	Util.add_box(pivot, Vector3(size.x + 0.02, 0.08, size.z + 0.02), Color(0.95, 0.95, 0.97), Vector3(0, 0.04, -size.z / 2.0))
	Util.add_box(pivot, Vector3(0.2, 0.04, 0.04), Color(0.2, 0.2, 0.22), Vector3(0, 0.09, -size.z / 2.0))
	var contents := Node3D.new()
	contents.position = Vector3(0, top + 0.04, 0)
	contents.visible = false
	parent.add_child(contents)
	Util.add_box(contents, Vector3(0.16, 0.08, 0.1), Color(0.9, 0.5, 0.5), Vector3(-0.15, 0, -0.08))
	Util.add_box(contents, Vector3(0.16, 0.08, 0.1), Color(0.85, 0.45, 0.45), Vector3(0.02, 0, -0.08))
	Util.add_cylinder(contents, 0.03, 0.12, Color(0.8, 0.8, 0.85), Vector3(0.18, 0, 0.08))
	Util.add_cylinder(contents, 0.03, 0.12, Color(0.8, 0.8, 0.85), Vector3(0.08, 0, 0.1))
	Util.add_box(contents, Vector3(0.2, 0.06, 0.12), Color(0.95, 0.85, 0.5), Vector3(-0.12, 0.0, 0.1))
	return {"lid": pivot, "contents": contents}


static func _grill(parent: Node3D, size: Vector3, color: Color) -> Dictionary:
	var gm := _glb(parent, "gasgrill")
	if gm != null:
		var fl := gm.find_child("flames", true, false) as Node3D
		if fl != null:
			fl.visible = false
			_fire_mat(fl, Color(1.0, 0.55, 0.15))
		return {"flames": fl}
	var bottom := -size.y / 2.0
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			Util.add_cylinder(parent, 0.025, 0.5, Color(0.15, 0.15, 0.17), Vector3(sx * 0.3, bottom + 0.25, sz * 0.2))
	Util.add_cylinder(parent, 0.11, 0.35, Color(0.7, 0.7, 0.72), Vector3(0.0, bottom + 0.3, 0.0))
	Util.add_box(parent, Vector3(size.x, 0.28, size.z), color, Vector3(0, bottom + 0.5 + 0.14, 0))
	var grate_y := bottom + 0.5 + 0.28
	Util.add_box(parent, Vector3(size.x * 0.92, 0.02, size.z * 0.88), Color(0.08, 0.08, 0.09), Vector3(0, grate_y + 0.005, 0))
	var pivot := Node3D.new()
	pivot.position = Vector3(0, grate_y, size.z / 2.0)
	parent.add_child(pivot)
	Util.add_box(pivot, Vector3(size.x, 0.12, size.z), color.lightened(0.1), Vector3(0, 0.06, -size.z / 2.0))
	Util.add_box(pivot, Vector3(0.3, 0.03, 0.03), Color(0.6, 0.6, 0.62), Vector3(0, 0.1, -size.z / 2.0 - 0.02))
	var flames := Node3D.new()
	flames.position = Vector3(0, grate_y + 0.08, 0)
	flames.visible = false
	parent.add_child(flames)
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.albedo_color = Color(1.0, 0.55, 0.15)
	for fx in [-0.22, 0.0, 0.22]:
		for fz in [-0.1, 0.1]:
			var f := Util.add_cone(flames, 0.05, 0.16, Color.WHITE, Vector3(fx, 0, fz))
			f.material_override = fm
	return {"lid": pivot, "flames": flames}


static func _rod(parent: Node3D, size: Vector3, color: Color = Color(0.15, 0.55, 0.3)) -> Dictionary:
	var rm := _glb(parent, "angelrute")
	if rm != null:
		var bk := rm.find_child("Blank", true, false) as MeshInstance3D
		if bk != null:
			var bmat := StandardMaterial3D.new()
			bmat.albedo_color = color
			bmat.roughness = 0.35
			bmat.metallic = 0.1
			bk.material_override = bmat
		return {}
	var rod := Util.add_cylinder(parent, 0.012, size.x, color, Vector3.ZERO)
	rod.rotation_degrees.z = 90.0
	var handle := Util.add_cylinder(parent, 0.025, 0.3, Color(0.4, 0.27, 0.15), Vector3(-0.55, 0, 0))
	handle.rotation_degrees.z = 90.0
	var reel := Util.add_cylinder(parent, 0.04, 0.04, Color(0.6, 0.6, 0.65), Vector3(-0.3, -0.05, 0))
	reel.rotation_degrees.x = 90.0
	return {}


static func _oven(parent: Node3D, size: Vector3) -> Dictionary:
	var om := _glb(parent, "dutchoven")
	if om != null:
		return {"lid": om.find_child("lid", true, false)}
	Util.add_cylinder(parent, 0.2, 0.2, Color(0.1, 0.1, 0.11), Vector3(0, -0.04, 0))
	for a in range(3):
		var ang := TAU * float(a) / 3.0
		Util.add_cylinder(parent, 0.02, 0.06, Color(0.1, 0.1, 0.11), Vector3(cos(ang) * 0.14, -0.14, sin(ang) * 0.14))
	var pivot := Node3D.new()
	pivot.position = Vector3(0, 0.06, size.z / 2.0)
	parent.add_child(pivot)
	Util.add_cylinder(pivot, 0.21, 0.05, Color(0.13, 0.13, 0.14), Vector3(0, 0.025, -size.z / 2.0))
	Util.add_cylinder(pivot, 0.035, 0.06, Color(0.25, 0.25, 0.27), Vector3(0, 0.08, -size.z / 2.0))
	return {"lid": pivot}


static func _chair_bag(parent: Node3D, size: Vector3, color: Color) -> Dictionary:
	Util.add_box(parent, size, color)
	for x in [-size.x * 0.25, size.x * 0.25]:
		Util.add_box(parent, Vector3(0.05, size.y + 0.01, size.z + 0.01), Color(0.1, 0.1, 0.1), Vector3(x, 0, 0))
	return {}


static func _chair(parent: Node3D, color: Color) -> void:
	var cm := _glb(parent, "campingstuhl")
	if cm != null:
		_tint(cm, "Stoff", color)
		return
	var b := -0.475
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			Util.add_box(parent, Vector3(0.04, 0.45, 0.04), Color(0.55, 0.55, 0.6), Vector3(sx * 0.22, b + 0.225, sz * 0.22))
	Util.add_box(parent, Vector3(0.5, 0.05, 0.5), color, Vector3(0, b + 0.475, 0))
	var back := Util.add_box(parent, Vector3(0.5, 0.45, 0.05), color, Vector3(0, b + 0.74, 0.24))
	back.rotation_degrees.x = -10.0


static func _canister(parent: Node3D, size: Vector3, color: Color) -> Dictionary:
	var wm := _glb(parent, "wasserflasche")
	if wm != null:
		wm.scale = Vector3.ONE * (size.y / 0.3)
		return {}
	Util.add_box(parent, size, color)
	Util.add_cylinder(parent, 0.035, 0.05, Color(0.1, 0.1, 0.12), Vector3(0.07, size.y / 2.0 + 0.025, 0))
	Util.add_box(parent, Vector3(0.12, 0.03, 0.05), Color(0.1, 0.1, 0.12), Vector3(-0.06, size.y / 2.0 + 0.015, 0))
	return {}


static func _firewood(parent: Node3D, size: Vector3) -> Dictionary:
	if _glb(parent, "brennholz") != null:
		return {}
	var cols: Array = [Color(0.5, 0.33, 0.18), Color(0.45, 0.3, 0.16), Color(0.55, 0.38, 0.2)]
	var rows: Array = [[-0.12, 0.0, 0.12], [-0.06, 0.06], [0.0]]
	var ys: Array = [-0.065, 0.04, 0.135]
	var n := 0
	for r in range(rows.size()):
		for z in rows[r]:
			var log_mesh := Util.add_cylinder(parent, 0.06, size.x, cols[n % cols.size()], Vector3(0, ys[r], z))
			log_mesh.rotation_degrees.z = 90.0
			n += 1
	for x in [-0.2, 0.2]:
		Util.add_box(parent, Vector3(0.03, 0.3, 0.34), Color(0.2, 0.2, 0.2), Vector3(x, 0.03, 0))
	return {}


## Holzkiste mit Klappdeckel (Proviant)
static func _crate(parent: Node3D, size: Vector3, color: Color) -> Dictionary:
	var cm := _glb(parent, "kiste")
	if cm != null:
		return {"proviant": cm.find_child("Proviant", true, false)}
	var wood := Color(0.55, 0.38, 0.2)
	Util.add_box(parent, Vector3(size.x, size.y - 0.06, size.z), wood, Vector3(0, -0.03, 0))
	for sy in [-0.1, 0.0, 0.1]:
		Util.add_box(parent, Vector3(size.x + 0.01, 0.015, size.z + 0.01), wood.darkened(0.3), Vector3(0, sy, 0))
	for cx in [-1.0, 1.0]:
		Util.add_box(parent, Vector3(0.04, size.y - 0.04, size.z + 0.015), wood.darkened(0.15), Vector3(cx * (size.x / 2.0 - 0.02), -0.03, 0))
	Util.add_box(parent, Vector3(size.x * 0.5, 0.08, 0.02), color, Vector3(0, 0.0, size.z / 2.0 + 0.012))
	var top := -0.03 + (size.y - 0.06) / 2.0
	var pivot := Node3D.new()
	pivot.position = Vector3(0, top, size.z / 2.0)
	parent.add_child(pivot)
	Util.add_box(pivot, Vector3(size.x + 0.02, 0.035, size.z + 0.02), wood.lightened(0.1), Vector3(0, 0.018, -size.z / 2.0))
	return {"lid": pivot}


static func _backpack(parent: Node3D, size: Vector3, color: Color) -> Dictionary:
	var rm := _glb(parent, "rucksack")
	if rm != null:
		_tint(rm, "Stoff", color)
		_tint(rm, "StoffDunkel", color.darkened(0.3))
		return {"lid": rm.find_child("lid", true, false)}
	Util.add_box(parent, Vector3(size.x, size.y - 0.08, size.z), color, Vector3(0, -0.04, 0))
	Util.add_box(parent, Vector3(size.x * 0.75, 0.2, 0.06), color.darkened(0.15), Vector3(0, -0.1, -size.z / 2.0 - 0.03))
	var top := -0.04 + (size.y - 0.08) / 2.0
	var pivot := Node3D.new()
	pivot.position = Vector3(0, top, size.z / 2.0)
	parent.add_child(pivot)
	Util.add_box(pivot, Vector3(size.x, 0.04, size.z + 0.02), color.darkened(0.3), Vector3(0, 0.02, -size.z / 2.0))
	return {"lid": pivot}


static func _firesteel(parent: Node3D) -> Dictionary:
	if _glb(parent, "feuerstahl") != null:
		return {}
	var rod := Util.add_cylinder(parent, 0.012, 0.14, Color(0.7, 0.7, 0.74), Vector3.ZERO)
	rod.rotation_degrees.z = 90.0
	Util.add_box(parent, Vector3(0.05, 0.03, 0.03), Color(0.75, 0.15, 0.1), Vector3(-0.08, 0, 0))
	return {}


## Feuerschale: Steinring mit Aschebett. "flames" und "embers" werden vom Feuer gesteuert.
static func _firebowl(parent: Node3D, size: Vector3) -> Dictionary:
	var fb := _glb(parent, "feuerschale")
	if fb != null:
		var pr := {}
		for k in ["kindling", "logs", "flames"]:
			var n := fb.find_child(k, true, false) as Node3D
			if n != null:
				n.visible = false
				pr[k] = n
		if pr.has("flames"):
			_fire_mat(pr["flames"], Color(1.0, 0.55, 0.12))
		return pr
	var bottom := -size.y / 2.0
	Util.add_cylinder(parent, 0.34, 0.06, Color(0.15, 0.13, 0.12), Vector3(0, bottom + 0.03, 0))
	for i in range(10):
		var a := TAU * float(i) / 10.0
		var st := Util.add_box(parent, Vector3(0.2, 0.17, 0.16), Color(0.5, 0.5, 0.52).lightened(0.05 * float(i % 3)),
			Vector3(cos(a) * 0.36, bottom + 0.11, sin(a) * 0.36))
		st.rotation.y = -a
	var kindling := Node3D.new()
	kindling.visible = false
	parent.add_child(kindling)
	for i in range(5):
		var a2 := TAU * float(i) / 5.0
		var stick := Util.add_cylinder(kindling, 0.02, 0.5, Color(0.4, 0.28, 0.16), Vector3(cos(a2) * 0.08, bottom + 0.14, sin(a2) * 0.08))
		stick.rotation = Vector3(0.9 * cos(a2), 0, 0.9 * sin(a2))
	var logs := Node3D.new()
	logs.visible = false
	parent.add_child(logs)
	for i in range(3):
		var a3 := TAU * float(i) / 3.0
		var lg := Util.add_cylinder(logs, 0.05, 0.5, Color(0.45, 0.3, 0.17), Vector3(cos(a3) * 0.1, bottom + 0.2, sin(a3) * 0.1))
		lg.rotation = Vector3(1.1 * cos(a3), 0, 1.1 * sin(a3))
	var flames := Node3D.new()
	flames.visible = false
	flames.position = Vector3(0, bottom + 0.2, 0)
	parent.add_child(flames)
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.albedo_color = Color(1.0, 0.5, 0.1)
	var fm2 := StandardMaterial3D.new()
	fm2.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm2.albedo_color = Color(1.0, 0.85, 0.25)
	for i in range(5):
		var a4 := TAU * float(i) / 5.0
		var f := Util.add_cone(flames, 0.12, 0.5, Color.WHITE, Vector3(cos(a4) * 0.1, 0.25, sin(a4) * 0.1))
		f.material_override = fm
	var core := Util.add_cone(flames, 0.1, 0.55, Color.WHITE, Vector3(0, 0.28, 0))
	core.material_override = fm2
	return {"kindling": kindling, "logs": logs, "flames": flames}


static func _ingredient(parent: Node3D, kind: String, color: Color) -> Dictionary:
	match kind:
		"Zwiebeln", "Knoblauch":
			Util.add_sphere(parent, 0.08, color, Vector3.ZERO)
			Util.add_cone(parent, 0.03, 0.07, color.darkened(0.2), Vector3(0, 0.09, 0))
		"Paprika":
			Util.add_sphere(parent, 0.08, color, Vector3.ZERO)
			Util.add_cylinder(parent, 0.012, 0.05, Color(0.15, 0.4, 0.1), Vector3(0, 0.09, 0))
		"Hackfleisch":
			Util.add_box(parent, Vector3(0.2, 0.06, 0.14), color, Vector3.ZERO)
		"Gewürze":
			Util.add_cylinder(parent, 0.035, 0.1, color, Vector3.ZERO)
			Util.add_cylinder(parent, 0.037, 0.03, Color(0.15, 0.15, 0.15), Vector3(0, 0.06, 0))
		_:
			Util.add_cylinder(parent, 0.05, 0.1, color, Vector3.ZERO)
			Util.add_cylinder(parent, 0.052, 0.015, Color(0.75, 0.75, 0.78), Vector3(0, 0.05, 0))
	return {}


static func _fish(parent: Node3D, size: Vector3, color: Color, kind: String = "") -> Dictionary:
	var fm: Node3D = null
	if kind.begins_with("Karpfen"):
		fm = _glb(parent, "karpfen")
	elif kind.begins_with("Hecht"):
		fm = _glb(parent, "hecht")
	if fm != null:
		fm.scale = Vector3.ONE * size.x
		return {}
	var body := Util.add_sphere(parent, 0.5, color, Vector3.ZERO)
	body.scale = Vector3(size.x * 0.6, size.y * 0.5 + 0.02, size.z * 0.6)
	var tail := Util.add_cone(parent, 0.5, 1.0, color.darkened(0.2), Vector3(size.x * 0.5, 0, 0))
	tail.scale = Vector3(size.y * 0.5 + 0.03, size.x * 0.2, 0.02)
	tail.rotation_degrees.z = 90.0
	Util.add_sphere(parent, 0.012, Color.BLACK, Vector3(-size.x * 0.32, size.y * 0.1, size.z * 0.18))
	return {}


## Rutenständer: zwei Gabeln, die Rute liegt schräg darauf. "rod" ist die (versteckte) Rute.
static func _rodpod(parent: Node3D) -> Dictionary:
	var pm := _glb(parent, "rutenstaender")
	if pm != null:
		var rn := pm.find_child("rod", true, false) as Node3D
		if rn != null:
			rn.visible = false
		return {"rod": rn}
	var wood := Color(0.45, 0.3, 0.16)
	Util.add_box(parent, Vector3(0.05, 0.9, 0.05), wood, Vector3(0, 0.0, -0.22))
	Util.add_box(parent, Vector3(0.05, 0.5, 0.05), wood, Vector3(0, -0.2, 0.22))
	var f1 := Util.add_box(parent, Vector3(0.05, 0.22, 0.05), wood, Vector3(-0.07, 0.4, -0.22))
	f1.rotation_degrees.z = 25.0
	var f2 := Util.add_box(parent, Vector3(0.05, 0.22, 0.05), wood, Vector3(0.07, 0.4, -0.22))
	f2.rotation_degrees.z = -25.0
	Util.add_box(parent, Vector3(0.5, 0.04, 0.04), wood.darkened(0.2), Vector3(0, -0.43, 0))
	var rodn := Node3D.new()
	rodn.visible = false
	parent.add_child(rodn)
	var r := Util.add_cylinder(rodn, 0.012, 2.0, Color(0.15, 0.55, 0.3), Vector3(0, 0.27, -0.2))
	r.rotation_degrees.x = 90.0 - 14.0
	Util.add_cylinder(rodn, 0.03, 0.18, Color(0.35, 0.22, 0.12), Vector3(0, 0.05, 0.4)).rotation_degrees.x = 76.0
	var led := Util.add_sphere(rodn, 0.025, Color(1, 0.1, 0.1), Vector3(0.0, 0.12, 0.12))
	return {"rod": rodn}


static func _hammock_bag(parent: Node3D, size: Vector3, color: Color) -> Dictionary:
	var hm := _glb(parent, "haengematte_sack")
	if hm != null:
		hm.scale = Vector3.ONE * (size.x / 0.55)
		return {}
	var roll := Util.add_cylinder(parent, size.z * 0.5, size.x, color, Vector3.ZERO)
	roll.rotation_degrees.z = 90.0
	Util.add_cylinder(parent, size.z * 0.5 + 0.01, 0.05, Color(0.1, 0.1, 0.1), Vector3(-0.1, 0, 0)).rotation_degrees.z = 90.0
	return {}
