extends SceneTree

## BallFlightSimulator must replay the runtime flight exactly enough for validation tooling:
## determinism, textbook sanity, curl direction, and parity with a real Jolt launch of Ball3D.

const BALL_SCENE := "res://scenes/free_kick/Ball3D.tscn"
const GOAL_CENTER := Vector3(0.0, 0.0, -52.5)
const START := Vector3(0.0, 0.16, -27.5)  # 25 m out, like a sandbox set piece
# Jolt parity tolerance at the goal line (m). Both integrate the same math at the same tick.
const PARITY_TOLERANCE := 0.02

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var ok := true
	ok = _test_is_deterministic() and ok
	ok = _test_vacuum_matches_parabola() and ok
	ok = _test_positive_spin_y_curls_left() and ok
	ok = _test_spin_is_clamped_to_jolt_limit() and ok
	for shot in _parity_shots():
		ok = await _test_jolt_parity(shot[0], shot[1]) and ok
	print("BallFlightSimulatorSmokeTest: ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)

func _aero() -> BallAerodynamics3D:
	return BallAerodynamics3D.new()

func _shot(speed: float, elevation_deg: float, spin_axis: Vector3 = Vector3.ZERO, spin_rate: float = 0.0) -> ShotParams:
	var params := ShotParams.new()
	var e := deg_to_rad(elevation_deg)
	params.launch_velocity = Vector3(0.0, sin(e), -cos(e)) * speed
	params.spin_axis = spin_axis
	params.spin_rate = spin_rate
	return params

func _test_is_deterministic() -> bool:
	var aero := _aero()
	var shot := _shot(27.0, 14.0, Vector3(0.2, 1.0, 0.0), 40.0)
	var a := BallFlightSimulator.simulate(shot, START, GOAL_CENTER, aero)
	var passed := true
	for _i in range(20):
		var b := BallFlightSimulator.simulate(shot, START, GOAL_CENTER, aero)
		passed = passed and b.goal_crossing == a.goal_crossing and b.flight_time == a.flight_time
	aero.free()
	_print_result("same launch gives an identical flight", passed)
	return passed

func _test_vacuum_matches_parabola() -> bool:
	# No aero: only gravity + whatever linear damping Ball3D.tscn resolves to, so the height at
	# the goal line must sit close to the closed-form solution.
	var aero := _aero()
	aero.aero_enabled = false
	var shot := _shot(25.0, 18.0)
	var r := BallFlightSimulator.simulate(shot, START, GOAL_CENTER, aero)
	# Closed form of v' = -k v + g with the ball's own linear damping k (0 = plain parabola).
	var k: float = BallFlightSimulator.ball_damping().x
	var vx := absf(shot.launch_velocity.z)
	var t := 25.0 / vx
	var ideal_y := START.y + shot.launch_velocity.y * t - 0.5 * 9.8 * t * t
	if k > 0.0:
		t = -log(1.0 - 25.0 * k / vx) / k
		ideal_y = START.y + (shot.launch_velocity.y + 9.8 / k) / k * (1.0 - exp(-k * t)) - 9.8 * t / k
	aero.free()
	# Semi-implicit Euler at 60 Hz sits ~0.5*g*dt*t (~9 cm here) below the closed form.
	var passed := r.reached_goal_line and absf(r.goal_crossing.y - ideal_y) < 0.15 and absf(r.flight_time - t) < 0.02
	_print_result("no-aero flight tracks the damped parabola (y %.2f vs %.2f, t %.3f vs %.3f)" % [r.goal_crossing.y, ideal_y, r.flight_time, t], passed)
	return passed

func _test_positive_spin_y_curls_left() -> bool:
	# ShotCalculator convention: positive omega.y bends a ball heading -Z toward world-left (-X).
	var aero := _aero()
	var r := BallFlightSimulator.simulate(_shot(26.0, 18.0, Vector3.UP, 40.0), START, GOAL_CENTER, aero)
	aero.free()
	var passed := r.reached_goal_line and r.goal_crossing.x < -0.5 and r.signed_chord_deviation != 0.0
	_print_result("positive spin.y curls left (x at goal %.2f m)" % r.goal_crossing.x, passed)
	return passed

func _test_spin_is_clamped_to_jolt_limit() -> bool:
	# Jolt caps angular speed (physics/jolt_physics_3d/limits/max_angular_velocity, 47.12 rad/s
	# by default). Only the very first force callback still sees the unclamped rate, so 140 rad/s
	# lands within ~0.5 m of 47 rad/s instead of the metres of extra curl it would otherwise add.
	var aero := _aero()
	var high := BallFlightSimulator.simulate(_shot(26.0, 18.0, Vector3.UP, 140.0), START, GOAL_CENTER, aero)
	var at_cap := BallFlightSimulator.simulate(_shot(26.0, 18.0, Vector3.UP, 47.12), START, GOAL_CENTER, aero)
	aero.free()
	var diff := absf(high.goal_crossing.x - at_cap.goal_crossing.x)
	var passed := diff < 0.5
	_print_result("spin above Jolt's cap adds no curl (goal-x diff %.3f m)" % diff, passed)
	return passed

func _parity_shots() -> Array:
	var knuckle := _shot(29.0, 15.0, Vector3(1.0, 0.0, 0.0), 2.0)
	knuckle.knuckle_gain = 1.0
	knuckle.knuckle_seed = 424242
	knuckle.knuckle_amp = 16.0
	return [
		["driven, no spin", _shot(30.0, 14.0)],
		["curl 40 rad/s", _shot(26.0, 18.0, Vector3(0.15, 1.0, 0.0).normalized(), 40.0)],
		["curl 120 rad/s (clamped)", _shot(24.0, 24.0, Vector3(-0.1, -1.0, 0.0).normalized(), 120.0)],
		["knuckle", knuckle],
	]

func _test_jolt_parity(label: String, shot: ShotParams) -> bool:
	var ball := (load(BALL_SCENE) as PackedScene).instantiate() as FreeKickBall3D
	root.add_child(ball)
	ball.freeze = true  # hold still until launch (launch() unfreezes)
	ball.global_position = START
	await physics_frame
	ball.launch(shot)
	var crossing := Vector3.INF
	var previous := ball.global_position
	var frames := 0
	while frames < 600:
		await physics_frame
		frames += 1
		var now := ball.global_position
		if previous.z > GOAL_CENTER.z and now.z <= GOAL_CENTER.z:
			var f := (previous.z - GOAL_CENTER.z) / (previous.z - now.z)
			crossing = previous.lerp(now, f)
			break
		if now.y < -1.0:
			break
		previous = now
	var aero := _aero()
	var sim := BallFlightSimulator.simulate(shot, START, GOAL_CENTER, aero)
	aero.free()
	ball.queue_free()
	var error := crossing.distance_to(sim.goal_crossing) if crossing != Vector3.INF else INF
	var passed := sim.reached_goal_line and error <= PARITY_TOLERANCE
	_print_result("Jolt parity [%s]: jolt %s vs sim %s (err %.3f m)" % [label, crossing, sim.goal_crossing, error], passed)
	return passed

func _print_result(label: String, passed: bool) -> void:
	if passed:
		print("PASS: ", label)
	else:
		push_error("FAIL: %s" % label)
