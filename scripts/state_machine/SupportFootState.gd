class_name SupportFootState
extends FreeKickState

## Step 2: unified "plant & aim" gesture (touch and mouse share one code path).
## Press places the heel (clamped to the legal support-foot side); dragging
## without releasing points the toe radially toward the finger within +/-30
## degrees; releasing commits immediately. A tap without drag commits a neutral
## 0-degree aim. Timeout commits defaults, exactly like before.

var elapsed := 0.0
var touch_elapsed := 0.0
var touching := false
var marker_local := Vector2.ZERO
var foot_angle := 0.0
var aim_target := 0.0
var radius := 160.0
var has_marker := false
var _gesture_active := false
var _gesture_index := -1

## Mouse/touch drag sensitivity (lower = less sensitive). Tune to comfort.
const DRAG_SENSITIVITY := 0.3

func enter(_controller: FreeKickController) -> void:
	super.enter(_controller)
	elapsed = 0.0
	touch_elapsed = 0.0
	touching = false
	has_marker = false
	foot_angle = 0.0
	aim_target = 0.0
	_gesture_active = false
	_gesture_index = -1
	controller.camera_rig.set_mode(&"SUPPORT_TOP_DOWN")
	controller.ui.show_support_foot_sector(controller.input_data.selected_foot, controller.difficulty)
	controller.ui.update_support_marker(Vector2(-radius * 0.55 if controller.input_data.selected_foot == "right" else radius * 0.55, 0.0))

func _process(delta: float) -> void:
	elapsed += delta
	var time_limit := controller.effective_step_time_limit(2)
	# DEBUG
	if int(elapsed * 10) % 10 == 0:
		print("DEBUG Step2: elapsed=", elapsed, " time_limit=", time_limit)
	var remaining := maxf(0.0, time_limit - elapsed)
	controller.ui.set_phase_progress(remaining / maxf(0.001, time_limit), "%.1fs" % remaining)
	if has_marker:
		controller.ui.set_status("PLANT - slide to aim - release to shoot - %.1fs" % remaining)
	else:
		controller.ui.set_status("PLANT - tap to plant your heel - %.1fs" % remaining)
	_align_world_marker()
	if touching:
		touch_elapsed += delta
	# Timer always checks, even if mouse is held down
	if elapsed >= time_limit:
		print("DEBUG: Timer expired, calling _commit(true)")
		_commit(true)

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_begin_gesture(event.index, event.position)
		elif event.index == _gesture_index:
			_end_gesture()
	elif event is InputEventScreenDrag and _gesture_active and event.index == _gesture_index:
		_drag_to(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_gesture(0, event.position)
		elif _gesture_active:
			_end_gesture()
	elif event is InputEventMouseMotion and _gesture_active:
		_drag_to(event.position)

## Press: plant the heel at the touch point, clamped to the legal side.
func _begin_gesture(index: int, screen_pos: Vector2) -> void:
	_gesture_index = index
	_gesture_active = true
	touching = true
	touch_elapsed = 0.0
	var local := _screen_to_ball_local(screen_pos)
	var clamped := FreeKickInputMapper.clamp_to_support_foot_side(local, radius, controller.input_data.selected_foot)
	var corrected := clamped.distance_to(local) > 8.0
	marker_local = clamped
	has_marker = true
	foot_angle = 0.0
	aim_target = 0.0
	controller.ui.update_support_marker(marker_local)
	if corrected:
		controller.ui.flash_support_correction()
	get_viewport().set_input_as_handled()

## Drag while pressed: point the toe radially toward the finger.
func _drag_to(screen_pos: Vector2) -> void:
	if not has_marker:
		return
	var local := _screen_to_ball_local(screen_pos)
	# Reduce drag sensitivity to prevent over-sensitive aiming
	var delta := local - marker_local
	delta *= DRAG_SENSITIVITY
	local = marker_local + delta
	aim_target = SupportPlantGesture.aim_target_from_toe(marker_local, local)
	foot_angle = SupportPlantGesture.toe_direction(aim_target).angle()
	controller.ui.update_support_foot_angle(foot_angle, aim_target)
	get_viewport().set_input_as_handled()

## Release: commit the step immediately (neutral aim if the heel was never dragged).
func _end_gesture() -> void:
	_gesture_active = false
	_gesture_index = -1
	touching = false
	_commit(not has_marker)

func _align_world_marker() -> void:
	var ball := controller.get_ball()
	var camera := controller.camera_rig.get_camera()
	if ball == null or camera == null:
		return
	var world_offset := Vector2.ZERO
	if has_marker:
		world_offset = marker_local / radius
	controller.ui.align_support_marker_hint(ball, camera, controller.input_data.selected_foot, world_offset)

func _screen_to_ball_local(screen_pos: Vector2) -> Vector2:
	var ball := controller.get_ball()
	var camera := controller.camera_rig.get_camera()
	if ball == null or camera == null:
		return Vector2.ZERO
	var center := camera.unproject_position(ball.global_position)
	var camera_right := camera.global_transform.basis.x.normalized()
	var camera_forward := -camera.global_transform.basis.z.normalized()
	var right_edge := camera.unproject_position(ball.global_position + camera_right * 0.75)
	var forward_edge := camera.unproject_position(ball.global_position + camera_forward.slide(Vector3.UP).normalized() * 0.75)
	var px_per_meter := maxf(1.0, maxf(absf(right_edge.x - center.x), absf(forward_edge.y - center.y)))
	var pixels := screen_pos - center
	var meters := pixels / px_per_meter
	return meters * radius

func _commit(use_default: bool) -> void:
	print("DEBUG _commit: use_default=", use_default, " has_marker=", has_marker, " elapsed=", elapsed)
	if use_default or not has_marker:
		controller.input_data.support_vector = Vector2.ZERO
		controller.input_data.plant_depth = 0.0
		controller.input_data.support_foot_angle = 0.0
		controller.input_data.support_aim_target = 0.0
		controller.input_data.support_quality = 0.72
		controller.input_data.support_angle_quality = 0.85
		controller.input_data.used_default_support = true
		controller.input_data.support_timer_expired = use_default
	else:
		var support := FreeKickInputMapper.support_vector_from_marker(marker_local, radius)
		controller.input_data.support_touch_pos = marker_local
		controller.input_data.support_vector = support
		controller.input_data.plant_depth = clampf(support.y, -1.0, 1.0)
		controller.input_data.support_foot_angle = foot_angle
		controller.input_data.support_aim_target = aim_target
		controller.input_data.support_quality = _support_quality(support)
		controller.input_data.support_angle_quality = _support_angle_quality(aim_target)
	if not use_default:
		controller._step2_end_msec = Time.get_ticks_msec()
	print("DEBUG: Emitting finished signal to BallContactState")
	finished.emit(&"BallContactState")

func _support_quality(support: Vector2) -> float:
	# Hidden biomechanical anchor model from piedeapoyo.md.
	# Normalized UI distances map roughly to real plant distance bands:
	# 0.00-0.15 too close, 0.20-0.35 optimal, 0.40-0.55 risky, >0.55 strongly penalized.
	var lateral_distance := absf(support.x)
	var depth := support.y
	var lateral_quality: float
	if lateral_distance < 0.15:
		lateral_quality = lerpf(0.35, 0.72, lateral_distance / 0.15)
	elif lateral_distance <= 0.35:
		lateral_quality = 1.0
	elif lateral_distance <= 0.55:
		lateral_quality = lerpf(0.82, 0.52, (lateral_distance - 0.35) / 0.20)
	else:
		lateral_quality = lerpf(0.48, 0.20, clampf((lateral_distance - 0.55) / 0.45, 0.0, 1.0))
	# Slightly ahead/open is balanced for free kicks; too far ahead/behind hurts stability.
	var depth_quality := 1.0 - clampf(absf(depth + 0.10) / 0.75, 0.0, 1.0) * 0.35
	return clampf(lateral_quality * depth_quality, 0.18, 1.0)

func _support_angle_quality(target: float) -> float:
	# 0 = foot points at target for straight/power. 10-25 degrees open is still good for curl.
	# The radial gesture maps to about +/-30 degrees visually, so full extremes trade control for shape.
	var open_amount := absf(clampf(target, -1.0, 1.0))
	if open_amount <= 0.55:
		return 1.0
	return lerpf(0.86, 0.62, (open_amount - 0.55) / 0.45)

