class_name ExecuteShotState
extends FreeKickState

@export var fallback_contact_delay: float = 0.25

var _run_id: int = -1
var _launched_ball: FreeKickBall3D

func enter(_controller: FreeKickController) -> void:
	super.enter(_controller)
	_run_id = controller.run_id
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
		ball.launch(controller.shot_params, controller.get_kicker())
		if not ball.came_to_rest.is_connected(_on_ball_done):
			ball.came_to_rest.connect(_on_ball_done, CONNECT_ONE_SHOT)
	else:
		_on_ball_done()

func exit() -> void:
	if _launched_ball != null and _launched_ball.came_to_rest.is_connected(_on_ball_done):
		_launched_ball.came_to_rest.disconnect(_on_ball_done)
	_launched_ball = null
	super.exit()

func _on_ball_done() -> void:
	# Ignore stale rest signals from a previous shot after the user restarted the loop.
	if controller.state_machine.current_state != self or controller.run_id != _run_id:
		return
	if controller.shot_observer != null:
		controller.shot_observer.stop_recording(&"landed")
	finished.emit(&"FeedbackState")
