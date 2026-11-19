extends Node2D
## Parallax starfield drawn in screen space. Far stars drift slower than near ones.

var main: Node
var _stars: Array = []
const TILE := 2048.0


var nebula: ColorRect
var backdrop: Control
var _t := 0.0
## [file, parallax, is the cloud layer, pixel scale, brightness]
const LAYERS := [["backdrop/stars_plain.png", 0.012, false, 1.0, 0.45], ["backdrop/stars_plain.png", 0.035, false, 2.0, 0.7]]


func _ready() -> void:
	# Nebula backdrop behind the stars, tinted per system.
	nebula = ColorRect.new()
	nebula.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	nebula.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/nebula.gdshader")
	nebula.material = mat
	nebula.show_behind_parent = true
	var holder := CanvasLayer.new()
	holder.layer = -20
	holder.add_child(nebula)
	# Pixel backdrop (Foozle Void environment, CC0) when installed: animated
	# cloud and star layers at slow parallax, tinted per system.
	if Art.tex("backdrop/stars_plain.png") != null:
		mat.set_shader_parameter("pixel", 5.0)
		mat.set_shader_parameter("levels", 14.0)
		backdrop = Control.new()
		backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
		backdrop.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		backdrop.draw.connect(_draw_backdrop)
		holder.add_child(backdrop)
	add_child.call_deferred(holder)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337
	for i in 420:
		var depth := rng.randf_range(0.05, 0.6)
		_stars.append({
			"p": Vector2(rng.randf() * TILE, rng.randf() * TILE),
			"depth": depth,
			"size": lerpf(0.6, 2.2, depth / 0.6),
			"color": Color(0.75, 0.82, 1.0).lerp(Color(1.0, 0.85, 0.7), rng.randf()) * Color(1, 1, 1, lerpf(0.35, 1.0, depth / 0.6)),
		})


## Colours per system: [cloud, wisps, density].
const TINTS := {
	"aurelia": [Color(0.10, 0.30, 0.55), Color(0.30, 0.12, 0.42), 0.75],
	"tiberine": [Color(0.40, 0.25, 0.10), Color(0.12, 0.30, 0.40), 0.7],
	"marcellus": [Color(0.42, 0.12, 0.10), Color(0.25, 0.10, 0.30), 0.8],
	"porta_aquila": [Color(0.12, 0.35, 0.40), Color(0.35, 0.30, 0.55), 0.8],
}


func _process(_delta: float) -> void:
	_t += _delta
	if backdrop:
		backdrop.queue_redraw()
	if nebula and main and main.camera:
		var mat := nebula.material as ShaderMaterial
		mat.set_shader_parameter("cam", main.camera.global_position)
		var sid: String = main.system_id if main.merchant else "aurelia"
		var tint: Array = TINTS.get(sid, TINTS["aurelia"])
		mat.set_shader_parameter("tint_a", tint[0])
		mat.set_shader_parameter("tint_b", tint[1])
		mat.set_shader_parameter("density", tint[2])
		mat.set_shader_parameter("seed", float(sid.hash() % 97))
	queue_redraw()


func _draw_backdrop() -> void:
	var vp := backdrop.size
	var cam_pos: Vector2 = main.camera.global_position if main and main.camera else Vector2.ZERO
	var sid: String = main.system_id if main and main.merchant else "aurelia"
	var tint: Array = TINTS.get(sid, TINTS["aurelia"])
	for l in LAYERS:
		var sc: float = l[3]
		var fw := 640.0 * sc
		var fh := 360.0 * sc
		var tex := Art.tex(l[0])
		if tex == null:
			continue
		var n := maxi(1, int(tex.get_width() / 640))
		var f := (int(_t * 3.0) + int(l[1] * 1000.0)) % n
		var b: float = l[4]
		var mod := Color(b, b, b)
		if l[2]:
			var a: Color = tint[0]
			mod = Color(1, 1, 1).lerp(Color(a.r * 2.4, a.g * 2.4, a.b * 2.4), 0.55) * Color(b, b, b)
		var off := -cam_pos * float(l[1])
		off = Vector2(fposmod(off.x, fw), fposmod(off.y, fh))
		var x := off.x - fw
		while x < vp.x:
			var y := off.y - fh
			while y < vp.y:
				backdrop.draw_texture_rect_region(tex, Rect2(x, y, fw, fh), Rect2(f * 640, 0, 640, 360), mod)
				y += fh
			x += fw


func _draw() -> void:
	if backdrop:
		return
	var vp := get_viewport_rect().size
	var cam_pos: Vector2 = main.camera.global_position if main and main.camera else Vector2.ZERO
	for s in _stars:
		var p: Vector2 = s["p"] - cam_pos * s["depth"]
		p = Vector2(fposmod(p.x, TILE), fposmod(p.y, TILE))
		# Tile the star field to cover any screen size.
		var x := p.x
		while x < vp.x:
			var y := p.y
			while y < vp.y:
				draw_circle(Vector2(x, y), s["size"], s["color"])
				if s["size"] > 1.9:
					var c: Color = s["color"]
					draw_circle(Vector2(x, y), s["size"] * 3.0, Color(c.r, c.g, c.b, 0.08))
				y += TILE
			x += TILE
