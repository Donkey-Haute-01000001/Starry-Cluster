extends "res://scripts/neon_menu.gd"
## A station notice opened full screen, in neon (docs/design/ui-look.md):
## the issuer up top, the typed text with its neon words, any handwriting in
## glowing pink, the signature, and one verb. Bar captains show their face.
## notice: {"issuer", "form", "body", "pen", "sign", "verb", "done", "portrait"}

const Neon = preload("res://scripts/neon.gd")
const PINK := Color(1.0, 0.43, 0.75)
const BODY_Y := 200.0
const WIDTH := 560.0

var notice: Dictionary = {}
var _body := {}
var _body_h := 0.0
var _pen_h := 0.0


func _ready() -> void:
	title = str(notice.get("issuer", ""))
	cols = [0.0]
	var done := str(notice.get("done", ""))
	if done != "":
		set_rows([{"cells": [done], "off": true}])
		hints = [["ESC", "BACK", _back]]
	else:
		set_rows([{"cells": [notice["verb"]]}])
		hints = [["ENTER", str(notice["verb"]), func(): _open(0)], ["ESC", "BACK", _back]]
	hint_gap = 44.0
	super._ready()
	if notice.has("body"):
		_body = Neon.parse(str(notice["body"]))
		_body_h = Neon.height(Data.font_talk, _body, WIDTH, 26)
	if notice.has("pen"):
		var lines := Data.font_hand.get_multiline_string_size(str(notice["pen"]), HORIZONTAL_ALIGNMENT_LEFT, WIDTH, 36)
		_pen_h = lines.y + 10.0


func _top() -> float:
	return BODY_Y + _portrait_h() + _pen_h + _body_h + 110.0


func _portrait_h() -> float:
	return 150.0 if notice.has("portrait") else 0.0


func _draw() -> void:
	# The station page dims away under the notice.
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.016, 0.02, 0.047, 0.9))
	super._draw()
	var talk: Font = Data.font_talk
	var hand: Font = Data.font_hand
	var x0 := _left()
	var a := _flicker(0)
	draw_string(talk, Vector2(x0, 168), str(notice.get("form", "")).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, SMALL, Color(OFF, a))
	var y := BODY_Y
	if notice.has("portrait"):
		var r := Rect2(Vector2(x0, y), Vector2(110, 132))
		var who := str(notice["portrait"])
		UIStyle.draw_id_photo(self, r, Data.portrait_for(who), "", who.hash(), who)
		draw_rect(r.grow(6), Color(UIStyle.GOLD, 0.15 * a), false, 4.0)
		draw_rect(r.grow(6), Color(UIStyle.GOLD, 0.6 * a), false, 1.0)
		y += _portrait_h()
	if notice.has("pen"):
		_pen(hand, Vector2(x0, y + 30), str(notice["pen"]), 36, a)
		y += _pen_h
	if not _body.is_empty():
		Neon.draw(self, talk, Vector2(x0, y), _body, WIDTH, 26, Data.TALK_BODY, a)
		y += _body_h
	# The signature, in pen.
	var sign := str(notice.get("sign", ""))
	if sign != "":
		var sw := hand.get_string_size(sign, HORIZONTAL_ALIGNMENT_LEFT, -1, 38).x
		_pen(hand, Vector2(x0 + WIDTH - sw, y + 50), sign, 38, a)


## Handwriting glowing pink, like a sign in a window.
func _pen(f: Font, p: Vector2, s: String, sz: int, a: float) -> void:
	for o in [Vector2(-2, 0), Vector2(2, 0), Vector2(0, -2), Vector2(0, 2)]:
		draw_multiline_string(f, p + o, s, HORIZONTAL_ALIGNMENT_LEFT, WIDTH, sz, -1, Color(PINK, 0.16 * a))
	draw_multiline_string(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, WIDTH, sz, -1, Color(1.0, 0.72, 0.87, a))
