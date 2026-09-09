class_name FreeKickStateMachine
extends Node

signal state_changed(state_name: StringName)

@export var initial_state: StringName = &"PowerState"

var controller: FreeKickController
var current_state: FreeKickState

func setup(owner_controller: FreeKickController) -> void:
	controller = owner_controller
	for child in get_children():
		var state := child as FreeKickState
		if state != null:
			state.finished.connect(_on_state_finished)

func start() -> void:
	transition_to(initial_state)

func transition_to(state_name: StringName) -> void:
	if current_state != null:
		current_state.exit()
	var next := get_node_or_null(NodePath(String(state_name))) as FreeKickState
	if next == null:
		push_error("Unknown free kick state: %s" % state_name)
		return
	current_state = next
	current_state.enter(controller)
	state_changed.emit(state_name)

func _on_state_finished(next_state: StringName) -> void:
	transition_to(next_state)
