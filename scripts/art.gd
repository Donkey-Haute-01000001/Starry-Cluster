class_name Art
extends RefCounted
## Loads the bought art from res://art at runtime. art/ is git-ignored (the packs
## can't be redistributed), so every caller falls back to procedural drawing when
## a file is missing. Build the folder with tools/prepare_art.py.

static var _tex := {}
static var _used := {}
static var _frames := {}


static func tex(rel: String) -> Texture2D:
	if _tex.has(rel):
		return _tex[rel]
	var t: Texture2D = null
	var path := ProjectSettings.globalize_path("res://art/" + rel)
	if FileAccess.file_exists(path):
		var img := Image.load_from_file(path)
		if img != null and not img.is_empty():
			_used[rel] = Rect2(img.get_used_rect())
			_hue[rel] = _dominant_hue(img)
			img.generate_mipmaps()
			t = ImageTexture.create_from_image(img)
	_tex[rel] = t
	return t


## The part of the image that isn't transparent, in pixels.
static func used_rect(rel: String) -> Rect2:
	tex(rel)
	return _used.get(rel, Rect2())


## Numbered animation frames in a folder: 00.png, 01.png, ...
static func frames(dir: String) -> Array:
	if _frames.has(dir):
		return _frames[dir]
	var out := []
	var i := 0
	while i < 200:
		var t := tex("%s/%02d.png" % [dir, i])
		if t == null:
			break
		out.append(t)
		i += 1
	_frames[dir] = out
	return out


## Draw a texture centered on the origin so its visible part spans `size` along
## its longest side. Returns false when the art is missing.
static func draw_fit(ci: CanvasItem, rel: String, size: float, modulate := Color.WHITE, t: Texture2D = null) -> bool:
	if t == null:
		t = tex(rel)
	if t == null:
		return false
	var u := used_rect(rel)
	if u.size == Vector2.ZERO:
		u = Rect2(Vector2.ZERO, t.get_size())
	var s := size / maxf(u.size.x, u.size.y)
	var full := t.get_size() * s
	# Keep the image center on the origin; the art is centered in its canvas.
	ci.draw_texture_rect(t, Rect2(-full * 0.5, full), false, modulate)
	return true


static var _livery_shader: Shader = null
static var _hue := {}


## The hue most of a sprite's paint is in, so a livery can tell paint from trim.
static func _dominant_hue(img: Image) -> float:
	var bins := PackedFloat32Array()
	bins.resize(24)
	var step := maxi(1, img.get_width() / 64)
	for y in range(0, img.get_height(), step):
		for x in range(0, img.get_width(), step):
			var c := img.get_pixel(x, y)
			if c.a > 0.5 and c.s > 0.3 and c.v > 0.15:
				bins[int(c.h * 24.0) % 24] += c.s * c.a
	var best := 0
	for i in 24:
		if bins[i] > bins[best]:
			best = i
	return (best + 0.5) / 24.0


static func main_hue(rel: String) -> float:
	tex(rel)
	return _hue.get(rel, -1.0)


## A faction's livery as a material. `seed` jitters hue and shade so a fleet
## isn't a row of clones.
static func livery(pal: Array, seed := 0, hue := -1.0) -> ShaderMaterial:
	if pal.size() < 2:
		return null
	if _livery_shader == null:
		_livery_shader = load("res://shaders/livery.gdshader")
	var m := ShaderMaterial.new()
	m.shader = _livery_shader
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(pal) ^ seed
	m.set_shader_parameter("paint", pal[0])
	m.set_shader_parameter("trim", pal[1])
	m.set_shader_parameter("main_hue", hue)
	m.set_shader_parameter("hue_jitter", rng.randf_range(-0.025, 0.025))
	m.set_shader_parameter("shade", rng.randf_range(0.86, 1.06))
	return m
