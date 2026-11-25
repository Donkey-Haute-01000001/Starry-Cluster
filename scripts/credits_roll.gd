extends Control
## Credits from the title menu: white names roll up over the still station,
## film style. Music keeps playing. Esc, click or any key: back to the menu.
## Mirrors CREDITS.md; keep the two in step.

signal closed

const SPEED := 38.0          ## px per second
const ROLE_SIZE := 14
const NAME_SIZE := 30
const NOTE_SIZE := 13

## [kind, text]: "title", "role" (small print over a block), "name", "note", "gap".
const LINES := [
	["role", "WRITTEN AND DIRECTED BY"],
	["name", "Vishnu"],
	["gap", ""],
	["role", "MUSIC BY"],
	["name", "DavidKBD"],
	["note", "\"Pink Bloom\" synthwave pack"],
	["gap", ""],
	["role", "SOUND"],
	["name", "Kenney"],
	["note", "Sci-fi Sounds  ·  Impact Sounds  ·  Interface Sounds  ·  RPG Audio  (CC0)"],
	["name", "media_man_uk"],
	["note", "\"Lazer Gun\"  (Pixabay)"],
	["name", "Dragon Studio"],
	["note", "\"Machine Gun SFX\"  (Pixabay)"],
	["gap", ""],
	["role", "ART"],
	["name", "Astek Game Studio"],
	["note", "\"Pixel Spaceship\"  ·  \"Stellar Environment\""],
	["name", "CraftPix"],
	["note", "\"Space Game GUI\""],
	["name", "Foozle"],
	["note", "Ships and backdrops  (CC0)"],
	["gap", ""],
	["role", "TYPE"],
	["name", "Big Shoulders"],
	["note", "The Big Shoulders Project Authors  (SIL OFL)"],
	["name", "Courier Prime"],
	["note", "The Courier Prime Project Authors  (SIL OFL)"],
	["name", "Nanum Pen Script"],
	["note", "NAVER Corporation  (SIL OFL)"],
	["name", "VT323"],
	["note", "Peter Hull  (SIL OFL)"],
	["gap", ""],
	["role", "ENGINE"],
	["name", "Godot Engine"],
	["note", "godotengine.org  (MIT)"],
]

var _y := 0.0         ## scroll, px
var _h := 0.0         ## total height of the roll
var _fade := 0.0


func _ready() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size
	mouse_filter = Control.MOUSE_FILTER_STOP
	for l in LINES:
		_h += _line_h(l[0])
	_y = size.y * 0.3   ## the title starts in the lower third, already rising
	create_tween().tween_property(self, "_fade", 1.0, 0.5)


func _line_h(kind: String) -> float:
	match kind:
		"title": return 70.0
		"role": return 34.0
		"name": return 26.0
		"note": return 44.0
	return 40.0


func _process(delta: float) -> void:
	_y += delta * SPEED
	# Back round once it's all gone by.
	if _y > size.y + _h + 40.0:
		_y = 0.0
	queue_redraw()


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed:
		close()
		accept_event()


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		close()
		get_viewport().set_input_as_handled()


func close() -> void:
	set_process_input(false)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw := create_tween()
	tw.tween_property(self, "_fade", 0.0, 0.35)
	tw.tween_callback(func():
		closed.emit()
		queue_free())


func _font(kind: String) -> Font:
	match kind:
		"role": return Data.font_type_bold
		"note": return Data.font_type
	return Data.font_bold


func _size(kind: String) -> int:
	match kind:
		"title": return 52
		"role": return ROLE_SIZE
		"note": return NOTE_SIZE
	return NAME_SIZE


func _draw() -> void:
	var vp := size
	# Dim the station so the names read, heavier toward the middle.
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.01, 0.012, 0.02, 0.62 * _fade))
	var y := vp.y - _y
	for l in LINES:
		var kind: String = l[0]
		var h := _line_h(kind)
		if kind != "gap" and y > -60.0 and y < vp.y + 60.0:
			var f := _font(kind)
			var sz := _size(kind)
			var a := 1.0
			if kind == "role":
				a = 0.55
			elif kind == "note":
				a = 0.6
			# Soft fade at the top and bottom edges.
			a *= clampf(minf(y, vp.y - y) / 140.0, 0.0, 1.0) * _fade
			var txt: String = l[1]
			var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
			draw_string(f, Vector2(roundf((vp.x - tw) * 0.5), roundf(y)), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color(1, 1, 1, a))
		y += h
	# The way out, low and quiet, like the menu row.
	var hint := "ESC  ·  BACK"
	var hf: Font = Data.font_type_bold
	var hw := hf.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	draw_string(hf, Vector2(vp.x - hw - 48, vp.y - 40), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.45 * _fade))
