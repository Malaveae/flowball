class_name HudTheme
extends RefCounted

# =============================================================================
# FLOWBALL FOOTBALL ARCHIVE — Design Palette
# =============================================================================
# Single source of truth for the visual language.
# Inspired by: 90s sports broadcast + Swiss editorial + limited cel palette.
#
# Base:        navy / azul muy oscuro
# Action:      cyan eléctrico (completed, info)
#              amarillo (current action)
#              naranja (alert, fail, event)
#              verde (physical feedback correcto)
#
# No rainbow colours. Every colour has a semantic function.
# =============================================================================

# --- Base ---
const BLUE := Color("0068c9")
const PURPLE := Color("9227ce")
const BODY_FONT := preload("res://assets/ui/tv_arcade/fonts/BarlowCondensed-SemiBold.ttf")
const DISPLAY_FONT := preload("res://assets/ui/tv_arcade/fonts/BarlowCondensed-ExtraBoldItalic.ttf")
## The Blender boot render points down; UI forward/aim is screen-up.
const BOOT_FORWARD_ROTATION := PI

const NAVY_DEEP := Color(0.035, 0.055, 0.10)
const NAVY_MID := Color(0.06, 0.09, 0.16)
const NAVY_LIGHT := Color(0.12, 0.18, 0.28)

# --- Cyan (completed, information, frames) ---
const CYAN_BRIGHT := Color(0.0, 0.95, 1.0)
const CYAN_VALUE := Color(0.25, 0.85, 1.0, 0.95)
const CYAN_FRAME := Color(0.08, 0.72, 0.95, 0.9)
const CYAN_FRAME_SOFT := Color(0.0, 0.85, 1.0, 0.45)
const CYAN_DIM := Color(0.0, 0.5, 0.7, 0.5)

# --- Yellow (current action, in-progress) ---
const YELLOW := Color(1.0, 0.92, 0.0)
const YELLOW_WARN := Color(1.0, 0.85, 0.2)
const YELLOW_DIM := Color(0.7, 0.6, 0.0, 0.5)

# --- Orange (alert, fail, event) ---
const ORANGE := Color("ff9419")
const ORANGE_BRIGHT := Color(1.0, 0.68, 0.18)
const ORANGE_DIM := Color(1.0, 0.56, 0.0, 0.55)
const ORANGE_DARK := Color(0.7, 0.35, 0.0)

# --- Green (correct physical feedback) ---
const GREEN_SUCCESS := Color("00ab5d")
const GREEN_SOFT := Color(0.55, 1.0, 0.25, 0.9)

# --- Red (risk, danger) ---
const RED_RISK := Color(1.0, 0.16, 0.08)
const RED_DIM := Color(0.7, 0.1, 0.05, 0.6)

# --- Magenta (alert edge, time-critical) ---
const MAGENTA_ALERT := Color(1.0, 0.0, 1.0)

# --- Text ---
const TEXT_PRIMARY := Color(1.0, 1.0, 1.0, 0.92)
const TEXT_LABEL := Color(0.75, 0.83, 0.94, 1.0)
const TEXT_FAINT := Color(1.0, 1.0, 1.0, 0.35)
const TEXT_HEADER := Color(0.6, 0.78, 0.92, 0.7)
const TEXT_BODY := Color(0.85, 0.88, 0.92, 0.88)

# --- Backgrounds (glassmorphism oscuro) ---
const BG_GLASS := Color(0.035, 0.055, 0.10, 0.72)
const BG_GLASS_DEEP := Color(0.025, 0.04, 0.08, 0.96)
const BG_SCRIM := Color(0.02, 0.03, 0.06, 0.45)

# --- Geometry ---
const RADIUS_PANEL := 6
const RADIUS_CARD := 10


# --- Style factories ---

## Standard HUD panel stylebox.
static func panel_style(
	bg_color: Color = BG_GLASS,
	border_color: Color = CYAN_FRAME_SOFT,
	border_width: int = 1,
	radius: int = RADIUS_PANEL
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	return style

## Pill style for value bubbles.
static func pill_style(border_color: Color) -> StyleBoxFlat:
	return panel_style(Color(0.0, 0.0, 0.0, 0.42), border_color, 1, RADIUS_PANEL)

static func small_frame_style() -> StyleBoxFlat:
	return panel_style(BG_GLASS_DEEP, BLUE, 2, 3)

static func make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font = BODY_FONT
	theme.default_font_size = 20
	return theme

static func draw_arcade_frame(canvas: Control, rect: Rect2, accent: Color) -> void:
	var p := rect.position
	var w := rect.size.x
	var h := rect.size.y
	var cut := 10.0
	var points := PackedVector2Array([p + Vector2(cut, 0), p + Vector2(w-cut, 0), p + Vector2(w, cut), p + Vector2(w, h-cut), p + Vector2(w-cut, h), p + Vector2(cut, h), p + Vector2(0, h-cut), p + Vector2(0, cut)])
	canvas.draw_colored_polygon(points, BG_GLASS_DEEP)
	points.append(points[0])
	canvas.draw_polyline(points, accent, 2.0, true)
	canvas.draw_line(p + Vector2(16, 4), p + Vector2(minf(w-16, 64), 4), accent, 3)
	# Small solid corner facets echo the broadcast frame without a texture dependency.
	for corner in [Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)]:
		var sx := 1.0 if corner.x == 0 else -1.0
		var sy := 1.0 if corner.y == 0 else -1.0
		canvas.draw_colored_polygon(PackedVector2Array([p + corner + Vector2(0, 11 * sy), p + corner + Vector2(11 * sx, 0), p + corner + Vector2(21 * sx, 0), p + corner + Vector2(0, 21 * sy)]), accent)

## Low-alpha glow variant for under-fills.
static func glow_variant(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, alpha)

## Semantic zone colour for power value readouts.
static func power_zone_color(value: float, alpha: float = 1.0) -> Color:
	if value < 0.40:
		return Color(0.0, 0.75, 1.0, alpha)
	if value < 0.70:
		return Color(0.3, 1.0, 0.2, alpha)
	if value < 0.85:
		return YELLOW
	return RED_RISK

## Semantic colour for step phase labels.
static func step_phase_color(step: int, is_active: bool, is_done: bool) -> Color:
	if is_done:
		return CYAN_BRIGHT
	if is_active:
		return YELLOW
	return TEXT_FAINT
