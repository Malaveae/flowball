class_name TrajectoryGhost3D
extends MeshInstance3D

@export var line_width_visual_hint: float = 0.035
@export var ghost_color: Color = Color(0.2, 0.85, 1.0, 0.9)
@export var point_scale: float = 0.035

var _material: StandardMaterial3D

func _ready() -> void:
	_material = StandardMaterial3D.new()
	_material.albedo_color = ghost_color
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.no_depth_test = false
	material_override = _material
	clear()

func clear() -> void:
	mesh = ImmediateMesh.new()
	visible = false

func show_telemetry(telemetry: BallFlightTelemetry) -> void:
	if telemetry == null or telemetry.positions.size() < 2:
		clear()
		return

	var immediate := ImmediateMesh.new()
	immediate.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for position in telemetry.positions:
		immediate.surface_set_color(ghost_color)
		immediate.surface_add_vertex(position)
	immediate.surface_end()
	mesh = immediate
	visible = true
