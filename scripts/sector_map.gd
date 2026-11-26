extends Control
## M: the Charter's chart of the whole cluster. Hesper March, the little pocket
## you know, is inked in detail; the Crossroads sits in the middle like a cork;
## everything past it is fog and pencilled rumor. Stops the clock while open.

var main: Node
var _was_paused := false
var _hover := ""
var _note_hover := -1
var _note_t := 0.0
var _t := 0.0
## Leaning in: wheel zooms toward the cursor, left-drag pans. Zoomed out you read
## the powers' names; zoomed in, their stations and lanes.
const ZOOM_MAX := 2.6
var _zoom := 1.0
var _pan := Vector2.ZERO
var _drag := false
var _names: Control

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
	[Vector2(0.6, 0.075), "League lanes", "merchant houses. tolls on everything"],
	[Vector2(0.82, 0.2), "Remnant holdout?", "old empire colors, they say"],
	[Vector2(0.855, 0.405), "Dynasty heartland", "warlords. don't go."],
	[Vector2(0.575, 0.795), "Free Ports", "pirate country"],
	[Vector2(0.84, 0.84), "the Faithful", "camped at the dead rifts"],
]
## Where the Crossroads' lanes run off into the fog.
const DEAD_RIFTS := [Vector2(0.97, 0.12), Vector2(0.985, 0.62), Vector2(0.9, 0.96), Vector2(0.47, 0.03), Vector2(0.4, 0.97)]
const GRAPHITE := Color(0.36, 0.35, 0.34)


## Pen notes you've made on the chart. Hidden until you hover the pen tick by
## what they're about; the chart stays clean. DRAFT lines.
const PEN_NOTES := [
	# [note at (chart 0..1), text, tilt, flag or "", key, anchor]. The anchor is
	# what the note is about: a system id, "wall", or a chart point.
	[Vector2(0.262, 0.695), "No papers till the 40,000 cr loan is paid", -1.5, "", "wall", "wall"],
	[Vector2(0.44, 0.35), "Papers only past here. Navy turns back the rest.", -2.5, "", "papers", Vector2(0.455, 0.5)],
	[Vector2(0.255, 0.2), "Tallyman hits Charter rigs at the jump exit", 1.5, "tally_hailed", "tally", "marcellus"],
	[Vector2(0.128, 0.515), "Red Stork, near Amber's. 3,000 dead, 4,500 alive", -1.5, "bounty_taken", "lark", "ambers"],
	[Vector2(0.44, 0.925), "Dead rift. %s's grandad flew it before the Severance", -1.5, "friend", "rift", Vector2(0.4, 0.97)],
]

## Who holds what, as best the Charter knows: [centre, radii (chart 0..1), tint,
## strength, name, holder, note]. Faint washes; the hovered one deepens.
const REGIONS := [
	[Vector2(0.19, 0.5), Vector2(0.175, 0.46), Color(0.55, 0.78, 1.0), 0.5, "Federation pocket", "The Federation", "Hesper March and the interior, behind the Wall. Navy patrols, Charter routes.", Vector2(0.19, 0.93)],
	[Vector2(0.205, 0.27), Vector2(0.06, 0.12), Color(0.85, 0.25, 0.25), 0.55, "The Grind", "Contested  ·  pirate clans", "Marcellus belt. Federation on paper; the rocks belong to whoever's armed.", Vector2(-1, -1)],
	[Vector2(0.53, 0.5), Vector2(0.13, 0.25), Color(0.62, 0.62, 0.62), 0.55, "The Crossroads", "The Dynasty", "Every lane in the cluster meets here. Dynasty gate, Dynasty tolls.", Vector2(0.53, 0.385)],
	[Vector2(0.86, 0.5), Vector2(0.11, 0.18), Color(0.2, 0.72, 0.42), 0.4, "Dynasty heartland", "The Dynasty  ·  rumor", "Warlord country on the far side. Nobody you know has been."],
	[Vector2(0.6, 0.15), Vector2(0.15, 0.12), Color(0.68, 0.42, 0.9), 0.4, "League lanes", "The Merchant League  ·  rumor", "Merchant houses on the lane stations. Tolls on everything, they say."],
	[Vector2(0.82, 0.22), Vector2(0.1, 0.13), Color(0.82, 0.66, 0.28), 0.4, "Remnant holdout", "Imperial Remnant  ·  rumor", "Old empire colors, still flying. If it's true."],
	[Vector2(0.58, 0.77), Vector2(0.14, 0.1), Color(0.85, 0.25, 0.25), 0.4, "Free Ports", "Nobody  ·  pirate country", "Free stations, free trade, free fire."],
	[Vector2(0.86, 0.84), Vector2(0.1, 0.12), Color(0.55, 0.42, 0.95), 0.45, "The dead rifts", "The Faithful  ·  rumor", "Zealots camped where the outbound rifts went dark, waiting."],
]

var _sheet: PaperSheet
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
	_sheet = PaperSheet.new({"folds": Vector2(3, 1), "wear": 1.0, "seed": 3.0})
	add_child(_sheet)
	_title_font = FontVariation.new()
	_title_font.base_font = Data.font_bold
	_title_font.spacing_glyph = 6
	_names = Control.new()
	_names.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_names.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_names.draw.connect(_draw_names)
	add_child(_names)


## The dim sits under the sheet as a sibling, so it doesn't turn with it.
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


func open(was_paused = null) -> void:
	if visible or main.pause_menu.visible:
		return
	_was_paused = get_tree().paused if was_paused == null else bool(was_paused)
	if main.journal.visible:
		_was_paused = main.journal.close(true)
	get_tree().paused = true
	visible = true
	_t = 0.0
	_zoom = 1.0
	_pan = Vector2.ZERO
	_drag = false
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
	if event.is_action_pressed("chart"):
		if not main.merchant or main.pause_menu.visible:
			return
		toggle()
		get_viewport().set_input_as_handled()
	elif visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var h := _system_at(event.position)
		if h != _hover:
			_hover = h
			queue_redraw()
		var nh := _note_at(event.position)
		if nh != _note_hover:
			_note_hover = nh
			_note_t = 0.0
		if _drag:
			_pan += get_viewport().get_mouse_position() - _drag_from
			_drag_from = get_viewport().get_mouse_position()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		close()
	elif event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and event.pressed:
		_zoom_at(1.18 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.18)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_drag = event.pressed and _zoom > 1.01
		_drag_from = get_viewport().get_mouse_position()


var _drag_from := Vector2.ZERO


## Zoom by `f`, keeping the point under the cursor where it is on screen.
func _zoom_at(f: float) -> void:
	var z2 := clampf(_zoom * f, 1.0, ZOOM_MAX)
	if is_equal_approx(z2, _zoom):
		return
	var sp := get_viewport().get_mouse_position()
	var piv := size * 0.5
	var m := (sp - _pan - piv) / _zoom
	_pan = sp - piv - m * z2
	_zoom = z2
	queue_redraw()


## How far in you've leaned: 0 = the whole chart, 1 = close enough to read stations.
func _detail() -> float:
	return smoothstep(1.25, 1.75, _zoom)


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	_note_t += delta
	# The sheet comes up off the desk and settles.
	var k := 1.0 - pow(1.0 - clampf(_t / 0.38, 0.0, 1.0), 3.0)
	pivot_offset = size * 0.5
	scale = Vector2.ONE * lerpf(0.94, 1.0, k) * _zoom
	var lim := size * 0.5 * (_zoom - 1.0)
	_pan = _pan.clamp(-lim, lim)
	position = _pan
	_names.modulate.a = 1.0 - _detail()
	_names.queue_redraw()
	rotation = lerpf(-0.035, 0.0, k)
	modulate.a = clampf(_t / 0.2, 0.0, 1.0)
	_dim.modulate.a = modulate.a
	var pr := _paper_rect()
	_sheet.place(pr)
	var c := _chart_rect()
	_sheet.param("fog_from", c.position.x - pr.position.x + c.size.x * 0.4)
	_sheet.param("ring", Vector3(pr.size.x * 0.035, pr.size.y * 0.965, 54.0))
	var rg: Array = []
	var rc: Array = []
	for r in REGIONS:
		rg.append(Vector4(c.position.x - pr.position.x + r[0].x * c.size.x, c.position.y - pr.position.y + r[0].y * c.size.y, r[1].x * c.size.x, r[1].y * c.size.y))
		rc.append(Vector4(r[2].r, r[2].g, r[2].b, r[3]))
	_sheet.param("reg_n", REGIONS.size())
	_sheet.param("reg", rg)
	_sheet.param("regc", rc)
	_sheet.param("reg_hi", _region_of(_hover))
	_sheet.param("reg_edge", 7)
	_sheet.param("reg_clip", Vector4(c.position.x - pr.position.x, c.position.y - pr.position.y, c.size.x, c.size.y))
	queue_redraw()


## How far the ink has come in, for things drawn `delay` seconds after opening.
func _ink(delay := 0.0) -> float:
	var k := clampf((_t - 0.3 - delay) / 0.45, 0.0, 1.0)
	return k * k * (3.0 - 2.0 * k)


func _paper_rect() -> Rect2:
	var ps := Vector2(minf(1260.0, size.x - 60.0), minf(770.0, size.y - 40.0))
	return Rect2((size - ps) * 0.5, ps)


func _chart_rect() -> Rect2:
	var p := _paper_rect()
	return Rect2(p.position + Vector2(44, 112), Vector2(p.size.x - 88, p.size.y - 222))


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
	# Smallest region under the cursor wins (the Grind sits inside the pocket).
	var c := _chart_rect()
	var best := -1
	var best_a := INF
	for i in REGIONS.size():
		var q: Vector2 = (p - _at(REGIONS[i][0])) / (REGIONS[i][1] * c.size)
		var a: float = REGIONS[i][1].x * REGIONS[i][1].y
		if q.length() < 0.95 and a < best_a:
			best = i
			best_a = a
	return "region_%d" % best if best >= 0 else ""


var _net_cache: Array = []


## The rumored jump networks past the Wall: [nodes, links]. Each power's
## network has its own shape, and you can read the politics off it:
##   Dynasty: spokes to a capital, one great road to the Crossroads.
##   League: a single trade line of stations, end to end.
##   Remnant: a ring of fortress systems, hidden: no Crossroads lane, only
##   a back way in from the League and one from the Dynasty.
##   Free Ports: scattered, loose, half the lanes only rumor.
##   Faithful: a short chain running out to the dead rifts.
## nodes: [chart pos, region, kind ("sys", "capital", "hub")];
## links: [from (-1 = Crossroads), to (or Vector2 for a dead rift), kind].
func _net() -> Array:
	if not _net_cache.is_empty():
		return _net_cache
	var nodes: Array = []
	var links: Array = []
	var add := func(v: Vector2, ri: int, kind := "sys") -> int:
		nodes.append([v, ri, kind])
		return nodes.size() - 1
	# Dynasty heartland: capital below its name, six satellites on spokes.
	var cap: int = add.call(Vector2(0.87, 0.62), 3, "capital")
	for k in 6:
		var ang := -PI * 0.5 + TAU * (k + 0.5) / 6.0
		var i: int = add.call(Vector2(0.87, 0.62) + Vector2(cos(ang) * 0.075, sin(ang) * 0.13), 3)
		links.append([cap, i, "spoke"])
	links.append([-1, cap, "road"])
	# The Crossroads: a ring of free stations round the Dynasty gate, every one
	# a toll, a market or a place to hide. (Vishnu 2026-11-26: "add more stations".)
	var ring: Array = []
	for v in [Vector2(0.45, 0.32), Vector2(0.43, 0.47), Vector2(0.465, 0.71), Vector2(0.57, 0.7), Vector2(0.665, 0.6), Vector2(0.64, 0.47)]:
		var ri: int = add.call(v, 2, "hub")
		links.append([-1, ri, "spoke"])
		ring.append(ri)
	for k in ring.size():
		links.append([ring[k], ring[(k + 1) % ring.size()], "local"])
	# A Dynasty fort guarding the Crossroads.
	links.append([-1, add.call(Vector2(0.6, 0.32), 2), "spoke"])
	# League: one long line of lane stations.
	var prev := -1
	for k in 6:
		var t := float(k) / 5.0
		var v := Vector2(lerpf(0.47, 0.705, t), 0.165 + sin(t * PI) * 0.05 + (0.012 if k % 2 else -0.008))
		var i2: int = add.call(v, 4, "hub" if k == 0 else "sys")
		if prev >= 0:
			links.append([prev, i2, "line"])
		prev = i2
	links.append([-1, prev - 5, "trunk"])
	# Remnant: a tight fortress, fully meshed.
	var rem: Array = []
	for v in [Vector2(0.75, 0.11), Vector2(0.885, 0.1), Vector2(0.74, 0.3), Vector2(0.9, 0.29)]:
		rem.append(add.call(v, 5, "fort"))
	for e in [[0, 1], [1, 3], [3, 2], [2, 0]]:
		links.append([rem[e[0]], rem[e[1]], "mesh"])
	# Hidden away: no lane from the Crossroads. You reach the Remnant only
	# through a League station or a Dynasty system, out of your way.
	links.append([prev - 2, rem[0], "local"])
	# Free Ports: scattered, loose.
	var fp: Array = []
	for v in [Vector2(0.46, 0.75), Vector2(0.45, 0.87), Vector2(0.69, 0.75), Vector2(0.72, 0.87), Vector2(0.6, 0.73)]:
		fp.append(add.call(v, 6, "port"))
	links.append([fp[0], fp[1], "rumor"])
	links.append([fp[2], fp[3], "local"])
	links.append([fp[4], fp[2], "local"])
	links.append([-1, fp[0], "trunk"])
	links.append([-1, fp[4], "trunk"])
	# The Faithful: out to the dead rifts.
	var f1: int = add.call(Vector2(0.76, 0.75), 7, "shrine")
	var f2: int = add.call(Vector2(0.95, 0.91), 7, "shrine")
	var f3: int = add.call(Vector2(0.95, 0.76), 7, "shrine")
	links.append([f3, f2, "local"])
	links.append([f2, Vector2(0.9, 0.96), "dead"])
	links.append([f3, Vector2(0.985, 0.62), "dead"])
	links.append([-1, f1, "trunk"])
	# Back roads that skip the Crossroads, if you believe the stories.
	# A Dynasty march system on the Remnant border, with a lane straight in.
	# (Vishnu 2026-11-26.)
	var march: int = add.call(Vector2(0.92, 0.37), 3)
	links.append([rem[3], march, "local"])
	links.append([march, cap + 1, "local"])
	# The Dynasty's south and the Faithful are bound up together, and the
	# Faithful's shrines open onto the Free Ports. (Vishnu's sketch, 2026-11-22.)
	for l in [[fp[1], fp[3]], [cap + 6, cap + 1], [fp[2], f1], [f1, fp[3]], [f1, cap + 5], [f1, cap + 4], [cap + 5, cap + 4],
			[cap + 4, cap + 3], [cap + 3, f3], [cap + 2, f3]]:
		links.append([l[0], l[1], "local"])
	_net_cache = [nodes, links]
	return _net_cache


## Which territory a hover target sits in, for the wash highlight.
const _HOVER_REGION := {"marcellus": 1, "crossroads": 2, "aurelia": 0, "tiberine": 0, "porta_aquila": 0,
		"rumor_0": 4, "rumor_1": 5, "rumor_2": 3, "rumor_3": 6, "rumor_4": 7}


func _region_of(h: String) -> int:
	if h.begins_with("region_"):
		return int(h.substr(7))
	return int(_HOVER_REGION.get(h, -1))


func _all_systems() -> Dictionary:
	var out: Dictionary = Data.systems.duplicate()
	out["crossroads"] = Data.crossroads
	return out


func _draw() -> void:
	var pr := _paper_rect()
	var c := _chart_rect()
	var tb: Font = Data.font_type_bold
	var tr: Font = Data.font_type
	var hand: Font = Data.font_hand
	var ink := UIStyle.INK_TYPE
	var faded := UIStyle.INK_FADED

	# --- Header: the Charter's title block, seal, edition --------------------------
	var hx := pr.position.x + 44.0
	var hy := pr.position.y + 26.0
	draw_line(Vector2(hx, hy), Vector2(pr.end.x - 44, hy), Color(ink, 0.8), 2.0)
	draw_line(Vector2(hx, hy + 4), Vector2(pr.end.x - 44, hy + 4), Color(ink, 0.5), 1.0)
	draw_string(_title_font, Vector2(hx, hy + 46), "THE CLUSTER", HORIZONTAL_ALIGNMENT_LEFT, -1, 40, ink)
	var tw := _title_font.get_string_size("THE CLUSTER", HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x
	draw_string(tb, Vector2(hx + tw + 22, hy + 28), "CHARTER COMPANY ROUTE CHART  ·  No. 61-H", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, ink)
	draw_string(tr, Vector2(hx + tw + 22, hy + 45), "Charter routes in ink. Past the Wall, rumor and pencil.", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, faded)
	draw_string(tr, Vector2(pr.end.x - 290, hy + 28), "OPERATOR'S COPY", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, faded)
	draw_string(tb, Vector2(pr.end.x - 290, hy + 47), "DAY %d" % (int(Career.day) + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, ink)
	_seal(Vector2(pr.end.x - 104, hy + 34), 0.82 * _ink(0.05))
	draw_line(Vector2(hx, hy + 62), Vector2(pr.end.x - 44, hy + 62), Color(ink, 0.5), 1.0)

	# --- The grid and the cluster's edge ----------------------------------------------
	var cols := 12
	var rows := 6
	for i in cols + 1:
		var x := c.position.x + c.size.x * i / cols
		draw_line(Vector2(x, c.position.y), Vector2(x, c.end.y), Color(ink, 0.045), 1.0)
		draw_line(Vector2(x, c.position.y - 5), Vector2(x, c.position.y), Color(ink, 0.5), 1.0)
		draw_line(Vector2(x, c.end.y), Vector2(x, c.end.y + 5), Color(ink, 0.5), 1.0)
		if i < cols:
			var L := String.chr(65 + i)
			draw_string(tr, Vector2(x + c.size.x / cols * 0.5 - 4, c.position.y - 9), L, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, faded)
	for j in rows + 1:
		var y := c.position.y + c.size.y * j / rows
		draw_line(Vector2(c.position.x, y), Vector2(c.end.x, y), Color(ink, 0.045), 1.0)
		draw_line(Vector2(c.position.x - 5, y), Vector2(c.position.x, y), Color(ink, 0.5), 1.0)
		draw_line(Vector2(c.end.x, y), Vector2(c.end.x + 5, y), Color(ink, 0.5), 1.0)
		if j < rows:
			draw_string(tr, Vector2(c.position.x - 16, y + c.size.y / rows * 0.5 + 4), str(j + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, faded)
	draw_rect(c, Color(ink, 0.55), false, 1.0)
	draw_rect(c.grow(4), Color(ink, 0.3), false, 1.0)
	for d in DEAD_RIFTS:
		_dead_rift(_at(d))

	# --- Past the Wall: the networks, pencilled from rumor --------------------------------
	# Each power's systems hang together on their own lanes; every network's
	# trunk runs into the Crossroads. The Federation has none: one gate, the Wall.
	var cx := _sys_pos("crossroads")
	var nodes: Array = _net()[0]
	var links: Array = _net()[1]
	var hr := _region_of(_hover)
	for l in links:
		var pa: Vector2 = cx if l[0] < 0 else _at(nodes[l[0]][0])
		var pb: Vector2 = _at(l[1]) if l[1] is Vector2 else _at(nodes[l[1]][0])
		var ra: int = 2 if l[0] < 0 else nodes[l[0]][1]
		var rb: int = 7 if l[1] is Vector2 else nodes[l[1]][1]
		var hi := hr >= 0 and (hr == ra or hr == rb)
		var m := (1.5 if hi else 1.0) * (0.3 + 0.7 * _detail())
		if l[0] < 0:
			pa += (pb - pa).normalized() * 34.0
		match l[2]:
			"road":
				# The Sultan's road: double-ruled, the only proper highway out here.
				var dn := (pb - pa).normalized().orthogonal() * 2.0
				draw_line(pa + dn, pb + dn, Color(ink, 0.45 * m), 1.1, true)
				draw_line(pa - dn, pb - dn, Color(ink, 0.45 * m), 1.1, true)
			"trunk":
				_dashed(pa, pb, Color(ink, 0.36 * m), 1.5, 9.0)
			"spoke", "line", "local":
				draw_line(pa, pb, Color(GRAPHITE, 0.5 * m), 1.3 if l[2] != "line" else 1.8, true)
			"mesh":
				draw_line(pa, pb, Color(GRAPHITE, 0.4 * m), 1.0, true)
			"rumor":
				_dashed(pa, pb, Color(GRAPHITE, 0.32 * m), 1.0, 3.0)
			"dead":
				_dashed(pa, pb, Color(UIStyle.INK_STAMP, 0.35 * m), 1.0, 4.0)
	for n in nodes:
		_net_glyph(_at(n[0]), str(n[2]), hr == n[1])
	# Hatching where nobody you know has been.
	var x0 := _at(Vector2(0.4, 0)).x
	var hxx := x0
	while hxx < c.end.x + c.size.y:
		var a := Vector2(hxx, c.position.y)
		var b := Vector2(hxx - c.size.y, c.end.y)
		if b.x < x0:
			b = b.lerp(a, (x0 - b.x) / (a.x - b.x))
		if a.x > c.end.x:
			a = a.lerp(b, (a.x - c.end.x) / (a.x - b.x))
		draw_line(a, b, Color(UIStyle.INK_TYPE, 0.045), 1.0)
		hxx += 11.0
	# Rumors, pencilled in by someone who's never been either.
	for i in RUMORS.size():
		var rm: Array = RUMORS[i]
		var p := _at(rm[0])
		var hov := _hover == "rumor_%d" % i
		var k := _ink(0.35 + i * 0.07)
		k *= _detail()
		var w := hand.get_string_size(rm[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
		draw_string(hand, p - Vector2(w * 0.5, 0), rm[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(GRAPHITE, (0.95 if hov else 0.72) * k))
		var w2 := hand.get_string_size(rm[2], HORIZONTAL_ALIGNMENT_LEFT, -1, 21).x
		draw_string(hand, p + Vector2(-w2 * 0.5, 21), rm[2], HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color(GRAPHITE, 0.58 * k))
		if hov:
			_scribble_ring(p + Vector2(0, 4), Vector2(w * 0.5 + 18, 30), UIStyle.INK_PEN, 1.6, 1.0, i)
	_compass(_at(Vector2(0.945, 0.15)), 30.0)

	# --- The Federation pocket ------------------------------------------------------------
	var fed := PackedVector2Array()
	for k in 96:
		var ang := TAU * k / 96.0
		fed.append(_at(Vector2(0.19, 0.5) + Vector2(cos(ang) * 0.17, sin(ang) * 0.45)))
	# A pale printed wash with a fine dash-dot border, like a political map.
	draw_colored_polygon(fed, Color(UIStyle.INK_PEN, 0.035))
	for k in fed.size():
		if k % 3 != 2:
			draw_line(fed[k], fed[(k + 1) % fed.size()].lerp(fed[k], 0.35 if k % 3 == 1 else 0.0), Color(UIStyle.INK_TYPE, 0.3), 1.0, true)
	var fl := "FEDERATION"
	var flw := tb.get_string_size(fl, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	var flp := _at(Vector2(0.19, 0.05)) + Vector2(-flw * 0.5, 4)
	draw_rect(Rect2(flp + Vector2(-6, -12), Vector2(flw + 12, 16)), UIStyle.PAPER)
	draw_string(tb, flp, fl, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(UIStyle.INK_TYPE, 0.6))
	for d in FED_DOTS:
		draw_circle(_at(d), 3.5, Color(ink, 0.5))
		draw_arc(_at(d), 6.0, 0, TAU, 16, Color(ink, 0.25), 1.0, true)

	# --- Hesper March: the routes you fly -------------------------------------------------
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
				_dashed(a2 + (b2 - a2).normalized() * 26.0, b2 - (b2 - a2).normalized() * 34.0, Color(UIStyle.INK_STAMP, 0.85), 2.5)
				var mid := (a2 + b2) * 0.5
				draw_string(tb, mid + Vector2(-38, 19), "PAPERS ONLY", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UIStyle.INK_STAMP)
			else:
				# A Charter lane: double-ruled, like a road on an old map.
				var dn := (b2 - a2).normalized().orthogonal() * 2.2
				draw_line(a2 + dn, b2 + dn, Color(ink, 0.8), 1.2, true)
				draw_line(a2 - dn, b2 - dn, Color(ink, 0.8), 1.2, true)
	draw_string(tb, _at(Vector2(0.03, 0.065)) + Vector2(0, 30), "HESPER MARCH", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, ink)
	draw_string(tr, _at(Vector2(0.03, 0.065)) + Vector2(0, 46), "\"the Long Haul\"  ·  Charter sector", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, faded)

	var obj_station: String = Career.objective.get("station", "") if Career.objective else ""
	var obj_sys: String = Data.stations[obj_station]["system"] if Data.stations.has(obj_station) else ""
	var route_next: String = Career.next_hop(Career.system_id, obj_sys) if obj_sys != "" else ""
	if route_next != "":
		_pen_route(_sys_pos(Career.system_id), _sys_pos(route_next), _ink(0.6))

	for id in Data.systems:
		var sd: Dictionary = Data.systems[id]
		var p := _sys_pos(id)
		var rough: bool = sd.get("security", "") == "Rough"
		var col := UIStyle.INK_STAMP if rough else ink
		var rad := 16.0
		var n_st := 0
		for st_id2 in Data.stations:
			if Data.stations[st_id2]["system"] == id:
				n_st += 1
		_system_glyph(p, rad, col, n_st, id == _hover, rough, id.hash())
		if id == "porta_aquila":
			# The fortress gate: a heavy bar across the way out.
			draw_rect(Rect2(p + Vector2(22, -18), Vector2(6, 36)), ink)
			draw_rect(Rect2(p + Vector2(30, -18), Vector2(2, 36)), ink)
			draw_string(tb, p + Vector2(-26, -28), "THE WALL", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, ink)
		var nm: String = sd["name"].to_upper()
		var nw := tb.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		var sub: String = "%s  ·  %s" % [sd["nick"], sd["security"]]
		var sw := tr.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		var bw := maxf(maxf(nw, sw), 70.0) + 12.0
		draw_rect(Rect2(p + Vector2(-bw * 0.5, rad + 4), Vector2(bw, 30 + n_st * 13)), Color(UIStyle.PAPER, 0.9))
		draw_string(tb, p + Vector2(-nw * 0.5, rad + 17), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, col if rough else ink)
		draw_string(tr, p + Vector2(-sw * 0.5, rad + 29), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, faded)
		var y := rad + 42.0
		for st_id in Data.stations:
			var st: Dictionary = Data.stations[st_id]
			if st["system"] != id:
				continue
			var label: String = st["nick"]
			var lw := tr.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
			draw_string(tr, p + Vector2(-lw * 0.5, y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, ink)
			if st_id == obj_station:
				var k := _ink(0.9)
				var xp := p + Vector2(lw * 0.5 + 10, y - 4)
				draw_line(xp + Vector2(-5, -5), xp + Vector2(-5, -5).lerp(Vector2(5, 5), k), UIStyle.INK_PEN, 2.6, true)
				if k > 0.5:
					draw_line(xp + Vector2(-5, 5), xp + Vector2(-5, 5).lerp(Vector2(5, -5), k * 2.0 - 1.0), UIStyle.INK_PEN, 2.6, true)
				_pen_underline(p + Vector2(-lw * 0.5 - 2, y + 4), lw + 4, k, st_id.hash())
			y += 13.0
		if Career.visited.has(id) and id != Career.system_id:
			var tk := p + Vector2(rad + 2, -rad + 1)
			draw_polyline(PackedVector2Array([tk + Vector2(-5, -2), tk + Vector2(-1, 3), tk + Vector2(7, -8)]), UIStyle.INK_PEN, 2.2, true)
		if id == Career.system_id:
			var k2 := _ink(0.45)
			var pts := PackedVector2Array()
			var n := int(34 * k2)
			for i in n:
				var ang := -0.4 + TAU * 1.08 * i / 33.0
				pts.append(p + Vector2(cos(ang), sin(ang)) * (rad + 8.0 + sin(i * 0.9) * 1.6))
			if pts.size() > 1:
				draw_polyline(pts, UIStyle.INK_PEN, 2.0, true)
			draw_string(hand, p + Vector2(-rad - 78, -rad - 4), "you're here", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(UIStyle.INK_PEN, k2))

	# --- The Crossroads: printed big, right in the way ----------------------------------
	var hov_c := _hover == "crossroads"
	draw_circle(cx, 26.0, UIStyle.PAPER)
	draw_arc(cx, 26.0, 0, TAU, 48, ink, 2.6 if hov_c else 2.0, true)
	_dashed_arc(cx, 33.0, Color(ink, 0.5))
	draw_arc(cx, 40.0, 0, TAU, 48, Color(ink, 0.18), 1.0, true)
	draw_string(_title_font, cx + Vector2(-7, 9), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, ink)
	var cn := "THE CROSSROADS"
	var cnw := tb.get_string_size(cn, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	var cs := "Dynasty gate  ·  every road meets here"
	var csw := tr.get_string_size(cs, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	var bw := maxf(cnw, csw)
	draw_rect(Rect2(cx + Vector2(-bw * 0.5 - 8, 44), Vector2(bw + 16, 36)), Color(UIStyle.PAPER, 0.92))
	draw_string(tb, cx + Vector2(-cnw * 0.5, 60), cn, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, ink)
	draw_string(tr, cx + Vector2(-csw * 0.5, 74), cs, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, faded)

	# --- Your own pen: a tick by each thing you've noted; hover it to read -------------
	var ka := _ink(1.0)
	for n in _notes():
		var i: int = n[0]
		var pn: Array = PEN_NOTES[i]
		if i == _note_hover:
			# The note opens beside its tick, like a scrap tucked under the chart's edge.
			var tq := _note_tick(i)
			var nw := Data.font_hand.get_string_size(n[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
			var at := tq + Vector2(18, -14)
			if at.x + nw + 30.0 > c.end.x:
				at.x = tq.x - 18.0 - nw
			if at.y - 30.0 < c.position.y:
				at.y = tq.y + 34.0
			_callout(at, n[1], pn[2], pn[5], clampf(_note_t / 0.3, 0.0, 1.0), i, str(pn[4]))
		elif ka > 0.0:
			_pen_tick(_note_tick(i), ka)

	# --- Footer: a typed slip, the legend, the fine print --------------------------------
	var fy := c.end.y + 30.0
	var fx := pr.position.x + 44.0
	var fw := pr.size.x * 0.5
	var ri := _region_of(_hover)
	if _hover.begins_with("region_") or _hover.begins_with("rumor_"):
		var rgn: Array = REGIONS[ri]
		draw_rect(Rect2(Vector2(fx, fy - 11), Vector2(12, 12)), Color(rgn[2], 0.85))
		draw_string(tb, Vector2(fx + 20, fy), str(rgn[4]).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, ink)
		var nw2 := tb.get_string_size(str(rgn[4]).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		draw_string(tr, Vector2(fx + 34 + nw2, fy), "held by  " + str(rgn[5]), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UIStyle.INK_STAMP if "rumor" in str(rgn[5]) else UIStyle.INK_PEN)
		draw_string(tr, Vector2(fx, fy + 18), str(rgn[6]), HORIZONTAL_ALIGNMENT_LEFT, fw, 12, faded)
	elif _hover != "" and systems.has(_hover):
		var sd2: Dictionary = systems[_hover]
		draw_string(tb, Vector2(fx, fy), str(sd2.get("name", _hover)).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, ink)
		if ri >= 0:
			var sn := tb.get_string_size(str(sd2.get("name", _hover)).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
			draw_rect(Rect2(Vector2(fx + sn + 14, fy - 11), Vector2(12, 12)), Color(REGIONS[ri][2], 0.85))
			draw_string(tr, Vector2(fx + sn + 32, fy), "held by  " + str(REGIONS[ri][5]), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UIStyle.INK_PEN)
		var desc: String = sd2.get("desc", "")
		if _hover == "crossroads":
			desc = "The cork in the bottle. Past the Wall, every lane in the cluster runs through it. Charter papers required."
		draw_multiline_string(tr, Vector2(fx, fy + 18), desc, HORIZONTAL_ALIGNMENT_LEFT, fw, 12, 2, faded)
	elif Career.objective:
		draw_string(tb, Vector2(fx, fy), "CURRENT JOB", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, faded)
		draw_multiline_string(hand, Vector2(fx, fy + 24), Career.objective["text"], HORIZONTAL_ALIGNMENT_LEFT, fw, 24, 2, Color(UIStyle.INK_PEN, _ink(0.2)))
	else:
		draw_string(tr, Vector2(fx, fy), "No job on the board. Check a station's board when you dock.", HORIZONTAL_ALIGNMENT_LEFT, fw, 12, faded)
	# Legend.
	var lx := pr.position.x + pr.size.x * 0.6
	var ly := fy - 8.0
	var dn2 := Vector2(0, 2.2)
	draw_line(Vector2(lx, ly) + dn2, Vector2(lx + 26, ly) + dn2, ink, 1.2)
	draw_line(Vector2(lx, ly) - dn2, Vector2(lx + 26, ly) - dn2, ink, 1.2)
	draw_string(tr, Vector2(lx + 32, ly + 4), "Charter lane", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, ink)
	_dashed(Vector2(lx + 120, ly), Vector2(lx + 146, ly), UIStyle.INK_STAMP, 2.0, 6.0)
	draw_string(tr, Vector2(lx + 152, ly + 4), "papers only", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, ink)
	_dead_rift(Vector2(lx + 248, ly))
	draw_string(tr, Vector2(lx + 262, ly + 4), "dead rift", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, ink)
	draw_arc(Vector2(lx + 342, ly), 7.0, 0, TAU, 16, UIStyle.INK_STAMP, 1.5, true)
	draw_string(tr, Vector2(lx + 354, ly + 4), "rough", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, ink)
	# Scale bar, of a sort.
	var sy := ly + 20.0
	for i in 4:
		draw_rect(Rect2(Vector2(lx + i * 40, sy - 3), Vector2(40, 6)), ink if i % 2 == 0 else UIStyle.PAPER)
	draw_rect(Rect2(Vector2(lx, sy - 3), Vector2(160, 6)), ink, false, 1.0)
	for i in 3:
		draw_string(tr, Vector2(lx + i * 80 - 3, sy + 15), str(i), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, ink)
	draw_string(tr, Vector2(lx + 172, sy + 4), "jumps  ·  not to scale. nothing out here is.", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, faded)
	draw_string(tb, Vector2(lx, sy + 34), "THE SEVERANCE", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, ink)
	draw_string(tr, Vector2(lx + 110, sy + 34), "outbound rifts, dark seventy years. Cause unknown.", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, faded)
	draw_string(tr, Vector2(pr.position.x + 44, pr.end.y - 14), "PROPERTY OF THE CHARTER COMPANY  ·  CHART 61-H  ·  ANNOTATION VOIDS LIEN WARRANTY  ·  DO NOT FOLD", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(faded, 0.85))
	draw_string(tr, Vector2(pr.end.x - 210, pr.end.y - 14), "Wheel zoom   drag pan   M close", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, faded)
	_tape(pr.position + Vector2(18, 14), -0.7)
	_tape(Vector2(pr.end.x - 18, pr.position.y + 14), 0.7)
	_tape(Vector2(pr.position.x + 20, pr.end.y - 12), 0.75)
	_tape(pr.end - Vector2(20, 12), -0.68)


## The notes you've earned: [index, text].
func _notes() -> Array:
	var out: Array = []
	for i in PEN_NOTES.size():
		var pn: Array = PEN_NOTES[i]
		var cond: String = pn[3]
		var text: String = pn[1]
		if cond == "friend":
			if not Career.friend.get("met", false):
				continue
			text = text % str(Career.friend.get("name", "Dez"))
		elif cond != "" and not _flag(cond):
			continue
		if pn[4] == "lark" and _flag("bounty_paid"):
			text = "Red Stork: bounty paid"
		if pn[4] == "wall" and Career.loan_balance <= 0:
			text = "Loan paid. Papers stamped."
		out.append([i, text])
	return out


## Where a note's pen tick sits: just off the top right of its target.
func _note_tick(i: int) -> Vector2:
	var tgt: Array = _callout_target(PEN_NOTES[i][5])
	if str(PEN_NOTES[i][5]) == "ambers":
		return tgt[0] + Vector2(72, 0)
	return tgt[0] + Vector2(tgt[1].x * 0.8 + 7.0, -tgt[1].y * 0.8 - 7.0)


func _note_at(p: Vector2) -> int:
	if not visible:
		return -1
	for n in _notes():
		var i: int = n[0]
		var tgt: Array = _callout_target(PEN_NOTES[i][5])
		if p.distance_to(_note_tick(i)) < 16.0 or ((p - tgt[0]) / (tgt[1] + Vector2(6, 6))).length() < 1.0:
			return i
	return -1


## A small pen asterisk: "I wrote something about this."
func _pen_tick(q: Vector2, k: float) -> void:
	var col := Color(UIStyle.INK_PEN, 0.85 * k)
	draw_circle(q, 8.5, Color(UIStyle.PAPER, 0.7 * k))
	for j in 3:
		var a := 0.3 + j * PI / 3.0
		var d := Vector2(cos(a), sin(a)) * 5.5
		draw_line(q - d, q + d, col, 1.6, true)


func _flag(k: String) -> bool:
	return bool(Career.flags.get(k, false))


## A system: a sun, its stations on a ring around it, a printed circle.
## Where a note points, and how big a ring to draw round it.
func _callout_target(anchor) -> Array:
	if anchor is Vector2:
		return [_at(anchor), Vector2(13, 13)]
	match str(anchor):
		"wall":
			return [_sys_pos("porta_aquila") + Vector2(28, 0), Vector2(11, 26)]
		"ambers":
			# The Amber's line in Marcellus's station list.
			return [_sys_pos("marcellus") + Vector2(0, 16.0 + 42.0 + 22.0), Vector2(34, 10)]
	return [_sys_pos(str(anchor)), Vector2(27, 27)]


## A pen callout: the note on a clean scrap of paper, a ring round its target,
## and a bowed leader joining them. Everything draws in with `k`.
func _callout(at: Vector2, text: String, tilt_deg: float, anchor, k: float, sd: int, key: String) -> void:
	var hand: Font = Data.font_hand
	var pen := UIStyle.INK_PEN
	var sz := 24
	var w := hand.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
	var tf := Transform2D(deg_to_rad(tilt_deg), at)
	var tgt: Array = _callout_target(anchor)
	var t: Vector2 = tgt[0]
	var rr: Vector2 = tgt[1]
	# Leave from whichever side of the note faces the target.
	var best := Vector2.ZERO
	var bd := INF
	for lp in [Vector2(-8, -7), Vector2(w + 8, -7), Vector2(w * 0.5, -24), Vector2(w * 0.5, 8),
			Vector2(w * 0.15, -24), Vector2(w * 0.85, -24), Vector2(w * 0.15, 8), Vector2(w * 0.85, 8)]:
		var q: Vector2 = tf * lp
		if q.distance_to(t) < bd:
			bd = q.distance_to(t)
			best = q
	var dir := (best - t).normalized()
	var ring_edge := t + Vector2(dir.x * rr.x, dir.y * rr.y).normalized() * Vector2(dir.x * rr.x, dir.y * rr.y).length() * 1.05
	# Ring first, then the leader, then the note on its scrap.
	_scribble_ring(t, rr, Color(pen, 0.85), 1.6, clampf(k * 1.6, 0.0, 1.0), sd * 7 + 3)
	if k > 0.35:
		var lk := clampf((k - 0.35) / 0.65, 0.0, 1.0)
		var mid := (best + ring_edge) * 0.5 + (ring_edge - best).orthogonal().normalized() * minf(14.0, best.distance_to(ring_edge) * 0.15)
		var pts := PackedVector2Array()
		for j in 13:
			var u := float(j) / 12.0 * lk
			pts.append(best.lerp(mid, u).lerp(mid.lerp(ring_edge, u), u))
		draw_polyline(pts, Color(pen, 0.8), 1.4, true)
		draw_circle(best, 2.0, Color(pen, 0.85))
	draw_set_transform_matrix(tf)
	draw_rect(Rect2(Vector2(-2, -18), Vector2(w + 12, 30)), Color(0, 0, 0, 0.18 * k))
	draw_rect(Rect2(Vector2(-6, -22), Vector2(w + 12, 30)), Color(UIStyle.PAPER, 0.97 * k))
	draw_string(hand, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, w * k + 1.0, sz, Color(pen, 0.95))
	if key == "tally":
		_tally(Vector2(w + 14, -18), 7, k)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A rumored system, drawn in the mark its power would use.
func _net_glyph(q: Vector2, kind: String, hi: bool) -> void:
	var col := Color(GRAPHITE, (1.0 if hi else 0.78) * (0.35 + 0.65 * _detail()))
	match kind:
		"capital":
			# An eight-point star: the Dynasty's seat.
			var pts := PackedVector2Array()
			for i in 16:
				var a := -PI * 0.5 + TAU * i / 16.0
				pts.append(q + Vector2(cos(a), sin(a)) * (9.0 if i % 2 == 0 else 4.0))
			draw_colored_polygon(pts, UIStyle.PAPER)
			pts.append(pts[0])
			draw_polyline(pts, col, 1.4, true)
			draw_circle(q, 2.0, col)
		"sys":
			# Dynasty / League holdings: a small diamond.
			var d := PackedVector2Array([q + Vector2(0, -5), q + Vector2(5, 0), q + Vector2(0, 5), q + Vector2(-5, 0), q + Vector2(0, -5)])
			draw_colored_polygon(d, UIStyle.PAPER)
			draw_polyline(d, col, 1.3, true)
		"hub":
			draw_circle(q, 5.0, UIStyle.PAPER)
			draw_arc(q, 5.0, 0, TAU, 16, col, 1.4, true)
			draw_circle(q, 2.2, col)
		"fort":
			# Remnant: a square keep.
			draw_rect(Rect2(q - Vector2(5, 5), Vector2(10, 10)), UIStyle.PAPER)
			draw_rect(Rect2(q - Vector2(5, 5), Vector2(10, 10)), col, false, 1.4)
			draw_rect(Rect2(q - Vector2(2, 2), Vector2(4, 4)), col)
		"port":
			draw_circle(q, 4.5, UIStyle.PAPER)
			draw_arc(q, 4.5, 0, TAU, 14, col, 1.2, true)
		"shrine":
			# The Faithful: a small upward triangle.
			var t := PackedVector2Array([q + Vector2(0, -6), q + Vector2(5.5, 4), q + Vector2(-5.5, 4), q + Vector2(0, -6)])
			draw_colored_polygon(t, UIStyle.PAPER)
			draw_polyline(t, col, 1.3, true)
		_:
			draw_circle(q, 4.0, UIStyle.PAPER)
			draw_arc(q, 4.0, 0, TAU, 14, col, 1.2, true)


func _system_glyph(p: Vector2, rad: float, col: Color, n_st: int, hov: bool, rough: bool, sd: int) -> void:
	draw_circle(p, rad, UIStyle.PAPER)
	if rough:
		for k in range(-3, 4):
			var o := k * 4.5
			var h := sqrt(maxf(0.0, rad * rad - o * o)) * 0.85
			draw_line(p + Vector2(o - h * 0.5, h * 0.5), p + Vector2(o + h * 0.5, -h * 0.5), Color(col, 0.22), 1.0)
	draw_arc(p, rad, 0, TAU, 40, col, 2.6 if hov else 1.8, true)
	draw_arc(p, 9.5, 0, TAU, 28, Color(col, 0.45), 1.0, true)
	draw_circle(p, 3.2, col)
	for i in n_st:
		var ang := float(sd % 100) * 0.1 + TAU * i / maxf(1.0, n_st)
		var q := p + Vector2(cos(ang), sin(ang)) * 9.5
		draw_circle(q, 2.4, UIStyle.PAPER)
		draw_circle(q, 1.8, col)
	if hov:
		_scribble_ring(p, Vector2(rad + 9, rad + 9), UIStyle.INK_PEN, 1.6, 1.0, sd)


## The Charter's route-office seal, stamped a little crooked.
func _seal(c: Vector2, a: float) -> void:
	if a <= 0.0:
		return
	var col := Color(UIStyle.INK_STAMP, a)
	draw_set_transform(c, deg_to_rad(-9.0), Vector2.ONE)
	draw_arc(Vector2.ZERO, 36.0, 0, TAU, 48, col, 2.4, true)
	draw_arc(Vector2.ZERO, 26.0, 0, TAU, 40, col, 1.2, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_ring_text(c, 29.5, "THE CHARTER COMPANY · ROUTE OFFICE · ", 8, col, deg_to_rad(-9.0) - PI * 0.5)
	draw_set_transform(c, deg_to_rad(-9.0), Vector2.ONE)
	var w := Data.font_stamp.get_string_size("CC", HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	draw_string(Data.font_stamp, Vector2(-w * 0.5, 7), "CC", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, col)
	draw_string(Data.font_type_bold, Vector2(-9, 18), "61", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


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


## A plain printed compass rose. Charter convention puts the core at north.
func _compass(c: Vector2, r: float) -> void:
	var ink := UIStyle.INK_TYPE
	draw_circle(c, r + 8.0, Color(UIStyle.PAPER, 0.85))
	draw_arc(c, r + 4.0, 0, TAU, 48, Color(ink, 0.6), 1.0, true)
	draw_arc(c, r * 0.42, 0, TAU, 32, Color(ink, 0.5), 1.0, true)
	for i in 8:
		var ang := -PI * 0.5 + TAU * i / 8.0
		var long := r if i % 2 == 0 else r * 0.58
		var tip := c + Vector2(cos(ang), sin(ang)) * long
		var side := Vector2(cos(ang + PI * 0.5), sin(ang + PI * 0.5)) * (5.0 if i % 2 == 0 else 3.5)
		draw_colored_polygon(PackedVector2Array([c, tip, c + side]), ink)
		draw_colored_polygon(PackedVector2Array([c, tip, c - side]), UIStyle.PAPER)
		draw_polyline(PackedVector2Array([c + side, tip, c - side]), Color(ink, 0.8), 1.0, true)
	for i in 32:
		var ang := TAU * i / 32.0
		var d := Vector2(cos(ang), sin(ang))
		draw_line(c + d * (r + 4.0), c + d * (r + (1.0 if i % 4 else 7.0)), Color(ink, 0.6), 1.0)
	draw_string(Data.font_type_bold, c + Vector2(-4, -r - 9), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, ink)
	draw_string(Data.font_type, c + Vector2(-30, r + 22), "core-ward", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, UIStyle.INK_FADED)


## A pen ring, loose and a little overdrawn.
func _scribble_ring(c: Vector2, r: Vector2, col: Color, w: float, k: float, sd: int) -> void:
	var pts := PackedVector2Array()
	var n := int(40 * k)
	for i in n:
		var ang := -0.5 + TAU * 1.1 * i / 39.0
		var wob := 1.0 + 0.04 * sin(i * 0.7 + sd)
		pts.append(c + Vector2(cos(ang) * r.x, sin(ang) * r.y) * wob)
	if pts.size() > 1:
		draw_polyline(pts, col, w, true)


func _pen_underline(at: Vector2, w: float, k: float, sd: int) -> void:
	if k <= 0.0:
		return
	var pts := PackedVector2Array()
	for i in 9:
		var t := float(i) / 8.0 * k
		pts.append(at + Vector2(w * t, sin(t * 6.0 + sd) * 1.2 + t * 1.5))
	draw_polyline(pts, UIStyle.INK_PEN, 1.6, true)


## A pen arrow from a note to what it's about, slightly bowed.
func _pen_arrow(a: Vector2, b: Vector2, k: float) -> void:
	if k <= 0.0:
		return
	var mid := (a + b) * 0.5 + (b - a).orthogonal().normalized() * 18.0
	var pts := PackedVector2Array()
	for i in 13:
		var t := float(i) / 12.0 * k
		pts.append(a.lerp(mid, t).lerp(mid.lerp(b, t), t))
	draw_polyline(pts, UIStyle.INK_PEN, 1.8, true)
	if k >= 1.0:
		var d := (b - mid).normalized()
		draw_line(b, b - d.rotated(0.45) * 11.0, UIStyle.INK_PEN, 1.8, true)
		draw_line(b, b - d.rotated(-0.45) * 11.0, UIStyle.INK_PEN, 1.8, true)


## Tally marks in pen: fives struck through.
func _tally(at: Vector2, n: int, k: float) -> void:
	var shown := int(ceil(n * k))
	for i in shown:
		var grp := i / 5
		var j := i % 5
		var x := at.x + grp * 34.0 + j * 6.0
		if j < 4:
			draw_line(Vector2(x, at.y), Vector2(x + 1.5, at.y + 18), UIStyle.INK_PEN, 1.8, true)
		else:
			var gx := at.x + grp * 34.0
			draw_line(Vector2(gx - 4, at.y + 14), Vector2(gx + 24, at.y + 3), UIStyle.INK_PEN, 1.8, true)


## A strip of yellowed tape across a corner.
func _tape(c: Vector2, ang: float) -> void:
	var L := 92.0
	var W := 26.0
	var pts := PackedVector2Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(c.x * 7.0 + c.y)
	pts.append(Vector2(-L * 0.5, -W * 0.5))
	pts.append(Vector2(L * 0.5, -W * 0.5))
	for i in range(1, 6):
		pts.append(Vector2(L * 0.5 + rng.randf_range(-3.0, 3.0), -W * 0.5 + W * i / 6.0))
	pts.append(Vector2(L * 0.5, W * 0.5))
	pts.append(Vector2(-L * 0.5, W * 0.5))
	for i in range(5, 0, -1):
		pts.append(Vector2(-L * 0.5 + rng.randf_range(-3.0, 3.0), -W * 0.5 + W * i / 6.0))
	var xf := Transform2D(ang, c)
	var poly := xf * pts
	draw_colored_polygon(poly, Color(0.92, 0.87, 0.62, 0.5))
	var closed := poly.duplicate()
	closed.append(poly[0])
	draw_polyline(closed, Color(0.6, 0.52, 0.3, 0.22), 1.0, true)
	draw_line(xf * Vector2(-L * 0.5, -W * 0.5 + 3), xf * Vector2(L * 0.5, -W * 0.5 + 3), Color(1, 1, 1, 0.18), 2.0)


func _dashed_arc(c: Vector2, r: float, col: Color) -> void:
	for i in 24:
		var a0 := TAU * i / 24.0
		draw_arc(c, r, a0, a0 + TAU / 48.0, 4, col, 1.2, true)


func _dashed(a: Vector2, b: Vector2, col: Color, w: float, dash := 10.0) -> void:
	var d := b - a
	var n := maxi(2, int(d.length() / dash))
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


## A pen arrow along the next jump toward the job, drawn in as the sheet opens.
func _pen_route(a: Vector2, b: Vector2, k: float) -> void:
	if k <= 0.0:
		return
	var d := (b - a).normalized()
	var n := d.orthogonal() * 8.0
	var s := a + d * 26.0 + n
	var e := b - d * 26.0 + n
	var pts := PackedVector2Array()
	for i in 17:
		var t := float(i) / 16.0 * k
		pts.append(s.lerp(e, t) + n * 0.4 * sin(t * PI))
	draw_polyline(pts, UIStyle.INK_PEN, 2.2, true)
	if k >= 1.0:
		draw_line(e, e - d.rotated(0.5) * 13.0, UIStyle.INK_PEN, 2.2, true)
		draw_line(e, e - d.rotated(-0.5) * 13.0, UIStyle.INK_PEN, 2.2, true)


## Zoomed out: each power's name, big and faint across its ground, letters spaced
## like a printed atlas. Fades as you lean in.
func _draw_names() -> void:
	if _names.modulate.a <= 0.01:
		return
	var big: Font = Data.font_bold
	var k := _ink(0.3)
	for spot in _label_spots():
		var x: float = spot["rect"].position.x
		var y: float = spot["base"]
		for ch in str(spot["text"]):
			_names.draw_string(big, Vector2(x, y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, spot["size"], Color(0.16, 0.15, 0.14, 0.55 * k))
			x += big.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, spot["size"]).x + spot["gap"]


var _spots_cache: Array = []
var _spots_for := Rect2()


## Where each territory's big name goes, the way a cartographer sets type: near
## where we asked for it, but never over a system, a printed label, the compass
## or another name, and crossing as few lanes as it can. Placed once per size.
func _label_spots() -> Array:
	var c := _chart_rect()
	if c == _spots_for and not _spots_cache.is_empty():
		return _spots_cache
	var big: Font = Data.font_bold
	# Things type must not sit on.
	var keep: Array = []
	var dot := func(q: Vector2, r: float): keep.append(Rect2(q - Vector2(r, r), Vector2(r, r) * 2.0))
	var nodes: Array = _net()[0]
	for n in nodes:
		dot.call(_at(n[0]), 9.0)
	for d in DEAD_RIFTS:
		dot.call(_at(d), 12.0)
	for d in FED_DOTS:
		dot.call(_at(d), 8.0)
	for id in LAYOUT:
		dot.call(_at(LAYOUT[id]), 44.0 if id == "crossroads" else 24.0)
	var cx := _sys_pos("crossroads")
	keep.append(Rect2(cx + Vector2(-135, 40), Vector2(270, 44)))
	dot.call(_at(Vector2(0.945, 0.15)), 44.0)
	for i in PEN_NOTES.size():
		dot.call(_note_tick(i), 12.0)
	# Lanes, as short segments.
	var segs: Array = []
	for l in _net()[1]:
		var pa: Vector2 = cx if l[0] < 0 else _at(nodes[l[0]][0])
		var pb: Vector2 = _at(l[1]) if l[1] is Vector2 else _at(nodes[l[1]][0])
		segs.append([pa, pb])
	var out: Array = []
	for ri in REGIONS.size():
		var r: Array = REGIONS[ri]
		var lp: Vector2 = r[7] if r.size() > 7 else r[0]
		if lp.x < 0.0:
			continue
		var nm: String = str(r[4]).to_upper()
		var room: float = r[1].x * c.size.x * 1.7
		var sz := 30
		var gap := 6.0
		var w := _tracked_w(big, nm, sz, gap)
		if w > room:
			sz = maxi(14, int(sz * room / w))
			gap = 3.0
			w = _tracked_w(big, nm, sz, gap)
		var h := float(sz) * 0.75
		var best := Rect2()
		var best_score := INF
		var home := _at(lp)
		for iy in range(-12, 13):
			for ix in range(-6, 7):
				var at := home + Vector2(ix * c.size.x * 0.01, iy * c.size.y * 0.01)
				var rect := Rect2(at - Vector2(w * 0.5, h * 0.5), Vector2(w, h))
				if not c.grow(-6.0).encloses(rect):
					continue
				var pad := rect.grow(6.0)
				var score := at.distance_to(home) / 12.0
				# Type stays inside its own territory, clear of the border.
				for q in [rect.position, rect.end, Vector2(rect.position.x, rect.end.y), Vector2(rect.end.x, rect.position.y), rect.get_center()]:
					if _owner_at((q - c.position) / c.size, 0.06) != ri:
						score += 100.0
				for o in keep:
					if pad.intersects(o):
						score += 100.0
				for sg in segs:
					for t in 9:
						if pad.has_point(sg[0].lerp(sg[1], (t + 0.5) / 9.0)):
							score += 0.6
							break
				if score < best_score:
					best_score = score
					best = rect
		keep.append(best)
		out.append({"text": nm, "rect": best, "base": best.end.y - h * 0.5 + sz * 0.35, "size": sz, "gap": gap})
	_spots_for = c
	_spots_cache = out
	return out


## Which territory holds a chart point, by the wash's own distance rule
## (noise left out). -1 when it sits within `margin` of a border.
func _owner_at(v: Vector2, margin: float) -> int:
	var best := -1
	var d1 := INF
	var d2 := INF
	for i in REGIONS.size():
		var d: float = ((v - REGIONS[i][0]) / REGIONS[i][1]).length()
		if d < d1:
			d2 = d1
			d1 = d
			best = i
		elif d < d2:
			d2 = d
	return best if d2 - d1 > margin else -1


func _tracked_w(f: Font, s: String, sz: int, gap: float) -> float:
	var w := 0.0
	for ch in s:
		w += f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x + gap
	return w - gap
