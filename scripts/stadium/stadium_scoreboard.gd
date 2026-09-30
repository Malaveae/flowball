class_name StadiumScoreboard extends Node3D

@export var sub_viewport_path: NodePath = "ScoreboardViewport"
@export var scoreboard_ui_path: NodePath = "ScoreboardViewport/ScoreboardUI"

@onready var _sub_viewport: SubViewport = get_node(sub_viewport_path)
@onready var _ui: Control = get_node(scoreboard_ui_path)

# UI label references
var _title_label: Label
var _set_piece_label: Label
var _conversion_label: Label
var _stats_label: Label
var _misses_label: Label
var _step_labels: Array[Label] = []

const COLOR_YELLOW := Color(1.0, 0.9, 0.0, 1.0)
const COLOR_DIM := Color(0.5, 0.5, 0.5, 1.0)
const COLOR_ORANGE := Color(1.0, 0.55, 0.0, 1.0)
const COLOR_WHITE := Color(1.0, 1.0, 1.0, 1.0)
const COLOR_CYAN := Color(0.0, 0.8, 1.0, 1.0)

func _ready() -> void:
	_title_label = _ui.get_node("TitleLabel") as Label
	_set_piece_label = _ui.get_node("SetPieceLabel") as Label
	_conversion_label = _ui.get_node("ConversionLabel") as Label
	_stats_label = _ui.get_node("StatsLabel") as Label
	_misses_label = _ui.get_node("MissesLabel") as Label
	_step_labels.append(_ui.get_node("StepsContainer/Step1Label") as Label)
	_step_labels.append(_ui.get_node("StepsContainer/Step2Label") as Label)
	_step_labels.append(_ui.get_node("StepsContainer/Step3Label") as Label)

	set_set_piece(1)
	set_stats(0, 0, 0)
	set_active_step(1)

	# Conectar al EventBus para recibir datos del gameplay
	var event_bus := get_node("/root/FlowballEventBus") as Node
	if event_bus == null:
		push_warning("StadiumScoreboard: FlowballEventBus not found")
		return

	event_bus.set_piece_changed.connect(func(piece, label, dist):
		set_set_piece(piece)
	)

	event_bus.stats_updated.connect(func(goals, attempts, misses, max_misses):
		set_stats(goals, attempts, misses)
	)

	event_bus.power_phase_entered.connect(func():
		set_active_step(1)
	)

	event_bus.plant_phase_entered.connect(func():
		set_active_step(2)
	)

	event_bus.contact_phase_entered.connect(func():
		set_active_step(3)
	)

	event_bus.phase_changed.connect(func(from_phase, to_phase):
		var step_map := {"PowerState": 1, "SupportFootState": 2, "BallContactState": 3}
		if step_map.has(to_phase):
			set_active_step(step_map[to_phase])
	)

func set_set_piece(n: int) -> void:
	if _set_piece_label:
		_set_piece_label.text = "SET PIECE %02d" % n

func set_stats(goals: int, attempts: int, misses: int) -> void:
	if _stats_label:
		_stats_label.text = "%d/%d" % [goals, attempts]
	var conversion := 0 if attempts <= 0 else roundi(100.0 * float(goals) / float(attempts))
	set_conversion_text("CONVERSION %d%%" % conversion)
	if _misses_label:
		var filled: int = clampi(misses, 0, 3)
		var empty: int = 3 - filled
		var circles := ""
		for i in range(filled):
			circles += "●"
		for i in range(empty):
			circles += "○"
		_misses_label.text = "MISSES %s" % circles

func set_active_step(step: int) -> void:
	if _step_labels.is_empty():
		return
	for i in range(_step_labels.size()):
		var label: Label = _step_labels[i]
		if i + 1 == step:
			label.add_theme_color_override("font_color", COLOR_YELLOW)
		else:
			label.add_theme_color_override("font_color", COLOR_DIM)

func set_phase_label(step: int, label: String) -> void:
	if step >= 1 and step <= _step_labels.size():
		_step_labels[step - 1].text = label

func set_conversion_text(text: String) -> void:
	if _conversion_label:
		_conversion_label.text = text
