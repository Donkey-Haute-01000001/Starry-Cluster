extends Control
## Esc / P in flight: stops the world. Resume, settings, quit to the title
## screen, quit the game. Same clean white menu type as the title screen.

var main: Node
var _list: VBoxContainer
var _note: Label
var _page := "main"
const Keys = preload("res://scripts/keys.gd")
var _bind_wait := ""   ## action waiting for a key on the controls page
var _bind_note := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.02, 0.72)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 14)
	_list.alignment = BoxContainer.ALIGNMENT_CENTER
	_list.custom_minimum_size = Vector2(520, 0)
	center.add_child(_list)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--pause-shot="):
			_shot_test.call_deferred(a.substr(13))


## Only opens over live flight: not while docked or while a scene holds the clock.
func can_open() -> bool:
	return not visible and not get_tree().paused


func open() -> void:
	if not can_open():
		return
	if main.wheel.visible:
		main.wheel.visible = false
	Engine.time_scale = 1.0
	get_tree().paused = true
	visible = true
	Sfx.play("tick", -6.0)
	_show_main()


func close() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = false
	Sfx.play("tick", -8.0)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ESCAPE, KEY_P]:
		if _page == "main":
			close()
		elif _page == "controls":
			_show_settings()
		else:
			_show_main()
		get_viewport().set_input_as_handled()


func _clear() -> void:
	for c in _list.get_children():
		c.queue_free()


func _title(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var f := FontVariation.new()
	f.base_font = Data.font_bold.base_font if Data.font_bold is FontVariation else Data.font_bold
	f.spacing_glyph = 10
	l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", 40)
	l.add_theme_color_override("font_color", Color.WHITE)
	_list.add_child(l)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 12)
	_list.add_child(gap)


func _small(text: String, alpha := 0.55) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_override("font", Data.font_type)
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", Color(1, 1, 1, alpha))
	_list.add_child(l)
	return l


func _button(text: String, cb: Callable, size := 24) -> Button:
	var f := FontVariation.new()
	f.base_font = Data.font_bold.base_font if Data.font_bold is FontVariation else Data.font_bold
	f.spacing_glyph = 5
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.process_mode = Node.PROCESS_MODE_ALWAYS
	b.add_theme_font_override("font", f)
	b.add_theme_font_size_override("font_size", size)
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
		var tw := create_tween()
		tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_method(func(v: float):
			b.set_meta("u", v)
			b.queue_redraw(), float(b.get_meta("u")), to, 0.15)
	b.pressed.connect(func():
		Sfx.play("tick", -6.0)
		cb.call())
	b.mouse_entered.connect(func():
		Sfx.play("tick", -16.0, 1.4)
		slide.call(1.0))
	b.mouse_exited.connect(func(): slide.call(0.0))
	var row := CenterContainer.new()
	row.add_child(b)
	_list.add_child(row)
	return b


func _show_main() -> void:
	_page = "main"
	_clear()
	_title("PAUSED")
	_button("RESUME", close)
	_button("SETTINGS", _show_settings)
	_button("QUIT TO MENU", _confirm_quit.bind(false))
	_button("QUIT GAME", _confirm_quit.bind(true))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 10)
	_list.add_child(gap)
	if main.merchant:
		var where: String = Career.resume_station
		_small("Saved automatically every time you dock." + ("" if where == "" else "  Last save: %s." % Data.stations.get(where, {}).get("name", where)))
	_small("Esc to resume")


func _confirm_quit(whole_game: bool) -> void:
	_page = "confirm"
	_clear()
	_title("QUIT TO DESKTOP?" if whole_game else "QUIT TO MENU?")
	if main.merchant:
		_small("Anything since your last dock is lost. Your career picks up from that dock.", 0.75)
	_button("YES, QUIT", func():
		if whole_game:
			get_tree().quit()
		else:
			get_tree().paused = false
			Engine.time_scale = 1.0
			get_tree().change_scene_to_file("res://scenes/start.tscn"))
	_button("NO, GO BACK", _show_main)


func _show_settings() -> void:
	_page = "settings"
	_clear()
	_title("SETTINGS")
	for r in [["Flight assist", "assist"], ["Mouse steering", "mouse_steer"]]:
		var key: String = r[1]
		_button("%s   %s" % [r[0].to_upper(), "ON" if PlayerController.setting(key) else "OFF"], func():
			PlayerController.toggle(key)
			_show_settings(), 20)
	_button("FULLSCREEN   %s" % ("ON" if PlayerController.fullscreen else "OFF"), func():
		PlayerController.fullscreen = not PlayerController.fullscreen
		PlayerController.save_settings()
		_show_settings(), 20)
	for r in [["MUSIC", "music_vol"], ["EFFECTS", "sfx_vol"]]:
		var key: String = r[1]
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 6)
		_list.add_child(row)
		var n := roundi(PlayerController.vol(key) * 10.0)
		var name_l := Label.new()
		name_l.text = r[0]
		name_l.custom_minimum_size = Vector2(120, 0)
		var f := FontVariation.new()
		f.base_font = Data.font_bold.base_font if Data.font_bold is FontVariation else Data.font_bold
		f.spacing_glyph = 5
		name_l.add_theme_font_override("font", f)
		name_l.add_theme_font_size_override("font_size", 20)
		row.add_child(name_l)
		for d in [-0.1, 0.1]:
			var b := _button(" - " if d < 0 else " + ", _step_vol.bind(key, d), 20)
			b.get_parent().reparent(row)
			if d < 0:
				var gauge := Label.new()
				gauge.text = "|".repeat(n) + ".".repeat(10 - n) + "  %3d%%" % (n * 10)
				gauge.add_theme_font_override("font", Data.font_type)
				gauge.add_theme_font_size_override("font_size", 18)
				gauge.custom_minimum_size = Vector2(190, 0)
				row.add_child(gauge)
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(28, 0)
		row.add_child(gap)
		var mb := _button("MUTED" if PlayerController.muted(key) else "MUTE", func():
			PlayerController.toggle_mute(key)
			_show_settings(), 20)
		mb.get_parent().reparent(row)
	_small("%s also toggles flight assist in flight." % Keys.key_name("assist"))
	_button("CONTROLS", func():
		_bind_wait = ""
		_bind_note = ""
		_show_controls(), 20)
	_button("BACK", _show_main, 20)


## Every key in two columns. Click a key, press the new one.
func _show_controls() -> void:
	_page = "controls"
	_clear()
	_title("CONTROLS")
	var cols := HBoxContainer.new()
	cols.alignment = BoxContainer.ALIGNMENT_CENTER
	cols.add_theme_constant_override("separation", 48)
	_list.add_child(cols)
	var left := VBoxContainer.new()
	var right := VBoxContainer.new()
	for c in [left, right]:
		c.custom_minimum_size = Vector2(300, 0)
		c.add_theme_constant_override("separation", 0)
		cols.add_child(c)
	var group := ""
	for a in Keys.ACTIONS:
		var col: VBoxContainer = left if a[2] == "FLIGHT" else right
		if a[2] != group:
			group = a[2]
			if col.get_child_count() > 0:
				var gap := Control.new()
				gap.custom_minimum_size = Vector2(0, 8)
				col.add_child(gap)
			col.add_child(_tag(group, 12, 0.5))
		var row := HBoxContainer.new()
		col.add_child(row)
		var l := _tag(a[1], 15, 0.8)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var id: String = a[0]
		var b := _button("PRESS A KEY" if _bind_wait == id else Keys.key_name(id).to_upper(), func():
			_bind_wait = id
			_bind_note = "Press the new key for %s. Esc cancels." % Keys.label(id)
			_show_controls(), 16)
		b.get_parent().custom_minimum_size = Vector2(110, 0)
		b.get_parent().reparent(row)
		if _bind_wait == id:
			b.add_theme_color_override("font_color", UIStyle.GOLD)
	var fixed := ""
	for f in Keys.FIXED:
		fixed += ("    " if fixed != "" else "") + "%s  %s" % [f[0], f[1].to_lower()]
	_small("Fixed:  " + fixed, 0.45)
	if _bind_note != "":
		_small(_bind_note, 0.9)
	if not Keys.is_default():
		_button("RESET TO DEFAULTS", func():
			Keys.reset()
			_bind_wait = ""
			_bind_note = "Defaults restored."
			_show_controls(), 18)
	_button("BACK", func():
		_bind_wait = ""
		_bind_note = ""
		_show_settings(), 20)


func _tag(text: String, sz: int, alpha: float) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", Data.font_type)
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", Color(1, 1, 1, alpha))
	return l


func _input(event: InputEvent) -> void:
	if not visible or _page != "controls" or _bind_wait == "":
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_bind_wait = ""
		_bind_note = ""
	else:
		var sp := Keys.spec_of(event)
		if sp == "":
			return
		if sp == "reserved":
			_bind_note = "That key is spoken for (see Fixed). Pick another."
		else:
			var id := _bind_wait
			var swapped := Keys.rebind(id, sp)
			_bind_wait = ""
			_bind_note = "%s  →  %s." % [Keys.label(id), Keys.key_name(id)]
			if swapped != "":
				_bind_note += "  %s moved to %s." % [Keys.label(swapped), Keys.key_name(swapped)]
		Sfx.play("tick", -6.0)
	get_viewport().set_input_as_handled()
	_show_controls.call_deferred()


func _step_vol(key: String, d: float) -> void:
	PlayerController.set_vol(key, clampf(snappedf(PlayerController.vol(key) + d, 0.1), 0.0, 1.0))
	_show_settings()


## Test hook: --pause-shot=DIR opens the menu in flight and saves both pages.
func _shot_test(dir: String) -> void:
	await get_tree().create_timer(2.0).timeout
	open()
	for i in 3:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir + "/pause_main.png")
	_show_settings()
	for i in 3:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir + "/pause_settings.png")
	_show_controls()
	# Rebind check: Forward guns onto R should swap Swap secondary onto Space.
	_bind_wait = "fire_fixed"
	_show_controls()
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_R
	ev.keycode = KEY_R
	ev.pressed = true
	_input(ev)
	await get_tree().process_frame
	print("[keys] fire_fixed=%s swap=%s map_ok=%s" % [Keys.key_name("fire_fixed"), Keys.key_name("swap_secondary"), InputMap.event_is_action(ev, "fire_fixed")])
	for i in 3:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir + "/pause_controls.png")
	Keys.reset()
	close()
	print("[pause] paused=%s visible=%s" % [get_tree().paused, visible])
	get_tree().quit()


## Alt-tab away mid-flight and the game waits for you.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and main and is_inside_tree() and DisplayServer.get_name() != "headless":
		open()
