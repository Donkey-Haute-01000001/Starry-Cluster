extends RefCounted
## Rebindable controls. One key (or mouse button) per action, saved in
## settings.cfg under [keys]. Arrows and F1 stay as fixed extras.
## Preload it: const Keys := preload("res://scripts/keys.gd")

## [action, label, group, default]. Default spec: "key:<physical keycode>" or "mouse:<button>".
const ACTIONS := [
	["thrust_forward", "Forward", "FLIGHT", "key:%d" % KEY_W],
	["thrust_back", "Back", "FLIGHT", "key:%d" % KEY_S],
	["strafe_left", "Strafe left", "FLIGHT", "key:%d" % KEY_A],
	["strafe_right", "Strafe right", "FLIGHT", "key:%d" % KEY_D],
	["turn_left", "Turn left", "FLIGHT", "key:%d" % KEY_Q],
	["turn_right", "Turn right", "FLIGHT", "key:%d" % KEY_E],
	["brake", "Brake", "FLIGHT", "key:%d" % KEY_X],
	["assist", "Flight assist", "FLIGHT", "key:%d" % KEY_V],
	["interact", "Dock / jump", "FLIGHT", "key:%d" % KEY_F],
	["autopilot", "Autopilot", "FLIGHT", "key:%d" % KEY_G],
	["fire_aimed", "Fire turrets", "COMBAT", "mouse:%d" % MOUSE_BUTTON_LEFT],
	["fire_secondary", "Fire secondary", "COMBAT", "mouse:%d" % MOUSE_BUTTON_RIGHT],
	["fire_fixed", "Forward guns", "COMBAT", "key:%d" % KEY_SPACE],
	["swap_secondary", "Swap secondary", "COMBAT", "key:%d" % KEY_R],
	["tactics", "Tactics (hold)", "COMBAT", "key:%d" % KEY_TAB],
	["target", "Attack target", "COMBAT", "key:%d" % KEY_T],
	["hail", "Hail ship", "COMMS", "key:%d" % KEY_Y],
	["board", "Board", "COMMS", "key:%d" % KEY_B],
	["answer", "Answer call", "COMMS", "key:%d" % KEY_C],
	["chart", "Chart", "SCREENS", "key:%d" % KEY_M],
	["journal", "Journal", "SCREENS", "key:%d" % KEY_J],
	["hold", "Hold", "SCREENS", "key:%d" % KEY_I],
	["toggle_help", "Controls card", "SCREENS", "key:%d" % KEY_H],
]
## Fixed extras, always on top of the bound key.
const EXTRAS := {
	"thrust_forward": [KEY_UP], "thrust_back": [KEY_DOWN],
	"turn_left": [KEY_LEFT], "turn_right": [KEY_RIGHT], "toggle_help": [KEY_F1],
}
## Shown on the sheet, never rebound. Binding one of these is refused.
const FIXED := [["Esc / P", "Pause"], ["Space / Enter", "Next comms line"], ["1 - 5", "Pick a reply"], ["Mouse", "Aim / steer"], ["Wheel", "Zoom"]]
const RESERVED := [KEY_ESCAPE, KEY_P, KEY_ENTER, KEY_KP_ENTER, KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_F1]

static var binds := {}  ## action -> spec, only where it differs from the default


static func spec(action: String) -> String:
	if binds.has(action):
		return binds[action]
	for a in ACTIONS:
		if a[0] == action:
			return a[3]
	return ""


static func label(action: String) -> String:
	for a in ACTIONS:
		if a[0] == action:
			return a[1]
	return action


## What the player sees: "W", "Space", "LMB".
static func key_name(action: String) -> String:
	return spec_name(spec(action))


static func spec_name(s: String) -> String:
	if s.begins_with("mouse:"):
		match int(s.substr(6)):
			MOUSE_BUTTON_LEFT: return "LMB"
			MOUSE_BUTTON_RIGHT: return "RMB"
			MOUSE_BUTTON_MIDDLE: return "MMB"
			MOUSE_BUTTON_XBUTTON1: return "Mouse 4"
			MOUSE_BUTTON_XBUTTON2: return "Mouse 5"
		return "Mouse %s" % s.substr(6)
	if s.begins_with("key:"):
		var pk := int(s.substr(4))
		var k := pk
		if DisplayServer.get_name() != "headless":
			var shown := DisplayServer.keyboard_get_keycode_from_physical(pk)
			if shown != KEY_NONE:
				k = shown
		return OS.get_keycode_string(k)
	return "-"


## A pressed key or mouse button as a spec. "" if it can't be bound.
## Reserved keys return "reserved".
static func spec_of(ev: InputEvent) -> String:
	if ev is InputEventKey and ev.pressed and not ev.echo:
		var pk: int = ev.physical_keycode if ev.physical_keycode != KEY_NONE else ev.keycode
		if pk in RESERVED:
			return "reserved"
		return "key:%d" % pk
	if ev is InputEventMouseButton and ev.pressed:
		if ev.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]:
			return ""
		return "mouse:%d" % ev.button_index
	return ""


## Bind; if another action had that key, it takes this one's old key (swap).
## Returns the action that was swapped, or "".
static func rebind(action: String, s: String) -> String:
	var old := spec(action)
	var swapped := ""
	for a in ACTIONS:
		if a[0] != action and spec(a[0]) == s:
			swapped = a[0]
			_put(swapped, old)
	_put(action, s)
	apply()
	PlayerController.save_settings()
	return swapped


static func _put(action: String, s: String) -> void:
	for a in ACTIONS:
		if a[0] == action:
			if a[3] == s:
				binds.erase(action)
			else:
				binds[action] = s


static func reset() -> void:
	binds.clear()
	apply()
	PlayerController.save_settings()


static func is_default() -> bool:
	return binds.is_empty()


## Push the binds into the InputMap.
static func apply() -> void:
	for a in ACTIONS:
		var id: String = a[0]
		if not InputMap.has_action(id):
			InputMap.add_action(id)
		InputMap.action_erase_events(id)
		InputMap.action_add_event(id, _event(spec(id)))
		for k in EXTRAS.get(id, []):
			InputMap.action_add_event(id, _event("key:%d" % k))


static func _event(s: String) -> InputEvent:
	if s.begins_with("mouse:"):
		var mb := InputEventMouseButton.new()
		mb.button_index = int(s.substr(6)) as MouseButton
		return mb
	var ev := InputEventKey.new()
	ev.physical_keycode = int(s.substr(4)) as Key
	return ev


static func write(c: ConfigFile) -> void:
	for id in binds:
		c.set_value("keys", id, binds[id])


static func read(c: ConfigFile) -> void:
	binds.clear()
	if c.has_section("keys"):
		for id in c.get_section_keys("keys"):
			var s: String = str(c.get_value("keys", id, ""))
			if (s.begins_with("key:") or s.begins_with("mouse:")) and label(id) != id:
				binds[id] = s
	apply()
