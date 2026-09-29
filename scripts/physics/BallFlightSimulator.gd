class_name BallFlightSimulator
extends RefCounted

## Deterministic offline replay of a free-kick flight, stepping the exact same aero math the
## runtime uses (BallAerodynamics3D.aero_acceleration / knuckle_accel_3d) in the same order
## Jolt applies it: linear damping -> gravity -> position -> custom forces; angular damping ->
## max-angular-velocity clamp -> spin decay. Used by validation tooling (historical
## free-kick feasibility) where launching a real RigidBody3D per candidate would be too slow.
## Collisions (wall, keeper, frame, ground bounce) are NOT simulated: the flight stops at the
## goal line, on first ground contact, or at MAX_FLIGHT_SECONDS; callers test clearance
## against the returned signatures.

const MAX_FLIGHT_SECONDS := 6.0
# Regulation goal mouth (inner edges). The sandbox frame posts sit at x = +-3.74 (centers).
const GOAL_HALF_WIDTH := 3.66
const GOAL_HEIGHT := 2.44
const WALL_DISTANCE_FROM_BALL := 9.15  # mirrors FreeKickSandbox.WALL_DISTANCE_FROM_BALL
const BALL_SCENE := "res://scenes/free_kick/Ball3D.tscn"

class Result extends RefCounted:
	var positions := PackedVector3Array()
	## True if the ball reached the goal-line plane before touching the ground or timing out.
	var reached_goal_line := false
	## World-space point where the ball crossed the goal-line plane (valid if reached_goal_line).
	var goal_crossing := Vector3.ZERO
	## Crossing point relative to the goal center, x = right (+) / left (-), y = height above ground.
	var goal_mouth_point := Vector2.ZERO
	var is_on_target := false
	var flight_time := 0.0
	var speed_at_goal := 0.0
	var reached_wall_plane := false
	## Ball center height and lateral offset (right +) when crossing the wall plane.
	var wall_plane_height := 0.0
	var wall_plane_lateral := 0.0
	var wall_plane_time := 0.0
	var apex_height := 0.0
	## Max horizontal distance from the straight chord start -> goal crossing (visible "curl").
	var max_chord_deviation := 0.0
	## Signed version of max_chord_deviation: + bulges to the kicker's right, - to the left.
	var signed_chord_deviation := 0.0
	var touched_ground := false

## Flight of `params` launched from `start` toward the goal whose center-on-ground is
## `goal_center` (x, z used; goal line plane = goal_center.z, goal faces +Z).
## max_angular_override > 0 replaces Jolt's max angular velocity (used to ask "would this
## kick work if the engine allowed more spin?" - never for gameplay parity).
static func simulate(params: ShotParams, start: Vector3, goal_center: Vector3, aero: BallAerodynamics3D, mass: float = 0.43, max_angular_override: float = -1.0) -> Result:
	var result := Result.new()
	var tick_hz := float(ProjectSettings.get_setting("physics/common/physics_ticks_per_second", 60))
	var dt := 1.0 / tick_hz
	var gravity_vector: Vector3 = ProjectSettings.get_setting("physics/3d/default_gravity_vector", Vector3.DOWN)
	var gravity: Vector3 = gravity_vector * float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	var damping := ball_damping()
	var linear_damp: float = damping.x
	var angular_damp: float = damping.y
	var max_angular := float(ProjectSettings.get_setting("physics/jolt_physics_3d/limits/max_angular_velocity", 47.1238899230957))
	if max_angular_override > 0.0:
		max_angular = max_angular_override

	var flat_goal := Vector3(goal_center.x, start.y, goal_center.z)
	var forward := (flat_goal - start).normalized()
	if forward == Vector3.ZERO:
		forward = Vector3.FORWARD
	var right := forward.cross(Vector3.UP).normalized()
	var wall_center := start + forward * WALL_DISTANCE_FROM_BALL
	var ball_radius := aero.ball_radius

	var position := start
	var velocity := params.launch_velocity
	var omega := params.spin_axis.normalized() * params.spin_rate
	var t := 0.0
	result.positions.append(position)
	result.apex_height = position.y
	while t < MAX_FLIGHT_SECONDS:
		var previous := position
		t += dt
		# Jolt step (measured against a real launch): v *= max(0, 1 - damp*dt), v += g*dt,
		# x += v*dt; spin gets the same damping followed by the max-angular clamp.
		velocity *= maxf(0.0, 1.0 - linear_damp * dt)
		velocity += gravity * dt
		omega *= maxf(0.0, 1.0 - angular_damp * dt)
		if omega.length() > max_angular:
			omega = omega.normalized() * max_angular
		position += velocity * dt
		# The custom-force callback (BallAerodynamics3D.apply_forces) then sees the post-step
		# state, so aero changes only take effect on the next step's position.
		var callback_velocity := velocity
		if aero.aero_enabled and (callback_velocity - aero.effective_wind()).length() >= 0.05:
			velocity += aero.aero_acceleration(callback_velocity, omega, mass) * dt
			velocity += BallAerodynamics3D.knuckle_accel_3d(t, callback_velocity, params.knuckle_seed, params.knuckle_gain, params.knuckle_amp) * dt
			omega *= aero.spin_decay_factor(dt)
		result.positions.append(position)
		result.apex_height = maxf(result.apex_height, position.y)

		if not result.reached_wall_plane:
			var d_prev := (previous - wall_center).dot(forward)
			var d_now := (position - wall_center).dot(forward)
			if d_prev < 0.0 and d_now >= 0.0:
				var f := d_prev / (d_prev - d_now)
				var p := previous.lerp(position, f)
				result.reached_wall_plane = true
				result.wall_plane_height = p.y
				result.wall_plane_lateral = (p - wall_center).dot(right)
				result.wall_plane_time = t - dt + f * dt

		if previous.z > goal_center.z and position.z <= goal_center.z:
			var f := (previous.z - goal_center.z) / (previous.z - position.z)
			result.reached_goal_line = true
			result.goal_crossing = previous.lerp(position, f)
			result.flight_time = t - dt + f * dt
			result.speed_at_goal = velocity.length()
			result.goal_mouth_point = Vector2(result.goal_crossing.x - goal_center.x, result.goal_crossing.y)
			result.is_on_target = absf(result.goal_mouth_point.x) <= GOAL_HALF_WIDTH - ball_radius \
				and result.goal_mouth_point.y <= GOAL_HEIGHT - ball_radius
			break
		if position.y <= ball_radius and velocity.y < 0.0:
			result.touched_ground = true
			result.flight_time = t
			break
		if t >= MAX_FLIGHT_SECONDS:
			result.flight_time = t

	_measure_chord_deviation(result, start)
	return result

static var _cached_damping := Vector2(-1.0, -1.0)

## Effective (linear, angular) damping of the real ball, resolved the way Godot does:
## Replace mode uses the body's own value, Combine adds it to the project default.
## Read once from Ball3D.tscn so the simulator follows any scene retune automatically.
static func ball_damping() -> Vector2:
	if _cached_damping.x >= 0.0:
		return _cached_damping
	var default_linear := float(ProjectSettings.get_setting("physics/3d/default_linear_damp", 0.1))
	var default_angular := float(ProjectSettings.get_setting("physics/3d/default_angular_damp", 0.1))
	var ball := (load(BALL_SCENE) as PackedScene).instantiate() as RigidBody3D
	var linear := ball.linear_damp if ball.linear_damp_mode == RigidBody3D.DAMP_MODE_REPLACE else default_linear + ball.linear_damp
	var angular := ball.angular_damp if ball.angular_damp_mode == RigidBody3D.DAMP_MODE_REPLACE else default_angular + ball.angular_damp
	ball.free()
	_cached_damping = Vector2(linear, angular)
	return _cached_damping

static func _measure_chord_deviation(result: Result, start: Vector3) -> void:
	var end := result.goal_crossing if result.reached_goal_line else result.positions[result.positions.size() - 1]
	var chord := Vector3(end.x - start.x, 0.0, end.z - start.z)
	if chord.length() < 0.01:
		return
	var chord_dir := chord.normalized()
	var chord_right := chord_dir.cross(Vector3.UP).normalized()
	for p in result.positions:
		var lateral := Vector3(p.x - start.x, 0.0, p.z - start.z).dot(chord_right)
		if absf(lateral) > result.max_chord_deviation:
			result.max_chord_deviation = absf(lateral)
			result.signed_chord_deviation = lateral
