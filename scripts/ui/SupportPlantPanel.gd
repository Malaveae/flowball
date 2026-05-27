class_name SupportPlantPanel
extends Panel

@export var selected_foot: String = "right"
@export var sector_radius: float = 160.0
@export var sector_angle_degrees: float = 120.0
@export var sector_color: Color = Color(0.05, 0.7, 0.95, 0.16)
@export var guide_color: Color = Color(0.65, 0.95, 1.0, 0.78)
@export var text_color: Color = Color(0.92, 0.98, 1.0, 0.96)

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
	var side_sign := -1.0 if selected_foot == "right" else 1.0
	var support_foot := "LEFT" if selected_foot == "right" else "RIGHT"
	var active_marker := center + marker_local if has_marker else center + Vector2(side_sign * sector_radius * 0.58, 18.0)

	_draw_backplate(center)
	_draw_pitch_grid(center)
	_draw_legal_zone(center, side_sign)
	_draw_distance_rings(center)
	_draw_aim_lanes(center)
	_draw_ball(center)
	_draw_support_foot(center, active_marker, side_sign)
	_draw_header(center, support_foot, font)
	_draw_footer(center, support_foot, font)

func _draw_backplate(center: Vector2) -> void:
	var panel_rect := Rect2(Vector2.ZERO, size)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.015, 0.027, 0.03, 0.92)
	bg.border_color = Color(0.08, 0.72, 0.95, 0.9)
	bg.border_width_left = 2
	bg.border_width_top = 2
	bg.border_width_right = 2
	bg.border_width_bottom = 2
	bg.corner_radius_top_left = 18
	bg.corner_radius_top_right = 18
	bg.corner_radius_bottom_left = 18
	bg.corner_radius_bottom_right = 18
	draw_style_box(bg, panel_rect)
	draw_circle(center, sector_radius * 1.22, Color(0.0, 0.9, 1.0, 0.035))
	draw_circle(center, sector_radius * 0.72, Color(0.6, 1.0, 0.2, 0.035))

func _draw_pitch_grid(center: Vector2) -> void:
	var pitch := Rect2(center - Vector2(sector_radius, sector_radius), Vector2(sector_radius * 2.0, sector_radius * 2.0))
	draw_rect(pitch, Color(0.03, 0.18, 0.12, 0.58), true)
	for i in range(0, 9):
		var x := pitch.position.x + float(i) * pitch.size.x / 8.0
		draw_line(Vector2(x, pitch.position.y), Vector2(x, pitch.end.y), Color(1, 1, 1, 0.055), 1.0)
		var y := pitch.position.y + float(i) * pitch.size.y / 8.0
		draw_line(Vector2(pitch.position.x, y), Vector2(pitch.end.x, y), Color(1, 1, 1, 0.055), 1.0)
	draw_rect(pitch, Color(0.55, 0.95, 1.0, 0.26), false, 2.0)

func _draw_legal_zone(center: Vector2, side_sign: float) -> void:
	var legal_rect := Rect2(center + Vector2(0.0 if side_sign > 0.0 else -sector_radius, -sector_radius), Vector2(sector_radius, sector_radius * 2.0))
	var illegal_rect := Rect2(center + Vector2(-sector_radius if side_sign > 0.0 else 0.0, -sector_radius), Vector2(sector_radius, sector_radius * 2.0))
	draw_rect(illegal_rect, Color(1.0, 0.06, 0.03, 0.10), true)
	draw_rect(legal_rect, sector_color, true)
	draw_line(center + Vector2(-sector_radius, 0), center + Vector2(sector_radius, 0), Color(1, 1, 1, 0.34), 2.0)
	draw_line(center + Vector2(0, -sector_radius), center + Vector2(0, sector_radius), Color(1.0, 0.86, 0.28, 0.5), 2.0)

func _draw_distance_rings(center: Vector2) -> void:
	draw_arc(center, sector_radius * 0.35, 0.0, TAU, 96, Color(0.35, 1.0, 0.28, 0.88), 3.0)
	draw_arc(center, sector_radius * 0.62, 0.0, TAU, 96, Color(1.0, 0.82, 0.22, 0.36), 1.5)
	draw_arc(center, sector_radius * 0.86, 0.0, TAU, 96, Color(1.0, 0.18, 0.08, 0.26), 1.5)

func _draw_aim_lanes(center: Vector2) -> void:
	var aim_ray_length := sector_radius * 0.86
	for lane in [-1, 0, 1]:
		var angle := deg_to_rad(float(lane) * 30.0)
		var end := center + Vector2.UP.rotated(angle) * aim_ray_length
		var color := Color(0.35, 0.9, 1.0, 0.62) if lane == 0 else Color(1.0, 1.0, 1.0, 0.28)
		draw_line(center, end, color, 2.5)
	var font := get_theme_default_font()
	draw_string(font, center + Vector2(-154.0, -sector_radius + 16.0), "LEFT POST", HORIZONTAL_ALIGNMENT_CENTER, 96.0, 12, text_color)
	draw_string(font, center + Vector2(-48.0, -sector_radius - 10.0), "CENTER", HORIZONTAL_ALIGNMENT_CENTER, 96.0, 12, Color(0.55, 0.95, 1.0, 1.0))
	draw_string(font, center + Vector2(58.0, -sector_radius + 16.0), "RIGHT POST", HORIZONTAL_ALIGNMENT_CENTER, 104.0, 12, text_color)

func _draw_ball(center: Vector2) -> void:
	draw_circle(center, 17.0, Color(0.03, 0.035, 0.04, 0.9))
	draw_circle(center, 13.0, Color.WHITE)
	draw_circle(center + Vector2(-4, -4), 3.0, Color(0.05, 0.08, 0.1, 0.65))
	draw_string(get_theme_default_font(), center + Vector2(18.0, -10.0), "BALL", HORIZONTAL_ALIGNMENT_LEFT, 72.0, 12, Color.WHITE)

func _draw_support_foot(center: Vector2, marker: Vector2, side_sign: float) -> void:
	var marker_color := Color(1.0, 0.18, 0.08, 1.0) if has_marker else Color(1.0, 0.5, 0.22, 0.54)
	draw_dashed_line(center, marker, marker_color, 3.0, 7.0)
	draw_circle(marker, 19.0, Color(1.0, 0.18, 0.08, 0.22))
	draw_circle(marker, 12.0, marker_color)
	draw_circle(marker, 5.0, Color.WHITE)
	var angle_dir := Vector2.from_angle(foot_angle) if has_foot_angle else Vector2(side_sign, 0.0)
	_draw_boot(marker, angle_dir, has_marker)
	if has_foot_angle:
		_draw_aim_meter(marker, angle_dir)

func _draw_boot(marker: Vector2, dir: Vector2, active: bool) -> void:
	var side := dir.orthogonal().normalized()
	var boot := PackedVector2Array([
		marker + dir * 31.0 + side * 8.0,
		marker + dir * 22.0 - side * 14.0,
		marker - dir * 28.0 - side * 10.0,
		marker - dir * 32.0 + side * 10.0,
		marker + dir * 12.0 + side * 16.0,
	])
	var color := Color(1.0, 1.0, 1.0, 0.96) if active else Color(1.0, 1.0, 1.0, 0.34)
	draw_colored_polygon(boot, color)
	draw_polyline(boot, Color(0.0, 0.75, 1.0, 0.85), 2.0, true)

func _draw_aim_meter(marker: Vector2, angle_dir: Vector2) -> void:
	var target := marker + angle_dir * 62.0
	draw_line(marker, target, Color(1.0, 0.9, 0.2, 0.92), 3.0)
	draw_circle(target, 7.0, Color(1.0, 0.85, 0.2, 1.0))
	var meter_width := 148.0
	var meter_pos := marker + Vector2(-meter_width * 0.5, 38.0)
	draw_rect(Rect2(meter_pos, Vector2(meter_width, 10.0)), Color(0.0, 0.0, 0.0, 0.55), true)
	draw_line(meter_pos + Vector2(meter_width * 0.5, -4.0), meter_pos + Vector2(meter_width * 0.5, 14.0), Color.WHITE, 1.5)
	var fill_end := meter_pos + Vector2(meter_width * 0.5 + aim_target * meter_width * 0.5, 5.0)
	draw_line(meter_pos + Vector2(meter_width * 0.5, 5.0), fill_end, Color(1.0, 0.85, 0.2, 1.0), 8.0)
	var label := "RIGHT POST" if aim_target > 0.25 else "LEFT POST" if aim_target < -0.25 else "CENTER"
	draw_string(get_theme_default_font(), meter_pos + Vector2(0, 29.0), "TARGET: %s" % label, HORIZONTAL_ALIGNMENT_CENTER, meter_width, 12, Color(1.0, 0.9, 0.35, 1.0))

func _draw_header(center: Vector2, support_foot: String, font: Font) -> void:
	draw_string(font, center + Vector2(-178.0, -sector_radius - 60.0), "STEP 2  ·  SUPPORT FOOT", HORIZONTAL_ALIGNMENT_LEFT, 420.0, 18, Color(1, 1, 1, 1))
	draw_string(font, center + Vector2(-178.0, -sector_radius - 36.0), substep_label.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, 440.0, 14, Color(1.0, 0.92, 0.3, 1.0))
	draw_string(font, center + Vector2(-178.0, -sector_radius - 16.0), "%s foot plants beside the ball, then rotates subtly toward the target lane." % support_foot, HORIZONTAL_ALIGNMENT_LEFT, 540.0, 13, text_color)

func _draw_footer(center: Vector2, support_foot: String, font: Font) -> void:
	var legal_side := "LEFT" if support_foot == "LEFT" else "RIGHT"
	draw_string(font, center + Vector2(-174.0, sector_radius + 18.0), "Allowed plant side: %s of ball  ·  Green ring = useful distance  ·  Yellow line = foot aim" % legal_side, HORIZONTAL_ALIGNMENT_LEFT, 600.0, 13, Color(1.0, 0.9, 0.45, 0.96))
