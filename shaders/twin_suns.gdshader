shader_type sky;
render_mode disable_fog;

uniform vec3 red_direction = vec3(0.4, 0.35, -0.85);
uniform vec3 green_direction = vec3(-0.3, 0.43, -0.85);
uniform float red_radius = 0.075;
uniform float green_radius = 0.032;
uniform float daylight = 0.4;
uniform float pressure = 0.0;

void sky() {
	float height = clamp(EYEDIR.y, 0.0, 1.0);
	vec3 horizon = mix(vec3(0.045, 0.037, 0.030), vec3(0.14, 0.095, 0.065), daylight);
	vec3 zenith = vec3(0.020, 0.017, 0.015);
	vec3 color = mix(horizon, zenith, pow(height, 0.48));
	float clouds = sin(EYEDIR.x * 13.0 + EYEDIR.z * 9.0) * sin(EYEDIR.y * 46.0 + EYEDIR.x * 4.0);
	color *= 0.91 + clouds * 0.09;
	color *= 1.0 - pressure * 0.77;
	if (EYEDIR.y > -0.01) {
		float red_angle = acos(clamp(dot(EYEDIR, normalize(red_direction)), -1.0, 1.0));
		float green_angle = acos(clamp(dot(EYEDIR, normalize(green_direction)), -1.0, 1.0));
		float red_disc = 1.0 - smoothstep(red_radius * 0.96, red_radius, red_angle);
		float green_disc = 1.0 - smoothstep(green_radius * 0.94, green_radius, green_angle);
		float scar = 0.86 + sin(EYEDIR.y * 260.0 + EYEDIR.x * 90.0) * 0.14;
		color += vec3(0.08, 0.022, 0.012) * exp(-red_angle * 15.0) * (1.0 - pressure * 0.75);
		color = mix(color, vec3(0.40, 0.14, 0.105) * scar * (1.0 - pressure * 0.16), red_disc);
		color = mix(color, vec3(0.15, 0.24, 0.13) * (0.90 + scar * 0.10), green_disc);
	} else {
		color *= 0.4;
	}
	COLOR = color;
}
