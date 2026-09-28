class_name FreeKickUI
extends CanvasLayer

const LEFT_SUPPORT_BOOT_TEXTURE := preload("res://assets/PumaAttacantoIZQ.png")

const WIND_HUD_SIZE := Vector2(156.0, 78.0)
const WIND_HUD_MARGIN := Vector2(24.0, 24.0)
const DIST_HUD_SIZE := Vector2(148.0, 68.0)
const DIST_HUD_MARGIN := Vector2(24.0, 24.0)

# Post-shot feedback recap: 4 frozen mini-diagrams (run-up, power, plant, contact).
const FEEDBACK_SNAPSHOT_WIDTH := 150.0
const FEEDBACK_SNAPSHOT_GAP := 14.0
const FEEDBACK_SNAPSHOT_HEIGHT := 168.0
const FEEDBACK_SNAPSHOTS_COUNT := 4
const FEEDBACK_SNAPSHOTS_TOTAL_WIDTH := FEEDBACK_SNAPSHOT_WIDTH * FEEDBACK_SNAPSHOTS_COUNT + FEEDBACK_SNAPSHOT_GAP * (FEEDBACK_SNAPSHOTS_COUNT - 1)

signal restart_requested
signal switch_foot_requested
signal next_spot_requested

var ui_root: Control

var impact_pulse: Control
var impact_pulse_progress := 0.0
var impact_pulse_alpha := 1.0
var impact_pulse_label := ""
var impact_pulse_color := Color.WHITE
var impact_pulse_screen_pos := Vector2.ZERO
var impact_pulse_tween: Tween

var result_card: Control
var result_card_title := ""
var result_card_cause := ""
var result_card_data := ""
var result_card_color := Color.WHITE
var result_card_alpha := 1.0
var result_card_progress := 0.0

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
	var phase_fill := 0.0
	var phase_time_text := ""
	var _pulse := 0.0
	const PHASE_LABELS := ["[1] POWER", "[2] PLANT", "[3] KICK"]
	# Palette lives in HudTheme (docs/hud-revamp-plan.md, Phase A); these aliases
	# keep the draw code readable while the palette stays centralized.
	const PHASE_CYAN := HudTheme.CYAN_BRIGHT
	const PHASE_ORANGE := HudTheme.ORANGE_BRIGHT
	const PHASE_RED := HudTheme.RED_RISK
	const NEON_CYAN := HudTheme.CYAN_BRIGHT
	const NEON_MAGENTA := HudTheme.MAGENTA_ALERT
	const NEON_YELLOW := HudTheme.YELLOW
	const NEON_ORANGE := HudTheme.ORANGE
	const NEON_ORANGE_DIM := HudTheme.ORANGE_DIM
	const NEON_ORANGE_BRIGHT := HudTheme.ORANGE_BRIGHT
	var distance_to_goal: float = 24.0

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		set_process(true)

	func _process(delta: float) -> void:
		_pulse += delta
		# Subtle breathing on the NinePatch chrome keeps the HUD alive like the
		# old drawn glow did (asset-baked neon is static otherwise).
		var frame := get_parent() as NinePatchRect
		if frame != null:
			frame.modulate.a = 0.94 + 0.06 * sin(_pulse * 2.4)
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

	func set_phase_progress(fill: float, time_text: String) -> void:
		phase_fill = clampf(fill, 0.0, 1.0)
		phase_time_text = time_text
		queue_redraw()

	func set_distance(distance: float) -> void:
		distance_to_goal = distance
		queue_redraw()


	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		var font := get_theme_default_font()
		var left_rect := Rect2(Vector2(46.0, 29.0), Vector2(238.0, 104.0))
		var center_rect := Rect2(Vector2(330.0, 29.0), Vector2(340.0, 104.0))
		var right_rect := Rect2(Vector2(728.0, 29.0), Vector2(248.0, 104.0))
		_draw_divider(Vector2(304.0, 26.0), Vector2(286.0, 136.0))
		_draw_divider(Vector2(705.0, 26.0), Vector2(723.0, 136.0))

		var effectiveness := 0.0 if attempts == 0 else float(goals) / float(attempts)
		_draw_level(font, left_rect)
		_draw_effectiveness(font, center_rect, effectiveness)
		_draw_misses(font, right_rect)

		_draw_phase_bar(font)

	func _draw_divider(a: Vector2, b: Vector2) -> void:
		draw_line(a, b, Color(1.0, 1.0, 1.0, 0.18), 1.8)
		draw_line(a + Vector2(2.0, 0.0), b + Vector2(2.0, 0.0), Color(0.0, 0.7, 1.0, 0.10), 1.0)

	func _draw_level(font: Font, rect: Rect2) -> void:
		draw_string(font, rect.position + Vector2(0.0, 16.0), "SET PIECE", HORIZONTAL_ALIGNMENT_LEFT, rect.size.x, 11, Color(0.6, 0.78, 0.92, 0.7))
		draw_string(font, rect.position + Vector2(0.0, 68.0), "%02d" % level, HORIZONTAL_ALIGNMENT_LEFT, 200.0, 46, Color(0.08, 0.84, 1.0, 1.0))

	func _draw_effectiveness(font: Font, rect: Rect2, effectiveness: float) -> void:
		draw_string(font, rect.position + Vector2(0.0, 21.0), "CONVERSION", HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 17, Color(NEON_ORANGE, 0.88))
		var pct := "%d%%" % roundi(effectiveness * 100.0)
		var ratio := "%d/%d" % [goals, max(1, attempts)]
		draw_string(font, rect.position + Vector2(0.0, 74.0), pct, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x * 0.48, 43, Color(NEON_ORANGE_BRIGHT, 1.0))
		draw_circle(rect.position + Vector2(rect.size.x * 0.50, 55.0), 4.0, Color(NEON_ORANGE, 1.0))
		draw_string(font, rect.position + Vector2(rect.size.x * 0.58, 74.0), ratio, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x * 0.42, 43, Color(1.0, 1.0, 1.0, 0.92))

	func _draw_misses(font: Font, rect: Rect2) -> void:
		draw_string(font, rect.position + Vector2(0.0, 21.0), "MISSES", HORIZONTAL_ALIGNMENT_LEFT, rect.size.x, 17, Color(NEON_ORANGE, 0.88))
		for i in range(max_misses):
			var center := rect.position + Vector2(24.0 + float(i) * 48.0, 59.0)
			var used := i < misses
			var fill := Color(NEON_ORANGE, 0.88) if used else Color(0.0, 0.0, 0.0, 0.15)
			var stroke := NEON_ORANGE_BRIGHT if used else Color(NEON_ORANGE, 0.45)
			draw_circle(center, 17.0, fill)
			draw_arc(center, 17.0, 0.0, TAU, 48, stroke, 2.2)
			if used:
				draw_arc(center, 23.0, 0.0, TAU, 48, Color(NEON_ORANGE, 0.26), 5.0)

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

	func _draw_phase_bar(font: Font) -> void:
		# Mockup style: three separate segmented boxes under the phase labels,
		# with the live countdown pill anchored inside the ACTIVE box.
		var bar_size := Vector2(480.0, 18.0)
		# Horizontally centered within the HUD's own width.
		var bar_pos := Vector2((size.x - bar_size.x) * 0.5, 150.0)
		var gap := 8.0
		var seg_w := (bar_size.x - gap * 2.0) / 3.0
		var low_time := active_step >= 2 and phase_time_text != "" and phase_fill < 0.30
		for i in range(3):
			var step := i + 1
			var is_done := active_step > step
			var is_active := active_step == step
			var seg_rect := Rect2(bar_pos + Vector2(float(i) * (seg_w + gap), 0.0), Vector2(seg_w, bar_size.y))
			# Box shell: dark glass + border that brightens for the active step.
			draw_rect(seg_rect, Color(0.02, 0.03, 0.06, 0.55), true)
			draw_rect(seg_rect, HudTheme.CYAN_BRIGHT if is_active else Color(1.0, 1.0, 1.0, 0.18), false, 1.2 if is_active else 1.0)
			var fill := 1.0 if is_done else phase_fill if is_active else 0.0
			if fill > 0.01:
				var fill_color := PHASE_CYAN if is_done else NEON_MAGENTA if is_active and low_time else NEON_YELLOW
				var fill_rect := Rect2(seg_rect.position + Vector2(2.0, 2.0), Vector2(maxf(0.0, (seg_rect.size.x - 4.0) * clampf(fill, 0.0, 1.0)), seg_rect.size.y - 4.0))
				draw_rect(fill_rect, HudTheme.glow_variant(fill_color, 0.22), true)
				draw_rect(fill_rect, fill_color, true)
				if is_active and step >= 2 and fill < 0.995:
					var cursor_x := fill_rect.end.x
					draw_line(Vector2(cursor_x, seg_rect.position.y + 1.0), Vector2(cursor_x, seg_rect.end.y - 1.0), HudTheme.CYAN_BRIGHT, 2.0)
			var label_color := NEON_YELLOW if is_active else NEON_ORANGE_DIM if is_done else Color(1.0, 1.0, 1.0, 0.35)
			draw_string(font, Vector2(seg_rect.position.x, bar_pos.y - 8.0), PHASE_LABELS[i], HORIZONTAL_ALIGNMENT_CENTER, seg_w, 10, label_color)
		# Countdown/percent pill anchored to the right edge of the ACTIVE box:
		# the fill grows left-to-right, so the pill is covered last and stays legible.
		var active_index := active_step - 1
		if phase_time_text != "" and active_index >= 0 and active_index < 3:
			var box := Rect2(bar_pos + Vector2(float(active_index) * (seg_w + gap), 0.0), Vector2(seg_w, bar_size.y))
			var text_color := NEON_MAGENTA if low_time else NEON_YELLOW
			if low_time:
				text_color.a = 0.65 + 0.35 * sin(_pulse * 9.0)
			var pill_w := 52.0
			var pill := Rect2(box.end - Vector2(pill_w + 2.0, bar_size.y + 2.0), Vector2(pill_w, bar_size.y + 4.0))
			draw_rect(pill, Color(0.0, 0.02, 0.04, 0.72), true)
			draw_rect(pill, Color(text_color, 0.55), false, 1.0)
			draw_string(font, pill.position + Vector2(0.0, pill.size.y * 0.5 + 4.0), phase_time_text, HORIZONTAL_ALIGNMENT_CENTER, pill.size.x, 12, text_color)

class WindHud extends Control:
	var wind_speed := 0.0
	var wind_direction_deg := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_wind(wind: Vector3) -> void:
		wind_speed = wind.length()
		if wind_speed > 0.01:
			wind_direction_deg = rad_to_deg(atan2(wind.x, -wind.z))
		else:
			wind_direction_deg = 0.0
		queue_redraw()

	func _draw() -> void:
		var font := get_theme_default_font()
		var rect := Rect2(Vector2.ZERO, size)
		draw_style_box(HudTheme.small_frame_style(), rect)
		draw_string(font, Vector2(12.0, 18.0), "WIND", HORIZONTAL_ALIGNMENT_LEFT, 60.0, 10, HudTheme.TEXT_LABEL)
		if wind_speed < 0.3:
			draw_string(font, Vector2(12.0, 50.0), "calm", HORIZONTAL_ALIGNMENT_LEFT, 60.0, 16, HudTheme.GREEN_SUCCESS)
		else:
			_draw_wind_arrow(Vector2(30.0, 46.0), wind_direction_deg, 14.0)
			draw_string(font, Vector2(48.0, 51.0), "%.1f m/s" % wind_speed, HORIZONTAL_ALIGNMENT_LEFT, 100.0, 16, HudTheme.CYAN_VALUE)

	func _draw_wind_arrow(origin: Vector2, direction_deg: float, length: float) -> void:
		var angle := deg_to_rad(direction_deg)
		var dir := Vector2(sin(angle), -cos(angle))
		var end := origin + dir * length
		var color := HudTheme.CYAN_VALUE
		draw_line(origin, end, color, 2.0)
		var head_size := 5.0
		var head_angle := deg_to_rad(140.0)
		draw_line(end, end - dir.rotated(head_angle) * head_size, color, 2.0)
		draw_line(end, end - dir.rotated(-head_angle) * head_size, color, 2.0)


class DistAngleHud extends Control:
	var distance := 0.0
	var angle := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_values(dist: float, ang: float) -> void:
		distance = dist
		angle = ang
		queue_redraw()

	func _draw() -> void:
		var font := get_theme_default_font()
		draw_style_box(HudTheme.small_frame_style(), Rect2(Vector2.ZERO, size))
		draw_string(font, Vector2(12.0, 26.0), "DIST", HORIZONTAL_ALIGNMENT_LEFT, 50.0, 11, HudTheme.TEXT_LABEL)
		draw_string(font, Vector2(60.0, 28.0), "%.1f m" % distance, HORIZONTAL_ALIGNMENT_LEFT, 90.0, 18, HudTheme.CYAN_VALUE)
		draw_string(font, Vector2(12.0, 54.0), "ANGLE", HORIZONTAL_ALIGNMENT_LEFT, 50.0, 11, HudTheme.TEXT_LABEL)
		draw_string(font, Vector2(60.0, 56.0), "%d°" % roundi(angle), HORIZONTAL_ALIGNMENT_LEFT, 90.0, 18, HudTheme.CYAN_VALUE)

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
var runup_anchor_screen := Vector2.ZERO
var runup_marker_screen := Vector2.ZERO
var runup_arc := Vector2(180.0, 270.0) # degrees clockwise from 12 o'clock, locked foot's valid arc
var runup_has_marker := false
var runup_angle_deg := 0.0
var runup_distance_m := 0.0
var runup_side := "right"
var left_support_boot_texture: Texture2D
var support_zone_center := Vector2(640.0, 360.0)
var support_zone_radius := 150.0
var support_zone_marker_local := Vector2.ZERO
var support_zone_has_marker := false
var support_zone_aim_target := 0.0
var support_zone_show_angle := false
var support_zone_flash := 0.0  # decays via tween; set by flash_support_correction()
var support_zone_flash_tween: Tween
var goal_banner: Control
var goal_banner_tween: Tween
var goal_banner_text := "GOAL!"
var goal_banner_subtitle := ""
var goal_banner_color := Color(0.0, 0.95, 1.0)
var goal_banner_progress := 0.0
var goal_banner_alpha := 1.0
var wind_module: Control
var dist_angle_module: Control
var feedback_snapshots_overlay: Control
var feedback_runup_angle_deg := 0.0
var feedback_runup_distance_m := 0.0
var feedback_runup_used_default := true
var feedback_kicking_foot := "right"
var feedback_power := 0.0
var feedback_support_vector := Vector2.ZERO
var feedback_support_foot_angle := 0.0
var feedback_has_support := false
var feedback_impact_point := Vector2.ZERO
var feedback_swipe_points: PackedVector2Array = PackedVector2Array()

func _ready() -> void:
	ui_root = get_node_or_null("Root") as Control
	if ui_root != null:
		ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
		ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_update_uiroot_margins()
		get_viewport().size_changed.connect(_update_uiroot_margins)
	impact_pulse = _create_impact_pulse()
	result_card = _create_result_card()
	left_support_boot_texture = LEFT_SUPPORT_BOOT_TEXTURE
	support_zone_overlay = _create_support_zone_overlay()
	support_marker_hint = _create_support_marker_hint()
	goal_banner = _create_goal_banner()
	wind_module = _create_wind_module()
	dist_angle_module = _create_dist_angle_module()
	feedback_snapshots_overlay = _create_feedback_snapshots_overlay()
	_apply_mvp_layout()
	_center_score_hud()
	restart_button.pressed.connect(func() -> void: restart_requested.emit())
	switch_foot_button.pressed.connect(func() -> void: switch_foot_requested.emit())
	next_spot_button.pressed.connect(func() -> void: next_spot_requested.emit())

func _update_uiroot_margins() -> void:
	if ui_root == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0:
		viewport_size = Vector2(1280.0, 720.0)
	var screen_size := Vector2(DisplayServer.screen_get_size())
	# get_display_safe_area is monitor-relative; convert to window-relative first.
	var safe_screen := DisplayServer.get_display_safe_area()
	var win_pos := Vector2(DisplayServer.window_get_position())
	var safe_window := Rect2(Vector2(safe_screen.position) - win_pos, Vector2(safe_screen.size))
	var safe_viewport := FreeKickUIScale.viewport_safe_area(viewport_size, screen_size, safe_window)
	ui_root.offset_left = maxf(0.0, safe_viewport.position.x)
	ui_root.offset_top = maxf(0.0, safe_viewport.position.y)
	ui_root.offset_right = -maxf(0.0, viewport_size.x - safe_viewport.end.x)
	ui_root.offset_bottom = -maxf(0.0, viewport_size.y - safe_viewport.end.y)
	var score_hud_frame := score_hud.get_parent() if score_hud != null else null
	if score_hud_frame != null:
		score_hud_frame.scale = Vector2.ONE * FreeKickUIScale.widget_scale(viewport_size.y)
		_center_score_hud()
	if result_card != null:
		var s := FreeKickUIScale.widget_scale(viewport_size.y)
		result_card.offset_left = -210.0 * s
		result_card.offset_right = 210.0 * s
		result_card.offset_top = 190.0 * s
		result_card.offset_bottom = (190.0 + 130.0) * s
		result_card.size = Vector2(420.0 * s, 130.0 * s)
	if feedback_snapshots_overlay != null:
		var s3 := FreeKickUIScale.widget_scale(viewport_size.y)
		var total_w := FEEDBACK_SNAPSHOTS_TOTAL_WIDTH * s3
		feedback_snapshots_overlay.offset_left = -total_w * 0.5
		feedback_snapshots_overlay.offset_right = total_w * 0.5
		feedback_snapshots_overlay.offset_top = 335.0 * s3
		feedback_snapshots_overlay.offset_bottom = (335.0 + FEEDBACK_SNAPSHOT_HEIGHT) * s3
		feedback_snapshots_overlay.size = Vector2(total_w, FEEDBACK_SNAPSHOT_HEIGHT * s3)
	_layout_corner_modules()

## Positions `control` inside ui_root at a normalized anchor point (0..1) with an edge margin.
## Sizes scale with the widget scale; margins stay in viewport px (stretch already scales them).
## Positions `control` inside ui_root at a normalized anchor point (0..1) with an edge margin.
## Sizes scale with the widget scale; margins stay in viewport px (stretch already scales them).
func _place_anchored(control: Control, anchor_point: Vector2, margin: Vector2, size_value: Vector2) -> void:
	if control == null or ui_root == null:
		return
	control.anchor_left = anchor_point.x
	control.anchor_top = anchor_point.y
	control.anchor_right = anchor_point.x
	control.anchor_bottom = anchor_point.y
	var s := size_value * FreeKickUIScale.widget_scale(ui_root.size.y if ui_root.size.y > 0.0 else 720.0)
	if anchor_point.x < 0.5:
		control.offset_left = margin.x
		control.offset_right = margin.x + s.x
	else:
		control.offset_left = -margin.x - s.x
		control.offset_right = -margin.x
	if anchor_point.y < 0.5:
		control.offset_top = margin.y
		control.offset_bottom = margin.y + s.y
	else:
		control.offset_top = -margin.y - s.y
		control.offset_bottom = -margin.y

func _layout_corner_modules() -> void:
	_place_anchored(wind_module, Vector2(0.0, 1.0), WIND_HUD_MARGIN, WIND_HUD_SIZE)
	_place_anchored(dist_angle_module, Vector2(1.0, 1.0), DIST_HUD_MARGIN, DIST_HUD_SIZE)

func _create_impact_pulse() -> Control:
	var pulse := Control.new()
	pulse.name = "ImpactPulse"
	pulse.set_anchors_preset(Control.PRESET_FULL_RECT)
	pulse.visible = false
	pulse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pulse.draw.connect(_draw_impact_pulse)
	if ui_root != null:
		ui_root.add_child(pulse)
	else:
		add_child(pulse)
	return pulse

## Ring pulse + label anchored to a world-space impact point (deterministic tween, no RNG).
func show_impact_pulse(world_point: Vector3, camera: Camera3D, label: String, color: Color) -> void:
	if impact_pulse == null or camera == null:
		return
	impact_pulse_screen_pos = camera.unproject_position(world_point)
	impact_pulse_label = label
	impact_pulse_color = color
	impact_pulse_progress = 0.0
	impact_pulse_alpha = 1.0
	impact_pulse.visible = true
	impact_pulse.queue_redraw()
	if impact_pulse_tween != null and impact_pulse_tween.is_valid():
		impact_pulse_tween.kill()
	impact_pulse_tween = create_tween()
	impact_pulse_tween.tween_method(_set_impact_progress, 0.0, 1.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	impact_pulse_tween.tween_method(_set_impact_alpha, 1.0, 0.0, 0.4)
	impact_pulse_tween.tween_callback(func() -> void:
		impact_pulse.visible = false
	)

func _set_impact_progress(value: float) -> void:
	impact_pulse_progress = value
	if impact_pulse != null:
		impact_pulse.queue_redraw()

func _set_impact_alpha(value: float) -> void:
	impact_pulse_alpha = value
	if impact_pulse != null:
		impact_pulse.queue_redraw()

func _draw_impact_pulse() -> void:
	if impact_pulse == null or not impact_pulse.visible:
		return
	var center := impact_pulse_screen_pos
	var radius := 14.0 + impact_pulse_progress * 90.0
	var a := impact_pulse_alpha
	impact_pulse.draw_arc(center, radius, 0.0, TAU, 48, Color(impact_pulse_color, 0.85 * a), 3.0)
	impact_pulse.draw_arc(center, radius * 0.55, 0.0, TAU, 48, Color(impact_pulse_color, 0.35 * a), 2.0)
	var font := impact_pulse.get_theme_default_font()
	impact_pulse.draw_string(font, Vector2(center.x - 60.0, center.y + radius + 22.0), impact_pulse_label, HORIZONTAL_ALIGNMENT_CENTER, 120.0, 13, Color(1.0, 1.0, 1.0, 0.95 * a))

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
	if feedback_snapshots_overlay != null:
		feedback_snapshots_overlay.visible = false

func _set_active_step(step: int) -> void:
	if score_hud != null and score_hud.has_method("set_active_step"):
		score_hud.call("set_active_step", step)

## Shows the active phase bar segment fill (0..1) and an optional time/percent label.
func set_phase_progress(fill: float, time_text: String = "") -> void:
	if score_hud != null and score_hud.has_method("set_phase_progress"):
		score_hud.call("set_phase_progress", fill, time_text)

func set_spot_label(label: String) -> void:
	if next_spot_button != null:
		next_spot_button.text = "Spot: %s" % label

func set_scoreboard(text: String) -> void:
	if score_hud != null and score_hud.has_method("set_fallback_text"):
		score_hud.call("set_fallback_text", text)

func set_run_hud(level: int, goals: int, attempts: int, misses: int, max_misses: int, message: String = "") -> void:
	if score_hud != null and score_hud.has_method("set_stats"):
		score_hud.call("set_stats", level, goals, attempts, misses, max_misses, message)

func set_environment_info(distance: float, wind: Vector3, angle: float = 0.0) -> void:
	if score_hud != null and score_hud.has_method("set_distance"):
		score_hud.call("set_distance", distance)
	if wind_module != null and wind_module.has_method("set_wind"):
		wind_module.call("set_wind", wind)
	if dist_angle_module != null and dist_angle_module.has_method("set_values"):
		dist_angle_module.call("set_values", distance, angle)

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
				var aim_len := radius * 0.62
				var aim_end := marker + Vector2.UP.rotated(aim_angle) * aim_len
				# Legal fan +/-30 deg around the heel: limits visible without guessing.
				overlay.draw_arc(marker, aim_len * 0.85, -PI / 2.0 - deg_to_rad(30.0), -PI / 2.0 + deg_to_rad(30.0), 24, Color(0.55, 0.9, 1.0, 0.35), 1.5)
				overlay.draw_dashed_line(marker, aim_end, Color(1.0, 0.86, 0.22, 0.95), 3.0, 8.0)
				overlay.draw_circle(aim_end, 5.0, Color(1.0, 0.86, 0.22, 1.0))
				_draw_support_foot_indicator(overlay, marker, true, aim_angle)
			if support_zone_flash > 0.01:
				# Green correction ring: the heel was clamped to the legal side.
				overlay.draw_arc(marker, 24.0, 0.0, TAU, 32, Color(0.3, 1.0, 0.45, 0.8 * support_zone_flash), 3.0)
		var side_text := "LEFT" if kicking_foot == "right" else "RIGHT"
		overlay.draw_string(overlay.get_theme_default_font(), center + Vector2(-96.0, radius + 28.0), "Plant zone: %s side - slide to aim" % side_text, HORIZONTAL_ALIGNMENT_CENTER, 192.0, 13, Color(1, 1, 1, 0.7))
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

func _create_goal_banner() -> Control:
	var root := get_node_or_null("Root") as Control
	var banner := Control.new()
	banner.name = "GoalBanner"
	banner.set_anchors_preset(Control.PRESET_FULL_RECT)
	banner.visible = false
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.draw.connect(_draw_goal_banner)
	if root != null:
		root.add_child(banner)
	else:
		add_child(banner)
	return banner

func _create_wind_module() -> Control:
	var root := get_node_or_null("Root") as Control
	var hud := WindHud.new()
	hud.name = "WindHud"
	if root != null:
		root.add_child(hud)
	else:
		add_child(hud)
	return hud

func _create_dist_angle_module() -> Control:
	var root := get_node_or_null("Root") as Control
	var hud := DistAngleHud.new()
	hud.name = "DistAngleHud"
	if root != null:
		root.add_child(hud)
	else:
		add_child(hud)
	return hud

## Compact result card (top-center under the score HUD): outcome / cause / data tiers.
func _create_result_card() -> Control:
	var card := Control.new()
	card.name = "ResultCard"
	card.visible = false
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.draw.connect(_draw_result_card)
	card.anchor_left = 0.5
	card.anchor_top = 0.0
	card.anchor_right = 0.5
	card.anchor_bottom = 0.0
	var s := FreeKickUIScale.widget_scale(get_viewport().get_visible_rect().size.y if get_viewport().get_visible_rect().size.y > 0.0 else 720.0)
	card.offset_left = -210.0 * s
	card.offset_right = 210.0 * s
	card.offset_top = 190.0 * s  # below the score HUD
	card.offset_bottom = (190.0 + 130.0) * s
	if ui_root != null:
		ui_root.add_child(card)
	else:
		add_child(card)
	return card

func _create_feedback_snapshots_overlay() -> Control:
	var overlay := Control.new()
	overlay.name = "FeedbackSnapshots"
	overlay.visible = false
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.anchor_left = 0.5
	overlay.anchor_right = 0.5
	overlay.anchor_top = 0.0
	overlay.anchor_bottom = 0.0
	var s := FreeKickUIScale.widget_scale(get_viewport().get_visible_rect().size.y if get_viewport().get_visible_rect().size.y > 0.0 else 720.0)
	var total_w := FEEDBACK_SNAPSHOTS_TOTAL_WIDTH * s
	overlay.offset_left = -total_w * 0.5
	overlay.offset_right = total_w * 0.5
	overlay.offset_top = 335.0 * s
	overlay.offset_bottom = (335.0 + FEEDBACK_SNAPSHOT_HEIGHT) * s
	overlay.size = Vector2(total_w, FEEDBACK_SNAPSHOT_HEIGHT * s)
	overlay.draw.connect(_draw_feedback_snapshots)
	if ui_root != null:
		ui_root.add_child(overlay)
	else:
		add_child(overlay)
	return overlay

## Freezes the attempt's raw gesture data for the 4-panel post-shot recap
## (run-up angle/distance, power, plant position/angle, ball contact).
func show_feedback_snapshots(input: FreeKickInputData) -> void:
	if feedback_snapshots_overlay == null or input == null:
		return
	feedback_runup_angle_deg = input.runup_angle_deg
	feedback_runup_distance_m = input.runup_distance_m
	feedback_runup_used_default = input.used_default_runup
	feedback_kicking_foot = input.selected_foot
	feedback_power = input.power_normalized
	feedback_support_vector = input.support_vector
	feedback_support_foot_angle = input.support_foot_angle
	feedback_has_support = not input.used_default_support
	feedback_impact_point = input.impact_point
	feedback_swipe_points = input.swipe_points
	feedback_snapshots_overlay.visible = true
	feedback_snapshots_overlay.queue_redraw()

func _draw_feedback_snapshots() -> void:
	var overlay := feedback_snapshots_overlay
	var s := FreeKickUIScale.widget_scale(get_viewport().get_visible_rect().size.y)
	var w := FEEDBACK_SNAPSHOT_WIDTH * s
	var h := FEEDBACK_SNAPSHOT_HEIGHT * s
	var gap := FEEDBACK_SNAPSHOT_GAP * s
	for i in range(FEEDBACK_SNAPSHOTS_COUNT):
		var rect := Rect2(Vector2(float(i) * (w + gap), 0.0), Vector2(w, h))
		match i:
			0: _draw_snapshot_runup(overlay, rect)
			1: _draw_snapshot_power(overlay, rect)
			2: _draw_snapshot_support(overlay, rect)
			3: _draw_snapshot_contact(overlay, rect)

func _draw_snapshot_frame(canvas: Control, rect: Rect2, title: String) -> Vector2:
	canvas.draw_style_box(HudTheme.panel_style(HudTheme.BG_GLASS, HudTheme.CYAN_FRAME_SOFT, 1, HudTheme.RADIUS_PANEL), rect)
	var font := canvas.get_theme_default_font()
	canvas.draw_string(font, rect.position + Vector2(8.0, 18.0), title, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 16.0, 11, HudTheme.TEXT_LABEL)
	return rect.position + Vector2(rect.size.x * 0.5, rect.size.y * 0.5 + 8.0) # diagram center, below the title

## Snapshot 1: run-up angle + distance, drawn as a small line from the ball toward
## the committed approach direction on the locked foot's side.
func _draw_snapshot_runup(canvas: Control, rect: Rect2) -> void:
	var center := _draw_snapshot_frame(canvas, rect, "RUN-UP")
	var font := canvas.get_theme_default_font()
	if feedback_runup_used_default:
		canvas.draw_string(font, center + Vector2(-50.0, 4.0), "NOT USED", HORIZONTAL_ALIGNMENT_CENTER, 100.0, 12, HudTheme.TEXT_FAINT)
		return
	var radius := rect.size.y * 0.32
	canvas.draw_circle(center, 4.0, Color(1.0, 1.0, 1.0, 0.7))
	# Straight-on (90deg) points down (away from goal, where the run-up comes from);
	# lateral (0deg) points to the locked foot's side - mirrors RunUpState's own arcs.
	var lateral_sign := -1.0 if feedback_kicking_foot == "right" else 1.0
	var angle_t := clampf(feedback_runup_angle_deg, 0.0, ShotCalculator.RUNUP_ANGLE_MAX_DEG) / ShotCalculator.RUNUP_ANGLE_MAX_DEG
	var dir := Vector2(lateral_sign * (1.0 - angle_t), angle_t).normalized()
	var distance_t := clampf(feedback_runup_distance_m / ShotCalculator.RUNUP_DISTANCE_MAX_M, 0.0, 1.0)
	var tip := center + dir * radius * lerpf(0.35, 1.0, distance_t)
	var risk_color := HudTheme.CYAN_VALUE.lerp(HudTheme.ORANGE_BRIGHT, distance_t)
	canvas.draw_line(center, tip, risk_color, 3.0)
	canvas.draw_circle(tip, 5.0, risk_color)
	var caption := "%.0f° · %.1fm · %s" % [feedback_runup_angle_deg, feedback_runup_distance_m, feedback_kicking_foot.to_upper()]
	canvas.draw_string(font, rect.position + Vector2(0.0, rect.size.y - 10.0), caption, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 11, HudTheme.TEXT_BODY)

## Snapshot 2: power bar with the same LOW/CONTROL/IDEAL/RISK zones as PowerMeterPanel,
## frozen at the released value.
func _draw_snapshot_power(canvas: Control, rect: Rect2) -> void:
	_draw_snapshot_frame(canvas, rect, "POWER")
	var font := canvas.get_theme_default_font()
	var bar_w := 22.0
	var bar_rect := Rect2(rect.position + Vector2(rect.size.x * 0.5 - bar_w * 0.5, 34.0), Vector2(bar_w, rect.size.y - 62.0))
	canvas.draw_style_box(HudTheme.panel_style(Color(0.0, 0.0, 0.0, 0.4), HudTheme.CYAN_FRAME_SOFT, 1, 8), bar_rect.grow(3.0))
	var zone_bounds: Array[Vector2] = [Vector2(0.0, 0.40), Vector2(0.40, 0.70), Vector2(0.70, 0.85), Vector2(0.85, 1.0)]
	var zone_colors: Array[Color] = [HudTheme.CYAN_VALUE, HudTheme.GREEN_SOFT, HudTheme.YELLOW, HudTheme.RED_RISK]
	for i in range(zone_bounds.size()):
		var y1: float = bar_rect.end.y - bar_rect.size.y * zone_bounds[i].x
		var y0: float = bar_rect.end.y - bar_rect.size.y * zone_bounds[i].y
		canvas.draw_rect(Rect2(bar_rect.position.x, y0, bar_rect.size.x, y1 - y0), Color(zone_colors[i], 0.55), true)
	var pointer_y := bar_rect.end.y - bar_rect.size.y * clampf(feedback_power, 0.0, 1.0)
	var pointer_color := HudTheme.power_zone_color(feedback_power, 1.0)
	canvas.draw_line(Vector2(bar_rect.position.x - 6.0, pointer_y), Vector2(bar_rect.end.x + 6.0, pointer_y), Color.WHITE, 2.0)
	canvas.draw_circle(Vector2(bar_rect.end.x + 10.0, pointer_y), 4.0, pointer_color)
	var caption := "%d%%" % roundi(feedback_power * 100.0)
	canvas.draw_string(font, rect.position + Vector2(0.0, rect.size.y - 10.0), caption, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 13, pointer_color)

## Snapshot 3: support-foot plant position + aim angle, relative to the ball.
func _draw_snapshot_support(canvas: Control, rect: Rect2) -> void:
	var center := _draw_snapshot_frame(canvas, rect, "PLANT")
	var font := canvas.get_theme_default_font()
	var radius := rect.size.y * 0.30
	canvas.draw_circle(center, 6.0, Color.WHITE)
	if not feedback_has_support:
		canvas.draw_string(font, center + Vector2(-50.0, 22.0), "DEFAULT", HORIZONTAL_ALIGNMENT_CENTER, 100.0, 12, HudTheme.TEXT_FAINT)
		return
	var marker := center + feedback_support_vector.limit_length(1.0) * radius
	canvas.draw_dashed_line(center, marker, HudTheme.GREEN_SUCCESS, 2.0, 5.0)
	canvas.draw_circle(marker, 6.0, HudTheme.GREEN_SUCCESS)
	var toe := marker + Vector2.from_angle(feedback_support_foot_angle) * 16.0
	canvas.draw_line(marker, toe, HudTheme.YELLOW, 2.5)
	var caption := "%+.0f° aim · %.0fcm" % [rad_to_deg(feedback_support_foot_angle), absf(feedback_support_vector.x) * 100.0]
	canvas.draw_string(font, rect.position + Vector2(0.0, rect.size.y - 10.0), caption, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 11, HudTheme.TEXT_BODY)

## Snapshot 4: ball contact point + follow-through swipe trace, same convention as
## BallContactPanel (normalized -1..1 ball-local coordinates).
func _draw_snapshot_contact(canvas: Control, rect: Rect2) -> void:
	var center := _draw_snapshot_frame(canvas, rect, "CONTACT")
	var font := canvas.get_theme_default_font()
	var ball_radius := rect.size.y * 0.26
	canvas.draw_circle(center, ball_radius, Color(1.0, 1.0, 1.0, 0.14))
	canvas.draw_arc(center, ball_radius, 0.0, TAU, 48, HudTheme.CYAN_FRAME_SOFT, 1.5)
	if feedback_swipe_points.size() == 0:
		canvas.draw_string(font, center + Vector2(-50.0, 22.0), "DEFAULT", HORIZONTAL_ALIGNMENT_CENTER, 100.0, 12, HudTheme.TEXT_FAINT)
		return
	var first := center + feedback_swipe_points[0] * ball_radius
	canvas.draw_circle(first, 5.0, HudTheme.YELLOW)
	for i in range(1, feedback_swipe_points.size()):
		var a := center + feedback_swipe_points[i - 1] * ball_radius
		var b := center + feedback_swipe_points[i] * ball_radius
		canvas.draw_line(a, b, HudTheme.YELLOW_WARN, 2.5)
	if feedback_swipe_points.size() > 1:
		var last := center + feedback_swipe_points[feedback_swipe_points.size() - 1] * ball_radius
		canvas.draw_circle(last, 4.0, HudTheme.ORANGE_BRIGHT)
	var caption := "contact %.0f%%, %.0f%%" % [feedback_impact_point.x * 100.0, feedback_impact_point.y * 100.0]
	canvas.draw_string(font, rect.position + Vector2(0.0, rect.size.y - 10.0), caption, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 11, HudTheme.TEXT_BODY)

## Pops a result banner (goal, miss, save, post, crossbar). Deterministic tween, no RNG.
func show_result_banner(text: String = "GOAL!", subtitle: String = "", highlight: Color = Color(0.0, 0.95, 1.0)) -> void:
	_show_result_card(text, subtitle, "", highlight)

func _set_goal_banner_progress(value: float) -> void:
	goal_banner_progress = value
	if goal_banner != null:
		goal_banner.queue_redraw()

func _set_goal_banner_alpha(value: float) -> void:
	goal_banner_alpha = value
	if goal_banner != null:
		goal_banner.queue_redraw()

func _draw_goal_banner() -> void:
	# The celebration banner was replaced by the compact result card (_draw_result_card).
	pass

func show_feedback(report: Resource, auto_restart_delay_seconds: float = 4.0) -> void:
	hide_all()
	_set_active_step(4)
	set_phase_progress(1.0, "")
	var cause := _result_cause_from_report(report)
	var data := _result_data_from_report(report)
	_show_result_card(report_summary(report), cause, data, Color(0.0, 0.95, 1.0))
	instruction_label.visible = true
	instruction_label.text = "Auto restart in %.0fs" % auto_restart_delay_seconds
	set_status("Auto restart")

func report_summary(report: Resource) -> String:
	if report == null or report.get("summary") == null:
		return "SHOT COMPLETE"
	return String(report.get("summary")).to_upper()

func _result_cause_from_report(report: Resource) -> String:
	if report == null:
		return ""
	var lines: Array[String] = []
	if report.get("support_feedback") != null and String(report.get("support_feedback")) != "":
		lines.append(String(report.get("support_feedback")))
	var curl_strength := String(report.get("curl_strength"))
	if curl_strength == "low":
		lines.append("add side contact for curl")
	elif curl_strength != "":
		lines.append("curl: %s" % curl_strength)
	if report.get("coach_tip") != null and String(report.get("coach_tip")) != "":
		lines.append(String(report.get("coach_tip")))
	return " · ".join(lines)

func _result_data_from_report(report: Resource) -> String:
	if report == null:
		return ""
	var power := roundi(float(report.get("power")) * 100.0)
	var elevation := roundi(float(report.get("elevation_angle")))
	var curl := String(report.get("curl_strength"))
	return "PWR %d%%  ·  ELEV %d°  ·  CURL %s" % [power, elevation, curl]

func _show_result_card(title: String, cause: String, data: String, color: Color) -> void:
	if result_card == null:
		return
	result_card_title = title
	result_card_cause = cause
	result_card_data = data
	result_card_color = color
	result_card_progress = 0.0
	result_card_alpha = 1.0
	result_card.visible = true
	result_card.queue_redraw()
	if goal_banner_tween != null and goal_banner_tween.is_valid():
		goal_banner_tween.kill()
	goal_banner_tween = create_tween()
	goal_banner_tween.tween_method(_set_goal_banner_progress, 0.0, 1.0, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	goal_banner_tween.tween_interval(1.05)
	goal_banner_tween.tween_method(_set_goal_banner_alpha, 1.0, 0.0, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	goal_banner_tween.tween_callback(func() -> void:
		result_card.visible = false
	)

func _draw_result_card() -> void:
	if result_card == null or not result_card.visible:
		return
	var scale := FreeKickUIScale.widget_scale(get_viewport().get_visible_rect().size.y)
	var font := result_card.get_theme_default_font()
	var bg := Color(0.0, 0.01, 0.03, 0.72 * result_card_alpha)
	var border := Color(result_card_color, 0.55 * result_card_alpha)
	result_card.draw_style_box(HudTheme.panel_style(bg, border, 2, HudTheme.RADIUS_CARD), Rect2(Vector2.ZERO, result_card.size))
	var title_size := roundi(34.0 * scale)
	result_card.draw_string(font, Vector2(0.0, 46.0 * scale), result_card_title, HORIZONTAL_ALIGNMENT_CENTER, result_card.size.x, title_size, Color(result_card_color, result_card_alpha))
	if result_card_cause != "":
		result_card.draw_string(font, Vector2(0.0, 78.0 * scale), result_card_cause, HORIZONTAL_ALIGNMENT_CENTER, result_card.size.x, roundi(14.0 * scale), Color(1.0, 1.0, 1.0, 0.92 * result_card_alpha))
	if result_card_data != "":
		result_card.draw_string(font, Vector2(0.0, 104.0 * scale), result_card_data, HORIZONTAL_ALIGNMENT_CENTER, result_card.size.x, roundi(11.0 * scale), Color(1.0, 1.0, 1.0, 0.5 * result_card_alpha))

func _create_score_hud() -> Control:
	var root := get_node_or_null("Root") as Control
	# Asset-backed chrome: the generated sci-fi frame (9-slice) is the panel;
	# the custom-drawn scoreboard content renders on top as a full-rect child.
	var frame := NinePatchRect.new()
	frame.name = "ScoreHudFrame"
	frame.texture = load("res://assets/ui/score_frame.png")
	frame.patch_margin_left = 64
	frame.patch_margin_right = 64
	frame.patch_margin_top = 46
	frame.patch_margin_bottom = 46
	frame.size = SCORE_HUD_DESIGN_SIZE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hud := ModernScoreHud.new()
	hud.name = "ModernScoreHud"
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(hud)
	if root != null:
		root.add_child(frame)
	else:
		add_child(frame)
	return hud

const SCORE_HUD_DESIGN_SIZE := Vector2(980.0, 180.0)
const SCORE_HUD_BOTTOM_BAND := 215.0  # design px reserved for the score HUD at the top

func _center_score_hud() -> void:
	if score_hud == null or ui_root == null:
		return
	var frame := score_hud.get_parent() as Control
	if frame == null:
		return
	# Anchor+offset sizing mutates `size`; always recompute from the design size
	# so repeated resizes cannot compound-shrink the HUD.
	frame.size = SCORE_HUD_DESIGN_SIZE
	frame.pivot_offset = SCORE_HUD_DESIGN_SIZE * 0.5
	frame.anchor_left = 0.5
	frame.anchor_right = 0.5
	frame.anchor_top = 0.0
	frame.anchor_bottom = 0.0
	var half_w := SCORE_HUD_DESIGN_SIZE.x * frame.scale.x * 0.5
	frame.offset_left = -half_w
	frame.offset_right = half_w
	frame.offset_top = 20.0
	frame.offset_bottom = 20.0 + SCORE_HUD_DESIGN_SIZE.y * frame.scale.y

func set_kicking_foot(foot: String) -> void:
	kicking_foot = foot
	if power_meter != null:
		power_meter.kicking_foot = foot
	_position_power_meter_for_foot()

func _support_foot_for_kick(kicking_foot: String) -> String:
	return "left" if kicking_foot == "right" else "right"

func show_runup_ready() -> void:
	hide_all()
	_set_active_step(1)
	set_phase_progress(0.0, "")
	runup_has_marker = false
	_show_primary_instruction("Run-up", "Tap beside the ball on your kicking foot's side and drag to set the run-up angle and distance.")
	set_status("RUN-UP - tap beside the ball, drag, release to fix")

func update_runup_gesture(angle_deg: float, distance_m: float, side: String, anchor_screen: Vector2, marker_screen: Vector2, arc: Vector2) -> void:
	runup_angle_deg = angle_deg
	runup_distance_m = distance_m
	runup_side = side
	runup_anchor_screen = anchor_screen
	runup_marker_screen = marker_screen
	runup_arc = arc
	runup_has_marker = true
	var distance_t := clampf(distance_m / ShotCalculator.RUNUP_DISTANCE_MAX_M, 0.0, 1.0)
	var risk := "LOW" if distance_t < 0.4 else "MED" if distance_t < 0.75 else "HIGH"
	feedback_label.text = "Run-up: %.0f deg (%s) - %s foot - %.1fm (%s risk)" % [angle_deg, _runup_style_label(angle_deg), side.to_upper(), distance_m, risk]
	set_status("RUN-UP - release to fix")

## Names the run-up style for player-facing feedback, mirroring real free-kick technique
## (angle measured from the goal line: 0 = lateral, 90 = straight-on). A lateral run-up
## favors curl/wrap; a straight-on run-up favors straight power/puntera.
func _runup_style_label(angle_deg: float) -> String:
	if angle_deg < 30.0:
		return "WIDE/CURL"
	if angle_deg < 60.0:
		return "BALANCED"
	return "STRAIGHT/POWER"

func show_power_ready() -> void:
	hide_all()
	_set_active_step(1)
	set_phase_progress(0.0, "")
	_position_power_meter_for_foot()
	_show_primary_instruction("Power building", "Power is building on its own - tap to strike!")
	set_status("POWER - building - tap to strike")

func show_power(power_value: float) -> void:
	_set_active_step(1)
	set_phase_progress(power_value, "%d%%" % roundi(power_value * 100.0))
	_position_power_meter_for_foot()
	power_label.visible = false
	power_meter.visible = true
	power_meter.power_value = power_value
	_show_primary_instruction("Tap to strike", _power_feedback(power_value))
	power_label.text = "%d%%" % roundi(power_value * 100.0)
	set_status("POWER - %s foot - tap in the 70-85%% ideal zone" % kicking_foot.to_upper())

func show_support_foot_sector(selected_foot: String, _difficulty: FreeKickDifficulty) -> void:
	hide_all()
	_set_active_step(2)
	set_phase_progress(1.0, "")
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
	_show_primary_instruction("Plant & aim", "%s plant beside the ball - slide to aim - release to shoot" % support_foot.capitalize())
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
	feedback_label.text = "Aim: %s - toe %+.0f deg" % [target_label, foot_offset]
	set_status("%s - release to shoot" % target_label)

## Brief green ring at the heel when the tap was clamped to the legal side.
func flash_support_correction() -> void:
	if support_zone_flash_tween != null and support_zone_flash_tween.is_valid():
		support_zone_flash_tween.kill()
	support_zone_flash = 1.0
	if support_zone_overlay != null:
		support_zone_overlay.queue_redraw()
	support_zone_flash_tween = create_tween()
	support_zone_flash_tween.tween_method(_set_zone_flash, 1.0, 0.0, 0.6)

func _set_zone_flash(value: float) -> void:
	support_zone_flash = value
	if support_zone_overlay != null:
		support_zone_overlay.queue_redraw()

## Shows how much aim angle the current plant distance allows (0..1).
func update_support_angle_scale(scale: float) -> void:
	if support_panel.visible:
		support_panel.set_angle_scale(scale)

func show_ball_contact_ui() -> void:
	hide_all()
	_set_active_step(3)
	set_phase_progress(1.0, "")
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
		return "Touch the ball, then drag to follow through"
	var contact := points[0] / maxf(1.0, ball_panel.ball_radius_px)
	var height := "lift" if contact.y > 0.25 else "drive" if contact.y < -0.25 else "medium"
	if points.size() < 2:
		return "Height: %s - keep dragging" % height
	var follow := (points[points.size() - 1] - points[0]) / maxf(1.0, ball_panel.ball_radius_px)
	var curl := "left" if follow.x < -0.12 else "right" if follow.x > 0.12 else "straight"
	return "Height: %s - curl: %s" % [height, curl]

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
	support_zone_radius = clampf(absf(radius_edge.x - support_zone_center.x), 120.0, 230.0)
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
	# Minimum effective contact diameter: the swipe target must stay accurate on small screens.
	var min_radius := 70.0 * FreeKickUIScale.widget_scale(get_viewport().get_visible_rect().size.y)
	screen_radius = maxf(min_radius, screen_radius)
	var diameter := screen_radius * 2.0
	ball_panel.size = Vector2(diameter, diameter)
	ball_panel.position = center - ball_panel.size * 0.5
	ball_panel.ball_radius_px = screen_radius
	ball_panel.queue_redraw()

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

func show_game_over(text: String) -> void:
	instruction_label.text = text
	instruction_label.visible = true
	status_label.visible = false

func _show_primary_instruction(action: String, consequence: String) -> void:
	instruction_label.visible = true
	feedback_label.visible = true
	instruction_label.text = action
	feedback_label.text = consequence

func _power_feedback(power_value: float) -> String:
	if power_value < 0.40:
		return "low — let it build for more distance"
	if power_value < 0.70:
		return "controlled — building toward ideal"
	if power_value <= 0.85:
		return "ideal window — tap now"
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
	# Real drawn content (labels+bar+boot) spans ~300px, not 150 - using the true width here
	# keeps the mirrored left/right positioning math (see _position_power_meter_for_foot)
	# actually centered on the visible graphic instead of an undersized assumed box.
	power_meter.size = Vector2(310.0, 320.0)
	power_meter.kicking_foot = kicking_foot
	_position_power_meter_for_foot()
	_place_anchored(feedback_label, Vector2(0.0, 0.0), Vector2(24.0, 60.0), Vector2(520.0, 58.0))
	feedback_label.add_theme_font_size_override("font_size", 15)
	feedback_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.82))
	_place_anchored(instruction_label, Vector2(0.0, 1.0), Vector2(24.0, 64.0), Vector2(760.0, 28.0))
	instruction_label.add_theme_font_size_override("font_size", 20)
	instruction_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.9))
	instruction_label.remove_theme_stylebox_override("normal")
	_place_anchored(status_label, Vector2(0.0, 1.0), Vector2(24.0, 100.0), Vector2(520.0, 24.0))
	status_label.add_theme_font_size_override("font_size", 12)
	status_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.28))
	status_label.remove_theme_stylebox_override("normal")
	_style_button(restart_button, "Restart  R")
	_place_anchored(restart_button, Vector2(0.0, 1.0), Vector2(24.0, 24.0), Vector2(158.0, 40.0))
	restart_button.visible = false
	_style_button(switch_foot_button, "Foot  F")
	_place_anchored(switch_foot_button, Vector2(0.0, 1.0), Vector2(24.0, 70.0), Vector2(128.0, 32.0))
	switch_foot_button.visible = false
	_style_button(next_spot_button, next_spot_button.text)
	_place_anchored(next_spot_button, Vector2(0.0, 1.0), Vector2(24.0, 110.0), Vector2(196.0, 40.0))
	next_spot_button.visible = false
	_layout_corner_modules()

func align_power_meter_to_ball(ball: Node3D, camera: Camera3D) -> void:
	if ball == null or camera == null or power_meter == null:
		_position_power_meter_for_foot()
		return
	# Follow the ball horizontally only; vertical placement stays centered but
	# always below the score HUD band (on phones the ball can project high).
	var ball_screen := camera.unproject_position(ball.global_position)
	var side := 1.0 if kicking_foot == "right" else -1.0
	var viewport_height := get_viewport().get_visible_rect().size.y
	var desired := Vector2(ball_screen.x + side * 145.0 - power_meter.size.x * 0.5, (viewport_height - power_meter.size.y) * 0.5)
	desired.y = maxf(desired.y, SCORE_HUD_BOTTOM_BAND)
	power_meter.position = _clamp_to_uiroot(desired, power_meter.size)
	if power_label != null:
		power_label.position = power_meter.position + Vector2(0.0, -46.0)

func _position_power_meter_for_foot() -> void:
	if power_meter == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = Vector2(1280.0, 720.0)
	# Vertically centered relative to the live viewport so the meter sits mid-screen
	# on any device (phones expand the design space; a fixed y drifts upward there).
	var center_x := viewport_size.x * 0.5
	var side := 1.0 if kicking_foot == "right" else -1.0
	var desired := Vector2(center_x + side * 145.0 - power_meter.size.x * 0.5, (viewport_size.y - power_meter.size.y) * 0.5)
	desired.y = maxf(desired.y, SCORE_HUD_BOTTOM_BAND)
	power_meter.position = _clamp_to_uiroot(desired, power_meter.size)
	if power_label != null:
		power_label.position = power_meter.position + Vector2(0.0, -46.0)

## Keeps the power meter inside the safe-area UIRoot on small phone viewports.
## The below-HUD band wins over the bottom margin when the viewport is too short.
func _clamp_to_uiroot(desired_pos: Vector2, control_size: Vector2) -> Vector2:
	if ui_root == null:
		return desired_pos
	var x := clampf(desired_pos.x, ui_root.offset_left + 18.0, ui_root.size.x + ui_root.offset_left - control_size.x - 18.0)
	var y_min := ui_root.offset_top + SCORE_HUD_BOTTOM_BAND
	var y_max := ui_root.size.y + ui_root.offset_top - control_size.y - 72.0
	var y := clampf(desired_pos.y, y_min, maxf(y_min, y_max))
	return Vector2(x, y)

func _style_button(button: Button, text_value: String) -> void:
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
