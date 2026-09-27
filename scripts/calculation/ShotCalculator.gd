class_name ShotCalculator
extends RefCounted

const MIN_LAUNCH_SPEED := 12.0
const MAX_LAUNCH_SPEED := 36.0
const MIN_ELEVATION_DEG := -3.0
const MAX_ELEVATION_DEG := 35.0
const MAX_SPIN_RATE := 140.0
const MAX_HORIZONTAL_OFFSET_DEG := 35.0
const IDEAL_POWER_MAX := 0.85

# Step 1 substep A: run-up angle is the real approach angle, measured from the goal line
# (0 = running parallel to the goal / lateral approach, 90 = perpendicular to the goal /
# straight-on approach). It never touches shot direction - it's pure technique, trading
# the straight-power/puntera ceiling against the curl/spin ceiling.
#
# Grounded in kicking biomechanics research (Isokawa & Lees; see also the general finding
# that approach angle can range ~15-90deg depending on whether power or curl is wanted,
# with wider angles trading power for hip-rotation room to wrap the ball). That literature
# measures approach angle from the ball-target line (0 = straight, 90 = lateral) - the
# opposite convention from this field, so a straight-on run here (90deg) corresponds to
# their ~0deg (minimal rotation, ideal for a direct/knuckle strike - a center puntera can't
# be hit clean without it), and a lateral run here (0deg) corresponds to their ~90deg
# (maximum hip-rotation room, best curl ceiling, worst straight-power ceiling). Their
# reported 30-45deg power/curl sweet spot sits at 45-60deg in this field's convention.
const RUNUP_ANGLE_MAX_DEG := 90.0
const RUNUP_SPEED_CEILING_AT_LATERAL_ANGLE := 0.4  # 0deg: a center puntera can't land clean - no forward momentum through the ball
const RUNUP_SPEED_CEILING_AT_STRAIGHT_ANGLE := 1.0 # 90deg: full access to top speed - ideal for a straight/knuckle strike
const RUNUP_SPIN_CEILING_AT_LATERAL_ANGLE := 1.0   # 0deg: full curl/wrap potential - maximum hip-rotation room
const RUNUP_SPIN_CEILING_AT_STRAIGHT_ANGLE := 0.5  # 90deg: curl capped - no room to rotate the hip on a straight run

# Run-up distance (step 1 substep A) is a literal ground distance, not a normalized 0..1 - a
# longer approach gives more room to build speed, at the cost of a harder power-release timing.
const RUNUP_DISTANCE_MAX_M := 15.0

# The run-up angle also reshapes the step-1 hold curve itself: a straight-on/power run-up
# reaches the ideal power point sooner AND with a wider, more forgiving window (easy power);
# a lateral/curl run-up is slower to build up through the low/control range, then whips
# through the remaining range in a narrower window once it gets going (harder to land).
const RUNUP_POWER_CENTER_SCALE_AT_LATERAL_ANGLE := 1.15
const RUNUP_POWER_CENTER_SCALE_AT_STRAIGHT_ANGLE := 0.85
const RUNUP_POWER_SMOOTH_SCALE_AT_LATERAL_ANGLE := 0.75
const RUNUP_POWER_SMOOTH_SCALE_AT_STRAIGHT_ANGLE := 1.25

# Step 1 power curve (sigmoid). The ideal window width follows control stats;
# the time to reach the ideal point follows kick_power.
const POWER_CURVE_CENTER_MIN := 0.85  # max-power players: ideal reached fastest
const POWER_CURVE_CENTER_MAX := 1.30  # low-power players: ideal reached slower
const POWER_CURVE_SMOOTH_MIN := 0.12  # low-control: steep, tiny ideal window
const POWER_CURVE_SMOOTH_MAX := 0.38  # high-control: wide ideal window

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

	params.stability = _plant_stability(params.plant_depth, input.support_vector, input.support_quality, input.support_angle_quality)
	# Step 2 sets the body anchor. Curl still comes from Step 3 contact + swipe, but an open
	# support-foot angle can slightly help shape while trading off control.
	params.curve_bias = _support_curve_bias(input.support_aim_target, input.support_quality)
	var foot_angle_offset := _support_aim_target_offset(input.support_aim_target)
	# Support foot side is physical placement. It should not aim the shot directly anymore.
	# Aim is fine-tuned by foot angle; curl/contact comes later in Step 3.
	# Plant distance gates how much aim angle is available: the optimal plant band
	# keeps the full lane, a cramped or overextended plant narrows it.
	var angle_scale := support_angle_scale(input.support_vector)
	params.horizontal_angle = clampf(
		foot_angle_offset * angle_scale,
		-MAX_HORIZONTAL_OFFSET_DEG,
		MAX_HORIZONTAL_OFFSET_DEG
	)

	params.elevation_angle = _elevation_from_contact(input.impact_point, input.swipe_points)
	var swipe_vector := _swipe_vector(input.swipe_points)
	params.spin_axis = _spin_axis_from_contact_and_swipe(input.impact_point, swipe_vector, input.selected_foot)
	params.spin_rate = _spin_rate(input, swipe_vector.length(), curve_stat, technique)
	# Power pressure: over-power damps curl so full-power strikes favor puntera/knuckleball.
	params.spin_rate *= difficulty.spin_power_factor(input.power_normalized)

	# Step 3 gesture (estado3_trazado_roce.md): classify the trace into a technique and
	# score execution quality. Default contact (timer expired) keeps the legacy blind shot.
	var gesture := ContactGesture.analyze(input.swipe_points, input.swipe_duration)
	var gesture_l_max := ContactGesture.l_max(params.power, curve_stat, difficulty)
	var gesture_tech := ContactGesture.classify(gesture, params.power, curve_stat, gesture_l_max, input.selected_foot)
	var gesture_quality := ContactGesture.quality(gesture, gesture_tech, input.selected_foot)
	params.gesture_technique = gesture_tech
	params.gesture_quality = gesture_quality
	params.gesture_l_max = gesture_l_max
	var quality_dispersion := 0.0
	if not input.used_default_contact:
		params.spin_rate *= _technique_spin_factor(gesture_tech)
		params.spin_rate *= 0.5 + 0.5 * gesture_quality
		params.spin_rate = clampf(params.spin_rate, 0.0, MAX_SPIN_RATE)
		params.spin_axis = _technique_axis_adjust(params.spin_axis, gesture_tech)
		params.elevation_angle = clampf(params.elevation_angle + _technique_elevation_adjust(gesture_tech), MIN_ELEVATION_DEG, MAX_ELEVATION_DEG)
		quality_dispersion = _quality_dispersion(gesture_quality, composure, gesture_tech)
	params.quality_dispersion_degrees = quality_dispersion

	# Run-up angle (step 1 substep A) caps how much curl the Step-3 gesture can convert into:
	# a straight run-up halves the ceiling even for a perfect curl swipe, a wide run-up leaves
	# the gesture's full potential untouched. It never adds curl by itself. Opt-in: a player who
	# didn't engage the run-up gesture (a bare tap) gets no ceiling at all, not the straight-run cap.
	if not input.used_default_runup:
		var runup_angle_t := clampf(input.runup_angle_deg, 0.0, RUNUP_ANGLE_MAX_DEG) / RUNUP_ANGLE_MAX_DEG
		var spin_ceiling := lerpf(RUNUP_SPIN_CEILING_AT_LATERAL_ANGLE, RUNUP_SPIN_CEILING_AT_STRAIGHT_ANGLE, runup_angle_t)
		params.spin_rate = minf(params.spin_rate, MAX_SPIN_RATE * spin_ceiling)

	params.error_cone_degrees = _error_cone(accuracy, technique, params.stability, overpower, weak_foot_penalty, timeout_penalty_value) + quality_dispersion
	params.final_error = _deterministic_error(input, params.error_cone_degrees)
	params.horizontal_angle += params.final_error.x
	params.elevation_angle = clampf(params.elevation_angle + params.final_error.y, MIN_ELEVATION_DEG, MAX_ELEVATION_DEG)

	var speed := _launch_speed(params.power, power_stat, environment.distance_to_goal, input.support_quality, input.step2_to_step3_ms, input.runup_distance_m, difficulty.runup_power_bonus_max, input.runup_angle_deg, not input.used_default_runup)
	params.launch_velocity = _launch_velocity(environment.base_goal_direction, params.horizontal_angle, params.elevation_angle, speed)
	params.shot_type = _classify_shot(params, swipe_vector)
	return params

## Step 1 hold curve: a sigmoid whose shape follows the player's stats.
## - Smoothness (window width) scales with control (accuracy/technique/composure):
##   a control player can land the ideal power more easily.
## - Center (where the slope is steepest) scales with kick_power:
##   a power player reaches the ideal point sooner, trading window for speed.
static func power_from_hold(hold_time: float, stats: PlayerFreeKickStats, runup_distance_m: float = 0.0, difficulty: FreeKickDifficulty = null, runup_angle_deg: float = 0.0, runup_engaged: bool = false) -> float:
	if stats == null:
		stats = PlayerFreeKickStats.new()
	var control := (stats.normalized(stats.free_kick_accuracy)
		+ stats.normalized(stats.technique)
		+ stats.normalized(stats.composure)) / 3.0
	var power_stat := stats.normalized(stats.kick_power)
	var center := lerpf(POWER_CURVE_CENTER_MAX, POWER_CURVE_CENTER_MIN, power_stat)
	var smooth := lerpf(POWER_CURVE_SMOOTH_MIN, POWER_CURVE_SMOOTH_MAX, control)
	# Run-up angle reshapes the curve itself: straight-on/power reaches the ideal point
	# sooner and with a wider, more forgiving window; lateral/curl is slower to build up
	# and then whips through a narrower window once it gets going. Opt-in, like the
	# speed/spin ceilings in calculate().
	if runup_engaged:
		var runup_angle_t := clampf(runup_angle_deg, 0.0, RUNUP_ANGLE_MAX_DEG) / RUNUP_ANGLE_MAX_DEG
		center *= lerpf(RUNUP_POWER_CENTER_SCALE_AT_LATERAL_ANGLE, RUNUP_POWER_CENTER_SCALE_AT_STRAIGHT_ANGLE, runup_angle_t)
		smooth *= lerpf(RUNUP_POWER_SMOOTH_SCALE_AT_LATERAL_ANGLE, RUNUP_POWER_SMOOTH_SCALE_AT_STRAIGHT_ANGLE, runup_angle_t)
	# Run-up distance (step 1 substep A) narrows the hold window: a longer run-up steepens
	# the curve so the same release-timing error swings power further off target.
	var runup_distance_t := clampf(runup_distance_m / RUNUP_DISTANCE_MAX_M, 0.0, 1.0)
	var precision_penalty_max := 0.55 if difficulty == null else difficulty.runup_precision_penalty_max
	smooth *= (1.0 - runup_distance_t * precision_penalty_max)
	return _sigmoid_hold(hold_time, center, smooth)

static func _sigmoid_hold(t: float, t0: float, s: float) -> float:
	# Normalized so power(0) = 0 and power(inf) = 1.
	var sig_start := 1.0 / (1.0 + exp(t0 / s))
	var sig_now := 1.0 / (1.0 + exp(-(t - t0) / s))
	return clampf((sig_now - sig_start) / (1.0 - sig_start), 0.0, 1.0)

static func _launch_speed(power: float, power_stat: float, distance: float, support_quality: float, step2_to_step3_ms: int = 0, runup_distance_m: float = 0.0, runup_power_bonus_max: float = 0.0, runup_angle_deg: float = 0.0, runup_engaged: bool = true) -> float:
	var distance_bonus := clampf((distance - 18.0) / 22.0, 0.0, 0.25)
	var support_transfer := lerpf(0.62, 1.0, clampf(support_quality, 0.0, 1.0))
	# Quick transition from step 2 support foot to step 3 ball contact rewards
	# instinctive follow-through. <200ms = max bonus, >800ms = no bonus.
	var transition_bonus := 1.0
	if step2_to_step3_ms > 0:
		var transition_quality := clampf(1.0 - float(step2_to_step3_ms - 200) / 600.0, 0.0, 1.0)
		transition_bonus = lerpf(1.0, 1.08, transition_quality)
	# Run-up distance (step 1 substep A) trades a launch-speed bonus against the power-hold
	# precision penalty applied in power_from_hold.
	var runup_distance_t := clampf(runup_distance_m / RUNUP_DISTANCE_MAX_M, 0.0, 1.0)
	var runup_bonus := 1.0 + runup_distance_t * runup_power_bonus_max
	var speed := lerpf(14.0, MAX_LAUNCH_SPEED, power) * lerpf(0.85, 1.08, power_stat) * support_transfer + distance_bonus * 4.0
	speed *= transition_bonus * runup_bonus
	# Run-up angle caps the top-end speed: a lateral/curl-style run-up trades away straight
	# pace, a straight-on run-up keeps full access to top speed. Opt-in, like the spin
	# ceiling above: no engagement with the run-up gesture means no cap at all.
	if runup_engaged:
		var runup_angle_t := clampf(runup_angle_deg, 0.0, RUNUP_ANGLE_MAX_DEG) / RUNUP_ANGLE_MAX_DEG
		var speed_ceiling := lerpf(RUNUP_SPEED_CEILING_AT_LATERAL_ANGLE, RUNUP_SPEED_CEILING_AT_STRAIGHT_ANGLE, runup_angle_t)
		speed = minf(speed, MAX_LAUNCH_SPEED * speed_ceiling)
	return clampf(speed, MIN_LAUNCH_SPEED, MAX_LAUNCH_SPEED)

static func _launch_velocity(base_direction: Vector3, horizontal_deg: float, elevation_deg: float, speed: float) -> Vector3:
	var flat_dir := base_direction.slide(Vector3.UP).normalized()
	if flat_dir == Vector3.ZERO:
		flat_dir = Vector3.FORWARD
	# Negate angle so positive = curve toward +X (right), negative = curve toward -X (left).
	flat_dir = flat_dir.rotated(Vector3.UP, deg_to_rad(-horizontal_deg)).normalized()
	var horizontal_speed := speed * cos(deg_to_rad(elevation_deg))
	var vertical_speed := speed * sin(deg_to_rad(elevation_deg))
	return flat_dir * horizontal_speed + Vector3.UP * vertical_speed

static func _plant_stability(plant_depth: float, support_vector: Vector2, support_quality: float, angle_quality: float) -> float:
	# The support foot is the biomechanical anchor: distance controls leverage, depth controls balance,
	# and foot angle controls hip rotation. Poor placement lowers power and expands the error cone.
	var depth_stability := clampf(1.0 - absf(plant_depth) * 0.30, 0.62, 1.0)
	var overreach_penalty := clampf((support_vector.length() - 0.65) / 0.45, 0.0, 1.0) * 0.18
	var quality := clampf(support_quality, 0.0, 1.0) * clampf(angle_quality, 0.0, 1.0)
	return clampf(depth_stability * lerpf(0.50, 1.0, quality) - overreach_penalty, 0.35, 1.0)

static func _support_curve_bias(aim_target: float, support_quality: float) -> float:
	# A moderately open plant supports curl. Bad support reduces that benefit.
	var open_amount := absf(clampf(aim_target, -1.0, 1.0))
	if open_amount < 0.25:
		return 0.0
	return clampf((open_amount - 0.25) / 0.75, 0.0, 1.0) * clampf(support_quality, 0.0, 1.0) * 0.18

static func support_angle_scale(support_vector: Vector2) -> float:
	# Plant distance controls rotational freedom (the biomechanical anchor):
	# the optimal plant band (0.20-0.35 normalized) keeps the full aim angle;
	# too close (cramped, foot crowding the ball) or too far (overextended,
	# lunging) narrows how far the shooter can open the shot.
	# Bands mirror _support_quality in SupportFootState (piedeapoyo.md).
	var distance := support_vector.length()
	if distance < 0.20:
		# Cramped: the marker clamp floors at ~0.18, so this band is steep.
		return lerpf(0.40, 1.0, clampf((distance - 0.18) / 0.02, 0.0, 1.0))
	if distance <= 0.35:
		return 1.0
	if distance <= 0.55:
		return lerpf(1.0, 0.60, (distance - 0.35) / 0.20)
	return lerpf(0.55, 0.25, clampf((distance - 0.55) / 0.45, 0.0, 1.0))

static func _support_aim_target_offset(target: float) -> float:
	# Step 2 substep B: the foot points at a target lane, independent of support-foot side.
	# Input convention: -1 = left post, 0 = center, +1 = right post.
	# Full aim range maps to MAX_HORIZONTAL_OFFSET_DEG so the player can aim
	# OUTSIDE the post and let the curl bring the ball back (wide-to-post curl shots).
	return clampf(target, -1.0, 1.0) * MAX_HORIZONTAL_OFFSET_DEG

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
	var natural_foot_bias := (0.12 if selected_foot == "right" else -0.12) * clampf(side_action * 2.0, 0.0, 1.0)
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
	spin_intent = clampf(spin_intent + absf(input.support_aim_target) * input.support_quality * 0.08, 0.0, 1.0)
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
	var missed_steps := (1 if input.used_default_runup else 0) + (1 if input.used_default_support else 0) + (1 if input.used_default_contact else 0)
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

static func _technique_spin_factor(tech: ContactGesture.Technique) -> float:
	# Doc section 2: technique scales how much effect the gesture can impart.
	match tech:
		ContactGesture.Technique.INSTEP:
			return 1.25
		ContactGesture.Technique.OUTSTEP:
			return 1.15
		ContactGesture.Technique.LACE_LONG:
			return 1.05
		ContactGesture.Technique.PUNTERA:
			return 0.35
		ContactGesture.Technique.DIRTY:
			return 0.85
	return 1.0

static func _technique_axis_adjust(axis: Vector3, tech: ContactGesture.Technique) -> Vector3:
	var result := axis
	match tech:
		ContactGesture.Technique.INSTEP:
			result.y *= 1.35
		ContactGesture.Technique.OUTSTEP:
			result.y *= 1.2
		ContactGesture.Technique.TOPSPIN:
			result.x = -absf(result.x)  # topspin: Magnus pulls the ball down late (dip)
		ContactGesture.Technique.BACKSPIN:
			result.x = absf(result.x)  # backspin: the ball floats
	return result.normalized() if result.length() > 0.001 else Vector3.ZERO

static func _technique_elevation_adjust(tech: ContactGesture.Technique) -> float:
	match tech:
		ContactGesture.Technique.TOPSPIN:
			return -3.0
		ContactGesture.Technique.BACKSPIN:
			return 2.0
		ContactGesture.Technique.PUNTERA:
			return 1.5
		ContactGesture.Technique.LACE_LONG:
			return -1.0
		ContactGesture.Technique.INSTEP, ContactGesture.Technique.OUTSTEP:
			return -1.0
	return 0.0

static func _quality_dispersion(gesture_quality: float, composure: float, tech: ContactGesture.Technique) -> float:
	# Doc section 5: dispersión_extra = (1 - calidad) x 2deg x (1 - PRE/200).
	# PRE maps to the player's composure (0..1). Puntera is inherently unpredictable;
	# dirty signatures spread even more.
	var base := (1.0 - gesture_quality) * 2.0 * (1.0 - composure * 0.5)
	match tech:
		ContactGesture.Technique.PUNTERA:
			base += 2.0
		ContactGesture.Technique.DIRTY:
			base += 1.5
	return base
