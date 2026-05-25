class_name PowerState
extends FreeKickState

var charging := false
var hold_time := 0.0

func enter(_controller: FreeKickController) -> void:
	super.enter(_controller)
	charging = false
	hold_time = 0.0
	controller.camera_rig.set_mode(&"POWER_VIEW")
	controller.ui.show_power(0.0)

func _process(delta: float) -> void:
	if charging:
		hold_time += delta
		controller.input_data.hold_time = hold_time
		controller.input_data.power_normalized = ShotCalculator.power_from_hold(hold_time)
		controller.ui.show_power(controller.input_data.power_normalized)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("free_kick_power") or _is_primary_touch_press(event):
		charging = true
		get_viewport().set_input_as_handled()
	elif charging and (event.is_action_released("free_kick_power") or _is_primary_touch_release(event)):
		charging = false
		controller.input_data.hold_time = hold_time
		controller.input_data.power_normalized = ShotCalculator.power_from_hold(hold_time)
		finished.emit(&"SupportFootState")
		get_viewport().set_input_as_handled()

func _is_primary_touch_press(event: InputEvent) -> bool:
	return event is InputEventScreenTouch and event.pressed

func _is_primary_touch_release(event: InputEvent) -> bool:
	return event is InputEventScreenTouch and not event.pressed
