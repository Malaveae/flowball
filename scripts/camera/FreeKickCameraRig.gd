class_name FreeKickCameraRig
extends Node3D

signal mode_changed(mode: StringName)

@export var camera_path: NodePath
@export var target_path: NodePath
@export var goal_position: Vector3 = Vector3(0.0, 1.2, -24.0)
@export var blend_time: float = 0.35
@export var match_view_transform := Transform3D(Basis(), Vector3(0.0, 7.0, 8.0))
@export var power_view_transform := Transform3D(Basis(), Vector3(0.0, 6.0, 7.0))
@export var support_view_transform := Transform3D(Basis(), Vector3(0.0, 9.0, 0.01))
# Step 3: tight first-person-ish ball view so the player touches/swipes over the ball in foreground.
@export var contact_view_transform := Transform3D(Basis(), Vector3(0.0, 0.42, 0.85))
# After contact, drop to a low chase angle to appreciate ball flight and curve.
@export var shot_follow_transform := Transform3D(Basis(), Vector3(0.0, 1.15, 6.5))
@export var feedback_transform := Transform3D(Basis(), Vector3(0.0, 2.2, 9.0))
@export var default_fov: float = 70.0
@export var contact_fov: float = 38.0
@export var shot_follow_fov: float = 55.0

var mode: StringName = &"MATCH_VIEW"
var _tween: Tween

func set_mode(next_mode: StringName) -> void:
	mode = next_mode
	var camera := get_camera()
	if camera != null:
		_apply_camera_transform(camera, _transform_for_mode(next_mode), _fov_for_mode(next_mode))
	mode_changed.emit(mode)

func get_camera() -> Camera3D:
	return get_node_or_null(camera_path) as Camera3D

func _apply_camera_transform(camera: Camera3D, target: Transform3D, target_fov: float) -> void:
	camera.current = true
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(camera, "global_transform", target, blend_time)
	_tween.tween_property(camera, "fov", target_fov, blend_time)

func _transform_for_mode(next_mode: StringName) -> Transform3D:
	if next_mode == &"BALL_CONTACT_UI":
		return _ball_contact_transform()
	if next_mode == &"SUPPORT_TOP_DOWN":
		return _support_top_down_transform()
	return _goal_centered_transform(next_mode)

func _goal_centered_transform(next_mode: StringName) -> Transform3D:
	var ball := _target_position()
	var goal := goal_position
	var to_goal := (goal - ball).slide(Vector3.UP)
	if to_goal.length() < 0.01:
		to_goal = Vector3.FORWARD
	var dir := to_goal.normalized()
	var right := dir.cross(Vector3.UP).normalized()
	var distance := ball.distance_to(goal)
	var height := 3.2
	var behind := clampf(distance * 0.38, 7.0, 13.0)
	var side := 0.0
	var look_height := 1.35
	var fov_bonus := 0.0

	match next_mode:
		&"POWER_VIEW":
			height = 4.6
			behind = clampf(distance * 0.42, 8.0, 15.0)
			look_height = 1.25
		&"SUPPORT_TOP_DOWN":
			height = 8.0
			behind = clampf(distance * 0.18, 4.0, 7.0)
			look_height = 1.0
			fov_bonus = 8.0
		&"SHOT_FOLLOW":
			height = 2.0
			behind = 6.5
			look_height = 1.2
		&"FEEDBACK_REPLAY":
			height = 3.0
			behind = clampf(distance * 0.34, 8.0, 13.0)
			look_height = 1.3
		_:
			height = 4.0
			behind = clampf(distance * 0.4, 8.0, 14.0)

	var origin := ball - dir * behind + right * side + Vector3.UP * height
	var target := goal.lerp(ball, 0.18) + Vector3.UP * look_height
	return Transform3D(Basis.looking_at((target - origin).normalized(), Vector3.UP), origin)

func _support_top_down_transform() -> Transform3D:
	# Step 2 uses the real ball from a zenith camera instead of a 2D overlay panel.
	var ball := _target_position()
	var origin := ball + Vector3.UP * 5.2
	return Transform3D(Basis.looking_at(Vector3.DOWN, Vector3.FORWARD), origin)

func _ball_contact_transform() -> Transform3D:
	# Contact mode intentionally centers the real foreground ball for touch input, not the goal.
	var ball := _target_position()
	var goal := goal_position
	var dir := (goal - ball).slide(Vector3.UP).normalized()
	if dir.length() < 0.01:
		dir = Vector3.FORWARD
	var origin := ball - dir * 0.85 + Vector3.UP * 0.42
	var target := ball + dir * 0.2 + Vector3.UP * 0.05
	return Transform3D(Basis.looking_at((target - origin).normalized(), Vector3.UP), origin)

func _fov_for_mode(next_mode: StringName) -> float:
	match next_mode:
		&"BALL_CONTACT_UI":
			return contact_fov
		&"SHOT_FOLLOW", &"FEEDBACK_REPLAY":
			return shot_follow_fov
		&"SUPPORT_TOP_DOWN":
			return 32.0
		_:
			return default_fov

func _target_position() -> Vector3:
	var target_node := get_node_or_null(target_path) as Node3D
	if target_node != null:
		return target_node.global_position
	return Vector3(0.0, 0.16, 0.0)
