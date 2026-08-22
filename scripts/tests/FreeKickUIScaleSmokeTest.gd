extends SceneTree

func _init() -> void:
	var ok := true
	ok = _test_widget_scale_bounds() and ok
	ok = _test_widget_scale_at_720_is_one() and ok
	ok = _test_viewport_safe_area_scales() and ok
	print("FreeKickUIScaleSmokeTest: ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)

func _test_widget_scale_bounds() -> bool:
	var low := FreeKickUIScale.widget_scale(300.0)
	var high := FreeKickUIScale.widget_scale(4000.0)
	return low == 0.85 and high == 1.6

func _test_widget_scale_at_720_is_one() -> bool:
	return FreeKickUIScale.widget_scale(720.0) == 1.0

func _test_viewport_safe_area_scales() -> bool:
	# Window 2340x1080, safe area inset 80px left/top, 120px right/bottom on screen.
	# Scale factor 1.5 -> viewport 1560x720.
	var viewport := Vector2(1560.0, 720.0)
	var screen := Vector2(2340.0, 1080.0)
	var safe := Rect2(80.0, 80.0, 2340.0 - 200.0, 1080.0 - 200.0)
	var got := FreeKickUIScale.viewport_safe_area(viewport, screen, safe)
	var expected := Rect2(80.0 / 1.5, 80.0 / 1.5, (2340.0 - 200.0) / 1.5, (1080.0 - 200.0) / 1.5)
	var tol := 0.001
	return (
		absf(got.position.x - expected.position.x) < tol
		and absf(got.position.y - expected.position.y) < tol
		and absf(got.size.x - expected.size.x) < tol
		and absf(got.size.y - expected.size.y) < tol
	)
