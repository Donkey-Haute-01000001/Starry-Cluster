class_name PlayerController
extends RefCounted
## Ship-relative flight: W/S forward and back, A/D strafe, Q/E turn, X brake assist.
## The camera never rotates. The mouse aims turrets and gimbals.
## Left click fires aimable weapons, Space fires the forward cannons.

var ship: Ship
var main: Node
static var assist := true        ## V toggles: thrusters damp drift
static var mouse_steer := true   ## M toggles: the ship turns to face the cursor
const SETTINGS_PATH := "user://settings.cfg"


static func setting(key: String) -> bool:
	return assist if key == "assist" else mouse_steer


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
	c.save(SETTINGS_PATH)


static func load_settings() -> void:
	var c := ConfigFile.new()
	if c.load(SETTINGS_PATH) == OK:
		assist = c.get_value("flight", "assist", true)
		mouse_steer = c.get_value("flight", "mouse_steer", true)


func _init(p_ship: Ship, p_main: Node) -> void:
	ship = p_ship
	main = p_main


func update(_delta: float) -> void:
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
