class_name Ship
extends Node2D
## A ship: flight physics, shields and hull, weapon mounts and drawing.
## A controller (player input or AI) sets the in_* inputs each physics tick.

signal disabled_now(ship)
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
var accel := 300.0            ## main engine (forward) acceleration
var side_accel := 100.0       ## maneuvering thrusters, sideways
var reverse_accel := 100.0    ## maneuvering thrusters, backwards
var max_speed := 300.0        ## hard cap; thrust past it only changes direction
var turn_rate := 3.0
var max_energy := 200.0
var energy := 200.0
var energy_regen := 50.0
var radius := 20.0
var mounts: Array = []
var alive := true
var display_name := ""        ## shown on the roster instead of the hull name
var is_friend := false        ## the old friend's ship
var captain_id := ""          ## a hired bar captain's ship (Data.captains)
var ace := false              ## jinks under fire (pilot friend)
var accuracy := 1.0           ## multiplies weapon spread (gunner friend: lower is better)
var traverse_mult := 1.0      ## multiplies turret traverse speed
var ion_t := 0.0              ## seconds left with engines knocked out by an ion hit
var hull_floor := 0.0         ## story ships: hull never drops below this fraction
var hold_fire := false        ## story: guns cold (ceasefire, hails)
var damage_taken := 0.0       ## running total, for scenes that score a fight
var cruise_on := false        ## cruise drive wanted: spools up, weapons offline
var cruise_k := 0.0           ## 0..1 spool
var cruise_cap := 1400.0      ## top cruise speed here, set by main from nearby mass
const CRUISE_SPOOL := 2.0
const CRUISE_DROP := 0.7
var disabled := false         ## dead in space below DISABLE_AT hull: drifts, can't fire, can be boarded
const DISABLE_AT := 0.15

# Inputs, written by the controller.
var in_move := Vector2.ZERO   ## ship-relative thrust: x forward(+)/back(-), y right(+)/left(-), each -1..1
var in_turn := 0.0            ## -1..1
var in_brake := false         ## brake assist: fire whichever thrusters oppose the drift
var in_fire_aimed := false    ## turrets (and gimbals) at the aim point
var in_fire_fixed := false    ## forward cannons
var aim_point := Vector2.ZERO ## world-space point turrets and gimbals aim at

## Thrust actually produced last tick, ship-relative and 0..1 per axis, for drawing.
var thrust_out := Vector2.ZERO

const THRUST_ENERGY := 12.0   ## energy per second at full main-engine thrust
const SHIELD_ENERGY := 0.5    ## energy per point of shield recharged

var _shield_flash := 0.0
var _hull_flash := 0.0
var _anim_t := 0.0
var _fired_t := 9.0   ## seconds since a gun last fired, for weapon animations


func setup(id: String, p_team: int, p_main: Node) -> void:
	hull_id = id
	def = Data.hulls[id]
	# Some hulls come in several models; each ship picks one.
	if not def.get("layered_alts", []).is_empty():
		def = def.duplicate()
		var la: Array = def["layered_alts"]
		def["layered"] = {"dir": la[randi() % la.size()]}
	if not def.get("sprite_alts", []).is_empty():
		def = def.duplicate()
		var alts: Array = def["sprite_alts"]
		def["sprite"] = alts[randi() % alts.size()]
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if def.has("layered"):
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if def.has("livery"):
		var art_rel: String = "ships/%s/base.png" % def["layered"]["dir"] if def.has("layered") else "ships/%s.png" % def.get("sprite", "")
		material = Art.livery(Data.liveries.get(def["livery"], []), get_instance_id(), Art.main_hue(art_rel))
	team = p_team
	main = p_main
	max_hull = def["hull"]
	hull_hp = max_hull
	max_shields = def["shields"]
	shields = max_shields
	shield_regen = def["shield_regen"]
	regen_delay = def["regen_delay"]
	accel = def["accel"]
	side_accel = accel * def["side_thrust"]
	reverse_accel = accel * def["reverse_thrust"]
	max_speed = def["max_speed"]
	max_energy = def["energy"]
	energy = max_energy
	energy_regen = def["energy_regen"]
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
	if disabled:
		in_move = Vector2.ZERO
		in_turn = 0.0
		in_fire_aimed = false
		in_fire_fixed = false
		velocity = velocity.move_toward(Vector2.ZERO, 12.0 * delta)
		if randf() < delta * 2.5:
			main.spawn_sparks(global_position + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * radius * 0.6, def["accent"], 3)
	elif controller:
		controller.update(delta)
	_anim_t += delta
	_fired_t += delta

	if cruise_on and (disabled or ion_t > 0.0):
		cruise_on = false
	cruise_k = move_toward(cruise_k, 1.0 if cruise_on else 0.0, delta / (CRUISE_SPOOL if cruise_on else CRUISE_DROP))
	energy = minf(max_energy, energy + energy_regen * delta)
	var turn := turn_rate * (0.3 if ion_t > 0.0 else 1.0)
	rotation = wrapf(rotation + clampf(in_turn, -1.0, 1.0) * turn * delta, -PI, PI)
	if ion_t > 0.0:
		# Engines dead: no thrust at all, just a slow drift down.
		ion_t -= delta
		velocity = velocity.move_toward(Vector2.ZERO, 20.0 * delta)
		thrust_out = Vector2.ZERO
	else:
		_apply_thrust(delta)
	position += velocity * delta

	# Shields recharge after a short delay without taking hits, paid for with energy.
	since_hit += delta
	if since_hit > regen_delay and shields < max_shields:
		var amount := minf(minf(max_shields - shields, shield_regen * delta), energy / SHIELD_ENERGY)
		shields += amount
		energy -= amount * SHIELD_ENERGY

	_update_weapons(delta)
	_shield_flash = maxf(0.0, _shield_flash - delta * 3.0)
	_hull_flash = maxf(0.0, _hull_flash - delta * 4.0)
	queue_redraw()


## Newtonian flight: no drag, so you coast until you burn against your motion.
## Every ship has a strong main engine and weaker side and reverse thrusters,
## always relative to where the ship points.
func _apply_thrust(delta: float) -> void:
	var cmd := Vector2(clampf(in_move.x, -1.0, 1.0), clampf(in_move.y, -1.0, 1.0))
	if in_brake and velocity.length() > 1.0:
		# Brake assist uses the real thrusters: each axis pushes against the drift,
		# so a ship facing its motion brakes slowly and one facing away brakes fast.
		var local := (-velocity).rotated(-rotation)
		var cap_x := accel if local.x > 0.0 else reverse_accel
		var bx := clampf(local.x / maxf(cap_x * delta, 0.001), -1.0, 1.0)
		var by := clampf(local.y / maxf(side_accel * delta, 0.001), -1.0, 1.0)
		if cmd.x == 0.0:
			cmd.x = bx
		if cmd.y == 0.0:
			cmd.y = by
	var a := Vector2(cmd.x * (accel if cmd.x > 0.0 else reverse_accel), cmd.y * side_accel)
	a *= 1.0 + 4.0 * cruise_k
	# Thrusters draw on the reactor. On an empty bar they still fire at half power.
	var draw := (absf(a.x) + absf(a.y)) / accel * THRUST_ENERGY * delta
	var power := 1.0
	if draw > 0.0:
		if energy >= draw:
			energy -= draw
		else:
			power = 0.5
			energy = 0.0
	velocity += a.rotated(rotation) * power * delta
	# Hard top speed: thrust past it only changes direction, never adds speed.
	velocity = velocity.limit_length(lerpf(max_speed, maxf(cruise_cap, max_speed), cruise_k))
	thrust_out = thrust_out.lerp(cmd * power, clampf(12.0 * delta, 0.0, 1.0))


func _update_weapons(delta: float) -> void:
	for m in mounts:
		m["cooldown"] -= delta
		var w: Dictionary = m["weapon"]
		var world_pos: Vector2 = to_global(m["pos"])
		var desired_local: float = wrapf((aim_point - world_pos).angle() - rotation, -PI, PI)
		var firing := in_fire_aimed
		if w["kind"] == "turret":
			m["angle"] = rotate_toward(m["angle"], desired_local, deg_to_rad(w["traverse"]) * traverse_mult * delta)
		else:
			var g := deg_to_rad(w["gimbal"])
			m["angle"] = rotate_toward(m["angle"], clampf(desired_local, -g, g), deg_to_rad(240.0) * delta)
			firing = in_fire_fixed
		if not firing or hold_fire or cruise_k > 0.0 or m["cooldown"] > 0.0:
			continue
		# The AI only fires a mount when it is actually lined up and in range.
		if not is_player:
			var dist := world_pos.distance_to(aim_point)
			if dist > w["range"] * 1.05:
				continue
			var tol := deg_to_rad(6.0) if w["kind"] == "turret" else deg_to_rad(w["gimbal"] + 4.0)
			if absf(wrapf(desired_local - m["angle"], -PI, PI)) > tol:
				continue
		var cost: float = w.get("energy", 0.0)
		if energy < cost:
			continue
		energy -= cost
		m["cooldown"] = w["cooldown"]
		var dir: float = rotation + m["angle"] + deg_to_rad(randf_range(-w["spread"], w["spread"]) * accuracy)
		main.spawn_projectile(world_pos, dir, w, self)
		_fired_t = 0.0


func take_damage(amount: float, hit_pos: Vector2) -> void:
	if not alive:
		return
	since_hit = 0.0
	damage_taken += amount
	if shields > 0.0:
		var absorbed := minf(shields, amount)
		shields -= absorbed
		amount -= absorbed
		_shield_flash = 1.0
	if amount > 0.0:
		hull_hp -= amount
		_hull_flash = 1.0
		main.spawn_sparks(hit_pos, def["accent"], 4)
	if hull_floor > 0.0:
		hull_hp = maxf(hull_hp, max_hull * hull_floor)
	if hull_hp <= 0.0:
		die()
	elif not disabled and not is_player and team != 0 and hull_hp <= max_hull * DISABLE_AT:
		_disable()


## Below DISABLE_AT hull the ship goes dead in space. Keep shooting and it dies.
func _disable() -> void:
	disabled = true
	hold_fire = true
	shields = 0.0
	max_shields = 0.0
	main.spawn_sparks(global_position, def["accent"], 14)
	Sfx.play("hiss", -4.0, 0.7)
	disabled_now.emit(self)


## An ion bolt: shields soak a little, then the engines go dead for a while.
func ion_hit(seconds: float) -> void:
	ion_t = maxf(ion_t, seconds)
	shields = maxf(0.0, shields - max_shields * 0.5)
	_shield_flash = 1.0


func die() -> void:
	if not alive:
		return
	alive = false
	main.spawn_explosion(global_position, radius, velocity)
	# Void fleet ships break apart in their own frames.
	if def.has("layered"):
		var t := Art.tex("ships/%s/destruction.png" % def["layered"]["dir"])
		if t:
			var wreck := Wreck.new()
			wreck.tex = t
			wreck.global_position = global_position
			wreck.rotation = rotation + PI * 0.5
			var u := Art.used_rect("ships/%s/base.png" % def["layered"]["dir"])
			var k: float = radius * float(def.get("sprite_scale", 3.6)) / maxf(maxf(u.size.x, u.size.y), 1.0)
			wreck.scale = Vector2(k, k)
			wreck.velocity = velocity
			wreck.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			main.add_child(wreck)
	destroyed.emit(self)
	queue_free()


func _draw() -> void:
	var shape := PackedVector2Array(def["shape"])
	var col: Color = def["color"]
	var accent: Color = def["accent"]
	# Engine flames for the main engine, small puffs for maneuvering thrusters.
	_draw_rcs(accent)
	var main_t := maxf(thrust_out.x, 0.0)
	if main_t > 0.05 and not def.has("layered"):
		for e in def["engines"]:
			var length := (10.0 + radius * 0.6) * main_t * randf_range(0.8, 1.15)
			var ep: Vector2 = e
			draw_colored_polygon(PackedVector2Array([ep + Vector2(0, -3), ep + Vector2(-length, 0), ep + Vector2(0, 3)]),
				Color(accent.r, accent.g, accent.b, 0.85))
			draw_colored_polygon(PackedVector2Array([ep + Vector2(0, -1.5), ep + Vector2(-length * 0.55, 0), ep + Vector2(0, 1.5)]),
				Color(1, 1, 0.9, 0.9))
	# Hull: the sprite when the art is installed, otherwise the polygon.
	var sprite: String = def.get("sprite", "")
	var flash := Color(1, 1, 1).lerp(Color(1, 0.45, 0.4), _hull_flash * 0.7)
	if def.has("layered"):
		_draw_layered(def["layered"], flash)
	elif sprite != "" and Art.draw_fit(self, "ships/%s.png" % sprite, radius * def.get("sprite_scale", 3.6), flash):
		for m in mounts:
			if m["weapon"]["kind"] == "turret":
				var p: Vector2 = m["pos"]
				draw_line(p, p + Vector2.RIGHT.rotated(m["angle"]) * 9.0, col.lightened(0.6), 2.0)
	else:
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
	# Ion crackle while the engines are dead.
	if ion_t > 0.0:
		for k in 3:
			var a0 := randf() * TAU
			draw_arc(Vector2.ZERO, radius * randf_range(0.6, 1.1), a0, a0 + randf_range(0.4, 1.0), 6, Color(0.7, 0.55, 1.0, 0.8), 1.5)
	# Shield shimmer when hit.
	if _shield_flash > 0.0 and shields > 0.0:
		draw_arc(Vector2.ZERO, radius + 6.0, 0.0, TAU, 32, Color(0.4, 0.75, 1.0, 0.6 * _shield_flash), 2.0, true)


## Small jets on the hull edges: nose jets for reverse thrust, flank jets for strafing.
func _draw_rcs(accent: Color) -> void:
	var col := Color(accent.r, accent.g, accent.b, 0.7)
	var jets: Array = []
	if thrust_out.x < -0.05:
		var k := -thrust_out.x
		jets.append([Vector2(radius * 0.7, -radius * 0.35), Vector2(1, -0.3), k])
		jets.append([Vector2(radius * 0.7, radius * 0.35), Vector2(1, 0.3), k])
	if absf(thrust_out.y) > 0.05:
		# Pushing right (+y) fires jets on the left flank (-y side), and vice versa.
		var side := -signf(thrust_out.y)
		var k := absf(thrust_out.y)
		jets.append([Vector2(radius * 0.3, side * radius * 0.6), Vector2(0, side), k])
		jets.append([Vector2(-radius * 0.5, side * radius * 0.6), Vector2(0, side), k])
	for j in jets:
		var p: Vector2 = j[0]
		var d: Vector2 = (j[1] as Vector2).normalized()
		var length := (4.0 + radius * 0.35) * float(j[2]) * randf_range(0.7, 1.2)
		var n := d.orthogonal() * 2.0
		draw_colored_polygon(PackedVector2Array([p + n, p + d * length, p - n]), col)


## Modular pixel ships (Foozle's Void packs): an animated engine strip that
## idles or roars with thrust, the hull (in damage states when the art has
## them), the weapon strip that plays when it fires, and the shield strip when
## it takes a hit. Art is nose-up; ours is nose-right.
func _draw_layered(spec: Dictionary, flash: Color) -> void:
	var dir: String = "ships/" + spec["dir"]
	var frac := hull_hp / maxf(max_hull, 1.0)
	var state := 0 if frac > 0.75 else (1 if frac > 0.5 else (2 if frac > 0.25 else 3))
	var base := Art.tex("%s/base_%d.png" % [dir, state])
	if base == null:
		base = Art.tex(dir + "/base.png")
	if base == null:
		return
	# Fit the visible hull, not the padded frame, to the ship's size.
	var u := Art.used_rect(dir + "/base.png" if Art.tex(dir + "/base.png") else dir + "/base_0.png")
	var span := maxf(u.size.x, u.size.y) if u.size != Vector2.ZERO else float(base.get_height())
	var k: float = radius * float(def.get("sprite_scale", 3.6)) / span
	draw_set_transform(Vector2.ZERO, PI * 0.5, Vector2(k, k))
	var thrusting: bool = thrust_out.x > 0.05
	# Engine: the Void main ship has idle/power flame strips; fleet ships one strip.
	var flame := Art.tex("%s/flame_%s_%s.png" % [dir, spec.get("engine", ""), "power" if thrusting else "idle"])
	if flame == null:
		flame = Art.tex(dir + "/engine.png")
	if flame:
		_strip(flame, int(_anim_t * (14.0 if thrusting else 7.0)), Color(1, 1, 1, 1.0 if thrusting else 0.6))
	var eng := Art.tex("%s/engine_%s.png" % [dir, spec.get("engine", "")])
	if eng:
		draw_texture_rect(eng, Rect2(-eng.get_size() * 0.5, eng.get_size()), false, flash)
	draw_texture_rect(base, Rect2(-base.get_size() * 0.5, base.get_size()), false, flash)
	var w := Art.tex("%s/weapon_%s.png" % [dir, spec["weapon"]]) if spec.has("weapon") else Art.tex(dir + "/weapons.png")
	if w:
		var n := _frames_in(w)
		_strip(w, mini(int(_fired_t * 20.0), n - 1) if _fired_t < 1.0 else 0, flash)
	if _shield_flash > 0.0:
		var sh := Art.tex(dir + "/shield.png")
		if sh:
			_strip(sh, int((1.0 - _shield_flash) * _frames_in(sh)), Color(1, 1, 1, _shield_flash))
	draw_set_transform(Vector2.ZERO)


func _frames_in(t: Texture2D) -> int:
	return maxi(1, roundi(float(t.get_width()) / float(t.get_height())))


## Draws frame `f` of a square-frame strip, centered.
func _strip(t: Texture2D, f: int, mod: Color) -> void:
	var n := _frames_in(t)
	var c := float(t.get_width()) / n
	var h := float(t.get_height())
	draw_texture_rect_region(t, Rect2(Vector2(-c, -h) * 0.5, Vector2(c, h)), Rect2((f % n) * c, 0, c, h), mod)


## A destroyed Void ship's break-up animation, drifting with the wreck.
class Wreck extends Node2D:
	var tex: Texture2D
	var velocity := Vector2.ZERO
	var t := 0.0
	func _process(delta: float) -> void:
		t += delta
		position += velocity * delta
		velocity *= 0.98
		var n := maxi(1, roundi(float(tex.get_width()) / tex.get_height()))
		if int(t * 12.0) >= n:
			queue_free()
		queue_redraw()
	func _draw() -> void:
		var n := maxi(1, roundi(float(tex.get_width()) / tex.get_height()))
		var c := float(tex.get_width()) / n
		var h := float(tex.get_height())
		draw_texture_rect_region(tex, Rect2(Vector2(-c, -h) * 0.5, Vector2(c, h)), Rect2(mini(int(t * 12.0), n - 1) * c, 0, c, h))
