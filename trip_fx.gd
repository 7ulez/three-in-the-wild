class_name TripFx
extends CanvasLayer
## Bildschirmeffekt nach dem Rauchen: Wellen, Farbverschiebung und Regenbogen-Farben.
## intensity 0 = aus, 1 = voll bunt.

const SHADER: String = """
shader_type canvas_item;
uniform sampler2D scr : hint_screen_texture, filter_linear, repeat_disable;
uniform float intensity = 0.0;
vec3 hue(vec3 c, float a) {
	vec3 k = vec3(0.57735);
	float ca = cos(a);
	return c * ca + cross(k, c) * sin(a) + k * dot(k, c) * (1.0 - ca);
}
void fragment() {
	vec2 uv = SCREEN_UV;
	float t = TIME;
	vec2 c = uv - vec2(0.5);
	float r = length(c);
	uv += vec2(sin(uv.y * 9.0 + t * 2.2), cos(uv.x * 7.0 + t * 1.8)) * 0.014 * intensity;
	uv += c * sin(r * 12.0 - t * 2.5) * 0.02 * intensity;
	vec3 col;
	col.r = texture(scr, uv + vec2(0.007, 0.0) * intensity).r;
	col.g = texture(scr, uv).g;
	col.b = texture(scr, uv - vec2(0.007, 0.0) * intensity).b;
	col = hue(col, (t * 1.4 + r * 7.0) * intensity);
	float l = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(l), col, 1.0 + 1.9 * intensity);
	vec3 rb = 0.5 + 0.5 * cos(6.28318 * (vec3(0.0, 0.33, 0.67) + t * 0.18 + SCREEN_UV.x * 0.6 + SCREEN_UV.y * 0.4));
	col = mix(col, col * rb * 1.7 + rb * 0.12, 0.4 * intensity);
	COLOR = vec4(col, 1.0);
}
"""

var rect: ColorRect
var mat: ShaderMaterial


func _init() -> void:
	layer = 1   # unter dem HUD (Layer 2), damit Anzeigen lesbar bleiben
	rect = ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mat = ShaderMaterial.new()
	mat.shader = Shader.new()
	mat.shader.code = SHADER
	rect.material = mat
	rect.visible = false
	add_child(rect)


func set_intensity(v: float) -> void:
	rect.visible = v > 0.01
	mat.set_shader_parameter("intensity", clampf(v, 0.0, 1.0))
