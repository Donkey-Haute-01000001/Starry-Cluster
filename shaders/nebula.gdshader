shader_type canvas_item;
// Deep-space backdrop: layered fractal noise clouds in two colours, drifting
// slowly with the camera for parallax. Cheap enough for a full-screen rect.

uniform vec2 cam = vec2(0.0);          // camera position in world units
uniform vec4 tint_a : source_color = vec4(0.10, 0.32, 0.55, 1.0);
uniform vec4 tint_b : source_color = vec4(0.38, 0.12, 0.45, 1.0);
uniform float density = 0.55;
uniform float seed = 0.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7)) + seed) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) {
	float v = 0.0, a = 0.5;
	for (int k = 0; k < 6; k++) { v += a * noise(p); p = p * 2.03 + vec2(1.7, 9.2); a *= 0.5; }
	return v;
}

void fragment() {
	vec2 px = SCREEN_UV / SCREEN_PIXEL_SIZE;            // screen pixels
	vec2 p = (px + cam * 0.025) / 520.0;                 // slow parallax
	vec2 q = vec2(fbm(p + vec2(0.0, TIME * 0.004)), fbm(p + vec2(5.2, 1.3)));
	float n = fbm(p + 1.8 * q);
	float m = fbm(p * 0.6 + q.yx * 1.3 + vec2(3.1, 7.7));
	float cloud = smoothstep(0.42, 0.95, n) * density;
	float wisps = smoothstep(0.55, 1.0, m) * density * 0.8;
	vec3 col = tint_a.rgb * cloud + tint_b.rgb * wisps;
	// Bright filaments where both layers overlap.
	col += vec3(0.55, 0.75, 1.0) * pow(cloud * wisps, 1.6) * 0.9;
	// Dust lanes darken some of it.
	col *= 1.0 - smoothstep(0.55, 0.85, fbm(p * 1.7 + 11.0)) * 0.6;
	vec3 base = vec3(0.006, 0.012, 0.028);
	COLOR = vec4(base + col, 1.0);
}
