shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;

uniform float aperture = 0.45;
uniform float energy = 1.0;
uniform vec4 rift_tint : source_color = vec4(0.88, 0.84, 0.74, 1.0);

void vertex() {
	// UV2 stores the 2D spine. Opening moves the lips, preserving stroke length.
	VERTEX.xy = UV2 + (VERTEX.xy - UV2) * aperture;
	VERTEX.z *= aperture;
}

void fragment() {
	vec2 grid_uv = UV * vec2(22.0, 5.0) + vec2(TIME * 0.15, -TIME * 0.08);
	vec2 grid = abs(fract(grid_uv) - 0.5);
	float seam = pow(max(grid.x, grid.y) * 2.0, 42.0);
	float depth = smoothstep(0.0, 0.32, UV.y) * smoothstep(1.0, 0.68, UV.y);
	ALBEDO = mix(rift_tint.rgb * 0.024, rift_tint.rgb * 0.002, depth);
	EMISSION = rift_tint.rgb * seam * 0.05 * energy;
}
