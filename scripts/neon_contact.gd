extends "res://scripts/neon_menu.gd"
## Form NK-2 in neon (docs/design/ui-look.md): Dez on your emergency-contact
## form. His photo and his names in your hand up top, then how you know him:
## tick one. The picked line's story and what it puts on file show beneath.
## FILE IT stamps the form and you're off.

signal filed(bg: String)

const PINK := Color(1.0, 0.43, 0.75)
const PHOTO := Vector2(104, 132)
const PHOTO_Y := 190.0

var bg := ""                      ## the ticked background
var _stamped := -1.0


func _ready() -> void:
	title = "THE CHARTER COMPANY"
	cols = [0.0, 52.0]
	row_h = 46.0
	hints = [["ENTER", "TICK", func(): _open(sel)], ["ESC", "BACK", _back]]
	if bg == "":
		bg = Data.friend_background_order[0]
	_fill()
	super._ready()
	sel = Data.friend_background_order.find(bg)


func _top() -> float:
	return PHOTO_Y + PHOTO.y + 78.0


func _fill() -> void:
	var r := []
	for k in Data.friend_background_order:
		var b: Dictionary = Data.friend_backgrounds[k]
		var role: Dictionary = Data.friend_roles[b["role"]]
		var mem: Dictionary = Data.friend_memories[b["memory"]]
		var td: String = mem["trait_desc"]
		var perk: String = td.split(":")[1].split("(")[0].strip_edges() if ":" in td else td
		r.append({"cells": ["[x]" if k == bg else "[ ]", b["title"]],
			"tint": {0: PINK if k == bg else OFF},
			"blurb": "%s\nOn file: flies a %s. %s %s" % [b["typed"], role["ship"], role["bonus"], perk[0].to_upper() + perk.substr(1)],
			"act": _tick.bind(k)})
	r.append({"cells": ["", "File it"], "act": _file_it})
	set_rows(r)


func _tick(k: String) -> void:
	if bg == k:
		return
	bg = k
	Sfx.play("pen", -10.0, 1.3)
	_fill()


func _file_it() -> void:
	if _stamped >= 0.0:
		return
	_stamped = 0.0
	Sfx.play("stamp", -2.0)
	get_tree().create_timer(1.0).timeout.connect(func(): filed.emit(bg))


func _process(delta: float) -> void:
	super._process(delta)
	if _stamped >= 0.0:
		_stamped += delta
		queue_redraw()


func _draw() -> void:
	super._draw()
	var talk: Font = Data.font_talk
	var hand: Font = Data.font_hand
	var x0 := _left()
	var a := _flicker(0)
	draw_string(talk, Vector2(x0, 168), "FORM NK-2   EMERGENCY CONTACT", HORIZONTAL_ALIGNMENT_LEFT, -1, SMALL, Color(OFF, a))
	draw_string(talk, Vector2(x0, 168), "NK-40817-1", HORIZONTAL_ALIGNMENT_RIGHT, 585, SMALL, Color(OFF, a))
	# Dez, in a gold frame.
	var pr := Rect2(Vector2(x0, PHOTO_Y + 8.0), PHOTO)
	UIStyle.draw_id_photo(self, pr, Data.speaker_portraits["Dez"], "NK-40817-1", 9, "Dez")
	draw_rect(pr.grow(8), Color(UIStyle.GOLD, 0.18 * a), false, 4.0)
	draw_rect(pr.grow(8), Color(UIStyle.GOLD, 0.7 * a), false, 1.0)
	# His names, in your hand.
	var fx := x0 + PHOTO.x + 34.0
	var fy := PHOTO_Y + 14.0
	for f in [["NAME", Data.FRIEND_FULL_NAME], ["GOES BY", Data.FRIEND_NAME], ["RELATIONSHIP", "Best Friend."]]:
		draw_string(talk, Vector2(fx, fy), f[0], HORIZONTAL_ALIGNMENT_LEFT, -1, SMALL, Color(OFF, a))
		_pen(hand, Vector2(fx, fy + 30.0), f[1], 32, a)
		fy += 46.0
	draw_string(talk, Vector2(x0, _top() - 34.0), "HOW KNOWN TO APPLICANT   TICK ONE", HORIZONTAL_ALIGNMENT_LEFT, -1, SMALL, Color(OFF, a))
	# FILED: a red neon stamp that slams on and buzzes.
	if _stamped >= 0.0:
		var sa: float = 1.0 if _stamped > 0.15 else [1.0, 0.2, 1.0][int(_stamped / 0.05) % 3]
		var sp := Vector2(x0 + 300.0, _row_y(rows.size() - 1) + 12.0)
		draw_set_transform(sp, deg_to_rad(-6.0))
		var sr := Rect2(Vector2(-8, -44), Vector2(170, 58))
		draw_rect(sr.grow(4), Color(RED, 0.15 * sa), false, 6.0)
		draw_rect(sr, Color(RED, 0.9 * sa), false, 2.0)
		draw_string(Data.font_stamp, Vector2(6, 0), "FILED", HORIZONTAL_ALIGNMENT_LEFT, -1, 52, Color(RED, 0.9 * sa))
		draw_set_transform(Vector2.ZERO)


## Pen in pink neon: a soft bloom, then the stroke.
func _pen(f: Font, p: Vector2, s: String, sz: int, a: float) -> void:
	for o in [Vector2(-2, 0), Vector2(2, 0), Vector2(0, -2), Vector2(0, 2)]:
		draw_string(f, p + o, s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color(PINK, 0.16 * a))
	draw_string(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color(1.0, 0.72, 0.87, a))
