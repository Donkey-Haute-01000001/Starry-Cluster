extends "res://scripts/neon_menu.gd"
## A start's file in neon (docs/design/ui-look.md): the issuer up top, the
## opening typing onto the dark a beat at a time, the terms in green and one
## line to sign. Your margin note glows pink, like a sign in a window.
## Enter or a click finishes the beat that's typing before it signs.

signal sandbox

const BeatsOnPaper = preload("res://scripts/beats_on_paper.gd")
const PINK := Color(1.0, 0.43, 0.75)
const BEATS_Y := 190.0
const TERMS_H := 62.0

var start: Dictionary = {}
var animate := true
var beats: Control
var _ink := 0.0            ## signature drawn so far, 0..1 (-1 = not signing)


func _ready() -> void:
	var doc: Dictionary = start["doc"]
	title = doc["issuer"]
	cols = [0.0]
	if start["playable"]:
		set_rows([{"cells": ["Sign here"]}])
		hints = [["ENTER", "SIGN", func(): _open(0)], ["ESC", "ALL FILES", _back], ["F2", "SANDBOX", sandbox.emit]]
	else:
		set_rows([{"cells": ["Sealed"], "off": true}])
		hints = [["ESC", "ALL FILES", _back], ["F2", "SANDBOX", sandbox.emit]]
	hint_gap = 34.0
	super._ready()
	beats = BeatsOnPaper.new()
	beats.neon = true
	beats.text_size = 26
	beats.beats = start["beats"]
	beats.width = 585.0
	beats.instant = not animate
	# Room for the opening between the header and the terms + sign line.
	beats.clip_contents = true
	beats.max_h = size.y - BEATS_Y - (TERMS_H if start["playable"] else 0.0) - 34.0 - row_h - 70.0
	beats.position = Vector2(_left(), BEATS_Y)
	add_child(beats)
	_ink = -1.0


func _process(delta: float) -> void:
	super._process(delta)
	if _ink >= 0.0 and _ink < 1.0:
		_ink = minf(_ink + delta * 1.6, 1.0)
	queue_redraw()   # the note glows in once the opening is down


func _top() -> float:
	var h: float = beats.custom_minimum_size.y if beats else 0.0
	return BEATS_Y + h + (TERMS_H if start.get("playable", false) else 0.0) + 34.0


func _bottom() -> float:
	return size.y - 70.0


## While the opening is still typing, Enter finishes the beat instead of signing.
func _open(i: int) -> void:
	if beats and not beats.done():
		beats.advance()
		return
	if _ink >= 0.0:
		return
	super._open(i)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F2:
		sandbox.emit()
		accept_event()
		return
	super._gui_input(event)


## The pen scrawls across the sign line in pink neon.
func scrawl() -> void:
	_ink = 0.0
	Sfx.play("pen", -2.0)


func _draw() -> void:
	super._draw()
	var talk: Font = Data.font_talk
	var x0 := _left()
	var doc: Dictionary = start["doc"]
	var a := _flicker(0)
	draw_string(talk, Vector2(x0, 168), doc["title"].to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, SMALL, Color(OFF, a))
	draw_string(talk, Vector2(x0, 168), doc["file"], HORIZONTAL_ALIGNMENT_RIGHT, 560, SMALL, Color(OFF, a))
	if not beats:
		return
	var done: bool = beats.done()
	var ty := BEATS_Y + beats.custom_minimum_size.y + 14.0
	if start["playable"]:
		var terms := [["PRINCIPAL", "%s cr" % _cr(Data.LOAN_TOTAL), 0.0], ["WEEKLY", "%s cr" % _cr(Data.LOAN_WEEKLY), 190.0],
			["LATE", "+%d%%" % int(Data.LOAN_INTEREST * 100), 350.0]]
		for t in terms:
			draw_string(talk, Vector2(x0 + t[2], ty), t[0], HORIZONTAL_ALIGNMENT_LEFT, -1, SMALL, Color(OFF, a))
			draw_string(talk, Vector2(x0 + t[2], ty + 26), t[1].to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, ROW_SIZE, Color(UIStyle.GREEN, a))
	# Your note, in your hand, glowing in once the opening is down.
	var hand: Font = Data.font_hand
	if done and hand:
		var na := clampf(beats._age - beats._beat_end(), 0.0, 1.0) if not beats.instant else 1.0
		# Right-aligned to the text column, so a long note never runs off screen.
		# A long note writes smaller to fit beside the sign line.
		var ns := 40
		var nw := hand.get_string_size(doc["note"], HORIZONTAL_ALIGNMENT_LEFT, -1, ns).x
		if nw > 420.0:
			ns = int(ns * 420.0 / nw)
			nw = hand.get_string_size(doc["note"], HORIZONTAL_ALIGNMENT_LEFT, -1, ns).x
		var np := Vector2(x0 + 585.0 - nw, _row_y(0) + 14.0)
		for o in [Vector2(-2, 0), Vector2(2, 0), Vector2(0, -2), Vector2(0, 2)]:
			draw_string(hand, np + o, doc["note"], HORIZONTAL_ALIGNMENT_LEFT, -1, ns, Color(PINK, 0.16 * na))
		draw_string(hand, np, doc["note"], HORIZONTAL_ALIGNMENT_LEFT, -1, ns, Color(1.0, 0.72, 0.87, na))
	# The signature: a loopy neon line across the sign row.
	if _ink > 0.0:
		var pts := PackedVector2Array()
		var n := int(60 * _ink)
		var w := 200.0
		var base := Vector2(x0 + 10.0, _row_y(0))
		for i in n:
			var u := i / 60.0
			pts.append(base + Vector2(u * w, sin(u * 23.0) * 10.0 * (1.0 - u * 0.6) - u * 8.0 + cos(u * 9.0) * 4.0))
		if pts.size() > 1:
			draw_polyline(pts, Color(PINK, 0.25), 6.0, true)
			draw_polyline(pts, Color(1.0, 0.8, 0.9), 2.0, true)


## 40000 -> "40,000"
static func _cr(n: int) -> String:
	var s := str(n)
	var out := ""
	for i in s.length():
		if i > 0 and (s.length() - i) % 3 == 0:
			out += ","
		out += s[i]
	return out
