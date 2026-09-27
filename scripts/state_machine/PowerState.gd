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
		controller.input_data.power_normalized = ShotCalculator.power_from_hold(hold_time, controller.stats, controller.input_data.runup_distance_m, controller.difficulty, controller.input_data.runup_angle_deg, not controller.input_data.used_default_runup)
		controller.ui.show_power(controller.input_data.power_normalized)

func _input(event: InputEvent) -> void:
	if _is_power_press(event):
		charging = true
		controller.ui.show_power(controller.input_data.power_normalized)
		get_viewport().set_input_as_handled()
	elif charging and _is_power_release(event):
		charging = false
		controller.input_data.hold_time = hold_time
		controller.input_data.power_normalized = ShotCalculator.power_from_hold(hold_time, controller.stats, controller.input_data.runup_distance_m, controller.difficulty, controller.input_data.runup_angle_deg, not controller.input_data.used_default_runup)
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

