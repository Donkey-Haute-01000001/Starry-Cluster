extends Node
## Game content, kept as data so new ships and weapons are easy to add.
## Ships face +X (to the right) at rotation 0. Units: pixels, seconds, degrees.
## Hulls: "accel" is the main engine; "side_thrust" and "reverse_thrust" are the
## maneuvering thrusters as a fraction of it. "energy" is the built-in reactor's
## capacity and "energy_regen" its output per second. Weapons cost "energy" per shot.

var mode := "sandbox"  ## "sandbox" (combat test) or "merchant" (the demo opening)

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
		"name": "Kestrel Frigate", "sprite": "raven", "role": "gunship",
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
	"light_freighter": {
		"name": "Light Freighter", "sprite": "cargo", "role": "freighter",
		"hull": 520.0, "shields": 260.0, "shield_regen": 18.0, "regen_delay": 3.0,
		"accel": 210.0, "side_thrust": 0.25, "reverse_thrust": 0.3, "max_speed": 290.0, "turn": 110.0, "radius": 24.0,
		"energy": 200.0, "energy_regen": 40.0, "cargo": 40,
		"color": Color(0.62, 0.6, 0.52), "accent": Color(1.0, 0.75, 0.35),
		"shape": [Vector2(26, -8), Vector2(26, 8), Vector2(18, 13), Vector2(-20, 13),
			Vector2(-26, 9), Vector2(-26, -9), Vector2(-20, -13), Vector2(18, -13)],
		"engines": [Vector2(-26, -6), Vector2(-26, 6)],
		"mounts": [
			{"pos": Vector2(4, 0), "weapon": "light_turret"},
		],
	},
	"wasp": {
		"name": "Wasp Interceptor", "sprite": "arachnid", "role": "fighter",
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
		"name": "Pirate Raider", "sprite": "crossbow", "role": "fighter",
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
		"name": "Pirate Marauder", "sprite": "bison", "role": "gunship",
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


# --- The Hesper March: the Merchant demo sector ----------------------------
# Every station makes what its geography makes cheap and pays well for what
# it can't make (comparative advantage). Names: imperial name, then nickname.

const MAKES_FACTOR := 0.8   ## price multiplier for goods a station makes
const WANTS_FACTOR := 1.25  ## price multiplier for goods a station needs

var goods := {
	"water": {"name": "Water", "slang": "wet", "base": 40,
		"desc": "Ice cut, melted and filtered. Everyone needs it; nobody pays much for it."},
	"rations": {"name": "Rations", "slang": "bricks", "base": 80,
		"desc": "Protein bricks in six flavors, all of them beige."},
	"ore": {"name": "Ore", "slang": "rock", "base": 60,
		"desc": "Raw belt ore, heavy and cheap, worth more the farther it travels."},
	"alloy": {"name": "Alloy", "slang": "plate", "base": 160,
		"desc": "Refined metal, the backbone of every hull and station."},
	"parts": {"name": "Machine parts", "slang": "guts", "base": 200,
		"desc": "Pumps, seals and spares. Always short, always needed."},
	"electronics": {"name": "Electronics", "slang": "chips", "base": 420,
		"desc": "Sensors, control boards and nav cores. Light, fragile and pricey."},
	"medicine": {"name": "Medicine", "slang": "meds", "base": 480,
		"desc": "Grown and pressed at the Greenhouse. Light, valuable and stolen often."},
	"luxuries": {"name": "Luxuries", "slang": "real coffee", "base": 900,
		"desc": "Silk, spirits and actual coffee from beyond the gate. The richest margins, for the people who can afford it."},
}
var goods_order := ["water", "rations", "ore", "alloy", "parts", "electronics", "medicine", "luxuries"]

var sector := {"name": "Hesper March", "nick": "the Long Haul"}

## Systems. "bodies" are scenery; "jumps" are natural rifts with gate stations,
## the only way between stars. "danger" sets pirate activity (0 = patrolled).
var systems := {
	"aurelia": {
		"name": "Aurelia", "nick": "the Plate", "security": "Core", "danger": 0.0,
		"desc": "Old industrial world with an ice moon. Factories, shipyard and water in one place; the safe home base.",
		"bodies": [
			{"kind": "planet", "pos": Vector2(0, 0), "radius": 420.0, "art": "laviria", "color": Color(0.42, 0.4, 0.38), "band": Color(0.55, 0.45, 0.35)},
			{"kind": "planet", "pos": Vector2(-2300, 1500), "radius": 130.0, "art": "glacia_glassa", "color": Color(0.75, 0.85, 0.95), "band": Color(0.6, 0.75, 0.9)},
		],
		"jumps": [
			{"to": "tiberine", "pos": Vector2(3600, -2100)},
			{"to": "marcellus", "pos": Vector2(-3200, -2600)},
		],
	},
	"tiberine": {
		"name": "Tiberine", "nick": "the Garden", "security": "Mid", "danger": 0.0,
		"desc": "Dry, sunny world farmed under domes. Feeds the sector, but has to import water and parts.",
		"bodies": [
			{"kind": "planet", "pos": Vector2(0, 0), "radius": 520.0, "art": "veriduna_sand", "color": Color(0.78, 0.62, 0.38), "band": Color(0.45, 0.6, 0.3)},
		],
		"jumps": [
			{"to": "aurelia", "pos": Vector2(-3300, 1900)},
			{"to": "porta_aquila", "pos": Vector2(3100, 2300)},
		],
	},
	"marcellus": {
		"name": "Marcellus", "nick": "the Grind", "security": "Rough", "danger": 1.0,
		"desc": "Asteroid belt, no water, no soil. Rich in ore, poor in everything else; pirates hide in the rocks.",
		"bodies": [
			{"kind": "belt", "pos": Vector2(0, 0), "radius": 2600.0, "width": 900.0, "color": Color(0.5, 0.45, 0.4)},
		],
		"jumps": [
			{"to": "aurelia", "pos": Vector2(-3600, -1900)},
			{"to": "porta_aquila", "pos": Vector2(3300, -2700)},
		],
	},
	"porta_aquila": {
		"name": "Porta Aquila", "nick": "the Wall", "security": "Fortress", "danger": 0.0,
		"desc": "Barren rock around the gate rift. Only there because of the gate; imports everything.",
		"bodies": [
			{"kind": "planet", "pos": Vector2(0, 0), "radius": 260.0, "art": "titus", "color": Color(0.4, 0.37, 0.36), "band": Color(0.3, 0.28, 0.28)},
		],
		"jumps": [
			{"to": "tiberine", "pos": Vector2(-3100, 1600)},
			{"to": "marcellus", "pos": Vector2(-2900, -1900)},
			{"to": "crossroads", "pos": Vector2(2700, 0), "locked": true},
		],
	},
}

var stations := {
	"counter": {"art": "hub", "art_size": 300.0, "name": "Aurelia Highport", "nick": "the Counter", "system": "aurelia", "pos": Vector2(760, -380),
		"makes": ["electronics"], "wants": ["luxuries", "medicine"],
		"desc": "Charter Company offices and the sector's busiest job board. Dispatch is on the third ring, past the coffee machine that only takes company scrip."},
	"bones": {"art": "depot", "art_size": 260.0, "name": "Aurelia Yards", "nick": "the Bones", "system": "aurelia", "pos": Vector2(1250, 560),
		"makes": ["parts"], "wants": ["alloy"],
		"desc": "Shipyard and outfitters. Half-built hulls hang in the docks like ribs."},
	"drip": {"art": "rim", "art_size": 220.0, "name": "Aurelia Waterworks", "nick": "the Drip", "system": "aurelia", "pos": Vector2(-2050, 1250),
		"makes": ["water"], "wants": ["rations"],
		"desc": "Ice refinery on the moon. It leaks, hence the name."},
	"greenhouse": {"art": "loop", "art_size": 260.0, "name": "Corvin Agricultural Ring", "nick": "the Greenhouse", "system": "tiberine", "pos": Vector2(950, -650),
		"makes": ["rations", "medicine"], "wants": ["water", "parts", "electronics"],
		"desc": "Domed farm ring above the dry world. Humid, green, and always short of water and pump seals."},
	"four": {"art": "depot", "art_size": 220.0, "name": "Ore Platform Four", "nick": "Four", "system": "marcellus", "pos": Vector2(1500, -900),
		"makes": ["ore"], "wants": ["rations", "water", "parts"],
		"desc": "Mining hub and the navy's patrol base in the belt. Everything is coated in grey dust."},
	"saltgate": {"art": "rim", "art_size": 220.0, "name": "Sal Gatum Transit Depot", "nick": "Saltgate", "system": "marcellus", "pos": Vector2(-1500, 950),
		"makes": ["alloy"], "wants": ["water", "rations", "medicine"],
		"desc": "Docks, a smelter and a bar. Ore in, alloy out."},
	"ambers": {"art": "rim", "art_size": 200.0, "name": "Santa Ambrosia Station", "nick": "Amber's", "system": "marcellus", "pos": Vector2(3900, 2500),
		"makes": ["electronics", "parts"], "wants": ["medicine", "luxuries"],
		"desc": "A dead mining station in the outer belt. The bar still wears the sign of Santa Ambrosia's Patisserie. The pastries are bad. Don't ask what's in the back."},
	"gatehouse": {"art": "hub", "art_size": 260.0, "name": "Aquila Gatehouse", "nick": "the Gate", "system": "porta_aquila", "pos": Vector2(650, 350),
		"makes": ["luxuries"], "wants": ["rations", "water", "medicine"],
		"desc": "Customs, garrison and the checkpoint where they ask for your Writ of Passage. Everybody calls it your papers."},
}

## Start screen. Only the Merchant start is playable in the demo.
var starts := [
	{"id": "merchant", "name": "Merchant", "playable": true,
		"blurb": "Seven years of loading freighters. Seven years of planning routes. Seven years of eating shit from your greedy bosses. Every time they made a hundred credits, they tossed you one, and insisted you thank them. But you smiled in their faces, and plotted (no, designed) behind their backs. After seven years, you were able to buy your way out. With the Charter Company financing your first freighter, you're eager to do things your way. It isn't freedom yet. Just a new master who bills weekly. What will your company look like?"},
	{"id": "scrapper", "name": "Scrapper", "playable": false,
		"blurb": "To them, you were worthless vermin. A despondent, lonely, and unloved urchin. No one noticed children like you. There was no point in noticing. Half of your friends were dead by ten. Of those remaining, half would meet violent ends before they reached adulthood. And Uncle Reeves, who sent them into the wrecks, still says you owe him for every meal. You scraped, hid, salvaged, recycled, and reclaimed the life your peers never got to have. You learned how to survive, but not how to live. You kept parts. A reactor coil here, a navigation computer there, eventually a cruise drive, and one fated day, a set of thrusters. After years of starving, unquenched dreaming, you finally built your first ship. She was wretched, she was small, and she barely got the job done, but you had never seen a thing so beautiful in your life. Will people finally notice you?"},
	{"id": "miner", "name": "Miner", "playable": false,
		"blurb": "Since you were old enough to crawl, you were accustomed to the sights and sounds of haulers, mining lasers, and claim life. This was a family business for you. You learned to read a rock face before you learned to read. You learned which seams sang and which ones lied. Then the laser rig in Shaft Three failed, and your mother didn't get out in time. She lived. She just can't fly anymore. Now the claim is yours. Your little brother asks when Mom will fly again. You don't have an answer. Eleven workers still clock in every shift, because eleven families still need to eat. The letter came on a Tuesday. A League house, sealed in real wax, offering to buy the claim. The price was an insult. The last line was worse: \"Accidents are so common in the belts. We would hate to see another.\" Your mother read it twice, then burned it. Can you hold what your family built?"},
	{"id": "pirate", "name": "Pirate", "playable": false,
		"blurb": "You were alone for as long as you could remember. No crew, no flag, no one to watch your back. You took what you needed from whoever couldn't stop you, until the day you jumped the wrong ship. Captain Rex outflew you, shot out your engines, and boarded you himself. Then, instead of spacing you, he laughed. \"Work for me, kid.\" Nobody had ever offered you anything before. Six years later, his crew is the only family you've known. You've bled for his dream: a fleet, a flag, a name nobody can take away. Tonight is the big one. One last run, Rex says, and the dream comes true for all of you. Where would you be without him?"},
]

## Charlie Hansen, Charter Company dispatch. Lines from the script doc.
var charlie := {
	"first_job": "Morning, captain. Sorry, still getting used to calling you that. Charlotte Hansen, Dispatch. Call me Charlie. I've got a starter run for you: twenty tons of water from the Drip to the Greenhouse. Easy money, patrolled route. Oh, and if you've got space left over, the Greenhouse always needs machine parts. Grab some at the Bones next door. Those hydroponic pumps eat seals like candy. You didn't hear that from me.",
	"paid": "Payment's through. %s down, %s to go. You're doing great, captain.",
	"missed": "Payment bounced, hon. They added interest. Get me something by next week, okay? I can only lose the paperwork so many times.",
	"paid_off": "...That's it. That's the last one. Paid in full. I'm stamping it myself. And your papers came through. Go see the gate, captain. Send me a postcard.",
	"job_done": "Greenhouse says the water's in. Nice flying, captain. The board's open: pick your own runs from here. Watch the belt, though. Marcellus pays well for a reason.",
}

## The Charter Company rig loan.
const LOAN_TOTAL := 40000
const LOAN_WEEKLY := 1200
const LOAN_INTEREST := 0.1   ## fraction of a missed payment added to the balance
const START_CREDITS := 2000
const SECONDS_PER_DAY := 60.0
