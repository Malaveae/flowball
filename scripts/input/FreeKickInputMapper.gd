class_name FreeKickInputMapper
extends RefCounted

static func clamp_to_support_sector(local_pos: Vector2, radius: float, selected_foot: String, sector_angle_degrees: float = 120.0) -> Vector2:
	if radius <= 0.0:
		return Vector2.ZERO
	var side_sign := 1.0 if selected_foot == "right" else -1.0
	var center_angle := 0.0 if side_sign > 0.0 else PI
	var half_angle := deg_to_rad(sector_angle_degrees * 0.5)
	var distance := clampf(local_pos.length(), 0.0, radius)
	if distance <= 0.001:
		return Vector2.RIGHT * side_sign * radius * 0.35
	var angle := local_pos.angle()
	var delta := wrapf(angle - center_angle, -PI, PI)
	delta = clampf(delta, -half_angle, half_angle)
	return Vector2.from_angle(center_angle + delta) * distance

static func clamp_to_support_foot_side(local_pos: Vector2, radius: float, selected_kicking_foot: String) -> Vector2:
	# Step 2 physical rule: if the player kicks with the right foot, the planted/support foot is the left foot,
	# so it must appear on the left side of the ball. Left-footed shots mirror this.
	if radius <= 0.0:
		return Vector2.ZERO
	var support_side := -1.0 if selected_kicking_foot == "right" else 1.0
	var min_side_distance := radius * 0.18
	var side_x := clampf(absf(local_pos.x), min_side_distance, radius) * support_side
	return Vector2(side_x, clampf(local_pos.y, -radius, radius))

static func clamp_to_goal_aim_lane(local_pos: Vector2, radius: float) -> Vector2:
	# Backward-compatible helper for older prototypes.
	if radius <= 0.0:
		return Vector2.ZERO
	return Vector2(clampf(local_pos.x, -radius, radius), clampf(local_pos.y, -radius, radius))

static func support_vector_from_marker(marker_pos: Vector2, radius: float) -> Vector2:
	if radius <= 0.0:
		return Vector2.ZERO
	var normalized := marker_pos / radius
	return Vector2(clampf(normalized.x, -1.0, 1.0), clampf(normalized.y, -1.0, 1.0))

static func support_good_enough(marker_pos: Vector2, radius: float, elapsed: float, threshold_multiplier: float = 1.0) -> bool:
	var min_radius := radius * 0.35 * threshold_multiplier
	var min_time := 0.12 * threshold_multiplier
	return marker_pos.length() >= min_radius and elapsed >= min_time

static func screen_to_control_local(screen_pos: Vector2, control: Control) -> Vector2:
	return screen_pos - control.global_position - control.size * 0.5

static func normalize_ball_contact(local_pos: Vector2, ball_radius_px: float) -> Vector2:
	if ball_radius_px <= 0.0:
		return Vector2.ZERO
	var p := local_pos / ball_radius_px
	return p.limit_length(1.0)

static func normalize_swipe_points(points: PackedVector2Array, ball_radius_px: float) -> PackedVector2Array:
	var normalized := PackedVector2Array()
	if ball_radius_px <= 0.0:
		return normalized
	for i in range(points.size()):
		var p := points[i] / ball_radius_px
		# First point is physical impact on the ball. Follow-through may extend beyond the ball
		# so a long sideways drag can intentionally create stronger curl.
		var max_length := 1.0 if i == 0 else 1.8
		normalized.append(p.limit_length(max_length))
	return normalized

static func contact_good_enough(points: PackedVector2Array, duration: float, ball_radius_px: float, threshold_multiplier: float = 1.0) -> bool:
	if points.size() < 2 or ball_radius_px <= 0.0:
		return false
	var swipe_distance := (points[points.size() - 1] - points[0]).length()
	return swipe_distance >= ball_radius_px * 0.10 * threshold_multiplier and duration >= 0.08 * threshold_multiplier
