extends Control
## The docked screen, in neon (docs/design/ui-look.md). Time is paused while
## it's open, like landing in Endless Sky. The station hangs on the left; one
## page on the dark fade to the right: market, ledger, jobs, the Charter
## account and the station's notices. Comms play under the station.
## Up/down picks, left/right sells/buys (Shift 10, Ctrl all), Enter opens,
## F undocks. The mouse does the same: hover picks, click buys, right click sells.

const Neon = preload("res://scripts/neon.gd")
const NeonNotice = preload("res://scripts/neon_notice.gd")

const WHITE := Color(0.9, 0.9, 0.94)
const DIM := Color(0.47, 0.49, 0.56)
const OFF := Color(0.3, 0.31, 0.37)
const BODY := Color(0.63, 0.65, 0.71)
const RED := Color(1.0, 0.3, 0.33)
const BG := Color(0.016, 0.02, 0.047)
const ROW := 30          ## market row text size
const ROW_H := 36.0
const SMALL := 20
const SEC := 18          ## section label size
const HINT := 24

var main: Node
var station_id := ""

## Everything you can land on, in order: {"kind", "rect", ...}.
## kind "good": {"good"}; kind "act": {"text", "cb", "on"}.
var _items: Array = []
var _sel := 0
var _age := 0.0
var _hint_rects: Array = []
var _sub_rects: Array = []     ## [Rect2, dir] for SELL / BUY on the picked good
var _log: Array = []
var _comms_text: RichTextLabel
var _notice: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_comms_text = RichTextLabel.new()
	_comms_text.bbcode_enabled = true
	_comms_text.fit_content = true
	_comms_text.scroll_active = false
	_comms_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_comms_text.add_theme_font_size_override("normal_font_size", 24)
	if Data.font_talk:
		_comms_text.add_theme_font_override("normal_font", Data.font_talk)
	_comms_text.add_theme_color_override("default_color", Data.TALK_BODY)
	_comms_text.meta_underlined = false
	# Highlighted words open their journal page.
	_comms_text.meta_clicked.connect(func(m):
		var bits := str(m).split("|")
		if bits.size() == 2:
			main.journal.open_to(bits[0], bits[1]))
	add_child(_comms_text)
	Career.changed.connect(_refresh)
	Career.comms.connect(_on_comms)
	resized.connect(_refresh)
	visible = false


func open(id: String) -> void:
	_close_notice()
	station_id = id
	_log.clear()
	_comms_text.text = ""
	_comms_text.visible = false
	_sel = 0
	_age = 0.0
	visible = true
	Sfx.play("neon", -12.0)
	_refresh()


func _process(delta: float) -> void:
	if not visible:
		return
	_age += delta
	if _comms_text.visible:
		_place_comms()   # the line's height settles a frame after it's set
	queue_redraw()   # flicker on, the station turning, the pick's glow


# --- Layout ------------------------------------------------------------------------

func _x0() -> float:
	return roundf(size.x * 0.4375)


func _refresh() -> void:
	if not visible or station_id == "":
		return
	var keep: Dictionary = _items[_sel] if _sel < _items.size() else {}
	_items.clear()
	var x0 := _x0()
	var y := _market_top()
	for g in Data.goods_order:
		_items.append({"kind": "good", "good": g, "rect": Rect2(x0 - 30, y - ROW_H * 0.5, size.x - x0 - 30, ROW_H)})
		y += ROW_H
	# Actions on the right column: the Charter account, then notices.
	var ax := x0 + _col2()
	var ay := _lower_top() + _jobs_h()
	if _charter_open():
		ay += 34.0
		if Career.arrears > 0:
			ay += 30.0
		var ax2 := ax
		for a in _charter_acts():
			var w: float = Data.font_talk.get_string_size(a[0], HORIZONTAL_ALIGNMENT_LEFT, -1, ROW).x
			_items.append({"kind": "act", "text": a[0], "cb": a[1], "on": a[2], "rect": Rect2(ax2 - 4, ay - 22, w + 8, 32)})
			ax2 += w + 34.0
		ay += 40.0
	var ns := _notices()
	if not ns.is_empty():
		ay += 34.0
		for n in ns:
			_items.append({"kind": "act", "text": n["row"], "cb": _open_notice.bind(n), "on": true, "tint": n.get("tint", WHITE),
				"rect": Rect2(ax - 30, ay - 22, size.x - ax - 30, 32)})
			ay += 32.0
	# Keep the pick on the same thing if it's still here.
	_sel = 0
	for i in _items.size():
		var it: Dictionary = _items[i]
		if not keep.is_empty() and it["kind"] == keep["kind"] and it.get("good", "") == keep.get("good", "") and it.get("text", "") == keep.get("text", ""):
			_sel = i
	_place_comms()
	queue_redraw()


func _market_top() -> float:
	return 262.0


func _lower_top() -> float:
	return _market_top() + Data.goods_order.size() * ROW_H + 34.0


func _col2() -> float:
	return 440.0


func _jobs_h() -> float:
	return 34.0 + maxf(1, Career.jobs.size()) * 80.0 - (50.0 if Career.jobs.is_empty() else 0.0)


func _charter_open() -> bool:
	return station_id == "counter" and Career.loan_balance > 0


func _charter_acts() -> Array:
	var out := []
	if Career.arrears > 0:
		out.append(["PAY OVERDUE", func(): Career.pay_extra(Career.arrears), Career.credits >= Career.arrears])
	out.append(["PAY 1,000 EXTRA", func(): Career.pay_extra(1000), Career.credits > 0])
	out.append(["PAY IN FULL", func(): Career.pay_extra(Career.loan_balance), Career.credits >= Career.loan_balance])
	return out


## The station's notices: each a row that opens as a neon file.
## {"row", "issuer", "form", "body", "pen" (pink), "sign", "verb", "cb", "done"}
func _notices() -> Array:
	var out := []
	var side: String = Career.flags.get("side", "")
	if station_id == "four" and Career.flags.get("franz_met", false) and not Career.flags.get("bounty_paid", false):
		var b: Dictionary = Data.bounty
		var state := ""
		if Career.flags.get("bounty_killed", false):
			state = "DONE, COLLECT HERE"
		elif Career.flags.get("bounty_taken", false):
			state = "TAKEN"
		out.append({"row": b["title"], "issuer": "NAVY NOTICE", "form": "MARCELLUS PATROL", "body": b["text"], "sign": b["sign"],
			"verb": "TAKE IT", "done": state, "cb": func():
				Sfx.play("tick")
				Career.take_bounty()})
	if station_id == "four" and Career.flags.get("franz_pitch", false) and side == "" and not Career.flags.get("tally_job", false):
		out.append({"row": "NAVY COMMISSION", "issuer": "NAVY COMMISSION", "form": "MARCELLUS PATROL", "body": Data.forks["navy_offer"],
			"sign": "Lt. F. Kessler", "verb": "SIGN IT", "cb": func():
				Sfx.play("stamp")
				Career.sign_navy()})
	if station_id == "ambers" and Career.flags.get("tally_offered", false) and side == "" and not Career.flags.get("tally_job", false):
		out.append({"row": "ONE RIG", "issuer": "ONE RIG", "form": "", "body": Data.forks["tally_offer"],
			"sign": "IIII IIII IIII II", "verb": "I'M IN", "tint": Neon.color("tally"), "cb": func():
				Sfx.play("stamp")
				Career.take_tally_job()})
	var shady := Career.shady_offer(station_id)
	if not shady.is_empty():
		Career.flags["shady_seen"] = true
		out.append({"row": Data.shady["title"], "issuer": Data.shady["title"], "form": "",
			"pen": Data.shady["text"] % [Data.stations[shady["to"]]["nick"], Career.fmt(shady["pay"])],
			"sign": "- " + Data.shady["sign"], "verb": "TAKE THE CRATES", "cb": func():
				Sfx.play("tick")
				Career.take_shady(shady)})
	if station_id == "saltgate":
		for id in Data.captain_order:
			var c: Dictionary = Data.captains[id]
			var hired: bool = Career.crew.has(id)
			out.append({"row": "%s   %s CR/WK%s" % [c["name"], Career.fmt(c["wage"]), "   HIRED" if hired else ""],
				"issuer": "SALTGATE BAR", "form": "BY THE DOOR", "pen": "%s %s cr/week" % [c["note"], Career.fmt(c["wage"])],
				"body": c["pitch"], "sign": c["full"], "portrait": c.get("name", id), "verb": "HIRE",
				"done": "HIRED" if hired else ("" if Career.credits >= c["wage"] else "SHORT OF CREDITS"), "cb": func():
					Sfx.play("stamp", -6.0)
					Career.hire(id)})
	return out


## The last line said, under the station, growing up from the bottom.
## (The journal's Radio keeps the rest.)
func _place_comms() -> void:
	var w := _x0() - 120.0 - 170.0
	_comms_text.custom_minimum_size.x = w
	_comms_text.size = Vector2(w, 0)
	_comms_text.reset_size()
	_comms_text.position = Vector2(170, size.y - 48.0 - _comms_text.get_content_height())


# --- Input -------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not visible or is_instance_valid(_notice):
		return
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		main.undock()
		return
	if not (event is InputEventKey and event.pressed):
		return
	var n := 10 if event.shift_pressed else (9999 if event.ctrl_pressed else 1)
	match event.keycode:
		KEY_UP, KEY_W:
			_pick(posmod(_sel - 1, _items.size()))
		KEY_DOWN, KEY_S:
			_pick(posmod(_sel + 1, _items.size()))
		KEY_LEFT, KEY_A:
			_trade(-1, n)
		KEY_RIGHT, KEY_D:
			_trade(1, n)
		KEY_ENTER, KEY_KP_ENTER:
			if event.echo:
				return
			_act()
		_:
			return
	get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var i := _item_at(event.position)
		if i >= 0 and i != _sel:
			_pick(i)
	elif event is InputEventMouseButton and event.pressed:
		var n := 10 if event.shift_pressed else (9999 if event.ctrl_pressed else 1)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_pick(posmod(_sel + 1, _items.size()))
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_pick(posmod(_sel - 1, _items.size()))
		elif event.button_index == MOUSE_BUTTON_LEFT:
			for h in _hint_rects:
				if h[0].has_point(event.position):
					h[1].call()
					accept_event()
					return
			for s in _sub_rects:
				if s[0].has_point(event.position):
					_trade(s[1], n)
					accept_event()
					return
			var i := _item_at(event.position)
			if i >= 0:
				_sel = i
				if _items[i]["kind"] == "good":
					_trade(1, n)
				else:
					_act()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			var i := _item_at(event.position)
			if i >= 0 and _items[i]["kind"] == "good":
				_sel = i
				_trade(-1, n)
		accept_event()


func _item_at(p: Vector2) -> int:
	for i in _items.size():
		if _items[i]["rect"].has_point(p):
			return i
	return -1


func _pick(i: int) -> void:
	if i == _sel or _items.is_empty():
		return
	_sel = i
	Sfx.play("tick", -16.0, 1.4)
	queue_redraw()


## Left sells, right buys, on the picked good.
func _trade(dir: int, n: int) -> void:
	if _items.is_empty() or _items[_sel]["kind"] != "good":
		return
	var g: String = _items[_sel]["good"]
	var done := Career.buy(station_id, g, n) if dir > 0 else Career.sell(station_id, g, n)
	if done > 0:
		Sfx.play("tick", -8.0, 1.0 + 0.1 * dir)


func _act() -> void:
	if _items.is_empty() or _items[_sel]["kind"] != "act" or not _items[_sel]["on"]:
		return
	Sfx.play("tick", -6.0)
	_items[_sel]["cb"].call()


func _open_notice(n: Dictionary) -> void:
	_notice = NeonNotice.new()
	_notice.notice = n
	_notice.back.connect(_close_notice)
	_notice.chosen.connect(func(_i):
		n["cb"].call()
		_close_notice())
	add_child(_notice)


func _close_notice() -> void:
	if is_instance_valid(_notice):
		_notice.queue_free()
	_notice = null
	_age = 1.0
	_refresh()


func _on_comms(speaker: String, text: String) -> void:
	_log = [[speaker, text]]
	_comms_text.text = Neon.bbcode(text)
	_comms_text.visible = true
	_place_comms()
	queue_redraw()


# --- Drawing -----------------------------------------------------------------------

## Flicker on: each part stutters in, one after the other.
func _flick(i: int) -> float:
	var t := _age - 0.04 * mini(i, 10)
	if t <= 0.0:
		return 0.0
	if t > 0.22:
		return 1.0
	return [1.0, 0.15, 0.8, 0.0, 1.0, 0.4][int(t / 0.04) % 6]


func _t(pos: Vector2, s: String, sz: int, col: Color, glow := false, right := false) -> float:
	var f: Font = Data.font_talk
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
	if right:
		pos.x -= w
	if glow:
		for o in [Vector2(-2, 0), Vector2(2, 0), Vector2(0, -2), Vector2(0, 2), Vector2(-3, -3), Vector2(3, 3)]:
			draw_string(f, pos + o, s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color(col, 0.13 * col.a))
	draw_string(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)
	return w


## Small tracked caps: section labels and the header.
func _tracked(pos: Vector2, s: String, sz: int, col: Color, gap: float, font: Font = null) -> float:
	var f: Font = font if font else Data.font_talk
	var x := pos.x
	for ch in s:
		draw_string(f, Vector2(x, pos.y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)
		x += f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x + gap
	return x - pos.x


func _draw() -> void:
	if station_id == "":
		return
	var st: Dictionary = Data.stations[station_id]
	var x0 := _x0()
	# The dark, a few stars, the station turning slowly on the left.
	draw_rect(Rect2(Vector2.ZERO, size), BG)
	var rng := RandomNumberGenerator.new()
	rng.seed = station_id.hash()
	for i in 90:
		var p := Vector2(rng.randf() * x0, rng.randf() * size.y)
		draw_rect(Rect2(p, Vector2(2, 2)), Color(1, 0.95, 0.85, rng.randf_range(0.1, 0.5)))
	var art := str(st.get("art", ""))
	if art != "":
		var frames := Art.frames("stations/" + art)
		var tex: Texture2D = frames[int(_age * 6.0) % frames.size()] if not frames.is_empty() else null
		draw_set_transform(Vector2(x0 * 0.47, size.y * 0.44), 0.0, Vector2.ONE)
		Art.draw_fit(self, "stations/%s/00.png" % art, minf(x0 * 0.72, size.y * 0.5), Color(1, 1, 1, 0.92), tex)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var fade_from := x0 - 300.0
	for k in 30:
		var x := fade_from + 300.0 * k / 30.0
		draw_rect(Rect2(x, 0, 300.0 / 30.0 + 1.0, size.y), Color(BG, 0.9 * float(k) / 30.0))
	draw_rect(Rect2(x0, 0, size.x - x0, size.y), Color(BG, 0.9))
	for y in range(0, int(size.y), 3):
		draw_line(Vector2(x0 - 120.0, y), Vector2(size.x, y), Color(0, 0, 0, 0.22), 1.0)

	var a := _flick(0)
	var rx := size.x - 60.0
	# Header: the station's name, tracked white; the place and the day, dim.
	_tracked(Vector2(x0, 92), str(st["nick"]).to_upper(), 34, Color(1, 1, 1, a), 9.0, Data.font_bold)
	var meta := "%s     DAY %d     WK %d" % [str(st["name"]).to_upper(), int(Career.day) + 1, Career.week()]
	var mw := 0.0
	for ch in meta:
		mw += Data.font_talk.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x + 3.0
	_tracked(Vector2(rx - mw, 88), meta, 22, Color(DIM, a), 3.0)
	draw_multiline_string(Data.font_talk, Vector2(x0, 128), str(st["desc"]), HORIZONTAL_ALIGNMENT_LEFT, rx - x0 - 60.0, 22, 2, Color(BODY, a * 0.85))

	_draw_market(x0, rx)
	_draw_lower(x0, rx)
	_draw_comms()
	if not is_instance_valid(_notice):
		_draw_hints(x0)


func _draw_market(x0: float, rx: float) -> void:
	var a := _flick(1)
	var top := _market_top()
	_tracked(Vector2(x0, top - 58), "MARKET", SEC, Color(DIM, a), 7.0)
	var trader: bool = Career.friend_with_you() and Career.friend["role"] == "trader"
	var c_price := x0 + 300.0
	var c_hold := x0 + 420.0
	var c_tag := x0 + 450.0
	var c_trade := x0 + 610.0
	_tracked(Vector2(x0 + 22, top - 26), "GOOD", 18, Color(OFF, a), 4.0)
	var ph := "BUY / SELL" if trader else "PRICE"
	_t(Vector2(c_price, top - 26), ph, 18, Color(OFF, a), false, true)
	_t(Vector2(c_hold, top - 26), "HOLD", 18, Color(OFF, a), false, true)
	var st: Dictionary = Data.stations[station_id]
	_sub_rects.clear()
	for i in Data.goods_order.size():
		var g: String = Data.goods_order[i]
		var ra := _flick(2 + i)
		var y := top + i * ROW_H + ROW * 0.3
		var on := _sel == i
		var col := UIStyle.GOLD if on else WHITE
		if on:
			_t(Vector2(x0 - 4, y), ">", ROW, Color(col, ra), true)
		var nw := _t(Vector2(x0 + 22, y), str(Data.goods[g]["name"]).to_upper(), ROW, Color(col, ra), on)
		if on:
			_t(Vector2(x0 + 34 + nw, y - 2), "\"%s\"" % Data.goods[g]["slang"], SMALL, Color(UIStyle.GOLD.darkened(0.35), ra))
		var bp := Career.buy_price(station_id, g)
		var sp := Career.sell_price(station_id, g)
		var ptxt := Career.fmt(bp) if bp == sp else "%s / %s" % [Career.fmt(bp), Career.fmt(sp)]
		_t(Vector2(c_price, y), ptxt, ROW, Color(UIStyle.GOLD if on else UIStyle.GREEN, ra), on, true)
		var owned: int = Career.cargo.get(g, 0)
		var job: int = Career.job_cargo.get(g, 0)
		var htxt := (str(owned) if owned > 0 else "-") + (" +%d JOB" % job if job > 0 else "")
		_t(Vector2(c_hold, y), htxt, ROW, Color(UIStyle.GREEN if owned + job > 0 else OFF, ra), false, true)
		if g in st["makes"]:
			_tracked(Vector2(c_tag, y - 3), "MADE HERE", SMALL, Color(UIStyle.GREEN, ra), 2.0)
		elif g in st["wants"]:
			_tracked(Vector2(c_tag, y - 3), "NEEDED", SMALL, Color(UIStyle.GOLD, ra), 2.0)
		if on:
			var can_sell := owned > 0
			var can_buy := Career.cargo_free() > 0 and Career.credits >= bp
			var sw := _t(Vector2(c_trade, y), "< SELL", ROW - 4, Color(UIStyle.GOLD if can_sell else OFF, ra), can_sell)
			_sub_rects.append([Rect2(c_trade - 6, y - 24, sw + 12, 32), -1])
			var bx := c_trade + sw + 36.0
			var bw := _t(Vector2(bx, y), "BUY >", ROW - 4, Color(UIStyle.GOLD if can_buy else OFF, ra), can_buy)
			_sub_rects.append([Rect2(bx - 6, y - 24, bw + 12, 32), 1])


func _draw_lower(x0: float, rx: float) -> void:
	var a := _flick(11)
	var top := _lower_top()
	# Ledger, left.
	_tracked(Vector2(x0, top), "LEDGER", SEC, Color(DIM, a), 7.0)
	var rows := [["CREDITS", Career.fmt(Career.credits), UIStyle.GREEN],
		["HOLD", "%d / %d T" % [Career.cargo_used(), Career.cargo_capacity], UIStyle.GREEN]]
	if Career.loan_balance > 0:
		rows.append(["LOAN", Career.fmt(Career.loan_balance), RED])
		var days_left := int(Career.next_payment_day) - int(Career.day)
		rows.append(["DUE DAY %d" % (int(Career.next_payment_day) + 1), Career.fmt(mini(Data.LOAN_WEEKLY, Career.loan_balance)), RED if days_left <= 1 else UIStyle.GREEN])
		if Career.arrears > 0:
			rows.append(["OVERDUE", Career.fmt(Career.arrears), RED])
	else:
		rows.append(["LOAN", "PAID", UIStyle.GREEN])
	if Career.friend_with_you():
		var role: Dictionary = Data.friend_roles[Career.friend["role"]]
		rows.append(["WITH ME", "%s, %s" % [Career.friend["name"], role["name"]], WHITE])
	var y := top + 34.0
	for r in rows:
		_t(Vector2(x0, y), str(r[0]).to_upper(), 28, Color(DIM, a))
		_t(Vector2(x0 + 200, y), str(r[1]).to_upper(), 28, Color(r[2], a))
		y += 32.0

	# Jobs, then the Charter account and notices, right.
	var cx := x0 + _col2()
	_tracked(Vector2(cx, top), "JOBS", SEC, Color(DIM, a), 7.0)
	y = top + 34.0
	if Career.jobs.is_empty():
		_t(Vector2(cx, y), "NOTHING PINNED", 28, Color(OFF, a))
		y += 30.0
	for j in Career.jobs:
		var where := "PICK UP AT %s" % Data.stations[j["from"]]["nick"] if not j["loaded"] else "DELIVER TO %s" % Data.stations[j["to"]]["nick"]
		_t(Vector2(cx, y), str(j["title"]).split(":")[0].to_upper(), 28, Color(WHITE, a))
		_t(Vector2(cx, y + 26), ("%d T %s, %s" % [j["tons"], Data.goods[j["good"]]["name"], where]).to_upper(), 24, Color(BODY, a))
		var pw := _t(Vector2(cx, y + 50), "PAYS ", 24, Color(DIM, a))
		_t(Vector2(cx + pw, y + 50), Career.fmt(j["pay"]), 24, Color(UIStyle.GREEN, a))
		y += 80.0
	y = top + _jobs_h()
	if _charter_open():
		_tracked(Vector2(cx, y), "CHARTER ACCOUNT  CC-40817-M", SEC, Color(DIM, a), 7.0)
		y += 34.0
		if Career.arrears > 0:
			var strike := "OVERDUE %s, STRIKE %d OF 2" % [Career.fmt(Career.arrears), Career.strikes]
			_t(Vector2(cx, y), strike, 24, Color(RED, a))
			y += 30.0
		y += 40.0
	if not _notices().is_empty():
		_tracked(Vector2(cx, y), "NOTICES", SEC, Color(DIM, a), 7.0)
	# The picked or idle actions (Charter verbs, notice rows).
	for i in _items.size():
		var it: Dictionary = _items[i]
		if it["kind"] != "act":
			continue
		var on := i == _sel
		var r: Rect2 = it["rect"]
		var p := Vector2(r.position.x + 4, r.position.y + 22)
		var col: Color = OFF if not it["on"] else (UIStyle.GOLD if on else it.get("tint", WHITE))
		if it.has("tint"):
			p.x += 30.0
			if on:
				_t(Vector2(p.x - 26, p.y), ">", 28, Color(col, a), true)
		_t(p, str(it["text"]).to_upper(), 28, Color(col, a), on and it["on"])
		if on and not it.has("tint"):
			draw_line(Vector2(r.position.x + 4, r.end.y), Vector2(r.end.x - 4, r.end.y), Color(UIStyle.GOLD, a * 0.8), 2.0)


func _draw_comms() -> void:
	if _log.is_empty():
		return
	var who := str(_log[-1][0])
	var top := _comms_text.position.y
	var r := Rect2(Vector2(70, top - 26), Vector2(80, 96))
	UIStyle.draw_id_photo(self, r, Data.portrait_for(who), "", who.hash(), who)
	draw_rect(r.grow(6), Color(UIStyle.GOLD, 0.15), false, 4.0)
	draw_rect(r.grow(6), Color(UIStyle.GOLD, 0.6), false, 1.0)
	_tracked(Vector2(170, top - 10), who.to_upper(), 22, UIStyle.GOLD, 4.0)


func _draw_hints(x0: float) -> void:
	_hint_rects.clear()
	var a := _flick(12)
	var hs := [["UP DOWN", "PICK", Callable()], ["LEFT RIGHT", "SELL BUY", Callable()], ["SHIFT", "X10", Callable()],
		["CTRL", "ALL", Callable()], ["F", "UNDOCK", func(): main.undock()]]
	var hx := x0
	var hy := size.y - 44.0
	var f: Font = Data.font_talk
	for h in hs:
		var kw := f.get_string_size(h[0] + "  ", HORIZONTAL_ALIGNMENT_LEFT, -1, HINT).x
		var vw := f.get_string_size(h[1], HORIZONTAL_ALIGNMENT_LEFT, -1, HINT).x
		draw_string(f, Vector2(hx, hy), h[0], HORIZONTAL_ALIGNMENT_LEFT, -1, HINT, Color(UIStyle.GOLD, a))
		draw_string(f, Vector2(hx + kw, hy), h[1], HORIZONTAL_ALIGNMENT_LEFT, -1, HINT, Color(DIM, a))
		if h[2].is_valid():
			_hint_rects.append([Rect2(hx - 6, hy - 22, kw + vw + 12, 30), h[2]])
		hx += kw + vw + 46.0
