extends SceneTree

## One-off asset prep for the score HUD frame.
## The generated hud_panel_frame.png has fake alpha: the "transparent" and
## "glass" areas are an opaque baked checkerboard. All processing runs at the
## final 180px height (fast) with this sequence:
##   1. Rescale source to target height
##   2. Chroma-key the exterior checker grays to alpha 0
##   3. Flood from the outside through everything that is NOT the bright neon
##      core ring; erase all reached pixels (kills checker residue + glow halo)
##   4. Repaint the enclosed dark glass interior with a clean navy gradient
##   5. Feather exterior edges, crop to alpha bbox
## Output: assets/ui/score_frame.png

const SRC_PATH := "res://assets/Inputs RAW/REvamp/generated/hud_panel_frame.png"
const DST_PATH := "res://assets/ui/score_frame.png"
const TARGET_HEIGHT := 180
const MIN_INTERIOR_PIXELS := 15000


func _initialize() -> void:
	_run()


func _run() -> void:
	var img := Image.load_from_file(SRC_PATH)
	if img == null:
		push_error("[CROP] could not load source frame")
		quit(1)
		return
	img.convert(Image.FORMAT_RGBA8)
	# Crop to the frame's alpha bbox measured at full resolution in a prior
	# analysis pass: (182, 403, 2388x731). Cropping BEFORE the rescale makes the
	# final texture height match the 180px HUD design so NinePatch borders and
	# corners render 1:1 without vertical distortion.
	var frame_bbox := Rect2i(182, 403, 2388, 731)
	img = img.get_region(frame_bbox)
	# 1) Rescale FIRST so every later pass runs at the final asset size.
	var scale_f := float(TARGET_HEIGHT) / float(img.get_height())
	var target_w := maxi(1, int(round(img.get_width() * scale_f)))
	img.resize(target_w, TARGET_HEIGHT, Image.INTERPOLATE_LANCZOS)
	var w := img.get_width()
	var h := img.get_height()
	print("[CROP] processing at ", w, "x", h)

	print("[CROP] stage: keying")
	# 2) Exterior checker grays -> transparent (helps the flood connect).
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			var maxc := maxf(c.r, maxf(c.g, c.b))
			var minc := minf(c.r, minf(c.g, c.b))
			var luma := 0.299 * c.r + 0.587 * c.g + 0.114 * c.b
			if (maxc - minc) <= 0.05 and luma > 0.22 and luma < 0.62:
				img.set_pixel(x, y, Color(c.r, c.g, c.b, 0.0))

	print("[CROP] stage: flood")
	# 3) Flood from outside through everything that is not neon core; erase.
	# Visited mask uses an exact byte array: alpha-marker hacks break because
	# RGBA8 stores 0.5 as 128/255 (~0.502) and equality never matches.
	var visited := PackedByteArray()
	visited.resize(w * h)
	var queue: Array[Vector2i] = [Vector2i(0, 0)]
	visited[0] = 1
	while not queue.is_empty():
		var p: Vector2i = queue.pop_back()
		for off in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
			var q: Vector2i = p + off
			if q.x < 0 or q.y < 0 or q.x >= w or q.y >= h:
				continue
			var idx := q.y * w + q.x
			if visited[idx] == 1:
				continue
			var c := img.get_pixelv(q)
			var maxc := maxf(c.r, maxf(c.g, c.b))
			var minc := minf(c.r, minf(c.g, c.b))
			if (maxc - minc) > 0.15 and c.g > 0.35:
				continue  # neon core frontier: the ring stays
			visited[idx] = 1
			queue.push_back(q)
	for y in h:
		for x in w:
			if visited[y * w + x] == 1:
				img.set_pixel(x, y, Color(0, 0, 0, 0))

	print("[CROP] stage: interior")
	# 4) Interior glass repaint (gradient + subtle center glow).
	var filled := 0
	var fill_top := Color(0.015, 0.055, 0.095, 0.84)
	var fill_bottom := Color(0.010, 0.040, 0.075, 0.88)
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			if c.a < 0.99:
				continue
			var luma := 0.299 * c.r + 0.587 * c.g + 0.114 * c.b
			if luma >= 0.35:
				continue
			var t := float(y) / float(h)
			var grad := fill_top.lerp(fill_bottom, t)
			var d := Vector2(x - w / 2.0, (y - h / 2.0) * 1.6).length() / (w * 0.30)
			var glow := clampf(1.0 - d, 0.0, 1.0)
			grad = grad.lerp(Color(0.10, 0.32, 0.42, 0.80), glow * 0.35)
			img.set_pixel(x, y, grad)
			filled += 1
	print("[CROP] repainted ", filled, " interior pixels")
	if filled < MIN_INTERIOR_PIXELS:
		push_error("[CROP] interior repaint too small (%d) - ring leak suspected, aborting" % filled)
		quit(1)
		return

	print("[CROP] stage: feather")
	# 5) Feather exterior edges, crop, save.
	var feather := Image.new()
	feather.copy_from(img)
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			var c := img.get_pixel(x, y)
			if c.a == 0.0:
				continue
			var maxc := maxf(c.r, maxf(c.g, c.b))
			var minc := minf(c.r, minf(c.g, c.b))
			if (maxc - minc) > 0.10:
				continue
			for off in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
				var n: Vector2i = Vector2i(x, y) + off
				if n.x < 0 or n.y < 0 or n.x >= w or n.y >= h:
					continue
				if img.get_pixelv(n).a == 0.0:
					feather.set_pixel(x, y, Color(c.r, c.g, c.b, c.a * 0.4))
					break
	img = feather
	var used := img.get_used_rect()
	print("[CROP] used_rect=", used)
	if used.size.x <= 0 or used.size.y <= 0:
		push_error("[CROP] nothing left after processing")
		quit(1)
		return
	var cropped := img.get_region(used)
	var err := cropped.save_png(DST_PATH)
	print("[CROP] saved ", DST_PATH, " ", cropped.get_width(), "x", cropped.get_height(), " err=", err)
	quit(0 if err == OK else 1)