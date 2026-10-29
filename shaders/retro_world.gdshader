shader_type canvas_item;
render_mode unshaded;
uniform sampler2D world_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float pixel_size : hint_range(1.0, 4.0, 1.0) = 2.0;
uniform float sharpness : hint_range(0.0, 0.4) = 0.16;
uniform float heat : hint_range(0.0, 1.0) = 0.0;
uniform float pressure : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 step_size = SCREEN_PIXEL_SIZE * pixel_size;
	vec2 uv = (floor(SCREEN_UV / step_size) + 0.5) * step_size;
	vec3 color = textureLod(world_texture, uv, 0.0).rgb;
	vec3 neighbors = (textureLod(world_texture, uv + vec2(step_size.x, 0.0), 0.0).rgb
		+ textureLod(world_texture, uv - vec2(step_size.x, 0.0), 0.0).rgb
		+ textureLod(world_texture, uv + vec2(0.0, step_size.y), 0.0).rgb
		+ textureLod(world_texture, uv - vec2(0.0, step_size.y), 0.0).rgb) * 0.25;
	color = max(vec3(0.0), color + (color - neighbors) * sharpness);
	float high = max(color.r, max(color.g, color.b));
	float low = min(color.r, min(color.g, color.b));
	float neutral = 1.0 - smoothstep(0.18, 0.45, (high - low) / max(high, 0.001));
	float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
	// Grade quiet architecture; saturated cyan/violet/orange rifts keep their hue.
	vec3 bone = vec3(1.12, 1.04, 0.90);
	vec3 ember = vec3(1.18, 0.90, 0.72);
	vec3 tint = mix(vec3(0.90, 0.80, 0.72), mix(bone, ember, heat * 0.6), smoothstep(0.03, 0.55, luma));
	color = mix(color, color * tint, neutral * 0.8);
	color *= 1.0 - pressure * neutral * 0.12;
	// The final frame (world + UI) is quantized by the shared 16/32-color pass.
	float vignette = 1.0 - smoothstep(0.30, 0.78, length(SCREEN_UV - 0.5)) * (0.18 + pressure * 0.16);
	COLOR = vec4(color * vignette, 1.0);
}
