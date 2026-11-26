extends Control
## A menu drawn as neon text over the scene (docs/design/ui-look.md).
## Dark fade from the right, one tracked header, VT323 rows that flicker on.
## The picked row burns gold with a caret. Numbers are green, danger is red.
## Up/down or the mouse picks a row, Enter or a click opens it, Esc backs out,
## left/right steps a value. Long lists scroll with the pick.
## If `can_void`, Del (or the VOID hint) arms the row, a second press voids it.

signal chosen(i: int)
signal voided(i: int)
signal back

const ROW_SIZE := 32
const HEAD_SIZE := 24
const HINT_SIZE := 24
const SMALL := 20
const WHITE := Color(0.9, 0.9, 0.94)
const DIM := Color(0.47, 0.49, 0.56)
const OFF := Color(0.3, 0.31, 0.37)
const RED := Color(1.0, 0.3, 0.33)

var title := ""
## Each row: {"cells": [String...]} plus any of
##   "off": true      dim, can't be opened
##   "head": true     a small group label, never picked
##   "act": Callable  Enter / click
##   "step": Callable(dir: int)   left / right (a click steps +1, right click -1)
##   "tint": {cell index: Color}  colour for one cell
##   "danger": true   red when picked
##   "blurb": String  a few dim lines under the list while this row is picked
var rows: Array = []
var cols: Array = []                 ## x offset of each cell from the left edge
var heads: Array = []                ## optional small column heads
var num_cols: Array = []             ## cells drawn in green
var can_void := false
var row_h := 52.0
var note := ""                       ## one dim line under the list
var note_col := DIM
## Footer: [[key, verb, Callable]]. Empty = ENTER OPEN (DEL VOID) ESC BACK.
var hints: Array = []
## While valid, every key and mouse press goes here first (key rebinding).
var catcher := Callable()

var sel := 0
var _armed := -1
var _age := 0.0
var _scroll := 0.0
var _hint_rects: Array = []          ## [Rect2, Callable]


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size = get_parent().size if get_parent() is Control else get_viewport_rect().size
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	grab_focus.call_deferred()
	sel = _next_on(0, 1)
	Sfx.play("neon", -12.0)


## New rows for the same menu. `fresh` replays the flicker (a new page).
func set_rows(r: Array, fresh := false) -> void:
	rows = r
	_armed = -1
	if fresh:
		sel = 0
		_age = 0.0
		_scroll = 0.0
	sel = clampi(sel, 0, maxi(rows.size() - 1, 0))
	if rows.size() > 0 and not _landable(sel, false):
		sel = _next_on(sel, 1)
	_follow()
	queue_redraw()


func _process(delta: float) -> void:
	_age += delta
	if _age < 1.0 or _armed >= 0 or catcher.is_valid():
		queue_redraw()


func _left() -> float:
	return size.x - 600.0


func _top() -> float:
	return 200.0 + (30.0 if heads.size() > 0 else 0.0)


func _bottom() -> float:
	return size.y - 150.0


func _row_y(i: int) -> float:
	return _top() + i * row_h - _scroll


## Keep the picked row on screen.
func _follow() -> void:
	var span := _bottom() - _top()
	var y := sel * row_h
	# A row of air above and below the pick, so you can see what's next.
	if y - _scroll > span - row_h * 2.0:
		_scroll = minf(y - span + row_h * 2.0, maxf(0.0, rows.size() * row_h - span))
	elif y - row_h < _scroll:
		_scroll = maxf(0.0, y - row_h)
	if sel <= 1:
		_scroll = 0.0


func _landable(i: int, any: bool) -> bool:
	var r: Dictionary = rows[i]
	if r.get("head", false):
		return false
	return not r.get("off", false) or (can_void and any)


## The next row you can land on: live rows first; dead ones only when they can be voided.
func _next_on(from: int, step: int, any := false) -> int:
	for live_only in ([false] if any else [true, false]):
		for k in rows.size():
			var i := posmod(from + k * step, rows.size())
			if _landable(i, not live_only):
				return i
	return 0


# --- Input -----------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if not catcher.is_valid() or not is_visible_in_tree():
		return
	if (event is InputEventKey or event is InputEventMouseButton) and event.pressed:
		get_viewport().set_input_as_handled()
		catcher.call(event)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var i := _row_at(event.position)
		if i >= 0 and i != sel:
			_pick(i)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN or event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_pick(_next_on(sel + (1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1),
				1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1, true))
		elif event.button_index == MOUSE_BUTTON_LEFT:
			for h in _hint_rects:
				if h[0].has_point(event.position):
					if h[1].is_valid():
						h[1].call()
					accept_event()
					return
			var i := _row_at(event.position)
			if i >= 0:
				sel = i
				if rows[i].has("step") and not rows[i].has("act"):
					_step(1)
				else:
					_open(i)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			var i := _row_at(event.position)
			if i >= 0 and rows[i].has("step"):
				sel = i
				_step(-1)
		accept_event()
	elif event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_UP, KEY_W:
				_pick(_next_on(sel - 1, -1, true))
			KEY_DOWN, KEY_S:
				_pick(_next_on(sel + 1, 1, true))
			KEY_LEFT, KEY_A:
				_step(-1)
			KEY_RIGHT, KEY_D:
				_step(1)
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				if not event.echo:
					_open(sel)
			KEY_DELETE, KEY_BACKSPACE:
				if not event.echo:
					_void()
			KEY_ESCAPE:
				if not event.echo:
					_back()
			_:
				return
		accept_event()


func _row_at(p: Vector2) -> int:
	if p.x < _left() - 40.0 or p.y < _top() - row_h * 0.5 or p.y > _bottom() + row_h * 0.5:
		return -1
	for i in rows.size():
		var y := _row_y(i)
		if p.y >= y - row_h * 0.5 and p.y < y + row_h * 0.5:
			return i if _landable(i, true) else -1
	return -1


func _pick(i: int) -> void:
	if i == sel:
		return
	sel = i
	_armed = -1
	_follow()
	Sfx.play("tick", -16.0, 1.4)
	queue_redraw()


func _open(i: int) -> void:
	if i < 0 or i >= rows.size() or rows[i].get("off", false) or rows[i].get("head", false):
		return
	sel = i
	Sfx.play("tick", -6.0)
	if rows[i].has("act"):
		rows[i]["act"].call()
	else:
		chosen.emit(i)


func _step(d: int) -> void:
	if rows.is_empty() or not rows[sel].has("step"):
		return
	Sfx.play("tick", -8.0, 1.0 + 0.1 * d)
	rows[sel]["step"].call(d)


func _void() -> void:
	if not can_void or rows.is_empty():
		return
	if _armed != sel:
		_armed = sel
		Sfx.play("tick", -6.0, 0.7)
		queue_redraw()
		return
	_armed = -1
	Sfx.play("stamp", -4.0)
	voided.emit(sel)


func _back() -> void:
	Sfx.play("tick", -6.0)
	back.emit()


# --- Drawing ---------------------------------------------------------------------

## Text with a soft neon bloom behind it.
func _glow(f: Font, pos: Vector2, s: String, sz: int, col: Color, a: float) -> void:
	for o in [Vector2(-2, 0), Vector2(2, 0), Vector2(0, -2), Vector2(0, 2), Vector2(-3, -3), Vector2(3, 3)]:
		draw_string(f, pos + o, s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color(col, 0.13 * a))
	draw_string(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color(col, a))


## Flicker on: each row stutters in, one after the other.
func _flicker(i: int) -> float:
	var t := _age - 0.04 * mini(i, 8)
	if t <= 0.0:
		return 0.0
	if t > 0.22:
		return 1.0
	return [1.0, 0.15, 0.8, 0.0, 1.0, 0.4][int(t / 0.04) % 6]


func _draw() -> void:
	var x0 := _left()
	var fade_from := x0 - 260.0
	var steps := 40
	for k in steps:
		var x := fade_from + (size.x - fade_from) * k / steps
		var w := (size.x - fade_from) / steps + 1.0
		draw_rect(Rect2(x, 0, w, size.y), Color(0.016, 0.02, 0.047, 0.88 * minf(1.0, float(k) / 14.0)))
	for y in range(0, int(size.y), 3):
		draw_line(Vector2(x0 - 120.0, y), Vector2(size.x, y), Color(0, 0, 0, 0.22), 1.0)

	var talk: Font = Data.font_talk
	var bold: Font = Data.font_bold
	var head_a := _flicker(0)
	var tx := x0
	for ch in title:
		draw_string(bold, Vector2(tx, 140), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, HEAD_SIZE, Color(1, 1, 1, head_a))
		tx += bold.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, HEAD_SIZE).x + 7.0
	for c in heads.size():
		draw_string(talk, Vector2(x0 + cols[c], _top() - 42.0), heads[c], HORIZONTAL_ALIGNMENT_LEFT, -1, SMALL, Color(OFF, head_a))

	var top := _top() - row_h * 0.5
	var bottom := _bottom() + row_h * 0.5
	for i in rows.size():
		var yc := _row_y(i)
		if yc < top or yc > bottom:
			continue
		var a := _flicker(i + 1)
		# Rows fade out as they scroll past the edges.
		a *= clampf(minf(yc - top, bottom - yc) / row_h, 0.0, 1.0)
		var r: Dictionary = rows[i]
		var y := yc + ROW_SIZE * 0.3
		if r.get("head", false):
			draw_string(talk, Vector2(x0, yc + 8.0), str(r["cells"][0]).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, SMALL, Color(OFF, a))
			continue
		var on := i == sel
		var off: bool = r.get("off", false)
		if i == _armed:
			var pulse := 0.75 + 0.25 * sin(_age * 9.0)
			_glow(talk, Vector2(x0 - 26, y), ">", ROW_SIZE, RED, a)
			_glow(talk, Vector2(x0, y), "VOID %s?   DEL AGAIN" % str(r["cells"][0]).to_upper(), ROW_SIZE, RED, a * pulse)
			continue
		var pick := RED if r.get("danger", false) else UIStyle.GOLD
		if on:
			_glow(talk, Vector2(x0 - 26, y), ">", ROW_SIZE, pick, a)
		var tint: Dictionary = r.get("tint", {})
		for c in r["cells"].size():
			var s := str(r["cells"][c]).to_upper()
			var col: Color = OFF if off else (UIStyle.GREEN if c in num_cols else (pick if on else WHITE))
			if tint.has(c) and not off:
				col = tint[c]
			var p := Vector2(x0 + cols[c], y)
			if on and not off:
				_glow(talk, p, s, ROW_SIZE, col, a)
			else:
				draw_string(talk, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, ROW_SIZE, Color(col, a))

	if note != "":
		draw_string(talk, Vector2(x0, size.y - 104.0), note.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, 560, SMALL, Color(note_col, head_a))
	# A row's own blurb, under the list, while it's picked.
	if not rows.is_empty() and rows[sel].has("blurb"):
		var by := _row_y(rows.size() - 1) + row_h * 0.5 + 30.0
		draw_multiline_string(talk, Vector2(x0, by), str(rows[sel]["blurb"]), HORIZONTAL_ALIGNMENT_LEFT,
			540, 24, 6, Color(DIM, _flicker(rows.size() + 1)))

	_hint_rects.clear()
	var hs := hints
	if hs.is_empty():
		hs = [["ENTER", "OPEN", _open.bind(sel)]]
		if can_void:
			hs.append(["DEL", "VOID", _void])
		hs.append(["ESC", "BACK", _back])
	var hx := x0
	var hy := size.y - 60.0
	for h in hs:
		var key: String = h[0]
		var verb: String = h[1]
		var kw := talk.get_string_size(key + "  ", HORIZONTAL_ALIGNMENT_LEFT, -1, HINT_SIZE).x
		var vw := talk.get_string_size(verb, HORIZONTAL_ALIGNMENT_LEFT, -1, HINT_SIZE).x
		draw_string(talk, Vector2(hx, hy), key, HORIZONTAL_ALIGNMENT_LEFT, -1, HINT_SIZE, Color(OFF, head_a))
		var vc := RED if verb == "VOID" and _armed >= 0 else DIM
		draw_string(talk, Vector2(hx + kw, hy), verb, HORIZONTAL_ALIGNMENT_LEFT, -1, HINT_SIZE, Color(vc, head_a))
		_hint_rects.append([Rect2(hx - 6, hy - 22, kw + vw + 12, 30), h[2]])
		hx += kw + vw + 56.0
