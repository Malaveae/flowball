class_name BallContactState
extends FreeKickState

var elapsed := 0.0
var swipe_duration := 0.0
var touching := false
var ball_radius_px := 180.0
var swipe_cap_px := 180.0
var raw_points := PackedVector2Array()
var _transition_recorded := false

func enter(_controller: FreeKickController) -> void:
	super.enter(_controller)
	elapsed = 0.0
	swipe_duration = 0.0
	touching = false
	raw_points = PackedVector2Array()
	_transition_recorded = false
	# Power pressure: an over-powered strike leaves less room for follow-through,
	# so the drag trace shrinks and favors a straight/puntera or knuckleball.
	var curve_stat := 0.0
	if controller.stats != null:
		curve_stat = controller.stats.normalized(controller.stats.curve)
	swipe_cap_px = ball_radius_px * ContactGesture.l_max(controller.input_data.power_normalized, curve_stat, controller.difficulty)
	controller.camera_rig.set_mode(&"BALL_CONTACT_UI")
	controller.ui.show_ball_contact_ui()
	controller.ui.set_status("Step 3: point on ball, then drag follow-through")

func _process(delta: float) -> void:
	elapsed += delta
	controller.ui.align_ball_contact_overlay(controller.get_ball(), controller.camera_rig.get_camera())
	var time_limit := controller.effective_step_time_limit(3)
	var remaining := maxf(0.0, time_limit - elapsed)
	controller.ui.set_phase_progress(remaining / maxf(0.001, time_limit), "%.1fs" % remaining)
	controller.ui.set_status("CONTACT - point and drag - %.1fs" % remaining)
	if touching:
		swipe_duration += delta
	elif elapsed >= time_limit:
		_commit(true)

func _input(event: InputEvent) -> void:
	var pos: Vector2
	var should_add_point := false
	var released := false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pos = event.position
		if event.pressed:
			touching = true
			swipe_duration = 0.0
			raw_points = PackedVector2Array()
			should_add_point = true
		else:
			released = true
	elif event is InputEventMouseMotion and touching:
		pos = event.position
		should_add_point = true
	elif event is InputEventScreenTouch:
		pos = event.position
		if event.pressed:
			touching = true
			swipe_duration = 0.0
			raw_points = PackedVector2Array()
			should_add_point = true
		else:
			released = true
	elif event is InputEventScreenDrag:
		pos = event.position
		should_add_point = true

	if should_add_point:
		if not _transition_recorded and controller._step2_end_msec > 0:
			_transition_recorded = true
			controller.input_data.step2_to_step3_ms = Time.get_ticks_msec() - controller._step2_end_msec
		var ball_control := controller.ui.get_ball_contact_control()
		var local := FreeKickInputMapper.screen_to_control_local(pos, ball_control)
		if raw_points.is_empty():
			local = local.limit_length(ball_radius_px)
		else:
			local = local.limit_length(swipe_cap_px)
		raw_points.append(local)
		controller.ui.update_ball_contact(raw_points)
		get_viewport().set_input_as_handled()
	elif released:
		touching = false
		if raw_points.size() >= 1:
			_commit(false)
		get_viewport().set_input_as_handled()

func _commit(use_default: bool) -> void:
	if use_default:
		controller.input_data.impact_point = Vector2.ZERO
		controller.input_data.swipe_points = PackedVector2Array([Vector2.ZERO, Vector2(0.0, -0.1)])
		controller.input_data.swipe_duration = 0.0
		controller.input_data.used_default_contact = true
		controller.input_data.contact_timer_expired = true
	else:
		var normalized := FreeKickInputMapper.normalize_swipe_points(raw_points, ball_radius_px)
		controller.input_data.impact_point = normalized[0] if normalized.size() > 0 else Vector2.ZERO
		controller.input_data.swipe_points = normalized
		controller.input_data.swipe_duration = swipe_duration
	finished.emit(&"CalculateShotState")
