extends Control
## Heads-up display: flagship status, fleet roster, combat indicator, target
## brackets, off-screen enemy arrows, radar, and messages.

var main: Node
var show_help := false
var _comms_speaker := ""
var _comms_text := ""
var _comms_t := 0.0
var _comms_queue: Array = []
var _comms_age := 0.0

const COL_SHIELD := Color(0.35, 0.7, 1.0)
const COL_HULL := Color(0.95, 0.75, 0.3)
const COL_ENEMY := Color(1.0, 0.4, 0.3)
const COL_FRIEND := Color(0.4, 0.9, 1.0)
const COL_ENERGY := Color(0.75, 0.55, 1.0)


func _process(delta: float) -> void:
	_comms_t = maxf(0.0, _comms_t - delta)
	_comms_age += delta
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
	_comms_age = 0.0
	if main.docked_at == "":
		Sfx.play("radio", -8.0)


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
		if main.story.ringing:
			var a := 0.55 + 0.45 * absf(sin(t * 4.0))
			_text(Vector2(vp.x * 0.5, 64), "INCOMING HAIL  ·  OPEN BAND  ·  [C] answer", 15, Color(1.0, 0.9, 0.6, a), true)
		elif main.story._choices:
			_text(Vector2(vp.x * 0.5, 64), "Half speed. Pick a reply, or stay quiet.", 14, Color(1.0, 0.9, 0.7), true)
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
		if ship.disabled:
			col = Color(0.75, 0.75, 0.7)
		var onscreen := Rect2(Vector2.ZERO, vp).grow(-10).has_point(sp)
		if onscreen:
			var r: float = ship.radius * main.camera.zoom.x + 8.0
			_brackets(sp, r, Color(col.r, col.g, col.b, 0.55))
			var hw := roundf(r)
			if ship.max_shields > 0:
				_pips((sp + Vector2(-hw, r + 6)).round(), hw * 2.0, ship.shields / ship.max_shields, COL_SHIELD)
			_pips((sp + Vector2(-hw, r + 11)).round(), hw * 2.0, ship.hull_hp / ship.max_hull, COL_HULL)
			if ship.disabled:
				var blink := 0.6 + 0.4 * sin(t * 6.0)
				draw_string(Data.font_type_bold, (sp + Vector2(-hw, -r - 6)).round(), "DISABLED", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.95, 0.85, 0.5, blink))
		elif ship.team != 0 and not ship.disabled:
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
		# The rig's own plate: registration stencilled, speed on an amber readout.
		var reg := "CC-40817-M" if main.merchant else "FLAGSHIP"
		draw_string(Data.font_stamp, base + Vector2(18, 28), reg, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.86, 0.62, 0.18))
		draw_string(Data.font_type, base + Vector2(132, 27), p.def["name"].to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UIStyle.TEXT_DIM)
		var spd := "%03d m/s" % int(p.velocity.length())
		var sr := Rect2(base + Vector2(330, 11), Vector2(94, 22))
		draw_rect(sr, Color(0.03, 0.02, 0.01))
		draw_string(Data.font_type_bold, sr.position + Vector2(8, 16), spd, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1.0, 0.6, 0.2))
		if p.in_brake:
			_text(base + Vector2(290, 27), "BRAKE", 12, UIStyle.GOLD, true, true)
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


## Pixel-art brackets: chunky stepped corners on a pixel grid with a dark
## outline, so they sit with the sprites instead of floating over them.
func _brackets(c: Vector2, r: float, col: Color, w := 1.5) -> void:
	var px := 2.0 if w < 2.5 else 3.0
	c = (c / px).round() * px
	r = roundf(r / px) * px
	var l := roundf(r * 0.4 / px) * px
	var ink := Color(0.02, 0.03, 0.05, col.a * 0.8)
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var k := c + Vector2(sx * r, sy * r)
			# Arms as filled rects; the corner pixel steps outward one cell.
			var arms := [
				Rect2(Vector2(minf(k.x, k.x - sx * l), k.y - px * 0.5 * (1.0 + sy)), Vector2(l, px)),
				Rect2(Vector2(k.x - px * 0.5 * (1.0 + sx), minf(k.y, k.y - sy * l)), Vector2(px, l)),
			]
			for a in arms:
				draw_rect(a.grow(px * 0.5), ink)
			for a in arms:
				draw_rect(a, col)
			draw_rect(Rect2(k + Vector2(sx * px, sy * px) - Vector2(px, px) * 0.5 * Vector2(1.0 - sx, 1.0 - sy), Vector2(px, px)), col.lightened(0.3))


## Segmented pixel pip bar under a bracket.
func _pips(at: Vector2, width: float, frac: float, col: Color) -> void:
	var n := clampi(int(width / 6.0), 4, 14)
	var seg := floorf(width / n)
	draw_rect(Rect2(at - Vector2(1, 1), Vector2(seg * n + 1, 5)), Color(0.02, 0.03, 0.05, 0.7))
	for i in n:
		var on := float(i) + 0.5 < frac * n
		draw_rect(Rect2(at + Vector2(i * seg, 0), Vector2(seg - 1, 3)), col if on else Color(col.r, col.g, col.b, 0.15))


## The rig's scope: a green phosphor tube in a riveted bezel.
func _draw_radar(center: Vector2, r: float) -> void:
	const PH := Color(0.45, 1.0, 0.55)
	UIStyle.draw_glass(self, Rect2(center - Vector2(r + 12, r + 12), Vector2(r + 12, r + 12) * 2.0), 1.0, 0.0, PH)
	draw_circle(center, r + 3, Color(0.02, 0.025, 0.02))
	draw_circle(center, r, Color(0.03, 0.08, 0.04))
	for k in [0.33, 0.66, 1.0]:
		draw_arc(center, r * k, 0, TAU, 48, Color(PH.r, PH.g, PH.b, 0.14 if k < 1.0 else 0.35), 1.0)
	draw_line(center - Vector2(r, 0), center + Vector2(r, 0), Color(PH.r, PH.g, PH.b, 0.08), 1.0)
	draw_line(center - Vector2(0, r), center + Vector2(0, r), Color(PH.r, PH.g, PH.b, 0.08), 1.0)
	var sweep := fmod(Time.get_ticks_msec() / 1000.0, 4.0) / 4.0 * TAU
	for k in 8:
		draw_line(center, center + Vector2.RIGHT.rotated(sweep - k * 0.04) * r, Color(PH.r, PH.g, PH.b, 0.3 - k * 0.035), 2.0)
	var origin: Vector2 = main.camera.global_position
	var scale := r / 2400.0
	for s in get_tree().get_nodes_in_group("ships"):
		var ship := s as Ship
		if ship == null or not ship.alive:
			continue
		var rp := (ship.global_position - origin) * scale
		if rp.length() > r - 3:
			rp = rp.normalized() * (r - 3)
		var col := Color(0.55, 1.0, 0.65) if ship.team == 0 else Color(1.0, 0.45, 0.3)
		if ship == main.player:
			col = Color(0.9, 1.0, 0.9)
		var d := 4.0 if ship.radius > 20 else 3.0
		draw_rect(Rect2((center + rp - Vector2(d, d) * 0.5).round(), Vector2(d, d)), col)


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

	# Comms: a radio feed. Channel and file number in print, the speaker's ID
	# photo, and the words coming in a letter at a time over the static.
	if _comms_t > 0.0 and not main.docked_at:
		_draw_comms(vp)



func _draw_comms(vp: Vector2) -> void:
	var a := minf(1.0, _comms_t)
	var info: Dictionary = Data.speaker_info(_comms_speaker)
	var col: Color = info["color"]
	var r := Rect2(Vector2(16, vp.y - 172), Vector2(560, 152))
	draw_rect(r, Color(0.02, 0.035, 0.045, 0.92 * a))
	draw_rect(r, Color(col.r, col.g, col.b, 0.35 * a), false, 1.0)
	# Channel strip across the top.
	draw_rect(Rect2(r.position, Vector2(r.size.x, 20)), Color(col.r, col.g, col.b, 0.16 * a))
	var tf: Font = Data.font_type_bold if Data.font_type_bold else ThemeDB.fallback_font
	draw_string(tf, r.position + Vector2(10, 15), info["channel"], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(col.r, col.g, col.b, a))
	# Signal meter: bars that flicker while the line is still coming in.
	var typing := _comms_age * 55.0 < _comms_text.length()
	for k in 5:
		var on := k < (5 if not typing else 2 + int(_comms_age * 20.0) % 4)
		draw_rect(Rect2(r.end.x - 60 + k * 9, r.position.y + 14 - k * 2, 5, 3 + k * 2), Color(col.r, col.g, col.b, (0.9 if on else 0.2) * a))
	# ID photo with its file number; a flicker of static when the line opens.
	var photo := Rect2(r.position + Vector2(14, 32), Vector2(78, 100))
	UIStyle.draw_id_photo(self, photo, Data.portrait_for(_comms_speaker), info["serial"], _comms_speaker.hash(), _comms_speaker)
	if _comms_age < 0.35:
		var rng := RandomNumberGenerator.new()
		rng.seed = int(_comms_age * 60.0)
		for i in 40:
			var y := photo.position.y + rng.randf() * photo.size.y
			draw_rect(Rect2(photo.position.x, y, photo.size.x, 1), Color(1, 1, 1, rng.randf() * 0.5))
	for y in range(int(photo.position.y), int(photo.end.y), 3):
		draw_line(Vector2(photo.position.x, y), Vector2(photo.end.x, y), Color(0, 0, 0, 0.12 * a), 1.0)
	# Name, role, then the words.
	var x := photo.end.x + 18.0
	_text(Vector2(x, r.position.y + 44), _comms_speaker.to_upper(), 15, Color(1, 1, 1, a), false, true)
	var role_w := (Data.font_bold if Data.font_bold else ThemeDB.fallback_font).get_string_size(_comms_speaker.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	_text(Vector2(x + role_w + 10, r.position.y + 44), info["role"], 12, Color(col.r, col.g, col.b, 0.85 * a))
	var shown := _comms_text.substr(0, int(_comms_age * 55.0))
	draw_multiline_string(ThemeDB.fallback_font, Vector2(x, r.position.y + 70), shown, HORIZONTAL_ALIGNMENT_LEFT, r.end.x - x - 16, 15, 5, Color(UIStyle.TEXT.r, UIStyle.TEXT.g, UIStyle.TEXT.b, a))
