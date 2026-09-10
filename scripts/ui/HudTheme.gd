class_name HudTheme
extends RefCounted

## Single source of truth for the sci-fi HUD visual language.
## Every HUD surface (scoreboard, wind, dist/angle, power meter, contact
## overlay, result card) consumes these constants/factories so a palette
## change only touches this file.
##
## Palette decision (docs/hud-revamp-plan.md): orange accents for
## CONVERSION/MISSES/phase labels; cyan for frames and info values;
## green = success/legal; red = risk/illegal; yellow = in-progress aim.

# --- Frames & accents ---
const CYAN_FRAME := Color(0.08, 0.72, 0.95, 0.9)
const CYAN_FRAME_SOFT := Color(0.0, 0.85, 1.0, 0.45)
const CYAN_BRIGHT := Color(0.0, 0.95, 1.0)
const CYAN_VALUE := Color(0.25, 0.85, 1.0, 0.95)

const ORANGE := Color(1.0, 0.56, 0.0)
const ORANGE_BRIGHT := Color(1.0, 0.68, 0.18)
const ORANGE_DIM := Color(1.0, 0.56, 0.0, 0.55)

const YELLOW := Color(1.0, 0.92, 0.0)
const YELLOW_WARN := Color(1.0, 0.85, 0.2)
const MAGENTA_ALERT := Color(1.0, 0.0, 1.0)

const GREEN_SUCCESS := Color(0.35, 1.0, 0.45)
const GREEN_SOFT := Color(0.55, 1.0, 0.25, 0.9)
const RED_RISK := Color(1.0, 0.16, 0.08)

# --- Text ---
const TEXT_PRIMARY := Color(1.0, 1.0, 1.0, 0.92)
const TEXT_LABEL := Color(0.55, 0.7, 0.85, 0.65)
const TEXT_FAINT := Color(1.0, 1.0, 1.0, 0.35)
const TEXT_HEADER := Color(0.6, 0.78, 0.92, 0.7)

# --- Backgrounds ---
const BG_GLASS := Color(0.0, 0.01, 0.03, 0.55)
const BG_GLASS_DEEP := Color(0.0, 0.008, 0.018, 0.78)
const BG_SCRIM := Color(0.0, 0.005, 0.012, 0.35)

# --- Geometry ---
const RADIUS_PANEL := 8
const RADIUS_CARD := 12


## Standard HUD panel stylebox: dark glass bg + cyan border + rounded corners.
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


## Label stylebox used by pills/value bubbles attached to pointers.
static func pill_style(border_color: Color) -> StyleBoxFlat:
	return panel_style(Color(0.0, 0.0, 0.0, 0.42), border_color, 1, RADIUS_PANEL)


const SMALL_FRAME_TEXTURE_PATH := "res://assets/ui/panel_frame_small.png"
static var _small_frame_style: StyleBoxTexture


## 9-slice stylebox wrapping the small neon frame asset, shared by the
## compact HUD panels (Wind, Dist/Angle). Margins cover the rounded corners.
static func small_frame_style() -> StyleBoxTexture:
	if _small_frame_style == null:
		var style := StyleBoxTexture.new()
		style.texture = load(SMALL_FRAME_TEXTURE_PATH)
		style.set_texture_margin(SIDE_LEFT, 18.0)
		style.set_texture_margin(SIDE_RIGHT, 18.0)
		style.set_texture_margin(SIDE_TOP, 18.0)
		style.set_texture_margin(SIDE_BOTTOM, 18.0)
		_small_frame_style = style
	return _small_frame_style


## Converts a base color into a low-alpha glow variant for under-fills.
static func glow_variant(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, alpha)


## Semantic zone color for power value readouts (LOW/CONTROL/IDEAL/RISK).
static func power_zone_color(value: float, alpha: float = 1.0) -> Color:
	if value < 0.40:
		return Color(0.0, 0.75, 1.0, alpha)
	if value < 0.70:
		return Color(0.3, 1.0, 0.2, alpha)
	if value < 0.85:
		return Color(0.9, 1.0, 0.0, alpha)
	return Color(1.0, 0.18, 0.08, alpha)
