extends Node2D
## Projectiles and particle effects, simulated in bulk and drawn in one pass.

var projectiles: Array = []
var particles: Array = []
var rings: Array = []


func spawn_projectile(pos: Vector2, angle: float, w: Dictionary, shooter: Ship) -> void:
	var dir := Vector2.RIGHT.rotated(angle)
	projectiles.append({
		"pos": pos,
		# Shots inherit the firing ship's velocity, so leading targets matters.
		"vel": dir * w["speed"] + shooter.velocity,
		"life": w["range"] / w["speed"],
		"damage": w["damage"],
		"team": shooter.team,
		"color": w["color"],
		"size": w["size"],
	})
	particles.append({"pos": pos, "vel": shooter.velocity + dir * 60.0, "life": 0.08, "max": 0.08,
		"color": w["color"].lightened(0.5), "size": w["size"] + 2.0})


func spawn_sparks(pos: Vector2, color: Color, count: int) -> void:
	for i in count:
		var v := Vector2.RIGHT.rotated(randf() * TAU) * randf_range(60.0, 220.0)
		var life := randf_range(0.15, 0.4)
		particles.append({"pos": pos, "vel": v, "life": life, "max": life, "color": color, "size": randf_range(1.5, 3.0)})


func spawn_explosion(pos: Vector2, radius: float, base_vel: Vector2) -> void:
	var count := int(radius * 2.0)
	for i in count:
		var v := base_vel * 0.5 + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(30.0, radius * 12.0)
		var life := randf_range(0.4, 1.2)
		var c := Color(1.0, randf_range(0.4, 0.9), randf_range(0.1, 0.4))
		particles.append({"pos": pos, "vel": v, "life": life, "max": life, "color": c, "size": randf_range(2.0, 5.0)})
	for i in int(radius * 0.6):
		var v := base_vel * 0.5 + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(10.0, 90.0)
		var life := randf_range(1.0, 2.2)
		particles.append({"pos": pos, "vel": v, "life": life, "max": life, "color": Color(0.45, 0.42, 0.4), "size": randf_range(2.0, 4.0)})
	rings.append({"pos": pos, "r": radius * 0.5, "max_r": radius * 5.0, "life": 0.45, "max": 0.45})


func _physics_process(delta: float) -> void:
	var ships := get_tree().get_nodes_in_group("ships")
	var i := projectiles.size() - 1
	while i >= 0:
		var p: Dictionary = projectiles[i]
		var prev: Vector2 = p["pos"]
		p["pos"] = prev + p["vel"] * delta
		p["life"] -= delta
		var hit := false
		for s in ships:
			var ship := s as Ship
			if ship == null or not ship.alive or ship.team == p["team"]:
				continue
			# Segment-vs-circle test so fast shots can't tunnel through small ships.
			var closest := Geometry2D.get_closest_point_to_segment(ship.global_position, prev, p["pos"])
			if closest.distance_squared_to(ship.global_position) < ship.radius * ship.radius:
				ship.take_damage(p["damage"], closest)
				spawn_sparks(closest, p["color"], 3)
				hit = true
				break
		if hit or p["life"] <= 0.0:
			projectiles.remove_at(i)
		i -= 1

	i = particles.size() - 1
	while i >= 0:
		var q: Dictionary = particles[i]
		q["pos"] += q["vel"] * delta
		q["vel"] *= 1.0 - 1.5 * delta
		q["life"] -= delta
		if q["life"] <= 0.0:
			particles.remove_at(i)
		i -= 1

	i = rings.size() - 1
	while i >= 0:
		var r: Dictionary = rings[i]
		r["life"] -= delta
		if r["life"] <= 0.0:
			rings.remove_at(i)
		i -= 1
	queue_redraw()


func _draw() -> void:
	for r in rings:
		var t: float = 1.0 - r["life"] / r["max"]
		var rad: float = lerpf(r["r"], r["max_r"], t)
		draw_arc(r["pos"], rad, 0.0, TAU, 40, Color(1.0, 0.8, 0.5, 1.0 - t), 3.0, true)
		if t < 0.3:
			draw_circle(r["pos"], rad * 0.6, Color(1.0, 0.95, 0.8, 0.6 * (1.0 - t / 0.3)))
	for q in particles:
		var a: float = q["life"] / q["max"]
		var c: Color = q["color"]
		draw_circle(q["pos"], q["size"] * (0.5 + 0.5 * a), Color(c.r, c.g, c.b, a))
	for p in projectiles:
		var v: Vector2 = p["vel"]
		var tail: Vector2 = p["pos"] - v.normalized() * (p["size"] * 5.0)
		var c: Color = p["color"]
		draw_line(tail, p["pos"], c, p["size"], true)
		draw_circle(p["pos"], p["size"] * 0.6, c.lightened(0.6))
