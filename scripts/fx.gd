extends Node2D
## Projectiles and particle effects, simulated in bulk and drawn in one pass.

var projectiles: Array = []
var particles: Array = []
var rings: Array = []
var puffs: Array = []        ## flak bursts
var arcs: Array = []         ## shield hit flares
var flashes: Array = []      ## hull hit flashes


var _tracer_n := 0


## `fuse`: flak rounds burst after travelling this far (the aim point).
func spawn_projectile(pos: Vector2, angle: float, w: Dictionary, shooter: Ship, fuse := -1.0, target: Ship = null) -> void:
	var dir := Vector2.RIGHT.rotated(angle)
	var flak: float = w.get("flak", 0.0)
	_tracer_n += 1
	projectiles.append({
		"pos": pos,
		# Shots inherit the firing ship's velocity, so leading targets matters.
		"vel": dir * w["speed"] + shooter.velocity,
		"life": (fuse if flak > 0.0 and fuse > 0.0 else w["range"]) / w["speed"],
		"flak": flak,
		"torp": w.get("torp", false),
		"blast": w.get("blast", 0.0),
		"turn": deg_to_rad(w.get("turn", 0.0)),
		"target": target,
		"speed": w["speed"],
		"tracer": w.get("tracer", false),
		"bright": _tracer_n % 3 == 0,
		"damage": w["damage"],
		"team": shooter.team,
		"color": w["color"],
		"size": w["size"],
		"ion": w.get("ion", 0.0),
	})
	particles.append({"pos": pos, "vel": shooter.velocity + dir * 60.0, "life": 0.08, "max": 0.08,
		"color": w["color"].lightened(0.5), "size": w["size"] + 2.0})


## A torpedo goes off: a real explosion, and splash on anything hostile nearby.
func _torp_blast(p: Dictionary, at: Vector2, ships: Array, direct: Ship) -> void:
	spawn_explosion(at, 9.0, Vector2.ZERO)
	Sfx.play_at("boom_small", at, -2.0, 1.2)
	for s in ships:
		var ship := s as Ship
		if ship == null or ship == direct or not ship.alive or ship.team == p["team"]:
			continue
		if ship.global_position.distance_to(at) < p["blast"] + ship.radius:
			ship.last_hit_team = p["team"]
			ship.take_damage(p["damage"] * 0.4, at)


## A flak round's fuze goes off: a small puff that chips everything hostile
## inside its radius.
func _flak_burst(p: Dictionary, ships: Array) -> void:
	var at: Vector2 = p["pos"]
	var r: float = p["flak"]
	for s in ships:
		var ship := s as Ship
		if ship == null or not ship.alive or ship.team == p["team"]:
			continue
		if ship.global_position.distance_to(at) < r + ship.radius:
			ship.last_hit_team = p["team"]
			ship.take_damage(p["damage"] * 0.7, at)
	# Flak also kills torpedoes flying through the burst.
	for q in projectiles:
		if q["torp"] and q["team"] != p["team"] and q["pos"].distance_to(at) < r + 6.0:
			q["life"] = 0.0
			q["torp"] = false
			spawn_sparks(q["pos"], Color(1.0, 0.6, 0.3), 10)
	for k in 4:
		var v := Vector2.RIGHT.rotated(randf() * TAU) * randf_range(20.0, 90.0)
		var life := randf_range(0.12, 0.28)
		particles.append({"pos": at, "vel": v + p["vel"] * 0.05, "life": life, "max": life,
			"color": Color(1.0, randf_range(0.55, 0.85), 0.3), "size": randf_range(1.5, 2.6)})
	puffs.append({"pos": at, "r": r, "life": 0.22, "max": 0.22})
	Sfx.play_at("flak", at, -12.0)


## Shield hit: a short bright arc on the bubble, facing the shot.
func spawn_shield_hit(at: Vector2, center: Vector2, r: float) -> void:
	arcs.append({"c": center, "r": r * 1.35, "a": (at - center).angle(), "life": 0.25, "max": 0.25})


## Hull hit: a white flash, hot sparks thrown back toward the shooter, and a
## couple of dark chunks of plating that tumble off.
func spawn_hull_hit(at: Vector2, center: Vector2, amount: float) -> void:
	var out := (at - center).normalized()
	var n := clampi(int(amount * 0.4) + 3, 3, 14)
	for i in n:
		var v := out.rotated(randf_range(-0.9, 0.9)) * randf_range(80.0, 320.0)
		var life := randf_range(0.12, 0.35)
		particles.append({"pos": at, "vel": v, "life": life, "max": life, "color": Color(1.0, randf_range(0.75, 1.0), 0.55), "size": randf_range(1.2, 2.4)})
	for i in clampi(int(amount / 12.0), 0, 3):
		var v := out.rotated(randf_range(-0.6, 0.6)) * randf_range(30.0, 110.0)
		var life := randf_range(1.2, 2.4)
		particles.append({"pos": at, "vel": v, "life": life, "max": life, "color": Color(0.32, 0.31, 0.3), "size": randf_range(2.5, 4.0)})
	flashes.append({"pos": at, "r": 6.0 + minf(amount, 40.0) * 0.4, "life": 0.08, "max": 0.08})


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
	flashes.append({"pos": pos, "r": radius * 3.0, "life": 0.12, "max": 0.12})
	# Wreckage: dark plates and glowing slag that drift and cool.
	for i in int(radius * 0.5) + 3:
		var v := base_vel * 0.6 + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(20.0, radius * 6.0)
		var life := randf_range(2.0, 4.0)
		var hot := randf() < 0.35
		particles.append({"pos": pos, "vel": v, "life": life, "max": life, "color": Color(1.0, 0.5, 0.2) if hot else Color(0.3, 0.29, 0.28), "size": randf_range(2.5, 5.5)})


func _physics_process(delta: float) -> void:
	var ships := get_tree().get_nodes_in_group("ships")
	var i := projectiles.size() - 1
	while i >= 0:
		var p: Dictionary = projectiles[i]
		var prev: Vector2 = p["pos"]
		if p["torp"]:
			# Homing: swing the nose toward the target, keep cruising speed.
			var tg = p["target"]
			var v: Vector2 = p["vel"]
			if tg != null and is_instance_valid(tg) and tg.alive:
				var want: float = (tg.global_position - prev).angle()
				v = Vector2.RIGHT.rotated(rotate_toward(v.angle(), want, p["turn"] * delta)) * maxf(v.length(), p["speed"])
			p["vel"] = v
			if randf() < 0.6:
				particles.append({"pos": prev, "vel": -v * 0.1, "life": 0.4, "max": 0.4, "color": Color(0.7, 0.68, 0.65), "size": 2.0})
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
				ship.last_hit_team = p["team"]
				ship.take_damage(p["damage"], closest)
				if p["torp"]:
					_torp_blast(p, closest, ships, ship)
				if p["ion"] > 0.0:
					ship.ion_hit(p["ion"])
				spawn_sparks(closest, p["color"], 3)
				hit = true
				break
		if not hit and p["life"] <= 0.0 and p["flak"] > 0.0:
			_flak_burst(p, ships)
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

	i = puffs.size() - 1
	while i >= 0:
		puffs[i]["life"] -= delta
		if puffs[i]["life"] <= 0.0:
			puffs.remove_at(i)
		i -= 1

	for arr in [arcs, flashes]:
		var j: int = arr.size() - 1
		while j >= 0:
			arr[j]["life"] -= delta
			if arr[j]["life"] <= 0.0:
				arr.remove_at(j)
			j -= 1

	i = rings.size() - 1
	while i >= 0:
		var r: Dictionary = rings[i]
		r["life"] -= delta
		if r["life"] <= 0.0:
			rings.remove_at(i)
		i -= 1
	queue_redraw()


func _draw() -> void:
	for f in flashes:
		var k: float = f["life"] / f["max"]
		draw_circle(f["pos"], f["r"] * (1.4 - 0.4 * k), Color(1.0, 0.95, 0.85, 0.35 * k))
		draw_circle(f["pos"], f["r"] * 0.45, Color(1, 1, 1, 0.9 * k))
	for a in arcs:
		var k: float = a["life"] / a["max"]
		var ang: float = a["a"]
		draw_arc(a["c"], a["r"], ang - 0.7, ang + 0.7, 14, Color(0.5, 0.85, 1.0, 0.85 * k), 3.0, true)
		draw_arc(a["c"], a["r"] + 3.0, ang - 0.45, ang + 0.45, 10, Color(0.8, 0.95, 1.0, 0.5 * k), 1.5, true)
	for r in rings:
		var t: float = 1.0 - r["life"] / r["max"]
		var rad: float = lerpf(r["r"], r["max_r"], t)
		draw_arc(r["pos"], rad, 0.0, TAU, 40, Color(1.0, 0.8, 0.5, 1.0 - t), 3.0, true)
		draw_arc(r["pos"], rad * 0.92, 0.0, TAU, 40, Color(0.5, 0.8, 1.0, 0.35 * (1.0 - t)), 8.0, true)
		if t < 0.35:
			var f := 1.0 - t / 0.35
			draw_circle(r["pos"], rad * 0.9, Color(1.0, 0.75, 0.4, 0.18 * f))
			draw_circle(r["pos"], rad * 0.5, Color(1.0, 0.9, 0.7, 0.45 * f))
			draw_circle(r["pos"], rad * 0.25, Color(1.0, 1.0, 0.95, 0.8 * f))
	for q in particles:
		var a: float = q["life"] / q["max"]
		var c: Color = q["color"]
		var sz: float = q["size"] * (0.5 + 0.5 * a)
		draw_circle(q["pos"], sz * 2.4, Color(c.r, c.g, c.b, a * 0.12))
		draw_circle(q["pos"], sz, Color(c.r, c.g, c.b, a))
	for f in puffs:
		var k: float = 1.0 - f["life"] / f["max"]
		var rad: float = f["r"] * (0.35 + 0.65 * k)
		draw_circle(f["pos"], rad, Color(1.0, 0.7, 0.35, 0.4 * (1.0 - k)))
		draw_circle(f["pos"], rad * 0.45, Color(1.0, 0.95, 0.75, 0.75 * (1.0 - k)))
		draw_arc(f["pos"], rad, 0.0, TAU, 16, Color(0.55, 0.5, 0.45, 0.55 * (1.0 - k)), 1.5)
	for p in projectiles:
		var v: Vector2 = p["vel"]
		if p["torp"]:
			var dt := v.normalized()
			draw_line(p["pos"] - dt * 12.0, p["pos"], Color(0.75, 0.72, 0.68), 4.0)
			draw_circle(p["pos"], 3.0, Color(1.0, 0.5, 0.3))
			draw_circle(p["pos"] - dt * 13.0, 4.0 + randf() * 2.0, Color(1.0, 0.8, 0.4, 0.6))
			continue
		if p["tracer"]:
			# Machine-gun tracer: a thin hot streak, every third round brighter.
			var d := v.normalized()
			var c2: Color = p["color"]
			var ln := 26.0 if p["bright"] else 16.0
			draw_line(p["pos"] - d * ln, p["pos"], Color(c2.r, c2.g, c2.b, 0.25), 5.0)
			draw_line(p["pos"] - d * ln, p["pos"], Color(c2.r, c2.g, c2.b, 1.0 if p["bright"] else 0.75), 2.6 if p["bright"] else 1.8)
			draw_line(p["pos"] - d * ln * 0.4, p["pos"], Color(1, 1, 0.9, 0.9), 1.2)
			continue
		var tail: Vector2 = p["pos"] - v.normalized() * (p["size"] * 5.0)
		var c: Color = p["color"]
		# Glowing bolt: a wide soft halo, the coloured body, then a hot white core.
		var long_tail: Vector2 = p["pos"] - v.normalized() * (p["size"] * 9.0)
		draw_line(long_tail, p["pos"], Color(c.r, c.g, c.b, 0.18), p["size"] * 3.2, true)
		draw_line(tail, p["pos"], c, p["size"], true)
		draw_line(tail.lerp(p["pos"], 0.5), p["pos"], Color(1, 1, 1, 0.9), maxf(1.0, p["size"] * 0.4), true)
		draw_circle(p["pos"], p["size"] * 1.6, Color(c.r, c.g, c.b, 0.25))
