extends Control

const Neon = preload("res://scripts/neon.gd")
## J: your logbook in neon (docs/design/ui-look.md), laid out like an
## encyclopedia. Sections across the top (Jobs, People, Places, Powers, Accounts,
## Radio); the left column lists entries, the right shows the one you picked.
## Stops the clock while it's open.

var main: Node
var _was_paused := false
var _tab := 0
var _sel := [0, 0, 0, 0, 0, 0, 0]    ## selected entry per tab
var _hit: Array = []              ## [Rect2, kind, index] clickable areas this frame

const TABS := ["JOBS", "PEOPLE", "PLACES", "POWERS", "ACCOUNTS", "RADIO", "HOLD"]
const HOLD := 6
## Order on the page: HOLD first (hold.md). Tab ids stay put for the links.
const ORDER := [6, 0, 1, 2, 3, 4, 5]
const RADIO_PAGE := 10            ## lines per Radio entry (a long day runs over pages)

var _t := 0.0
var _flip := 0.0                  ## seconds since the section last changed (flicker-on)
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
	_flip = 0.0
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
	if event.is_action_pressed("hold"):
		if not main.merchant or main.pause_menu.visible:
			return
		if visible and _tab == HOLD:
			close()
		else:
			_set_tab(HOLD)
			open()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("journal"):
		if not main.merchant or main.pause_menu.visible:
			return
		toggle()
		get_viewport().set_input_as_handled()
	elif not visible or not (event is InputEventKey and event.pressed and not event.echo):
		return
	elif event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_TAB or event.keycode == KEY_RIGHT:
		_set_tab(ORDER[posmod(ORDER.find(_tab) + (-1 if event.shift_pressed else 1), ORDER.size())])
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_LEFT:
		_set_tab(ORDER[posmod(ORDER.find(_tab) - 1, ORDER.size())])
		get_viewport().set_input_as_handled()
	elif event.keycode in [KEY_DOWN, KEY_S]:
		_step_sel(1)
		get_viewport().set_input_as_handled()
	elif event.keycode in [KEY_UP, KEY_W]:
		_step_sel(-1)
		get_viewport().set_input_as_handled()
	elif event.keycode >= KEY_1 and event.keycode <= KEY_7:
		_set_tab(ORDER[event.keycode - KEY_1])
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
		5: return _radio_entries()
		6: return _hold_entries()
	return []


## Every line heard, a day per entry (long days split over pages), newest day first.
## Each: ["Day N", who spoke, false, [lines]].
func _radio_entries() -> Array:
	var days := {}
	var order: Array = []
	for l in Career.comms_log:
		var d := int(l[0])
		if not days.has(d):
			days[d] = []
			order.append(d)
		days[d].append(l)
	var out: Array = []
	for i in range(order.size() - 1, -1, -1):
		var lines: Array = days[order[i]]
		var pages := ceili(lines.size() / float(RADIO_PAGE))
		for pg in range(pages - 1, -1, -1):
			var chunk := lines.slice(pg * RADIO_PAGE, (pg + 1) * RADIO_PAGE)
			var who: Array = []
			for l in chunk:
				if not who.has(l[1]):
					who.append(l[1])
			var title := "Day %d" % (order[i] + 1)
			if pages > 1:
				title += "  ·  %d of %d" % [pg + 1, pages]
			out.append([title, ", ".join(who), false, chunk])
	return out


## What's in the hold: job cargo first, then your own goods. Each:
## [name, "20 t  ·  job" / "10 t  ·  +190", false, {good, tons, job}].
func _hold_entries() -> Array:
	var out: Array = []
	for r in main.hud.hold_rows():
		var g: String = r[0]
		var gd: Dictionary = Data.goods.get(g, {"name": g})
		var sub := "%d t" % r[1]
		if r[2] == "JOB":
			sub += "   job" + ("   to %s" % r[3] if r[3] != "" else "")
		else:
			var best: Array = Career.best_market(g)
			if best[0] != "" and Career.paid.has(g):
				var gain: int = (int(best[1]) - int(Career.paid[g])) * int(r[1])
				sub += "   %s%d cr at %s" % ["+" if gain >= 0 else "", gain, Data.stations[best[0]]["nick"]]
		out.append([str(gd["name"]), sub, false, {"good": g, "tons": r[1], "job": r[2] == "JOB", "to": r[3]}])
	return out


func _hold_page(r: Rect2, e: Array) -> void:
	var d: Dictionary = e[3]
	var g: String = d["good"]
	var gd: Dictionary = Data.goods.get(g, {})
	var slang := str(gd.get("slang", ""))
	var y := _title(r, e[0], ("%d t in the hold" % d["tons"]) + ("   \"%s\"" % slang if slang != "" else ""))
	if gd.has("desc"):
		y = _para(r, y, str(gd["desc"]))
	if d["job"]:
		y = _head(r, y + 8, "JOB CARGO")
		for j in Career.jobs:
			if j["good"] == g and j["loaded"]:
				y = _para(r, y, "%s. Deliver to %s. Pays %s cr." % [j["title"], Data.stations[j["to"]]["nick"], _num(j["pay"])])
		return
	y = _head(r, y + 8, "THE MONEY")
	if Career.paid.has(g):
		y = _para(r, y, "Paid %d cr a ton." % int(Career.paid[g]), 22, WHITE)
	var wants: Array = []
	for sid in Data.stations:
		if g in Data.stations[sid].get("wants", []) and Career._prices.has(sid) and Career._prices[sid].has(g):
			wants.append([Career.sell_price(sid, g), sid])
	wants.sort_custom(func(a, b): return a[0] > b[0])
	if wants.is_empty():
		y = _para(r, y, "Nobody posts a price for this. Ask around.", 22, DIM)
	for w in wants:
		var line := "%s wants it: %d cr a ton" % [Data.stations[w[1]]["nick"], w[0]]
		if Career.paid.has(g):
			var gain: int = (int(w[0]) - int(Career.paid[g])) * int(d["tons"])
			line += ",  %s%d cr on the load" % ["+" if gain >= 0 else "", gain]
		y = _para(r, y, line, 22, WHITE)


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

const WHITE := Color(0.9, 0.9, 0.94)
const DIM := Color(0.47, 0.49, 0.56)
const OFF := Color(0.3, 0.31, 0.37)
const RED := Color(1.0, 0.3, 0.33)
const PINK := Color(1.0, 0.43, 0.75)
const PEN := Color(1.0, 0.72, 0.87)


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	_flip += delta
	modulate.a = clampf(_t / 0.15, 0.0, 1.0)
	_dim.modulate.a = modulate.a
	queue_redraw()


func _page_rect() -> Rect2:
	var ps := Vector2(minf(1240.0, size.x - 80.0), minf(660.0, size.y - 170.0))
	return Rect2((size - ps) * 0.5 + Vector2(0, 20), ps)


func _draw() -> void:
	_hit.clear()
	var pr := _page_rect()
	var half := pr.size.x * 0.3
	var lp := Rect2(pr.position, Vector2(half, pr.size.y))
	var rp := Rect2(pr.position + Vector2(half, 0), Vector2(pr.size.x - half, pr.size.y))
	var talk: Font = Data.font_talk
	# Dark wash over the paused world, scanlines.
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.016, 0.02, 0.047, 0.9))
	for y in range(0, int(size.y), 3):
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(0, 0, 0, 0.22), 1.0)
	var a := _flick(0)
	# Header: tracked title, file number.
	var tx := pr.position.x
	for ch in "OPERATOR'S LOG":
		draw_string(Data.font_bold, Vector2(tx, pr.position.y - 58), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 1, 1, a))
		tx += Data.font_bold.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x + 7.0
	var meta := "%s   DAY %d   CC-40817-M" % [str(Career.pilot.get("name", "")).to_upper(), int(Career.day) + 1]
	draw_string(talk, Vector2(pr.position.x, pr.position.y - 58), meta, HORIZONTAL_ALIGNMENT_RIGHT, pr.size.x, 20, Color(OFF, a))
	# Sections: a row of neon words, the open one burning gold.
	tx = pr.position.x
	for n in ORDER.size():
		var i: int = ORDER[n]
		var label: String = TABS[i]
		var on := i == _tab
		var kw := talk.get_string_size(str(n + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		var lw := talk.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
		var by := pr.position.y - 16.0
		draw_string(talk, Vector2(tx, by), str(n + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(OFF, a))
		if on:
			_glow(talk, Vector2(tx + kw + 8, by), label, 28, UIStyle.GOLD, a)
			draw_line(Vector2(tx + kw + 8, by + 8), Vector2(tx + kw + 8 + lw, by + 8), Color(UIStyle.GOLD, 0.8 * a), 2.0)
		else:
			draw_string(talk, Vector2(tx + kw + 8, by), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(DIM, a))
		_hit.append([Rect2(Vector2(tx - 6, by - 28), Vector2(kw + lw + 20, 40)), "tab", i])
		tx += kw + lw + 44.0
	draw_line(Vector2(pr.position.x, pr.position.y), Vector2(pr.end.x, pr.position.y), Color(OFF, 0.6 * a), 1.0)
	draw_line(Vector2(rp.position.x - 18, pr.position.y + 20), Vector2(rp.position.x - 18, pr.end.y - 10), Color(OFF, 0.45 * a), 1.0)
	# Footer keys.
	var fx := pr.position.x
	for h in [["TAB", "SECTION"], ["UP DOWN", "ENTRY"], ["J", "CLOSE"]]:
		draw_string(talk, Vector2(fx, pr.end.y + 52), h[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(UIStyle.GOLD, 0.85 * a))
		fx += talk.get_string_size(h[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x + 10.0
		draw_string(talk, Vector2(fx, pr.end.y + 52), h[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(DIM, a))
		fx += talk.get_string_size(h[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x + 40.0

	var body := _flick(1)
	if _tab == 4:
		_accounts(Rect2(lp.position + Vector2(0, 40), lp.size - Vector2(30, 50)), Rect2(rp.position + Vector2(10, 40), rp.size - Vector2(10, 50)))
	else:
		var list := _entries()
		_sel[_tab] = clampi(_sel[_tab], 0, maxi(0, list.size() - 1))
		_list(Rect2(lp.position + Vector2(0, 24), lp.size - Vector2(36, 30)), list)
		if list.is_empty():
			_pen(Data.font_hand, rp.position + Vector2(10, 90), "nothing here yet.", 30, body)
		else:
			var e: Array = list[_sel[_tab]]
			var r := Rect2(rp.position + Vector2(10, 40), rp.size - Vector2(10, 50))
			match _tab:
				0: _job_page(r, e)
				1: _person_page(r, e[3])
				2: _place_page(r, e[3])
				3: _power_page(r, e[3])
				5: _radio_page(r, e)
				6: _hold_page(r, e)


## Neon flicker-on: buzzes for a moment after opening or changing section.
func _flick(i: int) -> float:
	var t := _flip - i * 0.05
	if t < 0.0:
		return 0.0
	if t > 0.35:
		return 1.0
	return [1.0, 0.15, 0.8, 0.3, 1.0][int(t / 0.07) % 5]


func _glow(f: Font, p: Vector2, s: String, sz: int, col: Color, a: float) -> void:
	for o in [Vector2(-2, 0), Vector2(2, 0), Vector2(0, -2), Vector2(0, 2)]:
		draw_string(f, p + o, s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color(col, 0.16 * a))
	draw_string(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color(col, a))


## Your pen, in pink neon: a soft bloom, then the stroke.
func _pen(f: Font, p: Vector2, s: String, sz: int, a := 1.0, w := -1.0) -> void:
	for o in [Vector2(-2, 0), Vector2(2, 0), Vector2(0, -2), Vector2(0, 2)]:
		draw_string(f, p + o, s, HORIZONTAL_ALIGNMENT_LEFT, w, sz, Color(PINK, 0.16 * a))
	draw_string(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, w, sz, Color(PEN, a))


func _list(r: Rect2, list: Array) -> void:
	var talk: Font = Data.font_talk
	var y := r.position.y + 14.0
	var cnt := "%d %s" % [list.size(), "ENTRY" if list.size() == 1 else "ENTRIES"]
	draw_string(talk, Vector2(r.position.x, y), cnt, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(OFF, _flick(1)))
	y += 22.0
	var row_h := 56.0
	var max_rows := int((r.end.y - y - 24.0) / row_h)
	var first := clampi(_sel[_tab] - max_rows + 1, 0, maxi(0, list.size() - max_rows))
	for i in range(first, mini(list.size(), first + max_rows)):
		var a := _flick(i - first + 2)
		var e: Array = list[i]
		var rr := Rect2(Vector2(r.position.x - 30, y), Vector2(r.size.x + 30, row_h))
		var done: bool = e[2]
		var title := str(e[0]).to_upper()
		var on: bool = i == _sel[_tab]
		var p := Vector2(r.position.x, y + 28)
		if on:
			_glow(talk, p - Vector2(24, 0), ">", 28, UIStyle.GOLD, a)
			_glow(talk, p, title, 28, UIStyle.GOLD, a)
		else:
			draw_string(talk, p, title, HORIZONTAL_ALIGNMENT_LEFT, r.size.x, 28, Color(OFF if done else WHITE, a))
		if done and _tab == 0:
			var tw := minf(talk.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x, r.size.x)
			draw_line(p + Vector2(-2, -8), p + Vector2(tw + 2, -8), Color(PINK, 0.8 * a), 2.0)
		draw_string(talk, Vector2(r.position.x, y + 50), str(e[1]), HORIZONTAL_ALIGNMENT_LEFT, r.size.x, 19, Color(DIM, a))
		_hit.append([rr, "row", i])
		y += row_h
	if list.size() > first + max_rows:
		draw_string(talk, Vector2(r.position.x, r.end.y), "%d MORE BELOW" % (list.size() - first - max_rows), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(OFF, _flick(1)))


func _title(r: Rect2, title: String, sub: String) -> float:
	var x := r.position.x
	var a := _flick(1)
	for ch in title.to_upper():
		draw_string(Data.font_bold, Vector2(x, r.position.y + 28), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(1, 1, 1, a))
		x += Data.font_bold.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x + 5.0
	draw_string(Data.font_talk, r.position + Vector2(0, 56), sub.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, r.size.x, 20, Color(DIM, a))
	return r.position.y + 96.0


func _para(r: Rect2, y: float, text: String, sz := 22, col := WHITE, font: Font = null) -> float:
	var f: Font = font if font else Data.font_talk
	draw_multiline_string(f, Vector2(r.position.x, y), text, HORIZONTAL_ALIGNMENT_LEFT, r.size.x, sz, -1, col)
	return y + f.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, r.size.x, sz).y + 10.0


func _head(r: Rect2, y: float, text: String) -> float:
	draw_string(Data.font_talk, Vector2(r.position.x, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(DIM, _flick(2)))
	return y + 30.0


## Your own pen beside the type, glowing pink.
func _margin_note(at: Vector2, text: String, _tilt := -3.0, sz := 26) -> void:
	if text == "":
		return
	_pen(Data.font_hand, at, text, sz + 4, _flick(3))


func _job_page(r: Rect2, e: Array) -> void:
	var d: Dictionary = e[3]
	draw_string(Data.font_talk, Vector2(r.end.x - 70, r.position.y + 10), "No. %02d" % (_sel[0] + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, DIM)
	var y := _title(r, e[0], e[1])
	y = _para(r, y, d["desc"])
	y = _head(r, y + 8, "STEPS")
	for st in d["steps"]:
		var bx := Rect2(Vector2(r.position.x, y - 13), Vector2(15, 15))
		draw_rect(bx, WHITE, false, 1.3)
		if st[1]:
			draw_polyline(PackedVector2Array([bx.position + Vector2(2, 7), bx.position + Vector2(7, 13), bx.position + Vector2(20, -6)]), PINK, 2.5, true)
		draw_string(Data.font_talk, Vector2(r.position.x + 26, y), st[0], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 26, 22, DIM if st[1] else WHITE)
		if st[1]:
			var sw := minf(Data.font_talk.get_string_size(st[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x, r.size.x - 26)
			draw_line(Vector2(r.position.x + 24, y - 5), Vector2(r.position.x + 28 + sw, y - 4), Color(PINK, 0.55), 1.3, true)
		y += 28.0
	_margin_note(Vector2(r.position.x + 30, y + 34.0), str(Data.margin_notes.get(e[0], "")), -2.5)
	if e[2]:
		_stamp(r.end - Vector2(110, 40), "DONE")


func _person_page(r: Rect2, who: String) -> void:
	var a := _flick(1)
	var ph := Rect2(r.position + Vector2(0, 4), Vector2(124, 156))
	UIStyle.draw_id_photo(self, ph, Data.portrait_for(who), str(Data.speaker_info(who).get("serial", "")), who.hash(), who)
	draw_rect(ph.grow(8), Color(UIStyle.GOLD, 0.18 * a), false, 4.0)
	draw_rect(ph.grow(8), Color(UIStyle.GOLD, 0.7 * a), false, 1.0)
	var x := r.position.x + 160.0
	var w := r.end.x - x
	var tx := x
	for ch in who.to_upper():
		draw_string(Data.font_bold, Vector2(tx, r.position.y + 28), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(1, 1, 1, a))
		tx += Data.font_bold.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x + 5.0
	draw_string(Data.font_talk, Vector2(x, r.position.y + 56), _role_of(who).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, w, 20, Color(DIM, a))
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
	draw_string(Data.font_talk, Vector2(x, r.position.y + 80), meta.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, w, 18, Color(OFF, a))
	var by := _para(Rect2(Vector2(x, 0), Vector2(w, 0)), r.position.y + 110, str(Data.bios.get(who, "")), 22)
	_margin_note(Vector2(x, maxf(by + 22.0, r.position.y + 170.0)), str(Data.margin_notes.get(who, "")), -2.0, 24)
	var y := maxf(r.position.y + 220.0, by + 56.0)
	y = _head(r, y, "ON THE RADIO")
	var shown: Array = []
	var h := 0.0
	for i in range(lines.size() - 1, -1, -1):
		var t := "\"%s\"" % Neon.plain(lines[i][2])
		var lh := Data.font_talk.get_multiline_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 64, 19).y + 10.0
		if y + h + lh > r.end.y:
			break
		shown.push_front([lines[i][0], t])
		h += lh
	if shown.is_empty():
		draw_string(Data.font_talk, Vector2(r.position.x, y), "No transmissions logged.", HORIZONTAL_ALIGNMENT_LEFT, -1, 19, DIM)
	for s in shown:
		draw_string(Data.font_talk, Vector2(r.position.x, y), "D%02d" % (int(s[0]) + 1), HORIZONTAL_ALIGNMENT_LEFT, 56, 19, UIStyle.GREEN)
		var np := Neon.parse(s[1])
		y += Neon.draw(self, Data.font_talk, Vector2(r.position.x + 64, y - Data.font_talk.get_ascent(19)), np, r.size.x - 64, 19, WHITE, 1.0, 1e9, true) + 10.0


## One day's radio, in the order it was said: who, then the line.
func _radio_page(r: Rect2, e: Array) -> void:
	var y := _title(r, str(e[0]), "%d lines  ·  in the order heard" % (e[3] as Array).size())
	var name_w := 96.0
	for l in e[3]:
		var who := str(l[1])
		var np := Neon.parse(str(l[2]))
		var tw := r.size.x - name_w
		var h := Neon.height(Data.font_talk, np, tw, 19)
		if y + h > r.end.y:
			draw_string(Data.font_talk, Vector2(r.position.x, r.end.y), "CONTINUED NEXT ENTRY", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, OFF)
			break
		draw_string(Data.font_talk, Vector2(r.position.x, y + Data.font_talk.get_ascent(19)), who.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, name_w - 10, 17, DIM)
		y += Neon.draw(self, Data.font_talk, Vector2(r.position.x + name_w, y), np, tw, 19, WHITE, 1.0, 1e9, true) + 10.0


func _place_page(r: Rect2, st_id: String) -> void:
	var st: Dictionary = Data.stations[st_id]
	var sys: Dictionary = Data.systems[st["system"]]
	var known: bool = Career.visited.has(st["system"])
	var y := _title(Rect2(r.position, Vector2(r.size.x - 110, r.size.y)), st["name"], "\"%s\"  ·  %s, %s  ·  %s" % [st["nick"], sys["name"], sys["nick"], sys["security"]])
	if known:
		# Up in the page corner, clear of the title and the description.
		var vw := Data.font_talk.get_string_size("VISITED", HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
		_glow(Data.font_talk, Vector2(r.end.x - vw, r.position.y + 24), "VISITED", 24, UIStyle.GREEN, _flick(3))
	else:
		_margin_note(Vector2(r.end.x - 118, r.position.y + 40), "haven't been", 6.0, 24)
	y = _para(r, y, st.get("desc", ""))
	y = _head(r, y + 6, "TRADE")
	var names := func(arr: Array) -> String:
		return ", ".join(arr.map(func(g): return str(Data.goods[g]["name"]).to_lower()))
	draw_string(Data.font_talk, Vector2(r.position.x, y), "Makes (cheap here):", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, DIM)
	draw_string(Data.font_talk, Vector2(r.position.x + 190, y), names.call(st.get("makes", [])), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 190, 20, WHITE)
	y += 22
	draw_string(Data.font_talk, Vector2(r.position.x, y), "Wants (pays well):", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, DIM)
	draw_string(Data.font_talk, Vector2(r.position.x + 190, y), names.call(st.get("wants", [])), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 190, 20, WHITE)
	y += 32
	y = _head(r, y, "PRICES THIS WEEK" if known else "PRICES")
	_station_photo(Vector2(r.end.x - 128, r.end.y - 104), st_id, known)
	if known:
		var nt := str(Data.margin_notes.get("st_" + st_id, ""))
		draw_set_transform(Vector2(r.position.x + 8, r.end.y - 70), deg_to_rad(-2.5), Vector2.ONE)
		draw_multiline_string(Data.font_hand, Vector2.ZERO, nt, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 290, 28, -1, PEN)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if not known:
		_para(Rect2(r.position, Vector2(r.size.x - 290, r.size.y)), y, "No prices on file until you've docked in %s." % sys["name"], 20, DIM)
		return
	var col := 0
	var colw := r.size.x * 0.5
	for g in Data.goods_order:
		var px := r.position.x + col * colw
		var price := Career.price(st_id, g)
		var nm := str(Data.goods[g]["name"])
		var pv := "%d cr" % price
		draw_string(Data.font_talk, Vector2(px, y), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, DIM)
		var nw := Data.font_talk.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		var pw := Data.font_talk.get_string_size(pv, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		_leader(Vector2(px + nw + 6, y), px + colw - pw - 24)
		var pcol := WHITE
		if g in st.get("makes", []):
			pcol = UIStyle.GREEN
		elif g in st.get("wants", []):
			pcol = RED
		draw_string(Data.font_talk, Vector2(px + colw - pw - 18, y), pv, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, pcol)
		col += 1
		if col == 2:
			col = 0
			y += 22


func _power_page(r: Rect2, pw: Dictionary) -> void:
	var y := _title(Rect2(r.position, Vector2(r.size.x - 100, r.size.y)), pw["name"], pw["kind"])
	_emblem(Vector2(r.end.x - 44, r.position.y + 32), str(pw["id"]))
	y = _para(r, y, pw["desc"])
	y = _head(r, y + 8, "YOUR STANDING")
	_pen(Data.font_hand, Vector2(r.position.x + 6, y + 10), _standing(pw["id"]), 32, 1.0, r.size.x)
	_pen_underline(Vector2(r.position.x + 4, y + 18), minf(Data.font_hand.get_string_size(_standing(pw["id"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x + 8, r.size.x), 3)
	_standing_scale(Rect2(Vector2(r.position.x, y + 70), Vector2(r.size.x, 60)), _standing_value(pw["id"]))
	y += 150.0
	y = _head(r, y, "DOSSIER")
	for row in [["WANTS FROM YOU", "wants"], ["CAN DO TO YOU", "can"], ["A FRIEND THERE", "friend"]]:
		draw_string(Data.font_talk, Vector2(r.position.x, y), row[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, DIM)
		draw_multiline_string(Data.font_talk, Vector2(r.position.x + 150, y), str(pw.get(row[1], "")), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 150, 20, -1, WHITE)
		y += 34.0


func _accounts(l: Rect2, r: Rect2) -> void:
	var a := _flick(1)
	# Left: your ID.
	draw_string(Data.font_talk, Vector2(l.position.x, l.position.y + 14), "CHARTER FILE CC-40817-M", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(OFF, a))
	var ph := Vector2(120, 152)
	var pr := Rect2(l.position + Vector2(0, 40), ph)
	UIStyle.draw_id_photo(self, pr, [Color(0.8, 0.65, 0.5), Color(0.2, 0.15, 0.1), Color(0.3, 0.35, 0.4)], "CC-40817-M", 7, "pilot_%d" % int(Career.pilot.get("photo", 0)))
	draw_rect(pr.grow(8), Color(UIStyle.GOLD, 0.18 * a), false, 4.0)
	draw_rect(pr.grow(8), Color(UIStyle.GOLD, 0.7 * a), false, 1.0)
	var fx := l.position.x + ph.x + 30.0
	var yy := l.position.y + 66.0
	for f in [["OPERATOR", str(Career.pilot.get("name", ""))], ["RIG", str(Career.pilot.get("rig", ""))]]:
		draw_string(Data.font_talk, Vector2(fx, yy), f[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, DIM)
		_pen(Data.font_hand, Vector2(fx, yy + 32), f[1], 34, a, l.end.x - fx)
		yy += 66.0
	var y := l.position.y + 250.0
	y = _head(l, y, "FLEET")
	var fleet: Array = [[str(Career.pilot.get("rig", "your rig")), "light freighter  ·  you"]]
	if Career.friend.get("met", false):
		fleet.append([str(Career.friend.get("name", "Dez")), "%s%s" % [Data.friend_roles[Career.friend["role"]]["ship"], "  ·  down till next dock" if Career.friend.get("down", false) else ""]])
	for id in Career.crew:
		fleet.append([Data.captains[id]["name"], "%s  ·  %d cr/wk" % [Data.captains[id]["ship"], Data.captains[id]["wage"]]])
	for f in fleet:
		draw_string(Data.font_talk, Vector2(l.position.x, y), f[0].to_upper(), HORIZONTAL_ALIGNMENT_LEFT, l.size.x, 24, WHITE)
		draw_string(Data.font_talk, Vector2(l.position.x, y + 22), f[1], HORIZONTAL_ALIGNMENT_LEFT, l.size.x, 19, DIM)
		y += 54.0
	if Career.loan_balance > 0:
		_stamp(Vector2(l.position.x + 110, l.end.y - 30), "UNDER LIEN")

	# Right: the books.
	y = _title(r, "Accounts", "Day %d  ·  week %d" % [int(Career.day) + 1, int(Career.day / 7.0) + 1])
	var rows := [
		["Credits on hand", "%s cr" % _num(Career.credits), UIStyle.GREEN],
		["Charter loan", "%s cr" % _num(Career.loan_balance) if Career.loan_balance > 0 else "PAID IN FULL", RED if Career.loan_balance > 0 else UIStyle.GREEN],
		["Wages", "%s cr / week" % _num(_wages()), UIStyle.GREEN],
		["Hold", "%d / %d t" % [Career.cargo_used(), Career.cargo_capacity], UIStyle.GREEN],
	]
	for row in rows:
		draw_string(Data.font_talk, Vector2(r.position.x, y), row[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, DIM)
		var vw := Data.font_talk.get_string_size(row[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		_leader(Vector2(r.position.x + Data.font_talk.get_string_size(row[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x + 8, y), r.end.x - vw - 8)
		draw_string(Data.font_talk, Vector2(r.end.x - vw, y), row[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, row[2])
		y += 34.0
	y = _head(r, y + 10, "IN THE HOLD")
	var any := false
	for src in [[Career.cargo, ""], [Career.job_cargo, "  (job)"]]:
		for g in src[0]:
			var nm := "%s%s" % [Data.goods[g]["name"], src[1]]
			var v := "%d t" % src[0][g]
			draw_string(Data.font_talk, Vector2(r.position.x, y), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, WHITE)
			var vw2 := Data.font_talk.get_string_size(v, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
			_leader(Vector2(r.position.x + Data.font_talk.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 8, y), r.end.x - vw2 - 8)
			draw_string(Data.font_talk, Vector2(r.end.x - vw2, y), v, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, UIStyle.GREEN)
			y += 30.0
			any = true
	if not any:
		_pen(Data.font_hand, Vector2(r.position.x, y + 4), "empty. that's money sitting still.", 26, 1.0, -1)
		y += 24.0
	# The next payment, boxed in dim neon.
	if Career.loan_balance > 0:
		var due_in := maxf(0.0, Career.next_payment_day - Career.day)
		var cp := Rect2(Vector2(r.position.x, r.end.y - 96), Vector2(r.size.x, 86))
		_dashed_rect(cp, Color(OFF, 0.9))
		draw_string(Data.font_talk, cp.position + Vector2(16, 28), "NEXT REMITTANCE", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, DIM)
		draw_string(Data.font_talk, cp.position + Vector2(16, 62), "%s CR" % _num(Data.LOAN_WEEKLY), HORIZONTAL_ALIGNMENT_LEFT, -1, 30, RED)
		var dd := "DUE IN %.1f DAYS" % due_in
		var dw := Data.font_talk.get_string_size(dd, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
		draw_string(Data.font_talk, Vector2(cp.end.x - dw - 16, cp.position.y + 62), dd, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, WHITE)


func _wages() -> int:
	var w := 0
	for id in Career.crew:
		w += int(Data.captains[id]["wage"])
	return w


## A red neon stamp that buzzes on.
func _stamp(at: Vector2, text: String) -> void:
	var st := _flip - 0.3
	if st < 0.0:
		return
	var sa: float = 1.0 if st > 0.15 else [1.0, 0.2, 1.0][int(st / 0.05) % 3]
	draw_set_transform(at, deg_to_rad(-6.0), Vector2.ONE)
	var w := Data.font_stamp.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 34).x
	var sr := Rect2(Vector2(-w * 0.5 - 12, -34), Vector2(w + 24, 46))
	draw_rect(sr.grow(4), Color(RED, 0.15 * sa), false, 6.0)
	draw_rect(sr, Color(RED, 0.9 * sa), false, 2.0)
	draw_string(Data.font_stamp, Vector2(-w * 0.5, 2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color(RED, 0.9 * sa))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Visited: a green neon ring, like a port's visa lit up.
func _round_stamp(c: Vector2, ring: String, mid: String, _sd: int, k := 1.0) -> void:
	var col := Color(UIStyle.GREEN, 0.85 * _flick(3))
	draw_arc(c, 44.0 * k, 0, TAU, 48, Color(col, col.a * 0.2), 6.0, true)
	draw_arc(c, 44.0 * k, 0, TAU, 48, col, 1.6, true)
	var w := Data.font_talk.get_string_size(mid, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	draw_string(Data.font_talk, c + Vector2(-w * 0.5, 4), mid, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, col)
	var w2 := Data.font_talk.get_string_size(ring, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	draw_string(Data.font_talk, c + Vector2(-w2 * 0.5, 22), ring, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(col, col.a * 0.7))


func _ring_text(c: Vector2, rad: float, text: String, sz: int, col: Color, start: float) -> void:
	var f: Font = Data.font_talk
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
	var ink := Color(WHITE, 0.85)
	draw_arc(c, 34.0, 0, TAU, 48, ink, 2.0, true)
	draw_arc(c, 29.0, 0, TAU, 48, Color(ink, 0.5), 1.0, true)
	match id:
		"charter":
			var w := Data.font_stamp.get_string_size("CC", HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
			draw_string(Data.font_stamp, c + Vector2(-w * 0.5, 9), "CC", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, RED)
		"federation":
			for i in 3:
				var y := c.y - 10 + i * 9
				draw_polyline(PackedVector2Array([Vector2(c.x - 15, y), Vector2(c.x, y + 8), Vector2(c.x + 15, y)]), PINK, 3.0, true)
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
			draw_string(Data.font_talk, c + Vector2(-5, 7), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 31, ink)


## A printed scale from HOSTILE to TRUSTED with your pen mark on it.
func _standing_scale(r: Rect2, v: float) -> void:
	var ink := WHITE
	var y := r.position.y + 20.0
	var labels := ["HOSTILE", "WARY", "NEUTRAL", "FRIENDLY", "TRUSTED"]
	draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color(ink, 0.7), 1.5)
	for i in 5:
		var x := r.position.x + r.size.x * i / 4.0
		draw_line(Vector2(x, y - 6), Vector2(x, y + 6), Color(ink, 0.7), 1.5)
		var w := Data.font_talk.get_string_size(labels[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		var lx := clampf(x - w * 0.5, r.position.x, r.end.x - w)
		draw_string(Data.font_talk, Vector2(lx, y + 22), labels[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, DIM)
	for i in 21:
		var x2 := r.position.x + r.size.x * i / 20.0
		draw_line(Vector2(x2, y - 3), Vector2(x2, y), Color(ink, 0.4), 1.0)
	if v < 0.0:
		_pen(Data.font_hand, Vector2(r.position.x + r.size.x * 0.5 - 50, y - 12), "no idea yet", 26, 1.0, -1)
		return
	# Your mark: a pen chevron and a little X on the line.
	var mx := r.position.x + r.size.x * v
	draw_line(Vector2(mx - 6, y - 6), Vector2(mx + 6, y + 6), PINK, 2.4, true)
	draw_line(Vector2(mx - 6, y + 6), Vector2(mx + 6, y - 6), PINK, 2.4, true)
	draw_polyline(PackedVector2Array([Vector2(mx - 7, y - 24), Vector2(mx, y - 13), Vector2(mx + 7, y - 24)]), PINK, 2.0, true)
	_pen(Data.font_hand, Vector2(mx - 12, y - 28), "me", 24, 1.0, -1)


## A snapshot of the station taped into the log, or an empty frame if you
## haven't been.
func _station_photo(c: Vector2, st_id: String, known: bool) -> void:
	var st: Dictionary = Data.stations[st_id]
	var ph := Vector2(212, 148)
	var a := _flick(3)
	var img := Rect2(c - ph * 0.5, ph)
	draw_rect(img, Color(0.02, 0.025, 0.05))
	if known:
		var rng := RandomNumberGenerator.new()
		rng.seed = st_id.hash()
		for i in 40:
			var p := img.position + Vector2(rng.randf() * ph.x, rng.randf() * ph.y)
			draw_rect(Rect2(p, Vector2(1, 1)), Color(1, 1, 1, rng.randf_range(0.2, 0.8)))
		var art := str(st.get("art", ""))
		draw_set_transform(c, 0.0, Vector2.ONE)
		if art == "" or not Art.draw_fit(self, "stations/%s/00.png" % art, ph.y * 0.92, Color(0.95, 0.9, 0.8)):
			draw_arc(Vector2.ZERO, 40.0, 0, TAU, 32, Color(0.8, 0.8, 0.8), 3.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		var nw := Data.font_talk.get_string_size("NO PHOTO", HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		draw_string(Data.font_talk, c + Vector2(-nw * 0.5, 6), "NO PHOTO", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(OFF, a))
	draw_rect(img.grow(8), Color(UIStyle.GOLD, 0.18 * a), false, 4.0)
	draw_rect(img.grow(8), Color(UIStyle.GOLD, 0.7 * a), false, 1.0)
	var cap := str(st["nick"])
	var cw := Data.font_hand.get_string_size(cap, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
	_pen(Data.font_hand, Vector2(c.x - cw * 0.5, img.end.y + 40), cap, 28, a)


## A wire paperclip holding a photo to the page.
func _paperclip(_at: Vector2) -> void:
	pass


func _arc_into(pts: PackedVector2Array, c: Vector2, r: float, a0: float, a1: float) -> void:
	for i in 9:
		var a := lerpf(a0, a1, i / 8.0)
		pts.append(c + Vector2(cos(a), sin(a)) * r)


## A highlighter stroke behind a line of type.
func _highlighter(_at: Vector2, _w: float, _sd: int) -> void:
	pass


func _pen_underline(at: Vector2, w: float, _sd: int) -> void:
	draw_line(at, at + Vector2(w, 0), Color(PINK, 0.7), 2.0)


## Dotted leader from a label to its figure.
func _leader(from: Vector2, to_x: float) -> void:
	var x := from.x + 4.0
	while x < to_x:
		draw_rect(Rect2(Vector2(x, from.y - 4), Vector2(2, 2)), Color(OFF, 0.8))
		x += 8.0


func _dashed_rect(r: Rect2, col: Color) -> void:
	for side in [[r.position, Vector2(r.end.x, r.position.y)], [Vector2(r.end.x, r.position.y), r.end], [r.end, Vector2(r.position.x, r.end.y)], [Vector2(r.position.x, r.end.y), r.position]]:
		var a: Vector2 = side[0]
		var d: Vector2 = side[1] - a
		var n := maxi(2, int(d.length() / 7.0))
		for i in n:
			if i % 2 == 0:
				draw_line(a + d * (float(i) / n), a + d * (float(i + 1) / n), col, 1.0)


func _num(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out
