extends SceneTree

var failures := 0
const SAVE := "res://build/arcade_progress_test.cfg"

func _initialize() -> void:
	var progress := FreeKickProgress.new()
	check(progress.unlocked == ["sandbox:001"], "Only the first sandbox shot starts unlocked")
	check(not progress.select_shot(2), "Locked selection is rejected")
	for run in range(1, 4):
		progress.begin_attempt()
		check(progress.close_attempt(run, 1, false), "Miss closes once")
		check(not progress.close_attempt(run, 1, false), "Duplicate callback is ignored")
	check(progress.misses == 3 and progress.attempts == 3, "Three misses counted")
	progress.reset_local_attempts()
	check(progress.misses == 0 and progress.attempts == 3, "Restart preserves accumulated attempts")
	check(progress.close_attempt(4, 1, true), "Goal closes once")
	check(progress.goals == 1 and progress.attempts == 4, "Goal statistics")
	check(progress.unlocked.has("sandbox:002"), "Goal unlocks the next scenario")
	check(progress.select_shot(1), "Completed scenario can be replayed")
	progress.close_attempt(5, 1, true)
	check(progress.completed.size() == 1 and progress.unlocked.size() == 2, "Replay unlock is idempotent")
	check(progress.save_progress(SAVE) == OK, "Save succeeds")
	var restored := FreeKickProgress.new()
	restored.load_progress(SAVE)
	check(restored.goals == 2 and restored.attempts == 5, "Statistics survive reload")
	check(restored.unlocked == progress.unlocked and restored.completed == progress.completed, "Unlocks survive reload")
	check(restored.last_selected == "sandbox:001", "Selection survives reload")
	progress.begin_attempt()
	progress.close_attempt(6, FreeKickProgress.CATALOG_SIZE, true)
	check(not progress.unlocked.has(FreeKickProgress.shot_id(FreeKickProgress.CATALOG_SIZE + 1)), "Final scenario does not unlock a missing entry")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	print("ArcadeProgressSmokeTest: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(failures)

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
