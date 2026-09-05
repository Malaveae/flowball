# Mobile UI, Ball Flight Follow, and Post-Shot Feedback — Design

Date: 2026-08-22
Status: Approved design (pending implementation plan)
Scope: `scripts/ui`, `scripts/state_machine` (flight/support states), `FreeKickCameraRig`. No shot math changes.

## Problem

The current free-kick UI is hardcoded for a ~1280x720 desktop window:

- All widget positions use fixed pixel coordinates (`FreeKickUI._apply_mvp_layout()`, `ModernScoreHud._draw()`).
- No safe-area handling (notches), no touch-sized targets, no responsive layout.
- Step 2 (support plant) requires two press-release cycles, awkward on a phone.
- After the kick there is no visual follow of the ball to the net; post-shot feedback is a banner plus a dense text panel.

## Goals

1. One responsive UI serving landscape phones and desktop from the same widgets.
2. Step 2 becomes a single continuous one-thumb flow on touch, with an explicit two-thumb mode toggle and no accidental transitions.
3. The camera follows the ball flight to the goal, with a deterministic trajectory trail and highlighted impact.
4. A compact result card replaces the banner + dense text panel after the shot.

Non-goals: portrait support, aim preview before the kick (trajectory prediction during steps 1-3), gameplay math changes, full theme rebuild.

## Part A — Responsive Layout Foundation + Steps 1-3

### Layout rules (single source of truth per concern)

- Stretch: keep `canvas_items` + `expand`. Global scaling is Godot's job; nothing in our code multiplies a global scale on top of it.
- Positioning: all interactive elements (buttons, labels, power meter, banners) are positioned via anchors + margins relative to a new full-rect `UIRoot` Control inside the existing CanvasLayer.
- Safe area: `UIRoot` margins derive from `DisplayServer.get_display_safe_area()` **converted into viewport space** (`safe_area * viewport_size / screen_size`). Never used raw; screen coords do not match scaled viewport coords under stretch modes.
- Custom `_draw()` widgets (score HUD, wind HUD, plant zone overlay, contact panel, banners) draw in fixed 720p design space. They consume one shared scale helper, e.g. `FreeKickUIScale.widget_scale = clamp(viewport_height / 720.0, 0.85, 1.6)`, applied inside their drawing only. This is the only place that factor exists; anchored Controls must not apply it.

Anchored regions (relative to `UIRoot`):

- Top center: score HUD (custom-drawn, scaled).
- Bottom left: Restart / Foot / Spot buttons.
- Bottom right: player selector (< > + profile label).
- Center left: wind module.
- Touch targets minimum 48 px effective height for all buttons.

### Step 1 — Power

- Meter stays side-anchored relative to the ball projection, clamped inside `UIRoot`.
- Ideal window (70-85%) marked with color AND a notch/groove shape, not text alone.
- Larger readable percent feedback while holding.

### Step 2 — Support Plant (single-gesture, touch-first)

Current behavior: two sequential press-release substeps (`Substep.LOCATION` then `Substep.ANGLE`) in `SupportFootState.gd`.

New input routing, split explicitly by device:

**Touch (mobile):**
- Thumb 1 drags continuously to move the plant marker inside its legal zone (live update while held).
- When the marker is on the legal side, an "AIM" button (>=48 px, anchored bottom within `UIRoot`) enables.
- Tapping AIM with thumb 2 toggles to angle mode: location freezes with a confirmation ring, thumb-1 horizontal movement adjusts aim direction (left/center/right lanes as today). Button becomes "PLANT"; tapping it again returns to location mode without losing aim value. Explicit toggle only — no timers, no dwell detection, no heuristic transitions.
- Multitouch handled by event index (`InputEventScreenTouch/Drag.index`) so both thumbs work simultaneously.
- Release semantics by mode:
  - Release in LOCATION mode: current behavior — locks the plant and advances to the angle substep (natural fallback if the player never finds the toggle).
  - Release in ANGLE mode: commits the whole step 2.

**Desktop (mouse):**
- Unchanged: current two-substep release flow exactly as it works today. The mouse has one pointer and cannot drag while clicking AIM; the two-thumb toggle is touch-only.

**Shared:**
- Legality is decided by the state, not the UI: `SupportFootState` emits e.g. `plant_legality_changed(is_legal)`; `FreeKickUI` consumes it only to show/enable the AIM button. No legality re-validation inside UI code.
- Feedback: legal zone highlights on first touch; on switching to aim mode the aim line and three lanes reinforce with thickness/color plus a short "AIM" label next to the marker. Color is never the sole carrier.
- `FreeKickInputMapper` math does not change; both routes produce identical mapper values for identical intent.

### Steps 1 & 3 adjustments

- Step 3 contact panel keeps a minimum effective diameter (~140 px on small screens) so swipe precision survives scaling; textual feedback shortens to one line.

## Part B — Flight Follow + Post-Shot Feedback

### Camera follow (shot_follow mode)

- New mode `shot_follow` in `FreeKickCameraRig`: smoothly interpolates toward a point between ball and goal center, rate-limited, no cuts. Gameplay states request modes through `FreeKickController` -> rig; nothing manipulates the camera directly.
- The flight state requests `shot_follow` at launch and returns to the free view mode when the play ends (goal, save, or ball rest).
- Deterministic failsafe: if the ball outruns the interpolation, the camera clamps toward the goal — the impact is never lost off-screen.

### Trajectory trail

- 3D line over the ball during flight: positions recorded each physics frame into an `ImmediateMesh`; per-point alpha fades with age.
- Fully deterministic (no particle RNG): same inputs produce the same trail.
- On play end, the whole trail fades out via a short tween before reset.

### Impact highlight

- On contact: brief expanding-ring pulse at the exact impact point — net (goal), post, keeper, or out. Same pattern for all outcomes: project the 3D point to screen and draw (reuses the current goal banner mechanism), color-coded per outcome with a short label so color is never the only signal.

### Result card

- Replaces the current goal banner + dense feedback panel with one compact card anchored top-center under the score HUD, inside `UIRoot` safe area:
  - Line 1: outcome, large ("GOAL", "SAVED", "POST", "WIDE").
  - Line 2: cause in one readable phrase ("curled over the wall", "too much power").
  - Line 3 (secondary): numeric data (power %, elevation, curl), smaller and dimmed.
- Cause text derives from the existing `ShotReport`; the UI formats only, computes nothing.
- Auto-restart countdown lives inside the card; timing unchanged.

## Testing and Verification

- Smoke test (`scripts/tests/ShotCalculatorSmokeTest.gd`) must pass unchanged — no shot math changes anywhere in this design.
- Add synthetic-input test cases for step 2 substep transitions: `LOCATION -> tap AIM -> ANGLE -> toggle back -> release (LOCATION) -> release (ANGLE) -> commit`, asserting the same `FreeKickInputMapper` values as the desktop route for the same intent.
- Manual verification in `res://scenes/sandbox/FreeKickSandbox.tscn`: camera follow smoothness, trail determinism (identical kicks -> identical trails), card readability, safe-area placement.

## Implementation Slices (reviewable units)

1. Layout foundation: `UIRoot`, safe-area conversion, `FreeKickUIScale` helper, button/label anchoring.
2. Steps 1-3 mobile pass: power meter clamp/notch, step 2 two-thumb toggle + state signal, step 3 min size, plus synthetic-input tests.
3. `shot_follow` camera mode wired through controller/state.
4. Trajectory trail + impact highlight.
5. Result card replacing banner + feedback panel; cleanup and final verification pass.

Each slice lands independently verifiable in the sandbox; slices never mix gameplay math with UI restructuring.
