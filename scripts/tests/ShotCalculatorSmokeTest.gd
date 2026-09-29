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
	ok = _test_plant_distance_scales_aim_angle() and ok
	ok = _test_plant_distance_optimal_keeps_full_lane() and ok
	ok = _test_spot_angle_is_not_double_counted() and ok
	ok = _test_extended_follow_through_increases_curve() and ok
	ok = _test_support_location_does_not_directly_aim() and ok
	ok = _test_support_foot_side_is_physical() and ok
	ok = _test_power_shrinks_step_time_budget() and ok
	ok = _test_power_limits_swipe_trace() and ok
	ok = _test_over_power_reduces_curl() and ok
	ok = _test_power_time_budget_applies_to_steps() and ok
	ok = _test_player_catalog_loads_unique_ids() and ok
	ok = _test_power_profile_launches_faster_than_placement() and ok
	ok = _test_controller_applies_player_profile_stats() and ok
	ok = _test_power_curve_starts_zero_saturates_one() and ok
	ok = _test_control_player_has_wider_ideal_window() and ok
	ok = _test_power_player_reaches_ideal_sooner() and ok
	ok = _test_power_curve_is_deterministic() and ok
	ok = _test_gesture_tap_is_puntera() and ok
	ok = _test_gesture_classifies_lace_vs_long() and ok
	ok = _test_gesture_instep_rosca() and ok
	ok = _test_gesture_outstep_trivela() and ok
	ok = _test_gesture_topspin_ascending() and ok
	ok = _test_gesture_curvature_and_quality() and ok
	ok = _test_gesture_l_max_power_and_curve() and ok
	ok = _test_instep_boosts_curl_over_straight() and ok
	ok = _test_runup_angle_leaves_horizontal_aim_unchanged() and ok
	ok = _test_runup_angle_trades_power_for_curl() and ok
	ok = _test_runup_distance_boosts_launch_speed() and ok
	ok = _test_runup_distance_low_zone_speed() and ok
	ok = _test_runup_distance_control_zone_speed() and ok
	ok = _test_runup_distance_risk_zone_speed() and ok
	ok = _test_runup_angle_reaches_ideal_power_sooner_when_straight() and ok
	ok = _test_runup_angle_widens_power_window_when_straight() and ok
	ok = _test_set_piece_wind_is_repeatable() and ok
	ok = _test_set_piece_wind_respects_range_and_toggle() and ok
	ok = _test_knuckle_canonical_strike_is_reachable() and ok
	ok = _test_knuckle_params_are_repeatable() and ok
	ok = _test_knuckle_gain_zero_with_spin_or_slow_ball() and ok
	ok = _test_knuckle_zero_amp_has_no_wobble() and ok
	ok = _test_knuckle_flight_is_repeatable() and ok
	ok = _test_knuckle_drift_rms_in_band() and ok
	ok = _test_clean_strike_has_no_flaw_error() and ok
	ok = _test_overpower_flaw_sends_ball_high() and ok
	ok = _test_cramped_plant_keeps_ball_low() and ok
	ok = _test_overextended_plant_drags_across_kicking_foot() and ok
	ok = _test_open_foot_flaw_follows_aim() and ok
	ok = _test_flaw_error_is_smooth() and ok
	ok = _test_runup_speed_peaks_mid_angle() and ok
	quit(0 if ok else 1)

func _base_input(power: float = 0.7) -> FreeKickInputData:
	var input := FreeKickInputData.new()
	input.hold_time = 1.0
	input.power_normalized = power
	input.selected_foot = "right"
	# Baseline tests predate the run-up substep and don't engage it - opt-in ceilings
	# (see ShotCalculator run-up section) must stay off so unrelated tests are unaffected.
	input.used_default_runup = true
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
	var passed := right_angle.horizontal_angle > left_angle.horizontal_angle
	_print_result("support aim target adjusts aim", passed)
	return passed

func _test_plant_distance_scales_aim_angle() -> bool:
	# Same full-aim input, different plant distances: the optimal plant band
	# keeps the widest aim angle; a cramped or overextended plant narrows it.
	var full_aim := _base_input(0.75)
	full_aim.support_aim_target = 1.0
	full_aim.support_vector = Vector2(0.28, 0.0)   # optimal band -> full lane
	var optimal := ShotCalculator.calculate(full_aim, _stats(), _environment(), _difficulty())
	full_aim.support_vector = Vector2(0.185, 0.0)  # cramped (near the ball)
	var cramped := ShotCalculator.calculate(full_aim, _stats(), _environment(), _difficulty())
	full_aim.support_vector = Vector2(0.85, 0.0)   # overextended
	var overreached := ShotCalculator.calculate(full_aim, _stats(), _environment(), _difficulty())
	var passed := absf(optimal.horizontal_angle) > absf(cramped.horizontal_angle) \
		and absf(optimal.horizontal_angle) > absf(overreached.horizontal_angle) \
		and absf(cramped.horizontal_angle) > absf(overreached.horizontal_angle)
	_print_result("plant distance scales aim angle (optimal widest)", passed)
	return passed

func _test_plant_distance_optimal_keeps_full_lane() -> bool:
	# At the optimal plant distance the full aim lane is preserved (35 degrees).
	var input := _base_input(0.75)
	input.support_vector = Vector2(0.25, 0.0)
	input.support_aim_target = 1.0
	var center_input := _base_input(0.75)
	center_input.support_vector = Vector2(0.25, 0.0)
	center_input.support_aim_target = 0.0
	var full := ShotCalculator.calculate(input, _stats(), _environment(), _difficulty())
	var center := ShotCalculator.calculate(center_input, _stats(), _environment(), _difficulty())
	# Lane size only: full aim (1.0) is also an over-opened foot, whose flaw is tested separately.
	var passed := is_equal_approx(absf(_aim_without_flaw(full) - _aim_without_flaw(center)), 35.0)
	_print_result("optimal plant keeps full aim lane (35 deg)", passed)
	return passed

func _test_support_aim_target_reaches_goal_side() -> bool:
	var left_input := _base_input(0.75)
	left_input.support_aim_target = -1.0
	left_input.support_vector = Vector2(-0.28, 0.0)  # optimal plant band for full angle scale
	var right_input := _base_input(0.75)
	right_input.support_aim_target = 1.0
	right_input.support_vector = Vector2(-0.28, 0.0)  # optimal plant band for full angle scale
	var left := ShotCalculator.calculate(left_input, _stats(), _environment(), _difficulty())
	var right := ShotCalculator.calculate(right_input, _stats(), _environment(), _difficulty())
	print("DEBUG: left_angle=", left.horizontal_angle, " right_angle=", right.horizontal_angle)
	print("DEBUG: left_vel.x=", left.launch_velocity.x, " right_vel.x=", right.launch_velocity.x)
	var left_x := _x_at_goal_plane(left.launch_velocity, 24.0)
	var right_x := _x_at_goal_plane(right.launch_velocity, 24.0)
	print("DEBUG: left_x=", left_x, " right_x=", right_x)
	# aim_target=-1 curves left (negative x), aim_target=1 curves right (positive x)
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
	# The spot angle is already represented by environment.base_goal_direction.
	# horizontal_angle should only contain the support aim offset: full target lane = 35 degrees.
	var passed := is_equal_approx(absf(_aim_without_flaw(right) - _aim_without_flaw(center)), 35.0)
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

func _test_power_shrinks_step_time_budget() -> bool:
	var difficulty := _difficulty()
	var threshold := difficulty.time_penalty_threshold
	var full_step2 := difficulty.step_time_budget(0.0, 2)
	var at_threshold_step3 := difficulty.step_time_budget(threshold, 3)
	var mid_step2 := difficulty.step_time_budget(threshold + (1.0 - threshold) * 0.5, 2)
	var maxed_step2 := difficulty.step_time_budget(1.0, 2)
	var maxed_step3 := difficulty.step_time_budget(1.0, 3)
	var passed := is_equal_approx(full_step2, difficulty.step2_time_limit) \
		and is_equal_approx(at_threshold_step3, difficulty.step3_time_limit) \
		and mid_step2 > difficulty.min_step2_time \
		and mid_step2 < difficulty.step2_time_limit \
		and is_equal_approx(maxed_step2, difficulty.min_step2_time) \
		and is_equal_approx(maxed_step3, difficulty.min_step3_time)
	_print_result("power above ideal zone shrinks step time budget", passed)
	return passed

func _test_power_limits_swipe_trace() -> bool:
	var difficulty := _difficulty()
	var threshold := difficulty.time_penalty_threshold
	var full_trace := difficulty.swipe_scale(0.0)
	var at_threshold := difficulty.swipe_scale(threshold)
	var mid := difficulty.swipe_scale(threshold + (1.0 - threshold) * 0.5)
	var maxed := difficulty.swipe_scale(1.0)
	var passed := is_equal_approx(full_trace, difficulty.max_swipe_scale) \
		and is_equal_approx(at_threshold, difficulty.max_swipe_scale) \
		and mid < difficulty.max_swipe_scale \
		and mid > difficulty.min_swipe_scale \
		and is_equal_approx(maxed, difficulty.min_swipe_scale)
	_print_result("over-power shrinks the step 3 swipe trace", passed)
	return passed

func _test_over_power_reduces_curl() -> bool:
	var gentle := _base_input(0.85)
	var maxed := _base_input(0.98)
	# Strong side swipe intent at both powers; only the power level changes.
	gentle.impact_point = Vector2(0.55, 0.0)
	maxed.impact_point = Vector2(0.55, 0.0)
	gentle.swipe_points = PackedVector2Array([Vector2(0.55, 0.0), Vector2(1.4, -0.1)])
	maxed.swipe_points = PackedVector2Array([Vector2(0.55, 0.0), Vector2(1.4, -0.1)])
	var gentle_result := ShotCalculator.calculate(gentle, _stats(), _environment(), _difficulty())
	var maxed_result := ShotCalculator.calculate(maxed, _stats(), _environment(), _difficulty())
	var passed := maxed_result.spin_rate < gentle_result.spin_rate * 0.5
	_print_result("over-power reduces curl", passed)
	return passed

func _test_power_time_budget_applies_to_steps() -> bool:
	var controller := FreeKickController.new()
	controller.difficulty = _difficulty()
	var base_step2 := controller.difficulty.step2_time_limit
	var base_step3 := controller.difficulty.step3_time_limit
	# Without a power budget the states fall back to the difficulty base limits.
	var fallback := is_equal_approx(controller.effective_step_time_limit(2), base_step2) \
		and is_equal_approx(controller.effective_step_time_limit(3), base_step3)
	controller.set_power_time_budget(1.0)
	var passed := fallback \
		and is_equal_approx(controller.effective_step_time_limit(2), controller.difficulty.min_step2_time) \
		and is_equal_approx(controller.effective_step_time_limit(3), controller.difficulty.min_step3_time)
	_print_result("power budget scales step 2 and step 3 limits", passed)
	controller.free()
	return passed

func _test_player_catalog_loads_unique_ids() -> bool:
	var catalog := FreeKickPlayerCatalog.new()
	var loaded := catalog.load_from_json()
	var ids: Dictionary = {}
	var unique := true
	for profile in catalog.all_profiles():
		if ids.has(profile.id):
			unique = false
			break
		ids[profile.id] = true
	var passed := loaded and catalog.count() >= 10 and unique and catalog.get_by_id("starter") != null
	if not loaded:
		push_error("catalog error: %s" % catalog.last_error)
	_print_result("player catalog loads unique ids", passed)
	return passed

func _test_power_profile_launches_faster_than_placement() -> bool:
	var catalog := FreeKickPlayerCatalog.new()
	if not catalog.load_from_json():
		_print_result("power profile launches faster than placement", false)
		return false
	var power_profile := catalog.get_by_id("power_hammer")
	var placement_profile := catalog.get_by_id("placement_surgeon")
	if power_profile == null or placement_profile == null:
		_print_result("power profile launches faster than placement", false)
		return false
	var input := _base_input(0.85)
	var power_shot := ShotCalculator.calculate(input, power_profile.duplicate_stats(), _environment(), _difficulty())
	var placement_shot := ShotCalculator.calculate(input, placement_profile.duplicate_stats(), _environment(), _difficulty())
	var passed := power_shot.launch_velocity.length() > placement_shot.launch_velocity.length() \
		and placement_shot.error_cone_degrees < power_shot.error_cone_degrees
	_print_result("power profile launches faster than placement", passed)
	return passed

func _test_controller_applies_player_profile_stats() -> bool:
	var catalog := FreeKickPlayerCatalog.new()
	if not catalog.load_from_json():
		_print_result("controller applies player profile stats", false)
		return false
	var profile := catalog.get_by_id("curl_artist")
	var controller := FreeKickController.new()
	controller.set_player_profile(profile)
	var passed := controller.active_profile_id == "curl_artist" \
		and controller.stats != null \
		and is_equal_approx(controller.stats.curve, profile.stats.curve) \
		and controller.preferred_kicking_foot() == "left" \
		and controller.stats != profile.stats
	_print_result("controller applies player profile stats", passed)
	controller.free()
	return passed

func _test_power_curve_starts_zero_saturates_one() -> bool:
	var stats := _stats()
	var at_zero := ShotCalculator.power_from_hold(0.0, stats)
	var at_max := ShotCalculator.power_from_hold(6.0, stats)
	var passed := at_zero < 0.001 and at_max > 0.999
	_print_result("power curve starts zero saturates one", passed)
	return passed

func _test_control_player_has_wider_ideal_window() -> bool:
	# Same power stat, different control: the control player's ideal window
	# (hold time between 0.75 and 0.85) must be wider.
	var control_stats := _stats()
	control_stats.free_kick_accuracy = 95.0
	control_stats.technique = 95.0
	control_stats.composure = 95.0
	var sloppy_stats := _stats()
	sloppy_stats.free_kick_accuracy = 40.0
	sloppy_stats.technique = 40.0
	sloppy_stats.composure = 40.0
	var control_window := _ideal_window(control_stats)
	var sloppy_window := _ideal_window(sloppy_stats)
	var passed := control_window > sloppy_window * 1.4
	_print_result("control player has wider ideal window", passed)
	return passed

func _test_power_player_reaches_ideal_sooner() -> bool:
	# Same control, different power: the power player reaches the ideal point
	# (0.85) in less hold time.
	var power_stats := _stats()
	power_stats.kick_power = 96.0
	var weak_stats := _stats()
	weak_stats.kick_power = 40.0
	var power_time := _hold_time_for_power(power_stats, 0.85)
	var weak_time := _hold_time_for_power(weak_stats, 0.85)
	var passed := power_time < weak_time * 0.9
	_print_result("power player reaches ideal sooner", passed)
	return passed

func _test_power_curve_is_deterministic() -> bool:
	var stats := _stats()
	var a := ShotCalculator.power_from_hold(1.2, stats)
	var b := ShotCalculator.power_from_hold(1.2, stats)
	_print_result("power curve is deterministic", is_equal_approx(a, b))
	return is_equal_approx(a, b)

## Hold time needed to reach the given power level (binary search).
func _hold_time_for_power(stats: PlayerFreeKickStats, target: float) -> float:
	var low := 0.0
	var high := 8.0
	for _i in range(60):
		var mid := (low + high) * 0.5
		if ShotCalculator.power_from_hold(mid, stats) < target:
			low = mid
		else:
			high = mid
	return (low + high) * 0.5

## Hold time span between power 0.75 and 0.85 (the ideal window).
func _ideal_window(stats: PlayerFreeKickStats) -> float:
	return _hold_time_for_power(stats, 0.85) - _hold_time_for_power(stats, 0.75)

func _x_at_goal_plane(velocity: Vector3, goal_distance: float) -> float:
	var time_to_goal := -goal_distance / velocity.z
	return velocity.x * time_to_goal

func _test_gesture_tap_is_puntera() -> bool:
	var metrics := ContactGesture.analyze(PackedVector2Array([Vector2(0.2, -0.1)]), 0.1)
	var tech := ContactGesture.classify(metrics, 0.75, 0.75, 1.8, "right")
	var passed := tech == ContactGesture.Technique.PUNTERA
	_print_result("tap without drag classifies as puntera", passed)
	return passed

func _test_gesture_classifies_lace_vs_long() -> bool:
	var short_metrics := ContactGesture.analyze(PackedVector2Array([Vector2.ZERO, Vector2(0.3, -0.1)]), 0.2)
	var long_metrics := ContactGesture.analyze(PackedVector2Array([Vector2.ZERO, Vector2(1.4, -0.1)]), 0.4)
	var short := ContactGesture.classify(short_metrics, 0.75, 0.5, 1.8, "right")
	var long := ContactGesture.classify(long_metrics, 0.75, 0.5, 1.8, "right")
	var passed := short == ContactGesture.Technique.LACE and long == ContactGesture.Technique.LACE_LONG
	_print_result("short/long straight traces classify as lace", passed)
	return passed

func _test_gesture_instep_rosca() -> bool:
	# Right foot: inward = screen-right envelope -> rosca.
	var trace := PackedVector2Array([Vector2.ZERO, Vector2(0.35, 0.0), Vector2(0.9, 0.18), Vector2(1.3, 0.55), Vector2(1.45, 1.0)])
	var tech := ContactGesture.classify(ContactGesture.analyze(trace, 0.4), 0.75, 0.75, 1.8, "right")
	var passed := tech == ContactGesture.Technique.INSTEP
	_print_result("inward curve classifies as instep/rosca", passed)
	return passed

func _test_gesture_outstep_trivela() -> bool:
	var trace := PackedVector2Array([Vector2.ZERO, Vector2(-0.35, 0.0), Vector2(-0.9, 0.18), Vector2(-1.3, 0.55), Vector2(-1.45, 1.0)])
	var tech := ContactGesture.classify(ContactGesture.analyze(trace, 0.4), 0.75, 0.75, 1.8, "right")
	var passed := tech == ContactGesture.Technique.OUTSTEP
	_print_result("outward curve classifies as outstep/trivela", passed)
	return passed

func _test_gesture_topspin_ascending() -> bool:
	var trace := PackedVector2Array([Vector2(0.0, 0.5), Vector2(0.1, 0.1), Vector2(0.1, -0.3), Vector2(0.12, -0.8)])
	var tech := ContactGesture.classify(ContactGesture.analyze(trace, 0.3), 0.75, 0.5, 1.8, "right")
	var passed := tech == ContactGesture.Technique.TOPSPIN
	_print_result("ascending straight sweep classifies as topspin", passed)
	return passed

func _test_gesture_curvature_and_quality() -> bool:
	var clean := ContactGesture.analyze(PackedVector2Array([Vector2.ZERO, Vector2(0.5, 0.0), Vector2(1.0, 0.0)]), 0.2)
	var jitter := ContactGesture.analyze(PackedVector2Array([Vector2.ZERO, Vector2(0.25, -0.18), Vector2(0.5, 0.16), Vector2(0.75, -0.17), Vector2(1.0, 0.0)]), 0.2)
	var clean_curvature: float = clean.get("curvature", 1.0)
	var clean_cleanliness: float = clean.get("cleanliness", 1.0)
	var jitter_cleanliness: float = jitter.get("cleanliness", 1.0)
	var passed := clean_curvature < 0.12 and jitter_cleanliness < clean_cleanliness
	_print_result("curvature low for straight, jitter lowers cleanliness", passed)
	return passed

func _test_gesture_l_max_power_and_curve() -> bool:
	var difficulty := _difficulty()
	var full_curve := ContactGesture.l_max(0.85, 1.0, difficulty)
	var low_curve := ContactGesture.l_max(0.85, 0.0, difficulty)
	var over_power := ContactGesture.l_max(0.98, 0.5, difficulty)
	var passed := full_curve > low_curve and full_curve <= 1.8 * 1.15 + 0.001 and over_power < low_curve
	_print_result("l_max grows with curve stat and shrinks with power", passed)
	return passed

func _test_instep_boosts_curl_over_straight() -> bool:
	var instep_input := _base_input(0.75)
	instep_input.impact_point = Vector2(0.35, 0.0)
	instep_input.swipe_points = PackedVector2Array([Vector2(0.35, 0.0), Vector2(0.9, 0.18), Vector2(1.3, 0.55), Vector2(1.45, 1.0)])
	instep_input.swipe_duration = 0.4
	var straight_input := _base_input(0.75)
	straight_input.impact_point = Vector2(0.35, 0.0)
	straight_input.swipe_points = PackedVector2Array([Vector2(0.35, 0.0), Vector2(1.45, 0.1)])
	straight_input.swipe_duration = 0.4
	var instep := ShotCalculator.calculate(instep_input, _stats(), _environment(), _difficulty())
	var straight := ShotCalculator.calculate(straight_input, _stats(), _environment(), _difficulty())
	var passed := instep.gesture_technique == ContactGesture.Technique.INSTEP \
		and straight.gesture_technique == ContactGesture.Technique.LACE \
		and instep.spin_rate > straight.spin_rate
	_print_result("instep rosca boosts curl over same-length straight swipe", passed)
	return passed

func _test_runup_angle_leaves_horizontal_aim_unchanged() -> bool:
	var low_angle_input := _base_input()
	low_angle_input.used_default_runup = false
	low_angle_input.runup_angle_deg = 0.0
	var high_angle_input := _base_input()
	high_angle_input.used_default_runup = false
	high_angle_input.runup_angle_deg = ShotCalculator.RUNUP_ANGLE_MAX_DEG
	var low := ShotCalculator.calculate(low_angle_input, _stats(), _environment(), _difficulty())
	var high := ShotCalculator.calculate(high_angle_input, _stats(), _environment(), _difficulty())
	var passed := is_equal_approx(low.horizontal_angle, high.horizontal_angle)
	_print_result("run-up angle is pure technique - it never steers the shot", passed)
	return passed

func _test_runup_angle_trades_power_for_curl() -> bool:
	# Angle convention: 0 = lateral/parallel to the goal line (best curl ceiling, worst
	# straight-power ceiling), RUNUP_ANGLE_MAX_DEG (90) = perpendicular/straight-on (best
	# straight-power/puntera ceiling, worst curl ceiling). Grounded in kicking biomechanics
	# research (Isokawa & Lees): wider approach angles trade power for hip-rotation room.
	var curl_swipe := PackedVector2Array([Vector2.ZERO, Vector2(0.75, -0.2)])
	var straight_runup := _base_input(0.95)
	straight_runup.support_vector = Vector2.ZERO
	straight_runup.impact_point = Vector2(0.55, 0.0)
	straight_runup.swipe_points = curl_swipe
	straight_runup.used_default_runup = false
	straight_runup.runup_angle_deg = ShotCalculator.RUNUP_ANGLE_MAX_DEG
	var lateral_runup := _base_input(0.95)
	lateral_runup.support_vector = Vector2.ZERO
	lateral_runup.impact_point = Vector2(0.55, 0.0)
	lateral_runup.swipe_points = curl_swipe
	lateral_runup.used_default_runup = false
	lateral_runup.runup_angle_deg = 0.0
	var straight := ShotCalculator.calculate(straight_runup, _stats(), _environment(), _difficulty())
	var lateral := ShotCalculator.calculate(lateral_runup, _stats(), _environment(), _difficulty())
	var passed := (straight.spin_rate <= ShotCalculator.MAX_SPIN_RATE * ShotCalculator.RUNUP_SPIN_CEILING_AT_STRAIGHT_ANGLE + 0.01) \
		and lateral.spin_rate > straight.spin_rate \
		and straight.launch_velocity.length() >= lateral.launch_velocity.length()
	_print_result("straight-on run-up caps curl for speed, lateral run-up caps speed for curl", passed)
	return passed

func _test_runup_distance_boosts_launch_speed() -> bool:
	var base_input := _base_input(0.5)
	var boosted_input := _base_input(0.5)
	boosted_input.runup_distance_m = ShotCalculator.RUNUP_DISTANCE_MAX_M
	var base := ShotCalculator.calculate(base_input, _stats(), _environment(), _difficulty())
	var boosted := ShotCalculator.calculate(boosted_input, _stats(), _environment(), _difficulty())
	var passed := boosted.launch_velocity.length() > base.launch_velocity.length()
	_print_result("run-up distance boosts launch speed", passed)
	return passed

## Hold time needed to reach the given power level, with full run-up context (binary search).
func _hold_time_for_power_runup(stats: PlayerFreeKickStats, difficulty: FreeKickDifficulty, runup_distance_m: float, target: float, runup_angle_deg: float = 0.0, runup_engaged: bool = true) -> float:
	var low := 0.0
	var high := 8.0
	for _i in range(60):
		var mid := (low + high) * 0.5
		if ShotCalculator.power_from_hold(mid, stats, runup_distance_m, difficulty, runup_angle_deg, runup_engaged) < target:
			low = mid
		else:
			high = mid
	return (low + high) * 0.5

func _test_runup_distance_low_zone_speed() -> bool:
	# Short run-up is slow leaving the low zone (0-40%); far run-up is fast there.
	var stats := _stats()
	var difficulty := _difficulty()
	var short_time := _hold_time_for_power_runup(stats, difficulty, 0.0, 0.40)
	var far_time := _hold_time_for_power_runup(stats, difficulty, ShotCalculator.RUNUP_DISTANCE_MAX_M, 0.40)
	var passed := short_time > far_time
	_print_result("short run-up spends longer leaving the low zone than a far run-up", passed)
	return passed

func _test_runup_distance_control_zone_speed() -> bool:
	# Medium run-up is slow through the control zone (40-70%); short and far are both fast there.
	var stats := _stats()
	var difficulty := _difficulty()
	var short_dur := _hold_time_for_power_runup(stats, difficulty, 0.0, 0.70) - _hold_time_for_power_runup(stats, difficulty, 0.0, 0.40)
	var medium_dur := _hold_time_for_power_runup(stats, difficulty, ShotCalculator.RUNUP_DISTANCE_MAX_M * 0.5, 0.70) - _hold_time_for_power_runup(stats, difficulty, ShotCalculator.RUNUP_DISTANCE_MAX_M * 0.5, 0.40)
	var far_dur := _hold_time_for_power_runup(stats, difficulty, ShotCalculator.RUNUP_DISTANCE_MAX_M, 0.70) - _hold_time_for_power_runup(stats, difficulty, ShotCalculator.RUNUP_DISTANCE_MAX_M, 0.40)
	var passed := medium_dur > short_dur and medium_dur > far_dur
	_print_result("medium run-up spends longer in the control zone than short or far", passed)
	return passed

func _test_runup_distance_risk_zone_speed() -> bool:
	# Far run-up is slow through the risk zone (85-100%); short is fast there.
	var stats := _stats()
	var difficulty := _difficulty()
	var short_dur := _hold_time_for_power_runup(stats, difficulty, 0.0, 1.0) - _hold_time_for_power_runup(stats, difficulty, 0.0, 0.85)
	var far_dur := _hold_time_for_power_runup(stats, difficulty, ShotCalculator.RUNUP_DISTANCE_MAX_M, 1.0) - _hold_time_for_power_runup(stats, difficulty, ShotCalculator.RUNUP_DISTANCE_MAX_M, 0.85)
	var passed := far_dur > short_dur
	_print_result("far run-up spends longer in the risk zone than a short run-up", passed)
	return passed

func _test_runup_angle_reaches_ideal_power_sooner_when_straight() -> bool:
	var stats := _stats()
	var difficulty := _difficulty()
	var straight_power := ShotCalculator.power_from_hold(1.0, stats, 0.0, difficulty, ShotCalculator.RUNUP_ANGLE_MAX_DEG, true)
	var lateral_power := ShotCalculator.power_from_hold(1.0, stats, 0.0, difficulty, 0.0, true)
	var unengaged_power := ShotCalculator.power_from_hold(1.0, stats, 0.0, difficulty, 0.0, false)
	var baseline_power := ShotCalculator.power_from_hold(1.0, stats, 0.0, difficulty)
	var passed := straight_power > lateral_power and is_equal_approx(unengaged_power, baseline_power)
	_print_result("straight-on run-up reaches the ideal power point sooner than a lateral run-up", passed)
	return passed

func _test_runup_angle_widens_power_window_when_straight() -> bool:
	# Straight-on run-up should spend longer in the ideal zone (70-85%, more forgiving) than
	# a lateral run-up - same measurement style as the control-stat window comparison.
	var stats := _stats()
	var difficulty := _difficulty()
	var straight_window := _hold_time_for_power_runup(stats, difficulty, 0.0, 0.85, ShotCalculator.RUNUP_ANGLE_MAX_DEG, true) \
		- _hold_time_for_power_runup(stats, difficulty, 0.0, 0.70, ShotCalculator.RUNUP_ANGLE_MAX_DEG, true)
	var lateral_window := _hold_time_for_power_runup(stats, difficulty, 0.0, 0.85, 0.0, true) \
		- _hold_time_for_power_runup(stats, difficulty, 0.0, 0.70, 0.0, true)
	var passed := straight_window > lateral_window
	_print_result("straight-on run-up widens the power window (more forgiving) than a lateral run-up", passed)
	return passed

const SANDBOX_SCRIPT_PATH := "res://scripts/state_machine/FreeKickSandbox.gd"

func _test_set_piece_wind_is_repeatable() -> bool:
	# All three attempts of a set piece (and replays across sessions) must see the same wind.
	var sandbox: GDScript = load(SANDBOX_SCRIPT_PATH)
	var passed := true
	var any_differs := false
	var first: Vector3 = sandbox.wind_for_set_piece(1, 0.0, 3.0, true)
	for set_piece in range(1, 41):
		var a: Vector3 = sandbox.wind_for_set_piece(set_piece, 0.0, 3.0, true)
		var b: Vector3 = sandbox.wind_for_set_piece(set_piece, 0.0, 3.0, true)
		var c: Vector3 = sandbox.wind_for_set_piece(set_piece, 0.0, 3.0, true)
		passed = passed and a.is_equal_approx(b) and b.is_equal_approx(c)
		if not a.is_equal_approx(first):
			any_differs = true
	passed = passed and any_differs
	_print_result("same set piece always gets the same wind (and set pieces differ)", passed)
	return passed

func _test_set_piece_wind_respects_range_and_toggle() -> bool:
	var sandbox: GDScript = load(SANDBOX_SCRIPT_PATH)
	var passed := true
	for set_piece in range(1, 61):
		var wind: Vector3 = sandbox.wind_for_set_piece(set_piece, 1.0, 3.0, true)
		var speed := wind.length()
		passed = passed and speed >= 1.0 - 0.001 and speed <= 3.0 + 0.001 and is_zero_approx(wind.y)
		passed = passed and sandbox.wind_for_set_piece(set_piece, 1.0, 3.0, false) == Vector3.ZERO
	_print_result("set piece wind stays within its range and is zero when disabled", passed)
	return passed

## Canonical knuckle input: near-center contact, short straight trace through the ball,
## power inside the ideal zone, no timer defaults.
func _knuckle_input() -> FreeKickInputData:
	var input := _base_input(0.8)
	input.impact_point = Vector2(0.05, 0.05)
	input.swipe_points = PackedVector2Array([Vector2(0.05, 0.05), Vector2(0.05, -0.25)])
	input.swipe_duration = 0.2
	return input

func _test_knuckle_canonical_strike_is_reachable() -> bool:
	var params := ShotCalculator.calculate(_knuckle_input(), _stats(), _environment(), _difficulty())
	var passed := params.knuckle_gain > 0.5 and params.spin_rate < 8.0 and params.shot_type == &"knuckle_power"
	# A normal curled strike must not trigger it.
	var curled := ShotCalculator.calculate(_base_input(0.8), _stats(), _environment(), _difficulty())
	passed = passed and is_zero_approx(curled.knuckle_gain)
	_print_result("clean center strike in the ideal zone reaches knuckle (gain %.2f, spin %.1f)" % [params.knuckle_gain, params.spin_rate], passed)
	return passed

func _test_knuckle_params_are_repeatable() -> bool:
	var environment := _environment()
	environment.set_piece_seed = 7
	var a := ShotCalculator.calculate(_knuckle_input(), _stats(), environment, _difficulty())
	var b := ShotCalculator.calculate(_knuckle_input(), _stats(), environment, _difficulty())
	var other_set_piece := _environment()
	other_set_piece.set_piece_seed = 8
	var c := ShotCalculator.calculate(_knuckle_input(), _stats(), other_set_piece, _difficulty())
	var passed := is_equal_approx(a.knuckle_gain, b.knuckle_gain) \
		and a.knuckle_seed == b.knuckle_seed \
		and is_equal_approx(a.knuckle_amp, b.knuckle_amp) \
		and a.knuckle_seed != c.knuckle_seed
	_print_result("same input + set piece -> same knuckle gain/seed/amp", passed)
	return passed

func _test_knuckle_gain_zero_with_spin_or_slow_ball() -> bool:
	var passed := is_zero_approx(ShotCalculator.knuckle_physical_gain(30.0, 14.0)) \
		and is_zero_approx(ShotCalculator.knuckle_physical_gain(30.0, 40.0)) \
		and is_zero_approx(ShotCalculator.knuckle_physical_gain(16.0, 0.0)) \
		and is_zero_approx(ShotCalculator.knuckle_physical_gain(12.0, 2.0)) \
		and is_equal_approx(ShotCalculator.knuckle_physical_gain(30.0, 2.0), 1.0)
	_print_result("knuckle gain is 0 with spin >= 14 rad/s or speed <= 16 m/s", passed)
	return passed

func _test_knuckle_zero_amp_has_no_wobble() -> bool:
	var passed := true
	for i in range(60):
		var t := float(i) / 30.0
		passed = passed and BallAerodynamics3D.knuckle_accel(t, 30.0, 1234, 1.0, 0.0) == Vector2.ZERO
		passed = passed and BallAerodynamics3D.knuckle_accel(t, 30.0, 1234, 0.0, 16.0) == Vector2.ZERO
	# No wobble before the activation delay either.
	passed = passed and BallAerodynamics3D.knuckle_accel(0.1, 30.0, 1234, 1.0, 16.0) == Vector2.ZERO
	_print_result("knuckle wobble is zero with amp 0, gain 0, or before activation", passed)
	return passed

## Knuckle-only lateral/vertical drift over a straight 30 m/s flight (fixed 60 Hz step).
func _knuckle_drift(seed: int, amp: float, flight_time: float = 1.2) -> Vector2:
	var vel := Vector2.ZERO
	var pos := Vector2.ZERO
	var dt := 1.0 / 60.0
	var t := 0.0
	while t < flight_time:
		t += dt
		vel += BallAerodynamics3D.knuckle_accel(t, 30.0, seed, 1.0, amp) * dt
		pos += vel * dt
	return pos

func _test_knuckle_flight_is_repeatable() -> bool:
	var reference := _knuckle_drift(424242, 16.0)
	var passed := reference.length() > 0.0
	for _i in range(100):
		passed = passed and _knuckle_drift(424242, 16.0) == reference
	_print_result("100 repetitions of the same knuckle give the same drift", passed)
	return passed

func _test_knuckle_drift_rms_in_band() -> bool:
	# Report calibration (30 m/s, ~34 m, amp 16): RMS lateral drift ~0.43 m, visible but not wild.
	var sum_sq := 0.0
	var max_dx := 0.0
	for s in range(200):
		var drift := _knuckle_drift(hash(s * 7919 + 17), 16.0)
		sum_sq += drift.x * drift.x
		max_dx = maxf(max_dx, absf(drift.x))
	var rms := sqrt(sum_sq / 200.0)
	var passed := rms >= 0.3 and rms <= 0.55 and max_dx <= 1.6
	_print_result("knuckle drift RMS %.2f m (max %.2f m) within the calibrated band" % [rms, max_dx], passed)
	return passed

func _aim_without_flaw(params: ShotParams) -> float:
	return params.horizontal_angle - params.final_error.x

## Clean reference strike: optimal plant, balanced depth, controlled aim, ideal power,
## centered straight trace (gesture quality only affects the slice via off-center contact).
func _clean_input(power: float = 0.75) -> FreeKickInputData:
	var input := _base_input(power)
	input.support_vector = Vector2(-0.28, -0.10)
	input.plant_depth = -0.10
	input.support_aim_target = 0.3
	input.impact_point = Vector2.ZERO
	input.swipe_points = PackedVector2Array([Vector2.ZERO, Vector2(0.0, -0.3)])
	return input

func _test_clean_strike_has_no_flaw_error() -> bool:
	var shot := ShotCalculator.calculate(_clean_input(), _stats(), _environment(), _difficulty())
	var passed := shot.final_error.length() < 0.0001 and shot.dominant_flaw == &""
	_print_result("clean strike has no flaw error (%.4f deg)" % shot.final_error.length(), passed)
	return passed

func _test_overpower_flaw_sends_ball_high() -> bool:
	var clean := ShotCalculator.calculate(_clean_input(0.80), _stats(), _environment(), _difficulty())
	var over := ShotCalculator.calculate(_clean_input(1.0), _stats(), _environment(), _difficulty())
	var passed := over.final_error.y > 1.0 and absf(over.final_error.x) < 0.0001 and clean.final_error.length() < 0.0001
	_print_result("overpower lifts the shot (%.2f deg up)" % over.final_error.y, passed)
	return passed

func _test_cramped_plant_keeps_ball_low() -> bool:
	var input := _clean_input()
	input.support_vector = Vector2(-0.18, -0.10)
	var shot := ShotCalculator.calculate(input, _stats(), _environment(), _difficulty())
	var passed := shot.final_error.y < -0.5 and absf(shot.final_error.x) < 0.0001
	_print_result("cramped plant keeps the shot low (%.2f deg)" % shot.final_error.y, passed)
	return passed

func _test_overextended_plant_drags_across_kicking_foot() -> bool:
	# Right foot drags left, left foot drags right; mirrored plant positions with the same
	# foot give the same error (support side must never aim).
	var right_foot := _clean_input()
	right_foot.support_vector = Vector2(-0.9, -0.10)
	var right_foot_mirror := _clean_input()
	right_foot_mirror.support_vector = Vector2(0.9, -0.10)
	var left_foot := _clean_input()
	left_foot.selected_foot = "left"
	left_foot.support_vector = Vector2(0.9, -0.10)
	var left_stats := _stats()
	left_stats.preferred_foot = "left"
	var r := ShotCalculator.calculate(right_foot, _stats(), _environment(), _difficulty())
	var rm := ShotCalculator.calculate(right_foot_mirror, _stats(), _environment(), _difficulty())
	var l := ShotCalculator.calculate(left_foot, left_stats, _environment(), _difficulty())
	var passed := r.final_error.x < -0.5 and l.final_error.x > 0.5 and r.final_error.is_equal_approx(rm.final_error) 		and r.dominant_flaw == &"overextended_plant"
	_print_result("overextended plant drags across the kicking foot (R %.2f, L %.2f deg)" % [r.final_error.x, l.final_error.x], passed)
	return passed

func _test_open_foot_flaw_follows_aim() -> bool:
	var right := _clean_input()
	right.support_aim_target = 1.0
	var left := _clean_input()
	left.support_aim_target = -1.0
	var r := ShotCalculator.calculate(right, _stats(), _environment(), _difficulty())
	var l := ShotCalculator.calculate(left, _stats(), _environment(), _difficulty())
	var passed := r.final_error.x > 0.3 and l.final_error.x < -0.3
	_print_result("over-opened foot runs further across (%.2f / %.2f deg)" % [r.final_error.x, l.final_error.x], passed)
	return passed

func _test_flaw_error_is_smooth() -> bool:
	# The old error hashed raw inputs; now a tiny input change must give a tiny error change.
	var worst := 0.0
	var base := _base_input(0.95)
	base.support_vector = Vector2(-0.6, 0.3)
	base.plant_depth = 0.3
	base.support_aim_target = 0.8
	var reference := ShotCalculator.calculate(base, _stats(), _environment(), _difficulty())
	for step in [Vector2(0.01, 0.0), Vector2(0.0, 0.01)]:
		var nudged := _base_input(0.95)
		nudged.support_vector = base.support_vector + step
		nudged.plant_depth = base.plant_depth + step.y
		nudged.support_aim_target = base.support_aim_target + step.x
		nudged.hold_time = base.hold_time + 0.01
		var shot := ShotCalculator.calculate(nudged, _stats(), _environment(), _difficulty())
		worst = maxf(worst, shot.final_error.distance_to(reference.final_error))
	var passed := worst < 0.15
	_print_result("flaw error is smooth (max change %.3f deg for a 0.01 nudge)" % worst, passed)
	return passed

func _test_runup_speed_peaks_mid_angle() -> bool:
	# Isokawa & Lees / Scurr & Hall: ball speed peaks at the 45-60deg (game convention) plateau
	# and only eases off toward the ends - never the old 40% lateral cap.
	var lateral := ShotCalculator.runup_speed_ceiling(0.0)
	var peak := ShotCalculator.runup_speed_ceiling(52.0)
	var straight := ShotCalculator.runup_speed_ceiling(90.0)
	var smooth := absf(ShotCalculator.runup_speed_ceiling(44.9) - ShotCalculator.runup_speed_ceiling(45.1)) < 0.01
	var passed := is_equal_approx(peak, 1.0) and lateral < straight and straight < peak and lateral >= 0.8 and smooth
	_print_result("run-up speed peaks at mid angle (%.2f / %.2f / %.2f)" % [lateral, peak, straight], passed)
	return passed

func _print_result(label: String, passed: bool) -> void:
	if passed:
		print("PASS: ", label)
	else:
		push_error("FAIL: %s" % label)
