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
	if telemetry != null:
		report.outcome = telemetry.final_outcome
		report.peak_height = telemetry.peak_height
		report.total_flight_time = telemetry.total_flight_time
	report.summary = "Shot %s · %s · power %d%% · curl %s %s · elev %.0f°" % [String(report.outcome), String(report.shot_type), roundi(report.power * 100.0), String(report.curl_strength), String(report.curl_direction), report.elevation_angle]
	return report

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
