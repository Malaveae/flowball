class_name SupportPlantPanel
extends Panel

@export var selected_foot: String = "right"
@export var sector_radius: float = 160.0
@export var sector_angle_degrees: float = 120.0
@export var sector_color: Color = Color(0.2, 0.8, 1.0, 0.18)
@export var guide_color: Color = Color(0.7, 0.95, 1.0, 0.75)
@export var text_color: Color = Color(1.0, 1.0, 1.0, 0.95)

var marker_local: Vector2 = Vector2.ZERO
var has_marker: bool = false
var foot_angle: float = 0.0
var has_foot_angle: bool = false
var aim_target: float = 0.0
var substep_label: String = "1/2: choose foot location"

func set_foot(foot: String) -> void:
	selected_foot = foot
	queue_redraw()

func set_marker(local_pos: Vector2, active: bool = true) -> void:
	marker_local = local_pos
	has_marker = active
	queue_redraw()

func set_foot_angle(angle: float, active: bool = true, target: float = 0.0) -> void:
	foot_angle = angle
	aim_target = clampf(target, -1.0, 1.0)
	has_foot_angle = active
	queue_redraw()

func set_substep_label(text: String) -> void:
	substep_label = text
	queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	var font := get_theme_default_font()
	var font_size := 14
	# White center dot = the ball. Red marker = support/planted foot.
	# Physical rule: right-foot kick plants the left foot on the left side of the ball; left-foot kick mirrors it.
	var side_sign := -1.0 if selected_foot == "right" else 1.0
	var center_angle := 0.0 if side_sign > 0.0 else PI
	var half_angle := deg_to_rad(sector_angle_degrees * 0.5)
	var lane_rect := Rect2(center - Vector2(sector_radius, sector_radius), Vector2(sector_radius * 2.0, sector_radius * 2.0))
	draw_rect(lane_rect, sector_color, true)
	draw_rect(lane_rect, guide_color, false, 2.0)

	# Support-foot legal side. Dim the impossible side so the player understands the ball is the center.
	var legal_rect := Rect2(center + Vector2(0.0 if side_sign > 0.0 else -sector_radius, -sector_radius), Vector2(sector_radius, sector_radius * 2.0))
	var illegal_rect := Rect2(center + Vector2(-sector_radius if side_sign > 0.0 else 0.0, -sector_radius), Vector2(sector_radius, sector_radius * 2.0))
	draw_rect(legal_rect, Color(0.2, 0.9, 1.0, 0.16), true)
	draw_rect(illegal_rect, Color(1.0, 0.12, 0.08, 0.07), true)
	draw_line(center + Vector2(-sector_radius, 0), center + Vector2(sector_radius, 0), Color(1.0, 1.0, 1.0, 0.45), 2.0)
	draw_line(center + Vector2(0, -sector_radius), center + Vector2(0, sector_radius), Color(1.0, 0.85, 0.25, 0.45), 1.5)

	# Minimum useful plant distance.
	draw_arc(center, sector_radius * 0.35, 0.0, TAU, 64, Color(0.2, 1.0, 0.35, 0.9), 3.0)

	# Substep B guide: subtle support-foot rotation only, clamped to ±30°.
	var aim_ray_length := sector_radius * 0.8
	var max_aim_offset := deg_to_rad(30.0)
	var left_guide := center + Vector2.UP.rotated(-max_aim_offset) * aim_ray_length
	var center_guide := center + Vector2.UP * aim_ray_length
	var right_guide := center + Vector2.UP.rotated(max_aim_offset) * aim_ray_length
	draw_line(center, left_guide, Color(1.0, 1.0, 1.0, 0.28), 2.0)
	draw_line(center, center_guide, Color(0.35, 0.9, 1.0, 0.45), 2.5)
	draw_line(center, right_guide, Color(1.0, 1.0, 1.0, 0.28), 2.0)
	draw_string(font, left_guide + Vector2(-48.0, -10.0), "LEFT -30°", HORIZONTAL_ALIGNMENT_CENTER, 96.0, 11, text_color)
	draw_string(font, center_guide + Vector2(-44.0, -18.0), "CENTER", HORIZONTAL_ALIGNMENT_CENTER, 88.0, 11, text_color)
	draw_string(font, right_guide + Vector2(-48.0, -10.0), "RIGHT +30°", HORIZONTAL_ALIGNMENT_CENTER, 96.0, 11, text_color)

	# Support-foot vector: a straight line from ball center to plant point.
	if has_marker:
		var marker := center + marker_local
		var line_color := Color(1.0, 0.18, 0.1, 0.95)
		draw_line(center, marker, line_color, 5.0)
		draw_circle(marker, 12.0, line_color)
		draw_circle(marker, 5.0, Color.WHITE)
		var angle_dir := Vector2.from_angle(foot_angle) if has_foot_angle else (marker_local.normalized() if marker_local.length() > 0.001 else Vector2(side_sign, 0.0))
		# Foot angle line: second substep rotates this bar around the planted point.
		draw_line(marker - angle_dir * 24.0, marker + angle_dir * 24.0, Color(1.0, 1.0, 1.0, 0.95), 5.0)
		if has_foot_angle:
			var selected_target := marker + angle_dir * 58.0
			draw_line(marker, selected_target, Color(1.0, 0.9, 0.2, 0.85), 3.0)
			draw_circle(selected_target, 7.0, Color(1.0, 0.85, 0.2, 0.95))
			var aim_adjust := aim_target * 6.0
			var meter_width := 140.0
			var meter_pos := marker + Vector2(-meter_width * 0.5, 34.0)
			draw_rect(Rect2(meter_pos, Vector2(meter_width, 8.0)), Color(0.0, 0.0, 0.0, 0.45), true)
			draw_line(meter_pos + Vector2(meter_width * 0.5, -4.0), meter_pos + Vector2(meter_width * 0.5, 12.0), Color.WHITE, 1.5)
			var fill_center := meter_pos + Vector2(meter_width * 0.5, 0.0)
			var fill_end := fill_center + Vector2((aim_adjust / 6.0) * meter_width * 0.5, 0.0)
			draw_line(fill_center + Vector2(0, 4.0), fill_end + Vector2(0, 4.0), Color(1.0, 0.85, 0.2, 1.0), 7.0)
			var label := "RIGHT POST" if aim_target > 0.25 else "LEFT POST" if aim_target < -0.25 else "CENTER"
			draw_string(font, meter_pos + Vector2(0, 26.0), "FOOT TARGET: %s" % label, HORIZONTAL_ALIGNMENT_CENTER, meter_width, 12, Color(1.0, 0.9, 0.35, 1.0))

	draw_string(font, center + Vector2(-160.0, -sector_radius - 56.0), "STEP 2: SUPPORT FOOT SETUP", HORIZONTAL_ALIGNMENT_LEFT, 420.0, 17, Color(1, 1, 1, 1))
	draw_string(font, center + Vector2(-162.0, -sector_radius - 34.0), substep_label, HORIZONTAL_ALIGNMENT_LEFT, 440.0, 14, Color(1.0, 0.92, 0.3, 1.0))
	draw_string(font, center + Vector2(-162.0, -sector_radius - 14.0), "A = plant/support foot. B = subtle aim angle to LEFT POST / CENTER / RIGHT POST.", HORIZONTAL_ALIGNMENT_LEFT, 560.0, 13, text_color)
	var support_foot := "LEFT" if selected_foot == "right" else "RIGHT"
	var support_label := "%s SUPPORT FOOT ZONE (%s-foot kick)" % [support_foot, selected_foot.to_upper()]
	draw_string(font, center + Vector2(side_sign * 34.0 - 120.0, -sector_radius + 22.0), support_label, HORIZONTAL_ALIGNMENT_LEFT, 300.0, font_size, text_color)
	draw_string(font, center + Vector2(-92.0, sector_radius + 18.0), "White dot = ball center. Red dot = planted/support foot.", HORIZONTAL_ALIGNMENT_LEFT, 430.0, 13, Color(1.0, 0.9, 0.45, 0.95))
	draw_circle(center, 8.0, Color.WHITE)
	draw_string(font, center + Vector2(10.0, -10.0), "BALL", HORIZONTAL_ALIGNMENT_LEFT, 70.0, 12, Color.WHITE)
