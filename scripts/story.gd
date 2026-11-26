extends Node
## Scripted scenes in the Merchant opening, played out in real time in space:
## the Tallyman's ambush and Kessler's patrol, the Red Stork bounty, and the
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
var boarding: Boarding = null
var _board_hint := 0.0


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


# --- The Tallyman's job: one Charter hauler ------------------------------------------

var _hauler: Ship = null
var _hit_t := -1.0
var _hit_crew: Array = []


func _tally_hit_step(delta: float) -> void:
	if not Career.flags.get("tally_job", false) or main.system_id != "marcellus" or main.docked_at != "":
		return
	var p: Ship = main.player
	if not is_instance_valid(p):
		return
	if not is_instance_valid(_hauler):
		if scene != "":
			return
		# She pulls out of Four, bound for Aurelia.
		var four: Vector2 = Data.stations["four"]["pos"]
		_hauler = main.traffic._spawn("charter_hauler", "charter_hauler", four + Vector2(-260, 160))
		_hauler.remove_from_group("traffic")
		_hauler.team = 3
		_hauler.hold_fire = true
		_hauler.hull_floor = 0.05
		_hauler.display_name = Data.forks["tally_hauler"]
		_hauler.info["job"] = "ore to Aurelia"
		var exit: Vector2 = main.traffic.place("@aurelia")
		var pilot := Traffic.Pilot.new(_hauler, main, main.traffic)
		pilot.route = main.traffic.path(_hauler.global_position, exit).slice(1)
		pilot.end_kind = "jump"
		pilot.end_at = exit
		_hauler.controller = pilot
		_hit_t = -1.0
		_hit_crew.clear()
		main.show_message("Charter hauler %s leaving Four." % _hauler.display_name, 3.0)
		return
	if _hit_t < 0.0:
		if _hauler.disabled:
			_hit_t = 0.0
			# Tally's crew, right on cue.
			for k in 2:
				var at: Vector2 = _hauler.global_position + Vector2(900, 0).rotated(randf() * TAU)
				var r: Ship = main.spawn_ship("tally_escort", 2, at)
				r.display_name = "Tally's crew"
				var sp := ScriptedPilot.new(r, main)
				sp.goal = _hauler.global_position + Vector2(140, 0).rotated(TAU * k / 2.0)
				sp.face = (_hauler.global_position - sp.goal).angle()
				r.controller = sp
				_hit_crew.append(r)
		elif not _hauler.alive or not _hauler.is_inside_tree():
			_hauler = null
		elif main.debt and int(Career.flags.get("ledger_hailed", 0)) == 0 and p.global_position.distance_to(_hauler.global_position) < 1200.0:
			Career.flags["ledger_hailed"] = 1
			Career.say(_hauler.display_name, Data.forks["tally_hauler_hail"], true)
		return
	_hit_t += delta
	if _hit_t > 7.0:
		_hauler.team = 2
		_hauler.controller = Traffic.Leaving.new(_hauler, main)
		for r in _hit_crew:
			if is_instance_valid(r):
				r.controller = Traffic.Leaving.new(r, main)
		_hit_crew.clear()
		_hauler = null
		Career.tally_job_done()


# --- The paymaster's knife: kill his raider and he sends someone ---------------------

var _hunter: Ship = null
var _hunt_t := -1.0


func _hunter_step(delta: float) -> void:
	var f: Dictionary = Career.flags
	if not f.get("bounty_paid", false) or f.get("bounty_alive", false) or f.get("hunter_done", false):
		return
	if is_instance_valid(_hunter):
		if not _hunter.alive or _hunter.disabled:
			f["hunter_done"] = true
			if _hunter.alive:
				Career.say("Trojan", Data.forks["hunter_gone"], true)
				_hunter.controller = Traffic.Leaving.new(_hunter, main)
			_hunter = null
		return
	if main.system_id != "marcellus" or scene != "" or main.docked_at != "" or not is_instance_valid(main.player):
		return
	if _hunt_t < 0.0:
		_hunt_t = randf_range(90.0, 150.0)
	_hunt_t -= delta
	if _hunt_t > 0.0 or main.in_combat:
		return
	_hunt_t = -1.0
	var p: Ship = main.player
	var at := p.global_position + Vector2(1700, 0).rotated(randf() * TAU)
	_hunter = main.spawn_ship("dynasty_corsair", 1, at, (p.global_position - at).angle())
	_hunter.display_name = "Trojan"
	_hunter.info = {"group": "raider", "owner": "the paymaster at Amber's", "job": "hunting you"}
	_hunter.controller = AIController.new(_hunter, main)
	_hunter.controller.target = p
	Career.say("Trojan", Data.forks["hunter_crates"] if int(f.get("shady_done", 0)) > 0 else Data.forks["hunter"], true)


# --- The rig ahead of you ------------------------------------------------------------
# The first water run. Another liened rig is on the same lane a little ahead,
# same Charter number block, same forty tons. Backed raiders take it, and one
# freighter can't stop them. You watch it robbed. Charlie goes quiet. Its
# owner turns up later at the Saltgate bar.

var _rig: Ship = null
var _friend_rig: Ship = null   ## Alejandra's Sweet Margaret, flying with you
var _raiders: Array = []


func _start_ahead() -> void:
	scene = "ahead"
	_phase = "lane"
	_t = 0.0
	_raiders.clear()
	var p: Ship = main.player
	var gh: Vector2 = Data.stations["greenhouse"]["pos"]
	var pts: Array = main.traffic.path(p.global_position, gh)
	var dir: Vector2 = (pts[1] - p.global_position).normalized()
	var at: Vector2 = p.global_position + dir * 1500.0 + dir.orthogonal() * 120.0
	# Hollis' Girl up ahead is the one they hit; Alejandra's Sweet Margaret
	# runs the lane alongside you and talks you through it.
	_rig = main.traffic._spawn("liened_rig", "charter", at)
	_rig.display_name = Data.ahead["victim_rig"]
	_rig.info["owner"] = "%s, owner-operator" % Data.ahead["victim"]
	_rig.info["job"] = "water to the Greenhouse"
	_rig.info["good"] = "water"
	_rig.info["tons"] = 40
	var pilot := Traffic.Pilot.new(_rig, main, main.traffic)
	pilot.route = main.traffic.path(at, gh).slice(1)
	pilot.end_kind = "dock"
	pilot.end_at = gh
	_rig.controller = pilot
	_rig.rotation = dir.angle()
	_rig.velocity = dir * _rig.max_speed * 0.5
	var mat: Vector2 = p.global_position + dir * 400.0 - dir.orthogonal() * 260.0
	_friend_rig = main.traffic._spawn("liened_rig", "charter", mat)
	_friend_rig.display_name = Data.ahead["rig"]
	_friend_rig.info["owner"] = Data.ahead["owner_tag"]
	_friend_rig.info["job"] = "water to the Greenhouse"
	var fp := Traffic.Pilot.new(_friend_rig, main, main.traffic)
	fp.route = main.traffic.path(mat, gh).slice(1)
	fp.end_kind = "dock"
	fp.end_at = gh
	_friend_rig.controller = fp
	_friend_rig.rotation = dir.angle()
	_friend_rig.velocity = p.velocity
	_friend_rig.hull_floor = 0.5
	# Nobody on your side dies on the first run, however it looks.
	for s in _fleet():
		s.hull_floor = 0.12


func _ahead_step(delta: float) -> void:
	var p: Ship = main.player
	if not is_instance_valid(p) or main.system_id != "tiberine":
		_end_ahead()
		return
	var rig_ok := is_instance_valid(_rig) and _rig.alive
	match _phase:
		"lane":
			if _t > 3.0 and not Career.flags.has("ahead_hello"):
				Career.flags["ahead_hello"] = true
				Career.say(Data.ahead["owner"], Data.ahead["hello"] % str(Career.pilot.get("rig", "new rig")))
			# They hit it once you're close enough to see, or soon regardless.
			var near: bool = rig_ok and p.global_position.distance_to(_rig.global_position) < 2400.0
			if rig_ok and _t > 8.0 and (near or _t > 30.0):
				_raid_rig()
		"raid":
			if not rig_ok:
				_phase = "after"
				_t = 0.0
				return
			# Close in on them and one turns to warn you off. It's enough.
			for r in _raiders:
				if is_instance_valid(r) and r.alive and r.controller is AIController:
					var c: AIController = r.controller
					var to_p: float = r.global_position.distance_to(p.global_position)
					if r == _raiders[0] and to_p < 900.0:
						c.target = p
						_coach_2(true)
					elif c.target == p and to_p > 1400.0:
						c.target = _rig
			if _rig.disabled:
				_coach_2(false)
				_phase = "strip"
				_t = 0.0
				_rig.hull_floor = 0.1
				for r in _raiders:
					if is_instance_valid(r) and r.alive:
						var hold := ScriptedPilot.new(r, main)
						hold.goal = _rig.global_position + (r.global_position - _rig.global_position).normalized() * 140.0
						hold.face = (_rig.global_position - r.global_position).angle()
						r.controller = hold
		"strip":
			# Stripping the hold. The tanks come off one by one.
			if rig_ok and int(_t * 2.0) != int((_t - delta) * 2.0) and _t < 9.0:
				main.spawn_sparks(_rig.global_position + Vector2(randf_range(-30, 30), randf_range(-30, 30)), Color(0.9, 0.8, 0.5), 6)
			if _t > 9.0:
				for r in _raiders:
					if is_instance_valid(r) and r.alive:
						r.controller = Traffic.Leaving.new(r, main)
				if rig_ok:
					_rig.info["tons"] = 0
					_rig.info["job"] = "drifting, hold empty"
				_phase = "after"
				_t = 0.0
		"after":
			if _t > 3.0 and not Career.flags.has("ahead_robbed_line"):
				Career.flags["ahead_robbed_line"] = true
				Career.flags["ahead_robbed"] = true
				Career.say(Data.ahead["victim"].split(" ")[0], Data.ahead["robbed"])
			if _t > 6.0:
				_end_ahead()


func _raid_rig() -> void:
	_phase = "raid"
	_t = 0.0
	var side := 1.0 if randf() < 0.5 else -1.0
	var from: Vector2 = _rig.global_position + (_rig.velocity.normalized() if _rig.velocity.length() > 10.0 else Vector2.RIGHT).rotated(side * 1.2) * 1400.0
	for k in 3:
		var r: Ship = main.spawn_ship("backed_raider", 1, from + Vector2(randf_range(-150, 150), randf_range(-150, 150)), (from - _rig.global_position).angle() + PI)
		# Better guns than a freighter's, and paid not to quit.
		r.hull_floor = 0.4
		r.controller = AIController.new(r, main)
		r.controller.target = _rig
		r.info = {"group": "raider", "owner": "Pirate", "job": "hunting"}
		_raiders.append(r)
	_rig.controller.flee = true
	Career.say(Data.ahead["victim_rig"], Data.hails["mayday"] % [Data.ahead["victim_rig"], "the Greenhouse lane"], true)
	Career.say(Data.ahead["owner"], Data.ahead["coach_1"])


## Alejandra's second beat: a warning if you moved in, a quiet word if you watched.
func _coach_2(went_in: bool) -> void:
	if Career.flags.has("ahead_coach_2"):
		return
	Career.flags["ahead_coach_2"] = true
	if went_in:
		Career.flags["ahead_went_in"] = true
	Career.say(Data.ahead["owner"], Data.ahead["coach_2"])


func _end_ahead() -> void:
	Career.flags["ahead_done"] = true
	for s in _fleet():
		s.hull_floor = 0.0
	for r in _raiders:
		if is_instance_valid(r) and r.alive and not (r.controller is Traffic.Leaving):
			r.controller = Traffic.Leaving.new(r, main)
	_raiders.clear()
	if is_instance_valid(_rig) and _rig.alive and _rig.controller is Traffic.Pilot:
		_rig.controller.flee = false
	scene = ""
	_phase = ""


# --- The Tallyman's ambush ---------------------------------------------------------

## First arrival in Marcellus: he's waiting at the jump exit.
func on_enter_system(id: String, from_system: String) -> void:
	# Left Tiberine mid-scene: the rig ahead is behind you now.
	if scene == "ahead" and id != "tiberine":
		_end_ahead()
	_bounty_ship = null
	_hauler = null
	_hunter = null
	_hunt_t = -1.0
	_hit_crew.clear()
	if id == "marcellus" and from_system != "" and not Career.flags.get("tally_done", false) and scene == "":
		_start_ambush()
	elif id == "tiberine" and from_system != "" and scene == "" and not Career.flags.get("ahead_done", false) \
			and Career.jobs.any(func(j): return j["id"] == "starter_water" and j["loaded"]):
		_start_ahead()


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
	# Talky beats wait while you read: the clock stops until the comms are clear.
	if scene == "ambush" and _phase in ["talk", "gone", "navy"] and main.hud.comms_waiting():
		return
	_t += delta
	if _choices:
		_choices.position.y = main.hud.comms_top - 12.0 - _choices.size.y
	match scene:
		"ambush":
			_ambush_step()
		"ending":
			_ending_step()
		"ahead":
			_ahead_step(delta)
	_bounty_step()
	_tally_hit_step(delta)
	_hunter_step(delta)


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
				Sfx.play("ion", -2.0, 0.8)
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
			if _t > 3.5 and _answered_at < 0.0 and not ringing and not Career.flags.has("tally_hailed"):
				Career.flags["tally_hailed"] = true
				ringing = true
				_ring_ping = 0.0
			if ringing:
				if _t >= _ring_ping:
					_ring_ping = _t + 1.6
				if _t > 3.5 + HAIL_RING_TIME:
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
			# The fight is over for good: shake off ions and damage so they can
			# leave, and go neutral so nobody (your wing, the navy) keeps
			# shooting and the radio isn't held for combat (playtest 11-26).
			s.ion_t = 0.0
			if s.disabled:
				s.recover()
			s.team = 2
			s.hold_fire = true
			# Turrets cold, and they open the range: the fight is over.
			var away: Vector2 = (s.global_position - main.player.global_position).normalized()
			var pilot := ScriptedPilot.new(s, main)
			pilot.goal = main.player.global_position + away * maxf(900.0, s.global_position.distance_to(main.player.global_position) + 500.0)
			pilot.face = (-away).angle()
			s.controller = pilot
	# A white flare off the gunboat: the old spacer's sign for hold fire.
	var g: Ship = _tally[0] if not _tally.is_empty() and is_instance_valid(_tally[0]) else null
	if g:
		main.spawn_sparks(g.global_position, Color(1.0, 1.0, 0.96), 60)
		main.spawn_sparks(g.global_position + g.forward() * 40.0, Color(0.95, 0.97, 1.0), 40)
	Sfx.play("ion", -10.0, 1.6)
	main.show_message("White flare. They've stopped shooting.", 3.0)


## Answer the ringing hail: his line comes in and time drops to half speed
## while you pick a reply. Also used by the scripted test.
func answer() -> void:
	if not ringing:
		return
	ringing = false
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
			box.content_margin_right = 16
			box.content_margin_top = 6
			box.content_margin_bottom = 6
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
	if event.is_action_pressed("board") and can_board():
		get_viewport().set_input_as_handled()
		board()
	elif ringing and event.is_action_pressed("answer"):
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
		_board_check()
		return
	if not is_instance_valid(main.player) or scene != "":
		return
	var b: Dictionary = Data.bounty
	var near: Vector2 = Data.stations[b["station"]]["pos"]
	if main.player.global_position.distance_to(near) > 2200.0:
		return
	var at := near + Vector2(500, -400)
	_bounty_ship = main.spawn_ship(b["hull"], 1, at, PI)
	_bounty_ship.display_name = "Red Stork"
	_bounty_ship.controller = AIController.new(_bounty_ship, main)
	_bounty_ship.destroyed.connect(func(_s):
		Career.flags["bounty_killed"] = true
		Career.set_objective("Collect the Red Stork bounty from Kessler at Four.", "four")
		main.show_message("Red Stork destroyed. Collect the bounty at Four.", 3.5))
	_bounty_ship.disabled_now.connect(func(_s):
		if Career.flags.get("marines", 0) > 0:
			main.show_message("Red Stork disabled! Get alongside and press [B] to board.", 4.0)
		else:
			main.show_message("Red Stork disabled.", 2.5))
	var wing: Ship = main.spawn_ship("raider", 1, at + Vector2(60, 90), PI)
	wing.controller = AIController.new(wing, main)
	main.show_message("Red Stork spotted near Amber's!", 3.0)


## Alongside a disabled Red Stork with marines aboard: [B] to board.
func can_board() -> bool:
	var lark := _bounty_ship
	if boarding != null or not is_instance_valid(lark) or not lark.disabled or lark.team == 0:
		return false
	if Career.flags.get("marines", 0) <= 0 or not is_instance_valid(main.player):
		return false
	var p: Ship = main.player
	return p.global_position.distance_to(lark.global_position) < 280.0 and (p.velocity - lark.velocity).length() < 160.0


func _board_check() -> void:
	_board_hint -= get_physics_process_delta_time()
	if can_board() and _board_hint <= 0.0:
		_board_hint = 0.5
		main.show_message("[B] Board the Red Stork  ·  %d marines" % Career.flags.get("marines", 0), 0.6)


## Opens the plan card. Also used by the scripted test.
func board() -> void:
	if not can_board():
		return
	Career.say("Marines", Data.marine_lines["ready"])
	boarding = Boarding.new()
	boarding.main = main
	boarding.target = _bounty_ship
	boarding.marines = Career.flags.get("marines", 0)
	boarding.defenders = Career.flags.get("lark_crew", Data.bounty["crew"])
	boarding.plans = Data.board_plans.duplicate(true)
	boarding.finished.connect(_boarded)
	boarding.tree_exited.connect(func(): boarding = null)
	main.hud.get_parent().add_child(boarding)


func _boarded(won: bool, plan: Dictionary, left: int) -> void:
	var lost: int = Career.flags.get("marines", 0) - left
	Career.flags["marines"] = left
	if not won:
		Career.flags["lark_crew"] = boarding.defenders
		Career.say("Marines", Data.marine_lines["repelled"] % lost)
		if left <= 0:
			Career.say("Marines", Data.marine_lines["none"])
		return
	var share := Career.prize_share(plan["share"])
	Career.flags["bounty_alive"] = true
	Career.flags["bounty_killed"] = true
	Career.flags["prize_share"] = share
	Career.say("Marines", Data.marine_lines["taken"])
	var lines: Array = []
	for row in Data.bounty["hold"]:
		var kept := int(round(row[1] * plan["share"]))
		lines.append("HOLD   %d t %s%s" % [kept, Data.goods[row[0]]["name"].to_lower(), "" if kept == row[1] else "  (%d vented)" % (row[1] - kept)])
	lines.append("BOUNTY (ALIVE)  %s cr" % _num(Data.bounty["pay_alive"]))
	lines.append("YOUR PRIZE SHARE  +%s cr" % _num(share))
	boarding.set_loot(lines)
	Career.set_objective("Collect the Red Stork bounty and prize share from Kessler at Four.", "four")
	# The navy prize crew patches her up and flies her in.
	var lark := _bounty_ship
	get_tree().create_timer(3.0).timeout.connect(func():
		if not is_instance_valid(lark):
			return
		lark.team = 0
		lark.disabled = false
		lark.hold_fire = true
		lark.display_name = "Red Stork (prize)"
		var pilot := ScriptedPilot.new(lark, main)
		pilot.goal = Data.stations["four"]["pos"]
		pilot.face = (pilot.goal - lark.global_position).angle()
		lark.controller = pilot)


static func _num(n: int) -> String:
	var s := str(n)
	return s.substr(0, s.length() - 3) + "," + s.substr(s.length() - 3) if n >= 1000 else s


# --- The ending --------------------------------------------------------------------

## At the Wall's gate with your papers: customs, then the jump.
func start_gate(jump: Node2D) -> void:
	if scene != "":
		return
	scene = "ending"
	_next("customs")
	var f: Dictionary = Career.flags
	# The rigs you came back for are in the queue, and they speak up.
	var saved: Array = f.get("saved_names", [])
	for i in mini(saved.size(), 2):
		Career.say(str(saved[saved.size() - 1 - i]), Data.lanes["vouch"])
	Career.say("Gate customs", Data.ending["customs"])
	match str(f.get("side", "")):
		"navy":
			Career.say("Gate customs", Data.forks["navy_papers"])
		"tally":
			Career.say("Gate customs", Data.forks["tally_heat"])
	if int(f.get("busted", 0)) > 0:
		Career.say("Gate customs", Data.forks["flagged"])
	elif int(f.get("shady_done", 0)) == 0 and f.get("shady_seen", false):
		Career.say("Gate customs", Data.forks["charlie_vouch"])
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
	Sfx.play("jump", -2.0, 0.8)
	_next("arrive")


var _end_lines: Array = []


## Who's with you past the gate, and what you carry through it.
func _crossroads_lines() -> Array:
	var out: Array = []
	var f: Dictionary = Career.flags
	if Career.friend_with_you():
		var dez: String = Data.friend_memories["gate"]["line"] if Career.friend.get("memory", "") == "gate" else "Look at it. Look at all of it."
		out.append(["dez", Career.friend["name"], dez])
	if Career.crew.has("mersham"):
		out.append(["mersham", "Mersham", Data.ending["mersham"]])
	if Career.crew.has("navy_wing"):
		out.append(["wing", "Mbeki", Data.forks["halloran_gate"]])
	elif Career.crew.has("tally_wing"):
		out.append(["wing", "Notch", Data.forks["scratch_gate"]])
	if f.get("bounty_alive", false):
		out.append(["lark", "Qasim", Data.forks["lark_alive"]])
	if int(f.get("shady_done", 0)) >= 2 and not Career.paymaster_angry():
		out.append(["letter", "Dynasty courier", Data.forks["letter"]])
	out.append(["end", "", Data.ending["line"]])
	return out


func _ending_step() -> void:
	match _phase:
		"arrive":
			# The camera holds while the fleet drifts past.
			if is_instance_valid(main.player):
				main.player.velocity = main.player.velocity.move_toward(Vector2(40, 0), 20.0 * get_physics_process_delta_time())
			if _end_lines.is_empty():
				_end_lines = _crossroads_lines()
			# One voice at a time, then the line, then the card.
			var at := 4.0
			for l in _end_lines:
				if _t > at and not _overlay.has_line(l[0]):
					_overlay.show_line(l[0], l[1], l[2])
					break
				at += 4.8
			if _t > at + 8.0:
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
			_t += delta
			position += vel * delta
			queue_redraw()
		var _t := 0.0
		func _draw() -> void:
			# Void fleet hulls are folders: animated engine strip under the base.
			if not rel.ends_with(".png"):
				var base := Art.tex(rel + "/base.png")
				var u := Art.used_rect(rel + "/base.png")
				if base:
					var k := size / maxf(maxf(u.size.x, u.size.y), 1.0)
					draw_set_transform(Vector2.ZERO, PI * 0.5, Vector2(k, k))
					var eng := Art.tex(rel + "/engine.png")
					if eng:
						var n := maxi(1, roundi(float(eng.get_width()) / eng.get_height()))
						var c := float(eng.get_width()) / n
						var h := float(eng.get_height())
						draw_texture_rect_region(eng, Rect2(Vector2(-c, -h) * 0.5, Vector2(c, h)), Rect2((int(_t * 10.0) % n) * c, 0, c, h))
					draw_texture_rect(base, Rect2(-base.get_size() * 0.5, base.get_size()), false)
					draw_set_transform(Vector2.ZERO)
				return
			if not Art.draw_fit(self, rel, size, Color(0.88, 0.9, 0.9)):
				draw_rect(Rect2(-size * 0.5, -size * 0.12, size, size * 0.24), Color(0.3, 0.4, 0.32))
			draw_circle(Vector2(size * 0.45, 0), 4.0, light)
	func _ready() -> void:
		z_index = -1
		var rng := RandomNumberGenerator.new()
		rng.seed = 1453
		var groups := [
			["dynasty", ["@nairan/dreadnought", "@nairan/battlecruiser", "@nairan/frigate", "@nairan/torpedo_ship", "@nairan/frigate", "@nairan/bomber", "star_marine_trooper", "@nairan/battlecruiser"], 12, Vector2(160, 380), Color(0.5, 1.0, 0.6)],
			["dynasty", ["@nairan/fighter", "@nairan/scout", "@nairan/fighter"], 8, Vector2(40, 60), Color(0.5, 1.0, 0.6)],
			["league", ["transtellar", "dual_striker", "cargo", "harbinger"], 4, Vector2(120, 220), Color(1.0, 0.85, 0.4)],
			["faithful", ["seraph", "arcblaster"], 2, Vector2(90, 150), Color(0.85, 0.7, 1.0)],
			["nomad", ["bison", "scorpion"], 2, Vector2(100, 170), Color(0.6, 1.0, 0.9)],
			["pirate", ["@nautolan/fighter", "@nautolan/scout", "@nautolan/bomber"], 3, Vector2(50, 80), Color(1.0, 0.5, 0.3)],
		]
		for g in groups:
			var kinds: Array = g[1]
			for i in g[2]:
				var h := Hull.new()
				var kind: String = kinds[i % kinds.size()]
				h.rel = "ships/" + kind.substr(1) if kind.begins_with("@") else "ships/%s.png" % kind
				h.size = rng.randf_range(g[3].x, g[3].y)
				h.position = Vector2(rng.randf_range(-2600, 1800), rng.randf_range(-1300, 1300))
				var dyn: bool = g[0] == "dynasty"
				# The fleet holds a slow line; traffic crosses it at its own angles.
				var heading := PI * 0.95 if dyn else rng.randf_range(0, TAU)
				h.rotation = heading
				h.vel = Vector2.RIGHT.rotated(heading) * rng.randf_range(14, 30) * (1.0 if dyn else 2.2)
				h.light = Color(g[4].r, g[4].g, g[4].b, 0.6)
				if h.rel.ends_with(".png"):
					h.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
					h.material = Art.livery(Data.liveries[g[0]], i + 31 * _ships.size(), Art.main_hue(h.rel))
				else:
					h.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
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
