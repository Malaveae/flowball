class_name FreeKickProgress
extends RefCounted

## Sandbox IDs deliberately do not occupy the tutorial or historical namespaces.
const SAVE_PATH := "user://flowball_progress.cfg"
const CATALOG_SIZE := 60
var unlocked: Array[String] = ["sandbox:001"]
var completed: Array[String] = []
var last_selected := "sandbox:001"
var goals := 0
var attempts := 0
var misses := 0
var result_ready := false
var won := false
var _closed_run := -1

static func shot_id(index: int) -> String:
	return "sandbox:%03d" % index

func begin_attempt() -> void:
	result_ready = false
	won = false

func close_attempt(run: int, index: int, goal: bool) -> bool:
	if run == _closed_run or result_ready:
		return false
	_closed_run = run
	result_ready = true
	won = goal
	attempts += 1
	if goal:
		goals += 1
		var id := shot_id(index)
		if not completed.has(id):
			completed.append(id)
		if index < CATALOG_SIZE and not unlocked.has(shot_id(index + 1)):
			unlocked.append(shot_id(index + 1))
	else:
		misses = mini(misses + 1, 3)
	return true

func select_shot(index: int) -> bool:
	if index < 1 or index > CATALOG_SIZE or not unlocked.has(shot_id(index)):
		return false
	last_selected = shot_id(index)
	reset_local_attempts()
	return true

func reset_local_attempts() -> void:
	misses = 0
	begin_attempt()

func save_progress(path: String = SAVE_PATH) -> Error:
	var config := ConfigFile.new()
	config.set_value("progress", "version", 1)
	config.set_value("progress", "unlocked", unlocked)
	config.set_value("progress", "completed", completed)
	config.set_value("progress", "selected", last_selected)
	config.set_value("stats", "goals", goals)
	config.set_value("stats", "attempts", attempts)
	return config.save(path)

func load_progress(path: String = SAVE_PATH) -> void:
	var config := ConfigFile.new()
	if config.load(path) != OK or config.get_value("progress", "version", 0) != 1:
		return
	var saved_unlocked: Variant = config.get_value("progress", "unlocked", [])
	var saved_completed: Variant = config.get_value("progress", "completed", [])
	if not saved_unlocked is Array or not saved_completed is Array:
		return
	for value in saved_unlocked:
		if value is String and _valid_id(value) and not unlocked.has(value):
			unlocked.append(value)
	for value in saved_completed:
		if value is String and unlocked.has(value) and not completed.has(value):
			completed.append(value)
	var selected: String = str(config.get_value("progress", "selected", last_selected))
	if unlocked.has(selected):
		last_selected = selected
	attempts = maxi(0, int(config.get_value("stats", "attempts", 0)))
	goals = clampi(int(config.get_value("stats", "goals", 0)), 0, attempts)

func _valid_id(id: String) -> bool:
	for index in range(1, CATALOG_SIZE + 1):
		if id == shot_id(index):
			return true
	return false
