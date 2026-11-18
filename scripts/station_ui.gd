extends Control
## The docked screen. Time is paused while it's open, like landing in Endless Sky.
## Market for every good, the job board, Charlie's dispatch desk at the Counter,
## and the last comms message.

var main: Node
var station_id := ""

var _title: Label
var _sub: Label
var _desc: Label
var _market: GridContainer
var _status: Label
var _jobs: Label
var _dispatch: VBoxContainer
var _comms_name: Label
var _comms_text: Label

const COL_MAKES := Color(0.55, 0.95, 0.6)
const COL_WANTS := Color(1.0, 0.75, 0.4)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.01, 0.03, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1180, 700)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.07, 0.11, 0.97)
	sb.border_color = Color(0.35, 0.6, 0.8, 0.8)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(22)
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	panel.add_child(root)
	_title = _label(root, "", 30, Color(0.9, 0.95, 1.0))
	_sub = _label(root, "", 15, Color(0.6, 0.75, 0.9))
	_desc = _label(root, "", 15, Color(0.78, 0.82, 0.88))
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.custom_minimum_size.x = 1100

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 28)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)

	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 690
	body.add_child(left)
	_label(left, "MARKET", 16, Color(0.6, 0.85, 1.0))
	_market = GridContainer.new()
	_market.columns = 7
	_market.add_theme_constant_override("h_separation", 12)
	_market.add_theme_constant_override("v_separation", 6)
	left.add_child(_market)
	var legend := _label(left, "Green: made here, cheap.   Orange: needed here, pays well.", 13, Color(0.6, 0.68, 0.78))
	legend.custom_minimum_size.y = 26

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(right)
	_label(right, "CAPTAIN", 16, Color(0.6, 0.85, 1.0))
	_status = _label(right, "", 15)
	_label(right, "JOBS", 16, Color(0.6, 0.85, 1.0))
	_jobs = _label(right, "", 14)
	_jobs.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_jobs.custom_minimum_size.x = 400
	_dispatch = VBoxContainer.new()
	right.add_child(_dispatch)

	var comms := PanelContainer.new()
	var csb := StyleBoxFlat.new()
	csb.bg_color = Color(0.07, 0.11, 0.16, 1.0)
	csb.set_content_margin_all(12)
	csb.set_corner_radius_all(4)
	comms.add_theme_stylebox_override("panel", csb)
	root.add_child(comms)
	var cv := VBoxContainer.new()
	comms.add_child(cv)
	_comms_name = _label(cv, "", 14, Color(1.0, 0.85, 0.55))
	_comms_text = _label(cv, "", 15, Color(0.9, 0.92, 0.95))
	_comms_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_comms_text.custom_minimum_size.x = 1100

	var undock := Button.new()
	undock.text = "Undock  (F)"
	undock.custom_minimum_size = Vector2(200, 40)
	undock.size_flags_horizontal = Control.SIZE_SHRINK_END
	undock.pressed.connect(func(): main.undock())
	root.add_child(undock)

	Career.changed.connect(_refresh)
	Career.comms.connect(_on_comms)
	visible = false


func _label(parent: Control, text: String, sz := 15, col := Color(0.85, 0.9, 1.0)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	parent.add_child(l)
	return l


func open(id: String) -> void:
	station_id = id
	var st: Dictionary = Data.stations[id]
	var sys: Dictionary = Data.systems[st["system"]]
	_title.text = st["nick"][0].to_upper() + st["nick"].substr(1)
	_sub.text = "%s  ·  %s system (%s)  ·  %s" % [st["name"], sys["name"], sys["security"], Data.sector["name"]]
	_desc.text = st["desc"]
	_comms_name.text = ""
	_comms_text.text = ""
	visible = true
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		main.undock()


func _on_comms(speaker: String, text: String) -> void:
	_comms_name.text = speaker.to_upper()
	_comms_text.text = text


func _refresh() -> void:
	if not visible:
		return
	for c in _market.get_children():
		c.queue_free()
	for h in ["GOOD", "PRICE", "HOLD", "", "", "", ""]:
		_label(_market, h, 12, Color(0.55, 0.65, 0.75))
	var st: Dictionary = Data.stations[station_id]
	for g in Data.goods_order:
		var col := Color(0.85, 0.9, 1.0)
		var tag := ""
		if g in st["makes"]:
			col = COL_MAKES
			tag = "  made here"
		elif g in st["wants"]:
			col = COL_WANTS
			tag = "  needed"
		var name_l := _label(_market, Data.goods[g]["name"] + tag, 15, col)
		name_l.tooltip_text = "\"%s\": %s" % [Data.goods[g]["slang"], Data.goods[g]["desc"]]
		name_l.mouse_filter = Control.MOUSE_FILTER_PASS
		name_l.custom_minimum_size.x = 210
		_label(_market, "%s cr" % Career.fmt(Career.price(station_id, g)), 15, col)
		var owned: int = Career.cargo.get(g, 0)
		var job: int = Career.job_cargo.get(g, 0)
		_label(_market, str(owned) + (" (+%d job)" % job if job > 0 else ""), 15)
		_button(_market, "Buy 1", func(): Career.buy(station_id, g, 1))
		_button(_market, "Buy 10", func(): Career.buy(station_id, g, 10))
		_button(_market, "Sell 1", func(): Career.sell(station_id, g, 1), owned > 0)
		_button(_market, "Sell all", func(): Career.sell(station_id, g, 9999), owned > 0)

	_status.text = "Credits: %s\nHold: %d / %d tons\nCharter loan: %s\nNext payment: %s on day %d  (now day %d, week %d)" % [
		Career.fmt(Career.credits), Career.cargo_used(), Career.cargo_capacity,
		Career.fmt(Career.loan_balance), Career.fmt(mini(Data.LOAN_WEEKLY, Career.loan_balance)),
		int(Career.next_payment_day) + 1, int(Career.day) + 1, Career.week()]
	if Career.loan_balance <= 0:
		_status.text = "Credits: %s\nHold: %d / %d tons\nCharter loan: PAID IN FULL\nYour papers came through." % [
			Career.fmt(Career.credits), Career.cargo_used(), Career.cargo_capacity]

	var lines := []
	for j in Career.jobs:
		var where := "pick up at %s" % Data.stations[j["from"]]["nick"] if not j["loaded"] else "deliver to %s" % Data.stations[j["to"]]["nick"]
		lines.append("• %s: %d t %s, %s. Pays %s cr." % [j["title"], j["tons"], Data.goods[j["good"]]["name"].to_lower(), where, Career.fmt(j["pay"])])
	_jobs.text = "\n".join(lines) if not lines.is_empty() else "No jobs. Buy low where a good is made, sell where it's needed."

	for c in _dispatch.get_children():
		c.queue_free()
	if station_id == "counter" and Career.loan_balance > 0:
		_label(_dispatch, "CHARTER DISPATCH", 16, Color(0.6, 0.85, 1.0))
		var row := HBoxContainer.new()
		_dispatch.add_child(row)
		_button(row, "Pay 1,000 extra", func(): Career.pay_extra(1000), Career.credits > 0)
		_button(row, "Pay off the loan", func(): Career.pay_extra(Career.loan_balance), Career.credits >= Career.loan_balance)


func _button(parent: Control, text: String, cb: Callable, enabled := true) -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = not enabled
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	parent.add_child(b)
	return b
