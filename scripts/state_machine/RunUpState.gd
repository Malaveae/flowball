class_name RunUpState
extends FreeKickState

## Step 1 substep A: run-up angle + distance, chosen by a tap-drag-release gesture over
## the normal shot-context view (POWER_VIEW) - the player needs to see the situation
## (goal, wall, distance) while placing the run-up, not an abstract top-down screen.
##
## Press anchors the gesture; which side of the ball's on-screen position the anchor
## lands on locks the kicking foot for this attempt (a fresh press elsewhere re-locks it,
## canceling any earlier placement) - physical, like the support-foot placement: a
## right-footed kick must approach from behind-left of the ball (a clock arc from 6
## o'clock/straight-behind to 9 o'clock/lateral-left); a left-footed kick mirrors it
## (3 o'clock to 6 o'clock, behind-right). Dragging into the other foot's arc doesn't
## switch foot, it clamps to the nearest edge of the locked arc.
##
## The angle within the arc is pure technique (power vs curl ceiling, see ShotCalculator) -
## it never steers the shot. Drag magnitude sets the run-up distance in meters.
##
## Opt-in: a drag that never leaves ENGAGEMENT_DEADZONE_M means the player skipped the
## mechanic - no power bonus/risk and no straight/curl ceiling, same as if it didn't exist.
## Untimed by design: the player takes as long as they want to place the run-up.

var has_marker := false
var anchor_screen := Vector2.ZERO
var marker_screen := Vector2.ZERO
var runup_angle_deg := 0.0
var runup_distance_m := 0.0
var locked_foot := "right"
var _gesture_active := false
var _gesture_index := -1
var _mouse_captured := false

## Screen-space drag magnitude that maps to a full run-up distance (ShotCalculator.RUNUP_DISTANCE_MAX_M).
const MAX_DRAG_PX := 220.0

## Below this run-up distance (meters), treat the gesture as an unengaged tap.
const ENGAGEMENT_DEADZONE_M := 0.4

## Clock arcs (degrees clockwise from 12/straight-toward-goal) each foot may drag into.
const RIGHT_FOOT_ARC := Vector2(180.0, 270.0) # 6 o'clock (behind) .. 9 o'clock (lateral-left)
const LEFT_FOOT_ARC := Vector2(90.0, 180.0)   # 3 o'clock (lateral-right) .. 6 o'clock (behind)

func enter(_controller: FreeKickController) -> void:
	super.enter(_controller)
	has_marker = false
	anchor_screen = Vector2.ZERO
	marker_screen = Vector2.ZERO
	runup_angle_deg = 0.0
	runup_distance_m = 0.0
	locked_foot = "right"
	_gesture_active = false
	_gesture_index = -1
	_mouse_captured = false
	controller.camera_rig.set_mode(&"POWER_VIEW")
	controller.camera_rig.start_runup_tracking()
	controller.ui.show_runup_ready()
	var ball := controller.get_ball()
	controller.runup_ground_marker.show_ready(ball.global_position if ball != null else Vector3.ZERO, controller.camera_rig.goal_position)

func exit() -> void:
	super.exit()
	if _mouse_captured:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		_mouse_captured = false
	controller.runup_ground_marker.hide_marker()

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
			_begin_gesture(0, event.position, true)
		elif _gesture_active:
			_end_gesture()
	elif event is InputEventMouseMotion and _gesture_active:
		if _mouse_captured:
			_drag_by(event.relative)
		else:
			_drag_to(event.position)

## Press: anchor the gesture. Which side of the ball's screen position the anchor lands
## on locks the kicking foot (a fresh press elsewhere re-locks it, canceling the earlier one).
## Mouse presses capture the cursor so the drag is measured in unbounded relative motion
## instead of absolute screen position - otherwise some angles (e.g. a diagonal drag toward
## the bottom of the window, under POWER_VIEW's low ball framing) could hit the screen edge
## before reaching the full MAX_DRAG_PX, capping distance below max at those angles.
func _begin_gesture(index: int, screen_pos: Vector2, is_mouse: bool = false) -> void:
	_gesture_index = index
	_gesture_active = true
	has_marker = true
	anchor_screen = screen_pos
	marker_screen = screen_pos
	locked_foot = "right" if screen_pos.x < _ball_screen_x() else "left"
	controller.input_data.selected_foot = locked_foot
	controller.ui.set_kicking_foot(locked_foot)
	_mouse_captured = is_mouse
	if is_mouse:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_update_from_drag()
	get_viewport().set_input_as_handled()

func _drag_to(screen_pos: Vector2) -> void:
	if not has_marker:
		return
	marker_screen = screen_pos
	_update_from_drag()
	get_viewport().set_input_as_handled()

func _drag_by(relative: Vector2) -> void:
	if not has_marker:
		return
	marker_screen += relative
	_update_from_drag()
	get_viewport().set_input_as_handled()

## Drag direction (deviation from straight down, away from the anchor) sets the approach
## angle within the locked foot's arc; drag magnitude sets the run-up distance.
func _update_from_drag() -> void:
	var drag := marker_screen - anchor_screen
	var clock_theta := 180.0 if drag.length() < 0.001 else wrapf(rad_to_deg(drag.angle()) + 90.0, 0.0, 360.0)
	var arc := RIGHT_FOOT_ARC if locked_foot == "right" else LEFT_FOOT_ARC
	var clamped_theta := clampf(clock_theta, arc.x, arc.y)
	# Both arcs read "behind (6 o'clock) = straight-on/90deg, lateral edge = 0deg" - only
	# which lateral edge (9 vs 3 o'clock) differs per foot.
	if locked_foot == "right":
		runup_angle_deg = clampf(RIGHT_FOOT_ARC.y - clamped_theta, 0.0, ShotCalculator.RUNUP_ANGLE_MAX_DEG)
	else:
		runup_angle_deg = clampf(clamped_theta - LEFT_FOOT_ARC.x, 0.0, ShotCalculator.RUNUP_ANGLE_MAX_DEG)
	var distance_t := clampf(drag.length() / MAX_DRAG_PX, 0.0, 1.0)
	runup_distance_m = distance_t * ShotCalculator.RUNUP_DISTANCE_MAX_M
	controller.ui.update_runup_gesture(runup_angle_deg, runup_distance_m, locked_foot, anchor_screen, marker_screen, arc)
	controller.camera_rig.set_runup_distance(runup_distance_m)
	var ball := controller.get_ball()
	if ball != null:
		controller.runup_ground_marker.update_gesture(runup_angle_deg, runup_distance_m, locked_foot, ball.global_position, controller.camera_rig.goal_position)

func _ball_screen_x() -> float:
	var ball := controller.get_ball()
	var camera := controller.camera_rig.get_camera()
	if ball == null or camera == null:
		return get_viewport().get_visible_rect().size.x * 0.5
	return camera.unproject_position(ball.global_position).x

## Release: commit immediately (neutral/unengaged if the drag never left the deadzone).
func _end_gesture() -> void:
	_gesture_active = false
	_gesture_index = -1
	if _mouse_captured:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		_mouse_captured = false
	_commit(runup_distance_m < ENGAGEMENT_DEADZONE_M)

func _commit(use_default: bool) -> void:
	if use_default or not has_marker:
		controller.input_data.runup_angle_deg = 0.0
		controller.input_data.runup_distance_m = 0.0
		controller.input_data.used_default_runup = true
		# Keep whatever foot the anchor locked (even a tiny tap still indicates a side);
		# only the angle/distance mechanic itself is skipped.
		controller.input_data.selected_foot = locked_foot
	else:
		controller.input_data.runup_angle_deg = runup_angle_deg
		controller.input_data.runup_distance_m = runup_distance_m
		controller.input_data.selected_foot = locked_foot
		controller.input_data.used_default_runup = false
	controller.runup_ground_marker.hide_marker()
	finished.emit(&"PowerState")
