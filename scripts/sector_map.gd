extends Control
## M: the Charter's route chart of the sector, printed on paper and marked up
## in pen. Systems, jump links, stations, where you are and where the job is.
## Stops the clock while it's open.

var main: Node
var _was_paused := false
var _hover := ""
var _t := 0.0

const PAPER := Vector2(1040, 640)
## Where each system sits on the chart (0..1 of the chart area).
const LAYOUT := {
	"aurelia": Vector2(0.16, 0.52),
	"marcellus": Vector2(0.45, 0.2),
	"tiberine": Vector2(0.45, 0.82),
	"porta_aquila": Vector2(0.72, 0.52),
	"crossroads": Vector2(0.93, 0.52),
}


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


func open(was_paused = null) -> void:
	if visible or main.pause_menu.visible:
		return
	_was_paused = get_tree().paused if was_paused == null else bool(was_paused)
	if main.journal.visible:
		_was_paused = main.journal.close(true)
	get_tree().paused = true
	visible = true
	_t = 0.0
	Sfx.play("paper", -6.0)


## Closes the chart. `keep_paused` hands the clock to another sheet; returns
## whether the game was paused before this sheet opened.
func close(keep_paused := false) -> bool:
	if not visible:
		return _was_paused
	visible = false
	if not keep_paused and not _was_paused:
		get_tree().paused = false
	Sfx.play("paper", -10.0, 1.2)
	return _was_paused


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_M:
		if not main.merchant or main.pause_menu.visible:
			return
		toggle()
		get_viewport().set_input_as_handled()
	elif visible and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var h := _system_at(event.position)
		if h != _hover:
			_hover = h
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		close()


func _process(delta: float) -> void:
	if visible:
		_t += delta
		queue_redraw()


func _paper_rect() -> Rect2:
	return Rect2((size - PAPER) * 0.5, PAPER)


func _chart_rect() -> Rect2:
	var p := _paper_rect()
	return Rect2(p.position + Vector2(40, 96), Vector2(p.size.x - 80, p.size.y - 190))


func _sys_pos(id: String) -> Vector2:
	var c := _chart_rect()
	return c.position + LAYOUT.get(id, Vector2(0.5, 0.5)) * c.size


func _system_at(p: Vector2) -> String:
	for id in LAYOUT:
		if _sys_pos(id).distance_to(p) < 46.0:
			return id
	return ""


func _all_systems() -> Dictionary:
	var out: Dictionary = Data.systems.duplicate()
	out["crossroads"] = Data.crossroads
	return out


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.02, 0.78))
	var pr := _paper_rect()
	draw_rect(Rect2(pr.position + Vector2(6, 8), pr.size), Color(0, 0, 0, 0.4))
	draw_rect(pr, UIStyle.PAPER)
	# Faint survey grid.
	var c := _chart_rect()
	var gx := c.position.x
	while gx <= c.end.x:
		draw_line(Vector2(gx, c.position.y), Vector2(gx, c.end.y), Color(UIStyle.INK_PEN, 0.06), 1.0)
		gx += 40.0
	var gy := c.position.y
	while gy <= c.end.y:
		draw_line(Vector2(c.position.x, gy), Vector2(c.end.x, gy), Color(UIStyle.INK_PEN, 0.06), 1.0)
		gy += 40.0
	var tb: Font = Data.font_type_bold
	var tr: Font = Data.font_type
	var hand: Font = Data.font_hand
	var ink := UIStyle.INK_TYPE
	# Header.
	draw_string(tb, pr.position + Vector2(40, 46), "HESPER MARCH  ·  CHARTER ROUTE CHART", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, ink)
	draw_string(tr, pr.position + Vector2(40, 70), "\"The Long Haul.\"  Jump links only: rifts can't be built, only crossed.", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UIStyle.INK_FADED)
	draw_string(tr, pr.position + Vector2(pr.size.x - 220, 46), "DAY %d" % (int(Career.day) + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, ink)
	draw_line(pr.position + Vector2(40, 82), Vector2(pr.end.x - 40, pr.position.y + 82), Color(ink, 0.5), 1.0)

	var systems := _all_systems()
	# Jump links first, under everything.
	var drawn := {}
	for id in systems:
		for j in systems[id].get("jumps", []):
			var key := [id, j["to"]]
			key.sort()
			if drawn.has(str(key)):
				continue
			drawn[str(key)] = true
			var a := _sys_pos(id)
			var b := _sys_pos(j["to"])
			if j.get("locked", false):
				_dashed(a, b, Color(UIStyle.INK_STAMP, 0.7), 2.0)
				var mid := (a + b) * 0.5
				draw_string(tr, mid + Vector2(-48, -10), "papers only", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UIStyle.INK_STAMP)
			else:
				draw_line(a, b, Color(ink, 0.55), 2.0, true)

	# The job's destination system, for the pen mark.
	var obj_station: String = Career.objective.get("station", "") if Career.objective else ""
	var obj_sys: String = Data.stations[obj_station]["system"] if Data.stations.has(obj_station) else ""
	var route_next: String = Career.next_hop(Career.system_id, obj_sys) if obj_sys != "" else ""
	if route_next != "":
		_pen_route(_sys_pos(Career.system_id), _sys_pos(route_next))

	for id in systems:
		var sd: Dictionary = systems[id]
		var p := _sys_pos(id)
		var known: bool = id == "crossroads" or Career.visited.has(id)
		var rough: bool = sd.get("security", "") == "Rough"
		var col := UIStyle.INK_STAMP if rough else ink
		var rad := 30.0 if id != "crossroads" else 24.0
		draw_circle(p, rad, UIStyle.PAPER)
		draw_arc(p, rad, 0, TAU, 40, col, 2.5 if id == _hover else 1.6, true)
		if rough:
			# Hatched: pirates in the rocks.
			for k in range(-3, 4):
				var o := k * 8.0
				var h := sqrt(maxf(0.0, rad * rad - o * o)) * 0.85
				draw_line(p + Vector2(o - h * 0.5, h * 0.5), p + Vector2(o + h * 0.5, -h * 0.5), Color(col, 0.25), 1.0)
		if id == "crossroads":
			draw_string(tb, p + Vector2(-6, 7), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, col)
		# Name block.
		var name: String = sd.get("name", id).to_upper()
		var nw := tb.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		draw_string(tb, p + Vector2(-nw * 0.5, rad + 22), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, ink)
		var sub: String = "%s  ·  %s" % [sd.get("nick", ""), sd.get("security", "")]
		var sw := tr.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		draw_string(tr, p + Vector2(-sw * 0.5, rad + 38), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UIStyle.INK_FADED)
		# Stations, one per line.
		var y := rad + 56.0
		for st_id in Data.stations:
			var st: Dictionary = Data.stations[st_id]
			if st["system"] != id:
				continue
			var label: String = st["nick"]
			var lw := tr.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
			draw_rect(Rect2(p + Vector2(-lw * 0.5 - 12, y - 8), Vector2(5, 5)), Color(ink, 0.8))
			draw_string(tr, p + Vector2(-lw * 0.5, y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, ink)
			if st_id == obj_station:
				# The job: a pen X and an underline.
				var xp := p + Vector2(lw * 0.5 + 10, y - 5)
				draw_line(xp + Vector2(-6, -6), xp + Vector2(6, 6), UIStyle.INK_PEN, 2.5, true)
				draw_line(xp + Vector2(-6, 6), xp + Vector2(6, -6), UIStyle.INK_PEN, 2.5, true)
				draw_line(p + Vector2(-lw * 0.5, y + 4), p + Vector2(lw * 0.5, y + 5), UIStyle.INK_PEN, 1.5, true)
			y += 17.0
		if known and id != "crossroads" and id != Career.system_id:
			var tk := p + Vector2(rad + 2, -rad + 2)
			draw_polyline(PackedVector2Array([tk + Vector2(-6, -2), tk + Vector2(-1, 4), tk + Vector2(9, -10)]), UIStyle.INK_PEN, 2.5, true)
		if id == Career.system_id:
			# You are here: a loose pen circle.
			var pts := PackedVector2Array()
			for i in 34:
				var ang := -0.4 + TAU * 1.05 * i / 33.0
				pts.append(p + Vector2(cos(ang), sin(ang)) * (rad + 9.0 + sin(i * 0.9) * 2.0))
			draw_polyline(pts, UIStyle.INK_PEN, 2.0, true)
			draw_string(hand, p + Vector2(-rad - 64, -rad - 4), "you're here", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, UIStyle.INK_PEN)

	# Footer: the job, or what's under the cursor.
	var fy := pr.end.y - 58.0
	draw_line(Vector2(pr.position.x + 40, fy - 22), Vector2(pr.end.x - 40, fy - 22), Color(ink, 0.5), 1.0)
	if _hover != "" and systems.has(_hover):
		var sd2: Dictionary = systems[_hover]
		draw_string(tb, Vector2(pr.position.x + 40, fy), sd2.get("name", _hover).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, ink)
		var desc: String = sd2.get("desc", "")
		if _hover == "crossroads":
			desc = "Past the Wall. Charter papers required. Nobody you know has been."
		draw_multiline_string(tr, Vector2(pr.position.x + 40, fy + 18), desc, HORIZONTAL_ALIGNMENT_LEFT, pr.size.x - 80, 13, 2, UIStyle.INK_FADED)
	elif Career.objective:
		draw_string(tb, Vector2(pr.position.x + 40, fy), "CURRENT JOB", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UIStyle.INK_FADED)
		draw_multiline_string(hand, Vector2(pr.position.x + 40, fy + 24), Career.objective["text"], HORIZONTAL_ALIGNMENT_LEFT, pr.size.x - 80, 24, 2, UIStyle.INK_PEN)
	else:
		draw_string(tr, Vector2(pr.position.x + 40, fy), "No job on the board. Check a station's job board when you dock.", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UIStyle.INK_FADED)
	draw_string(tr, Vector2(pr.end.x - 240, pr.end.y - 14), "M or Esc to close  ·  J journal", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UIStyle.INK_FADED)


func _dashed(a: Vector2, b: Vector2, col: Color, w: float) -> void:
	var d := b - a
	var n := int(d.length() / 12.0)
	for i in n:
		if i % 2 == 0:
			draw_line(a + d * (float(i) / n), a + d * (float(i + 1) / n), col, w)


## A pen arrow along the next jump toward the job.
func _pen_route(a: Vector2, b: Vector2) -> void:
	var d := (b - a).normalized()
	var s := a + d * 40.0
	var e := b - d * 40.0
	var n := d.orthogonal() * 7.0
	draw_line(s + n, e + n, UIStyle.INK_PEN, 2.0, true)
	draw_line(e + n, e + n - d.rotated(0.5) * 14.0, UIStyle.INK_PEN, 2.0, true)
	draw_line(e + n, e + n - d.rotated(-0.5) * 14.0, UIStyle.INK_PEN, 2.0, true)
