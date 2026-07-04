class_name ExecuteShotState
extends FreeKickState

@export var fallback_contact_delay: float = 0.25
@export var max_shot_duration: float = 7.0
@export var min_contact_feedback_distance: float = 3.0

var _run_id: int = -1
var _launched_ball: FreeKickBall3D
var _launch_position := Vector3.ZERO
var _shot_finished := false

func enter(_controller: FreeKickController) -> void:
	super.enter(_controller)
	_run_id = controller.run_id
	_shot_finished = false
	controller.camera_rig.set_mode(&"SHOT_FOLLOW")
	controller.ui.hide_all()
	var ball := controller.get_ball()
	_launched_ball = ball
	if controller.shot_observer != null and ball != null:
		controller.shot_observer.start_recording(ball, controller.shot_params)
	# TODO: replace with AnimationTree/AnimationPlayer contact-frame signal.
	await get_tree().create_timer(fallback_contact_delay).timeout
	if controller == null or controller.run_id != _run_id or controller.state_machine.current_state != self:
		return
	if ball != null:
		_launch_position = ball.global_position
		if ball.aerodynamics != null:
			ball.aerodynamics.wind_vector = controller.environment.wind_vector
		ball.launch(controller.shot_params, controller.get_kicker())
		if not ball.came_to_rest.is_connected(_on_ball_done):
			ball.came_to_rest.connect(_on_ball_done, CONNECT_ONE_SHOT)
		if not ball.body_entered.is_connected(_on_ball_body_entered):
			ball.body_entered.connect(_on_ball_body_entered)
		_force_feedback_after_timeout(_run_id)
	else:
		_on_ball_done()

func exit() -> void:
	if _launched_ball != null and _launched_ball.came_to_rest.is_connected(_on_ball_done):
		_launched_ball.came_to_rest.disconnect(_on_ball_done)
	if _launched_ball != null and _launched_ball.body_entered.is_connected(_on_ball_body_entered):
		_launched_ball.body_entered.disconnect(_on_ball_body_entered)
	_launched_ball = null
	super.exit()

func _force_feedback_after_timeout(shot_run_id: int) -> void:
	await get_tree().create_timer(max_shot_duration).timeout
	if controller == null or controller.run_id != shot_run_id or controller.state_machine.current_state != self:
		return
	_finish_shot(&"timeout")

func _on_ball_done() -> void:
	_finish_shot(&"landed")

func _on_ball_body_entered(body: Node) -> void:
	if body == null or _launched_ball == null:
		return
	if _launched_ball.global_position.distance_to(_launch_position) < min_contact_feedback_distance:
		return
	if _is_feedback_contact_body(body):
		_finish_shot(_outcome_for_contact_body(body))

func _is_feedback_contact_body(body: Node) -> bool:
	var body_name := String(body.name)
	return body_name == "TribunaBackground" \
		or body_name == "GoalCollision" \
		or body_name == "Goalkeeper" \
		or body_name == "GoalkeeperCollision" \
		or body_name == "GoalNetCollision" \
		or body_name.begins_with("WallDummy")

func _outcome_for_contact_body(body: Node) -> StringName:
	var body_name := String(body.name)
	if body_name == "TribunaBackground":
		return &"background_contact"
	if body_name == "Goalkeeper" or body_name == "GoalkeeperCollision":
		return &"keeper_contact"
	if body_name.begins_with("WallDummy"):
		return &"wall_contact"
	return &"goal_frame_contact"

func _finish_shot(outcome: StringName) -> void:
	# Ignore stale rest signals from a previous shot after the user restarted the loop.
	if _shot_finished or controller.state_machine.current_state != self or controller.run_id != _run_id:
		return
	_shot_finished = true
	if controller.shot_observer != null:
		controller.shot_observer.record_sample_now()
		controller.shot_observer.stop_recording(outcome)
	finished.emit(&"FeedbackState")
