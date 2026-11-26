extends Control

const Neon = preload("res://scripts/neon.gd")
const Keys = preload("res://scripts/keys.gd")
## Heads-up display: flagship status, fleet roster, combat indicator, target
## brackets, off-screen enemy arrows, radar, and messages.

var main: Node
var show_help := false
var _comms_speaker := ""
var _comms_text := ""
var _comms_t := 0.0
var _comms_queue: Array = []
var _comms_age := 0.0
var _comms_words := 0      ## words typed in so far (one key tick each)
var comms_top := 0.0      ## top edge of the comms panel this frame (cards stack above it)
var comms_rect := Rect2()  ## the comms panel on screen, for clicks
var comms_links: Array = []  ## highlighted words in the comms panel: [Rect2, kind, phrase]
var _plate_k := 1.0        ## nav plate: 1 full, 0 tucked away
var _plate_wake := 0.0     ## seconds since the plate last had news
var _plate_sig := ""
var _slip_k := 1.0
var _slip_wake := 0.0
var _slip_sig := ""
var _tick: Array = []      ## chatter line on the ticker: [speaker, text]
var _tick_t := 0.0
var _tick_queue: Array = []
var _comms_hold := false   ## this line waits for you (Space, Enter or a click)

const TALK_SIZE := 24       ## VT323 runs small
const COL_SHIELD := Color(0.35, 0.7, 1.0)
const COL_HULL := Color(0.95, 0.75, 0.3)
const COL_ENEMY := Color(1.0, 0.4, 0.3)
const COL_FRIEND := Color(0.4, 0.9, 1.0)
const COL_NEUTRAL := Color(0.86, 0.84, 0.76)
const COL_ENERGY := Color(0.75, 0.55, 1.0)


# --- First-flight prompts ---------------------------------------------------------
## Each shows once per career, when it's useful, and clears once you've done it.
## Keys are action names ("@thrust_forward") or fixed text ("MOUSE"); "@" reads the live bind.
const TIPS := {
	"fly": [["@thrust_forward", "thrust"], ["MOUSE", "steer"], ["@brake", "brake"]],
	"travel": [["@autopilot", "autopilot to the job"], ["@chart", "chart"], ["@journal", "journal"]],
	"guns": [["@fire_aimed", "turrets"], ["@fire_secondary", "ion / torpedo"], ["@swap_secondary", "swap"]],
	"tactics": [["HOLD @tactics", "fleet orders"]],
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
			return main.autopilot_on() or _tip_t > 30.0
		"guns":
			return (_tip_t > 5.0 and (p.in_fire_aimed or p.in_fire_fixed)) or _tip_t > 16.0 or not main.in_combat
		"tactics":
			return main.wheel_open() or _tip_t > 14.0
	return true


## Key caps in a row, centred under the ship: [KEY] what it does.
func _draw_tip(vp: Vector2) -> void:
	if _tip_a <= 0.01 or not TIPS.has(tip if tip != "" else "fly"):
		return
	var segs: Array = []
	for sg in TIPS.get(tip, []):
		var cap: String = sg[0]
		var at := cap.find("@")
		if at >= 0:
			cap = cap.substr(0, at) + Keys.key_name(cap.substr(at + 1)).to_upper()
		segs.append([cap, sg[1]])
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
	if not (_comms_hold and _comms_t > 0.0):
		_comms_t = maxf(0.0, _comms_t - delta)
	_comms_age += delta
	_type_sounds()
	if _comms_t <= 0.0 and not _comms_queue.is_empty() and not _quiet():
		var next: Array = _comms_queue.pop_front()
		_show_comms(next[0], next[1])
	_quiet_step(delta)
	# The ticker: everyday chatter scrolls by and doesn't wait for you.
	_tick_t = maxf(0.0, _tick_t - delta)
	if _tick_t <= 0.0 and not _tick_queue.is_empty() and not _quiet():
		_tick = _tick_queue.pop_front()
		_tick_t = 4.0 + str(_tick[1]).length() * 0.045
	queue_redraw()


## Quiet by default: panels speak up when something changes, then tuck
## away. In a fight the trade panels go and the fleet takes their place.
func _quiet_step(delta: float) -> void:
	if not main.merchant:
		return
	var sig := "%s|%d|%d|%d" % [main.system_id, Career.credits, Career.cargo_used(), Career.loan_balance]
	if sig != _plate_sig or main.docked_at != "":
		_plate_sig = sig
		_plate_wake = 0.0
	var osig := str(Career.objective.get("text", ""))
	if osig != _slip_sig or main.docked_at != "":
		_slip_sig = osig
		_slip_wake = 0.0
	_plate_wake += delta
	_slip_wake += delta
	var mp := get_local_mouse_position()
	var peek := mp.y < 140.0 and mp.y >= 0.0
	var fight: bool = main.in_combat
	var want_plate := 0.0 if fight else (1.0 if _plate_wake < 8.0 or peek else 0.0)
	var want_slip := 0.0 if fight else (1.0 if _slip_wake < 10.0 or peek else 0.0)
	_plate_k = move_toward(_plate_k, want_plate, delta * 3.0)
	_slip_k = move_toward(_slip_k, want_slip, delta * 3.0)


## Nobody talks during an engagement. Scripted scenes are the exception:
## they stage their own talk.
func _quiet() -> bool:
	return main.merchant and main.in_combat and not (main.story and main.story.busy())


## Comms messages from people (Charlie, dock crews). Shown in flight for a while.
## In flight, a line that arrives while another is showing waits its turn.
func on_comms(speaker: String, text: String) -> void:
	if Career.chatter_now:
		if main.docked_at == "":
			_tick_queue.append([speaker, text])
			while _tick_queue.size() > 3:
				_tick_queue.pop_front()
		return
	if main.docked_at != "":
		# Docked: the station's comms board shows it; don't replay it in flight.
		_comms_queue.clear()
		_comms_t = 0.0
		return
	if _comms_t > 0.0 or _quiet():
		if not hold_enabled():
			_comms_t = minf(_comms_t, 2.5)
		_comms_queue.append([speaker, text])
		return
	_show_comms(speaker, text)


## Lines wait for the player, except in scripted tests.
func hold_enabled() -> bool:
	return not main._merchant_test and DisplayServer.get_name() != "headless"


func _show_comms(speaker: String, text: String) -> void:
	_comms_speaker = speaker
	_comms_text = text
	_comms_hold = hold_enabled()
	_comms_t = maxf(6.0 + text.length() * 0.04, Neon.duration(Neon.parse(text)) + 3.0)
	_comms_age = 0.0
	_comms_words = 0


## A line is up, or waiting its turn.
func comms_waiting() -> bool:
	return (_comms_hold and _comms_t > 0.0) or not _comms_queue.is_empty()


func comms_showing() -> bool:
	return _comms_t > 0.0 and main.docked_at == ""


## Space / Enter / click: finish the line if it's still typing, else the next one.
func advance_comms() -> void:
	var dur := Neon.duration(Neon.parse(_comms_text))
	if _comms_age < dur:
		_comms_age = dur + 0.01
		_comms_words = 1 << 20
		return
	Sfx.play("tick", -12.0)
	if not _comms_queue.is_empty():
		var next: Array = _comms_queue.pop_front()
		_show_comms(next[0], next[1])
	else:
		_comms_hold = false
		_comms_t = minf(_comms_t, 0.35)


## The highlighted word under `at` in the comms panel that opens a journal
## page: [Rect2, kind, phrase], or [] if none.
func link_at(at: Vector2) -> Array:
	if _comms_t <= 0.0 or not comms_rect.has_point(at):
		return []
	for h in comms_links:
		if (h[0] as Rect2).grow(2).has_point(at) and not Neon.link(h[1], h[2]).is_empty():
			return h
	return []


## Story lines type in with a soft key tick per word; a threat word lands
## with a neon buzz. The ticker stays silent.
func _type_sounds() -> void:
	if _comms_t <= 0.0 or not _comms_hold or main.docked_at != "":
		return
	var np := Neon.parse(_comms_text)
	var n := Neon.words_at(np, _comms_age)
	if n <= _comms_words:
		return
	var pitch := 0.92 + float(absi(_comms_speaker.hash()) % 5) * 0.04
	for i in range(_comms_words, mini(n, np["words"].size())):
		if Neon.word_kind(np, i) == "threats":
			Sfx.play("neon", -14.0, randf_range(0.95, 1.05))
	Sfx.play("key", -20.0, pitch * randf_range(0.96, 1.04))
	_comms_words = n


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
	var fade := clampf((spd - 40.0) / 220.0, 0.0, 1.0)
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
		if is_instance_valid(main.player) and main.player.disabled:
			_text(Vector2(vp.x * 0.5, 42), "ENGINES DEAD", 24, Color(1.0, 0.45, 0.35), true)
			_text(Vector2(vp.x * 0.5, 64), "Adrift. Your wing is all you've got.", 14, Color(1.0, 0.8, 0.75), true)
		elif main.escorts.is_empty():
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
		var col := COL_FRIEND if ship.team == 0 else (COL_NEUTRAL if ship.team == 2 else COL_ENEMY)
		if ship.disabled:
			col = Color(0.75, 0.75, 0.7)
		var hov: bool = ship == main.ship_under_mouse() if main.merchant else false
		var onscreen := Rect2(Vector2.ZERO, vp).grow(-10).has_point(sp)
		if onscreen:
			var r: float = ship.radius * main.camera.zoom.x + 8.0
			_brackets(sp, r, Color(col.r, col.g, col.b, 0.9 if hov else (0.3 if ship.team == 2 else 0.55)))
			if hov or (ship.team == 2 and ship.controller is Traffic.Pilot and ship.controller.flee):
				_ship_tag(sp + Vector2(r * 1.5 + 14, -r * 0.6), ship, hov)
			var hw := roundf(r)
			if ship.team == 2 and not hov and ship.hull_hp >= ship.max_hull:
				continue
			if ship.max_shields > 0:
				_pips((sp + Vector2(-hw, r + 6)).round(), hw * 2.0, ship.shields / ship.max_shields, COL_SHIELD)
			_pips((sp + Vector2(-hw, r + 11)).round(), hw * 2.0, ship.hull_hp / ship.max_hull, COL_HULL)
			if ship.disabled:
				var blink := 0.6 + 0.4 * sin(t * 6.0)
				draw_string(Data.font_type_bold, (sp + Vector2(-hw, -r - 6)).round(), "DISABLED", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.95, 0.85, 0.5, blink))
		elif ship.team == 1 and not ship.disabled:
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
		var reg: String = (str(Career.pilot.get("rig", "")).to_upper() if str(Career.pilot.get("rig", "")) != "" else "CC-40817-M") if main.merchant else "FLAGSHIP"
		draw_string(Data.font_stamp, base + Vector2(18, 28), reg, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.86, 0.62, 0.18))
		var reg_w := Data.font_stamp.get_string_size(reg, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		draw_string(Data.font_type, base + Vector2(maxf(132.0, 18.0 + reg_w + 14.0), 27), p.def["name"].to_upper(), HORIZONTAL_ALIGNMENT_LEFT, 300.0 - reg_w, 12, UIStyle.TEXT_DIM)
		var spd := "%03d m/s" % int(p.velocity.length())
		var sr := Rect2(base + Vector2(330, 11), Vector2(94, 22))
		draw_rect(sr, Color(0.03, 0.02, 0.01))
		draw_string(Data.font_type_bold, sr.position + Vector2(8, 16), spd, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1.0, 0.6, 0.2))
		if main.merchant and main.edge and (main.edge.outside or main.edge.reserve < 1.0):
			# Reserve tank: only out past the beacons does it matter.
			var ek: float = main.edge.reserve
			var ec := UIStyle.GREEN if ek > 0.5 else (UIStyle.GOLD if ek > 0.25 else UIStyle.RED)
			if ek <= 0.0:
				ec = Color(UIStyle.RED, 0.5 + 0.5 * sin(t * 8.0))
			draw_rect(Rect2(sr.position + Vector2(0, 25), Vector2(94, 4)), Color(0.05, 0.05, 0.05))
			draw_rect(Rect2(sr.position + Vector2(0, 25), Vector2(94 * ek, 4)), ec)
			_text(base + Vector2(286, 27), "DRY" if ek <= 0.0 else "RESERVE", 11, ec, true, true)
		elif p.in_brake:
			_text(base + Vector2(290, 27), "BRAKE", 12, UIStyle.GOLD, true, true)
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
	if not live.is_empty() and (not main.merchant or main.in_combat or main.wheel_open()):
		var ry := 16.0 if main.merchant else 128.0
		var rr := Rect2(Vector2(16, ry), Vector2(410, 48 + live.size() * 26))
		UIStyle.draw_glass(self, rr, 1.0, 10.0)
		_text(rr.position + Vector2(14, 22), _sp("FLEET") + "   ·   %s  ·  %s" % [_order_name(main.fleet_order), main.formation.capitalize()], 11, UIStyle.KICKER)
		var y := rr.position.y + 50
		for e in live:
			var nm: String = e.display_name if e.display_name != "" else e.def["name"]
			_text(Vector2(rr.position.x + 14, y), nm, 14, UIStyle.GOLD if e.is_friend else UIStyle.TEXT)
			# What this pilot is actually doing, and whether they've caught up with your order.
			var st := _escort_state(e)
			_text(Vector2(rr.position.x + 196, y), st[0], 11, st[1])
			_bar(Rect2(Vector2(rr.position.x + 300, y - 11), Vector2(94, 4)), e.shields / e.max_shields, COL_SHIELD)
			_bar(Rect2(Vector2(rr.position.x + 300, y - 5), Vector2(94, 4)), e.hull_hp / e.max_hull, COL_HULL)
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
		var K := func(a: String) -> String: return Keys.key_name(a)
		var lines := ["%s / %s   forward / back" % [K.call("thrust_forward"), K.call("thrust_back")], "%s / %s   strafe" % [K.call("strafe_left"), K.call("strafe_right")],
			"Mouse   steer", "%s / %s   turn" % [K.call("turn_left"), K.call("turn_right")], "%s   flight assist on/off" % K.call("assist"), "%s   brake" % K.call("brake"),
			"%s   dock / jump" % K.call("interact"), "Mouse   aim turrets", "%s   fire turrets" % K.call("fire_aimed"), "%s   forward guns" % K.call("fire_fixed"),
			"Space / Enter   next comms line", "%s   fire secondary" % K.call("fire_secondary"), "%s   swap secondary" % K.call("swap_secondary"),
			"%s   autopilot to the job" % K.call("autopilot"), "%s   hail the ship under the cursor" % K.call("hail"), "%s (hold)   tactics wheel" % K.call("tactics"),
			"%s   attack target under cursor" % K.call("target"), "%s   sector chart" % K.call("chart"), "%s   journal" % K.call("journal"), "Wheel   zoom", "Esc   pause",
			"%s   hide controls  ·  rebind in Settings" % K.call("toggle_help")]
		var hr := Rect2(Vector2(vp.x - 300, 130), Vector2(284, 50 + lines.size() * 22))
		UIStyle.draw_glass(self, hr, 1.0, 10.0)
		_text(hr.position + Vector2(14, 24), _sp("CONTROLS"), 11, UIStyle.KICKER)
		for i in lines.size():
			_text(hr.position + Vector2(14, 52 + i * 22), lines[i], 14, UIStyle.TEXT)
	else:
		_text(Vector2(vp.x - 230, vp.y - 214), Keys.key_name("toggle_help") + "   controls", 13, Color(UIStyle.TEXT_DIM.r, UIStyle.TEXT_DIM.g, UIStyle.TEXT_DIM.b, 0.7))


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
	if main.merchant and main.edge:
		# Beacon range: the dashed edge, where it crosses the scope.
		var er: float = main.edge.radius
		for i in 180:
			if i % 2:
				continue
			var a0 := TAU * i / 180.0
			var q0 := (Vector2(cos(a0), sin(a0)) * er - origin) * scale
			var q1 := (Vector2(cos(a0 + TAU / 180.0), sin(a0 + TAU / 180.0)) * er - origin) * scale
			if q0.length() < r - 2 and q1.length() < r - 2:
				draw_line(center + q0, center + q1, Color(0.55, 0.8, 1.0, 0.55), 1.5)
	for s in get_tree().get_nodes_in_group("ships"):
		var ship := s as Ship
		if ship == null or not ship.alive:
			continue
		var rp := (ship.global_position - origin) * scale
		if rp.length() > r - 3:
			rp = rp.normalized() * (r - 3)
		var col := Color(0.55, 1.0, 0.65) if ship.team == 0 else (Color(0.75, 0.78, 0.72, 0.8) if ship.team == 2 else Color(1.0, 0.45, 0.3))
		if ship == main.player:
			col = Color(0.9, 1.0, 0.9)
		var d := 4.0 if ship.radius > 20 else 3.0
		draw_rect(Rect2((center + rp - Vector2(d, d) * 0.5).round(), Vector2(d, d)), col)


func _escort_state(e: Ship) -> Array:
	var c = e.controller
	if not (c is AIController):
		return ["", UIStyle.TEXT_DIM]
	if c.pending():
		match c.temper():
			"hesitant": return ["hesitating...", UIStyle.GOLD]
			"presses": return ["finishing it", UIStyle.RED]
		return ["...", UIStyle.TEXT_DIM]
	var verb := {"engage": "engaging", "focus": "on target", "screen": "screening", "bait": "engaging",
		"break": "forming on you", "hold": "holding"}
	var o: String = c.obeyed
	if o == "bait" and e == main.bait_ship:
		return ["BAITING", COL_ENEMY]
	return [verb.get(o, o), UIStyle.TEXT_DIM]


func _order_name(id: String) -> String:
	match id:
		"engage": return "Engage at will"
		"focus": return "Focus my target"
		"hold": return "Hold formation"
		"screen": return "Screen me"
		"bait": return "Bait"
		"break": return "Break off"
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
func _label_tape(at: Vector2, text: String, seed: int, base := Vector2.ZERO) -> void:
	var f: Font = Data.font_type_bold
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 20.0
	var tilt := (float(absi(seed) % 7) - 3.0) * 0.006
	draw_set_transform(base + at, tilt, Vector2.ONE)
	var r := Rect2(Vector2.ZERO, Vector2(w, 22))
	draw_rect(Rect2(r.position + Vector2(1, 2), r.size), Color(0, 0, 0, 0.5))
	draw_rect(r, Color(0.08, 0.08, 0.09))
	draw_rect(Rect2(Vector2(0, 0), Vector2(w, 1)), Color(0.25, 0.25, 0.27))
	# Cut ends.
	draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(3, 11), Vector2(0, 22)]), Color(0.075, 0.085, 0.095))
	draw_colored_polygon(PackedVector2Array([Vector2(w, 0), Vector2(w - 3, 11), Vector2(w, 22)]), Color(0.075, 0.085, 0.095))
	draw_string(f, Vector2(10, 16), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.93, 0.93, 0.9))
	draw_set_transform(base, 0.0, Vector2.ONE)


## The current job in neon (docs/design/ui-look.md): a dark wash at the top of
## the screen, the dispatch line typed in VT323 with its words lit.
func _draw_dispatch_slip(vp: Vector2, text: String, a := 1.0) -> void:
	var f: Font = Data.font_talk
	var np := Neon.parse(text)
	text = str(np["text"])
	var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	var w := maxf(tw, 300.0)
	var r := Rect2(Vector2(roundf(vp.x * 0.5 - w * 0.5), 70), Vector2(roundf(w), 56))
	# Soft dark wash, no box.
	for k in 10:
		var g := 40.0 - k * 4.0
		draw_rect(r.grow_individual(g, g * 0.4, g, g * 0.4), Color(0.016, 0.02, 0.047, 0.16 * a))
	var dim := Color(0.3, 0.31, 0.37, a)
	draw_string(f, r.position + Vector2(0, 16), "DISPATCH   CH 03", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, dim)
	draw_string(f, r.position + Vector2(0, 16), "JOB", HORIZONTAL_ALIGNMENT_RIGHT, r.size.x, 18, Color(UIStyle.GOLD, a))
	Neon.draw(self, f, r.position + Vector2(roundf((r.size.x - tw) * 0.5), 46 - f.get_ascent(24)), np, tw + 4.0, 24, Color(0.9, 0.9, 0.94), a, 1e9)


## Who a ship is: name, owner, what it's doing. Hovered ships say how to hail.
func _ship_tag(at: Vector2, ship: Ship, hov: bool) -> void:
	var name := ship.display_name if ship.display_name != "" else str(ship.def["name"])
	var owner: String = ship.info.get("owner", "")
	var job: String = ship.info.get("job", "")
	if ship.team == 2 and ship.controller is Traffic.Pilot and ship.controller.flee:
		job = "MAYDAY"
	var f: Font = Data.font_type_bold
	var fr: Font = Data.font_type
	var tw := maxf(f.get_string_size(name.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x, maxf(fr.get_string_size(owner, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x, fr.get_string_size(job, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x))
	draw_rect(Rect2(at + Vector2(-6, -14), Vector2(tw + 12, 22 + (13 if owner != "" else 0) + (13 if job != "" else 0) + (13 if hov and ship.team != 0 else 0))), Color(0.02, 0.03, 0.04, 0.72))
	draw_string(f, at.round(), name.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.95))
	var y := 14.0
	if owner != "":
		draw_string(fr, (at + Vector2(0, y)).round(), owner, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(COL_NEUTRAL, 0.85))
		y += 13.0
	if job != "":
		draw_string(fr, (at + Vector2(0, y)).round(), job, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, COL_ENEMY if job == "MAYDAY" else Color(COL_NEUTRAL, 0.7))
		y += 13.0
	if hov and ship.team != 0 and main.merchant:
		draw_string(fr, (at + Vector2(0, y)).round(), "[Y] hail", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UIStyle.GOLD)


## The lien in flight: the repo cutter, a customs scan, the repossession notice.
func _draw_debt(vp: Vector2) -> void:
	var d = main.debt
	if is_instance_valid(d.cutter) and d.cutter.alive:
		var sp := _to_screen(d.cutter.global_position)
		if Rect2(Vector2.ZERO, vp).has_point(sp):
			_ship_tag(sp + Vector2(d.cutter.radius * main.camera.zoom.x * 1.5, -10), d.cutter, false)
		_text(Vector2(vp.x * 0.5, 188), _sp("REPO CUTTER") + "   ·   pay the overdue at the Counter, or jump out", 13, COL_ENEMY, true, true)
	if not d.scan.is_empty() and is_instance_valid(d.scan["by"]):
		var by: Ship = d.scan["by"]
		var sp2 := _to_screen(by.global_position)
		var k: float = d.scan["k"]
		var amber := Color(1.0, 0.75, 0.3)
		draw_arc(sp2, by.radius * main.camera.zoom.x + 26.0, -PI * 0.5, -PI * 0.5 + TAU * k, 48, amber, 2.5)
		_text(Vector2(vp.x * 0.5, vp.y * 0.33), "CUSTOMS SCAN  ·  SEALED CRATES ABOARD", 15, amber, true, true)
		_bar(Rect2(Vector2(vp.x * 0.5 - 150, vp.y * 0.33 + 10), Vector2(300, 6)), k, amber)
	if not d.slip.is_empty():
		_draw_repo_slip(vp, d.slip)


## Charter Recovery's notice: what they took, and the fee on top.
func _draw_repo_slip(vp: Vector2, slip: Dictionary) -> void:
	var k := clampf(float(slip["t"]) / 0.4, 0.0, 1.0)
	var r := Rect2(Vector2(roundf(vp.x * 0.5 - 200), lerpf(-220.0, 140.0, 1.0 - pow(1.0 - k, 3.0))), Vector2(400, 210))
	draw_rect(Rect2(r.position + Vector2(5, 7), r.size), Color(0, 0, 0, 0.45))
	draw_rect(r, Color(0.93, 0.91, 0.85))
	draw_rect(Rect2(r.position, Vector2(r.size.x, 6)), UIStyle.INK_STAMP)
	var f: Font = Data.font_type
	var fb: Font = Data.font_type_bold
	draw_string(fb, r.position + Vector2(18, 30), "THE CHARTER COMPANY  ·  RECOVERY", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UIStyle.INK_FADED)
	draw_string(fb, r.position + Vector2(18, 58), "NOTICE OF REPOSSESSION", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, UIStyle.INK_TYPE)
	draw_string(f, r.position + Vector2(18, 84), "Cargo seized: %d t, all of it." % int(slip["seized"]), HORIZONTAL_ALIGNMENT_LEFT, 364, 12, UIStyle.INK_TYPE)
	draw_string(f, r.position + Vector2(18, 102), "Cash applied to overdue: %s cr." % Career.fmt(int(slip["took"])), HORIZONTAL_ALIGNMENT_LEFT, 364, 12, UIStyle.INK_TYPE)
	draw_string(f, r.position + Vector2(18, 120), "Rig released to owner-operator. Strikes cleared.", HORIZONTAL_ALIGNMENT_LEFT, 364, 12, UIStyle.INK_TYPE)
	draw_line(r.position + Vector2(18, 134), r.position + Vector2(382, 134), Color(UIStyle.INK_FADED, 0.5), 1.0)
	draw_string(fb, r.position + Vector2(18, 156), "RECOVERY FEE", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UIStyle.INK_TYPE)
	draw_string(fb, r.position + Vector2(140, 156), "%s cr" % Career.fmt(int(slip["fee"])), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UIStyle.INK_TYPE)
	if float(slip["t"]) > 0.9:
		var sk := clampf((float(slip["t"]) - 0.9) / 0.15, 0.0, 1.0)
		var sc := 1.6 - 0.6 * sk
		draw_set_transform(r.position + Vector2(285, 170), -0.16, Vector2(sc, sc))
		var stamp := "RECOVERED"
		var sw := Data.font_stamp.get_string_size(stamp, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
		draw_rect(Rect2(Vector2(-sw * 0.5 - 8, -26), Vector2(sw + 16, 34)), Color(UIStyle.INK_STAMP, 0.85 * sk), false, 2.5)
		draw_string(Data.font_stamp, Vector2(-sw * 0.5, 0), stamp, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(UIStyle.INK_STAMP, 0.85 * sk))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The tow slip: a Charter recovery chit, fee stamped onto the lien.
func _draw_tow_slip(vp: Vector2, slip: Dictionary) -> void:
	var k := clampf(float(slip["t"]) / 0.4, 0.0, 1.0)
	var r := Rect2(Vector2(roundf(vp.x * 0.5 - 190), lerpf(-200.0, 150.0, 1.0 - pow(1.0 - k, 3.0))), Vector2(380, 196))
	draw_rect(Rect2(r.position + Vector2(5, 7), r.size), Color(0, 0, 0, 0.45))
	draw_rect(r, Color(0.93, 0.91, 0.85))
	var f: Font = Data.font_type
	var fb: Font = Data.font_type_bold
	draw_string(fb, r.position + Vector2(18, 26), "THE CHARTER COMPANY  ·  RECOVERY", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UIStyle.INK_FADED)
	draw_string(fb, r.position + Vector2(18, 54), "TOW SLIP  No. %03d" % (40 + int(slip["n"])), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, UIStyle.INK_TYPE)
	var rig := str(Career.pilot.get("rig", "your rig"))
	draw_string(f, r.position + Vector2(18, 82), slip.get("what", "Recovery of rig \"%s\" from past beacon range." % rig), HORIZONTAL_ALIGNMENT_LEFT, 344, 12, UIStyle.INK_TYPE)
	draw_string(f, r.position + Vector2(18, 102), "Towed to nearest berth." if slip.has("what") else "Towed to nearest berth. Reserve refuelled.", HORIZONTAL_ALIGNMENT_LEFT, 344, 12, UIStyle.INK_TYPE)
	draw_line(r.position + Vector2(18, 116), r.position + Vector2(362, 116), Color(UIStyle.INK_FADED, 0.5), 1.0)
	draw_string(fb, r.position + Vector2(18, 138), "FEE", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UIStyle.INK_TYPE)
	draw_string(fb, r.position + Vector2(90, 138), "%s cr" % Career.fmt(int(slip["fee"])), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UIStyle.INK_TYPE)
	if float(slip["t"]) > 0.9:
		var sk := clampf((float(slip["t"]) - 0.9) / 0.15, 0.0, 1.0)
		var sc := 1.6 - 0.6 * sk
		draw_set_transform(r.position + Vector2(260, 150), -0.18, Vector2(sc, sc))
		var stamp := "ADDED TO LIEN"
		var sw := Data.font_stamp.get_string_size(stamp, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		draw_rect(Rect2(Vector2(-sw * 0.5 - 8, -24), Vector2(sw + 16, 32)), Color(UIStyle.INK_STAMP, 0.85 * sk), false, 2.5)
		draw_string(Data.font_stamp, Vector2(-sw * 0.5, 0), stamp, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(UIStyle.INK_STAMP, 0.85 * sk))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if int(slip["n"]) >= 3 and float(slip["t"]) > 1.6 and Data.font_hand:
		draw_string(Data.font_hand, r.position + Vector2(18, 182), "3rd tow. see me.  - R. Pruitt, Supv.", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, UIStyle.INK_PEN)


func _draw_merchant(vp: Vector2, t: float) -> void:
	var sys: Dictionary = Data.systems.get(main.system_id, Data.crossroads)
	# The rig's nav plate: security tag, stencilled system name, and the
	# nickname spacers use, punched on label tape and stuck on crooked.
	var pk := 1.0 - pow(1.0 - _plate_k, 3.0)
	if _plate_k < 0.98 and not main.in_combat:
		# Tucked away: one quiet line where the plate was.
		var line := "%s  ·  %s  ·  %s cr" % [sys["name"].to_upper(), sys["security"].to_upper(), Career.fmt(Career.credits)]
		if Career.strikes > 0:
			line += "  ·  STRIKE %d/2" % Career.strikes
		var la := 1.0 - pk
		draw_rect(Rect2(Vector2(16, 12), Vector2(Data.font_type_bold.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 24, 22)), Color(0.02, 0.03, 0.04, 0.6 * la))
		draw_string(Data.font_type_bold, Vector2(28, 27), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(UIStyle.TEXT_DIM, la))
	var lift := Vector2(0, -(1.0 - pk) * 140.0)
	draw_set_transform(lift, 0.0, Vector2.ONE)
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
	_label_tape(Vector2(nick_x, 58), sys["nick"].to_upper(), sys["name"].hash(), lift)
	var loan := "Loan paid off" if Career.loan_balance <= 0 else "Loan %s · %s due day %d" % [Career.fmt(Career.loan_balance), Career.fmt(mini(Data.LOAN_WEEKLY, Career.loan_balance)), int(Career.next_payment_day) + 1]
	if Career.strikes > 0:
		loan = "Loan %s · OVERDUE %s · STRIKE %d/2" % [Career.fmt(Career.loan_balance), Career.fmt(Career.arrears), Career.strikes]
	draw_line(Vector2(30, 90), Vector2(plate.end.x - 14, 90), Color(0.22, 0.24, 0.26), 1.0)
	_text(Vector2(32, 112), "%s cr" % Career.fmt(Career.credits), 15, UIStyle.TEXT, false, true)
	_text(Vector2(140, 112), "Hold %d/%d t" % [Career.cargo_used(), Career.cargo_capacity], 15, UIStyle.TEXT)
	_text(Vector2(262, 112), loan, 15, UIStyle.RED if Career.loan_balance > 0 else UIStyle.GREEN)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Every station and jump in the system, named at the screen edge, so you
	# always know where home is. The job's stop gets the bright arrow below.
	if main.merchant and is_instance_valid(main.player) and main.docked_at == "":
		_draw_nav_pips(vp)

	# Objective line and a marker toward where to go next. The full slip
	# fades when nothing changes; a short line stays pinned (playtest 11-26).
	var fight: bool = main.in_combat
	if not Career.objective.is_empty():
		var ot: String = Career.objective["text"]
		var sk := 1.0 - pow(1.0 - _slip_k, 3.0)
		if sk > 0.01:
			_draw_dispatch_slip(vp, ot, sk)
		if sk < 0.99 and not fight:
			_pinned_line(vp, "JOB", str(Neon.parse(ot)["text"]), 1.0 - sk)
		var target: Node2D = main.objective_target()
		if target and is_instance_valid(main.player):
			var sp := _to_screen(target.global_position)
			var col := Color(0.5, 1.0, 0.6, 0.85)
			var dist := int(main.player.global_position.distance_to(target.global_position))
			var name := _stop_name(target)
			var hint := "" if fight or main.autopilot_on() else "[%s] autopilot" % Keys.key_name("autopilot")
			if Rect2(Vector2.ZERO, vp).grow(-40).has_point(sp):
				_brackets(sp, 62.0 + 4.0 * sin(t * 4.0), col, 2.5)
				_text(sp + Vector2(0, 86), name, 14, col, true, true)
			else:
				# Ride the edge of the clear middle, inside the HUD panels.
				var edge := _lane_edge(vp, sp)
				var dir := (sp - _nav_lane(vp).get_center()).normalized()
				draw_colored_polygon(PackedVector2Array([edge + dir * 18, edge + dir.rotated(2.5) * 13, edge + dir.rotated(-2.5) * 13]), col)
				var lp := edge - dir * 34
				_text(lp + Vector2(0, -4), name, 14, col, true, true)
				_text(lp + Vector2(0, 12), "%s km" % _km(dist), 13, col, true)
				if hint != "":
					_text(lp + Vector2(0, 27), hint, 12, UIStyle.GOLD, true)
	elif main.merchant and main.docked_at == "" and not fight and not (main.story and main.story.scene in ["ambush", "ending"]):
		_pinned_line(vp, "TRADE", _trade_hint(), 1.0)

	if main.edge and not main.edge.slip.is_empty():
		_draw_tow_slip(vp, main.edge.slip)
	if main.debt:
		_draw_debt(vp)

	# What F does right now. Not while the launch card is up: you've only just left the berth.
	var b: Node2D = main.nearby_interactable()
	if b and is_instance_valid(main.player) and not main.launch_card:
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
		_text(Vector2(vp.x * 0.5, vp.y * 0.7), "RESERVE DRY  ·  ENGINES STARVED" if main.merchant and main.edge and main.edge.reserve <= 0.0 else "ENGINES DOWN  ·  ION DAMAGE", 18, Color(0.78, 0.62, 1.0, pulse), true, true)
	if main.jump_charge >= 0.0:
		var frac: float = main.jump_charge / main.JUMP_CHARGE
		_text(Vector2(vp.x * 0.5, vp.y * 0.66), "JUMP DRIVE CHARGING", 16, Color(0.75, 0.6, 1.0), true)
		_bar(Rect2(Vector2(vp.x * 0.5 - 150, vp.y * 0.67), Vector2(300, 8)), frac, Color(0.65, 0.5, 1.0))

	# Comms: a radio feed. Channel and file number in print, the speaker's ID
	# photo, and the words coming in a letter at a time over the static.
	comms_top = vp.y - 192.0
	if _comms_t > 0.0 and not main.docked_at:
		_draw_comms(vp)
	if _tick_t > 0.0 and not main.docked_at and not _tick.is_empty():
		_draw_ticker(vp)


## One line of chatter, low on the left: who, then what. Fades on its own.
func _draw_ticker(vp: Vector2) -> void:
	var a := clampf(_tick_t / 0.6, 0.0, 1.0) * clampf((4.0 + str(_tick[1]).length() * 0.045 - _tick_t) / 0.25, 0.0, 1.0)
	var who := str(_tick[0])
	var info: Dictionary = Data.speaker_info(who)
	var col: Color = info["color"]
	if str(_tick[1]).begins_with("Mayday"):
		col = COL_ENEMY
	var y := (comms_top - 18.0) if _comms_t > 0.0 else vp.y - 34.0
	var fb: Font = Data.font_type_bold
	var f: Font = Data.font_talk if Data.font_talk else Data.font_type
	var ww := fb.get_string_size(who.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	var text := str(_tick[1])
	# Stay clear of the ship panel in the middle; long lines wrap to two.
	var cap := minf(620.0, vp.x * 0.5 - 250.0 - 40.0 - ww)
	var np := Neon.parse(text)
	text = str(np["text"])
	var full := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x
	var tw := minf(full, cap)
	var lines := 1 if full <= cap else 2
	var h := 24.0 + 20.0 * (lines - 1)
	y -= 20.0 * (lines - 1)
	draw_rect(Rect2(Vector2(16, y - 17), Vector2(ww + tw + 36, h)), Color(0.02, 0.035, 0.045, 0.78 * a))
	draw_rect(Rect2(Vector2(16, y - 17), Vector2(3, h)), Color(col, a))
	draw_string(fb, Vector2(28, y), who.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(col, a))
	Neon.draw(self, f, Vector2(28 + ww + 12, y - f.get_ascent(19) + 1), np, tw + 12.0, 19, Data.TALK_BODY.lightened(0.1), a, 1e9, false, 2)


func _draw_comms(vp: Vector2) -> void:
	var a := minf(1.0, _comms_t)
	var info: Dictionary = Data.speaker_info(_comms_speaker)
	var col: Color = info["color"]
	# The panel grows upward to fit the whole line.
	var body_w := 560.0 - 110.0 - 16.0
	var np := Neon.parse(_comms_text)
	var tf22: Font = Data.font_talk if Data.font_talk else ThemeDB.fallback_font
	var text_h := Neon.height(tf22, np, body_w, TALK_SIZE)
	var h := maxf(152.0, 70.0 + text_h + 18.0)
	var r := Rect2(Vector2(16, vp.y - 20 - h), Vector2(560, h))
	comms_top = r.position.y
	comms_rect = r
	draw_rect(r, Color(0.02, 0.035, 0.045, 0.92 * a))
	draw_rect(r, Color(col.r, col.g, col.b, 0.35 * a), false, 1.0)
	# Channel strip across the top.
	draw_rect(Rect2(r.position, Vector2(r.size.x, 20)), Color(col.r, col.g, col.b, 0.16 * a))
	var tf: Font = Data.font_type_bold if Data.font_type_bold else ThemeDB.fallback_font
	draw_string(tf, r.position + Vector2(10, 15), info["channel"], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(col.r, col.g, col.b, a))
	# Signal meter: bars that flicker while the line is still coming in.
	var typing := _comms_age < Neon.duration(np)
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
	# What to press, and how many lines are waiting.
	if _comms_hold:
		var more := _comms_queue.size()
		var hint := ("SPACE  ▸  next (%d more)" % more) if more > 0 else "SPACE  ▸  close"
		if typing:
			hint = "SPACE  ▸  skip"
		var hf: Font = Data.font_type_bold if Data.font_type_bold else ThemeDB.fallback_font
		var hw := hf.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		var blink := 0.55 + 0.45 * absf(sin(_comms_age * 3.0))
		draw_string(hf, Vector2(r.end.x - hw - 12, r.end.y - 10), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(col.r, col.g, col.b, blink * a))
	comms_links.clear()
	Neon.draw(self, tf22, Vector2(x, r.position.y + 70 - tf22.get_ascent(TALK_SIZE)), np, body_w, TALK_SIZE, Data.TALK_BODY, a, _comms_age, false, -1, comms_links)
	# Highlighted words are links into the journal: underline the one under the mouse.
	var hov := link_at(get_local_mouse_position())
	if not hov.is_empty():
		var hr: Rect2 = hov[0]
		draw_line(Vector2(hr.position.x, hr.end.y - 2), Vector2(hr.end.x, hr.end.y - 2), Color(Neon.color(hov[1]), 0.8 * a), 1.0)


## The clear middle of the screen that edge markers ride, inside the HUD panels.
func _nav_lane(vp: Vector2) -> Rect2:
	return Rect2(Vector2(60, 150), vp - Vector2(120, 150 + 240))


## Where a line from the middle toward an off-screen point meets the lane edge.
func _lane_edge(vp: Vector2, sp: Vector2) -> Vector2:
	var lane := _nav_lane(vp)
	var center := lane.get_center()
	var dir := (sp - center).normalized()
	return center + dir * minf(absf(lane.size.x * 0.5 / dir.x) if dir.x != 0 else 1e9, absf(lane.size.y * 0.5 / dir.y) if dir.y != 0 else 1e9)


func _stop_name(b: Node2D) -> String:
	var n: String = b.label if b.label != "" else b.id
	return n.replace("Jump point: ", "JUMP  ").to_upper()


## No job: say what's in the hold and where it sells, or how trading works.
func _trade_hint() -> String:
	var best := ""
	var tons := 0
	for g in Career.cargo:
		if int(Career.cargo[g]) > tons:
			tons = int(Career.cargo[g])
			best = g
	if best == "":
		return "Hold's empty. Buy what a station makes, sell where it's needed."
	var where: Array = []
	for sid in Data.stations:
		if best in Data.stations[sid].get("wants", []):
			where.append(Data.stations[sid]["nick"])
	var gname: String = Data.goods[best]["name"].to_lower()
	if where.is_empty():
		return "%d t %s in the hold." % [tons, gname]
	return "%d t %s in the hold. Needed at %s." % [tons, gname, ", ".join(where.slice(0, 3))]


func _km(d: int) -> String:
	return "%.1f" % (d / 1000.0) if d < 10000 else "%d" % (d / 1000)


## A short job line that stays up after the full dispatch slip fades.
func _pinned_line(vp: Vector2, tag: String, text: String, a: float) -> void:
	var f: Font = Data.font_talk
	var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	var gw := f.get_string_size(tag + "   ", HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	var x := roundf(vp.x * 0.5 - (tw + gw) * 0.5)
	for k in 6:
		var g := 24.0 - k * 4.0
		draw_rect(Rect2(x - g, 70 - g * 0.4, tw + gw + g * 2.0, 30 + g * 0.8), Color(0.016, 0.02, 0.047, 0.14 * a))
	draw_string(f, Vector2(x, 92), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(UIStyle.GOLD, a))
	draw_string(f, Vector2(x + gw, 92), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.9, 0.9, 0.94, a * 0.9))


## Off-screen stations and jumps: a small mark and the name at the edge.
func _draw_nav_pips(vp: Vector2) -> void:
	var target: Node2D = main.objective_target()
	var col := Color(COL_NEUTRAL, 0.75)
	for b in main.bodies:
		if not is_instance_valid(b) or b == target or not (b.kind == "station" or b.kind == "jump"):
			continue
		var sp := _to_screen(b.global_position)
		if Rect2(Vector2.ZERO, vp).grow(-40).has_point(sp):
			continue
		var edge := _lane_edge(vp, sp)
		var dir := (sp - _nav_lane(vp).get_center()).normalized()
		draw_colored_polygon(PackedVector2Array([edge + dir * 7, edge + dir.rotated(PI * 0.5) * 5, edge - dir * 5, edge + dir.rotated(-PI * 0.5) * 5]), col)
		var nm := _stop_name(b)
		var half := ThemeDB.fallback_font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x * 0.5 + 8.0
		var lp := edge - dir * 22 + Vector2(0, 4)
		lp.x = clampf(lp.x, half, vp.x - half)
		_text(lp, nm, 12, col, true)
