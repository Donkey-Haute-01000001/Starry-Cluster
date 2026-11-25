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
	_label(sign, "COUNTER STATION  ·  BERTH 14  ·  AURELIA", Data.font_type_bold, 15, Color(1.0, 0.75, 0.35, 0.85))

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
		elif a.begins_with("--files-shot="):
			_open_board()
			_show_index(false)
			_snapshot.call_deferred(a.substr(13))
		elif a == "--pick-test":
			# New career -> Merchant should open the Merchant file.
			_open_board()
			_show_index(false)
			_pick(0)
			print("[pick] opened file %d" % _selected)
			get_tree().quit.call_deferred()
		elif a.begins_with("--settings-shot="):
			_open_board()
			_show_settings(false)
			_snapshot.call_deferred(a.substr(16))
		elif a.begins_with("--start-shot="):
			_open_board()
			_show_file(0, false)
			_snapshot.call_deferred(a.substr(13))
		elif a.begins_with("--id-shot="):
			_open_board()
			_show_identity(false)
			_snapshot.call_deferred(a.substr(10))
		elif a.begins_with("--creator-shot="):
			_open_board()
			_show_contact(false)
			_snapshot.call_deferred(a.substr(15))


func _snapshot(path: String) -> void:
	await get_tree().create_timer(1.2).timeout
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()


## Now and then the dock talks: a hydraulic hiss or the PA chime.
func _ambience() -> void:
	while is_inside_tree():
		await get_tree().create_timer(randf_range(6.0, 13.0)).timeout
		if not is_inside_tree():
			return
		Sfx.play("hiss" if randf() < 0.65 else "chime", -10.0)


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
	# The clipboard slides in with the page already on it (no second page swipe).
	_menu_button("NEW CAREER", func():
		_open_board()
		_show_index(false))
	_menu_button("SETTINGS", func():
		_open_board()
		_show_settings(false))
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
		var l := _label(col, sub, Data.font_type, 12, Color(1, 1, 1, 0.55))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


## Top right: the sector bulletin, printed and pinned. Flavour for the
## world outside the berth.
func _build_bulletin() -> void:
	var vp := get_viewport_rect().size
	var slip := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.93, 0.91, 0.85)
	sb.shadow_color = Color(0, 0, 0, 0.4)
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(2, 3)
	sb.set_content_margin_all(14)
	slip.add_theme_stylebox_override("panel", sb)
	slip.position = Vector2(vp.x - 380, 54)
	slip.custom_minimum_size = Vector2(340, 0)
	slip.rotation = deg_to_rad(0.6)
	add_child(slip)
	_bulletin = slip
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 7)
	slip.add_child(v)
	_type(v, "HESPER MARCH BULLETIN  ·  WEEK 1", 11, true, UIStyle.INK_FADED)
	_rule(v)
	for line in [
		"Charter Co. posts record quarter. Haulers' rates unchanged.",
		"Navy patrol warns of raiders in the Marcellus belt.",
		"Saltgate bar: pilots for hire, cheap.",
		"Aquila customs: Writs of Passage checked in full.",
	]:
		# Hanging bullet: a square of ink, then the wrapped line beside it.
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		v.add_child(row)
		var dot := Control.new()
		dot.custom_minimum_size = Vector2(6, 0)
		dot.draw.connect(func(): dot.draw_rect(Rect2(0, 6, 5, 5), UIStyle.INK_TYPE))
		row.add_child(dot)
		var t := _type(row, line, 13)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.custom_minimum_size = Vector2(298, 0)
	# Two thumbtacks pin it to the berth wall.
	var tacks := Control.new()
	tacks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tacks.position = slip.position
	tacks.rotation = slip.rotation
	tacks.size = Vector2(340, 20)
	tacks.draw.connect(func():
		for x in [16.0, 324.0]:
			tacks.draw_circle(Vector2(x + 2, 4), 6.5, Color(0, 0, 0, 0.35))
			tacks.draw_circle(Vector2(x, 2), 6.0, Color(0.72, 0.16, 0.14))
			tacks.draw_circle(Vector2(x - 1.8, 0.2), 2.0, Color(1.0, 0.6, 0.55, 0.8)))
	add_child(tacks)
	slip.set_meta("tacks", tacks)


func _continue() -> void:
	if Career.load_game():
		Data.mode = "merchant"
		get_tree().change_scene_to_file("res://scenes/main.tscn")


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


## The career files, none opened yet: pick one.
func _show_index(animate := true) -> void:
	_selected = -1   # no file open: any pick opens one
	var page := _new_page(animate)
	var v := _sheet_body(page)
	_type(v, "BERTH 14  ·  CAPTAIN'S FILES", 13, true, UIStyle.INK_FADED)
	_label(v, "Who were you?", Data.font_bold, 34, UIStyle.INK_TYPE)
	_type(v, "Pick a file. Only the Merchant is open in the demo.", 14, false, UIStyle.INK_FADED)
	_rule(v)
	for k in Data.starts.size():
		var st: Dictionary = Data.starts[k]
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		v.add_child(row)
		var b := _type_button(row, "%s   ·   %s" % [st["name"].to_upper(), st["doc"]["file"]], _pick.bind(k), 18)
		if not st["playable"]:
			b.add_theme_color_override("font_color", Color(UIStyle.INK_TYPE, 0.55))
		var blurb: String = st["blurb"]
		var cut := blurb.find(".", 60)
		var t := _type(row, blurb.substr(0, cut + 1) if cut > 0 else blurb, 13, false, UIStyle.INK_FADED)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.custom_minimum_size = Vector2(PAPER_W - 70, 0)
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(0, 8)
		v.add_child(gap)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)
	_type_button(v, "back to menu", _close_board, 12)


## Settings: the flight controls, as a checklist.
func _show_settings(animate := true) -> void:
	var page := _new_page(animate)
	var v := _sheet_body(page)
	_type(v, "BERTH 14  ·  RIG SETUP SHEET", 13, true, UIStyle.INK_FADED)
	_label(v, "Settings", Data.font_bold, 34, UIStyle.INK_TYPE)
	_rule(v)
	var rows := [
		["Flight assist", "Thrusters damp unwanted drift. (V in flight)", "assist"],
		["Mouse steering", "The rig turns to face your cursor. Off: Q/E to turn.", "mouse_steer"],
	]
	for r in rows:
		var key: String = r[2]
		var on: bool = PlayerController.setting(key)
		_type_button(v, "[%s]  %s" % ["x" if on else "  ", r[0]], func():
			PlayerController.toggle(key)
			_show_settings(false), 18)
		var t := _type(v, "       " + r[1], 13, false, UIStyle.INK_FADED)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var fs := PlayerController.fullscreen
	_type_button(v, "[%s]  Fullscreen" % ("x" if fs else "  "), func():
		PlayerController.fullscreen = not PlayerController.fullscreen
		PlayerController.save_settings()
		_show_settings(false), 18)
	_rule(v)
	# Volume: ten ticks, typed like a gauge. - and + step it.
	for r in [["Music", "music_vol"], ["Effects", "sfx_vol"]]:
		var key: String = r[1]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		v.add_child(row)
		var lv: float = PlayerController.vol(key)
		var n := roundi(lv * 10.0)
		var name_l := _type(row, r[0].rpad(9), 18, true)
		name_l.custom_minimum_size = Vector2(110, 0)
		_type_button(row, " - ", _step_vol.bind(key, -0.1), 18)
		_type(row, "|".repeat(n) + ".".repeat(10 - n), 18, true, UIStyle.INK_TYPE)
		_type_button(row, " + ", _step_vol.bind(key, 0.1), 18)
		_type(row, "%d%%" % (n * 10), 14, false, UIStyle.INK_FADED)
		var mute := PlayerController.muted(key)
		_type_button(row, "[%s] mute" % ("x" if mute else "  "), func():
			PlayerController.toggle_mute(key)
			_show_settings(false), 16)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)
	_type_button(v, "back to menu", _close_board, 12)


func _step_vol(key: String, d: float) -> void:
	PlayerController.set_vol(key, clampf(snappedf(PlayerController.vol(key) + d, 0.1), 0.0, 1.0))
	Sfx.play("tick", -6.0)
	_show_settings(false)


func _close_board() -> void:
	var tw := create_tween()
	var home := _board.position
	tw.tween_property(_board, "position:x", home.x + 700.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		_board.visible = false
		_board.position = home
		_set_menu_shown(true))
	Sfx.play("paper", -6.0)


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
	return _label(parent, text, Data.font_type_bold if bold else Data.font_type, sz, col)


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
	b.add_theme_font_size_override("font_size", sz)
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
	var s: Dictionary = Data.starts[i]
	var doc: Dictionary = s["doc"]
	var page := _new_page(animate)
	var v := _sheet_body(page)

	# Folder tabs: one file per career.
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	v.add_child(tabs)
	for k in Data.starts.size():
		var label: String = Data.starts[k]["name"].to_upper()
		var b := _type_button(tabs, ("[%s]" % label) if k == i else label, _pick.bind(k), 13)
		if k == i:
			b.disabled = true
			b.add_theme_color_override("font_disabled_color", UIStyle.INK_TYPE)

	var head := HBoxContainer.new()
	v.add_child(head)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", -2)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(left)
	_type(left, doc["issuer"], 21, true)
	_type(left, doc["title"], 14)
	_type(left, doc["office"], 12, false, UIStyle.INK_FADED)
	var file := _type(head, "FILE NO.\n" + doc["file"], 12, true, UIStyle.INK_FADED)
	file.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_rule(v)

	var blurb := _type(v, s["blurb"], 14)
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.custom_minimum_size.x = PAPER_W - 60

	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(gap)

	if s["playable"]:
		_rule(v)
		var terms := GridContainer.new()
		terms.columns = 3
		terms.add_theme_constant_override("h_separation", 26)
		v.add_child(terms)
		for t in [["PRINCIPAL", "%d cr" % Data.LOAN_TOTAL], ["WEEKLY", "%d cr" % Data.LOAN_WEEKLY],
				["MISSED PMT", "+%d%%" % int(Data.LOAN_INTEREST * 100)]]:
			var cell := VBoxContainer.new()
			cell.add_theme_constant_override("separation", -3)
			terms.add_child(cell)
			_type(cell, t[0], 11, false, UIStyle.INK_FADED)
			_type(cell, t[1], 17, true)
		var sig := HBoxContainer.new()
		sig.add_theme_constant_override("separation", 10)
		v.add_child(sig)
		_type(sig, "BORROWER", 12, false, UIStyle.INK_FADED)
		var line := _type_button(sig, "x  sign here", _sign, 16)
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		_type(v, "Not in the demo. This file stays sealed for now.", 13, false, UIStyle.INK_FADED)

	_rule(v)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 14)
	v.add_child(foot)
	_type_button(foot, "all files", func(): _show_index(true), 12)
	_type_button(foot, "combat sandbox", func():
		Data.mode = "sandbox"
		get_tree().change_scene_to_file("res://scenes/main.tscn"), 12)
	_type_button(foot, "quit", func(): get_tree().quit(), 12)

	# Ink on top: the stamp, and your note in the margin.
	_stamp(page, doc["stamp"], Vector2(PAPER_W - 250, PAPER_H - 300), -9.0, animate,
		UIStyle.INK_STAMP if s["playable"] else UIStyle.INK_FADED)
	_pen(page, doc["note"], Vector2(40, PAPER_H - 250), -4.0)


func _pick(i: int) -> void:
	if _busy or i == _selected:
		return
	Sfx.play("flip", -4.0)
	_show_file(i)


## Signing the loan: the pen scrawls a signature, then the next form comes up.
func _sign() -> void:
	if _busy:
		return
	_busy = true
	Sfx.play("pen", -2.0)
	var scrawl := Scrawl.new()
	scrawl.position = Vector2(140, PAPER_H - 128)
	scrawl.size = Vector2(240, 50)
	_page.add_child(scrawl)
	await get_tree().create_timer(0.75).timeout
	_show_identity(true)
	_busy = false


## An animated signature: a loopy pen line drawn left to right.
class Scrawl extends Control:
	var _t := 0.0
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _process(delta: float) -> void:
		_t = minf(_t + delta * 1.6, 1.0)
		queue_redraw()
	func _draw() -> void:
		var pts := PackedVector2Array()
		var n := int(60 * _t)
		for i in n:
			var u := i / 60.0
			pts.append(Vector2(u * size.x, size.y * 0.55 + sin(u * 23.0) * 12.0 * (1.0 - u * 0.6) - u * 10.0
				+ cos(u * 9.0) * 5.0))
		if pts.size() > 1:
			draw_polyline(pts, UIStyle.INK_PEN, 2.0, true)


# --- Page two: who you are ----------------------------------------------------------

## Form ID-1: your name, your rig's name and the photo the Charter keeps on file.
func _show_identity(animate := true) -> void:
	if _pilot.is_empty():
		_pilot = {"name": Data.pilot_names.pick_random(), "rig": Data.rig_names.pick_random(), "photo": randi() % Data.PILOT_PHOTOS}
	var page := _new_page(animate)
	var v := _sheet_body(page)
	v.add_theme_constant_override("separation", 8)
	_type(v, "THE CHARTER COMPANY", 21, true)
	_type(v, "Form ID-1  ·  Licensed Operator Identification", 13)
	_type(v, "Attach to file CC-40817-M. Print clearly. Photo must be current.", 11, false, UIStyle.INK_FADED)
	_rule(v)

	var who := HBoxContainer.new()
	who.add_theme_constant_override("separation", 22)
	v.add_child(who)
	# The photo, with arrows to pick another.
	var pcol := VBoxContainer.new()
	pcol.add_theme_constant_override("separation", 4)
	who.add_child(pcol)
	var photo := Control.new()
	photo.custom_minimum_size = Vector2(150, 190)
	photo.draw.connect(func():
		UIStyle.draw_id_photo(photo, Rect2(Vector2(4, 4), Vector2(142, 182)), [Color(0.8, 0.65, 0.5), Color(0.2, 0.15, 0.1), Color(0.3, 0.35, 0.4)], "CC-40817-M", 7, "pilot_%d" % _pilot["photo"]))
	pcol.add_child(photo)
	var arrows := HBoxContainer.new()
	arrows.alignment = BoxContainer.ALIGNMENT_CENTER
	arrows.add_theme_constant_override("separation", 18)
	pcol.add_child(arrows)
	for d in [-1, 1]:
		_type_button(arrows, "<  prev" if d < 0 else "next  >", func():
			_pilot["photo"] = posmod(int(_pilot["photo"]) + d, Data.PILOT_PHOTOS)
			Sfx.play("flip", -10.0, 1.3)
			photo.queue_redraw(), 13)

	var fields := VBoxContainer.new()
	fields.add_theme_constant_override("separation", 2)
	fields.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.add_child(fields)
	_field(fields, "OPERATOR NAME", "name", 30)
	var gap0 := Control.new()
	gap0.custom_minimum_size = Vector2(0, 12)
	fields.add_child(gap0)
	_field(fields, "RIG NAME  (as painted on hull)", "rig", 30)
	var gap1 := Control.new()
	gap1.custom_minimum_size = Vector2(0, 12)
	fields.add_child(gap1)
	_type(fields, "RIG CLASS", 11, false, UIStyle.INK_FADED)
	_type(fields, "Light freighter, used.\nCharter lien until paid.", 14)

	_rule(v)
	var note := _type(v, "Click a line to change it. The Charter will use this name on every invoice it sends you.", 12, false, UIStyle.INK_FADED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size.x = PAPER_W - 70
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(gap)
	_rule(v)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 14)
	v.add_child(foot)
	var go := _type_button(foot, "next form", func():
		if _busy:
			return
		for k in ["name", "rig"]:
			_pilot[k] = str(_pilot[k]).strip_edges()
			if _pilot[k] == "":
				_pilot[k] = (Data.pilot_names if k == "name" else Data.rig_names).pick_random()
		Sfx.play("flip", -4.0)
		_show_contact(true), 17)
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_type_button(foot, "back", func():
		if not _busy:
			_show_file(_selected), 12)


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

func _show_contact(animate := true) -> void:
	if _bg == "":
		_bg = Data.friend_background_order[0]
	var page := _new_page(animate)
	var v := _sheet_body(page)
	v.add_theme_constant_override("separation", 6)

	_type(v, "THE CHARTER COMPANY", 21, true)
	_type(v, "Form NK-2  ·  Emergency Contact / Next of Kin", 13)
	_type(v, "Attach to file CC-40817-M. One contact only. Print clearly.", 11, false, UIStyle.INK_FADED)
	_rule(v)

	var who := HBoxContainer.new()
	who.add_theme_constant_override("separation", 18)
	v.add_child(who)
	var photo := Control.new()
	photo.custom_minimum_size = Vector2(104, 132)
	photo.draw.connect(func():
		UIStyle.draw_id_photo(photo, Rect2(Vector2(4, 4), Vector2(96, 124)), Data.speaker_portraits["Dez"], "NK-40817-1", 9, "Dez"))
	who.add_child(photo)
	var fields := VBoxContainer.new()
	fields.add_theme_constant_override("separation", 2)
	fields.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.add_child(fields)
	for f in [["NAME", Data.FRIEND_FULL_NAME], ["GOES BY", Data.FRIEND_NAME], ["RELATIONSHIP", "friend. best one."]]:
		_type(fields, f[0], 11, false, UIStyle.INK_FADED)
		var h := _label(fields, f[1], Data.font_hand, 25, UIStyle.INK_PEN)
		h.add_theme_constant_override("line_spacing", -6)

	_type(v, "HOW KNOWN TO APPLICANT  (tick one)", 12, true)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 4)
	v.add_child(rows)
	for k in Data.friend_background_order:
		_bg_row(rows, k)

	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(gap)
	_rule(v)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 14)
	v.add_child(foot)
	var go := _type_button(foot, "file it", _file_it, 17)
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_type_button(foot, "back", func():
		if not _busy:
			_show_identity(true), 12)

	var b: Dictionary = Data.friend_backgrounds[_bg]
	var note := _pen(page, b["note"], Vector2(300, 172), -5.0, 24)
	note.text = note.text.replace(". ", ".\n")
	note.add_theme_constant_override("line_spacing", -8)
	note.name = "Note"


func _bg_row(parent: Node, k: String) -> void:
	var b: Dictionary = Data.friend_backgrounds[k]
	var role: Dictionary = Data.friend_roles[b["role"]]
	var mem: Dictionary = Data.friend_memories[b["memory"]]
	var row := Button.new()
	row.focus_mode = Control.FOCUS_NONE
	row.custom_minimum_size = Vector2(0, 98)
	var clear := StyleBoxFlat.new()
	clear.bg_color = Color(0, 0, 0, 0)
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(UIStyle.INK_TYPE, 0.05)
	for st in ["normal", "focus", "pressed"]:
		row.add_theme_stylebox_override(st, clear)
	for st in ["hover", "hover_pressed"]:
		row.add_theme_stylebox_override(st, hover)
	row.pressed.connect(func():
		if _busy or _bg == k:
			return
		_bg = k
		Sfx.play("tick")
		Sfx.play("pen", -10.0, 1.3)
		for c in parent.get_children():
			c.queue_redraw()
		var note := _page.get_node_or_null("Note") as Label
		if note:
			note.text = b["note"].replace(". ", ".\n"))
	row.draw.connect(func():
		# Tick box, with a pen check when it's the one.
		var bx := Rect2(4, 8, 18, 18)
		row.draw_rect(bx, UIStyle.INK_TYPE, false, 1.5)
		if _bg == k:
			row.draw_polyline(PackedVector2Array([bx.position + Vector2(2, 8), bx.position + Vector2(8, 16),
				bx.position + Vector2(24, -8)]), UIStyle.INK_PEN, 3.0, true))
	parent.add_child(row)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", -1)
	text.position = Vector2(34, 4)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)
	var t1 := _type(text, b["title"].to_upper(), 14, true)
	var t2 := _type(text, b["typed"], 12)
	t2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t2.custom_minimum_size.x = PAPER_W - 100
	var perk: String = mem["trait_desc"].split(":")[1].split("(")[0].strip_edges() if ":" in mem["trait_desc"] else mem["trait_desc"]
	var t3 := _type(text, "On file: flies a %s. %s %s" % [role["ship"], role["bonus"], perk[0].to_upper() + perk.substr(1)], 11, false, UIStyle.INK_FADED)
	t3.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t3.custom_minimum_size.x = PAPER_W - 100
	for l in [t1, t2, t3]:
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _file_it() -> void:
	if _busy:
		return
	_busy = true
	_stamp(_page, "FILED", Vector2(PAPER_W - 210, PAPER_H - 150), 8.0, true)
	await get_tree().create_timer(1.0).timeout
	_begin(Data.friend_for(_bg))
