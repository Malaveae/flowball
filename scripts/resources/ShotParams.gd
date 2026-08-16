class_name ShotParams
extends Resource

@export_range(0.0, 1.0, 0.001) var power: float = 0.0
@export var launch_velocity: Vector3 = Vector3.ZERO
@export var spin_axis: Vector3 = Vector3.UP
@export var spin_rate: float = 0.0
@export var elevation_angle: float = 0.0
@export var horizontal_angle: float = 0.0
@export var contact_point: Vector2 = Vector2.ZERO
@export var support_vector: Vector2 = Vector2.ZERO
@export var plant_depth: float = 0.0
@export var support_foot_angle: float = 0.0
@export var support_aim_target: float = 0.0
@export var stability: float = 1.0
@export var curve_bias: float = 0.0
@export var error_cone_degrees: float = 0.0
@export var final_error: Vector2 = Vector2.ZERO
@export var shot_type: StringName = &"unknown"
@export var gesture_technique: int = ContactGesture.Technique.LACE
@export var gesture_quality: float = 1.0
@export var gesture_l_max: float = 1.8
@export var quality_dispersion_degrees: float = 0.0
