class_name FreeKickUI
extends CanvasLayer

signal restart_requested
signal switch_foot_requested
signal next_spot_requested

@onready var power_label: Label = %PowerLabel
@onready var power_bar: ProgressBar = %PowerBar
@onready var support_panel: SupportPlantPanel = %SupportPanel
@onready var support_marker: Control = %SupportMarker
@onready var ball_panel: BallContactPanel = %BallContactPanel
@onready var feedback_label: Label = %FeedbackLabel
@onready var instruction_label: Label = %InstructionLabel
@onready var status_label: Label = %StatusLabel
@onready var restart_button: Button = %RestartButton
@onready var switch_foot_button: Button = %SwitchFootButton
@onready var next_spot_button: Button = %NextSpotButton

func _ready() -> void:
	restart_button.pressed.connect(func() -> void: restart_requested.emit())
	switch_foot_button.pressed.connect(func() -> void: switch_foot_requested.emit())
	next_spot_button.pressed.connect(func() -> void: next_spot_requested.emit())

func hide_all() -> void:
	power_label.visible = false
	power_bar.visible = false
	support_panel.visible = false
	ball_panel.visible = false
	feedback_label.visible = false
	instruction_label.visible = true
	status_label.visible = true
	restart_button.visible = true
	switch_foot_button.visible = true
	next_spot_button.visible = true

func set_spot_label(label: String) -> void:
	if next_spot_button != null:
		next_spot_button.text = "Spot: %s" % label

func _support_foot_for_kick(kicking_foot: String) -> String:
	return "left" if kicking_foot == "right" else "right"

func show_power(power_value: float) -> void:
	power_label.visible = true
	power_bar.visible = true
	instruction_label.visible = true
	instruction_label.text = "Mouse: hold left button to charge power; release to lock. Keyboard: Space."
	power_label.text = "Power: %d%%" % roundi(power_value * 100.0)
	power_bar.value = clampf(power_value * 100.0, 0.0, 100.0)
	_update_power_bar_color(power_value)
	set_status("State: POWER · charge, then release")

func show_support_foot_sector(selected_foot: String, _difficulty: FreeKickDifficulty) -> void:
	hide_all()
	var support_foot := _support_foot_for_kick(selected_foot)
	power_label.visible = true
	support_panel.visible = true
	support_panel.set_foot(selected_foot)
	support_panel.set_marker(Vector2.ZERO, false)
	support_panel.set_foot_angle(0.0, false)
	support_panel.set_substep_label("1/2: drag to set support-foot location")
	support_marker.position = support_panel.size * 0.5 - support_marker.size * 0.5
	feedback_label.visible = true
	instruction_label.visible = true
	instruction_label.text = "STEP 2 — SUPPORT FOOT: white dot=ball, red dot=plant/support foot. Kicking foot: %s. Plant with the %s foot, then point it subtly toward LEFT POST, CENTER, or RIGHT POST." % [selected_foot.to_upper(), support_foot.to_upper()]
	feedback_label.text = "Plant setup: %s support foot (%s-foot kick)" % [support_foot, selected_foot]
	set_status("State: PLANT · support: %s · kicking: %s" % [support_foot, selected_foot])

func update_support_marker(local_pos: Vector2) -> void:
	support_panel.set_marker(local_pos, true)
	support_marker.position = support_panel.size * 0.5 + local_pos - support_marker.size * 0.5
	var side := "LEFT of ball" if local_pos.x < 0.0 else "RIGHT of ball"
	var plant := "ahead/open" if local_pos.y < -18.0 else "behind/closed" if local_pos.y > 18.0 else "level/balanced"
	set_status("Substep 1/2: support foot %s · %s · release" % [side, plant])

func update_support_foot_angle(angle: float, aim_target: float = 0.0) -> void:
	support_panel.set_substep_label("2/2: subtle foot angle · ±30° max")
	support_panel.set_foot_angle(angle, true, aim_target)
	var foot_offset := clampf(aim_target, -1.0, 1.0) * 30.0
	var target_label := "RIGHT POST" if aim_target > 0.25 else "LEFT POST" if aim_target < -0.25 else "CENTER"
	feedback_label.text = "Support foot: %+.0f° · Target lane: %s" % [foot_offset, target_label]
	set_status("Substep 2/2: subtle angle to %s · release to confirm" % target_label)

func show_ball_contact_ui() -> void:
	hide_all()
	power_label.visible = true
	ball_panel.visible = true
	ball_panel.modulate = Color(1.0, 1.0, 1.0, 0.92)
	ball_panel.clear_swipe()
	feedback_label.visible = true
	instruction_label.visible = true
	instruction_label.text = "STEP 3 — POINT + DRAG: press on the ball, then drag beyond it for follow-through. Longer sideways drag = stronger curl; lower start = lift; center+straight = clean power."
	feedback_label.text = "Ball contact: choose impact point and swipe"
	set_status("State: CONTACT · foreground ball touch")

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

func show_feedback(report: Resource) -> void:
	hide_all()
	feedback_label.visible = true
	feedback_label.position = Vector2(24.0, 96.0)
	feedback_label.size = Vector2(1156.0, 134.0)
	feedback_label.add_theme_font_size_override("font_size", 22)
	var feedback_bg := StyleBoxFlat.new()
	feedback_bg.bg_color = Color(0.02, 0.025, 0.035, 0.82)
	feedback_bg.border_color = Color(0.15, 0.85, 1.0, 0.95)
	feedback_bg.border_width_left = 3
	feedback_bg.border_width_top = 3
	feedback_bg.border_width_right = 3
	feedback_bg.border_width_bottom = 3
	feedback_bg.corner_radius_top_left = 10
	feedback_bg.corner_radius_top_right = 10
	feedback_bg.corner_radius_bottom_left = 10
	feedback_bg.corner_radius_bottom_right = 10
	feedback_bg.content_margin_left = 14
	feedback_bg.content_margin_top = 10
	feedback_bg.content_margin_right = 14
	feedback_bg.content_margin_bottom = 10
	feedback_label.add_theme_stylebox_override("normal", feedback_bg)
	instruction_label.visible = true
	instruction_label.text = "Feedback shown top-left with cyan ghost trajectory. Right-click/R restarts. Middle-click/F switches foot."
	if report != null and report.get("summary") != null:
		feedback_label.text = "SHOT FEEDBACK\n" + String(report.get("summary"))
		if report.get("support_feedback") != null and String(report.get("support_feedback")) != "":
			feedback_label.text += "\nSupport foot: %s" % String(report.get("support_feedback"))
		if report.get("coach_tip") != null and String(report.get("coach_tip")) != "":
			feedback_label.text += "\nCoach tip: %s" % String(report.get("coach_tip"))
		if report.get("peak_height") != null:
			feedback_label.text += "\nPeak %.1fm · flight %.1fs · aim %.1f°" % [float(report.get("peak_height")), float(report.get("total_flight_time")), float(report.get("horizontal_angle"))]
	else:
		feedback_label.text = "SHOT FEEDBACK\nShot complete"
	set_status("State: FEEDBACK — read top-left shot feedback")

func set_status(text: String) -> void:
	status_label.text = text

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
