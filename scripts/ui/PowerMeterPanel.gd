class_name PowerMeterPanel
extends Control

const BOOT_TEXTURE := preload("res://assets/PumaAttacantoIZQ.png")

@export_enum("right", "left") var kicking_foot: String = "right":
	set(value):
		kicking_foot = value
		queue_redraw()

@export var power_value: float = 0.0:
	set(value):
		power_value = clampf(value, 0.0, 1.0)
		queue_redraw()

const OPTIMAL_MIN := 0.70
const OPTIMAL_MAX := 0.85

var boot_texture: Texture2D = BOOT_TEXTURE


func _draw() -> void:
	var font := get_theme_default_font()
	# Touch-friendly sizing: bar width and boot scale are relative to the control
	# height so the widget stays readable on narrow phone screens.
	var bar_width := maxf(52.0, size.y * 0.17)
	var boot_scale := (bar_width / 28.0) * 0.9
	var boot_size := Vector2(58.0, 106.0) * boot_scale
	var boot_rect := Rect2(Vector2.ZERO, boot_size)
	var bar_rect := Rect2(Vector2.ZERO, Vector2(bar_width, size.y - 24.0))
	# Zone labels live on the side OPPOSITE the boot so the moving boot never
	# covers them: right-foot kick -> labels on the left, left-foot -> labels right.
	var labels_on_left := kicking_foot == "right"
	# Linear layout: [labels][bar][boot] for right foot, [boot][bar][labels] for left.
	# Bar is anchored to the side of the labels so nothing overlaps.
	var bar_x: float
	if labels_on_left:
		bar_x = 8.0 + 96.0 + 12.0
	else:
		bar_x = 12.0 + boot_size.x + 16.0
	bar_rect.position = Vector2(bar_x, 12.0)

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
		var w := maxf(15.0, bar_width * 0.55) if i % 5 == 0 else maxf(8.0, bar_width * 0.3)
		draw_line(Vector2(inner.position.x, y), Vector2(inner.position.x + w, y), Color(1, 1, 1, 0.34), 1.0)
		draw_line(Vector2(inner.end.x - w, y), Vector2(inner.end.x, y), Color(1, 1, 1, 0.24), 1.0)

	_draw_vertical_zone_marker(inner, OPTIMAL_MIN, Color(0.6, 1.0, 0.0, 0.88), labels_on_left)
	_draw_vertical_zone_marker(inner, OPTIMAL_MAX, Color(1.0, 0.2, 0.1, 0.88), labels_on_left)
	# Ideal window grooves across the bar: shape + color, never color alone (accessibility).
	var notch_color := Color(1.0, 1.0, 1.0, 0.55)
	for frac: float in [OPTIMAL_MIN, OPTIMAL_MAX]:
		var notch_y := inner.end.y - inner.size.y * frac
		draw_line(Vector2(inner.position.x - 5.0, notch_y), Vector2(inner.position.x + bar_width + 5.0, notch_y), notch_color, 1.6)
	_draw_zone_label(inner, 0.20, "LOW", Color(0.0, 0.75, 1.0, 0.9), font, labels_on_left)
	_draw_zone_label(inner, 0.55, "CONTROL", Color(0.55, 1.0, 0.25, 0.9), font, labels_on_left)
	_draw_zone_label(inner, 0.775, "IDEAL", Color(1.0, 0.92, 0.0, 0.95), font, labels_on_left)
	_draw_zone_label(inner, 0.925, "RISK", Color(1.0, 0.22, 0.08, 0.95), font, labels_on_left)

	var pointer_y := inner.end.y - inner.size.y * power_value
	var pointer_color := _power_color(power_value, 1.0)
	draw_line(Vector2(inner.position.x - 9.0, pointer_y), Vector2(inner.end.x + 9.0, pointer_y), Color(1, 1, 1, 0.58), 2.0)
	draw_circle(Vector2(inner.get_center().x, pointer_y), maxf(5.0, bar_width * 0.2), pointer_color)

	# The boot travels the FULL panel bottom-to-top as power goes 0% -> 100%:
	# at 0% it sits at the base, at 100% it reaches the top, moving throughout the
	# whole travel instead of clamping partway.
	var boot_bottom_y := size.y - boot_rect.size.y - 8.0
	var boot_top_y := 8.0
	var boot_y := lerpf(boot_bottom_y, boot_top_y, power_value)
	if kicking_foot == "right":
		# Boot follows the bar on the right, keeping the linear labels/bar/boot layout.
		boot_rect.position = Vector2(bar_rect.end.x + 12.0, boot_y)
	else:
		boot_rect.position = Vector2(12.0, boot_y)
	_draw_kicking_boot(boot_rect)
	_draw_power_value_label(boot_rect, pointer_y, pointer_color)
	draw_string(font, Vector2(0.0, size.y - 2.0), "%s FOOT  -  POWER" % kicking_foot.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, size.x, maxf(12.0, size.y * 0.05), Color(1, 1, 1, 0.48))

func _draw_power_value_label(boot_rect: Rect2, pointer_y: float, color: Color) -> void:
	var font := get_theme_default_font()
	var label_size := Vector2(maxf(56.0, boot_rect.size.x * 0.9), 28.0)
	var x := boot_rect.position.x - label_size.x - 6.0 if kicking_foot == "right" else boot_rect.end.x + 6.0
	var y := clampf(pointer_y - label_size.y * 0.5, 8.0, size.y - label_size.y - 8.0)
	var rect := Rect2(Vector2(x, y), label_size)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.0, 0.0, 0.0, 0.42)
	bg.border_color = color
	bg.border_width_left = 1
	bg.border_width_top = 1
	bg.border_width_right = 1
	bg.border_width_bottom = 1
	bg.corner_radius_top_left = 8
	bg.corner_radius_top_right = 8
	bg.corner_radius_bottom_left = 8
	bg.corner_radius_bottom_right = 8
	draw_style_box(bg, rect)
	draw_string(font, rect.position + Vector2(0.0, 20.0), "%d%%" % roundi(power_value * 100.0), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 18, Color(1.0, 1.0, 1.0, 0.92))

func _draw_kicking_boot(rect: Rect2) -> void:
	var center := rect.get_center()
	var scale := Vector2(-1.0, 1.0) if kicking_foot == "right" else Vector2.ONE
	draw_set_transform(center, 0.0, scale)
	var local_rect := Rect2(-rect.size * 0.5, rect.size)
	if boot_texture != null:
		draw_texture_rect(boot_texture, local_rect, false, Color(1.0, 1.0, 1.0, 0.96))
	else:
		draw_rect(local_rect, Color(1.0, 1.0, 1.0, 0.7), true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_vertical_segment(rect: Rect2, from_t: float, to_t: float, color: Color, glow: Color) -> void:
	var y1 := rect.end.y - rect.size.y * from_t
	var y0 := rect.end.y - rect.size.y * to_t
	var segment := Rect2(rect.position.x, y0, rect.size.x, y1 - y0)
	draw_rect(segment.grow(3.0), glow, true)
	draw_rect(segment, color, true)

func _draw_vertical_zone_marker(rect: Rect2, t: float, color: Color, on_left: bool) -> void:
	var y := rect.end.y - rect.size.y * t
	if on_left:
		draw_dashed_line(Vector2(rect.position.x - 34.0, y), Vector2(rect.position.x - 6.0, y), color, 1.2, 4.0)
	else:
		draw_dashed_line(Vector2(rect.end.x + 6.0, y), Vector2(rect.end.x + 34.0, y), color, 1.2, 4.0)

func _draw_zone_label(rect: Rect2, t: float, label: String, color: Color, font: Font, on_left: bool) -> void:
	var y := rect.end.y - rect.size.y * t + 5.0
	if on_left:
		var text_x := rect.position.x - 104.0
		draw_string(font, Vector2(text_x, y), label, HORIZONTAL_ALIGNMENT_RIGHT, 96.0, 12, color)
	else:
		var text_x := rect.end.x + 40.0
		draw_string(font, Vector2(text_x, y), label, HORIZONTAL_ALIGNMENT_LEFT, 96.0, 12, color)

func _power_color(value: float, alpha: float) -> Color:
	if value < 0.40:
		return Color(0.0, 0.75, 1.0, alpha)
	if value < 0.70:
		return Color(0.3, 1.0, 0.2, alpha)
	if value < 0.85:
		return Color(0.9, 1.0, 0.0, alpha)
	return Color(1.0, 0.18, 0.08, alpha)
