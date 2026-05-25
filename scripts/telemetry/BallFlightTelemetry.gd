class_name BallFlightTelemetry
extends Resource

@export var sample_interval: float = 0.05
@export var positions: PackedVector3Array = PackedVector3Array()
@export var velocities: PackedVector3Array = PackedVector3Array()
@export var peak_height: float = 0.0
@export var max_lateral_deviation: float = 0.0
@export var total_flight_time: float = 0.0
@export var final_outcome: StringName = &"unknown"

func add_sample(position: Vector3, velocity: Vector3) -> void:
	positions.append(position)
	velocities.append(velocity)
	peak_height = maxf(peak_height, position.y)
