extends Control
## The first launch of a new career: your Charter ID card drops in over the
## Counter while the rig clears the berth, then dispatch calls.

signal finished

var _t := 0.0
const HOLD := 5.5
const CARD := Vector2(560, 250)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Sfx.play("paper", -6.0)


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
	var in_k := clampf(_t / 0.5, 0.0, 1.0)
	var out_k := clampf((_t - HOLD) / 0.5, 0.0, 1.0)
	var ease_in := 1.0 - pow(1.0 - in_k, 3.0)
	var a := 1.0 - out_k
	var pos := Vector2((vp.x - CARD.x) * 0.5, lerpf(-CARD.y - 20.0, vp.y * 0.16, ease_in) - out_k * 40.0)
	var r := Rect2(pos, CARD)
	draw_set_transform(r.get_center(), deg_to_rad(-1.5), Vector2.ONE)
	r.position = -CARD * 0.5
	# Card stock with a printed header band.
	draw_rect(Rect2(r.position + Vector2(4, 6), r.size), Color(0, 0, 0, 0.35 * a))
	draw_rect(r, Color(UIStyle.PAPER, a))
	draw_rect(Rect2(r.position, Vector2(r.size.x, 34)), Color(UIStyle.INK_TYPE, 0.9 * a))
	var ft: Font = Data.font_type_bold
	var fr: Font = Data.font_type
	draw_string(ft, r.position + Vector2(16, 23), "THE CHARTER COMPANY  ·  LICENSED OPERATOR", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(UIStyle.PAPER, a))
	draw_string(fr, r.position + Vector2(r.size.x - 130, 23), "CC-40817-M", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(UIStyle.PAPER, 0.75 * a))
	# Photo.
	var ph := Rect2(r.position + Vector2(18, 50), Vector2(128, 162))
	UIStyle.draw_id_photo(self, ph, [Color(0.8, 0.65, 0.5), Color(0.2, 0.15, 0.1), Color(0.3, 0.35, 0.4)], "", 7, "You")
	if a < 1.0:
		draw_rect(ph.grow(4), Color(UIStyle.PAPER, 1.0 - a))
	# Fields.
	var x := ph.end.x + 22.0
	var y := r.position.y + 62.0
	for f in [["OPERATOR", str(Career.pilot.get("name", ""))], ["RIG", str(Career.pilot.get("rig", ""))],
			["LIEN", "%s cr owed" % _num(Career.loan_balance)]]:
		draw_string(fr, Vector2(x, y), f[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(UIStyle.INK_FADED, a))
		var hand: bool = f[0] != "LIEN"
		draw_string(Data.font_hand if hand else fr, Vector2(x, y + (28.0 if hand else 20.0)), f[1], HORIZONTAL_ALIGNMENT_LEFT, r.end.x - x - 16.0, 28 if hand else 15, Color(UIStyle.INK_PEN if hand else UIStyle.INK_TYPE, a))
		y += 50.0
	# Stamp, once the card has landed.
	if _t > 1.1:
		var sk := clampf((_t - 1.1) / 0.12, 0.0, 1.0)
		var sc := lerpf(1.6, 1.0, sk)
		draw_set_transform(pos + CARD * 0.5 + Vector2(140, 100), deg_to_rad(-8.0), Vector2(sc, sc))
		var col := Color(UIStyle.INK_STAMP, 0.85 * a * sk)
		var w := Data.font_stamp.get_string_size("CLEARED TO UNDOCK", HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
		draw_rect(Rect2(Vector2(-w * 0.5 - 10, -26), Vector2(w + 20, 36)), col, false, 3.0)
		draw_string(Data.font_stamp, Vector2(-w * 0.5, 2), "CLEARED TO UNDOCK", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_string(fr, Vector2(vp.x * 0.5 - 80, pos.y + CARD.y + 34), "Day 1  ·  Aurelia, the Plate", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.6 * a))


func _num(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out
