extends Control
## J: your logbook, laid out like an encyclopedia. Tabs across the top (Jobs,
## People, Places, Powers, Accounts); the left page lists entries, the right
## page shows the one you picked. Stops the clock while it's open.

var main: Node
var _was_paused := false
var _tab := 0
var _sel := [0, 0, 0, 0, 0]       ## selected entry per tab
var _hit: Array = []              ## [Rect2, kind, index] clickable areas this frame

const TABS := ["JOBS", "PEOPLE", "PLACES", "POWERS", "ACCOUNTS"]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func open() -> void:
	if visible or main.pause_menu.visible:
		return
	_was_paused = get_tree().paused
	if main.sector_map.visible:
		_was_paused = main.sector_map.close(true)
	get_tree().paused = true
	visible = true
	Sfx.play("flip", -4.0)
	queue_redraw()


func close(keep_paused := false) -> bool:
	if not visible:
		return _was_paused
	visible = false
	if not keep_paused and not _was_paused:
		get_tree().paused = false
	Sfx.play("flip", -10.0, 1.2)
	return _was_paused


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_J:
		if not main.merchant or main.pause_menu.visible:
			return
		toggle()
		get_viewport().set_input_as_handled()
	elif not visible:
		return
	elif event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_TAB or event.keycode == KEY_RIGHT:
		_set_tab(posmod(_tab + (-1 if event.shift_pressed else 1), TABS.size()))
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_LEFT:
		_set_tab(posmod(_tab - 1, TABS.size()))
		get_viewport().set_input_as_handled()
	elif event.keycode in [KEY_DOWN, KEY_S]:
		_step_sel(1)
		get_viewport().set_input_as_handled()
	elif event.keycode in [KEY_UP, KEY_W]:
		_step_sel(-1)
		get_viewport().set_input_as_handled()
	elif event.keycode >= KEY_1 and event.keycode <= KEY_5:
		_set_tab(event.keycode - KEY_1)
		get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			close()
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_step_sel(1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_step_sel(-1)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			for h in _hit:
				if (h[0] as Rect2).has_point(event.position):
					if h[1] == "tab":
						_set_tab(h[2])
					else:
						_sel[_tab] = h[2]
						Sfx.play("tick", -10.0)
						queue_redraw()
					return


func _set_tab(i: int) -> void:
	if i == _tab:
		return
	_tab = i
	Sfx.play("flip", -8.0, 1.2)
	queue_redraw()


func _step_sel(d: int) -> void:
	var n := _entries().size()
	if n == 0:
		return
	_sel[_tab] = clampi(_sel[_tab] + d, 0, n - 1)
	queue_redraw()


# --- Entries ------------------------------------------------------------------------

## The left page's list for the current tab: [title, subtitle, done, payload].
func _entries() -> Array:
	match _tab:
		0: return _job_entries()
		1: return _people_entries()
		2: return _place_entries()
		3: return _power_entries()
	return []


func _flag(k: String) -> bool:
	return bool(Career.flags.get(k, false))


## Story threads and board jobs. Each: title, status line, done, steps [[text, done]].
func _job_entries() -> Array:
	var out: Array = []
	var loan_done := Career.loan_balance <= 0
	out.append(["The Charter loan", "%s cr owed" % _num(Career.loan_balance) if not loan_done else "paid in full", loan_done, {
		"desc": "Forty thousand credits for a used light freighter, %s a week, interest on anything missed. Pay it off and the rig is yours, and so are your papers." % _num(Data.LOAN_WEEKLY),
		"steps": [["Sign the financing agreement", true], ["Pay it down, week by week", loan_done], ["Get your papers stamped at the Wall", _flag("papers") or loan_done]]}])
	if _flag("met_charlie"):
		var sd := _flag("starter_done")
		var loaded := sd
		for j in Career.jobs:
			if j["id"] == "starter_water" and j["loaded"]:
				loaded = true
		out.append(["Starter run: water", "the Drip to the Greenhouse", sd, {
			"desc": "Charlie's first job: twenty tons of water from the Drip to the Greenhouse. Easy money, patrolled route. The Greenhouse also wants machine parts from the Bones.",
			"steps": [["Pick up 20 t of water at the Drip", loaded], ["Deliver it to the Greenhouse in Tiberine", sd]]}])
	if Career.friend.get("met", false):
		out.append(["An old friend", "Dez is flying with you", true, {
			"desc": "Ran into Dez at the Greenhouse bar. He's got a beat-up ship and nothing to haul, and he won't take wages.",
			"steps": [["Find Dez at the Greenhouse", true]]}])
	if _flag("tally_hailed") or _flag("tally_done"):
		out.append(["The Tallyman", "he let you go", _flag("tally_done"), {
			"desc": "Ambushed at the Marcellus jump exit. He ion-bolted the rig, talked, took nothing and left. He keeps a tally of Charter rigs on his hull.",
			"steps": [["Survive the ambush", _flag("tally_done")], ["Meet the navy patrol", _flag("franz_met")]]}])
	if _flag("franz_met"):
		var taken := _flag("bounty_taken")
		var killed := _flag("bounty_killed")
		var paid := _flag("bounty_paid")
		out.append(["Bounty: the Mud Lark", "pirate skiff near Amber's" if not paid else "paid", paid, {
			"desc": "Lt. Kessler's board at Four: the Mud Lark, last seen near Amber's. 3,000 dead, 4,500 alive. He lends you four marines.",
			"steps": [["Take the bounty at Four", taken], ["Disable or destroy the Mud Lark", killed], ["Collect at Four", paid]]}])
	if _flag("bar_pitch"):
		out.append(["Saltgate bar", "two captains looking for work", Career.crew.size() >= 2, {
			"desc": "Fay (150 a week) and Mersham (600 a week) pitched you at the Saltgate bar. Weekly contracts.",
			"steps": [["Hire Fay", Career.crew.has("fay")], ["Hire Mersham", Career.crew.has("mersham")]]}])
	for j in Career.jobs:
		if j["id"] == "starter_water":
			continue
		out.append([j["title"], "%s cr" % _num(j["pay"]), false, {
			"desc": "%d t of %s from %s to %s. Pays %s cr on delivery." % [j["tons"], Data.goods[j["good"]]["name"].to_lower(), Data.stations[j["from"]]["nick"], Data.stations[j["to"]]["nick"], _num(j["pay"])],
			"steps": [["Load at %s" % Data.stations[j["from"]]["nick"], j["loaded"]], ["Deliver to %s" % Data.stations[j["to"]]["nick"], false]]}])
	# Active first, then done.
	var active := out.filter(func(e): return not e[2])
	var done := out.filter(func(e): return e[2])
	return active + done


func _people_entries() -> Array:
	var out: Array = []
	for who in Career.contacts:
		if who == "You":
			continue
		out.append([who, _role_of(who), false, who])
	return out


func _place_entries() -> Array:
	var out: Array = []
	for sid in Data.systems:
		for st_id in Data.stations:
			var st: Dictionary = Data.stations[st_id]
			if st["system"] != sid:
				continue
			var known: bool = Career.visited.has(sid)
			out.append([st["nick"], "%s, %s" % [st["name"], Data.systems[sid]["name"]] if known else "%s  ·  not visited" % Data.systems[sid]["name"], not known, st_id])
	return out


func _power_entries() -> Array:
	var out: Array = []
	for pw in Data.powers:
		out.append([pw["name"], _standing(pw["id"]), false, pw])
	return out


func _standing(id: String) -> String:
	match id:
		"charter":
			return "debtor  ·  %s cr owed" % _num(Career.loan_balance) if Career.loan_balance > 0 else "paid in full  ·  owner-operator"
		"federation":
			if _flag("bounty_paid"):
				return "known to Lt. Kessler"
			if _flag("franz_met"):
				return "met the Marcellus patrol"
			return "citizen, unremarkable"
		"grind":
			if _flag("bounty_killed"):
				return "you took the Mud Lark"
			return "the Tallyman let you go" if _flag("tally_done") else "never met"
		"dynasty":
			return "one exile flies with you" if Career.crew.has("mersham") else "never met"
	return "rumor only"


func _role_of(who: String) -> String:
	if Career.friend.get("name", "") == who:
		return "old friend  ·  " + str(Data.friend_roles.get(Career.friend.get("role", ""), {}).get("name", "")).to_lower()
	if who in ["Fay", "Mersham"]:
		return "crew" if Career.crew.has(who.to_lower()) else "Saltgate bar"
	var role := str(Data.speaker_info(who).get("role", "")).to_lower()
	return role if role != "" else "no file  ·  open band"


# --- Drawing ------------------------------------------------------------------------

func _draw() -> void:
	_hit.clear()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.02, 0.78))
	var ps := Vector2(minf(1120.0, size.x - 60.0), minf(680.0, size.y - 90.0))
	var pr := Rect2((size - ps) * 0.5 + Vector2(0, 18), ps)
	# Tabs: paper flaps sticking up off the top edge.
	var tx := pr.position.x + 30.0
	for i in TABS.size():
		var label: String = TABS[i]
		var w := Data.font_type_bold.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 30.0
		var on := i == _tab
		var tr := Rect2(Vector2(tx, pr.position.y - (34.0 if on else 28.0)), Vector2(w, 36.0))
		draw_rect(tr, UIStyle.PAPER if on else UIStyle.PAPER_SHADE)
		draw_rect(tr, Color(UIStyle.INK_TYPE, 0.25), false, 1.0)
		draw_string(Data.font_type_bold, tr.position + Vector2(15, 22), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UIStyle.INK_TYPE if on else UIStyle.INK_FADED)
		_hit.append([tr, "tab", i])
		tx += w + 4.0
	draw_rect(Rect2(pr.position + Vector2(6, 8), pr.size), Color(0, 0, 0, 0.4))
	var half := pr.size.x * 0.42
	var lp := Rect2(pr.position, Vector2(half, pr.size.y))
	var rp := Rect2(pr.position + Vector2(half, 0), Vector2(pr.size.x - half, pr.size.y))
	draw_rect(lp, UIStyle.PAPER.darkened(0.03))
	draw_rect(rp, UIStyle.PAPER)
	for k in 6:
		draw_line(Vector2(rp.position.x - 3 + k, pr.position.y), Vector2(rp.position.x - 3 + k, pr.end.y), Color(0, 0, 0, 0.05 + 0.02 * (3 - absi(k - 3))), 1.0)
	draw_string(Data.font_type, Vector2(pr.position.x + 30, pr.end.y - 12), "OPERATOR'S LOG  ·  %s  ·  day %d" % [str(Career.pilot.get("name", "")), int(Career.day) + 1], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UIStyle.INK_FADED)
	draw_string(Data.font_type, Vector2(pr.end.x - 450, pr.end.y - 12), "Tab / 1-5 pages  ·  click or wheel entries  ·  J or Esc closes", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UIStyle.INK_FADED)
	if _tab == 4:
		_accounts(lp.grow(-28), rp.grow(-34))
		return
	var list := _entries()
	_sel[_tab] = clampi(_sel[_tab], 0, maxi(0, list.size() - 1))
	_list(lp.grow(-26), list)
	if list.is_empty():
		draw_string(Data.font_type, rp.position + Vector2(34, 60), "Nothing here yet.", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UIStyle.INK_FADED)
		return
	var e: Array = list[_sel[_tab]]
	var r := rp.grow(-34)
	match _tab:
		0: _job_page(r, e)
		1: _person_page(r, e[3])
		2: _place_page(r, e[3])
		3: _power_page(r, e[3])


func _list(r: Rect2, list: Array) -> void:
	var tb: Font = Data.font_type_bold
	var tr: Font = Data.font_type
	var y := r.position.y + 6.0
	draw_string(tb, Vector2(r.position.x, y + 14), TABS[_tab], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UIStyle.INK_TYPE)
	y += 26.0
	draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color(UIStyle.INK_TYPE, 0.5), 1.0)
	y += 8.0
	var row_h := 44.0
	# Keep the selection on the page.
	var max_rows := int((r.end.y - y - 20.0) / row_h)
	var first := clampi(_sel[_tab] - max_rows + 1, 0, maxi(0, list.size() - max_rows))
	for i in range(first, mini(list.size(), first + max_rows)):
		var e: Array = list[i]
		var rr := Rect2(Vector2(r.position.x - 8, y), Vector2(r.size.x + 16, row_h - 4))
		if i == _sel[_tab]:
			draw_rect(rr, Color(UIStyle.INK_PEN, 0.08))
			draw_rect(Rect2(rr.position, Vector2(3, rr.size.y)), UIStyle.INK_PEN)
		var done: bool = e[2]
		var col := UIStyle.INK_FADED if done else UIStyle.INK_TYPE
		draw_string(tb, Vector2(r.position.x + 4, y + 17), str(e[0]), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 8, 14, col)
		if done and _tab == 0:
			var tw := minf(tb.get_string_size(str(e[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x, r.size.x - 8)
			draw_line(Vector2(r.position.x + 2, y + 12), Vector2(r.position.x + 6 + tw, y + 11), Color(UIStyle.INK_PEN, 0.7), 1.5)
		draw_string(tr, Vector2(r.position.x + 4, y + 33), str(e[1]), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 8, 11, UIStyle.INK_FADED)
		_hit.append([rr, "row", i])
		y += row_h
	if list.size() > first + max_rows:
		draw_string(tr, Vector2(r.position.x, r.end.y - 4), "▼ %d more" % (list.size() - first - max_rows), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UIStyle.INK_FADED)


func _title(r: Rect2, title: String, sub: String) -> float:
	draw_string(Data.font_type_bold, r.position + Vector2(0, 20), title.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, r.size.x, 22, UIStyle.INK_TYPE)
	draw_string(Data.font_type, r.position + Vector2(0, 40), sub, HORIZONTAL_ALIGNMENT_LEFT, r.size.x, 12, UIStyle.INK_FADED)
	draw_line(r.position + Vector2(0, 50), Vector2(r.end.x, r.position.y + 50), Color(UIStyle.INK_TYPE, 0.5), 1.0)
	return r.position.y + 72.0


func _para(r: Rect2, y: float, text: String, sz := 14, col := UIStyle.INK_TYPE, font: Font = null) -> float:
	var f: Font = font if font else Data.font_type
	draw_multiline_string(f, Vector2(r.position.x, y), text, HORIZONTAL_ALIGNMENT_LEFT, r.size.x, sz, -1, col)
	return y + f.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, r.size.x, sz).y + 10.0


func _head(r: Rect2, y: float, text: String) -> float:
	draw_string(Data.font_type_bold, Vector2(r.position.x, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UIStyle.INK_FADED)
	draw_line(Vector2(r.position.x, y + 5), Vector2(r.end.x, y + 5), Color(UIStyle.INK_TYPE, 0.25), 1.0)
	return y + 24.0


func _job_page(r: Rect2, e: Array) -> void:
	var d: Dictionary = e[3]
	var y := _title(r, e[0], e[1])
	y = _para(r, y, d["desc"])
	y = _head(r, y + 6, "STEPS")
	for st in d["steps"]:
		var bx := Rect2(Vector2(r.position.x, y - 13), Vector2(15, 15))
		draw_rect(bx, UIStyle.INK_TYPE, false, 1.3)
		if st[1]:
			draw_polyline(PackedVector2Array([bx.position + Vector2(2, 7), bx.position + Vector2(7, 13), bx.position + Vector2(20, -6)]), UIStyle.INK_PEN, 2.5, true)
		draw_string(Data.font_type, Vector2(r.position.x + 26, y), st[0], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 26, 14, UIStyle.INK_FADED if st[1] else UIStyle.INK_TYPE)
		y += 26.0
	if e[2]:
		_stamp(r.end - Vector2(120, 60), "DONE")


func _person_page(r: Rect2, who: String) -> void:
	var ph := Rect2(r.position, Vector2(120, 152))
	UIStyle.draw_id_photo(self, ph, Data.portrait_for(who), str(Data.speaker_info(who).get("serial", "")), who.hash(), who)
	var x := ph.end.x + 22.0
	var tr := Rect2(Vector2(x, r.position.y), Vector2(r.end.x - x, 160))
	draw_string(Data.font_type_bold, Vector2(x, r.position.y + 22), who.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, tr.size.x, 22, UIStyle.INK_TYPE)
	draw_string(Data.font_type, Vector2(x, r.position.y + 42), _role_of(who), HORIZONTAL_ALIGNMENT_LEFT, tr.size.x, 12, UIStyle.INK_FADED)
	draw_string(Data.font_type, Vector2(x, r.position.y + 60), str(Data.speaker_info(who).get("channel", "")), HORIZONTAL_ALIGNMENT_LEFT, tr.size.x, 11, UIStyle.INK_FADED)
	var first := -1.0
	var lines: Array = []
	for l in Career.comms_log:
		if l[1] == who:
			if first < 0.0:
				first = l[0]
			lines.append(l)
	if first >= 0.0:
		draw_string(Data.font_type, Vector2(x, r.position.y + 78), "first contact: day %d" % (int(first) + 1), HORIZONTAL_ALIGNMENT_LEFT, tr.size.x, 11, UIStyle.INK_FADED)
	_para(Rect2(Vector2(x, 0), tr.size), r.position.y + 104, str(Data.bios.get(who, "")), 13)
	var y := ph.end.y + 28.0
	y = _head(r, y, "ON THE RADIO")
	# Newest last; as many as fit.
	var shown: Array = []
	var h := 0.0
	for i in range(lines.size() - 1, -1, -1):
		var t := "\"%s\"" % lines[i][2]
		var lh := Data.font_type.get_multiline_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 60, 12).y + 8.0
		if y + h + lh > r.end.y:
			break
		shown.push_front([lines[i][0], t])
		h += lh
	for s in shown:
		draw_string(Data.font_type, Vector2(r.position.x, y), "day %d" % (int(s[0]) + 1), HORIZONTAL_ALIGNMENT_LEFT, 56, 10, UIStyle.INK_FADED)
		draw_multiline_string(Data.font_type, Vector2(r.position.x + 60, y), s[1], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 60, 12, -1, UIStyle.INK_TYPE)
		y += Data.font_type.get_multiline_string_size(s[1], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 60, 12).y + 8.0


func _place_page(r: Rect2, st_id: String) -> void:
	var st: Dictionary = Data.stations[st_id]
	var sys: Dictionary = Data.systems[st["system"]]
	var known: bool = Career.visited.has(st["system"])
	var y := _title(r, st["name"], "\"%s\"  ·  %s, %s  ·  %s" % [st["nick"], sys["name"], sys["nick"], sys["security"]])
	y = _para(r, y, st.get("desc", ""))
	y = _head(r, y + 4, "TRADE")
	var names := func(arr: Array) -> String:
		return ", ".join(arr.map(func(g): return str(Data.goods[g]["name"]).to_lower()))
	draw_string(Data.font_type, Vector2(r.position.x, y), "Makes (cheap here):", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UIStyle.INK_FADED)
	draw_string(Data.font_type_bold, Vector2(r.position.x + 190, y), names.call(st.get("makes", [])), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 190, 13, UIStyle.INK_TYPE)
	y += 20
	draw_string(Data.font_type, Vector2(r.position.x, y), "Wants (pays well):", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UIStyle.INK_FADED)
	draw_string(Data.font_type_bold, Vector2(r.position.x + 190, y), names.call(st.get("wants", [])), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 190, 13, UIStyle.INK_TYPE)
	y += 30
	y = _head(r, y, "PRICES THIS WEEK" if known else "PRICES")
	if not known:
		_para(r, y, "You haven't been to %s yet." % sys["name"], 13, UIStyle.INK_FADED)
		return
	var col := 0
	for g in Data.goods_order:
		var px := r.position.x + col * (r.size.x * 0.5)
		draw_string(Data.font_type, Vector2(px, y), str(Data.goods[g]["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UIStyle.INK_FADED)
		draw_string(Data.font_type_bold, Vector2(px + 150, y), "%d cr" % Career.price(st_id, g), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UIStyle.INK_TYPE)
		col += 1
		if col == 2:
			col = 0
			y += 20


func _power_page(r: Rect2, pw: Dictionary) -> void:
	var y := _title(r, pw["name"], pw["kind"])
	y = _para(r, y, pw["desc"])
	y = _head(r, y + 4, "YOUR STANDING")
	draw_string(Data.font_hand, Vector2(r.position.x, y + 8), _standing(pw["id"]), HORIZONTAL_ALIGNMENT_LEFT, r.size.x, 28, UIStyle.INK_PEN)


func _accounts(l: Rect2, r: Rect2) -> void:
	# Left: your ID.
	var y := _title(l, "Operator", "Charter file CC-40817-M")
	var ph := Rect2(Vector2(l.position.x, y - 8), Vector2(130, 166))
	UIStyle.draw_id_photo(self, ph, [Color(0.8, 0.65, 0.5), Color(0.2, 0.15, 0.1), Color(0.3, 0.35, 0.4)], "CC-40817-M", 7, "You")
	var yy := ph.end.y + 30.0
	for f in [["OPERATOR", str(Career.pilot.get("name", ""))], ["RIG", str(Career.pilot.get("rig", ""))]]:
		draw_string(Data.font_type, Vector2(l.position.x, yy), f[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UIStyle.INK_FADED)
		draw_string(Data.font_hand, Vector2(l.position.x, yy + 30), f[1], HORIZONTAL_ALIGNMENT_LEFT, l.size.x, 32, UIStyle.INK_PEN)
		yy += 64.0
	draw_string(Data.font_type, Vector2(l.position.x, yy), "Light freighter  ·  Charter lien", HORIZONTAL_ALIGNMENT_LEFT, l.size.x, 12, UIStyle.INK_TYPE)
	# Right: the books.
	y = _title(r, "Accounts", "Day %d  ·  week %d" % [int(Career.day) + 1, int(Career.day / 7.0) + 1])
	var due_in := maxf(0.0, Career.next_payment_day - Career.day)
	var rows := [
		["Credits", "%s cr" % _num(Career.credits)],
		["Charter loan", "%s cr" % _num(Career.loan_balance) if Career.loan_balance > 0 else "PAID IN FULL"],
		["Next payment", ("%s cr in %.1f days" % [_num(Data.LOAN_WEEKLY), due_in]) if Career.loan_balance > 0 else "none"],
		["Wages", "%s cr a week" % _num(_wages())],
		["Hold", "%d / %d t" % [Career.cargo_used(), Career.cargo_capacity]],
	]
	for row in rows:
		draw_string(Data.font_type, Vector2(r.position.x, y), row[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UIStyle.INK_FADED)
		draw_string(Data.font_type_bold, Vector2(r.position.x + 200, y), row[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UIStyle.INK_TYPE)
		y += 22.0
	y = _head(r, y + 12, "IN THE HOLD")
	var any := false
	for src in [[Career.cargo, ""], [Career.job_cargo, "  (job)"]]:
		for g in src[0]:
			draw_string(Data.font_type, Vector2(r.position.x, y), "%s%s" % [Data.goods[g]["name"], src[1]], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UIStyle.INK_TYPE)
			draw_string(Data.font_type_bold, Vector2(r.position.x + 200, y), "%d t" % src[0][g], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UIStyle.INK_TYPE)
			y += 20.0
			any = true
	if not any:
		draw_string(Data.font_type, Vector2(r.position.x, y), "Empty.", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UIStyle.INK_FADED)
		y += 20.0
	y = _head(r, y + 12, "FLEET")
	var fleet: Array = ["%s  ·  light freighter  ·  you" % str(Career.pilot.get("rig", "your rig"))]
	if Career.friend.get("met", false):
		fleet.append("Dez  ·  %s%s" % [Data.friend_roles[Career.friend["role"]]["ship"], "  ·  down, back at next dock" if Career.friend.get("down", false) else ""])
	for id in Career.crew:
		fleet.append("%s  ·  %s  ·  %d cr/wk" % [Data.captains[id]["name"], Data.captains[id]["ship"], Data.captains[id]["wage"]])
	for f in fleet:
		draw_string(Data.font_type, Vector2(r.position.x, y), f, HORIZONTAL_ALIGNMENT_LEFT, r.size.x, 13, UIStyle.INK_TYPE)
		y += 20.0


func _wages() -> int:
	var w := 0
	for id in Career.crew:
		w += int(Data.captains[id]["wage"])
	return w


func _stamp(at: Vector2, text: String) -> void:
	draw_set_transform(at, deg_to_rad(-8.0), Vector2.ONE)
	var w := Data.font_stamp.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
	var col := Color(UIStyle.INK_STAMP, 0.75)
	draw_rect(Rect2(Vector2(-w * 0.5 - 10, -30), Vector2(w + 20, 40)), col, false, 3.0)
	draw_string(Data.font_stamp, Vector2(-w * 0.5, 2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _num(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out
