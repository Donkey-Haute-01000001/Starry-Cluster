extends Control
## Title and start screen: pick a background. Only the Merchant start is
## playable in the demo; the others show their story and stay locked.

var _selected := 0
var _blurb: Label
var _name: Label
var _play: Button
var _cards: Array = []


func _ready() -> void:
	# Automated runs skip straight past the menu.
	var args := OS.get_cmdline_user_args()
	if "--autotest" in args:
		Data.mode = "sandbox"
		get_tree().change_scene_to_file.call_deferred("res://scenes/main.tscn")
		return
	if "--merchant-test" in args:
		_start_merchant.call_deferred()
		return

	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.015, 0.015, 0.035)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 70)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 18)
	margin.add_child(root)

	var title := Label.new()
	title.text = "SECTOR SECUNDUS"
	title.add_theme_font_size_override("font_size", 54)
	title.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0))
	root.add_child(title)
	var tag := Label.new()
	tag.text = "Who were you before the stars?"
	tag.add_theme_font_size_override("font_size", 18)
	tag.add_theme_color_override("font_color", Color(0.6, 0.72, 0.88))
	root.add_child(tag)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	root.add_child(row)
	for i in Data.starts.size():
		var s: Dictionary = Data.starts[i]
		var b := Button.new()
		b.text = s["name"] + ("" if s["playable"] else "  (locked)")
		b.custom_minimum_size = Vector2(230, 54)
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 20)
		b.pressed.connect(_select.bind(i))
		row.add_child(b)
		_cards.append(b)

	_name = Label.new()
	_name.add_theme_font_size_override("font_size", 26)
	_name.add_theme_color_override("font_color", Color(1.0, 0.85, 0.55))
	root.add_child(_name)
	_blurb = Label.new()
	_blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_blurb.custom_minimum_size = Vector2(980, 0)
	_blurb.add_theme_font_size_override("font_size", 19)
	_blurb.add_theme_color_override("font_color", Color(0.85, 0.88, 0.93))
	root.add_child(_blurb)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(spacer)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 14)
	root.add_child(bottom)
	_play = Button.new()
	_play.custom_minimum_size = Vector2(260, 52)
	_play.add_theme_font_size_override("font_size", 20)
	_play.focus_mode = Control.FOCUS_NONE
	_play.pressed.connect(_start_merchant)
	bottom.add_child(_play)
	var sandbox := Button.new()
	sandbox.text = "Combat sandbox"
	sandbox.custom_minimum_size = Vector2(200, 52)
	sandbox.focus_mode = Control.FOCUS_NONE
	sandbox.pressed.connect(func():
		Data.mode = "sandbox"
		get_tree().change_scene_to_file("res://scenes/main.tscn"))
	bottom.add_child(sandbox)
	_select(0)
	for a in args:
		if a.begins_with("--start-shot="):
			_snapshot.call_deferred(a.substr(13))


func _snapshot(path: String) -> void:
	await get_tree().create_timer(0.5).timeout
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()


func _select(i: int) -> void:
	_selected = i
	for k in _cards.size():
		_cards[k].button_pressed = k == i
	var s: Dictionary = Data.starts[i]
	_name.text = s["name"]
	_blurb.text = s["blurb"]
	_play.disabled = not s["playable"]
	_play.text = "Begin" if s["playable"] else "Coming after the demo"


func _start_merchant() -> void:
	Data.mode = "merchant"
	Career.start_merchant()
	get_tree().change_scene_to_file("res://scenes/main.tscn")
