class_name InspectorModel
extends RefCounted
## Der Fischereiaufseher: Uniform in Oliv, Schirmmuetze mit Abzeichen, Schnauzer und Klemmbrett.
## Gebaut aus einfachen Formen; Gesicht zeigt nach -Z (vorn).

const UNIFORM := Color(0.36, 0.40, 0.27)
const UNIFORM_DARK := Color(0.24, 0.27, 0.18)
const TROUSER := Color(0.22, 0.24, 0.26)
const BOOT := Color(0.06, 0.05, 0.05)
const SKIN := Color(0.93, 0.78, 0.66)
const HAIR := Color(0.28, 0.2, 0.12)
const BROWN := Color(0.42, 0.28, 0.14)
const RED := Color(0.72, 0.1, 0.1)
const GOLD := Color(0.85, 0.7, 0.25)
const PAPER := Color(0.95, 0.95, 0.92)


static func build(parent: Node3D) -> Dictionary:
	# Beine und Stiefel (an Huefte-Pivots, damit sie schwingen koennen)
	var piv: Dictionary = {}
	for x in [-0.11, 0.11]:
		var lp := Node3D.new()
		lp.position = Vector3(x, 0.85, 0.0)
		parent.add_child(lp)
		Util.add_box(lp, Vector3(0.15, 0.8, 0.16), TROUSER, Vector3(0, -0.4, 0.0))
		Util.add_box(lp, Vector3(0.17, 0.1, 0.24), BOOT, Vector3(0, -0.8, -0.03))
		piv["legL" if x < 0.0 else "legR"] = lp
	# Koerper: Uniformjacke, Guertel, Brustabzeichen
	Util.add_box(parent, Vector3(0.46, 0.66, 0.27), UNIFORM, Vector3(0.0, 1.2, 0.0))
	Util.add_box(parent, Vector3(0.48, 0.07, 0.29), UNIFORM_DARK, Vector3(0.0, 0.86, 0.0))
	Util.add_box(parent, Vector3(0.08, 0.06, 0.02), GOLD, Vector3(0.0, 0.88, -0.15))
	Util.add_box(parent, Vector3(0.1, 0.13, 0.01), UNIFORM_DARK, Vector3(-0.12, 1.36, -0.14))
	Util.add_cylinder(parent, 0.025, 0.02, GOLD, Vector3(-0.12, 1.36, -0.15))
	# Kragenspiegel rot
	for x in [-0.08, 0.08]:
		Util.add_box(parent, Vector3(0.06, 0.05, 0.02), RED, Vector3(x, 1.52, -0.13))
	# Arme, Haende (rechter Arm schwingt; linker haelt das Klemmbrett)
	for x in [-0.31, 0.31]:
		var ap := Node3D.new()
		ap.position = Vector3(x, 1.5, 0.0)
		parent.add_child(ap)
		Util.add_box(ap, Vector3(0.14, 0.62, 0.15), UNIFORM, Vector3(0, -0.32, 0.0))
		Util.add_sphere(ap, 0.07, SKIN, Vector3(0, -0.65, 0.0))
		if x > 0.0:
			piv["armR"] = ap
	# Klemmbrett in der linken Hand (vor der Brust)
	var board := Util.add_box(parent, Vector3(0.26, 0.33, 0.02), BROWN, Vector3(-0.2, 1.0, -0.2))
	board.rotation_degrees.x = -20.0
	var sheet := Util.add_box(parent, Vector3(0.21, 0.27, 0.01), PAPER, Vector3(-0.2, 1.0, -0.212))
	sheet.rotation_degrees.x = -20.0
	# Hals und Kopf
	Util.add_cylinder(parent, 0.06, 0.12, SKIN, Vector3(0.0, 1.6, 0.0))
	Util.add_sphere(parent, 0.14, SKIN, Vector3(0.0, 1.75, 0.0))
	Util.add_sphere(parent, 0.15, HAIR, Vector3(0.0, 1.8, 0.02)).scale = Vector3(1.0, 0.6, 1.0)
	# Augen, Brauen, Schnauzer
	for x in [-0.055, 0.055]:
		Util.add_sphere(parent, 0.018, Color(0.1, 0.1, 0.1), Vector3(x, 1.77, -0.13))
		Util.add_box(parent, Vector3(0.06, 0.12, 0.02), HAIR, Vector3(x, 1.82, -0.128))
	Util.add_box(parent, Vector3(0.13, 0.035, 0.05), HAIR, Vector3(0.0, 1.71, -0.14))
	# Schirmmuetze mit Abzeichen
	Util.add_cylinder(parent, 0.15, 0.1, UNIFORM_DARK, Vector3(0.0, 1.92, 0.0))
	Util.add_box(parent, Vector3(0.34, 0.02, 0.16), UNIFORM_DARK, Vector3(0.0, 1.9, -0.1))
	var badge := Util.add_cylinder(parent, 0.04, 0.02, RED, Vector3(0.0, 1.96, -0.155))
	badge.rotation_degrees.x = 90.0
	return piv


## Gangbewegung: phase laeuft weiter, moving=false -> Glieder gleiten zurueck in Ruhe.
static func animate(piv: Dictionary, phase: float, moving: bool, delta: float) -> void:
	var amp := 0.6 if moving else 0.0
	var sw := sin(phase) * amp
	var k := minf(delta * 10.0, 1.0)
	for key in piv:
		var n := piv[key] as Node3D
		if n == null or not is_instance_valid(n):
			continue
		var target := 0.0
		match key:
			"legL": target = sw
			"legR": target = -sw
			"armR": target = sw * 0.8
		n.rotation.x = lerpf(n.rotation.x, target, k)
