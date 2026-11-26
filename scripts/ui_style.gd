class_name UIStyle
extends RefCounted
## The look: Stellaris-style dark glass panels with cut corners, thin cyan
## frames and soft glow. One palette and a few builders shared by every screen.

const CYAN := Color(0.37, 0.82, 1.0)
const CYAN_DIM := Color(0.37, 0.82, 1.0, 0.35)
const GOLD := Color(1.0, 0.77, 0.42)
const GREEN := Color(0.56, 0.94, 0.64)
const RED := Color(1.0, 0.45, 0.35)
const TEXT := Color(0.85, 0.92, 0.98)
const TEXT_DIM := Color(0.56, 0.7, 0.81)
const KICKER := Color(0.5, 0.78, 0.94)
const GLASS := Color(0.035, 0.085, 0.14, 0.9)
const GLASS_CARD := Color(0.03, 0.09, 0.14, 0.72)

# Paperwork: the Charter's print, people's pen, rubber stamps.
const PAPER := Color(0.91, 0.88, 0.8)
const PAPER_SHADE := Color(0.82, 0.78, 0.69)
const INK_TYPE := Color(0.16, 0.17, 0.2)      ## typewriter / print
const INK_PEN := Color(0.13, 0.22, 0.52)      ## ballpoint blue
const INK_STAMP := Color(0.72, 0.13, 0.12)    ## stamp red
const INK_FADED := Color(0.42, 0.4, 0.37)
const BOARD := Color(0.24, 0.18, 0.12)        ## clipboard


## A panel stylebox with two cut corners (top-left, bottom-right).
static func panel(bg := GLASS, border := Color(0.47, 0.78, 1.0, 0.45), cut := 22, margin := 22.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.corner_radius_top_left = cut
	sb.corner_radius_bottom_right = cut
	sb.corner_detail = 1  # one segment per corner: a chamfer instead of a curve
	sb.set_content_margin_all(margin)
	sb.shadow_color = Color(0.15, 0.6, 1.0, 0.12)
	sb.shadow_size = 18
	sb.anti_aliasing = true
	return sb


static func card() -> StyleBoxFlat:
	var sb := panel(GLASS_CARD, Color(0.4, 0.7, 0.9, 0.25), 0, 14.0)
	sb.shadow_size = 0
	return sb


## The small outlined "MADE HERE" / "NEEDED" tag.
static func tag(col: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(col.r, col.g, col.b, 0.08)
	sb.border_color = Color(col.r, col.g, col.b, 0.6)
	sb.set_border_width_all(1)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 0
	sb.content_margin_bottom = 0
	return sb


static func _button_box(top: Color, border: Color, glow := 0.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = top
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.corner_radius_top_left = 6
	sb.corner_radius_bottom_right = 6
	sb.corner_detail = 1
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	if glow > 0.0:
		sb.shadow_color = Color(CYAN.r, CYAN.g, CYAN.b, glow)
		sb.shadow_size = 8
	return sb


## Restyle Godot's default theme so every Button, Label, LineEdit and
## ProgressBar in the game picks up the look without per-screen work.
static func apply_default_theme(font: Font) -> void:
	var t := ThemeDB.get_default_theme()
	if font:
		t.default_font = font
	t.default_font_size = 16
	t.set_stylebox("normal", "Button", _button_box(Color(0.12, 0.3, 0.45, 0.55), Color(0.43, 0.78, 1.0, 0.55)))
	t.set_stylebox("hover", "Button", _button_box(Color(0.18, 0.42, 0.6, 0.75), Color(0.55, 0.88, 1.0, 0.9), 0.35))
	t.set_stylebox("pressed", "Button", _button_box(Color(0.25, 0.55, 0.75, 0.85), CYAN, 0.5))
	t.set_stylebox("hover_pressed", "Button", _button_box(Color(0.28, 0.6, 0.8, 0.9), CYAN, 0.5))
	t.set_stylebox("disabled", "Button", _button_box(Color(0.08, 0.15, 0.22, 0.35), Color(0.43, 0.78, 1.0, 0.15)))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color(1, 1, 1))
	t.set_color("font_pressed_color", "Button", Color(1, 1, 1))
	t.set_color("font_hover_pressed_color", "Button", Color(1, 1, 1))
	t.set_color("font_disabled_color", "Button", Color(0.6, 0.72, 0.82, 0.35))
	t.set_color("font_color", "Label", TEXT)
	var le := _button_box(Color(0.02, 0.07, 0.12, 0.85), Color(0.43, 0.78, 1.0, 0.45))
	le.content_margin_top = 6
	le.content_margin_bottom = 6
	t.set_stylebox("normal", "LineEdit", le)
	var lef := le.duplicate()
	lef.border_color = CYAN
	t.set_stylebox("focus", "LineEdit", lef)
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("caret_color", "LineEdit", CYAN)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.37, 0.82, 1.0, 0.12)
	var fill := StyleBoxFlat.new()
	fill.bg_color = CYAN
	fill.shadow_color = Color(CYAN.r, CYAN.g, CYAN.b, 0.5)
	fill.shadow_size = 4
	t.set_stylebox("background", "ProgressBar", bg)
	t.set_stylebox("fill", "ProgressBar", fill)
	t.set_constant("outline_size", "Label", 0)


# --- Immediate-mode helpers for the HUD (drawn in _draw) -----------------------

## Points of a rectangle with its top-left and bottom-right corners cut.
static func chamfer(r: Rect2, cut: float) -> PackedVector2Array:
	var a := r.position
	var b := r.end
	return PackedVector2Array([Vector2(a.x + cut, a.y), Vector2(b.x, a.y), Vector2(b.x, b.y - cut),
		Vector2(b.x - cut, b.y), Vector2(a.x, b.y), Vector2(a.x, a.y + cut)])


## A glass panel with a thin frame and a short glowing accent on top.
## Cockpit panel: a gunmetal plate with a pixel bevel, corner rivets and a
## painted accent tick, so the HUD reads as the rig's own instruments.
static func draw_glass(ci: CanvasItem, r: Rect2, alpha := 1.0, cut := 14.0, accent := CYAN) -> void:
	r = Rect2(r.position.round(), r.size.round())
	ci.draw_rect(r.grow(2), Color(0.01, 0.01, 0.02, 0.85 * alpha))
	ci.draw_rect(r, Color(0.075, 0.085, 0.095, 0.93 * alpha))
	# Bevel: lit top and left, shadowed bottom and right.
	ci.draw_rect(Rect2(r.position, Vector2(r.size.x, 2)), Color(0.24, 0.26, 0.28, alpha))
	ci.draw_rect(Rect2(r.position, Vector2(2, r.size.y)), Color(0.2, 0.22, 0.24, alpha))
	ci.draw_rect(Rect2(r.position.x, r.end.y - 2, r.size.x, 2), Color(0.03, 0.03, 0.04, alpha))
	ci.draw_rect(Rect2(r.end.x - 2, r.position.y, 2, r.size.y), Color(0.03, 0.03, 0.04, alpha))
	for k in [Vector2(5, 5), Vector2(r.size.x - 8, 5), Vector2(5, r.size.y - 8), Vector2(r.size.x - 8, r.size.y - 8)]:
		ci.draw_rect(Rect2(r.position + k, Vector2(3, 3)), Color(0.32, 0.34, 0.36, alpha))
		ci.draw_rect(Rect2(r.position + k, Vector2(1, 1)), Color(0.55, 0.57, 0.6, alpha))
	ci.draw_rect(Rect2(r.position + Vector2(14, 2), Vector2(minf(70.0, r.size.x * 0.25), 3)), Color(accent.r, accent.g, accent.b, 0.9 * alpha))


## A segmented LED gauge: lit cells for the value, dark cells for the rest.
static func draw_bar(ci: CanvasItem, r: Rect2, frac: float, col: Color, alpha := 1.0) -> void:
	var cell := 6.0 if r.size.y >= 5.0 else 4.0
	var n := int(r.size.x / cell)
	var lit := frac * n
	for i in n:
		var c := Rect2(r.position.x + i * cell, r.position.y, cell - 2.0, r.size.y)
		if float(i) + 0.5 < lit:
			ci.draw_rect(c, Color(col.r, col.g, col.b, alpha))
		else:
			ci.draw_rect(c, Color(col.r, col.g, col.b, 0.13 * alpha))


static func draw_portrait(ci: CanvasItem, r: Rect2, pal: Array, frame := GOLD) -> void:
	ci.draw_rect(r, Color(0.05, 0.12, 0.2))
	var c := r.get_center()
	var s := r.size.x
	# Shoulders: a circle cut off at the frame's bottom edge.
	var body := PackedVector2Array()
	var bc := Vector2(c.x, r.end.y + s * 0.08)
	for i in 33:
		var p := bc + Vector2.RIGHT.rotated(PI + PI * float(i) / 32.0) * s * 0.4
		body.append(Vector2(clampf(p.x, r.position.x, r.end.x), minf(p.y, r.end.y)))
	ci.draw_colored_polygon(body, pal[2])
	ci.draw_circle(Vector2(c.x, r.position.y + s * 0.42), s * 0.21, pal[0])
	ci.draw_arc(Vector2(c.x, r.position.y + s * 0.4), s * 0.22, PI * 1.05, PI * 1.95, 16, pal[1], s * 0.09)
	ci.draw_rect(r, Color(frame.r, frame.g, frame.b, 0.6), false, 1.0)


## A Charter ID photo: a grainy, washed-out file photo with a serial number and
## a corner of the Charter's seal over it. Real portrait art drops in later.
static var _portrait_cache := {}

static var _photo_bg := {}

const PORTRAIT_FILES := {
	"Dez": "dez", "Charlie": "charlie", "Franz": "franz", "Tallyman": "tallyman",
	"Fay": "fay", "Mersham": "mersham", "Gate customs": "customs", "Dock crew": "dock_crew", "Marines": "marines",
	# Pack picks 2026-11-26 (portrait-picks.png): Alejandra #155, Hollis #44, Mbeki #118,
	# Qasim #78, Notch #10, Trojan #40, Recovery #194, Navy patrol #140.
	"Alejandra": "alejandra", "Hollis": "hollis", "Hollis' Girl": "hollis", "Mbeki": "mbeki", "Qasim": "qasim",
	"Notch": "notch", "Trojan": "trojan", "Charter Recovery": "recovery", "Navy patrol": "navy_patrol",
}


## Hand-made pixel portrait for a speaker, or null.
static func portrait_tex(who: String) -> Texture2D:
	# You: the photo you picked on the financing agreement.
	if who == "You":
		who = "pilot_%d" % int(Career.pilot.get("photo", 0))
	var file: String = who if who.begins_with("pilot_") else PORTRAIT_FILES.get(who, "")
	if file == "":
		return null
	if _portrait_cache.has(who):
		return _portrait_cache[who]
	# Vishnu's portrait pack (art/, not in git) wins over the hand-made set.
	var tex: Texture2D = null
	for path in ["res://art/portraits/%s.png" % file, "res://portraits/%s.png" % file]:
		if ResourceLoader.exists(path):
			tex = load(path)
		elif FileAccess.file_exists(path):
			var img := Image.load_from_file(ProjectSettings.globalize_path(path))
			if img:
				tex = ImageTexture.create_from_image(img)
		if tex:
			break
	_portrait_cache[who] = tex
	return tex


static func draw_id_photo(ci: CanvasItem, r: Rect2, pal: Array, serial := "", seed := 1, who := "") -> void:
	# Photo paper border.
	ci.draw_rect(r.grow(3), Color(0.93, 0.91, 0.86))
	var p := r
	if serial != "":
		p.size.y -= 14
	var tex := portrait_tex(who)
	if tex:
		ci.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		# Cover the photo, crop centered.
		var ts := tex.get_size()
		if ts.x >= ts.y * 0.95:
			# Square pack portrait: fit the width, sit it on the bottom edge,
			# and extend its backdrop up to fill the taller photo.
			if not _photo_bg.has(tex):
				var img := tex.get_image()
				_photo_bg[tex] = img.get_pixel(0, 0) if img else Color(0.4, 0.45, 0.5)
			var bg: Color = _photo_bg[tex]
			ci.draw_rect(p, Color(bg.r * 0.96, bg.g * 0.95, bg.b * 0.92))
			var kk := p.size.x / ts.x
			ci.draw_texture_rect(tex, Rect2(Vector2(p.position.x, p.end.y - ts.y * kk), ts * kk), false, Color(0.96, 0.95, 0.92))
			_photo_finish(ci, p, serial, seed)
			return
		var k := maxf(p.size.x / ts.x, p.size.y / ts.y)
		var dst := Rect2(p.get_center() - ts * k * 0.5, ts * k)
		var src := Rect2(Vector2.ZERO, ts)
		# Clip to the photo rect via source rect.
		var over := (dst.size - p.size) / k
		src = Rect2(over * 0.5, ts - over)
		ci.draw_texture_rect_region(tex, p, src, Color(0.96, 0.95, 0.92))
		_photo_finish(ci, p, serial, seed)
		return
	var wash := func(c: Color) -> Color:
		var g := c.get_luminance()
		return Color(lerpf(c.r, g, 0.55) * 0.9 + 0.06, lerpf(c.g, g, 0.55) * 0.92 + 0.07, lerpf(c.b, g, 0.55) * 0.95 + 0.09)
	ci.draw_rect(p, Color(0.62, 0.66, 0.68))  # backdrop wall
	ci.draw_rect(Rect2(p.position, Vector2(p.size.x, p.size.y * 0.12)), Color(0.55, 0.59, 0.62))
	var c := p.get_center()
	var s := p.size.x
	var body := PackedVector2Array()
	var bc := Vector2(c.x, p.end.y + s * 0.08)
	for i in 33:
		var q := bc + Vector2.RIGHT.rotated(PI + PI * float(i) / 32.0) * s * 0.42
		body.append(Vector2(clampf(q.x, p.position.x, p.end.x), minf(q.y, p.end.y)))
	ci.draw_colored_polygon(body, wash.call(pal[2]))
	ci.draw_rect(Rect2(c.x - s * 0.07, p.position.y + p.size.y * 0.58, s * 0.14, p.size.y * 0.14), wash.call(pal[0]).darkened(0.1))
	ci.draw_circle(Vector2(c.x, p.position.y + p.size.y * 0.43), s * 0.2, wash.call(pal[0]))
	ci.draw_arc(Vector2(c.x, p.position.y + p.size.y * 0.41), s * 0.205, PI * 1.08, PI * 1.92, 16, wash.call(pal[1]), s * 0.07)
	_photo_finish(ci, p, serial, seed)


static func _photo_finish(ci: CanvasItem, p: Rect2, serial: String, seed: int) -> void:
	var s := p.size.x
	# Grain and a soft light leak.
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for i in int(s * s * 0.06):
		var gp := p.position + Vector2(rng.randf() * p.size.x, rng.randf() * p.size.y)
		var v := rng.randf()
		ci.draw_rect(Rect2(gp, Vector2(1, 1)), Color(v, v, v, 0.12))
	ci.draw_rect(Rect2(p.position, Vector2(p.size.x, p.size.y * 0.35)), Color(1, 0.95, 0.85, 0.06))
	# Seal: a red ring biting into the corner.
	ci.draw_arc(Vector2(p.end.x - s * 0.08, p.end.y - s * 0.12), s * 0.17, 0, TAU, 24, Color(INK_STAMP.r, INK_STAMP.g, INK_STAMP.b, 0.45), 1.5, true)
	if serial != "":
		var f: Font = Data.font_type if Data.font_type else ThemeDB.fallback_font
		ci.draw_rect(Rect2(p.position.x, p.end.y, p.size.x, 14), Color(0.93, 0.91, 0.86))
		ci.draw_string(f, Vector2(p.position.x + 2, p.end.y + 11), serial, HORIZONTAL_ALIGNMENT_CENTER, p.size.x - 4, 10, INK_TYPE)


## What's behind a paper overlay: the cockpit gone dark, one warm pool of lamp
## light under the sheet. Hides the flight HUD so the paper is all you see.
static func lamp_backdrop() -> TextureRect:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	g.colors = PackedColorArray([Color(0.13, 0.1, 0.07, 0.95), Color(0.05, 0.04, 0.04, 0.96), Color(0.0, 0.0, 0.01, 0.985)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.05, 1.0)
	gt.width = 256
	gt.height = 256
	var r := TextureRect.new()
	r.texture = gt
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	return r
