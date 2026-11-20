extends Node2D
## Parallax starfield drawn in screen space. Far stars drift slower than near ones.

var main: Node
var _stars: Array = []
const TILE := 2048.0


var nebula: ColorRect
var backdrop: Control
var _t := 0.0
## [file, parallax, is the cloud layer, pixel scale, brightness]
const LAYERS := [["backdrop/stars_plain.png", 0.02, false, 1.0, 0.45], ["backdrop/stars_plain.png", 0.06, false, 2.0, 0.7]]
## Near star layers: [parallax, count per tile, pixel size, brightness]. These are
## what rush past you; they stretch into streaks with speed.
const NEAR := [[0.22, 70, 2.0, 0.55], [0.45, 40, 2.0, 0.75], [0.8, 18, 3.0, 0.9]]
const NEAR_TILE := 900.0


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
	"tiberine": [Color(0.12, 0.36, 0.20), Color(0.36, 0.30, 0.10), 0.7],
	"marcellus": [Color(0.42, 0.12, 0.10), Color(0.25, 0.10, 0.30), 0.8],
	"porta_aquila": [Color(0.16, 0.24, 0.36), Color(0.30, 0.32, 0.38), 0.85],
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
	_draw_near_stars(vp, cam_pos)
	_draw_ambience(vp, cam_pos, sid)


func _draw_near_stars(vp: Vector2, cam_pos: Vector2) -> void:
	var vel := Vector2.ZERO
	if main and is_instance_valid(main.player):
		vel = main.player.velocity
	var zoom: float = main.camera.zoom.x if main and main.camera else 1.0
	for li in NEAR.size():
		var l: Array = NEAR[li]
		var depth: float = l[0]
		var tail := -vel * depth * 0.09 * zoom
		if tail.length() > 160.0 * depth:
			tail = tail.normalized() * 160.0 * depth
		for i in int(l[1]):
			var h := float(i) * 12.9898 + li * 57.3
			var base := Vector2(fposmod(sin(h) * 43758.5453, 1.0), fposmod(sin(h + 1.91) * 24634.6345, 1.0)) * NEAR_TILE
			var lum := fposmod(sin(h * 3.7) * 9631.1, 1.0)
			var col := Color(0.8, 0.88, 1.0).lerp(Color(1.0, 0.9, 0.78), fposmod(lum * 7.0, 1.0))
			col.a = float(l[3]) * (0.45 + 0.55 * lum)
			var p := base - cam_pos * depth * zoom
			p = Vector2(fposmod(p.x, NEAR_TILE), fposmod(p.y, NEAR_TILE))
			var sz: float = l[2]
			var x := p.x
			while x < vp.x + 160.0:
				var y := p.y
				while y < vp.y + 160.0:
					var q := Vector2(x, y).floor()
					if tail.length() > 2.0:
						backdrop.draw_line(q, q + tail, Color(col, col.a * 0.55), sz * 0.75)
					backdrop.draw_rect(Rect2(q, Vector2(sz, sz)), col)
					y += NEAR_TILE
				x += NEAR_TILE


## Per-system scenery between the stars and the ships: what makes each place
## feel like itself. The Plate's far traffic, the Garden's spores, the Grind's
## ore dust, the Wall's picket buoys.
func _draw_ambience(vp: Vector2, cam_pos: Vector2, sid: String) -> void:
	match sid:
		"marcellus":
			_motes(vp, cam_pos, 90, 0.55, 900.0, Color(0.72, 0.6, 0.46, 0.55), Vector2(3, 3), Vector2(-6, 3))
			_motes(vp, cam_pos, 50, 0.8, 1100.0, Color(0.78, 0.64, 0.5, 0.4), Vector2(6, 6), Vector2(-10, 5))
		"tiberine":
			_motes(vp, cam_pos, 80, 0.45, 900.0, Color(0.7, 0.95, 0.55, 0.55), Vector2(3, 3), Vector2(4, -5))
			_motes(vp, cam_pos, 35, 0.7, 1000.0, Color(1.0, 0.9, 0.5, 0.4), Vector2(5, 5), Vector2(2, -8))
		"aurelia":
			# Far-off traffic: pairs of nav lights crawling along lanes.
			for i in 40:
				var h := float(i) * 7.31
				var base := Vector2(fposmod(sin(h) * 9137.0, 1800.0), fposmod(cos(h * 1.3) * 7121.0, 1000.0))
				var dir := Vector2.RIGHT.rotated(0.35 if i % 2 else PI + 0.35)
				var p := base + dir * _t * (14.0 + i % 5 * 4.0) - cam_pos * 0.2
				p = Vector2(fposmod(p.x, 1800.0), fposmod(p.y, 1000.0))
				if p.x > vp.x or p.y > vp.y:
					continue
				var on := fposmod(_t + i * 0.37, 1.4) < 0.25
				backdrop.draw_rect(Rect2(p, Vector2(3, 3)), Color(1.0, 0.3, 0.25, 1.0 if on else 0.35))
				backdrop.draw_rect(Rect2(p + dir.orthogonal() * 6.0, Vector2(3, 3)), Color(0.4, 1.0, 0.5, 0.35 if on else 1.0))
				backdrop.draw_rect(Rect2(p - dir * 4.0, Vector2(2, 2)), Color(0.9, 0.9, 0.85, 0.5))
		"porta_aquila":
			# The Wall's picket: a grid of navy buoys blinking in step.
			var g := 520.0
			var off := -cam_pos * 0.5
			off = Vector2(fposmod(off.x, g), fposmod(off.y, g))
			var on := fposmod(_t, 2.0) < 0.3
			var x := off.x - g
			while x < vp.x + g:
				var y := off.y - g
				while y < vp.y + g:
					backdrop.draw_rect(Rect2(Vector2(x, y), Vector2(3, 3)), Color(0.45, 0.7, 1.0, 0.9 if on else 0.2))
					if on:
						backdrop.draw_circle(Vector2(x + 1.5, y + 1.5), 7.0, Color(0.45, 0.7, 1.0, 0.12))
					y += g
				x += g


## Drifting square motes at one parallax depth, tiled across the screen.
func _motes(vp: Vector2, cam_pos: Vector2, count: int, depth: float, tile: float, col: Color, sz: Vector2, drift: Vector2) -> void:
	for i in count:
		var h := float(i) * 12.9898 + depth * 100.0
		var p := Vector2(fposmod(sin(h) * 43758.5, tile), fposmod(sin(h + 3.1) * 24634.6, tile))
		p += drift * _t - cam_pos * depth
		p = Vector2(fposmod(p.x, tile), fposmod(p.y, tile))
		var x := p.x
		while x < vp.x:
			var y := p.y
			while y < vp.y:
				backdrop.draw_rect(Rect2(Vector2(x, y).floor(), sz), col)
				y += tile
			x += tile


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
