class_name FreeKickState
extends Node

signal finished(next_state: StringName)

var controller: FreeKickController

func _ready() -> void:
	set_process(false)
	set_process_input(false)

func enter(_controller: FreeKickController) -> void:
	controller = _controller
	set_process(true)
	set_process_input(true)

func exit() -> void:
	set_process(false)
	set_process_input(false)

func cancel_to_default() -> void:
	pass
