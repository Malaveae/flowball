extends SceneTree

## One-off: generates a small neon panel frame (dark glass + rounded cyan
## neon ring with glow) via a signed-distance field, for the compact HUD
## panels (Wind, Dist/Angle). Same visual language as the score frame asset.
## Output: assets/ui/panel_frame_small.png (240x120, RGBA)

const DST_PATH := "res://assets/ui/panel_frame_small.png"
const W := 240
const H := 120
const RADIUS := 14.0
const CORE_HALF_WIDTH := 1.6
const GLOW_EXTENT := 9.0


func _initialize() -> void:
	_run()


func _sd_rounded_rect(p: Vector2, half: Vector2, radius: float) -> float:
	var q := p.abs() - (half - Vector2(radius, radius))
	return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - radius


func _run() -> void:
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	var half := Vector2(W, H) * 0.5
	var fill_top := Color(0.015, 0.055, 0.095, 0.82)
	var fill_bottom := Color(0.010, 0.040, 0.075, 0.86)
	var core := Color(0.35, 0.92, 1.0, 1.0)
	var glow := Color(0.10, 0.82, 1.0, 0.0)
	for y in H:
		for x in W:
			var p := Vector2(x + 0.5, y + 0.5)
			var d := _sd_rounded_rect(p - half, half, RADIUS)
			var color := Color(0, 0, 0, 0)
			if d < 0.0:
				# Interior glass: navy gradient + soft center glow.
				var t := float(y) / float(H)
				color = fill_top.lerp(fill_bottom, t)
				var dg := Vector2(p.x - half.x, (p.y - half.y) * 1.6).length() / (half.x * 0.9)
				color = color.lerp(Color(0.08, 0.28, 0.38, 0.80), clampf(1.0 - dg, 0.0, 1.0) * 0.4)
				# Fade glass toward the ring so the core line sits on soft glass.
				if d > -CORE_HALF_WIDTH:
					color.a = lerpf(color.a, 0.55, clampf(1.0 + d / CORE_HALF_WIDTH, 0.0, 1.0))
			elif d <= CORE_HALF_WIDTH:
				# Neon core line, anti-aliased across the width.
				var edge := 1.0 - absf(d) / CORE_HALF_WIDTH
				color = core
				color.a = clampf(edge, 0.0, 1.0)
			elif d <= GLOW_EXTENT:
				# Outer glow falloff (falloff^2 reads as neon bloom).
				var t2 := (d - CORE_HALF_WIDTH) / (GLOW_EXTENT - CORE_HALF_WIDTH)
				color = glow
				color.a = (1.0 - t2) * (1.0 - t2) * 0.55
			img.set_pixel(x, y, color)
	var err := img.save_png(DST_PATH)
	print("[GEN] saved ", DST_PATH, " ", W, "x", H, " err=", err)
	quit(0 if err == OK else 1)