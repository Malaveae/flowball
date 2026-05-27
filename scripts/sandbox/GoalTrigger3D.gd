class_name GoalTrigger3D
extends Area3D

signal goal_scored

@export var net_capture_velocity_scale: float = 0.12
@export var net_capture_max_forward_speed: float = 0.45
@export var net_capture_spin_scale: float = 0.15
@export var net_capture_stop_delay: float = 0.18

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if body is FreeKickBall3D:
		_capture_ball_in_net(body)
		goal_scored.emit()
		print("GOAL")

func _capture_ball_in_net(ball: FreeKickBall3D) -> void:
	var velocity := ball.linear_velocity * net_capture_velocity_scale
	if velocity.z < -net_capture_max_forward_speed:
		velocity.z = -net_capture_max_forward_speed
	ball.linear_velocity = velocity
	ball.angular_velocity *= net_capture_spin_scale
	ball.capture_in_net(net_capture_stop_delay)
