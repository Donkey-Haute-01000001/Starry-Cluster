extends Control
## A start's opening, typed onto its file a beat at a time. Neon words land as
## coloured ink, [shake] [wave] [slow] still play. Click or Space: finish typing.

const Neon = preload("res://scripts/neon.gd")

const SIZE := 14
const BEAT_GAP := 9.0      ## px between beats
const BEAT_PAUSE := 0.55    ## s of quiet between beats

var beats: Array = []
var width := 440.0
var instant := false

var _age := 0.0
var _starts: Array = []     ## when each beat begins typing
var _words := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var t := 0.4
	var h := 0.0
	for b in beats:
		_starts.append(t)
		var p := Neon.parse(b)
		t += Neon.duration(p) + BEAT_PAUSE
		h += Neon.height(_font(), p, width, SIZE) + BEAT_GAP
	custom_minimum_size = Vector2(width, h)
	if instant:
		finish()


func _font() -> Font:
	return Data.font_type if Data.font_type else ThemeDB.fallback_font


func _total() -> float:
	if beats.is_empty():
		return 0.0
	return _starts[-1] + Neon.duration(Neon.parse(beats[-1]))


func finish() -> void:
	_age = _total() + 0.01
	_words = 1 << 20


func _process(delta: float) -> void:
	_age += delta
	_tick()
	queue_redraw()   # shake / wave keep moving after the type-in


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and _age < _total():
		finish()
		accept_event()


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and e.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER] \
			and _age < _total() and is_visible_in_tree():
		finish()
		get_viewport().set_input_as_handled()


## A typewriter key as each word lands.
func _tick() -> void:
	if _words >= (1 << 20):
		return
	var n := 0
	for i in beats.size():
		if _age >= _starts[i]:
			n += Neon.words_at(Neon.parse(beats[i]), _age - _starts[i])
	if n > _words:
		Sfx.play("key", -16.0, randf_range(0.9, 1.0))
		_words = n


func _draw() -> void:
	var f := _font()
	var y := 0.0
	for i in beats.size():
		var p := Neon.parse(beats[i])
		var age: float = _age - _starts[i]
		var h := Neon.height(f, p, width, SIZE)
		if age >= 0.0:
			Neon.draw(self, f, Vector2(0, y), p, width, SIZE, UIStyle.INK_TYPE, 1.0, age, true)
		y += h + BEAT_GAP
