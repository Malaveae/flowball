class_name FreeKickEnvironment
extends Resource

@export var wind_vector: Vector3 = Vector3.ZERO # m/s, world-space wind velocity.
@export var distance_to_goal: float = 24.0 # meters.
@export var angle_to_goal: float = 0.0 # degrees, + right / - left from central goal line.
@export var wall_player_count: int = 4
@export_range(1.0, 100.0, 1.0) var goalkeeper_rating: float = 70.0
@export_range(0.0, 1.0, 0.01) var pressure_context: float = 0.5
@export var base_goal_direction: Vector3 = Vector3(0.0, 0.0, -1.0)
