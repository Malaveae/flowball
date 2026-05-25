class_name SupportFootState
extends FreeKickState

enum Substep { LOCATION, ANGLE }

var elapsed := 0.0
var touch_elapsed := 0.0
var touching := false
var marker_local := Vector2.ZERO
var foot_angle := 0.0
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
	controller.camera_rig.set_mode(&"SUPPORT_TOP_DOWN")
	controller.ui.show_support_foot_sector(controller.input_data.selected_foot, controller.difficulty)

func _process(delta: float) -> void:
	elapsed += delta
	var step_text := "1/2 LOCATION — release to lock" if substep == Substep.LOCATION else "2/2 FOOT ANGLE — release to continue"
	controller.ui.set_status("State: PLANT %s · %.1fs" % [step_text, maxf(0.0, controller.difficulty.step2_time_limit - elapsed)])
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
			controller.ui.update_support_foot_angle(foot_angle)
		elif substep == Substep.ANGLE and has_marker:
			_commit(false)
		get_viewport().set_input_as_handled()

func _update_from_screen(pos: Vector2) -> void:
	var support_control := controller.ui.get_support_control()
	var local := FreeKickInputMapper.screen_to_control_local(pos, support_control)
	if substep == Substep.LOCATION:
		marker_local = FreeKickInputMapper.clamp_to_support_foot_side(local, radius, controller.input_data.selected_foot)
		has_marker = true
		foot_angle = marker_local.angle() if marker_local.length() > 0.001 else 0.0
		controller.ui.update_support_marker(marker_local)
	else:
		var angle_vector := local - marker_local
		if angle_vector.length() > 4.0:
			foot_angle = angle_vector.angle()
		controller.ui.update_support_foot_angle(foot_angle)

func _commit(use_default: bool) -> void:
	if use_default or not has_marker:
		controller.input_data.support_vector = Vector2.ZERO
		controller.input_data.plant_depth = 0.0
		controller.input_data.support_foot_angle = 0.0
		controller.input_data.used_default_support = true
		controller.input_data.support_timer_expired = use_default
	else:
		var support := FreeKickInputMapper.support_vector_from_marker(marker_local, radius)
		controller.input_data.support_touch_pos = marker_local
		controller.input_data.support_vector = support
		controller.input_data.plant_depth = clampf(support.y, -1.0, 1.0)
		controller.input_data.support_foot_angle = foot_angle
	finished.emit(&"BallContactState")
