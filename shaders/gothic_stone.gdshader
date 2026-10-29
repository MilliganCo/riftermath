shader_type spatial;

uniform vec4 base_tint : source_color = vec4(0.28, 0.30, 0.28, 1.0);
uniform float stone_scale = 1.3;
varying vec3 world_point;
varying vec3 world_normal;

void vertex() {
	world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec3 axis = abs(world_normal);
	vec2 uv = axis.y > 0.6 ? world_point.xz : (axis.x > axis.z ? world_point.zy : world_point.xy);
	uv *= stone_scale;
	uv.x += mod(floor(uv.y), 2.0) * 0.5;
	vec2 cell = floor(uv);
	vec2 local = fract(uv);
	float seed = fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
	float mortar = smoothstep(0.015, 0.045, min(min(local.x, 1.0 - local.x), min(local.y, 1.0 - local.y)));
	float fracture = 1.0 - smoothstep(0.006, 0.018, abs(local.x - local.y * 0.45 - seed));
	float grain = sin(world_point.x * 17.0 + world_point.y * 8.0) * sin(world_point.z * 13.0 + world_point.y * 11.0);
	float value = mix(0.47, 0.84 + seed * 0.26, mortar) - fracture * 0.08 + grain * 0.025;
	ALBEDO = base_tint.rgb * value;
	ROUGHNESS = 0.94;
	METALLIC = 0.05;
}
