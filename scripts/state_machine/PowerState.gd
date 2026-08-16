class_name PowerState
extends FreeKickState

var charging := false
var hold_time := 0.0

func enter(_controller: FreeKickController) -> void:
	super.enter(_controller)
	charging = false
	hold_time = 0.0
	controller.input_data.hold_time = 0.0
	controller.input_data.power_normalized = 0.0
	controller.camera_rig.set_mode(&"POWER_VIEW")
	controller.ui.show_power_ready()

func _process(delta: float) -> void:
	controller.ui.align_power_meter_to_ball(controller.get_ball(), controller.camera_rig.get_camera())
	if charging:
		hold_time += delta
		controller.input_data.hold_time = hold_time
		controller.input_data.power_normalized = ShotCalculator.power_from_hold(hold_time, controller.stats)
		controller.ui.show_power(controller.input_data.power_normalized)

func _input(event: InputEvent) -> void:
	if _is_power_press(event):
		_select_foot_from_event(event)
		charging = true
		controller.ui.show_power(controller.input_data.power_normalized)
		get_viewport().set_input_as_handled()
	elif charging and _is_power_release(event):
		charging = false
		controller.input_data.hold_time = hold_time
		controller.input_data.power_normalized = ShotCalculator.power_from_hold(hold_time, controller.stats)
		controller.set_power_time_budget(controller.input_data.power_normalized)
		finished.emit(&"SupportFootState")
		get_viewport().set_input_as_handled()

func _is_power_press(event: InputEvent) -> bool:
	return event.is_action_pressed("free_kick_power") or _is_primary_touch_press(event) or _is_primary_mouse_press(event)

func _is_power_release(event: InputEvent) -> bool:
	return event.is_action_released("free_kick_power") or _is_primary_touch_release(event) or _is_primary_mouse_release(event)

func _is_primary_touch_press(event: InputEvent) -> bool:
	return event is InputEventScreenTouch and event.pressed

func _is_primary_touch_release(event: InputEvent) -> bool:
	return event is InputEventScreenTouch and not event.pressed

func _is_primary_mouse_press(event: InputEvent) -> bool:
	return event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed

func _is_primary_mouse_release(event: InputEvent) -> bool:
	return event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed

func _select_foot_from_event(event: InputEvent) -> void:
	var press_position := _event_position(event)
	if press_position == Vector2.INF:
		return
	var viewport_width := get_viewport().get_visible_rect().size.x
	var selected_foot := "left" if press_position.x < viewport_width * 0.5 else "right"
	controller.input_data.selected_foot = selected_foot
	controller.ui.set_kicking_foot(selected_foot)

func _event_position(event: InputEvent) -> Vector2:
	if event is InputEventScreenTouch:
		return event.position
	if event is InputEventMouseButton:
		return event.position
	return Vector2.INF
