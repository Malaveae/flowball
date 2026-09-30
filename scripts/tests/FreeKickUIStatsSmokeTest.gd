extends SceneTree

var _scene: Node
var _passed := false

func _init() -> void:
	var packed: PackedScene = load("res://scenes/free_kick/FreeKickController.tscn")
	_scene = packed.instantiate()
	get_root().add_child(_scene)
	process_frame.connect(_run, CONNECT_ONE_SHOT)

func _run() -> void:
	var ui := _scene.get_node("FreeKickUI") as FreeKickUI
	ui.set_run_hud(2, 5, 8, 1, 3, "test")

	var hud := ui.score_hud as ArcadeScoreHud
	_passed = hud != null \
		and hud.level == 2 \
		and hud.goals == 5 \
		and hud.attempts == 8 \
		and hud.misses == 1 \
		and hud.max_misses == 3

	print("FreeKickUIStatsSmokeTest: ", "PASS" if _passed else "FAIL")
	quit(0 if _passed else 1)
