shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;

uniform float aperture = 0.45;
uniform float energy = 1.0;
uniform vec4 edge_color : source_color = vec4(0.36, 0.96, 1.0, 1.0);

void vertex() {
	VERTEX.xy = UV2 + (VERTEX.xy - UV2) * aperture;
	VERTEX.z *= aperture;
}

void fragment() {
	float flicker = 0.88 + 0.12 * sin(UV.x * 105.0 - TIME * 17.0);
	ALBEDO = edge_color.rgb;
	EMISSION = edge_color.rgb * (2.2 + COLOR.r) * energy * flicker;
}
