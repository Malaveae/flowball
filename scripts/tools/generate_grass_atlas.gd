extends SceneTree

## Deterministic grass blade atlas generator (Tier 1 césped).
##
## Produces an 8-slot horizontal strip atlas (1024x256) plus a matching
## tangent-space normal map, both written under assets/textures/.
##
## Texture orientation follows Godot's QuadMesh UVs (verified empirically):
##   UV.y == 0  ->  mesh top vertex  ->  blade TIP
##   UV.y == 1  ->  mesh bottom      ->  blade BASE
## Therefore the atlas draws the tip at the TOP of the texture (y=0)
## and the base at the BOTTOM (y=255).
##
## Run from repo root:
##   godot --headless --script scripts/tools/generate_grass_atlas.gd
##
## The sandbox scene (and GrassPatch.tscn) reference the atlas via
## res://assets/textures/grass_blade_atlas{,_normal}.png.

const ATLAS_PATH := "res://assets/textures/grass_blade_atlas.png"
const NORMAL_PATH := "res://assets/textures/grass_blade_atlas_normal.png"

const SLOT_COUNT := 8
const SLOT_W := 128
const SLOT_H := 256

# --- Deterministic hash (mirrors the shader's hash) ---
func _hash(n: float) -> float:
	return fposmod(sin(n) * 43758.5453123, 1.0)


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20240831  # fixed seed: identical atlas every run

	var atlas := Image.create(SLOT_COUNT * SLOT_W, SLOT_H, false, Image.FORMAT_RGBA8)
	atlas.fill(Color(0, 0, 0, 0))

	var layouts := _slot_layouts(rng)
	for s in SLOT_COUNT:
		_draw_slot(atlas, s, layouts[s], rng)

	atlas.save_png(ATLAS_PATH)

	var nrm := _build_normal_map(atlas)
	nrm.save_png(NORMAL_PATH)

	# --- Sanity stats ---
	var opaque := 0
	for y in SLOT_H:
		for x in SLOT_COUNT * SLOT_W:
			if atlas.get_pixel(x, y).a > 0.5:
				opaque += 1
	print("grass atlas: ", atlas.get_width(), "x", atlas.get_height(),
			" | opaque px ratio: ", float(opaque) / float(SLOT_COUNT * SLOT_W * SLOT_H))
	quit(0)


## Builds the slot list. Slots 0-4 are single blades with distinct shape
## profiles; slots 5-7 are clusters of 2-3 blades to break repetition.
func _slot_layouts(rng: RandomNumberGenerator) -> Array:
	var layouts: Array = []

	# Single blades: base_half_width, tip_y, lean (px at tip), curl factor, hue
	var singles := [
		[26.0, 250.0, 4.0, 0.0, 0.33],
		[22.0, 232.0, 30.0, 0.0, 0.35],
		[24.0, 245.0, -34.0, 0.0, 0.31],
		[20.0, 205.0, 12.0, 0.6, 0.34],
		[32.0, 255.0, -6.0, 0.0, 0.33],
	]
	for s in singles:
		layouts.append({
			"blades": [_jitter_blade(rng, s[0], s[1], s[2], s[3], s[4])],
		})

	# Clusters: list of [base_half_width, tip_y, lean, curl, hue, bx]
	var clusters := [
		[[22.0, 240.0, -20.0, 0.0, 0.35, 42.0], [18.0, 215.0, 18.0, 0.3, 0.32, 88.0]],
		[[16.0, 235.0, 25.0, 0.0, 0.34, 28.0], [24.0, 252.0, -10.0, 0.0, 0.32, 66.0], [15.0, 220.0, -28.0, 0.4, 0.36, 100.0]],
		[[20.0, 255.0, 8.0, 0.0, 0.33, 40.0], [26.0, 248.0, -22.0, 0.0, 0.31, 86.0]],
	]
	for c in clusters:
		var blades: Array = []
		for b in c:
			blades.append(_jitter_blade(rng, b[0], b[1], b[2], b[3], b[4], b[5]))
		layouts.append({"blades": blades})

	return layouts


func _jitter_blade(rng: RandomNumberGenerator, base_hw: float, tip_y: float,
		lean: float, curl: float, hue: float, bx: float = 64.0) -> Dictionary:
	return {
		"bx": bx + rng.randf_range(-6.0, 6.0),
		"base_hw": base_hw * rng.randf_range(0.9, 1.1),
		"tip_y": tip_y + rng.randf_range(-10.0, 8.0),
		"lean": lean * rng.randf_range(0.85, 1.15),
		"curl": curl * rng.randf_range(0.7, 1.3),
		"hue": hue + rng.randf_range(-0.015, 0.015),
	}


func _inside_blade(sx: float, sy: float, b: Dictionary) -> bool:
	var tip_y: float = b.tip_y
	if sy < tip_y - 2.0 or sy > SLOT_H - 1.0:
		return false
	# t: 0 at base (bottom), 1 at tip (top)
	var t := clampf((SLOT_H - 1.0 - sy) / (SLOT_H - 1.0 - tip_y + 2.0), 0.0, 1.0)
	var hw: float = b.base_hw * pow(1.0 - t * 0.94, 1.25) + 1.0
	var cx: float = b.bx + b.lean * t * t + b.curl * sin(t * PI)
	return absf(sx - cx) <= hw


func _draw_slot(img: Image, slot: int, layout: Dictionary, _rng: RandomNumberGenerator) -> void:
	var x0 := slot * SLOT_W
	var blades: Array = layout.blades
	# 4x supersampling for ~1px anti-aliased coverage (alpha scissor friendly)
	var subs := [Vector2(-0.25, -0.25), Vector2(0.25, -0.25), Vector2(-0.25, 0.25), Vector2(0.25, 0.25)]

	for px in SLOT_W:
		for py in SLOT_H:
			var cov := 0.0
			var hit: Dictionary = {}
			for sp: Vector2 in subs:
				var sx := px + sp.x
				var sy := py + sp.y
				for b: Dictionary in blades:
					if _inside_blade(sx, sy, b):
						cov += 0.25
						hit = b
						break
			if cov <= 0.0:
				continue

			# Color: darker base -> lighter, slightly yellower tip + per-pixel noise
			var t := clampf((SLOT_H - 1.0 - py) / (SLOT_H - 1.0 - hit.tip_y + 2.0), 0.0, 1.0)
			var base_col := Color.from_hsv(hit.hue, 0.62, 0.47)
			var tip_col := Color.from_hsv(clampf(hit.hue - 0.04, 0.0, 1.0), 0.5, 0.68)
			var col := base_col.lerp(tip_col, t)
			var noise := 0.94 + 0.12 * _hash(px * 3.1 + py * 7.7 + x0 * 0.13)
			col *= noise

			img.set_pixel(x0 + px, py, Color(col.r, col.g, col.b, cov * 255.0))


## Tangent-space normal map from the atlas alpha silhouette (Sobel) + micro noise.
func _build_normal_map(src: Image) -> Image:
	var w := src.get_width()
	var h := src.get_height()
	var nrm := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var amp := 0.55

	for x in w:
		for y in h:
			var a := src.get_pixel(x, y).a
			var al := src.get_pixel(clampi(x - 1, 0, w - 1), y).a
			var ar := src.get_pixel(clampi(x + 1, 0, w - 1), y).a
			var au := src.get_pixel(x, clampi(y - 1, 0, h - 1)).a
			var ad := src.get_pixel(x, clampi(y + 1, 0, h - 1)).a

			var n := Vector3(-(ar - al) * amp, -(ad - au) * amp, 1.0).normalized()
			# Micro noise keeps blades from reading as glassy
			n += Vector3((_hash(x * 0.31 + y * 1.7) - 0.5) * 0.06,
					(_hash(x * 2.9 + y * 0.23) - 0.5) * 0.06, 0.0)
			n = n.normalized()

			nrm.set_pixel(x, y, Color(n.x * 0.5 + 0.5, n.y * 0.5 + 0.5, n.z * 0.5 + 0.5, 1.0))
	return nrm
