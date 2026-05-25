class_name CalculateShotState
extends FreeKickState

func enter(_controller: FreeKickController) -> void:
	super.enter(_controller)
	controller.calculate_shot()
	finished.emit(&"ExecuteShotState")
