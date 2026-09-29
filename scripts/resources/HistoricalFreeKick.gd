class_name HistoricalFreeKick
extends Resource

## One real free kick the mechanics must be able to replicate (Collection mode card).
## Envelope targets are [min, max] ranges: a simulated flight "replicates" the kick when every
## signature with data falls inside its range. A zero-width Vector2.ZERO range means "no data"
## and is skipped by the validator. Coordinates follow BallFlightSimulator:
## goal-mouth x = right (+) / left (-) of the goal center from the kicker's view, y = height.

enum Confidence { MEASURED, BROADCAST_ESTIMATE, DERIVED }

@export var id: String = ""
@export var title: String = ""
@export var kicker: String = ""
@export var match_label: String = ""
@export var date: String = ""
@export var foot: String = "right"
## Free-text technique label from the sources (e.g. "outside-foot curl", "knuckle").
@export var technique: String = ""

# Spot: straight-line distance from the ball to the goal-line center (m) and lateral offset
# of the ball from the goal's center line (m, + = kicker's right when facing goal).
@export var distance_m: float = 25.0
@export var lateral_m: float = 0.0
@export var wall_count: int = 4

# Envelope targets (Vector2(min, max); Vector2.ZERO = unknown).
@export var goal_entry_x_m := Vector2.ZERO
@export var goal_entry_y_m := Vector2.ZERO
@export var launch_speed_ms := Vector2.ZERO
@export var flight_time_s := Vector2.ZERO
## Signed max deviation from the straight chord start -> goal entry (+ = bulges right).
@export var curl_m := Vector2.ZERO
@export var wall_plane_height_m := Vector2.ZERO
@export var knuckle_expected: bool = false

@export var confidence: Confidence = Confidence.DERIVED
@export var sources: PackedStringArray = PackedStringArray()
@export var notes: String = ""

static func has_range(bounds: Vector2) -> bool:
	return bounds != Vector2.ZERO

static func in_range(value: float, bounds: Vector2) -> bool:
	return not has_range(bounds) or (value >= bounds.x and value <= bounds.y)

## Distance outside a range (0 inside), used by the validator's search objective.
static func range_miss(value: float, bounds: Vector2) -> float:
	if not has_range(bounds):
		return 0.0
	if value < bounds.x:
		return bounds.x - value
	if value > bounds.y:
		return value - bounds.y
	return 0.0

## Ball start position in the sandbox world (goal line at goal_center.z, facing +Z).
func ball_position(goal_center: Vector3, ball_height: float = 0.16) -> Vector3:
	var along := sqrt(maxf(distance_m * distance_m - lateral_m * lateral_m, 1.0))
	return Vector3(goal_center.x + lateral_m, ball_height, goal_center.z + along)
