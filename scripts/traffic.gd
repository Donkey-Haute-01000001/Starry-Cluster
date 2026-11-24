class_name Traffic
extends Node
## The March going about its business. Freighters run the lanes the economy
## implies (Data.traffic), patrols loop, warships keep station. In rough
## systems raiders jump a rig now and then; what you do about it is yours.
## Team 2 is neutral: nobody's escort, nobody's enemy but the raiders'.

const NEUTRAL := 2
const DOCK_RANGE := 170.0
const PACE := 0.5                ## scales every route's departure interval
const JUMP_RANGE := 160.0

var main: Node
var _route_t: Array = []         ## seconds to each route's next departure
var _incident_t := 60.0
var incident := {}               ## the raid in progress, if any
var _wrecks := {}                ## system id -> [{pos, name, good, tons}]
var _wreck_nodes: Array = []
var _used_names := {}


func _init(p_main: Node) -> void:
	main = p_main


func _sys() -> Dictionary:
	return Data.traffic.get(main.system_id, {})


func ships() -> Array:
	var out: Array = []
	for s in main.get_tree().get_nodes_in_group("traffic"):
		if is_instance_valid(s) and s.alive:
			out.append(s)
	return out


# --- Places ----------------------------------------------------------------------

## A route endpoint ("drip", "@tiberine") as a point in the loaded system.
func place(key: String) -> Vector2:
	if key.begins_with("@"):
		for j in Data.systems[main.system_id]["jumps"]:
			if j["to"] == key.substr(1):
				return j["pos"]
		return Vector2.ZERO
	return Data.stations[key]["pos"]


## Straight lines, bent around any planet in the way.
func path(a: Vector2, b: Vector2) -> Array:
	var pts := [a]
	for body in Data.systems[main.system_id]["bodies"]:
		if body["kind"] != "planet":
			continue
		var c: Vector2 = body["pos"]
		var r: float = body["radius"] + 320.0
		var ab := b - a
		var t := clampf((c - a).dot(ab) / maxf(ab.length_squared(), 1.0), 0.0, 1.0)
		var near := a + ab * t
		if near.distance_to(c) < r and t > 0.05 and t < 0.95:
			var side := (near - c).normalized() if near.distance_to(c) > 1.0 else ab.orthogonal().normalized()
			pts.append(c + side * r * 1.15)
	pts.append(b)
	return pts


func _name(group: String) -> String:
	var pool: Array = Data.traffic_names.get(group, ["Unknown"])
	for i in 6:
		var n: String = pool[randi() % pool.size()]
		if not _used_names.has(n):
			_used_names[n] = true
			return n
	return pool[randi() % pool.size()]


# --- Loading a system -------------------------------------------------------------

func on_load() -> void:
	_used_names.clear()
	incident = {}
	var sys := _sys()
	_incident_t = randf_range(35.0, 60.0)
	_route_t.clear()
	if sys.is_empty():
		return
	var routes: Array = sys["routes"]
	for i in routes.size():
		_route_t.append(randf_range(0.1, 1.0) * float(routes[i][5]) * PACE)
	# The lanes are already busy when you arrive: seed ships part-way along.
	var seeded := 0
	var order := range(routes.size())
	order.shuffle()
	for pass_k in 2:
		for i in order:
			if seeded >= int(sys["cap"]) - 3:
				break
			if pass_k == 0 or randf() < 0.5:
				_launch(routes[i], randf_range(0.1, 0.45) if pass_k == 0 else randf_range(0.55, 0.9))
				seeded += 1
	for p in sys["patrols"]:
		var pts: Array = []
		for k in p[0]:
			pts.append(place(k))
		var lead: Ship = null
		for j in p[1].size():
			var s := _spawn(p[1][j], "navy", pts[0] + Vector2(randf_range(-200, 200), randf_range(-200, 200)))
			s.info["job"] = "patrol"
			var pilot := Pilot.new(s, main, self)
			pilot.loop = pts
			pilot.leg = randi() % pts.size()
			s.global_position = pts[pilot.leg] + Vector2(randf_range(-300, 300), randf_range(-300, 300))
			if lead:
				pilot.wing_of = lead
				s.global_position = lead.global_position + Vector2(-120, 90)
			else:
				lead = s
			s.controller = pilot
	for h in sys["holds"]:
		var s := _spawn(h[1], h[2], h[0])
		s.info["job"] = "working the claim" if h[2] == "compact" else "holding the gate"
		var pilot := Pilot.new(s, main, self)
		pilot.hold = h[0]
		s.controller = pilot
	for w in _wrecks.get(main.system_id, []):
		_add_wreck_node(w)


func _spawn(hull: String, group: String, at: Vector2) -> Ship:
	var s: Ship = main.spawn_ship(hull, NEUTRAL, at, randf() * TAU)
	s.add_to_group("traffic")
	var key := group
	if hull in ["charter_hauler", "ore_barge"]:
		key = hull
	s.display_name = _name(key)
	s.info = {"group": key, "owner": Data.traffic_owner.get(key, ""), "job": ""}
	return s


## One departure along a route, `progress` of the way there already.
func _launch(r: Array, progress := 0.0) -> Ship:
	var a := place(r[0])
	var b := place(r[1])
	var pts := path(a, b)
	# Keep right: each direction has its own lane, a little apart.
	var side := (b - a).normalized().orthogonal() * (130.0 + randf_range(-40.0, 40.0))
	if pts.size() == 2:
		pts.insert(1, a.lerp(b, 0.85))
	for i in range(1, pts.size() - 1):
		pts[i] += side
	var start: Vector2 = (a + side).lerp(pts[1], progress)
	if progress <= 0.0:
		# Out of a station's berth, or through the rift.
		start = a + (b - a).normalized() * (220.0 if not str(r[0]).begins_with("@") else 300.0)
		if str(r[0]).begins_with("@"):
			main.spawn_sparks(start, Color(0.6, 0.85, 1.0), 18)
	var s := _spawn(r[2], r[3], start)
	var dest_name: String = _place_name(r[1])
	s.info["job"] = ("%s to %s" % [Data.goods[r[4]]["name"].to_lower(), dest_name]) if r[4] != "" else ("passing through to %s" % dest_name if r[3] == "navy" else "empty, back to %s" % dest_name)
	s.info["good"] = r[4]
	s.info["tons"] = 0 if r[4] == "" else randi_range(14, 30)
	var pilot := Pilot.new(s, main, self)
	pilot.route = pts.slice(1)
	pilot.end_kind = "jump" if str(r[1]).begins_with("@") else "dock"
	pilot.end_at = b
	s.controller = pilot
	var dir: Vector2 = (pilot.route[0] - start).normalized()
	s.rotation = dir.angle()
	s.velocity = dir * s.max_speed * (0.55 if progress > 0.0 else 0.15)
	return s


func _place_name(key: String) -> String:
	if key.begins_with("@"):
		var to := key.substr(1)
		return "the Crossroads" if to == "crossroads" else Data.systems[to]["name"]
	return str(Data.stations[key]["nick"])


# --- Every frame ------------------------------------------------------------------

func step(delta: float) -> void:
	var sys := _sys()
	if sys.is_empty():
		return
	var routes: Array = sys["routes"]
	var n := ships().size()
	for i in routes.size():
		_route_t[i] -= delta
		if _route_t[i] <= 0.0:
			_route_t[i] = float(routes[i][5]) * PACE * randf_range(0.8, 1.25)
			if n < int(sys["cap"]):
				_launch(routes[i])
				n += 1
	_incident_step(delta)


# --- Raids --------------------------------------------------------------------

func _incident_step(delta: float) -> void:
	var danger: float = Data.systems[main.system_id]["danger"]
	if incident.is_empty():
		if danger <= 0.0 or main.story.busy():
			return
		_incident_t -= delta
		if _incident_t <= 0.0:
			_incident_t = randf_range(80.0, 130.0) / danger
			_start_raid()
		return
	incident["t"] += delta
	var victim: Ship = incident["victim"]
	var raiders: Array = incident["raiders"].filter(func(r): return is_instance_valid(r) and r.alive and not r.disabled)
	var near_player: bool = is_instance_valid(main.player) and is_instance_valid(victim) and main.player.global_position.distance_to(victim.global_position) < 2200.0
	if near_player:
		incident["player_near"] = true
	# The Navy cutter comes, eventually.
	if not incident["navy_sent"] and incident["t"] > incident["navy_at"]:
		incident["navy_sent"] = true
		for s in ships():
			if s.info.get("group") == "navy" and s.controller is Pilot and is_instance_valid(victim):
				s.controller.respond = victim.global_position
	if not is_instance_valid(victim) or not victim.alive:
		_end_raid("destroyed")
	elif victim.disabled:
		if incident["kind"] == "petty":
			if incident["robbed_t"] < 0.0:
				incident["robbed_t"] = incident["t"]
				Career.say(victim.display_name, Data.hails["robbed"], true)
				for r in raiders:
					r.controller = Leaving.new(r, main)
			elif incident["t"] - incident["robbed_t"] > 25.0:
				# Patched up enough to limp home.
				victim.disabled = false
				victim.hold_fire = false
				victim.hull_hp = victim.max_hull * 0.3
				victim.info["tons"] = 0
				victim.info["job"] = "limping home, hold empty"
				_end_raid("robbed")
		elif incident["robbed_t"] < 0.0:
			# Sponsored crews don't leave rigs to limp home. They leave wrecks.
			incident["robbed_t"] = incident["t"]
		elif incident["t"] - incident["robbed_t"] > 12.0:
			# Stripping the hold takes a while. That's your window.
			victim.die()
	elif raiders.is_empty():
		_end_raid("saved")
	elif incident["t"] > 150.0:
		_end_raid("timeout")


func _start_raid() -> void:
	var pool: Array = ships().filter(func(s): return s.info.get("group") in ["charter", "ore_barge", "compact"] and not s.disabled and s.controller is Pilot and not s.controller.leaving)
	if pool.is_empty():
		return
	# Raiders hunt the lanes, not the stations: pick a rig out in the open.
	pool.shuffle()
	var victim: Ship = pool[0]
	var roll := randf()
	var kind := "petty"
	var hulls := ["raider"] if randf() < 0.6 else ["raider", "raider"]
	if roll < 0.06:
		kind = "corsair"
		hulls = ["dynasty_corsair"]
	elif roll < 0.5:
		kind = "backed"
		hulls = ["backed_raider", "backed_raider"] if randf() < 0.5 else ["backed_raider"]
	var from := randf() * TAU
	var raiders: Array = []
	for h in hulls:
		var p: Vector2 = victim.global_position + Vector2.RIGHT.rotated(from) * 1500.0 + Vector2(randf_range(-120, 120), randf_range(-120, 120))
		var r: Ship = main.spawn_ship(h, 1, p, from + PI)
		r.controller = AIController.new(r, main)
		r.controller.target = victim
		r.info = {"group": "raider", "owner": "Dynasty corsair" if kind == "corsair" else "Pirate", "job": "hunting"}
		raiders.append(r)
	victim.controller.flee = true
	var where := _nearest_station_name(victim.global_position)
	incident = {"victim": victim, "raiders": raiders, "kind": kind, "t": 0.0, "navy_at": randf_range(45.0, 75.0),
		"navy_sent": false, "robbed_t": -1.0, "player_near": false, "player_hits": 0.0}
	Career.say(victim.display_name, Data.hails["mayday"] % [victim.display_name, where], true)


func _nearest_station_name(at: Vector2) -> String:
	var best := ""
	var bd := INF
	for sid in Data.stations:
		var st: Dictionary = Data.stations[sid]
		if st["system"] != main.system_id:
			continue
		var d := at.distance_to(st["pos"])
		if d < bd:
			bd = d
			best = st["nick"]
	return best


func _end_raid(how: String) -> void:
	if main._merchant_test:
		print("[raid] end %s t=%.1f raiders=%s" % [how, incident["t"], incident["raiders"].map(func(r): return [is_instance_valid(r), r.alive if is_instance_valid(r) else false, r.disabled if is_instance_valid(r) else false])])
	var victim = incident.get("victim")
	var player_helped := false
	for r in incident["raiders"]:
		if is_instance_valid(r) and r.player_damage > 0.0:
			player_helped = true
	match how:
		"saved":
			if is_instance_valid(victim):
				victim.controller.flee = false
				if player_helped:
					var reward := randi_range(2, 4) * 100
					Career.credits += reward
					Career.say(victim.display_name, Data.hails["thanks"] + " (+%s cr)" % Career.fmt(reward), true)
					Career.flags["rigs_saved"] = int(Career.flags.get("rigs_saved", 0)) + 1
					_dez("helped")
				else:
					Career.say(victim.display_name, Data.hails["thanks_navy"], true)
		"destroyed":
			if incident["player_near"] and not player_helped:
				_dez("ignored")
	for r in incident["raiders"]:
		if is_instance_valid(r) and r.alive and not (r.controller is Leaving):
			r.controller = Leaving.new(r, main)
	incident = {}


func _dez(key: String) -> void:
	if Career.friend_with_you():
		Career.say(str(Career.friend.get("name", "Dez")), Data.traffic_dez[key], true)


## A traffic ship died: if it carried cargo, the wreck stays where it fell.
func on_ship_destroyed(s: Ship) -> void:
	if not s.is_in_group("traffic"):
		return
	var w := {"pos": s.global_position, "name": s.display_name, "good": s.info.get("good", ""), "tons": int(s.info.get("tons", 0))}
	if not _wrecks.has(main.system_id):
		_wrecks[main.system_id] = []
	_wrecks[main.system_id].append(w)
	_add_wreck_node(w)


func _add_wreck_node(w: Dictionary) -> void:
	var n := Derelict.new()
	n.data = w
	n.position = w["pos"]
	main.world.add_child(n)
	_wreck_nodes.append(n)


## Leaving the system: wrecks stay on the books, their nodes go.
func clear() -> void:
	for n in _wreck_nodes:
		if is_instance_valid(n):
			n.queue_free()
	_wreck_nodes.clear()
	incident = {}


## The wreck in reach of the player, if any.
func wreck_near(at: Vector2) -> Node2D:
	for n in _wreck_nodes:
		if is_instance_valid(n) and n.data["tons"] > 0 and n.global_position.distance_to(at) < 220.0:
			return n
	return null


func loot(n: Node2D) -> void:
	var w: Dictionary = n.data
	var take := mini(int(w["tons"]), Career.cargo_free())
	if take <= 0 or w["good"] == "":
		main.show_message("Nothing worth taking." if w["good"] == "" else "Hold's full.", 2.0)
		return
	Career.cargo[w["good"]] = int(Career.cargo.get(w["good"], 0)) + take
	w["tons"] -= take
	Career.changed.emit()
	Sfx.play("dock", -8.0)
	main.show_message("Salvaged %d t of %s from the %s." % [take, Data.goods[w["good"]]["name"].to_lower(), w["name"]], 3.0)
	if not Career.flags.get("looted_once", false):
		Career.flags["looted_once"] = true
		_dez("looted")
	n.queue_redraw()


## Hail a ship: one line in its people's voice.
func hail(s: Ship) -> void:
	var g: String = s.info.get("group", "")
	if g == "raider":
		Career.say(s.display_name if s.display_name != "" else "Raider", "Cut your engines and we'll take the cargo, not the rig." if incident.get("kind", "") == "petty" else "...", true)
		return
	var lines: Array = Data.hails.get(g, ["..."])
	if s.display_name == Data.ahead["rig"] and Career.flags.get("ahead_robbed", false):
		Career.say(s.display_name, Data.ahead["hail"], true)
		return
	if s.controller is Pilot and s.controller.flee:
		Career.say(s.display_name, "Not now! Not now!", true)
		return
	Career.say(s.display_name, lines[randi() % lines.size()], true)


# --- Pilots ------------------------------------------------------------------

## Flies a traffic ship: along its route at an easy pace, round a patrol loop,
## or holding station. Flees raiders; the Navy fights them.
class Pilot extends RefCounted:
	var ship: Ship
	var main: Node
	var traffic: Traffic
	var ai: AIController
	var route: Array = []
	var end_kind := ""          ## "dock" or "jump"
	var end_at := Vector2.ZERO
	var loop: Array = []
	var leg := 0
	var hold = null             ## Vector2 to keep station at
	var wing_of: Ship = null
	var flee := false
	var respond = null          ## Vector2: the Navy heading for a raid
	var leaving := false
	var _leave_t := 0.0
	var _wait := 0.0
	var _engaged := false

	func _init(p_ship: Ship, p_main: Node, p_traffic: Traffic) -> void:
		ship = p_ship
		main = p_main
		traffic = p_traffic
		ai = AIController.new(ship, main)
		ai.freelance = true

	func update(delta: float) -> void:
		if leaving:
			_leave_t += delta
			ship.in_move = Vector2(0.3, 0) if end_kind == "jump" else Vector2.ZERO
			ship.in_brake = end_kind == "dock"
			ship.modulate.a = clampf(1.0 - _leave_t / 0.8, 0.0, 1.0)
			ship.scale = Vector2.ONE * lerpf(1.0, 0.6 if end_kind == "dock" else 1.4, clampf(_leave_t / 0.8, 0.0, 1.0))
			if _leave_t > 0.8:
				ship.remove_from_group("ships")
				ship.remove_from_group("traffic")
				ship.queue_free()
			return
		var g: String = ship.info.get("group", "")
		# Warships fight raiders in reach; the patrol answers a mayday.
		if g == "navy":
			# Stretched thin: they only see what's on top of them, unless answering a mayday.
			var foe: Ship = main.nearest_enemy(ship.team, ship.global_position, 2200.0 if respond != null or _engaged else 800.0)
			_engaged = foe != null
			if foe:
				ai.update(delta)
				return
			if respond != null:
				ai._fly_to(respond, Vector2.ZERO, ship.rotation)
				if ship.global_position.distance_to(respond) < 400.0:
					respond = null
				return
		ai._set_fire(false)
		if flee:
			var haven := _nearest_haven()
			ai._fly_to(haven, Vector2.ZERO, (haven - ship.global_position).angle())
			# Freighter turrets shoot back while they run.
			var foe2: Ship = main.nearest_enemy(ship.team, ship.global_position, ship.max_range())
			if foe2:
				ai._shoot_at(foe2)
			return
		if hold != null:
			var drift: Vector2 = hold + Vector2(cos(Time.get_ticks_msec() * 0.0002 + ship.get_instance_id()), sin(Time.get_ticks_msec() * 0.00017)) * 60.0
			ai._fly_to(drift, Vector2.ZERO, ship.rotation)
			return
		if wing_of != null:
			if is_instance_valid(wing_of) and wing_of.alive:
				var slot := wing_of.global_position + Vector2(-130, 100).rotated(wing_of.rotation)
				ai._fly_to(slot, wing_of.velocity, wing_of.rotation)
				return
			wing_of = null
		if not loop.is_empty():
			var p: Vector2 = loop[leg]
			_cruise_to(p, false)
			if ship.global_position.distance_to(p) < 350.0:
				leg = (leg + 1) % loop.size()
			return
		if route.is_empty():
			return
		var target: Vector2 = route[0]
		var last := route.size() == 1
		_cruise_to(target, last)
		var d := ship.global_position.distance_to(target)
		if not last and d < 300.0:
			route.pop_front()
		elif last and d < (160.0 if end_kind == "jump" else 230.0) and (end_kind == "jump" or ship.velocity.length() < 90.0):
			leaving = true
			if end_kind == "jump":
				main.spawn_sparks(ship.global_position, Color(0.6, 0.85, 1.0), 22)

	## Easy pace on the lanes; ease in when this is the last stop.
	func _cruise_to(p: Vector2, arrive: bool) -> void:
		var to := p - ship.global_position
		var pace := ship.max_speed * 0.62
		var v := to.normalized() * pace
		if arrive and end_kind == "dock":
			v = to.normalized() * minf(pace, to.length() * 0.45)
		ai._fly_to(ship.global_position + to.limit_length(120.0), v, to.angle())

	func _nearest_haven() -> Vector2:
		var best := ship.global_position
		var bd := INF
		for sid in Data.stations:
			var st: Dictionary = Data.stations[sid]
			if st["system"] != main.system_id:
				continue
			var d := ship.global_position.distance_to(st["pos"])
			if d < bd:
				bd = d
				best = st["pos"]
		return best


## Raiders done for the day: burn away and vanish in the rocks.
class Leaving extends RefCounted:
	var ship: Ship
	var main: Node
	var _t := 0.0
	var _dir := Vector2.ZERO

	func _init(p_ship: Ship, p_main: Node) -> void:
		ship = p_ship
		main = p_main
		_dir = (ship.global_position - Vector2.ZERO).normalized().rotated(randf_range(-0.5, 0.5))

	func update(delta: float) -> void:
		_t += delta
		ship.in_fire_aimed = false
		ship.in_fire_fixed = false
		var err := wrapf(_dir.angle() - ship.rotation, -PI, PI)
		ship.in_turn = clampf(err * 3.0, -1.0, 1.0)
		ship.in_move = Vector2(1.0 if absf(err) < 0.6 else 0.2, 0)
		if _t > 4.0:
			ship.modulate.a = clampf(1.0 - (_t - 4.0) / 1.5, 0.0, 1.0)
		if _t > 5.5:
			ship.remove_from_group("ships")
			ship.queue_free()


## What's left of a rig: tumbling plates, a cold beacon, and whatever was in the hold.
class Derelict extends Node2D:
	var data := {}
	var kind := "wreck"
	var _t := 0.0

	func interact_range() -> float:
		return 220.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(data.get("name", ""))
		for i in 9:
			var a := rng.randf() * TAU + _t * rng.randf_range(-0.08, 0.08)
			var d := rng.randf_range(4, 46)
			var c := Vector2(cos(a), sin(a)) * d
			var w := rng.randf_range(6, 18)
			var h := rng.randf_range(3, 9)
			draw_set_transform(c, a * 2.0 + _t * rng.randf_range(-0.3, 0.3), Vector2.ONE)
			draw_rect(Rect2(-w * 0.5, -h * 0.5, w, h), Color(0.28, 0.25, 0.22))
			draw_rect(Rect2(-w * 0.5, -h * 0.5, w, h), Color(0.86, 0.62, 0.18, 0.5), false, 1.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# Emergency beacon, still blinking.
		if fmod(_t, 2.0) < 0.2:
			draw_circle(Vector2.ZERO, 4.0, Color(1.0, 0.35, 0.2, 0.9))
		var f: Font = Data.font_type
		var label := "WRECK  ·  " + str(data.get("name", "")).to_upper()
		draw_string(f, Vector2(-f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x * 0.5, -62), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.85, 0.8, 0.7, 0.8))
		if int(data.get("tons", 0)) > 0 and data.get("good", "") != "":
			var sub := "%d t %s in the hold  ·  [F] salvage" % [data["tons"], Data.goods[data["good"]]["name"].to_lower()]
			draw_string(f, Vector2(-f.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x * 0.5, -46), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.75, 0.7, 0.6, 0.7))
