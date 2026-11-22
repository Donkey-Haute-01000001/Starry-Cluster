extends Control
## J: your logbook. Left page: who you are, your accounts, the job and the
## people you know. Right page: every comms line, newest at the bottom.
## Stops the clock while it's open.

var main: Node
var _was_paused := false
var _scroll := 0  ## comms lines scrolled up from the newest

const PAPER := Vector2(1100, 660)


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
	_scroll = 0
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
	elif visible and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_scroll = mini(_scroll + 1, maxi(0, Career.comms_log.size() - 1))
			queue_redraw()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_scroll = maxi(_scroll - 1, 0)
			queue_redraw()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			close()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.02, 0.78))
	var pr := Rect2((size - PAPER) * 0.5, PAPER)
	draw_rect(Rect2(pr.position + Vector2(6, 8), pr.size), Color(0, 0, 0, 0.4))
	# Two pages and a spine.
	var half := pr.size.x * 0.5
	var lp := Rect2(pr.position, Vector2(half, pr.size.y))
	var rp := Rect2(pr.position + Vector2(half, 0), Vector2(half, pr.size.y))
	draw_rect(lp, UIStyle.PAPER)
	draw_rect(rp, UIStyle.PAPER.darkened(0.02))
	for k in 6:
		draw_line(Vector2(pr.position.x + half - 3 + k, pr.position.y), Vector2(pr.position.x + half - 3 + k, pr.end.y), Color(0, 0, 0, 0.05 + 0.02 * (3 - absi(k - 3))), 1.0)
	_left(lp.grow(-34))
	_right(rp.grow(-34))
	draw_string(Data.font_type, Vector2(pr.end.x - 380, pr.end.y - 12), "J or Esc to close  ·  M chart  ·  wheel scrolls log", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UIStyle.INK_FADED)


func _left(r: Rect2) -> void:
	var tb: Font = Data.font_type_bold
	var tr: Font = Data.font_type
	var hand: Font = Data.font_hand
	var ink := UIStyle.INK_TYPE
	var y := r.position.y + 14
	draw_string(tb, Vector2(r.position.x, y), "OPERATOR'S LOG", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, ink)
	draw_string(tr, Vector2(r.end.x - 70, y), "DAY %d" % (int(Career.day) + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, ink)
	y += 14
	draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color(ink, 0.5), 1.0)
	y += 14
	# ID card.
	var ph := Rect2(Vector2(r.position.x, y), Vector2(96, 122))
	UIStyle.draw_id_photo(self, ph, [Color(0.8, 0.65, 0.5), Color(0.2, 0.15, 0.1), Color(0.3, 0.35, 0.4)], "CC-40817-M", 7, "You")
	var x := ph.end.x + 18
	draw_string(tr, Vector2(x, y + 12), "OPERATOR", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UIStyle.INK_FADED)
	draw_string(hand, Vector2(x, y + 40), str(Career.pilot.get("name", "")), HORIZONTAL_ALIGNMENT_LEFT, r.end.x - x, 30, UIStyle.INK_PEN)
	draw_string(tr, Vector2(x, y + 62), "RIG", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UIStyle.INK_FADED)
	draw_string(hand, Vector2(x, y + 88), str(Career.pilot.get("rig", "")), HORIZONTAL_ALIGNMENT_LEFT, r.end.x - x, 28, UIStyle.INK_PEN)
	draw_string(tr, Vector2(x, y + 110), "Light freighter  ·  Charter lien  ·  file CC-40817-M", HORIZONTAL_ALIGNMENT_LEFT, r.end.x - x, 12, ink)
	y = ph.end.y + 26

	# Accounts.
	_head(r, y, "ACCOUNTS")
	y += 22
	var due_in := maxf(0.0, Career.next_payment_day - Career.day)
	var rows := [
		["Credits", "%s cr" % _num(Career.credits)],
		["Charter loan", "%s cr" % _num(Career.loan_balance) if Career.loan_balance > 0 else "PAID IN FULL"],
		["Next payment", ("%s cr in %.1f days" % [_num(Data.LOAN_WEEKLY), due_in]) if Career.loan_balance > 0 else "none"],
		["Hold", "%d / %d t" % [Career.cargo_used(), Career.cargo_capacity]],
	]
	for row in rows:
		draw_string(tr, Vector2(r.position.x, y), row[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UIStyle.INK_FADED)
		draw_string(tb, Vector2(r.position.x + 170, y), row[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, ink)
		y += 20
	y += 10

	# The job.
	_head(r, y, "CURRENT JOB")
	y += 26
	if Career.objective:
		var txt: String = Career.objective["text"]
		draw_multiline_string(hand, Vector2(r.position.x, y), txt, HORIZONTAL_ALIGNMENT_LEFT, r.size.x, 24, 3, UIStyle.INK_PEN)
		y += hand.get_multiline_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, r.size.x, 24, 3).y
	else:
		draw_string(tr, Vector2(r.position.x, y), "Nothing pressing. Pick runs off any station's board.", HORIZONTAL_ALIGNMENT_LEFT, r.size.x, 13, UIStyle.INK_FADED)
		y += 18
	y += 14

	# People: everyone who's been on your comms, with a word on who they are.
	_head(r, y, "PEOPLE")
	y += 14
	var px := r.position.x
	for who in Career.contacts:
		if who == "You":
			continue
		if px + 76 > r.end.x:
			px = r.position.x
			y += 128
		if y + 110 > r.end.y:
			break
		var pp := Rect2(Vector2(px, y), Vector2(62, 78))
		UIStyle.draw_id_photo(self, pp, Data.portrait_for(who), "", who.hash(), who)
		draw_string(tb, Vector2(px, pp.end.y + 16), who.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, 72, 11, ink)
		var role: String = _role_of(who)
		draw_string(tr, Vector2(px, pp.end.y + 29), role, HORIZONTAL_ALIGNMENT_LEFT, 72, 10, UIStyle.INK_FADED)
		px += 80


func _role_of(who: String) -> String:
	if Career.friend.get("name", "") == who:
		return "old friend"
	if who in ["Fay", "Mersham"]:
		return "crew" if Career.crew.has(who.to_lower()) else "Saltgate bar"
	return Data.speaker_info(who).get("role", "")


func _right(r: Rect2) -> void:
	var tb: Font = Data.font_type_bold
	var tr: Font = Data.font_type
	var ink := UIStyle.INK_TYPE
	var y := r.position.y + 14
	draw_string(tb, Vector2(r.position.x, y), "COMMS LOG", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, ink)
	y += 14
	draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color(ink, 0.5), 1.0)
	var top := y + 12
	var entries: Array = Career.comms_log
	if entries.is_empty():
		draw_string(tr, Vector2(r.position.x, top + 16), "Nothing on the radio yet.", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UIStyle.INK_FADED)
		return
	# Lay out from the newest (minus scroll) upward until the page is full.
	var by := r.end.y - 14
	var text_w := r.size.x - 104
	var i := entries.size() - 1 - _scroll
	while i >= 0:
		var e: Array = entries[i]
		var txt: String = e[2]
		var h := tr.get_multiline_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, text_w, 13).y
		if by - h < top:
			break
		var ty := by - h
		var who: String = e[1]
		var col: Color = UIStyle.INK_PEN if who == "You" else ink
		draw_string(tb, Vector2(r.position.x, ty + 12), who.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, 96, 11, col)
		draw_string(tr, Vector2(r.position.x, ty + 25), "day %d" % (int(e[0]) + 1), HORIZONTAL_ALIGNMENT_LEFT, 96, 10, UIStyle.INK_FADED)
		draw_multiline_string(tr, Vector2(r.position.x + 104, ty + 12), txt, HORIZONTAL_ALIGNMENT_LEFT, text_w, 13, -1, col)
		by = ty - 12
		draw_line(Vector2(r.position.x, by + 5), Vector2(r.end.x, by + 5), Color(ink, 0.08), 1.0)
		i -= 1
	if _scroll > 0:
		draw_string(tr, Vector2(r.end.x - 150, r.end.y + 4), "▼ %d newer" % _scroll, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UIStyle.INK_FADED)


func _head(r: Rect2, y: float, text: String) -> void:
	draw_string(Data.font_type_bold, Vector2(r.position.x, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UIStyle.INK_FADED)
	draw_line(Vector2(r.position.x, y + 5), Vector2(r.end.x, y + 5), Color(UIStyle.INK_TYPE, 0.25), 1.0)


func _num(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out
