extends Control

const Neon = preload("res://scripts/neon.gd")
## J: your logbook, laid out like an encyclopedia. Tabs across the top (Jobs,
## People, Places, Powers, Accounts); the left page lists entries, the right
## page shows the one you picked. Stops the clock while it's open.

var main: Node
var _was_paused := false
var _tab := 0
var _sel := [0, 0, 0, 0, 0]       ## selected entry per tab
var _hit: Array = []              ## [Rect2, kind, index] clickable areas this frame

const TABS := ["JOBS", "PEOPLE", "PLACES", "POWERS", "ACCOUNTS"]

var _t := 0.0
var _flip := 1.0                  ## page-turn progress after a tab change
var _cover: PaperSheet
var _left: PaperSheet
var _right: PaperSheet
var _dim: Control
var _title_font: FontVariation


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_dim = UIStyle.lamp_backdrop()
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.visible = false
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_add_dim.call_deferred()
	_cover = PaperSheet.new({"mode": 1, "tint": LEATHER, "seed": 11.0})
	_cover.shadow = Vector2(8, 14)
	_cover.shadow_alpha = 0.6
	add_child(_cover)
	_left = PaperSheet.new({"gutter": 1.0, "wear": 0.55, "seed": 4.0, "rule": 22.0, "rule_top": 86.0, "margin": 14.0})
	_left.shadow_alpha = 0.0
	add_child(_left)
	_right = PaperSheet.new({"gutter": 0.0, "wear": 0.55, "seed": 8.0})
	_right.shadow_alpha = 0.0
	add_child(_right)
	_title_font = FontVariation.new()
	_title_font.base_font = Data.font_bold
	_title_font.spacing_glyph = 3


## The dim sits under the book as a sibling, so it doesn't turn with it.
func _add_dim() -> void:
	get_parent().add_child(_dim)
	get_parent().move_child(_dim, get_index())


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and _dim and _dim.is_inside_tree():
		_dim.visible = visible
		_dim.modulate.a = 0.0


func toggle() -> void:
	if visible:
		close()
	else:
		open()


## Open straight to the page for a highlighted word (M&B encyclopedia links).
func open_to(kind: String, phrase: String) -> bool:
	var l: Array = Neon.link(kind, phrase)
	if l.is_empty():
		return false
	_tab = l[0]
	var list := _entries()
	for i in list.size():
		var pay = list[i][3]
		var key = pay["id"] if pay is Dictionary else pay
		if str(key) == str(l[1]):
			_sel[_tab] = i
			break
	open()
	return true


func open() -> void:
	if visible or main.pause_menu.visible:
		return
	_was_paused = get_tree().paused
	if main.sector_map.visible:
		_was_paused = main.sector_map.close(true)
	get_tree().paused = true
	visible = true
	_t = 0.0
	_flip = 1.0
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
	_flip = 0.0
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
		out.append(["Bounty: the Red Stork", "pirate skiff near Amber's" if not paid else "paid", paid, {
			"desc": "Lt. Kessler's board at Four: the Red Stork, last seen near Amber's. 3,000 dead, 4,500 alive. He lends you four marines.",
			"steps": [["Take the bounty at Four", taken], ["Disable or destroy the Red Stork", killed], ["Collect at Four", paid]]}])
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
				return "you took the Red Stork"
			return "the Tallyman let you go" if _flag("tally_done") else "never met"
		"dynasty":
			return "one exile flies with you" if Career.crew.has("mersham") else "never met"
	return "rumor only"


## Where you sit with a power, 0 (hostile) to 1 (trusted); -1 = no idea.
func _standing_value(id: String) -> float:
	match id:
		"charter":
			return 0.62 if Career.loan_balance <= 0 else 0.36
		"federation":
			return 0.5 + (0.12 if _flag("franz_met") else 0.0) + (0.14 if _flag("bounty_paid") else 0.0)
		"grind":
			if _flag("bounty_killed"):
				return 0.24
			return 0.45 if _flag("tally_done") else -1.0
		"dynasty":
			return 0.56 if Career.crew.has("mersham") else -1.0
	return -1.0


func _role_of(who: String) -> String:
	if Career.friend.get("name", "") == who:
		return "old friend  ·  " + str(Data.friend_roles.get(Career.friend.get("role", ""), {}).get("name", "")).to_lower()
	if who in ["Fay", "Mersham"]:
		return "crew" if Career.crew.has(who.to_lower()) else "Saltgate bar"
	var role := str(Data.speaker_info(who).get("role", "")).to_lower()
	return role if role != "" else "no file  ·  open band"


# --- Drawing ------------------------------------------------------------------------

const TAB_TINTS := [Color(0.87, 0.79, 0.56), Color(0.68, 0.75, 0.6), Color(0.64, 0.71, 0.8), Color(0.83, 0.63, 0.58), Color(0.86, 0.71, 0.44)]
const LEATHER := Color(0.33, 0.17, 0.11)
const GOLD_FOIL := Color(0.8, 0.66, 0.38)
const HIGHLIGHT := Color(1.0, 0.86, 0.25, 0.38)


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	_flip = minf(_flip + delta / 0.3, 1.0)
	var k := 1.0 - pow(1.0 - clampf(_t / 0.38, 0.0, 1.0), 3.0)
	pivot_offset = size * 0.5
	scale = Vector2.ONE * lerpf(0.94, 1.0, k)
	rotation = lerpf(0.03, 0.0, k)
	modulate.a = clampf(_t / 0.2, 0.0, 1.0)
	_dim.modulate.a = modulate.a
	var pr := _page_rect()
	var half := pr.size.x * 0.42
	_cover.place(Rect2(pr.position - Vector2(24, 24), pr.size + Vector2(48, 66)))
	_left.place(Rect2(pr.position, Vector2(half, pr.size.y)))
	_right.place(Rect2(pr.position + Vector2(half, 0), Vector2(pr.size.x - half, pr.size.y)))
	queue_redraw()


func _page_rect() -> Rect2:
	var ps := Vector2(minf(1120.0, size.x - 90.0), minf(640.0, size.y - 150.0))
	return Rect2((size - ps) * 0.5 + Vector2(0, 14), ps)


func _draw() -> void:
	_hit.clear()
	var pr := _page_rect()
	var half := pr.size.x * 0.42
	var lp := Rect2(pr.position, Vector2(half, pr.size.y))
	var rp := Rect2(pr.position + Vector2(half, 0), Vector2(pr.size.x - half, pr.size.y))
	var cover := Rect2(pr.position - Vector2(24, 24), pr.size + Vector2(48, 66))
	# The page block's edges, under the pages.
	for k in range(4, 0, -1):
		draw_line(Vector2(pr.position.x + 4, pr.end.y + k * 2.0), Vector2(pr.end.x - 4, pr.end.y + k * 2.0), Color(0.86, 0.82, 0.72).darkened(0.08 * k), 2.0)
	# Gold foil on the cover's lip.
	var foil := "OPERATOR'S LOG  ·  THE CHARTER COMPANY  ·  CC-40817-M"
	var fw := Data.font_type_bold.get_string_size(foil, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	draw_string(Data.font_type_bold, Vector2(cover.get_center().x - fw * 0.5, cover.end.y - 17), foil, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(GOLD_FOIL, 0.75))
	# The ribbon, hanging out of the bottom.
	_ribbon(Vector2(rp.position.x + rp.size.x * 0.72, pr.end.y - 4), cover.end.y + 46.0)
	# Index tabs, sticking up from behind the pages.
	var tx := pr.position.x + 34.0
	for i in TABS.size():
		var label: String = TABS[i]
		var w := Data.font_type_bold.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 44.0
		var on := i == _tab
		var h := 40.0 if on else 32.0
		var tr := Rect2(Vector2(tx, cover.position.y - h + 10), Vector2(w, h))
		var tint: Color = TAB_TINTS[i]
		var poly := PackedVector2Array([tr.position + Vector2(0, h), tr.position + Vector2(5, 4), tr.position + Vector2(9, 0),
				tr.position + Vector2(w - 9, 0), tr.position + Vector2(w - 5, 4), tr.position + Vector2(w, h)])
		draw_colored_polygon(poly, tint if on else tint.darkened(0.18))
		draw_polyline(poly, Color(0, 0, 0, 0.25), 1.0, true)
		draw_line(tr.position + Vector2(10, 2), tr.position + Vector2(w - 10, 2), Color(1, 1, 1, 0.25), 1.5)
		draw_string(Data.font_type, tr.position + Vector2(13, 21), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(UIStyle.INK_TYPE, 0.55))
		draw_string(Data.font_type_bold, tr.position + Vector2(26, 22), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UIStyle.INK_TYPE if on else Color(UIStyle.INK_TYPE, 0.6))
		_hit.append([tr, "tab", i])
		tx += w + 6.0
	# Footers.
	var name_s := str(Career.pilot.get("name", ""))
	draw_string(Data.font_type, Vector2(lp.position.x + 30, pr.end.y - 14), "%s  ·  day %d  ·  p. %d" % [name_s, int(Career.day) + 1, _tab * 12 + _sel[_tab] * 2 + 1], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UIStyle.INK_FADED)
	draw_string(Data.font_type, Vector2(rp.end.x - 70, pr.end.y - 14), "p. %d" % (_tab * 12 + _sel[_tab] * 2 + 2), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UIStyle.INK_FADED)
	var hint := "Tab / 1-5 sections   ·   wheel or click entries   ·   J or Esc closes"
	var hw := Data.font_type.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	draw_string(Data.font_type, Vector2(pr.get_center().x - hw * 0.5, cover.end.y + 30), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.45))

	if _tab == 4:
		_accounts(lp.grow(-30), rp.grow(-38))
	else:
		var list := _entries()
		_sel[_tab] = clampi(_sel[_tab], 0, maxi(0, list.size() - 1))
		_list(lp.grow(-26), list)
		if list.is_empty():
			draw_string(Data.font_hand, rp.position + Vector2(40, 80), "nothing here yet.", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, UIStyle.INK_PEN)
		else:
			var e: Array = list[_sel[_tab]]
			var r := rp.grow(-38)
			match _tab:
				0: _job_page(r, e)
				1: _person_page(r, e[3])
				2: _place_page(r, e[3])
				3: _power_page(r, e[3])
	if _flip < 1.0:
		_turning_page(lp, rp, _flip)


## A page turning over, right to left: it lifts off the right page and lays
## down on the left, shading as it goes.
func _turning_page(lp: Rect2, rp: Rect2, t: float) -> void:
	var g := rp.position.x
	var top := rp.position.y
	var bot := rp.end.y
	var e := t * t * (3.0 - 2.0 * t)
	var edge := lerpf(rp.end.x, lp.position.x, e)
	var lift := sin(e * PI) * 22.0
	var shade := 0.55 + 0.45 * absf(e - 0.5) * 2.0
	var paper := UIStyle.PAPER * Color(shade, shade, shade * 0.97, 1.0)
	var poly := PackedVector2Array([Vector2(g, top), Vector2(edge, top - lift), Vector2(edge, bot + lift * 0.4), Vector2(g, bot)])
	var cols := PackedColorArray([paper.darkened(0.15), paper, paper, paper.darkened(0.15)])
	# Its shadow on the page beneath.
	var sh := 18.0 * sin(e * PI)
	var sdir := 1.0 if edge > g else -1.0
	draw_colored_polygon(PackedVector2Array([Vector2(g, top), Vector2(edge + sh * sdir, top), Vector2(edge + sh * sdir, bot), Vector2(g, bot)]), Color(0, 0, 0, 0.12 * sin(e * PI)))
	draw_polygon(poly, cols)
	draw_line(Vector2(edge, top - lift), Vector2(edge, bot + lift * 0.4), Color(0, 0, 0, 0.2), 1.0)


func _list(r: Rect2, list: Array) -> void:
	var tb: Font = Data.font_type_bold
	var tr: Font = Data.font_type
	var y := r.position.y + 6.0
	draw_string(_title_font, Vector2(r.position.x + 4, y + 22), TABS[_tab], HORIZONTAL_ALIGNMENT_LEFT, -1, 26, UIStyle.INK_TYPE)
	var cnt := "%d %s" % [list.size(), "entry" if list.size() == 1 else "entries"]
	draw_string(tr, Vector2(r.end.x - tr.get_string_size(cnt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x, y + 20), cnt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UIStyle.INK_FADED)
	y += 34.0
	var row_h := 44.0
	var max_rows := int((r.end.y - y - 24.0) / row_h)
	var first := clampi(_sel[_tab] - max_rows + 1, 0, maxi(0, list.size() - max_rows))
	for i in range(first, mini(list.size(), first + max_rows)):
		var e: Array = list[i]
		var rr := Rect2(Vector2(r.position.x - 8, y), Vector2(r.size.x + 16, row_h))
		var done: bool = e[2]
		var title := str(e[0])
		var tw := minf(tb.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x, r.size.x - 8)
		if i == _sel[_tab]:
			_highlighter(Vector2(r.position.x, y + 12), tw + 10, i)
			draw_string(Data.font_hand, Vector2(r.position.x - 22, y + 20), "»", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, UIStyle.INK_PEN)
		var col := UIStyle.INK_FADED if done else UIStyle.INK_TYPE
		draw_string(tb, Vector2(r.position.x + 4, y + 17), title, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 8, 14, col)
		if done and _tab == 0:
			var pts := PackedVector2Array()
			for k in 6:
				pts.append(Vector2(r.position.x + 1 + (tw + 8) * k / 5.0, y + 12 + sin(k * 1.7 + i) * 0.9))
			draw_polyline(pts, Color(UIStyle.INK_PEN, 0.8), 1.6, true)
		draw_string(tr, Vector2(r.position.x + 4, y + 39), str(e[1]), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 8, 11, UIStyle.INK_FADED)
		_hit.append([rr, "row", i])
		y += row_h
	if list.size() > first + max_rows:
		draw_string(Data.font_hand, Vector2(r.position.x, r.end.y - 6), "%d more over the page..." % (list.size() - first - max_rows), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, UIStyle.INK_PEN)


func _title(r: Rect2, title: String, sub: String) -> float:
	draw_string(_title_font, r.position + Vector2(0, 28), title.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, r.size.x, 30, UIStyle.INK_TYPE)
	draw_string(Data.font_type, r.position + Vector2(0, 48), sub, HORIZONTAL_ALIGNMENT_LEFT, r.size.x, 12, UIStyle.INK_FADED)
	draw_line(r.position + Vector2(0, 58), Vector2(r.end.x, r.position.y + 58), Color(UIStyle.INK_TYPE, 0.7), 1.5)
	draw_line(r.position + Vector2(0, 61), Vector2(r.end.x, r.position.y + 61), Color(UIStyle.INK_TYPE, 0.35), 1.0)
	return r.position.y + 84.0


func _para(r: Rect2, y: float, text: String, sz := 14, col := UIStyle.INK_TYPE, font: Font = null) -> float:
	var f: Font = font if font else Data.font_type
	draw_multiline_string(f, Vector2(r.position.x, y), text, HORIZONTAL_ALIGNMENT_LEFT, r.size.x, sz, -1, col)
	return y + f.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, r.size.x, sz).y + 10.0


func _head(r: Rect2, y: float, text: String) -> float:
	draw_string(Data.font_type_bold, Vector2(r.position.x, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UIStyle.INK_FADED)
	var w := Data.font_type_bold.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	draw_line(Vector2(r.position.x + w + 10, y - 4), Vector2(r.end.x, y - 4), Color(UIStyle.INK_TYPE, 0.25), 1.0)
	return y + 24.0


## Your own pen in the margin, a little crooked.
func _margin_note(at: Vector2, text: String, tilt := -3.0, sz := 26) -> void:
	if text == "":
		return
	draw_set_transform(at, deg_to_rad(tilt), Vector2.ONE)
	draw_string(Data.font_hand, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color(UIStyle.INK_PEN, 0.92))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _job_page(r: Rect2, e: Array) -> void:
	var d: Dictionary = e[3]
	draw_string(Data.font_type, Vector2(r.end.x - 70, r.position.y + 10), "No. %02d" % (_sel[0] + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UIStyle.INK_FADED)
	var y := _title(r, e[0], e[1])
	y = _para(r, y, d["desc"])
	y = _head(r, y + 8, "STEPS")
	for st in d["steps"]:
		var bx := Rect2(Vector2(r.position.x, y - 13), Vector2(15, 15))
		draw_rect(bx, UIStyle.INK_TYPE, false, 1.3)
		if st[1]:
			draw_polyline(PackedVector2Array([bx.position + Vector2(2, 7), bx.position + Vector2(7, 13), bx.position + Vector2(20, -6)]), UIStyle.INK_PEN, 2.5, true)
		draw_string(Data.font_type, Vector2(r.position.x + 26, y), st[0], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 26, 14, UIStyle.INK_FADED if st[1] else UIStyle.INK_TYPE)
		if st[1]:
			var sw := minf(Data.font_type.get_string_size(st[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x, r.size.x - 26)
			draw_line(Vector2(r.position.x + 24, y - 5), Vector2(r.position.x + 28 + sw, y - 4), Color(UIStyle.INK_PEN, 0.55), 1.3, true)
		y += 28.0
	_margin_note(Vector2(r.position.x + 30, y + 34.0), str(Data.margin_notes.get(e[0], "")), -2.5)
	if e[2]:
		_stamp(r.end - Vector2(110, 40), "DONE")


func _person_page(r: Rect2, who: String) -> void:
	var ph := Rect2(Vector2.ZERO, Vector2(124, 156))
	var pc := r.position + Vector2(66, 84)
	# Clipped into the log, a little crooked.
	draw_set_transform(pc, deg_to_rad(-3.0), Vector2.ONE)
	draw_rect(Rect2(-ph.size * 0.5 + Vector2(4, 6), ph.size + Vector2(6, 6)), Color(0, 0, 0, 0.18))
	UIStyle.draw_id_photo(self, Rect2(-ph.size * 0.5, ph.size), Data.portrait_for(who), str(Data.speaker_info(who).get("serial", "")), who.hash(), who)
	_paperclip(Vector2(-ph.size.x * 0.5 + 34, -ph.size.y * 0.5 - 14))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var x := r.position.x + 152.0
	var w := r.end.x - x
	draw_string(_title_font, Vector2(x, r.position.y + 28), who.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, w, 30, UIStyle.INK_TYPE)
	draw_string(Data.font_type, Vector2(x, r.position.y + 48), _role_of(who), HORIZONTAL_ALIGNMENT_LEFT, w, 12, UIStyle.INK_FADED)
	draw_line(Vector2(x, r.position.y + 58), Vector2(r.end.x, r.position.y + 58), Color(UIStyle.INK_TYPE, 0.7), 1.5)
	var first := -1.0
	var lines: Array = []
	for l in Career.comms_log:
		if l[1] == who:
			if first < 0.0:
				first = l[0]
			lines.append(l)
	var meta := str(Data.speaker_info(who).get("channel", ""))
	if first >= 0.0:
		meta += "   ·   first contact day %d" % (int(first) + 1)
	draw_string(Data.font_type, Vector2(x, r.position.y + 76), meta, HORIZONTAL_ALIGNMENT_LEFT, w, 11, UIStyle.INK_FADED)
	var by := _para(Rect2(Vector2(x, 0), Vector2(w, 0)), r.position.y + 100, str(Data.bios.get(who, "")), 13)
	_margin_note(Vector2(x + 4, maxf(by + 14.0, r.position.y + 160.0)), str(Data.margin_notes.get(who, "")), -2.0, 24)
	var y := maxf(r.position.y + 200.0, by + 46.0)
	y = _head(r, y, "ON THE RADIO")
	var shown: Array = []
	var h := 0.0
	for i in range(lines.size() - 1, -1, -1):
		var t := "\"%s\"" % Neon.plain(lines[i][2])
		var lh := Data.font_type.get_multiline_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 64, 12).y + 10.0
		if y + h + lh > r.end.y:
			break
		shown.push_front([lines[i][0], t])
		h += lh
	if shown.is_empty():
		draw_string(Data.font_type, Vector2(r.position.x, y), "No transmissions logged.", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UIStyle.INK_FADED)
	for s in shown:
		draw_string(Data.font_type_bold, Vector2(r.position.x, y), "D%02d" % (int(s[0]) + 1), HORIZONTAL_ALIGNMENT_LEFT, 56, 10, UIStyle.INK_FADED)
		draw_line(Vector2(r.position.x + 52, y - 10), Vector2(r.position.x + 52, y + 2), Color(UIStyle.INK_STAMP, 0.4), 1.0)
		var np := Neon.parse(s[1])
		y += Neon.draw(self, Data.font_type, Vector2(r.position.x + 64, y - Data.font_type.get_ascent(12)), np, r.size.x - 64, 12, UIStyle.INK_TYPE, 1.0, 1e9, true) + 10.0


func _place_page(r: Rect2, st_id: String) -> void:
	var st: Dictionary = Data.stations[st_id]
	var sys: Dictionary = Data.systems[st["system"]]
	var known: bool = Career.visited.has(st["system"])
	var y := _title(Rect2(r.position, Vector2(r.size.x - 110, r.size.y)), st["name"], "\"%s\"  ·  %s, %s  ·  %s" % [st["nick"], sys["name"], sys["nick"], sys["security"]])
	if known:
		# Up in the page corner, clear of the title and the description.
		_round_stamp(Vector2(r.end.x - 30, r.position.y + 4), sys["name"].to_upper(), "VISITED", st_id.hash(), 0.8)
	else:
		_margin_note(Vector2(r.end.x - 118, r.position.y + 40), "haven't been", 6.0, 24)
	y = _para(r, y, st.get("desc", ""))
	y = _head(r, y + 6, "TRADE")
	var names := func(arr: Array) -> String:
		return ", ".join(arr.map(func(g): return str(Data.goods[g]["name"]).to_lower()))
	draw_string(Data.font_type, Vector2(r.position.x, y), "Makes (cheap here):", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UIStyle.INK_FADED)
	draw_string(Data.font_type_bold, Vector2(r.position.x + 190, y), names.call(st.get("makes", [])), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 190, 13, UIStyle.INK_TYPE)
	y += 22
	draw_string(Data.font_type, Vector2(r.position.x, y), "Wants (pays well):", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UIStyle.INK_FADED)
	draw_string(Data.font_type_bold, Vector2(r.position.x + 190, y), names.call(st.get("wants", [])), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 190, 13, UIStyle.INK_TYPE)
	y += 32
	y = _head(r, y, "PRICES THIS WEEK" if known else "PRICES")
	_station_photo(Vector2(r.end.x - 128, r.end.y - 104), st_id, known)
	if known:
		var nt := str(Data.margin_notes.get("st_" + st_id, ""))
		draw_set_transform(Vector2(r.position.x + 8, r.end.y - 70), deg_to_rad(-2.5), Vector2.ONE)
		draw_multiline_string(Data.font_hand, Vector2.ZERO, nt, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 290, 26, -1, Color(UIStyle.INK_PEN, 0.92))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if not known:
		_para(Rect2(r.position, Vector2(r.size.x - 290, r.size.y)), y, "No prices on file until you've docked in %s." % sys["name"], 13, UIStyle.INK_FADED)
		return
	var col := 0
	var colw := r.size.x * 0.5
	for g in Data.goods_order:
		var px := r.position.x + col * colw
		var price := Career.price(st_id, g)
		var nm := str(Data.goods[g]["name"])
		var pv := "%d cr" % price
		draw_string(Data.font_type, Vector2(px, y), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UIStyle.INK_FADED)
		var nw := Data.font_type.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		var pw := Data.font_type_bold.get_string_size(pv, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		_leader(Vector2(px + nw + 6, y), px + colw - pw - 24)
		var pcol := UIStyle.INK_TYPE
		if g in st.get("makes", []):
			pcol = Color(0.18, 0.4, 0.22)
		elif g in st.get("wants", []):
			pcol = UIStyle.INK_STAMP
		draw_string(Data.font_type_bold, Vector2(px + colw - pw - 18, y), pv, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, pcol)
		col += 1
		if col == 2:
			col = 0
			y += 22


func _power_page(r: Rect2, pw: Dictionary) -> void:
	var y := _title(Rect2(r.position, Vector2(r.size.x - 100, r.size.y)), pw["name"], pw["kind"])
	_emblem(Vector2(r.end.x - 44, r.position.y + 32), str(pw["id"]))
	y = _para(r, y, pw["desc"])
	y = _head(r, y + 8, "YOUR STANDING")
	draw_string(Data.font_hand, Vector2(r.position.x + 6, y + 10), _standing(pw["id"]), HORIZONTAL_ALIGNMENT_LEFT, r.size.x, 30, UIStyle.INK_PEN)
	_pen_underline(Vector2(r.position.x + 4, y + 18), minf(Data.font_hand.get_string_size(_standing(pw["id"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x + 8, r.size.x), 3)
	_standing_scale(Rect2(Vector2(r.position.x, y + 70), Vector2(r.size.x, 60)), _standing_value(pw["id"]))
	y += 150.0
	y = _head(r, y, "DOSSIER")
	for row in [["WANTS FROM YOU", "wants"], ["CAN DO TO YOU", "can"], ["A FRIEND THERE", "friend"]]:
		draw_string(Data.font_type_bold, Vector2(r.position.x, y), row[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UIStyle.INK_FADED)
		draw_multiline_string(Data.font_type, Vector2(r.position.x + 150, y), str(pw.get(row[1], "")), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 150, 13, -1, UIStyle.INK_TYPE)
		y += 34.0


func _accounts(l: Rect2, r: Rect2) -> void:
	# Left: your ID, clipped to the page.
	draw_string(_title_font, Vector2(l.position.x, l.position.y + 26), "OPERATOR", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, UIStyle.INK_TYPE)
	draw_string(Data.font_type, Vector2(l.position.x, l.position.y + 46), "Charter file CC-40817-M", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UIStyle.INK_FADED)
	var ph := Vector2(132, 168)
	var pc := l.position + Vector2(ph.x * 0.5 + 6, 76 + ph.y * 0.5)
	draw_set_transform(pc, deg_to_rad(2.5), Vector2.ONE)
	draw_rect(Rect2(-ph * 0.5 + Vector2(4, 6), ph + Vector2(6, 6)), Color(0, 0, 0, 0.18))
	UIStyle.draw_id_photo(self, Rect2(-ph * 0.5, ph), [Color(0.8, 0.65, 0.5), Color(0.2, 0.15, 0.1), Color(0.3, 0.35, 0.4)], "CC-40817-M", 7, "You")
	_paperclip(Vector2(-ph.x * 0.5 + 18, -ph.y * 0.5 - 14))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var fx := l.position.x + ph.x + 34.0
	var yy := l.position.y + 96.0
	for f in [["OPERATOR", str(Career.pilot.get("name", ""))], ["RIG", str(Career.pilot.get("rig", ""))]]:
		draw_string(Data.font_type, Vector2(fx, yy), f[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UIStyle.INK_FADED)
		draw_string(Data.font_hand, Vector2(fx, yy + 30), f[1], HORIZONTAL_ALIGNMENT_LEFT, l.end.x - fx, 32, UIStyle.INK_PEN)
		yy += 66.0
	var y := l.position.y + 280.0
	y = _head(l, y, "FLEET")
	var fleet: Array = [[str(Career.pilot.get("rig", "your rig")), "light freighter  ·  you"]]
	if Career.friend.get("met", false):
		fleet.append([str(Career.friend.get("name", "Dez")), "%s%s" % [Data.friend_roles[Career.friend["role"]]["ship"], "  ·  down till next dock" if Career.friend.get("down", false) else ""]])
	for id in Career.crew:
		fleet.append([Data.captains[id]["name"], "%s  ·  %d cr/wk" % [Data.captains[id]["ship"], Data.captains[id]["wage"]]])
	for f in fleet:
		draw_string(Data.font_type_bold, Vector2(l.position.x, y), f[0], HORIZONTAL_ALIGNMENT_LEFT, l.size.x, 13, UIStyle.INK_TYPE)
		draw_string(Data.font_type, Vector2(l.position.x, y + 16), f[1], HORIZONTAL_ALIGNMENT_LEFT, l.size.x, 11, UIStyle.INK_FADED)
		y += 40.0
	if Career.loan_balance > 0:
		_stamp(Vector2(l.end.x - 90, l.end.y - 40), "UNDER LIEN")

	# Right: the books.
	y = _title(r, "Accounts", "Day %d  ·  week %d" % [int(Career.day) + 1, int(Career.day / 7.0) + 1])
	var rows := [
		["Credits on hand", "%s cr" % _num(Career.credits), UIStyle.INK_TYPE],
		["Charter loan", "%s cr" % _num(Career.loan_balance) if Career.loan_balance > 0 else "PAID IN FULL", UIStyle.INK_STAMP if Career.loan_balance > 0 else UIStyle.INK_TYPE],
		["Wages", "%s cr / week" % _num(_wages()), UIStyle.INK_TYPE],
		["Hold", "%d / %d t" % [Career.cargo_used(), Career.cargo_capacity], UIStyle.INK_TYPE],
	]
	for row in rows:
		draw_string(Data.font_type, Vector2(r.position.x, y), row[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UIStyle.INK_FADED)
		var vw := Data.font_type_bold.get_string_size(row[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		_leader(Vector2(r.position.x + Data.font_type.get_string_size(row[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 8, y), r.end.x - vw - 8)
		draw_string(Data.font_type_bold, Vector2(r.end.x - vw, y), row[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, row[2])
		y += 26.0
	y = _head(r, y + 10, "IN THE HOLD")
	var any := false
	for src in [[Career.cargo, ""], [Career.job_cargo, "  (job)"]]:
		for g in src[0]:
			var nm := "%s%s" % [Data.goods[g]["name"], src[1]]
			var v := "%d t" % src[0][g]
			draw_string(Data.font_type, Vector2(r.position.x, y), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UIStyle.INK_TYPE)
			var vw2 := Data.font_type_bold.get_string_size(v, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
			_leader(Vector2(r.position.x + Data.font_type.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 8, y), r.end.x - vw2 - 8)
			draw_string(Data.font_type_bold, Vector2(r.end.x - vw2, y), v, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UIStyle.INK_TYPE)
			y += 22.0
			any = true
	if not any:
		draw_string(Data.font_hand, Vector2(r.position.x, y + 4), "empty. that's money sitting still.", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, UIStyle.INK_PEN)
		y += 24.0
	# The remittance coupon for the next payment, ready to tear off.
	if Career.loan_balance > 0:
		var due_in := maxf(0.0, Career.next_payment_day - Career.day)
		var cp := Rect2(Vector2(r.position.x, r.end.y - 104), Vector2(r.size.x, 96))
		draw_rect(cp, Color(0.95, 0.9, 0.78, 0.6))
		_dashed_rect(cp, Color(UIStyle.INK_TYPE, 0.6))
		draw_string(Data.font_type, Vector2(cp.position.x + 6, cp.position.y - 5), "- - - tear here - - -", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, UIStyle.INK_FADED)
		draw_string(Data.font_type_bold, cp.position + Vector2(14, 24), "CHARTER COMPANY  ·  WEEKLY REMITTANCE", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UIStyle.INK_TYPE)
		draw_string(Data.font_type, cp.position + Vector2(14, 46), "Amount due", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UIStyle.INK_FADED)
		draw_string(Data.font_type_bold, cp.position + Vector2(130, 46), "%s cr" % _num(Data.LOAN_WEEKLY), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UIStyle.INK_STAMP)
		draw_string(Data.font_type, cp.position + Vector2(14, 66), "Due in", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UIStyle.INK_FADED)
		draw_string(Data.font_type_bold, cp.position + Vector2(130, 66), "%.1f days" % due_in, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UIStyle.INK_TYPE)
		draw_string(Data.font_type, cp.position + Vector2(14, 86), "Late payments accrue interest. The Charter thanks you.", HORIZONTAL_ALIGNMENT_LEFT, cp.size.x - 28, 9, UIStyle.INK_FADED)
		for i in 7:
			draw_rect(Rect2(cp.end + Vector2(-110 + i * 13, -66), Vector2(2 + (i * 7) % 4, 40)), UIStyle.INK_TYPE)


func _wages() -> int:
	var w := 0
	for id in Career.crew:
		w += int(Data.captains[id]["wage"])
	return w


func _stamp(at: Vector2, text: String) -> void:
	draw_set_transform(at, deg_to_rad(-8.0), Vector2.ONE)
	var w := Data.font_stamp.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
	var col := Color(UIStyle.INK_STAMP, 0.72)
	draw_rect(Rect2(Vector2(-w * 0.5 - 12, -32), Vector2(w + 24, 44)), col, false, 3.0)
	draw_rect(Rect2(Vector2(-w * 0.5 - 8, -28), Vector2(w + 16, 36)), Color(col, 0.5), false, 1.0)
	draw_string(Data.font_stamp, Vector2(-w * 0.5, 2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A round entry stamp, like a port's visa.
func _round_stamp(c: Vector2, ring: String, mid: String, sd: int, k := 1.0) -> void:
	var col := Color(0.2, 0.3, 0.55, 0.7)
	var rot := deg_to_rad(float(sd % 30) - 15.0)
	draw_set_transform(c, rot, Vector2.ONE * k)
	draw_arc(Vector2.ZERO, 44.0, 0, TAU, 48, col, 2.4, true)
	draw_arc(Vector2.ZERO, 31.0, 0, TAU, 40, col, 1.2, true)
	var w := Data.font_stamp.get_string_size(mid, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	draw_string(Data.font_stamp, Vector2(-w * 0.5, 6), mid, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, col)
	draw_line(Vector2(-24, -12), Vector2(24, -12), col, 1.0)
	draw_line(Vector2(-24, 12), Vector2(24, 12), col, 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_ring_text(c, 37.0 * k, "%s · HESPER MARCH · " % ring, maxi(7, int(round(8 * k))), col, rot - PI * 0.5)


func _ring_text(c: Vector2, rad: float, text: String, sz: int, col: Color, start: float) -> void:
	var f: Font = Data.font_type_bold
	var total := 0.0
	for ch in text:
		total += f.get_char_size(ch.unicode_at(0), sz).x
	var spread := TAU / maxf(total, 1.0) * rad
	var ang := start
	for ch in text:
		var w := f.get_char_size(ch.unicode_at(0), sz).x * spread
		var a := ang + w * 0.5 / rad
		draw_set_transform(c + Vector2(cos(a), sin(a)) * rad, a + PI * 0.5, Vector2(spread, 1.0))
		draw_char(f, Vector2(-w * 0.5 / spread, sz * 0.35), ch, sz, col)
		ang += w / rad
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Each power's mark, as printed on its paperwork.
func _emblem(c: Vector2, id: String) -> void:
	var ink := Color(UIStyle.INK_TYPE, 0.85)
	draw_arc(c, 34.0, 0, TAU, 48, ink, 2.0, true)
	draw_arc(c, 29.0, 0, TAU, 48, Color(ink, 0.5), 1.0, true)
	match id:
		"charter":
			var w := Data.font_stamp.get_string_size("CC", HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
			draw_string(Data.font_stamp, c + Vector2(-w * 0.5, 9), "CC", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, UIStyle.INK_STAMP)
		"federation":
			for i in 3:
				var y := c.y - 10 + i * 9
				draw_polyline(PackedVector2Array([Vector2(c.x - 15, y), Vector2(c.x, y + 8), Vector2(c.x + 15, y)]), UIStyle.INK_PEN, 3.0, true)
		"grind":
			for i in 4:
				draw_line(c + Vector2(-12 + i * 7, -13), c + Vector2(-11 + i * 7, 13), ink, 2.2)
			draw_line(c + Vector2(-17, 9), c + Vector2(17, -8), ink, 2.2)
		"dynasty":
			draw_arc(c + Vector2(0, 6), 14.0, PI, TAU, 20, ink, 2.4, true)
			draw_line(c + Vector2(-14, 6), c + Vector2(-14, 16), ink, 2.4)
			draw_line(c + Vector2(14, 6), c + Vector2(14, 16), ink, 2.4)
			for i in 8:
				var a := TAU * i / 8.0
				draw_line(c + Vector2(0, -2), c + Vector2(0, -2) + Vector2(cos(a), sin(a)) * 6.0, ink, 1.5)
		"league":
			draw_line(c + Vector2(0, -15), c + Vector2(0, 14), ink, 2.0)
			draw_line(c + Vector2(-16, -9), c + Vector2(16, -9), ink, 2.0)
			draw_arc(c + Vector2(-12, 0), 6.0, 0, PI, 12, ink, 1.8, true)
			draw_arc(c + Vector2(12, 0), 6.0, 0, PI, 12, ink, 1.8, true)
			draw_line(c + Vector2(-8, 14), c + Vector2(8, 14), ink, 2.0)
		_:
			draw_string(Data.font_type_bold, c + Vector2(-5, 7), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, ink)


## A printed scale from HOSTILE to TRUSTED with your pen mark on it.
func _standing_scale(r: Rect2, v: float) -> void:
	var ink := UIStyle.INK_TYPE
	var y := r.position.y + 20.0
	var labels := ["HOSTILE", "WARY", "NEUTRAL", "FRIENDLY", "TRUSTED"]
	draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color(ink, 0.7), 1.5)
	for i in 5:
		var x := r.position.x + r.size.x * i / 4.0
		draw_line(Vector2(x, y - 6), Vector2(x, y + 6), Color(ink, 0.7), 1.5)
		var w := Data.font_type.get_string_size(labels[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		var lx := clampf(x - w * 0.5, r.position.x, r.end.x - w)
		draw_string(Data.font_type, Vector2(lx, y + 22), labels[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UIStyle.INK_FADED)
	for i in 21:
		var x2 := r.position.x + r.size.x * i / 20.0
		draw_line(Vector2(x2, y - 3), Vector2(x2, y), Color(ink, 0.4), 1.0)
	if v < 0.0:
		draw_string(Data.font_hand, Vector2(r.position.x + r.size.x * 0.5 - 50, y - 12), "no idea yet", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, UIStyle.INK_PEN)
		return
	# Your mark: a pen chevron and a little X on the line.
	var mx := r.position.x + r.size.x * v
	draw_line(Vector2(mx - 6, y - 6), Vector2(mx + 6, y + 6), UIStyle.INK_PEN, 2.4, true)
	draw_line(Vector2(mx - 6, y + 6), Vector2(mx + 6, y - 6), UIStyle.INK_PEN, 2.4, true)
	draw_polyline(PackedVector2Array([Vector2(mx - 7, y - 24), Vector2(mx, y - 13), Vector2(mx + 7, y - 24)]), UIStyle.INK_PEN, 2.0, true)
	draw_string(Data.font_hand, Vector2(mx - 12, y - 28), "me", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, UIStyle.INK_PEN)


## A snapshot of the station taped into the log, or an empty frame if you
## haven't been.
func _station_photo(c: Vector2, st_id: String, known: bool) -> void:
	var st: Dictionary = Data.stations[st_id]
	var ph := Vector2(212, 148)
	var rot := deg_to_rad(2.5 if st_id.hash() % 2 == 0 else -2.0)
	draw_set_transform(c, rot, Vector2.ONE)
	var frame := Rect2(-ph * 0.5 - Vector2(10, 10), ph + Vector2(20, 44))
	draw_rect(Rect2(frame.position + Vector2(5, 7), frame.size), Color(0, 0, 0, 0.2))
	draw_rect(frame, Color(0.95, 0.93, 0.88))
	var img := Rect2(-ph * 0.5, ph)
	if known:
		draw_rect(img, Color(0.04, 0.05, 0.07))
		var rng := RandomNumberGenerator.new()
		rng.seed = st_id.hash()
		for i in 40:
			var p := img.position + Vector2(rng.randf() * ph.x, rng.randf() * ph.y)
			draw_rect(Rect2(p, Vector2(1, 1)), Color(1, 1, 1, rng.randf_range(0.2, 0.8)))
		var art := str(st.get("art", ""))
		draw_set_transform(c + Vector2(0, -frame.size.y * 0.0).rotated(rot), rot, Vector2.ONE)
		if art == "" or not Art.draw_fit(self, "stations/%s/00.png" % art, ph.y * 0.92, Color(0.95, 0.9, 0.8)):
			draw_arc(Vector2.ZERO, 40.0, 0, TAU, 32, Color(0.8, 0.8, 0.8), 3.0)
		# Film wash: warm, a touch faded.
		draw_rect(img, Color(1.0, 0.85, 0.6, 0.08))
		draw_rect(Rect2(img.position, Vector2(ph.x, ph.y * 0.3)), Color(1, 1, 1, 0.05))
	else:
		draw_rect(img, Color(0.86, 0.84, 0.78))
		var w := Data.font_hand.get_string_size("no photo yet", HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
		draw_string(Data.font_hand, Vector2(-w * 0.5, 6), "no photo yet", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(UIStyle.INK_PEN, 0.7))
	var cap := str(st["nick"])
	var cw := Data.font_hand.get_string_size(cap, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	draw_string(Data.font_hand, Vector2(-cw * 0.5, ph.y * 0.5 + 28), cap, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, UIStyle.INK_PEN)
	# Tape across the top.
	draw_colored_polygon(PackedVector2Array([Vector2(-36, -ph.y * 0.5 - 22), Vector2(36, -ph.y * 0.5 - 24), Vector2(38, -ph.y * 0.5 + 2), Vector2(-34, -ph.y * 0.5 + 4)]), Color(0.92, 0.87, 0.62, 0.6))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A wire paperclip holding a photo to the page.
func _paperclip(at: Vector2) -> void:
	var col := Color(0.55, 0.58, 0.62)
	# Straights and round ends, like bent wire.
	var pts := PackedVector2Array([at + Vector2(4, 30), at + Vector2(4, 4)])
	_arc_into(pts, at + Vector2(9, 4), 5.0, PI, TAU)
	pts.append(at + Vector2(14, 44))
	_arc_into(pts, at + Vector2(7, 44), 7.0, 0.0, PI)
	pts.append(at + Vector2(0, 0))
	_arc_into(pts, at + Vector2(9, 0), 9.0, PI, TAU)
	pts.append(at + Vector2(18, 38))
	draw_polyline(pts, Color(0, 0, 0, 0.25), 3.4, true)
	draw_polyline(pts, col, 2.2, true)
	draw_polyline(pts, Color(1, 1, 1, 0.35), 0.8, true)


func _arc_into(pts: PackedVector2Array, c: Vector2, r: float, a0: float, a1: float) -> void:
	for i in 9:
		var a := lerpf(a0, a1, i / 8.0)
		pts.append(c + Vector2(cos(a), sin(a)) * r)


## A highlighter stroke behind a line of type.
func _highlighter(at: Vector2, w: float, sd: int) -> void:
	var pts := PackedVector2Array()
	var h := 15.0
	for i in 7:
		pts.append(at + Vector2(w * i / 6.0, -h * 0.5 + sin(i * 2.1 + sd) * 1.2))
	for i in range(6, -1, -1):
		pts.append(at + Vector2(w * i / 6.0 + 2.0, h * 0.5 + sin(i * 1.3 + sd) * 1.2))
	draw_colored_polygon(pts, HIGHLIGHT)


func _pen_underline(at: Vector2, w: float, sd: int) -> void:
	var pts := PackedVector2Array()
	for i in 9:
		var t := float(i) / 8.0
		pts.append(at + Vector2(w * t, sin(t * 6.0 + sd) * 1.2 + t * 1.5))
	draw_polyline(pts, UIStyle.INK_PEN, 1.6, true)


## Dotted ledger leader from a label to its figure.
func _leader(from: Vector2, to_x: float) -> void:
	var x := from.x + 4.0
	while x < to_x:
		draw_rect(Rect2(Vector2(x, from.y - 2), Vector2(1.5, 1.5)), Color(UIStyle.INK_TYPE, 0.4))
		x += 6.0


func _dashed_rect(r: Rect2, col: Color) -> void:
	for side in [[r.position, Vector2(r.end.x, r.position.y)], [Vector2(r.end.x, r.position.y), r.end], [r.end, Vector2(r.position.x, r.end.y)], [Vector2(r.position.x, r.end.y), r.position]]:
		var a: Vector2 = side[0]
		var d: Vector2 = side[1] - a
		var n := maxi(2, int(d.length() / 7.0))
		for i in n:
			if i % 2 == 0:
				draw_line(a + d * (float(i) / n), a + d * (float(i + 1) / n), col, 1.0)


## The bookmark ribbon, tucked in and hanging out of the bottom.
func _ribbon(top: Vector2, bottom: float) -> void:
	var w := 16.0
	var col := Color(0.55, 0.1, 0.12)
	var sway := 6.0
	var pts := PackedVector2Array([top + Vector2(-w * 0.5, 0), top + Vector2(w * 0.5, 0),
			Vector2(top.x + w * 0.5 + sway, bottom), Vector2(top.x + sway, bottom - 9), Vector2(top.x - w * 0.5 + sway, bottom)])
	draw_colored_polygon(pts, col)
	draw_line(top + Vector2(-w * 0.5 + 3, 0), Vector2(top.x - w * 0.5 + 3 + sway, bottom - 4), Color(1, 1, 1, 0.12), 2.0)
	draw_line(top + Vector2(w * 0.5 - 2, 0), Vector2(top.x + w * 0.5 - 2 + sway, bottom - 2), Color(0, 0, 0, 0.25), 1.5)
	draw_rect(Rect2(top + Vector2(-w * 0.5, 0), Vector2(w, 6)), Color(0, 0, 0, 0.25))


func _num(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out
