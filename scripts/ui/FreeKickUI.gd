class_name FreeKickUI
extends CanvasLayer

signal restart_requested
signal switch_foot_requested

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

func _ready() -> void:
	restart_button.pressed.connect(func() -> void: restart_requested.emit())
	switch_foot_button.pressed.connect(func() -> void: switch_foot_requested.emit())

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
	power_label.visible = true
	support_panel.visible = true
	support_panel.set_foot(selected_foot)
	support_panel.set_marker(Vector2.ZERO, false)
	support_marker.position = support_panel.size * 0.5 - support_marker.size * 0.5
	feedback_label.visible = true
	instruction_label.visible = true
	instruction_label.text = "STEP 2 — AIM ONLY: drag red line to FIRST POST, CENTER, or SECOND POST. Ignore curl here; curl is Step 3. Release to confirm."
	feedback_label.text = "Plant setup: %s foot" % selected_foot
	set_status("State: PLANT · foot: %s" % selected_foot)

func update_support_marker(local_pos: Vector2) -> void:
	support_panel.set_marker(local_pos, true)
	support_marker.position = support_panel.size * 0.5 + local_pos - support_marker.size * 0.5
	var aim := "SECOND POST" if local_pos.x > support_panel.sector_radius * 0.33 else "FIRST POST" if local_pos.x < -support_panel.sector_radius * 0.33 else "CENTER"
	var plant := "open/curl" if local_pos.y < -18.0 else "close/drive" if local_pos.y > 18.0 else "balanced"
	set_status("Support line target: %s · plant: %s · release to confirm" % [aim, plant])

func show_ball_contact_ui() -> void:
	hide_all()
	power_label.visible = true
	ball_panel.visible = true
	ball_panel.modulate = Color(1.0, 1.0, 1.0, 0.92)
	ball_panel.clear_swipe()
	feedback_label.visible = true
	instruction_label.visible = true
	instruction_label.text = "STEP 3 — CURL/HEIGHT: center+straight = straight. Lower = lift. Swipe left/right or hit side = curve. Bigger sideways swipe = more curl."
	feedback_label.text = "Ball contact: choose impact point and swipe"
	set_status("State: CONTACT · foreground ball touch")

func update_ball_contact(points: PackedVector2Array) -> void:
	ball_panel.set_swipe_points(points)
	feedback_label.text = "Swipe points: %d" % points.size()
	set_status("Contact swipe points: %d" % points.size())

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
	instruction_label.visible = true
	instruction_label.text = "Feedback shown with cyan ghost trajectory. Right-click/R restarts. Middle-click/F switches foot."
	if report != null and report.get("summary") != null:
		feedback_label.text = String(report.get("summary"))
	else:
		feedback_label.text = "Shot complete"
	set_status("State: FEEDBACK")

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
