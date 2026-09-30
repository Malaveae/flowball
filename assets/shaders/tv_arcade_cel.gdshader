shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
uniform vec4 base_color : source_color = vec4(1.0);
uniform bool instance_tint = false;
uniform bool turf = false;
uniform float emission_strength = 0.0;
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	ALBEDO = base_color.rgb * (instance_tint ? COLOR.rgb : vec3(1.0));
	if (turf) {
		vec2 cell = world_position.xz * 45.0;
		float seed = fract(sin(dot(floor(cell), vec2(12.9898, 78.233))) * 43758.5453);
		vec2 blade = fract(cell);
		float mark = step(abs(blade.x - 0.5 + blade.y * 0.2), 0.06) * step(blade.y, 0.7);
		float fade = 1.0 - smoothstep(0.25, 1.0, max(fwidth(cell.x), fwidth(cell.y)));
		ALBEDO *= 1.0 + (seed * 0.12 + mark * 0.16 - 0.06) * fade;
	}
	EMISSION = base_color.rgb * emission_strength;
	ROUGHNESS = 1.0;
}
void light() {
	float value = dot(NORMAL, LIGHT);
	float band = value > 0.45 ? 1.0 : (value > -0.15 ? 0.63 : 0.30);
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * band * ATTENUATION / 3.14159265;
}
