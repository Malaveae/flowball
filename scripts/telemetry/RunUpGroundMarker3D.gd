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
## Above the visual turf (0.047 m) and its blades (up to ~0.084 m).
## Presentation only: pitch and ball colliders remain unchanged.
@export var ground_y: float = 0.095
## Dims the inactive half's wedge to this fraction of the active half's alpha, so the full
## 180 degrees stays visible while the current foot's half reads as clearly highlighted.
@export var inactive_alpha_scale: float = 0.35

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

	# Always paint the FULL 180 degrees (both feet's halves), highlighting whichever half
	# matches the currently-selected foot so the legal area and the live selection are both
	# visible at once.
	_add_half_wedge(immediate, ball, right, dir, 1.0, locked_foot == "left")
	_add_half_wedge(immediate, ball, right, dir, -1.0, locked_foot == "right")

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

## Paints one 90-degree half of the full 180 (lateral_sign=+1 is the left-foot half, -1 is
## the right-foot half) as a fill + outline + edge lines, dimmed when it isn't the active half.
func _add_half_wedge(immediate: ImmediateMesh, ball: Vector3, right: Vector3, dir: Vector3, lateral_sign: float, is_active: bool) -> void:
	var alpha_scale := 1.0 if is_active else inactive_alpha_scale
	var fill_color := wedge_color
	fill_color.a = wedge_fill_alpha * alpha_scale
	var outline_color := wedge_color
	outline_color.a = wedge_outline_alpha * alpha_scale

	var rim_points: Array[Vector3] = []
	for i in range(arc_segments + 1):
		var t := float(i) / float(arc_segments)
		rim_points.append(ball + _world_dir_for_angle_t(t, right, dir, lateral_sign) * visual_radius_m)

	immediate.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(rim_points.size() - 1):
		immediate.surface_set_color(fill_color)
		immediate.surface_add_vertex(ball)
		immediate.surface_set_color(fill_color)
		immediate.surface_add_vertex(rim_points[i])
		immediate.surface_set_color(fill_color)
		immediate.surface_add_vertex(rim_points[i + 1])
	immediate.surface_end()

	immediate.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for p in rim_points:
		immediate.surface_set_color(outline_color)
		immediate.surface_add_vertex(p)
	immediate.surface_end()

	immediate.surface_begin(Mesh.PRIMITIVE_LINES)
	for edge_point in [ball, rim_points[0], ball, rim_points[rim_points.size() - 1]]:
		immediate.surface_set_color(outline_color)
		immediate.surface_add_vertex(edge_point)
	immediate.surface_end()

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
