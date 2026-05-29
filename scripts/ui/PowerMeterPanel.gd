class_name PowerMeterPanel
extends Control

@export var power_value: float = 0.0:
	set(value):
		power_value = clampf(value, 0.0, 1.0)
		queue_redraw()

const OPTIMAL_MIN := 0.70
const OPTIMAL_MAX := 0.85

func _draw() -> void:
	var bar_rect := Rect2(22.0, 12.0, 28.0, size.y - 24.0)
	var font := get_theme_default_font()

	var shell := StyleBoxFlat.new()
	shell.bg_color = Color(0.0, 0.0, 0.0, 0.34)
	shell.border_color = Color(1.0, 1.0, 1.0, 0.16)
	shell.border_width_left = 1
	shell.border_width_top = 1
	shell.border_width_right = 1
	shell.border_width_bottom = 1
	shell.corner_radius_top_left = 14
	shell.corner_radius_top_right = 14
	shell.corner_radius_bottom_left = 14
	shell.corner_radius_bottom_right = 14
	draw_style_box(shell, bar_rect.grow(6.0))

	var inner := bar_rect.grow(-4.0)
	_draw_vertical_segment(inner, 0.0, 0.40, Color(0.0, 0.75, 1.0, 0.78), Color(0.0, 0.95, 1.0, 0.20))
	_draw_vertical_segment(inner, 0.40, 0.70, Color(0.25, 1.0, 0.25, 0.78), Color(0.55, 1.0, 0.0, 0.20))
	_draw_vertical_segment(inner, 0.70, 0.85, Color(1.0, 0.92, 0.0, 0.88), Color(1.0, 0.65, 0.0, 0.24))
	_draw_vertical_segment(inner, 0.85, 1.0, Color(1.0, 0.16, 0.08, 0.84), Color(1.0, 0.35, 0.16, 0.22))

	var fill_height := inner.size.y * power_value
	if fill_height > 0.0:
		var fill_rect := Rect2(inner.position.x, inner.end.y - fill_height, inner.size.x, fill_height)
		draw_rect(fill_rect.grow(3.0), _power_color(power_value, 0.22), true)
		draw_rect(fill_rect, _power_color(power_value, 0.78), true)

	for i in range(0, 11):
		var t := float(i) / 10.0
		var y := inner.end.y - inner.size.y * t
		var w := 15.0 if i % 5 == 0 else 8.0
		draw_line(Vector2(inner.position.x, y), Vector2(inner.position.x + w, y), Color(1, 1, 1, 0.34), 1.0)
		draw_line(Vector2(inner.end.x - w, y), Vector2(inner.end.x, y), Color(1, 1, 1, 0.24), 1.0)

	_draw_vertical_zone_marker(inner, OPTIMAL_MIN, Color(0.6, 1.0, 0.0, 0.88))
	_draw_vertical_zone_marker(inner, OPTIMAL_MAX, Color(1.0, 0.2, 0.1, 0.88))

	var pointer_y := inner.end.y - inner.size.y * power_value
	var pointer_color := _power_color(power_value, 1.0)
	draw_line(Vector2(inner.position.x - 9.0, pointer_y), Vector2(inner.end.x + 9.0, pointer_y), Color(1, 1, 1, 0.58), 2.0)
	draw_circle(Vector2(inner.get_center().x, pointer_y), 5.0, pointer_color)
	draw_string(font, Vector2(0.0, size.y - 2.0), "POWER", HORIZONTAL_ALIGNMENT_CENTER, size.x, 12, Color(1, 1, 1, 0.48))

func _draw_vertical_segment(rect: Rect2, from_t: float, to_t: float, color: Color, glow: Color) -> void:
	var y1 := rect.end.y - rect.size.y * from_t
	var y0 := rect.end.y - rect.size.y * to_t
	var segment := Rect2(rect.position.x, y0, rect.size.x, y1 - y0)
	draw_rect(segment.grow(3.0), glow, true)
	draw_rect(segment, color, true)

func _draw_vertical_zone_marker(rect: Rect2, t: float, color: Color) -> void:
	var y := rect.end.y - rect.size.y * t
	draw_dashed_line(Vector2(rect.end.x + 6.0, y), Vector2(rect.end.x + 28.0, y), color, 1.2, 4.0)

func _power_color(value: float, alpha: float) -> Color:
	if value < 0.40:
		return Color(0.0, 0.75, 1.0, alpha)
	if value < 0.70:
		return Color(0.3, 1.0, 0.2, alpha)
	if value < 0.85:
		return Color(0.9, 1.0, 0.0, alpha)
	return Color(1.0, 0.18, 0.08, alpha)
