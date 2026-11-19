class_name TitleScene
extends Control
## The live title scene: your rig in its Charter berth at the Counter. Loaders
## shuttle cargo, berth lights blink, traffic drifts past. Draws the bought art
## when it's there and plain shapes when it isn't.

const STATION := "stations/hub"
const RIG := "ships/cargo.png"
const LOADER := "ships/starsparrow.png"
const TRAFFIC := ["ships/diverger.png", "ships/harbinger.png", "ships/raven.png"]

var _t := 0.0
var _frames: Array = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # pixel art stays crisp
	_frames = Art.frames(STATION)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


## Where things sit, relative to the station's center, at scale 1.
func _layout() -> Dictionary:
	if size.y < 10.0:
		size = get_viewport_rect().size
	var h := size.y
	var station_size := h * 0.72
	var center := Vector2(size.x * 0.2, h * 0.56) + Vector2(sin(_t * 0.07) * 10.0, sin(_t * 0.05) * 6.0)
	var arm := center + Vector2(station_size * 0.47, 0)
	var rig_len := h * 0.38
	var rig := arm + Vector2(rig_len * 0.52, 0)
	return {"center": center, "station": station_size, "arm": arm, "rig": rig, "rig_len": rig_len}


func _draw() -> void:
	var L := _layout()
	_draw_traffic(0.35)
	# Station.
	if not _frames.is_empty():
		var f: Texture2D = _frames[int(_t * 6.0) % _frames.size()]
		draw_set_transform(L["center"])
		Art.draw_fit(self, STATION + "/00.png", L["station"], Color(0.82, 0.86, 0.95), f)
		draw_set_transform(Vector2.ZERO)
	else:
		draw_circle(L["center"], L["station"] * 0.3, Color(0.18, 0.22, 0.3))
		draw_arc(L["center"], L["station"] * 0.48, 0, TAU, 96, Color(0.3, 0.36, 0.45), 4.0, true)
		draw_rect(Rect2(L["center"] - Vector2(0, 14), Vector2(L["station"] * 0.48, 28)), Color(0.22, 0.27, 0.35))
	# Berth floodlights washing over the rig.
	var rig: Vector2 = L["rig"]
	var rl: float = L["rig_len"]
	for k in 2:
		var src := Vector2(rig.x - rl * 0.25 + k * rl * 0.5, rig.y - rl * 0.55 + k * rl * 1.1)
		var dir := 1.0 if k == 0 else -1.0
		var cone := PackedVector2Array([src, rig + Vector2(-rl * 0.35, -dir * rl * 0.05), rig + Vector2(rl * 0.35, -dir * rl * 0.05)])
		draw_colored_polygon(cone, Color(1.0, 0.86, 0.55, 0.05))
		draw_circle(src, 4.0, Color(1.0, 0.9, 0.65, 0.9))
		draw_circle(src, 10.0, Color(1.0, 0.85, 0.5, 0.15))
	# Umbilicals from the docking arm to the rig, with cargo pulses running along.
	var tail := rig - Vector2(rl * 0.46, 0)
	for k in [-1, 1]:
		var a: Vector2 = L["arm"] + Vector2(-6, k * 10)
		var b := tail + Vector2(0, k * 8)
		draw_line(a, b, Color(0.35, 0.4, 0.48), 5.0)
		draw_line(a, b, Color(0.55, 0.62, 0.7), 1.5)
		for i in 3:
			var u := fmod(_t * 0.4 + i / 3.0 + (0.5 if k > 0 else 0.0), 1.0)
			draw_circle(a.lerp(b, u), 2.5, Color(1.0, 0.75, 0.35, 0.8))
	# Your rig.
	draw_set_transform(rig)
	if not Art.draw_fit(self, RIG, rl):
		draw_rect(Rect2(Vector2(-rl * 0.5, -rl * 0.12), Vector2(rl, rl * 0.24)), Color(0.3, 0.25, 0.22))
		draw_rect(Rect2(Vector2(rl * 0.15, -rl * 0.2), Vector2(rl * 0.35, rl * 0.4)), Color(0.35, 0.28, 0.24))
	draw_set_transform(Vector2.ZERO)
	# Loaders shuttling between the station and the rig's hold.
	for i in 3:
		var ph := _t * 0.18 + i * 0.37
		var u := 0.5 - 0.5 * cos(ph * TAU)   # ease back and forth
		var a: Vector2 = L["center"] + Vector2(L["station"] * 0.2, (i - 1) * 60.0)
		var b := rig + Vector2(rl * (0.05 + i * 0.12), -rl * 0.3 + (i % 2) * rl * 0.6)
		var p := a.lerp(b, u) + Vector2(0, sin(ph * 5.0) * 4.0)
		var going := sin(ph * TAU) > 0.0
		draw_set_transform(p, 0.0 if going else PI)
		if not Art.draw_fit(self, LOADER, 34.0):
			draw_rect(Rect2(-8, -5, 16, 10), Color(0.6, 0.55, 0.4))
		draw_set_transform(Vector2.ZERO)
		draw_circle(p + Vector2(0, -8), 1.5, Color(1.0, 0.4, 0.2, 0.5 + 0.5 * sin(_t * 6.0 + i)))
	# Berth warning lights: amber, chasing along the arm.
	for i in 6:
		var p: Vector2 = L["arm"].lerp(tail, i / 5.0) + Vector2(0, -28)
		var on := int(_t * 4.0) % 6 == i
		draw_circle(p, 3.0, Color(1.0, 0.65, 0.15, 0.95 if on else 0.25))
		if on:
			draw_circle(p, 9.0, Color(1.0, 0.6, 0.1, 0.25))
		var q := p + Vector2(0, 56)
		draw_circle(q, 3.0, Color(1.0, 0.65, 0.15, 0.95 if on else 0.25))
	# Red beacons on the rig's hull.
	var blink := fmod(_t, 1.6) < 0.12
	for o in [Vector2(rl * 0.42, -rl * 0.18), Vector2(rl * 0.42, rl * 0.18)]:
		draw_circle(rig + o, 2.5, Color(1.0, 0.25, 0.2, 1.0 if blink else 0.3))
		if blink:
			draw_circle(rig + o, 12.0, Color(1.0, 0.2, 0.15, 0.25))
	_draw_traffic(1.0)


## Ships crossing far behind (depth < 1) or close in front (depth 1).
func _draw_traffic(depth: float) -> void:
	var n := 2 if depth < 1.0 else 1
	for i in n:
		var speed := (18.0 + i * 9.0) * depth
		var span := size.x + 400.0
		var x := size.x + 200.0 - fmod(_t * speed + i * span * 0.55 + depth * 300.0, span)
		var y := size.y * (0.14 + i * 0.7) if depth < 1.0 else size.y * 0.9
		var sz := 46.0 * depth if depth < 1.0 else 90.0
		var tint := Color(0.55, 0.6, 0.7, 0.75) if depth < 1.0 else Color(0.5, 0.52, 0.58, 0.9)
		draw_set_transform(Vector2(x, y), PI)
		if not Art.draw_fit(self, TRAFFIC[(i + int(depth)) % TRAFFIC.size()], sz, tint):
			draw_rect(Rect2(-sz * 0.5, -sz * 0.15, sz, sz * 0.3), tint.darkened(0.5))
		draw_set_transform(Vector2.ZERO)
		draw_circle(Vector2(x + sz * 0.5, y), 3.0 * depth + 1.0, Color(0.5, 0.8, 1.0, 0.5))
