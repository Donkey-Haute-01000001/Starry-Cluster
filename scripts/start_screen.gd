extends Control
## Title screen: a live shot of your rig in its Charter berth, and the paperwork
## on a clipboard. Page one is the file for your career (only the Merchant's
## Charter loan is playable in the demo). Sign it, and page two is the Charter's
## emergency-contact form, where you say how you know Dez.

const PAPER_W := 520.0
const PAPER_H := 780.0

var _selected := 0
var _bg := ""                       ## Dez's background on the contact form
var _pilot := {}                     ## name, rig and photo from the ID form
var _board: Control                 ## the clipboard
var _bulletin: Control              ## top-right sector bulletin (hidden under the clipboard)
var _page: Control                  ## the current sheet of paper
var _busy := false
var _menu: HBoxContainer            ## the main menu: one row along the bottom
const Neon = preload("res://scripts/neon.gd")
const NeonMenu = preload("res://scripts/neon_menu.gd")
const NeonSettings = preload("res://scripts/neon_settings.gd")
const NeonFile = preload("res://scripts/neon_file.gd")
const NeonId = preload("res://scripts/neon_id.gd")
const NeonContact = preload("res://scripts/neon_contact.gd")
var _beats: Control                 ## the start's opening, typing onto the file
var _file: Control                  ## the start's file, in neon
const BeatsOnPaper = preload("res://scripts/beats_on_paper.gd")
const CreditsRoll = preload("res://scripts/credits_roll.gd")


func _ready() -> void:
	# Automated runs skip straight past the menu.
	var args := OS.get_cmdline_user_args()
	if "--autotest" in args:
		Data.mode = "sandbox"
		get_tree().change_scene_to_file.call_deferred("res://scenes/main.tscn")
		return
	if "--new-career-test" in args:
		_pilot = {"name": "Test Pilot", "rig": "Test Rig", "photo": 3}
		_begin.call_deferred(Data.friend_for(Data.friend_background_order[0]))
		return
	if "--merchant-test" in args:
		var bg := "dock_hustler"
		for a in args:
			if a.begins_with("--friend-bg="):
				bg = a.substr(12)
			elif a.begins_with("--friend-role="):
				for k in Data.friend_backgrounds:
					if Data.friend_backgrounds[k]["role"] == a.substr(14):
						bg = k
		var f := Data.friend_for(bg)
		for a in args:
			if a.begins_with("--friend-memory="):
				f["memory"] = a.substr(16)
		_begin.call_deferred(f)
		return

	set_anchors_preset(Control.PRESET_FULL_RECT)
	var sky := ColorRect.new()
	sky.color = Color(0.015, 0.015, 0.035)
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/nebula.gdshader")
	mat.set_shader_parameter("density", 0.55)
	mat.set_shader_parameter("seed", 11.0)
	sky.material = mat
	add_child(sky)
	add_child(TitleScene.new())

	# Dock signage, top left: the game's name stencilled like a berth number.
	var sign := VBoxContainer.new()
	sign.position = Vector2(48, 36)
	sign.add_theme_constant_override("separation", 0)
	add_child(sign)
	var title := _label(sign, "SECTOR SECUNDUS", Data.font_bold, 46, Color(0.88, 0.92, 0.98))
	title.add_theme_constant_override("outline_size", 0)
	_label(sign, "AURELIA   HESPER MARCH", Data.font_type_bold, 20, Color(1.0, 0.75, 0.35, 0.85))

	_board = Control.new()
	_board.size = Vector2(PAPER_W + 44, PAPER_H + 70)
	_board.position = Vector2(get_viewport_rect().size.x - _board.size.x - 40, 26)
	_board.pivot_offset = _board.size * 0.5
	_board.rotation = deg_to_rad(-0.8)
	_board.draw.connect(_draw_board)
	add_child(_board)


	PlayerController.load_settings()
	_build_bulletin()
	# The clipboard waits off to the side until you pick New career or Settings.
	_board.visible = false
	_build_menu()
	for a in args:
		if a.begins_with("--menu-shot="):
			_snapshot.call_deferred(a.substr(12))
		elif a.begins_with("--careers-shot="):
			_show_register.call_deferred()
			_snapshot.call_deferred(a.substr(15))
		elif a.begins_with("--files-shot="):
			_show_starts.call_deferred()
			_snapshot.call_deferred(a.substr(13))
		elif a == "--pick-test":
			# New career -> Merchant should open the Merchant file.
			(func():
				_show_starts()._open(0)
				print("[pick] opened file %d" % _selected)
				get_tree().quit()).call_deferred()
		elif a.begins_with("--credits-shot="):
			_show_credits()
			_credits_shot.call_deferred(a.substr(15))
		elif a.begins_with("--controls-shot="):
			(func(): _show_settings().show_controls(true)).call_deferred()
			_snapshot.call_deferred(a.substr(16))
		elif a.begins_with("--settings-shot="):
			_show_settings.call_deferred()
			_snapshot.call_deferred(a.substr(16))
		elif a.begins_with("--intro-shot="):
			# --intro-shot=DIR: each start's opening, a beat in, plus the Merchant file after.
			_intro_shots.call_deferred(a.substr(13))
		elif a.begins_with("--file-open="):
			# --file-open=N: open start N's file and let it type (for recordings).
			_show_file.call_deferred(int(a.substr(12)), true)
		elif a.begins_with("--start-shot="):
			_show_file.call_deferred(0, false)
			_snapshot.call_deferred(a.substr(13))
		elif a.begins_with("--id-shot="):
			_show_identity.call_deferred()
			_snapshot.call_deferred(a.substr(10))
		elif a.begins_with("--creator-shot="):
			_show_contact.call_deferred()
			_snapshot.call_deferred(a.substr(15))


## --credits-shot=DIR: the roll a few seconds in.
func _credits_shot(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	await get_tree().create_timer(9.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir + "/credits.png")
	get_tree().quit()


## --intro-shot=DIR: each start's file, part-typed and fully typed.
func _intro_shots(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	for i in Data.starts.size():
		_show_file(i, false)
		await get_tree().create_timer(4.0).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/file_%s_typing.png" % [dir, Data.starts[i]["id"]])
		_beats.finish()
		await get_tree().create_timer(0.4).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/file_%s.png" % [dir, Data.starts[i]["id"]])
	get_tree().quit()


func _snapshot(path: String) -> void:
	await get_tree().create_timer(1.2).timeout
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()


## Now and then the dock talks: a hydraulic release or the PA chime.
func _ambience() -> void:
	while is_inside_tree():
		await get_tree().create_timer(randf_range(6.0, 13.0)).timeout
		if not is_inside_tree():
			return
		Sfx.play("undock" if randf() < 0.65 else "chime", -10.0)


func _begin(friend: Dictionary) -> void:
	Data.mode = "merchant"
	Career.start_merchant(friend, _pilot)
	get_tree().change_scene_to_file("res://scenes/main.tscn")


# --- Main menu -------------------------------------------------------------------

## The menu: one row of stencilled options across a dark strip at the bottom.
func _build_menu() -> void:
	if _menu:
		_menu.get_meta("strip").queue_free()
	var vp := get_viewport_rect().size
	var strip := Control.new()
	strip.position = Vector2(0, vp.y - 120)
	strip.size = Vector2(vp.x, 120)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.draw.connect(func():
		for i in 24:
			var a := float(i) / 24.0
			strip.draw_rect(Rect2(0, strip.size.y * (1.0 - a), strip.size.x, strip.size.y / 24.0 + 1.0), Color(0.02, 0.022, 0.03, 0.88 * a))
		pass)
	add_child(strip)
	_menu = HBoxContainer.new()
	_menu.add_theme_constant_override("separation", 88)
	_menu.position = Vector2(48, 44)
	_menu.size = Vector2(vp.x - 96, 60)
	_menu.alignment = BoxContainer.ALIGNMENT_CENTER
	strip.add_child(_menu)
	_menu.set_meta("strip", strip)
	if Career.has_save():
		_menu_button("CONTINUE", _continue, Career.save_summary())
	if not Career.list_careers().is_empty():
		_menu_button("CAREERS", _show_register)
	_menu_button("NEW CAREER", _show_starts)
	_menu_button("SETTINGS", _show_settings)
	_menu_button("CREDITS", _show_credits)
	_menu_button("QUIT", func(): get_tree().quit())


## Pure white, clean and tracked out; a thin white rule slides in under the hovered one.
func _menu_button(text: String, cb: Callable, sub := "") -> void:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	_menu.add_child(col)
	var f := FontVariation.new()
	f.base_font = Data.font_bold.base_font if Data.font_bold is FontVariation else Data.font_bold
	f.spacing_glyph = 5
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", f)
	b.add_theme_font_size_override("font_size", 24)
	var none := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
		b.add_theme_stylebox_override(st, none)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, Color.WHITE)
	b.set_meta("u", 0.0)
	b.draw.connect(func():
		var u: float = b.get_meta("u")
		if u > 0.0:
			var w := (b.size.x - 5.0) * u
			b.draw_rect(Rect2((b.size.x - 5.0 - w) * 0.5, b.size.y - 4, w, 1.5), Color.WHITE))
	var slide := func(to: float):
		create_tween().tween_method(func(v: float):
			b.set_meta("u", v)
			b.queue_redraw(), float(b.get_meta("u")), to, 0.15)
	b.pressed.connect(func():
		Sfx.play("tick", -6.0)
		cb.call())
	b.mouse_entered.connect(func():
		Sfx.play("tick", -16.0, 1.4)
		slide.call(1.0))
	b.mouse_exited.connect(func(): slide.call(0.0))
	col.add_child(b)
	if sub != "":
		var l := _label(col, sub, Data.font_type, 16, Color(1, 1, 1, 0.55))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


## Top right: the sector bulletin in neon (docs/design/ui-look.md), typed on a
## dark wash. Flavour for the world outside the berth.
func _build_bulletin() -> void:
	var vp := get_viewport_rect().size
	var lines := [
		"Charter Co. posts record quarter. Haulers' rates unchanged.",
		"Navy patrol warns of raiders in the Marcellus belt.",
		"Saltgate bar: pilots for hire, cheap.",
		"Aquila customs: Writs of Passage checked in full.",
	]
	var slip := Control.new()
	slip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slip.position = Vector2(vp.x - 440, 60)
	slip.size = Vector2(400, 260)
	add_child(slip)
	_bulletin = slip
	slip.draw.connect(func():
		var f: Font = Data.font_talk
		var w := slip.size.x
		# Soft dark wash, no box.
		for k in 10:
			var g := 30.0 - k * 3.0
			slip.draw_rect(Rect2(Vector2.ZERO, slip.size).grow(g), Color(0.016, 0.02, 0.047, 0.1))
		slip.draw_string(f, Vector2(0, 20), "HESPER MARCH BULLETIN", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.3, 0.31, 0.37))
		slip.draw_string(f, Vector2(0, 20), "WEEK 1", HORIZONTAL_ALIGNMENT_RIGHT, w, 20, Color(0.3, 0.31, 0.37))
		var y := 54.0
		for line in lines:
			slip.draw_string(f, Vector2(0, y), ">", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(UIStyle.GOLD, 0.8))
			slip.draw_multiline_string(f, Vector2(18, y), line, HORIZONTAL_ALIGNMENT_LEFT, w - 18.0, 22, -1, Color(0.9, 0.9, 0.94))
			y += f.get_multiline_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, w - 18.0, 22).y + 10.0)
	slip.set_meta("tacks", Control.new())
	slip.get_meta("tacks").visible = false
	add_child(slip.get_meta("tacks"))


func _continue(n := -1) -> void:
	if Career.load_game(n):
		Data.mode = "merchant"
		get_tree().change_scene_to_file("res://scenes/main.tscn")


## The berth register, in neon: one line per career, last played on top.
## Enter takes it up; Del twice voids it for good.
func _show_register() -> void:
	_set_menu_shown(false)
	var m := NeonMenu.new()
	m.title = "REGISTER"
	m.cols = [0.0, 200.0, 330.0, 470.0]
	m.heads = ["PILOT", "RIG", "LAST BERTH", "DAY"]
	m.num_cols = [3]
	m.can_void = true
	var careers := []
	var fill := func():
		# Lambdas capture by value: refill the same array, don't reassign it.
		var all := Career.list_careers()
		careers.clear()
		careers.append_array(all.filter(func(c): return not c["damaged"]))
		careers.append_array(all.filter(func(c): return c["damaged"]))
		m.set_rows(careers.map(func(c):
			if c["damaged"]:
				return {"cells": ["File %d" % c["slot"], "unreadable", "", ""], "off": true}
			return {"cells": [c["pilot"], c["rig"], c["where"], str(c["day"])]}))
	fill.call()
	add_child(m)
	m.chosen.connect(func(i): _continue(careers[i]["slot"]))
	m.voided.connect(func(i):
		Career.delete_career(careers[i]["slot"])
		_build_menu()
		if Career.list_careers().is_empty():
			m.queue_free()
			_set_menu_shown(true)
		else:
			_set_menu_shown(false)
			fill.call())
	m.back.connect(func():
		m.queue_free()
		_set_menu_shown(true))


func _open_board() -> void:
	if _board.visible:
		return
	_board.visible = true
	_set_menu_shown(false)
	var target := _board.position
	_board.position.x += 700.0
	var tw := create_tween()
	tw.tween_property(_board, "position", target, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	Sfx.play("paper", -4.0)


## New career: the starts in neon. Pick one and its file comes up on the
## clipboard, the opening typing onto it.
func _show_starts() -> NeonMenu:
	_set_menu_shown(false)
	var m := NeonMenu.new()
	m.title = "WHO WERE YOU?"
	m.cols = [0.0, 220.0, 420.0]
	var r := []
	for k in Data.starts.size():
		var st: Dictionary = Data.starts[k]
		var first := Neon.plain(st["beats"][0]).replace("\n", " ")
		var cut := first.find(".", 60)
		r.append({"cells": [st["name"], st["doc"]["file"], "" if st["playable"] else "sealed"],
			"tint": {1: NeonMenu.DIM, 2: NeonMenu.OFF},
			"blurb": first.substr(0, cut + 1) if cut > 0 else first})
	m.set_rows(r)
	add_child(m)
	m.chosen.connect(func(k):
		m.queue_free()
		_show_file(k, true))
	m.back.connect(func():
		m.queue_free()
		_set_menu_shown(true))
	return m


## Settings and Controls: neon pages, shared with the pause menu.
func _show_settings() -> NeonSettings:
	_set_menu_shown(false)
	var m := NeonSettings.new()
	add_child(m)
	m.back.connect(func():
		m.queue_free()
		_set_menu_shown(true))
	return m


func _close_board() -> void:
	var tw := create_tween()
	var home := _board.position
	tw.tween_property(_board, "position:x", home.x + 700.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		_board.visible = false
		_board.position = home
		_set_menu_shown(true))
	Sfx.play("paper", -6.0)


## Credits roll over the station; the menu steps aside till it's closed.
func _show_credits() -> void:
	_set_menu_shown(false)
	var roll := CreditsRoll.new()
	add_child(roll)
	roll.closed.connect(func(): _set_menu_shown(true))


## The menu strip and bulletin step aside while the clipboard is out.
func _set_menu_shown(on: bool) -> void:
	for n in [_bulletin, _bulletin.get_meta("tacks"), _menu.get_meta("strip")]:
		n.visible = on


# --- The clipboard ---------------------------------------------------------------

func _draw_board() -> void:
	var r := Rect2(Vector2.ZERO, _board.size)
	_board.draw_rect(r.grow(2), Color(0, 0, 0, 0.35))
	_board.draw_rect(r, UIStyle.BOARD)
	# Pressboard grain.
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	for i in 60:
		var y := rng.randf() * r.size.y
		_board.draw_line(Vector2(0, y), Vector2(r.size.x, y + rng.randf_range(-3, 3)), Color(0, 0, 0, 0.06), 1.0)
	# The clip.
	var cw := 170.0
	var cx := (r.size.x - cw) * 0.5
	_board.draw_rect(Rect2(cx, -10, cw, 46), Color(0.55, 0.57, 0.6))
	_board.draw_rect(Rect2(cx, -10, cw, 6), Color(0.78, 0.8, 0.83))
	_board.draw_rect(Rect2(cx + 8, 30, cw - 16, 8), Color(0.42, 0.44, 0.47))
	_board.draw_circle(Vector2(cx + 20, 12), 5, Color(0.3, 0.31, 0.33))
	_board.draw_circle(Vector2(cx + cw - 20, 12), 5, Color(0.3, 0.31, 0.33))


## A fresh sheet on the clipboard. Slides in from below unless instant.
func _new_page(animate: bool) -> Control:
	if _page:
		var old := _page
		if animate:
			var tw := create_tween()
			tw.tween_property(old, "position:x", old.position.x - 700.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.parallel().tween_property(old, "rotation", deg_to_rad(-8.0), 0.35)
			tw.tween_callback(old.queue_free)
		else:
			old.queue_free()
	var page := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = UIStyle.PAPER
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(2, 3)
	page.add_theme_stylebox_override("panel", sb)
	page.size = Vector2(PAPER_W, PAPER_H)
	page.position = Vector2(22, 28)
	page.pivot_offset = page.size * 0.5
	page.draw.connect(_draw_paper.bind(page))
	_board.add_child(page)
	_board.move_child(page, -1)
	if animate:
		var target := page.position
		page.position.y += 900.0
		page.rotation = deg_to_rad(4.0)
		var tw := create_tween()
		tw.tween_interval(0.12)
		tw.tween_property(page, "position", target, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(page, "rotation", 0.0, 0.45)
		Sfx.play("paper", -4.0)
	_page = page
	return page


## Faint ruled lines and a punched margin, so it reads as paper.
func _draw_paper(page: Control) -> void:
	for y in range(150, int(page.size.y) - 20, 26):
		page.draw_line(Vector2(24, y), Vector2(page.size.x - 24, y), Color(0.4, 0.5, 0.65, 0.07), 1.0)
	page.draw_rect(Rect2(Vector2.ZERO, page.size), Color(UIStyle.PAPER_SHADE, 0.25), false, 1.0)


func _label(parent: Node, text: String, font: Font, sz: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	if font:
		l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	parent.add_child(l)
	return l


func _type(parent: Node, text: String, sz := 15, bold := false, col := UIStyle.INK_TYPE) -> Label:
	return _label(parent, text, Data.font_type_bold if bold else Data.font_type, roundi(sz * 1.3), col)


func _rule(parent: Node) -> void:
	var r := ColorRect.new()
	r.color = Color(UIStyle.INK_TYPE, 0.55)
	r.custom_minimum_size = Vector2(0, 1)
	parent.add_child(r)


## Pen on paper, at an angle, in its own spot.
func _pen(parent: Control, text: String, pos: Vector2, deg := -3.0, sz := 26, col := UIStyle.INK_PEN) -> Label:
	var l := _label(parent, text, Data.font_hand, sz, col)
	l.position = pos
	l.rotation = deg_to_rad(deg)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## A rubber stamp. Lands with a thunk when animated.
func _stamp(parent: Control, text: String, pos: Vector2, deg: float, animate: bool, col := UIStyle.INK_STAMP, sz := 40) -> Label:
	var l := _label(parent, text, Data.font_stamp, sz, Color(col, 0.78))
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0, 0, 0, 0)
	box.border_color = Color(col, 0.7)
	box.set_border_width_all(3)
	box.set_content_margin_all(6)
	box.content_margin_left = 12
	box.content_margin_right = 12
	l.add_theme_stylebox_override("normal", box)
	l.position = pos
	l.rotation = deg_to_rad(deg)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.reset_size()
	l.pivot_offset = l.size * 0.5
	if animate:
		l.scale = Vector2(1.8, 1.8)
		l.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(l, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(l, "modulate:a", 1.0, 0.08)
		tw.tween_callback(func():
			Sfx.play("stamp")
			_shake())
	return l


func _shake() -> void:
	var base := _board.position
	var tw := create_tween()
	for i in 4:
		tw.tween_property(_board, "position", base + Vector2(randf_range(-3, 3), randf_range(-2, 4)), 0.03)
	tw.tween_property(_board, "position", base, 0.05)


## Typed text that works as a button: underlined on hover, like a form field.
func _type_button(parent: Node, text: String, cb: Callable, sz := 16) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if Data.font_type_bold:
		b.add_theme_font_override("font", Data.font_type_bold)
	b.add_theme_font_size_override("font_size", roundi(sz * 1.3))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0, 0, 0, 0)
	normal.border_color = Color(UIStyle.INK_TYPE, 0.6)
	normal.border_width_bottom = 1
	normal.set_content_margin_all(4)
	var hover := normal.duplicate()
	hover.bg_color = Color(UIStyle.INK_TYPE, 0.07)
	hover.border_width_bottom = 2
	for st in ["normal", "focus"]:
		b.add_theme_stylebox_override(st, normal)
	for st in ["hover", "pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(st, hover)
	var dis := normal.duplicate()
	dis.border_color = Color(UIStyle.INK_TYPE, 0.2)
	b.add_theme_stylebox_override("disabled", dis)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, UIStyle.INK_TYPE)
	b.add_theme_color_override("font_disabled_color", Color(UIStyle.INK_TYPE, 0.3))
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _sheet_body(page: Control) -> VBoxContainer:
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, 30)
	m.add_theme_constant_override("margin_top", 26)
	m.add_theme_constant_override("margin_bottom", 22)
	page.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	m.add_child(v)
	return v


# --- Page one: the file -------------------------------------------------------------

func _show_file(i: int, animate := true) -> void:
	_selected = i
	_board.visible = false   # back from the ID form: the clipboard goes
	if _file:
		_file.queue_free()
	_set_menu_shown(false)
	var f := NeonFile.new()
	f.start = Data.starts[i]
	f.animate = animate
	add_child(f)
	_file = f
	_beats = f.beats
	f.back.connect(func():
		_file = null
		f.queue_free()
		_show_starts())
	f.chosen.connect(func(_r): _sign())
	f.sandbox.connect(func():
		Data.mode = "sandbox"
		get_tree().change_scene_to_file("res://scenes/main.tscn"))


## Signing the loan: a neon scrawl across the line, then the next form comes up.
func _sign() -> void:
	if _busy:
		return
	_busy = true
	_file.scrawl()
	await get_tree().create_timer(0.9).timeout
	_file.queue_free()
	_file = null
	_show_identity()
	_busy = false


# --- Page two: who you are ----------------------------------------------------------

## Form ID-1, in neon: your photo, your name and your rig's name.
func _show_identity() -> void:
	if _pilot.is_empty():
		_pilot = {"name": Data.pilot_names.pick_random(), "rig": Data.rig_names.pick_random(), "photo": randi() % Data.PILOT_PHOTOS}
	_board.visible = false   # back from the contact form: the clipboard goes
	_set_menu_shown(false)
	var m := NeonId.new()
	m.pilot = _pilot
	add_child(m)
	m.filed.connect(func():
		m.queue_free()
		Sfx.play("flip", -4.0)
		_show_contact())
	m.back.connect(func():
		m.queue_free()
		_show_file(_selected, false))


## A blank on a form: typed label, your handwriting on the line.
func _field(parent: Node, label: String, key: String, sz: int) -> void:
	_type(parent, label, 11, false, UIStyle.INK_FADED)
	var e := LineEdit.new()
	e.text = str(_pilot[key])
	e.max_length = 24
	e.flat = true
	e.caret_blink = true
	e.select_all_on_focus = true
	e.add_theme_font_override("font", Data.font_hand)
	e.add_theme_font_size_override("font_size", sz)
	e.add_theme_color_override("font_color", UIStyle.INK_PEN)
	e.add_theme_color_override("caret_color", UIStyle.INK_PEN)
	e.add_theme_color_override("selection_color", Color(UIStyle.INK_PEN, 0.2))
	e.add_theme_color_override("font_selected_color", UIStyle.INK_PEN)
	var line := StyleBoxLine.new()
	line.color = Color(UIStyle.INK_TYPE, 0.5)
	line.thickness = 1
	line.vertical = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = Color(UIStyle.INK_TYPE, 0.45)
	sb.border_width_bottom = 1
	sb.content_margin_left = 2
	for st in ["normal", "focus", "read_only"]:
		e.add_theme_stylebox_override(st, sb)
	e.text_changed.connect(func(t: String): _pilot[key] = t)
	e.text_submitted.connect(func(_t: String): e.release_focus())
	parent.add_child(e)


# --- Page three: Dez on the emergency-contact form -------------------------------------

func _show_contact() -> void:
	_board.visible = false
	_set_menu_shown(false)
	var m := NeonContact.new()
	m.bg = _bg
	add_child(m)
	m.filed.connect(func(bg: String):
		_bg = bg
		_begin(Data.friend_for(bg)))
	m.back.connect(func():
		_bg = m.bg
		m.queue_free()
		_show_identity())
