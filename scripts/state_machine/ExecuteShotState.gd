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
	if body_name == "GoalCollision":
		return _goal_frame_hit(body)
	return &"net"

func _goal_frame_hit(frame_body: Node) -> StringName:
	# The ball contacts GoalCollision as a whole; refine by checking the ball
	# position against the post/crossbar collision shapes (local-space test).
	var ball_pos := _launched_ball.global_position if _launched_ball != null else Vector3.ZERO
	var shape_grow := 0.16  # ball radius + small tolerance
	for child in frame_body.get_children():
		var shape := child as CollisionShape3D
		if shape == null or shape.disabled:
			continue
		if not _shape_contains_point(shape, ball_pos, shape_grow):
			continue
		var shape_name := String(child.name)
		if shape_name.begins_with("LeftPost") or shape_name.begins_with("RightPost"):
			return &"post"
		if shape_name.begins_with("Crossbar"):
			return &"crossbar"
	return &"net"

func _shape_contains_point(shape: CollisionShape3D, world_pos: Vector3, margin: float) -> bool:
	var local := shape.global_transform.affine_inverse() * world_pos
	var s := shape.shape
	if s is BoxShape3D:
		var half: Vector3 = (s as BoxShape3D).size * 0.5 + Vector3.ONE * margin
		return absf(local.x) <= half.x and absf(local.y) <= half.y and absf(local.z) <= half.z
	if s is SphereShape3D:
		return local.length() <= (s as SphereShape3D).radius + margin
	if s is CapsuleShape3D:
		var cap := s as CapsuleShape3D
		var spine_half := maxf(0.0, cap.height * 0.5 - cap.radius)
		var on_spine := Vector3(local.x, clampf(local.y, -spine_half, spine_half), local.z)
		return on_spine.distance_to(local) <= cap.radius + margin
	return false

func _finish_shot(outcome: StringName) -> void:
	# Ignore stale rest signals from a previous shot after the user restarted the loop.
	if _shot_finished or controller.state_machine.current_state != self or controller.run_id != _run_id:
		return
	_shot_finished = true
	_show_outcome_banner(outcome)
	if controller.shot_observer != null:
		controller.shot_observer.record_sample_now()
		controller.shot_observer.stop_recording(outcome)
	if _launched_ball != null and _launched_ball.trail_node != null:
		_launched_ball.trail_node.stop_and_fade()
	finished.emit(&"FeedbackState")

func _show_outcome_banner(outcome: StringName) -> void:
	# Pop the result banner at the moment the outcome is known (miss/save/frame).
	# Goals use their own banner from the sandbox goal trigger.
	if controller.ui == null:
		return
	_show_impact_for_outcome(outcome)
	match outcome:
		&"background_contact":
			controller.ui.show_result_banner("MISSED", "Wide of the goal - keep aim inside the posts", Color(1.0, 0.30, 0.22))
		&"keeper_contact":
			controller.ui.show_result_banner("BLOCKED", "Great save - try the other corner", Color(1.0, 0.68, 0.22))
		&"post":
			controller.ui.show_result_banner("IT HIT THE POST", "So close - aim a touch inside", Color(0.0, 0.85, 1.0))
		&"crossbar":
			controller.ui.show_result_banner("CROSSBAR", "So close - a little more dip", Color(0.92, 0.96, 1.0))

## Ring pulse at the ball's current position for non-goal outcomes (goals pulse from the sandbox).
func _show_impact_for_outcome(outcome: StringName) -> void:
	if controller.ui == null or _launched_ball == null:
		return
	var camera := controller.camera_rig.get_camera()
	if camera == null:
		return
	var pos := _launched_ball.global_position
	match outcome:
		&"keeper_contact":
			controller.ui.show_impact_pulse(pos, camera, "SAVED", Color(1.0, 0.68, 0.22))
		&"post":
			controller.ui.show_impact_pulse(pos, camera, "POST", Color(0.0, 0.85, 1.0))
		&"crossbar":
			controller.ui.show_impact_pulse(pos, camera, "CROSSBAR", Color(0.92, 0.96, 1.0))
		&"background_contact":
			controller.ui.show_impact_pulse(pos, camera, "WIDE", Color(1.0, 0.30, 0.22))
