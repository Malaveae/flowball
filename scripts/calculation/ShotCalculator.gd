class_name ShotCalculator
extends RefCounted

const MIN_LAUNCH_SPEED := 12.0
const MAX_LAUNCH_SPEED := 36.0
const MIN_ELEVATION_DEG := -3.0
const MAX_ELEVATION_DEG := 35.0
# Spin the ball can actually carry: Jolt clamps angular speed to
# physics/jolt_physics_3d/limits/max_angular_velocity (47.12 rad/s), so anything above it is
# never flown. It sits inside measured curled-kick spin (25-59 rad/s), and at this rate
# BallAerodynamics3D's Magnus term gives a lift coefficient (~0.27 at 25 m/s) inside the
# 0.23-0.29 Bray & Kerwin (2003) measured on real free kicks.
const MAX_SPIN_RATE := 47.12
# Swipe intent -> spin scale. Chosen so a neutral (70-rated) kicker's full-intent swipe lands
# exactly at MAX_SPIN_RATE before technique factors; the old 140 rad/s scale saturated far
# above what Jolt can fly, which silently erased curl trade-offs (overpower, follow-through,
# rosca) for any strong swipe. Neutral stat multiplier = lerp(1.25,2.15,0.7) * lerp(0.95,1.25,0.7).
const SPIN_NEUTRAL_STAT_MULT := 1.88 * 1.16
const SPIN_INTENT_SCALE := MAX_SPIN_RATE / SPIN_NEUTRAL_STAT_MULT
# Spin bands on real flown spin (0..MAX_SPIN_RATE), shared by classification and feedback.
const CURL_SHOT_MIN_SPIN := 20.0      # "curling_finesse" label
const VISIBLE_CURL_STRAIGHT := 6.0    # side spin below this reads as straight
const VISIBLE_CURL_LOW := 15.0
const VISIBLE_CURL_MEDIUM := 30.0
const MAX_HORIZONTAL_OFFSET_DEG := 35.0
const IDEAL_POWER_MAX := 0.85

# Knuckle (see BallAerodynamics3D.knuckle_accel for the in-flight wobble).
const KNUCKLE_SPEED_MIN := 16.0   # m/s: no knuckle at or below this launch speed
const KNUCKLE_SPEED_FULL := 22.0
const KNUCKLE_SPIN_FULL := 4.0    # rad/s: full knuckle at or below this spin
const KNUCKLE_SPIN_MAX := 14.0    # rad/s: no knuckle at or above this spin
const KNUCKLE_CONTACT_RADIUS_MAX := 0.12  # normalized ball radii from center
const KNUCKLE_TRACE_RATIO_MAX := 0.40     # trace length as a fraction of L_max
# Since the intent->spin curve was rescaled to MAX_SPIN_RATE, a canonical clean strike (center,
# 0.3-radius straight trace, power 0.8) already lands at ~2.4 rad/s and a 0.6-radius trace at
# ~6 rad/s, so no extra damping is needed: gain still rewards the shortest, cleanest strike.
# Kept as a tuning knob (was 0.2 against the old 140 rad/s scale).
const KNUCKLE_CLEAN_STRIKE_SPIN_SCALE := 1.0

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
# (maximum hip-rotation room, best curl ceiling). Their reported 30-45deg sweet spot for ball
# speed sits at 45-60deg in this field's convention (see runup_speed_ceiling).
const RUNUP_ANGLE_MAX_DEG := 90.0
# Speed ceiling vs approach angle peaks on the studies' optimum instead of rising linearly to a
# straight run: Isokawa & Lees (1988) found peak ball speed at a 30-45deg approach (45-60deg
# here), declining beyond; Scurr & Hall (2009, JSSM 8:230) found no significant ball-speed
# difference across 30/45/60deg (~25 m/s). Neither reports a large drop, so both ends lose only
# a little. The end values are estimates (no study quantifies the fall-off) - tune by feel.
const RUNUP_SPEED_PEAK_START_DEG := 45.0
const RUNUP_SPEED_PEAK_END_DEG := 60.0
const RUNUP_SPEED_CEILING_AT_LATERAL_ANGLE := 0.85  # 0deg: body can't drive forward through the ball as well
const RUNUP_SPEED_CEILING_AT_STRAIGHT_ANGLE := 0.90 # 90deg: little hip rotation to add to leg speed
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

# Step 1+2 (merged): the power bar auto-fills the instant run-up commits, walking through
# four fixed zones (LOW/CONTROL/IDEAL/RISK, matching PowerMeterPanel's HUD colors) at a
# per-zone rate. kick_power sets overall pace; the accuracy/technique/composure average
# ("control") specifically stretches the IDEAL zone's duration (a more forgiving window to
# release in, not a literal wider power range).
const POWER_STAT_SPEED_MIN := 0.8    # low kick_power: slower overall pace
const POWER_STAT_SPEED_MAX := 1.3    # high kick_power: faster overall pace
const POWER_CONTROL_WIDEN_MIN := 0.6 # low control: less time to release in the ideal zone
const POWER_CONTROL_WIDEN_MAX := 1.5 # high control: more time to release in the ideal zone

# Run-up distance reshapes how fast the bar moves through each zone, continuously
# interpolated across 3 reference points (short=0m, medium=7.5m, far=RUNUP_DISTANCE_MAX_M).
# Reads as momentum: a long run-up carries you fast through low/control/ideal but pushing
# past your natural pace into max power is the hard part; a short run-up has a sluggish
# start but explodes through control/ideal/risk once moving. Each regime has exactly one
# "slow" zone (0.5x) immediately followed by one "neutral" (1.0x) zone; everything else is
# "fast" (1.6x).
const RUNUP_ZONE_LOW_SHORT := 0.5
const RUNUP_ZONE_LOW_MEDIUM := 1.6
const RUNUP_ZONE_LOW_FAR := 1.6
const RUNUP_ZONE_CONTROL_SHORT := 1.0
const RUNUP_ZONE_CONTROL_MEDIUM := 0.5
const RUNUP_ZONE_CONTROL_FAR := 1.6
const RUNUP_ZONE_IDEAL_SHORT := 1.6
const RUNUP_ZONE_IDEAL_MEDIUM := 1.0
const RUNUP_ZONE_IDEAL_FAR := 1.6
const RUNUP_ZONE_RISK_SHORT := 1.6
const RUNUP_ZONE_RISK_MEDIUM := 1.6
const RUNUP_ZONE_RISK_FAR := 0.5

# Directional flaw model (see _flaw_terms). One unit of flaw moves the shot by
# FLAW_ERROR_SCALE x error cone degrees - the same peak size the old hash error had.
const FLAW_ERROR_SCALE := 0.35
const FLAW_OVERPOWER_LIFT := 1.0
# Plant bands mirror support_angle_scale / SupportFootState (normalized lateral distance).
const FLAW_CRAMPED_DISTANCE := 0.20   # below this the plant crowds the ball
const FLAW_CRAMPED_RAMP := 0.02       # marker clamp floors at ~0.18, so this band is steep
const FLAW_CRAMPED_DROP := 1.0
const FLAW_OVERREACH_START := 0.35    # end of the optimal band
const FLAW_OVERREACH_RAMP := 0.45     # full drag by ~0.8 (well into "strongly penalized")
const FLAW_OVERREACH_PULL := 1.0
const FLAW_BALANCED_DEPTH := -0.10    # SupportFootState: slightly ahead of the ball is balanced
const FLAW_DEPTH_RAMP := 0.75
const FLAW_DEPTH_LIFT := 0.6
const FLAW_OPEN_FOOT_START := 0.55    # matches SupportFootState.support_angle_quality
const FLAW_OPEN_FOOT_PULL := 0.8
const FLAW_SLICE_CONTACT_GAIN := 3.0  # contact ~0.33 radii off-center gives the full slice side
const FLAW_SLICE_PULL := 1.0
const FLAW_PUNTERA_LIFT := 0.5
const FLAW_REPORT_MIN := 0.15        # flaw units below which a strike counts as clean for feedback

# Power-value bounds of the four HUD zones (must match PowerMeterPanel's LOW/CONTROL/IDEAL/RISK).
const POWER_ZONE_LOW_WIDTH := 0.40
const POWER_ZONE_CONTROL_WIDTH := 0.30
const POWER_ZONE_IDEAL_WIDTH := 0.15
const POWER_ZONE_RISK_WIDTH := 0.15

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

	# Knuckle strike: a clean, near-center, short straight trace barely spins the ball. The
	# extra damping here is what makes the knuckle reachable (spin must drop under ~14 rad/s).
	var clean_knuckle_strike := _is_clean_knuckle_strike(input, gesture, gesture_l_max)
	if clean_knuckle_strike:
		params.spin_rate *= KNUCKLE_CLEAN_STRIKE_SPIN_SCALE

	# Run-up angle (step 1 substep A) caps how much curl the Step-3 gesture can convert into:
	# a straight run-up halves the ceiling even for a perfect curl swipe, a wide run-up leaves
	# the gesture's full potential untouched. It never adds curl by itself. Opt-in: a player who
	# didn't engage the run-up gesture (a bare tap) gets no ceiling at all, not the straight-run cap.
	if not input.used_default_runup:
		var runup_angle_t := clampf(input.runup_angle_deg, 0.0, RUNUP_ANGLE_MAX_DEG) / RUNUP_ANGLE_MAX_DEG
		var spin_ceiling := lerpf(RUNUP_SPIN_CEILING_AT_LATERAL_ANGLE, RUNUP_SPIN_CEILING_AT_STRAIGHT_ANGLE, runup_angle_t)
		params.spin_rate = minf(params.spin_rate, MAX_SPIN_RATE * spin_ceiling)

	params.error_cone_degrees = _error_cone(accuracy, technique, params.stability, overpower, weak_foot_penalty, timeout_penalty_value) + quality_dispersion
	var flaws := _flaw_terms(input, overpower, gesture_quality, gesture_tech, not input.used_default_contact)
	params.final_error = _sum_flaws(flaws) * params.error_cone_degrees * FLAW_ERROR_SCALE
	params.dominant_flaw = _dominant_flaw(flaws)
	params.horizontal_angle += params.final_error.x
	params.elevation_angle = clampf(params.elevation_angle + params.final_error.y, MIN_ELEVATION_DEG, MAX_ELEVATION_DEG)

	var speed := _launch_speed(params.power, power_stat, environment.distance_to_goal, input.support_quality, input.step2_to_step3_ms, input.runup_distance_m, difficulty.runup_power_bonus_max, input.runup_angle_deg, not input.used_default_runup)
	params.launch_velocity = _launch_velocity(environment.base_goal_direction, params.horizontal_angle, params.elevation_angle, speed)
	if clean_knuckle_strike:
		params.knuckle_gain = knuckle_physical_gain(speed, params.spin_rate) \
			* lerpf(0.6, 1.0, technique) \
			* lerpf(0.7, 1.0, clampf(gesture_quality, 0.0, 1.0)) \
			* lerpf(0.7, 1.0, clampf(input.support_quality, 0.0, 1.0))
	params.knuckle_amp = difficulty.knuckle_amp_max
	params.knuckle_seed = _knuckle_seed(input, environment.set_piece_seed)
	params.shot_type = _classify_shot(params, swipe_vector)
	return params

## Knuckle needs pace and almost no spin: 0 at <=16 m/s or >=14 rad/s, full at >=22 m/s and <=4 rad/s.
static func knuckle_physical_gain(speed: float, spin_rate: float) -> float:
	return smoothstep(KNUCKLE_SPEED_MIN, KNUCKLE_SPEED_FULL, speed) \
		* (1.0 - smoothstep(KNUCKLE_SPIN_FULL, KNUCKLE_SPIN_MAX, spin_rate))

static func _is_clean_knuckle_strike(input: FreeKickInputData, metrics: Dictionary, l_max: float) -> bool:
	if input.used_default_contact:
		return false
	var length: float = metrics.get("length", 0.0)
	return input.impact_point.length() <= KNUCKLE_CONTACT_RADIUS_MAX \
		and length >= ContactGesture.MIN_GESTURE_LENGTH \
		and length <= l_max * KNUCKLE_TRACE_RATIO_MAX \
		and float(metrics.get("curvature", 0.0)) < ContactGesture.CURVATURE_LOW

## Quantized input + set piece: the same input always wobbles the same way (learnable and
## shareable); a slightly different input gives a different - but equally fixed - wobble.
static func _knuckle_seed(input: FreeKickInputData, set_piece_seed: int) -> int:
	var swipe := _swipe_vector(input.swipe_points)
	return hash([
		set_piece_seed,
		roundi(input.impact_point.x / 0.05), roundi(input.impact_point.y / 0.05),
		roundi(swipe.x / 0.05), roundi(swipe.y / 0.05),
		roundi(input.power_normalized / 0.01),
		roundi(input.support_aim_target / 0.05),
	])

## Step 1+2 (merged) hold curve: the power bar auto-fills through four fixed zones
## (LOW/CONTROL/IDEAL/RISK). kick_power sets overall pace; control (accuracy/technique/
## composure) stretches how long the IDEAL zone lasts (a more forgiving release window);
## run-up angle (opt-in, as elsewhere) reshapes both the same way it always has; run-up
## distance reshapes each zone's speed independently (see RUNUP_ZONE_* constants above).
static func power_from_hold(hold_time: float, stats: PlayerFreeKickStats, runup_distance_m: float = 0.0, difficulty: FreeKickDifficulty = null, runup_angle_deg: float = 0.0, runup_engaged: bool = false) -> float:
	if stats == null:
		stats = PlayerFreeKickStats.new()
	if difficulty == null:
		difficulty = FreeKickDifficulty.new()
	var control := (stats.normalized(stats.free_kick_accuracy)
		+ stats.normalized(stats.technique)
		+ stats.normalized(stats.composure)) / 3.0
	var power_stat := stats.normalized(stats.kick_power)
	var speed := lerpf(POWER_STAT_SPEED_MIN, POWER_STAT_SPEED_MAX, power_stat)
	var widen := lerpf(POWER_CONTROL_WIDEN_MIN, POWER_CONTROL_WIDEN_MAX, control)
	# Run-up angle reshapes the curve itself: straight-on/power reaches the ideal point
	# sooner and with a wider, more forgiving window; lateral/curl is slower to build up
	# and then whips through a narrower window once it gets going. Opt-in, like the
	# speed/spin ceilings in calculate().
	if runup_engaged:
		var runup_angle_t := clampf(runup_angle_deg, 0.0, RUNUP_ANGLE_MAX_DEG) / RUNUP_ANGLE_MAX_DEG
		speed /= lerpf(RUNUP_POWER_CENTER_SCALE_AT_LATERAL_ANGLE, RUNUP_POWER_CENTER_SCALE_AT_STRAIGHT_ANGLE, runup_angle_t)
		widen *= lerpf(RUNUP_POWER_SMOOTH_SCALE_AT_LATERAL_ANGLE, RUNUP_POWER_SMOOTH_SCALE_AT_STRAIGHT_ANGLE, runup_angle_t)
	var distance_t := clampf(runup_distance_m / RUNUP_DISTANCE_MAX_M, 0.0, 1.0)
	var low_mult := _lerp3(RUNUP_ZONE_LOW_SHORT, RUNUP_ZONE_LOW_MEDIUM, RUNUP_ZONE_LOW_FAR, distance_t)
	var control_mult := _lerp3(RUNUP_ZONE_CONTROL_SHORT, RUNUP_ZONE_CONTROL_MEDIUM, RUNUP_ZONE_CONTROL_FAR, distance_t)
	var ideal_mult := _lerp3(RUNUP_ZONE_IDEAL_SHORT, RUNUP_ZONE_IDEAL_MEDIUM, RUNUP_ZONE_IDEAL_FAR, distance_t)
	var risk_mult := _lerp3(RUNUP_ZONE_RISK_SHORT, RUNUP_ZONE_RISK_MEDIUM, RUNUP_ZONE_RISK_FAR, distance_t)
	var low_dur := difficulty.power_zone_low_seconds / (speed * low_mult)
	var control_dur := difficulty.power_zone_control_seconds / (speed * control_mult)
	var ideal_dur := difficulty.power_zone_ideal_seconds * widen / (speed * ideal_mult)
	var risk_dur := difficulty.power_zone_risk_seconds / (speed * risk_mult)
	return _walk_power_zones(hold_time, [
		Vector2(low_dur, POWER_ZONE_LOW_WIDTH),
		Vector2(control_dur, POWER_ZONE_CONTROL_WIDTH),
		Vector2(ideal_dur, POWER_ZONE_IDEAL_WIDTH),
		Vector2(risk_dur, POWER_ZONE_RISK_WIDTH),
	])

## Walks hold_time through a sequence of (duration_seconds, power_width) zones, each
## traversed at a constant rate, saturating at 1.0 once past the last zone.
static func _walk_power_zones(hold_time: float, zones: Array) -> float:
	var remaining := hold_time
	var power_floor := 0.0
	for zone in zones:
		var duration: float = zone.x
		var width: float = zone.y
		if remaining < duration:
			return clampf(power_floor + width * (remaining / maxf(duration, 0.0001)), 0.0, 1.0)
		remaining -= duration
		power_floor += width
	return 1.0

## Piecewise-lerps short->medium over t in [0, 0.5] and medium->far over t in [0.5, 1].
static func _lerp3(short_value: float, medium_value: float, far_value: float, t: float) -> float:
	if t <= 0.5:
		return lerpf(short_value, medium_value, t * 2.0)
	return lerpf(medium_value, far_value, (t - 0.5) * 2.0)

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
		speed = minf(speed, MAX_LAUNCH_SPEED * runup_speed_ceiling(runup_angle_deg))
	return clampf(speed, MIN_LAUNCH_SPEED, MAX_LAUNCH_SPEED)

## Fraction of MAX_LAUNCH_SPEED reachable from a run-up angle: 1.0 on the 45-60deg plateau,
## easing down to the lateral/straight ends (see RUNUP_SPEED_* constants).
static func runup_speed_ceiling(runup_angle_deg: float) -> float:
	var angle := clampf(runup_angle_deg, 0.0, RUNUP_ANGLE_MAX_DEG)
	if angle < RUNUP_SPEED_PEAK_START_DEG:
		return lerpf(RUNUP_SPEED_CEILING_AT_LATERAL_ANGLE, 1.0, smoothstep(0.0, RUNUP_SPEED_PEAK_START_DEG, angle))
	if angle > RUNUP_SPEED_PEAK_END_DEG:
		return lerpf(1.0, RUNUP_SPEED_CEILING_AT_STRAIGHT_ANGLE, smoothstep(RUNUP_SPEED_PEAK_END_DEG, RUNUP_ANGLE_MAX_DEG, angle))
	return 1.0

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
	var rate := lerpf(0.0, SPIN_INTENT_SCALE, spin_intent) * lerpf(1.25, 2.15, curve_stat) * lerpf(0.95, 1.25, technique)
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

## Directional flaw model: each technical flaw pushes the ball a predictable way, so a player
## can read a miss and correct it (skill-only design; a clean strike has no error at all).
## Flaw directions follow piedeapoyo.md plus standard kicking coaching; the error cone (stats,
## stability, overpower, timeouts, weak foot, gesture dispersion) only scales how hard they bite.
## Every term is continuous in the inputs: near-identical inputs give near-identical shots.
## x = horizontal (+ right), y = vertical (+ up), in flaw units later scaled to degrees.
static func _flaw_terms(input: FreeKickInputData, overpower: float, gesture_quality: float, gesture_tech: ContactGesture.Technique, used_gesture: bool) -> Dictionary:
	var terms := {}
	# Over-hitting past the ideal zone: the body leans back and the ball sails high.
	terms[&"overpower"] = Vector2(0.0, overpower * FLAW_OVERPOWER_LIFT)
	# Plant distance uses only |x| - the support side is fixed by the kicking foot and must
	# never aim the shot. Cramped ("golpe trabado"): scuffed and low. Overextended ("tiros
	# cruzados"): the leg drags across the body - left for a right-footer, right for a left-footer.
	var lateral := absf(input.support_vector.x)
	var across := -1.0 if input.selected_foot == "right" else 1.0
	terms[&"cramped_plant"] = Vector2(0.0, -clampf((FLAW_CRAMPED_DISTANCE - lateral) / FLAW_CRAMPED_RAMP, 0.0, 1.0) * FLAW_CRAMPED_DROP)
	terms[&"overextended_plant"] = Vector2(across * clampf((lateral - FLAW_OVERREACH_START) / FLAW_OVERREACH_RAMP, 0.0, 1.0) * FLAW_OVERREACH_PULL, 0.0)
	# Plant depth relative to the balanced spot (slightly ahead, see SupportFootState): a plant
	# behind the ball leans the body back (ball rises); too far ahead keeps it down.
	terms[&"plant_depth"] = Vector2(0.0, clampf((input.plant_depth - FLAW_BALANCED_DEPTH) / FLAW_DEPTH_RAMP, -1.0, 1.0) * FLAW_DEPTH_LIFT)
	# Foot opened past the controlled range ("demasiado abierto"): the ball runs further across
	# in the direction the foot points.
	var aim := clampf(input.support_aim_target, -1.0, 1.0)
	terms[&"open_foot"] = Vector2(signf(aim) * clampf((absf(aim) - FLAW_OPEN_FOOT_START) / (1.0 - FLAW_OPEN_FOOT_START), 0.0, 1.0) * FLAW_OPEN_FOOT_PULL, 0.0)
	if used_gesture:
		# A messy trace slices the ball away from the side it was struck on; a toe-poke pops up.
		var slice := clampf(input.impact_point.x * FLAW_SLICE_CONTACT_GAIN, -1.0, 1.0)
		terms[&"messy_contact"] = Vector2(-slice * (1.0 - clampf(gesture_quality, 0.0, 1.0)) * FLAW_SLICE_PULL, 0.0)
		if gesture_tech == ContactGesture.Technique.PUNTERA:
			terms[&"toe_poke"] = Vector2(0.0, FLAW_PUNTERA_LIFT)
	return terms

static func _sum_flaws(terms: Dictionary) -> Vector2:
	var flaw := Vector2.ZERO
	for key in terms:
		flaw += terms[key]
	return flaw

## Flaw that moved the shot most (for coach feedback); &"" when the strike was clean.
static func _dominant_flaw(terms: Dictionary) -> StringName:
	var best := &""
	var best_size := FLAW_REPORT_MIN
	for key in terms:
		var size: float = (terms[key] as Vector2).length()
		if size > best_size:
			best_size = size
			best = key
	return best

static func _classify_shot(params: ShotParams, swipe: Vector2) -> StringName:
	if params.knuckle_gain >= 0.5:
		return &"knuckle_power"
	if params.elevation_angle < 8.0 and swipe.y > 0.25:
		return &"low_driven"
	if absf(params.spin_axis.y) > 0.55 and params.spin_rate > CURL_SHOT_MIN_SPIN:
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
