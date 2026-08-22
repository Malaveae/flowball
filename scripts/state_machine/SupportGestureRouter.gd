class_name SupportGestureRouter
extends RefCounted

## Pure decision logic for the step-2 support-plant gesture. No timers, no heuristics:
## every mode transition is an explicit tap on the AIM/PLANT toggle.
## Desktop legacy behavior is preserved: release in LOCATION advances to ANGLE.

enum Action { NONE, UPDATE, TOGGLE_TO_ANGLE, TOGGLE_TO_LOCATION, ADVANCE_SUBSTEP, COMMIT }

const LOCATION := 0
const ANGLE := 1

static func resolve_touch_press(substep: int, has_marker: bool, toggle_requested: bool, legal: bool) -> int:
	if not toggle_requested:
		return Action.NONE
	if not has_marker or not legal:
		return Action.NONE
	if substep == LOCATION:
		return Action.TOGGLE_TO_ANGLE
	if substep == ANGLE:
		return Action.TOGGLE_TO_LOCATION
	return Action.NONE

static func resolve_release(substep: int, has_marker: bool) -> int:
	if not has_marker:
		return Action.NONE
	if substep == LOCATION:
		return Action.ADVANCE_SUBSTEP
	if substep == ANGLE:
		return Action.COMMIT
	return Action.NONE
