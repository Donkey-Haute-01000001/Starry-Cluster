extends Node
## Game content, kept as data so new ships and weapons are easy to add.
## Ships face +X (to the right) at rotation 0. Units: pixels, seconds, degrees.
## Hulls: "accel" is the main engine; "side_thrust" and "reverse_thrust" are the
## maneuvering thrusters as a fraction of it. "energy" is the built-in reactor's
## capacity and "energy_regen" its output per second. Weapons cost "energy" per shot.

## UI font for everything (Exo 2, SIL Open Font License; see fonts/).
const UI_FONT := "res://fonts/Exo2.ttf"
const UI_FONT_WEIGHT := 500
var font_bold: Font = null  ## titles and headings
## Paperwork fonts (all SIL Open Font License; see fonts/). The Charter's cold
## print, people's handwriting on top of it, and rubber stamps.
var font_type: Font = null       ## Courier Prime: forms, serials, typed text
var font_type_bold: Font = null
var font_hand: Font = null       ## Caveat: pen notes, signatures, tally marks
var font_stamp: Font = null      ## Black Ops One: rubber stamps


func _load_font(path: String) -> FontFile:
	if ResourceLoader.exists(path):
		return load(path)
	var ff := FontFile.new()
	if ff.load_dynamic_font(ProjectSettings.globalize_path(path)) != OK:
		return null
	return ff


func _ready() -> void:
	for id in hull_variants:
		var v: Array = hull_variants[id]
		var h: Dictionary = hulls[v[0]].duplicate(true)
		h.merge(v[1], true)
		hulls[id] = h
	font_type = _load_font("res://fonts/CourierPrime.ttf")
	font_type_bold = _load_font("res://fonts/CourierPrime-Bold.ttf")
	font_stamp = _load_font("res://fonts/BlackOpsOne.ttf")
	var hand := _load_font("res://fonts/Caveat.ttf")
	if hand:
		font_hand = FontVariation.new()
		font_hand.base_font = hand
		font_hand.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 550}
	var base := _load_font(UI_FONT)
	if base == null:
		return
	var f := FontVariation.new()
	f.base_font = base
	f.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): UI_FONT_WEIGHT}
	# Every Control without its own theme font, and every draw_string that uses
	# the fallback font (HUD, labels in space), picks this up.
	ThemeDB.fallback_font = f
	font_bold = FontVariation.new()
	font_bold.base_font = base
	font_bold.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 680}
	UIStyle.apply_default_theme(f)


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
	# Story only: the Tallyman's opener. Knocks the engines out instead of killing.
	"ion_bolt": {
		"name": "Ion Bolt", "kind": "gun",
		"damage": 10.0, "cooldown": 9.0, "energy": 0.0, "speed": 700.0, "range": 2400.0,
		"gimbal": 30.0, "spread": 0.0, "color": Color(0.7, 0.5, 1.0), "size": 7.0, "ion": 14.0,
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
	# The old friend's ships, one per role. Picked by Dez's background.
	"friend_gunboat": {
		"name": "Light Gunboat", "sprite": "starsparrow", "role": "fighter",
		"hull": 260.0, "shields": 180.0, "shield_regen": 20.0, "regen_delay": 2.0,
		"accel": 480.0, "side_thrust": 0.55, "reverse_thrust": 0.5, "max_speed": 420.0, "turn": 240.0, "radius": 16.0,
		"energy": 170.0, "energy_regen": 42.0,
		"color": Color(0.7, 0.45, 0.4), "accent": Color(1.0, 0.6, 0.3),
		"shape": [Vector2(18, 0), Vector2(-4, -7), Vector2(-12, -14), Vector2(-9, -3),
			Vector2(-13, 0), Vector2(-9, 3), Vector2(-12, 14), Vector2(-4, 7)],
		"engines": [Vector2(-13, -4), Vector2(-13, 4)],
		"mounts": [
			{"pos": Vector2(8, -5), "weapon": "pulse_cannon"},
			{"pos": Vector2(8, 5), "weapon": "pulse_cannon"},
		],
	},
	"friend_corvette": {
		"name": "Corvette", "sprite": "scifighter", "role": "gunship",
		"hull": 420.0, "shields": 260.0, "shield_regen": 22.0, "regen_delay": 2.5,
		"accel": 300.0, "side_thrust": 0.35, "reverse_thrust": 0.35, "max_speed": 340.0, "turn": 150.0, "radius": 21.0,
		"energy": 220.0, "energy_regen": 46.0,
		"color": Color(0.45, 0.55, 0.75), "accent": Color(0.4, 0.7, 1.0),
		"shape": [Vector2(24, 0), Vector2(8, -10), Vector2(-18, -14), Vector2(-14, 0),
			Vector2(-18, 14), Vector2(8, 10)],
		"engines": [Vector2(-17, -7), Vector2(-17, 7)],
		"mounts": [
			{"pos": Vector2(14, 0), "weapon": "pulse_cannon"},
			{"pos": Vector2(-2, -8), "weapon": "light_turret"},
			{"pos": Vector2(-2, 8), "weapon": "light_turret"},
		],
	},
	"salvage_freighter": {
		"name": "Salvage Freighter", "sprite": "harbinger", "role": "freighter",
		"hull": 560.0, "shields": 160.0, "shield_regen": 14.0, "regen_delay": 3.0,
		"accel": 200.0, "side_thrust": 0.25, "reverse_thrust": 0.3, "max_speed": 290.0, "turn": 100.0, "radius": 24.0,
		"energy": 180.0, "energy_regen": 36.0,
		"color": Color(0.5, 0.5, 0.48), "accent": Color(1.0, 0.7, 0.3),
		"shape": [Vector2(26, -9), Vector2(26, 9), Vector2(-24, 12), Vector2(-24, -12)],
		"engines": [Vector2(-24, -6), Vector2(-24, 6)],
		"mounts": [
			{"pos": Vector2(4, 0), "weapon": "light_turret"},
		],
	},
	"friend_freighter": {
		"name": "Light Freighter", "sprite": "diverger", "role": "freighter",
		"hull": 480.0, "shields": 240.0, "shield_regen": 18.0, "regen_delay": 3.0,
		"accel": 210.0, "side_thrust": 0.25, "reverse_thrust": 0.3, "max_speed": 290.0, "turn": 110.0, "radius": 23.0,
		"energy": 190.0, "energy_regen": 38.0, "cargo": 20,
		"color": Color(0.6, 0.58, 0.5), "accent": Color(1.0, 0.75, 0.35),
		"shape": [Vector2(25, -8), Vector2(25, 8), Vector2(-22, 12), Vector2(-22, -12)],
		"engines": [Vector2(-22, -6), Vector2(-22, 6)],
		"mounts": [
			{"pos": Vector2(2, 0), "weapon": "light_turret"},
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
		"name": "Pirate Raider", "sprite": "crossbow", "role": "fighter", "livery": "pirate",
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
		"name": "Pirate Marauder", "sprite": "bison", "role": "gunship", "livery": "pirate",
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

## Faction paint: main color and trim. One model reads as many owners.
var liveries := {
	"charter": [Color(0.86, 0.62, 0.18), Color(0.92, 0.9, 0.84)],   # company amber, white trim
	"navy": [Color(0.32, 0.42, 0.58), Color(0.9, 0.92, 0.96)],      # Federation slate blue, white
	"pirate": [Color(0.55, 0.26, 0.16), Color(0.85, 0.6, 0.3)],     # rust, scavenged brass
	"tally": [Color(0.32, 0.12, 0.1), Color(0.85, 0.82, 0.74)],     # oxblood, bone tally marks
	"dynasty": [Color(0.22, 0.45, 0.32), Color(0.88, 0.7, 0.32)],   # Dynasty green, brass
	"karabey": [Color(0.6, 0.12, 0.12), Color(0.2, 0.18, 0.18)],    # Clan Karabey crimson and black
	"league": [Color(0.18, 0.4, 0.55), Color(0.9, 0.78, 0.4)],      # Merchant League teal, gold
	"faithful": [Color(0.78, 0.75, 0.66), Color(0.45, 0.3, 0.45)],   # pilgrim white, violet
	"nomad": [Color(0.6, 0.5, 0.3), Color(0.35, 0.6, 0.55)],        # patched ochre, verdigris
}


## Story ships, built from a base hull plus overrides (Data._ready merges them).
var hull_variants := {
	"tally_gunboat": ["marauder", {"name": "Tally's Gunboat", "sprite": "hull", "sprite_scale": 3.2, "livery": "tally",
		"hull": 1600.0, "shields": 800.0, "shield_regen": 30.0, "accel": 300.0, "max_speed": 330.0, "turn": 140.0, "radius": 30.0,
		"mounts": [{"pos": Vector2(24, -6), "weapon": "pulse_cannon"}, {"pos": Vector2(24, 6), "weapon": "pulse_cannon"},
			{"pos": Vector2(2, -13), "weapon": "light_turret"}, {"pos": Vector2(2, 13), "weapon": "light_turret"}]}],
	"tally_escort": ["raider", {"name": "Tally's Raider", "sprite": "pointbreak", "livery": "tally", "hull": 420.0, "shields": 220.0,
		"mounts": [{"pos": Vector2(6, -3), "weapon": "pulse_cannon"}, {"pos": Vector2(6, 3), "weapon": "pulse_cannon"}]}],
	"navy_cutter": ["kestrel", {"name": "FNS Halberd", "sprite": "northstar", "livery": "navy", "hull": 900.0, "shields": 600.0, "radius": 27.0}],
	"navy_wing": ["wasp", {"name": "Navy Interceptor", "sprite": "cruxio", "livery": "navy", "radius": 15.0}],
	"mud_lark": ["raider", {"name": "Mud Lark", "sprite": "switchblade", "hull": 380.0, "shields": 160.0, "radius": 15.0}],
	"fay_skiff": ["wasp", {"name": "Fay's Skiff", "sprite": "areisu", "role": "fighter", "hull": 220.0, "shields": 140.0, "radius": 15.0}],
	"karabey_fighter": ["wasp", {"name": "Karabey Lancer", "sprite": "endra", "livery": "karabey", "hull": 320.0, "shields": 240.0, "accel": 600.0, "max_speed": 490.0, "radius": 17.0,
		"mounts": [{"pos": Vector2(8, -5), "weapon": "pulse_cannon"}, {"pos": Vector2(8, 5), "weapon": "pulse_cannon"}, {"pos": Vector2(10, 0), "weapon": "pulse_cannon"}]}],
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
	{"id": "merchant", "doc": {"issuer": "THE CHARTER COMPANY", "title": "Rig Financing Agreement", "office": "Aurelia Sector Office", "file": "CC-40817-M", "stamp": "APPROVED", "note": "7 years. never again."}, "name": "Merchant", "playable": true,
		"blurb": "Seven years of loading freighters. Seven years of planning routes. Seven years of eating shit from your greedy bosses. Every time they made a hundred credits, they tossed you one, and insisted you thank them. But you smiled in their faces, and plotted (no, designed) behind their backs. After seven years, you were able to buy your way out. With the Charter Company financing your first freighter, you're eager to do things your way. It isn't freedom yet. Just a new master who bills weekly. What will your company look like?"},
	{"id": "scrapper", "doc": {"issuer": "REEVES SALVAGE & RECLAMATION", "title": "Debt Ledger, Minor", "office": "Wreckyard Nine", "file": "RS-0013", "stamp": "SEALED", "note": "every meal. he counted every meal."}, "name": "Scrapper", "playable": false,
		"blurb": "To them, you were worthless vermin. A despondent, lonely, and unloved urchin. No one noticed children like you. There was no point in noticing. Half of your friends were dead by ten. Of those remaining, half would meet violent ends before they reached adulthood. And Uncle Reeves, who sent them into the wrecks, still says you owe him for every meal. You scraped, hid, salvaged, recycled, and reclaimed the life your peers never got to have. You learned how to survive, but not how to live. You kept parts. A reactor coil here, a navigation computer there, eventually a cruise drive, and one fated day, a set of thrusters. After years of starving, unquenched dreaming, you finally built your first ship. She was wretched, she was small, and she barely got the job done, but you had never seen a thing so beautiful in your life. Will people finally notice you?"},
	{"id": "miner", "doc": {"issuer": "MINERS' COMPACT", "title": "Family Claim Deed", "office": "Belt Registry", "file": "MC-2216-F", "stamp": "SEALED", "note": "not for sale."}, "name": "Miner", "playable": false,
		"blurb": "Since you were old enough to crawl, you were accustomed to the sights and sounds of haulers, mining lasers, and claim life. This was a family business for you. You learned to read a rock face before you learned to read. You learned which seams sang and which ones lied. Then the laser rig in Shaft Three failed, and your mother didn't get out in time. She lived. She just can't fly anymore. Now the claim is yours. Your little brother asks when Mom will fly again. You don't have an answer. Eleven workers still clock in every shift, because eleven families still need to eat. The letter came on a Tuesday. A League house, sealed in real wax, offering to buy the claim. The price was an insult. The last line was worse: \"Accidents are so common in the belts. We would hate to see another.\" Your mother read it twice, then burned it. Can you hold what your family built?"},
	{"id": "pirate", "doc": {"issuer": "SECTOR PATROL", "title": "Notice of Bounty", "office": "Wanted, Dead or Alive", "file": "SP-7741-W", "stamp": "SEALED", "note": "rex says one last run."}, "name": "Pirate", "playable": false,
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


# --- The old friend: Desmond "Dez" Okafor ---------------------------------------
# Prewritten. The player picks one of four backgrounds on the Charter's
# emergency-contact form; each bundles a role, a shared memory and lines. Met at
# the Greenhouse bar after the first delivery. Flies free. Lines are drafts: the
# script doc's Old friend tab wins.

const FRIEND_NAME := "Dez"
const FRIEND_FULL_NAME := "Desmond Okafor"

var friend_roles := {
	"pilot": {"name": "Pilot", "hull": "friend_gunboat", "ship": "light gunboat",
		"bonus": "Better dodging under fire."},
	"gunner": {"name": "Gunner", "hull": "friend_corvette", "ship": "corvette",
		"bonus": "Steadier turrets: tighter spread, faster traverse."},
	"engineer": {"name": "Engineer", "hull": "salvage_freighter", "ship": "salvage freighter",
		"bonus": "Patches up your fleet between fights."},
	"trader": {"name": "Trader", "hull": "friend_freighter", "ship": "light freighter",
		"bonus": "His hold adds 20 tons to yours, and he haggles: 3% better prices."},
}

var friend_memories := {
	"drip": {"memory": "the winter we kept your old rig running at the Drip", "trait": "Steady",
		"trait_desc": "Holds up under fire: his shields recover faster.",
		"line": "Still warmer than that winter at the Drip."},
	"four": {"memory": "that bar fight on Four", "trait": "Brawler",
		"trait_desc": "Tough as old boots: a sturdier hull. (Boarding bonus once boarding is in.)",
		"line": "Just like Four. You take the big one."},
	"lost": {"memory": "the night that crate \"fell off\" at Amber's", "trait": "Light fingers",
		"trait_desc": "Knows the back doors: 10% better prices at Amber's.",
		"line": "Remember that crate? Nobody ever found it."},
	"gate": {"memory": "the first time we saw the gate", "trait": "Dreamer",
		"trait_desc": "Sells survey data: 300 credits the first time you enter a system.",
		"line": "Told you we'd get through one day."},
}

## The four backgrounds on the form. "note" is your handwriting in the margin.
var friend_backgrounds := {
	"rift_pilot": {"title": "Rift pilot", "role": "pilot", "memory": "gate",
		"typed": "Flew survey skiffs out to the dead rifts. Will not stop talking about what's past them.",
		"note": "made me watch the gate\nall night. worth it."},
	"navy_gunner": {"title": "Ex-navy gunner", "role": "gunner", "memory": "four",
		"typed": "Washed out of the navy. Cleared a bar on Four with the applicant.",
		"note": "he started it. I finished it."},
	"yard_mechanic": {"title": "Yard mechanic", "role": "engineer", "memory": "drip",
		"typed": "Kept the applicant's last rig alive one winter at the Drip, on parts and spite.",
		"note": "owe him a reactor. and my life."},
	"dock_hustler": {"title": "Dock hustler", "role": "trader", "memory": "lost",
		"typed": "Knows every buyer from here to Amber's. Ask no questions about the crate.",
		"note": "what crate?"},
}
var friend_background_order := ["rift_pilot", "navy_gunner", "yard_mechanic", "dock_hustler"]


## Everything Career needs to know about Dez for one background.
func friend_for(bg: String) -> Dictionary:
	var b: Dictionary = friend_backgrounds[bg]
	return {"name": FRIEND_NAME, "calls_you": "Cap", "background": bg,
		"role": b["role"], "memory": b["memory"]}


## Portraits for the people who talk to you on comms (placeholder art).
var speaker_portraits := {
	"Dez": [Color(0.36, 0.23, 0.16), Color(0.06, 0.05, 0.05), Color(0.38, 0.4, 0.26)],
	"Charlie": [Color(0.94, 0.78, 0.66), Color(0.55, 0.3, 0.15), Color(0.23, 0.42, 0.6)],
	"Dock crew": [Color(0.7, 0.55, 0.42), Color(0.2, 0.18, 0.16), Color(0.55, 0.45, 0.2)],
}


func portrait_for(speaker: String) -> Array:
	if story_portraits.has(speaker):
		return story_portraits[speaker]
	return speaker_portraits.get(speaker, [Color(0.75, 0.7, 0.65), Color(0.3, 0.3, 0.3), Color(0.35, 0.4, 0.45)])


## %s slots: name, memory, ship.
const FRIEND_MEETING := "%s? Is that you? Last time I saw you was %s. Heard you got your own rig. Look at you, a real captain. Tell you what: I've got a beat-up %s and nothing to haul. You need someone watching your back out there?"

## Conscience: reacts to what you do without blocking it. Drafts.
var friend_lines := {
	"joined": "Friends don't take wages. Just don't get me killed.",
	"first_kill": "Poor bastards. Bet half of them owed somebody too.",
	"fled": "Running's smart. Living's smarter.",
	"missed": "Missed one. Don't let it happen twice, they'll own your grandkids.",
	"paid_extra": "Paying the company early? Who are you?",
	"paid_off": "Free and clear. Never thought I'd see it.",
	"down": "I'm out! Pod's fine. Meet you at the next dock.",
	"back": "Patched her up. Where were we?",
}


# --- The rest of the Merchant opening ---------------------------------------------
# Lines marked DRAFT are mine; everything else is from the script doc, which wins.

## The Tallyman's ambush on your first run into Marcellus (script doc: Tallyman).
var tally := {
	"hail": "Easy, easy. Charter colors on a rig that old? Let me guess. Eleven years, company terms, weekly payments.",
	"choices": [
		{"text": "Maybe.", "reply": "Maybe. Ha. That's what I used to say."},  # DRAFT reply
		{"text": "Seven years, actually.", "reply": "Seven. They'll make it eleven. They always do."},  # DRAFT reply
	],
	"silence": "Nothing? Fine. Quiet ones last longer out here.",  # DRAFT: you let the clock run out
	"ignored": "Not picking up? Charter teach you that? I'll talk, you listen.",  # DRAFT: you never answered
	# DRAFT: what he thinks of how you fought.
	"fought_well": "You fly that brick like you mean it. Most Charter boys just cry on the open channel.",
	"fought_poorly": "Relax. If I wanted you dead, you'd know it.",
	"spare": "I'm not taking your cargo. Not this time. Keep paying them. You'll see.",
	"signoff": "Name's Tallyn. They call me the Tallyman. I keep count.",
	"dez": "He let us go. Why'd he let us go?",  # DRAFT, Dez's conscience
}

## Lt. Franz Kessler (script doc: Franz).
var franz := {
	"arrival": "Federation Navy, Marcellus patrol. Captain, you hurt? ...The Tallyman. Again. That's the fourth Charter rig this month. He takes the rig, lets the crew walk, and paints another mark on his hull. But he left you alone. Huh.",
	"intro": "Lieutenant Franz Kessler. If you're hauling through the belt, you'll want friends out here. I post bounties at Four. Pays better than water.",
	"patched": "Engines are back. My crew can't fix the paint job. Finish your run, captain. We'll keep the belt quiet for an hour.",  # DRAFT
	"at_four": "Five now. Another Charter rig this morning. He never takes the cargo. He just counts.",  # DRAFT, from the brief
	"pitch": "We're stretched thin, and honest pilots are rare out here. If you ever get tired of hauling for the Charter, the navy's hiring.",
	"paid": "Mud Lark's done. Good work, captain. Bounty's yours.",  # DRAFT
}

## Kessler's board at Four. "alive" waits for boarding.
var bounty := {
	"id": "mud_lark", "hull": "mud_lark", "station": "ambers",
	"title": "BOUNTY: pirate skiff Mud Lark",
	"text": "Last seen near Amber's. 3,000 credits; alive pays 4,500.",
	"sign": "Lt. F. Kessler",
	"pay": 3000, "pay_alive": 4500,
}

## Bar captains at Saltgate, hired on weekly contracts (script doc: Phaedra, Mersham).
var captains := {
	"fay": {"name": "Fay", "full": "Phaedra \"Fay\" Andreou", "hull": "fay_skiff", "ship": "skiff", "wage": 150,
		"pitch": "You're the one with the freighter? Hire me. I've loaded, fixed, flown and fueled every ship that's ever docked at Saltgate. I'm cheap, I learn fast, and I really, really want to see the gate.",
		"hired": "You won't regret this! ...Probably!",
		"note": "Cheap, eager, green. Flies a patched-up skiff."},
	"mersham": {"name": "Mersham", "full": "Mersham Ali of Clan Karabey", "hull": "karabey_fighter", "ship": "lancer", "wage": 600, "ace": true,
		"pitch": "You fly a hauler, and your escorts fly like cargo. I flew for Clan Karabey, until the court decided my clan backed the wrong prince. My price is high. My aim is better.",
		"hired": "Point me at whoever's bothering you.",
		"note": "Clan Karabey ace. Expensive. Flies point."},
}
var captain_order := ["fay", "mersham"]
## DRAFT: the discovered bond when you hire both.
var captains_bond := ["Mersham", "Stay on my wing, girl. Watch what I do, not what I say.", "Fay", "...Yes, sir! I mean. Yes."]
var captain_lines := {
	"unpaid": "No pay, no wings. Find me at Saltgate when your books are better.",  # DRAFT
	"down": "Punching out! Pick me up at the next dock.",  # DRAFT
}

## The ending (script doc: Ending).
var ending := {
	"customs": "Writ of Passage, Charter file CC-40817-M... paid in full. Stamped. You're cleared to jump, captain. Don't come back broke.",  # DRAFT
	"mersham": "...Home. Or what they made of it.",  # DRAFT
	"line": "The crossroads. Every road in the cluster, and not one of them owes you anything.",
}

var crossroads := {
	"name": "The Crossroads", "nick": "Dynasty gate", "security": "Dynasty", "danger": 0.0,
	"desc": "", "bodies": [], "jumps": [],
}

var story_portraits := {
	"Tallyman": [Color(0.72, 0.55, 0.42), Color(0.35, 0.33, 0.3), Color(0.28, 0.24, 0.22)],
	"Franz": [Color(0.93, 0.8, 0.68), Color(0.78, 0.6, 0.32), Color(0.2, 0.28, 0.42)],
	"Fay": [Color(0.86, 0.68, 0.54), Color(0.18, 0.12, 0.1), Color(0.55, 0.42, 0.25)],
	"Mersham": [Color(0.62, 0.45, 0.32), Color(0.1, 0.09, 0.08), Color(0.5, 0.18, 0.16)],
	"Gate customs": [Color(0.8, 0.66, 0.55), Color(0.25, 0.22, 0.2), Color(0.25, 0.3, 0.36)],
}


## Who's on the radio: channel, role and the file number on their ID photo.
var speakers := {
	"Charlie": {"channel": "CH 03  ·  CHARTER DISPATCH", "role": "Dispatch", "serial": "CC-0042-D", "color": Color(1.0, 0.77, 0.42)},
	"Dock crew": {"channel": "CH 05  ·  DOCK CONTROL", "role": "Loading crew", "serial": "DOCK", "color": Color(0.75, 0.75, 0.7)},
	"Dez": {"channel": "CH 09  ·  PRIVATE", "role": "Old friend", "serial": "NK-40817-1", "color": Color(0.56, 0.94, 0.64)},
	"Fay": {"channel": "CH 09  ·  CREW", "role": "Bar captain", "serial": "SG-1187", "color": Color(0.56, 0.94, 0.64)},
	"Mersham": {"channel": "CH 09  ·  CREW", "role": "Bar captain", "serial": "FED-INT-0031", "color": Color(0.56, 0.94, 0.64)},
	"Franz": {"channel": "CH 16  ·  FEDERATION NAVY", "role": "Lt., Marcellus patrol", "serial": "FN-2231-LT", "color": Color(0.45, 0.7, 1.0)},
	"Tallyman": {"channel": "OPEN BAND  ·  UNREGISTERED", "role": "", "serial": "NO FILE", "color": Color(1.0, 0.45, 0.35)},
	"Gate customs": {"channel": "CH 01  ·  AQUILA CUSTOMS", "role": "Gatehouse", "serial": "AQ-CUSTOMS", "color": Color(0.85, 0.85, 0.95)},
	"You": {"channel": "OUTBOUND", "role": "", "serial": "CC-40817-M", "color": Color(0.85, 0.92, 0.98)},
}


func speaker_info(who: String) -> Dictionary:
	if speakers.has(who):
		return speakers[who]
	return {"channel": "OPEN BAND", "role": "", "serial": "", "color": Color(0.75, 0.8, 0.85)}
