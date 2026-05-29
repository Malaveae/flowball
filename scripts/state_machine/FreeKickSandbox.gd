extends Node3D

@onready var controller: FreeKickController = $FreeKickController

const WALL_DISTANCE_FROM_BALL := 9.15
const DEFAULT_WALL_PLAYER_COUNT := 5
const WALL_PLAYER_SPACING := 0.78
const WALL_PLAYER_HEIGHT := 1.8
const WALL_PLAYER_RADIUS := 0.26
const GOAL_CENTER := Vector3(0.0, 1.2, -24.0)

var wall_root: Node3D
var wall_material: StandardMaterial3D

var set_piece_spots := [
	{"label": "Warm-up center 20m", "position": Vector3(0.0, 0.16, -4.0), "wall_count": 0},
	{"label": "Center 24m", "position": Vector3(0.0, 0.16, 0.0), "wall_count": 0},
	{"label": "Left half-space 22m", "position": Vector3(-4.5, 0.16, -2.0), "wall_count": 2},
	{"label": "Right half-space 22m", "position": Vector3(4.5, 0.16, -2.0), "wall_count": 2},
	{"label": "Deep center 30m", "position": Vector3(0.0, 0.16, 6.0), "wall_count": 4},
	{"label": "Wide left 25m", "position": Vector3(-7.5, 0.16, 0.5), "wall_count": 5},
	{"label": "Wide right 25m", "position": Vector3(7.5, 0.16, 0.5), "wall_count": 5},
]
var spot_index := 0
var total_goals := 0
var total_attempts := 0
var current_spot_attempts := 0
var current_spot_goal_scored := false
var completed_set_pieces: Array[Dictionary] = []

func _ready() -> void:
	_setup_wall_dummies()
	var goal_trigger := get_node_or_null("GoalTrigger") as GoalTrigger3D
	if goal_trigger != null:
		goal_trigger.goal_scored.connect(_on_goal_scored)
	_apply_set_piece_spot()
	# Start immediately for prototype. In production, match controller would call this.
	_start_attempt("right")

func cycle_set_piece_spot() -> void:
	_advance_to_next_set_piece()
	_start_attempt(controller.input_data.selected_foot)

func start_new_attempt(selected_foot: String = "right") -> void:
	_start_attempt(selected_foot)

func _apply_set_piece_spot() -> void:
	var spot: Dictionary = set_piece_spots[spot_index]
	var ball_position := spot["position"] as Vector3
	controller.set_free_kick_spot(String(spot["label"]), ball_position)
	_position_wall_dummies(ball_position, int(spot.get("wall_count", DEFAULT_WALL_PLAYER_COUNT)))
	_update_scoreboard()

func _start_attempt(selected_foot: String) -> void:
	current_spot_attempts += 1
	total_attempts += 1
	current_spot_goal_scored = false
	controller.start_free_kick(selected_foot)
	_update_scoreboard()

func _advance_to_next_set_piece() -> void:
	spot_index = (spot_index + 1) % set_piece_spots.size()
	current_spot_attempts = 0
	current_spot_goal_scored = false
	_apply_set_piece_spot()

func _on_goal_scored() -> void:
	if current_spot_goal_scored:
		return
	current_spot_goal_scored = true
	total_goals += 1
	completed_set_pieces.append({
		"label": String(set_piece_spots[spot_index]["label"]),
		"attempts": current_spot_attempts,
	})
	_update_scoreboard("GOAL! %s completed in %d attempt%s. Next set piece..." % [String(set_piece_spots[spot_index]["label"]), current_spot_attempts, "" if current_spot_attempts == 1 else "s"])
	await get_tree().create_timer(1.25).timeout
	_advance_to_next_set_piece()
	_start_attempt(controller.input_data.selected_foot)

func _update_scoreboard(message: String = "") -> void:
	var spot: Dictionary = set_piece_spots[spot_index]
	var text := "SPOT %d/%d  ·  GOALS %d  ·  ATTEMPTS %d\n%s  ·  THIS SPOT %d" % [spot_index + 1, set_piece_spots.size(), total_goals, total_attempts, String(spot["label"]), current_spot_attempts]
	if message != "":
		text += "\n%s" % message
	if controller != null and controller.ui != null:
		controller.ui.set_scoreboard(text)

func _setup_wall_dummies() -> void:
	wall_root = Node3D.new()
	wall_root.name = "FreeKickWallDummies"
	add_child(wall_root)

	wall_material = StandardMaterial3D.new()
	wall_material.albedo_color = Color(0.25, 0.75, 1.0, 0.38)
	wall_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wall_material.flags_transparent = true
	wall_material.no_depth_test = false
	wall_material.cull_mode = BaseMaterial3D.CULL_DISABLED

	for i in range(DEFAULT_WALL_PLAYER_COUNT):
		var dummy := StaticBody3D.new()
		dummy.name = "WallDummy%d" % (i + 1)
		dummy.physics_material_override = _wall_physics_material()
		wall_root.add_child(dummy)

		var shape := CollisionShape3D.new()
		var capsule_shape := CapsuleShape3D.new()
		capsule_shape.radius = WALL_PLAYER_RADIUS
		capsule_shape.height = WALL_PLAYER_HEIGHT
		shape.shape = capsule_shape
		dummy.add_child(shape)

		var mesh := MeshInstance3D.new()
		var capsule_mesh := CapsuleMesh.new()
		capsule_mesh.radius = WALL_PLAYER_RADIUS
		capsule_mesh.height = WALL_PLAYER_HEIGHT
		mesh.mesh = capsule_mesh
		mesh.material_override = wall_material
		dummy.add_child(mesh)

func _wall_physics_material() -> PhysicsMaterial:
	var material := PhysicsMaterial.new()
	material.friction = 0.7
	material.bounce = 0.12
	return material

func _position_wall_dummies(ball_position: Vector3, active_wall_count: int = DEFAULT_WALL_PLAYER_COUNT) -> void:
	if wall_root == null:
		return
	active_wall_count = clampi(active_wall_count, 0, wall_root.get_child_count())
	var flat_goal := Vector3(GOAL_CENTER.x, ball_position.y, GOAL_CENTER.z)
	var to_goal := flat_goal - ball_position
	if to_goal.length() < 0.01:
		to_goal = Vector3(0.0, 0.0, -1.0)
	var forward := to_goal.normalized()
	var right := forward.cross(Vector3.UP).normalized()
	var wall_center := ball_position + forward * WALL_DISTANCE_FROM_BALL
	var first_offset := -float(active_wall_count - 1) * WALL_PLAYER_SPACING * 0.5

	for i in range(wall_root.get_child_count()):
		var dummy := wall_root.get_child(i) as Node3D
		dummy.visible = i < active_wall_count
		for child in dummy.get_children():
			if child is CollisionShape3D:
				(child as CollisionShape3D).disabled = i >= active_wall_count
		if i >= active_wall_count:
			continue
		var lateral := first_offset + float(i) * WALL_PLAYER_SPACING
		dummy.global_position = wall_center + right * lateral + Vector3.UP * (WALL_PLAYER_HEIGHT * 0.5)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("free_kick_restart"):
		_start_attempt(controller.input_data.selected_foot)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("free_kick_switch_foot"):
		controller._on_switch_foot_requested()
		get_viewport().set_input_as_handled()
