extends Control
## M: the Charter's chart of the whole cluster. Hesper March, the little pocket
## you know, is inked in detail; the Crossroads sits in the middle like a cork;
## everything past it is fog and pencilled rumor. Stops the clock while open.

var main: Node
var _was_paused := false
var _hover := ""
var _t := 0.0

## Where each charted system sits (0..1 of the chart area).
const LAYOUT := {
	"aurelia": Vector2(0.105, 0.5),
	"marcellus": Vector2(0.2, 0.3),
	"tiberine": Vector2(0.2, 0.71),
	"porta_aquila": Vector2(0.31, 0.5),
	"crossroads": Vector2(0.52, 0.5),
}
## The rest of the Federation pocket: printed, no Charter routes.
const FED_DOTS := [Vector2(0.07, 0.22), Vector2(0.06, 0.78), Vector2(0.2, 0.1), Vector2(0.12, 0.88), Vector2(0.035, 0.5)]
## Rumors in pencil: [pos, title, line].
const RUMORS := [
	[Vector2(0.56, 0.13), "League lanes", "merchant houses. tolls on everything"],
	[Vector2(0.82, 0.2), "Remnant holdout?", "old empire colors, they say"],
	[Vector2(0.86, 0.52), "Dynasty heartland", "warlords. don't go."],
	[Vector2(0.57, 0.86), "Free Ports", "pirate country"],
	[Vector2(0.84, 0.84), "the Faithful", "camped at the dead rifts"],
]
## Where the Crossroads' lanes run off into the fog.
const LANES := [Vector2(0.58, 0.2), Vector2(0.75, 0.27), Vector2(0.8, 0.5), Vector2(0.74, 0.76), Vector2(0.58, 0.8), Vector2(0.45, 0.83), Vector2(0.44, 0.17)]
const DEAD_RIFTS := [Vector2(0.97, 0.12), Vector2(0.985, 0.62), Vector2(0.9, 0.96), Vector2(0.62, 0.03), Vector2(0.4, 0.97)]
const GRAPHITE := Color(0.36, 0.35, 0.34)


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
	var ps := Vector2(minf(1240.0, size.x - 60.0), minf(740.0, size.y - 50.0))
	return Rect2((size - ps) * 0.5, ps)


func _chart_rect() -> Rect2:
	var p := _paper_rect()
	return Rect2(p.position + Vector2(30, 92), Vector2(p.size.x - 60, p.size.y - 170))


func _at(v: Vector2) -> Vector2:
	var c := _chart_rect()
	return c.position + v * c.size


func _sys_pos(id: String) -> Vector2:
	return _at(LAYOUT.get(id, Vector2(0.5, 0.5)))


func _system_at(p: Vector2) -> String:
	for id in LAYOUT:
		if _sys_pos(id).distance_to(p) < 30.0:
			return id
	for i in RUMORS.size():
		if _at(RUMORS[i][0]).distance_to(p) < 70.0:
			return "rumor_%d" % i
	return ""


func _all_systems() -> Dictionary:
	var out: Dictionary = Data.systems.duplicate()
	out["crossroads"] = Data.crossroads
	return out


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.02, 0.8))
	var pr := _paper_rect()
	draw_rect(Rect2(pr.position + Vector2(6, 8), pr.size), Color(0, 0, 0, 0.4))
	draw_rect(pr, UIStyle.PAPER)
	var c := _chart_rect()
	var tb: Font = Data.font_type_bold
	var tr: Font = Data.font_type
	var hand: Font = Data.font_hand
	var ink := UIStyle.INK_TYPE

	# Header.
	draw_string(tb, pr.position + Vector2(30, 42), "THE CLUSTER  ·  CHARTER ROUTE CHART", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, ink)
	draw_string(tr, pr.position + Vector2(30, 64), "Charter routes in ink. Past the Wall, it's rumor and pencil.", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UIStyle.INK_FADED)
	draw_string(tr, Vector2(pr.end.x - 110, pr.position.y + 42), "DAY %d" % (int(Career.day) + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, ink)
	draw_line(pr.position + Vector2(30, 76), Vector2(pr.end.x - 30, pr.position.y + 76), Color(ink, 0.5), 1.0)

	# The cluster's edge: beyond it the outbound rifts went dark.
	_dashed_rect(c.grow(-4), Color(ink, 0.35))
	for d in DEAD_RIFTS:
		_dead_rift(_at(d))
	draw_string(tb, Vector2(c.end.x - 330, c.end.y + 24), "⊗  THE SEVERANCE", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(ink, 0.7))
	draw_string(tr, Vector2(c.end.x - 330, c.end.y + 40), "Outbound rifts, dark seventy years. Cause unknown.", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UIStyle.INK_FADED)

	# Uncharted systems: faint printed dots, most of them under fog.
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	var dots: Array = []
	while dots.size() < 70:
		var v := Vector2(rng.randf_range(0.38, 0.97), rng.randf_range(0.05, 0.95))
		if v.distance_to(LAYOUT["crossroads"]) < 0.07:
			continue
		dots.append(v)
	for i in dots.size():
		var v: Vector2 = dots[i]
		draw_circle(_at(v), 2.5, Color(ink, 0.35))
		# A few faint printed links, as if half-surveyed.
		if i % 3 == 0 and i + 1 < dots.size() and v.distance_to(dots[i + 1]) < 0.22:
			draw_line(_at(v), _at(dots[i + 1]), Color(ink, 0.1), 1.0)
	# The Crossroads' lanes into the dark.
	var cx := _sys_pos("crossroads")
	for l in LANES:
		_dashed(cx, _at(l), Color(ink, 0.3), 1.5)
	# Fog: soft paper-coloured cloud over everything past the Wall.
	var fog := RandomNumberGenerator.new()
	fog.seed = 31337
	for i in 260:
		var v := Vector2(fog.randf_range(0.4, 1.0), fog.randf_range(0.0, 1.0))
		var rr := fog.randf_range(30.0, 90.0)
		draw_circle(_at(v), rr, Color(UIStyle.PAPER_SHADE.r, UIStyle.PAPER_SHADE.g, UIStyle.PAPER_SHADE.b, 0.07))
		draw_circle(_at(v), rr * 0.6, Color(UIStyle.PAPER.r, UIStyle.PAPER.g, UIStyle.PAPER.b, 0.12))
	# Pencil hatching where nobody's been.
	var hx := _at(Vector2(0.4, 0)).x
	while hx < c.end.x + c.size.y:
		var a := Vector2(hx, c.position.y)
		var b := Vector2(hx - c.size.y, c.end.y)
		if b.x < _at(Vector2(0.4, 0)).x:
			var k := (_at(Vector2(0.4, 0)).x - b.x) / (a.x - b.x)
			b = b.lerp(a, k)
		if a.x > c.end.x:
			var k2 := (a.x - c.end.x) / (a.x - b.x)
			a = a.lerp(b, k2)
		draw_line(a, b, Color(GRAPHITE, 0.07), 1.0)
		hx += 14.0
	# Rumors, pencilled in.
	for i in RUMORS.size():
		var rm: Array = RUMORS[i]
		var p := _at(rm[0])
		var hov := _hover == "rumor_%d" % i
		var w := hand.get_string_size(rm[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
		draw_string(hand, p - Vector2(w * 0.5, 0), rm[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(GRAPHITE, 0.95 if hov else 0.75))
		var w2 := hand.get_string_size(rm[2], HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		draw_string(hand, p + Vector2(-w2 * 0.5, 20), rm[2], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(GRAPHITE, 0.6))

	# The Federation pocket: a printed border around what you know.
	var fed := PackedVector2Array()
	for k in 48:
		var ang := TAU * k / 48.0
		var e := Vector2(cos(ang) * 0.17, sin(ang) * 0.45)
		fed.append(_at(Vector2(0.19, 0.5) + e))
	fed.append(fed[0])
	draw_polyline(fed, Color(UIStyle.INK_PEN, 0.35), 2.0, true)
	draw_string(tb, _at(Vector2(0.15, 0.03)) + Vector2(0, 8), "FEDERATION", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(UIStyle.INK_PEN, 0.7))
	for d in FED_DOTS:
		draw_circle(_at(d), 4.0, Color(ink, 0.45))
	draw_string(tr, _at(Vector2(0.01, 0.985)), "dots: Federation interior, no Charter routes", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UIStyle.INK_FADED)

	# Hesper March: inked, in detail.
	var systems := _all_systems()
	var drawn := {}
	for id in Data.systems:
		for j in Data.systems[id].get("jumps", []):
			var key := [id, j["to"]]
			key.sort()
			if drawn.has(str(key)):
				continue
			drawn[str(key)] = true
			var a2 := _sys_pos(id)
			var b2 := _sys_pos(j["to"])
			if j.get("locked", false):
				_dashed(a2, b2, Color(UIStyle.INK_STAMP, 0.8), 2.5)
				draw_string(tr, (a2 + b2) * 0.5 + Vector2(-36, -10), "papers only", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UIStyle.INK_STAMP)
			else:
				draw_line(a2, b2, Color(ink, 0.7), 2.0, true)
	draw_string(tb, _at(Vector2(0.03, 0.06)) + Vector2(0, 30), "HESPER MARCH", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, ink)
	draw_string(tr, _at(Vector2(0.03, 0.06)) + Vector2(0, 45), "\"the Long Haul\" · Charter sector", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UIStyle.INK_FADED)

	var obj_station: String = Career.objective.get("station", "") if Career.objective else ""
	var obj_sys: String = Data.stations[obj_station]["system"] if Data.stations.has(obj_station) else ""
	var route_next: String = Career.next_hop(Career.system_id, obj_sys) if obj_sys != "" else ""
	if route_next != "":
		_pen_route(_sys_pos(Career.system_id), _sys_pos(route_next))

	for id in Data.systems:
		var sd: Dictionary = Data.systems[id]
		var p := _sys_pos(id)
		var rough: bool = sd.get("security", "") == "Rough"
		var col := UIStyle.INK_STAMP if rough else ink
		var rad := 15.0
		draw_circle(p, rad, UIStyle.PAPER)
		draw_arc(p, rad, 0, TAU, 32, col, 2.6 if id == _hover else 1.8, true)
		if rough:
			for k in range(-2, 3):
				var o := k * 5.0
				var h := sqrt(maxf(0.0, rad * rad - o * o)) * 0.8
				draw_line(p + Vector2(o - h * 0.5, h * 0.5), p + Vector2(o + h * 0.5, -h * 0.5), Color(col, 0.3), 1.0)
		if id == "porta_aquila":
			# The fortress gate: a heavy bar across the way out.
			draw_rect(Rect2(p + Vector2(20, -16), Vector2(5, 32)), ink)
			draw_string(tb, p + Vector2(-26, -26), "THE WALL", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, ink)
		var nm: String = sd["name"].to_upper()
		var nw := tb.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		var sub: String = "%s · %s" % [sd["nick"], sd["security"]]
		var sw := tr.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		var n_st := 0
		for st_id2 in Data.stations:
			if Data.stations[st_id2]["system"] == id:
				n_st += 1
		var bw := maxf(maxf(nw, sw), 70.0) + 12.0
		draw_rect(Rect2(p + Vector2(-bw * 0.5, rad + 3), Vector2(bw, 30 + n_st * 13)), Color(UIStyle.PAPER, 0.92))
		draw_string(tb, p + Vector2(-nw * 0.5, rad + 16), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, ink)
		draw_string(tr, p + Vector2(-sw * 0.5, rad + 28), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UIStyle.INK_FADED)
		var y := rad + 41.0
		for st_id in Data.stations:
			var st: Dictionary = Data.stations[st_id]
			if st["system"] != id:
				continue
			var label: String = st["nick"]
			var lw := tr.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
			draw_string(tr, p + Vector2(-lw * 0.5, y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, ink)
			if st_id == obj_station:
				var xp := p + Vector2(lw * 0.5 + 9, y - 4)
				draw_line(xp + Vector2(-5, -5), xp + Vector2(5, 5), UIStyle.INK_PEN, 2.5, true)
				draw_line(xp + Vector2(-5, 5), xp + Vector2(5, -5), UIStyle.INK_PEN, 2.5, true)
				draw_line(p + Vector2(-lw * 0.5, y + 3), p + Vector2(lw * 0.5, y + 4), UIStyle.INK_PEN, 1.5, true)
			y += 13.0
		if Career.visited.has(id) and id != Career.system_id:
			var tk := p + Vector2(rad + 1, -rad + 1)
			draw_polyline(PackedVector2Array([tk + Vector2(-5, -2), tk + Vector2(-1, 3), tk + Vector2(7, -8)]), UIStyle.INK_PEN, 2.2, true)
		if id == Career.system_id:
			var pts := PackedVector2Array()
			for i in 34:
				var ang := -0.4 + TAU * 1.05 * i / 33.0
				pts.append(p + Vector2(cos(ang), sin(ang)) * (rad + 7.0 + sin(i * 0.9) * 1.5))
			draw_polyline(pts, UIStyle.INK_PEN, 2.0, true)
			draw_string(hand, p + Vector2(-rad - 70, -rad - 2), "you're here", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, UIStyle.INK_PEN)

	# The Crossroads: printed, big, right in the way.
	draw_circle(cx, 24.0, UIStyle.PAPER)
	draw_arc(cx, 24.0, 0, TAU, 40, ink, 2.6 if _hover == "crossroads" else 2.0, true)
	draw_arc(cx, 30.0, 0, TAU, 40, Color(ink, 0.4), 1.0, true)
	draw_string(tb, cx + Vector2(-6, 7), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, ink)
	var cn := "THE CROSSROADS"
	var cnw := tb.get_string_size(cn, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	draw_rect(Rect2(cx + Vector2(-cnw * 0.5 - 6, 36), Vector2(cnw + 12, 34)), Color(UIStyle.PAPER, 0.9))
	draw_string(tb, cx + Vector2(-cnw * 0.5, 52), cn, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, ink)
	var cs := "Dynasty gate · every road meets here"
	var csw := tr.get_string_size(cs, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	draw_string(tr, cx + Vector2(-csw * 0.5, 66), cs, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UIStyle.INK_FADED)

	# Footer: what's under the cursor, or the job.
	var fy := pr.end.y - 44.0
	draw_line(Vector2(pr.position.x + 30, fy - 20), Vector2(pr.position.x + pr.size.x * 0.55, fy - 20), Color(ink, 0.4), 1.0)
	var fw := pr.size.x * 0.55 - 30.0
	if _hover.begins_with("rumor_"):
		var rm2: Array = RUMORS[int(_hover.substr(6))]
		draw_string(tb, Vector2(pr.position.x + 30, fy), str(rm2[1]).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, ink)
		draw_string(tr, Vector2(pr.position.x + 30, fy + 18), "Rumor only. Nobody you know has flown it.", HORIZONTAL_ALIGNMENT_LEFT, fw, 12, UIStyle.INK_FADED)
	elif _hover != "" and systems.has(_hover):
		var sd2: Dictionary = systems[_hover]
		draw_string(tb, Vector2(pr.position.x + 30, fy), str(sd2.get("name", _hover)).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, ink)
		var desc: String = sd2.get("desc", "")
		if _hover == "crossroads":
			desc = "The cork in the bottle. Past the Wall, every lane in the cluster runs through it. Charter papers required."
		draw_multiline_string(tr, Vector2(pr.position.x + 30, fy + 18), desc, HORIZONTAL_ALIGNMENT_LEFT, fw, 12, 2, UIStyle.INK_FADED)
	elif Career.objective:
		draw_string(tb, Vector2(pr.position.x + 30, fy), "CURRENT JOB", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UIStyle.INK_FADED)
		draw_multiline_string(hand, Vector2(pr.position.x + 30, fy + 22), Career.objective["text"], HORIZONTAL_ALIGNMENT_LEFT, fw, 22, 2, UIStyle.INK_PEN)
	else:
		draw_string(tr, Vector2(pr.position.x + 30, fy), "No job on the board. Check a station's board when you dock.", HORIZONTAL_ALIGNMENT_LEFT, fw, 12, UIStyle.INK_FADED)
	draw_string(tr, Vector2(pr.end.x - 230, pr.end.y - 10), "M or Esc to close  ·  J journal", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UIStyle.INK_FADED)


func _dashed(a: Vector2, b: Vector2, col: Color, w: float) -> void:
	var d := b - a
	var n := maxi(2, int(d.length() / 10.0))
	for i in n:
		if i % 2 == 0:
			draw_line(a + d * (float(i) / n), a + d * (float(i + 1) / n), col, w)


func _dashed_rect(r: Rect2, col: Color) -> void:
	_dashed(r.position, Vector2(r.end.x, r.position.y), col, 1.0)
	_dashed(Vector2(r.end.x, r.position.y), r.end, col, 1.0)
	_dashed(r.end, Vector2(r.position.x, r.end.y), col, 1.0)
	_dashed(Vector2(r.position.x, r.end.y), r.position, col, 1.0)


## A dead rift at the rim: a crossed-out circle.
func _dead_rift(p: Vector2) -> void:
	var col := Color(UIStyle.INK_TYPE, 0.55)
	draw_arc(p, 9.0, 0, TAU, 20, col, 1.5, true)
	draw_line(p + Vector2(-6, -6), p + Vector2(6, 6), col, 1.5)
	draw_line(p + Vector2(-6, 6), p + Vector2(6, -6), col, 1.5)


## A pen arrow along the next jump toward the job.
func _pen_route(a: Vector2, b: Vector2) -> void:
	var d := (b - a).normalized()
	var s := a + d * 24.0
	var e := b - d * 24.0
	var n := d.orthogonal() * 6.0
	draw_line(s + n, e + n, UIStyle.INK_PEN, 2.0, true)
	draw_line(e + n, e + n - d.rotated(0.5) * 12.0, UIStyle.INK_PEN, 2.0, true)
	draw_line(e + n, e + n - d.rotated(-0.5) * 12.0, UIStyle.INK_PEN, 2.0, true)
