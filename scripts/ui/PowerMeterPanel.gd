class_name PowerMeterPanel
extends Control

const BOOT_TEXTURE_PATH := "res://assets/PumaAttacantoIZQ.png"

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

var boot_texture: Texture2D

func _ready() -> void:
	boot_texture = _load_texture_from_png(BOOT_TEXTURE_PATH)

func _draw() -> void:
	var font := get_theme_default_font()
	var boot_rect := Rect2(Vector2.ZERO, Vector2(58.0, 106.0))
	var bar_rect := Rect2(Vector2.ZERO, Vector2(28.0, size.y - 24.0))
	if kicking_foot == "right":
		bar_rect.position = Vector2(18.0, 12.0)
	else:
		bar_rect.position = Vector2(size.x - bar_rect.size.x - 18.0, 12.0)

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

	var boot_y := clampf(pointer_y - boot_rect.size.y * 0.5, 8.0, size.y - boot_rect.size.y - 24.0)
	if kicking_foot == "right":
		boot_rect.position = Vector2(size.x - boot_rect.size.x - 8.0, boot_y)
	else:
		boot_rect.position = Vector2(8.0, boot_y)
	_draw_kicking_boot(boot_rect)
	_draw_power_value_label(boot_rect, pointer_y, pointer_color)
	draw_string(font, Vector2(0.0, size.y - 2.0), "%s FOOT  ·  POWER" % kicking_foot.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, size.x, 12, Color(1, 1, 1, 0.48))

func _draw_power_value_label(boot_rect: Rect2, pointer_y: float, color: Color) -> void:
	var font := get_theme_default_font()
	var label_size := Vector2(48.0, 24.0)
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
	draw_string(font, rect.position + Vector2(0.0, 17.0), "%d%%" % roundi(power_value * 100.0), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 14, Color(1.0, 1.0, 1.0, 0.92))

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

func _load_texture_from_png(path: String) -> Texture2D:
	var image := Image.new()
	var error := image.load(path)
	if error != OK:
		push_warning("Could not load power foot texture: %s" % path)
		return null
	return ImageTexture.create_from_image(image)

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
