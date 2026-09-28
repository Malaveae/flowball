class_name RunUpGroundMarker3D
extends MeshInstance3D

## Ground-painted 3D equivalent of the run-up gesture's valid-arc wedge + marker,
## replacing the old flat 2D screen overlay so the indicator reads as lying on the pitch
## under RunUpState's oblique POWER_VIEW camera.

@export var wedge_color: Color = HudTheme.GREEN_SUCCESS
@export var wedge_fill_alpha: float = 0.16
@export var wedge_outline_alpha: float = 0.85
## POWER_VIEW's camera sits only 2.0m behind the ball (FreeKickCameraRig._goal_centered_transform);
## a wedge edge much past that falls outside the view frustum.
@export var visual_radius_m: float = 1.6
@export var arc_segments: int = 24
@export var marker_dot_radius_m: float = 0.09
## Above the grass, below both the ball's underside (~0.05, from resting y=0.16 - radius 0.11)
## and FootballFieldMarkings3D.LINE_Y (0.062) - avoids z-fighting with either.
@export var ground_y: float = 0.03

var _material: StandardMaterial3D

func _ready() -> void:
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.vertex_color_use_as_albedo = true
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material_override = _material
	clear()

func clear() -> void:
	mesh = ImmediateMesh.new()
	visible = false

func show_ready(_ball_ground_pos: Vector3, _goal_position: Vector3) -> void:
	clear()

func hide_marker() -> void:
	clear()

func update_gesture(angle_deg: float, distance_m: float, locked_foot: String, ball_pos: Vector3, goal_position: Vector3) -> void:
	var ball := Vector3(ball_pos.x, ground_y, ball_pos.z)
	var to_goal := (goal_position - ball).slide(Vector3.UP)
	if to_goal.length() < 0.01:
		to_goal = Vector3.FORWARD
	var dir := to_goal.normalized()
	var right := dir.cross(Vector3.UP).normalized()
	var lateral_sign := -1.0 if locked_foot == "right" else 1.0

	var immediate := ImmediateMesh.new()

	var fill_color := wedge_color
	fill_color.a = wedge_fill_alpha
	var rim_points: Array[Vector3] = []
	for i in range(arc_segments + 1):
		var t := float(i) / float(arc_segments)
		var world_dir := _world_dir_for_angle_t(t, right, dir, lateral_sign)
		rim_points.append(ball + world_dir * visual_radius_m)
	immediate.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(rim_points.size() - 1):
		immediate.surface_set_color(fill_color)
		immediate.surface_add_vertex(ball)
		immediate.surface_set_color(fill_color)
		immediate.surface_add_vertex(rim_points[i])
		immediate.surface_set_color(fill_color)
		immediate.surface_add_vertex(rim_points[i + 1])
	immediate.surface_end()

	var outline_color := wedge_color
	outline_color.a = wedge_outline_alpha
	immediate.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for i in range(arc_segments + 1):
		var t := float(i) / float(arc_segments)
		var world_dir := _world_dir_for_angle_t(t, right, dir, lateral_sign)
		immediate.surface_set_color(outline_color)
		immediate.surface_add_vertex(ball + world_dir * visual_radius_m)
	immediate.surface_end()

	immediate.surface_begin(Mesh.PRIMITIVE_LINES)
	for edge_t in [0.0, 1.0]:
		var world_dir := _world_dir_for_angle_t(edge_t, right, dir, lateral_sign)
		immediate.surface_set_color(outline_color)
		immediate.surface_add_vertex(ball)
		immediate.surface_set_color(outline_color)
		immediate.surface_add_vertex(ball + world_dir * visual_radius_m)
	immediate.surface_end()

	var distance_t := clampf(distance_m / ShotCalculator.RUNUP_DISTANCE_MAX_M, 0.0, 1.0)
	var risk_color := HudTheme.CYAN_VALUE.lerp(HudTheme.ORANGE_BRIGHT, distance_t)
	var marker_angle_t := clampf(angle_deg, 0.0, ShotCalculator.RUNUP_ANGLE_MAX_DEG) / ShotCalculator.RUNUP_ANGLE_MAX_DEG
	var marker_dir := _world_dir_for_angle_t(marker_angle_t, right, dir, lateral_sign)
	var marker_point := ball + marker_dir * (visual_radius_m * distance_t)
	immediate.surface_begin(Mesh.PRIMITIVE_LINES)
	immediate.surface_set_color(risk_color)
	immediate.surface_add_vertex(ball)
	immediate.surface_set_color(risk_color)
	immediate.surface_add_vertex(marker_point)
	immediate.surface_end()

	_append_disc(immediate, marker_point, marker_dot_radius_m, risk_color)
	_append_disc(immediate, ball, marker_dot_radius_m * 0.55, Color(1.0, 1.0, 1.0, 0.6))

	mesh = immediate
	visible = true

func _world_dir_for_angle_t(angle_t: float, right: Vector3, dir: Vector3, lateral_sign: float) -> Vector3:
	return (right * lateral_sign * (1.0 - angle_t) + (-dir) * angle_t).normalized()

func _append_disc(immediate: ImmediateMesh, center: Vector3, radius: float, color: Color, segments: int = 12) -> void:
	immediate.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(segments):
		var a0 := TAU * float(i) / float(segments)
		var a1 := TAU * float(i + 1) / float(segments)
		immediate.surface_set_color(color)
		immediate.surface_add_vertex(center)
		immediate.surface_set_color(color)
		immediate.surface_add_vertex(center + Vector3(cos(a0), 0.0, sin(a0)) * radius)
		immediate.surface_set_color(color)
		immediate.surface_add_vertex(center + Vector3(cos(a1), 0.0, sin(a1)) * radius)
	immediate.surface_end()
