class_name BallContactPanel
extends Panel

@export var ball_radius_px: float = 180.0
@export var ball_color: Color = Color(1.0, 1.0, 1.0, 0.16)
@export var guide_color: Color = Color(0.2, 0.85, 1.0, 0.85)
@export var lift_color: Color = Color(0.35, 1.0, 0.45, 0.8)
@export var drive_color: Color = Color(1.0, 0.35, 0.2, 0.8)
@export var swipe_color: Color = Color(1.0, 0.9, 0.25, 0.9)

var raw_points: PackedVector2Array = PackedVector2Array()

func set_swipe_points(points: PackedVector2Array) -> void:
	raw_points = points
	queue_redraw()

func clear_swipe() -> void:
	raw_points = PackedVector2Array()
	queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	var font := get_theme_default_font()
	var font_size := 15

	# Main ball target, screen-aligned over the real foreground ball.
	draw_circle(center, ball_radius_px, ball_color)
	draw_arc(center, ball_radius_px, 0.0, TAU, 96, Color(1.0, 1.0, 1.0, 0.95), 3.0)
	draw_arc(center, ball_radius_px * 0.55, 0.0, TAU, 96, Color(1, 1, 1, 0.38), 1.5)
	draw_line(center + Vector2(-ball_radius_px, 0), center + Vector2(ball_radius_px, 0), Color(1, 1, 1, 0.45), 1.5)
	draw_line(center + Vector2(0, -ball_radius_px), center + Vector2(0, ball_radius_px), Color(1, 1, 1, 0.45), 1.5)

	# Contact meaning zones.
	draw_rect(Rect2(center.x - ball_radius_px, center.y - ball_radius_px, ball_radius_px * 2.0, ball_radius_px * 0.55), Color(1.0, 0.25, 0.15, 0.09), true)
	draw_rect(Rect2(center.x - ball_radius_px, center.y + ball_radius_px * 0.45, ball_radius_px * 2.0, ball_radius_px * 0.55), Color(0.25, 1.0, 0.35, 0.10), true)
	draw_string(font, center + Vector2(-55, -ball_radius_px + 26), "HIGH CONTACT = DRIVE / TOPSPIN", HORIZONTAL_ALIGNMENT_CENTER, 220.0, font_size, drive_color)
	draw_string(font, center + Vector2(-55, ball_radius_px - 14), "LOW CONTACT = LIFT / BACKSPIN", HORIZONTAL_ALIGNMENT_CENTER, 220.0, font_size, lift_color)
	draw_string(font, center + Vector2(-56, 20), "CENTER = CLEAN / POWER", HORIZONTAL_ALIGNMENT_CENTER, 220.0, 14, Color.WHITE)
	draw_string(font, center + Vector2(-ball_radius_px + 14, 4), "LEFT\nCURL", HORIZONTAL_ALIGNMENT_LEFT, 90.0, 15, guide_color)
	draw_string(font, center + Vector2(ball_radius_px - 62, 4), "RIGHT\nCURL", HORIZONTAL_ALIGNMENT_LEFT, 95.0, 15, guide_color)
	draw_string(font, center + Vector2(-88, ball_radius_px + 24), "Drag outside ball = stronger follow-through", HORIZONTAL_ALIGNMENT_LEFT, 320.0, 14, Color(1.0, 0.92, 0.35, 0.95))

	# Contact + follow-through visualization.
	if raw_points.size() > 0:
		var first := center + raw_points[0]
		draw_circle(first, 10.0, Color(1.0, 0.9, 0.25, 1.0))
		draw_arc(first, 16.0, 0.0, TAU, 32, Color(0.0, 0.0, 0.0, 0.85), 2.0)
		draw_string(font, first + Vector2(12, -12), "CONTACT", HORIZONTAL_ALIGNMENT_LEFT, 100.0, 12, Color(1.0, 0.95, 0.4, 1.0))
		for i in range(1, raw_points.size()):
			var a := center + raw_points[i - 1]
			var b := center + raw_points[i]
			draw_line(a, b, swipe_color, 5.0)
		var last := center + raw_points[raw_points.size() - 1]
		if raw_points.size() >= 2:
			draw_circle(last, 6.0, Color(1.0, 0.55, 0.15, 1.0))
			var follow := last - first
			var curl_strength := clampf(absf(follow.x) / maxf(1.0, ball_radius_px), 0.0, 1.8)
			var meter_rect := Rect2(center.x - ball_radius_px, center.y + ball_radius_px + 44.0, ball_radius_px * 2.0, 10.0)
			draw_rect(meter_rect, Color(0.0, 0.0, 0.0, 0.45), true)
			draw_rect(Rect2(meter_rect.position, Vector2(meter_rect.size.x * clampf(curl_strength / 1.4, 0.0, 1.0), meter_rect.size.y)), Color(1.0, 0.55, 0.08, 0.95), true)
			draw_string(font, meter_rect.position + Vector2(0, 28), "CURL METER", HORIZONTAL_ALIGNMENT_LEFT, 160.0, 12, Color(1.0, 0.8, 0.3, 1.0))
			if follow.length() > 8.0:
				var dir := follow.normalized()
				draw_line(last, last - dir.rotated(0.45) * 18.0, swipe_color, 4.0)
				draw_line(last, last - dir.rotated(-0.45) * 18.0, swipe_color, 4.0)
