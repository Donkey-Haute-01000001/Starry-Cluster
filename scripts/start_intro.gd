extends Control
## A career's opening, read over the berth: letterbox bars close in, and the
## start's beats type in at the bottom of the screen in neon, one at a time.
## Space / Enter / click: finish the beat, then the next. Esc: skip the lot.

const Neon = preload("res://scripts/neon.gd")

signal finished

const SIZE := 34
const BAR := 0.12          ## letterbox bar height, share of the screen
const IN := 0.6            ## seconds for the bars to close in

var beats: Array = []
var place := ""            ## slug line over the top bar
var _i := 0
var _age := -IN            ## age of the current beat; negative while the bars close
var _words := 0
var _out := -1.0           ## counts up once we're leaving
var _shown := 0.0          ## bars: 0 open, 1 closed


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _process(delta: float) -> void:
	if _out >= 0.0:
		_out += delta
		_shown = 1.0 - clampf(_out / 0.45, 0.0, 1.0)
		if _out > 0.45:
			finished.emit()
			queue_free()
	else:
		_age += delta
		_shown = clampf((_age + IN) / IN, 0.0, 1.0) if _i == 0 else 1.0
		_tick_sounds()
	queue_redraw()


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		advance()
		accept_event()


func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey and e.pressed and not e.echo):
		return
	match e.keycode:
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
			advance()
		KEY_ESCAPE:
			skip()
		_:
			return
	get_viewport().set_input_as_handled()


func advance() -> void:
	if _out >= 0.0 or _age < 0.0:
		return
	var p := Neon.parse(beats[_i])
	if _age < Neon.duration(p):
		_age = Neon.duration(p) + 0.01
		_words = 1 << 20
		return
	Sfx.play("tick", -12.0)
	_i += 1
	_age = 0.0
	_words = 0
	if _i >= beats.size():
		_i = beats.size() - 1
		_out = 0.0


func skip() -> void:
	if _out < 0.0:
		_out = 0.0


## A soft key tick per word as it types; threat words buzz.
func _tick_sounds() -> void:
	if _age < 0.0:
		return
	var p := Neon.parse(beats[_i])
	var n := Neon.words_at(p, _age)
	if n <= _words:
		return
	for k in range(_words, mini(n, p["words"].size())):
		if Neon.word_kind(p, k) == "threats":
			Sfx.play("neon", -14.0, randf_range(0.95, 1.05))
	Sfx.play("key", -18.0, randf_range(0.92, 1.0))
	_words = n


func _draw() -> void:
	var vp := size
	var bar := vp.y * BAR * _shown
	var f: Font = Data.font_talk if Data.font_talk else ThemeDB.fallback_font
	var tf: Font = Data.font_type_bold if Data.font_type_bold else ThemeDB.fallback_font
	# Lower third: a soft dark ramp so the words sit on something.
	var ramp := 260.0
	for k in 40:
		var a := float(k) / 40.0
		draw_rect(Rect2(0, vp.y - bar - ramp + a * ramp, vp.x, ramp / 40.0 + 1.0), Color(0, 0, 0, a * 0.85 * _shown))
	draw_rect(Rect2(0, 0, vp.x, bar), Color.BLACK)
	draw_rect(Rect2(0, vp.y - bar, vp.x, bar), Color.BLACK)
	if _shown < 1.0 and _out < 0.0:
		return
	var a := _shown
	draw_string(tf, Vector2(110, bar * 0.6), place, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.75, 0.35, 0.85 * a))
	# The beat, bottom-anchored so short and long beats sit on the same line.
	if _age >= 0.0:
		var p := Neon.parse(beats[_i])
		var w := minf(1100.0, vp.x - 220.0)
		var h := Neon.height(f, p, w, SIZE)
		var fade := minf(1.0, _age / 0.15) * a
		Neon.draw(self, f, Vector2(110, vp.y - bar - 48 - h), p, w, SIZE, Data.TALK_BODY.lightened(0.25), fade, _age)
	var hint := "SPACE  ▸  next      ESC  skip"
	draw_string(tf, Vector2(vp.x - 110 - tf.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x, vp.y - bar * 0.42),
		hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.45 * a))
	draw_string(tf, Vector2(110, vp.y - bar * 0.42), "%d / %d" % [_i + 1, beats.size()],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.3 * a))
