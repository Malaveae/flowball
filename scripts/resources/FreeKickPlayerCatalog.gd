class_name FreeKickPlayerCatalog
extends RefCounted

const DEFAULT_PATH := "res://data/free_kick_players.json"

var _profiles: Array[FreeKickPlayerProfile] = []
var _by_id: Dictionary = {}  # String -> FreeKickPlayerProfile
var last_error: String = ""

func load_from_json(path: String = DEFAULT_PATH) -> bool:
	_profiles.clear()
	_by_id.clear()
	last_error = ""
	if not FileAccess.file_exists(path):
		last_error = "Missing roster file: %s" % path
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		last_error = "Could not open roster file: %s" % path
		return false
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		last_error = "Roster root must be a JSON object"
		return false
	var players: Variant = (parsed as Dictionary).get("players", [])
	if typeof(players) != TYPE_ARRAY:
		last_error = "Roster 'players' must be an array"
		return false
	for entry in players as Array:
		if typeof(entry) != TYPE_DICTIONARY:
			last_error = "Each player entry must be an object"
			return false
		var profile := _profile_from_dict(entry as Dictionary)
		if profile == null:
			return false
		if _by_id.has(profile.id):
			last_error = "Duplicate player id: %s" % profile.id
			return false
		_profiles.append(profile)
		_by_id[profile.id] = profile
	if _profiles.is_empty():
		last_error = "Roster contains no players"
		return false
	return true

func count() -> int:
	return _profiles.size()

func all_profiles() -> Array[FreeKickPlayerProfile]:
	return _profiles.duplicate()

func get_by_id(profile_id: String) -> FreeKickPlayerProfile:
	return _by_id.get(profile_id, null) as FreeKickPlayerProfile

func get_at(index: int) -> FreeKickPlayerProfile:
	if index < 0 or index >= _profiles.size():
		return null
	return _profiles[index]

func index_of(profile_id: String) -> int:
	for i in range(_profiles.size()):
		if _profiles[i].id == profile_id:
			return i
	return -1

func default_profile() -> FreeKickPlayerProfile:
	var starter := get_by_id("starter")
	if starter != null:
		return starter
	for profile in _profiles:
		if profile.unlocked_by_default:
			return profile
	return _profiles[0] if not _profiles.is_empty() else null

func _profile_from_dict(data: Dictionary) -> FreeKickPlayerProfile:
	var profile_id := String(data.get("id", "")).strip_edges()
	if profile_id.is_empty():
		last_error = "Player entry missing id"
		return null
	var stats_data: Variant = data.get("stats", {})
	if typeof(stats_data) != TYPE_DICTIONARY:
		last_error = "Player '%s' stats must be an object" % profile_id
		return null
	var stats := _stats_from_dict(stats_data as Dictionary, profile_id)
	if stats == null:
		return null
	var profile := FreeKickPlayerProfile.new()
	profile.id = profile_id
	profile.display_name = String(data.get("display_name", profile_id))
	profile.archetype = String(data.get("archetype", "balanced"))
	profile.token_cost = int(data.get("token_cost", 0))
	profile.unlocked_by_default = bool(data.get("unlocked_by_default", false))
	profile.stats = stats
	return profile

func _stats_from_dict(data: Dictionary, profile_id: String) -> PlayerFreeKickStats:
	var stats := PlayerFreeKickStats.new()
	stats.kick_power = _clamp_stat(float(data.get("kick_power", 70.0)), profile_id, "kick_power")
	stats.free_kick_accuracy = _clamp_stat(float(data.get("free_kick_accuracy", 70.0)), profile_id, "free_kick_accuracy")
	stats.curve = _clamp_stat(float(data.get("curve", 70.0)), profile_id, "curve")
	stats.technique = _clamp_stat(float(data.get("technique", 70.0)), profile_id, "technique")
	stats.composure = _clamp_stat(float(data.get("composure", 70.0)), profile_id, "composure")
	stats.weak_foot = _clamp_stat(float(data.get("weak_foot", 60.0)), profile_id, "weak_foot")
	var foot := String(data.get("preferred_foot", "right")).to_lower()
	if foot != "left" and foot != "right":
		last_error = "Player '%s' preferred_foot must be left or right" % profile_id
		return null
	stats.preferred_foot = foot
	return stats

func _clamp_stat(value: float, profile_id: String, field: String) -> float:
	if value < 1.0 or value > 100.0:
		push_warning("Player '%s' %s clamped from %.1f into 1-100" % [profile_id, field, value])
	return clampf(value, 1.0, 100.0)
