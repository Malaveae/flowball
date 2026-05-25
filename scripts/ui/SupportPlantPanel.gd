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

func set_foot(foot: String) -> void:
	selected_foot = foot
	queue_redraw()

func set_marker(local_pos: Vector2, active: bool = true) -> void:
	marker_local = local_pos
	has_marker = active
	queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	# Screen-space sector: right-foot plant appears on the right side, left-foot plant on the left.
	# The mapper uses the same convention, so the marker should sit exactly inside this drawn sector.
	var side_sign := 1.0 if selected_foot == "right" else -1.0
	var center_angle := 0.0 if side_sign > 0.0 else PI
	var half_angle := deg_to_rad(sector_angle_degrees * 0.5)
	var lane_rect := Rect2(center - Vector2(sector_radius, sector_radius), Vector2(sector_radius * 2.0, sector_radius * 2.0))
	draw_rect(lane_rect, sector_color, true)
	draw_rect(lane_rect, guide_color, false, 2.0)

	# Goal target lanes: first post / center / second post.
	var third := sector_radius * 2.0 / 3.0
	var left_x := center.x - sector_radius + third
	var right_x := center.x - sector_radius + third * 2.0
	draw_line(Vector2(left_x, center.y - sector_radius), Vector2(left_x, center.y + sector_radius), Color(1, 1, 1, 0.35), 2.0)
	draw_line(Vector2(right_x, center.y - sector_radius), Vector2(right_x, center.y + sector_radius), Color(1, 1, 1, 0.35), 2.0)
	draw_line(center + Vector2(-sector_radius, 0), center + Vector2(sector_radius, 0), Color(1.0, 1.0, 1.0, 0.45), 2.0)
	draw_line(center + Vector2(0, -sector_radius), center + Vector2(0, sector_radius), Color(1.0, 0.85, 0.25, 0.45), 1.5)

	# Minimum useful plant distance.
	draw_arc(center, sector_radius * 0.35, 0.0, TAU, 64, Color(0.2, 1.0, 0.35, 0.9), 3.0)

	# Support-foot vector: a straight line from ball center to plant point.
	if has_marker:
		var marker := center + marker_local
		var line_color := Color(1.0, 0.18, 0.1, 0.95)
		draw_line(center, marker, line_color, 5.0)
		draw_circle(marker, 12.0, line_color)
		draw_circle(marker, 5.0, Color.WHITE)
		var dir := marker_local.normalized() if marker_local.length() > 0.001 else Vector2(side_sign, 0.0)
		var tangent := dir.rotated(PI * 0.5)
		# Simple foot/shoe bar perpendicular to the plant vector.
		draw_line(marker - tangent * 18.0, marker + tangent * 18.0, Color(1.0, 1.0, 1.0, 0.95), 4.0)

	var font := get_theme_default_font()
	var font_size := 14
	draw_string(font, center + Vector2(-160.0, -sector_radius - 42.0), "STEP 2: AIM WITH SUPPORT-FOOT LINE", HORIZONTAL_ALIGNMENT_LEFT, 420.0, 17, Color(1, 1, 1, 1))
	draw_string(font, center + Vector2(-162.0, -sector_radius - 20.0), "Drag red line toward FIRST POST / CENTER / SECOND POST", HORIZONTAL_ALIGNMENT_LEFT, 440.0, 14, text_color)
	draw_string(font, center + Vector2(-sector_radius + 10.0, -sector_radius + 22.0), "FIRST\nPOST", HORIZONTAL_ALIGNMENT_LEFT, 90.0, font_size, text_color)
	draw_string(font, center + Vector2(-28.0, -sector_radius + 22.0), "CENTER", HORIZONTAL_ALIGNMENT_LEFT, 90.0, font_size, text_color)
	draw_string(font, center + Vector2(sector_radius - 78.0, -sector_radius + 22.0), "SECOND\nPOST", HORIZONTAL_ALIGNMENT_LEFT, 100.0, font_size, text_color)
	draw_string(font, center + Vector2(-92.0, sector_radius + 18.0), "Y axis still adjusts plant depth/body setup", HORIZONTAL_ALIGNMENT_LEFT, 330.0, 13, Color(1.0, 0.9, 0.45, 0.95))
	draw_circle(center, 5.0, Color.WHITE)
