extends Control
## Esc / P in flight: stops the world. Resume, settings, quit to the title
## screen, quit the game. Neon pages, the same ones the title screen uses.

var main: Node
var _page := "main"
var _m: Control                ## the neon page on screen
const Keys = preload("res://scripts/keys.gd")
const NeonMenu = preload("res://scripts/neon_menu.gd")
const NeonSettings = preload("res://scripts/neon_settings.gd")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.02, 0.35)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
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
	if _m:
		_m.queue_free()
		_m = null
	get_tree().paused = false
	Sfx.play("tick", -8.0)


## P closes it from the top page; Esc is handled by the neon menu itself.
func _unhandled_input(event: InputEvent) -> void:
	if visible and _page == "main" and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_P:
		close()
		get_viewport().set_input_as_handled()


## Swap the neon page on screen.
func _swap(m: Control) -> void:
	if _m:
		_m.queue_free()
	_m = m
	add_child(m)


func _show_main() -> void:
	_page = "main"
	var m := NeonMenu.new()
	m.title = "PAUSED"
	m.cols = [0.0]
	m.hints = [["ENTER", "SELECT", func(): m._open(m.sel)], ["ESC", "RESUME", close]]
	if main.merchant and Career.resume_station != "":
		var where: String = Career.resume_station
		m.note = "Last save: %s." % Data.stations.get(where, {}).get("name", where)
	m.set_rows([
		{"cells": ["Resume"], "act": close},
		{"cells": ["Settings"], "act": _show_settings},
		{"cells": ["Quit to menu"], "act": _confirm_quit.bind(false)},
		{"cells": ["Quit game"], "act": _confirm_quit.bind(true)},
	])
	m.back.connect(close)
	_swap(m)


func _confirm_quit(whole_game: bool) -> void:
	_page = "confirm"
	var m := NeonMenu.new()
	m.title = "QUIT GAME?" if whole_game else "QUIT TO MENU?"
	m.cols = [0.0]
	m.hints = [["ENTER", "SELECT", func(): m._open(m.sel)], ["ESC", "BACK", _show_main]]
	if main.merchant:
		m.note = "Anything since your last dock is lost."
		m.note_col = NeonMenu.RED
	m.set_rows([
		{"cells": ["No, go back"], "act": _show_main},
		{"cells": ["Yes, quit"], "danger": true, "act": func():
			if whole_game:
				get_tree().quit()
			else:
				get_tree().paused = false
				Engine.time_scale = 1.0
				get_tree().change_scene_to_file("res://scenes/start.tscn")},
	])
	m.back.connect(_show_main)
	_swap(m)


func _show_settings() -> NeonSettings:
	_page = "settings"
	var m := NeonSettings.new()
	m.back.connect(_show_main)
	_swap(m)
	return m


## Test hook: --pause-shot=DIR opens the menu in flight and saves both pages.
func _shot_test(dir: String) -> void:
	await get_tree().create_timer(2.0).timeout
	open()
	await get_tree().create_timer(0.6).timeout
	get_viewport().get_texture().get_image().save_png(dir + "/pause_main.png")
	var st := _show_settings()
	await get_tree().create_timer(0.6).timeout
	get_viewport().get_texture().get_image().save_png(dir + "/pause_settings.png")
	st.show_controls(true)
	# Rebind check: Forward guns onto R should swap Swap secondary onto Space.
	for i in st.rows.size():
		if st.rows[i]["cells"][0] == Keys.label("fire_fixed"):
			st.sel = i
			st._open(i)
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_R
	ev.keycode = KEY_R
	ev.pressed = true
	st._input(ev)
	await get_tree().process_frame
	print("[keys] paused=%s fire_fixed=%s swap=%s map_ok=%s note=%s" % [get_tree().paused, Keys.key_name("fire_fixed"), Keys.key_name("swap_secondary"), InputMap.event_is_action(ev, "fire_fixed"), st.note])
	await get_tree().create_timer(0.6).timeout
	for i in 3:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir + "/pause_controls.png")
	Keys.reset()
	st._back()
	st._back()
	await get_tree().process_frame
	print("[pause] page after two backs=%s" % _page)
	close()
	print("[pause] paused=%s visible=%s" % [get_tree().paused, visible])
	get_tree().quit()


## Alt-tab away mid-flight and the game waits for you.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and main and is_inside_tree() and DisplayServer.get_name() != "headless":
		open()
