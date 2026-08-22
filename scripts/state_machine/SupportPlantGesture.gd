class_name SupportPlantGesture
extends RefCounted

## Pure mapping logic for the unified step-2 "plant & aim" gesture.
## Press places the heel (the state clamps it to the legal support-foot side);
## dragging without releasing points the toe radially (heel -> finger) within
## +/-30 degrees; releasing commits. No modes, no timers, no RNG.

const MAX_AIM_DEG := 30.0

## Maps a radial drag (heel anchor -> finger position, in marker-local space)
## to the aim target range -1..1. Neutral toe points up (toward the goal);
## positive result = right post, negative = left post.
static func aim_target_from_toe(heel_local: Vector2, finger_local: Vector2) -> float:
	var dir := finger_local - heel_local
	if dir.length() < 0.001:
		return 0.0
	# Screen-up is -PI/2 in Godot's Y-down space; signed offset from it is the aim.
	var rel := wrapf(dir.angle() - (-PI / 2.0), -PI, PI)
	return clampf(rel / deg_to_rad(MAX_AIM_DEG), -1.0, 1.0)

## Toe (foot) direction vector for an aim target, matching ShotCalculator's
## +/-30 degree visual range.
static func toe_direction(aim_target: float) -> Vector2:
	return Vector2.UP.rotated(clampf(aim_target, -1.0, 1.0) * deg_to_rad(MAX_AIM_DEG))
