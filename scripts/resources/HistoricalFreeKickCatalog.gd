class_name HistoricalFreeKickCatalog
extends RefCounted

## Loads the historical free-kick dataset (Collection mode source of truth). Mirrors
## FreeKickPlayerCatalog: JSON in, typed resources out, last_error on failure.

const DEFAULT_PATH := "res://data/historical_free_kicks.json"
const RANGE_FIELDS := [
	"goal_entry_x_m", "goal_entry_y_m", "launch_speed_ms",
	"flight_time_s", "curl_m", "wall_plane_height_m",
]

var _kicks: Array[HistoricalFreeKick] = []
var _by_id: Dictionary = {}  # String -> HistoricalFreeKick
var last_error: String = ""

func load_from_json(path: String = DEFAULT_PATH) -> bool:
	_kicks.clear()
	_by_id.clear()
	last_error = ""
	if not FileAccess.file_exists(path):
		last_error = "Missing historical free-kick file: %s" % path
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		last_error = "Historical free-kick root must be a JSON object"
		return false
	var kicks: Variant = (parsed as Dictionary).get("kicks", [])
	if typeof(kicks) != TYPE_ARRAY:
		last_error = "'kicks' must be an array"
		return false
	for entry in kicks as Array:
		if typeof(entry) != TYPE_DICTIONARY:
			last_error = "Each kick entry must be an object"
			return false
		var kick := _kick_from_dict(entry as Dictionary)
		if kick == null:
			return false
		if _by_id.has(kick.id):
			last_error = "Duplicate kick id: %s" % kick.id
			return false
		_kicks.append(kick)
		_by_id[kick.id] = kick
	if _kicks.is_empty():
		last_error = "Historical free-kick file contains no kicks"
		return false
	return true

func count() -> int:
	return _kicks.size()

func all_kicks() -> Array[HistoricalFreeKick]:
	return _kicks.duplicate()

func get_by_id(kick_id: String) -> HistoricalFreeKick:
	return _by_id.get(kick_id, null) as HistoricalFreeKick

func _kick_from_dict(data: Dictionary) -> HistoricalFreeKick:
	var kick := HistoricalFreeKick.new()
	kick.id = String(data.get("id", "")).strip_edges()
	if kick.id.is_empty():
		last_error = "Kick entry missing id"
		return null
	kick.title = String(data.get("title", kick.id))
	kick.kicker = String(data.get("kicker", ""))
	kick.match_label = String(data.get("match", ""))
	kick.date = String(data.get("date", ""))
	kick.foot = String(data.get("foot", "right")).to_lower()
	if kick.foot != "left" and kick.foot != "right":
		last_error = "Kick '%s' foot must be left or right" % kick.id
		return null
	kick.technique = String(data.get("technique", ""))
	kick.distance_m = float(data.get("distance_m", 25.0))
	kick.lateral_m = float(data.get("lateral_m", 0.0))
	if kick.distance_m <= 9.15 or absf(kick.lateral_m) >= kick.distance_m:
		last_error = "Kick '%s' has an impossible spot (distance %.1f, lateral %.1f)" % [kick.id, kick.distance_m, kick.lateral_m]
		return null
	kick.wall_count = int(data.get("wall_count", 4))
	var envelope: Dictionary = data.get("envelope", {})
	for field in RANGE_FIELDS:
		if not envelope.has(field):
			continue
		var raw: Variant = envelope[field]
		if typeof(raw) != TYPE_ARRAY or (raw as Array).size() != 2:
			last_error = "Kick '%s' envelope.%s must be [min, max]" % [kick.id, field]
			return null
		var bounds := Vector2(float(raw[0]), float(raw[1]))
		if bounds.x > bounds.y:
			last_error = "Kick '%s' envelope.%s has min > max" % [kick.id, field]
			return null
		kick.set(field, bounds)
	kick.knuckle_expected = bool(data.get("knuckle_expected", false))
	match String(data.get("confidence", "derived")):
		"measured":
			kick.confidence = HistoricalFreeKick.Confidence.MEASURED
		"broadcast_estimate":
			kick.confidence = HistoricalFreeKick.Confidence.BROADCAST_ESTIMATE
		_:
			kick.confidence = HistoricalFreeKick.Confidence.DERIVED
	kick.sources = PackedStringArray(data.get("sources", []))
	kick.notes = String(data.get("notes", ""))
	return kick
