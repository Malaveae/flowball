class_name FreeKickUIScale
extends RefCounted

## Single source of truth for custom _draw() widget scaling (fixed 720p design space).
## Anchored Controls must NOT use this; stretch mode already handles them.

const DESIGN_HEIGHT := 720.0
const MIN_SCALE := 0.85
const MAX_SCALE := 1.6

static func widget_scale(viewport_height: float) -> float:
	return clampf(viewport_height / DESIGN_HEIGHT, MIN_SCALE, MAX_SCALE)

## Converts a screen-space Rect2 into viewport space under canvas_items + expand.
## With that stretch mode the scale factor is uniform, so componentwise division is exact.
static func viewport_safe_area(viewport_size: Vector2, screen_size: Vector2, safe_area_screen: Rect2) -> Rect2:
	if screen_size.x <= 0.0 or screen_size.y <= 0.0:
		return Rect2(Vector2.ZERO, viewport_size)
	var factor := viewport_size / screen_size
	return Rect2(safe_area_screen.position * factor, safe_area_screen.size * factor)
