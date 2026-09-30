shader_type canvas_item;

// Godot 4.x: SCREEN_TEXTURE must be declared as a uniform with hint_screen_texture
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

// Global intensity; scales all effects. <0.001 = passthrough.
uniform float intensity : hint_range(0.0, 1.0) = 0.35;

// Per-effect toggles (0.0 = off, 1.0 = full effect)
uniform float scanline_strength : hint_range(0.0, 1.0) = 1.0;
uniform float grain_strength : hint_range(0.0, 1.0) = 1.0;
uniform float chromatic_aberration_strength : hint_range(0.0, 1.0) = 1.0;
uniform float vignette_strength : hint_range(0.0, 1.0) = 1.0;
uniform float curvature_strength : hint_range(0.0, 1.0) = 0.0; // disabled by default
uniform float jitter_strength : hint_range(0.0, 1.0) = 1.0;

// Tuning constants
const float SCANLINE_FREQUENCY = 320.0;
const float SCANLINE_SCROLL_SPEED = 0.3;
const float GRAIN_AMOUNT = 0.02;
const float CHROMATIC_ABERRATION_AMOUNT = 0.001;
const float VIGNETTE_AMOUNT = 0.15;
const float CURVATURE_BARREL = 0.05;
const float JITTER_AMOUNT = 0.001;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

vec2 apply_curvature(vec2 uv, float strength) {
	vec2 centered = uv - 0.5;
	float dist = length(centered);
	float factor = 1.0 + strength * CURVATURE_BARREL * (dist * dist);
	return centered * factor + 0.5;
}

void fragment() {
	vec2 uv = SCREEN_UV;

	// Passthrough when effect is effectively off
	if (intensity < 0.001) {
		COLOR = texture(SCREEN_TEXTURE, uv);
	} else {
		// --- Curvature (barrel distortion) ---
		float curv = curvature_strength * intensity;
		if (curv > 0.0) {
			uv = apply_curvature(uv, curv);
		}

		// --- Signal jitter: tiny horizontal displacement ---
		float jit = jitter_strength * intensity * JITTER_AMOUNT;
		if (jit > 0.0) {
			float jitter_offset = noise(vec2(floor(TIME * 60.0), uv.y * 10.0)) - 0.5;
			uv.x += jitter_offset * jit;
		}

		// --- Chromatic aberration near edges ---
		float ca = chromatic_aberration_strength * intensity * CHROMATIC_ABERRATION_AMOUNT;
		vec2 centered = uv - 0.5;
		float edge_dist = length(centered);
		vec4 color = texture(SCREEN_TEXTURE, uv);
		if (ca > 0.0) {
			float ca_offset = ca * edge_dist * edge_dist * 4.0;
			color.r = texture(SCREEN_TEXTURE, uv + vec2(ca_offset, 0.0)).r;
			color.b = texture(SCREEN_TEXTURE, uv - vec2(ca_offset, 0.0)).b;
		}

		// --- Scanlines: horizontal subtle, ~320px, slow scroll ---
		float scan = scanline_strength * intensity;
		if (scan > 0.0) {
			float scanline = sin((uv.y + TIME * SCANLINE_SCROLL_SPEED * 0.01) * SCANLINE_FREQUENCY * PI);
			scanline = scanline * 0.5 + 0.5;
			scanline = pow(scanline, 2.0);
			float darken = mix(1.0, 0.92, scan * 0.3);
			color.rgb *= mix(1.0, darken, scan);
		}

		// --- Film grain: ~2% ---
		float grain = grain_strength * intensity;
		if (grain > 0.0) {
			float grain_val = hash(uv * vec2(1280.0, 720.0) + vec2(TIME * 2.0, TIME * 3.0));
			grain_val = (grain_val - 0.5) * 2.0;
			color.rgb += grain_val * GRAIN_AMOUNT * grain;
		}

		// --- Vignette: corner darkening, ~15% ---
		float vig = vignette_strength * intensity;
		if (vig > 0.0) {
			float v = 1.0 - dot(centered, centered) * 1.5;
			v = clamp(v, 0.0, 1.0);
			v = pow(v, 1.5);
			float vignette_darken = mix(VIGNETTE_AMOUNT, 0.0, v);
			color.rgb *= 1.0 - vignette_darken * vig;
		}

		COLOR = color;
	}
}
