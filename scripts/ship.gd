class_name Ship
extends Node2D
## A ship: flight physics, shields and hull, weapon mounts and drawing.
## A controller (player input or AI) sets the in_* inputs each physics tick.

signal destroyed(ship: Ship)

var hull_id := ""
var def: Dictionary = {}
var team := 0
var is_player := false
var main: Node = null
var controller: RefCounted = null

var velocity := Vector2.ZERO
var max_hull := 100.0
var hull_hp := 100.0
var max_shields := 0.0
var shields := 0.0
var shield_regen := 0.0
var regen_delay := 2.0
var since_hit := 99.0
var accel := 300.0
var max_speed := 300.0
var turn_rate := 3.0
var radius := 20.0
var mounts: Array = []
var alive := true

# Inputs, written by the controller.
var in_thrust := 0.0          ## 0..1 forward thrust
var in_turn := 0.0            ## -1..1
var in_fire := false
var aim_point := Vector2.ZERO ## world-space point turrets and gimbals aim at

var _shield_flash := 0.0
var _hull_flash := 0.0
var _flame := 0.0


func setup(id: String, p_team: int, p_main: Node) -> void:
	hull_id = id
	def = Data.hulls[id]
	team = p_team
	main = p_main
	max_hull = def["hull"]
	hull_hp = max_hull
	max_shields = def["shields"]
	shields = max_shields
	shield_regen = def["shield_regen"]
	regen_delay = def["regen_delay"]
	accel = def["accel"]
	max_speed = def["max_speed"]
	turn_rate = deg_to_rad(def["turn"])
	radius = def["radius"]
	mounts.clear()
	for m in def["mounts"]:
		var w: Dictionary = Data.weapons[m["weapon"]]
		mounts.append({"pos": m["pos"], "weapon": w, "angle": 0.0, "cooldown": randf() * 0.2})


func forward() -> Vector2:
	return Vector2.RIGHT.rotated(rotation)


func has_guns() -> bool:
	for m in mounts:
		if m["weapon"]["kind"] == "gun":
			return true
	return false


func max_range() -> float:
	var r := 0.0
	for m in mounts:
		r = max(r, m["weapon"]["range"])
	return r


func _physics_process(delta: float) -> void:
	if not alive:
		return
	if controller:
		controller.update(delta)

	# Flight: rotate and thrust with inertia, like a real ship in space.
	rotation = wrapf(rotation + clampf(in_turn, -1.0, 1.0) * turn_rate * delta, -PI, PI)
	if in_thrust > 0.0:
		velocity += forward() * accel * in_thrust * delta
	# Light drag so ships coast but settle, then a hard cap at top speed.
	velocity -= velocity * (accel / max_speed) * 0.12 * delta
	velocity = velocity.limit_length(max_speed)
	position += velocity * delta
	_flame = lerpf(_flame, in_thrust, 12.0 * delta)

	# Shields recharge after a short delay without taking hits.
	since_hit += delta
	if since_hit > regen_delay:
		shields = minf(max_shields, shields + shield_regen * delta)

	_update_weapons(delta)
	_shield_flash = maxf(0.0, _shield_flash - delta * 3.0)
	_hull_flash = maxf(0.0, _hull_flash - delta * 4.0)
	queue_redraw()


func _update_weapons(delta: float) -> void:
	for m in mounts:
		m["cooldown"] -= delta
		var w: Dictionary = m["weapon"]
		var world_pos: Vector2 = to_global(m["pos"])
		var desired_local: float = wrapf((aim_point - world_pos).angle() - rotation, -PI, PI)
		if w["kind"] == "turret":
			m["angle"] = rotate_toward(m["angle"], desired_local, deg_to_rad(w["traverse"]) * delta)
		else:
			var g := deg_to_rad(w["gimbal"])
			m["angle"] = rotate_toward(m["angle"], clampf(desired_local, -g, g), deg_to_rad(240.0) * delta)
		if not in_fire or m["cooldown"] > 0.0:
			continue
		# The AI only fires a mount when it is actually lined up and in range.
		if not is_player:
			var dist := world_pos.distance_to(aim_point)
			if dist > w["range"] * 1.05:
				continue
			var tol := deg_to_rad(6.0) if w["kind"] == "turret" else deg_to_rad(w["gimbal"] + 4.0)
			if absf(wrapf(desired_local - m["angle"], -PI, PI)) > tol:
				continue
		m["cooldown"] = w["cooldown"]
		var dir: float = rotation + m["angle"] + deg_to_rad(randf_range(-w["spread"], w["spread"]))
		main.spawn_projectile(world_pos, dir, w, self)


func take_damage(amount: float, hit_pos: Vector2) -> void:
	if not alive:
		return
	since_hit = 0.0
	if shields > 0.0:
		var absorbed := minf(shields, amount)
		shields -= absorbed
		amount -= absorbed
		_shield_flash = 1.0
	if amount > 0.0:
		hull_hp -= amount
		_hull_flash = 1.0
		main.spawn_sparks(hit_pos, def["accent"], 4)
	if hull_hp <= 0.0:
		die()


func die() -> void:
	if not alive:
		return
	alive = false
	main.spawn_explosion(global_position, radius, velocity)
	destroyed.emit(self)
	queue_free()


func _draw() -> void:
	var shape := PackedVector2Array(def["shape"])
	var col: Color = def["color"]
	var accent: Color = def["accent"]
	# Engine flames.
	if _flame > 0.05:
		for e in def["engines"]:
			var length := (10.0 + radius * 0.6) * _flame * randf_range(0.8, 1.15)
			var ep: Vector2 = e
			draw_colored_polygon(PackedVector2Array([ep + Vector2(0, -3), ep + Vector2(-length, 0), ep + Vector2(0, 3)]),
				Color(accent.r, accent.g, accent.b, 0.85))
			draw_colored_polygon(PackedVector2Array([ep + Vector2(0, -1.5), ep + Vector2(-length * 0.55, 0), ep + Vector2(0, 1.5)]),
				Color(1, 1, 0.9, 0.9))
	# Hull.
	var body := col.lerp(Color(1, 0.4, 0.3), _hull_flash * 0.6)
	draw_colored_polygon(shape, body)
	var outline := shape.duplicate()
	outline.append(shape[0])
	draw_polyline(outline, col.lightened(0.45), 1.5, true)
	draw_line(Vector2(-radius * 0.5, 0), Vector2(radius * 0.7, 0), col.darkened(0.3), 2.0)
	if is_player:
		draw_circle(Vector2(radius * 0.25, 0), 3.0, Color(0.8, 0.95, 1.0))
	# Mounts: turrets as domes with barrels, guns as short forward barrels.
	for m in mounts:
		var p: Vector2 = m["pos"]
		var a: float = m["angle"]
		if m["weapon"]["kind"] == "turret":
			draw_circle(p, 4.5, col.darkened(0.35))
			draw_line(p, p + Vector2.RIGHT.rotated(a) * 9.0, col.lightened(0.6), 2.0)
		else:
			draw_line(p, p + Vector2.RIGHT.rotated(a) * 7.0, col.lightened(0.5), 2.0)
	# Shield shimmer when hit.
	if _shield_flash > 0.0 and shields > 0.0:
		draw_arc(Vector2.ZERO, radius + 6.0, 0.0, TAU, 32, Color(0.4, 0.75, 1.0, 0.6 * _shield_flash), 2.0, true)
