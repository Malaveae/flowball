shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// --- Textures ---
uniform sampler2D albedo_tex : source_color;
uniform sampler2D normal_tex : hint_normal;
uniform sampler2D rough_tex;

// --- UV tiling ---
uniform float uv_scale_x : hint_range(1.0, 100.0) = 42.0;
uniform float uv_scale_y : hint_range(1.0, 100.0) = 64.0;

// --- Mowing stripes: alternating luminance bands along the pitch length ---
// The classic TV broadcast cue: a mower runs parallel bands over the turf.
// Bands are computed in world space so they stay pinned to the field.
uniform float stripe_width : hint_range(1.0, 20.0) = 7.5;     // m per band
uniform float stripe_strength : hint_range(0.0, 0.15) = 0.09;
uniform float stripe_edge : hint_range(0.0, 0.5) = 0.12;      // band-edge softness

// --- Area wear: worn turf near the goal, penalty spot, and shot spot ---
// Darkens/yellows the albedo and raises roughness under a noisy radial mask.
uniform float wear_strength : hint_range(0.0, 1.0) = 0.32;
uniform float wear_radius : hint_range(1.0, 25.0) = 8.0;
uniform float wear_stretch : hint_range(1.0, 4.0) = 1.7;      // elongates patches along Z
uniform float wear_noise_scale : hint_range(0.5, 8.0) = 2.2;
uniform vec3 wear_spot_goal = vec3(0.0, 0.0, -49.5);
uniform vec3 wear_spot_penalty = vec3(0.0, 0.0, -41.5);
uniform vec3 wear_spot_shot = vec3(0.0, 0.0, 0.0);
uniform vec3 wear_weights = vec3(1.0, 0.9, 0.7);              // per-spot influence

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

float _wear_at(vec3 p, vec3 spot, float weight) {
	float d = length((p.xz - spot.xz) / vec2(1.0, wear_stretch));
	float f = 1.0 - smoothstep(wear_radius * 0.25, wear_radius, d);
	return f * weight;
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

	// --- Mowing stripes ---
	// Band index along Z from the goal line (-52.5). Alternating +/-
	// luminance with soft transitions; band edges leave a thin darker seam
	// (the mower's turn line), which is exactly how real pitches read.
	float z_from_goal = world_pos.z + 52.5;                 // 0 at goal line
	float band = floor(z_from_goal / stripe_width);
	float t = z_from_goal / stripe_width - band;            // 0..1 inside band
	float edge = smoothstep(0.0, stripe_edge, t) * (1.0 - smoothstep(1.0 - stripe_edge, 1.0, t));
	float sign_band = mod(band, 2.0) < 1.0 ? 1.0 : -1.0;
	float stripe_factor = 1.0 + sign_band * stripe_strength * mix(0.35, 1.0, edge);

	// --- Area wear ---
	float wear_noise = 0.55 + 0.45 * vnoise(world_pos.xz / wear_noise_scale);
	float wear_goal = _wear_at(world_pos, wear_spot_goal, wear_weights.x);
	float wear_penalty = _wear_at(world_pos, wear_spot_penalty, wear_weights.y);
	float wear_shot = _wear_at(world_pos, wear_spot_shot, wear_weights.z);
	float wear_total = clamp(wear_strength * (wear_goal + wear_penalty + wear_shot), 0.0, 1.0) * wear_noise;

	vec3 col = albedo * (0.78 + patch_var) * stripe_factor;
	col *= 1.0 - wear_total * 0.30;
	col.r += wear_total * 0.035;   // yellower where worn
	col.g -= wear_total * 0.025;
	col.b += wear_total * 0.01;

	ALBEDO = col;
	NORMAL_MAP = normal;
	ROUGHNESS = mix(mix(0.80, 0.96, rough), 0.96, wear_total * 0.5);
	SPECULAR = 0.15;
}
