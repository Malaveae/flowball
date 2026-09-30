extends SceneTree

var failures := 0
const SAVE := "res://build/arcade_flow_test.cfg"

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene := load("res://scenes/sandbox/FreeKickSandbox.tscn") as PackedScene
	var sandbox := scene.instantiate()
	sandbox.progress_path = SAVE
	root.add_child(sandbox)
	await process_frame
	var controller: FreeKickController = sandbox.controller
	var position: Vector3 = controller.free_kick_position
	var wind: Vector3 = controller.environment.wind_vector
	var foot: String = controller.input_data.selected_foot
	for i in range(3):
		controller.state_machine.transition_to(&"FeedbackState")
		check(controller.ui.feedback_snapshots_overlay.visible, "Feedback is visible on every miss")
		check(controller.ui.result_actions.visible, "Result actions are visible")
		if i < 2:
			sandbox.handle_result_action(&"primary")
	check(sandbox.game_over and sandbox.total_attempts == 3, "Three attempts exhaust the scenario")
	check(controller.ui.result_actions.get_child(0).text == "Restart", "Third miss offers Restart")
	var run_before := controller.run_id
	await create_timer(4.3).timeout
	check(controller.run_id == run_before, "Feedback never restarts automatically")
	sandbox.handle_result_action(&"primary")
	check(not sandbox.game_over and sandbox.current_spot_misses == 0, "Restart grants three fresh attempts")
	check(sandbox.total_attempts == 3, "Restart retains statistics")
	check(controller.free_kick_position == position and controller.environment.wind_vector == wind and controller.input_data.selected_foot == foot, "Restart preserves scenario and foot")
	controller.calculate_shot()
	controller.state_machine.transition_to(&"ExecuteShotState")
	sandbox._on_goal_scored()
	controller.state_machine.transition_to(&"FeedbackState")
	sandbox._on_free_kick_finished(null)
	check(sandbox.total_goals == 1 and sandbox.total_attempts == 4, "Goal and finish signals count once")
	run_before = controller.run_id
	await create_timer(1.5).timeout
	check(controller.run_id == run_before and sandbox.set_piece_number == 1, "Goal waits for manual advance")
	sandbox.handle_result_action(&"choose")
	check(controller.ui.is_selector_open(), "Selector opens from result")
	sandbox.select_unlocked_shot(3)
	check(sandbox.set_piece_number == 1, "Locked level cannot be selected")
	sandbox.select_unlocked_shot(2)
	check(sandbox.set_piece_number == 2 and not controller.ui.is_selector_open(), "Unlocked selection starts the selected scenario")
	check(not controller.ui.result_card.visible, "Old result disappears when a new attempt begins")
	# An actual timed sequence must still move through plant/contact into execution.
	controller.state_machine.transition_to(&"PowerState")
	controller.input_data.power_normalized = 0.76
	controller.set_power_time_budget(0.76)
	controller.state_machine.transition_to(&"SupportFootState")
	check(controller.ui.phase_clock.phase == 2 and controller.ui.phase_clock.visible, "Plant displays its separate clock")
	await create_timer(controller.effective_step_time_limit(2) + 0.1).timeout
	check(controller.state_machine.current_state is BallContactState, "Plant timeout still advances to contact")
	check(controller.ui.phase_clock.phase == 3 and controller.ui.phase_clock.visible, "Contact displays its separate clock")
	await create_timer(controller.effective_step_time_limit(3) + 0.1).timeout
	check(controller.state_machine.current_state is ExecuteShotState, "Contact timeout still executes the shot")
	# End the test flight through the normal state boundary, avoiding a long physics wait.
	(controller.state_machine.current_state as ExecuteShotState)._finish_shot(&"timeout")
	sandbox.progress.unlocked.append(FreeKickProgress.shot_id(FreeKickProgress.CATALOG_SIZE))
	sandbox.select_unlocked_shot(FreeKickProgress.CATALOG_SIZE)
	controller.calculate_shot()
	controller.state_machine.transition_to(&"ExecuteShotState")
	sandbox._on_goal_scored()
	controller.state_machine.transition_to(&"FeedbackState")
	check(controller.ui.result_actions.get_child_count() == 2 and controller.ui.result_actions.get_child(0).text == "Repetir tiro", "Final scenario offers repeat and selection, not a missing next scenario")
	root.remove_child(sandbox)
	sandbox.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	print("ArcadeFlowSmokeTest: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(failures)

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
