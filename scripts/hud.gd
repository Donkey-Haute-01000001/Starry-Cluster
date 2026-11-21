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
var comms_top := 0.0      ## top edge of the comms panel this frame (cards stack above it)

const COL_SHIELD := Color(0.35, 0.7, 1.0)
const COL_HULL := Color(0.95, 0.75, 0.3)
const COL_ENEMY := Color(1.0, 0.4, 0.3)
const COL_FRIEND := Color(0.4, 0.9, 1.0)
const COL_ENERGY := Color(0.75, 0.55, 1.0)


# --- First-flight prompts ---------------------------------------------------------
## Each shows once per career, when it's useful, and clears once you've done it.
const TIPS := {
	"fly": [["W", "thrust"], ["MOUSE", "steer"], ["X", "brake"]],
	"travel": [["G", "autopilot to the job"], ["C", "cruise"]],
	"guns": [["LMB", "turrets"], ["RMB", "ion / torpedo"], ["R", "swap"]],
	"tactics": [["HOLD TAB", "fleet orders"]],
}
var tip := ""          ## the prompt on screen ("" = none)
var _tip_t := 0.0      ## how long it's been up
var _tip_a := 0.0      ## fade
var _tip_moved := 0.0
var _tip_done_t := -1.0


func _tip_step(delta: float) -> void:
	var p: Ship = main.player if is_instance_valid(main.player) else null
	_tip_a = move_toward(_tip_a, 1.0 if tip != "" and _tip_done_t < 0.0 else 0.0, delta * 3.0)
	if not main.merchant or p == null or main.docked_at != "" or main.story.busy():
		return
	if tip != "":
		_tip_t += delta
		_tip_moved += p.velocity.length() * delta
		if _tip_done_t < 0.0 and _tip_finished(p):
			_tip_done_t = 0.0
			Career.flags["tip_" + tip] = true
		if _tip_done_t >= 0.0:
			_tip_done_t += delta
			if _tip_done_t > 0.6:
				tip = ""
		return
	var f: Dictionary = Career.flags
	var next := ""
	if not f.get("tip_guns", false) and main.nearest_enemy(0, p.global_position, 1400.0) != null:
		next = "guns"
	elif not f.get("tip_fly", false):
		next = "fly"
	elif not f.get("tip_travel", false):
		var t: Node2D = main.objective_target()
		if t and p.global_position.distance_to(t.global_position) > 2500.0 and not main.in_combat:
			next = "travel"
	elif not f.get("tip_tactics", false) and f.get("tip_guns", false) and main.in_combat and not main.escorts.is_empty():
		next = "tactics"
	if next != "":
		tip = next
		_tip_t = 0.0
		_tip_moved = 0.0
		_tip_done_t = -1.0


func _tip_finished(p: Ship) -> bool:
	match tip:
		"fly":
			return _tip_moved > 900.0 or _tip_t > 25.0
		"travel":
			return main.autopilot_on() or p.cruise_on or _tip_t > 30.0
		"guns":
			return (_tip_t > 5.0 and (p.in_fire_aimed or p.in_fire_fixed)) or _tip_t > 16.0 or not main.in_combat
		"tactics":
			return main.wheel_open() or _tip_t > 14.0
	return true


## Key caps in a row, centred under the ship: [KEY] what it does.
func _draw_tip(vp: Vector2) -> void:
	if _tip_a <= 0.01 or not TIPS.has(tip if tip != "" else "fly"):
		return
	var segs: Array = TIPS.get(tip, [])
	if segs.is_empty():
		return
	var font: Font = ThemeDB.fallback_font
	var bold: Font = Data.font_bold
	var gap := 26.0
	var w := 0.0
	for sg in segs:
		w += bold.get_string_size(sg[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 18.0 + 8.0
		w += font.get_string_size(sg[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x + gap
	w -= gap
	var a := _tip_a
	var x := vp.x * 0.5 - w * 0.5
	var y := vp.y * 0.74
	draw_rect(Rect2(x - 18, y - 22, w + 36, 40), Color(0.02, 0.025, 0.035, 0.6 * a))
	var ok := _tip_done_t >= 0.0
	for sg in segs:
		var kw := bold.get_string_size(sg[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 18.0
		var kr := Rect2(x, y - 13, kw, 24)
		draw_rect(Rect2(kr.position + Vector2(0, 3), kr.size), Color(0.5, 0.52, 0.55, 0.5 * a))
		draw_rect(kr, Color(0.93, 0.94, 0.95, a) if not ok else Color(0.55, 0.95, 0.6, a))
		draw_string(bold, Vector2(x + 9, y + 5), sg[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.05, 0.06, 0.07, a))
		x += kw + 8.0
		draw_string(font, Vector2(x, y + 6), sg[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(1, 1, 1, 0.92 * a))
		x += font.get_string_size(sg[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x + gap


func _process(delta: float) -> void:
	_tip_step(delta)
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


## Cruise streaks: thin lines sliding past along your heading.
func _draw_streaks(vp: Vector2) -> void:
	var p: Ship = main.player
	if p == null or not is_instance_valid(p) or p.cruise_k <= 0.05:
		return
	var v := p.velocity
	var spd := v.length()
	if spd < 400.0:
		return
	var dir := -v / spd
	var k := p.cruise_k * clampf((spd - 400.0) / 900.0, 0.0, 1.0)
	var t := Time.get_ticks_msec() / 1000.0
	for i in 46:
		var h := float(i) * 12.9898
		var bx := fposmod(sin(h) * 43758.5453, 1.0) * vp.x
		var by := fposmod(sin(h + 1.7) * 24634.6345, 1.0) * vp.y
		var travel := fposmod(t * spd * 0.9 + i * 137.0, vp.length())
		var pt := Vector2(fposmod(bx + dir.x * travel, vp.x), fposmod(by + dir.y * travel, vp.y))
		var ln := 40.0 + 120.0 * k
		draw_line(pt, pt - dir * ln, Color(0.75, 0.88, 1.0, 0.22 * k), 1.5)


## Space dust: specks fixed in the world, so they slide past at your true speed
## (the starfield is far away and barely moves). Streaks stretch with speed.
const DUST_CELL := 300.0


func _draw_dust(vp: Vector2) -> void:
	var p: Ship = main.player
	if p == null or not is_instance_valid(p):
		return
	var xf := get_viewport().get_canvas_transform()
	var inv := xf.affine_inverse()
	var a0: Vector2 = inv * Vector2.ZERO
	var a1: Vector2 = inv * vp
	var zoom := xf.get_scale().x
	var v := p.velocity
	var spd := v.length()
	var tail := -v * 0.12 * zoom
	if tail.length() > 70.0:
		tail = tail.normalized() * 70.0
	# Only shows when you move: at rest space is empty and still.
	var fade := clampf((spd - 40.0) / 220.0, 0.0, 1.0) * (1.0 - 0.7 * p.cruise_k)
	if fade <= 0.01:
		return
	for cx in range(floori(a0.x / DUST_CELL) - 1, ceili(a1.x / DUST_CELL) + 1):
		for cy in range(floori(a0.y / DUST_CELL) - 1, ceili(a1.y / DUST_CELL) + 1):
			var h := float(cx * 73856093 ^ cy * 19349663)
			var jx := fposmod(sin(h) * 43758.5453, 1.0)
			var jy := fposmod(sin(h * 1.37 + 2.1) * 24634.6345, 1.0)
			var lum := fposmod(sin(h * 0.71 + 5.3) * 9631.17, 1.0)
			var sp := xf * Vector2((cx + jx) * DUST_CELL, (cy + jy) * DUST_CELL)
			var col := Color(0.85, 0.9, 0.95, (0.22 + 0.33 * lum) * fade)
			if spd > 25.0:
				draw_line(sp, sp + tail, col, 1.0)
			draw_rect(Rect2(sp - Vector2(1, 1), Vector2(2, 2)), Color(col, col.a * 1.4))


## Velocity marker: a small ring where you're drifting, a tick where you're
## pointing. When they disagree, you're sliding.
func _draw_vel_marker() -> void:
	var p: Ship = main.player
	if p == null or not is_instance_valid(p) or not p.alive:
		return
	var c := _to_screen(p.global_position)
	var spd := p.velocity.length()
	var col := Color(0.55, 0.9, 1.0, 0.75)
	# heading tick
	var hd := Vector2.RIGHT.rotated(p.rotation)
	draw_line(c + hd * 78.0, c + hd * 90.0, Color(1, 1, 1, 0.6), 2.0)
	if spd < 20.0:
		return
	var vd := p.velocity / spd
	var r := 72.0 + clampf(spd / 300.0, 0.0, 1.0) * 30.0
	var m := c + vd * r
	draw_arc(m, 6.0, 0.0, TAU, 16, col, 1.5)
	for k in 3:
		var a := vd.angle() + PI + (k - 1) * PI * 0.5
		draw_line(m + Vector2.RIGHT.rotated(a) * 6.0, m + Vector2.RIGHT.rotated(a) * 10.0, col, 1.5)
	_text(m + vd * 14.0 + Vector2(-8, 4) + Vector2(vd.x * 10.0, 0), "%d" % int(spd), 12, Color(col, 0.85))


func _draw() -> void:
	var vp := size
	var t := Time.get_ticks_msec() / 1000.0
	_draw_dust(vp)
	_draw_streaks(vp)
	_draw_vel_marker()

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
		if p.cruise_k > 0.0 or p.cruise_on:
			# Cruise: spool bar under the readout, and the drive state.
			var full := p.cruise_k >= 1.0
			var tag := "CRUISE" if full else ("SPOOL" if p.cruise_on else "DROP")
			_text(base + Vector2(286, 27), tag, 12, Color(0.45, 0.85, 1.0) if full else UIStyle.GOLD, true, true)
			draw_rect(Rect2(sr.position + Vector2(0, 24), Vector2(94 * p.cruise_k, 3)), Color(0.45, 0.85, 1.0))
		elif p.in_brake:
			_text(base + Vector2(290, 27), "BRAKE", 12, UIStyle.GOLD, true, true)
		elif main.merchant and not main.in_combat:
			_text(base + Vector2(286, 27), "[C] CRUISE", 10, Color(UIStyle.TEXT_DIM.r, UIStyle.TEXT_DIM.g, UIStyle.TEXT_DIM.b, 0.8), true)
		if not p.secondaries.is_empty():
			# Secondary tab on top of the plate: what right click fires.
			var sec: Dictionary = p.secondaries[p.sec_index]
			var sw: Dictionary = sec["weapon"]
			var state := "READY"
			var sc := UIStyle.GREEN
			if sec["ammo"] == 0:
				state = "EMPTY"
				sc = UIStyle.RED
			elif sec["cooldown"] > 0.0:
				state = "LOADING"
				sc = UIStyle.GOLD
			var label: String = sw["name"].to_upper() + ("  %d/%d" % [sec["ammo"], sw["ammo"]] if sw.has("ammo") else "")
			var tab := Rect2(base + Vector2(0, -24), Vector2(300, 22))
			draw_rect(tab, Color(0.05, 0.055, 0.06, 0.92))
			draw_rect(Rect2(tab.position, Vector2(3, tab.size.y)), sw["color"])
			draw_string(Data.font_type_bold, tab.position + Vector2(12, 16), "RMB  " + label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UIStyle.TEXT)
			var stw := Data.font_type_bold.get_string_size(state, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
			draw_string(Data.font_type_bold, tab.position + Vector2(tab.size.x - 10 - stw, 16), state, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, sc)
			draw_string(Data.font_type, tab.position + Vector2(tab.size.x + 10, 16), "[R] swap", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UIStyle.TEXT_DIM)
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

	if main.merchant:
		_draw_tip(vp)
		if main.autopilot_on():
			_text(Vector2(vp.x * 0.5, 160), _sp("AUTOPILOT") + "   →   " + str(main.player.controller.autopilot.label), 13, Color(0.55, 0.9, 1.0, 0.9), true, true)
	if main.message_t > 0:
		_text(Vector2(vp.x * 0.5, vp.y * 0.25), main.message, 20, Color(0.92, 0.97, 1.0, minf(1.0, main.message_t)), true, true)

	_draw_radar(Vector2(vp.x - 110, vp.y - 110), 90.0)

	if show_help:
		var lines := ["W / S   forward / back", "A / D   strafe", "Mouse   steer (M toggles)", "Q / E   turn", "V   flight assist on/off", "X   brake", "F   dock / jump",
			"Mouse   aim turrets", "Left click   fire turrets", "Space   fire cannons (if fitted)", "Right click   fire secondary", "R   swap secondary",
			"C   cruise drive", "G   autopilot to the job", "Tab (hold)   tactics wheel", "T   attack target under cursor", "Wheel   zoom", "Esc   pause", "H   hide controls"]
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


const SECURITY_COLORS := {
	"Core": Color(0.45, 0.85, 0.55), "Mid": Color(1.0, 0.77, 0.42), "Rough": Color(1.0, 0.42, 0.3),
	"Fortress": Color(0.45, 0.7, 1.0), "Dynasty": Color(0.8, 0.55, 1.0),
}


## Security tag: striped warning plate. Rough space gets the black-and-colour
## hazard stripes; the rest a calmer solid band.
func _hazard(r: Rect2, col: Color, striped: bool) -> void:
	draw_rect(r, col.darkened(0.55))
	if striped:
		for i in range(-2, int(r.size.x / 8.0) + 3):
			var x := r.position.x + i * 8.0
			var poly := PackedVector2Array([Vector2(x, r.end.y), Vector2(x + 4, r.end.y), Vector2(x + 4 + r.size.y, r.position.y), Vector2(x + r.size.y, r.position.y)])
			for j in poly.size():
				poly[j].x = clampf(poly[j].x, r.position.x, r.end.x)
			draw_colored_polygon(poly, col)
	draw_rect(r, col.darkened(0.2), false, 1.0)


## Embossed label-maker tape: black strip, raised white letters, tilted a hair.
func _label_tape(at: Vector2, text: String, seed: int) -> void:
	var f: Font = Data.font_type_bold
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 20.0
	var tilt := (float(absi(seed) % 7) - 3.0) * 0.006
	draw_set_transform(at, tilt, Vector2.ONE)
	var r := Rect2(Vector2.ZERO, Vector2(w, 22))
	draw_rect(Rect2(r.position + Vector2(1, 2), r.size), Color(0, 0, 0, 0.5))
	draw_rect(r, Color(0.08, 0.08, 0.09))
	draw_rect(Rect2(Vector2(0, 0), Vector2(w, 1)), Color(0.25, 0.25, 0.27))
	# Cut ends.
	draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(3, 11), Vector2(0, 22)]), Color(0.075, 0.085, 0.095))
	draw_colored_polygon(PackedVector2Array([Vector2(w, 0), Vector2(w - 3, 11), Vector2(w, 22)]), Color(0.075, 0.085, 0.095))
	draw_string(f, Vector2(10, 16), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.93, 0.93, 0.9))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The current job, as a dispatch printout fed out of the dash printer:
## thermal paper, typed, torn edge at the bottom.
func _draw_dispatch_slip(vp: Vector2, text: String) -> void:
	var f: Font = Data.font_type
	var fb: Font = Data.font_type_bold
	var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	var w := maxf(tw + 44.0, 300.0)
	var r := Rect2(Vector2(roundf(vp.x * 0.5 - w * 0.5), 74), Vector2(roundf(w), 50))
	# Printer slot it hangs from.
	draw_rect(Rect2(r.position + Vector2(-10, -6), Vector2(r.size.x + 20, 8)), Color(0.05, 0.05, 0.06))
	draw_rect(Rect2(r.position + Vector2(-10, -6), Vector2(r.size.x + 20, 2)), Color(0.24, 0.26, 0.28))
	# Paper with a torn bottom edge.
	var paper := Color(0.93, 0.91, 0.85)
	var poly := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y)])
	var n := int(r.size.x / 7.0)
	for i in range(n, -1, -1):
		var x := r.position.x + r.size.x * float(i) / n
		poly.append(Vector2(x, r.end.y - (3.0 if i % 2 else 0.0)))
	var shadow := PackedVector2Array()
	for q in poly:
		shadow.append(q + Vector2(2, 3))
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.45))
	draw_colored_polygon(poly, paper)
	draw_string(fb, r.position + Vector2(14, 16), "DISPATCH  ·  CHARTER CH 03", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UIStyle.INK_FADED)
	draw_string(fb, r.position + Vector2(r.size.x - 14 - fb.get_string_size("JOB", HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x, 16), "JOB", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UIStyle.INK_STAMP)
	draw_string(f, r.position + Vector2(roundf((r.size.x - tw) * 0.5), 37), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UIStyle.INK_TYPE)


func _draw_merchant(vp: Vector2, t: float) -> void:
	var sys: Dictionary = Data.systems.get(main.system_id, Data.crossroads)
	# The rig's nav plate: security tag, stencilled system name, and the
	# nickname spacers use, punched on label tape and stuck on crooked.
	var plate := Rect2(Vector2(16, 16), Vector2(470, 108))
	UIStyle.draw_glass(self, plate, 1.0, 14.0, SECURITY_COLORS.get(sys["security"], UIStyle.GOLD))
	var sec: String = sys["security"].to_upper()
	var sc: Color = SECURITY_COLORS.get(sys["security"], UIStyle.GOLD)
	var tf: Font = Data.font_type_bold
	var tag_w := tf.get_string_size(sec, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 34.0
	var tag := Rect2(Vector2(30, 26), Vector2(tag_w, 18))
	_hazard(tag, sc, sys.get("danger", 0.0) > 0.5)
	draw_rect(Rect2(tag.position + Vector2(9, 3), Vector2(tag_w - 18, 12)), Color(0.04, 0.04, 0.05))
	draw_string(tf, tag.position + Vector2(17, 13), sec, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, sc)
	draw_string(Data.font_type, Vector2(tag.end.x + 10, 39), "%s  ·  DAY %d  ·  WK %d" % [Data.sector["name"].to_upper(), int(Career.day) + 1, Career.week()], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UIStyle.TEXT_DIM)
	var name_up: String = sys["name"].to_upper()
	draw_string(Data.font_stamp, Vector2(31, 79), name_up, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(0, 0, 0, 0.6))
	draw_string(Data.font_stamp, Vector2(30, 78), name_up, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(0.9, 0.88, 0.82))
	var nick_x := 30.0 + Data.font_stamp.get_string_size(name_up, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x + 14.0
	_label_tape(Vector2(nick_x, 58), sys["nick"].to_upper(), sys["name"].hash())
	var loan := "Loan paid off" if Career.loan_balance <= 0 else "Loan %s · %s due day %d" % [Career.fmt(Career.loan_balance), Career.fmt(mini(Data.LOAN_WEEKLY, Career.loan_balance)), int(Career.next_payment_day) + 1]
	draw_line(Vector2(30, 90), Vector2(plate.end.x - 14, 90), Color(0.22, 0.24, 0.26), 1.0)
	_text(Vector2(32, 112), "%s cr" % Career.fmt(Career.credits), 15, UIStyle.TEXT, false, true)
	_text(Vector2(140, 112), "Hold %d/%d t" % [Career.cargo_used(), Career.cargo_capacity], 15, UIStyle.TEXT)
	_text(Vector2(262, 112), loan, 15, UIStyle.RED if Career.loan_balance > 0 else UIStyle.GREEN)

	# Objective line and a marker toward where to go next.
	if not Career.objective.is_empty():
		var ot: String = Career.objective["text"]
		_draw_dispatch_slip(vp, ot)
		var target: Node2D = main.objective_target()
		if target and is_instance_valid(main.player):
			var sp := _to_screen(target.global_position)
			var col := Color(0.5, 1.0, 0.6, 0.85)
			if Rect2(Vector2.ZERO, vp).grow(-40).has_point(sp):
				_brackets(sp, 62.0 + 4.0 * sin(t * 4.0), col, 2.5)
			else:
				# Ride the edge of the clear middle, inside the HUD panels.
				var lane := Rect2(Vector2(60, 150), vp - Vector2(120, 150 + 240))
				var center := lane.get_center()
				var dir := (sp - center).normalized()
				var edge := center + dir * minf(absf(lane.size.x * 0.5 / dir.x) if dir.x != 0 else 1e9, absf(lane.size.y * 0.5 / dir.y) if dir.y != 0 else 1e9)
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
	comms_top = vp.y - 192.0
	if _comms_t > 0.0 and not main.docked_at:
		_draw_comms(vp)



func _draw_comms(vp: Vector2) -> void:
	var a := minf(1.0, _comms_t)
	var info: Dictionary = Data.speaker_info(_comms_speaker)
	var col: Color = info["color"]
	# The panel grows upward to fit the whole line.
	var body_w := 560.0 - 110.0 - 16.0
	var text_h := ThemeDB.fallback_font.get_multiline_string_size(_comms_text, HORIZONTAL_ALIGNMENT_LEFT, body_w, 17).y
	var h := maxf(152.0, 70.0 + text_h + 18.0)
	var r := Rect2(Vector2(16, vp.y - 20 - h), Vector2(560, h))
	comms_top = r.position.y
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
	# Channel static across the whole panel while the line opens.
	if _comms_age < 0.3:
		var srng := RandomNumberGenerator.new()
		srng.seed = int(_comms_age * 90.0) + 7
		var fade := 1.0 - _comms_age / 0.3
		for i in 26:
			var sy := r.position.y + 20 + srng.randf() * (r.size.y - 20)
			var sx := r.position.x + srng.randf() * r.size.x * 0.6
			draw_rect(Rect2(sx, sy, srng.randf_range(40, r.size.x * 0.5), srng.randf_range(1, 3)), Color(col.r, col.g, col.b, srng.randf() * 0.4 * fade))
	# Name, role, then the words.
	var x := photo.end.x + 18.0
	_text(Vector2(x, r.position.y + 44), _comms_speaker.to_upper(), 15, Color(1, 1, 1, a), false, true)
	var role_w := (Data.font_bold if Data.font_bold else ThemeDB.fallback_font).get_string_size(_comms_speaker.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	_text(Vector2(x + role_w + 10, r.position.y + 44), info["role"], 12, Color(col.r, col.g, col.b, 0.85 * a))
	var shown := _comms_text.substr(0, int(_comms_age * 55.0))
	draw_multiline_string(ThemeDB.fallback_font, Vector2(x, r.position.y + 70), shown, HORIZONTAL_ALIGNMENT_LEFT, body_w, 17, -1, Color(UIStyle.TEXT.r, UIStyle.TEXT.g, UIStyle.TEXT.b, a))
