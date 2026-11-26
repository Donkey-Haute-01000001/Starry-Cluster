extends Node
## The Charter briefing (docs/design/briefing.md). On a new career Charlie
## walks you through the HUD while the rig is held at the berth, each part
## appearing as she names it. Radar, ship panel, guns and orders get one
## line the first time each matters. Skip it with a reply; the first-time
## lines still come.

var main: Node
var choosing := false      ## the opener's reply buttons are up
var active := false        ## the parked part is running
var _step := ""
var _wait := 0.0
var _choices: Control = null
var _park := Vector2.ZERO

const PARTS := ["plate", "job", "nav", "ship", "radar"]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## True for a career that hasn't been briefed (or skipped it) yet.
static func needed() -> bool:
	return not Career.flags.has("briefed")


func start() -> void:
	active = true
	Career.flags["briefed"] = "started"
	Career.flags["tip_fly"] = true  # key caps wait for her "keys" line
	main.hud.tip = ""
	for part in PARTS:
		main.hud.held[part] = true
	_park = main.player.global_position
	_go("opener", 0.6)


func _go(step: String, wait := 0.4) -> void:
	_step = step
	_wait = wait


func _say(key: String) -> void:
	Career.say("Charlie", Data.briefing[key])


func _process(delta: float) -> void:
	if active and is_instance_valid(main.player):
		# Clamps on: the rig sits still at the berth until she lets go.
		main.player.velocity = Vector2.ZERO
		main.player.global_position = _park
	if choosing:
		return
	if active:
		if main.hud.comms_waiting():
			return
		_wait -= delta
		if _wait <= 0.0:
			_parked_step()
	elif Career.flags.has("briefed") and not get_tree().paused:
		_first_times()
	if main.hud.force_talk and not main.hud.comms_waiting():
		main.hud.force_talk = false


func _parked_step() -> void:
	var hud = main.hud
	match _step:
		"opener":
			_say("opener")
			_go("choose")
		"choose":
			if hud.hold_enabled():
				_show_choices()
			else:
				_choose(0)  # scripted tests take the briefing
		"comms":
			_say("comms")
			_go("plate", 0.8)
		"plate":
			hud.reveal("plate")
			_say("plate")
			_go("job_hail", 0.8)
		"job_hail":
			Career.first_job()  # her starter-run hail sets the job up
			_go("job", 0.6)
		"job":
			hud.reveal("job")
			_say("job")
			_go("nav", 0.8)
		"nav":
			hud.reveal("nav")
			_say("nav")
			_go("keys", 0.8)
		"keys":
			Career.flags["tip_fly"] = false
			_say("keys")
			_go("release", 0.2)
		"release":
			active = false
			Career.flags["briefed"] = "done"


## Radar, shields, guns, orders: one line each, the first time it matters.
func _first_times() -> void:
	var hud = main.hud
	var p: Ship = main.player
	if not is_instance_valid(p) or main.docked_at != "" or hud.comms_waiting():
		return
	var f: Dictionary = Career.flags
	if not f.has("brief_radar") and _ship_near(p, 1800.0):
		f["brief_radar"] = true
		_first("radar", "radar")
	elif not f.has("brief_shields") and p.shields < p.max_shields - 1.0 and p.since_hit < 1.0:
		f["brief_shields"] = true
		_first("ship", "shields")
	elif not f.has("brief_guns") and main.nearest_enemy(0, p.global_position, 1400.0) != null:
		f["brief_guns"] = true
		_first("", "guns")
	elif not f.has("brief_orders") and main.in_combat and not main.escorts.is_empty():
		f["brief_orders"] = true
		_first("", "orders")


func _first(part: String, key: String) -> void:
	if part != "":
		main.hud.reveal(part)
	main.hud.force_talk = true
	_say(key)


func _ship_near(p: Ship, dist: float) -> bool:
	for s in get_tree().get_nodes_in_group("ships"):
		if s != p and is_instance_valid(s) and not (s in main.escorts) and s.global_position.distance_to(p.global_position) < dist:
			return true
	return false


# --- The opener's reply -------------------------------------------------------

func _show_choices() -> void:
	choosing = true
	get_tree().paused = true
	var vp: Vector2 = main.get_viewport().get_visible_rect().size
	_choices = VBoxContainer.new()
	_choices.process_mode = Node.PROCESS_MODE_ALWAYS
	_choices.add_theme_constant_override("separation", 6)
	main.hud.get_parent().add_child(_choices)
	var head := Label.new()
	head.text = "REPLY"
	head.add_theme_font_override("font", Data.font_type_bold)
	head.add_theme_font_size_override("font_size", 16)
	head.add_theme_color_override("font_color", UIStyle.GOLD)
	_choices.add_child(head)
	var opts: Array = Data.briefing["replies"]
	for i in opts.size():
		var b := Button.new()
		b.text = "[%d]  %s" % [i + 1, opts[i]]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(520, 40)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_override("font", Data.font_talk)
		b.add_theme_font_size_override("font_size", 20)
		for st in ["normal", "hover", "pressed"]:
			var box := StyleBoxFlat.new()
			box.bg_color = Color(0.02, 0.035, 0.045, 0.96) if st == "normal" else Color(0.13, 0.11, 0.07, 0.98)
			box.border_color = UIStyle.GOLD.darkened(0.35 if st == "normal" else 0.0)
			box.border_width_left = 4
			box.content_margin_left = 14
			box.content_margin_right = 16
			box.content_margin_top = 6
			box.content_margin_bottom = 6
			b.add_theme_stylebox_override(st, box)
		b.add_theme_color_override("font_color", Color(0.9, 0.9, 0.94))
		b.add_theme_color_override("font_hover_color", UIStyle.GOLD)
		b.pressed.connect(_choose.bind(i))
		_choices.add_child(b)
	_choices.reset_size()
	_choices.position = Vector2(roundf((vp.x - _choices.size.x) * 0.5), roundf(vp.y - 150.0 - _choices.size.y))


func _unhandled_input(event: InputEvent) -> void:
	if not choosing or not (event is InputEventKey and event.pressed and not event.echo):
		return
	var i: int = event.keycode - KEY_1
	if i >= 0 and i < Data.briefing["replies"].size():
		get_viewport().set_input_as_handled()
		_choose(i)


func _choose(i: int) -> void:
	if _choices:
		_choices.queue_free()
		_choices = null
	if choosing:
		choosing = false
		get_tree().paused = false
	var text: String = Data.briefing["replies"][i]
	Career.say("You", text.split("  (")[0])
	if i == 0:
		_go("comms", 0.6)
		return
	# Skipped: everything shows, the job comes in, first-time lines still play.
	Career.say("Charlie", Data.briefing["skipped"])
	for part in ["plate", "job", "nav"]:
		main.hud.reveal(part)
	main.hud.held.clear()
	Career.first_job()
	Career.flags["tip_fly"] = false
	active = false
	Career.flags["briefed"] = "skipped"
