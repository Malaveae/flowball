class_name BallFlightTrail
extends Node3D

## Deterministic 3D line behind the flying ball. Records positions each physics
## frame; older points fade. No RNG: same shot, same trail.

const MAX_POINTS := 240
const FADE_LIFETIME := 1.2  # seconds for a point to fade out

var _ball: Node3D
var _points: PackedVector3Array = PackedVector3Array()
var _ages: Array[float] = []
var _fading := false
var _fade_elapsed := 0.0
var _fade_duration := 0.5
var _mesh: ImmediateMesh
var _mesh_instance: MeshInstance3D

func _ready() -> void:
	# Keep recording while the ball flies even if other nodes pause.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_mesh = ImmediateMesh.new()
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.mesh = _mesh
	_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh_instance)

func begin_tracking(ball: Node3D) -> void:
	_ball = ball
	_points.clear()
	_ages.clear()
	_fading = false
	_fade_elapsed = 0.0
	set_process(true)
	set_physics_process(true)

func stop_and_fade() -> void:
	if _points.is_empty():
		queue_free()
		return
	_fading = true
	_fade_elapsed = 0.0
	set_physics_process(false)

func _physics_process(_delta: float) -> void:
	if _ball == null:
		return
	_points.append(_ball.global_position)
	_ages.append(0.0)
	while _points.size() > MAX_POINTS:
		_points.remove_at(0)
		_ages.remove_at(0)
	_redraw()

func _process(delta: float) -> void:
	if not _fading:
		return
	_fade_elapsed += delta
	if _fade_elapsed >= _fade_duration:
		queue_free()
		return
	for i in _ages.size():
		_ages[i] += delta
	_redraw()

func _redraw() -> void:
	_mesh.clear_surfaces()
	if _points.size() < 2:
		return
	_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in range(1, _points.size()):
		var age := _ages[i] if i < _ages.size() else 0.0
		var alpha := clampf(1.0 - age / FADE_LIFETIME, 0.0, 1.0) * (1.0 - _fade_elapsed / _fade_duration if _fading else 1.0)
		if alpha <= 0.01:
			continue
		var color := Color(0.2, 0.9, 1.0, alpha)
		_mesh.surface_set_color(color)
		_mesh.surface_add_vertex(_points[i - 1])
		_mesh.surface_set_color(color)
		_mesh.surface_add_vertex(_points[i])
	_mesh.surface_end()
