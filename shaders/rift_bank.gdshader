shader_type spatial;
render_mode cull_disabled;

uniform float aperture = 0.45;
uniform float energy = 1.0;
uniform vec4 rift_tint : source_color = vec4(0.88, 0.84, 0.74, 1.0);

void vertex() {
	VERTEX.xy = UV2 + (VERTEX.xy - UV2) * aperture;
	VERTEX.z *= aperture;
}

void fragment() {
	ALBEDO = rift_tint.rgb * mix(0.045, 0.25, COLOR.r);
	METALLIC = 0.7;
	ROUGHNESS = 0.28;
	EMISSION = rift_tint.rgb * 0.06 * energy;
}
