class_name FootballFieldMarkings3D
extends Node3D

# FIFA/IFAB common international pitch dimensions, in meters.
const PITCH_LENGTH := 105.0
const PITCH_WIDTH := 68.0
const LINE_WIDTH := 0.12
const GOAL_WIDTH := 7.32
const PENALTY_AREA_DEPTH := 16.5
const PENALTY_AREA_WIDTH := 40.32 # 16.5m from each goalpost edge.
const GOAL_AREA_DEPTH := 5.5
const GOAL_AREA_WIDTH := 18.32 # 5.5m from each goalpost edge.
const PENALTY_MARK_DISTANCE := 11.0
const CENTER_CIRCLE_RADIUS := 9.15
const PENALTY_ARC_RADIUS := 9.15
const CORNER_ARC_RADIUS := 1.0
const LINE_Y := 0.062

@export var line_color: Color = Color(0.92, 0.92, 0.86, 1.0)
@export var line_height: float = 0.012
@export var arc_segments: int = 48

var _line_material: StandardMaterial3D

func _ready() -> void:
	_build_real_field_markings()

func _build_real_field_markings() -> void:
	for child in get_children():
		child.queue_free()
	_line_material = StandardMaterial3D.new()
	_line_material.albedo_color = line_color
	_line_material.roughness = 0.65

	var half_w := PITCH_WIDTH * 0.5
	var half_l := PITCH_LENGTH * 0.5

	# Boundary and halfway lines. X = field width, Z = field length. Goal being attacked is at -Z.
	_add_line("NorthGoalLine", Vector3(0.0, LINE_Y, -half_l), Vector3(PITCH_WIDTH, line_height, LINE_WIDTH))
	_add_line("SouthGoalLine", Vector3(0.0, LINE_Y, half_l), Vector3(PITCH_WIDTH, line_height, LINE_WIDTH))
	_add_line("LeftTouchline", Vector3(-half_w, LINE_Y, 0.0), Vector3(LINE_WIDTH, line_height, PITCH_LENGTH))
	_add_line("RightTouchline", Vector3(half_w, LINE_Y, 0.0), Vector3(LINE_WIDTH, line_height, PITCH_LENGTH))
	_add_line("HalfwayLine", Vector3(0.0, LINE_Y, 0.0), Vector3(PITCH_WIDTH, line_height, LINE_WIDTH))

	_add_rect_open_to_goal("NorthPenaltyArea", -half_l, PENALTY_AREA_DEPTH, PENALTY_AREA_WIDTH, -1.0)
	_add_rect_open_to_goal("SouthPenaltyArea", half_l, PENALTY_AREA_DEPTH, PENALTY_AREA_WIDTH, 1.0)
	_add_rect_open_to_goal("NorthGoalArea", -half_l, GOAL_AREA_DEPTH, GOAL_AREA_WIDTH, -1.0)
	_add_rect_open_to_goal("SouthGoalArea", half_l, GOAL_AREA_DEPTH, GOAL_AREA_WIDTH, 1.0)

	_add_spot("CenterSpot", Vector3.ZERO, 0.22)
	_add_arc("CenterCircle", Vector3.ZERO, CENTER_CIRCLE_RADIUS, 0.0, TAU)

	_add_spot("NorthPenaltyMark", Vector3(0.0, 0.0, -half_l + PENALTY_MARK_DISTANCE), 0.22)
	_add_spot("SouthPenaltyMark", Vector3(0.0, 0.0, half_l - PENALTY_MARK_DISTANCE), 0.22)
	_add_penalty_arc("NorthPenaltyArc", Vector3(0.0, 0.0, -half_l + PENALTY_MARK_DISTANCE), -half_l + PENALTY_AREA_DEPTH, -1.0)
	_add_penalty_arc("SouthPenaltyArc", Vector3(0.0, 0.0, half_l - PENALTY_MARK_DISTANCE), half_l - PENALTY_AREA_DEPTH, 1.0)

	_add_corner_arc("NorthLeftCornerArc", Vector3(-half_w, 0.0, -half_l), 0.0, PI * 0.5)
	_add_corner_arc("NorthRightCornerArc", Vector3(half_w, 0.0, -half_l), PI * 0.5, PI)
	_add_corner_arc("SouthRightCornerArc", Vector3(half_w, 0.0, half_l), PI, PI * 1.5)
	_add_corner_arc("SouthLeftCornerArc", Vector3(-half_w, 0.0, half_l), PI * 1.5, TAU)

func _add_rect_open_to_goal(prefix: String, goal_z: float, depth: float, width: float, goal_sign: float) -> void:
	var top_z := goal_z - goal_sign * depth
	var center_z := goal_z - goal_sign * depth * 0.5
	var half_width := width * 0.5
	_add_line("%sTop" % prefix, Vector3(0.0, LINE_Y, top_z), Vector3(width, line_height, LINE_WIDTH))
	_add_line("%sLeft" % prefix, Vector3(-half_width, LINE_Y, center_z), Vector3(LINE_WIDTH, line_height, depth))
	_add_line("%sRight" % prefix, Vector3(half_width, LINE_Y, center_z), Vector3(LINE_WIDTH, line_height, depth))

func _add_penalty_arc(name: String, spot: Vector3, area_top_z: float, goal_sign: float) -> void:
	var points: PackedVector3Array = PackedVector3Array()
	var start := 0.0
	var end := PI
	if goal_sign > 0.0:
		start = PI
		end = TAU
	for i in range(arc_segments + 1):
		var t := float(i) / float(arc_segments)
		var angle := lerpf(start, end, t)
		var p := spot + Vector3(cos(angle) * PENALTY_ARC_RADIUS, 0.0, sin(angle) * PENALTY_ARC_RADIUS)
		if goal_sign < 0.0 and p.z >= area_top_z:
			points.append(p)
		elif goal_sign > 0.0 and p.z <= area_top_z:
			points.append(p)
	_add_polyline(name, points)

func _add_corner_arc(name: String, center: Vector3, start_angle: float, end_angle: float) -> void:
	_add_arc(name, center, CORNER_ARC_RADIUS, start_angle, end_angle)

func _add_arc(name: String, center: Vector3, radius: float, start_angle: float, end_angle: float) -> void:
	var points: PackedVector3Array = PackedVector3Array()
	for i in range(arc_segments + 1):
		var t := float(i) / float(arc_segments)
		var angle := lerpf(start_angle, end_angle, t)
		points.append(center + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius))
	_add_polyline(name, points)

func _add_polyline(name: String, points: PackedVector3Array) -> void:
	for i in range(points.size() - 1):
		var a := points[i]
		var b := points[i + 1]
		var midpoint := (a + b) * 0.5
		var length := a.distance_to(b)
		var mesh := BoxMesh.new()
		mesh.size = Vector3(LINE_WIDTH, line_height, length)
		mesh.material = _line_material
		var instance := MeshInstance3D.new()
		instance.name = "%sSegment%02d" % [name, i]
		instance.mesh = mesh
		var direction := (b - a).normalized()
		instance.transform = Transform3D(Basis.looking_at(direction, Vector3.UP), Vector3(midpoint.x, LINE_Y, midpoint.z))
		add_child(instance)

func _add_spot(name: String, position: Vector3, diameter: float) -> void:
	_add_line(name, Vector3(position.x, LINE_Y + 0.002, position.z), Vector3(diameter, line_height, diameter))

func _add_line(name: String, position: Vector3, size: Vector3) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _line_material
	var instance := MeshInstance3D.new()
	instance.name = name
	instance.mesh = mesh
	instance.position = position
	add_child(instance)
