class_name FeedbackState
extends FreeKickState

func enter(_controller: FreeKickController) -> void:
	super.enter(_controller)
	controller.camera_rig.set_mode(&"FEEDBACK_REPLAY")
	var report: Resource = null
	if controller.shot_observer != null:
		report = controller.shot_observer.build_report(controller.input_data)
		if controller.trajectory_ghost != null:
			controller.trajectory_ghost.show_telemetry(controller.shot_observer.telemetry)
	controller.ui.show_feedback(report)
	controller.free_kick_finished.emit(report)
