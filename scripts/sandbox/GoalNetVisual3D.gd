class_name GoalNetVisual3D
extends Node3D

## Visual net for the goal.
## Uses the Blender-built mesh (assets/models/goal_net.glb) with a GPU vertex
## shader for impact deformation. Falls back to the legacy procedural
## cylinder net when the imported mesh is unavailable.

@export var width := 7.32
@export var height := 2.44
@export var depth := 1.35
@export var cord_radius := 0.008
@export var reaction_strength := 0.42
@export var recovery_speed := 7.5

@export_file("*.glb") var net_mesh_path := "res://assets/models/goal_net.glb"
@export_file("*.glb") var back_frame_path := "res://assets/models/goal_back_frame.glb"
@export var shader_path := "res://assets/shaders/goal_net.gdshader"

var _material: StandardMaterial3D
var _shader_material: ShaderMaterial
var _mesh_instance: MeshInstance3D
var _segments: Array[Dictionary] = []
var _impact_point := Vector3.ZERO
var _impulse := 0.0

func _ready() -> void:
	if _try_load_imported_net():
		_try_load_back_frame()
		return
	_build_material()
	_build_net()
	_try_load_back_frame()

## Loads the rear support frame that follows the net shape.
## Static mesh; intentionally NOT wired to the deformation shader.
func _try_load_back_frame() -> bool:
	if not ResourceLoader.exists(back_frame_path):
		return false
	var packed: PackedScene = load(back_frame_path)
	if packed == null:
		return false
	add_child(packed.instantiate())
	return true

## Returns true when the Blender net mesh was loaded and wired to the shader.
func _try_load_imported_net() -> bool:
	if not ResourceLoader.exists(net_mesh_path):
		return false
	var packed: PackedScene = load(net_mesh_path)
	if packed == null:
		return false
	var shader: Shader = load(shader_path) if ResourceLoader.exists(shader_path) else null
	if shader == null:
		return false
	var instance := packed.instantiate()
	var mesh_instance := _first_mesh_instance(instance)
	if mesh_instance == null:
		instance.free()
		return false
	add_child(instance)
	_mesh_instance = mesh_instance
	_shader_material = ShaderMaterial.new()
	_shader_material.shader = shader
	_mesh_instance.material_override = _shader_material
	return true

func _first_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found := _first_mesh_instance(child)
		if found != null:
			return found
	return null

func react_to_ball(ball: Node3D) -> void:
	if ball == null:
		return
	_impact_point = to_local(ball.global_position)
	_impulse = reaction_strength
	_apply_impulse()

func _process(delta: float) -> void:
	if _impulse <= 0.001:
		return
	_impulse = move_toward(_impulse, 0.0, recovery_speed * delta * reaction_strength)
	_apply_impulse()

func _apply_impulse() -> void:
	if _mesh_instance != null and _shader_material != null:
		_shader_material.set_shader_parameter("impulse", _impulse)
		_shader_material.set_shader_parameter("impact_point", _impact_point)
	else:
		_update_segments()

# ---------------------------------------------------------------------------
# Legacy procedural fallback (unchanged behavior when the GLB is missing)
# ---------------------------------------------------------------------------

func _build_material() -> void:
	_material = StandardMaterial3D.new()
	_material.albedo_color = Color(0.78, 0.92, 1.0, 0.52)
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.flags_transparent = true
	_material.roughness = 0.86
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL

func _build_net() -> void:
	for child in get_children():
		child.queue_free()
	_segments.clear()
	var half_w := width * 0.5
	var back_z := -depth

	for i in range(17):
		var x := -half_w + width * float(i) / 16.0
		_add_segment(Vector3(x, 0.10, back_z), Vector3(x, height * 0.92, back_z), true)
	for j in range(9):
		var y := 0.10 + (height * 0.82) * float(j) / 8.0
		_add_segment(Vector3(-half_w, y, back_z), Vector3(half_w, y, back_z), true)

	for i in range(13):
		var x := -half_w + width * float(i) / 12.0
		_add_segment(Vector3(x, height, 0.0), Vector3(x, height * 0.92, back_z), true)
	for k in range(5):
		var z := -depth * float(k) / 4.0
		var y := height - 0.08 * float(k)
		_add_segment(Vector3(-half_w, y, z), Vector3(half_w, y, z), true)

	for side_x in [-half_w, half_w]:
		for j in range(7):
			var y := 0.12 + (height - 0.22) * float(j) / 6.0
			_add_segment(Vector3(side_x, y, 0.0), Vector3(side_x, y * 0.94, back_z), true)
		for k in range(5):
			var z := -depth * float(k) / 4.0
			_add_segment(Vector3(side_x, 0.12, z), Vector3(side_x, height - 0.10 * float(k), z), true)
	_update_segments()

func _add_segment(start: Vector3, end: Vector3, reactive: bool) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = cord_radius
	mesh.bottom_radius = cord_radius
	mesh.height = 1.0
	mesh.radial_segments = 8
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _material
	add_child(instance)
	_segments.append({"node": instance, "start": start, "end": end, "reactive": reactive})

func _update_segments() -> void:
	for segment in _segments:
		var start := segment["start"] as Vector3
		var end := segment["end"] as Vector3
		if segment["reactive"]:
			start += _net_displacement(start)
			end += _net_displacement(end)
		_place_cylinder(segment["node"] as MeshInstance3D, start, end)

func _net_displacement(point: Vector3) -> Vector3:
	if _impulse <= 0.001:
		return Vector3.ZERO
	var distance := point.distance_to(_impact_point)
	var weight := clampf(1.0 - distance / 2.0, 0.0, 1.0)
	weight = weight * weight
	return Vector3(0.0, -_impulse * 0.18 * weight, -_impulse * weight)

func _place_cylinder(instance: MeshInstance3D, start: Vector3, end: Vector3) -> void:
	var direction := end - start
	var length := direction.length()
	if length <= 0.001:
		return
	var rotation := Quaternion(Vector3.UP, direction.normalized())
	instance.transform = Transform3D(Basis(rotation).scaled(Vector3(1.0, length, 1.0)), (start + end) * 0.5)
