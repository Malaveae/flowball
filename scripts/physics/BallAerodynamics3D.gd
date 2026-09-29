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
@export var magnus_multiplier: float = 0.65
@export var spin_decay_per_second: float = 0.35
@export var wind_multiplier: float = 1.0

var ball: RigidBody3D

# Knuckle wobble: a sum of seeded sines (no randf at runtime), perpendicular to the velocity,
# kicking in shortly after launch and scaling with (v/30)^2 so it fades as the ball slows.
const KNUCKLE_DELAY_START := 0.15
const KNUCKLE_DELAY_END := 0.25
const KNUCKLE_FREQ_MIN_HZ := 0.8
const KNUCKLE_FREQ_MAX_HZ := 3.5
const KNUCKLE_VERTICAL_WEIGHT := 0.5
const KNUCKLE_REFERENCE_SPEED := 30.0
const KNUCKLE_COMPONENTS := 3
const KNUCKLE_NORMALIZATION := 1.0 / 3.0

var _knuckle_gain := 0.0
var _knuckle_seed := 0
var _knuckle_amp := 0.0
var _flight_time := 0.0
var _knuckle_velocity := Vector3.ZERO
## Displacement caused only by the knuckle wobble; subtracting it from the ball position
## gives the "no-noise" (predictable) path shown by the trajectory ghost.
var knuckle_offset := Vector3.ZERO

func _ready() -> void:
	ball = get_parent() as RigidBody3D
	if ball == null:
		push_error("BallAerodynamics3D must be a child of a RigidBody3D.")

func apply_forces(state: PhysicsDirectBodyState3D) -> void:
	if not aero_enabled or ball == null:
		return

	var velocity := state.linear_velocity
	if (velocity - effective_wind()).length() < 0.05:
		return

	state.linear_velocity += aero_acceleration(velocity, state.angular_velocity, ball.mass) * state.step
	_apply_knuckle(state, velocity)
	state.angular_velocity *= spin_decay_factor(state.step)

## Drag + Magnus acceleration (m/s^2) for the current tuning. Shared by the runtime
## (apply_forces) and BallFlightSimulator so offline validation can't drift from real flight.
func aero_acceleration(velocity: Vector3, angular_velocity: Vector3, mass: float) -> Vector3:
	var relative_velocity := velocity - effective_wind()
	var speed := relative_velocity.length()
	if speed < 0.05:
		return Vector3.ZERO

	var area := PI * ball_radius * ball_radius
	var total_force := -relative_velocity.normalized() * 0.5 * air_density * speed * speed * drag_coefficient * area * drag_multiplier

	if magnus_enabled and angular_velocity.length() > 0.05:
		# Direction follows omega x v. This is intentionally tuned higher than strict real-world scale
		# so curl is readable in the short 20-30m prototype sandbox.
		total_force += angular_velocity.cross(relative_velocity) * air_density * area * ball_radius * magnus_multiplier

	return total_force / maxf(mass, 0.001)

func effective_wind() -> Vector3:
	return wind_vector * wind_multiplier if wind_enabled else Vector3.ZERO

## Per-step multiplicative spin decay applied after the aero forces.
func spin_decay_factor(step: float) -> float:
	return maxf(0.0, 1.0 - spin_decay_per_second * step)

func begin_shot(params: ShotParams) -> void:
	_knuckle_gain = params.knuckle_gain if params != null else 0.0
	_knuckle_seed = params.knuckle_seed if params != null else 0
	_knuckle_amp = params.knuckle_amp if params != null else 0.0
	_flight_time = 0.0
	_knuckle_velocity = Vector3.ZERO
	knuckle_offset = Vector3.ZERO

func end_shot() -> void:
	_knuckle_gain = 0.0
	_flight_time = 0.0
	_knuckle_velocity = Vector3.ZERO
	knuckle_offset = Vector3.ZERO

func _apply_knuckle(state: PhysicsDirectBodyState3D, velocity: Vector3) -> void:
	if _knuckle_gain <= 0.0 or _knuckle_amp <= 0.0:
		return
	_flight_time += state.step
	var accel_3d := knuckle_accel_3d(_flight_time, velocity, _knuckle_seed, _knuckle_gain, _knuckle_amp)
	if accel_3d == Vector3.ZERO:
		return
	state.linear_velocity += accel_3d * state.step
	_knuckle_velocity += accel_3d * state.step
	knuckle_offset += _knuckle_velocity * state.step

## knuckle_accel projected into world space, perpendicular to the velocity (lateral + vertical).
static func knuckle_accel_3d(t: float, velocity: Vector3, seed: int, gain: float, amp: float) -> Vector3:
	var accel := knuckle_accel(t, velocity.length(), seed, gain, amp)
	if accel == Vector2.ZERO:
		return Vector3.ZERO
	var lateral_axis := velocity.cross(Vector3.UP)
	if lateral_axis.length() < 0.001:
		return Vector3.ZERO
	lateral_axis = lateral_axis.normalized()
	var vertical_axis := lateral_axis.cross(velocity.normalized()).normalized()
	return lateral_axis * accel.x + vertical_axis * accel.y

## Pure knuckle wobble (m/s^2): x = lateral, y = vertical. Same (t, speed, seed) -> same value.
static func knuckle_accel(t: float, speed: float, seed: int, gain: float, amp: float) -> Vector2:
	if gain <= 0.0 or amp <= 0.0:
		return Vector2.ZERO
	var activation := smoothstep(KNUCKLE_DELAY_START, KNUCKLE_DELAY_END, t)
	if activation <= 0.0:
		return Vector2.ZERO
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var lateral := 0.0
	var vertical := 0.0
	for _i in range(KNUCKLE_COMPONENTS):
		var lateral_freq := rng.randf_range(KNUCKLE_FREQ_MIN_HZ, KNUCKLE_FREQ_MAX_HZ)
		var lateral_phase := rng.randf_range(0.0, TAU)
		var vertical_freq := rng.randf_range(KNUCKLE_FREQ_MIN_HZ, KNUCKLE_FREQ_MAX_HZ)
		var vertical_phase := rng.randf_range(0.0, TAU)
		lateral += sin(TAU * lateral_freq * t + lateral_phase)
		vertical += sin(TAU * vertical_freq * t + vertical_phase)
	var speed_scale := pow(speed / KNUCKLE_REFERENCE_SPEED, 2.0)
	var magnitude := amp * gain * activation * speed_scale * KNUCKLE_NORMALIZATION
	return Vector2(lateral, vertical * KNUCKLE_VERTICAL_WEIGHT) * magnitude
