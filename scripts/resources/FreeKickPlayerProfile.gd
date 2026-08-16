class_name FreeKickPlayerProfile
extends Resource

## Stable unlock / save key (future token shop).
@export var id: String = ""
@export var display_name: String = "Unknown"
## Build role: power, curl, knuckle, placement, balanced, etc.
@export var archetype: String = "balanced"
@export var stats: PlayerFreeKickStats
## Reserved for future token shop; unused in this slice.
@export var token_cost: int = 0
@export var unlocked_by_default: bool = false

func ensure_stats() -> PlayerFreeKickStats:
	if stats == null:
		stats = PlayerFreeKickStats.new()
	return stats

func duplicate_stats() -> PlayerFreeKickStats:
	var source := ensure_stats()
	return source.duplicate(true) as PlayerFreeKickStats
