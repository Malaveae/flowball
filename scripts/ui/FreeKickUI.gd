class_name FreeKickUI
extends CanvasLayer

const LEFT_SUPPORT_BOOT_TEXTURE_PATH := "res://assets/PumaAttacantoIZQ.png"

signal restart_requested
signal switch_foot_requested
signal next_spot_requested

@onready var power_label: Label = %PowerLabel
@onready var power_bar: ProgressBar = %PowerBar
@onready var power_meter: Control = %PowerMeterPanel
@onready var support_panel: SupportPlantPanel = %SupportPanel
@onready var support_marker: Control = %SupportMarker
@onready var ball_panel: BallContactPanel = %BallContactPanel
@onready var feedback_label: Label = %FeedbackLabel
@onready var instruction_label: Label = %InstructionLabel
@onready var status_label: Label = %StatusLabel
@onready var score_label: Label = _create_score_label()
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
	left_support_boot_texture = _load_texture_from_png(LEFT_SUPPORT_BOOT_TEXTURE_PATH)
	support_zone_overlay = _create_support_zone_overlay()
	support_marker_hint = _create_support_marker_hint()
	_apply_mvp_layout()
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

func set_spot_label(label: String) -> void:
	if next_spot_button != null:
		next_spot_button.text = "Spot: %s" % label

func set_scoreboard(text: String) -> void:
	if score_label != null:
		score_label.text = text

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
		overlay.draw_string(overlay.get_theme_default_font(), center + Vector2(-96.0, radius + 28.0), "Plant zone: %s side · drag then aim" % side_text, HORIZONTAL_ALIGNMENT_CENTER, 192.0, 13, Color(1, 1, 1, 0.7))
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

func _create_score_label() -> Label:
	var root := get_node_or_null("Root") as Control
	var label := Label.new()
	label.name = "ScoreLabel"
	label.position = Vector2(760.0, 20.0)
	label.size = Vector2(420.0, 70.0)
	label.text = "SPOT 1/7  ·  GOALS 0  ·  ATTEMPTS 0\nCenter 24m  ·  THIS SPOT 0"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.66))
	if root != null:
		root.add_child(label)
	else:
		add_child(label)
	return label

func set_kicking_foot(foot: String) -> void:
	kicking_foot = foot
	if power_meter != null:
		power_meter.kicking_foot = foot
	_position_power_meter_for_foot()

func _support_foot_for_kick(kicking_foot: String) -> String:
	return "left" if kicking_foot == "right" else "right"

func show_power_ready() -> void:
	hide_all()
	instruction_label.visible = true
	instruction_label.text = "Touch left for left foot · touch right for right foot"
	set_status("POWER · choose kicking foot by screen side")

func show_power(power_value: float) -> void:
	_position_power_meter_for_foot()
	power_label.visible = true
	power_meter.visible = true
	instruction_label.visible = true
	instruction_label.text = "Hold · release at 70–85%"
	power_label.text = "%d%%" % roundi(power_value * 100.0)
	power_meter.power_value = power_value
	set_status("POWER · %s foot · charge into the optimal zone, then release" % kicking_foot.to_upper())

func show_support_foot_sector(selected_foot: String, _difficulty: FreeKickDifficulty) -> void:
	hide_all()
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
	feedback_label.visible = true
	instruction_label.visible = true
	instruction_label.text = "Zenith view · place %s foot beside the real ball" % support_foot
	feedback_label.text = "Plant foot"
	set_status("PLANT · support: %s · kicking: %s" % [support_foot, selected_foot])

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
	feedback_label.text = "Plant: %s · %s" % [side, plant]
	set_status("Plant %s · %s · release" % [side, plant])

func update_support_foot_angle(angle: float, aim_target: float = 0.0) -> void:
	if support_panel.visible:
		support_panel.set_substep_label("2/2: drag left/right to aim · ±30° max")
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
	feedback_label.text = "Aim: %s · foot %+.0f°" % [target_label, foot_offset]
	set_status("Aim %s · drag left/right, release to shoot setup" % target_label)

func show_ball_contact_ui() -> void:
	hide_all()
	power_label.visible = true
	ball_panel.visible = true
	ball_panel.modulate = Color(1.0, 1.0, 1.0, 0.92)
	ball_panel.clear_swipe()
	feedback_label.visible = true
	instruction_label.visible = true
	instruction_label.text = "Touch · drag through ball"
	feedback_label.text = "Ball contact"
	set_status("CONTACT · foreground ball touch")

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
		return "Contact: %s · now drag follow-through" % height
	var follow := (points[points.size() - 1] - points[0]) / maxf(1.0, ball_panel.ball_radius_px)
	var curl_strength := absf(follow.x) + absf(contact.x) * 0.75
	var curl_side := "left" if follow.x < -0.12 else "right" if follow.x > 0.12 else "straight"
	var curl_label := "LOW" if curl_strength < 0.35 else "MEDIUM" if curl_strength < 0.85 else "HIGH"
	var length_label := "short" if follow.length() < 0.45 else "good" if follow.length() < 1.0 else "big"
	return "Contact: %s · curl: %s %s · follow-through: %s" % [height, curl_label, curl_side, length_label]

func _ball_contact_status(points: PackedVector2Array) -> String:
	if points.size() < 2:
		return "Step 3: hold on contact point, then drag"
	var follow := (points[points.size() - 1] - points[0]) / maxf(1.0, ball_panel.ball_radius_px)
	return "Step 3: sideways %.0f%% · length %.0f%% · release to shoot" % [absf(follow.x) * 100.0, follow.length() * 100.0]

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

func _load_texture_from_png(path: String) -> Texture2D:
	var image := Image.new()
	var error := image.load(path)
	if error != OK:
		push_warning("Could not load support foot texture: %s" % path)
		return null
	return ImageTexture.create_from_image(image)

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
	feedback_label.visible = true
	feedback_label.position = Vector2(24.0, 370.0)
	feedback_label.size = Vector2(680.0, 150.0)
	feedback_label.add_theme_font_size_override("font_size", 16)
	feedback_label.add_theme_stylebox_override("normal", _make_panel_style(Color(0.0, 0.0, 0.0, 0.34), Color(1.0, 1.0, 1.0, 0.14), 1, 6))
	instruction_label.visible = true
	instruction_label.text = "Auto restart in %.0fs" % auto_restart_delay_seconds
	if report != null and report.get("summary") != null:
		feedback_label.text = String(report.get("summary"))
		if report.get("support_feedback") != null and String(report.get("support_feedback")) != "":
			feedback_label.text += "\nPlant: %s" % String(report.get("support_feedback"))
		if report.get("coach_tip") != null and String(report.get("coach_tip")) != "":
			feedback_label.text += "\nTip: %s" % String(report.get("coach_tip"))
		if report.get("peak_height") != null:
			feedback_label.text += "\nPeak %.1fm · flight %.1fs · aim %.1f°" % [float(report.get("peak_height")), float(report.get("total_flight_time")), float(report.get("horizontal_angle"))]
	else:
		feedback_label.text = "Shot complete"
	set_status("Auto restart")

func set_status(text: String) -> void:
	status_label.text = text

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
	feedback_label.size = Vector2(430.0, 58.0)
	feedback_label.add_theme_font_size_override("font_size", 15)
	feedback_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.82))
	instruction_label.position = Vector2(24.0, 676.0)
	instruction_label.size = Vector2(760.0, 28.0)
	instruction_label.add_theme_font_size_override("font_size", 16)
	instruction_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.72))
	instruction_label.remove_theme_stylebox_override("normal")
	status_label.position = Vector2(24.0, 642.0)
	status_label.size = Vector2(520.0, 24.0)
	status_label.add_theme_font_size_override("font_size", 13)
	status_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.42))
	status_label.remove_theme_stylebox_override("normal")
	_style_button(restart_button, Vector2(24.0, 586.0), Vector2(158.0, 40.0), "Restart  R")
	restart_button.visible = false
	_style_button(switch_foot_button, Vector2(24.0, 594.0), Vector2(128.0, 32.0), "Foot  F")
	switch_foot_button.visible = false
	_style_button(next_spot_button, Vector2(214.0, 586.0), Vector2(196.0, 40.0), next_spot_button.text)
	next_spot_button.visible = false

func _position_power_meter_for_foot() -> void:
	if power_meter == null:
		return
	var viewport_width := get_viewport().get_visible_rect().size.x
	if viewport_width <= 0.0:
		viewport_width = 1280.0
	var x := maxf(24.0, viewport_width - power_meter.size.x - 24.0) if kicking_foot == "right" else 24.0
	power_meter.position = Vector2(x, 178.0)
	if power_label != null:
		power_label.position = Vector2(x, 132.0)

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
