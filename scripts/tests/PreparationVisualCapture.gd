extends SceneTree

## Captures the real sandbox without modifying the player's progression file.
func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var directory := "res://build/preparation_delivery/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var sandbox := load("res://scenes/sandbox/FreeKickSandbox.tscn").instantiate() as Node3D
	sandbox.progress_path = "res://build/preparation_capture_progress.cfg"
	root.add_child(sandbox)
	# Keep unrelated desktop pointer events out of this deterministic capture.
	sandbox.controller.state_machine.current_state.set_process_input(false)
	await create_timer(3.0).timeout
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(ProjectSettings.globalize_path(directory + "preparation.png"))
	assert(error == OK)
	print("Preparation capture: renderer=", RenderingServer.get_current_rendering_method(), "; FPS sample=", Engine.get_frames_per_second(), "; draw calls=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	root.size = Vector2i(1560, 720)
	await process_frame
	sandbox.controller.ui._update_uiroot_margins()
	sandbox.controller.start_free_kick("left")
	sandbox.controller.state_machine.current_state.set_process_input(false)
	sandbox.controller.camera_rig.start_runup_tracking()
	await create_timer(0.7).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(directory + "preparation_wide_left.png"))
	root.size = Vector2i(1280, 720)
	await process_frame
	sandbox.controller.ui._update_uiroot_margins()
	# A second real camera view makes geometry and texture integration reviewable.
	var runup := sandbox.controller.state_machine.current_state as RunUpState
	runup._begin_gesture(0, Vector2(640, 510))
	runup._drag_to(Vector2(550, 600))
	await create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(directory + "runup_preview.png"))
	runup._end_gesture()
	sandbox.controller.state_machine.transition_to(&"SupportFootState")
	sandbox.controller.state_machine.current_state.set_process(false)
	await create_timer(0.7).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(directory + "support_geometry.png"))
	# Debug overview: prove clearance at all four pitch corners in the imported mesh.
	var audit_camera := Camera3D.new()
	sandbox.add_child(audit_camera)
	audit_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	audit_camera.size = 146.0
	audit_camera.position = Vector3(0, 120, 0.1)
	audit_camera.look_at(Vector3.ZERO)
	audit_camera.current = true
	sandbox.controller.ui.hide()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(directory + "stadium_clearance.png"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(sandbox.progress_path))
	quit()
