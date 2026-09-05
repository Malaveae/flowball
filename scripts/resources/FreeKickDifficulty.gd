class_name FreeKickDifficulty
extends Resource

@export var step2_time_limit: float = 1.5  # TESTING: reduced from 3.0
@export var step3_time_limit: float = 2.8
@export var sector_size_multiplier: float = 1.0
@export_range(0, 3, 1) var guidance_level: int = 1
@export var default_penalty_scale: float = 1.0
@export var composure_penalty_scale: float = 1.0
@export_range(0.0, 1.0, 0.01) var input_smoothing_assist: float = 0.35
@export var auto_commit_threshold_multiplier: float = 1.0

# Power pressure: charging past the ideal zone shrinks the step 2/3 time budget.
@export_range(0.0, 1.0, 0.01) var time_penalty_threshold: float = 0.85  # keep in sync with ShotCalculator.IDEAL_POWER_MAX
@export var min_step2_time: float = 0.8  # step 2 (support foot) window in seconds at 100% power
@export var min_step3_time: float = 0.4  # step 3 (ball contact) window in seconds at 100% power
@export_range(0.25, 3.0, 0.05) var power_time_ramp: float = 1.0  # 1.0 = linear, >1 delays the bite toward full power
@export var max_swipe_scale: float = 1.8  # step 3 follow-through trace cap (ball radii) at/below ideal power
@export var min_swipe_scale: float = 0.6  # trace cap at 100% power: no room for a long curl swipe
@export_range(0.0, 1.0, 0.01) var spin_power_loss: float = 0.75  # spin rate multiplier loss at full over-power

func step_time_budget(power: float, step: int) -> float:
	# Full base time up to the ideal zone ceiling, then drops toward the per-step floor at full power.
	var base_time := step2_time_limit if step == 2 else step3_time_limit
	var min_time := min_step2_time if step == 2 else min_step3_time
	var p := clampf(power, 0.0, 1.0)
	if p <= time_penalty_threshold:
		return base_time
	var t := (p - time_penalty_threshold) / (1.0 - time_penalty_threshold)
	return lerpf(base_time, min_time, pow(t, power_time_ramp))

func swipe_scale(power: float) -> float:
	# Trace budget for the step 3 follow-through: full length up to the ideal zone,
	# then it shrinks so over-power strikes favor a straight/puntera or knuckleball.
	var p := clampf(power, 0.0, 1.0)
	if p <= time_penalty_threshold:
		return max_swipe_scale
	var t := (p - time_penalty_threshold) / (1.0 - time_penalty_threshold)
	return lerpf(max_swipe_scale, min_swipe_scale, pow(t, power_time_ramp))

func spin_power_factor(power: float) -> float:
	# Power pressure also damps curl: an over-powered strike cannot impart full spin.
	var p := clampf(power, 0.0, 1.0)
	if p <= time_penalty_threshold:
		return 1.0
	var t := (p - time_penalty_threshold) / (1.0 - time_penalty_threshold)
	return 1.0 - spin_power_loss * pow(t, power_time_ramp)
