class_name GoalTrigger3D
extends Area3D

signal goal_scored

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if body is FreeKickBall3D:
		goal_scored.emit()
		print("GOAL")
