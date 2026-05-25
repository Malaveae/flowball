class_name FreeKickInputData
extends Resource

@export var hold_time: float = 0.0
@export_range(0.0, 1.0, 0.001) var power_normalized: float = 0.0
@export_enum("right", "left") var selected_foot: String = "right"

@export var support_touch_pos: Vector2 = Vector2.ZERO
@export var support_vector: Vector2 = Vector2.ZERO
@export_range(-1.0, 1.0, 0.001) var plant_depth: float = 0.0
@export var support_timer_expired: bool = false
@export var used_default_support: bool = false

@export var impact_point: Vector2 = Vector2.ZERO
@export var swipe_points: PackedVector2Array = PackedVector2Array()
@export var swipe_duration: float = 0.0
@export var contact_timer_expired: bool = false
@export var used_default_contact: bool = false

func reset() -> void:
	hold_time = 0.0
	power_normalized = 0.0
	selected_foot = "right"
	support_touch_pos = Vector2.ZERO
	support_vector = Vector2.ZERO
	plant_depth = 0.0
	support_timer_expired = false
	used_default_support = false
	impact_point = Vector2.ZERO
	swipe_points = PackedVector2Array()
	swipe_duration = 0.0
	contact_timer_expired = false
	used_default_contact = false
