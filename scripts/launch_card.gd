extends Control
## The first launch of a new career: your Charter ID card flickers on in neon
## (docs/design/ui-look.md) while the rig clears the berth, then dispatch calls.

signal finished

var _t := 0.0
const HOLD := 5.5
const CARD := Vector2(560, 250)
const PINK := Color(1.0, 0.43, 0.75)
const OFF := Color(0.3, 0.31, 0.37)
const RED := Color(1.0, 0.3, 0.33)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Sfx.play("flip", -8.0)


func _process(delta: float) -> void:
	_t += delta
	if _t > HOLD + 0.6:
		finished.emit()
		queue_free()
	queue_redraw()


func skip() -> void:
	_t = maxf(_t, HOLD)


func _draw() -> void:
	var vp := size
	var a := 1.0 - clampf((_t - HOLD) / 0.5, 0.0, 1.0)
	# Flicker on, like the neon menus.
	if _t < 0.35:
		a *= [1.0, 0.15, 0.8, 0.3, 1.0][int(_t / 0.07) % 5]
	var pos := Vector2((vp.x - CARD.x) * 0.5, vp.y * 0.16)
	var r := Rect2(pos, CARD)
	# A dark wash, soft at the edges, scanlines on it. No box.
	for k in 14:
		var g := 70.0 - k * 5.0
		draw_rect(r.grow_individual(g, minf(g, 14.0), g, g), Color(0.016, 0.02, 0.047, 0.19 * a))
	for y in range(int(r.position.y - 10.0), int(r.end.y + 30.0), 3):
		draw_line(Vector2(r.position.x - 30.0, y), Vector2(r.end.x + 30.0, y), Color(0, 0, 0, 0.18 * a), 1.0)
	var talk: Font = Data.font_talk
	var bold: Font = Data.font_bold
	var tx := r.position.x
	for ch in "THE CHARTER COMPANY":
		draw_string(bold, Vector2(tx, r.position.y + 22.0), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 1, 1, a))
		tx += bold.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x + 7.0
	draw_string(talk, r.position + Vector2(0, 50), "LICENSED OPERATOR", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(OFF, a))
	draw_string(talk, r.position + Vector2(0, 50), "CC-40817-M", HORIZONTAL_ALIGNMENT_RIGHT, CARD.x, 20, Color(OFF, a))
	# Photo in a gold frame.
	var ph := Rect2(r.position + Vector2(8, 72), Vector2(120, 152))
	UIStyle.draw_id_photo(self, ph, [Color(0.8, 0.65, 0.5), Color(0.2, 0.15, 0.1), Color(0.3, 0.35, 0.4)], "CC-40817-M", 7, "pilot_%d" % int(Career.pilot.get("photo", 0)))
	draw_rect(ph.grow(8), Color(UIStyle.GOLD, 0.18 * a), false, 4.0)
	draw_rect(ph.grow(8), Color(UIStyle.GOLD, 0.7 * a), false, 1.0)
	# Names in your hand, pink; the lien in green.
	var x := ph.end.x + 34.0
	var y := ph.position.y + 8.0
	var hand: Font = Data.font_hand
	for f in [["OPERATOR", str(Career.pilot.get("name", ""))], ["RIG", str(Career.pilot.get("rig", ""))]]:
		draw_string(talk, Vector2(x, y), f[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(OFF, a))
		for o in [Vector2(-2, 0), Vector2(2, 0), Vector2(0, -2), Vector2(0, 2)]:
			draw_string(hand, Vector2(x, y + 34.0) + o, f[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color(PINK, 0.16 * a))
		draw_string(hand, Vector2(x, y + 34.0), f[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color(1.0, 0.72, 0.87, a))
		y += 56.0
	draw_string(talk, Vector2(x, y), "LIEN", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(OFF, a))
	draw_string(talk, Vector2(x, y + 30.0), "%s CR" % _num(Career.loan_balance), HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color(UIStyle.GREEN, a))
	# CLEARED TO UNDOCK: a red neon stamp that slams on and buzzes.
	if _t > 1.1:
		var st := _t - 1.1
		var sa: float = (1.0 if st > 0.15 else [1.0, 0.2, 1.0][int(st / 0.05) % 3]) * a
		var w := Data.font_stamp.get_string_size("CLEARED TO UNDOCK", HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
		draw_set_transform(Vector2(r.end.x - w - 10.0, r.end.y - 6.0), deg_to_rad(-6.0))
		var sr := Rect2(Vector2(-12, -34), Vector2(w + 24, 44))
		draw_rect(sr.grow(4), Color(RED, 0.15 * sa), false, 6.0)
		draw_rect(sr, Color(RED, 0.9 * sa), false, 2.0)
		draw_string(Data.font_stamp, Vector2(0, 0), "CLEARED TO UNDOCK", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(RED, 0.9 * sa))
		draw_set_transform(Vector2.ZERO)


func _num(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out
