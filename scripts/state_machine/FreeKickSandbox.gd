extends Node3D

@onready var controller: FreeKickController = $FreeKickController

const WALL_DISTANCE_FROM_BALL := 9.15
const WALL_PLAYER_COUNT := 5
const WALL_PLAYER_SPACING := 0.78
const WALL_PLAYER_HEIGHT := 1.8
const WALL_PLAYER_RADIUS := 0.26
const GOAL_CENTER := Vector3(0.0, 1.2, -24.0)

var wall_root: Node3D
var wall_material: StandardMaterial3D

var set_piece_spots := [
	{"label": "Center 24m", "position": Vector3(0.0, 0.16, 0.0)},
	{"label": "Left half-space 22m", "position": Vector3(-4.5, 0.16, -2.0)},
	{"label": "Right half-space 22m", "position": Vector3(4.5, 0.16, -2.0)},
	{"label": "Deep center 30m", "position": Vector3(0.0, 0.16, 6.0)},
	{"label": "Wide left 25m", "position": Vector3(-7.5, 0.16, 0.5)},
	{"label": "Wide right 25m", "position": Vector3(7.5, 0.16, 0.5)},
]
var spot_index := 0

func _ready() -> void:
	_setup_wall_dummies()
	_apply_set_piece_spot()
	# Start immediately for prototype. In production, match controller would call this.
	controller.start_free_kick("right")

func cycle_set_piece_spot() -> void:
	spot_index = (spot_index + 1) % set_piece_spots.size()
	_apply_set_piece_spot()
	controller.start_free_kick(controller.input_data.selected_foot)

func _apply_set_piece_spot() -> void:
	var spot: Dictionary = set_piece_spots[spot_index]
	var ball_position := spot["position"] as Vector3
	controller.set_free_kick_spot(String(spot["label"]), ball_position)
	_position_wall_dummies(ball_position)

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

	for i in range(WALL_PLAYER_COUNT):
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

func _position_wall_dummies(ball_position: Vector3) -> void:
	if wall_root == null:
		return
	var flat_goal := Vector3(GOAL_CENTER.x, ball_position.y, GOAL_CENTER.z)
	var to_goal := flat_goal - ball_position
	if to_goal.length() < 0.01:
		to_goal = Vector3(0.0, 0.0, -1.0)
	var forward := to_goal.normalized()
	var right := forward.cross(Vector3.UP).normalized()
	var wall_center := ball_position + forward * WALL_DISTANCE_FROM_BALL
	var first_offset := -float(WALL_PLAYER_COUNT - 1) * WALL_PLAYER_SPACING * 0.5

	for i in range(wall_root.get_child_count()):
		var dummy := wall_root.get_child(i) as Node3D
		var lateral := first_offset + float(i) * WALL_PLAYER_SPACING
		dummy.global_position = wall_center + right * lateral + Vector3.UP * (WALL_PLAYER_HEIGHT * 0.5)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("free_kick_restart"):
		controller.start_free_kick(controller.input_data.selected_foot)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("free_kick_switch_foot"):
		controller._on_switch_foot_requested()
		get_viewport().set_input_as_handled()
