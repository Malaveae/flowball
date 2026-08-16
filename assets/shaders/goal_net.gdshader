// Goal net deformation shader.
// Deforms the imported net mesh around the ball impact point on the GPU,
// replacing the old per-cylinder CPU animation. The displacement matches
// GoalNetVisual3D's legacy formula so the feel stays the same.
shader_type spatial;
render_mode cull_disabled, blend_mix, depth_draw_opaque;

// White netting with slight translucency.
uniform vec4 net_color : source_color = vec4(0.96, 0.97, 1.0, 0.6);
uniform float net_roughness : hint_range(0.0, 1.0) = 0.85;

// Deformation controls (object space).
uniform vec3 impact_point : source_color = vec3(0.0);
uniform float impulse : hint_range(0.0, 1.0) = 0.0;
uniform float reaction_radius : hint_range(0.5, 4.0) = 2.0;
uniform float reaction_strength : hint_range(0.0, 1.0) = 0.18;

void vertex() {
	if (impulse > 0.001) {
		// Same falloff as the old CPU version: squared, radius ~2 m.
		float distance_to_impact = distance(VERTEX, impact_point);
		float weight = clamp(1.0 - distance_to_impact / reaction_radius, 0.0, 1.0);
		weight = weight * weight;
		VERTEX += vec3(0.0, -impulse * reaction_strength * weight, -impulse * weight);
	}
}

void fragment() {
	ALBEDO = net_color.rgb;
	ALPHA = net_color.a;
	ROUGHNESS = net_roughness;
	METALLIC = 0.0;
}
