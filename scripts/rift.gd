class_name Rift
## A jump point drawn as what it is: a natural tear in space. A jagged,
## breathing seam of light on a pixel grid, with dust and ice drawn into it.
## Nobody built it; the gate station just sits on top.


## `length` is the seam's full height; `col` its light. Draws at the origin,
## vertical; rotate with draw_set_transform before calling.
static func draw(ci: CanvasItem, t: float, length: float, col: Color, seed := 7, px := 4.0) -> void:
	var half := length * 0.5
	var rows := int(length / px)
	var width := length * 0.15
	# Outer glow, the bright lips of the tear, the dark of whatever is behind
	# it, and a thin white thread down the middle.
	var void_col := Color(0.04, 0.01, 0.08)
	var layers := [[2.4, 0.08], [1.5, 0.16], [1.0, 0.9], [0.78, 1.0], [0.1, 0.9]]
	for li in layers.size():
		var spread: float = layers[li][0]
		var alpha: float = layers[li][1]
		var c: Color = col
		if li == 2:
			c = col.lerp(Color(1, 1, 1), 0.35)
		elif li == 3:
			c = void_col
		elif li == 4:
			c = col.lerp(Color(1, 1, 1), 0.6)
		c.a = alpha * (0.85 + 0.15 * sin(t * 7.0 + li))
		for r in rows:
			var y := -half + r * px
			var u := y / half                       # -1..1 along the seam
			var env := pow(maxf(1.0 - u * u, 0.0), 0.65)
			# Jagged spine: slow wander plus fast crackle near the core.
			var cx := sin(u * 3.1 + seed) * width * 0.35 + sin(u * 9.0 + seed * 2.1 + t * 0.5) * width * 0.08
			var w := width * spread * env * (0.8 + 0.2 * sin(u * 31.0 + t * 3.0 + seed))
			if li == 4:
				w *= 0.5 + 1.0 * absf(sin(u * 23.0 - t * 4.0))
			if w < px * 0.5:
				continue
			var x0 := floorf((cx - w) / px) * px
			var x1 := ceilf((cx + w) / px) * px
			ci.draw_rect(Rect2(x0, y, x1 - x0, px), c)
	# Debris: specks spiral in along the seam's flanks and wink out at the core.
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	# Faint stars that aren't ours, inside the tear.
	var srng := RandomNumberGenerator.new()
	srng.seed = seed + 11
	for i in 14:
		var u := srng.randf_range(-0.7, 0.7)
		var cx := sin(u * 3.1 + seed) * width * 0.35
		var env := pow(maxf(1.0 - u * u, 0.0), 0.65)
		var p := Vector2(cx + srng.randf_range(-0.5, 0.5) * width * 0.7 * env, u * half)
		ci.draw_rect(Rect2((p / px).floor() * px, Vector2(px, px) * 0.5), Color(0.8, 0.85, 1.0, 0.4 + 0.4 * sin(t * 2.0 + i)))
	for i in 40:
		var phase := fmod(t * rng.randf_range(0.08, 0.2) + rng.randf(), 1.0)
		var side := -1.0 if i % 2 == 0 else 1.0
		var y0 := rng.randf_range(-half * 0.8, half * 0.8)
		var d := (1.0 - phase) * width * rng.randf_range(3.0, 7.0)
		var p := Vector2(side * d, y0 + side * (1.0 - phase) * width * 1.5)
		p = (p / px).floor() * px
		var a := phase * (1.0 - phase) * 3.0
		ci.draw_rect(Rect2(p, Vector2(px, px) * (1.0 if i % 5 else 2.0)), Color(col.lightened(0.5), a * 0.7))
