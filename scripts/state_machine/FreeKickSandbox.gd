extends Node3D

@onready var controller: FreeKickController = $FreeKickController
@onready var goalkeeper: Node = get_node_or_null("Goalkeeper")

const WALL_DISTANCE_FROM_BALL := 9.15
const DEFAULT_WALL_PLAYER_COUNT := 5
const WALL_PLAYER_SPACING := 0.78
const WALL_PLAYER_HEIGHT := 1.8
const WALL_PLAYER_RADIUS := 0.26
const GOAL_CENTER := Vector3(0.0, 1.2, -52.5)

var wall_root: Node3D
var wall_material: StandardMaterial3D
var wall_rng := RandomNumberGenerator.new()

const MAX_TRIALS_PER_SET_PIECE := 3
const MIN_FREE_KICK_DISTANCE := 20.0
const MAX_FREE_KICK_DISTANCE := 34.0
const MAX_LATERAL_OFFSET := 10.5
const WALL_VARIATION_START_LEVEL := 30
const WALL_MIN_HEIGHT_HIGH_LEVEL := 1.62
const WALL_MAX_HEIGHT_HIGH_LEVEL := 2.05
const WALL_JUMP_MIN_HEIGHT := 0.28
const WALL_JUMP_MAX_HEIGHT := 0.62
const WALL_JUMP_UP_SECONDS := 0.16
const WALL_JUMP_DOWN_SECONDS := 0.22

var set_piece_number := 1
var current_set_piece: Dictionary = {}
var total_goals := 0
var total_attempts := 0
var current_spot_attempts := 0
var current_spot_misses := 0
var current_spot_goal_scored := false
var game_over := false
var completed_set_pieces: Array[Dictionary] = []

func _ready() -> void:
	wall_rng.randomize()
	_setup_wall_dummies()
	_find_grass_patch()
	_setup_ground_shader()
	var goal_trigger := get_node_or_null("GoalTrigger") as GoalTrigger3D
	if goal_trigger != null:
		goal_trigger.goal_scored.connect(_on_goal_scored)
	controller.free_kick_finished.connect(_on_free_kick_finished)
	controller.shot_calculated.connect(_on_shot_calculated)
	_generate_set_piece()
	_apply_set_piece_spot()
	# Start immediately for prototype. In production, match controller would call this.
	_start_attempt("right")

func cycle_set_piece_spot() -> void:
	if game_over:
		return
	_advance_to_next_set_piece()
	_start_attempt(controller.input_data.selected_foot)

func start_new_attempt(selected_foot: String = "right") -> void:
	if game_over:
		return
	_start_attempt(selected_foot)

func _apply_set_piece_spot() -> void:
	var ball_position := current_set_piece["position"] as Vector3
	controller.set_free_kick_spot(String(current_set_piece["label"]), ball_position, GOAL_CENTER)
	_position_wall_dummies(ball_position, int(current_set_piece.get("wall_count", DEFAULT_WALL_PLAYER_COUNT)))
	_update_scoreboard()

func _start_attempt(selected_foot: String) -> void:
	if game_over:
		return
	current_spot_attempts += 1
	total_attempts += 1
	current_spot_goal_scored = false
	if goalkeeper != null:
		goalkeeper.call("reset_for_free_kick")
		goalkeeper.call("set_ready")
	controller.start_free_kick(selected_foot)
	_update_scoreboard()

func _advance_to_next_set_piece() -> void:
	set_piece_number += 1
	current_spot_attempts = 0
	current_spot_misses = 0
	current_spot_goal_scored = false
	_generate_set_piece()
	_apply_set_piece_spot()

func _on_goal_scored() -> void:
	if current_spot_goal_scored:
		return
	current_spot_goal_scored = true
	total_goals += 1
	completed_set_pieces.append({
		"label": String(current_set_piece["label"]),
		"attempts": current_spot_attempts,
	})
	_update_scoreboard("GOAL! %s completed in %d attempt%s. Next set piece..." % [String(current_set_piece["label"]), current_spot_attempts, "" if current_spot_attempts == 1 else "s"])
	await get_tree().create_timer(1.25).timeout
	if game_over:
		return
	_advance_to_next_set_piece()
	_start_attempt(controller.input_data.selected_foot)

func _on_shot_calculated(shot_params: ShotParams) -> void:
	_trigger_wall_jump_reactions()
	if goalkeeper != null:
		goalkeeper.call("react_to_shot", shot_params, _predict_target_at_goal(shot_params))

func _on_free_kick_finished(report: Resource) -> void:
	if game_over or current_spot_goal_scored:
		return
	if report != null and report.get("outcome") == &"goal":
		if goalkeeper != null:
			goalkeeper.call("play_goal_conceded_reaction")
		return
	current_spot_misses = mini(current_spot_misses + 1, MAX_TRIALS_PER_SET_PIECE)
	_update_scoreboard()
	if current_spot_misses >= MAX_TRIALS_PER_SET_PIECE:
		_game_over()

func _game_over() -> void:
	game_over = true
	_update_scoreboard("GAME OVER - failed to score in %d trials." % MAX_TRIALS_PER_SET_PIECE)
	if controller != null and controller.ui != null:
		controller.ui.hide_all()
		controller.ui.set_scoreboard(_scoreboard_text("GAME OVER - failed to score in %d trials. Press R to restart run." % MAX_TRIALS_PER_SET_PIECE))

func _update_scoreboard(message: String = "") -> void:
	if controller != null and controller.ui != null:
		if controller.ui.has_method("set_run_hud"):
			controller.ui.set_run_hud(set_piece_number, total_goals, total_attempts, current_spot_misses, MAX_TRIALS_PER_SET_PIECE, message)
		else:
			controller.ui.set_scoreboard(_scoreboard_text(message))

func _scoreboard_text(message: String = "") -> String:
	var trials_left: int = maxi(0, MAX_TRIALS_PER_SET_PIECE - current_spot_attempts)
	var text: String = "SET PIECE %d  -  GOALS %d  -  ATTEMPTS %d\n%s  -  TRIAL %d/%d  -  LEFT %d" % [set_piece_number, total_goals, total_attempts, String(current_set_piece.get("label", "Set piece")), current_spot_attempts, MAX_TRIALS_PER_SET_PIECE, trials_left]
	if message != "":
		text += "\n%s" % message
	return text

func _restart_run() -> void:
	game_over = false
	set_piece_number = 1
	total_goals = 0
	total_attempts = 0
	current_spot_attempts = 0
	current_spot_misses = 0
	current_spot_goal_scored = false
	completed_set_pieces.clear()
	_generate_set_piece()
	_apply_set_piece_spot()
	_start_attempt(controller.input_data.selected_foot)

func _generate_set_piece() -> void:
	var difficulty_step: int = set_piece_number - 1
	var distance: float = clampf(20.0 + float(difficulty_step) * 1.15, MIN_FREE_KICK_DISTANCE, MAX_FREE_KICK_DISTANCE)
	var lateral_limit: float = minf(MAX_LATERAL_OFFSET, 2.0 + float(difficulty_step) * 0.85)
	var lateral_wave: float = sin(float(set_piece_number) * 1.83) * lateral_limit
	var z: float = GOAL_CENTER.z + distance
	var wall_count: int = clampi(difficulty_step / 2, 0, DEFAULT_WALL_PLAYER_COUNT)
	
	# After set piece 50, bias toward penalty area corners: shorter distance, higher lateral.
	if set_piece_number > 50:
		var corner_factor := clampf(float(set_piece_number - 51) / 12.0, 0.0, 1.0)
		lateral_limit = lerpf(lateral_limit, 18.0, corner_factor)
		lateral_wave = sin(float(set_piece_number) * 2.47 + 1.2) * lateral_limit
		var corner_distance := 20.0 + float((set_piece_number - 51) % 5) * 2.0
		distance = lerpf(distance, corner_distance, corner_factor)
		z = GOAL_CENTER.z + distance
	
	var side_label: String = "center" if absf(lateral_wave) < 1.5 else "left" if lateral_wave < 0.0 else "right"
	current_set_piece = {
		"label": "#%d %s %.0fm - wall %d" % [set_piece_number, side_label.capitalize(), distance, wall_count],
		"position": Vector3(lateral_wave, 0.16, z),
		"wall_count": wall_count,
	}

var _grass_patches: Array[GrassPatch3D] = []

func _find_grass_patch() -> void:
	_grass_patches.clear()
	for i in range(14):
		var patch := get_node_or_null("GrassPatch%d" % i) as GrassPatch3D
		if patch:
			_grass_patches.append(patch)

func _process(_delta: float) -> void:
	if _grass_patches.is_empty():
		return
	var positions: Array[Vector3] = []
	var ball := controller.get_ball()
	if ball:
		positions.append(ball.global_position)
	# Could also add wall dummies, goalkeeper, etc.
	for patch in _grass_patches:
		patch.set_actor_positions(positions)

func _setup_ground_shader() -> void:
	var pitch_mesh := get_node_or_null("TestPitch/PitchMesh") as MeshInstance3D
	if pitch_mesh == null:
		return
	var shader := load("res://assets/shaders/pitch_ground.gdshader") as Shader
	if shader == null:
		return
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("albedo_tex", load("res://assets/Cesped/grass_albedo_2048.png"))
	mat.set_shader_parameter("normal_tex", load("res://assets/Cesped/grass_normal_1024.png"))
	mat.set_shader_parameter("rough_tex",  load("res://assets/Cesped/grass_roughness_1024.png"))
	mat.set_shader_parameter("uv_scale_x", 42.0)
	mat.set_shader_parameter("uv_scale_y", 64.0)
	mat.set_shader_parameter("patch_noise_scale", 3.5)
	mat.set_shader_parameter("patch_noise_strength", 0.12)
	pitch_mesh.material_override = mat
	var goal_floor := get_node_or_null("GoalBackgroundFloor/Mesh") as MeshInstance3D
	if goal_floor != null:
		goal_floor.material_override = mat.duplicate()

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

func _predict_target_at_goal(shot_params: ShotParams) -> Vector3:
	if shot_params == null:
		return GOAL_CENTER
	var ball := controller.get_ball()
	var origin := Vector3.ZERO if ball == null else ball.global_position
	var velocity := shot_params.launch_velocity
	if absf(velocity.z) < 0.001:
		return GOAL_CENTER
	var time_to_goal_plane := (GOAL_CENTER.z - origin.z) / velocity.z
	if time_to_goal_plane < 0.0:
		return GOAL_CENTER
	var gravity := ProjectSettings.get_setting("physics/3d/default_gravity") as float
	var predicted := origin + velocity * time_to_goal_plane
	predicted.y -= 0.5 * gravity * time_to_goal_plane * time_to_goal_plane
	predicted.z = GOAL_CENTER.z
	return predicted

func _position_wall_dummies(ball_position: Vector3, active_wall_count: int = DEFAULT_WALL_PLAYER_COUNT) -> void:
	if wall_root == null:
		return
	active_wall_count = clampi(active_wall_count, 0, wall_root.get_child_count())
	var wall_heights := _roll_wall_heights(active_wall_count)
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
		var height := WALL_PLAYER_HEIGHT if i >= wall_heights.size() else wall_heights[i]
		_apply_wall_dummy_height(dummy, height)
		for child in dummy.get_children():
			if child is CollisionShape3D:
				(child as CollisionShape3D).disabled = i >= active_wall_count
		if i >= active_wall_count:
			continue
		var lateral := first_offset + float(i) * WALL_PLAYER_SPACING
		dummy.global_position = wall_center + right * lateral + Vector3.UP * (height * 0.5)
		dummy.set_meta("base_global_position", dummy.global_position)

func _roll_wall_heights(active_wall_count: int) -> Array[float]:
	var heights: Array[float] = []
	for i in range(active_wall_count):
		if set_piece_number >= WALL_VARIATION_START_LEVEL:
			heights.append(wall_rng.randf_range(WALL_MIN_HEIGHT_HIGH_LEVEL, WALL_MAX_HEIGHT_HIGH_LEVEL))
		else:
			heights.append(WALL_PLAYER_HEIGHT)
	return heights

func _apply_wall_dummy_height(dummy: Node3D, height: float) -> void:
	for child in dummy.get_children():
		if child is CollisionShape3D:
			var collision := child as CollisionShape3D
			var capsule_shape := collision.shape as CapsuleShape3D
			if capsule_shape != null:
				capsule_shape.height = height
		elif child is MeshInstance3D:
			var mesh_instance := child as MeshInstance3D
			var capsule_mesh := mesh_instance.mesh as CapsuleMesh
			if capsule_mesh != null:
				capsule_mesh.height = height

func _trigger_wall_jump_reactions() -> void:
	if wall_root == null or set_piece_number < WALL_VARIATION_START_LEVEL:
		return
	var active_dummies: Array[Node3D] = []
	for child in wall_root.get_children():
		var dummy := child as Node3D
		if dummy != null and dummy.visible:
			active_dummies.append(dummy)
	if active_dummies.is_empty():
		return
	var jump_probability := clampf(0.35 + float(set_piece_number - WALL_VARIATION_START_LEVEL) * 0.015, 0.35, 0.9)
	var jumped := false
	for dummy in active_dummies:
		if wall_rng.randf() <= jump_probability:
			_jump_wall_dummy(dummy)
			jumped = true
	if not jumped:
		_jump_wall_dummy(active_dummies[wall_rng.randi_range(0, active_dummies.size() - 1)])

func _jump_wall_dummy(dummy: Node3D) -> void:
	var base_position := dummy.global_position
	if dummy.has_meta("base_global_position"):
		base_position = dummy.get_meta("base_global_position") as Vector3
	dummy.global_position = base_position
	var jump_height := wall_rng.randf_range(WALL_JUMP_MIN_HEIGHT, WALL_JUMP_MAX_HEIGHT)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(dummy, "global_position", base_position + Vector3.UP * jump_height, WALL_JUMP_UP_SECONDS)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(dummy, "global_position", base_position, WALL_JUMP_DOWN_SECONDS)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("free_kick_restart"):
		if game_over:
			_restart_run()
		else:
			_start_attempt(controller.input_data.selected_foot)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("free_kick_switch_foot"):
		controller._on_switch_foot_requested()
		get_viewport().set_input_as_handled()
