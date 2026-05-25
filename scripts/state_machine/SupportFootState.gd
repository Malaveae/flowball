class_name SupportFootState
extends FreeKickState

var elapsed := 0.0
var touch_elapsed := 0.0
var touching := false
var marker_local := Vector2.ZERO
var radius := 160.0
var has_marker := false

func enter(_controller: FreeKickController) -> void:
	super.enter(_controller)
	elapsed = 0.0
	touch_elapsed = 0.0
	touching = false
	has_marker = false
	controller.camera_rig.set_mode(&"SUPPORT_TOP_DOWN")
	controller.ui.show_support_foot_sector(controller.input_data.selected_foot, controller.difficulty)

func _process(delta: float) -> void:
	elapsed += delta
	controller.ui.set_status("State: PLANT · %.1fs" % maxf(0.0, controller.difficulty.step2_time_limit - elapsed))
	if touching:
		touch_elapsed += delta
	elif elapsed >= controller.difficulty.step2_time_limit:
		_commit(true)

func _input(event: InputEvent) -> void:
	var pos: Vector2
	var should_update_marker := false
	var released := false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pos = event.position
		if event.pressed:
			touching = true
			touch_elapsed = 0.0
			should_update_marker = true
		else:
			released = true
	elif event is InputEventMouseMotion and touching:
		pos = event.position
		should_update_marker = true
	elif event is InputEventScreenTouch:
		pos = event.position
		if event.pressed:
			touching = true
			touch_elapsed = 0.0
			should_update_marker = true
		else:
			released = true
	elif event is InputEventScreenDrag:
		pos = event.position
		should_update_marker = true

	if should_update_marker:
		var support_control := controller.ui.get_support_control()
		var local := FreeKickInputMapper.screen_to_control_local(pos, support_control)
		marker_local = FreeKickInputMapper.clamp_to_goal_aim_lane(local, radius)
		has_marker = true
		controller.ui.update_support_marker(marker_local)
		get_viewport().set_input_as_handled()
	elif released:
		touching = false
		if has_marker:
			_commit(false)
		get_viewport().set_input_as_handled()

func _commit(use_default: bool) -> void:
	if use_default:
		controller.input_data.support_vector = Vector2.ZERO
		controller.input_data.plant_depth = 0.0
		controller.input_data.used_default_support = true
		controller.input_data.support_timer_expired = true
	else:
		var support := FreeKickInputMapper.support_vector_from_marker(marker_local, radius)
		controller.input_data.support_touch_pos = marker_local
		controller.input_data.support_vector = support
		controller.input_data.plant_depth = clampf(support.y, -1.0, 1.0)
	finished.emit(&"BallContactState")
