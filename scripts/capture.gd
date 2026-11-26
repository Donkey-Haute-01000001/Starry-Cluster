extends Control
## Losing (docs/design/losing.md, signed 2026-11-25). Your rig is beaten: it
## goes dead in space. If your escorts drive them off, the Charter tows you in.
## If not, the raider comes alongside and you choose: open the airlock, or
## fight the breach. Open it and you're held three days, robbed, and ransomed
## onto your lien. Fight and lose, and that's the end: load your last dock.
## The Tallyman takes nothing. He counts, and leaves.

const BoardingScript := preload("res://scripts/boarding.gd")
const Neon = preload("res://scripts/neon.gd")

const DRIFT_TIME := 3.0       ## seconds dead in space before anyone comes alongside
const ALONGSIDE := 320.0
const CARD_TIME := 10.0       ## game seconds (half speed) to choose; silence = you open the lock
const SCAN := 3200.0
const BOARDERS := 3
const HOLD_BONUS := 1.5       ## defending your own corridors

var main: Node
var phase := ""               ## "", adrift, card, breach, held, towing, taken, dead
var captor: Ship = null
var _t := 0.0
var _card: VBoxContainer
var _bar: ColorRect
var _base_scale := 1.0
var _breach: Node = null
var _receipt := {}
var _black := 0.0
var _clangs := 0
var _ticks := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func busy() -> bool:
	return phase != ""


func _process(delta: float) -> void:
	var p: Ship = main.player
	if phase == "":
		if is_instance_valid(p) and p.alive and p.disabled and main.docked_at == "":
			_begin()
		return
	_t += delta
	match phase:
		"adrift":
			_adrift(p)
		"card":
			var left := 1.0 - _t / CARD_TIME
			if _bar:
				_bar.size.x = 420.0 * clampf(left, 0.0, 1.0)
			if _card:
				_card.position.y = main.hud.comms_top - 12.0 - _card.size.y
			if left <= 0.0:
				_choose(0)
			elif not _valid(captor):
				_close_card()
				phase = "adrift"
				_t = 0.0
		"breach":
			# Their ship blew or broke off mid-breach: nobody left to take you.
			if not is_instance_valid(_breach):
				phase = "held"
				_t = 0.0
		"held":
			if _t > 3.0:
				_release_captor()
				_tow("Recovery of rig \"%s\", dead in space, boarders repelled." % _rig())
		"towing":
			if main.docked_at != "" or (is_instance_valid(p) and not p.disabled):
				_done()
		"taken":
			_taken_step(delta)
		"dead":
			# Let OVERRUN land, then the black.
			if _t > 1.8:
				_black = minf(1.0, _black + delta * 1.5)
			if _black > 0.4 and is_instance_valid(_breach):
				_breach.queue_free()
	queue_redraw()


func _begin() -> void:
	phase = "adrift"
	_t = 0.0
	captor = null
	main.jump_charge = -1.0
	main.autopilot_off("")
	main.show_message("ENGINES DEAD  ·  ADRIFT", 3.0)


## Dead in space. Somebody's coming: them, or the tow.
func _adrift(p: Ship) -> void:
	if not is_instance_valid(p) or not p.disabled:
		_done()
		return
	# Charter Recovery handles its own (debt.gd): seize, fee, tow.
	if is_instance_valid(main.debt.cutter) and main.debt.cutter.alive:
		return
	if not _valid(captor):
		captor = _nearest_raider(p)
		if captor:
			captor.controller = Alongside.new(captor, main)
	if captor == null:
		# Nobody left to take you: your wing drove them off, or they never came.
		if _t > DRIFT_TIME:
			_tow("Recovery of rig \"%s\", dead in space." % _rig())
		return
	if _t > DRIFT_TIME and captor.global_position.distance_to(p.global_position) < ALONGSIDE:
		if captor in main.story._tally:
			_tallyman()
		else:
			_show_card()


func _nearest_raider(p: Ship) -> Ship:
	var best: Ship = null
	var bd := SCAN
	for s in get_tree().get_nodes_in_group("ships"):
		var sh := s as Ship
		if _valid(sh) and sh.team == 1:
			var d := sh.global_position.distance_to(p.global_position)
			if d < bd:
				bd = d
				best = sh
	return best


func _valid(s) -> bool:
	return is_instance_valid(s) and s.alive and not s.disabled


## He looks, he marks, he goes. No take, no ransom: just the tow.
func _tallyman() -> void:
	main.show_message(Data.capture["tally"], 5.0)
	for s in main.story._tally:
		if is_instance_valid(s) and s.alive:
			s.controller = Traffic.Leaving.new(s, main)
			s.team = 2
	captor = null
	_tow("Recovery of rig \"%s\", dead in space." % _rig())


func _tow(what: String) -> void:
	phase = "towing"
	_t = 0.0
	main.edge.bill_tow(what)


# --- The choice ---------------------------------------------------------------

func _show_card() -> void:
	phase = "card"
	_t = 0.0
	_base_scale = Engine.time_scale
	Engine.time_scale = _base_scale * 0.5
	_card = VBoxContainer.new()
	_card.add_theme_constant_override("separation", 6)
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_card.position = Vector2(24, vp.y - 380)
	get_parent().add_child(_card)
	var head := Label.new()
	head.text = "BOARDED  ·  %s ALONGSIDE" % _name(captor).to_upper()
	head.add_theme_font_override("font", Data.font_type_bold)
	head.add_theme_font_size_override("font_size", 12)
	head.add_theme_color_override("font_color", UIStyle.RED)
	_card.add_child(head)
	var hail := Label.new()
	hail.text = Data.capture["hail"]
	hail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hail.custom_minimum_size = Vector2(420, 0)
	if Data.font_talk:
		hail.add_theme_font_override("font", Data.font_talk)
	hail.add_theme_font_size_override("font_size", 20)
	hail.add_theme_color_override("font_color", Color(0.92, 0.88, 0.78))
	_card.add_child(hail)
	var odds: float = BoardingScript.win_odds(_your_side(), BOARDERS, HOLD_BONUS, 1.0)
	var rows := [
		[Data.capture["surrender"], "Held %d days. Cargo and cash gone. Ransom on the lien." % Data.HELD_DAYS],
		[Data.capture["fight"], "%d of yours vs %d boarders  ·  %d%%. Lose and it's over." % [_your_side(), BOARDERS, roundi(odds * 100.0)]],
	]
	for i in rows.size():
		var b := Button.new()
		b.text = "[%d]  %s\n       %s" % [i + 1, rows[i][0], rows[i][1]]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(420, 52)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_override("font", Data.font_type)
		b.add_theme_font_size_override("font_size", 16)
		for st in ["normal", "hover", "pressed"]:
			var box := StyleBoxFlat.new()
			box.bg_color = Color(0.06, 0.065, 0.07, 0.94) if st == "normal" else Color(0.13, 0.07, 0.06, 0.96)
			box.border_color = UIStyle.RED.darkened(0.35 if st == "normal" else 0.0)
			box.border_width_left = 4
			box.border_width_bottom = 2
			box.content_margin_left = 14
			box.content_margin_right = 16
			box.content_margin_top = 6
			box.content_margin_bottom = 6
			b.add_theme_stylebox_override(st, box)
		b.add_theme_color_override("font_color", Color(0.92, 0.88, 0.78))
		b.add_theme_color_override("font_hover_color", UIStyle.RED)
		b.pressed.connect(_choose.bind(i))
		_card.add_child(b)
	var track := ColorRect.new()
	track.color = Color(0.1, 0.1, 0.1, 0.8)
	track.custom_minimum_size = Vector2(420, 4)
	_card.add_child(track)
	_bar = ColorRect.new()
	_bar.color = UIStyle.RED
	_bar.size = Vector2(420, 4)
	track.add_child(_bar)
	Sfx.play("disabled", -8.0)


## You, plus any of Kessler's marines still aboard.
func _your_side() -> int:
	return 1 + int(Career.flags.get("marines", 0))


func _unhandled_input(event: InputEvent) -> void:
	if phase == "card" and event is InputEventKey and event.pressed and not event.echo:
		var i: int = event.keycode - KEY_1
		if i >= 0 and i < 2:
			get_viewport().set_input_as_handled()
			_choose(i)
	elif phase == "taken" and _receipt.has("shown") and _t > _receipt["shown"] + 1.5 and event is InputEventKey and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		_wake()
	elif phase == "dead" and _black >= 1.0 and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			get_viewport().set_input_as_handled()
			_load_last_dock()
		elif event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			Engine.time_scale = 1.0
			get_tree().change_scene_to_file("res://scenes/start.tscn")


func _close_card() -> void:
	if _card:
		_card.queue_free()
		_card = null
	Engine.time_scale = _base_scale


func _choose(i: int) -> void:
	if phase != "card":
		return
	_close_card()
	Sfx.play("stamp", -4.0, 0.8)
	if i == 0:
		phase = "taken"
		_t = 0.0
		_clangs = 0
		_ticks = 0
		_black = 0.0
		_receipt = {}
	else:
		_fight()


# --- Fight the breach -----------------------------------------------------------

func _fight() -> void:
	phase = "breach"
	_t = 0.0
	_breach = BoardingScript.new()
	_breach.main = main
	_breach.target = captor
	_breach.defending = true
	_breach.marines = _your_side()
	_breach.defenders = BOARDERS
	_breach.plans = [{"id": "hold", "name": "Hold the lock", "note": "", "atk": HOLD_BONUS, "def": 1.0, "share": 0.0}]
	_breach.finished.connect(_breach_over)
	get_parent().add_child(_breach)
	_breach.pick(0)


func _breach_over(won: bool, _plan: Dictionary, left: int) -> void:
	if Career.flags.get("marines", 0) > 0:
		Career.flags["marines"] = maxi(0, left - 1)
	_t = 0.0
	if won:
		phase = "held"
		main.show_message(Data.capture["held"], 4.0)
	else:
		phase = "dead"
		_black = 0.0


func _release_captor() -> void:
	for s in get_tree().get_nodes_in_group("ships"):
		var sh := s as Ship
		if sh and sh.alive and sh.team == 1 and is_instance_valid(main.player) and sh.global_position.distance_to(main.player.global_position) < SCAN:
			sh.controller = Traffic.Leaving.new(sh, main)
			sh.team = 2
	captor = null


func _load_last_dock() -> void:
	Engine.time_scale = 1.0
	# This career's own file, not just the latest one (saves.md: one file per career).
	if Career.slot >= 0 and Career.load_game(Career.slot):
		Data.mode = "merchant"
		get_tree().change_scene_to_file("res://scenes/main.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/start.tscn")


# --- Taken: clangs, black, three days, the receipt --------------------------------

func _taken_step(delta: float) -> void:
	# Hull clangs as they come aboard.
	if _clangs < 3 and _t > 0.2 + _clangs * 0.55:
		_clangs += 1
		Sfx.play("hit_hull", -2.0, 0.7 - _clangs * 0.05)
		main._shake = maxf(main._shake, 6.0)
	if _t > 1.2:
		_black = minf(1.0, _black + delta / 1.2)
	# Day 1, Day 2, Day 3, ticked by hand.
	if _black >= 1.0 and _ticks < Data.HELD_DAYS and _t > 3.0 + _ticks * 1.0:
		_ticks += 1
		Sfx.play("pen", -4.0)
	if _ticks >= Data.HELD_DAYS and _receipt.is_empty() and _t > 3.0 + Data.HELD_DAYS * 1.0 + 0.6:
		_receipt = Career.ransom(Career.downed_escorts())
		_receipt["shown"] = _t
		Sfx.play("paper", -4.0)
	if _receipt.has("shown") and not _receipt.has("stamped") and _t > _receipt["shown"] + 0.9:
		_receipt["stamped"] = true
		Sfx.play("stamp", -2.0)
	if _receipt.has("shown") and _t > _receipt["shown"] + 9.0:
		_wake()


## You wake docked at the nearest berth. Whoever was still flying is waiting.
func _wake() -> void:
	if phase != "taken":
		return
	_release_captor()
	for s in get_tree().get_nodes_in_group("ships"):
		var sh := s as Ship
		if sh and sh.team == 2 and sh.controller is Traffic.Leaving and is_instance_valid(main.player) and sh.global_position.distance_to(main.player.global_position) < SCAN:
			sh.queue_free()
	_done()
	main.edge.tow_home()
	Career.say("Charlie", Data.capture["charlie_wake"])


func _done() -> void:
	_close_card()
	phase = ""
	captor = null
	_black = 0.0
	_receipt = {}
	queue_redraw()


func _rig() -> String:
	return str(Career.pilot.get("rig", "your rig"))


func _name(s) -> String:
	if is_instance_valid(s):
		return str(s.display_name) if str(s.display_name) != "" else str(s.def.get("name", "raiders"))
	return "raiders"


# --- Drawing -------------------------------------------------------------------

func _draw() -> void:
	var vp := get_viewport_rect().size
	if _black > 0.0:
		draw_rect(Rect2(Vector2.ZERO, vp), Color(0, 0, 0, _black))
	if phase == "taken":
		_draw_days(vp)
		if _receipt.has("shown"):
			_draw_receipt(vp)
	elif phase == "dead" and _black > 0.0:
		_draw_death(vp)


func _draw_days(vp: Vector2) -> void:
	if _ticks <= 0 or Data.font_hand == null:
		return
	var a := 1.0 if not _receipt.has("shown") else clampf(1.0 - (_t - _receipt["shown"]) / 0.4, 0.25, 1.0)
	var at := Vector2(vp.x * 0.5 - 150, vp.y * 0.5 if not _receipt.has("shown") else 90.0)
	for i in _ticks:
		draw_string(Data.font_hand, at + Vector2(i * 110, 0), "Day %d" % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color(0.85, 0.85, 0.9, a))
		draw_line(at + Vector2(i * 110 - 4, -12), at + Vector2(i * 110 + 76, -4), Color(0.85, 0.85, 0.9, a * 0.8), 2.0)


## The ransom receipt in neon (docs/design/ui-look.md): it flickers on over the
## black, amounts in green, ADDED TO LIEN slams on as a red neon stamp.
func _draw_receipt(vp: Vector2) -> void:
	var age := _t - float(_receipt["shown"])
	var a: float = 1.0 if age > 0.35 else [1.0, 0.15, 0.8, 0.3, 1.0][int(age / 0.07) % 5]
	var talk: Font = Data.font_talk
	var bold: Font = Data.font_bold
	var white := Color(0.9, 0.9, 0.94, a)
	var off := Color(0.3, 0.31, 0.37, a)
	var green := Color(UIStyle.GREEN, a)
	var w := 520.0
	var x0 := roundf(vp.x * 0.5 - w * 0.5)
	var y := vp.y * 0.5 - 170.0
	var tx := x0
	for ch in "THE CHARTER COMPANY":
		draw_string(bold, Vector2(tx, y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 1, 1, a))
		tx += bold.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x + 7.0
	draw_string(talk, Vector2(x0, y + 28), "RECOVERY   RANSOM RECEIPT", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, off)
	draw_string(talk, Vector2(x0, y + 28), "NO. %03d" % (10 + int(_receipt["n"])), HORIZONTAL_ALIGNMENT_RIGHT, w, 20, off)
	y += 70.0
	draw_string(talk, Vector2(x0, y), "Rig \"%s\" and operator" % _rig(), HORIZONTAL_ALIGNMENT_LEFT, w, 24, white)
	draw_string(talk, Vector2(x0, y + 26), "released after %d days." % Data.HELD_DAYS, HORIZONTAL_ALIGNMENT_LEFT, w, 24, white)
	draw_string(talk, Vector2(x0, y + 52), "Cargo taken: %d t.   Cash taken: %s cr." % [int(_receipt["seized"]), Career.fmt(int(_receipt["took"]))], HORIZONTAL_ALIGNMENT_LEFT, w, 24, white)
	y += 94.0
	var dn := int(_receipt["downed"])
	for row in [["RANSOM, RIG AND OPERATOR", Data.RANSOM_FEE, true], ["ESCORT PILOTS RECOVERED  X%d" % dn, dn * Data.RANSOM_PER_ESCORT, dn > 0]]:
		draw_string(talk, Vector2(x0, y), row[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, white if row[2] else off)
		draw_string(talk, Vector2(x0, y), "%s CR" % Career.fmt(int(row[1])), HORIZONTAL_ALIGNMENT_RIGHT, w, 24, green if row[2] else off)
		y += 30.0
	y += 14.0
	draw_string(talk, Vector2(x0, y), "TOTAL", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, off)
	var tot := "%s CR" % Career.fmt(int(_receipt["fee"]))
	for o in [Vector2(-2, 0), Vector2(2, 0), Vector2(0, -2), Vector2(0, 2)]:
		draw_string(talk, Vector2(x0, y + 4) + o, tot, HORIZONTAL_ALIGNMENT_RIGHT, w, 36, Color(UIStyle.GREEN, 0.15 * a))
	draw_string(talk, Vector2(x0, y + 4), tot, HORIZONTAL_ALIGNMENT_RIGHT, w, 36, green)
	draw_string(talk, Vector2(x0, vp.y * 0.5 + 190.0), "ANY KEY", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.47, 0.49, 0.56, 1.0 if age > 1.5 else 0.0))
	if _receipt.has("stamped"):
		var st := age - 0.9
		var sa: float = 1.0 if st > 0.15 else [1.0, 0.2, 1.0][int(st / 0.05) % 3]
		var red := Color(1.0, 0.3, 0.33)
		var stamp := "ADDED TO LIEN"
		var sw := Data.font_stamp.get_string_size(stamp, HORIZONTAL_ALIGNMENT_LEFT, -1, 34).x
		draw_set_transform(Vector2(x0 + 30.0, y + 58.0), deg_to_rad(-6.0))
		var sr := Rect2(Vector2(-12, -38), Vector2(sw + 24, 48))
		draw_rect(sr.grow(4), Color(red, 0.15 * sa), false, 6.0)
		draw_rect(sr, Color(red, 0.9 * sa), false, 2.0)
		draw_string(Data.font_stamp, Vector2(0, 0), stamp, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color(red, 0.9 * sa))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_death(vp: Vector2) -> void:
	var a := _black
	var now := Time.get_ticks_msec() / 1000.0
	# The headline is a neon tube: it stutters on, then hums, with the odd flicker.
	var on := _t - 2.4
	var hum := a
	if on < 0.5 and int(on * 30.0) % 3 == 0:
		hum *= 0.25
	elif fmod(now, 4.3) < 0.12:
		hum *= 0.55
	var head: String = Data.capture["death_head"]
	var hs := 72
	var hw := Data.font_stamp.get_string_size(head, HORIZONTAL_ALIGNMENT_LEFT, -1, hs).x
	var hat := Vector2(vp.x * 0.5 - hw * 0.5, vp.y * 0.36)
	var red: Color = Data.neon["colors"]["threats"]
	for g in [[16, 0.05], [9, 0.10], [4, 0.22]]:
		draw_string_outline(Data.font_stamp, hat, head, HORIZONTAL_ALIGNMENT_LEFT, -1, hs, g[0], Color(red, red.a * g[1] * hum))
	draw_string(Data.font_stamp, hat, head, HORIZONTAL_ALIGNMENT_LEFT, -1, hs, Color(red.lightened(0.15), hum))
	# Vishnu's epitaph, a line at a time, centered.
	var font: Font = Data.font_talk if Data.font_talk else Data.font_type
	var size := 26
	var y := vp.y * 0.36 + 40.0
	var lines: Array = Data.capture["death"]
	var start := 3.4
	for i in lines.size():
		var pl: Dictionary = Neon.parse(lines[i])
		var w := font.get_string_size(str(pl["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var age := _t - start
		if age > 0.0:
			Neon.draw(self, font, Vector2(vp.x * 0.5 - w * 0.5, y), pl, w + 40.0, size, Color(0.92, 0.88, 0.78), a, age)
		y += Neon.height(font, pl, w + 40.0, size) + 4.0
		start += Neon.duration(pl) + 0.5
	var b := clampf((_t - start) / 0.8, 0.0, 1.0) * a
	draw_string(Data.font_type_bold, Vector2(vp.x * 0.5 - 360, y + 50.0), "[R]  LOAD LAST DOCK        [ESC]  TITLE", HORIZONTAL_ALIGNMENT_CENTER, 720, 14, Color(UIStyle.TEXT_DIM, b))


## The raider comes alongside your dead rig and holds there.
class Alongside extends AIController:
	func update(_delta: float) -> void:
		var p: Ship = main.player
		if not is_instance_valid(p):
			ship.in_move = Vector2.ZERO
			_set_fire(false)
			return
		var to_p := p.global_position - ship.global_position
		var hold := p.global_position - to_p.normalized() * 200.0
		_fly_to(hold, p.velocity, to_p.angle())
		_set_fire(false)
