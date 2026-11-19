extends Control
## Heads-up display: flagship status, fleet roster, combat indicator, target
## brackets, off-screen enemy arrows, radar, and messages.

var main: Node
var show_help := false
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


func _text(pos: Vector2, s: String, sz: int = 15, col: Color = Color(0.85, 0.9, 1.0), centered := false, bold := false) -> void:
	var font: Font = Data.font_bold if bold and Data.font_bold else ThemeDB.fallback_font
	if centered:
		pos.x -= font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x * 0.5
	draw_string(font, pos + Vector2(1, 1), s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color(0, 0, 0, 0.6))
	draw_string(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)


func _bar(rect: Rect2, frac: float, col: Color) -> void:
	UIStyle.draw_bar(self, rect, frac, col)


## Letter-spaced small caps for kickers and labels.
func _sp(s: String) -> String:
	return " ".join(s.split(""))


func _draw() -> void:
	var vp := size
	var t := Time.get_ticks_msec() / 1000.0

	# During a hail the guns are cold: say so instead of the combat banner.
	if main.story and main.story.ceasefire():
		_text(Vector2(vp.x * 0.5, 42), "GUNS COLD", 24, UIStyle.GOLD, true)
		_text(Vector2(vp.x * 0.5, 64), "You're being hailed. Pick a reply.", 14, Color(1.0, 0.9, 0.7), true)
	# Combat indicator: pulsing red frame and banner while enemies are close.
	elif main.in_combat:
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
		base = Vector2(vp.x * 0.5 - 220, vp.y - 108)
		UIStyle.draw_glass(self, Rect2(base, Vector2(440, 92)))
		_text(base + Vector2(18, 26), p.def["name"].to_upper(), 15, UIStyle.TEXT, false, true)
		var spd := "%d m/s" % int(p.velocity.length())
		_text(base + Vector2(422 - ThemeDB.fallback_font.get_string_size(spd, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x, 26), spd, 15, UIStyle.TEXT_DIM)
		if p.in_brake:
			_text(base + Vector2(220, 26), "BRAKE", 13, UIStyle.GOLD, true, true)
		var rows := [["SHIELDS", p.shields / p.max_shields, COL_SHIELD], ["HULL", p.hull_hp / p.max_hull, COL_HULL], ["ENERGY", p.energy / p.max_energy, COL_ENERGY]]
		for i in rows.size():
			var y0 := base.y + 44 + i * 16
			_text(Vector2(base.x + 18, y0 + 7), _sp(rows[i][0]), 10, rows[i][2])
			_bar(Rect2(Vector2(base.x + 100, y0), Vector2(322, 6)), rows[i][1], rows[i][2])
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
	var live: Array = main.escorts.filter(func(e): return is_instance_valid(e) and e.alive)
	if not live.is_empty():
		var ry := 128.0
		var rr := Rect2(Vector2(16, ry), Vector2(330, 48 + live.size() * 26))
		UIStyle.draw_glass(self, rr, 1.0, 10.0)
		_text(rr.position + Vector2(14, 22), _sp("FLEET") + "   ·   %s  ·  %s" % [_order_name(main.fleet_order), main.formation.capitalize()], 11, UIStyle.KICKER)
		var y := rr.position.y + 50
		for e in live:
			var nm: String = e.display_name if e.display_name != "" else e.def["name"]
			_text(Vector2(rr.position.x + 14, y), nm, 14, UIStyle.GOLD if e.is_friend else UIStyle.TEXT)
			_bar(Rect2(Vector2(rr.position.x + 220, y - 11), Vector2(94, 4)), e.shields / e.max_shields, COL_SHIELD)
			_bar(Rect2(Vector2(rr.position.x + 220, y - 5), Vector2(94, 4)), e.hull_hp / e.max_hull, COL_HULL)
			y += 26

	if main.merchant:
		_draw_merchant(vp, t)
	else:
		# Wave and score, top left.
		UIStyle.draw_glass(self, Rect2(Vector2(16, 16), Vector2(420, 96)))
		_text(Vector2(32, 40), _sp("COMBAT SANDBOX"), 11, UIStyle.KICKER)
		_text(Vector2(32, 70), "Wave %d" % main.wave, 26, Color(0.92, 0.97, 1.0), false, true)
		_text(Vector2(32, 96), "Pirates destroyed: %d" % main.kills, 15, UIStyle.TEXT)
		if main.next_wave_t > 0 and main.hostile_count() == 0 and main.wave > 0:
			_text(Vector2(250, 96), "Next wave in %d…" % ceili(main.next_wave_t), 15, UIStyle.GOLD)

	if main.message_t > 0:
		_text(Vector2(vp.x * 0.5, vp.y * 0.25), main.message, 20, Color(0.92, 0.97, 1.0, minf(1.0, main.message_t)), true, true)

	_draw_radar(Vector2(vp.x - 110, vp.y - 110), 90.0)

	if show_help:
		var lines := ["W / S   forward / back", "A / D   strafe", "Q / E   turn", "X   brake", "F   dock / jump",
			"Mouse   aim turrets", "Left click   fire turrets", "Space   fire cannons",
			"Tab (hold)   tactics wheel", "T   attack target under cursor", "Wheel   zoom", "H   hide controls"]
		var hr := Rect2(Vector2(vp.x - 300, 130), Vector2(284, 50 + lines.size() * 22))
		UIStyle.draw_glass(self, hr, 1.0, 10.0)
		_text(hr.position + Vector2(14, 24), _sp("CONTROLS"), 11, UIStyle.KICKER)
		for i in lines.size():
			_text(hr.position + Vector2(14, 52 + i * 22), lines[i], 14, UIStyle.TEXT)
	else:
		_text(Vector2(vp.x - 230, vp.y - 214), "H   controls", 13, Color(UIStyle.TEXT_DIM.r, UIStyle.TEXT_DIM.g, UIStyle.TEXT_DIM.b, 0.7))


func _brackets(c: Vector2, r: float, col: Color, w := 1.5) -> void:
	var l := r * 0.45
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var corner := c + Vector2(sx * r, sy * r)
			draw_line(corner, corner - Vector2(sx * l, 0), col, w)
			draw_line(corner, corner - Vector2(0, sy * l), col, w)


func _draw_radar(center: Vector2, r: float) -> void:
	draw_circle(center, r, Color(UIStyle.GLASS.r, UIStyle.GLASS.g, UIStyle.GLASS.b, 0.8))
	draw_arc(center, r + 4, 0, TAU, 64, Color(0.37, 0.82, 1.0, 0.12), 6.0, true)
	draw_arc(center, r, 0, TAU, 64, Color(0.47, 0.78, 1.0, 0.55), 1.2, true)
	draw_arc(center, r * 0.66, 0, TAU, 48, Color(0.37, 0.82, 1.0, 0.15), 1.0, true)
	draw_arc(center, r * 0.33, 0, TAU, 32, Color(0.37, 0.82, 1.0, 0.12), 1.0, true)
	draw_line(center - Vector2(r, 0), center + Vector2(r, 0), Color(0.37, 0.82, 1.0, 0.08), 1.0)
	draw_line(center - Vector2(0, r), center + Vector2(0, r), Color(0.37, 0.82, 1.0, 0.08), 1.0)
	var sweep := fmod(Time.get_ticks_msec() / 1000.0, 4.0) / 4.0 * TAU
	draw_line(center, center + Vector2.RIGHT.rotated(sweep) * r, Color(0.37, 0.82, 1.0, 0.25), 1.5, true)
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
	var sys: Dictionary = Data.systems.get(main.system_id, Data.crossroads)
	UIStyle.draw_glass(self, Rect2(Vector2(16, 16), Vector2(470, 100)))
	_text(Vector2(32, 40), _sp("%s SPACE · %s · DAY %d · WEEK %d" % [sys["security"].to_upper(), Data.sector["name"].to_upper(), int(Career.day) + 1, Career.week()]), 10, UIStyle.KICKER)
	_text(Vector2(32, 72), sys["name"], 28, Color(0.92, 0.97, 1.0), false, true)
	var nick_x := 32.0 + Data.font_bold.get_string_size(sys["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x + 12.0 if Data.font_bold else 200.0
	_text(Vector2(nick_x, 72), sys["nick"], 16, UIStyle.TEXT_DIM)
	var loan := "Loan paid off" if Career.loan_balance <= 0 else "Loan %s · %s due day %d" % [Career.fmt(Career.loan_balance), Career.fmt(mini(Data.LOAN_WEEKLY, Career.loan_balance)), int(Career.next_payment_day) + 1]
	_text(Vector2(32, 100), "%s cr" % Career.fmt(Career.credits), 15, UIStyle.TEXT, false, true)
	_text(Vector2(140, 100), "Hold %d/%d t" % [Career.cargo_used(), Career.cargo_capacity], 15, UIStyle.TEXT)
	_text(Vector2(262, 100), loan, 15, UIStyle.RED if Career.loan_balance > 0 else UIStyle.GREEN)

	# Objective line and a marker toward where to go next.
	if not Career.objective.is_empty():
		var ot: String = Career.objective["text"]
		var ow := ThemeDB.fallback_font.get_string_size(ot, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 40.0
		UIStyle.draw_glass(self, Rect2(Vector2(vp.x * 0.5 - ow * 0.5, 84), Vector2(ow, 34)), 1.0, 8.0, UIStyle.GREEN)
		_text(Vector2(vp.x * 0.5, 106), ot, 15, Color(0.75, 1.0, 0.8), true)
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
		var pw := ThemeDB.fallback_font.get_string_size(prompt, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x + 44.0
		UIStyle.draw_glass(self, Rect2(Vector2(vp.x * 0.5 - pw * 0.5, vp.y * 0.62 - 25), Vector2(pw, 36)), 1.0, 8.0, UIStyle.GOLD)
		_text(Vector2(vp.x * 0.5, vp.y * 0.62), prompt, 17, Color(1.0, 0.92, 0.7), true, true)
	if is_instance_valid(main.player) and main.player.ion_t > 0.0:
		var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.008)
		_text(Vector2(vp.x * 0.5, vp.y * 0.7), "ENGINES DOWN  ·  ION DAMAGE", 18, Color(0.78, 0.62, 1.0, pulse), true, true)
	if main.jump_charge >= 0.0:
		var frac: float = main.jump_charge / main.JUMP_CHARGE
		_text(Vector2(vp.x * 0.5, vp.y * 0.66), "JUMP DRIVE CHARGING", 16, Color(0.75, 0.6, 1.0), true)
		_bar(Rect2(Vector2(vp.x * 0.5 - 150, vp.y * 0.67), Vector2(300, 8)), frac, Color(0.65, 0.5, 1.0))

	# Comms box: who's talking to you.
	if _comms_t > 0.0 and not main.docked_at:
		var a := minf(1.0, _comms_t)
		var r := Rect2(Vector2(16, vp.y - 170), Vector2(540, 150))
		UIStyle.draw_glass(self, r, a, 12.0, UIStyle.GOLD)
		draw_rect(Rect2(r.position + Vector2(0, 14), Vector2(3, r.size.y - 28)), Color(UIStyle.GOLD.r, UIStyle.GOLD.g, UIStyle.GOLD.b, a))
		UIStyle.draw_id_photo(self, Rect2(r.position + Vector2(18, 18), Vector2(60, 72)), Data.portrait_for(_comms_speaker), "", _comms_speaker.hash())
		_text(r.position + Vector2(100, 34), _sp(_comms_speaker.to_upper()), 12, Color(UIStyle.GOLD.r, UIStyle.GOLD.g, UIStyle.GOLD.b, a))
		var font := ThemeDB.fallback_font
		draw_multiline_string(font, r.position + Vector2(100, 60), _comms_text, HORIZONTAL_ALIGNMENT_LEFT, 425, 15, 5, Color(UIStyle.TEXT.r, UIStyle.TEXT.g, UIStyle.TEXT.b, a))
