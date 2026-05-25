extends Node3D

@onready var controller: FreeKickController = $FreeKickController

func _ready() -> void:
	# Start immediately for prototype. In production, match controller would call this.
	controller.start_free_kick("right")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("free_kick_restart"):
		controller.start_free_kick(controller.input_data.selected_foot)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("free_kick_switch_foot"):
		controller._on_switch_foot_requested()
		get_viewport().set_input_as_handled()
