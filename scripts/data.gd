extends Node
## Game content, kept as data so new ships and weapons are easy to add.
## Ships face +X (to the right) at rotation 0. Units: pixels, seconds, degrees.
## Hulls: "accel" is the main engine; "side_thrust" and "reverse_thrust" are the
## maneuvering thrusters as a fraction of it. "energy" is the built-in reactor's
## capacity and "energy_regen" its output per second. Weapons cost "energy" per shot.

var weapons := {
	# Fixed guns: fire straight ahead (with a small gimbal). Hit harder for the space they use.
	"pulse_cannon": {
		"name": "Pulse Cannon", "kind": "gun",
		"damage": 16.0, "cooldown": 0.16, "energy": 3.0, "speed": 1050.0, "range": 760.0,
		"gimbal": 8.0, "spread": 1.5, "color": Color(0.55, 0.9, 1.0), "size": 3.0,
	},
	"raider_gun": {
		"name": "Scrap Blaster", "kind": "gun",
		"damage": 9.0, "cooldown": 0.22, "energy": 2.0, "speed": 900.0, "range": 650.0,
		"gimbal": 5.0, "spread": 3.0, "color": Color(1.0, 0.55, 0.3), "size": 3.0,
	},
	# Turrets: rotate toward the aim point at a limited traverse speed.
	"light_turret": {
		"name": "Light Turret", "kind": "turret",
		"damage": 9.0, "cooldown": 0.2, "energy": 2.5, "speed": 820.0, "range": 640.0,
		"traverse": 200.0, "spread": 2.0, "color": Color(0.7, 1.0, 0.6), "size": 2.5,
	},
	"pirate_turret": {
		"name": "Rusty Turret", "kind": "turret",
		"damage": 8.0, "cooldown": 0.28, "energy": 2.0, "speed": 700.0, "range": 600.0,
		"traverse": 120.0, "spread": 4.0, "color": Color(1.0, 0.75, 0.35), "size": 2.5,
	},
}

var hulls := {
	"kestrel": {
		"name": "Kestrel Frigate", "role": "gunship",
		"hull": 650.0, "shields": 450.0, "shield_regen": 30.0, "regen_delay": 2.5,
		"accel": 300.0, "side_thrust": 0.35, "reverse_thrust": 0.35, "max_speed": 330.0, "turn": 150.0, "radius": 24.0,
		"energy": 260.0, "energy_regen": 50.0,
		"color": Color(0.55, 0.65, 0.8), "accent": Color(0.3, 0.8, 1.0),
		"shape": [Vector2(30, 0), Vector2(12, -10), Vector2(-4, -20), Vector2(-22, -18),
			Vector2(-16, -6), Vector2(-24, 0), Vector2(-16, 6), Vector2(-22, 18),
			Vector2(-4, 20), Vector2(12, 10)],
		"engines": [Vector2(-22, -11), Vector2(-22, 11)],
		"mounts": [
			{"pos": Vector2(18, -6), "weapon": "pulse_cannon"},
			{"pos": Vector2(18, 6), "weapon": "pulse_cannon"},
			{"pos": Vector2(-6, -11), "weapon": "light_turret"},
			{"pos": Vector2(-6, 11), "weapon": "light_turret"},
		],
	},
	"wasp": {
		"name": "Wasp Interceptor", "role": "fighter",
		"hull": 170.0, "shields": 120.0, "shield_regen": 18.0, "regen_delay": 2.0,
		"accel": 560.0, "side_thrust": 0.6, "reverse_thrust": 0.55, "max_speed": 470.0, "turn": 290.0, "radius": 13.0,
		"energy": 140.0, "energy_regen": 38.0,
		"color": Color(0.5, 0.7, 0.75), "accent": Color(0.3, 0.8, 1.0),
		"shape": [Vector2(16, 0), Vector2(-2, -5), Vector2(-10, -12), Vector2(-8, -3),
			Vector2(-12, 0), Vector2(-8, 3), Vector2(-10, 12), Vector2(-2, 5)],
		"engines": [Vector2(-12, 0)],
		"mounts": [
			{"pos": Vector2(6, -4), "weapon": "pulse_cannon"},
			{"pos": Vector2(6, 4), "weapon": "pulse_cannon"},
		],
	},
	"raider": {
		"name": "Pirate Raider", "role": "fighter",
		"hull": 140.0, "shields": 70.0, "shield_regen": 12.0, "regen_delay": 2.5,
		"accel": 480.0, "side_thrust": 0.5, "reverse_thrust": 0.45, "max_speed": 430.0, "turn": 250.0, "radius": 13.0,
		"energy": 120.0, "energy_regen": 30.0,
		"color": Color(0.6, 0.4, 0.35), "accent": Color(1.0, 0.45, 0.2),
		"shape": [Vector2(15, 0), Vector2(4, -4), Vector2(-4, -11), Vector2(-12, -9),
			Vector2(-8, 0), Vector2(-12, 9), Vector2(-4, 11), Vector2(4, 4)],
		"engines": [Vector2(-9, -5), Vector2(-9, 5)],
		"mounts": [
			{"pos": Vector2(6, -3), "weapon": "raider_gun"},
			{"pos": Vector2(6, 3), "weapon": "raider_gun"},
		],
	},
	"marauder": {
		"name": "Pirate Marauder", "role": "gunship",
		"hull": 520.0, "shields": 220.0, "shield_regen": 15.0, "regen_delay": 3.0,
		"accel": 210.0, "side_thrust": 0.25, "reverse_thrust": 0.3, "max_speed": 250.0, "turn": 100.0, "radius": 26.0,
		"energy": 220.0, "energy_regen": 35.0,
		"color": Color(0.5, 0.38, 0.32), "accent": Color(1.0, 0.45, 0.2),
		"shape": [Vector2(28, -6), Vector2(28, 6), Vector2(10, 14), Vector2(-10, 22),
			Vector2(-26, 16), Vector2(-20, 0), Vector2(-26, -16), Vector2(-10, -22),
			Vector2(10, -14)],
		"engines": [Vector2(-24, -9), Vector2(-24, 9)],
		"mounts": [
			{"pos": Vector2(24, 0), "weapon": "raider_gun"},
			{"pos": Vector2(2, -13), "weapon": "pirate_turret"},
			{"pos": Vector2(2, 13), "weapon": "pirate_turret"},
		],
	},
}
