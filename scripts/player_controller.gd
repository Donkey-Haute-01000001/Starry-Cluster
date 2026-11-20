class_name PlayerController
extends RefCounted
## Ship-relative flight: W/S forward and back, A/D strafe, Q/E turn, X brake assist.
## The camera never rotates. The mouse aims turrets and gimbals.
## Left click fires aimable weapons, Space fires the forward cannons.

var ship: Ship
var main: Node
static var assist := true        ## V toggles: thrusters damp drift
static var mouse_steer := true   ## M toggles: the ship turns to face the cursor
static var music_vol := 0.8      ## 0..1, the Music bus
static var sfx_vol := 1.0        ## 0..1, the SFX bus
static var fullscreen := false
const SETTINGS_PATH := "user://settings.cfg"


static func setting(key: String) -> bool:
	return assist if key == "assist" else mouse_steer


static func vol(key: String) -> float:
	return music_vol if key == "music_vol" else sfx_vol


static func set_vol(key: String, v: float) -> void:
	if key == "music_vol":
		music_vol = v
	else:
		sfx_vol = v
	save_settings()


static func toggle(key: String) -> bool:
	if key == "assist":
		assist = not assist
	else:
		mouse_steer = not mouse_steer
	save_settings()
	return setting(key)


static func save_settings() -> void:
	var c := ConfigFile.new()
	c.set_value("flight", "assist", assist)
	c.set_value("flight", "mouse_steer", mouse_steer)
	c.set_value("audio", "music", music_vol)
	c.set_value("audio", "sfx", sfx_vol)
	c.set_value("video", "fullscreen", fullscreen)
	c.save(SETTINGS_PATH)
	apply_settings()


## Push audio levels and window mode to the engine. Buses are made on first use.
static func apply_settings() -> void:
	for pair in [["Music", music_vol], ["SFX", sfx_vol]]:
		var i := AudioServer.get_bus_index(pair[0])
		if i < 0:
			AudioServer.add_bus()
			i = AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, pair[0])
			AudioServer.set_bus_send(i, "Master")
		var v: float = pair[1]
		AudioServer.set_bus_mute(i, v <= 0.001)
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.001)))
	if DisplayServer.get_name() != "headless":
		var want := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != want and not (not fullscreen and DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MAXIMIZED):
			DisplayServer.window_set_mode(want)


static func load_settings() -> void:
	var c := ConfigFile.new()
	if c.load(SETTINGS_PATH) == OK:
		assist = c.get_value("flight", "assist", true)
		mouse_steer = c.get_value("flight", "mouse_steer", true)
		music_vol = c.get_value("audio", "music", 0.8)
		sfx_vol = c.get_value("audio", "sfx", 1.0)
		fullscreen = c.get_value("video", "fullscreen", false)
	apply_settings()


func _init(p_ship: Ship, p_main: Node) -> void:
	ship = p_ship
	main = p_main


## Autopilot (G): flies to this body, cruising when the lane is open, and
## brakes into dock range. Any stick input hands control back.
var autopilot: Node2D = null


func manual_input() -> bool:
	for a in ["thrust_forward", "thrust_back", "strafe_left", "strafe_right", "turn_left", "turn_right", "brake"]:
		if Input.is_action_pressed(a):
			return true
	return false


func _fly_autopilot() -> void:
	var to: Vector2 = autopilot.global_position - ship.global_position
	var dist := to.length()
	var stop_at: float = autopilot.interact_range() * 0.45
	var dir := to / maxf(dist, 1.0)
	# Flip and burn: the main engine brakes far harder than the reverse
	# thrusters, so when we're coming in hot, turn tail and fire it.
	var along := ship.velocity.dot(dir)
	var side := ship.velocity - dir * along
	var flip_time := PI / ship.turn_rate + 0.3
	var room := maxf(dist - stop_at - along * flip_time, 0.0)
	var ok_speed := sqrt(2.0 * ship.accel * 0.8 * room) + 25.0
	ship.assist = true
	ship.aim_point = autopilot.global_position
	ship.in_move = Vector2.ZERO
	ship.in_brake = false
	var face := dir.angle()
	if along > ok_speed and along > 90.0:
		face = (-ship.velocity).angle()
	var diff := wrapf(face - ship.rotation, -PI, PI)
	ship.in_turn = clampf(diff / deg_to_rad(12.0), -1.0, 1.0)
	if dist < stop_at:
		ship.in_brake = true
	elif absf(diff) < deg_to_rad(20.0) and (face != dir.angle() or along <= ok_speed):
		ship.in_move.x = 1.0
	elif along > ok_speed:
		ship.in_brake = true
	# Trim sideways drift with the side thrusters.
	var lat := side.rotated(-ship.rotation).y
	if absf(lat) > 8.0:
		ship.in_move.y = clampf(-lat / 60.0, -1.0, 1.0)


func update(_delta: float) -> void:
	if autopilot != null:
		if not is_instance_valid(autopilot) or manual_input():
			autopilot = null
			main.autopilot_off("Autopilot off.")
		else:
			_fly_autopilot()
			var free0: bool = not main.wheel_open()
			ship.in_fire_aimed = free0 and Input.is_action_pressed("fire_aimed")
			ship.in_fire_fixed = free0 and Input.is_action_pressed("fire_fixed")
			ship.in_fire_secondary = free0 and Input.is_action_pressed("fire_secondary")
			if ship.in_fire_aimed or ship.in_fire_secondary:
				ship.aim_point = main.mouse_world()
			return
	var move := Vector2.ZERO
	if Input.is_action_pressed("thrust_forward"):
		move.x += 1.0
	if Input.is_action_pressed("thrust_back"):
		move.x -= 1.0
	if Input.is_action_pressed("strafe_right"):
		move.y += 1.0
	if Input.is_action_pressed("strafe_left"):
		move.y -= 1.0
	ship.in_move = move

	var turn := 0.0
	if Input.is_action_pressed("turn_left"):
		turn -= 1.0
	if Input.is_action_pressed("turn_right"):
		turn += 1.0
	if turn == 0.0 and mouse_steer and not main.wheel_open():
		# Turn toward the cursor, easing in over the last few degrees so the
		# nose settles instead of wobbling.
		var want: float = (main.mouse_world() - ship.global_position).angle()
		var diff := wrapf(want - ship.rotation, -PI, PI)
		turn = clampf(diff / deg_to_rad(12.0), -1.0, 1.0)
	ship.in_turn = turn
	ship.assist = assist
	ship.in_brake = Input.is_action_pressed("brake")

	ship.aim_point = main.mouse_world()
	var free: bool = not main.wheel_open()
	ship.in_fire_aimed = free and Input.is_action_pressed("fire_aimed")
	ship.in_fire_fixed = free and Input.is_action_pressed("fire_fixed")
	ship.in_fire_secondary = free and Input.is_action_pressed("fire_secondary")
