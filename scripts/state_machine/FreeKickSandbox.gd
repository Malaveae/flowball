extends Node3D

@onready var controller: FreeKickController = $FreeKickController

var set_piece_spots := [
	{"label": "Center 24m", "position": Vector3(0.0, 0.16, 0.0)},
	{"label": "Left half-space 22m", "position": Vector3(-4.5, 0.16, -2.0)},
	{"label": "Right half-space 22m", "position": Vector3(4.5, 0.16, -2.0)},
	{"label": "Deep center 30m", "position": Vector3(0.0, 0.16, 6.0)},
	{"label": "Wide left 25m", "position": Vector3(-7.5, 0.16, 0.5)},
	{"label": "Wide right 25m", "position": Vector3(7.5, 0.16, 0.5)},
]
var spot_index := 0

func _ready() -> void:
	_apply_set_piece_spot()
	# Start immediately for prototype. In production, match controller would call this.
	controller.start_free_kick("right")

func cycle_set_piece_spot() -> void:
	spot_index = (spot_index + 1) % set_piece_spots.size()
	_apply_set_piece_spot()
	controller.start_free_kick(controller.input_data.selected_foot)

func _apply_set_piece_spot() -> void:
	var spot: Dictionary = set_piece_spots[spot_index]
	controller.set_free_kick_spot(String(spot["label"]), spot["position"])

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("free_kick_restart"):
		controller.start_free_kick(controller.input_data.selected_foot)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("free_kick_switch_foot"):
		controller._on_switch_foot_requested()
		get_viewport().set_input_as_handled()
