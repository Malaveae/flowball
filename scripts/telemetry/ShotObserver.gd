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
	if telemetry != null:
		report.outcome = telemetry.final_outcome
		report.peak_height = telemetry.peak_height
		report.total_flight_time = telemetry.total_flight_time
	report.summary = "Shot %s · %s · power %d%% · spin %.1f rad/s" % [String(report.outcome), String(report.shot_type), roundi(report.power * 100.0), report.spin_rate]
	return report
