extends Node
## Game content, kept as data so new ships and weapons are easy to add.
## Ships face +X (to the right) at rotation 0. Units: pixels, seconds, degrees.
## Hulls: "accel" is the main engine; "side_thrust" and "reverse_thrust" are the
## maneuvering thrusters as a fraction of it. "energy" is the built-in reactor's
## capacity and "energy_regen" its output per second. Weapons cost "energy" per shot.

## UI font for everything: Big Shoulders, tall dock signage (SIL Open Font License; see fonts/).
const UI_FONT := "res://fonts/BigShoulders-SemiBold.ttf"
const UI_FONT_BOLD := "res://fonts/BigShoulders-ExtraBold.ttf"
const UI_FONT_WEIGHT := 500
var font_bold: Font = null  ## titles and headings
## Paperwork fonts (all SIL Open Font License; see fonts/). The Charter's cold
## print, people's handwriting on top of it, and rubber stamps.
var font_type: Font = null       ## Courier Prime: forms, serials, typed text
var font_type_bold: Font = null
var font_hand: Font = null       ## Nanum Pen Script: pen notes, signatures, tally marks
var font_talk: Font = null       ## VT323, crisp pixels: what people say (comms, ticker)
const TALK_BODY := Color(0.68, 0.71, 0.76)  ## dim body so the neon words carry the line
var font_stamp: Font = null      ## Big Shoulders Stencil: rubber stamps, hull marks


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
	# --fontset=DIR swaps in ui/ui_bold/type/type_bold/stamp/hand .ttf from DIR
	# (for comparing type directions; missing files keep the defaults).
	var fs := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--fontset="):
			var dir := a.substr(10)
			for k in ["ui", "ui_bold", "type", "type_bold", "stamp", "hand"]:
				if FileAccess.file_exists(dir + "/" + k + ".ttf"):
					fs[k] = dir + "/" + k + ".ttf"
	font_type = _load_font(fs.get("type", "res://fonts/CourierPrime.ttf"))
	font_type_bold = _load_font(fs.get("type_bold", "res://fonts/CourierPrime-Bold.ttf"))
	font_stamp = _load_font(fs.get("stamp", "res://fonts/BigShouldersStencil-ExtraBold.ttf"))
	var hand := _load_font(fs.get("hand", "res://fonts/NanumPenScript.ttf"))
	if hand:
		font_hand = FontVariation.new()
		font_hand.base_font = hand
		font_hand.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 550}
	var talk := _load_font("res://fonts/VT323-Regular.ttf")
	if talk:
		talk.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		talk.hinting = TextServer.HINTING_NONE
		talk.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		var tv := FontVariation.new()
		tv.base_font = talk
		tv.spacing_glyph = 1
		font_talk = tv
	var base := _load_font(fs.get("ui", UI_FONT))
	if base == null:
		return
	var f := FontVariation.new()
	f.base_font = base
	f.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): UI_FONT_WEIGHT}
	# Every Control without its own theme font, and every draw_string that uses
	# the fallback font (HUD, labels in space), picks this up.
	f.spacing_glyph = 1   # Big Shoulders is narrow; a hair of tracking keeps small text legible
	ThemeDB.fallback_font = f
	font_bold = FontVariation.new()
	font_bold.base_font = _load_font(fs.get("ui_bold", UI_FONT_BOLD))
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
	# Turrets: rotate toward the aim point at a limited traverse speed. Rapid
	# tracer rounds with flak fuzes: each round bursts at the aim point, so a
	# near miss still chips the target. Low damage, high rate of fire.
	"light_turret": {
		"name": "Light Turret", "kind": "turret",
		"damage": 3.5, "cooldown": 0.07, "energy": 0.9, "speed": 1150.0, "range": 640.0,
		"traverse": 200.0, "spread": 3.0, "color": Color(1.0, 0.86, 0.5), "size": 1.6,
		"flak": 30.0, "tracer": true,
	},
	# Story only: the Tallyman's opener. Knocks the engines out instead of killing.
	"ion_bolt": {
		"name": "Ion Bolt", "kind": "gun",
		"damage": 10.0, "cooldown": 9.0, "energy": 0.0, "speed": 700.0, "range": 2400.0,
		"gimbal": 30.0, "spread": 0.0, "color": Color(0.7, 0.5, 1.0), "size": 7.0, "ion": 14.0,
	},
	# Charter Recovery's grapple-ion: a short stall, again and again, until it's alongside.
	"repo_ion": {
		"name": "Recovery Ion", "kind": "gun",
		"damage": 4.0, "cooldown": 5.0, "energy": 0.0, "speed": 760.0, "range": 1100.0,
		"gimbal": 40.0, "spread": 0.0, "color": Color(1.0, 0.7, 0.3), "size": 7.0, "ion": 3.5,
	},
	# Secondaries: right click fires the selected one, R swaps.
	"ion_cannon": {
		"name": "Ion Bolt", "kind": "secondary",
		"damage": 6.0, "cooldown": 3.5, "energy": 40.0, "speed": 760.0, "range": 900.0,
		"gimbal": 20.0, "spread": 0.0, "color": Color(0.7, 0.5, 1.0), "size": 6.0, "ion": 3.0,
	},
	"torpedo": {
		"name": "Torpedo", "kind": "secondary",
		"damage": 110.0, "cooldown": 1.2, "energy": 0.0, "speed": 430.0, "range": 1500.0,
		"gimbal": 20.0, "spread": 0.0, "color": Color(1.0, 0.5, 0.3), "size": 4.0,
		"torp": true, "ammo": 6, "blast": 55.0, "turn": 100.0,
	},
	"pirate_turret": {
		"name": "Rusty Turret", "kind": "turret",
		"damage": 3.0, "cooldown": 0.1, "energy": 0.7, "speed": 1000.0, "range": 600.0,
		"traverse": 120.0, "spread": 5.0, "color": Color(1.0, 0.7, 0.4), "size": 1.6,
		"flak": 26.0, "tracer": true,
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
		"secondaries": ["ion_cannon", "torpedo"],
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
		"sprite_alts": ["crossbow", "red_fighter", "galactix_racer", "micro_recon"],
		"layered_alts": ["nautolan/fighter", "nautolan/scout", "nautolan/bomber"],
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
		"sprite_alts": ["bison", "camo_stellar_jet"],
		"layered_alts": ["nautolan/frigate", "nautolan/torpedo_ship"],
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
	"sealed": {"name": "Sealed crates", "slang": "no-questions", "base": 0,
		"desc": "No manifest, no markings. Heavy for their size."},
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
	"default": [Color(0.72, 0.1, 0.08), Color(0.86, 0.62, 0.18)],   # Charter default red, over old company amber
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
		"layered": {"dir": "nautolan/battlecruiser"}, "layered_alts": [],
		"hull": 1600.0, "shields": 800.0, "shield_regen": 30.0, "accel": 300.0, "max_speed": 330.0, "turn": 140.0, "radius": 30.0,
		"mounts": [{"pos": Vector2(24, -6), "weapon": "pulse_cannon"}, {"pos": Vector2(24, 6), "weapon": "pulse_cannon"},
			{"pos": Vector2(2, -13), "weapon": "light_turret"}, {"pos": Vector2(2, 13), "weapon": "light_turret"}]}],
	"tally_escort": ["raider", {"name": "Tally's Raider", "sprite": "infrared_furtive", "livery": "tally", "sprite_alts": [],
		"layered": {"dir": "nautolan/bomber"}, "layered_alts": [], "hull": 420.0, "shields": 220.0,
		"mounts": [{"pos": Vector2(6, -3), "weapon": "pulse_cannon"}, {"pos": Vector2(6, 3), "weapon": "pulse_cannon"}]}],
	"navy_cutter": ["kestrel", {"name": "FNS Halberd", "sprite": "warship", "livery": "navy", "layered": {"dir": "klaed/frigate"}, "hull": 900.0, "shields": 600.0, "radius": 27.0}],
	"navy_wing": ["wasp", {"name": "Navy Interceptor", "sprite": "interstellar_runner", "livery": "navy", "layered": {"dir": "klaed/fighter"}, "radius": 15.0}],
	"mud_lark": ["raider", {"name": "Red Stork", "sprite": "switchblade", "sprite_alts": [], "livery": "default", "layered": {"dir": "nautolan/scout"}, "layered_alts": [], "hull": 380.0, "shields": 160.0, "radius": 15.0}],
	"fay_skiff": ["wasp", {"name": "Fay's Skiff", "sprite": "areisu",
		"layered": {"dir": "void", "engine": "burst", "weapon": "cannon"}, "role": "fighter", "hull": 220.0, "shields": 140.0, "radius": 15.0}],
	# Traffic: the March going about its business.
	"liened_rig": ["light_freighter", {"name": "Charter Rig", "livery": "charter", "sprite_alts": ["cargo", "transtellar", "diverger"], "secondaries": []}],
	"charter_hauler": ["salvage_freighter", {"name": "Charter Hauler", "livery": "charter", "layered": {"dir": "klaed/support_ship"}, "sprite_scale": 4.4,
		"hull": 1400.0, "shields": 500.0, "accel": 150.0, "max_speed": 230.0, "turn": 70.0, "radius": 36.0}],
	"ore_barge": ["light_freighter", {"name": "Ore Barge", "livery": "charter", "sprite": "bison", "sprite_alts": [], "secondaries": [], "mounts": [],
		"accel": 170.0, "max_speed": 240.0, "turn": 90.0}],
	"compact_miner": ["light_freighter", {"name": "Claim Miner", "livery": "nomad", "sprite": "micro_recon", "sprite_alts": [], "secondaries": [], "mounts": [], "radius": 20.0}],
	"navy_patrol": ["kestrel", {"name": "Navy Cutter", "sprite": "warship", "livery": "navy", "layered": {"dir": "klaed/frigate"}, "hull": 900.0, "shields": 600.0, "radius": 27.0}],
	"league_trader": ["light_freighter", {"name": "League Trader", "livery": "league", "sprite": "transtellar", "sprite_alts": [], "secondaries": []}],
	"dynasty_trader": ["light_freighter", {"name": "Dynasty Trader", "livery": "dynasty", "layered": {"dir": "nairan/support_ship"}, "sprite_alts": [], "secondaries": [], "radius": 26.0}],
	"backed_raider": ["raider", {"name": "Raider", "hull": 460.0, "shields": 220.0,
		"mounts": [{"pos": Vector2(6, -3), "weapon": "pulse_cannon"}, {"pos": Vector2(6, 3), "weapon": "pulse_cannon"}]}],
	"dynasty_corsair": ["marauder", {"name": "Corsair", "livery": "dynasty", "layered": {"dir": "nairan/frigate"}, "layered_alts": [], "hull": 1100.0, "shields": 600.0, "radius": 28.0}],
	"repo_cutter": ["kestrel", {"name": "Recovery Cutter", "sprite": "warship", "livery": "charter", "layered": {"dir": "klaed/frigate"}, "layered_alts": [],
		"hull": 1300.0, "shields": 700.0, "accel": 320.0, "max_speed": 315.0, "radius": 27.0,
		"mounts": [{"pos": Vector2(20, -5), "weapon": "repo_ion"}, {"pos": Vector2(20, 5), "weapon": "repo_ion"}]}],
	"karabey_fighter": ["wasp", {"name": "Karabey Lancer", "sprite": "endra", "livery": "karabey", "layered": {"dir": "nairan/fighter"}, "hull": 320.0, "shields": 240.0, "accel": 600.0, "max_speed": 490.0, "radius": 17.0,
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
		"makes": ["alloy"], "wants": ["ore", "water", "rations", "medicine"],
		"desc": "Docks, a smelter and a bar. Ore in, alloy out."},
	"ambers": {"art": "rim", "art_size": 200.0, "name": "Santa Ambrosia Station", "nick": "Amber's", "system": "marcellus", "pos": Vector2(3900, 2500),
		"makes": ["electronics", "parts"], "wants": ["medicine", "luxuries"],
		"desc": "A dead mining station in the outer belt. The bar still wears the sign of Santa Ambrosia's Patisserie. The pastries are bad. Don't ask what's in the back."},
	"gatehouse": {"art": "hub", "art_size": 260.0, "name": "Aquila Gatehouse", "nick": "the Gate", "system": "porta_aquila", "pos": Vector2(650, 350),
		"makes": ["luxuries"], "wants": ["rations", "water", "medicine"],
		"desc": "Customs, garrison and the checkpoint where they ask for your Writ of Passage. Everybody calls it your papers."},
}

## The March's own traffic, derived from what each station makes and wants
## (each buys what it can't make). Routes: [from, to, hull, owner, cargo,
## seconds between departures]; "@sys" is the jump toward sys. Patrols loop
## their waypoints; "hold" ships keep station at a point (chart units).
var traffic := {
	"aurelia": {"cap": 16, "routes": [
		["drip", "@tiberine", "liened_rig", "charter", "water", 40],
		["bones", "@tiberine", "liened_rig", "charter", "parts", 60],
		["counter", "@tiberine", "charter_hauler", "charter", "electronics", 75],
		["@tiberine", "counter", "charter_hauler", "charter", "medicine", 75],
		["@tiberine", "drip", "liened_rig", "charter", "rations", 45],
		["drip", "@marcellus", "liened_rig", "charter", "water", 70],
		["bones", "@marcellus", "liened_rig", "charter", "parts", 90],
		["@marcellus", "bones", "liened_rig", "charter", "alloy", 60],
		["@tiberine", "counter", "liened_rig", "charter", "luxuries", 120],
	], "patrols": [[["counter", "@tiberine", "drip", "bones"], ["navy_patrol", "navy_wing"]]], "holds": []},
	"tiberine": {"cap": 11, "routes": [
		["@aurelia", "greenhouse", "liened_rig", "charter", "water", 45],
		["@aurelia", "greenhouse", "liened_rig", "charter", "parts", 75],
		["greenhouse", "@aurelia", "liened_rig", "charter", "rations", 45],
		["greenhouse", "@aurelia", "charter_hauler", "charter", "medicine", 90],
		["greenhouse", "@porta_aquila", "liened_rig", "charter", "rations", 70],
		["@porta_aquila", "@aurelia", "liened_rig", "charter", "luxuries", 110],
		["@aurelia", "@porta_aquila", "navy_patrol", "navy", "", 160],
	], "patrols": [], "holds": []},
	"marcellus": {"cap": 9, "routes": [
		["four", "saltgate", "ore_barge", "charter", "ore", 35],
		["saltgate", "four", "ore_barge", "charter", "", 50],
		["@aurelia", "four", "liened_rig", "charter", "water", 90],
		["@aurelia", "saltgate", "liened_rig", "charter", "rations", 100],
		["saltgate", "@aurelia", "liened_rig", "charter", "alloy", 80],
		["@porta_aquila", "ambers", "liened_rig", "charter", "luxuries", 150],
	], "patrols": [[["four", "@aurelia", "saltgate"], ["navy_patrol"]]],
		"holds": [[Vector2(-1900, -1700), "compact_miner", "compact"], [Vector2(2300, 1250), "compact_miner", "compact"]]},
	"porta_aquila": {"cap": 12, "routes": [
		["@tiberine", "gatehouse", "liened_rig", "charter", "rations", 55],
		["@tiberine", "gatehouse", "liened_rig", "charter", "water", 70],
		["gatehouse", "@tiberine", "liened_rig", "charter", "luxuries", 70],
		["gatehouse", "@marcellus", "liened_rig", "charter", "luxuries", 140],
		["@crossroads", "gatehouse", "league_trader", "league", "luxuries", 80],
		["@crossroads", "gatehouse", "dynasty_trader", "dynasty", "luxuries", 110],
		["gatehouse", "@crossroads", "league_trader", "league", "medicine", 120],
	], "patrols": [],
		"holds": [[Vector2(2200, -260), "navy_patrol", "navy"], [Vector2(2250, 260), "navy_patrol", "navy"], [Vector2(2050, 0), "navy_wing", "navy"]]},
}

## Traffic names and voices. DRAFT lines.
var traffic_names := {
	"charter": ["Cold Coffee", "Paid Monday", "Second Mortgage", "Little Margin", "Mother's Ring", "Overdue", "Interest Only", "Seven Years", "Late Fee", "Small Comfort", "Good Enough", "Lucky Thursday", "Patience", "Rent Day", "Owed Nothing", "Hope Floats"],
	"charter_hauler": ["CCS Dividend", "CCS Quarterly", "CCS Prospectus", "CCS Shareholder", "CCS Fiscal Year"],
	"ore_barge": ["Barge 4-07", "Barge 4-11", "Barge 4-12", "Barge 4-19", "Barge 4-23"],
	"navy": ["FNS Pike", "FNS Sabre", "FNS Glaive", "FNS Partisan", "FNS Bardiche", "FNS Ranseur"],
	"league": ["Ca' Dorata", "Ca' Venier", "Serenissima Rosa", "Ca' Morosini"],
	"dynasty": ["Kara Yel", "Ak Dogan", "Sultana's Patience", "Gul Bahar"],
	"compact": ["Okonjo claim", "Kovac claim", "Lindqvist claim", "Mensah claim"],
}
var traffic_owner := {"charter": "Charter lien rig", "charter_hauler": "Charter Company", "ore_barge": "Charter mining crew",
	"navy": "Federation Navy", "league": "Merchant League", "dynasty": "Dynasty trader", "compact": "Miners' Compact claim"}
var hails := {
	"charter": ["Can't talk, captain. Clock's running and so's the interest.", "If you're Charter collections, I already paid. Check again.", "Three more weeks and she's mine. Three more weeks.", "Watch the belt. Lost a cousin out there."],
	"charter_hauler": ["Company vessel. Keep clear of the lane.", "This channel is for Charter business."],
	"ore_barge": ["Four to Saltgate, Saltgate to Four. Pays the same either way.", "Rock in, rock out. Wake me at shift change."],
	"navy": ["Federation Navy. Keep your transponder on and your guns cold.", "Patrol's stretched thin, captain. Don't make me come back here.", "Most of the fleet's at the Wall. The rest of us are this."],
	"league": ["The League thanks you for your interest. Gatehouse is as far as they let us.", "Everything has a price, captain. Even the hail."],
	"dynasty": ["Peace on your road, captain.", "We are only traders. Please tell your customs officers."],
	"compact": ["This claim's not for sale. Tell whoever sent you.", "Compact rock. Charter can buy the ore. Not the hole."],
	"mayday": "Mayday, mayday. %s, near %s. Raiders on me. Anyone!",
	"thanks": "You came. Most don't. Here, it's what I can spare.",
	"thanks_navy": "Navy got here. Late, but here.",
	"robbed": "They took the whole hold and left me drifting. I'm alive. That's something.",
}
## Things Dez says about what you did. DRAFT lines.
var traffic_dez := {
	"helped": "That's one rig that makes its payment this week. Good.",
	"ignored": "Could've been us. Next time it might be.",
	"looted": "We're picking their bones now? ...Fine. Just don't tell me what you get for it.",
}


## Each station's wall when you're docked: bulkhead paint, the stripe they
## painted round it, and how worn it is. The boards hang on this.
var station_walls := {
	"counter": {"wall": Color(0.2, 0.23, 0.27), "stripe": Color(0.86, 0.62, 0.18), "wear": 0.2},   # Charter grey, company amber
	"bones": {"wall": Color(0.22, 0.2, 0.18), "stripe": Color(0.9, 0.72, 0.12), "wear": 0.8, "hazard": true},
	"drip": {"wall": Color(0.14, 0.22, 0.24), "stripe": Color(0.5, 0.75, 0.78), "wear": 0.7},
	"greenhouse": {"wall": Color(0.2, 0.25, 0.2), "stripe": Color(0.85, 0.88, 0.8), "wear": 0.4},
	"four": {"wall": Color(0.23, 0.24, 0.21), "stripe": Color(0.38, 0.47, 0.6), "wear": 0.9},     # dust grey, navy blue
	"saltgate": {"wall": Color(0.21, 0.16, 0.13), "stripe": Color(0.75, 0.38, 0.18), "wear": 0.7},
	"ambers": {"wall": Color(0.2, 0.14, 0.15), "stripe": Color(0.82, 0.55, 0.6), "wear": 1.0},     # old patisserie pink
	"gatehouse": {"wall": Color(0.24, 0.26, 0.3), "stripe": Color(0.88, 0.9, 0.95), "wear": 0.1},
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

## ID photos you can pick on the financing agreement (art/portraits/pilot_N.png).
const PILOT_PHOTOS := 12
## Name ideas for the blank on the form; you can type your own.
var pilot_names := ["Ines Kovac", "Tobias Reyes", "Mara Quill", "Sol Benedek", "Yara Mensah", "Pell Okonkwo", "Rosa Lindqvist", "Arun Desai", "Nadia Ferro"]
var rig_names := ["Second Wind", "Paid in Full", "Long Haul", "Small Mercy", "Old Faithful", "Debt Collector", "Fair Weather", "Last Light"]

## Charlie Hansen, Charter Company dispatch. Lines from the script doc.
var charlie := {
	"first_job": "Morning, captain. Sorry, still getting used to calling you that. Charlotte Hansen, Dispatch. Call me Charlie. I've got a starter run for you: twenty tons of water from the Drip to the Greenhouse. Easy money, patrolled route. Oh, and if you've got space left over, the Greenhouse always needs machine parts. Grab some at the Bones next door. Those hydroponic pumps eat seals like candy. You didn't hear that from me.",
	"paid": "Payment's through. %s down, %s to go. You're doing great, captain.",
	"missed": "Payment bounced, hon. They added interest. Get me something by next week, okay? I can only lose the paperwork so many times.",
	"paid_off": "...That's it. That's the last one. Paid in full. I'm stamping it myself. And your papers came through. Go see the gate, captain. Send me a postcard.",
	"strike1": "Hey. So... your payment bounced. That's a [red]strike[/red] on your file. One more and Recovery sends a cutter, and I really don't want to be the one reading you that, hon.",
	"strike2": "Captain, that's the second one. Recovery's put a cutter on your file. Officially, I can't help you. Unofficially, pay the overdue at the Counter and they'll let me call it off. I already printed the form. Don't ask why.",
	"called_off": "Okay. Overdue's in, cutter's turning around. Officially, you're in good standing. Unofficially, I owe the filing clerk a coffee. He takes four sugars, so.",
	"cutter_inbound": "Captain? [shake]Recovery cutter just jumped into your system[/shake], boarding crew and everything. I'm not supposed to tell you that. Just... run. Be careful. I'm staying on this channel till you're clear.",
	"repossessed": "They took the cargo, and the fee's on the lien. ...I'm so sorry, captain.",
	"job_done": "Greenhouse says the water's in. Nice flying, captain. The board's open: pick your own runs from here. Watch the belt, though. Marcellus pays well for a reason.",
}

## The Charter Company rig loan.
const LOAN_TOTAL := 40000
const LOAN_WEEKLY := 1200
const LOAN_INTEREST := 0.1   ## fraction of a missed payment added to the balance
const REPO_FEE := 2500       ## Charter Recovery's fee when the cutter catches you
const OBSTRUCTION_FEE := 2000 ## ...and when you drive it off

## The rig ahead of you, on the first water run. Drafts: the script doc wins.
var ahead := {
	"rig": "Sweet Margaret",
	"owner": "Alejandra",
	"owner_tag": "Alejandra Vargas, owner-operator",
	"hello": "Sweet Margaret hailing %s. Grye, hauler. Welcome, family. Let's mint.",  ## %s = your rig's name (Vishnu)
	"robbed": "Oh, great, everybody just watched. Love that. ...Forty tons. That was my whole week. Somebody tell the Greenhouse I'm gonna be late. Real late.",  ## Hollis (Vishnu)
	"charlie_after": "...Greenhouse says the water's in. Board's open from here, captain. Pick your own runs.",
	## Alejandra at the Saltgate bar (Vishnu 2026-11-24): held back / went in after Hollis.
	"bar": "Grye. Sit down. You missed Hollis's speech, it was very moving. ...You did right out there. Doesn't feel like it, I know. It never does.",
	"bar_saved": "Grye. ...You didn't listen to me. Good. Don't tell anyone I said that.",
	"hail": "Go on, deliver yours. Somebody should get paid today.",
	## Restage (Vishnu 2026-11-24): Alejandra flies with you; a stranger, Hollis Gray
	## in Hollis' Girl, is the one raided. Alejandra coaches in two beats.
	"victim_rig": "Hollis' Girl",
	"victim": "Hollis Gray",
	"coach_1": "That's Hollis. Man named his rig after himself, so. ...Three on one, though? Over water? Somebody's got a beef with whoever he hauls for.",
	"hollis_bar": "Hey, it's the lane-watcher. Relax, I'm not mad. ...I'm a little mad. Charter fined me for the late delivery. Robbed, and then fined. Buy me something that burns and we're even.",
	"hollis_bar_saved": "You came in. Nobody ever comes in. ...I don't know what to do with that. Here, that's my channel. You need something hauled, I owe you one.",
	"coach_2": "[shake]Back off.[/shake] You go in there, they strip you too. They take his water, he limps home. That's how it goes.",
}

## The forks: what the March remembers of you, and how it pays off at the gate.
## Drafts: the script doc wins.
var lanes := {
	"friend": ["Hey, it's the rig that stops for people. Clear skies, captain.", "Word on the band is you came back for a stranger. Drinks on me, Saltgate.", "Saw you on the scope and stopped worrying. Funny, that."],
	"scav": ["Keep your distance, scavenger. I'm still breathing.", "Nothing in my hold worth dying for. Fly on.", "Everyone knows your rig. Everyone."],
	"saved": "You came for me. I won't forget it. Ask anyone on the lane.",
	"vouch": "That's the one who came for us. Let 'em through.",
}
var forks := {
	# Navy or Tallyman.
	"navy_offer": "Captain! Sorry, that was loud. I've been practicing this. ...The Navy gave us one cutter for the whole belt, so I'm asking for help. If you sign, you fly with us when we need you. You'd get a wingman, and papers that get you through the Wall. And your rig stays yours. I made sure of that.",
	"navy_signed": "Thank you. Really. Mbeki will fly with you. Please bring him back, his mother writes me every week. Long letters.",
	"navy_after_tally": "The Ledger Line went missing out of Four. People say you were there. ...I don't want to believe it. I had your papers ready, captain. I can't sign them now. I'm sorry.",
	"tally_offer": "Sit down. ...Missed one, didn't you. I can tell. I missed two, back when I hauled for them. [slow]They took her on the third.[/slow] There's a Charter hauler leaving Four. Knock her engines out, my people take her, her crew walks home. ...There's other ways off the Charter's books, you know. Not all of them are on paper.",
	"tally_done": "There she goes. Charter's poorer by one hauler and nobody bled. You're on the good list now, captain. Notch'll fly with you.",
	"tally_hauler": "CCS Ledger Line",
	"tally_hauler_hail": "Unidentified rig, you are interfering with Charter property. Break off.",
	"charter_heat": "Captain, Recovery just put a security surcharge on your account. Fifteen hundred. They wouldn't say why. ...I think I know why.",
	# The Red Stork.
	"lark_alive": "They painted her red and called her theirs. I only took back what I paid for. ...You brought me in breathing. That is a debt, and Karabey pays its debts. Ask for Qasim on the other side of the Wall.",
	"hunter": "For the Red Stork. The paymaster sends his regards.",
	"hunter_crates": "You carried his crates and then you killed his dog. The paymaster sends his regards.",
	"hunter_gone": "...Tell the paymaster his horse came back lame.",
	# The crates.
	"letter": "Captain. A letter for you, from a friend at Amber's. Any house on the Dynasty side will honor it. He says you deliver.",
	"charlie_vouch": "One more thing on your file, from Charter dispatch. Handwritten. 'Honest. Mostly.' ...Cleared.",
	"flagged": "Flagged, captain. Contraband, Marcellus patrol report. Papers are papers, so you're cleared. But the Wall will remember your face.",
	"tally_heat": "Charter has you down for a hauler that went missing on your watch. They can't prove it. Cleared. Barely.",
	"navy_papers": "Navy commission, Lieutenant Kessler's signature. Wall's yours, captain. Fly safe.",
	"halloran_gate": "Never been through. Kessler said I'd know it when I saw it. ...He was right.",
	"scratch_gate": "Tally always said he'd see this place. Guess I'm seeing it for him.",
}

## Default red: the Charter paints a repossessed rig red so no dock will service it.
## The Red Stork wears it. Draft.
var default_red := "Charter paints defaults red so no dock will touch them. Qasim missed three payments, watched them paint his rig, and took her back off the impound line the same night."

## Charter Recovery and navy customs. Drafts: the script doc wins.
var recovery := {
	"hail": "Owner-operator [red]CC-40817-M[/red], your account is in default. Cut engines and prepare to be boarded. Thank you for choosing the Charter.",
	"driven_off": "Damage to Charter property has been logged and billed to account CC-40817-M. Including the paint. Recovery will follow up.",
}
var customs := {
	"scan": "Charter rig, hold your course. Routine customs scan.",
	"clean": "You're clean. Fly safe, captain.",
	"bust": "Sealed cargo, no manifest. That's contraband, captain. Crates are seized, fine goes on your account.",
}
## The weekly no-questions job: a note pinned where Charter eyes don't look.
var shady := {
	"title": "NO QUESTIONS",
	"text": "Six crates, sealed. Take them to %s. Don't open them, don't scan them, don't get scanned. %s cr when they land. That's a week's payment, captain.",
	"sign": "a friend at Amber's",
	"tons": 6,
}
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
	"shady_take": "Sealed crates, no name on 'em. ...I'm not asking. I'm just saying I noticed.",
	"shady_done": "Payment's covered. Nobody got hurt. Probably. Let's not make it a habit.",
	"shady_again": "Same note, same crates. You know whose silver that is, right?",
	"shady_caught": "Well. Now the navy knows our names. Good start.",
	"strike": "Missed two. They're coming for the rig now. Pay or run, but pick fast.",
	"repo_fought": "We just shot at the company. I'd like that noted somewhere.",
}


# --- The rest of the Merchant opening ---------------------------------------------
# All lines approved by Vishnu (2026-11-20); the script doc wins on any change.

## The Tallyman's ambush on your first run into Marcellus (script doc: Tallyman).
var tally := {
	"hail": "Easy, easy. Charter colors on a rig that old? Let me guess. Eleven years, company terms, weekly payments.",
	"choices": [
		{"text": "Maybe.", "reply": "Maybe. Ha. That's what I used to say."},
		{"text": "Seven years, actually.", "reply": "Seven. They'll make it eleven. They always do."},
	],
	"silence": "Nothing? Fine. Quiet ones last longer out here.",
	"ignored": "Not picking up? Charter teach you that? I'll talk, you listen.",
	# what he thinks of how you fought.
	"fought_well": "You fly that brick like you mean it. Most Charter boys just cry on the open channel.",
	"fought_poorly": "Relax. If I wanted you dead, you'd know it.",
	"spare": "I'm not taking your cargo. Not this time. Keep paying them. You'll see.",
	"signoff": "Name's Tallyn. They call me the Tallyman. I keep count.",
	"dez": "He let us go. Why'd he let us go?",
}

## Lt. Franz Kessler (script doc: Franz).
var franz := {
	"arrival": "Federation Navy, Marcellus patrol. Captain, you hurt? ...The Tallyman. Again. That's the fourth Charter rig this month. He takes the rig, lets the crew walk, and paints another mark on his hull. But he left you alone. Huh.",
	"intro": "Lieutenant Franz Kessler. If you're hauling through the belt, you'll want friends out here. I post bounties at Four. Pays better than water.",
	"patched": "Engines are back. My crew can't fix the paint job. Finish your run, captain. We'll keep the belt quiet for an hour.",
	"at_four": "Five now. Another Charter rig this morning. He never takes the cargo. He just counts.",
	"pitch": "We're stretched thin, and honest pilots are rare out here. If you ever get tired of hauling for the Charter, the navy's hiring.",
	"paid": "Red Stork's done. Good work, captain. Bounty's yours.",
	"marines": "Take four of my marines. Knock her dead in the water, get alongside, and they'll do the rest. Alive pays better.",
	"paid_alive": "Prize crew brought the Red Stork in an hour ago. Clean work, captain. Alive rate, plus your share of her hold.",
}

## Kessler's board at Four. "alive" waits for boarding.
var bounty := {
	"id": "mud_lark", "hull": "mud_lark", "station": "ambers",
	"title": "BOUNTY: pirate skiff Red Stork",
	"text": "Repossessed Charter rig, default red, stolen back off the impound line by her own pilot. Raids out of Amber's now. 3,000 credits; alive pays 4,500.",
	"sign": "Lt. F. Kessler",
	"pay": 3000, "pay_alive": 4500,
	"crew": 3, "marines": 4,
	"hold": [["medicine", 8], ["electronics", 6]],
	"share": 0.2,   ## prize court: your cut of the hold's value
}

## Boarding plans (demo: Franz's marines). atk/def weight each round; share is
## how much of the hold survives.
var board_plans := [
	{"id": "storm", "name": "Storm the bridge", "note": "Fast and loud. The hold stays intact.",
		"atk": 1.1, "def": 1.0, "share": 1.0, "order": "Marines, storm the bridge."},
	{"id": "seal", "name": "Seal the crew in", "note": "Weld the hatches. Safer, but they'll vent cargo.",
		"atk": 1.0, "def": 0.5, "share": 0.4, "order": "Seal them in. No heroics."},
]

## Marines on comms during a boarding.
var marine_lines := {
	"ready": "Alongside. Pick a plan, captain.",
	"taken": "Ship's ours! Prize crew's taking her to Four.",
	"repelled": "They're dug in! Falling back, lost %d.",
	"none": "No marines left. Finish her for the dead bounty.",
}

## Bar captains at Saltgate, hired on weekly contracts (script doc: Phaedra, Mersham).
var captains := {
	"fay": {"name": "Fay", "full": "Phaedra \"Fay\" Andreou", "hull": "fay_skiff", "ship": "skiff", "wage": 150, "temper": "hesitant",
		"pitch": "You're the one with the freighter? Hire me. I've loaded, fixed, flown and fueled every ship that's ever docked at Saltgate. I'm cheap, I learn fast, and I really, really want to see the gate.",
		"hired": "You won't regret this! ...Probably!",
		"note": "Cheap, eager, green. Flies a patched-up skiff."},
	"mersham": {"name": "Mersham", "full": "Mersham Ali of Clan Karabey", "hull": "karabey_fighter", "ship": "lancer", "wage": 600, "ace": true, "temper": "presses",
		"pitch": "You fly a hauler, and your escorts fly like cargo. I flew for Clan Karabey, until the court decided my clan backed the wrong prince. My price is high. My aim is better.",
		"hired": "Point me at whoever's bothering you.",
		"note": "Clan Karabey ace. Expensive. Flies point."},
	# Fork wingmen: they come with a side you picked, not from the bar. Drafts.
	"navy_wing": {"name": "Mbeki", "full": "Petty Officer Mbeki, FNS Ulysses", "hull": "navy_wing", "ship": "FNS Ulysses", "wage": 0, "temper": "steady",
		"pitch": "", "hired": "Petty Officer Mbeki, FNS Ulysses, reporting, sir. Taking your port side. ...Sir, the channel was open. Everyone heard the part about my mother.", "note": "Navy interceptor on loan. Goes where you go, reports to Kessler."},
	"tally_wing": {"name": "Notch", "full": "\"Notch\", Tally's crew", "hull": "tally_escort", "ship": "raider", "wage": 0, "temper": "presses",
		"pitch": "", "hired": "Tally says you're on the list now. The good list. Don't make him cross you off.", "note": "One of the Tallyman's raiders. Flies with you because Tally said so."},
}
var captain_order := ["fay", "mersham"]
## the discovered bond when you hire both.
var captains_bond := ["Mersham", "Stay on my wing, girl. Watch what I do, not what I say.", "Fay", "...Yes, sir! I mean. Yes."]
var captain_lines := {
	"unpaid": "No pay, no wings. Find me at Saltgate when your books are better.",
	"down": "Punching out! Pick me up at the next dock.",
}

## The ending (script doc: Ending).
var ending := {
	"customs": "Writ of Passage, Charter file CC-40817-M... paid in full. Stamped. You're cleared to jump, captain. Don't come back broke.",
	"mersham": "...Home. Or what they made of it.",
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
	"Marines": {"channel": "CH 16  ·  BOARDING TEAM", "role": "Kessler's marines", "serial": "FN-MAR-04", "color": Color(0.45, 0.7, 1.0)},
	"Gate customs": {"channel": "CH 01  ·  AQUILA CUSTOMS", "role": "Gatehouse", "serial": "AQ-CUSTOMS", "color": Color(0.85, 0.85, 0.95)},
	"You": {"channel": "OUTBOUND", "role": "", "serial": "CC-40817-M", "color": Color(0.85, 0.92, 0.98)},
}

# --- Neon text: Katana Zero-style highlighted words in every line you read -------
## Colors per kind. Vishnu 2026-11-24: people white, Navy cobalt, credits greedy gold,
## Dynasty Ottoman green (extra glow), Tally ultraviolet in his own hand (pen font), rest column A.
## Lines can also carry tags: [shake]..[/shake], [wave]..[/wave], [red]..[/red],
## [slow]..[/slow]. Matching is case-sensitive except "threats".
var neon := {
	"colors": {
		"people": Color("#FFFFFF"), "places": Color("#FF4FD8"), "threats": Color("#FF2E4D"),
		"charter": Color("#FFB23A"), "navy": Color("#4D6BFF"), "dynasty": Color("#0FB866"),
		"tally": Color("#9B6BFF"), "credits": Color("#FFE27A"),
	},
	"people": ["Charlotte Hansen", "Charlie", "Desmond Okafor", "Dez", "Phaedra Andreou", "Fay",
		"Mersham Ali", "Mersham", "Lt. Franz Kessler", "Franz Kessler", "Lt. Kessler", "Kessler", "Franz",
		"Alejandra Vargas", "Alejandra", "Hollis Gray", "Hollis", "Jack Tallyn", "Tallyman", "Tally", "Qasim", "Petty Officer Mbeki", "Mbeki",
		"Notch", "Trojan", "Uncle Reeves", "Reeves", "Ines Kovac", "R. Pruitt", "Pruitt"],
	"places": ["Hesper March", "the Long Haul", "the Crossroads", "the Wall", "Saltgate", "Amber's", "Four",
		"the Drip", "the Bones", "the Counter", "the Grind", "the Gatehouse", "Wreckyard Nine", "Marcellus belt"],
	"charter": ["Charter Company", "the Charter", "Charter"],
	"navy": ["Federation Navy", "the Federation", "Federation", "the Navy", "Navy", "FNS Ulysses", "Ulysses"],
	"dynasty": ["the Dynasty", "Dynasty", "Clan Karabey", "Karabey"],
	"tally": ["Tally's crew", "Tally crew"],
	"threats": ["Charter Recovery", "Recovery", "repossession", "repossessed", "repossess", "repo", "strikes", "strike",
		"overdue", "default", "seized", "impound", "raiders", "pirates", "mayday"],
	## Click a highlighted word to open its journal page (M&B encyclopedia).
	## Names -> People entry; powers -> Powers id. Places resolve by station name/nick.
	"links": {
		"Charlotte Hansen": "Charlie", "Desmond Okafor": "Dez", "Phaedra Andreou": "Fay", "Mersham Ali": "Mersham",
		"Lt. Franz Kessler": "Franz", "Franz Kessler": "Franz", "Lt. Kessler": "Franz", "Kessler": "Franz",
		"Alejandra Vargas": "Alejandra", "Hollis Gray": "Hollis", "Jack Tallyn": "Tallyman", "Tally": "Tallyman", "Petty Officer Mbeki": "Mbeki",
		"charter": "charter", "navy": "federation", "dynasty": "dynasty", "tally": "grind",
		"the Wall": "gate", "the Gatehouse": "gate",
	},
}


func speaker_info(who: String) -> Dictionary:
	if speakers.has(who):
		return speakers[who]
	return {"channel": "OPEN BAND", "role": "", "serial": "", "color": Color(0.75, 0.8, 0.85)}

# --- The journal: who people are, and the powers you deal with ---------------------
## One line per person, as you'd write it in your logbook. Drafts.
var bios := {
	"Qasim": "Pilot of the Red Stork. Missed three Charter payments, watched them paint his rig default red, and stole her back off the impound line the same night. Raids on Dynasty coin now.",
	"Mbeki": "Petty Officer Mbeki, Federation Navy, flying the interceptor FNS Ulysses. On loan from Kessler's patrol. Young, by the book, and trying very hard.",
	"Notch": "One of the Tallyman's raiders. Flies with you because Tally said so. Talks less than Tally, counts more.",
	"Alejandra": "Alejandra Vargas, owner-operator of the Sweet Margaret, one number ahead of you in the Charter block. Calls every trucker family. Means it.",
	"Hollis": "Hollis Gray, owner-operator of Hollis' Girl. Named his rig after himself. Robbed on the Greenhouse lane, then billed for being late.",
	"Charlie": "Charlotte Hansen, Charter dispatch, third ring. Roots for you while working for the people who own your rig. Loses paperwork on purpose, sometimes.",
	"Dock crew": "Loading crews on every station. They'll load anything that's paid for, and remember who tips.",
	"Dez": "Desmond Okafor. Your oldest friend. Flies for free, cracks wise, and won't let you forget who you were.",
	"Franz": "Lt. Franz Kessler, Federation Navy, Marcellus patrol. Mining family, came up from the ranks. Decent, and stretched thin.",
	"Tallyman": "Jack Tallyn. Ex-Charter trucker the debt broke. Takes Charter rigs, lets the crews walk, keeps a tally on his hull.",
	"Fay": "Phaedra Andreou. Saltgate kid who has done every job on that dock. Cheap, eager, green. Wants to see the gate.",
	"Mersham": "Mersham Ali of Clan Karabey. Dynasty exile and ace. His clan backed the wrong prince.",
	"Marines": "Kessler's boarding team, on loan. Four of them, if you bring them all back.",
	"Gate customs": "Aquila customs at the Wall. Nothing goes through to the Crossroads without stamped papers.",
}

## Your own pen in the logbook's margin, next to each person and job. DRAFT lines.
var margin_notes := {
	"Charlie": "only kind voice on the company band",
	"Dock crew": "tip them. always tip them",
	"Dez": "same Dez. worse ship.",
	"Franz": "decent. tired. half the belt owes him",
	"Tallyman": "said my name like he'd read my file",
	"Fay": "eager. maybe too eager",
	"Mersham": "flies like he's done it in a war. he has",
	"Marines": "bring all four back",
	"Gate customs": "papers. always papers",
	"The Charter loan": "every week. every single week.",
	"Starter run: water": "\"easy money.\" Charlie isn't flying it",
	"An old friend": "won't take a credit. stubborn",
	"The Tallyman": "he didn't take the cargo. why?",
	"Bounty: the Red Stork": "alive pays better. alive is harder",
	"Saltgate bar": "can I even afford one of them?",
	"st_counter": "Charlie's on the third ring. bring coffee",
	"st_bones": "they'll fit anything. for a price",
	"st_drip": "leaks. smells like wet pennies",
	"st_greenhouse": "only place out here that smells green",
	"st_four": "Kessler's board. bounties",
	"st_saltgate": "good bar. captains for hire",
	"st_ambers": "too quiet out here",
	"st_gatehouse": "need papers. don't have papers",
}

## The powers, as seen from a freighter cockpit. wants/can/friend lines are DRAFTS. Standing text comes from the story so far.
var powers := [
	{"id": "charter", "name": "The Charter Company", "kind": "Federation-chartered monopoly",
		"desc": "Owns the routes, the dispatch board, and your rig until it's paid off. Bills weekly. Never forgets.",
		"wants": "Its money, every week, on time.", "can": "Repossess the rig. Pull your papers.", "friend": "Charlie in dispatch."},
	{"id": "federation", "name": "The Federation", "kind": "Great power  ·  the pocket behind the Wall",
		"desc": "Holds Hesper March and the interior behind its fortress gates. The navy keeps the core safe; the belt, less so.",
		"wants": "Taxes, quiet lanes, and pilots for the navy.", "can": "Arrest you. Close the Wall.", "friend": "Lt. Kessler, Marcellus patrol."},
	{"id": "grind", "name": "Pirates of the Grind", "kind": "Outlaws  ·  Marcellus belt",
		"desc": "Clans in the Marcellus rocks. Some sponsored, most not. The Tallyman hunts Charter rigs and nobody else.",
		"wants": "Your cargo, or your rig if it flies Charter colors.", "can": "Ion your engines and leave you drifting.", "friend": "Nobody. Yet."},
	{"id": "dynasty", "name": "The Dynasty", "kind": "Great power  ·  holds the Crossroads",
		"desc": "Warlords who stormed the old garrison after the Severance. Ruled by an aging, careful sultan. The heirs are circling.",
		"wants": "Tolls at the Crossroads. Loyalty, past it.", "can": "Shut the only road out.", "friend": "Mersham, if you hire him."},
	{"id": "league", "name": "The Merchant League", "kind": "Great power  ·  rumor",
		"desc": "Merchant houses on the lane stations past the Crossroads. Tolls on everything, they say.",
		"wants": "Trade. On their terms.", "can": "Nobody here knows.", "friend": "Nobody."},
]
