shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled, depth_draw_never;

// --- Textures ---
uniform sampler2D blade_tex : source_color;
uniform sampler2D blade_normal_tex : hint_normal;
uniform sampler2D wind_noise_tex;

// --- Atlas layout ---
// The blade texture is a horizontal strip of N slots. QuadMesh UVs put the
// blade TIP at UV.y=0 and the BASE at UV.y=1 (verified empirically), so the
// atlas is authored tip-up. Vertex picks a slot by per-blade seed.
uniform int atlas_slots : hint_range(1, 16) = 8;

// --- Tuning ---
uniform float alpha_cutoff : hint_range(0.01, 0.95) = 0.35;

// --- Wind: world-space noise texture (core technique from Dylearn) ---
// The noise texture is sampled in world space and scrolled by
// TIME * wind_direction * wind_speed, creating a flowing wind field.
// Each blade samples the field at its world position — spatial coherence
// without oscillation. Two octaves + gust channel + flutter.
uniform vec2 wind_direction = vec2(0.6, 0.8);
uniform float wind_speed : hint_range(0.0, 3.0) = 0.8;
uniform float wind_strength : hint_range(0.0, 1.0) = 0.18;
uniform float wind_noise_scale : hint_range(0.5, 20.0) = 3.5;

// --- Gusts: second noise channel at coarser scale ---
uniform float gust_strength : hint_range(0.0, 2.0) = 0.8;
uniform float gust_speed : hint_range(0.0, 2.0) = 0.4;

// --- Flutter: fast procedural tip vibration ---
uniform float flutter_strength : hint_range(0.0, 0.5) = 0.12;
uniform float flutter_frequency : hint_range(2.0, 10.0) = 5.5;

// --- False perspective: compress blade height by camera distance ---
uniform float perspective_factor : hint_range(0.0, 0.6) = 0.0;
uniform float perspective_max_dist : hint_range(10.0, 100.0) = 55.0;

// --- Animation framerate (0 = continuous, >0 = quantized with stagger) ---
uniform float animation_fps : hint_range(0.0, 30.0) = 0.0;

// --- Reactive displacement (actor interaction) ---
uniform vec3 actor_positions[4];
uniform int actor_count = 0;
uniform float interaction_radius : hint_range(0.0, 3.0) = 1.2;
uniform float interaction_strength : hint_range(0.0, 1.5) = 0.8;

// --- Color variation ---
uniform float brightness_variation : hint_range(0.0, 0.3) = 0.08;

// --- World-space noise patches ---
uniform float patch_noise_scale : hint_range(0.5, 20.0) = 3.5;
uniform float patch_noise_strength : hint_range(0.0, 0.5) = 0.12;

// --- Accent grass ---
uniform float accent_probability : hint_range(0.0, 0.5) = 0.16;

// --- Roystan grass technique (roystan.net/articles/grass-shader) ---
// Thin blades transmit light: blades whose back faces the light still
// receive a floor of illumination. Applied in the custom light() below.
uniform float translucency_gain : hint_range(0.0, 1.0) = 0.4;
// Per-blade forward curve (BladeForward/BladeCurve): each blade leans
// along its own axis, curving more toward the tip (quadratic).
uniform float blade_forward : hint_range(0.0, 1.0) = 0.3;

// World-space blade root position, passed from vertex so fragment noise
// stays pinned to the pitch (fragment VERTEX is view-space in Godot 4).
varying vec3 world_pos;

// Deterministic hash
float hash(float n) {
	return fract(sin(n) * 43758.5453123);
}

float pos_seed(vec3 pos) {
	return hash(pos.x * 1.313 + pos.y * 7.117 + pos.z * 3.149);
}

// 2D value noise for world-space color patches
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

// Accent type from seed: 0..1 encodes what kind of accent blade this is
vec4 accent_attrs(float s) {
	float type = hash(s + 10.0);
	if (type >= accent_probability) {
		return vec4(1.0, 1.0, 0.0, 0.0);
	}
	float flavor = hash(s + 11.0);
	if (flavor < 0.25) {
		return vec4(1.38, 0.75, -0.18, -0.10);
	} else if (flavor < 0.50) {
		return vec4(0.60, 1.40, 0.02, -0.06);
	} else if (flavor < 0.75) {
		return vec4(1.0, 1.25, 0.14, 0.06);
	} else {
		return vec4(0.50, 0.80, -0.25, -0.18);
	}
}

void vertex() {
	float height = 1.0 - UV.y;  // QuadMesh: UV.y=0 is the tip, UV.y=1 the base

	vec3 model_world = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	world_pos = model_world;
	float seed = pos_seed(model_world);
	float scale_seed = hash(seed + 2.0);
	float bend_seed = hash(seed + 3.0);

	// --- Quantized animation time with per-blade stagger ---
	// When animation_fps > 0, TIME is snapped to discrete frames.
	// Each blade gets a different phase offset so they don't all
	// change on the same frame — stop-motion without uniformity.
	float sim_time = TIME;
	if (animation_fps > 0.0) {
		float stagger = hash(seed + 20.0) / animation_fps;
		sim_time = floor((TIME + stagger) * animation_fps) / animation_fps;
	}

	// --- Sprite variation ---
	float slot_count = float(atlas_slots);
	float sprite_pick = floor(hash(seed + 6.0) * slot_count);
	UV = vec2(sprite_pick * (1.0 / slot_count) + UV.x * (1.0 / slot_count), UV.y);

	// --- Accent grass ---
	vec4 accent = accent_attrs(seed);
	float height_variation = (0.75 + scale_seed * 0.5) * accent.x;
	float width_scale = accent.y;

	// --- Manual cylinder billboard ---
	vec3 to_cam = CAMERA_POSITION_WORLD - model_world;
	float yaw = atan(to_cam.x, to_cam.z);
	float cos_yaw = cos(yaw);
	float sin_yaw = sin(yaw);

	vec3 pos = VERTEX;
	VERTEX.x = pos.x * cos_yaw - pos.z * sin_yaw;
	VERTEX.z = pos.x * sin_yaw + pos.z * cos_yaw;

	VERTEX.x *= width_scale;

	// --- Static random bend ---
	float bend_angle = (bend_seed - 0.5) * 0.15;
	VERTEX.x += sin(bend_angle) * height * 0.05;
	VERTEX.z += cos(bend_angle) * height * 0.03;

	// --- Roystan-style forward blade curve ---
	// Quadratic lean along the billboard's camera-facing axis: base anchored,
	// tip leaning furthest (BladeForward/BladeCurve from the article).
	float forward_lean = (bend_seed - 0.5) * blade_forward;
	VERTEX.z += forward_lean * height * height * 0.35;

	VERTEX.y *= height_variation;

	// ───────────────────────────────────────────────
	// World-space texture-based wind (Dylearn method)
	// ───────────────────────────────────────────────
	vec2 wind_dir = normalize(wind_direction);

	// Main wind: sample noise texture at world XZ, scrolled over time.
	vec2 wind_uv = model_world.xz / wind_noise_scale + wind_dir * sim_time * wind_speed;
	float wind_base = texture(wind_noise_tex, wind_uv).r;

	// Detail layer: finer scale, offset for organic complexity.
	vec2 detail_uv = model_world.xz / (wind_noise_scale * 0.28)
	               + wind_dir * sim_time * wind_speed * 1.5 + vec2(127.0, 63.0);
	float wind_detail = texture(wind_noise_tex, detail_uv).r;

	// Gust channel: coarser scale, slower scroll.
	vec2 gust_uv = model_world.xz / (wind_noise_scale * 2.5)
	             + wind_dir * sim_time * gust_speed + vec2(63.0, 127.0);
	float gust_raw = texture(wind_noise_tex, gust_uv).r;
	float gust = smoothstep(0.55, 0.9, gust_raw);

	// Flutter: fast procedural tip vibration (per-blade phase).
	float flutter = sin(sim_time * flutter_frequency + seed * 6.0) * 0.5
	              + cos(sim_time * flutter_frequency * 1.7 + seed * 13.0) * 0.5;
	flutter *= flutter_strength;

	// Bend: quadratic — still at base, maximal at tip.
	float bend = height * height;

	float wind_value    = (wind_base   - 0.5) * 2.0;
	float detail_value  = (wind_detail - 0.5) * 2.0 * 0.3;
	float gust_value    = gust * gust_strength * 0.6;
	float total = (wind_value + detail_value + gust_value + flutter * 0.3) * wind_strength * bend;

	VERTEX.x += wind_dir.x * total;
	VERTEX.z += wind_dir.y * total;

	// ───────────────────────────────────────────────
	// False perspective: compress blade height by camera distance.
	// Far blades appear shorter, adding depth without geometry.
	// ───────────────────────────────────────────────
	float cam_dist = distance(CAMERA_POSITION_WORLD, model_world);
	VERTEX.y *= 1.0 - clamp(cam_dist / perspective_max_dist, 0.0, 1.0) * perspective_factor;

	// ───────────────────────────────────────────────
	// Reactive displacement: push blades away from actors.
	// ───────────────────────────────────────────────
	for (int i = 0; i < 4; i++) {
		if (i >= actor_count) break;
		vec3 to_actor = model_world - actor_positions[i];
		float h_dist = length(to_actor.xz);
		if (h_dist < interaction_radius) {
			float factor = 1.0 - smoothstep(0.0, interaction_radius, h_dist);
			// Squash blade down
			VERTEX.y *= 1.0 - factor * interaction_strength;
			// Push blade away from actor
			vec2 push_dir = normalize(to_actor.xz + vec2(0.001));
			VERTEX.x += push_dir.x * factor * interaction_strength * 0.2;
			VERTEX.z += push_dir.y * factor * interaction_strength * 0.2;
		}
	}
}

void fragment() {
	vec4 tex = texture(blade_tex, UV);
	vec3 normal_tex = texture(blade_normal_tex, UV).rgb;

	// Alpha scissor: hard cutoff keeps blades in the opaque pipeline
	// (depth-correct, no per-instance sorting cost for ~90k quads).
	ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cutoff;

	// --- World-space noise for color patches ---
	float noise_coarse = vnoise(world_pos.xz / patch_noise_scale);
	float noise_fine   = vnoise(world_pos.xz / (patch_noise_scale * 0.3 + 0.001));
	float noise_y      = vnoise(world_pos.xz / (patch_noise_scale * 1.7 + 0.001) + vec2(127.0, 0.0));
	float patch_var = (noise_coarse - 0.5) * patch_noise_strength
	                + (noise_fine   - 0.5) * patch_noise_strength * 0.35
	                + (noise_y      - 0.5) * patch_noise_strength * 0.2;

	// --- Per-instance color variation ---
	float seed = pos_seed(world_pos);
	float color_seed = hash(seed + 4.0);
	float brightness = 1.0 + (color_seed - 0.5) * brightness_variation * 2.0;
	float hue_shift = (hash(seed + 5.0) - 0.5) * 0.04;

	vec4 accent = accent_attrs(seed);
	float accent_r = accent.z;
	float accent_g = accent.w;

	vec3 color = tex.rgb * brightness * (1.0 + patch_var);
	color.g *= (1.0 + hue_shift);
	color.r *= (1.0 - hue_shift * 0.5);
	color.r += accent_r;
	color.g += accent_g;

	// --- Blade-level ambient occlusion ---
	// Base of blade (UV.y ≈ 1) is shadowed by ground and neighbor blades.
	// Tip (UV.y ≈ 0) receives full light.
	float blade_ao = mix(0.68, 1.0, pow(1.0 - UV.y, 0.55));

	// --- Edge transmission (subtle backlight glow at blade edges) ---
	// Thin grass blades let a bit of light through at the silhouette.
	float edge_transmission = (1.0 - tex.a) * 0.08;

	ALBEDO = color * blade_ao + vec3(edge_transmission);

	NORMAL_MAP = normal_tex;

	// Roughness: slightly smoother near tip, rougher near base (occlusion+dirt).
	ROUGHNESS = mix(0.88, 0.76, pow(1.0 - UV.y, 0.5));
	SPECULAR = 0.15;
}

// ───────────────────────────────────────────────
// Custom light: Roystan-style translucent grass
// ───────────────────────────────────────────────
// Thin grass transmits light: blades whose back faces the light still receive
// a floor of illumination (translucency_gain). Shadow attenuation keeps the
// blades readable in shadow while the glow prevents them from going black.
// Mirrors the article's NdotL = saturate(saturate(dot(N,L)) + gain) * shadow.
void light() {
	float ndotl = max(dot(NORMAL, LIGHT), 0.0) + translucency_gain;
	ndotl = clamp(ndotl, 0.0, 1.0) * ATTENUATION;
	DIFFUSE_LIGHT = ALBEDO * LIGHT_COLOR * ndotl;
	// Grass has no meaningful specular (the article's final shader is diffuse-only).
	SPECULAR_LIGHT = vec3(0.0);
}
