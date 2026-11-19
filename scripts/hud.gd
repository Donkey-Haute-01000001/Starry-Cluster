extends Control
## Heads-up display: flagship status, fleet roster, combat indicator, target
## brackets, off-screen enemy arrows, radar, and messages.

var main: Node
var show_help := true
var _comms_speaker := ""
var _comms_text := ""
var _comms_t := 0.0
var _comms_queue: Array = []

const COL_SHIELD := Color(0.35, 0.7, 1.0)
const COL_HULL := Color(0.95, 0.75, 0.3)
const COL_ENEMY := Color(1.0, 0.4, 0.3)
const COL_FRIEND := Color(0.4, 0.9, 1.0)
const COL_ENERGY := Color(0.75, 0.55, 1.0)


func _process(delta: float) -> void:
	_comms_t = maxf(0.0, _comms_t - delta)
	if _comms_t <= 0.0 and not _comms_queue.is_empty():
		var next: Array = _comms_queue.pop_front()
		_show_comms(next[0], next[1])
	queue_redraw()


## Comms messages from people (Charlie, dock crews). Shown in flight for a while.
## In flight, a line that arrives while another is showing waits its turn.
func on_comms(speaker: String, text: String) -> void:
	if main.docked_at == "" and _comms_t > 0.0:
		_comms_t = minf(_comms_t, 2.5)
		_comms_queue.append([speaker, text])
		return
	_comms_queue.clear()
	_show_comms(speaker, text)


func _show_comms(speaker: String, text: String) -> void:
	_comms_speaker = speaker
	_comms_text = text
	_comms_t = 6.0 + text.length() * 0.04


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
		if main.escorts.is_empty():
			_text(Vector2(vp.x * 0.5, 42), "HOSTILES CLOSING", 24, Color(1.0, 0.45, 0.35), true)
			_text(Vector2(vp.x * 0.5, 64), "Fight with your turret, or run for a station", 14, Color(1.0, 0.8, 0.75), true)
		else:
			_text(Vector2(vp.x * 0.5, 42), "FLEET ENGAGED", 24, Color(1.0, 0.45, 0.35), true)
			_text(Vector2(vp.x * 0.5, 64), "Hold Tab for tactics   ·   T: attack my target", 14, Color(1.0, 0.8, 0.75), true)

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
	var base := Vector2(vp.x * 0.5 - 180, vp.y - 80)
	if p and is_instance_valid(p) and p.alive:
		_text(base + Vector2(0, -8), p.def["name"].to_upper(), 14, Color(0.7, 0.85, 1.0))
		_text(base + Vector2(250, -8), "%d m/s" % int(p.velocity.length()), 14, Color(0.6, 0.75, 0.9))
		_bar(Rect2(base, Vector2(360, 12)), p.shields / p.max_shields, COL_SHIELD)
		_bar(Rect2(base + Vector2(0, 18), Vector2(360, 12)), p.hull_hp / p.max_hull, COL_HULL)
		_bar(Rect2(base + Vector2(0, 36), Vector2(360, 8)), p.energy / p.max_energy, COL_ENERGY)
		_text(base + Vector2(366, 11), "SHIELDS", 11, COL_SHIELD)
		_text(base + Vector2(366, 29), "HULL", 11, COL_HULL)
		_text(base + Vector2(366, 45), "ENERGY", 11, COL_ENERGY)
		if p.in_brake:
			_text(base + Vector2(130, -8), "BRAKE", 14, Color(1.0, 0.85, 0.4))
		# Velocity marker: where your drift is taking you.
		if p.velocity.length() > 20.0:
			var sp := _to_screen(p.global_position)
			var vp_end := sp + p.velocity.normalized() * (40.0 + 60.0 * p.velocity.length() / p.max_speed)
			draw_line(sp, vp_end, Color(0.6, 0.9, 1.0, 0.35), 1.5)
			draw_circle(vp_end, 3.0, Color(0.6, 0.9, 1.0, 0.6))
	else:
		_text(Vector2(vp.x * 0.5, vp.y * 0.45), "FREIGHTER DESTROYED" if main.merchant else "FLAGSHIP DESTROYED", 34, COL_ENEMY, true)
		_text(Vector2(vp.x * 0.5, vp.y * 0.45 + 34), "Press R to return to the start screen" if main.merchant else "Press R to restart", 18, Color(1, 1, 1), true)

	# Fleet roster, left side.
	var y := 120.0 if not main.merchant else 150.0
	if not main.escorts.is_empty():
		_text(Vector2(20, y), "FLEET  ·  %s  ·  %s" % [_order_name(main.fleet_order), main.formation.capitalize()], 14, Color(0.6, 0.85, 1.0))
	y += 10
	for e in main.escorts:
		if not is_instance_valid(e) or not e.alive:
			continue
		y += 22
		_text(Vector2(20, y), e.display_name if e.display_name != "" else e.def["name"], 13)
		_bar(Rect2(Vector2(150, y - 10), Vector2(80, 5)), e.shields / e.max_shields, COL_SHIELD)
		_bar(Rect2(Vector2(150, y - 3), Vector2(80, 5)), e.hull_hp / e.max_hull, COL_HULL)

	if main.merchant:
		_draw_merchant(vp, t)
	else:
		# Wave and score, top left.
		_text(Vector2(20, 34), "SECTOR SECUNDUS  ·  Combat sandbox", 16, Color(0.75, 0.88, 1.0))
		_text(Vector2(20, 58), "Wave %d   ·   Pirates destroyed: %d" % [main.wave, main.kills], 14)
		if main.next_wave_t > 0 and main.hostile_count() == 0 and main.wave > 0:
			_text(Vector2(20, 80), "Next wave in %d…" % ceili(main.next_wave_t), 14, Color(1.0, 0.8, 0.5))

	if main.message_t > 0:
		_text(Vector2(vp.x * 0.5, vp.y * 0.25), main.message, 20, Color(1, 1, 0.85, minf(1.0, main.message_t)), true)

	_draw_radar(Vector2(vp.x - 110, vp.y - 110), 90.0)

	if show_help:
		var lines := ["W/S forward/back   A/D strafe   Q/E turn   X brake   F dock / jump",
			"Mouse aim   Left click turrets   Space cannons",
			"Hold Tab tactics wheel   T attack target under cursor",
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


func _draw_merchant(vp: Vector2, t: float) -> void:
	var sys: Dictionary = Data.systems[main.system_id]
	_text(Vector2(20, 34), "%s  ·  %s" % [sys["name"].to_upper(), sys["nick"]], 18, Color(0.75, 0.88, 1.0))
	_text(Vector2(20, 58), "%s space  ·  %s  ·  Day %d, week %d" % [sys["security"], Data.sector["name"], int(Career.day) + 1, Career.week()], 14)
	_text(Vector2(20, 82), "Credits %s   ·   Hold %d/%d t   ·   Loan %s (next %s on day %d)" % [
		Career.fmt(Career.credits), Career.cargo_used(), Career.cargo_capacity, Career.fmt(Career.loan_balance),
		Career.fmt(mini(Data.LOAN_WEEKLY, Career.loan_balance)), int(Career.next_payment_day) + 1], 14, Color(1.0, 0.88, 0.6))

	# Objective line and a marker toward where to go next.
	if not Career.objective.is_empty():
		_text(Vector2(vp.x * 0.5, 100), Career.objective["text"], 16, Color(0.7, 1.0, 0.75), true)
		var target: Node2D = main.objective_target()
		if target and is_instance_valid(main.player):
			var sp := _to_screen(target.global_position)
			var col := Color(0.5, 1.0, 0.6, 0.85)
			if Rect2(Vector2.ZERO, vp).grow(-40).has_point(sp):
				_brackets(sp, 62.0 + 4.0 * sin(t * 4.0), col, 2.5)
			else:
				var center := vp * 0.5
				var dir := (sp - center).normalized()
				var edge := center + dir * minf(absf((vp.x * 0.5 - 50) / dir.x) if dir.x != 0 else 1e9, absf((vp.y * 0.5 - 50) / dir.y) if dir.y != 0 else 1e9)
				draw_colored_polygon(PackedVector2Array([edge + dir * 18, edge + dir.rotated(2.5) * 13, edge + dir.rotated(-2.5) * 13]), col)
				var dist := int(main.player.global_position.distance_to(target.global_position))
				_text(edge - dir * 30 + Vector2(0, 5), "%d" % dist, 13, col, true)

	# What F does right now.
	var b: Node2D = main.nearby_interactable()
	if b and is_instance_valid(main.player):
		var prompt := ""
		if b.kind == "station":
			prompt = "F  Dock at %s" % b.label
		elif b.locked:
			prompt = "F  Hail gate customs"
		else:
			prompt = "F  Jump to %s" % Data.systems[b.id]["name"]
		_text(Vector2(vp.x * 0.5, vp.y * 0.62), prompt, 18, Color(1.0, 0.95, 0.7), true)
	if main.jump_charge >= 0.0:
		var frac: float = main.jump_charge / main.JUMP_CHARGE
		_text(Vector2(vp.x * 0.5, vp.y * 0.66), "JUMP DRIVE CHARGING", 16, Color(0.75, 0.6, 1.0), true)
		_bar(Rect2(Vector2(vp.x * 0.5 - 150, vp.y * 0.67), Vector2(300, 8)), frac, Color(0.65, 0.5, 1.0))

	# Comms box: who's talking to you.
	if _comms_t > 0.0 and not main.docked_at:
		var a := minf(1.0, _comms_t)
		var r := Rect2(Vector2(20, vp.y - 250), Vector2(560, 130))
		draw_rect(r, Color(0.04, 0.07, 0.11, 0.85 * a))
		draw_rect(r, Color(0.4, 0.6, 0.8, 0.6 * a), false, 1.5)
		_text(r.position + Vector2(14, 24), _comms_speaker.to_upper(), 14, Color(1.0, 0.85, 0.55, a))
		var font := ThemeDB.fallback_font
		draw_multiline_string(font, r.position + Vector2(14, 48), _comms_text, HORIZONTAL_ALIGNMENT_LEFT, 530, 14, 6, Color(0.9, 0.92, 0.95, a))
