class_name Edge
extends Node2D
## The edge of a system: the beacon ring. Inside it, station tugs and beacons
## carry you and fuel is nobody's chore. Past it you burn the rig's own
## reserve, and when that's gone the Charter tows you home and bills the lien.

const TANK_SECONDS := 75.0     ## full-burn seconds in the reserve
const REFILL := 0.25           ## per second, back on the beacons
const TOW_FEE := 1500
const MARGIN := 1400.0         ## ring sits this far past the outermost station or rift

var main: Node
var radius := 5000.0
var reserve := 1.0
var outside := false
var slip := {}                 ## the tow slip on screen: {fee, n, t}
var _dry_t := -1.0
var _warned := {}
var _t := 0.0


func _init(p_main: Node) -> void:
	main = p_main
	z_index = -5


func on_load() -> void:
	var far := 0.0
	for sid in Data.stations:
		if Data.stations[sid]["system"] == main.system_id:
			far = maxf(far, (Data.stations[sid]["pos"] as Vector2).length())
	for j in Data.systems[main.system_id]["jumps"]:
		far = maxf(far, (j["pos"] as Vector2).length())
	radius = far + MARGIN
	outside = false
	reserve = 1.0
	_dry_t = -1.0
	_warned.clear()
	queue_redraw()


func step(delta: float) -> void:
	_t += delta
	if not slip.is_empty():
		slip["t"] += delta
		if slip.get("call", false) and slip["t"] > 4.5:
			tow_home()
	var p: Ship = main.player
	if not is_instance_valid(p) or not p.alive:
		return
	var was := outside
	outside = p.global_position.length() > radius
	if outside and not was:
		if not Career.flags.get("beacon_told", false):
			Career.flags["beacon_told"] = true
			Career.say("Charlie", "You're off the beacons, captain. Every burn out there comes out of your own tank.", true)
		else:
			main.show_message("Off the beacons. Burning reserve.", 2.5)
	elif was and not outside:
		main.show_message("Back on the beacons. Reserve refilling.", 2.0)
	if outside:
		var burn := clampf(p.thrust_out.length(), 0.0, 1.0)
		reserve = maxf(0.0, reserve - burn * delta / TANK_SECONDS)
		for mark in [0.5, 0.25]:
			if reserve <= mark and not _warned.has(mark):
				_warned[mark] = true
				Career.say("Charlie", "Reserve's at half, captain. That's your turn-back point." if mark == 0.5 else "Quarter tank. I mean it. Come home.", true)
	elif _dry_t < 0.0:
		reserve = minf(1.0, reserve + REFILL * delta)
		if reserve >= 1.0:
			_warned.clear()
	if reserve <= 0.0 and outside:
		# Dry: engines starve. You drift; turrets still work off the batteries.
		p.ion_t = maxf(p.ion_t, 0.25)
		if _dry_t < 0.0:
			_dry_t = 0.0
			main.show_message("Reserve dry. Engines starved.", 3.0)
		_dry_t += delta
		if _dry_t > 2.0 and not _warned.has("tow"):
			_warned["tow"] = true
			var n := int(Career.flags.get("tows", 0))
			Career.say("Charlie", ["Tow's on the way. It's going on the lien. Sorry, hon.", "Again? ...Tow's coming. Same fee.", "I'm sending the tow. My supervisor's asking about you, captain."][mini(n, 2)], true)
		if _dry_t > 7.0 and slip.is_empty():
			Career.flags["tows"] = int(Career.flags.get("tows", 0)) + 1
			Career.loan_balance += TOW_FEE
			Career.changed.emit()
			slip = {"fee": TOW_FEE, "n": int(Career.flags["tows"]), "t": 0.0}
		if not slip.is_empty() and slip["t"] > 4.5:
			tow_home()


## A tow for a rig that's dead in space inside the ring (losing.md): same slip, same fee.
func bill_tow(what: String) -> void:
	Career.flags["tows"] = int(Career.flags.get("tows", 0)) + 1
	Career.loan_balance += TOW_FEE
	Career.changed.emit()
	slip = {"fee": TOW_FEE, "n": int(Career.flags["tows"]), "t": 0.0, "what": what, "call": true}


## The tug drops you at the nearest berth in the system.
func tow_home() -> void:
	var p: Ship = main.player
	var best := ""
	var bd := INF
	for sid in Data.stations:
		var st: Dictionary = Data.stations[sid]
		if st["system"] != main.system_id:
			continue
		var d := p.global_position.distance_to(st["pos"])
		if d < bd:
			bd = d
			best = sid
	_dry_t = -1.0
	reserve = 1.0
	outside = false
	p.ion_t = 0.0
	if p.disabled:
		p.recover()
	slip = {}
	if best == "":
		return
	var st: Dictionary = Data.stations[best]
	p.global_position = st["pos"] + Vector2(0, 160)
	p.velocity = Vector2.ZERO
	for e in main.escorts:
		if is_instance_valid(e):
			e.global_position = p.global_position + Vector2(randf_range(-160, 160), randf_range(80, 200))
			e.velocity = Vector2.ZERO
	main.camera.global_position = p.global_position
	main.dock(best)


func _process(_delta: float) -> void:
	queue_redraw()


## The ring itself: a faint dashed circle, labelled where it crosses the axes.
func _draw() -> void:
	var col := Color(0.55, 0.75, 0.9, 0.16)
	var cam: Vector2 = main.camera.global_position if main.camera else Vector2.ZERO
	var n := 360
	for i in n:
		if i % 2 == 1:
			continue
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var q0 := Vector2(cos(a0), sin(a0)) * radius
		if q0.distance_to(cam) > 2600.0:
			continue
		draw_line(q0, Vector2(cos(a1), sin(a1)) * radius, col, 3.0)
	var f: Font = Data.font_type_bold
	for k in 8:
		var a := TAU * k / 8.0 + 0.2
		var q := Vector2(cos(a), sin(a)) * (radius - 40.0)
		if q.distance_to(cam) > 2600.0:
			continue
		draw_set_transform(q, a + PI * 0.5, Vector2.ONE)
		var s := "BEACON RANGE"
		draw_string(f, Vector2(-f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 21).x * 0.5, 0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color(0.55, 0.75, 0.9, 0.3))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
