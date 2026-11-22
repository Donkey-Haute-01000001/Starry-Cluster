class_name PaperSheet
extends Control
## A sheet of handled paper (or logbook leather) drawn behind its parent's ink.
## The parent draws the type and pen on top; this draws the stock and a shadow.

const SHADER := preload("res://shaders/paper.gdshader")

var shadow := Vector2(7, 10)
var shadow_alpha := 0.5


func _init(params := {}) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	show_behind_parent = true
	var m := ShaderMaterial.new()
	m.shader = SHADER
	material = m
	for k in params:
		m.set_shader_parameter(k, params[k])


func param(k: String, v) -> void:
	(material as ShaderMaterial).set_shader_parameter(k, v)


## Moves the sheet; cheap enough to call every frame.
func place(r: Rect2) -> void:
	if position != r.position:
		position = r.position
	if size != r.size:
		size = r.size
		param("size", size)
		queue_redraw()


func _draw() -> void:
	# Shadow: a few soft layers (dark vertex colour = shader pass-through).
	if shadow_alpha > 0.0:
		for i in 4:
			var g := 2.0 + i * 4.0
			draw_rect(Rect2(shadow - Vector2(g, g) * 0.5, size + Vector2(g, g)), Color(0, 0, 0, shadow_alpha * 0.28))
	draw_rect(Rect2(Vector2.ZERO, size), Color.WHITE)
