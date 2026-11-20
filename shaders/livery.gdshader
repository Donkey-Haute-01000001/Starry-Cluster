shader_type canvas_item;
// Faction livery: repaints the saturated hull paint in the faction's main
// color and the bright trim in its second color. Greys, metal, glass and
// engine lights stay as drawn, so one model reads as many owners.

uniform vec3 paint = vec3(0.3, 0.55, 0.3);
uniform vec3 trim = vec3(0.8, 0.65, 0.3);
uniform float main_hue = -1.0;  // the sprite's dominant paint hue; others are trim
uniform float strength = 1.0;   // 0 = original colors
uniform float shade = 1.0;      // per-ship brightness jitter
uniform float hue_jitter = 0.0; // per-ship hue jitter, in turns

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * clamp(p - 1.0, 0.0, 1.0);
}

void fragment() {
	vec4 src = texture(TEXTURE, UV);
	vec3 hsv = rgb2hsv(src.rgb);
	vec3 out_rgb = src.rgb;
	// Only paint: enough color to be paint, not so bright it's a light.
	float painted = smoothstep(0.28, 0.45, hsv.y) * (1.0 - smoothstep(0.92, 1.0, hsv.z) * step(hsv.y, 0.5));
	if (painted > 0.0) {
		float dh = abs(fract(hsv.x - main_hue + 0.5) - 0.5);
		bool is_trim = main_hue >= 0.0 ? dh > 0.11 : (hsv.z > 0.78 && hsv.y < 0.75);
		vec3 target = rgb2hsv(is_trim ? trim : paint);
		// Keep the drawn shading: carry the source value, scaled toward the target's.
		float v = clamp(hsv.z * mix(1.0, target.z / 0.7, 0.5), 0.0, 1.0);
		vec3 repaint = hsv2rgb(vec3(fract(target.x + hue_jitter), mix(hsv.y, target.y, 0.6), v));
		out_rgb = mix(src.rgb, repaint, painted * strength);
	}
	// Flat draws (shields, flames) sample white: leave them alone.
	float is_art = 1.0 - step(2.995, src.r + src.g + src.b);
	// COLOR already holds texture * modulate: swap the texture's part for ours.
	vec3 ratio = (out_rgb * mix(1.0, shade, is_art)) / max(src.rgb, vec3(0.004));
	COLOR.rgb = clamp(COLOR.rgb * ratio, 0.0, 1.0);
}
