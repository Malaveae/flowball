class_name FreeKickDifficulty
extends Resource

@export var step2_time_limit: float = 3.0
@export var step3_time_limit: float = 2.8
@export var sector_size_multiplier: float = 1.0
@export_range(0, 3, 1) var guidance_level: int = 1
@export var default_penalty_scale: float = 1.0
@export var composure_penalty_scale: float = 1.0
@export_range(0.0, 1.0, 0.01) var input_smoothing_assist: float = 0.35
@export var auto_commit_threshold_multiplier: float = 1.0
