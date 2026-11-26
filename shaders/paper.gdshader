shader_type canvas_item;
// Handled paper (and the logbook's leather) for the paperwork overlays.
// Everything is procedural: grain, fibers, mottling, foxing, scorched edges,
// fold creases, a coffee ring, a binding gutter, ruled lines, pencil fog.
// Draws with a dark vertex colour (red < 0.5) pass straight through: shadows.

uniform vec2 size = vec2(800.0, 600.0);
uniform vec3 tint : source_color = vec3(0.91, 0.88, 0.8);
uniform int mode = 0;            // 0 paper, 1 leather
uniform vec2 folds = vec2(0.0);  // fold lines across x and y
uniform float wear = 1.0;
uniform float seed = 0.0;
uniform vec3 ring = vec3(0.0);   // coffee ring: x, y, radius (px); radius 0 = none
uniform float gutter = -1.0;     // binding side: 0 left, 1 right, -1 none
uniform float rule = 0.0;        // ruled-line spacing (px), 0 = none
uniform float rule_top = 0.0;
uniform float margin = 0.0;      // red margin line x (px), 0 = none
uniform float fog_from = 0.0;    // pencil-rubbed fog right of this x (px), 0 = none
uniform float fade = 1.0;
// Territory washes: watercolor ellipses. reg = centre xy, radii zw (px);
// regc = tint rgb, strength a. reg_hi = hovered region (-1 none).
uniform int reg_n = 0;
uniform vec4 reg[10];
uniform vec4 regc[10];
uniform int reg_hi = -1;

varying vec2 lp;

void vertex() {
	lp = VERTEX;
}

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21) + seed * 0.137);
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p = p * 2.03 + 17.1;
		a *= 0.5;
	}
	return v;
}

// Signed distance to the sheet's (slightly rounded) edge, negative inside.
float sheet_sdf(vec2 p, float r) {
	vec2 q = abs(p - size * 0.5) - (size * 0.5 - r);
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

// Creases: alternating panel shading plus a dark fold line with a lit lip.
vec3 creases(vec3 col, float u, float n, float len) {
	if (n <= 0.0) return col;
	float cell = u * (n + 1.0);
	float fi = floor(cell);
	float t = fract(cell);
	float panel = len / (n + 1.0);
	float shade = mod(fi, 2.0) < 0.5 ? t : 1.0 - t;
	col *= 1.0 - 0.06 * shade * wear;
	float near = t < 0.5 ? t : 1.0 - t;
	bool outer = (fi < 0.5 && t < 0.5) || (fi > n - 0.5 && t >= 0.5);
	if (!outer) {
		float d = near * panel;
		col *= 1.0 - 0.2 * exp(-d * d / 1.2) * wear;
		float side = t < 0.5 ? 1.0 : 0.0;
		col += 0.05 * exp(-pow(d - 2.5, 2.0) / 2.0) * side * wear;
		// Fibres split along the fold.
		col *= 1.0 - 0.08 * exp(-d * d / 6.0) * step(0.7, noise(vec2(u * len * 0.4, d))) * wear;
	}
	return col;
}

vec3 paper(vec2 p, vec2 uv) {
	vec3 col = tint;
	col *= 0.93 + 0.11 * fbm(p / 210.0);
	col += (hash(floor(p)) - 0.5) * 0.04;
	col -= smoothstep(0.66, 0.95, noise(p / vec2(2.5, 38.0) + 7.0)) * 0.035;
	col -= smoothstep(0.66, 0.95, noise(p / vec2(41.0, 2.2) + 3.0)) * 0.02;
	// Foxing: little rust spots.
	float fx = fbm(p / 34.0 + 13.0);
	col = mix(col, col * vec3(0.84, 0.72, 0.56), smoothstep(0.75, 0.8, fx) * 0.4 * wear);
	// Pencil fog: rubbed graphite past the edge of the known.
	if (fog_from > 0.0) {
		float f = smoothstep(fog_from - 40.0, fog_from + 220.0, p.x);
		float smudge = fbm(p / 70.0 + 5.0) * 0.7 + fbm(p / 14.0) * 0.3;
		col = mix(col, vec3(0.62, 0.61, 0.6), f * smoothstep(0.35, 0.75, smudge) * 0.22);
		col *= 1.0 - f * 0.03;
	}
	// Coffee ring.
	if (ring.z > 0.0) {
		float d = length(p - ring.xy);
		float br = 0.45 + 0.55 * noise(vec2(atan(p.y - ring.y, p.x - ring.x) * 3.0, 0.0) + 2.0);
		float ringv = exp(-pow((d - ring.z) / 1.8, 2.0)) * br;
		float pool = (1.0 - smoothstep(ring.z - 6.0, ring.z, d)) * 0.25 * fbm(p / 18.0);
		col = mix(col, col * vec3(0.72, 0.55, 0.38), clamp(ringv * 0.6 + pool, 0.0, 1.0) * wear);
	}
	// Territory, Victoria-style: every power's colour spreads until it meets a
	// neighbour, then the two bleed into each other across a soft border. Far
	// from everyone the paper stays blank.
	if (reg_n > 0) {
		vec3 rtint = vec3(0.0);
		float wsum = 0.0;
		float dmin = 99.0;
		float w1 = 0.0;
		float w2 = 0.0;
		float hi = 0.0;
		float str = 0.0;
		for (int i = 0; i < 10; i++) {
			if (i >= reg_n) break;
			vec2 q = (p - reg[i].xy) / reg[i].zw;
			float d = length(q) + (fbm(p / 45.0 + float(i) * 7.3) - 0.5) * 0.28;
			float w = exp(-d * 7.0);
			rtint += regc[i].rgb * w;
			str += regc[i].a * w;
			hi += (i == reg_hi ? 1.0 : 0.0) * w;
			wsum += w;
			dmin = min(dmin, d);
			if (w > w1) { w2 = w1; w1 = w; } else if (w > w2) { w2 = w; }
		}
		rtint /= wsum;
		str /= wsum;
		hi /= wsum;
		float cover = 1.0 - smoothstep(1.05, 1.7, dmin);
		float bloom = 0.85 + 0.3 * fbm(p / 22.0);
		// A faint pooled line where two powers meet.
		float border = exp(-pow((w1 - w2) / (w1 + 1e-5) / 0.18, 2.0)) * cover;
		float k = clamp(str * (1.0 + hi * 0.8) * bloom * cover, 0.0, 0.85);
		col = col * mix(vec3(1.0), rtint, k);
		col *= 1.0 - border * 0.22;
	}
	col = creases(col, uv.x, folds.x, size.x);
	col = creases(col, uv.y, folds.y, size.y);
	// Binding gutter.
	if (gutter >= 0.0) {
		float gx = gutter < 0.5 ? p.x : size.x - p.x;
		col *= 1.0 - 0.26 * exp(-gx / 26.0) - 0.06 * exp(-gx / 90.0);
	}
	// Ruled lines and the red margin.
	if (rule > 0.0 && p.y > rule_top) {
		float ly = mod(p.y - rule_top, rule);
		col = mix(col, vec3(0.56, 0.66, 0.8), (1.0 - smoothstep(0.0, 1.2, ly)) * 0.42);
	}
	if (margin > 0.0) {
		float m = min(abs(p.x - margin), abs(p.x - margin - 4.0));
		col = mix(col, vec3(0.8, 0.38, 0.36), (1.0 - smoothstep(0.3, 1.1, m)) * 0.5);
	}
	// Handled, scorched edges and a soft vignette.
	float edge = -sheet_sdf(p, 3.0);
	float burn = 1.0 - smoothstep(0.0, 22.0 + 26.0 * fbm(p / 55.0), edge);
	col = mix(col, col * vec3(0.76, 0.64, 0.48), burn * 0.6 * wear);
	col *= 1.0 - 0.1 * wear * smoothstep(0.25, 0.75, length(uv - 0.5));
	return col;
}

vec3 leather(vec2 p, vec2 uv) {
	vec3 col = tint * (0.78 + 0.34 * fbm(p / 110.0));
	float pebble = noise(p / 2.2) * 0.55 + noise(p / 1.1) * 0.45;
	col *= 0.9 + 0.17 * pebble;
	// Creases in the hide.
	float cr = abs(fbm(p / 40.0 + 9.0) - 0.5);
	col *= 1.0 - 0.18 * (1.0 - smoothstep(0.0, 0.025, cr));
	// Scuffs and polish from hands.
	col = mix(col, col * 1.55 + 0.03, smoothstep(0.68, 0.85, fbm(p / 22.0 + 3.0)) * 0.3);
	float edge = -sheet_sdf(p, 10.0);
	col = mix(col, col * 1.7 + 0.05, (1.0 - smoothstep(0.0, 14.0, edge)) * 0.45);
	// Saddle stitching.
	float inset = abs(edge - 9.0);
	vec2 c = abs(p - size * 0.5) - size * 0.5;
	float along = c.x > c.y ? p.y : p.x;
	float dash = smoothstep(0.38, 0.46, fract(along / 9.0)) * (1.0 - smoothstep(0.88, 0.96, fract(along / 9.0)));
	col *= 1.0 - 0.35 * (1.0 - smoothstep(0.6, 2.4, inset));
	col = mix(col, vec3(0.74, 0.64, 0.46), (1.0 - smoothstep(0.5, 1.4, inset)) * dash * 0.9);
	col *= 1.0 - 0.18 * smoothstep(0.3, 0.8, length(uv - 0.5));
	return col;
}

void fragment() {
	if (COLOR.r >= 0.5) {
		vec2 p = lp;
		vec2 uv = p / size;
		float r = mode == 1 ? 10.0 : 3.0;
		float sd = sheet_sdf(p, r);
		// Deckled, slightly ragged edge.
		float a = 1.0 - smoothstep(-1.0, 0.4, sd + (mode == 1 ? 0.0 : 1.6 * noise(p / 2.7)));
		vec3 col = mode == 1 ? leather(p, uv) : paper(p, uv);
		COLOR = vec4(col, a * fade * COLOR.a);
	} else {
		COLOR.a *= fade;
	}
}
