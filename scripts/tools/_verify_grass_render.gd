extends SceneTree

## Renders the sandbox for a few frames and captures a screenshot for
## visual verification of the Tier 1 grass pass. Prints basic pixel stats
## so the capture can be sanity-checked without opening an image viewer.
## Run: godot --path . --script scripts/tools/_verify_grass_render.gd

const SHOT_PATH := "G:/tmp/grass_tier1_check.png"

var _frames := 0

func _initialize() -> void:
	var scene: Node = load("res://scenes/sandbox/FreeKickSandbox.tscn").instantiate()
	root.add_child(scene)

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 60:
		return false  # let physics + camera settle
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(SHOT_PATH)
	_print_stats(img)
	print("captured: ", SHOT_PATH)
	quit(0)
	return true

func _print_stats(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var samples := 0
	var r := 0.0
	var g := 0.0
	var b := 0.0
	var dark := 0
	var sky := 0
	# Sample a grid across the lower 2/3 of the frame (pitch region)
	for y in range(int(h * 0.35), h, 8):
		for x in range(0, w, 8):
			var c := img.get_pixel(x, y)
			r += c.r
			g += c.g
			b += c.b
			samples += 1
			if c.r + c.g + c.b < 0.15:
				dark += 1
			if c.b > c.g * 1.3 and c.b > 0.3:
				sky += 1
	if samples == 0:
		print("no samples")
		return
	r /= samples
	g /= samples
	b /= samples
	print("pitch-region avg RGB: (%.3f, %.3f, %.3f) | dark_ratio=%.3f sky_ratio=%.3f" % [r, g, b, float(dark) / samples, float(sky) / samples])
	# Grass reads as green when g is clearly above r and b
	var greenish := g > r * 1.15 and g > b * 1.2
	print("pitch-region looks like grass: ", greenish)
