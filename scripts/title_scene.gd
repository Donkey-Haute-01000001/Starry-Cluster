class_name TitleScene
extends Control
## The live title scene: Aurelia, huge and slowly turning, its limb across the
## lower screen. A Charter convoy crawls over the night side, running lights
## only. Draws the bought art when it's there and plain shapes when it isn't.

const PLANET := "planets/laviria"
const TRAFFIC := ["ships/diverger.png", "ships/harbinger.png", "ships/raven.png"]
const CONVOY := 9

var _t := 0.0
var _planet: Array = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # pixel art stays crisp
	_planet = Art.frames(PLANET)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	if size.y < 10.0:
		size = get_viewport_rect().size
	_draw_traffic()
	var d := size.y * 2.3
	var c := Vector2(size.x * 0.58, size.y * 1.52)
	_draw_planet(c, d)
	_draw_convoy(c, d * 0.5 + 34.0)


func _draw_planet(c: Vector2, d: float) -> void:
	# Atmosphere glow along the limb.
	for k in 6:
		draw_circle(c, d * 0.5 * (0.985 + k * 0.012), Color(1.0, 0.35, 0.45, 0.035))
	if _planet.is_empty():
		draw_circle(c, d * 0.48, Color(0.2, 0.08, 0.15))
		return
	var f: Texture2D = _planet[int(_t * 2.0) % _planet.size()]
	draw_texture_rect(f, Rect2(c - Vector2(d, d) * 0.5, Vector2(d, d)), false)


## Haulers nose to tail along the limb, left to right, a red beacon blinking on each.
func _draw_convoy(c: Vector2, r: float) -> void:
	var span := 1.5
	for i in CONVOY:
		var u := fmod(_t * 0.004 + i * 0.026, span)
		var ang := -PI * 0.5 - span * 0.5 + u
		var p := c + Vector2(cos(ang), sin(ang)) * r
		var fade := clampf(minf(u, span - u) / 0.12, 0.0, 1.0)
		draw_circle(p, 1.8, Color(1.0, 0.86, 0.62, 0.95 * fade))
		draw_circle(p, 6.0, Color(1.0, 0.75, 0.4, 0.16 * fade))
		if fmod(_t + i * 0.37, 1.4) < 0.1:
			var q := p - Vector2(cos(ang + PI * 0.5), sin(ang + PI * 0.5)) * 4.0
			draw_circle(q, 1.4, Color(1.0, 0.3, 0.25, fade))
			draw_circle(q, 7.0, Color(1.0, 0.3, 0.25, 0.2 * fade))


## Two ships crossing far behind, small and dim.
func _draw_traffic() -> void:
	for i in 2:
		var speed := (18.0 + i * 9.0) * 0.35
		var span := size.x + 400.0
		var x := size.x + 200.0 - fmod(_t * speed + i * span * 0.55 + 105.0, span)
		var y := size.y * (0.14 + i * 0.22)
		var sz := 16.0
		var tint := Color(0.55, 0.6, 0.7, 0.75)
		draw_set_transform(Vector2(x, y), PI)
		if not Art.draw_fit(self, TRAFFIC[i % TRAFFIC.size()], sz, tint):
			draw_rect(Rect2(-sz * 0.5, -sz * 0.15, sz, sz * 0.3), tint.darkened(0.5))
		draw_set_transform(Vector2.ZERO)
		draw_circle(Vector2(x + sz * 0.5, y), 2.0, Color(0.5, 0.8, 1.0, 0.5))
