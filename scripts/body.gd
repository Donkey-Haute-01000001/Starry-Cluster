extends Node2D
## A thing in a star system that isn't a ship: a planet, an asteroid belt,
## a station you can dock at, or a jump point (a natural rift with a gate station).

var kind := "planet"        ## planet, belt, station, jump
var id := ""                ## station id, or destination system id for jumps
var radius := 100.0
var width := 0.0
var color := Color.GRAY
var band := Color.GRAY
var label := ""
var sublabel := ""
var locked := false
var art := ""               ## planet or station art folder under res://art (optional)
var art_size := 0.0         ## station display size when art is installed
var _frames: Array = []
var _rock_tex: Array = []
var _rocks: Array = []
var _t := 0.0

const DOCK_RANGE := 260.0
const JUMP_RANGE := 320.0


func setup(p_kind: String, data: Dictionary) -> void:
	kind = p_kind
	position = data.get("pos", Vector2.ZERO)
	radius = data.get("radius", 100.0)
	width = data.get("width", 0.0)
	color = data.get("color", Color.GRAY)
	band = data.get("band", color.darkened(0.2))
	art = data.get("art", "")
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if kind == "planet" and art != "":
		_frames = Art.frames("planets/" + art)
	elif kind == "belt":
		for i in 11:
			var t := Art.tex("asteroids/%02d.png" % i)
			if t != null:
				_rock_tex.append(t)
	if kind == "belt":
		var rng := RandomNumberGenerator.new()
		rng.seed = 4242
		for i in 420:
			var a := rng.randf() * TAU
			var r := radius + rng.randf_range(-width * 0.5, width * 0.5)
			_rocks.append([Vector2.RIGHT.rotated(a) * r, rng.randf_range(4.0, 16.0), rng.randf_range(0.7, 1.1), rng.randf() * TAU, rng.randi()])
	z_index = -3 if kind in ["planet", "belt"] else -1


## Station art: an animated folder under res://art/stations. Call after setup.
func set_station_art(key: String, size: float) -> void:
	art = key
	art_size = size
	_frames = Art.frames("stations/" + key) if key != "" else []


func interact_range() -> float:
	return DOCK_RANGE if kind == "station" else JUMP_RANGE


func _process(delta: float) -> void:
	_t += delta
	if kind in ["station", "jump"] or (kind == "planet" and not _frames.is_empty()):
		queue_redraw()


func _draw() -> void:
	if kind == "planet" and not _frames.is_empty():
		# Slow spin through the animation frames. The art has some margin, so
		# fit the visible disc to the planet's radius.
		var f: Texture2D = _frames[int(_t * 3.0) % _frames.size()]
		var rel := "planets/%s/00.png" % art
		Art.draw_fit(self, rel, radius * 2.0, Color.WHITE, f)
	elif kind == "station" and not _frames.is_empty():
		var f: Texture2D = _frames[int(_t * 10.0) % _frames.size()]
		Art.draw_fit(self, "stations/%s/00.png" % art, art_size, Color.WHITE, f)
		draw_arc(Vector2.ZERO, DOCK_RANGE, 0, TAU, 64, Color(0.5, 0.8, 1.0, 0.08), 2.0, true)
	else:
		match kind:
			"planet":
				draw_circle(Vector2.ZERO, radius, color)
				# A few soft bands and a terminator shadow so planets read as spheres.
				for k in 3:
					var y := (k - 1) * radius * 0.4
					var hw := sqrt(maxf(radius * radius - y * y, 0.0))
					draw_line(Vector2(-hw, y), Vector2(hw, y), Color(band.r, band.g, band.b, 0.35), radius * 0.12)
				for k in 8:
					var f := float(k) / 8.0
					draw_circle(Vector2(radius * 0.35 * f, radius * 0.35 * f), radius * (1.0 - f * 0.5), Color(0, 0, 0, 0.05))
				draw_arc(Vector2.ZERO, radius + 4.0, 0, TAU, 96, Color(color.lightened(0.4), 0.25), 6.0, true)
			"belt":
				for r in _rocks:
					if _rock_tex.is_empty():
						draw_circle(r[0], r[1], color * Color(r[2], r[2], r[2], 1.0))
					else:
						var t: Texture2D = _rock_tex[r[4] % _rock_tex.size()]
						var sz: float = r[1] * 2.6
						draw_set_transform(r[0], r[3])
						draw_texture_rect(t, Rect2(-sz * 0.5, -sz * 0.5, sz, sz), false, Color(r[2], r[2], r[2], 1.0))
				draw_set_transform(Vector2.ZERO, 0.0)
			"station":
				var c := Color(0.7, 0.78, 0.85)
				draw_arc(Vector2.ZERO, 46.0, 0, TAU, 48, c, 7.0, true)
				for k in 4:
					var a := _t * 0.15 + k * TAU / 4.0
					draw_line(Vector2.ZERO, Vector2.RIGHT.rotated(a) * 46.0, c.darkened(0.25), 4.0)
				draw_circle(Vector2.ZERO, 16.0, c.darkened(0.15))
				draw_circle(Vector2.ZERO, 6.0, Color(1.0, 0.85, 0.5, 0.6 + 0.4 * sin(_t * 3.0)))
				draw_arc(Vector2.ZERO, DOCK_RANGE, 0, TAU, 64, Color(0.5, 0.8, 1.0, 0.08), 2.0, true)
			"jump":
				var col := Color(0.55, 0.4, 1.0) if not locked else Color(1.0, 0.45, 0.35)
				# The gate station's ring sits around the rift.
				Art.draw_fit(self, "gate.png", 240.0, Color(1, 1, 1) if not locked else Color(1.0, 0.6, 0.55))
				# A slow swirl of light: the rift itself.
				for k in 5:
					var r := 40.0 + k * 22.0
					var a := _t * (0.6 - k * 0.08)
					draw_arc(Vector2.ZERO, r, a, a + PI * 1.3, 32, Color(col.r, col.g, col.b, 0.5 - k * 0.08), 3.0, true)
				draw_circle(Vector2.ZERO, 18.0, Color(col.r, col.g, col.b, 0.35))
				draw_arc(Vector2.ZERO, JUMP_RANGE, 0, TAU, 64, Color(col.r, col.g, col.b, 0.1), 2.0, true)

	if label != "":
		var font := ThemeDB.fallback_font
		var off := radius + 26.0 if kind == "planet" else 70.0
		if kind == "station" and not _frames.is_empty():
			off = art_size * 0.5 + 18.0
		elif kind == "jump" and Art.tex("gate.png") != null:
			off = 140.0
		var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		draw_string(font, Vector2(-w * 0.5, off), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.85, 0.9, 1.0, 0.9))
		if sublabel != "":
			var w2 := font.get_string_size(sublabel, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
			draw_string(font, Vector2(-w2 * 0.5, off + 20), sublabel, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.65, 0.72, 0.85, 0.8))
