extends Control
## Title and start screen: pick a background. Only the Merchant start is
## playable in the demo; the others show their story and stay locked.

var _selected := 0
var _blurb: Label
var _name: Label
var _play: Button
var _cards: Array = []
var _root: VBoxContainer

# Friend creator state.
var _friend := {"name": "", "calls_you": "Cap", "portrait": 0, "role": "pilot", "memory": "drip"}
var _role_btns := {}
var _mem_btns := {}
var _portrait_btns: Array = []
var _role_desc: Label
var _mem_desc: Label
var _preview: Label
var _name_edit: LineEdit
var _you_edit: LineEdit


## A placeholder portrait: head and shoulders in the chosen palette.
class Portrait extends Control:
	var pal: Array = []
	func _draw() -> void:
		var c := size * 0.5
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.1, 0.15))
		draw_circle(Vector2(c.x, size.y * 1.08), size.x * 0.4, pal[2])
		draw_circle(Vector2(c.x, size.y * 0.42), size.x * 0.22, pal[0])
		draw_arc(Vector2(c.x, size.y * 0.4), size.x * 0.23, PI * 1.05, PI * 1.95, 16, pal[1], size.x * 0.1)


func _ready() -> void:
	# Automated runs skip straight past the menu.
	var args := OS.get_cmdline_user_args()
	if "--autotest" in args:
		Data.mode = "sandbox"
		get_tree().change_scene_to_file.call_deferred("res://scenes/main.tscn")
		return
	if "--merchant-test" in args:
		var f := {"name": "Rook", "calls_you": "Cap", "portrait": 0, "role": "trader", "memory": "drip"}
		for a in args:
			if a.begins_with("--friend-role="):
				f["role"] = a.substr(14)
			elif a.begins_with("--friend-memory="):
				f["memory"] = a.substr(16)
		_begin.call_deferred(f)
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
	_root = root

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
	_play.pressed.connect(_open_creator)
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
		elif a.begins_with("--creator-shot="):
			_open_creator()
			_snapshot.call_deferred(a.substr(15))


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


func _begin(friend: Dictionary) -> void:
	Data.mode = "merchant"
	Career.start_merchant(friend)
	get_tree().change_scene_to_file("res://scenes/main.tscn")


# --- Friend creator ----------------------------------------------------------

func _lbl(parent: Control, text: String, sz := 16, col := Color(0.85, 0.9, 1.0)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	parent.add_child(l)
	return l


func _toggle(parent: Control, text: String, cb: Callable, w := 200.0) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(w, 40)
	b.add_theme_font_size_override("font_size", 17)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


## Right after you pick your start, you design the old friend you'll meet later.
func _open_creator() -> void:
	for c in _root.get_children():
		c.queue_free()
	_friend["name"] = Data.friend_default_names[randi() % Data.friend_default_names.size()]
	_lbl(_root, "AN OLD FRIEND", 40, Color(0.85, 0.92, 1.0))
	_lbl(_root, "Somebody from before the rig and the loan. You'll run into them out there.", 17, Color(0.6, 0.72, 0.88))

	var names := HBoxContainer.new()
	names.add_theme_constant_override("separation", 14)
	_root.add_child(names)
	_lbl(names, "Their name", 17)
	_name_edit = LineEdit.new()
	_name_edit.text = _friend["name"]
	_name_edit.custom_minimum_size.x = 220
	_name_edit.max_length = 16
	_name_edit.text_changed.connect(func(t): _friend["name"] = t.strip_edges(); _update_creator())
	names.add_child(_name_edit)
	_lbl(names, "    What they call you", 17)
	_you_edit = LineEdit.new()
	_you_edit.text = _friend["calls_you"]
	_you_edit.custom_minimum_size.x = 220
	_you_edit.max_length = 16
	_you_edit.text_changed.connect(func(t): _friend["calls_you"] = t.strip_edges(); _update_creator())
	names.add_child(_you_edit)

	var prow := HBoxContainer.new()
	prow.add_theme_constant_override("separation", 10)
	_root.add_child(prow)
	_lbl(prow, "Face  ", 17)
	for i in Data.friend_portraits.size():
		var b := Button.new()
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(76, 76)
		var p := Portrait.new()
		p.pal = Data.friend_portraits[i]
		p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		p.offset_left = 5; p.offset_top = 5; p.offset_right = -5; p.offset_bottom = -5
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.clip_contents = true
		b.add_child(p)
		b.pressed.connect(func(): _friend["portrait"] = i; _update_creator())
		prow.add_child(b)
		_portrait_btns.append(b)

	_lbl(_root, "WHAT THEY DO", 15, Color(0.6, 0.85, 1.0))
	var rrow := HBoxContainer.new()
	rrow.add_theme_constant_override("separation", 10)
	_root.add_child(rrow)
	for r in Data.friend_role_order:
		_role_btns[r] = _toggle(rrow, Data.friend_roles[r]["name"], func(): _friend["role"] = r; _update_creator())
	_role_desc = _lbl(_root, "", 16, Color(0.85, 0.88, 0.93))

	_lbl(_root, "LAST TIME YOU SAW EACH OTHER", 15, Color(0.6, 0.85, 1.0))
	var mrow := HBoxContainer.new()
	mrow.add_theme_constant_override("separation", 10)
	_root.add_child(mrow)
	for m in Data.friend_memory_order:
		var label: String = Data.friend_memories[m]["memory"]
		_mem_btns[m] = _toggle(mrow, label[0].to_upper() + label.substr(1), func(): _friend["memory"] = m; _update_creator(), 290)
	_mem_desc = _lbl(_root, "", 16, Color(0.85, 0.88, 0.93))

	_preview = _lbl(_root, "", 17, Color(1.0, 0.85, 0.55))
	_preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_preview.custom_minimum_size.x = 1100

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_root.add_child(spacer)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 14)
	_root.add_child(bottom)
	var go := Button.new()
	go.text = "Begin"
	go.custom_minimum_size = Vector2(260, 52)
	go.add_theme_font_size_override("font_size", 20)
	go.focus_mode = Control.FOCUS_NONE
	go.pressed.connect(func():
		if _friend["name"] == "":
			_friend["name"] = "Rook"
		if _friend["calls_you"] == "":
			_friend["calls_you"] = "Cap"
		_begin(_friend))
	bottom.add_child(go)
	_update_creator()


func _update_creator() -> void:
	for i in _portrait_btns.size():
		_portrait_btns[i].button_pressed = i == _friend["portrait"]
	for r in _role_btns:
		_role_btns[r].button_pressed = r == _friend["role"]
	for m in _mem_btns:
		_mem_btns[m].button_pressed = m == _friend["memory"]
	var role: Dictionary = Data.friend_roles[_friend["role"]]
	var mem: Dictionary = Data.friend_memories[_friend["memory"]]
	_role_desc.text = "Flies a %s. %s" % [role["ship"], role["bonus"]]
	_mem_desc.text = "%s: %s" % [mem["trait"], mem["trait_desc"]]
	var who: String = _friend["name"] if _friend["name"] != "" else "Rook"
	var you: String = _friend["calls_you"] if _friend["calls_you"] != "" else "Cap"
	_preview.text = "%s:  \"%s\"" % [who, Data.FRIEND_MEETING % [you, mem["memory"], role["ship"]]]
