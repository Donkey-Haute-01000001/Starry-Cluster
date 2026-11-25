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

var _age := 0.0
var _starts: Array = []     ## when each beat begins typing (only beats started so far)
var _words := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var h := 0.0
	for b in beats:
		h += Neon.height(_font(), Neon.parse(b), width, SIZE) + BEAT_GAP
	custom_minimum_size = Vector2(width, h)
	if not beats.is_empty():
		_starts.append(LEAD)
	if instant:
		finish()


func _font() -> Font:
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
	for i in _starts.size():
		_starts[i] = 0.0
	_age = maxf(_age, _beat_end() + 0.01)
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
	var y := 0.0
	for i in beats.size():
		var p := Neon.parse(beats[i])
		var h := Neon.height(f, p, width, SIZE)
		if i < _starts.size() and _age >= _starts[i]:
			Neon.draw(self, f, Vector2(0, y), p, width, SIZE, UIStyle.INK_TYPE, 1.0, _age - _starts[i], true)
		y += h + BEAT_GAP
	# More to come: a typewriter caret blinks where the next beat will land.
	if _starts.size() < beats.size() and _age >= _beat_end() and fmod(_age, 1.0) < 0.6:
		var yy := 0.0
		for i in _starts.size():
			yy += Neon.height(f, Neon.parse(beats[i]), width, SIZE) + BEAT_GAP
		draw_rect(Rect2(0, yy + f.get_ascent(SIZE) - 2, 8, 2), UIStyle.INK_FADED)
