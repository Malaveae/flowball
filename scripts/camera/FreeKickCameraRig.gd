class_name FreeKickCameraRig
extends Node3D

signal mode_changed(mode: StringName)

@export var camera_path: NodePath
@export var target_path: NodePath
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
	var t := match_view_transform
	match next_mode:
		&"POWER_VIEW":
			t = power_view_transform
		&"SUPPORT_TOP_DOWN":
			t = support_view_transform
		&"BALL_CONTACT_UI":
			t = contact_view_transform
		&"SHOT_FOLLOW":
			t = shot_follow_transform
		&"FEEDBACK_REPLAY":
			t = feedback_transform
		_:
			t = match_view_transform
	return _looking_at_origin(t)

func _fov_for_mode(next_mode: StringName) -> float:
	match next_mode:
		&"BALL_CONTACT_UI":
			return contact_fov
		&"SHOT_FOLLOW", &"FEEDBACK_REPLAY":
			return shot_follow_fov
		_:
			return default_fov

func _looking_at_origin(transform: Transform3D) -> Transform3D:
	var origin := transform.origin
	var target := _target_position()
	if origin.distance_to(target) < 0.01:
		return transform
	return Transform3D(Basis.looking_at((target - origin).normalized(), Vector3.UP), origin)

func _target_position() -> Vector3:
	var target_node := get_node_or_null(target_path) as Node3D
	if target_node != null:
		return target_node.global_position
	return Vector3(0.0, 0.16, 0.0)
