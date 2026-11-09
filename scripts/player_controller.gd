class_name PlayerController
extends RefCounted
## Keyboard flies the ship (rotate + thrust), the mouse aims turrets and gun gimbals.

var ship: Ship
var main: Node


func _init(p_ship: Ship, p_main: Node) -> void:
	ship = p_ship
	main = p_main


func update(_delta: float) -> void:
	var turn := 0.0
	if Input.is_action_pressed("turn_left"):
		turn -= 1.0
	if Input.is_action_pressed("turn_right"):
		turn += 1.0
	ship.in_thrust = 1.0 if Input.is_action_pressed("thrust") else 0.0

	# "Reverse" turns the ship to face against its motion, Endless Sky style,
	# so you can burn to slow down.
	if Input.is_action_pressed("reverse") and turn == 0.0 and ship.velocity.length() > 10.0:
		var want := (-ship.velocity).angle()
		var diff := wrapf(want - ship.rotation, -PI, PI)
		turn = clampf(diff / (ship.turn_rate * 0.08), -1.0, 1.0)
	ship.in_turn = turn

	ship.aim_point = main.mouse_world()
	ship.in_fire = Input.is_action_pressed("fire") and not main.wheel_open()
