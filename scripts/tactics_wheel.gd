extends Control
## Hold Tab: time slows and a radial menu of formations and orders appears.
## Point the mouse at an option and release Tab to give the order.

var main: Node
var options := [
	{"id": "engage", "label": "Engage at will", "group": "Order"},
	{"id": "focus", "label": "Focus my target", "group": "Order"},
	{"id": "screen", "label": "Screen me", "group": "Order"},
	{"id": "bait", "label": "Bait", "group": "Order"},
	{"id": "break", "label": "Break off", "group": "Order"},
	{"id": "wedge", "label": "Wedge", "group": "Formation"},
	{"id": "line", "label": "Line abreast", "group": "Formation"},
	{"id": "ring", "label": "Ring", "group": "Formation"},
]
var selected := -1
const RADIUS := 205.0
const INNER := 60.0


func _process(_delta: float) -> void:
	if not visible:
		return
	var c := size * 0.5
	var m := get_local_mouse_position() - c
	selected = -1
	if m.length() > INNER:
		var seg := TAU / options.size()
		var a := fposmod(m.angle() + PI * 0.5 + seg * 0.5, TAU)
		selected = int(a / seg) % options.size()
	queue_redraw()


func current_id() -> String:
	return options[selected]["id"] if selected >= 0 else ""


func _draw() -> void:
	var c := size * 0.5
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.02, 0.06, 0.35))
	var seg := TAU / options.size()
	for i in options.size():
		var o: Dictionary = options[i]
		var start := -PI * 0.5 - seg * 0.5 + seg * i
		var active := _is_active(o["id"])
		var col := Color(0.1, 0.18, 0.28, 0.85)
		if o["group"] == "Formation":
			col = Color(0.12, 0.22, 0.2, 0.85)
		if i == selected:
			col = col.lightened(0.35)
		var pts := PackedVector2Array()
		for k in 17:
			pts.append(c + Vector2.RIGHT.rotated(start + seg * k / 16.0) * RADIUS)
		for k in range(16, -1, -1):
			pts.append(c + Vector2.RIGHT.rotated(start + seg * k / 16.0) * INNER)
		draw_colored_polygon(pts, col)
		var edge := Color(0.5, 0.85, 1.0, 0.9) if active else Color(0.4, 0.6, 0.75, 0.5)
		draw_polyline(pts + PackedVector2Array([pts[0]]), edge, 2.0 if active else 1.0, true)
		var mid := c + Vector2.RIGHT.rotated(start + seg * 0.5) * (RADIUS + INNER) * 0.5
		var label: String = o["label"]
		var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		draw_string(font, mid + Vector2(-w * 0.5, 0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 1, 1) if i == selected else Color(0.8, 0.88, 0.95))
		var g: String = o["group"].to_upper() + (" (active)" if active else "")
		var gw := font.get_string_size(g, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		draw_string(font, mid + Vector2(-gw * 0.5, 16), g, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.6, 0.75, 0.85))
	var title := "TACTICS"
	var tw := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	draw_string(font, c + Vector2(-tw * 0.5, 6), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.7, 0.9, 1.0))
	var hint := "Point at an option and release Tab.  Release in the middle to cancel."
	var hw := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	draw_string(font, c + Vector2(-hw * 0.5, RADIUS + 34), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.75, 0.85, 0.95))


func _is_active(id: String) -> bool:
	return id == main.fleet_order or id == main.formation
