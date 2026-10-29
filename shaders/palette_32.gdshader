shader_type canvas_item;
render_mode unshaded, blend_disabled;

uniform sampler2D frame : hint_screen_texture, repeat_disable, filter_nearest;
uniform int palette_size = 32;
const vec3 PALETTE[32] = vec3[32](
	vec3(0.0314, 0.0275, 0.0235), vec3(0.0902, 0.0706, 0.0627),
	vec3(0.1569, 0.1176, 0.0941), vec3(0.2314, 0.1765, 0.1373),
	vec3(0.3255, 0.2549, 0.2039), vec3(0.4353, 0.3569, 0.2745),
	vec3(0.5569, 0.4745, 0.3608), vec3(0.7059, 0.6275, 0.5020),
	vec3(0.8392, 0.7765, 0.6431), vec3(0.9451, 0.8902, 0.7804),
	vec3(1.0000, 1.0000, 0.8706), vec3(0.1686, 0.0667, 0.0980),
	vec3(0.3137, 0.1176, 0.1608), vec3(0.5216, 0.2000, 0.2000),
	vec3(0.6706, 0.3725, 0.3137), vec3(0.7529, 0.4667, 0.3608),
	vec3(0.7647, 0.5804, 0.4510), vec3(0.8275, 0.7294, 0.5294),
	vec3(0.0784, 0.1569, 0.1098), vec3(0.1922, 0.3176, 0.2039),
	vec3(0.3647, 0.4353, 0.3373), vec3(0.5725, 0.6706, 0.5725),
	vec3(0.7333, 0.7961, 0.6588), vec3(0.0863, 0.1412, 0.1569),
	vec3(0.1137, 0.2745, 0.3333), vec3(0.1882, 0.4745, 0.5216),
	vec3(0.5255, 0.7216, 0.7333), vec3(0.7451, 0.8510, 0.8157),
	vec3(0.2039, 0.1412, 0.2392), vec3(0.4392, 0.2980, 0.5098),
	vec3(0.6471, 0.5686, 0.7137), vec3(0.7765, 0.6078, 0.6588)
);
const int SMALL[16] = int[16](0, 2, 4, 6, 8, 10, 12, 15, 17, 19, 21, 24, 26, 27, 30, 31);
const float BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

void fragment() {
	vec3 color = clamp(textureLod(frame, SCREEN_UV, 0.0).rgb, vec3(0.0), vec3(1.0));
	vec3 first = PALETTE[0];
	vec3 second = PALETTE[1];
	float best = 100.0;
	float next_best = 100.0;
	// Neutral stone stays in the warm grayscale ramp: do not dither it with pink/green.
	float span = max(color.r, max(color.g, color.b)) - min(color.r, min(color.g, color.b));
	bool quiet = span < 0.055 || (color.r >= color.g && color.g >= color.b && color.r - color.g < (color.g - color.b) * 1.35 + 0.015);
	for (int i = 0; i < 32; i++) {
		if (i >= palette_size) { break; }
		int index = palette_size == 16 ? SMALL[i] : i;
		if (quiet && index > 10) { continue; }
		vec3 delta = color - PALETTE[index];
		float distance = dot(delta * delta, vec3(0.30, 0.59, 0.11));
		if (distance < best) {
			next_best = best;
			second = first;
			best = distance;
			first = PALETTE[index];
		} else if (distance < next_best) {
			next_best = distance;
			second = PALETTE[index];
		}
	}
	vec3 segment = second - first;
	float blend = clamp(dot(color - first, segment) / max(dot(segment, segment), 0.00001), 0.0, 1.0);
	ivec2 pixel = ivec2(floor(FRAGCOORD.xy));
	float threshold = (BAYER[(pixel.y % 4) * 4 + pixel.x % 4] + 0.5) / 16.0;
	COLOR = vec4(blend > threshold ? second : first, 1.0);
}
