class_name Signpost
extends Node3D
## Wegweiser aus einem Pfosten mit Schildern. Jedes Schild zeigt mit seiner Spitze
## in Richtung "yaw" (Grad um die Hochachse): 90 = Norden (-Z), 180 = Westen (-X),
## 0 = Osten (+X), 270 = Süden (+Z). Die Schrift ist von beiden Seiten lesbar.

const WOOD: Color = Color(0.45, 0.3, 0.16)
const BOARD: Color = Color(0.66, 0.53, 0.32)


## boards: Array aus {"text": String, "yaw": float, "y": float}
func build(boards: Array) -> void:
	Util.add_cylinder(self, 0.09, 2.7, WOOD, Vector3(0, 1.35, 0))

	for b in boards:
		var node := Node3D.new()
		node.position.y = b["y"]
		node.rotation_degrees.y = b["yaw"]
		add_child(node)

		Util.add_box(node, Vector3(2.0, 0.38, 0.06), BOARD, Vector3.ZERO)

		# Pfeilspitze am +X-Ende
		var tip := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(0.38, 0.3, 0.06)
		tip.mesh = pm
		tip.material_override = Util.mat(BOARD)
		tip.rotation_degrees.z = -90.0
		tip.position = Vector3(1.0 + 0.15, 0, 0)
		node.add_child(tip)

		for side in [1.0, -1.0]:
			var label := Label3D.new()
			label.text = b["text"]
			label.font_size = 36
			label.pixel_size = 0.0048
			label.modulate = Color(0.1, 0.06, 0.02)
			label.outline_size = 0
			label.position = Vector3(-0.05, 0, side * 0.035)
			# Schrift auf die Schildbreite (1,7 m, Spitze bleibt frei) einpassen
			var wd := ThemeDB.fallback_font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.font_size).x * label.pixel_size
			if wd > 1.7:
				label.pixel_size *= 1.7 / wd
			if side < 0.0:
				label.rotation_degrees.y = 180.0
			node.add_child(label)
