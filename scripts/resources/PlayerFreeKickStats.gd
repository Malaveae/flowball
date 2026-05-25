class_name PlayerFreeKickStats
extends Resource

@export_range(1.0, 100.0, 1.0) var kick_power: float = 70.0
@export_range(1.0, 100.0, 1.0) var free_kick_accuracy: float = 70.0
@export_range(1.0, 100.0, 1.0) var curve: float = 70.0
@export_range(1.0, 100.0, 1.0) var technique: float = 70.0
@export_range(1.0, 100.0, 1.0) var composure: float = 70.0
@export_range(1.0, 100.0, 1.0) var weak_foot: float = 60.0
@export_enum("right", "left") var preferred_foot: String = "right"

func normalized(stat_value: float) -> float:
	return clamp(stat_value / 100.0, 0.01, 1.0)
