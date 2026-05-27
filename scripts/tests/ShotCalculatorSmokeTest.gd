extends SceneTree

func _init() -> void:
	var ok := true
	ok = _test_same_input_is_repeatable() and ok
	ok = _test_overpower_increases_error() and ok
	ok = _test_default_timeout_penalty() and ok
	ok = _test_lower_contact_lifts_ball() and ok
	ok = _test_center_contact_goes_straighter() and ok
	ok = _test_side_swipe_adds_strong_curve() and ok
	ok = _test_right_half_contact_with_left_support_curls_left() and ok
	ok = _test_right_half_contact_with_right_support_curls_left() and ok
	ok = _test_support_aim_target_adjusts_aim() and ok
	ok = _test_support_aim_target_reaches_goal_side() and ok
	ok = _test_spot_angle_is_not_double_counted() and ok
	ok = _test_extended_follow_through_increases_curve() and ok
	ok = _test_support_location_does_not_directly_aim() and ok
	ok = _test_support_foot_side_is_physical() and ok
	quit(0 if ok else 1)

func _base_input(power: float = 0.7) -> FreeKickInputData:
	var input := FreeKickInputData.new()
	input.hold_time = 1.0
	input.power_normalized = power
	input.selected_foot = "right"
	input.support_vector = Vector2(0.2, 0.0)
	input.plant_depth = 0.0
	input.impact_point = Vector2(0.15, -0.2)
	input.swipe_points = PackedVector2Array([Vector2.ZERO, Vector2(0.25, -0.35)])
	input.swipe_duration = 0.2
	return input

func _stats() -> PlayerFreeKickStats:
	var stats := PlayerFreeKickStats.new()
	stats.kick_power = 75.0
	stats.free_kick_accuracy = 75.0
	stats.curve = 75.0
	stats.technique = 75.0
	stats.composure = 75.0
	stats.weak_foot = 65.0
	stats.preferred_foot = "right"
	return stats

func _environment() -> FreeKickEnvironment:
	var environment := FreeKickEnvironment.new()
	environment.distance_to_goal = 24.0
	environment.angle_to_goal = 0.0
	environment.base_goal_direction = Vector3.FORWARD
	return environment

func _difficulty() -> FreeKickDifficulty:
	return FreeKickDifficulty.new()

func _test_same_input_is_repeatable() -> bool:
	var a := ShotCalculator.calculate(_base_input(), _stats(), _environment(), _difficulty())
	var b := ShotCalculator.calculate(_base_input(), _stats(), _environment(), _difficulty())
	var passed := a.launch_velocity.is_equal_approx(b.launch_velocity) and is_equal_approx(a.spin_rate, b.spin_rate)
	_print_result("same input is repeatable", passed)
	return passed

func _test_overpower_increases_error() -> bool:
	var controlled := ShotCalculator.calculate(_base_input(0.75), _stats(), _environment(), _difficulty())
	var overpowered := ShotCalculator.calculate(_base_input(0.98), _stats(), _environment(), _difficulty())
	var passed := overpowered.error_cone_degrees > controlled.error_cone_degrees
	_print_result("overpower increases error", passed)
	return passed

func _test_default_timeout_penalty() -> bool:
	var clean_input := _base_input(0.75)
	var default_input := _base_input(0.75)
	default_input.used_default_support = true
	default_input.used_default_contact = true
	var clean := ShotCalculator.calculate(clean_input, _stats(), _environment(), _difficulty())
	var penalized := ShotCalculator.calculate(default_input, _stats(), _environment(), _difficulty())
	var passed := penalized.error_cone_degrees > clean.error_cone_degrees and penalized.spin_rate < clean.spin_rate
	_print_result("timer defaults add penalty", passed)
	return passed

func _test_lower_contact_lifts_ball() -> bool:
	var upper_input := _base_input(0.75)
	upper_input.impact_point = Vector2(0.0, -0.65)
	upper_input.swipe_points = PackedVector2Array([Vector2.ZERO, Vector2(0.0, 0.25)])
	var lower_input := _base_input(0.75)
	lower_input.impact_point = Vector2(0.0, 0.65)
	lower_input.swipe_points = PackedVector2Array([Vector2.ZERO, Vector2(0.0, -0.25)])
	var upper := ShotCalculator.calculate(upper_input, _stats(), _environment(), _difficulty())
	var lower := ShotCalculator.calculate(lower_input, _stats(), _environment(), _difficulty())
	var passed := lower.elevation_angle > upper.elevation_angle
	_print_result("lower ball contact increases elevation", passed)
	return passed

func _test_center_contact_goes_straighter() -> bool:
	var center_input := _base_input(0.75)
	center_input.support_vector = Vector2.ZERO
	center_input.impact_point = Vector2.ZERO
	center_input.swipe_points = PackedVector2Array([Vector2.ZERO, Vector2(0.0, -0.12)])
	var side_input := _base_input(0.75)
	side_input.support_vector = Vector2.ZERO
	side_input.impact_point = Vector2(0.65, 0.0)
	side_input.swipe_points = PackedVector2Array([Vector2.ZERO, Vector2(0.55, -0.12)])
	var center := ShotCalculator.calculate(center_input, _stats(), _environment(), _difficulty())
	var side := ShotCalculator.calculate(side_input, _stats(), _environment(), _difficulty())
	var passed := absf(center.spin_axis.y) < absf(side.spin_axis.y) and center.spin_rate < side.spin_rate
	_print_result("center contact is straighter than side contact", passed)
	return passed

func _test_side_swipe_adds_strong_curve() -> bool:
	var straight_input := _base_input(0.75)
	straight_input.support_vector = Vector2.ZERO
	straight_input.impact_point = Vector2.ZERO
	straight_input.swipe_points = PackedVector2Array([Vector2.ZERO, Vector2(0.0, -0.2)])
	var curve_input := _base_input(0.75)
	curve_input.support_vector = Vector2.ZERO
	curve_input.impact_point = Vector2(0.55, 0.0)
	curve_input.swipe_points = PackedVector2Array([Vector2.ZERO, Vector2(0.75, -0.2)])
	var straight := ShotCalculator.calculate(straight_input, _stats(), _environment(), _difficulty())
	var curve := ShotCalculator.calculate(curve_input, _stats(), _environment(), _difficulty())
	var passed := absf(curve.spin_axis.y) > absf(straight.spin_axis.y) and curve.spin_rate > straight.spin_rate * 2.0
	_print_result("side swipe adds strong curve", passed)
	return passed

func _test_right_half_contact_with_left_support_curls_left() -> bool:
	var curve_input := _base_input(0.75)
	curve_input.selected_foot = "right"
	curve_input.support_vector = Vector2(-0.45, 0.0)
	curve_input.impact_point = Vector2(0.55, 0.0)
	curve_input.swipe_points = PackedVector2Array([Vector2(0.55, 0.0), Vector2(1.2, -0.1)])
	var curve := ShotCalculator.calculate(curve_input, _stats(), _environment(), _difficulty())
	var magnus := curve.spin_axis.normalized().cross(curve.launch_velocity.normalized())
	var passed := magnus.x < 0.0
	_print_result("right half contact with left support curls left", passed)
	return passed

func _test_right_half_contact_with_right_support_curls_left() -> bool:
	var curve_input := _base_input(0.75)
	curve_input.selected_foot = "left"
	curve_input.support_vector = Vector2(0.45, 0.0)
	curve_input.impact_point = Vector2(0.55, 0.0)
	curve_input.swipe_points = PackedVector2Array([Vector2(0.55, 0.0), Vector2(1.2, -0.1)])
	var curve := ShotCalculator.calculate(curve_input, _stats(), _environment(), _difficulty())
	var magnus := curve.spin_axis.normalized().cross(curve.launch_velocity.normalized())
	var passed := magnus.x < 0.0
	_print_result("right half contact with right support curls left", passed)
	return passed

func _test_support_aim_target_adjusts_aim() -> bool:
	var left_angle_input := _base_input(0.75)
	left_angle_input.support_vector = Vector2.ZERO
	left_angle_input.support_aim_target = -1.0
	var right_angle_input := _base_input(0.75)
	right_angle_input.support_vector = Vector2.ZERO
	right_angle_input.support_aim_target = 1.0
	var left_angle := ShotCalculator.calculate(left_angle_input, _stats(), _environment(), _difficulty())
	var right_angle := ShotCalculator.calculate(right_angle_input, _stats(), _environment(), _difficulty())
	var passed := right_angle.horizontal_angle < left_angle.horizontal_angle
	_print_result("support aim target adjusts aim", passed)
	return passed

func _test_support_aim_target_reaches_goal_side() -> bool:
	var left_input := _base_input(0.75)
	left_input.support_aim_target = -1.0
	var right_input := _base_input(0.75)
	right_input.support_aim_target = 1.0
	var left := ShotCalculator.calculate(left_input, _stats(), _environment(), _difficulty())
	var right := ShotCalculator.calculate(right_input, _stats(), _environment(), _difficulty())
	var left_x := _x_at_goal_plane(left.launch_velocity, 24.0)
	var right_x := _x_at_goal_plane(right.launch_velocity, 24.0)
	var passed := right_x > left_x and right_x > 0.0 and left_x < 0.0
	_print_result("support aim target reaches goal side", passed)
	return passed

func _test_spot_angle_is_not_double_counted() -> bool:
	var environment := _environment()
	environment.base_goal_direction = Vector3(-0.3, 0.0, -1.0).normalized()
	environment.angle_to_goal = rad_to_deg(atan2(environment.base_goal_direction.x, -environment.base_goal_direction.z))
	var center_input := _base_input(0.75)
	center_input.support_aim_target = 0.0
	var right_input := _base_input(0.75)
	right_input.support_aim_target = 1.0
	var center := ShotCalculator.calculate(center_input, _stats(), environment, _difficulty())
	var right := ShotCalculator.calculate(right_input, _stats(), environment, _difficulty())
	var passed := is_equal_approx(absf(right.horizontal_angle - center.horizontal_angle), 25.0)
	_print_result("spot angle is not double-counted", passed)
	return passed

func _test_extended_follow_through_increases_curve() -> bool:
	var short_input := _base_input(0.75)
	short_input.impact_point = Vector2(0.2, 0.0)
	short_input.swipe_points = PackedVector2Array([Vector2(0.2, 0.0), Vector2(0.45, -0.1)])
	var long_input := _base_input(0.75)
	long_input.impact_point = Vector2(0.2, 0.0)
	long_input.swipe_points = PackedVector2Array([Vector2(0.2, 0.0), Vector2(1.65, -0.1)])
	var short := ShotCalculator.calculate(short_input, _stats(), _environment(), _difficulty())
	var long := ShotCalculator.calculate(long_input, _stats(), _environment(), _difficulty())
	var passed := long.spin_rate > short.spin_rate and absf(long.spin_axis.y) >= absf(short.spin_axis.y)
	_print_result("extended follow-through increases curve", passed)
	return passed

func _test_support_location_does_not_directly_aim() -> bool:
	var left_plant := _base_input(0.75)
	left_plant.support_vector = Vector2(-1.0, 0.0)
	left_plant.support_foot_angle = 0.0
	left_plant.impact_point = Vector2.ZERO
	var right_plant := _base_input(0.75)
	right_plant.support_vector = Vector2(1.0, 0.0)
	right_plant.support_foot_angle = 0.0
	right_plant.impact_point = Vector2.ZERO
	var left := ShotCalculator.calculate(left_plant, _stats(), _environment(), _difficulty())
	var right := ShotCalculator.calculate(right_plant, _stats(), _environment(), _difficulty())
	var passed := absf(left.horizontal_angle - right.horizontal_angle) < 0.001
	_print_result("support location does not directly aim", passed)
	return passed

func _test_support_foot_side_is_physical() -> bool:
	var right_kick_marker := FreeKickInputMapper.clamp_to_support_foot_side(Vector2(120.0, 20.0), 160.0, "right")
	var left_kick_marker := FreeKickInputMapper.clamp_to_support_foot_side(Vector2(-120.0, 20.0), 160.0, "left")
	var passed := right_kick_marker.x < 0.0 and left_kick_marker.x > 0.0
	_print_result("support foot side is physical", passed)
	return passed

func _x_at_goal_plane(velocity: Vector3, goal_distance: float) -> float:
	var time_to_goal := -goal_distance / velocity.z
	return velocity.x * time_to_goal

func _print_result(label: String, passed: bool) -> void:
	if passed:
		print("PASS: ", label)
	else:
		push_error("FAIL: %s" % label)
