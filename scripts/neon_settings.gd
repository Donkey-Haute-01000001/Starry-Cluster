extends "res://scripts/neon_menu.gd"
## Settings and Controls as neon pages. The title screen and the pause menu
## both use this, so the two never drift apart. Esc on Settings emits `back`.

const Keys = preload("res://scripts/keys.gd")

var page := "settings"
var _bind_wait := ""


func _ready() -> void:
	super._ready()
	show_settings(true)


func _back() -> void:
	if page == "controls":
		Sfx.play("tick", -6.0)
		show_settings(true)
		sel = rows.size() - 1   # back on the Controls line
		return
	super._back()


# --- Settings --------------------------------------------------------------------

func show_settings(fresh := false) -> void:
	page = "settings"
	title = "SETTINGS"
	cols = [0.0, 300.0]
	row_h = 52.0
	catcher = Callable()
	note = ""
	hints = [["←→", "CHANGE", Callable()], ["ENTER", "SELECT", func(): _open(sel)], ["ESC", "BACK", _back]]
	var r := []
	for t in [["Flight assist", "assist"], ["Mouse steering", "mouse_steer"]]:
		var key: String = t[1]
		r.append(_toggle(t[0], PlayerController.setting(key), func(): PlayerController.toggle(key)))
	r.append(_toggle("Fullscreen", PlayerController.fullscreen, func():
		PlayerController.fullscreen = not PlayerController.fullscreen
		PlayerController.save_settings()))
	for t in [["Music", "music_vol"], ["Effects", "sfx_vol"]]:
		r.append(_volume(t[0], t[1]))
	r.append({"cells": ["Text speed", PlayerController.text_speed_name()],
		"step": func(d: int):
			PlayerController.step_text_speed(d)
			show_settings(),
		"act": func():
			PlayerController.step_text_speed(1)
			show_settings()})
	r.append({"cells": ["Controls", ""], "act": func(): show_controls(true)})
	set_rows(r, fresh)


func _toggle(label: String, on: bool, flip: Callable) -> Dictionary:
	var f := func(_d := 0):
		flip.call()
		show_settings()
	return {"cells": [label, "on" if on else "off"], "tint": {1: UIStyle.GREEN if on else OFF},
		"act": f, "step": f}


## Ten ticks like a meter. Left/right steps it, Enter mutes.
func _volume(label: String, key: String) -> Dictionary:
	var n := roundi(PlayerController.vol(key) * 10.0)
	var muted := PlayerController.muted(key)
	var gauge := "|".repeat(n) + ".".repeat(10 - n) + "  %d%%" % (n * 10)
	return {"cells": [label, "muted" if muted else gauge], "tint": {1: RED if muted else UIStyle.GREEN},
		"step": func(d: int):
			PlayerController.set_vol(key, clampf(snappedf(PlayerController.vol(key) + 0.1 * d, 0.1), 0.0, 1.0))
			show_settings(),
		"act": func():
			PlayerController.toggle_mute(key)
			show_settings()}


# --- Controls --------------------------------------------------------------------

func show_controls(fresh := false) -> void:
	page = "controls"
	title = "CONTROLS"
	cols = [0.0, 330.0]
	hints = [["ENTER", "REBIND", func(): _open(sel)], ["ESC", "BACK", _back]]
	if _bind_wait != "":
		hints = [["ANY KEY", "BIND", Callable()], ["ESC", "CANCEL", Callable()]]
	var r := []
	var group := ""
	for a in Keys.ACTIONS:
		if a[2] != group:
			group = a[2]
			r.append({"cells": [group], "head": true})
		var id: String = a[0]
		var waiting := _bind_wait == id
		r.append({"cells": [a[1], "press a key" if waiting else Keys.key_name(id)],
			"tint": {1: UIStyle.GOLD if waiting else UIStyle.GREEN},
			"act": func():
				_bind_wait = id
				note = "Press the new key for %s. Esc cancels." % Keys.label(id)
				note_col = UIStyle.GOLD
				catcher = _catch
				show_controls()})
	r.append({"cells": ["Fixed"], "head": true})
	for f in Keys.FIXED:
		r.append({"cells": [f[1], f[0]], "off": true})
	if not Keys.is_default():
		r.append({"cells": ["Reset to defaults", ""], "danger": true, "act": func():
			Keys.reset()
			note = "Defaults restored."
			note_col = DIM
			show_controls()})
	row_h = 44.0
	set_rows(r, fresh)
	if fresh:
		note = ""


## The next key or mouse button pressed goes to the waiting action.
func _catch(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_ESCAPE:
		note = ""
	else:
		var sp := Keys.spec_of(event)
		if sp == "":
			return
		if sp == "reserved":
			note = "That key is spoken for (see Fixed). Pick another."
			note_col = RED
			Sfx.play("tick", -6.0, 0.7)
			return
		var id := _bind_wait
		var swapped := Keys.rebind(id, sp)
		note = "%s  →  %s." % [Keys.label(id), Keys.key_name(id)]
		if swapped != "":
			note += "  %s moved to %s." % [Keys.label(swapped), Keys.key_name(swapped)]
		note_col = UIStyle.GREEN
	Sfx.play("tick", -6.0)
	_bind_wait = ""
	catcher = Callable()
	show_controls()
