class_name TitleScene
extends Control
## The live title scene: a Federation navy squadron and a Dynasty squadron
## hold station face to face over Aurelia's limb. Nobody fires. Draws the
## bought art when it's there and plain shapes when it isn't.

const PLANET := "planets/laviria"
const TRAFFIC := ["ships/diverger.png", "ships/harbinger.png", "ships/raven.png"]
## [pack dir, x, y (fractions of the screen), scale]. Navy on the left facing
## right, the Dynasty mirrored on the right facing left.
const NAVY := [["klaed/dreadnought", 0.27, 0.40, 3.0], ["klaed/battlecruiser", 0.12, 0.27, 2.0],
	["klaed/frigate", 0.15, 0.55, 2.0], ["klaed/frigate", 0.33, 0.22, 2.0],
	["klaed/fighter", 0.40, 0.33, 1.0], ["klaed/fighter", 0.41, 0.48, 1.0], ["klaed/fighter", 0.37, 0.56, 1.0]]
const DYNASTY := [["nairan/dreadnought", 0.73, 0.44, 3.0], ["nairan/battlecruiser", 0.88, 0.58, 2.0],
	["nairan/frigate", 0.91, 0.40, 2.0], ["nairan/frigate", 0.67, 0.62, 2.0],
	["nairan/fighter", 0.60, 0.36, 1.0], ["nairan/fighter", 0.59, 0.50, 1.0], ["nairan/fighter", 0.62, 0.27, 1.0]]

var _t := 0.0
var _planet: Array = []
var _ships: Array = []            ## [engine layer, hull layer], drawn over the planet


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # pixel art stays crisp
	_planet = Art.frames(PLANET)
	# Each ship's hull gets its side's livery, so each needs its own layer.
	for side in [[NAVY, PI * 0.5, "navy", 0], [DYNASTY, -PI * 0.5, "dynasty", 10]]:
		for i in side[0].size():
			var s: Array = side[0][i]
			var eng := Node2D.new()
			eng.draw.connect(_draw_ship.bind(eng, s, side[1], i + side[3], true))
			var hull := Node2D.new()
			hull.material = Art.livery(Data.liveries.get(side[2], []), i, Art.main_hue("ships/%s/base.png" % s[0]))
			hull.draw.connect(_draw_ship.bind(hull, s, side[1], i + side[3], false))
			add_child(eng)
			add_child(hull)
			_ships.append_array([eng, hull])


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	for n in _ships:
		n.queue_redraw()


func _draw() -> void:
	if size.y < 10.0:
		size = get_viewport_rect().size
	_draw_traffic()
	var d := size.y * 2.3
	_draw_planet(Vector2(size.x * 0.5, size.y * 1.8), d)


## One pack ship at idle: engine glow cycling, a slow bob.
func _draw_ship(ci: CanvasItem, s: Array, rot: float, seed: int, engine: bool) -> void:
	var dir := "ships/" + str(s[0])
	var base := Art.tex(dir + "/base.png")
	var p := Vector2(size.x * float(s[1]), size.y * float(s[2]))
	p.y += sin(_t * 0.6 + seed * 1.7) * 3.0
	var k := float(s[3]) * size.y / 900.0
	if base == null:
		if not engine:
			ci.draw_circle(p, 20.0 * k, Color(0.3, 0.35, 0.45))
		return
	ci.draw_set_transform(p.round(), rot, Vector2(k, k))
	if engine:
		var eng := Art.tex(dir + "/engine.png")
		if eng:
			var h := eng.get_height()
			var n := maxi(1, eng.get_width() / h)
			var f := int(_t * 7.0 + seed) % n
			ci.draw_texture_rect_region(eng, Rect2(-Vector2(h, h) * 0.5, Vector2(h, h)), Rect2(f * h, 0, h, h), Color(1, 1, 1, 0.7))
		return
	ci.draw_texture_rect(base, Rect2(-base.get_size() * 0.5, base.get_size()), false)
	var w := Art.tex(dir + "/weapons.png")
	if w:
		var h2 := w.get_height()
		ci.draw_texture_rect_region(w, Rect2(-Vector2(h2, h2) * 0.5, Vector2(h2, h2)), Rect2(0, 0, h2, h2))


func _draw_planet(c: Vector2, d: float) -> void:
	# Atmosphere glow along the limb.
	for k in 6:
		draw_circle(c, d * 0.5 * (0.985 + k * 0.012), Color(1.0, 0.35, 0.45, 0.035))
	if _planet.is_empty():
		draw_circle(c, d * 0.48, Color(0.2, 0.08, 0.15))
		return
	var f: Texture2D = _planet[int(_t * 2.0) % _planet.size()]
	draw_texture_rect(f, Rect2(c - Vector2(d, d) * 0.5, Vector2(d, d)), false)


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
