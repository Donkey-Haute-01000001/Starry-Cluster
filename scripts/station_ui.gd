extends Control

const Neon = preload("res://scripts/neon.gd")
## The docked screen. Time is paused while it's open, like landing in Endless Sky.
## Market for every good, captain status, the job board, Charlie's dispatch desk
## at the Counter, and the comms log. Each station is its own wall of physical
## things: a chalk price board, your ledger, pinned manifests, the Charter's
## file, the radio. Their print, our handwriting.

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
var _comms_text: RichTextLabel
var _log: Array = []
var _wall: Control

const CHALK := Color(0.9, 0.9, 0.86)
const CHALK_DIM := Color(0.62, 0.66, 0.62)
const CHALK_YELLOW := Color(0.96, 0.85, 0.45)
const CHALK_GREEN := Color(0.6, 0.9, 0.62)
const MANILA := Color(0.84, 0.74, 0.5)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_wall = Control.new()
	_wall.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_wall.draw.connect(_draw_wall)
	add_child(_wall)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := MarginContainer.new()
	panel.custom_minimum_size = Vector2(1340, 760)
	center.add_child(panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	panel.add_child(root)

	# Header: the station's sign plate, bolted to the wall; the shift clock on the right.
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 24)
	root.add_child(head)
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", _box(Color(0.07, 0.07, 0.07, 0.92), Color(0, 0, 0, 0), 0, 16))
	plate.draw.connect(func(): _bolts(plate, Rect2(Vector2.ZERO, plate.size)))
	head.add_child(plate)
	var left_head := VBoxContainer.new()
	left_head.add_theme_constant_override("separation", 0)
	plate.add_child(left_head)
	_kicker = _label(left_head, "", 12, CHALK_DIM)
	_kicker.add_theme_font_override("font", Data.font_type)
	_title = _label(left_head, "", 42, Color(0.92, 0.97, 1.0))
	if Data.font_stamp:
		_title.add_theme_font_override("font", Data.font_stamp)
	_sub = _label(left_head, "", 14, CHALK_DIM)
	_sub.add_theme_font_override("font", Data.font_type)
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_child(mid)
	# The station's blurb on a small enamel placard, so the stripe runs behind it.
	var placard := PanelContainer.new()
	placard.add_theme_stylebox_override("panel", _box(Color(0.08, 0.08, 0.08, 0.9), Color(0.3, 0.3, 0.28), 1, 10))
	placard.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	mid.add_child(placard)
	_desc = _label(placard, "", 14, Color(0.85, 0.85, 0.8))
	_desc.add_theme_font_override("font", Data.font_type)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.custom_minimum_size.x = 520
	var clock := PanelContainer.new()
	clock.add_theme_stylebox_override("panel", _box(Color(0.04, 0.05, 0.04, 0.95), Color(0.3, 0.3, 0.28), 2, 10))
	clock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(clock)
	var cv0 := VBoxContainer.new()
	cv0.add_theme_constant_override("separation", 0)
	clock.add_child(cv0)
	_clock_k = _label(cv0, "", 18, Color(1.0, 0.55, 0.25))
	_clock_k.add_theme_font_override("font", Data.font_type_bold)
	_clock_k.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_clock_v = _label(cv0, "", 13, Color(0.9, 0.6, 0.35))
	_clock_v.add_theme_font_override("font", Data.font_type)
	_clock_v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 18)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(cols)

	var market_card := _card(cols, "PRICES TODAY", "chalk")
	market_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	market_card.size_flags_stretch_ratio = 1.9
	_market = GridContainer.new()
	_market.columns = 7
	_market.add_theme_constant_override("h_separation", 8)
	_market.add_theme_constant_override("v_separation", 9)
	market_card.get_child(0).add_child(_market)

	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 18)
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(side)
	var cap := _card(side, "MY LEDGER", "ledger")
	_stats = VBoxContainer.new()
	_stats.add_theme_constant_override("separation", 4)
	cap.get_child(0).add_child(_stats)
	var jobs_card := _card(side, "JOBS", "wall")
	_jobs = VBoxContainer.new()
	_jobs.add_theme_constant_override("separation", 8)
	jobs_card.get_child(0).add_child(_jobs)
	_dispatch = VBoxContainer.new()
	_dispatch.add_theme_constant_override("separation", 8)
	side.add_child(_dispatch)

	# Comms: portrait, speaker, and the last few lines.
	_comms_box = PanelContainer.new()
	var csb := StyleBoxFlat.new()
	csb.bg_color = Color(0.06, 0.065, 0.07, 0.95)
	csb.border_color = Color(0.32, 0.33, 0.33)
	csb.set_border_width_all(2)
	csb.border_width_left = 4
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
	_comms_who.add_theme_font_override("font", Data.font_type_bold)
	_comms_text = RichTextLabel.new()
	_comms_text.bbcode_enabled = true
	_comms_text.fit_content = true
	_comms_text.scroll_active = false
	_comms_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_comms_text.custom_minimum_size.x = 1100
	_comms_text.add_theme_font_size_override("normal_font_size", 22)
	if Data.font_talk:
		_comms_text.add_theme_font_override("normal_font", Data.font_talk)
	_comms_text.add_theme_color_override("default_color", Data.TALK_BODY)
	_comms_text.meta_underlined = false
	# Highlighted words open their journal page.
	_comms_text.meta_clicked.connect(func(m):
		var bits := str(m).split("|")
		if bits.size() == 2:
			main.journal.open_to(bits[0], bits[1]))
	cv.add_child(_comms_text)

	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(foot)
	var undock := Button.new()
	undock.text = "UNDOCK  [F]"
	undock.custom_minimum_size = Vector2(220, 48)
	undock.focus_mode = Control.FOCUS_NONE
	undock.add_theme_font_size_override("font_size", 20)
	if Data.font_stamp:
		undock.add_theme_font_override("font", Data.font_stamp)
	for st in ["normal", "hover", "pressed"]:
		undock.add_theme_stylebox_override(st, _box(Color(0.1, 0.09, 0.06) if st == "normal" else Color(0.2, 0.16, 0.06), Color(0.95, 0.75, 0.15), 3, 12))
	undock.add_theme_color_override("font_color", Color(0.95, 0.75, 0.15))
	undock.add_theme_color_override("font_hover_color", Color(1, 0.88, 0.4))
	undock.draw.connect(func(): _hazard(undock, Rect2(Vector2(4, undock.size.y - 8), Vector2(undock.size.x - 8, 4))))
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


## A titled board on the wall. Kinds: chalk (price board), ledger (your own
## lined notebook, in pen), manila (the Charter's file), wall (stencil on the
## bulkhead, with things pinned under it). Returns the card; first child is the body.
func _card(parent: Control, title: String, kind := "wall") -> PanelContainer:
	var c := PanelContainer.new()
	c.set_meta("kind", kind)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	var t: Label
	match kind:
		"chalk":
			var sb := _box(Color(0.1, 0.13, 0.115), Color(0.36, 0.25, 0.15), 10, 18)
			c.add_theme_stylebox_override("panel", sb)
			c.draw.connect(func(): _chalk_dust(c))
			c.add_child(v)
			t = _label(v, title, 26, CHALK)
			t.add_theme_font_override("font", Data.font_hand)
		"ledger":
			var lb := _box(UIStyle.PAPER, UIStyle.PAPER_SHADE, 1, 12)
			lb.content_margin_left = 44
			c.add_theme_stylebox_override("panel", lb)
			c.draw.connect(func(): _ruled(c))
			c.rotation = deg_to_rad(0.5)
			c.add_child(v)
			t = _label(v, title, 13, UIStyle.INK_FADED)
			t.add_theme_font_override("font", Data.font_type_bold)
		"manila":
			c.add_theme_stylebox_override("panel", _box(MANILA, MANILA.darkened(0.2), 1, 14))
			c.rotation = deg_to_rad(-0.4)
			c.add_child(v)
			t = _label(v, title, 14, UIStyle.INK_STAMP)
			t.add_theme_font_override("font", Data.font_stamp)
		_:
			c.add_theme_stylebox_override("panel", _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 4))
			c.add_child(v)
			t = _label(v, title, 22, _stripe().lightened(0.1))
			t.add_theme_font_override("font", Data.font_stamp)
	parent.add_child(c)
	return c


func _box(bg: Color, border: Color, bw: int, margin: float) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_content_margin_all(margin)
	sb.shadow_color = Color(0, 0, 0, 0.35 if bg.a > 0.5 else 0.0)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(3, 4)
	return sb


func _wall_def() -> Dictionary:
	return Data.station_walls.get(station_id, {"wall": Color(0.2, 0.22, 0.24), "stripe": Color(0.8, 0.8, 0.8), "wear": 0.5})


func _stripe() -> Color:
	return _wall_def()["stripe"]


## The bulkhead: painted plates, seams, rivets, the station's stripe, grime.
func _draw_wall() -> void:
	var w := _wall_def()
	var sz := _wall.size
	var base: Color = w["wall"]
	var wear: float = w["wear"]
	_wall.draw_rect(Rect2(Vector2.ZERO, sz), base)
	var rng := RandomNumberGenerator.new()
	rng.seed = station_id.hash()
	var ph := 150.0
	var row := 0
	var y := -40.0
	while y < sz.y:
		var x := -rng.randf_range(0, 200)
		while x < sz.x:
			var pw := rng.randf_range(220, 380)
			var tone := rng.randf_range(-0.035, 0.035)
			_wall.draw_rect(Rect2(x + 2, y + 2, pw - 4, ph - 4), Color(base.r + tone, base.g + tone, base.b + tone))
			# Seam shadow and highlight, rivets in the corners.
			_wall.draw_rect(Rect2(x, y, pw, 2), base.darkened(0.45))
			_wall.draw_rect(Rect2(x, y, 2, ph), base.darkened(0.45))
			_wall.draw_rect(Rect2(x + 2, y + 2, pw - 4, 1), base.lightened(0.08))
			for k in [Vector2(10, 10), Vector2(pw - 12, 10), Vector2(10, ph - 12), Vector2(pw - 12, ph - 12)]:
				_wall.draw_rect(Rect2(Vector2(x, y) + k, Vector2(3, 3)), base.darkened(0.35))
				_wall.draw_rect(Rect2(Vector2(x, y) + k, Vector2(2, 2)), base.lightened(0.12))
			# Stains and scuffs, more on worn stations.
			if rng.randf() < wear * 0.6:
				var sp := Vector2(x + rng.randf_range(10, pw - 40), y + rng.randf_range(10, ph - 20))
				for d in 6:
					_wall.draw_rect(Rect2(sp + Vector2(rng.randf_range(-8, 8), d * rng.randf_range(4, 9)), Vector2(rng.randf_range(4, 26), 3)), Color(0, 0, 0, 0.08 + 0.05 * wear))
			x += pw
		y += ph
		row += 1
	# The painted stripe round the room, chipped.
	var sy := sz.y * 0.5 - 392.0  # runs behind the sign plate, clear of the boards
	var stripe: Color = w["stripe"]
	_wall.draw_rect(Rect2(0, sy, sz.x, 14), Color(stripe.r, stripe.g, stripe.b, 0.55))
	for i in int(sz.x / 9.0 * wear):
		_wall.draw_rect(Rect2(rng.randf() * sz.x, sy + rng.randf_range(0, 12), rng.randf_range(3, 10), rng.randf_range(2, 5)), base)
	if w.get("hazard", false):
		_hazard(_wall, Rect2(0, sz.y - 22, sz.x, 22))
	# Grime collects low on the wall; light falls from above.
	for i in 12:
		var f := float(i) / 12.0
		_wall.draw_rect(Rect2(0, sz.y * (0.6 + f * 0.4), sz.x, sz.y * 0.04), Color(0, 0, 0, 0.03 + 0.04 * wear * f))
		_wall.draw_rect(Rect2(0, sz.y * f * 0.25, sz.x, sz.y * 0.025), Color(1, 0.95, 0.85, 0.012 * (1.0 - f)))


func _bolts(ci: Control, r: Rect2) -> void:
	for k in [Vector2(6, 6), Vector2(r.size.x - 10, 6), Vector2(6, r.size.y - 10), Vector2(r.size.x - 10, r.size.y - 10)]:
		ci.draw_rect(Rect2(k, Vector2(4, 4)), Color(0.45, 0.45, 0.42))
		ci.draw_rect(Rect2(k + Vector2(1, 1), Vector2(2, 1)), Color(0.75, 0.75, 0.7))


func _hazard(ci: CanvasItem, r: Rect2) -> void:
	ci.draw_rect(r, Color(0.08, 0.07, 0.05))
	var x := r.position.x - r.size.y
	while x < r.end.x:
		var pts := PackedVector2Array([Vector2(x, r.end.y), Vector2(x + r.size.y, r.position.y), Vector2(x + r.size.y + 10, r.position.y), Vector2(x + 10, r.end.y)])
		for i in pts.size():
			pts[i].x = clampf(pts[i].x, r.position.x, r.end.x)
		ci.draw_colored_polygon(pts, Color(0.9, 0.7, 0.12, 0.85))
		x += 20


## Old chalk ghosts on the board: last week's prices never quite wipe off.
func _chalk_dust(c: Control) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = station_id.hash() + 3
	for i in 60:
		var p := Vector2(rng.randf() * c.size.x, rng.randf() * c.size.y)
		c.draw_rect(Rect2(p, Vector2(rng.randf_range(10, 60), 2)), Color(1, 1, 1, 0.025))
	c.draw_rect(Rect2(Vector2(14, c.size.y - 14), Vector2(c.size.x - 28, 5)), Color(0.3, 0.21, 0.13))  # chalk ledge


## Ruled lines and a red margin on your ledger.
func _ruled(c: Control) -> void:
	c.draw_line(Vector2(34, 4), Vector2(34, c.size.y - 4), Color(0.8, 0.3, 0.3, 0.4), 1.0)


## Letter-spaced caps for small headings.
func _spaced(s: String) -> String:
	return " ".join(s.split(""))


func open(id: String) -> void:
	station_id = id
	var st: Dictionary = Data.stations[id]
	var sys: Dictionary = Data.systems[st["system"]]
	_kicker.text = "%s SYSTEM · %s SPACE · %s" % [sys["name"].to_upper(), sys["security"].to_upper(), Data.sector["name"].to_upper()]
	_title.text = st["nick"].to_upper()
	_title.add_theme_color_override("font_color", _stripe().lerp(Color(1, 1, 1), 0.25))
	_wall.queue_redraw()
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
	if _log.size() > 2:
		_log.pop_front()
	var last: Array = _log[-1]
	_comms_who.text = last[0].to_upper()
	var lines := []
	for i in _log.size() - 1:
		lines.append("%s:  %s" % [_log[i][0], Neon.bbcode(_log[i][1])])
	lines.append(Neon.bbcode(last[1]))
	_comms_text.text = "\n\n".join(lines)
	_comms_box.visible = true
	_comms_face.queue_redraw()


func _draw_face() -> void:
	if _log.is_empty():
		return
	UIStyle.draw_id_photo(_comms_face, Rect2(Vector2(3, 3), _comms_face.size - Vector2(6, 6)), Data.portrait_for(_log[-1][0]), "", str(_log[-1][0]).hash(), str(_log[-1][0]))


func _refresh() -> void:
	if not visible:
		return
	var days_left := int(Career.next_payment_day) - int(Career.day)
	_clock_k.text = "DAY %02d · WK %d" % [int(Career.day) + 1, Career.week()]
	_clock_v.text = "Loan paid off" if Career.loan_balance <= 0 else ("Payment due tomorrow" if days_left <= 1 else "Next payment in %d days" % days_left)

	for c in _market.get_children():
		c.queue_free()
	var trader: bool = Career.friend_with_you() and Career.friend["role"] == "trader"
	for h in ["", "price" if not trader else "buy / sell", "in hold", "", "", "", ""]:
		var hl := _chalk(_market, h.to_upper(), 11, CHALK_DIM)
		if h != "":
			hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var st: Dictionary = Data.stations[station_id]
	for g in Data.goods_order:
		var col := CHALK
		var tag := ""
		if g in st["makes"]:
			col = CHALK_GREEN
			tag = "made here"
		elif g in st["wants"]:
			col = CHALK_YELLOW
			tag = "NEEDED!"
		# Name, tag and the dockworkers' slang underneath, all in chalk.
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", -2)
		cell.custom_minimum_size.x = 250
		_market.add_child(cell)
		var nrow := HBoxContainer.new()
		nrow.add_theme_constant_override("separation", 10)
		cell.add_child(nrow)
		_chalk(nrow, Data.goods[g]["name"], 18, col)
		if tag != "":
			var tl := _chalk(nrow, tag, 20, col, true)
			tl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			tl.draw.connect(func(): tl.draw_line(Vector2(0, tl.size.y - 4), Vector2(tl.size.x, tl.size.y - 6), Color(col, 0.7), 1.5))
		_typed(cell, "\"%s\"" % Data.goods[g]["slang"], 12, CHALK_DIM).tooltip_text = Data.goods[g]["desc"]
		cell.tooltip_text = Data.goods[g]["desc"]
		cell.mouse_filter = Control.MOUSE_FILTER_PASS

		var bp := Career.buy_price(station_id, g)
		var sp := Career.sell_price(station_id, g)
		var ptxt := "%s" % Career.fmt(bp) if bp == sp else "%s / %s" % [Career.fmt(bp), Career.fmt(sp)]
		var pl := _chalk(_market, ptxt, 20, CHALK)
		pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		pl.custom_minimum_size.x = 90
		var owned: int = Career.cargo.get(g, 0)
		var job: int = Career.job_cargo.get(g, 0)
		var hl2 := _chalk(_market, (str(owned) if owned > 0 else "-") + (" +%d job" % job if job > 0 else ""), 17, CHALK if owned + job > 0 else CHALK_DIM)
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
	if Career.loan_balance > 0:
		_stat("Charter loan", Career.fmt(Career.loan_balance), UIStyle.INK_STAMP)
		_stat("Next payment", "%s, day %d" % [Career.fmt(mini(Data.LOAN_WEEKLY, Career.loan_balance)), int(Career.next_payment_day) + 1])
	else:
		_stat("Charter loan", "PAID!! all of it", Color(0.15, 0.45, 0.2))
		_stat("Papers", "came through", Color(0.15, 0.45, 0.2))
	if Career.friend_with_you():
		var role: Dictionary = Data.friend_roles[Career.friend["role"]]
		_stat("Flying with me", "%s, %s" % [Career.friend["name"], role["name"].to_lower()])

	for c in _jobs.get_children():
		c.queue_free()
	if Career.jobs.is_empty():
		var none := _label(_jobs, "Nothing pinned. Buy where a good is made, sell where it's needed.", 14, CHALK_DIM)
		none.add_theme_font_override("font", Data.font_type)
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var n := 0
	for j in Career.jobs:
		var where := "pick up at %s" % Data.stations[j["from"]]["nick"] if not j["loaded"] else "deliver to %s" % Data.stations[j["to"]]["nick"]
		# A typed manifest slip, pinned.
		var slip := PanelContainer.new()
		slip.add_theme_stylebox_override("panel", _box(UIStyle.PAPER, UIStyle.PAPER_SHADE, 1, 10))
		slip.rotation = deg_to_rad(0.7 if n % 2 == 0 else -0.6)
		# A strip of masking tape holds it to the wall.
		slip.draw.connect(func(): slip.draw_rect(Rect2(slip.size.x * 0.5 - 28, -7, 56, 15), Color(0.86, 0.8, 0.62, 0.85)))
		_jobs.add_child(slip)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 0)
		slip.add_child(box)
		_typed(box, "MANIFEST · " + j["title"].split(":")[0].to_upper(), 13, UIStyle.INK_TYPE, true)
		_typed(box, "%d t %s, %s" % [j["tons"], Data.goods[j["good"]]["name"].to_lower(), where], 14, UIStyle.INK_TYPE)
		_typed(box, "PAYS %s CR" % Career.fmt(j["pay"]), 12, UIStyle.INK_FADED)
		n += 1

	for c in _dispatch.get_children():
		c.queue_free()
	if station_id == "counter" and Career.loan_balance > 0:
		var d := _card(_dispatch, "CHARTER COMPANY · ACCOUNT CC-40817-M", "manila")
		_typed(d.get_child(0), "Rig loan, company terms. Balance %s cr. Early payments accepted." % Career.fmt(Career.loan_balance), 13, UIStyle.INK_TYPE).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if Career.arrears > 0:
			_typed(d.get_child(0), "OVERDUE %s CR  ·  STRIKE %d OF 2%s" % [Career.fmt(Career.arrears), Career.strikes, "  ·  RECOVERY DISPATCHED" if Career.strikes >= 2 else ""], 14, UIStyle.INK_STAMP, true)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		d.get_child(0).add_child(row)
		if Career.arrears > 0:
			_button(row, "PAY OVERDUE", func(): Career.pay_extra(Career.arrears), Career.credits >= Career.arrears, "stamp")
		_button(row, "PAY 1,000 EXTRA", func(): Career.pay_extra(1000), Career.credits > 0, "stamp")
		_button(row, "PAY IN FULL", func(): Career.pay_extra(Career.loan_balance), Career.credits >= Career.loan_balance, "stamp")
	if station_id == "four" and Career.flags.get("franz_met", false) and not Career.flags.get("bounty_paid", false):
		_bounty_notice()
	if station_id == "saltgate":
		_bar()
	# The forks: Kessler's commission at Four, the Tallyman's job at Amber's.
	var side: String = Career.flags.get("side", "")
	if station_id == "four" and Career.flags.get("franz_pitch", false) and side == "" and not Career.flags.get("tally_job", false):
		_fork_note("NAVY COMMISSION · MARCELLUS PATROL", Data.forks["navy_offer"], "Lt. F. Kessler", "SIGN IT", func(): Career.sign_navy(), UIStyle.PAPER, deg_to_rad(-0.8))
	if station_id == "ambers" and Career.flags.get("tally_offered", false) and side == "" and not Career.flags.get("tally_job", false):
		_fork_note("ONE RIG", Data.forks["tally_offer"], "IIII IIII IIII II", "I'M IN", func(): Career.take_tally_job(), Color(0.8, 0.76, 0.66), deg_to_rad(1.8))
	var shady := Career.shady_offer(station_id)
	if not shady.is_empty():
		Career.flags["shady_seen"] = true
		_shady_note(shady)


## An offer that picks a side: typed, signed in pen, one stamp to take it.
func _fork_note(title: String, text: String, sign: String, verb: String, cb: Callable, bg: Color, rot: float) -> void:
	var paper := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_content_margin_all(12)
	paper.add_theme_stylebox_override("panel", sb)
	paper.rotation = rot
	_dispatch.add_child(paper)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	paper.add_child(v)
	var t := _label(v, title, 15, UIStyle.INK_TYPE)
	if Data.font_type_bold:
		t.add_theme_font_override("font", Data.font_type_bold)
	var body := _label(v, text, 13, UIStyle.INK_TYPE)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size.x = 380
	if Data.font_type:
		body.add_theme_font_override("font", Data.font_type)
	var row := HBoxContainer.new()
	v.add_child(row)
	var sig := _label(row, sign, 22, UIStyle.INK_PEN)
	sig.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if Data.font_hand:
		sig.add_theme_font_override("font", Data.font_hand)
	_button(row, verb, func():
		Sfx.play("stamp")
		cb.call(), true, "stamp")


## The no-questions job: a scrap of paper tucked behind the real notices.
## Handwritten, unsigned but for where to find the sender.
func _shady_note(j: Dictionary) -> void:
	var paper := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.86, 0.82, 0.72)
	sb.set_content_margin_all(12)
	paper.add_theme_stylebox_override("panel", sb)
	paper.rotation = deg_to_rad(1.4)
	_dispatch.add_child(paper)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	paper.add_child(v)
	var t := _label(v, Data.shady["title"], 15, UIStyle.INK_TYPE)
	if Data.font_type_bold:
		t.add_theme_font_override("font", Data.font_type_bold)
	var body := _label(v, Data.shady["text"] % [Data.stations[j["to"]]["nick"], Career.fmt(j["pay"])], 17, UIStyle.INK_PEN)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size.x = 380
	if Data.font_hand:
		body.add_theme_font_override("font", Data.font_hand)
	var row := HBoxContainer.new()
	v.add_child(row)
	var sig := _label(row, "- " + Data.shady["sign"], 20, UIStyle.INK_PEN)
	sig.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if Data.font_hand:
		sig.add_theme_font_override("font", Data.font_hand)
	_button(row, "TAKE THE CRATES", func():
		Sfx.play("tick")
		Career.take_shady(j), true, "stamp")


## Kessler's notice, pinned to the board at Four: typed, signed in pen.
func _bounty_notice() -> void:
	var b: Dictionary = Data.bounty
	var paper := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = UIStyle.PAPER
	sb.set_content_margin_all(12)
	paper.add_theme_stylebox_override("panel", sb)
	paper.rotation = deg_to_rad(-0.6)
	_dispatch.add_child(paper)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	paper.add_child(v)
	var t := _label(v, b["title"], 15, UIStyle.INK_TYPE)
	if Data.font_type_bold:
		t.add_theme_font_override("font", Data.font_type_bold)
	var body := _label(v, b["text"], 13, UIStyle.INK_TYPE)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if Data.font_type:
		body.add_theme_font_override("font", Data.font_type)
	var row := HBoxContainer.new()
	v.add_child(row)
	var sig := _label(row, b["sign"], 22, UIStyle.INK_PEN)
	sig.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if Data.font_hand:
		sig.add_theme_font_override("font", Data.font_hand)
	if Career.flags.get("bounty_killed", false):
		_label(row, "DONE: collect here", 13, UIStyle.INK_STAMP)
	elif Career.flags.get("bounty_taken", false):
		_label(row, "taken", 13, UIStyle.INK_FADED)
	else:
		_button(row, "TAKE IT", func():
			Sfx.play("tick")
			Career.take_bounty(), true, "stamp")


## Saltgate's bar: captains for hire on weekly contracts. Their own notes,
## pinned by the bar door, in their own hands.
func _bar() -> void:
	var d := _card(_dispatch, "SALTGATE BAR", "wall")
	var n := 0
	for id in Data.captain_order:
		var c: Dictionary = Data.captains[id]
		var note := PanelContainer.new()
		note.add_theme_stylebox_override("panel", _box(Color(0.93, 0.9, 0.78) if n == 0 else Color(0.86, 0.84, 0.8), UIStyle.PAPER_SHADE, 1, 10))
		note.rotation = deg_to_rad(-1.0 if n == 0 else 0.8)
		d.get_child(0).add_child(note)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		note.add_child(row)
		var info := VBoxContainer.new()
		info.add_theme_constant_override("separation", -4)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		var nm := _label(info, c["full"], 24, UIStyle.INK_PEN)
		nm.add_theme_font_override("font", Data.font_hand)
		var line := _label(info, "%s %s cr/week" % [c["note"], Career.fmt(c["wage"])], 19, UIStyle.INK_TYPE)
		line.add_theme_font_override("font", Data.font_hand)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.tooltip_text = c["pitch"]
		if Career.crew.has(id):
			var h := _label(row, "HIRED", 16, UIStyle.INK_STAMP)
			h.add_theme_font_override("font", Data.font_stamp)
			h.rotation = deg_to_rad(-8)
		else:
			_button(row, "HIRE", func():
				Sfx.play("stamp", -6.0)
				Career.hire(id), Career.credits >= c["wage"], "stamp")
		n += 1


## A line in your ledger: the printed column, your figures in pen.
func _stat(name: String, value: String, col := UIStyle.INK_PEN) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 32
	row.draw.connect(func(): row.draw_line(Vector2(-40, row.size.y + 1), Vector2(row.size.x + 4, row.size.y + 1), Color(0.45, 0.6, 0.8, 0.35), 1.0))
	_stats.add_child(row)
	var n := _typed(row, name, 13, UIStyle.INK_FADED)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.size_flags_vertical = Control.SIZE_SHRINK_END
	var v := _label(row, value, 24, col)
	v.add_theme_font_override("font", Data.font_hand)


## Chalk on the board: legible print by default, handwriting only for flourishes.
func _chalk(parent: Control, text: String, sz: int, col: Color, hand := false) -> Label:
	var l := _label(parent, text, sz, col)
	l.add_theme_font_override("font", Data.font_hand if hand else Data.font_bold)
	return l


func _typed(parent: Control, text: String, sz: int, col: Color, bold := false) -> Label:
	var l := _label(parent, text, sz, col)
	l.add_theme_font_override("font", Data.font_type_bold if bold else Data.font_type)
	return l


## Buttons: chalk boxes on the board, rubber stamps on paper.
func _button(parent: Control, text: String, cb: Callable, enabled := true, style := "chalk") -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = not enabled
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 30)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var ink := CHALK if style == "chalk" else UIStyle.INK_STAMP
	b.add_theme_font_override("font", Data.font_type_bold if style == "chalk" else Data.font_stamp)
	b.add_theme_font_size_override("font_size", 14)
	for st in ["normal", "hover", "pressed", "disabled"]:
		var a := 0.55
		match st:
			"hover":
				a = 1.0
			"pressed":
				a = 0.8
			"disabled":
				a = 0.18
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(ink.r, ink.g, ink.b, 0.12 if st == "hover" else 0.0)
		sb.border_color = Color(ink.r, ink.g, ink.b, a)
		sb.set_border_width_all(2 if style == "stamp" else 1)
		sb.set_corner_radius_all(3 if style == "stamp" else 0)
		sb.content_margin_left = 9
		sb.content_margin_right = 9
		sb.content_margin_top = 0
		sb.content_margin_bottom = 0
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_color_override("font_color", Color(ink, 0.85))
	b.add_theme_color_override("font_hover_color", ink.lightened(0.15) if style == "chalk" else ink)
	b.add_theme_color_override("font_pressed_color", ink)
	b.add_theme_color_override("font_disabled_color", Color(ink, 0.25))
	b.pressed.connect(cb)
	parent.add_child(b)
	return b
