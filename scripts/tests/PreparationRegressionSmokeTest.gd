extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error(description)

func run() -> void:
	var stadium := load("res://assets/models/preparation/stadium.glb").instantiate() as Node3D
	root.add_child(stadium)
	var minimum_clearance := INF
	for child in stadium.find_children("*", "MeshInstance3D", true, false):
		var instance := child as MeshInstance3D
		for surface in range(instance.mesh.get_surface_count()):
			var material := instance.mesh.surface_get_material(surface)
			if material.resource_name.begins_with("PrepTurf") or material.resource_name.begins_with("PrepApron"):
				continue
			var vertices: PackedVector3Array = instance.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for vertex in vertices:
				var point := instance.global_transform * vertex
				if point.y > 2.0:
					continue
				var outside := Vector2(maxf(absf(point.x) - 34.0, 0), maxf(absf(point.z) - 52.5, 0))
				minimum_clearance = minf(minimum_clearance, outside.length())
	check(is_finite(minimum_clearance) and minimum_clearance >= 4.0, "Imported stadium leaves at least 4 m around the entire rectangular pitch")
	print("Minimum imported low-geometry clearance: ", minimum_clearance, " m")
	stadium.free()
	var sandbox := load("res://scenes/sandbox/FreeKickSandbox.tscn").instantiate() as Node3D
	sandbox.progress_path = "res://build/preparation_regression.cfg"
	root.add_child(sandbox)
	await process_frame
	var controller: FreeKickController = sandbox.controller
	for drag in [Vector2(-110, 110), Vector2(110, 110)]:
		controller.start_free_kick()
		var runup := controller.state_machine.current_state as RunUpState
		check(controller.ui.feedback_label.visible, "Preparation exposes run-up guidance before power")
		runup._begin_gesture(0, Vector2(640, 520))
		runup._drag_to(Vector2(640, 520) + drag)
		check(controller.state_machine.current_state is RunUpState, "Dragging previews run-up without setting power")
		check(controller.ui.feedback_label.visible and controller.ui.feedback_label.text.contains("45°") and controller.ui.feedback_label.text.contains("10.6 m"), "Both feet display live angle and distance")
		check(not controller.ui.power_meter.visible, "Power stays hidden until run-up release")
		check(controller.runup_ground_marker.visible and controller.runup_ground_marker.ground_y > 0.084, "Ground marker clears the new visual grass")
		var angle_before := runup.runup_angle_deg
		var distance_before := runup.runup_distance_m
		runup._end_gesture()
		check(controller.state_machine.current_state is PowerState, "Release starts the existing power phase")
		check(is_equal_approx(controller.input_data.runup_angle_deg, angle_before) and is_equal_approx(controller.input_data.runup_distance_m, distance_before), "Displayed run-up is committed unchanged")
	root.remove_child(sandbox)
	sandbox.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("res://build/preparation_regression.cfg"))
	print("PreparationRegressionSmokeTest: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
