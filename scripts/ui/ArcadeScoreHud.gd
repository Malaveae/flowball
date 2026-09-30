class_name ArcadeScoreHud
extends Control

const LOGO := preload("res://assets/ui/tv_arcade/flowball.svg")
var level := 1
var goals := 0
var attempts := 0
var misses := 0
var max_misses := 3

func set_stats(next_level: int, next_goals: int, next_attempts: int, next_misses: int, next_max: int, _message: String = "") -> void:
	level = next_level
	goals = next_goals
	attempts = next_attempts
	misses = next_misses
	max_misses = next_max
	queue_redraw()

func _draw() -> void:
	# Broadcast silhouette: compact wings and a dropped center for statistics.
	var frame := PackedVector2Array([Vector2(16, 0), Vector2(884, 0), Vector2(900, 16), Vector2(890, 48), Vector2(876, 54), Vector2(585, 54), Vector2(557, 82), Vector2(343, 82), Vector2(315, 54), Vector2(20, 54), Vector2(5, 47), Vector2(0, 18), Vector2(16, 0)])
	draw_colored_polygon(frame, Color("060e29"))
	for width in [9.0, 5.0]:
		draw_polyline(frame, Color(0.0, 0.30, 1.0, 0.16), width, true)
	draw_polyline(frame, HudTheme.CYAN_BRIGHT, 1.8, true)
	var inner := PackedVector2Array([Vector2(20, 5), Vector2(879, 5), Vector2(893, 18), Vector2(884, 44), Vector2(874, 49)])
	draw_polyline(inner, HudTheme.CYAN_FRAME, 1.2, true)
	draw_line(Vector2(23, 49), Vector2(310, 49), HudTheme.CYAN_FRAME, 1.2, true)
	draw_line(Vector2(13, 18), Vector2(24, 7), HudTheme.TEXT_PRIMARY, 2, true)
	draw_line(Vector2(12, 20), Vector2(20, 40), HudTheme.CYAN_BRIGHT, 3, true)
	var font := HudTheme.DISPLAY_FONT
	draw_line(Vector2(270, 10), Vector2(262, 43), HudTheme.BLUE, 2)
	draw_line(Vector2(642, 10), Vector2(650, 43), HudTheme.BLUE, 2)
	draw_string(font, Vector2(40, 32), "TIRO DE FALTA", HORIZONTAL_ALIGNMENT_LEFT, 140, 19, HudTheme.TEXT_PRIMARY)
	draw_string(font, Vector2(188, 43), "%02d" % level, HORIZONTAL_ALIGNMENT_LEFT, 65, 48, HudTheme.CYAN_BRIGHT)
	draw_texture_rect(LOGO, Rect2(302, 9, 302, 38), false)
	var percent := 0 if attempts == 0 else roundi(100.0 * goals / attempts)
	draw_string(font, Vector2(344, 73), "%d%%" % percent, HORIZONTAL_ALIGNMENT_CENTER, 85, 32, HudTheme.ORANGE)
	draw_circle(Vector2(450, 63), 4.0, HudTheme.TEXT_PRIMARY)
	draw_string(font, Vector2(471, 73), "%d/%d" % [goals, attempts], HORIZONTAL_ALIGNMENT_CENTER, 85, 32, HudTheme.TEXT_PRIMARY)
	draw_string(font, Vector2(670, 32), "FALLOS", HORIZONTAL_ALIGNMENT_LEFT, 80, 19, HudTheme.TEXT_PRIMARY)
	for i in range(max_misses):
		var point := Vector2(772 + i * 39, 27)
		if i < misses:
			draw_circle(point, 15, HudTheme.ORANGE)
		draw_arc(point, 15, 0, TAU, 40, HudTheme.ORANGE, 1.6, true)
