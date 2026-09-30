class_name BallContactPanel
extends Panel

@export var ball_radius_px: float = 180.0
@export var ball_color: Color = Color(1.0, 1.0, 1.0, 0.04)

var raw_points: PackedVector2Array = PackedVector2Array()

func set_swipe_points(points: PackedVector2Array) -> void:
	raw_points = points
	queue_redraw()

func clear_swipe() -> void:
	raw_points = PackedVector2Array()
	queue_redraw()

func _draw_dashed_arc(center: Vector2, radius: float, start_angle: float, end_angle: float, point_count: int, color: Color, width: float, dash_length: float) -> void:
	var step := (end_angle - start_angle) / float(point_count)
	var prev := center + Vector2(cos(start_angle), sin(start_angle)) * radius
	var accumulated := 0.0
	var drawing := true
	var toggle := dash_length
	for i in range(1, point_count + 1):
		var t := start_angle + step * float(i)
		var p := center + Vector2(cos(t), sin(t)) * radius
		var seg_len := radius * step
		if drawing:
			draw_line(prev, p, color, width)
		accumulated += seg_len
		if accumulated >= toggle:
			drawing = not drawing
			accumulated = 0.0
			toggle = dash_length if drawing else dash_length
		prev = p

func _draw() -> void:
	var center := size * 0.5
	var r := ball_radius_px
	var font := get_theme_default_font()

	# --- Ball target outline ---
	draw_circle(center, r, ball_color)
	draw_arc(center, r, 0.0, TAU, 96, HudTheme.CYAN_FRAME_SOFT, 2.0)
	_draw_dashed_arc(center, r * 0.55, 0.0, TAU, 64, HudTheme.CYAN_DIM, 1.0, 4.0)

	# --- Guide cross (editorial crop marks style) ---
	draw_line(center + Vector2(-r, 0.0), center + Vector2(r, 0.0), Color(HudTheme.CYAN_DIM.r, HudTheme.CYAN_DIM.g, HudTheme.CYAN_DIM.b, 0.4), 1.0)
	draw_line(center + Vector2(0.0, -r), center + Vector2(0.0, r), Color(HudTheme.CYAN_DIM.r, HudTheme.CYAN_DIM.g, HudTheme.CYAN_DIM.b, 0.4), 1.0)

	# --- Diagonal crop marks ---
	var diag_len := 8.0
	var diag_dist := r * 0.85
	for angle_deg in [45, 135, 225, 315]:
		var rad := deg_to_rad(float(angle_deg))
		var dir := Vector2(cos(rad), sin(rad))
		var p := center + dir * diag_dist
		draw_line(p - dir * diag_len * 0.5, p + dir * diag_len * 0.5, HudTheme.TEXT_FAINT, 1.5)

	# --- Region labels ---
	# High contact (top)
	draw_string(font, center + Vector2(-60.0, -r * 1.2), "HIGH CONTACT", HORIZONTAL_ALIGNMENT_LEFT, 120.0, 17, HudTheme.CYAN_BRIGHT)
	draw_string(font, center + Vector2(-60.0, -r * 1.2 + 15.0), "→ DRIVE / TOP", HORIZONTAL_ALIGNMENT_LEFT, 120.0, 14, HudTheme.TEXT_LABEL)

	# Low contact (bottom)
	draw_string(font, center + Vector2(-55.0, r * 1.05), "LOW CONTACT", HORIZONTAL_ALIGNMENT_LEFT, 110.0, 17, HudTheme.GREEN_SUCCESS)
	draw_string(font, center + Vector2(-50.0, r * 1.05 + 14.0), "→ LIFT / BACKSPIN", HORIZONTAL_ALIGNMENT_LEFT, 130.0, 14, HudTheme.TEXT_LABEL)

	# Left curl
	draw_string(font, center + Vector2(-r - 70.0, -6.0), "LEFT", HORIZONTAL_ALIGNMENT_LEFT, 60.0, 17, HudTheme.YELLOW)
	draw_string(font, center + Vector2(-r - 70.0, 10.0), "→ LEFT CURL", HORIZONTAL_ALIGNMENT_LEFT, 80.0, 14, HudTheme.TEXT_LABEL)

	# Right curl
	draw_string(font, center + Vector2(r + 10.0, -6.0), "RIGHT", HORIZONTAL_ALIGNMENT_LEFT, 70.0, 17, HudTheme.YELLOW)
	draw_string(font, center + Vector2(r + 8.0, 10.0), "→ RIGHT CURL", HORIZONTAL_ALIGNMENT_LEFT, 80.0, 14, HudTheme.TEXT_LABEL)

	# Center
	draw_string(font, center + Vector2(-50.0, 4.0), "CLEAN / POWER", HORIZONTAL_ALIGNMENT_LEFT, 100.0, 14, HudTheme.TEXT_BODY)

	# --- Swipe trail ---
	if raw_points.size() > 0:
		var first := center + raw_points[0]
		draw_circle(first, 8.0, HudTheme.YELLOW)
		draw_arc(first, 10.0, 0.0, TAU, 24, Color.BLACK, 2.0)

		for i in range(1, raw_points.size()):
			var a := center + raw_points[i - 1]
			var b := center + raw_points[i]
			draw_line(a, b, HudTheme.YELLOW_WARN, 4.0)

		var last := center + raw_points[raw_points.size() - 1]
		draw_circle(last, 5.0, HudTheme.ORANGE_BRIGHT)

		if raw_points.size() >= 2:
			var follow := last - first
			var follow_len := follow.length()
			if follow_len > 10.0:
				var dir := follow.normalized()
				var arrow_head := 14.0
				draw_line(last, last - dir.rotated(0.45) * arrow_head, HudTheme.YELLOW_WARN, 3.0)
				draw_line(last, last - dir.rotated(-0.45) * arrow_head, HudTheme.YELLOW_WARN, 3.0)

			var curl_pct := clampi(int(round(follow_len / r * 100.0)), 0, 100)
			draw_string(font, center + Vector2(-60.0, r + 42.0), "FOLLOW-THROUGH: %d%%" % curl_pct, HORIZONTAL_ALIGNMENT_LEFT, 200.0, 14, HudTheme.CYAN_VALUE)
