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
static func draw_glass(ci: CanvasItem, r: Rect2, alpha := 1.0, cut := 14.0, accent := CYAN) -> void:
	var pts := chamfer(r, cut)
	ci.draw_colored_polygon(pts, Color(GLASS.r, GLASS.g, GLASS.b, 0.82 * alpha))
	var outline := pts.duplicate()
	outline.append(pts[0])
	ci.draw_polyline(outline, Color(0.47, 0.78, 1.0, 0.45 * alpha), 1.0, true)
	var ax := r.position.x + cut
	ci.draw_line(Vector2(ax, r.position.y + 1), Vector2(ax + minf(110.0, r.size.x * 0.3), r.position.y + 1),
		Color(accent.r, accent.g, accent.b, 0.95 * alpha), 2.0)


## A slim bar: dim track, bright fill with a faint glow.
static func draw_bar(ci: CanvasItem, r: Rect2, frac: float, col: Color, alpha := 1.0) -> void:
	ci.draw_rect(r, Color(col.r, col.g, col.b, 0.12 * alpha))
	var w := r.size.x * clampf(frac, 0.0, 1.0)
	if w > 0.0:
		ci.draw_rect(Rect2(r.position - Vector2(0, 1), Vector2(w, r.size.y + 2)), Color(col.r, col.g, col.b, 0.18 * alpha))
		ci.draw_rect(Rect2(r.position, Vector2(w, r.size.y)), Color(col.r, col.g, col.b, alpha))


## Placeholder portrait: head and shoulders in a palette from Data.friend_portraits.
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
