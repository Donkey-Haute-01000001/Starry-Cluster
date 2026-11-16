extends Control
## Heads-up display: flagship status, fleet roster, combat indicator, target
## brackets, off-screen enemy arrows, radar, and messages.

var main: Node
var show_help := true

const COL_SHIELD := Color(0.35, 0.7, 1.0)
const COL_HULL := Color(0.95, 0.75, 0.3)
const COL_ENEMY := Color(1.0, 0.4, 0.3)
const COL_FRIEND := Color(0.4, 0.9, 1.0)


func _process(_delta: float) -> void:
	queue_redraw()


func _to_screen(world_pos: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform() * world_pos


func _text(pos: Vector2, s: String, sz: int = 15, col: Color = Color(0.85, 0.9, 1.0), centered := false) -> void:
	var font := ThemeDB.fallback_font
	if centered:
		pos.x -= font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x * 0.5
	draw_string(font, pos + Vector2(1, 1), s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color(0, 0, 0, 0.6))
	draw_string(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)


func _bar(rect: Rect2, frac: float, col: Color) -> void:
	draw_rect(rect, Color(0.05, 0.08, 0.12, 0.8))
	draw_rect(Rect2(rect.position, Vector2(rect.size.x * clampf(frac, 0.0, 1.0), rect.size.y)), col)
	draw_rect(rect, col.darkened(0.3), false, 1.0)


func _draw() -> void:
	var vp := size
	var t := Time.get_ticks_msec() / 1000.0

	# Combat indicator: pulsing red frame and banner while enemies are close.
	if main.in_combat:
		var a := 0.25 + 0.15 * sin(t * 5.0)
		for k in 4:
			var inset := float(k) * 6.0
			draw_rect(Rect2(Vector2(inset, inset), vp - Vector2(inset, inset) * 2.0), Color(1.0, 0.15, 0.1, a * (1.0 - k * 0.25)), false, 6.0)
		_text(Vector2(vp.x * 0.5, 42), "FLEET ENGAGED", 24, Color(1.0, 0.45, 0.35), true)
		_text(Vector2(vp.x * 0.5, 64), "Hold Q for tactics   ·   T: attack my target", 14, Color(1.0, 0.8, 0.75), true)

	# Brackets on fleet ships and enemies, and arrows to enemies off screen.
	for s in get_tree().get_nodes_in_group("ships"):
		var ship := s as Ship
		if ship == null or not ship.alive or ship == main.player:
			continue
		var sp := _to_screen(ship.global_position)
		var col := COL_FRIEND if ship.team == 0 else COL_ENEMY
		var onscreen := Rect2(Vector2.ZERO, vp).grow(-10).has_point(sp)
		if onscreen:
			var r: float = ship.radius * main.camera.zoom.x + 8.0
			_brackets(sp, r, Color(col.r, col.g, col.b, 0.55))
			var hw := r
			if ship.max_shields > 0:
				draw_rect(Rect2(sp + Vector2(-hw, r + 4), Vector2(hw * 2.0 * ship.shields / ship.max_shields, 2)), COL_SHIELD)
			draw_rect(Rect2(sp + Vector2(-hw, r + 7), Vector2(hw * 2.0 * ship.hull_hp / ship.max_hull, 2)), COL_HULL)
		elif ship.team != 0:
			var center := vp * 0.5
			var dir := (sp - center).normalized()
			var edge := center + dir * minf(absf((vp.x * 0.5 - 30) / dir.x) if dir.x != 0 else 1e9, absf((vp.y * 0.5 - 30) / dir.y) if dir.y != 0 else 1e9)
			draw_colored_polygon(PackedVector2Array([edge + dir * 12, edge + dir.rotated(2.5) * 9, edge + dir.rotated(-2.5) * 9]), COL_ENEMY)

	if main.focus_target and is_instance_valid(main.focus_target):
		var fp := _to_screen(main.focus_target.global_position)
		var fr: float = main.focus_target.radius * main.camera.zoom.x + 16.0 + 3.0 * sin(t * 8.0)
		_brackets(fp, fr, Color(1.0, 0.9, 0.3), 3.0)
		_text(fp + Vector2(0, -fr - 8), "TARGET", 12, Color(1.0, 0.9, 0.3), true)

	# Flagship status, bottom centre.
	var p: Ship = main.player
	var base := Vector2(vp.x * 0.5 - 180, vp.y - 70)
	if p and is_instance_valid(p) and p.alive:
		_text(base + Vector2(0, -8), p.def["name"].to_upper(), 14, Color(0.7, 0.85, 1.0))
		_text(base + Vector2(250, -8), "%d m/s" % int(p.velocity.length()), 14, Color(0.6, 0.75, 0.9))
		_bar(Rect2(base, Vector2(360, 12)), p.shields / p.max_shields, COL_SHIELD)
		_bar(Rect2(base + Vector2(0, 18), Vector2(360, 12)), p.hull_hp / p.max_hull, COL_HULL)
		_text(base + Vector2(366, 11), "SHIELDS", 11, COL_SHIELD)
		_text(base + Vector2(366, 29), "HULL", 11, COL_HULL)
	else:
		_text(Vector2(vp.x * 0.5, vp.y * 0.45), "FLAGSHIP DESTROYED", 34, COL_ENEMY, true)
		_text(Vector2(vp.x * 0.5, vp.y * 0.45 + 34), "Press R to restart", 18, Color(1, 1, 1), true)

	# Fleet roster, left side.
	var y := 120.0
	_text(Vector2(20, y), "FLEET  ·  %s  ·  %s" % [_order_name(main.fleet_order), main.formation.capitalize()], 14, Color(0.6, 0.85, 1.0))
	y += 10
	for e in main.escorts:
		if not is_instance_valid(e) or not e.alive:
			continue
		y += 22
		_text(Vector2(20, y), e.def["name"], 13)
		_bar(Rect2(Vector2(150, y - 10), Vector2(80, 5)), e.shields / e.max_shields, COL_SHIELD)
		_bar(Rect2(Vector2(150, y - 3), Vector2(80, 5)), e.hull_hp / e.max_hull, COL_HULL)

	# Wave and score, top left.
	_text(Vector2(20, 34), "SECTOR SECUNDUS  ·  Combat sandbox", 16, Color(0.75, 0.88, 1.0))
	_text(Vector2(20, 58), "Wave %d   ·   Pirates destroyed: %d" % [main.wave, main.kills], 14)
	if main.next_wave_t > 0 and main.hostile_count() == 0 and main.wave > 0:
		_text(Vector2(20, 80), "Next wave in %d…" % ceili(main.next_wave_t), 14, Color(1.0, 0.8, 0.5))

	if main.message_t > 0:
		_text(Vector2(vp.x * 0.5, vp.y * 0.25), main.message, 20, Color(1, 1, 0.85, minf(1.0, main.message_t)), true)

	_draw_radar(Vector2(vp.x - 110, vp.y - 110), 90.0)

	if show_help:
		var lines := ["W thrust   A/D turn   S face retrograde",
			"Mouse aim turrets   Left click / Space fire",
			"Hold Q tactics wheel   T attack target under cursor",
			"Mouse wheel zoom   H hide help"]
		for i in lines.size():
			_text(Vector2(20, vp.y - 90 + i * 20), lines[i], 13, Color(0.7, 0.8, 0.9, 0.85))


func _brackets(c: Vector2, r: float, col: Color, w := 1.5) -> void:
	var l := r * 0.45
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var corner := c + Vector2(sx * r, sy * r)
			draw_line(corner, corner - Vector2(sx * l, 0), col, w)
			draw_line(corner, corner - Vector2(0, sy * l), col, w)


func _draw_radar(center: Vector2, r: float) -> void:
	draw_circle(center, r, Color(0.02, 0.06, 0.1, 0.75))
	draw_arc(center, r, 0, TAU, 48, Color(0.3, 0.6, 0.8, 0.6), 1.5, true)
	draw_arc(center, r * 0.5, 0, TAU, 32, Color(0.3, 0.6, 0.8, 0.25), 1.0, true)
	var origin: Vector2 = main.camera.global_position
	var scale := r / 2400.0
	for s in get_tree().get_nodes_in_group("ships"):
		var ship := s as Ship
		if ship == null or not ship.alive:
			continue
		var rp := (ship.global_position - origin) * scale
		if rp.length() > r - 3:
			rp = rp.normalized() * (r - 3)
		var col := COL_FRIEND if ship.team == 0 else COL_ENEMY
		if ship == main.player:
			col = Color(1, 1, 1)
		draw_circle(center + rp, 3.0 if ship.radius > 20 else 2.0, col)


func _order_name(id: String) -> String:
	match id:
		"engage": return "Engage at will"
		"focus": return "Attack my target"
		"hold": return "Hold formation"
	return id
