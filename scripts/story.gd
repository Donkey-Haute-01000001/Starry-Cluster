extends Node
## Scripted scenes in the Merchant opening, played out in real time in space:
## the Tallyman's ambush and Kessler's patrol, the Mud Lark bounty, and the
## ending at the gate. Lines live in Data (the script doc wins).

const TALLY_FIGHT_TIME := 35.0
const FOUGHT_WELL_DAMAGE := 600.0
const HAIL_RING_TIME := 12.0   ## seconds the hail pings before it counts as ignored
const HAIL_REPLY_TIME := 8.0   ## game seconds to reply (at half speed, ~16 real)
const SILENCE := -1

var main: Node
var scene := ""            ## "", "ambush", "ending"
var _phase := ""
var _t := 0.0
var _tally: Array = []     ## the Tallyman's ships
var _navy: Array = []      ## Kessler's patrol
var _choices: Control
var _overlay: Control
var _bounty_ship: Ship = null
var _saved_order := ""
var ringing := false       ## a hail is pinging, press C to answer
var _ring_ping := 0.0
var _answered_at := -1.0
var _base_scale := 1.0
var _reply_bar: ColorRect


## Flies to a point and brakes there. For story ships that aren't fighting.
class ScriptedPilot extends AIController:
	var goal := Vector2.ZERO
	var face := 0.0
	func update(_delta: float) -> void:
		ship.aim_point = ship.global_position + ship.forward() * 200.0
		_set_fire(false)
		_fly_to(goal, Vector2.ZERO, face)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE


func busy() -> bool:
	return scene != ""


## True while a scene has called a ceasefire (the Tallyman's hail).
func ceasefire() -> bool:
	return scene == "ambush" and _phase in ["hail", "talk", "gone"]


# --- The Tallyman's ambush ---------------------------------------------------------

## First arrival in Marcellus: he's waiting at the jump exit.
func on_enter_system(id: String, from_system: String) -> void:
	_bounty_ship = null
	if id == "marcellus" and from_system != "" and not Career.flags.get("tally_done", false) and scene == "":
		_start_ambush()


func _start_ambush() -> void:
	scene = "ambush"
	_phase = "approach"
	_t = 0.0
	_tally.clear()
	_navy.clear()
	var p: Ship = main.player
	var ahead := p.global_position + p.forward() * 700.0
	var facing := p.rotation + PI
	var g: Ship = main.spawn_ship("tally_gunboat", 1, ahead, facing)
	g.display_name = "The Tallyman"
	_tally.append(g)
	for k in [-1, 1]:
		var e: Ship = main.spawn_ship("tally_escort", 1, ahead + Vector2(-80, 220 * k).rotated(p.rotation), facing)
		_tally.append(e)
	for s in _tally:
		s.hull_floor = 0.3
		s.hold_fire = true
		var pilot := ScriptedPilot.new(s, main)
		pilot.goal = s.global_position
		pilot.face = facing
		s.controller = pilot
	# Nobody on your side dies today, however it looks.
	for s in _fleet():
		s.hull_floor = 0.12
	main.show_message("Contacts at the jump exit. Unknown gunboat, two escorts.", 3.0)


func _fleet() -> Array:
	var out := []
	for s in [main.player] + main.escorts:
		if is_instance_valid(s) and s.alive:
			out.append(s)
	return out


func _physics_process(delta: float) -> void:
	if not is_instance_valid(main) or not main.merchant:
		return
	_t += delta
	match scene:
		"ambush":
			_ambush_step()
		"ending":
			_ending_step()
	_bounty_step()


func _ambush_step() -> void:
	var p: Ship = main.player
	if not is_instance_valid(p):
		return
	var g: Ship = _tally[0] if not _tally.is_empty() and is_instance_valid(_tally[0]) else null
	match _phase:
		"approach":
			if _t > 1.4 and g:
				# The ion shot, then the engines go dark.
				var w: Dictionary = Data.weapons["ion_bolt"]
				main.spawn_projectile(g.global_position + g.forward() * 30.0, (p.global_position - g.global_position).angle(), w, g)
				Sfx.play("hiss", -2.0, 0.6)
				_next("ion")
		"ion":
			if p.ion_t <= 0.0 and _t > 2.5:
				p.ion_hit(14.0)
			if p.ion_t > 0.0 and _t > 0.6:
				p.ion_t = 999.0  # dead until the navy patches you
				main.show_message("ENGINES DOWN. Ion hit. Turrets still work.", 3.5)
				for s in _tally:
					if is_instance_valid(s):
						s.hold_fire = false
						s.controller = AIController.new(s, main)
				_next("fight")
		"fight":
			var dealt := 0.0
			for s in _tally:
				if is_instance_valid(s):
					dealt += s.damage_taken
			var beaten := _t > 15.0 and p.hull_hp <= p.max_hull * 0.13 and p.shields <= 1.0
			if _t > TALLY_FIGHT_TIME or beaten or dealt > FOUGHT_WELL_DAMAGE * 2.0:
				Career.flags["tally_score"] = int(dealt)
				_ceasefire()
				_next("hail")
		"hail":
			# The hail pings until you answer (C) or it times out.
			if _t > 1.0 and _answered_at < 0.0 and not ringing and not Career.flags.has("tally_hailed"):
				Career.flags["tally_hailed"] = true
				ringing = true
				_ring_ping = 0.0
			if ringing:
				if _t >= _ring_ping:
					_ring_ping = _t + 1.6
					Sfx.play("radio", -4.0, 1.3)
				if _t > 1.0 + HAIL_RING_TIME:
					ringing = false
					Career.flags["tally_ignored"] = true
					_reply(SILENCE)
			elif _choices:
				var left := 1.0 - (_t - _answered_at) / HAIL_REPLY_TIME
				if _reply_bar:
					_reply_bar.size.x = 360.0 * maxf(left, 0.0)
				if left <= 0.0:
					choose(SILENCE)
		"talk":
			_say_at(1.5 if Career.flags.get("tally_choice", 0) == SILENCE else 2.5, "Tallyman", _chosen_reply())
			var fought: String = "fought_well" if Career.flags.get("tally_score", 0) >= FOUGHT_WELL_DAMAGE else "fought_poorly"
			_say_at(8.0, "Tallyman", Data.tally[fought])
			_say_at(13.0, "Tallyman", Data.tally["spare"])
			_say_at(18.5, "Tallyman", Data.tally["signoff"])
			if _t > 22.0:
				_tally_leaves()
				_next("gone")
		"gone":
			if _t > 3.0 and Career.friend_with_you() and not Career.flags.has("tally_dez"):
				Career.flags["tally_dez"] = true
				Career.say(Career.friend["name"], Data.tally["dez"])
			if _t > 7.0:
				_navy_arrives()
				_next("navy")
			_despawn_far(_tally, 2600.0)
		"navy":
			_despawn_far(_tally, 2600.0)
			_say_at(0.5, "Franz", Data.franz["arrival"])
			_say_at(11.0, "Franz", Data.franz["intro"])
			if _t > 18.0:
				p.ion_t = 0.0
				for s in _fleet():
					s.hull_floor = 0.0
					s.hull_hp = s.max_hull
					s.shields = s.max_shields
					s.hold_fire = false
				main.fleet_order = _saved_order if _saved_order != "" else "engage"
				Career.say("Franz", Data.franz["patched"])
				Career.flags["tally_done"] = true
				Career.flags["franz_met"] = true
				for s in _navy:
					if is_instance_valid(s):
						var four: Vector2 = Data.stations["four"]["pos"]
						s.controller.goal = four + Vector2(randf_range(-200, 200), randf_range(-200, 200))
				_next("leaving")
		"leaving":
			_despawn_far(_tally, 2600.0)
			if _t > 25.0:
				for s in _navy:
					if is_instance_valid(s):
						s.remove_from_group("ships")
						s.queue_free()
				_navy.clear()
				scene = ""


func _next(phase: String) -> void:
	_phase = phase
	_t = 0.0


## Says a line once, when the phase clock passes `at`.
func _say_at(at: float, who: String, text: String) -> void:
	var key := "said_%s_%d" % [_phase, int(at * 10)]
	if _t >= at and not Career.flags.has(key):
		Career.flags[key] = true
		Career.say(who, text)


func _ceasefire() -> void:
	_saved_order = main.fleet_order
	main.fleet_order = "hold"
	for s in _fleet():
		s.hold_fire = true
	for s in _tally:
		if is_instance_valid(s):
			s.hold_fire = true
			var pilot := ScriptedPilot.new(s, main)
			pilot.goal = s.global_position
			pilot.face = (main.player.global_position - s.global_position).angle()
			s.controller = pilot
	main.show_message("They've stopped shooting. Incoming hail.", 3.0)


## Answer the ringing hail: his line comes in and time drops to half speed
## while you pick a reply. Also used by the scripted test.
func answer() -> void:
	if not ringing:
		return
	ringing = false
	Sfx.play("radio", -2.0)
	Career.say("Tallyman", Data.tally["hail"])
	_base_scale = Engine.time_scale
	Engine.time_scale = _base_scale * 0.5
	_answered_at = _t
	_show_choices()


## Reply buttons: a strip of the rig's radio panel, numbered keys, your words
## in your own hand.
func _show_choices() -> void:
	_choices = VBoxContainer.new()
	_choices.add_theme_constant_override("separation", 6)
	var vp: Vector2 = main.get_viewport().get_visible_rect().size
	_choices.position = Vector2(24, vp.y - 300)
	main.hud.get_parent().add_child(_choices)
	var head := Label.new()
	head.text = "TX  ·  OPEN BAND  ·  REPLY OR STAY QUIET"
	head.add_theme_font_override("font", Data.font_type_bold)
	head.add_theme_font_size_override("font_size", 12)
	head.add_theme_color_override("font_color", UIStyle.GOLD)
	_choices.add_child(head)
	var opts: Array = Data.tally["choices"]
	for i in opts.size():
		var b := Button.new()
		b.text = "[%d]  %s" % [i + 1, opts[i]["text"]]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(360, 40)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_override("font", Data.font_type)
		b.add_theme_font_size_override("font_size", 17)
		for st in ["normal", "hover", "pressed"]:
			var box := StyleBoxFlat.new()
			box.bg_color = Color(0.06, 0.065, 0.07, 0.94) if st == "normal" else Color(0.13, 0.11, 0.07, 0.96)
			box.border_color = UIStyle.GOLD.darkened(0.35 if st == "normal" else 0.0)
			box.border_width_left = 4
			box.border_width_bottom = 2
			box.content_margin_left = 14
			b.add_theme_stylebox_override(st, box)
		b.add_theme_color_override("font_color", Color(0.92, 0.88, 0.78))
		b.add_theme_color_override("font_hover_color", UIStyle.GOLD)
		b.pressed.connect(choose.bind(i))
		_choices.add_child(b)
	# The countdown: when it runs out, silence is your answer.
	var track := ColorRect.new()
	track.color = Color(0.1, 0.1, 0.1, 0.8)
	track.custom_minimum_size = Vector2(360, 4)
	_choices.add_child(track)
	_reply_bar = ColorRect.new()
	_reply_bar.color = UIStyle.GOLD
	_reply_bar.size = Vector2(360, 4)
	track.add_child(_reply_bar)


func _unhandled_input(event: InputEvent) -> void:
	if ringing and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_C:
		get_viewport().set_input_as_handled()
		answer()
	elif _choices and event is InputEventKey and event.pressed and not event.echo:
		var i: int = event.keycode - KEY_1
		if i >= 0 and i < Data.tally["choices"].size():
			get_viewport().set_input_as_handled()
			choose(i)
	elif _overlay and _overlay.done and event.is_pressed() and not event.is_echo():
		get_viewport().set_input_as_handled()
		Engine.time_scale = 1.0
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/start.tscn")


## Pick a reply in the hail; SILENCE when the clock runs out. Also used by the
## scripted test.
func choose(i: int) -> void:
	if _choices == null:
		return
	_choices.queue_free()
	_choices = null
	_reply_bar = null
	Engine.time_scale = _base_scale
	_reply(i)


func _reply(i: int) -> void:
	Career.flags["tally_choice"] = i
	if i != SILENCE:
		Career.say("You", Data.tally["choices"][i]["text"])
	_next("talk")


func _chosen_reply() -> String:
	var i: int = Career.flags.get("tally_choice", 0)
	if i == SILENCE:
		return Data.tally["ignored"] if Career.flags.has("tally_ignored") else Data.tally["silence"]
	return Data.tally["choices"][Career.flags.get("tally_choice", 0)]["reply"]


func _tally_leaves() -> void:
	var p: Ship = main.player
	for s in _tally:
		if is_instance_valid(s):
			s.hull_floor = 0.0
			s.controller.goal = s.global_position + (s.global_position - p.global_position).normalized().rotated(0.3) * 4000.0
			s.controller.face = (s.controller.goal - s.global_position).angle()


func _despawn_far(ships: Array, dist: float) -> void:
	if not is_instance_valid(main.player):
		return
	for s in ships.duplicate():
		if is_instance_valid(s) and s.global_position.distance_to(main.player.global_position) > dist:
			s.remove_from_group("ships")
			s.queue_free()
			ships.erase(s)


func _navy_arrives() -> void:
	var p: Ship = main.player
	var from := p.global_position + Vector2(-1500, 600).rotated(p.rotation)
	for i in 3:
		var hull := "navy_cutter" if i == 0 else "navy_wing"
		var s: Ship = main.spawn_ship(hull, 0, from + Vector2(i * 60, (i - 1) * 90), (p.global_position - from).angle())
		s.display_name = "Lt. Kessler" if i == 0 else ""
		s.velocity = (p.global_position - from).normalized() * 300.0
		var pilot := ScriptedPilot.new(s, main)
		pilot.goal = p.global_position + Vector2(-160 - i * 40, 140 * (i - 1) + 120).rotated(p.rotation)
		pilot.face = p.rotation
		s.controller = pilot
		s.hull_floor = 0.5
		_navy.append(s)


# --- Kessler's bounty --------------------------------------------------------------

func _bounty_step() -> void:
	var f: Dictionary = Career.flags
	if not f.get("bounty_taken", false) or f.get("bounty_killed", false) or main.system_id != "marcellus":
		return
	if _bounty_ship != null and is_instance_valid(_bounty_ship):
		return
	if not is_instance_valid(main.player) or scene != "":
		return
	var b: Dictionary = Data.bounty
	var near: Vector2 = Data.stations[b["station"]]["pos"]
	if main.player.global_position.distance_to(near) > 2200.0:
		return
	var at := near + Vector2(500, -400)
	_bounty_ship = main.spawn_ship(b["hull"], 1, at, PI)
	_bounty_ship.display_name = "Mud Lark"
	_bounty_ship.controller = AIController.new(_bounty_ship, main)
	_bounty_ship.destroyed.connect(func(_s):
		Career.flags["bounty_killed"] = true
		Career.set_objective("Collect the Mud Lark bounty from Kessler at Four.", "four")
		main.show_message("Mud Lark destroyed. Collect the bounty at Four.", 3.5))
	var wing: Ship = main.spawn_ship("raider", 1, at + Vector2(60, 90), PI)
	wing.controller = AIController.new(wing, main)
	main.show_message("Mud Lark spotted near Amber's!", 3.0)


# --- The ending --------------------------------------------------------------------

## At the Wall's gate with your papers: customs, then the jump.
func start_gate(jump: Node2D) -> void:
	if scene != "":
		return
	scene = "ending"
	_next("customs")
	Career.say("Gate customs", Data.ending["customs"])
	Sfx.play("stamp")
	main.jump_charge = 0.0
	main.jump_target = jump
	main.show_message("Cleared. Charging jump drive...", 2.5)


## The jump lands here instead of a normal system.
func arrive_crossroads() -> void:
	main.clear_system()
	main.system_id = "crossroads"
	var p: Ship = main.player
	p.global_position = Vector2(-900, 0)
	p.rotation = 0.0
	p.velocity = Vector2(90, 0)
	p.controller = null
	p.in_move = Vector2.ZERO
	p.in_turn = 0.0
	p.in_fire_aimed = false
	p.in_fire_fixed = false
	p.hold_fire = true
	for k in main.escorts.size():
		var e: Ship = main.escorts[k]
		if is_instance_valid(e):
			e.global_position = p.global_position + Vector2(-110.0 * (k + 1), 70.0 * (1 if k % 2 else -1))
			e.velocity = p.velocity
			e.hold_fire = true
	main.camera.global_position = p.global_position
	var view := Crossroads.new()
	main.world.add_child(view)
	main.world.move_child(view, 0)
	main.hud.visible = false
	main._zoom = 0.42
	_overlay = Overlay.new()
	main.hud.get_parent().add_child(_overlay)
	Sfx.play("hiss", -6.0, 0.5)
	_next("arrive")


func _ending_step() -> void:
	match _phase:
		"arrive":
			# The camera holds while the fleet drifts past.
			if is_instance_valid(main.player):
				main.player.velocity = main.player.velocity.move_toward(Vector2(40, 0), 20.0 * get_physics_process_delta_time())
			if _t > 4.0 and not _overlay.has_line("dez"):
				var dez: String = Data.friend_memories["gate"]["line"] if Career.friend.get("memory", "") == "gate" else "Look at it. Look at all of it."
				if Career.friend_with_you():
					_overlay.show_line("dez", Career.friend["name"], dez)
			if _t > 9.0 and Career.crew.has("mersham") and not _overlay.has_line("mersham"):
				_overlay.show_line("mersham", "Mersham", Data.ending["mersham"])
			if _t > 14.0 and not _overlay.has_line("end"):
				_overlay.show_line("end", "", Data.ending["line"])
			if _t > 22.0:
				_overlay.title_card()
				_next("title")
		"title":
			pass


## The crossroads backdrop: the Dynasty's gate fortress and a fleet sliding past.
class Crossroads extends Node2D:
	var _t := 0.0
	var _ships := []
	## The Dynasty fleet on station, plus the traffic of a chaotic crossroads:
	## League haulers, pilgrims, nomads, a corsair or two. Same hulls, each
	## in its owner's paint with a little wear of its own.
	class Hull extends Node2D:
		var rel := ""
		var size := 200.0
		var vel := Vector2.ZERO
		var light := Color(0.5, 1.0, 0.6, 0.6)
		func _process(delta: float) -> void:
			position += vel * delta
			queue_redraw()
		func _draw() -> void:
			if not Art.draw_fit(self, rel, size, Color(0.88, 0.9, 0.9)):
				draw_rect(Rect2(-size * 0.5, -size * 0.12, size, size * 0.24), Color(0.3, 0.4, 0.32))
			draw_circle(Vector2(size * 0.45, 0), 4.0, light)
	func _ready() -> void:
		z_index = -1
		var rng := RandomNumberGenerator.new()
		rng.seed = 1453
		var groups := [
			["dynasty", ["mjolnir_mark_v", "star_marine_trooper", "destructor", "meteor_slicer", "trident", "ultraviolet_intruder", "vangaurd", "starblaster"], 12, Vector2(160, 380), Color(0.5, 1.0, 0.6)],
			["league", ["transtellar", "dual_striker", "cargo", "harbinger"], 4, Vector2(120, 220), Color(1.0, 0.85, 0.4)],
			["faithful", ["seraph", "arcblaster"], 2, Vector2(90, 150), Color(0.85, 0.7, 1.0)],
			["nomad", ["bison", "scorpion"], 2, Vector2(100, 170), Color(0.6, 1.0, 0.9)],
			["pirate", ["red_fighter", "galactix_racer", "diablo"], 3, Vector2(60, 90), Color(1.0, 0.5, 0.3)],
		]
		for g in groups:
			var kinds: Array = g[1]
			for i in g[2]:
				var h := Hull.new()
				h.rel = "ships/%s.png" % kinds[i % kinds.size()]
				h.size = rng.randf_range(g[3].x, g[3].y)
				h.position = Vector2(rng.randf_range(-2600, 1800), rng.randf_range(-1300, 1300))
				var dyn: bool = g[0] == "dynasty"
				# The fleet holds a slow line; traffic crosses it at its own angles.
				var heading := PI * 0.95 if dyn else rng.randf_range(0, TAU)
				h.rotation = heading
				h.vel = Vector2.RIGHT.rotated(heading) * rng.randf_range(14, 30) * (1.0 if dyn else 2.2)
				h.light = Color(g[4].r, g[4].g, g[4].b, 0.6)
				h.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
				h.material = Art.livery(Data.liveries[g[0]], i + 31 * _ships.size(), Art.main_hue(h.rel))
				add_child(h)
				_ships.append(h)
	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()
	func _draw() -> void:
		# The fortress on the rift, huge and slow.
		var frames := Art.frames("stations/dyson")
		draw_set_transform(Vector2(1500, -150))
		if frames.is_empty():
			draw_circle(Vector2.ZERO, 700, Color(0.2, 0.24, 0.22))
		else:
			Art.draw_fit(self, "stations/dyson/00.png", 1700.0, Color(0.85, 0.95, 0.85), frames[int(_t * 4.0) % frames.size()])
		# The rift you came through, behind you: a tear, not a door.
		draw_set_transform(Vector2(-1250, 0), 0.3)
		Rift.draw(self, _t, 520.0, Color(0.6, 0.45, 1.0), 1453, 5.0)
		draw_set_transform(Vector2.ZERO)


## Cinematic subtitles, then the title card. The demo ends hard there.
class Overlay extends Control:
	var _lines := {}
	var _current := ["", ""]
	var _line_t := 0.0
	var _card_t := -1.0
	var done := false
	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		process_mode = Node.PROCESS_MODE_ALWAYS
	func has_line(key: String) -> bool:
		return _lines.has(key)
	func show_line(key: String, who: String, text: String) -> void:
		_lines[key] = true
		_current = [who, text]
		_line_t = 0.0
	func title_card() -> void:
		_card_t = 0.0
	func _process(delta: float) -> void:
		_line_t += delta
		if _card_t >= 0.0:
			var before := _card_t
			_card_t += delta
			if before < 1.6 and _card_t >= 1.6:
				Sfx.play("stamp", 2.0, 0.7)
			done = _card_t > 6.0
		queue_redraw()
	func _draw() -> void:
		var vp := size if size.x > 10.0 else get_viewport_rect().size
		# Letterbox bars.
		draw_rect(Rect2(0, 0, vp.x, 70), Color(0, 0, 0, 0.85))
		draw_rect(Rect2(0, vp.y - 90, vp.x, 90), Color(0, 0, 0, 0.85))
		var f: Font = ThemeDB.fallback_font
		if _current[1] != "" and _card_t < 0.0:
			var a := clampf(_line_t / 0.8, 0.0, 1.0)
			var text: String = _current[1] if _current[0] == "" else "%s:  \"%s\"" % [_current[0], _current[1]]
			var sz := 26 if _current[0] == "" else 20
			var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
			draw_string(f, Vector2((vp.x - w) * 0.5, vp.y - 38), text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color(0.92, 0.95, 1.0, a))
		if _card_t >= 0.0:
			draw_rect(Rect2(Vector2.ZERO, vp), Color(0, 0, 0, clampf(_card_t / 1.4, 0.0, 1.0)))
			if _card_t > 1.6:
				var tf: Font = Data.font_bold if Data.font_bold else f
				var title := "SECTOR SECUNDUS"
				var tw := tf.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 84).x
				draw_string(tf, Vector2((vp.x - tw) * 0.5, vp.y * 0.5 + 28), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 84, Color(0.9, 0.94, 1.0))
			if done:
				var hint := "press any key"
				var hw := f.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
				draw_string(f, Vector2((vp.x - hw) * 0.5, vp.y - 60), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.6, 0.65, 0.75, 0.6))
