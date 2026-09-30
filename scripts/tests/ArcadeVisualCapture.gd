extends SceneTree

## Deterministic screenshots of the actual scene; does not touch player saves.
const DIRECTORY := "res://build/tv_arcade_captures/"
var sandbox: Node3D
var controller: FreeKickController

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIRECTORY))
	var scene := load("res://scenes/sandbox/FreeKickSandbox.tscn") as PackedScene
	sandbox = scene.instantiate()
	sandbox.progress_path = "res://build/visual_capture_progress.cfg"
	root.add_child(sandbox)
	controller = sandbox.controller
	# Live desktop pointer events must not change the scripted run-up foot.
	controller.state_machine.current_state.set_process_input(false)
	await create_timer(1.2).timeout
	await snapshot("01_preparation")
	var runup := controller.state_machine.current_state as RunUpState
	runup._begin_gesture(0, Vector2(650, 550))
	runup._drag_to(Vector2(535, 660))
	await create_timer(0.8).timeout
	await snapshot("02_runup")
	runup._end_gesture()
	controller.state_machine.current_state.set_process(false)
	controller.input_data.power_normalized = 0.76
	controller.ui.show_power(0.76)
	await create_timer(0.5).timeout
	await snapshot("03_power")
	controller.state_machine.transition_to(&"SupportFootState")
	controller.state_machine.current_state.set_process(false)
	await create_timer(0.6).timeout
	var plant := controller.state_machine.current_state as SupportFootState
	plant._align_world_marker()
	controller.ui.update_support_marker(Vector2(-60, 0))
	controller.ui.update_support_foot_angle(0.15, 0.28)
	controller.ui.set_phase_time(1.2, 2.0)
	controller.input_data.support_vector = Vector2(-0.55, 0.1)
	controller.input_data.support_foot_angle = 0.15
	controller.input_data.used_default_support = false
	await snapshot("04_support")
	controller.state_machine.transition_to(&"BallContactState")
	controller.state_machine.current_state.set_process(false)
	await create_timer(0.6).timeout
	controller.ui.align_ball_contact_overlay(controller.get_ball(), controller.camera_rig.get_camera())
	controller.ui.set_phase_time(0.9, 1.5)
	controller.input_data.impact_point = Vector2(-0.18, 0.2)
	controller.input_data.swipe_points = PackedVector2Array([Vector2(-0.18, 0.2), Vector2(0.1, -0.1), Vector2(0.45, -0.2)])
	controller.ui.ball_panel.set_swipe_points(PackedVector2Array([Vector2(-25, 30), Vector2(10, -10), Vector2(60, -26)]))
	await snapshot("05_contact")
	controller.calculate_shot()
	controller.shot_observer.shot_params = controller.shot_params
	controller.state_machine.transition_to(&"FeedbackState")
	await create_timer(0.6).timeout
	await snapshot("06_feedback")
	sandbox.handle_result_action(&"primary")
	controller.state_machine.transition_to(&"FeedbackState")
	sandbox.handle_result_action(&"primary")
	controller.state_machine.transition_to(&"FeedbackState")
	await snapshot("07_restart")
	sandbox.handle_result_action(&"choose")
	await snapshot("08_selector")
	sandbox.select_unlocked_shot(1)
	controller.start_free_kick("left")
	controller.state_machine.transition_to(&"PowerState")
	controller.state_machine.current_state.set_process(false)
	controller.ui.show_power(0.76)
	await create_timer(0.5).timeout
	await snapshot("09_power_left")
	controller.state_machine.transition_to(&"SupportFootState")
	controller.state_machine.current_state.set_process(false)
	await create_timer(0.5).timeout
	(controller.state_machine.current_state as SupportFootState)._align_world_marker()
	controller.ui.update_support_marker(Vector2(60, 0))
	controller.ui.update_support_foot_angle(-0.15, -0.28)
	controller.ui.set_phase_time(0.3, 2.0)
	await snapshot("10_support_left_warning")
	controller.calculate_shot()
	controller.shot_observer.shot_params = controller.shot_params
	controller.state_machine.transition_to(&"FeedbackState")
	for resolution in [Vector2i(1560, 720), Vector2i(1024, 768)]:
		root.size = resolution
		await process_frame
		controller.ui._update_uiroot_margins()
		await snapshot("11_feedback_%dx%d" % [resolution.x, resolution.y])
	# Include a wall scenario without altering the real unlock file.
	sandbox.progress.unlocked.append(FreeKickProgress.shot_id(10))
	sandbox.select_unlocked_shot(10)
	root.size = Vector2i(1280, 720)
	await create_timer(0.8).timeout
	await snapshot("12_wall")
	var keeper := sandbox.get_node("Goalkeeper") as GoalkeeperController
	assert(keeper.skeleton != null)
	assert(keeper.animation_player.get_animation(&"gk_ready").get_track_count() > 0)
	print("Animation: ", keeper.animation_player.current_animation, "; tracks=", keeper.animation_player.get_animation(&"gk_ready").get_track_count())
	print("Desktop sample: FPS=", Engine.get_frames_per_second(), "; draw calls=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(sandbox.progress_path))
	print("ArcadeVisualCapture: complete; renderer=", RenderingServer.get_current_rendering_method())
	quit()

func snapshot(filename: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(ProjectSettings.globalize_path(DIRECTORY + filename + ".png"))
	assert(error == OK)
