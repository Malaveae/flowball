shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// --- Textures ---
uniform sampler2D albedo_tex : source_color;
uniform sampler2D normal_tex : hint_normal;
uniform sampler2D rough_tex;

// --- UV tiling ---
uniform float uv_scale_x : hint_range(1.0, 100.0) = 42.0;
uniform float uv_scale_y : hint_range(1.0, 100.0) = 64.0;

// --- World-space noise patches (mirrors grass_card.gdshader) ---
uniform float patch_noise_scale : hint_range(0.5, 20.0) = 3.5;
uniform float patch_noise_strength : hint_range(0.0, 0.5) = 0.12;

// — Identical noise functions to grass_card.gdshader —
float hash(float n) {
	return fract(sin(n) * 43758.5453123);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);

	float a = hash(i.x + i.y * 157.0);
	float b = hash(i.x + 1.0 + i.y * 157.0);
	float c = hash(i.x + (i.y + 1.0) * 157.0);
	float d = hash(i.x + 1.0 + (i.y + 1.0) * 157.0);

	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Fragment VERTEX is view-space in Godot 4, so pass true world position
// from the vertex stage to keep the noise pinned to the pitch.
varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = UV * vec2(uv_scale_x, uv_scale_y);
	vec3 albedo = texture(albedo_tex, uv).rgb;
	vec3 normal = texture(normal_tex, uv).rgb;
	float rough = texture(rough_tex, uv).r;

	// Same noise formula as grass_card so pitch patches align with grass patches.
	float noise_coarse = vnoise(world_pos.xz / patch_noise_scale);
	float noise_fine   = vnoise(world_pos.xz / (patch_noise_scale * 0.3 + 0.001));
	float noise_y      = vnoise(world_pos.xz / (patch_noise_scale * 1.7 + 0.001) + vec2(127.0, 0.0));

	float patch_var = (noise_coarse - 0.5) * patch_noise_strength
	                + (noise_fine   - 0.5) * patch_noise_strength * 0.35
	                + (noise_y      - 0.5) * patch_noise_strength * 0.2;

	ALBEDO = albedo * (0.78 + patch_var);
	NORMAL_MAP = normal;
	ROUGHNESS = mix(0.80, 0.96, rough);
	SPECULAR = 0.15;
}
