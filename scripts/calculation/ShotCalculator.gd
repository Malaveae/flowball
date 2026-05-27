class_name ShotCalculator
extends RefCounted

const MIN_LAUNCH_SPEED := 12.0
const MAX_LAUNCH_SPEED := 36.0
const MIN_ELEVATION_DEG := -3.0
const MAX_ELEVATION_DEG := 35.0
const MAX_SPIN_RATE := 140.0
const MAX_HORIZONTAL_OFFSET_DEG := 25.0
const IDEAL_POWER_MAX := 0.85

static func calculate(
	input: FreeKickInputData,
	stats: PlayerFreeKickStats,
	environment: FreeKickEnvironment,
	difficulty: FreeKickDifficulty
) -> ShotParams:
	var params := ShotParams.new()
	params.power = clamp(input.power_normalized, 0.0, 1.0)
	params.support_vector = input.support_vector
	params.plant_depth = clamp(input.plant_depth, -1.0, 1.0)
	params.support_foot_angle = input.support_foot_angle
	params.support_aim_target = input.support_aim_target
	params.contact_point = input.impact_point

	var accuracy := stats.normalized(stats.free_kick_accuracy)
	var power_stat := stats.normalized(stats.kick_power)
	var curve_stat := stats.normalized(stats.curve)
	var technique := stats.normalized(stats.technique)
	var composure := stats.normalized(stats.composure)

	var weak_foot_penalty := 0.0
	if input.selected_foot != stats.preferred_foot:
		weak_foot_penalty = 1.0 - stats.normalized(stats.weak_foot)

	var timeout_penalty_value := _timeout_penalty(input, difficulty, composure)
	var overpower := maxf(0.0, params.power - IDEAL_POWER_MAX) / (1.0 - IDEAL_POWER_MAX)

	params.stability = _plant_stability(params.plant_depth)
	# Step 2 is now pure aiming/body setup. Curl comes from Step 3 contact + swipe.
	params.curve_bias = 0.0
	var foot_angle_offset := _support_aim_target_offset(input.support_aim_target)
	# Support foot side is physical placement. It should not aim the shot directly anymore.
	# Aim is fine-tuned by foot angle; curl/contact comes later in Step 3.
	params.horizontal_angle = clampf(
		foot_angle_offset,
		-MAX_HORIZONTAL_OFFSET_DEG,
		MAX_HORIZONTAL_OFFSET_DEG
	)

	params.elevation_angle = _elevation_from_contact(input.impact_point, input.swipe_points)
	var swipe_vector := _swipe_vector(input.swipe_points)
	params.spin_axis = _spin_axis_from_contact_and_swipe(input.impact_point, swipe_vector, input.selected_foot)
	params.spin_rate = _spin_rate(input, swipe_vector.length(), curve_stat, technique)

	params.error_cone_degrees = _error_cone(accuracy, technique, params.stability, overpower, weak_foot_penalty, timeout_penalty_value)
	params.final_error = _deterministic_error(input, params.error_cone_degrees)
	params.horizontal_angle += params.final_error.x
	params.elevation_angle = clampf(params.elevation_angle + params.final_error.y, MIN_ELEVATION_DEG, MAX_ELEVATION_DEG)

	var speed := _launch_speed(params.power, power_stat, environment.distance_to_goal)
	params.launch_velocity = _launch_velocity(environment.base_goal_direction, params.horizontal_angle, params.elevation_angle, speed)
	params.shot_type = _classify_shot(params, swipe_vector)
	return params

static func power_from_hold(hold_time: float, charge_tau: float = 0.75) -> float:
	return clampf(1.0 - exp(-maxf(0.0, hold_time) / charge_tau), 0.0, 1.0)

static func _launch_speed(power: float, power_stat: float, distance: float) -> float:
	var distance_bonus := clampf((distance - 18.0) / 22.0, 0.0, 0.25)
	var speed := lerpf(14.0, MAX_LAUNCH_SPEED, power) * lerpf(0.85, 1.08, power_stat) + distance_bonus * 4.0
	return clampf(speed, MIN_LAUNCH_SPEED, MAX_LAUNCH_SPEED)

static func _launch_velocity(base_direction: Vector3, horizontal_deg: float, elevation_deg: float, speed: float) -> Vector3:
	var flat_dir := base_direction.slide(Vector3.UP).normalized()
	if flat_dir == Vector3.ZERO:
		flat_dir = Vector3.FORWARD
	flat_dir = flat_dir.rotated(Vector3.UP, deg_to_rad(horizontal_deg)).normalized()
	var horizontal_speed := speed * cos(deg_to_rad(elevation_deg))
	var vertical_speed := speed * sin(deg_to_rad(elevation_deg))
	return flat_dir * horizontal_speed + Vector3.UP * vertical_speed

static func _plant_stability(plant_depth: float) -> float:
	# Middle plant is most stable; extremes prepare special shots but reduce precision.
	return clampf(1.0 - absf(plant_depth) * 0.35, 0.55, 1.0)

static func _support_aim_target_offset(target: float) -> float:
	# Step 2 substep B: the foot points at a target lane, independent of support-foot side.
	# Input convention: -1 = left post, 0 = center, +1 = right post.
	# Godot uses -Z as the forward goal direction in this scene. Rotating Vector3(0,0,-1)
	# around +Y by a positive angle moves it toward world-left (negative X), so gameplay
	# right must be converted to a negative Y-rotation angle.
	return -clampf(target, -1.0, 1.0) * 45.0

static func _curve_bias_from_support(support_x: float, selected_foot: String) -> float:
	var foot_sign := -1.0 if selected_foot == "right" else 1.0
	return clampf(support_x * foot_sign, -1.0, 1.0)

static func _elevation_from_contact(contact: Vector2, swipe_points: PackedVector2Array) -> float:
	# Ball UI coordinates are normalized: center (0,0), top y=-1, bottom y=+1.
	# Football contact principle: striking below the center lifts the ball; striking above the center drives it down.
	var lower_contact_lift := clampf(contact.y, -1.0, 1.0)
	var swipe := _swipe_vector(swipe_points)
	# Upward swipe on screen is negative Y and adds lift/follow-through.
	var upward_follow_through := clampf(-swipe.y, -1.0, 1.0)
	var elevation := 10.0 + lower_contact_lift * 16.0 + upward_follow_through * 9.0
	return clampf(elevation, MIN_ELEVATION_DEG, MAX_ELEVATION_DEG)

static func _swipe_vector(points: PackedVector2Array) -> Vector2:
	if points.size() < 2:
		return Vector2.ZERO
	return points[points.size() - 1] - points[0]

static func _spin_axis_from_contact_and_swipe(contact: Vector2, swipe: Vector2, selected_foot: String) -> Vector3:
	# Intuitive prototype rule:
	# - center + vertical swipe = straight
	# - swipe/contact to screen-left = visible left curl
	# - swipe/contact to screen-right = visible right curl
	# Foot only slightly biases natural inside-foot curl; it must not invert what the player sees.
	var side_action := absf(contact.x) + absf(swipe.x)
	var natural_foot_bias := (-0.12 if selected_foot == "right" else 0.12) * clampf(side_action * 2.0, 0.0, 1.0)
	var raw_side_spin := contact.x * 1.65 + swipe.x * 2.35 + natural_foot_bias
	# Magnus force uses omega x velocity. With goal direction near -Z, positive omega.y
	# bends the ball toward world-left. Hitting/swiping the visible right half of the ball
	# applies that opposite-side spin for a right-foot/left-support setup.
	var side_spin := _signed_deadzone(raw_side_spin, 0.06)
	# Lower contact and upward follow-through bias toward backspin/lift; upper contact/downward follow-through biases topspin/drive.
	var backspin_bias := _signed_deadzone(contact.y - swipe.y * 0.5, 0.08)
	var axis := Vector3(backspin_bias, side_spin, 0.0).normalized()
	return axis if axis.length() > 0.001 else Vector3.ZERO

static func _spin_rate(input: FreeKickInputData, swipe_length: float, curve_stat: float, technique: float) -> float:
	var contact_offset := input.impact_point.length()
	var swipe_vector := _swipe_vector(input.swipe_points)
	var lateral_action := absf(input.impact_point.x) + absf(swipe_vector.x)
	var vertical_action := absf(input.impact_point.y) + absf(swipe_vector.y)
	# Center + straight/short swipe should be close to a knuckle/straight strike, not a high-spin curl.
	var spin_intent := pow(clampf(maxf(lateral_action, vertical_action * 0.8), 0.0, 1.0), 1.35)
	if contact_offset < 0.16 and absf(swipe_vector.x) < 0.10:
		spin_intent *= 0.35
	var rate := lerpf(0.0, MAX_SPIN_RATE, spin_intent) * lerpf(1.25, 2.15, curve_stat) * lerpf(0.95, 1.25, technique)
	if input.used_default_contact:
		rate *= 0.35
	return clampf(rate, 0.0, MAX_SPIN_RATE)

static func _signed_deadzone(value: float, deadzone: float) -> float:
	var magnitude := absf(value)
	if magnitude <= deadzone:
		return 0.0
	return signf(value) * clampf((magnitude - deadzone) / (1.0 - deadzone), 0.0, 1.0)

static func _timeout_penalty(input: FreeKickInputData, difficulty: FreeKickDifficulty, composure: float) -> float:
	var missed_steps := (1 if input.used_default_support else 0) + (1 if input.used_default_contact else 0)
	if missed_steps == 0:
		return 0.0
	return missed_steps * difficulty.default_penalty_scale * difficulty.composure_penalty_scale * (1.0 - composure) * 0.75

static func _error_cone(accuracy: float, technique: float, stability: float, overpower: float, weak_foot_penalty: float, timeout_penalty: float) -> float:
	var base_error := lerpf(8.0, 1.0, accuracy)
	base_error *= lerpf(1.3, 0.75, technique)
	base_error *= lerpf(1.45, 0.8, stability)
	base_error += overpower * 6.0
	base_error += weak_foot_penalty * 5.0
	base_error += timeout_penalty * 6.0
	return clampf(base_error, 0.25, 18.0)

static func _deterministic_error(input: FreeKickInputData, error_cone_degrees: float) -> Vector2:
	# Stable pseudo-random-ish error from raw input. Replace with seeded RNG if match replay needs explicit seed storage.
	# Plant depth can influence consistency, but lateral support-foot side is constrained by kicking foot
	# and must not secretly aim the shot through deterministic error.
	var seed_value := sin(input.hold_time * 12.9898 + input.plant_depth * 78.233 + input.impact_point.y * 37.719)
	var seed2 := cos(input.power_normalized * 91.17 + input.plant_depth * 11.37 + input.impact_point.x * 43.11)
	return Vector2(seed_value, seed2) * error_cone_degrees * 0.35

static func _classify_shot(params: ShotParams, swipe: Vector2) -> StringName:
	if params.spin_rate < 18.0 and params.power > 0.82:
		return &"knuckle_power"
	if params.elevation_angle < 8.0 and swipe.y > 0.25:
		return &"low_driven"
	if absf(params.spin_axis.y) > 0.55 and params.spin_rate > 35.0:
		return &"curling_finesse"
	if params.elevation_angle > 22.0:
		return &"lifted"
	return &"balanced"
