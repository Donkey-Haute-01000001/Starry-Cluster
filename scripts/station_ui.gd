extends Control
## The docked screen. Time is paused while it's open, like landing in Endless Sky.
## Market for every good, captain status, the job board, Charlie's dispatch desk
## at the Counter, and the comms log. Styled with UIStyle (Stellaris-like glass).

var main: Node
var station_id := ""

var _kicker: Label
var _title: Label
var _sub: Label
var _clock_k: Label
var _clock_v: Label
var _desc: Label
var _market: GridContainer
var _stats: VBoxContainer
var _hold_bar: ProgressBar
var _jobs: VBoxContainer
var _dispatch: VBoxContainer
var _comms_box: PanelContainer
var _comms_face: Control
var _comms_who: Label
var _comms_text: Label
var _log: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.01, 0.03, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1300, 780)
	panel.add_theme_stylebox_override("panel", UIStyle.panel(UIStyle.GLASS, Color(0.47, 0.78, 1.0, 0.45), 24, 28.0))
	center.add_child(panel)
	# A short glowing accent along the top edge, like Stellaris window headers.
	panel.draw.connect(func():
		panel.draw_rect(Rect2(24, -1, 150, 3), UIStyle.CYAN)
		panel.draw_rect(Rect2(24, -3, 150, 7), Color(UIStyle.CYAN.r, UIStyle.CYAN.g, UIStyle.CYAN.b, 0.2)))

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	panel.add_child(root)

	# Header: system kicker, station name, its formal name; the clock on the right.
	var head := HBoxContainer.new()
	root.add_child(head)
	var left_head := VBoxContainer.new()
	left_head.add_theme_constant_override("separation", 0)
	left_head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(left_head)
	_kicker = _label(left_head, "", 12, UIStyle.KICKER)
	_title = _label(left_head, "", 40, Color(0.92, 0.97, 1.0))
	if Data.font_bold:
		_title.add_theme_font_override("font", Data.font_bold)
	_sub = _label(left_head, "", 16, UIStyle.TEXT_DIM)
	var clock := VBoxContainer.new()
	clock.alignment = BoxContainer.ALIGNMENT_END
	head.add_child(clock)
	_clock_k = _label(clock, "", 12, UIStyle.KICKER)
	_clock_k.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_clock_v = _label(clock, "", 16, UIStyle.TEXT)
	_clock_v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	_desc = _label(root, "", 16, Color(0.71, 0.8, 0.88))
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.custom_minimum_size.x = 1200

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 18)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(cols)

	var market_card := _card(cols, "MARKET")
	market_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	market_card.size_flags_stretch_ratio = 1.9
	_market = GridContainer.new()
	_market.columns = 7
	_market.add_theme_constant_override("h_separation", 8)
	_market.add_theme_constant_override("v_separation", 10)
	market_card.get_child(0).add_child(_market)

	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 18)
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(side)
	var cap := _card(side, "CAPTAIN")
	_stats = VBoxContainer.new()
	_stats.add_theme_constant_override("separation", 4)
	cap.get_child(0).add_child(_stats)
	var jobs_card := _card(side, "JOBS")
	_jobs = VBoxContainer.new()
	_jobs.add_theme_constant_override("separation", 8)
	jobs_card.get_child(0).add_child(_jobs)
	_dispatch = VBoxContainer.new()
	_dispatch.add_theme_constant_override("separation", 8)
	side.add_child(_dispatch)

	# Comms: portrait, speaker, and the last few lines.
	_comms_box = PanelContainer.new()
	var csb := StyleBoxFlat.new()
	csb.bg_color = Color(0.03, 0.09, 0.14, 0.75)
	csb.border_color = UIStyle.GOLD
	csb.border_width_left = 3
	csb.set_content_margin_all(14)
	_comms_box.add_theme_stylebox_override("panel", csb)
	root.add_child(_comms_box)
	var crow := HBoxContainer.new()
	crow.add_theme_constant_override("separation", 16)
	_comms_box.add_child(crow)
	_comms_face = Control.new()
	_comms_face.custom_minimum_size = Vector2(60, 72)
	_comms_face.draw.connect(_draw_face)
	crow.add_child(_comms_face)
	var cv := VBoxContainer.new()
	cv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	crow.add_child(cv)
	_comms_who = _label(cv, "", 13, UIStyle.GOLD)
	_comms_text = _label(cv, "", 16, UIStyle.TEXT)
	_comms_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_comms_text.custom_minimum_size.x = 1100

	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(foot)
	var undock := Button.new()
	undock.text = "UNDOCK   F"
	undock.custom_minimum_size = Vector2(190, 44)
	undock.focus_mode = Control.FOCUS_NONE
	undock.add_theme_font_size_override("font_size", 17)
	if Data.font_bold:
		undock.add_theme_font_override("font", Data.font_bold)
	undock.pressed.connect(func(): main.undock())
	foot.add_child(undock)

	Career.changed.connect(_refresh)
	Career.comms.connect(_on_comms)
	visible = false


func _label(parent: Control, text: String, sz := 16, col := UIStyle.TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	parent.add_child(l)
	return l


## A titled card: "MARKET", "CAPTAIN"... Returns the card; its first child is the body.
func _card(parent: Control, title: String) -> PanelContainer:
	var c := PanelContainer.new()
	c.add_theme_stylebox_override("panel", UIStyle.card())
	parent.add_child(c)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	c.add_child(v)
	var t := _label(v, _spaced(title), 13, UIStyle.CYAN)
	var line := ColorRect.new()
	line.color = Color(UIStyle.CYAN.r, UIStyle.CYAN.g, UIStyle.CYAN.b, 0.25)
	line.custom_minimum_size = Vector2(0, 1)
	v.add_child(line)
	t.add_theme_constant_override("line_spacing", 0)
	return c


## Letter-spaced caps for small headings.
func _spaced(s: String) -> String:
	return " ".join(s.split(""))


func open(id: String) -> void:
	station_id = id
	var st: Dictionary = Data.stations[id]
	var sys: Dictionary = Data.systems[st["system"]]
	_kicker.text = _spaced("%s SYSTEM · %s SPACE · %s" % [sys["name"].to_upper(), sys["security"].to_upper(), Data.sector["name"].to_upper()])
	_title.text = st["nick"][0].to_upper() + st["nick"].substr(1)
	_sub.text = st["name"]
	_desc.text = st["desc"]
	_log.clear()
	_comms_who.text = ""
	_comms_text.text = ""
	_comms_box.visible = false
	visible = true
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		main.undock()


## Shows the last few lines, newest at the bottom, so back-to-back lines aren't lost.
func _on_comms(speaker: String, text: String) -> void:
	_log.append([speaker, text])
	if _log.size() > 3:
		_log.pop_front()
	var last: Array = _log[-1]
	_comms_who.text = _spaced(last[0].to_upper())
	var lines := []
	for i in _log.size() - 1:
		lines.append("%s:  %s" % [_log[i][0], _log[i][1]])
	lines.append(last[1])
	_comms_text.text = "\n\n".join(lines)
	_comms_box.visible = true
	_comms_face.queue_redraw()


func _draw_face() -> void:
	if _log.is_empty():
		return
	UIStyle.draw_id_photo(_comms_face, Rect2(Vector2(3, 3), _comms_face.size - Vector2(6, 6)), Data.portrait_for(_log[-1][0]), "", str(_log[-1][0]).hash())


func _refresh() -> void:
	if not visible:
		return
	var days_left := int(Career.next_payment_day) - int(Career.day)
	_clock_k.text = _spaced("DAY %d · WEEK %d" % [int(Career.day) + 1, Career.week()])
	_clock_v.text = "Loan paid off" if Career.loan_balance <= 0 else ("Payment due tomorrow" if days_left <= 1 else "Next payment in %d days" % days_left)

	for c in _market.get_children():
		c.queue_free()
	var trader: bool = Career.friend_with_you() and Career.friend["role"] == "trader"
	for h in ["GOOD", "PRICE" if not trader else "BUY / SELL", "HOLD", "", "", "", ""]:
		var hl := _label(_market, _spaced(h), 11, Color(0.44, 0.6, 0.71))
		if h != "GOOD":
			hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var st: Dictionary = Data.stations[station_id]
	for g in Data.goods_order:
		var col := UIStyle.TEXT
		var tag := ""
		if g in st["makes"]:
			col = UIStyle.GREEN
			tag = "MADE HERE"
		elif g in st["wants"]:
			col = UIStyle.GOLD
			tag = "NEEDED"
		# Name, tag and the dockworkers' slang underneath.
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", -1)
		cell.custom_minimum_size.x = 250
		_market.add_child(cell)
		var nrow := HBoxContainer.new()
		nrow.add_theme_constant_override("separation", 8)
		cell.add_child(nrow)
		_label(nrow, Data.goods[g]["name"], 16, col)
		if tag != "":
			var tl := _label(nrow, _spaced(tag), 10, col)
			tl.add_theme_stylebox_override("normal", UIStyle.tag(col))
			tl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_label(cell, "\"%s\"" % Data.goods[g]["slang"], 11, Color(0.44, 0.6, 0.71)).tooltip_text = Data.goods[g]["desc"]
		cell.tooltip_text = Data.goods[g]["desc"]
		cell.mouse_filter = Control.MOUSE_FILTER_PASS

		var bp := Career.buy_price(station_id, g)
		var sp := Career.sell_price(station_id, g)
		var ptxt := "%s cr" % Career.fmt(bp) if bp == sp else "%s / %s" % [Career.fmt(bp), Career.fmt(sp)]
		var pl := _label(_market, ptxt, 16, UIStyle.TEXT)
		pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		pl.custom_minimum_size.x = 90
		var owned: int = Career.cargo.get(g, 0)
		var job: int = Career.job_cargo.get(g, 0)
		var hl2 := _label(_market, str(owned) + (" +%d job" % job if job > 0 else ""), 16, UIStyle.TEXT if owned + job > 0 else UIStyle.TEXT_DIM)
		hl2.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		hl2.custom_minimum_size.x = 80
		_button(_market, "Buy 1", func(): Career.buy(station_id, g, 1))
		_button(_market, "Buy 10", func(): Career.buy(station_id, g, 10))
		_button(_market, "Sell 1", func(): Career.sell(station_id, g, 1), owned > 0)
		_button(_market, "Sell all", func(): Career.sell(station_id, g, 9999), owned > 0)

	for c in _stats.get_children():
		c.queue_free()
	_stat("Credits", Career.fmt(Career.credits))
	_stat("Hold", "%d / %d t" % [Career.cargo_used(), Career.cargo_capacity])
	_hold_bar = ProgressBar.new()
	_hold_bar.show_percentage = false
	_hold_bar.custom_minimum_size = Vector2(0, 4)
	_hold_bar.max_value = Career.cargo_capacity
	_hold_bar.value = Career.cargo_used()
	_stats.add_child(_hold_bar)
	if Career.loan_balance > 0:
		_stat("Charter loan", Career.fmt(Career.loan_balance), UIStyle.RED)
		_stat("Next payment", "%s · day %d" % [Career.fmt(mini(Data.LOAN_WEEKLY, Career.loan_balance)), int(Career.next_payment_day) + 1])
	else:
		_stat("Charter loan", "PAID IN FULL", UIStyle.GREEN)
		_stat("Writ of Passage", "Your papers came through", UIStyle.GREEN)
	if Career.friend_with_you():
		var role: Dictionary = Data.friend_roles[Career.friend["role"]]
		_stat("Flying with you", "%s, %s" % [Career.friend["name"], role["name"].to_lower()], UIStyle.GOLD)

	for c in _jobs.get_children():
		c.queue_free()
	if Career.jobs.is_empty():
		_label(_jobs, "No jobs. Buy where a good is made, sell where it's needed.", 14, UIStyle.TEXT_DIM).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for j in Career.jobs:
		var where := "pick up at %s" % Data.stations[j["from"]]["nick"] if not j["loaded"] else "deliver to %s" % Data.stations[j["to"]]["nick"]
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 0)
		_jobs.add_child(box)
		var t := _label(box, j["title"].split(":")[0], 16, Color(0.92, 0.97, 1.0))
		if Data.font_bold:
			t.add_theme_font_override("font", Data.font_bold)
		_label(box, "%d t %s, %s" % [j["tons"], Data.goods[j["good"]]["name"].to_lower(), where], 15, UIStyle.TEXT)
		_label(box, "Pays %s cr" % Career.fmt(j["pay"]), 13, UIStyle.TEXT_DIM)

	for c in _dispatch.get_children():
		c.queue_free()
	if station_id == "counter" and Career.loan_balance > 0:
		var d := _card(_dispatch, "CHARTER DISPATCH")
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		d.get_child(0).add_child(row)
		_button(row, "Pay 1,000 extra", func(): Career.pay_extra(1000), Career.credits > 0)
		_button(row, "Pay off the loan", func(): Career.pay_extra(Career.loan_balance), Career.credits >= Career.loan_balance)


func _stat(name: String, value: String, col := Color(0.92, 0.97, 1.0)) -> void:
	var row := HBoxContainer.new()
	_stats.add_child(row)
	var n := _label(row, name, 16, UIStyle.TEXT)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := _label(row, value, 16, col)
	if Data.font_bold:
		v.add_theme_font_override("font", Data.font_bold)


func _button(parent: Control, text: String, cb: Callable, enabled := true) -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = not enabled
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 13)
	b.custom_minimum_size = Vector2(0, 28)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(cb)
	parent.add_child(b)
	return b
