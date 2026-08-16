class_name ContactGesture
extends RefCounted

## Step 3 trace analysis and technique classification (estado3_trazado_roce.md).
## All functions are pure/deterministic: the same trace always yields the same
## metrics, technique and quality, so shot calculation stays replay-friendly.
## Units are normalized ball radii (the same convention as FreeKickInputMapper).

enum Technique {
	PUNTERA,     # simple tap without drag: chipped, unpredictable, low power
	LACE,        # short straight trace: lace (knuckleball candidate when centered)
	LACE_LONG,   # long straight trace: lace + follow-through, power and stability
	INSTEP,      # inward enveloping curve: rosca on the natural curl side
	OUTSTEP,     # outward curve: trivela (inverted curve)
	TOPSPIN,     # ascending sweep: dips over the wall
	BACKSPIN,    # descending sweep: floating ball
	DIRTY,       # low classifier confidence: extra dispersion
}

const TECHNIQUE_NAMES: Dictionary = {
	Technique.PUNTERA: "Puntera",
	Technique.LACE: "Empeine",
	Technique.LACE_LONG: "Empeine largo",
	Technique.INSTEP: "Rosca",
	Technique.OUTSTEP: "Trivela",
	Technique.TOPSPIN: "Topspin",
	Technique.BACKSPIN: "Backspin",
	Technique.DIRTY: "Contacto sucio",
}

# Classifier thresholds (doc section 2), adapted to normalized ball radii.
const MIN_GESTURE_LENGTH := 0.15        # shorter traces read as a plain tap (puntera)
const CURVATURE_LOW := 0.12             # deviation <12% of trace length = straight
const SWEEP_ENVELOPE_DEG := 90.0        # swept angle >=90deg around the trace = enveloping
const VERTICAL_RATIO_ASCENT := 0.55     # vertical share >55% = ascending/descending sweep
const SHORT_TRACE_RATIO := 0.40         # <40% of L_max = short lace
const LONG_TRACE_RATIO := 0.60          # >60% of L_max = long lace
const CONFIDENCE_MIN := 0.60            # below this the signature is called dirty
const SPEED_CV_MAX := 0.70              # coefficient of variation cap for consistency
const L_MAX_CURVE_MIN := 0.9            # curve stat scales the spatial trace budget
const L_MAX_CURVE_MAX := 1.15


static func analyze(points: PackedVector2Array, duration: float) -> Dictionary:
	var metrics := {
		"point_count": points.size(),
		"impact": points[0] if points.size() > 0 else Vector2.ZERO,
		"length": 0.0,
		"chord": 0.0,
		"curvature": 0.0,
		"sweep_angle": 0.0,
		"vertical_ratio": 0.0,
		"vertical_sign": 0,
		"side_sign": 0,
		"mean_speed": 0.0,
		"speed_cv": 0.0,
		"cleanliness": 1.0,
	}
	if points.size() < 2:
		return metrics
	var path := 0.0
	var first := points[0]
	var last := points[points.size() - 1]
	var chord_vec := last - first
	var chord := chord_vec.length()
	var net_dx := 0.0
	var net_dy := 0.0
	var tangent_turn := 0.0
	var prev_dir := Vector2.ZERO
	var speeds := PackedFloat32Array()
	for i in range(1, points.size()):
		var seg := points[i] - points[i - 1]
		var seg_len := seg.length()
		path += seg_len
		net_dx += seg.x
		net_dy += seg.y
		speeds.append(seg_len)
		if seg_len > 0.0001:
			var dir := seg / seg_len
			if prev_dir != Vector2.ZERO:
				tangent_turn += absf(dir.angle_to(prev_dir))
			prev_dir = dir
	metrics["length"] = path
	metrics["chord"] = chord
	metrics["sweep_angle"] = minf(tangent_turn, PI)
	metrics["vertical_ratio"] = absf(net_dy) / maxf(path, 0.0001)
	metrics["vertical_sign"] = 1 if net_dy > 0.05 else -1 if net_dy < -0.05 else 0
	metrics["side_sign"] = 1 if net_dx > 0.05 else -1 if net_dx < -0.05 else 0
	if duration > 0.0:
		metrics["mean_speed"] = path / duration
		var seg_count := maxi(1, speeds.size())
		var mean_seg := path / float(seg_count)
		var var_sum := 0.0
		for s in speeds:
			var_sum += (s - mean_seg) * (s - mean_seg)
		metrics["speed_cv"] = sqrt(var_sum / float(seg_count)) / maxf(mean_seg, 0.0001)
	# Curvature = max deviation from the chord, relative to trace length (doc: <12% is straight).
	var max_dev := 0.0
	for i in range(1, points.size() - 1):
		max_dev = maxf(max_dev, _deviation_from_chord(points[i], first, chord_vec, chord))
	metrics["curvature"] = max_dev / maxf(path, 0.0001)
	# Cleanliness = high-frequency jitter once the intentional curve is removed.
	if chord > 0.0001 and points.size() >= 3:
		var devs := PackedFloat32Array()
		for i in range(1, points.size() - 1):
			devs.append(_deviation_from_chord(points[i], first, chord_vec, chord))
		var mean_dev := 0.0
		for d in devs:
			mean_dev += d
		mean_dev /= float(devs.size())
		var jitter := 0.0
		for d in devs:
			jitter += (d - mean_dev) * (d - mean_dev)
		jitter = sqrt(jitter / float(devs.size()))
		metrics["cleanliness"] = clampf(1.0 - jitter / maxf(chord, 0.0001) * 6.0, 0.0, 1.0)
	return metrics


static func l_max(power: float, curve_stat: float, difficulty: FreeKickDifficulty) -> float:
	# Spatial trace budget in ball radii: base cap from power pressure (difficulty.swipe_scale)
	# scaled by the player's curve stat (high CUR = the shoe can hug more of the ball).
	if difficulty == null:
		return 1.8
	return difficulty.swipe_scale(power) * lerpf(L_MAX_CURVE_MIN, L_MAX_CURVE_MAX, clampf(curve_stat, 0.0, 1.0))


static func classify(metrics: Dictionary, power: float, curve_stat: float, l_max: float, selected_foot: String) -> Technique:
	var point_count: int = metrics.get("point_count", 0)
	var length: float = metrics.get("length", 0.0)
	if point_count < 2 or length < MIN_GESTURE_LENGTH:
		return Technique.PUNTERA
	var curvature: float = metrics.get("curvature", 0.0)
	var sweep_deg := rad_to_deg(float(metrics.get("sweep_angle", 0.0)))
	var vertical_ratio: float = metrics.get("vertical_ratio", 0.0)
	var vertical_sign: int = metrics.get("vertical_sign", 0)
	var side_sign: int = metrics.get("side_sign", 0)
	var curved := curvature >= CURVATURE_LOW or sweep_deg >= SWEEP_ENVELOPE_DEG
	var technique: Technique
	if curved:
		# Inward = toward the kicking foot's natural curl side (right foot: screen-right action).
		var inward := (side_sign > 0) if selected_foot == "right" else (side_sign < 0)
		technique = Technique.INSTEP if inward else Technique.OUTSTEP
	elif vertical_ratio >= VERTICAL_RATIO_ASCENT:
		technique = Technique.TOPSPIN if vertical_sign < 0 else Technique.BACKSPIN
	else:
		var ratio := length / maxf(l_max, 0.001)
		technique = Technique.LACE_LONG if ratio > LONG_TRACE_RATIO else Technique.LACE
	return technique if _confidence(curved, metrics) >= CONFIDENCE_MIN else Technique.DIRTY


static func quality(metrics: Dictionary, technique: Technique, selected_foot: String) -> float:
	# Doc weights: cleanliness 40%, speed consistency 30%, start point 30%.
	var cleanliness: float = metrics.get("cleanliness", 1.0)
	var speed_cv: float = metrics.get("speed_cv", 0.0)
	var consistency := clampf(1.0 - speed_cv / SPEED_CV_MAX, 0.0, 1.0)
	var start_point := _start_point_quality(metrics, technique, selected_foot)
	return clampf(cleanliness * 0.4 + consistency * 0.3 + start_point * 0.3, 0.0, 1.0)


static func _confidence(curved: bool, metrics: Dictionary) -> float:
	var curvature: float = metrics.get("curvature", 0.0)
	var sweep_deg := rad_to_deg(float(metrics.get("sweep_angle", 0.0)))
	var decisiveness := maxf(curvature / CURVATURE_LOW, sweep_deg / SWEEP_ENVELOPE_DEG)
	if curved:
		return clampf(0.5 + decisiveness * 0.5, 0.0, 1.0)
	return clampf(1.0 - decisiveness * 0.5, 0.0, 1.0)


static func _start_point_quality(metrics: Dictionary, technique: Technique, selected_foot: String) -> float:
	var impact: Vector2 = metrics.get("impact", Vector2.ZERO)
	match technique:
		Technique.PUNTERA, Technique.DIRTY:
			return 0.8
		Technique.LACE, Technique.LACE_LONG:
			return clampf(1.0 - absf(impact.x) * 1.2 - absf(impact.y) * 0.9, 0.0, 1.0)
		Technique.INSTEP:
			var expect_in := 0.25 if selected_foot == "right" else -0.25
			return clampf(1.0 - absf(impact.x - expect_in) * 2.2 - maxf(0.0, -impact.y - 0.2) * 1.4, 0.0, 1.0)
		Technique.OUTSTEP:
			var expect_out := -0.25 if selected_foot == "right" else 0.25
			return clampf(1.0 - absf(impact.x - expect_out) * 2.2, 0.0, 1.0)
		Technique.TOPSPIN:
			return clampf(1.0 - maxf(0.0, -impact.y - 0.05) * 1.8 - absf(impact.x) * 1.2, 0.0, 1.0)
		Technique.BACKSPIN:
			return clampf(1.0 - maxf(0.0, impact.y - 0.05) * 1.8 - absf(impact.x) * 1.2, 0.0, 1.0)
	return 0.8


static func _deviation_from_chord(p: Vector2, first: Vector2, chord_vec: Vector2, chord: float) -> float:
	if chord <= 0.0001:
		return 0.0
	var t := clampf((p - first).dot(chord_vec) / (chord * chord), 0.0, 1.0)
	return (p - (first + chord_vec * t)).length()
