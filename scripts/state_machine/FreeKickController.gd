class_name FreeKickController
extends Node

signal free_kick_started
signal shot_calculated(shot_params: ShotParams)
signal free_kick_finished(report: Resource)
signal player_profile_changed(profile: FreeKickPlayerProfile)

@export var ball_path: NodePath
@export var kicker_path: NodePath
@export var stats: PlayerFreeKickStats
@export var difficulty: FreeKickDifficulty
@export var environment: FreeKickEnvironment

var input_data: FreeKickInputData = FreeKickInputData.new()
var shot_params: ShotParams
var run_id: int = 0
var free_kick_position: Vector3 = Vector3(0.0, 0.16, 0.0)
var spot_label: String = "Center 24m"
var active_profile_id: String = ""
var active_profile: FreeKickPlayerProfile
var _step2_end_msec: int = 0  # transient: timestamp when step 2 committed, used for step2→3 speed bonus
var step2_time_limit_effective: float = -1.0  # set at PowerState release; power pressure scales the step 2 budget
var step3_time_limit_effective: float = -1.0  # set at PowerState release; power pressure scales the step 3 budget

@onready var state_machine: FreeKickStateMachine = $FreeKickStateMachine
@onready var ui: FreeKickUI = $FreeKickUI
@onready var camera_rig: FreeKickCameraRig = $FreeKickCameraRig
@onready var shot_observer: ShotObserver = $ShotObserver
@onready var trajectory_ghost: TrajectoryGhost3D = $TrajectoryGhost3D

func _ready() -> void:
	if stats == null:
		stats = PlayerFreeKickStats.new()
	if difficulty == null:
		difficulty = FreeKickDifficulty.new()
	if environment == null:
		environment = FreeKickEnvironment.new()
	ui.restart_requested.connect(_on_restart_requested)
	ui.switch_foot_requested.connect(_on_switch_foot_requested)
	ui.next_spot_requested.connect(_on_next_spot_requested)
	state_machine.state_changed.connect(_on_state_changed)
	state_machine.setup(self)

func set_player_profile(profile: FreeKickPlayerProfile) -> void:
	if profile == null:
		return
	active_profile = profile
	active_profile_id = profile.id
	stats = profile.duplicate_stats()
	player_profile_changed.emit(profile)

func preferred_kicking_foot() -> String:
	if stats != null and (stats.preferred_foot == "left" or stats.preferred_foot == "right"):
		return stats.preferred_foot
	return "right"

func set_free_kick_spot(label: String, ball_position: Vector3, goal_position: Vector3 = Vector3(0.0, 1.2, -52.5)) -> void:
	spot_label = label
	free_kick_position = ball_position
	var flat_to_goal := Vector3(goal_position.x - ball_position.x, 0.0, goal_position.z - ball_position.z)
	if environment == null:
		environment = FreeKickEnvironment.new()
	environment.distance_to_goal = flat_to_goal.length()
	if flat_to_goal.length() > 0.001:
		environment.base_goal_direction = flat_to_goal.normalized()
		environment.angle_to_goal = rad_to_deg(atan2(flat_to_goal.x, -flat_to_goal.z))
	if camera_rig != null:
		camera_rig.goal_position = goal_position
	if ui != null:
		ui.set_spot_label(label)

func start_free_kick(selected_foot: String = "right") -> void:
	run_id += 1
	step2_time_limit_effective = -1.0
	step3_time_limit_effective = -1.0
	input_data = FreeKickInputData.new()
	input_data.selected_foot = selected_foot
	if ui != null:
		ui.set_kicking_foot(selected_foot)
	shot_params = null
	if trajectory_ghost != null:
		trajectory_ghost.clear()
	_reset_ball_for_sandbox()
	free_kick_started.emit()
	state_machine.start()

func calculate_shot() -> ShotParams:
	shot_params = ShotCalculator.calculate(input_data, stats, environment, difficulty)
	shot_calculated.emit(shot_params)
	return shot_params

func set_power_time_budget(power: float) -> void:
	# Harder shots give less time to plant and strike (risk/reward for over-power).
	step2_time_limit_effective = difficulty.step_time_budget(power, 2)
	step3_time_limit_effective = difficulty.step_time_budget(power, 3)

func effective_step_time_limit(step: int) -> float:
	match step:
		2: return step2_time_limit_effective if step2_time_limit_effective > 0.0 else difficulty.step2_time_limit
		3: return step3_time_limit_effective if step3_time_limit_effective > 0.0 else difficulty.step3_time_limit
	return 0.0

func get_ball() -> FreeKickBall3D:
	return get_node_or_null(ball_path) as FreeKickBall3D

func get_kicker() -> Node3D:
	return get_node_or_null(kicker_path) as Node3D

func restart_attempt() -> void:
	var sandbox := get_parent()
	if sandbox != null and sandbox.has_method("start_new_attempt"):
		sandbox.call("start_new_attempt", input_data.selected_foot)
	else:
		start_free_kick(input_data.selected_foot)

func _on_restart_requested() -> void:
	restart_attempt()

func _on_switch_foot_requested() -> void:
	var next_foot := "left" if input_data.selected_foot == "right" else "right"
	start_free_kick(next_foot)

func _on_next_spot_requested() -> void:
	var sandbox := get_parent()
	if sandbox != null and sandbox.has_method("cycle_set_piece_spot"):
		sandbox.call("cycle_set_piece_spot")

func _on_state_changed(state_name: StringName) -> void:
	if ui != null:
		ui.set_status("State: %s" % String(state_name))

func _reset_ball_for_sandbox() -> void:
	if shot_observer != null and shot_observer.recording:
		shot_observer.stop_recording(&"reset")
	var ball := get_ball()
	if ball == null:
		return
	ball.reset_for_free_kick(free_kick_position)
	camera_rig.set_mode(&"POWER_VIEW")
