class_name AIController
extends RefCounted
## AI pilot. Fighters make gun runs (attack, overshoot, extend, come back).
## Gunships hold at range and orbit, letting turrets do the work.
## Escorts (team 0) follow the fleet's formation and tactic orders.

var ship: Ship
var main: Node
var slot_index := 0
var target: Ship = null
var _state := "attack"
var _state_t := 0.0
var _retarget_t := 0.0
var _orbit_dir := 1.0
var freelance := false ## fight on its own instead of following fleet orders


func _init(p_ship: Ship, p_main: Node) -> void:
	ship = p_ship
	main = p_main
	_orbit_dir = 1.0 if randf() < 0.5 else -1.0


func update(delta: float) -> void:
	_retarget_t -= delta
	_state_t -= delta
	if ship.team == 0 and not freelance:
		_update_escort(delta)
	else:
		_update_hostile(delta)


# --- Escorts -------------------------------------------------------------
# Orders land through each pilot's temper: steady hands obey at once, Fay
# second-guesses for a beat, Mersham finishes the kill before he lets go.

var obeyed := "engage"   ## the order this pilot is actually flying
var _heard := "engage"
var _obey_t := 0.0
var _bait_phase := ""
var _bait_dir := Vector2.RIGHT


func temper() -> String:
	if ship.captain_id != "":
		return str(Data.captains.get(ship.captain_id, {}).get("temper", "steady"))
	return "steady"


## True while the pilot has the new order but hasn't acted on it yet.
func pending() -> bool:
	return obeyed != _heard


func _hear(delta: float) -> void:
	var o: String = main.fleet_order
	if o != _heard:
		_heard = o
		match temper():
			"hesitant":
				_obey_t = randf_range(1.2, 2.0)
			"presses":
				# Won't break off a target that's nearly dead.
				var pulling_back: bool = o in ["break", "hold", "screen"]
				_obey_t = 2.5 if pulling_back and _valid(target) and target.hull_hp < target.max_hull * 0.45 else 0.0
			_:
				_obey_t = 0.3
	if obeyed != _heard:
		_obey_t -= delta
		if _obey_t <= 0.0:
			obeyed = _heard


func start_bait() -> void:
	_bait_phase = "go"


func _update_escort(delta: float) -> void:
	_hear(delta)
	var leader: Ship = main.player
	var order := obeyed
	if leader == null or not is_instance_valid(leader):
		order = "engage"
	if order == "bait" and ship != main.bait_ship:
		order = "engage"

	match order:
		"bait":
			_bait(delta, leader)
			return
		"focus":
			if is_instance_valid(main.focus_target) and main.focus_target.alive:
				target = main.focus_target
			else:
				order = "engage"
		"screen":
			# Anything coming at you gets met; nothing else is our business.
			if _retarget_t <= 0.0 or not _valid(target):
				target = main.threat_to_player(700.0)
				_retarget_t = 0.5
			if _valid(target) and _valid(leader) and ship.global_position.distance_to(leader.global_position) > 900.0:
				target = null
		"hold", "break":
			target = null
	if order == "engage":
		var reach := 2000.0 if temper() == "presses" else 1600.0
		if _retarget_t <= 0.0 or not _valid(target):
			var center := leader.global_position if _valid(leader) else ship.global_position
			target = main.nearest_enemy(ship.team, ship.global_position, reach, center)
			_retarget_t = 1.0

	if _valid(target):
		_attack(delta, target)
		return

	# Formation (or nothing to fight): fly to our slot, shoot what comes in range.
	if _valid(leader):
		var slot: Vector2 = main.formation_slot(slot_index)
		_fly_to(slot, leader.velocity, main.fleet_heading)
	var opportunistic = main.nearest_enemy(ship.team, ship.global_position, ship.max_range())
	_shoot_at(opportunistic)


## Run in, get their attention, then drag them away from the captain.
func _bait(delta: float, leader: Ship) -> void:
	var foe = main.nearest_enemy(ship.team, ship.global_position, 2600.0, leader.global_position if _valid(leader) else ship.global_position)
	if not _valid(foe):
		_bait_phase = ""
		if _valid(leader):
			_fly_to(main.formation_slot(slot_index), leader.velocity, main.fleet_heading)
		return
	if _bait_phase == "":
		_bait_phase = "go"
	if _bait_phase == "go":
		_fly_to(foe.global_position, foe.velocity, (foe.global_position - ship.global_position).angle())
		_shoot_at(foe)
		if ship.global_position.distance_to(foe.global_position) < 520.0:
			_bait_phase = "drag"
			var away: Vector2 = (foe.global_position - leader.global_position).normalized() if _valid(leader) else Vector2.RIGHT
			_bait_dir = away.rotated((0.8 if randf() < 0.5 else -0.8))
		return
	# Drag: burn away, jinking, guns on whoever follows.
	var run_to := ship.global_position + _bait_dir * 900.0
	_fly_to(run_to, _bait_dir * ship.max_speed, _bait_dir.angle())
	ship.in_move.y = clampf(ship.in_move.y + sin(Time.get_ticks_msec() * 0.005) * 0.7, -1.0, 1.0)
	_shoot_at(main.nearest_enemy(ship.team, ship.global_position, ship.max_range()))


# --- Hostiles ------------------------------------------------------------

func _update_hostile(delta: float) -> void:
	if _retarget_t <= 0.0 or not _valid(target):
		target = main.nearest_enemy(ship.team, ship.global_position, 2600.0)
		_retarget_t = 1.5
		# A wingman flying bait under your nose is hard to ignore.
		var bait = main.get("bait_ship")
		if ship.team == 1 and _valid(bait) and main.fleet_order == "bait" and ship.global_position.distance_to(bait.global_position) < 1500.0:
			target = bait
	if _valid(target):
		_attack(delta, target)
	else:
		# Nothing to fight: kill the drift and wait.
		ship.in_move = Vector2.ZERO
		ship.in_turn = 0.0
		ship.in_brake = true
		_set_fire(false)


# --- Behaviours ----------------------------------------------------------

func _attack(_delta: float, t: Ship) -> void:
	var to_t := t.global_position - ship.global_position
	var dist := to_t.length()
	var lead := _lead_point(t)
	ship.aim_point = lead
	ship.in_brake = false
	_set_fire(dist < ship.max_range() * 1.05)

	if ship.def["role"] in ["gunship", "freighter"]:
		# Orbit at turret range, nose roughly toward the target for any forward guns.
		var keep := ship.max_range() * 0.65
		var radial := (ship.global_position - t.global_position).normalized()
		var orbit_point := t.global_position + radial.rotated(0.5 * _orbit_dir) * keep
		_fly_to(orbit_point, t.velocity, (lead - ship.global_position).angle())
		_jink()
		return

	# Fighter gun runs.
	if _state == "extend":
		var away := (-to_t).normalized().rotated(0.6 * _orbit_dir)
		_face(away.angle())
		ship.in_move = Vector2(1.0, 0.0)
		if _state_t <= 0.0 or dist > ship.max_range() * 0.9:
			_state = "attack"
		return
	_face((lead - ship.global_position).angle())
	var facing_err := absf(wrapf((lead - ship.global_position).angle() - ship.rotation, -PI, PI))
	# Main engine toward the target; side thrusters cancel drift across the line of attack.
	var want_vel := t.velocity + to_t.normalized() * ship.max_speed
	var local_dv := (want_vel - ship.velocity).rotated(-ship.rotation)
	var fwd := 1.0 if facing_err < 0.6 and dist > 140.0 else 0.3
	ship.in_move = Vector2(fwd, clampf(local_dv.y / 150.0, -1.0, 1.0))
	_jink()
	if dist < 150.0 + ship.radius + t.radius:
		_state = "extend"
		_state_t = randf_range(0.8, 1.4)
		_orbit_dir = -_orbit_dir


## Ace pilots weave with their side thrusters when they've been shot at recently.
func _jink() -> void:
	if not ship.ace or ship.since_hit > 3.0:
		return
	var w := sin(Time.get_ticks_msec() * 0.004 + ship.get_instance_id() % 7) * 0.9
	ship.in_move.y = clampf(ship.in_move.y + w, -1.0, 1.0)


func _shoot_at(t: Ship) -> void:
	if _valid(t):
		ship.aim_point = _lead_point(t)
		_set_fire(true)
	else:
		ship.aim_point = ship.global_position + ship.forward() * 200.0
		_set_fire(false)


func _set_fire(on: bool) -> void:
	ship.in_fire_aimed = on
	ship.in_fire_fixed = on


## Steer toward a point while matching a reference velocity; settle facing rest_heading.
## With no drag the AI has to burn against its own drift, using every thruster it has.
func _fly_to(point: Vector2, match_vel: Vector2, rest_heading: float) -> void:
	ship.in_brake = false
	var offset := point - ship.global_position
	var desired := match_vel + offset.limit_length(ship.max_speed) * 1.6
	desired = desired.limit_length(ship.max_speed)
	var dv := desired - ship.velocity
	if dv.length() < 15.0 and offset.length() < 40.0:
		_face(rest_heading)
		ship.in_move = Vector2.ZERO
		return
	# Big corrections: point the main engine at the burn. Small ones: keep facing
	# where we want to and trim with the maneuvering thrusters.
	if dv.length() > 160.0:
		_face(dv.angle())
	else:
		_face(rest_heading)
	var local := dv.rotated(-ship.rotation)
	var cap_x := ship.accel if local.x > 0.0 else ship.reverse_accel
	ship.in_move = Vector2(clampf(local.x / (cap_x * 0.25), -1.0, 1.0),
		clampf(local.y / (ship.side_accel * 0.25), -1.0, 1.0))


func _face(angle: float) -> void:
	var diff := wrapf(angle - ship.rotation, -PI, PI)
	ship.in_turn = clampf(diff / (ship.turn_rate * 0.08), -1.0, 1.0)


## Where to aim so a projectile meets the target, using relative velocity.
func _lead_point(t: Ship) -> Vector2:
	var speed := 800.0
	for m in ship.mounts:
		speed = m["weapon"]["speed"]
		break
	var rel_pos := t.global_position - ship.global_position
	var rel_vel := t.velocity - ship.velocity
	var time := rel_pos.length() / speed
	for i in 2:
		time = (rel_pos + rel_vel * time).length() / speed
	return t.global_position + rel_vel * time


func _valid(s) -> bool:
	return s != null and is_instance_valid(s) and s.alive
