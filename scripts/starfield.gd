extends Node2D
## Parallax starfield drawn in screen space. Far stars drift slower than near ones.

var main: Node
var _stars: Array = []
const TILE := 2048.0


func _ready() -> void:
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


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var vp := get_viewport_rect().size
	var cam_pos: Vector2 = main.camera.global_position if main and main.camera else Vector2.ZERO
	# Faint nebula washes for some colour.
	var neb := [[Vector2(600, 400), 900.0, Color(0.25, 0.1, 0.4, 0.06)], [Vector2(-900, 1300), 1200.0, Color(0.05, 0.25, 0.4, 0.05)]]
	for n in neb:
		var sp: Vector2 = n[0] - cam_pos * 0.03 + vp * 0.5
		var c: Color = n[2]
		# Stack soft circles so the nebula fades out instead of having a hard edge.
		for k in 10:
			var f := 1.0 - float(k) / 10.0
			draw_circle(sp, n[1] * f, Color(c.r, c.g, c.b, c.a * 0.35))
	for s in _stars:
		var p: Vector2 = s["p"] - cam_pos * s["depth"]
		p = Vector2(fposmod(p.x, TILE), fposmod(p.y, TILE))
		# Tile the star field to cover any screen size.
		var x := p.x
		while x < vp.x:
			var y := p.y
			while y < vp.y:
				draw_circle(Vector2(x, y), s["size"], s["color"])
				y += TILE
			x += TILE
