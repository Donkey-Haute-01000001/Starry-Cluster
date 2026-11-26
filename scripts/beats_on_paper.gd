extends Control
## A start's opening, typed onto its file a beat at a time. Neon words land as
## coloured ink, [shake] [wave] [slow] still play. Types at the Text speed
## setting. Each beat waits for you: click or Space finishes the one typing,
## then starts the next.

const Neon = preload("res://scripts/neon.gd")

const SIZE := 14
const BEAT_GAP := 9.0      ## px between beats
const LEAD := 0.4          ## s before the first beat types

var beats: Array = []
var width := 440.0
var instant := false
## Neon: VT323 on the dark, words glow instead of inking (docs/design/ui-look.md).
var neon := false
var text_size := SIZE
## Taller than this, older beats scroll up and fade out the top (0 = no limit).
var max_h := 0.0

var _age := 0.0
var _starts: Array = []     ## when each beat begins typing (only beats started so far)
var _words := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var h := 0.0
	for b in beats:
		h += Neon.height(_font(), Neon.parse(b), width, text_size) + BEAT_GAP
	custom_minimum_size = Vector2(width, h if max_h <= 0.0 else minf(h, max_h))
	if not beats.is_empty():
		_starts.append(LEAD)
	if instant:
		finish()


func _font() -> Font:
	if neon and Data.font_talk:
		return Data.font_talk
	return Data.font_type if Data.font_type else ThemeDB.fallback_font


## When the beat typing now is fully down.
func _beat_end() -> float:
	if _starts.is_empty():
		return 0.0
	return _starts[-1] + Neon.duration(Neon.parse(beats[_starts.size() - 1]))


## Every beat typed.
func done() -> bool:
	return _starts.size() >= beats.size() and _age >= _beat_end()


## Lay every beat down at once (shots, coming back to the file).
func finish() -> void:
	while _starts.size() < beats.size():
		_starts.append(0.0)
	var longest := 0.0
	for i in _starts.size():
		_starts[i] = 0.0
		longest = maxf(longest, Neon.duration(Neon.parse(beats[i])))
	_age = maxf(_age, longest + 0.01)   # a slow beat can outlast the last one
	_words = 1 << 20


## Click / Space: finish the beat typing, or start the next one.
func advance() -> void:
	if _age < _beat_end():
		_age = _beat_end() + 0.01
		_words = 1 << 20
	elif _starts.size() < beats.size():
		_starts.append(_age)
		_words = 0


func _process(delta: float) -> void:
	_age += delta
	_tick()
	queue_redraw()   # shake / wave keep moving after the type-in


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and not done():
		advance()
		accept_event()


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and e.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER] \
			and not done() and is_visible_in_tree():
		advance()
		get_viewport().set_input_as_handled()


## A typewriter key as each word lands.
func _tick() -> void:
	if _words >= (1 << 20):
		return
	var i := _starts.size() - 1
	if i < 0 or _age < _starts[i]:
		return
	var n := Neon.words_at(Neon.parse(beats[i]), _age - _starts[i])
	if n > _words:
		Sfx.play("key", -16.0, randf_range(0.9, 1.0))
		_words = n


func _draw() -> void:
	var f := _font()
	var hs: Array = []
	var typed := 0.0     # height of every beat started so far
	for i in beats.size():
		hs.append(Neon.height(f, Neon.parse(beats[i]), width, text_size))
		if i < _starts.size():
			typed += hs[i] + BEAT_GAP
	var scroll := maxf(0.0, typed - max_h) if max_h > 0.0 else 0.0
	var fade := text_size * 3.0
	var y := -scroll
	for i in beats.size():
		var p := Neon.parse(beats[i])
		var h: float = hs[i]
		if i < _starts.size() and _age >= _starts[i] and y + h > 0.0:
			var a := clampf((y + h) / fade, 0.0, 1.0) if scroll > 0.0 and y < fade else 1.0
			Neon.draw(self, f, Vector2(0, y), p, width, text_size, Color(0.9, 0.9, 0.94) if neon else UIStyle.INK_TYPE,
				a, _age - _starts[i], not neon)
		y += h + BEAT_GAP
	# More to come: a typewriter caret blinks where the next beat will land.
	if _starts.size() < beats.size() and _age >= _beat_end() and fmod(_age, 1.0) < 0.6:
		draw_rect(Rect2(0, typed - scroll + f.get_ascent(text_size) - 2, 8 if not neon else 12, 2),
			Color(1.0, 0.77, 0.42) if neon else UIStyle.INK_FADED)
