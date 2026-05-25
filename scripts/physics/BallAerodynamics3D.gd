class_name BallAerodynamics3D
extends Node

@export var aero_enabled: bool = true
@export var magnus_enabled: bool = true
@export var wind_enabled: bool = true
@export var wind_vector: Vector3 = Vector3.ZERO # m/s.

@export var air_density: float = 1.225
@export var ball_radius: float = 0.11
@export var drag_coefficient: float = 0.25
@export var drag_multiplier: float = 1.0
@export var magnus_multiplier: float = 0.45
@export var spin_decay_per_second: float = 0.35
@export var wind_multiplier: float = 1.0

var ball: RigidBody3D

func _ready() -> void:
	ball = get_parent() as RigidBody3D
	if ball == null:
		push_error("BallAerodynamics3D must be a child of a RigidBody3D.")

func apply_forces(state: PhysicsDirectBodyState3D) -> void:
	if not aero_enabled or ball == null:
		return

	var velocity := state.linear_velocity
	var wind := wind_vector * wind_multiplier if wind_enabled else Vector3.ZERO
	var relative_velocity := velocity - wind
	var speed := relative_velocity.length()
	if speed < 0.05:
		return

	var area := PI * ball_radius * ball_radius
	var total_force := -relative_velocity.normalized() * 0.5 * air_density * speed * speed * drag_coefficient * area * drag_multiplier

	if magnus_enabled:
		var omega := state.angular_velocity
		if omega.length() > 0.05:
			# Direction follows omega x v. This is intentionally tuned higher than strict real-world scale
			# so curl is readable in the short 20-30m prototype sandbox.
			total_force += omega.cross(relative_velocity) * air_density * area * ball_radius * magnus_multiplier

	state.linear_velocity += (total_force / maxf(ball.mass, 0.001)) * state.step

	var decay := maxf(0.0, 1.0 - spin_decay_per_second * state.step)
	state.angular_velocity *= decay
