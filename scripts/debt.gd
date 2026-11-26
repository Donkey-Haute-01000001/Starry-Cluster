class_name Debt
extends RefCounted
## What the lien does to you in flight. Two missed payments and Charter
## Recovery sends a cutter: it ions your engines, boards, and takes the cargo.
## Jump out and it loses you for a while; pay the overdue and it's called off.
## Also navy customs: patrols scan rigs that come close, and sealed crates
## from the no-questions job don't pass.

const RECOVERY := 3            ## team: hostile to you and your wing, nobody else
const SCAN_RANGE := 650.0
const SCAN_TIME := 4.0
const CATCH_RANGE := 380.0

var main: Node
var cutter: Ship = null
var slip := {}                 ## repossession notice on screen: {seized, took, fee, t}
var scan := {}                 ## {"by": Ship, "k": 0..1} while a patrol is scanning you
var _hunt_t := -1.0
var _caught_t := -1.0
var _scanned := {}             ## patrol instance id -> true once they've cleared you


func _init(p_main: Node) -> void:
	main = p_main


func on_load() -> void:
	cutter = null
	scan = {}
	_scanned.clear()
	_caught_t = -1.0
	# A hunted rig gets a little head start in each new system.
	_hunt_t = randf_range(70.0, 120.0) if Career.strikes >= 2 else -1.0


func step(delta: float) -> void:
	if not slip.is_empty():
		slip["t"] += delta
		if slip["t"] > 4.5:
			slip = {}
			main.edge.tow_home()
		return
	var p: Ship = main.player
	if not is_instance_valid(p) or not p.alive or main.docked_at != "":
		return
	_hunt_step(delta, p)
	_scan_step(delta, p)


# --- The repo cutter ---------------------------------------------------------

func _hunt_step(delta: float, p: Ship) -> void:
	if Career.strikes < 2:
		if is_instance_valid(cutter):
			# Called off mid-chase.
			cutter.controller = Traffic.Leaving.new(cutter, main)
			cutter = null
		_hunt_t = -1.0
		return
	if not is_instance_valid(cutter):
		if _hunt_t < 0.0:
			_hunt_t = randf_range(70.0, 120.0)
		_hunt_t -= delta
		if _hunt_t <= 0.0 and not main.in_combat:
			_send_cutter(p)
		return
	if not cutter.alive:
		cutter = null
		return
	if cutter.disabled:
		# Driven off: it limps away and the company bills you for it.
		Career.obstruct()
		Career.say("Charter Recovery", Data.recovery["driven_off"], true)
		cutter.disabled = false
		cutter.team = 2
		cutter.controller = Traffic.Leaving.new(cutter, main)
		cutter = null
		_hunt_t = randf_range(150.0, 220.0)
		return
	# Caught: engines ioned and the cutter alongside.
	if (p.ion_t > 0.0 or p.disabled) and cutter.global_position.distance_to(p.global_position) < CATCH_RANGE:
		_caught_t = maxf(_caught_t, 0.0) + delta
		if _caught_t > 2.5:
			var r := Career.repossess()
			r["t"] = 0.0
			r["n"] = int(Career.flags.get("repos", 1))
			slip = r
			cutter.controller = Traffic.Leaving.new(cutter, main)
			cutter.team = 2
			cutter = null
	else:
		_caught_t = -1.0


func _send_cutter(p: Ship) -> void:
	# In from the beacon ring, on the far side of your heading.
	var dir := (-p.velocity).normalized() if p.velocity.length() > 50.0 else Vector2.RIGHT.rotated(randf() * TAU)
	var at := p.global_position + dir * 1900.0
	cutter = main.spawn_ship("repo_cutter", RECOVERY, at)
	cutter.display_name = "Charter Recovery"
	cutter.info = {"group": "recovery", "owner": "Charter Company", "job": "repossession"}
	cutter.controller = Cutter.new(cutter, main)
	# A full comms line, not the ticker: she's breaking the rules to tell you.
	Career.say("Charlie", Data.charlie["cutter_inbound"])
	Career.call_in("HAIL", "Charter Recovery", Data.recovery["hail"], cutter)


## Flies straight for your rig and nobody else: ion first, then guns.
class Cutter extends AIController:
	func update(delta: float) -> void:
		_retarget_t -= delta
		_state_t -= delta
		var p: Ship = main.player
		if not _valid(p):
			ship.in_move = Vector2.ZERO
			_set_fire(false)
			return
		target = p
		var to_p := p.global_position - ship.global_position
		ship.aim_point = _lead_point(p)
		# Close to boarding range and sit on the rig's quarter.
		var hold := p.global_position - to_p.normalized() * 220.0
		_fly_to(hold, p.velocity, to_p.angle())
		_set_fire(to_p.length() < 1400.0)


# --- Navy customs ----------------------------------------------------------

func _scan_step(delta: float, p: Ship) -> void:
	# Clean rigs get waved through without a fuss; only the crates make it a scene.
	if not Career.job_cargo.has("sealed"):
		scan = {}
		return
	var by: Ship = null
	var best := SCAN_RANGE
	for s in main.traffic.ships():
		if s.info.get("group") != "navy" or s.disabled:
			continue
		var d: float = s.global_position.distance_to(p.global_position)
		if d < best and not _scanned.has(s.get_instance_id()):
			best = d
			by = s
	if by == null:
		if not scan.is_empty():
			scan["k"] = maxf(0.0, scan["k"] - delta / SCAN_TIME)
			if scan["k"] <= 0.0:
				scan = {}
		return
	if scan.is_empty() or scan["by"] != by:
		scan = {"by": by, "k": 0.0}
		Career.call_in("HAIL", "Navy patrol", Data.customs["scan"], by)
	scan["k"] = minf(1.0, scan["k"] + delta / SCAN_TIME)
	if scan["k"] >= 1.0:
		_scanned[by.get_instance_id()] = true
		Career.customs_bust()
		scan = {}
