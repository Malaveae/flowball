extends SceneTree

func _init() -> void:
	var ok := true
	ok = _test_no_drag_is_neutral() and ok
	ok = _test_straight_up_is_neutral() and ok
	ok = _test_half_right_drag() and ok
	ok = _test_far_right_clamps() and ok
	ok = _test_far_left_clamps() and ok
	ok = _test_toe_direction_matches_target() and ok
	print("SupportPlantGestureSmokeTest: ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)

const HEEL := Vector2(-60.0, 20.0)
const MAX_DEG := 30.0

func _test_no_drag_is_neutral() -> bool:
	return SupportPlantGesture.aim_target_from_toe(HEEL, HEEL) == 0.0

func _test_straight_up_is_neutral() -> bool:
	var finger := HEEL + Vector2.UP * 120.0
	return absf(SupportPlantGesture.aim_target_from_toe(HEEL, finger)) < 0.001

func _test_half_right_drag() -> bool:
	# Finger at half the legal arc (15 deg right of up) maps to +0.5 aim target.
	var finger := HEEL + Vector2.UP.rotated(deg_to_rad(15.0)) * 150.0
	return absf(SupportPlantGesture.aim_target_from_toe(HEEL, finger) - 0.5) < 0.01

func _test_far_right_clamps() -> bool:
	var finger := HEEL + Vector2.UP.rotated(deg_to_rad(15.0)) * 40.0 \
		+ Vector2.RIGHT * 500.0
	return SupportPlantGesture.aim_target_from_toe(HEEL, finger) == 1.0

func _test_far_left_clamps() -> bool:
	var finger := HEEL + Vector2.LEFT * 500.0
	return SupportPlantGesture.aim_target_from_toe(HEEL, finger) == -1.0

func _test_toe_direction_matches_target() -> bool:
	var toe := SupportPlantGesture.toe_direction(1.0)
	return toe.angle() == Vector2.UP.rotated(deg_to_rad(MAX_DEG)).angle()
