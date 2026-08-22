extends SceneTree

func _init() -> void:
	var ok := true
	ok = _test_release_location_advances() and ok
	ok = _test_release_angle_commits() and ok
	ok = _test_toggle_requires_legal_and_marker() and ok
	ok = _test_toggle_cycles_modes() and ok
	ok = _test_angle_release_without_marker_noop() and ok
	print("SupportGestureRouterSmokeTest: ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)

const LOCATION := SupportGestureRouter.LOCATION
const ANGLE := SupportGestureRouter.ANGLE
const A := SupportGestureRouter.Action

func _test_release_location_advances() -> bool:
	return SupportGestureRouter.resolve_release(LOCATION, true) == A.ADVANCE_SUBSTEP

func _test_release_angle_commits() -> bool:
	return SupportGestureRouter.resolve_release(ANGLE, true) == A.COMMIT

func _test_toggle_requires_legal_and_marker() -> bool:
	return SupportGestureRouter.resolve_touch_press(LOCATION, false, true, true) == A.NONE \
		and SupportGestureRouter.resolve_touch_press(LOCATION, true, true, false) == A.NONE \
		and SupportGestureRouter.resolve_touch_press(LOCATION, true, false, true) == A.NONE

func _test_toggle_cycles_modes() -> bool:
	return SupportGestureRouter.resolve_touch_press(LOCATION, true, true, true) == A.TOGGLE_TO_ANGLE \
		and SupportGestureRouter.resolve_touch_press(ANGLE, true, true, true) == A.TOGGLE_TO_LOCATION

func _test_angle_release_without_marker_noop() -> bool:
	return SupportGestureRouter.resolve_release(ANGLE, false) == A.NONE
