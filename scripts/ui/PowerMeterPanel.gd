class_name PowerMeterPanel
extends Control

@export var power_value: float = 0.0:
	set(value):
		power_value = clampf(value, 0.0, 1.0)
		queue_redraw()

const OPTIMAL_MIN := 0.70
const OPTIMAL_MAX := 0.85

func _draw() -> void:
	var bar_rect := Rect2(0.0, 34.0, size.x, 42.0)
	var radius := 21
	var font := get_theme_default_font()

	# Outer neon shell.
	var shell := StyleBoxFlat.new()
	shell.bg_color = Color(0.015, 0.025, 0.035, 0.72)
	shell.border_color = Color(0.1, 0.85, 1.0, 0.95)
	shell.border_width_left = 2
	shell.border_width_top = 2
	shell.border_width_right = 2
	shell.border_width_bottom = 2
	shell.corner_radius_top_left = radius
	shell.corner_radius_top_right = radius
	shell.corner_radius_bottom_left = radius
	shell.corner_radius_bottom_right = radius
	draw_style_box(shell, bar_rect.grow(7.0))

	var inner := bar_rect.grow(-5.0)
	_draw_segment(inner, 0.0, 0.40, Color(0.0, 0.75, 1.0, 0.92), Color(0.0, 0.95, 1.0, 0.35))
	_draw_segment(inner, 0.40, 0.70, Color(0.25, 1.0, 0.25, 0.92), Color(0.55, 1.0, 0.0, 0.35))
	_draw_segment(inner, 0.70, 0.85, Color(1.0, 0.92, 0.0, 0.95), Color(1.0, 0.65, 0.0, 0.35))
	_draw_segment(inner, 0.85, 1.0, Color(1.0, 0.16, 0.08, 0.95), Color(1.0, 0.35, 0.16, 0.35))

	# Fill mask/glow for current power.
	var fill_width := inner.size.x * power_value
	if fill_width > 0.0:
		var fill_rect := Rect2(inner.position, Vector2(fill_width, inner.size.y))
		draw_rect(fill_rect.grow(4.0), _power_color(power_value, 0.25), true)
		draw_rect(fill_rect, _power_color(power_value, 0.88), true)

	# Tick marks.
	for i in range(0, 21):
		var t := float(i) / 20.0
		var x := inner.position.x + inner.size.x * t
		var h := 20.0 if i % 5 == 0 else 10.0
		draw_line(Vector2(x, inner.position.y), Vector2(x, inner.position.y + h), Color(1, 1, 1, 0.42), 1.0)
		draw_line(Vector2(x, inner.end.y - h), Vector2(x, inner.end.y), Color(1, 1, 1, 0.30), 1.0)

	# Optimal zone brackets.
	_draw_zone_marker(inner, OPTIMAL_MIN, Color(0.6, 1.0, 0.0, 0.95), "70%")
	_draw_zone_marker(inner, OPTIMAL_MAX, Color(1.0, 0.2, 0.1, 0.95), "85%")

	# Current pointer.
	var pointer_x := inner.position.x + inner.size.x * power_value
	var pointer_color := _power_color(power_value, 1.0)
	var tri := PackedVector2Array([
		Vector2(pointer_x, bar_rect.position.y - 10.0),
		Vector2(pointer_x - 13.0, bar_rect.position.y - 30.0),
		Vector2(pointer_x + 13.0, bar_rect.position.y - 30.0),
	])
	draw_colored_polygon(tri, pointer_color)
	draw_line(Vector2(pointer_x, inner.position.y - 5.0), Vector2(pointer_x, inner.end.y + 5.0), Color(1, 1, 1, 0.58), 2.0)

	var percent := "%d%%" % roundi(power_value * 100.0)
	draw_string(font, Vector2(pointer_x - 38.0, 22.0), percent, HORIZONTAL_ALIGNMENT_CENTER, 76.0, 28, pointer_color)
	draw_string(font, Vector2(0.0, 112.0), "0–40% CONTROL", HORIZONTAL_ALIGNMENT_LEFT, 220.0, 15, Color(0.0, 0.75, 1.0, 1.0))
	draw_string(font, Vector2(size.x * 0.5 - 115.0, 112.0), "70–85% OPTIMAL", HORIZONTAL_ALIGNMENT_CENTER, 230.0, 15, Color(0.5, 1.0, 0.1, 1.0))
	draw_string(font, Vector2(size.x - 230.0, 112.0), "85–100% RISK", HORIZONTAL_ALIGNMENT_RIGHT, 230.0, 15, Color(1.0, 0.25, 0.12, 1.0))

func _draw_segment(rect: Rect2, from_t: float, to_t: float, color: Color, glow: Color) -> void:
	var x0 := rect.position.x + rect.size.x * from_t
	var x1 := rect.position.x + rect.size.x * to_t
	var segment := Rect2(x0, rect.position.y, x1 - x0, rect.size.y)
	draw_rect(segment.grow(3.0), glow, true)
	draw_rect(segment, color, true)

func _draw_zone_marker(rect: Rect2, t: float, color: Color, label: String) -> void:
	var x := rect.position.x + rect.size.x * t
	draw_dashed_line(Vector2(x, rect.end.y + 4.0), Vector2(x, rect.end.y + 52.0), color, 1.5, 5.0)
	draw_string(get_theme_default_font(), Vector2(x - 28.0, rect.end.y + 72.0), label, HORIZONTAL_ALIGNMENT_CENTER, 56.0, 14, color)

func _power_color(value: float, alpha: float) -> Color:
	if value < 0.40:
		return Color(0.0, 0.75, 1.0, alpha)
	if value < 0.70:
		return Color(0.3, 1.0, 0.2, alpha)
	if value < 0.85:
		return Color(0.9, 1.0, 0.0, alpha)
	return Color(1.0, 0.18, 0.08, alpha)
