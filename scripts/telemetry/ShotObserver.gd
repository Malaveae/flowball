class_name ShotObserver
extends Node

@export var sample_interval: float = 0.05

var ball: FreeKickBall3D
var shot_params: ShotParams
var telemetry: BallFlightTelemetry
var recording := false
var _accum := 0.0
var _elapsed := 0.0
var _outcome: StringName = &"unknown"

func start_recording(target_ball: FreeKickBall3D, params: ShotParams) -> void:
	ball = target_ball
	shot_params = params
	telemetry = BallFlightTelemetry.new()
	telemetry.sample_interval = sample_interval
	recording = true
	_accum = 0.0
	_elapsed = 0.0
	_outcome = &"in_flight"
	set_process(true)

func record_sample_now() -> void:
	if recording and ball != null and telemetry != null:
		telemetry.add_sample(ball.global_position, ball.linear_velocity)

func stop_recording(outcome: StringName) -> void:
	_outcome = outcome
	recording = false
	set_process(false)
	if telemetry != null:
		telemetry.final_outcome = outcome
		telemetry.total_flight_time = _elapsed

func _process(delta: float) -> void:
	if not recording or ball == null:
		return
	_elapsed += delta
	_accum += delta
	if _accum >= sample_interval:
		_accum = 0.0
		telemetry.add_sample(ball.global_position, ball.linear_velocity)

func build_report(_input_data: FreeKickInputData) -> FreeKickFeedbackReport:
	var report := FreeKickFeedbackReport.new()
	if shot_params != null:
		report.shot_type = shot_params.shot_type
		report.power = shot_params.power
		report.spin_rate = shot_params.spin_rate
		report.elevation_angle = shot_params.elevation_angle
		report.horizontal_angle = shot_params.horizontal_angle
		report.curl_direction = _curl_direction(shot_params)
		report.curl_strength = _curl_strength(shot_params.spin_rate, shot_params.spin_axis.y)
		report.support_feedback = _support_feedback(_input_data)
		report.coach_tip = _coach_tip(_input_data, shot_params, report)
	if telemetry != null:
		report.outcome = telemetry.final_outcome
		report.peak_height = telemetry.peak_height
		report.total_flight_time = telemetry.total_flight_time
	report.summary = "Shot %s - %s - power %d%% - curl %s %s - elev %.0f deg" % [String(report.outcome), String(report.shot_type), roundi(report.power * 100.0), String(report.curl_strength), String(report.curl_direction), report.elevation_angle]
	return report

func _support_feedback(input_data: FreeKickInputData) -> String:
	var expected_side := "left" if input_data.selected_foot == "right" else "right"
	var actual_side := "left" if input_data.support_vector.x < 0.0 else "right" if input_data.support_vector.x > 0.0 else "center"
	var side_note := "plant side OK" if actual_side == expected_side else "plant side corrected to %s" % expected_side
	var depth_note := "balanced plant"
	if input_data.plant_depth < -0.25:
		depth_note = "ahead/open plant: easier curl, less drive"
	elif input_data.plant_depth > 0.25:
		depth_note = "behind/closed plant: more drive, less lift"
	var angle_note := "foot angle aimed center"
	if input_data.support_aim_target > 0.25:
		angle_note = "foot angle aimed right post"
	elif input_data.support_aim_target < -0.25:
		angle_note = "foot angle aimed left post"
	var quality_note := "stable anchor"
	if input_data.support_quality < 0.45:
		quality_note = "poor anchor: less power/control"
	elif input_data.support_quality < 0.72:
		quality_note = "risky anchor"
	return "%s - %s - %s - %s" % [side_note, depth_note, angle_note, quality_note]

func _coach_tip(input_data: FreeKickInputData, params: ShotParams, report: FreeKickFeedbackReport) -> String:
	if input_data.used_default_support or input_data.used_default_contact:
		return "Use all steps before the timer expires for better control."
	if report.outcome == &"goal":
		return "Good sequence. Repeat the same plant side and contact, then vary only foot angle."
	if params.elevation_angle > 28.0:
		return "Too much lift: start contact closer to center or swipe less upward."
	if params.elevation_angle < 6.0:
		return "Too low: start lower on the ball or swipe slightly upward."
	var visible_spin := params.spin_rate * absf(params.spin_axis.y)
	if visible_spin < 28.0:
		return "Need more curl: hit farther to the side and drag longer sideways through the ball."
	if absf(params.horizontal_angle) > 10.0:
		return "Aim correction is large: rotate the support-foot angle closer to neutral."
	if absf(input_data.plant_depth) > 0.65:
		return "Extreme plant depth reduces stability. Try placing the support foot closer to level with the ball."
	return "Balanced shot. Adjust one variable at a time: plant depth, foot angle, then ball contact."

func _curl_direction(params: ShotParams) -> StringName:
	if absf(params.spin_axis.y) < 0.18 or params.spin_rate < 18.0:
		return &"straight"
	return &"right" if params.spin_axis.y > 0.0 else &"left"

func _curl_strength(spin_rate: float, side_axis: float) -> StringName:
	var visible_spin := spin_rate * absf(side_axis)
	if visible_spin < 28.0:
		return &"low"
	if visible_spin < 75.0:
		return &"medium"
	return &"high"
