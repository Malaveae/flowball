class_name SupportFootState
extends FreeKickState

enum Substep { LOCATION, ANGLE }

var elapsed := 0.0
var touch_elapsed := 0.0
var touching := false
var marker_local := Vector2.ZERO
var foot_angle := 0.0
var aim_target := 0.0
var radius := 160.0
var has_marker := false
var substep: Substep = Substep.LOCATION

func enter(_controller: FreeKickController) -> void:
	super.enter(_controller)
	elapsed = 0.0
	touch_elapsed = 0.0
	touching = false
	has_marker = false
	substep = Substep.LOCATION
	foot_angle = 0.0
	aim_target = 0.0
	controller.camera_rig.set_mode(&"SUPPORT_TOP_DOWN")
	controller.ui.show_support_foot_sector(controller.input_data.selected_foot, controller.difficulty)
	controller.ui.update_support_marker(Vector2(-radius * 0.55 if controller.input_data.selected_foot == "right" else radius * 0.55, 0.0))

func _process(delta: float) -> void:
	elapsed += delta
	var step_text := "1/2 LOCATION — release to lock" if substep == Substep.LOCATION else "2/2 FOOT ANGLE — release to continue"
	controller.ui.set_status("State: PLANT %s · %.1fs" % [step_text, maxf(0.0, controller.difficulty.step2_time_limit - elapsed)])
	_align_world_marker()
	if touching:
		touch_elapsed += delta
	elif elapsed >= controller.difficulty.step2_time_limit:
		_commit(true)

func _input(event: InputEvent) -> void:
	var pos: Vector2
	var should_update := false
	var released := false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pos = event.position
		if event.pressed:
			touching = true
			touch_elapsed = 0.0
			should_update = true
		else:
			released = true
	elif event is InputEventMouseMotion and touching:
		pos = event.position
		should_update = true
	elif event is InputEventScreenTouch:
		pos = event.position
		if event.pressed:
			touching = true
			touch_elapsed = 0.0
			should_update = true
		else:
			released = true
	elif event is InputEventScreenDrag:
		pos = event.position
		should_update = true

	if should_update:
		_update_from_screen(pos)
		get_viewport().set_input_as_handled()
	elif released:
		touching = false
		if substep == Substep.LOCATION and has_marker:
			substep = Substep.ANGLE
			controller.ui.update_support_foot_angle(foot_angle, aim_target)
		elif substep == Substep.ANGLE and has_marker:
			_commit(false)
		get_viewport().set_input_as_handled()

func _update_from_screen(pos: Vector2) -> void:
	var local := _screen_to_ball_local(pos)
	if substep == Substep.LOCATION:
		var target_marker := FreeKickInputMapper.clamp_to_support_foot_side(local, radius, controller.input_data.selected_foot)
		marker_local = target_marker if not has_marker else marker_local.lerp(target_marker, 0.45)
		has_marker = true
		foot_angle = marker_local.angle() if marker_local.length() > 0.001 else 0.0
		controller.ui.update_support_marker(marker_local)
	else:
		# Substep 2 is a stable left/right aim slider, not a free rotation around the plant foot.
		# This avoids twitchy angle jumps when the finger is close to the planted marker.
		# Drag left = left post, center = center, drag right = right post.
		var aim_width := radius * 0.75
		var horizontal_offset := 0.0 if aim_width <= 0.0 else (local.x - marker_local.x) / aim_width
		aim_target = clampf(horizontal_offset, -1.0, 1.0)
		var max_offset := deg_to_rad(30.0)
		var clamped_offset := aim_target * max_offset
		foot_angle = Vector2.UP.rotated(clamped_offset).angle()
		controller.ui.update_support_foot_angle(foot_angle, aim_target)

func _align_world_marker() -> void:
	var ball := controller.get_ball()
	var camera := controller.camera_rig.get_camera()
	if ball == null or camera == null:
		return
	var world_offset := Vector2.ZERO
	if has_marker:
		world_offset = marker_local / radius
	controller.ui.align_support_marker_hint(ball, camera, controller.input_data.selected_foot, world_offset)

func _screen_to_ball_local(screen_pos: Vector2) -> Vector2:
	var ball := controller.get_ball()
	var camera := controller.camera_rig.get_camera()
	if ball == null or camera == null:
		return Vector2.ZERO
	var center := camera.unproject_position(ball.global_position)
	var camera_right := camera.global_transform.basis.x.normalized()
	var camera_forward := -camera.global_transform.basis.z.normalized()
	var right_edge := camera.unproject_position(ball.global_position + camera_right * 0.75)
	var forward_edge := camera.unproject_position(ball.global_position + camera_forward.slide(Vector3.UP).normalized() * 0.75)
	var px_per_meter := maxf(1.0, maxf(absf(right_edge.x - center.x), absf(forward_edge.y - center.y)))
	var pixels := screen_pos - center
	var meters := pixels / px_per_meter
	return meters * radius

func _commit(use_default: bool) -> void:
	if use_default or not has_marker:
		controller.input_data.support_vector = Vector2.ZERO
		controller.input_data.plant_depth = 0.0
		controller.input_data.support_foot_angle = 0.0
		controller.input_data.support_aim_target = 0.0
		controller.input_data.used_default_support = true
		controller.input_data.support_timer_expired = use_default
	else:
		var support := FreeKickInputMapper.support_vector_from_marker(marker_local, radius)
		controller.input_data.support_touch_pos = marker_local
		controller.input_data.support_vector = support
		controller.input_data.plant_depth = clampf(support.y, -1.0, 1.0)
		controller.input_data.support_foot_angle = foot_angle
		controller.input_data.support_aim_target = aim_target
	finished.emit(&"BallContactState")
