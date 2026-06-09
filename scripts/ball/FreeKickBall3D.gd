class_name FreeKickBall3D
extends RigidBody3D

signal launched(shot_params: ShotParams)
signal came_to_rest

@export var rest_speed_threshold: float = 0.25
@export var rest_time_required: float = 0.75
@export_file("*.png") var ball_albedo_texture_path := "res://assets/trionda.png"

var active_shot: ShotParams
var _rest_time := 0.0
var _net_capture_active := false
@onready var aerodynamics: BallAerodynamics3D = get_node_or_null("BallAerodynamics3D")

func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 8
	_apply_ball_texture()

func _apply_ball_texture() -> void:
	var image := Image.load_from_file(ball_albedo_texture_path)
	if image == null:
		push_warning("Could not load ball texture: %s" % ball_albedo_texture_path)
		return
	var texture := ImageTexture.create_from_image(image)
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.roughness = 0.42
	material.metallic = 0.0
	material.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	_apply_material_to_meshes(self, material)

func _apply_material_to_meshes(node: Node, material: Material) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		mesh_instance.material_override = material
	for child in node.get_children():
		_apply_material_to_meshes(child, material)

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if aerodynamics != null:
		aerodynamics.apply_forces(state)
	if active_shot != null:
		if state.linear_velocity.length() <= rest_speed_threshold:
			_rest_time += state.step
			if _rest_time >= rest_time_required:
				active_shot = null
				came_to_rest.emit()
		else:
			_rest_time = 0.0

func reset_for_free_kick(position: Vector3 = Vector3(0.0, 0.16, 0.0)) -> void:
	active_shot = null
	_rest_time = 0.0
	_net_capture_active = false
	freeze = true
	sleeping = false
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	global_transform = Transform3D(Basis(), position)
	reset_physics_interpolation()
	visible = true
	for child in get_children():
		if child is Node3D:
			(child as Node3D).visible = true
	call_deferred("_finish_reset_visibility", position)

func _finish_reset_visibility(position: Vector3) -> void:
	global_transform = Transform3D(Basis(), position)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	visible = true
	reset_physics_interpolation()

func launch(shot_params: ShotParams, kicker: Node3D = null, ignore_seconds: float = 0.2) -> void:
	active_shot = shot_params
	_rest_time = 0.0
	_net_capture_active = false
	freeze = false
	sleeping = false
	linear_velocity = shot_params.launch_velocity
	angular_velocity = shot_params.spin_axis.normalized() * shot_params.spin_rate
	if kicker != null:
		add_collision_exception_with(kicker)
		_restore_collision_exception_later(kicker, ignore_seconds)
	launched.emit(shot_params)

func capture_in_net(stop_delay: float = 0.18) -> void:
	if _net_capture_active:
		return
	_net_capture_active = true
	await get_tree().create_timer(stop_delay).timeout
	if not is_inside_tree() or not _net_capture_active:
		return
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	freeze = true
	sleeping = true
	if active_shot != null:
		active_shot = null
		came_to_rest.emit()

func _restore_collision_exception_later(kicker: Node, seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
	if is_instance_valid(kicker):
		remove_collision_exception_with(kicker)
