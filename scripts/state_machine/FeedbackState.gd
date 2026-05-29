class_name FeedbackState
extends FreeKickState

const AUTO_RESTART_DELAY_SECONDS := 4.0

func enter(_controller: FreeKickController) -> void:
	super.enter(_controller)
	controller.camera_rig.set_mode(&"FEEDBACK_REPLAY")
	var report: Resource = null
	if controller.shot_observer != null:
		report = controller.shot_observer.build_report(controller.input_data)
		if controller.trajectory_ghost != null:
			controller.trajectory_ghost.show_telemetry(controller.shot_observer.telemetry)
	controller.ui.show_feedback(report, AUTO_RESTART_DELAY_SECONDS)
	controller.free_kick_finished.emit(report)
	_auto_restart_after_delay(controller.run_id)

func _auto_restart_after_delay(feedback_run_id: int) -> void:
	await get_tree().create_timer(AUTO_RESTART_DELAY_SECONDS).timeout
	if controller == null or controller.run_id != feedback_run_id:
		return
	controller.restart_attempt()
