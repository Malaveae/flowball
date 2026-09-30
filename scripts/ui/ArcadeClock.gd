class_name ArcadeClock
extends Control

var remaining := 0.0
var duration := 1.0
var phase := 2

func set_time(seconds: float, total: float) -> void:
	duration = maxf(total, 0.001)
	remaining = clampf(seconds, 0.0, duration)
	queue_redraw()

func _draw() -> void:
	var fraction := remaining / duration
	var accent := HudTheme.GREEN_SUCCESS if phase == 2 else HudTheme.YELLOW
	if fraction <= 0.25:
		accent = HudTheme.ORANGE
	var center := size * 0.5
	draw_circle(center, 30.0, HudTheme.BG_GLASS_DEEP)
	draw_arc(center, 26.0, PI * 0.75, PI * 2.25, 48, HudTheme.NAVY_LIGHT, 4.0, true)
	if fraction > 0.0:
		draw_arc(center, 26.0, PI * 0.75, PI * 0.75 + PI * 1.5 * fraction, 48, accent, 4.0, true)
	draw_string(get_theme_default_font(), center + Vector2(-24.0, 7.0), "%.1f" % remaining, HORIZONTAL_ALIGNMENT_CENTER, 48.0, 23, HudTheme.TEXT_PRIMARY)
