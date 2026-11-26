extends "res://scripts/neon_menu.gd"
## Form ID-1 in neon (docs/design/ui-look.md): your Charter photo up top, then
## your name and your rig's name in your own hand, glowing pink. Enter on a
## name writes it; left/right flips the photo. FILE IT goes to the next form.

signal filed

const PINK := Color(1.0, 0.43, 0.75)
const PHOTO := Vector2(150, 190)
const PHOTO_Y := 186.0

var pilot: Dictionary = {}        ## name, rig, photo; shared with the title screen
var _edit: LineEdit
var _arrows: Array = []           ## [Rect2, dir]: click either side of the photo to flip it


func _ready() -> void:
	title = "THE CHARTER COMPANY"
	cols = [0.0, 230.0]
	hints = [["ENTER", "WRITE", func(): _open(sel)], ["< >", "PHOTO", Callable()], ["ESC", "BACK", _back]]
	_fill()
	super._ready()


func _top() -> float:
	return PHOTO_Y + PHOTO.y + 64.0


func _fill() -> void:
	var r := [
		{"cells": ["Operator", ""], "act": _write.bind("name", 0), "step": _photo},
		{"cells": ["Rig", ""], "act": _write.bind("rig", 1), "step": _photo},
		{"cells": ["Class", "light freighter, used"], "off": true},
		{"cells": ["File it", ""], "act": _file_it},
	]
	set_rows(r)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not _edit:
		for h in _arrows:
			if (h[0] as Rect2).has_point(event.position):
				_photo(h[1])
				accept_event()
				return
	if event is InputEventMouseMotion:
		queue_redraw()
	super._gui_input(event)


func _photo(d: int) -> void:
	pilot["photo"] = posmod(int(pilot["photo"]) + d, Data.PILOT_PHOTOS)
	Sfx.play("flip", -10.0, 1.3)
	queue_redraw()


func _file_it() -> void:
	for k in ["name", "rig"]:
		pilot[k] = str(pilot[k]).strip_edges()
		if pilot[k] == "":
			pilot[k] = (Data.pilot_names if k == "name" else Data.rig_names).pick_random()
	filed.emit()


## Write a name: a pink pen line opens where the name sits. Enter keeps it, Esc drops it.
func _write(key: String, row: int) -> void:
	if _edit:
		return
	var e := LineEdit.new()
	e.text = str(pilot[key])
	e.max_length = 24
	e.flat = true
	e.caret_blink = true
	e.select_all_on_focus = true
	e.add_theme_font_override("font", Data.font_hand)
	e.add_theme_font_size_override("font_size", 40)
	e.add_theme_color_override("font_color", Color(1.0, 0.72, 0.87))
	e.add_theme_color_override("caret_color", PINK)
	e.add_theme_color_override("selection_color", Color(PINK, 0.25))
	e.add_theme_color_override("font_selected_color", Color.WHITE)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = Color(PINK, 0.5)
	sb.border_width_bottom = 1
	for st in ["normal", "focus", "read_only"]:
		e.add_theme_stylebox_override(st, sb)
	e.position = Vector2(_left() + cols[1] - 4.0, _row_y(row) - 28.0)
	e.size = Vector2(350, 50)
	add_child(e)
	_edit = e
	e.grab_focus()
	var done := func(keep: bool):
		if keep and e.text.strip_edges() != "":
			pilot[key] = e.text.strip_edges()
		_edit = null
		e.queue_free()
		grab_focus()
		queue_redraw()
	e.text_submitted.connect(func(_t): done.call(true))
	e.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventKey and ev.pressed and ev.keycode == KEY_ESCAPE:
			e.accept_event()
			done.call(false))
	e.focus_exited.connect(func():
		if _edit == e:
			done.call(true))


func _draw() -> void:
	super._draw()
	var talk: Font = Data.font_talk
	var x0 := _left()
	var a := _flicker(0)
	draw_string(talk, Vector2(x0, 168), "FORM ID-1   LICENSED OPERATOR", HORIZONTAL_ALIGNMENT_LEFT, -1, SMALL, Color(OFF, a))
	draw_string(talk, Vector2(x0, 168), "CC-40817-M", HORIZONTAL_ALIGNMENT_RIGHT, 585, SMALL, Color(OFF, a))
	if pilot.is_empty():
		return
	# The photo, a thin neon frame round it, arrows either side.
	var pr := Rect2(Vector2(x0, PHOTO_Y + 10.0), PHOTO)
	UIStyle.draw_id_photo(self, pr, [Color(0.8, 0.65, 0.5), Color(0.2, 0.15, 0.1), Color(0.3, 0.35, 0.4)], "CC-40817-M", 7, "pilot_%d" % pilot["photo"])
	draw_rect(pr.grow(8), Color(UIStyle.GOLD, 0.18 * a), false, 4.0)
	draw_rect(pr.grow(8), Color(UIStyle.GOLD, 0.7 * a), false, 1.0)
	# Arrows you can click, either side of the photo; left/right keys flip it too.
	_arrows.clear()
	var mid := pr.position.y + pr.size.y * 0.5
	for d in [-1, 1]:
		var c := Vector2(pr.position.x - 34.0 if d < 0 else pr.end.x + 34.0, mid)
		var hot := Rect2(c - Vector2(22, 30), Vector2(44, 60))
		_arrows.append([hot, d])
		var on := hot.has_point(get_local_mouse_position())
		var col := Color(UIStyle.GOLD, a * (1.0 if on else 0.75))
		draw_colored_polygon(PackedVector2Array([c + Vector2(10 * d, 0), c + Vector2(-8 * d, -14), c + Vector2(-8 * d, 14)]), col)
	draw_string(talk, Vector2(x0 + PHOTO.x + 64.0, PHOTO_Y + 104.0), "PHOTO %d OF %d" % [int(pilot["photo"]) + 1, Data.PILOT_PHOTOS],
		HORIZONTAL_ALIGNMENT_LEFT, -1, SMALL, Color(UIStyle.GOLD, a))
	draw_string(talk, Vector2(x0 + PHOTO.x + 64.0, PHOTO_Y + 130.0), "CLICK THE ARROWS OR < >",
		HORIZONTAL_ALIGNMENT_LEFT, -1, SMALL, Color(DIM, a))
	# Your names, in your own hand, glowing pink.
	var hand: Font = Data.font_hand
	for i in 2:
		var key: String = ["name", "rig"][i]
		var p := Vector2(x0 + cols[1], _row_y(i) + 12.0)
		if _edit and absf(_edit.position.y - (_row_y(i) - 28.0)) < 1.0:
			continue
		for o in [Vector2(-2, 0), Vector2(2, 0), Vector2(0, -2), Vector2(0, 2)]:
			draw_string(hand, p + o, str(pilot[key]), HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(PINK, 0.16 * a))
		draw_string(hand, p, str(pilot[key]), HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(1.0, 0.72, 0.87, a))
