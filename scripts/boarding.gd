extends Control
class_name Boarding
## Boarding a disabled ship, in real time. Pick a plan on a card (time runs at
## half speed, like a hail), then the breach plays out over the target: rounds
## tick, pips drop, the odds swing, and it ends in SHIP TAKEN or REPELLED.
## Endless Sky style crew battle: each round one side loses a body, weighted by
## numbers times strength.

signal finished(won: bool, plan: Dictionary, marines_left: int)

const ROUND_TIME := 0.85
const PLAN_TIME := 8.0      ## game seconds to pick (half speed, ~16 real)
const SIMS := 400

var main: Node
var target: Ship
var plans: Array = []       ## [{id, name, note, atk, def, share}]
var marines := 0
var m_total := 0
var d_total := 0
var defenders := 0
var phase := "plan"         ## plan, breach, done
var plan: Dictionary = {}
var round_n := 0
var odds := 0.0
var _odds_shown := 0.0
var _swing := 0.0
var _t := 0.0
var _round_t := 0.0
var _won := false
var _flash := {}            ## "m"/"d" -> index of the pip that just dropped, and its timer
var _flash_t := 0.0
var _end_t := 0.0
var _base_scale := 1.0
var _card: VBoxContainer
var _bar: ColorRect
var _loot: Array = []       ## lines revealed one by one after a win
var _shake := 0.0
var _grapple := Vector2.ZERO   ## target's offset from the player, locked while boarding
var defending := false      ## they're boarding you: your side vs theirs, HELD or OVERRUN


static func win_odds(a: int, d: int, a_pow: float, d_pow: float) -> float:
	if a <= 0:
		return 0.0
	if d <= 0:
		return 1.0
	var wins := 0
	for i in SIMS:
		var x := a
		var y := d
		while x > 0 and y > 0:
			if randf() < x * a_pow / (x * a_pow + y * d_pow):
				y -= 1
			else:
				x -= 1
		if y == 0:
			wins += 1
	return float(wins) / SIMS


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_instance_valid(main.player) and is_instance_valid(target):
		_grapple = target.global_position - main.player.global_position
	m_total = marines
	d_total = defenders
	_base_scale = Engine.time_scale
	Engine.time_scale = _base_scale * 0.5
	_show_card()


## The plan card: same radio-panel strip as hail replies, odds on each plan.
func _show_card() -> void:
	_card = VBoxContainer.new()
	_card.add_theme_constant_override("separation", 6)
	var vp: Vector2 = main.get_viewport().get_visible_rect().size
	_card.position = Vector2(24, vp.y - 380)
	get_parent().add_child(_card)
	var head := Label.new()
	head.text = "BOARDING  ·  %d MARINES vs %d CREW  ·  PICK A PLAN" % [marines, defenders]
	head.add_theme_font_override("font", Data.font_type_bold)
	head.add_theme_font_size_override("font_size", 12)
	head.add_theme_color_override("font_color", UIStyle.GOLD)
	_card.add_child(head)
	for i in plans.size():
		var p: Dictionary = plans[i]
		var o := win_odds(marines, defenders, p["atk"], p["def"])
		p["odds"] = o
		var b := Button.new()
		b.text = "[%d]  %s   %d%%\n       %s" % [i + 1, p["name"], roundi(o * 100.0), p["note"]]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(420, 52)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_override("font", Data.font_type)
		b.add_theme_font_size_override("font_size", 16)
		for st in ["normal", "hover", "pressed"]:
			var box := StyleBoxFlat.new()
			box.bg_color = Color(0.06, 0.065, 0.07, 0.94) if st == "normal" else Color(0.13, 0.11, 0.07, 0.96)
			box.border_color = UIStyle.GOLD.darkened(0.35 if st == "normal" else 0.0)
			box.border_width_left = 4
			box.border_width_bottom = 2
			box.content_margin_left = 14
			box.content_margin_right = 16
			box.content_margin_top = 6
			box.content_margin_bottom = 6
			b.add_theme_stylebox_override(st, box)
		b.add_theme_color_override("font_color", Color(0.92, 0.88, 0.78))
		b.add_theme_color_override("font_hover_color", UIStyle.GOLD)
		b.pressed.connect(pick.bind(i))
		_card.add_child(b)
	var track := ColorRect.new()
	track.color = Color(0.1, 0.1, 0.1, 0.8)
	track.custom_minimum_size = Vector2(420, 4)
	_card.add_child(track)
	_bar = ColorRect.new()
	_bar.color = UIStyle.GOLD
	_bar.size = Vector2(420, 4)
	track.add_child(_bar)


func _unhandled_input(event: InputEvent) -> void:
	if phase == "plan" and event is InputEventKey and event.pressed and not event.echo:
		var i: int = event.keycode - KEY_1
		if i >= 0 and i < plans.size():
			get_viewport().set_input_as_handled()
			pick(i)


## Commit to a plan. The clock running out picks the first (the marines go in
## their own way). Also used by the scripted test.
func pick(i: int) -> void:
	if phase != "plan":
		return
	plan = plans[i]
	_card.queue_free()
	_card = null
	Engine.time_scale = _base_scale
	if plan.has("order"):
		Career.say("You", plan["order"])
	Sfx.play("stamp", -4.0, 0.8)
	odds = plan["odds"]
	_odds_shown = odds
	phase = "breach"
	_round_t = ROUND_TIME * 1.4   # beat before the first round: the breach charge
	_shake = 1.0
	main.spawn_sparks(target.global_position, Color(1.0, 0.8, 0.4), 24)


func _process(delta: float) -> void:
	_t += delta
	_flash_t = maxf(_flash_t - delta, 0.0)
	_shake = maxf(_shake - delta * 2.0, 0.0)
	_odds_shown = lerpf(_odds_shown, odds, minf(delta * 6.0, 1.0))
	_swing = lerpf(_swing, 0.0, minf(delta * 2.0, 1.0))
	if is_instance_valid(target):
		# Grappled: the target rides alongside until the fight's over.
		if phase != "done" and is_instance_valid(main.player) and target.team != 0:
			target.global_position = main.player.global_position + _grapple
			target.velocity = main.player.velocity
		position = target.get_global_transform_with_canvas().origin
	elif phase != "done":
		_close()
		return
	if _card:
		_card.position.y = main.hud.comms_top - 12.0 - _card.size.y
	match phase:
		"plan":
			var left := 1.0 - _t / PLAN_TIME  # delta is game time, so ~2x real at half speed
			if _bar:
				_bar.size.x = 420.0 * clampf(left, 0.0, 1.0)
			if left <= 0.0:
				pick(0)
		"breach":
			_round_t -= delta
			if _round_t <= 0.0:
				_round()
		"done":
			_end_t += delta
			if _end_t > 5.5:
				_close()
	queue_redraw()


func _round() -> void:
	_round_t = ROUND_TIME
	round_n += 1
	var a: float = marines * plan["atk"]
	var d: float = defenders * plan["def"]
	var before := odds
	if randf() < a / (a + d):
		defenders -= 1
		_flash = {"side": "d", "i": defenders}
		Sfx.play("tick", -2.0, 1.2)
	else:
		marines -= 1
		_flash = {"side": "m", "i": marines}
		Sfx.play("tick", -2.0, 0.7)
	_flash_t = 0.5
	_shake = 0.5
	main.spawn_sparks(target.global_position + Vector2(randf_range(-20, 20), randf_range(-20, 20)), Color(1.0, 0.6, 0.3), 6)
	odds = win_odds(marines, defenders, plan["atk"], plan["def"])
	_swing = odds - before
	if defenders <= 0 or marines <= 0:
		_won = defenders <= 0
		phase = "done"
		_end_t = 0.0
		_shake = 1.2
		Sfx.play("chime" if _won else "repelled", -2.0)
		finished.emit(_won, plan, marines)


func set_loot(lines: Array) -> void:
	_loot = lines


func _close() -> void:
	if _card:
		_card.queue_free()
	if phase == "plan":
		Engine.time_scale = _base_scale
	queue_free()


func _draw() -> void:
	if phase != "done" and is_instance_valid(main.player) and is_instance_valid(target):
		var to: Vector2 = main.player.get_global_transform_with_canvas().origin - position
		for k in [-6.0, 6.0]:
			var n: Vector2 = to.orthogonal().normalized() * k
			draw_line(n, to + n, Color(0.75, 0.7, 0.6, 0.8), 2.0)
	if phase == "plan":
		return
	var f: Font = Data.font_type_bold
	var jolt := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake * 4.0
	var o := Vector2(-150, -150) + jolt
	var w := 300.0
	# Panel: gunmetal plate with a hazard edge.
	draw_rect(Rect2(o, Vector2(w, 96)), Color(0.05, 0.055, 0.06, 0.92))
	draw_rect(Rect2(o, Vector2(w, 96)), UIStyle.GOLD.darkened(0.3), false, 2.0)
	var title := "BREACH  ·  ROUND %d" % round_n if round_n > 0 else "BREACH  ·  CHARGES SET"
	draw_string(f, o + Vector2(10, 18), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UIStyle.GOLD)
	draw_string(Data.font_type, o + Vector2(w * 0.5 - 10, 18), plan.get("name", "").to_upper(), HORIZONTAL_ALIGNMENT_RIGHT, w * 0.5, 11, UIStyle.TEXT_DIM)
	# Pips: marines (navy blue-white) vs crew (red). Dead pips go dark, the one
	# that just fell flashes.
	_pips(o + Vector2(10, 30), "YOURS" if defending else "MARINES", m_total, marines, Color(0.75, 0.88, 1.0), "m")
	_pips(o + Vector2(10, 50), "BOARDERS" if defending else "CREW", d_total, defenders, UIStyle.RED, "d")
	# Odds bar with the swing arrow.
	var bar := Rect2(o + Vector2(10, 72), Vector2(w - 70, 12))
	draw_rect(bar, Color(0.15, 0.06, 0.05))
	var fill := bar
	fill.size.x *= _odds_shown
	draw_rect(fill, UIStyle.GREEN.lerp(UIStyle.GOLD, 1.0 - _odds_shown))
	for i in range(1, 10):
		draw_line(bar.position + Vector2(bar.size.x * i / 10.0, 0), bar.position + Vector2(bar.size.x * i / 10.0, 12), Color(0, 0, 0, 0.5), 1.0)
	var pct := "%d%%" % roundi(_odds_shown * 100.0)
	draw_string(f, o + Vector2(w - 54, 83), pct, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UIStyle.TEXT)
	if absf(_swing) > 0.02:
		var up := _swing > 0.0
		var c := o + Vector2(w - 12, 77)
		var tri := PackedVector2Array([c + Vector2(-5, 4), c + Vector2(5, 4), c + Vector2(0, -5)]) if up else PackedVector2Array([c + Vector2(-5, -4), c + Vector2(5, -4), c + Vector2(0, 5)])
		draw_colored_polygon(tri, UIStyle.GREEN if up else UIStyle.RED)
	# The stinger.
	if phase == "done":
		var k := clampf(_end_t / 0.25, 0.0, 1.0)
		var size := int(lerpf(64.0, 40.0, k))
		var msg := ("HELD" if _won else "OVERRUN") if defending else ("SHIP TAKEN" if _won else "REPELLED")
		var col: Color = UIStyle.GOLD if _won else UIStyle.RED
		var sw := Data.font_stamp.get_string_size(msg, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var at := Vector2(-sw * 0.5, -190) + jolt
		draw_string(Data.font_stamp, at + Vector2(3, 3), msg, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, 0.7))
		draw_string(Data.font_stamp, at, msg, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
		# Loot reveal: one manifest line every half second.
		for i in _loot.size():
			var show_at := 0.8 + i * 0.5
			if _end_t < show_at:
				break
			var a := clampf((_end_t - show_at) / 0.2, 0.0, 1.0)
			var line: String = _loot[i]
			var last := i == _loot.size() - 1
			var y := 60.0 + i * 22.0
			draw_rect(Rect2(Vector2(-150, y - 15), Vector2(300, 20)), Color(0.91, 0.88, 0.8, 0.95 * a))
			draw_string(Data.font_type_bold if last else Data.font_type, Vector2(-142, y), line, HORIZONTAL_ALIGNMENT_LEFT, 284, 13, Color(UIStyle.INK_STAMP if last else UIStyle.INK_TYPE, a))


func _pips(at: Vector2, label: String, total: int, alive: int, col: Color, side: String) -> void:
	draw_string(Data.font_type, at + Vector2(0, 11), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UIStyle.TEXT_DIM)
	for i in total:
		var r := Rect2(at + Vector2(70 + i * 20, 0), Vector2(14, 14))
		if i < alive:
			draw_rect(r, col)
		else:
			var hit: bool = _flash.get("side", "") == side and _flash.get("i", -1) == i and _flash_t > 0.0
			draw_rect(r, Color.WHITE if hit and int(_flash_t * 20.0) % 2 == 0 else col.darkened(0.75))
			draw_line(r.position, r.end, col.darkened(0.5), 2.0)
