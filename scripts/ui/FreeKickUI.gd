class_name FreeKickUI
extends CanvasLayer

const LEFT_SUPPORT_BOOT_TEXTURE := preload("res://assets/PumaAttacantoIZQ.png")

signal restart_requested
signal switch_foot_requested
signal next_spot_requested

class ModernScoreHud:
	extends Control

	var level := 1
	var goals := 0
	var attempts := 0
	var misses := 0
	var max_misses := 3
	var message := ""
	var fallback_text := ""
	var active_step := 0
	var _pulse := 0.0

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		set_process(true)

	func _process(delta: float) -> void:
		_pulse += delta
		queue_redraw()

	func set_stats(next_level: int, next_goals: int, next_attempts: int, next_misses: int, next_max_misses: int, next_message: String = "") -> void:
		level = max(1, next_level)
		goals = max(0, next_goals)
		attempts = max(0, next_attempts)
		misses = clampi(next_misses, 0, max(1, next_max_misses))
		max_misses = max(1, next_max_misses)
		message = next_message
		fallback_text = ""
		queue_redraw()

	func set_fallback_text(text: String) -> void:
		fallback_text = text
		message = text
		queue_redraw()

	func set_active_step(step: int) -> void:
		active_step = clampi(step, 0, 4)
		queue_redraw()

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		var font := get_theme_default_font()
		var glow := 0.55 + sin(_pulse * 2.4) * 0.16
		_draw_stadium_glass(rect, glow)

		var left_rect := Rect2(Vector2(46.0, 29.0), Vector2(238.0, 104.0))
		var center_rect := Rect2(Vector2(330.0, 29.0), Vector2(340.0, 104.0))
		var right_rect := Rect2(Vector2(728.0, 29.0), Vector2(248.0, 104.0))
		_draw_divider(Vector2(304.0, 26.0), Vector2(286.0, 136.0))
		_draw_divider(Vector2(705.0, 26.0), Vector2(723.0, 136.0))

		var effectiveness := 0.0 if attempts == 0 else float(goals) / float(attempts)
		_draw_level(font, left_rect)
		_draw_effectiveness(font, center_rect, effectiveness)
		_draw_misses(font, right_rect)

		_draw_stepper(font)
		var footer := "SCORE AT LEAST ONCE IN 3 TRIALS" if message == "" else message.to_upper()
		draw_string(font, Vector2(0.0, 170.0), footer, HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, Color(0.04, 0.86, 1.0, 0.95))

	func _draw_stadium_glass(rect: Rect2, glow: float) -> void:
		var poly := PackedVector2Array([
			Vector2(34.0, 0.0), Vector2(size.x - 34.0, 0.0), Vector2(size.x - 8.0, 8.0),
			Vector2(size.x, 28.0), Vector2(size.x, 122.0), Vector2(size.x - 16.0, 146.0),
			Vector2(size.x - 56.0, 162.0), Vector2(size.x - 312.0, 162.0), Vector2(size.x - 340.0, 180.0),
			Vector2(340.0, 180.0), Vector2(312.0, 162.0), Vector2(56.0, 162.0),
			Vector2(16.0, 146.0), Vector2(0.0, 122.0), Vector2(0.0, 28.0), Vector2(8.0, 8.0)
		])
		draw_colored_polygon(poly, Color(0.0, 0.008, 0.018, 0.78))
		draw_polyline(poly + PackedVector2Array([poly[0]]), Color(0.08, 0.82, 1.0, glow), 2.4, true)
		draw_polyline(PackedVector2Array([Vector2(28.0, 4.0), Vector2(174.0, 4.0), Vector2(188.0, 10.0)]), Color(0.0, 0.95, 1.0, 0.95), 3.0, true)
		draw_polyline(PackedVector2Array([Vector2(size.x - 188.0, 10.0), Vector2(size.x - 174.0, 4.0), Vector2(size.x - 28.0, 4.0)]), Color(0.0, 0.95, 1.0, 0.95), 3.0, true)
		draw_rect(Rect2(Vector2(56.0, 14.0), Vector2(size.x - 112.0, 1.0)), Color(0.55, 0.95, 1.0, 0.18), true)
		draw_rect(Rect2(Vector2(70.0, 132.0), Vector2(size.x - 140.0, 1.0)), Color(1.0, 1.0, 1.0, 0.10), true)

	func _draw_divider(a: Vector2, b: Vector2) -> void:
		draw_line(a, b, Color(1.0, 1.0, 1.0, 0.18), 1.8)
		draw_line(a + Vector2(2.0, 0.0), b + Vector2(2.0, 0.0), Color(0.0, 0.7, 1.0, 0.10), 1.0)

	func _draw_level(font: Font, rect: Rect2) -> void:
		draw_string(font, rect.position + Vector2(0.0, 21.0), "SET PIECE", HORIZONTAL_ALIGNMENT_LEFT, rect.size.x, 17, Color(1.0, 1.0, 1.0, 0.88))
		draw_string(font, rect.position + Vector2(0.0, 74.0), "%02d" % level, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x, 43, Color(0.08, 0.84, 1.0, 1.0))
		_draw_progress_bar(Rect2(rect.position + Vector2(0.0, 93.0), Vector2(210.0, 10.0)), clampf(float(level % 5) / 5.0, 0.18, 1.0), Color(0.04, 0.83, 1.0, 1.0))

	func _draw_effectiveness(font: Font, rect: Rect2, effectiveness: float) -> void:
		draw_string(font, rect.position + Vector2(0.0, 21.0), "CONVERSION", HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 17, Color(1.0, 1.0, 1.0, 0.88))
		var pct := "%d%%" % roundi(effectiveness * 100.0)
		var ratio := "%d/%d" % [goals, max(1, attempts)]
		draw_string(font, rect.position + Vector2(0.0, 74.0), pct, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x * 0.48, 43, Color(0.62, 1.0, 0.16, 1.0))
		draw_circle(rect.position + Vector2(rect.size.x * 0.50, 55.0), 4.0, Color(0.62, 1.0, 0.16, 1.0))
		draw_string(font, rect.position + Vector2(rect.size.x * 0.58, 74.0), ratio, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x * 0.42, 43, Color(1.0, 1.0, 1.0, 0.92))
		_draw_progress_bar(Rect2(rect.position + Vector2(0.0, 93.0), Vector2(rect.size.x, 10.0)), effectiveness, Color(0.62, 1.0, 0.16, 1.0))

	func _draw_misses(font: Font, rect: Rect2) -> void:
		draw_string(font, rect.position + Vector2(0.0, 21.0), "MISSES", HORIZONTAL_ALIGNMENT_LEFT, rect.size.x, 17, Color(1.0, 1.0, 1.0, 0.88))
		for i in range(max_misses):
			var center := rect.position + Vector2(24.0 + float(i) * 48.0, 59.0)
			var used := i < misses
			var fill := Color(1.0, 0.08, 0.04, 0.88) if used else Color(0.0, 0.0, 0.0, 0.20)
			var stroke := Color(1.0, 0.14, 0.08, 1.0) if used else Color(1.0, 1.0, 1.0, 0.55)
			draw_circle(center, 17.0, fill)
			draw_arc(center, 17.0, 0.0, TAU, 48, stroke, 2.2)
			if used:
				draw_arc(center, 23.0, 0.0, TAU, 48, Color(1.0, 0.08, 0.04, 0.26), 5.0)
		draw_string(font, rect.position + Vector2(174.0, 67.0), "%d / %d" % [misses, max_misses], HORIZONTAL_ALIGNMENT_LEFT, 74.0, 27, Color(1.0, 1.0, 1.0, 0.92))

	func _draw_progress_bar(rect: Rect2, value: float, accent: Color) -> void:
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0.65, 0.78, 0.86, 0.16)
		bg.border_color = Color(1.0, 1.0, 1.0, 0.24)
		bg.border_width_left = 1
		bg.border_width_top = 1
		bg.border_width_right = 1
		bg.border_width_bottom = 1
		bg.corner_radius_top_left = 5
		bg.corner_radius_top_right = 5
		bg.corner_radius_bottom_left = 5
		bg.corner_radius_bottom_right = 5
		draw_style_box(bg, rect)
		var fill_rect := Rect2(rect.position + Vector2(1.0, 1.0), Vector2(maxf(4.0, (rect.size.x - 2.0) * clampf(value, 0.0, 1.0)), rect.size.y - 2.0))
		var fill := StyleBoxFlat.new()
		fill.bg_color = accent
		fill.corner_radius_top_left = 4
		fill.corner_radius_top_right = 4
		fill.corner_radius_bottom_left = 4
		fill.corner_radius_bottom_right = 4
		draw_style_box(fill, fill_rect)

	func _draw_stepper(font: Font) -> void:
		var labels := ["1 POWER", "2 PLANT", "3 CONTACT", "SHOT"]
		var start_x := 204.0
		var y := 142.0
		var gap := 156.0
		for i in range(labels.size()):
			var step_index := i + 1
			var center := Vector2(start_x + float(i) * gap, y)
			var is_done := active_step > step_index
			var is_active := active_step == step_index
			var fill := Color(0.62, 1.0, 0.16, 0.92) if is_done else Color(0.04, 0.86, 1.0, 0.95) if is_active else Color(0.0, 0.0, 0.0, 0.30)
			var stroke := Color(0.9, 1.0, 1.0, 0.95) if is_active else Color(1.0, 1.0, 1.0, 0.28)
			draw_circle(center, 10.0, fill)
			draw_arc(center, 10.0, 0.0, TAU, 32, stroke, 1.4)
			if i < labels.size() - 1:
				var next_center := Vector2(start_x + float(i + 1) * gap, y)
				var line_color := Color(0.62, 1.0, 0.16, 0.72) if is_done else Color(1.0, 1.0, 1.0, 0.18)
				draw_line(center + Vector2(14.0, 0.0), next_center - Vector2(14.0, 0.0), line_color, 2.0)
			draw_string(font, center + Vector2(-50.0, 27.0), labels[i], HORIZONTAL_ALIGNMENT_CENTER, 100.0, 11, Color(1.0, 1.0, 1.0, 0.76))

@onready var power_label: Label = %PowerLabel
@onready var power_bar: ProgressBar = %PowerBar
@onready var power_meter: Control = %PowerMeterPanel
@onready var support_panel: SupportPlantPanel = %SupportPanel
@onready var support_marker: Control = %SupportMarker
@onready var ball_panel: BallContactPanel = %BallContactPanel
@onready var feedback_label: Label = %FeedbackLabel
@onready var instruction_label: Label = %InstructionLabel
@onready var status_label: Label = %StatusLabel
@onready var score_hud: Control = _create_score_hud()
@onready var restart_button: Button = %RestartButton
@onready var switch_foot_button: Button = %SwitchFootButton
@onready var next_spot_button: Button = %NextSpotButton

var kicking_foot := "right"
var support_marker_hint: Control
var support_zone_overlay: Control
var left_support_boot_texture: Texture2D
var support_zone_center := Vector2(640.0, 360.0)
var support_zone_radius := 150.0
var support_zone_marker_local := Vector2.ZERO
var support_zone_has_marker := false
var support_zone_aim_target := 0.0
var support_zone_show_angle := false

func _ready() -> void:
	left_support_boot_texture = LEFT_SUPPORT_BOOT_TEXTURE
	support_zone_overlay = _create_support_zone_overlay()
	support_marker_hint = _create_support_marker_hint()
	_apply_mvp_layout()
	_center_score_hud()
	restart_button.pressed.connect(func() -> void: restart_requested.emit())
	switch_foot_button.pressed.connect(func() -> void: switch_foot_requested.emit())
	next_spot_button.pressed.connect(func() -> void: next_spot_requested.emit())

func hide_all() -> void:
	power_label.visible = false
	power_bar.visible = false
	power_meter.visible = false
	support_panel.visible = false
	ball_panel.visible = false
	feedback_label.visible = false
	instruction_label.visible = true
	status_label.visible = true
	restart_button.visible = false
	switch_foot_button.visible = false
	next_spot_button.visible = false
	feedback_label.remove_theme_stylebox_override("normal")
	if support_marker_hint != null:
		support_marker_hint.visible = false
	if support_zone_overlay != null:
		support_zone_overlay.visible = false

func _set_active_step(step: int) -> void:
	if score_hud != null and score_hud.has_method("set_active_step"):
		score_hud.call("set_active_step", step)

func set_spot_label(label: String) -> void:
	if next_spot_button != null:
		next_spot_button.text = "Spot: %s" % label

func set_scoreboard(text: String) -> void:
	if score_hud != null and score_hud.has_method("set_fallback_text"):
		score_hud.call("set_fallback_text", text)

func set_run_hud(level: int, goals: int, attempts: int, misses: int, max_misses: int, message: String = "") -> void:
	if score_hud != null and score_hud.has_method("set_stats"):
		score_hud.call("set_stats", level, goals, attempts, misses, max_misses, message)

func _create_support_zone_overlay() -> Control:
	var root := get_node_or_null("Root") as Control
	var overlay := Control.new()
	overlay.name = "SupportZoneOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.draw.connect(func() -> void:
		var center := support_zone_center
		var radius := support_zone_radius
		var legal_side := -1.0 if kicking_foot == "right" else 1.0
		var legal_rect := Rect2(center + Vector2(-radius if legal_side < 0.0 else 0.0, -radius), Vector2(radius, radius * 2.0))
		var blocked_rect := Rect2(center + Vector2(0.0 if legal_side < 0.0 else -radius, -radius), Vector2(radius, radius * 2.0))
		overlay.draw_rect(blocked_rect, Color(1.0, 0.08, 0.04, 0.06), true)
		overlay.draw_rect(legal_rect, Color(0.2, 1.0, 0.45, 0.08), true)
		overlay.draw_arc(center, radius * 0.38, 0.0, TAU, 72, Color(0.3, 1.0, 0.35, 0.72), 2.0)
		overlay.draw_arc(center, radius * 0.68, 0.0, TAU, 72, Color(1.0, 0.85, 0.25, 0.36), 1.4)
		overlay.draw_line(center + Vector2(-radius, 0.0), center + Vector2(radius, 0.0), Color(1, 1, 1, 0.18), 1.0)
		overlay.draw_line(center + Vector2(0.0, -radius), center + Vector2(0.0, radius), Color(1, 1, 1, 0.14), 1.0)
		for lane in [-1, 0, 1]:
			var angle := deg_to_rad(float(lane) * 30.0)
			var end := center + Vector2.UP.rotated(angle) * radius * 0.92
			var color := Color(0.85, 0.9, 1.0, 0.24) if lane != 0 else Color(0.35, 0.9, 1.0, 0.58)
			overlay.draw_line(center, end, color, 2.0)
		if support_zone_has_marker:
			var marker := _support_marker_screen_position()
			overlay.draw_dashed_line(center, marker, Color(0.4, 1.0, 0.45, 0.7), 2.0, 6.0)
			overlay.draw_circle(marker, 14.0, Color(0.25, 1.0, 0.35, 0.24))
			overlay.draw_circle(marker, 6.0, Color(0.4, 1.0, 0.45, 0.95))
			if support_zone_show_angle:
				var aim_angle := deg_to_rad(support_zone_aim_target * 30.0)
				var aim_end := marker + Vector2.UP.rotated(aim_angle) * 62.0
				overlay.draw_line(marker, aim_end, Color(1.0, 0.86, 0.22, 0.95), 3.0)
				overlay.draw_circle(aim_end, 5.0, Color(1.0, 0.86, 0.22, 1.0))
				_draw_support_foot_indicator(overlay, marker, true, aim_angle)
		var side_text := "LEFT" if kicking_foot == "right" else "RIGHT"
		overlay.draw_string(overlay.get_theme_default_font(), center + Vector2(-96.0, radius + 28.0), "Plant zone: %s side - drag then aim" % side_text, HORIZONTAL_ALIGNMENT_CENTER, 192.0, 13, Color(1, 1, 1, 0.7))
	)
	if root != null:
		root.add_child(overlay)
	else:
		add_child(overlay)
	return overlay

func _create_support_marker_hint() -> Control:
	var root := get_node_or_null("Root") as Control
	var marker := Control.new()
	marker.name = "SupportMarkerHint"
	marker.size = Vector2(96.0, 96.0)
	marker.visible = false
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.draw.connect(func() -> void:
		var center := marker.size * 0.5
		var legal_color := Color(0.35, 1.0, 0.4, 0.88)
		var ghost_color := Color(1.0, 1.0, 1.0, 0.2)
		marker.draw_arc(center, 34.0, 0.0, TAU, 48, legal_color, 2.0)
		marker.draw_circle(center, 7.0, legal_color)
		marker.draw_line(center + Vector2(-22.0, 0.0), center + Vector2(22.0, 0.0), ghost_color, 1.0)
		marker.draw_line(center + Vector2(0.0, -22.0), center + Vector2(0.0, 22.0), ghost_color, 1.0)
		if support_zone_show_angle:
			_draw_support_foot_indicator(marker, center, true, deg_to_rad(support_zone_aim_target * 30.0))
		var label := "LEFT PLANT" if kicking_foot == "right" else "RIGHT PLANT"
		marker.draw_string(marker.get_theme_default_font(), Vector2(0.0, 88.0), label, HORIZONTAL_ALIGNMENT_CENTER, marker.size.x, 10, Color(1, 1, 1, 0.72))
	)
	if root != null:
		root.add_child(marker)
	else:
		add_child(marker)
	return marker

func _create_score_hud() -> Control:
	var root := get_node_or_null("Root") as Control
	var hud := ModernScoreHud.new()
	hud.name = "ModernScoreHud"
	hud.size = Vector2(980.0, 180.0)
	hud.scale = Vector2(0.88, 0.88)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if root != null:
		root.add_child(hud)
	else:
		add_child(hud)
	return hud

func _center_score_hud() -> void:
	if score_hud == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0:
		viewport_size = Vector2(1280.0, 720.0)
	var visual_size := score_hud.size * score_hud.scale
	score_hud.position = Vector2((viewport_size.x - visual_size.x) * 0.5, 20.0)

func set_kicking_foot(foot: String) -> void:
	kicking_foot = foot
	if power_meter != null:
		power_meter.kicking_foot = foot
	_position_power_meter_for_foot()

func _support_foot_for_kick(kicking_foot: String) -> String:
	return "left" if kicking_foot == "right" else "right"

func show_power_ready() -> void:
	hide_all()
	_set_active_step(1)
	_position_power_meter_for_foot()
	_show_primary_instruction("Choose kicking foot", "Tap left or right side, then hold to charge power.")
	set_status("POWER - choose kicking foot")

func show_power(power_value: float) -> void:
	_set_active_step(1)
	_position_power_meter_for_foot()
	power_label.visible = false
	power_meter.visible = true
	power_meter.power_value = power_value
	_show_primary_instruction("Hold power", _power_feedback(power_value))
	power_label.text = "%d%%" % roundi(power_value * 100.0)
	set_status("POWER - %s foot - release in the 70-85%% ideal zone" % kicking_foot.to_upper())

func show_support_foot_sector(selected_foot: String, _difficulty: FreeKickDifficulty) -> void:
	hide_all()
	_set_active_step(2)
	var support_foot := _support_foot_for_kick(selected_foot)
	power_label.visible = false
	power_meter.visible = false
	support_panel.visible = false
	support_marker.visible = false
	if support_zone_overlay != null:
		support_zone_overlay.visible = true
		support_zone_has_marker = false
		support_zone_show_angle = false
		support_zone_overlay.queue_redraw()
	_show_primary_instruction("Place support foot", "%s plant beside the ball. Release to lock position." % support_foot.capitalize())
	set_status("PLANT - support: %s - kicking: %s" % [support_foot, selected_foot])

func update_support_marker(local_pos: Vector2) -> void:
	if support_panel.visible:
		support_panel.set_marker(local_pos, true)
		support_marker.position = support_panel.size * 0.5 + local_pos - support_marker.size * 0.5
	support_zone_marker_local = local_pos
	support_zone_has_marker = true
	support_zone_show_angle = false
	if support_zone_overlay != null:
		support_zone_overlay.queue_redraw()
	if support_marker_hint != null:
		support_marker_hint.visible = true
		support_marker_hint.position = _support_hint_position(local_pos) - support_marker_hint.size * 0.5
		support_marker_hint.queue_redraw()
	var side := "LEFT of ball" if local_pos.x < 0.0 else "RIGHT of ball"
	var plant := "ahead/open" if local_pos.y < -18.0 else "behind/closed" if local_pos.y > 18.0 else "level/balanced"
	feedback_label.text = "Plant: %s - %s" % [side, plant]
	set_status("Plant %s - %s - release" % [side, plant])

func update_support_foot_angle(angle: float, aim_target: float = 0.0) -> void:
	if support_panel.visible:
		support_panel.set_substep_label("2/2: drag left/right to aim - +/-30 deg max")
		support_panel.set_foot_angle(angle, true, aim_target)
	support_zone_aim_target = clampf(aim_target, -1.0, 1.0)
	support_zone_show_angle = true
	if support_marker_hint != null:
		support_marker_hint.visible = true
		support_marker_hint.position = _support_marker_screen_position() - support_marker_hint.size * 0.5
		support_marker_hint.queue_redraw()
	if support_zone_overlay != null:
		support_zone_overlay.queue_redraw()
	var foot_offset := support_zone_aim_target * 30.0
	var target_label := "RIGHT POST" if aim_target > 0.25 else "LEFT POST" if aim_target < -0.25 else "CENTER"
	feedback_label.text = "Aim: %s - foot %+.0f deg" % [target_label, foot_offset]
	set_status("Aim %s - drag left/right, release to shoot setup" % target_label)

func show_ball_contact_ui() -> void:
	hide_all()
	_set_active_step(3)
	power_label.visible = false
	ball_panel.visible = true
	ball_panel.modulate = Color(1.0, 1.0, 1.0, 0.92)
	ball_panel.clear_swipe()
	_show_primary_instruction("Touch, then drag", "Contact point sets height. Follow-through sets curl.")
	set_status("CONTACT - foreground ball touch")

func update_ball_contact(points: PackedVector2Array) -> void:
	ball_panel.set_swipe_points(points)
	feedback_label.text = _ball_contact_feedback(points)
	set_status(_ball_contact_status(points))

func _ball_contact_feedback(points: PackedVector2Array) -> String:
	if points.is_empty():
		return "Ball contact: point and drag"
	var contact := points[0] / maxf(1.0, ball_panel.ball_radius_px)
	var height := "lift" if contact.y > 0.25 else "drive" if contact.y < -0.25 else "medium height"
	if points.size() < 2:
		return "Contact: %s - now drag follow-through" % height
	var follow := (points[points.size() - 1] - points[0]) / maxf(1.0, ball_panel.ball_radius_px)
	var curl_strength := absf(follow.x) + absf(contact.x) * 0.75
	var curl_side := "left" if follow.x < -0.12 else "right" if follow.x > 0.12 else "straight"
	var curl_label := "LOW" if curl_strength < 0.35 else "MEDIUM" if curl_strength < 0.85 else "HIGH"
	var length_label := "short" if follow.length() < 0.45 else "good" if follow.length() < 1.0 else "big"
	return "Contact: %s - curl: %s %s - follow-through: %s" % [height, curl_label, curl_side, length_label]

func _ball_contact_status(points: PackedVector2Array) -> String:
	if points.size() < 2:
		return "Step 3: hold on contact point, then drag"
	var follow := (points[points.size() - 1] - points[0]) / maxf(1.0, ball_panel.ball_radius_px)
	return "Step 3: sideways %.0f%% - length %.0f%% - release to shoot" % [absf(follow.x) * 100.0, follow.length() * 100.0]

func align_support_marker_hint(ball: Node3D, camera: Camera3D, selected_foot: String, world_offset: Vector2 = Vector2.ZERO) -> void:
	if ball == null or camera == null:
		return
	kicking_foot = selected_foot
	support_zone_center = camera.unproject_position(ball.global_position)
	var camera_right := camera.global_transform.basis.x.normalized()
	var radius_edge := camera.unproject_position(ball.global_position + camera_right * 1.05)
	support_zone_radius = clampf(absf(radius_edge.x - support_zone_center.x), 95.0, 190.0)
	if support_zone_has_marker:
		support_zone_marker_local = world_offset * support_zone_radius
	if support_zone_overlay != null and support_zone_overlay.visible:
		support_zone_overlay.queue_redraw()
	if support_marker_hint == null or not support_marker_hint.visible:
		return
	support_marker_hint.position = _support_marker_screen_position() - support_marker_hint.size * 0.5
	support_marker_hint.queue_redraw()

func _support_marker_screen_position() -> Vector2:
	return support_zone_center + support_zone_marker_local

func _draw_support_foot_indicator(canvas: CanvasItem, center: Vector2, active: bool = true, rotation: float = 0.0) -> void:
	var boot_size := Vector2(42.0, 76.0)
	var alpha := 1.0 if active else 0.55
	var mirror_scale := Vector2.ONE if kicking_foot == "right" else Vector2(-1.0, 1.0)
	canvas.draw_set_transform(center, rotation, mirror_scale)
	if left_support_boot_texture != null:
		canvas.draw_texture_rect(left_support_boot_texture, Rect2(-boot_size * 0.5, boot_size), false, Color(1.0, 1.0, 1.0, alpha))
	else:
		canvas.draw_rect(Rect2(-boot_size * 0.5, boot_size), Color(1.0, 1.0, 1.0, alpha), true)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _support_hint_position(local_pos: Vector2) -> Vector2:
	return support_zone_center + local_pos

func align_ball_contact_overlay(ball: Node3D, camera: Camera3D, world_radius: float = 0.11) -> void:
	if ball == null or camera == null or not ball_panel.visible:
		return
	var center := camera.unproject_position(ball.global_position)
	var camera_right := camera.global_transform.basis.x.normalized()
	var edge := camera.unproject_position(ball.global_position + camera_right * world_radius)
	var screen_radius := maxf(80.0, absf(edge.x - center.x) * 1.35)
	var diameter := screen_radius * 2.0
	ball_panel.size = Vector2(diameter, diameter)
	ball_panel.position = center - ball_panel.size * 0.5
	ball_panel.ball_radius_px = screen_radius
	ball_panel.queue_redraw()

func show_feedback(report: Resource, auto_restart_delay_seconds: float = 4.0) -> void:
	hide_all()
	_set_active_step(4)
	feedback_label.visible = true
	feedback_label.position = Vector2(24.0, 370.0)
	feedback_label.size = Vector2(760.0, 210.0)
	feedback_label.add_theme_font_size_override("font_size", 15)
	feedback_label.add_theme_stylebox_override("normal", _make_panel_style(Color(0.0, 0.0, 0.0, 0.34), Color(1.0, 1.0, 1.0, 0.14), 1, 6))
	instruction_label.visible = true
	instruction_label.text = "Auto restart in %.0fs" % auto_restart_delay_seconds
	if report != null and report.get("summary") != null:
		feedback_label.text = _format_feedback_report(report)
	else:
		feedback_label.text = "Shot complete"
	set_status("Auto restart")

func _format_feedback_report(report: Resource) -> String:
	var lines: Array[String] = []
	lines.append(String(report.get("summary")).to_upper())
	var power := float(report.get("power"))
	var elevation := float(report.get("elevation_angle"))
	var horizontal := float(report.get("horizontal_angle"))
	var spin_rate := float(report.get("spin_rate"))
	var curl_strength := String(report.get("curl_strength"))
	lines.append("Power: %s" % _power_feedback(power))
	if report.get("support_feedback") != null and String(report.get("support_feedback")) != "":
		lines.append("Plant: %s" % String(report.get("support_feedback")))
	if elevation > 28.0:
		lines.append("Contact: low strike added extra lift")
	elif elevation < 6.0:
		lines.append("Contact: high/central strike kept it flat")
	else:
		lines.append("Contact: usable launch height")
	if absf(horizontal) > 10.0:
		lines.append("Aim: large support-foot target offset")
	if spin_rate < 18.0 or curl_strength == "low":
		lines.append("Curl: low — add side contact or a longer sideways drag")
	else:
		lines.append("Curl: %s" % curl_strength)
	if report.get("coach_tip") != null and String(report.get("coach_tip")) != "":
		lines.append("Tip: %s" % String(report.get("coach_tip")))
	if report.get("peak_height") != null:
		lines.append("Data: peak %.1fm · flight %.1fs · aim %.1f°" % [float(report.get("peak_height")), float(report.get("total_flight_time")), horizontal])
	return "\n".join(lines)

func set_status(text: String) -> void:
	status_label.text = text

func _show_primary_instruction(action: String, consequence: String) -> void:
	instruction_label.visible = true
	feedback_label.visible = true
	instruction_label.text = action
	feedback_label.text = consequence

func _power_feedback(power_value: float) -> String:
	if power_value < 0.40:
		return "low — hold longer for distance"
	if power_value < 0.70:
		return "controlled — keep charging toward ideal"
	if power_value <= 0.85:
		return "ideal window — release now"
	return "risk — extra power reduces precision"

func _apply_mvp_layout() -> void:
	var root := get_node_or_null("Root") as Control
	if root != null:
		root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	power_label.position = Vector2(24.0, 20.0)
	power_label.size = Vector2(110.0, 38.0)
	power_label.add_theme_font_size_override("font_size", 26)
	power_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.9))
	power_bar.visible = false
	power_bar.position = Vector2(24.0, 64.0)
	power_bar.size = Vector2(260.0, 6.0)
	power_meter.size = Vector2(150.0, 320.0)
	power_meter.kicking_foot = kicking_foot
	_position_power_meter_for_foot()
	feedback_label.position = Vector2(24.0, 304.0)
	feedback_label.size = Vector2(520.0, 58.0)
	feedback_label.add_theme_font_size_override("font_size", 15)
	feedback_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.82))
	instruction_label.position = Vector2(24.0, 676.0)
	instruction_label.size = Vector2(760.0, 28.0)
	instruction_label.add_theme_font_size_override("font_size", 20)
	instruction_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.9))
	instruction_label.remove_theme_stylebox_override("normal")
	status_label.position = Vector2(24.0, 642.0)
	status_label.size = Vector2(520.0, 24.0)
	status_label.add_theme_font_size_override("font_size", 12)
	status_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.28))
	status_label.remove_theme_stylebox_override("normal")
	_style_button(restart_button, Vector2(24.0, 586.0), Vector2(158.0, 40.0), "Restart  R")
	restart_button.visible = false
	_style_button(switch_foot_button, Vector2(24.0, 594.0), Vector2(128.0, 32.0), "Foot  F")
	switch_foot_button.visible = false
	_style_button(next_spot_button, Vector2(214.0, 586.0), Vector2(196.0, 40.0), next_spot_button.text)
	next_spot_button.visible = false

func align_power_meter_to_ball(ball: Node3D, camera: Camera3D) -> void:
	if ball == null or camera == null or power_meter == null:
		_position_power_meter_for_foot()
		return
	var ball_screen := camera.unproject_position(ball.global_position)
	var side := 1.0 if kicking_foot == "right" else -1.0
	var desired := ball_screen + Vector2(side * 145.0, -170.0)
	var viewport_size := get_viewport().get_visible_rect().size
	var x := clampf(desired.x - power_meter.size.x * 0.5, 18.0, viewport_size.x - power_meter.size.x - 18.0)
	var y := clampf(desired.y, 80.0, viewport_size.y - power_meter.size.y - 72.0)
	power_meter.position = Vector2(x, y)
	if power_label != null:
		power_label.position = Vector2(x, y - 46.0)

func _position_power_meter_for_foot() -> void:
	if power_meter == null:
		return
	var viewport_width := get_viewport().get_visible_rect().size.x
	if viewport_width <= 0.0:
		viewport_width = 1280.0
	var center_x := viewport_width * 0.5
	var side := 1.0 if kicking_foot == "right" else -1.0
	var x := clampf(center_x + side * 145.0 - power_meter.size.x * 0.5, 18.0, viewport_width - power_meter.size.x - 18.0)
	power_meter.position = Vector2(x, 250.0)
	if power_label != null:
		power_label.position = Vector2(x, 204.0)

func _style_button(button: Button, pos: Vector2, size_value: Vector2, text_value: String) -> void:
	button.position = pos
	button.size = size_value
	button.text = text_value
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.78))
	button.add_theme_stylebox_override("normal", _make_panel_style(Color(0.0, 0.0, 0.0, 0.28), Color(1.0, 1.0, 1.0, 0.18), 1, 6))
	button.add_theme_stylebox_override("hover", _make_panel_style(Color(1.0, 1.0, 1.0, 0.10), Color(1.0, 1.0, 1.0, 0.42), 1, 6))
	button.add_theme_stylebox_override("pressed", _make_panel_style(Color(1.0, 1.0, 1.0, 0.16), Color(1.0, 0.86, 0.25, 0.72), 1, 6))

func _make_panel_style(bg: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = 14
	style.content_margin_top = 10
	style.content_margin_right = 14
	style.content_margin_bottom = 10
	return style

func _update_power_bar_color(power_value: float) -> void:
	var fill := power_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill == null:
		fill = StyleBoxFlat.new()
		power_bar.add_theme_stylebox_override("fill", fill)
	if power_value < 0.72:
		fill.bg_color = Color(0.25, 0.95, 0.35, 1.0)
	elif power_value < 0.85:
		fill.bg_color = Color(1.0, 0.75, 0.18, 1.0)
	else:
		fill.bg_color = Color(1.0, 0.18, 0.12, 1.0)

func get_support_control() -> Control:
	return support_panel

func get_ball_contact_control() -> Control:
	return ball_panel
