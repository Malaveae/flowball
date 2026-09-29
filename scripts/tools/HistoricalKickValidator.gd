extends SceneTree

## Phase-1 feasibility check for Collection mode: can the current mechanics replicate each
## historical free kick in data/historical_free_kicks.json?
##
## Stage 1 (physics reachability): search raw launch parameters (speed, elevation, aim, spin
## rate, spin axis) through BallFlightSimulator. Run once inside the current caps
## (ShotCalculator limits + Jolt's max angular velocity) and once with relaxed caps, so a
## failure can name the binding constraint.
## Stage 2 (input reachability): search player inputs (power hold, run-up, plant, contact
## trace) through ShotCalculator.calculate -> BallFlightSimulator with one neutral stat block
## (skill-only design: no per-kick player profile). The skill window is the share of nearby
## inputs, under a simple human-noise model, that still replicate the kick.
##
## Everything is seeded, so two runs produce a byte-identical report.
## Usage: godot --headless --script scripts/tools/HistoricalKickValidator.gd [-- --only=<kick-id>]

const GOAL_CENTER := Vector3(0.0, 0.0, -52.5)
const BALL_HEIGHT := 0.16
const REPORT_PATH := "res://docs/validation/historical-feasibility.md"
const SEARCH_SEED := 20260929
const RANDOM_SAMPLES := 20000  # override with -- --samples=N
const REFINE_STARTS := 8
const SKILL_WINDOW_SAMPLES := 200
const KNUCKLE_SEEDS := 3000
const PASS_EPSILON := 0.0001
# Stop refining once every signature sits at least this far (fraction of its range) inside.
const TARGET_MARGIN := 0.3
const MOUTH_HALF_WIDTH := 3.66 - 0.11
const MOUTH_TOP := 2.44 - 0.11
const MOUTH_BOTTOM := 0.11
const KNUCKLE_GAIN_MIN := 0.5

# Stage-1 bounds: [speed m/s], [elevation deg], [aim deg], [spin rad/s]. The capped spin
# bound is Jolt's physics/jolt_physics_3d/limits/max_angular_velocity.
const CAPPED := {"speed": Vector2(12.0, 36.0), "elevation": Vector2(-3.0, 35.0), "aim": Vector2(-35.0, 35.0), "spin": Vector2(0.0, 47.12)}
const RELAXED := {"speed": Vector2(10.0, 45.0), "elevation": Vector2(-3.0, 45.0), "aim": Vector2(-50.0, 50.0), "spin": Vector2(0.0, 90.0)}

# Stage-2 input dimensions (normalized search space -> physical ranges).
const HOLD_MAX_S := 3.0
const SUPPORT_LATERAL := Vector2(0.18, 1.0)
const TRACE_DURATION := Vector2(0.08, 0.8)
const TRANSITION_MS := Vector2(150.0, 1200.0)
# Human input noise (1 sigma, physical units) for the skill window. A first guess to be
# calibrated from playtest telemetry, not a measured value.
const NOISE := {
	"hold_s": 0.04, "runup_angle": 4.0, "runup_distance": 0.8, "support_lateral": 0.03,
	"depth": 0.05, "aim": 0.04, "impact": 0.06, "trace_end": 0.08, "bend": 0.05,
	"duration": 0.05, "transition_ms": 80.0,
}

var _aero: BallAerodynamics3D
var _stats: PlayerFreeKickStats
var _difficulty: FreeKickDifficulty
var _strip_error := false
var _random_samples := RANDOM_SAMPLES

func _initialize() -> void:
	var only := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.substr(7)
		elif arg.begins_with("--samples="):
			_random_samples = int(arg.substr(10))
	var catalog := HistoricalFreeKickCatalog.new()
	if not catalog.load_from_json():
		push_error(catalog.last_error)
		quit(1)
		return
	_aero = BallAerodynamics3D.new()
	_difficulty = FreeKickDifficulty.new()
	var rows: Array[Dictionary] = []
	for kick in catalog.all_kicks():
		if not only.is_empty() and kick.id != only:
			continue
		print("Validating %s ..." % kick.id)
		rows.append(_validate(kick))
	_aero.free()
	var report := _render_report(rows)
	if only.is_empty():
		var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
		if file == null:
			push_error("Could not write %s" % REPORT_PATH)
			quit(1)
			return
		file.store_string(report)
		file.close()
		print("Report written to %s" % REPORT_PATH)
	else:
		print(report)
	quit(0)

func _validate(kick: HistoricalFreeKick) -> Dictionary:
	# Neutral kicker: the roster's balanced baseline, with the kick's own foot as preferred so
	# the weak-foot penalty never applies (skill-only design; see report gap list).
	_stats = _kicker_stats(kick, 70.0)
	var row := {"kick": kick}
	row["constrained"] = _constrained_signatures(kick)
	row["stage1_capped"] = _stage1(kick, CAPPED, -1.0)
	var capped_pass: bool = row["stage1_capped"]["pass"]
	if not capped_pass:
		# Relaxed bounds contain the capped ones, so start from the capped best point.
		row["stage1_relaxed"] = _stage1(kick, RELAXED, RELAXED["spin"].y, row["stage1_capped"])
	row["stage2"] = _stage2(kick)
	if row["stage2"]["pass"]:
		row["skill_window"] = _skill_window(kick, row["stage2"]["u"])
		# Same inputs with a max-control kicker (accuracy/technique/composure 100): separates
		# input sensitivity from the stat-driven deterministic error cone.
		_stats = _kicker_stats(kick, 70.0, 100.0)
		row["skill_window_control"] = _skill_window(kick, row["stage2"]["u"])
		_stats = _kicker_stats(kick, 70.0)
		row["sensitivity"] = _sensitivity(kick, row["stage2"]["u"])
		# Re-center without the error term (warm start from the neutral best), then measure.
		_strip_error = true
		var seeds: Array = [row["stage2"]["u"]]
		seeds.append_array(_technique_seeds(kick))
		var evaluate := func(u: PackedFloat32Array) -> float:
			return float(_run_input(kick, u)["score"])
		var centered := _optimize(evaluate, STAGE2_DIMS, hash(kick.id) ^ (SEARCH_SEED + 5), seeds)
		row["skill_window_no_error"] = _skill_window(kick, centered["u"]) if centered["score"] <= PASS_EPSILON else 0.0
		_strip_error = false
	return row

func _kicker_stats(kick: HistoricalFreeKick, base: float, control: float = -1.0) -> PlayerFreeKickStats:
	var stats := PlayerFreeKickStats.new()
	for field in ["kick_power", "free_kick_accuracy", "curve", "technique", "composure"]:
		stats.set(field, base)
	if control > 0.0:
		for field in ["free_kick_accuracy", "technique", "composure"]:
			stats.set(field, control)
	stats.weak_foot = 60.0
	stats.preferred_foot = kick.foot
	return stats

# ---------------------------------------------------------------- scoring

## Positive = weighted distance outside the envelope (fail). Zero or negative = replicated;
## the negative part is minus the smallest normalized margin to any range edge (0..0.5), so
## the optimizer keeps pushing a passing solution toward the envelope's center. The skill
## window is then measured around a robust input rather than one sitting on an edge.
func _score(kick: HistoricalFreeKick, r: BallFlightSimulator.Result, launch_speed: float, knuckle_gain: float, check_knuckle: bool) -> float:
	if not r.reached_goal_line:
		var last := r.positions[r.positions.size() - 1]
		return 20.0 + absf(last.z - GOAL_CENTER.z)
	var wall_height := r.wall_plane_height if r.reached_wall_plane else 0.0
	var checks := [
		[r.goal_mouth_point.x, kick.goal_entry_x_m, 1.0],
		[r.goal_mouth_point.y, kick.goal_entry_y_m, 1.0],
		[r.flight_time, kick.flight_time_s, 10.0],
		[r.signed_chord_deviation, kick.curl_m, 1.0],
		[wall_height, kick.wall_plane_height_m, 1.0],
		[launch_speed, kick.launch_speed_ms, 0.2],
	]
	var miss := 0.0
	miss += maxf(0.0, absf(r.goal_mouth_point.x) - MOUTH_HALF_WIDTH) * 2.0
	miss += maxf(0.0, r.goal_mouth_point.y - MOUTH_TOP) * 2.0
	miss += maxf(0.0, MOUTH_BOTTOM - r.goal_mouth_point.y) * 2.0  # ball center can't be below its radius
	# Always-on margin: stay inside the goal mouth (normalized over 1 m, capped at 0.5).
	var margin := clampf(minf(MOUTH_HALF_WIDTH - absf(r.goal_mouth_point.x), MOUTH_TOP - r.goal_mouth_point.y), 0.0, 0.5)
	for check in checks:
		var bounds: Vector2 = check[1]
		if not HistoricalFreeKick.has_range(bounds):
			continue
		var value: float = check[0]
		miss += HistoricalFreeKick.range_miss(value, bounds) * float(check[2])
		margin = minf(margin, clampf(minf(value - bounds.x, bounds.y - value) / maxf(bounds.y - bounds.x, 0.0001), 0.0, 0.5))
	if check_knuckle and kick.knuckle_expected:
		miss += maxf(0.0, KNUCKLE_GAIN_MIN - knuckle_gain) * 4.0
		margin = minf(margin, clampf(knuckle_gain - KNUCKLE_GAIN_MIN, 0.0, 0.5))
	return miss if miss > 0.0 else -margin

func _constrained_signatures(kick: HistoricalFreeKick) -> int:
	var n := 0
	for bounds in [kick.goal_entry_x_m, kick.goal_entry_y_m, kick.flight_time_s, kick.curl_m, kick.wall_plane_height_m, kick.launch_speed_ms]:
		if HistoricalFreeKick.has_range(bounds):
			n += 1
	return n + (1 if kick.knuckle_expected else 0)

func _start(kick: HistoricalFreeKick) -> Vector3:
	return kick.ball_position(GOAL_CENTER, BALL_HEIGHT)

func _goal_direction(kick: HistoricalFreeKick) -> Vector3:
	var start := _start(kick)
	return Vector3(GOAL_CENTER.x - start.x, 0.0, GOAL_CENTER.z - start.z).normalized()

# ---------------------------------------------------------------- stage 1

func _stage1(kick: HistoricalFreeKick, bounds: Dictionary, spin_override: float, warm_start: Dictionary = {}) -> Dictionary:
	var start := _start(kick)
	var direction := _goal_direction(kick)
	var decode := func(u: PackedFloat32Array) -> ShotParams:
		var params := ShotParams.new()
		var speed := lerpf(bounds["speed"].x, bounds["speed"].y, u[0])
		var elevation := lerpf(bounds["elevation"].x, bounds["elevation"].y, u[1])
		var aim := lerpf(bounds["aim"].x, bounds["aim"].y, u[2])
		params.launch_velocity = ShotCalculator._launch_velocity(direction, aim, elevation, speed)
		params.spin_rate = lerpf(bounds["spin"].x, bounds["spin"].y, u[3])
		var phi := lerpf(-PI, PI, u[4])
		# ShotCalculator axis convention: x = backspin(+)/topspin(-), y = side spin.
		params.spin_axis = Vector3(sin(phi), cos(phi), 0.0)
		params.elevation_angle = elevation
		params.horizontal_angle = aim
		return params
	var evaluate := func(u: PackedFloat32Array) -> float:
		var params: ShotParams = decode.call(u)
		var r := BallFlightSimulator.simulate(params, start, GOAL_CENTER, _aero, 0.43, spin_override)
		return _score(kick, r, params.launch_velocity.length(), 0.0, false)
	var seeds: Array = []
	if not warm_start.is_empty():
		seeds.append(PackedFloat32Array([
			inverse_lerp(bounds["speed"].x, bounds["speed"].y, warm_start["speed"]),
			inverse_lerp(bounds["elevation"].x, bounds["elevation"].y, warm_start["elevation"]),
			inverse_lerp(bounds["aim"].x, bounds["aim"].y, warm_start["aim"]),
			inverse_lerp(bounds["spin"].x, bounds["spin"].y, warm_start["spin"]),
			warm_start["u"][4],
		]))
	var best := _optimize(evaluate, 5, hash(kick.id) ^ SEARCH_SEED, seeds)
	var params: ShotParams = decode.call(best["u"])
	var r := BallFlightSimulator.simulate(params, start, GOAL_CENTER, _aero, 0.43, spin_override)
	return {
		"pass": best["score"] <= PASS_EPSILON,
		"score": best["score"],
		"speed": params.launch_velocity.length(),
		"elevation": params.elevation_angle,
		"aim": params.horizontal_angle,
		"spin": params.spin_rate,
		"u": best["u"],
		"result": r,
	}

# ---------------------------------------------------------------- stage 2

const STAGE2_DIMS := 14

func _decode_input(kick: HistoricalFreeKick, u: PackedFloat32Array) -> FreeKickInputData:
	var input := FreeKickInputData.new()
	input.selected_foot = kick.foot
	var engaged := u[1] >= 0.5
	input.used_default_runup = not engaged
	input.runup_angle_deg = lerpf(0.0, 90.0, u[2]) if engaged else 0.0
	input.runup_distance_m = lerpf(0.0, 15.0, u[3]) if engaged else 0.0
	input.hold_time = u[0] * HOLD_MAX_S
	input.power_normalized = ShotCalculator.power_from_hold(input.hold_time, _stats, input.runup_distance_m, _difficulty, input.runup_angle_deg, engaged)
	# Plant: the support foot sits on the anatomically correct side (FreeKickInputMapper rule).
	var side := -1.0 if kick.foot == "right" else 1.0
	var support := Vector2(side * lerpf(SUPPORT_LATERAL.x, SUPPORT_LATERAL.y, u[4]), lerpf(-1.0, 1.0, u[5]))
	var aim := lerpf(-1.0, 1.0, u[6])
	input.support_vector = support
	input.plant_depth = support.y
	input.support_aim_target = aim
	input.support_foot_angle = SupportPlantGesture.toe_direction(aim).angle()
	input.support_quality = SupportFootState.support_quality(support)
	input.support_angle_quality = SupportFootState.support_angle_quality(aim)
	# Contact: impact on the ball face, then a quadratic-Bezier follow-through trace, clamped
	# exactly like BallContactState (trace cap = ContactGesture.l_max, normalized cap 1.8).
	var curve_stat := _stats.normalized(_stats.curve)
	var cap := minf(ContactGesture.l_max(input.power_normalized, curve_stat, _difficulty), 1.8)
	var impact := Vector2(lerpf(-1.0, 1.0, u[7]), lerpf(-1.0, 1.0, u[8])).limit_length(1.0)
	var end := (impact + Vector2(lerpf(-1.8, 1.8, u[9]), lerpf(-1.8, 1.8, u[10]))).limit_length(cap)
	var chord := end - impact
	var normal := Vector2(-chord.y, chord.x)
	var control := (impact + end) * 0.5 + normal * lerpf(-0.6, 0.6, u[11])
	var points := PackedVector2Array([impact])
	for i in range(1, 11):
		var t := float(i) / 10.0
		var p := impact.lerp(control, t).lerp(control.lerp(end, t), t)
		points.append(p.limit_length(cap))
	input.impact_point = impact
	input.swipe_points = points
	input.swipe_duration = lerpf(TRACE_DURATION.x, TRACE_DURATION.y, u[12])
	input.step2_to_step3_ms = int(lerpf(TRANSITION_MS.x, TRANSITION_MS.y, u[13]))
	return input

func _environment(kick: HistoricalFreeKick) -> FreeKickEnvironment:
	var environment := FreeKickEnvironment.new()
	var start := _start(kick)
	environment.distance_to_goal = Vector2(GOAL_CENTER.x - start.x, GOAL_CENTER.z - start.z).length()
	environment.base_goal_direction = _goal_direction(kick)
	environment.wind_vector = Vector3.ZERO  # album shots must be replicable without wind
	environment.set_piece_seed = hash(kick.id)
	return environment

func _run_input(kick: HistoricalFreeKick, u: PackedFloat32Array) -> Dictionary:
	var input := _decode_input(kick, u)
	var params := ShotCalculator.calculate(input, _stats, _environment(kick), _difficulty)
	if _strip_error:
		# Counterfactual only (never gameplay): undo the flaw error (final_error) to see how much
		# of the fragility comes from it versus the input->launch mapping itself.
		params.horizontal_angle -= params.final_error.x
		params.elevation_angle -= params.final_error.y
		params.launch_velocity = ShotCalculator._launch_velocity(_environment(kick).base_goal_direction, params.horizontal_angle, params.elevation_angle, params.launch_velocity.length())
	var r := BallFlightSimulator.simulate(params, _start(kick), GOAL_CENTER, _aero)
	return {"input": input, "params": params, "result": r, "score": _score(kick, r, params.launch_velocity.length(), params.knuckle_gain, true)}

func _stage2(kick: HistoricalFreeKick) -> Dictionary:
	var evaluate := func(u: PackedFloat32Array) -> float:
		return float(_run_input(kick, u)["score"])
	var best := _optimize(evaluate, STAGE2_DIMS, hash(kick.id) ^ (SEARCH_SEED + 1), _technique_seeds(kick))
	var run := _run_input(kick, best["u"])
	run["u"] = best["u"]
	run["pass"] = best["score"] <= PASS_EPSILON
	return run

## Extra starting points inside narrow technique windows that blind random sampling of a
## 14-D space almost never hits. Knuckle: ShotCalculator's clean strike needs contact within
## KNUCKLE_CONTACT_RADIUS_MAX of center and a short, straight trace.
func _technique_seeds(kick: HistoricalFreeKick) -> Array:
	var seeds: Array = []
	if not kick.knuckle_expected:
		return seeds
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kick.id) ^ (SEARCH_SEED + 3)
	var impact_u := ShotCalculator.KNUCKLE_CONTACT_RADIUS_MAX / 2.0  # u-span of +-0.12 radii
	var trace_u := 0.35 / 3.6                                      # u-span of +-0.35 radii
	for _i in range(KNUCKLE_SEEDS):
		var u := PackedFloat32Array()
		u.resize(STAGE2_DIMS)
		for d in range(STAGE2_DIMS):
			u[d] = rng.randf()
		u[7] = 0.5 + rng.randf_range(-impact_u, impact_u)
		u[8] = 0.5 + rng.randf_range(-impact_u, impact_u)
		u[9] = 0.5 + rng.randf_range(-trace_u, trace_u)
		u[10] = 0.5 + rng.randf_range(-trace_u, trace_u)
		u[11] = 0.5 + rng.randf_range(-0.02, 0.02)
		seeds.append(u)
	return seeds

const INPUT_LABELS := [
	"power hold", "run-up on/off", "run-up angle", "run-up distance", "plant distance",
	"plant depth", "plant aim", "impact x", "impact y", "trace end x", "trace end y",
	"trace bend", "trace duration", "plant->contact delay",
]
const SENSITIVITY_SAMPLES := 40

## Pass rate when human noise is applied to one input at a time. Lowest = most fragile.
func _sensitivity(kick: HistoricalFreeKick, u: PackedFloat32Array) -> Array:
	var sigma := _noise_sigma()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kick.id) ^ (SEARCH_SEED + 4)
	var rates: Array = []
	for d in range(STAGE2_DIMS):
		if sigma[d] <= 0.0:
			continue
		var passes := 0
		for _i in range(SENSITIVITY_SAMPLES):
			var v := u.duplicate()
			v[d] = clampf(v[d] + rng.randfn(0.0, sigma[d]), 0.0, 1.0)
			if float(_run_input(kick, v)["score"]) <= PASS_EPSILON:
				passes += 1
		rates.append([float(passes) / float(SENSITIVITY_SAMPLES), INPUT_LABELS[d]])
	rates.sort_custom(func(a, b): return a[0] < b[0] or (a[0] == b[0] and String(a[1]) < String(b[1])))
	return rates

func _skill_window(kick: HistoricalFreeKick, u: PackedFloat32Array) -> float:
	var sigma := _noise_sigma()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kick.id) ^ (SEARCH_SEED + 2)
	var passes := 0
	for _i in range(SKILL_WINDOW_SAMPLES):
		var v := u.duplicate()
		for d in range(STAGE2_DIMS):
			v[d] = clampf(v[d] + rng.randfn(0.0, sigma[d]), 0.0, 1.0)
		if float(_run_input(kick, v)["score"]) <= PASS_EPSILON:
			passes += 1
	return float(passes) / float(SKILL_WINDOW_SAMPLES)

## NOISE converted to the normalized search space (run-up on/off is never flipped).
func _noise_sigma() -> PackedFloat32Array:
	return PackedFloat32Array([
		NOISE["hold_s"] / HOLD_MAX_S, 0.0, NOISE["runup_angle"] / 90.0, NOISE["runup_distance"] / 15.0,
		NOISE["support_lateral"] / (SUPPORT_LATERAL.y - SUPPORT_LATERAL.x), NOISE["depth"] / 2.0, NOISE["aim"] / 2.0,
		NOISE["impact"] / 2.0, NOISE["impact"] / 2.0, NOISE["trace_end"] / 3.6, NOISE["trace_end"] / 3.6,
		NOISE["bend"] / 1.2, NOISE["duration"] / (TRACE_DURATION.y - TRACE_DURATION.x),
		NOISE["transition_ms"] / (TRANSITION_MS.y - TRANSITION_MS.x),
	])

# ---------------------------------------------------------------- optimizer

## Seeded random sampling over [0,1]^dims (plus any warm-start points), then coordinate
## descent from the best few samples.
## Passing points keep being refined toward the envelope center until TARGET_MARGIN.
func _optimize(evaluate: Callable, dims: int, seed: int, seeds: Array = []) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var pool: Array = []  # [score, u]
	for seeded in seeds:
		pool.append([float(evaluate.call(seeded)), seeded])
	for _i in range(_random_samples):
		var u := PackedFloat32Array()
		u.resize(dims)
		for d in range(dims):
			u[d] = rng.randf()
		var s: float = evaluate.call(u)
		pool.append([s, u])
		if s <= -TARGET_MARGIN:
			return {"score": s, "u": u}
	pool.sort_custom(func(a, b): return a[0] < b[0])
	var best_score: float = pool[0][0]
	var best_u: PackedFloat32Array = pool[0][1]
	for start in range(mini(REFINE_STARTS, pool.size())):
		var u: PackedFloat32Array = (pool[start][1] as PackedFloat32Array).duplicate()
		var s: float = pool[start][0]
		var step := 0.1
		while step > 0.002 and s > -TARGET_MARGIN:
			var improved := false
			for d in range(dims):
				for direction in [-1.0, 1.0]:
					var trial := u.duplicate()
					trial[d] = clampf(trial[d] + direction * step, 0.0, 1.0)
					var ts: float = evaluate.call(trial)
					if ts < s:
						s = ts
						u = trial
						improved = true
			if not improved:
				step *= 0.5
		if s < best_score:
			best_score = s
			best_u = u
		if best_score <= -TARGET_MARGIN:
			break
	return {"score": best_score, "u": best_u}

# ---------------------------------------------------------------- report

func _render_report(rows: Array[Dictionary]) -> String:
	var lines := PackedStringArray()
	lines.append("# Historical free-kick feasibility (Phase 1)")
	lines.append("")
	lines.append("Generated by `scripts/tools/HistoricalKickValidator.gd` from `data/historical_free_kicks.json`. Deterministic: re-running produces this file byte-for-byte.")
	lines.append("")
	lines.append("- **Stage 1 (physics)**: can *any* launch (speed, elevation, aim, spin) inside the current caps reproduce the kick's envelope? If not, the relaxed search names the binding cap.")
	lines.append("- **Stage 2 (inputs)**: can real player inputs through `ShotCalculator` (neutral 70-rated kicker, kick's own foot, no wind) reproduce it?")
	lines.append("- **Skill window**: share of %d noisy repeats of the best input that still replicate the kick (noise model is a first guess - calibrate from playtests). Shown as *neutral / max-control / no-error*: neutral 70-rated kicker; accuracy/technique/composure at 100; and neutral with the flaw error (`ShotParams.final_error`) removed after the fact (counterfactual) - separating technique flaws from the input->launch mapping." % SKILL_WINDOW_SAMPLES)
	lines.append("- **Most sensitive inputs**: pass rate when only that one input gets human noise (lowest first) - where the kick is fragile.")
	lines.append("- **Constraints**: how many envelope signatures the dataset actually pins down. Few constraints = an easy pass that proves little.")
	lines.append("")
	lines.append("| Kick | Conf. | Constraints | Stage 1 (caps) | Stage 2 (inputs) | Skill window | Notes |")
	lines.append("|---|---|---|---|---|---|---|")
	for row in rows:
		var kick: HistoricalFreeKick = row["kick"]
		var s1: Dictionary = row["stage1_capped"]
		var s1_text := "PASS" if s1["pass"] else "FAIL (miss %.2f)" % s1["score"]
		var note := ""
		if not s1["pass"]:
			var relaxed: Dictionary = row["stage1_relaxed"]
			note = "Relaxed caps: " + ("PASS - binding: %s" % _binding_caps(relaxed) if relaxed["pass"] else "still FAIL (miss %.2f) - flight model can't produce it" % relaxed["score"])
		var s2: Dictionary = row["stage2"]
		var s2_text := "PASS" if s2["pass"] else "FAIL (miss %.2f)" % s2["score"]
		var window := "%.0f%% / %.0f%% / %.0f%%" % [float(row["skill_window"]) * 100.0, float(row["skill_window_control"]) * 100.0, float(row["skill_window_no_error"]) * 100.0] if row.has("skill_window") else "-"
		lines.append("| `%s` %s | %s | %d | %s | %s | %s | %s |" % [kick.id, kick.kicker, _confidence_label(kick.confidence), row["constrained"], s1_text, s2_text, window, note])
	lines.append("")
	lines.append("## Per-kick detail")
	for row in rows:
		lines.append("")
		lines.append_array(_kick_detail(row))
	lines.append("")
	return "\n".join(lines)

func _kick_detail(row: Dictionary) -> PackedStringArray:
	var kick: HistoricalFreeKick = row["kick"]
	var out := PackedStringArray()
	out.append("### %s - %s (%s)" % [kick.kicker, kick.title, kick.date])
	out.append("")
	out.append("%s foot, %.1f m, lateral %+.1f m. Technique: %s." % [kick.foot.capitalize(), kick.distance_m, kick.lateral_m, kick.technique])
	out.append("")
	out.append("- Target envelope: %s" % _envelope_text(kick))
	out.append("- Stage 1 best launch (caps): %s" % _launch_text(row["stage1_capped"]))
	if row.has("stage1_relaxed"):
		out.append("- Stage 1 best launch (relaxed): %s" % _launch_text(row["stage1_relaxed"]))
	var s2: Dictionary = row["stage2"]
	var params: ShotParams = s2["params"]
	var r: BallFlightSimulator.Result = s2["result"]
	out.append("- Stage 2 best flight: %s" % _flight_text(r, params.launch_velocity.length(), params.spin_rate))
	out.append("- Stage 2 best input: %s" % _input_text(s2["input"], params))
	out.append("- Stage 2 envelope margin: %s" % ("%.0f%% of the tightest range" % (-float(s2["score"]) * 100.0) if s2["pass"] else "n/a (miss %.2f)" % s2["score"]))
	if row.has("sensitivity"):
		var parts := PackedStringArray()
		for entry in (row["sensitivity"] as Array).slice(0, 4):
			parts.append("%s %.0f%%" % [entry[1], float(entry[0]) * 100.0])
		out.append("- Most sensitive inputs: %s" % ", ".join(parts))
	return out

func _envelope_text(kick: HistoricalFreeKick) -> String:
	var parts := PackedStringArray()
	var fields := {
		"entry x": kick.goal_entry_x_m, "entry y": kick.goal_entry_y_m, "speed": kick.launch_speed_ms,
		"flight time": kick.flight_time_s, "curl": kick.curl_m, "wall-plane height": kick.wall_plane_height_m,
	}
	for label in fields:
		var bounds: Vector2 = fields[label]
		if HistoricalFreeKick.has_range(bounds):
			parts.append("%s [%.2f, %.2f]" % [label, bounds.x, bounds.y])
	if kick.knuckle_expected:
		parts.append("knuckle gain >= %.1f" % KNUCKLE_GAIN_MIN)
	return "on target only (no measured signatures)" if parts.is_empty() else ", ".join(parts)

func _launch_text(s: Dictionary) -> String:
	var r: BallFlightSimulator.Result = s["result"]
	return "%s | elevation %.1f deg, aim %+.1f deg -> %s" % [
		"PASS" if s["pass"] else "miss %.2f" % s["score"], s["elevation"], s["aim"], _flight_text(r, s["speed"], s["spin"])]

func _flight_text(r: BallFlightSimulator.Result, speed: float, spin: float) -> String:
	if not r.reached_goal_line:
		return "%.1f m/s, spin %.0f rad/s, did not reach the goal line (%s)" % [speed, spin, "hit the ground" if r.touched_ground else "timed out"]
	var spin_text := "%.0f rad/s" % spin if spin <= CAPPED["spin"].y else "%.0f rad/s (Jolt clamps to %.0f)" % [spin, CAPPED["spin"].y]
	return "%.1f m/s, spin %s, entry (%+.2f, %.2f) m, %.2f s, curl %+.2f m, wall plane %.2f m%s" % [
		speed, spin_text, r.goal_mouth_point.x, r.goal_mouth_point.y, r.flight_time,
		r.signed_chord_deviation, r.wall_plane_height, "" if r.is_on_target else " (off target)"]

func _input_text(input: FreeKickInputData, params: ShotParams) -> String:
	var runup := "skipped" if input.used_default_runup else "%.0f deg / %.1f m" % [input.runup_angle_deg, input.runup_distance_m]
	var last := input.swipe_points[input.swipe_points.size() - 1]
	return "power %.2f (hold %.2f s), run-up %s, plant (%+.2f, %+.2f) aim %+.2f, impact (%+.2f, %+.2f) -> trace end (%+.2f, %+.2f) in %.2f s = %s (quality %.2f), knuckle gain %.2f, error cone %.1f deg" % [
		input.power_normalized, input.hold_time, runup, input.support_vector.x, input.support_vector.y,
		input.support_aim_target, input.impact_point.x, input.impact_point.y, last.x, last.y,
		input.swipe_duration, ContactGesture.TECHNIQUE_NAMES.get(params.gesture_technique, "?"),
		params.gesture_quality, params.knuckle_gain, params.error_cone_degrees]

func _binding_caps(s: Dictionary) -> String:
	var caps := PackedStringArray()
	if s["speed"] > CAPPED["speed"].y:
		caps.append("launch speed %.1f > %.0f m/s" % [s["speed"], CAPPED["speed"].y])
	if s["spin"] > CAPPED["spin"].y:
		caps.append("spin %.0f > %.1f rad/s (Jolt max_angular_velocity)" % [s["spin"], CAPPED["spin"].y])
	if s["elevation"] > CAPPED["elevation"].y:
		caps.append("elevation %.1f > %.0f deg" % [s["elevation"], CAPPED["elevation"].y])
	if absf(s["aim"]) > CAPPED["aim"].y:
		caps.append("aim %.1f beyond +-%.0f deg" % [s["aim"], CAPPED["aim"].y])
	return "none individually (search luck)" if caps.is_empty() else ", ".join(caps)

func _confidence_label(confidence: HistoricalFreeKick.Confidence) -> String:
	match confidence:
		HistoricalFreeKick.Confidence.MEASURED:
			return "measured"
		HistoricalFreeKick.Confidence.BROADCAST_ESTIMATE:
			return "broadcast"
	return "derived"
