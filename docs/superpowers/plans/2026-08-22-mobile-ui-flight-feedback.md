# Mobile UI + Ball Flight Follow + Post-Shot Feedback — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Flowball's free-kick UI responsive for landscape phones (steps 1–3 touch-friendly, step 2 single-gesture with explicit two-thumb toggle), and add deterministic ball-flight follow (tracking camera, trajectory trail, impact highlight) plus a compact post-shot result card.

**Architecture:** One shared UI serves desktop and mobile. Stretch mode `canvas_items` + `expand` handles global scaling; a new safe-area-aware `Root` control hosts all anchored widgets; custom `_draw()` widgets consume a single shared scale helper. Step 2 gesture routing is split explicitly by input device (touch two-thumb toggle vs desktop two-substep release), with legality decided by the state via signal. Camera `SHOT_FOLLOW` upgrades from a one-shot tween to continuous per-frame tracking with a deterministic clamp failsafe. Trail and impact use no RNG.

**Tech Stack:** Godot 4.6, GDScript 2, Jolt physics. Existing scene `res://scenes/sandbox/FreeKickSandbox.tscn`, controller `FreeKickController`, state machine under `scripts/state_machine`, camera rig `scripts/camera/FreeKickCameraRig.gd`.

**Spec:** `docs/superpowers/specs/2026-08-22-mobile-ui-flight-feedback-design.md` (travels with this plan; executor reads both).

## Global Constraints

- No shot-math changes: `ShotCalculator` stays deterministic and identical for identical inputs; `scripts/tests/ShotCalculatorSmokeTest.gd` must pass unchanged after every task.
- `FreeKickInputMapper` values for the same intent must be identical between the touch route and the desktop route.
- Legality of the plant is decided only by `SupportFootState` (signal), never re-validated in UI code.
- No timers/heuristics for step-2 mode transitions: every transition is an explicit tap on the AIM/PLANT toggle. Release semantics by mode: release in LOCATION advances to ANGLE (desktop legacy behavior preserved as fallback); release in ANGLE commits step 2.
- Desktop mouse flow stays unchanged (one pointer cannot drag + click; two-thumb toggle is touch-only).
- Interactive touch targets minimum 48 px effective height.
- `canvas_items` + `expand` remains the stretch mode; never apply a second global scale on top. Custom `_draw()` widgets use only `FreeKickUIScale.widget_scale()`.
- Safe area comes from `DisplayServer.get_display_safe_area()` converted into viewport space (`viewport_size / screen_size` componentwise), window-relative. Never used raw.
- All state transitions, camera moves, trail data, and impact pulses are deterministic: no RNG anywhere in this plan.
- Gameplay states request camera modes through `FreeKickController.camera_rig.set_mode()`; nothing manipulates the camera directly.
- Code comments and identifiers in English, matching the repo.

---

### Task 1: Scale helper + safe-area conversion + UIRoot margins

**Files:**
- Create: `scripts/ui/FreeKickUIScale.gd`
- Create: `scripts/tests/FreeKickUIScaleSmokeTest.gd`
- Modify: `scripts/ui/FreeKickUI.gd`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `FreeKickUIScale.widget_scale(viewport_height: float) -> float`
  - `FreeKickUIScale.viewport_safe_area(viewport_size: Vector2, screen_size: Vector2, safe_area_screen: Rect2) -> Rect2`
  - `FreeKickUI._update_uiroot_margins() -> void` (uses the above)

- [ ] **Step 1: Write the failing test**

Create `scripts/tests/FreeKickUIScaleSmokeTest.gd` following the structure of `scripts/tests/ShotCalculatorSmokeTest.gd` (`extends SceneTree`, `_init()` runs cases, prints result, `quit(0/1)`):

```gdscript
extends SceneTree

func _init() -> void:
	var ok := true
	ok = _test_widget_scale_bounds() and ok
	ok = _test_widget_scale_at_720_is_one() and ok
	ok = _test_viewport_safe_area_scales() and ok
	print("FreeKickUIScaleSmokeTest: ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)

func _test_widget_scale_bounds() -> bool:
	var low := FreeKickUIScale.widget_scale(300.0)
	var high := FreeKickUIScale.widget_scale(4000.0)
	return low == 0.85 and high == 1.6

func _test_widget_scale_at_720_is_one() -> bool:
	return FreeKickUIScale.widget_scale(720.0) == 1.0

func _test_viewport_safe_area_scales() -> bool:
	# Window 2340x1080, safe area inset 80px left/top, 120px right/bottom on screen.
	# Scale factor 1.5 -> viewport 1560x720.
	var viewport := Vector2(1560.0, 720.0)
	var screen := Vector2(2340.0, 1080.0)
	var safe := Rect2(80.0, 80.0, 2340.0 - 200.0, 1080.0 - 200.0)
	var got := FreeKickUIScale.viewport_safe_area(viewport, screen, safe)
	var expected := Rect2(80.0 / 1.5, 80.0 / 1.5, (2340.0 - 200.0) / 1.5, (1080.0 - 200.0) / 1.5)
	var tol := 0.001
	return (
		absf(got.position.x - expected.position.x) < tol
		and absf(got.position.y - expected.position.y) < tol
		and absf(got.size.x - expected.size.x) < tol
		and absf(got.size.y - expected.size.y) < tol
	)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --script scripts/tests/FreeKickUIScaleSmokeTest.gd`
Expected: FAIL — "Parse Error: Could not find type 'FreeKickUIScale'".

- [ ] **Step 3: Write minimal implementation**

Create `scripts/ui/FreeKickUIScale.gd`:

```gdscript
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
```

In `scripts/ui/FreeKickUI.gd`, add a full-rect `ui_root` that owns safe-area margins, and hook resize. Add member and `_ready` wiring:

```gdscript
var ui_root: Control

func _ready() -> void:
	ui_root = get_node_or_null("Root") as Control
	if ui_root != null:
		ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
		ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_update_uiroot_margins()
		get_viewport().size_changed.connect(_update_uiroot_margins)
	# ... existing _ready body continues unchanged
```

Add method:

```gdscript
func _update_uiroot_margins() -> void:
	if ui_root == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0:
		viewport_size = Vector2(1280.0, 720.0)
	var screen_size := Vector2(DisplayServer.screen_get_size())
	# get_display_safe_area is monitor-relative; convert to window-relative first.
	var safe_screen := DisplayServer.get_display_safe_area()
	var win_pos := Vector2(DisplayServer.window_get_position())
	var safe_window := Rect2(safe_screen.position - win_pos, safe_screen.size)
	var safe_viewport := FreeKickUIScale.viewport_safe_area(viewport_size, screen_size, safe_window)
	ui_root.offset_left = maxf(0.0, safe_viewport.position.x)
	ui_root.offset_top = maxf(0.0, safe_viewport.position.y)
	ui_root.offset_right = -maxf(0.0, viewport_size.x - safe_viewport.end.x)
	ui_root.offset_bottom = -maxf(0.0, viewport_size.y - safe_viewport.end.y)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `godot --headless --script scripts/tests/FreeKickUIScaleSmokeTest.gd`
Expected: PASS.

Also run the existing smoke test to confirm nothing broke:
Run: `godot --headless --script scripts/tests/ShotCalculatorSmokeTest.gd`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/ui/FreeKickUIScale.gd scripts/tests/FreeKickUIScaleSmokeTest.gd scripts/ui/FreeKickUI.gd
git commit -m "ui: add responsive scale helper and safe-area UIRoot margins"
```

---

### Task 2: Anchor-based layout for buttons, labels, score HUD, wind module

**Files:**
- Modify: `scripts/ui/FreeKickUI.gd`

**Interfaces:**
- Consumes: `FreeKickUIScale.widget_scale(viewport_height: float) -> float` (Task 1); `ui_root` full-rect Control (Task 1).
- Produces: `FreeKickUI._place_anchored(control: Control, anchor_point: Vector2, margin: Vector2, size_value: Vector2) -> void` — positions any control relative to `ui_root` edges with widget-scale-aware sizing.

- [ ] **Step 1: Add the anchor helper**

In `scripts/ui/FreeKickUI.gd` add:

```gdscript
## Positions `control` inside ui_root at a normalized anchor point (0..1) with an edge margin.
## Sizes scale with the widget scale; margins stay in viewport px (stretch already scales them).
func _place_anchored(control: Control, anchor_point: Vector2, margin: Vector2, size_value: Vector2) -> void:
	if control == null or ui_root == null:
		return
	control.anchor_left = anchor_point.x
	control.anchor_top = anchor_point.y
	control.anchor_right = anchor_point.x
	control.anchor_bottom = anchor_point.y
	var s := size_value * FreeKickUIScale.widget_scale(ui_root.size.y if ui_root.size.y > 0.0 else 720.0)
	if anchor_point.x < 0.5:
		control.offset_left = margin.x
		control.offset_right = margin.x + s.x
	else:
		control.offset_left = -margin.x - s.x
		control.offset_right = -margin.x
	if anchor_point.y < 0.5:
		control.offset_top = margin.y
		control.offset_bottom = margin.y + s.y
	else:
		control.offset_top = -margin.y - s.y
		control.offset_bottom = -margin.y
```

- [ ] **Step 2: Migrate the fixed-position calls**

Replace the body of `_apply_mvp_layout()` so every hardcoded `position/size` pair for an interactive control becomes a `_place_anchored` call, keeping identical text and styling:

- `restart_button` → anchor `(0.0, 1.0)`, margin `(24.0, 24.0)`, size `(158.0, 40.0)`.
- `switch_foot_button` → anchor `(0.0, 1.0)`, margin `(24.0, 70.0)`, size `(128.0, 32.0)`.
- `next_spot_button` → anchor `(0.0, 1.0)`, margin `(24.0, 110.0)`, size `(196.0, 40.0)`.
- `prev_player_button` → anchor `(1.0, 1.0)`, margin `(24.0, 24.0)`, size `(64.0, 40.0)`.
- `next_player_button` → anchor `(1.0, 1.0)`, margin `(100.0, 24.0)`, size `(64.0, 40.0)`.
- `player_profile_label` → anchor `(1.0, 1.0)`, margin `(172.0, 20.0)`, size `(296.0, 48.0)`.
- `feedback_label` → anchor `(0.0, 0.0)`, margin `(24.0, 60.0)`, size `(520.0, 58.0)` (below instruction area — see note).
- `instruction_label` → anchor `(0.0, 1.0)`, margin `(24.0, 64.0)`, size `(760.0, 28.0)`.
- `status_label` → anchor `(0.0, 1.0)`, margin `(24.0, 100.0)`, size `(520.0, 24.0)`.

Note: `feedback_label` is used both as a step-instruction consequence line (top) and as the post-shot panel (Task 8). For now anchor it top-left below the power meter area; Task 8 repositions it inside the result card.

Replace `_center_score_hud()` with anchor-based centering:

```gdscript
func _center_score_hud() -> void:
	if score_hud == null or ui_root == null:
		return
	score_hud.anchor_left = 0.5
	score_hud.anchor_right = 0.5
	score_hud.anchor_top = 0.0
	score_hud.anchor_bottom = 0.0
	score_hud.offset_left = -score_hud.size.x * score_hud.scale.x * 0.5
	score_hud.offset_right = score_hud.size.x * score_hud.scale.x * 0.5
	score_hud.offset_top = 20.0
	score_hud.offset_bottom = 20.0 + score_hud.size.y * score_hud.scale.y
```

and set its scale from the widget scale in `_create_score_hud()`:

```gdscript
hud.scale = Vector2.ONE * FreeKickUIScale.widget_scale(720.0)
```

(scale is refreshed in `_update_uiroot_margins()` — add `score_hud.scale = Vector2.ONE * FreeKickUIScale.widget_scale(viewport_size.y)` there when `score_hud != null`.)

Wind module: `_create_wind_module()` keeps its anchor (`PRESET_CENTER_LEFT`) but its `position` becomes `Vector2(22.0, -46.0)` relative to `ui_root` — change from `root.add_child(hud)`/manual to `ui_root.add_child(hud)` and `hud.set_anchors_preset(Control.PRESET_CENTER_LEFT)` with `hud.position = Vector2(22.0, -46.0)`.

- [ ] **Step 3: Verify layout runs**

Run: `godot --path .`
Manual check: windowed 1280x720 — buttons bottom-left/bottom-right, score HUD centered top, wind center-left; nothing overlaps; restart flow still works.

- [ ] **Step 4: Run smoke test**

Run: `godot --headless --script scripts/tests/ShotCalculatorSmokeTest.gd`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/ui/FreeKickUI.gd
git commit -m "ui: anchor interactive controls and score HUD to safe UIRoot"
```

---

### Task 3: Step 1 power meter — touch clamp + ideal-window notch

**Files:**
- Modify: `scripts/ui/PowerMeterPanel.gd`
- Modify: `scripts/ui/FreeKickUI.gd`

**Interfaces:**
- Consumes: `ui_root` full-rect (Task 1); `PowerMeterPanel.power_value` (existing).
- Produces: nothing new; behavior change only.

- [ ] **Step 1: Add the ideal-window notch markers**

In `PowerMeterPanel.gd::_draw()`, after the segment fills (`_draw_vertical_segment` calls), add two groove lines at the optimal window bounds so the zone is visible by shape, not color only:

```gdscript
	# Ideal window grooves: shape + color, never color alone (accessibility).
	var notch_color := Color(1.0, 1.0, 1.0, 0.55)
	for frac in [OPTIMAL_MIN, OPTIMAL_MAX]:
		var y := inner.end.y - inner.size.y * frac
		draw_line(Vector2(inner.position.x - 5.0, y), Vector2(inner.position.x + bar_width + 5.0, y), notch_color, 1.6)
	draw_string(font, Vector2(inner.position.x, inner.end.y - inner.size.y * OPTIMAL_MAX - 8.0), "IDEAL", HORIZONTAL_ALIGNMENT_CENTER, bar_width, 9, Color(1.0, 0.92, 0.0, 0.8))
```

(Keep existing `_power_color`, `_draw_vertical_segment`, boot texture code untouched.)

- [ ] **Step 2: Clamp the meter inside ui_root**

In `FreeKickUI._position_power_meter_for_foot()` and `align_power_meter_to_ball()`, replace the viewport-based clamp with a ui_root-relative clamp. Extract a helper:

```gdscript
func _clamp_to_uiroot(desired_pos: Vector2, control_size: Vector2) -> Vector2:
	if ui_root == null:
		return desired_pos
	var x := clampf(desired_pos.x, ui_root.offset_left + 18.0, ui_root.size.x + ui_root.offset_left - control_size.x - 18.0)
	var y := clampf(desired_pos.y, ui_root.offset_top + 80.0, ui_root.size.y + ui_root.offset_top - control_size.y - 72.0)
	return Vector2(x, y)
```

Use it in both functions: `power_meter.position = _clamp_to_uiroot(desired, power_meter.size)` (compute `desired` exactly as today).

- [ ] **Step 3: Verify**

Run: `godot --path .`
Manual check: hold power — meter clamps inside safe area at small phone window (e.g. 800x360) and large; notch + IDEAL label visible; fill color still transitions.

Run: `godot --headless --script scripts/tests/ShotCalculatorSmokeTest.gd`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add scripts/ui/PowerMeterPanel.gd scripts/ui/FreeKickUI.gd
git commit -m "ui: clamp power meter to safe area and add ideal-window notch"
```

---

### Task 4: Step 2 — gesture router + two-thumb toggle + legality signal

**Files:**
- Create: `scripts/state_machine/SupportGestureRouter.gd`
- Create: `scripts/tests/SupportGestureRouterSmokeTest.gd`
- Modify: `scripts/state_machine/SupportFootState.gd`
- Modify: `scripts/ui/FreeKickUI.gd`

**Interfaces:**
- Consumes: `FreeKickInputMapper.clamp_to_support_foot_side` (existing); `SupportFootState` existing members (`substep`, `has_marker`, `marker_local`, `aim_target`, `foot_angle`, `radius`, `touching`).
- Produces:
  - `SupportGestureRouter.Action` enum (`NONE, UPDATE, TOGGLE_TO_ANGLE, TOGGLE_TO_LOCATION, ADVANCE_SUBSTEP, COMMIT`)
  - `SupportGestureRouter.resolve_touch_press(substep: int, has_marker: bool, toggle_requested: bool, legal: bool) -> int`
  - `SupportGestureRouter.resolve_release(substep: int, has_marker: bool) -> int`
  - `SupportFootState.plant_legality_changed(legal: bool)` signal
  - `SupportFootState.set_aim_toggle_requested() -> void`
  - `FreeKickUI.aim_toggle_pressed` signal + `set_aim_toggle_enabled(enabled: bool)` + `set_aim_toggle_mode(in_angle_mode: bool)`

- [ ] **Step 1: Write the failing test**

Create `scripts/tests/SupportGestureRouterSmokeTest.gd`:

```gdscript
extends SceneTree

func _init() -> void:
	var ok := true
	ok = _test_release_location_advances() and ok
	ok = _test_release_angle_commits() and ok
	ok = _test_toggle_requires_legal_and_marker() and ok
	ok = _test_toggle_cycles_modes() and ok
	ok = _test_angle_release_without_marker_noop() and ok
	print("SupportGestureRouterSmokeTest: ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)

const LOCATION := 0
const ANGLE := 1
const A := SupportGestureRouter.Action

func _test_release_location_advances() -> bool:
	return A.resolve_release(LOCATION, true) == A.ADVANCE_SUBSTEP

func _test_release_angle_commits() -> bool:
	return A.resolve_release(ANGLE, true) == A.COMMIT

func _test_toggle_requires_legal_and_marker() -> bool:
	return A.resolve_touch_press(LOCATION, false, true, true) == A.NONE \
		and A.resolve_touch_press(LOCATION, true, true, false) == A.NONE \
		and A.resolve_touch_press(LOCATION, true, false, true) == A.NONE

func _test_toggle_cycles_modes() -> bool:
	return A.resolve_touch_press(LOCATION, true, true, true) == A.TOGGLE_TO_ANGLE \
		and A.resolve_touch_press(ANGLE, true, true, true) == A.TOGGLE_TO_LOCATION

func _test_angle_release_without_marker_noop() -> bool:
	return A.resolve_release(ANGLE, false) == A.NONE
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --script scripts/tests/SupportGestureRouterSmokeTest.gd`
Expected: FAIL — "Could not find type 'SupportGestureRouter'".

- [ ] **Step 3: Write the router**

Create `scripts/state_machine/SupportGestureRouter.gd`:

```gdscript
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `godot --headless --script scripts/tests/SupportGestureRouterSmokeTest.gd`
Expected: PASS.

- [ ] **Step 5: Wire the router + legality signal into SupportFootState**

In `scripts/state_machine/SupportFootState.gd`:

Add signal near the top:

```gdscript
signal plant_legality_changed(legal: bool)
```

Add members:

```gdscript
var _drag_index := -1  # touch index of the primary dragging thumb
```

Replace the release handling block in `_input()` with router calls:

```gdscript
	if should_update:
		_update_from_screen(pos)
		get_viewport().set_input_as_handled()
	elif released:
		touching = false
		var action := SupportGestureRouter.resolve_release(substep, has_marker)
		match action:
			SupportGestureRouter.Action.ADVANCE_SUBSTEP:
				substep = Substep.ANGLE
				controller.ui.set_aim_toggle_mode(true)
				controller.ui.update_support_foot_angle(foot_angle, aim_target)
			SupportGestureRouter.Action.COMMIT:
				_commit(false)
			_:
				pass
		get_viewport().set_input_as_handled()
```

Add the toggle entry point (called by the UI's AIM button):

```gdscript
func set_aim_toggle_requested() -> void:
	var legal := _is_plant_legal()
	var action := SupportGestureRouter.resolve_touch_press(substep, has_marker, true, legal)
	match action:
		SupportGestureRouter.Action.TOGGLE_TO_ANGLE:
			substep = Substep.ANGLE
			controller.ui.set_aim_toggle_mode(true)
			controller.ui.update_support_foot_angle(foot_angle, aim_target)
		SupportGestureRouter.Action.TOGGLE_TO_LOCATION:
			substep = Substep.LOCATION
			controller.ui.set_aim_toggle_mode(false)
		_:
			pass
```

Add legality helper (single source of truth):

```gdscript
func _is_plant_legal() -> bool:
	if not has_marker:
		return false
	var support := FreeKickInputMapper.support_vector_from_marker(marker_local, radius)
	if controller.input_data.selected_foot == "right":
		return support.x < -0.05
	return support.x > 0.05
```

Emit the signal whenever the marker changes — at the end of `_update_from_screen()` in the LOCATION branch, after `controller.ui.update_support_marker(marker_local)`:

```gdscript
		plant_legality_changed.emit(_is_plant_legal())
```

and in `enter()` after the initial marker set, emit the initial state:

```gdscript
	plant_legality_changed.emit(_is_plant_legal())
```

Also reset `_drag_index = -1` in `enter()`.

- [ ] **Step 6: Wire the AIM toggle button into FreeKickUI**

In `scripts/ui/FreeKickUI.gd`:

Add signal:

```gdscript
signal aim_toggle_pressed
```

Add members:

```gdscript
var aim_toggle_button: Button
var _aim_toggle_enabled := false
var _aim_toggle_angle_mode := false
```

In `_ready()` create the button anchored bottom-center (reachable by the second thumb in landscape):

```gdscript
func _create_aim_toggle() -> void:
	aim_toggle_button = Button.new()
	aim_toggle_button.name = "AimToggleButton"
	aim_toggle_button.text = "AIM"
	aim_toggle_button.disabled = true
	aim_toggle_button.visible = false
	aim_toggle_button.pressed.connect(func() -> void: aim_toggle_pressed.emit())
	if ui_root != null:
		ui_root.add_child(aim_toggle_button)
	_place_anchored(aim_toggle_button, Vector2(0.5, 1.0), Vector2(0.0, 24.0), Vector2(120.0, 52.0))
```

Call it from `_ready()`. Add setters:

```gdscript
func set_aim_toggle_enabled(enabled: bool) -> void:
	_aim_toggle_enabled = enabled
	if aim_toggle_button != null:
		aim_toggle_button.visible = enabled
		aim_toggle_button.disabled = not enabled

func set_aim_toggle_mode(in_angle_mode: bool) -> void:
	_aim_toggle_angle_mode = in_angle_mode
	if aim_toggle_button != null:
		aim_toggle_button.text = "PLANT" if in_angle_mode else "AIM"
```

Style it with `_style_button`-like theming (font_size 16, min height already 52).

In `show_support_foot_sector()` call `set_aim_toggle_enabled(false)`; connect legality in the state instead (state calls `controller.ui.set_aim_toggle_enabled(legal)` in the `plant_legality_changed` emission — replace the direct emit with a helper that both emits and updates UI):

```gdscript
func _update_plant_legality_ui() -> void:
	var legal := _is_plant_legal()
	plant_legality_changed.emit(legal)
	controller.ui.set_aim_toggle_enabled(legal)
```

and call `_update_plant_legality_ui()` in the two places above instead of `plant_legality_changed.emit(...)`.

- [ ] **Step 7: Run both smoke tests**

Run: `godot --headless --script scripts/tests/SupportGestureRouterSmokeTest.gd`
Expected: PASS.
Run: `godot --headless --script scripts/tests/ShotCalculatorSmokeTest.gd`
Expected: PASS.

- [ ] **Step 8: Verify touch + desktop flows manually**

Run: `godot --path .`

Touch (or simulate via mouse events in a touch-capable device):
- Drag marker into legal side → AIM button appears enabled; tap → mode switches to angle, marker freezes, horizontal drag adjusts aim; button text becomes PLANT; tap again → back to location, aim value retained; release in ANGLE → commits.
- Release in LOCATION without touching toggle → advances to ANGLE (legacy behavior intact).

Desktop: two-substep release flow behaves exactly as before (release → lock → drag aim → release → commit).

- [ ] **Step 9: Commit**

```bash
git add scripts/state_machine/SupportGestureRouter.gd scripts/tests/SupportGestureRouterSmokeTest.gd scripts/state_machine/SupportFootState.gd scripts/ui/FreeKickUI.gd
git commit -m "feat: step 2 two-thumb aim toggle with deterministic gesture router"
```

---

### Task 5: Step 3 — minimum contact size + one-line feedback

**Files:**
- Modify: `scripts/ui/FreeKickUI.gd`
- Modify: `scripts/ui/BallContactPanel.gd`

**Interfaces:**
- Consumes: `align_ball_contact_overlay` (existing); `FreeKickUIScale.widget_scale` (Task 1).
- Produces: nothing new.

- [ ] **Step 1: Enforce minimum effective contact diameter**

In `FreeKickUI.align_ball_contact_overlay()`, replace the clamp:

```gdscript
	var min_radius := 70.0 * FreeKickUIScale.widget_scale(get_viewport().get_visible_rect().size.y)
	screen_radius = maxf(min_radius, screen_radius)
```

so the panel never shrinks below ~140 px effective diameter on small screens.

- [ ] **Step 2: Shorten step-3 textual feedback**

In `FreeKickUI._ball_contact_feedback()` return a single concise line, e.g.:

```gdscript
	if points.is_empty():
		return "Touch the ball, then drag to follow through"
	var contact := points[0] / maxf(1.0, ball_panel.ball_radius_px)
	var height := "lift" if contact.y > 0.25 else "drive" if contact.y < -0.25 else "medium"
	if points.size() < 2:
		return "Height: %s - keep dragging" % height
	var follow := (points[points.size() - 1] - points[0]) / maxf(1.0, ball_panel.ball_radius_px)
	var curl := "left" if follow.x < -0.12 else "right" if follow.x > 0.12 else "straight"
	return "Height: %s - curl: %s" % [height, curl]
```

`_ball_contact_status()` keeps its numeric line for the status area.

- [ ] **Step 3: Verify**

Run: `godot --path .`
Manual: at 800x360 the contact circle stays large enough to swipe accurately; feedback reads as one short line.

Run: `godot --headless --script scripts/tests/ShotCalculatorSmokeTest.gd`
Expected: PASS (UI-only change).

- [ ] **Step 4: Commit**

```bash
git add scripts/ui/FreeKickUI.gd scripts/ui/BallContactPanel.gd
git commit -m "ui: enforce min contact size and shorten step-3 feedback"
```

---

### Task 6: SHOT_FOLLOW continuous tracking camera

**Files:**
- Modify: `scripts/camera/FreeKickCameraRig.gd`

**Interfaces:**
- Consumes: existing `mode`, `goal_position`, `_target_position()`, `_clamp_camera_origin()`, `shot_follow_fov`.
- Produces: continuous tracking behavior when `mode == &"SHOT_FOLLOW"`; `tracking_active()` accessor for the trail task.

- [ ] **Step 1: Add per-frame tracking**

Add members:

```gdscript
const SHOT_FOLLOW_RATE := 6.0  # 1/s lerp rate toward target transform
var _follow_active := false

func tracking_active() -> bool:
	return _follow_active
```

In `set_mode()`, when entering `SHOT_FOLLOW` set `_follow_active = true` and `process_mode = Node.PROCESS_MODE_ALWAYS` (the camera may need to track while other nodes pause); for any other mode set `_follow_active = false`.

Add:

```gdscript
func _process(delta: float) -> void:
	if not _follow_active or mode != &"SHOT_FOLLOW":
		return
	var camera := get_camera()
	if camera == null:
		return
	var target := _shot_follow_transform()
	var weight := 1.0 - exp(-SHOT_FOLLOW_RATE * delta)
	camera.global_transform = camera.global_transform.interpolate_with(target, weight)
	camera.fov = lerpf(camera.fov, shot_follow_fov, weight)
```

Add the live target transform (computed from the ball's current position, not the launch-time snapshot):

```gdscript
func _shot_follow_transform() -> Transform3D:
	var ball := _target_position()
	var goal := goal_position
	var to_goal := (goal - ball).slide(Vector3.UP)
	if to_goal.length() < 0.01:
		to_goal = Vector3.FORWARD
	var dir := to_goal.normalized()
	var right := dir.cross(Vector3.UP).normalized()
	var distance := ball.distance_to(goal)
	var behind := clampf(distance * 0.16, 3.2, 6.0)
	var origin := ball - dir * behind + Vector3.UP * 1.85
	origin = _clamp_camera_origin(origin)
	var target := goal.lerp(ball, 0.30) + Vector3.UP * 0.7
	return Transform3D(Basis.looking_at((target - origin).normalized(), Vector3.UP), origin)
```

`_transform_for_mode` keeps returning the static one-shot for the initial tween on entry (smooth approach), then `_process` takes over; `_fov_for_mode` already maps `SHOT_FOLLOW` to `shot_follow_fov`.

- [ ] **Step 2: Verify**

Run: `godot --path .`
Manual: take a shot — camera transitions smoothly from launch view into continuous tracking behind the ball, follows to goal/save, clamps when the ball outruns it (never loses impact), and `FEEDBACK_REPLAY` still engages after.

- [ ] **Step 3: Run smoke test**

Run: `godot --headless --script scripts/tests/ShotCalculatorSmokeTest.gd`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add scripts/camera/FreeKickCameraRig.gd
git commit -m "feat: continuous shot-follow camera tracking with clamp failsafe"
```

---

### Task 7: Deterministic ball-flight trail

**Files:**
- Create: `scripts/ball/BallFlightTrail.gd`
- Modify: `scripts/state_machine/ExecuteShotState.gd`

**Interfaces:**
- Consumes: `FreeKickBall3D.launched` signal (existing), `FreeKickBall3D.global_position`; camera rig `tracking_active()` (Task 6) is not required — trail is independent.
- Produces: `BallFlightTrail.begin_tracking(ball: FreeKickBall3D) -> void`, `BallFlightTrail.stop_and_fade() -> void`.

- [ ] **Step 1: Write the trail node**

Create `scripts/ball/BallFlightTrail.gd`:

```gdscript
class_name BallFlightTrail
extends Node3D

## Deterministic 3D line behind the flying ball. Records positions each physics
## frame; older points fade. No RNG: same shot, same trail.

const MAX_POINTS := 240
const FADE_LIFETIME := 1.2  # seconds for a point to fade out

var _ball: Node3D
var _points: PackedVector3Array = PackedVector3Array()
var _ages: Array[float] = []
var _fading := false
var _fade_elapsed := 0.0
var _fade_duration := 0.5
var _mesh: ImmediateMesh
var _mesh_instance: MeshInstance3D

func _ready() -> void:
	_mesh = ImmediateMesh.new()
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.mesh = _mesh
	_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh_instance)

func begin_tracking(ball: Node3D) -> void:
	_ball = ball
	_points.clear()
	_ages.clear()
	_fading = false
	set_process(true)
	_set_physics_process(true)

func stop_and_fade() -> void:
	if _points.is_empty():
		queue_free()
		return
	_fading = true
	_fade_elapsed = 0.0
	set_process(false)

func _physics_process(delta: float) -> void:
	if _ball == null:
		return
	_points.append(_ball.global_position)
	_ages.append(0.0)
	while _points.size() > MAX_POINTS:
		_points.remove_at(0)
		_ages.remove_at(0)
	_redraw()

func _process(delta: float) -> void:
	if not _fading:
		return
	_fade_elapsed += delta
	if _fade_elapsed >= _fade_duration:
		queue_free()
		return
	for i in _ages.size():
		_ages[i] += delta
	_redraw()

func _redraw() -> void:
	_mesh.clear_surfaces()
	if _points.size() < 2:
		return
	_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in range(1, _points.size()):
		var age := _ages[i] if i < _ages.size() else 0.0
		var alpha := clampf(1.0 - age / FADE_LIFETIME, 0.0, 1.0) * (1.0 - _fade_elapsed / _fade_duration if _fading else 1.0)
		if alpha <= 0.01:
			continue
		var color := Color(0.2, 0.9, 1.0, alpha)
		_mesh.surface_set_color(color)
		_mesh.surface_add_vertex(_points[i - 1])
		_mesh.surface_set_color(color)
		_mesh.surface_add_vertex(_points[i])
	_mesh.surface_end()
```

Note: `_physics_process` must run while the ball flies — set `process_mode = Node.PROCESS_MODE_ALWAYS` in `_ready()` so the trail keeps recording during any state pauses.

- [ ] **Step 2: Wire into ExecuteShotState**

In `scripts/state_machine/ExecuteShotState.gd::enter()`, after `ball.launch(...)`:

```gdscript
		if ball.trail_node == null:
			ball.trail_node = BallFlightTrail.new()
			ball.trail_node.name = "BallFlightTrail"
			ball.add_child(ball.trail_node)
		ball.trail_node.begin_tracking(ball)
```

Add `trail_node: BallFlightTrail` to `FreeKickBall3D.gd` (member only; no scene change needed since it's added in code).

In `_finish_shot()`, before `finished.emit(...)`:

```gdscript
	if _launched_ball != null and _launched_ball.trail_node != null:
		_launched_ball.trail_node.stop_and_fade()
```

- [ ] **Step 3: Verify**

Run: `godot --path .`
Manual: kick — a cyan line trails the ball and fades; identical kicks produce identical trails (visually); trail fades fully before reset; no errors in console.

Run: `godot --headless --script scripts/tests/ShotCalculatorSmokeTest.gd`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add scripts/ball/BallFlightTrail.gd scripts/state_machine/ExecuteShotState.gd scripts/ball/FreeKickBall3D.gd
git commit -m "feat: deterministic ball-flight trail with fade"
```

---

### Task 8: Impact highlight overlay

**Files:**
- Modify: `scripts/ui/FreeKickUI.gd`
- Modify: `scripts/state_machine/ExecuteShotState.gd`
- Modify: `scripts/state_machine/FreeKickSandbox.gd` (goal impact)

**Interfaces:**
- Consumes: existing `goal_banner` tween mechanism; `ExecuteShotState._show_outcome_banner(outcome)`; sandbox goal trigger.
- Produces: `FreeKickUI.show_impact_pulse(world_point: Vector3, camera: Camera3D, label: String, color: Color) -> void`.

- [ ] **Step 1: Add the impact pulse method**

In `scripts/ui/FreeKickUI.gd`, add a dedicated control and method (reuses the banner's expand-ring pattern but anchored to the impact point):

```gdscript
var impact_pulse: Control
var impact_pulse_progress := 0.0
var impact_pulse_alpha := 1.0
var impact_pulse_label := ""
var impact_pulse_color := Color.WHITE
var impact_pulse_screen_pos := Vector2.ZERO
var impact_pulse_tween: Tween
```

Create it in `_ready()`:

```gdscript
func _create_impact_pulse() -> Control:
	var pulse := Control.new()
	pulse.name = "ImpactPulse"
	pulse.set_anchors_preset(Control.PRESET_FULL_RECT)
	pulse.visible = false
	pulse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pulse.draw.connect(_draw_impact_pulse)
	if ui_root != null:
		ui_root.add_child(pulse)
	else:
		add_child(pulse)
	return pulse
```

```gdscript
func show_impact_pulse(world_point: Vector3, camera: Camera3D, label: String, color: Color) -> void:
	if impact_pulse == null or camera == null:
		return
	impact_pulse_screen_pos = camera.unproject_position(world_point)
	impact_pulse_label = label
	impact_pulse_color = color
	impact_pulse_progress = 0.0
	impact_pulse_alpha = 1.0
	impact_pulse.visible = true
	impact_pulse.queue_redraw()
	if impact_pulse_tween != null and impact_pulse_tween.is_valid():
		impact_pulse_tween.kill()
	impact_pulse_tween = create_tween()
	impact_pulse_tween.tween_method(func(v: float) -> void:
		impact_pulse_progress = v
		if impact_pulse != null:
			impact_pulse.queue_redraw(), 0.0, 1.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	impact_pulse_tween.tween_method(func(v: float) -> void:
		impact_pulse_alpha = v
		if impact_pulse != null:
			impact_pulse.queue_redraw(), 1.0, 0.0, 0.4)
	impact_pulse_tween.tween_callback(func() -> void:
		impact_pulse.visible = false
	)
```

```gdscript
func _draw_impact_pulse() -> void:
	if impact_pulse == null or not impact_pulse.visible:
		return
	var center := impact_pulse_screen_pos
	var radius := 14.0 + impact_pulse_progress * 90.0
	var a := impact_pulse_alpha
	impact_pulse.draw_arc(center, radius, 0.0, TAU, 48, Color(impact_pulse_color, 0.85 * a), 3.0)
	impact_pulse.draw_arc(center, radius * 0.55, 0.0, TAU, 48, Color(impact_pulse_color, 0.35 * a), 2.0)
	var font := impact_pulse.get_theme_default_font()
	impact_pulse.draw_string(font, Vector2(center.x - 60.0, center.y + radius + 22.0), impact_pulse_label, HORIZONTAL_ALIGNMENT_CENTER, 120.0, 13, Color(1.0, 1.0, 1.0, 0.95 * a))
```

- [ ] **Step 2: Fire pulses from outcomes**

In `ExecuteShotState._show_outcome_banner()`, before each `show_result_banner` call add a matching pulse. Use the ball's current position and the camera:

```gdscript
	_show_impact_for_outcome(outcome)
```

```gdscript
func _show_impact_for_outcome(outcome: StringName) -> void:
	if controller.ui == null or _launched_ball == null:
		return
	var camera := controller.camera_rig.get_camera()
	if camera == null:
		return
	var pos := _launched_ball.global_position
	match outcome:
		&"keeper_contact":
			controller.ui.show_impact_pulse(pos, camera, "SAVED", Color(1.0, 0.68, 0.22))
		&"post":
			controller.ui.show_impact_pulse(pos, camera, "POST", Color(0.0, 0.85, 1.0))
		&"crossbar":
			controller.ui.show_impact_pulse(pos, camera, "CROSSBAR", Color(0.92, 0.96, 1.0))
		&"background_contact":
			controller.ui.show_impact_pulse(pos, camera, "WIDE", Color(1.0, 0.30, 0.22))
```

- [ ] **Step 3: Fire pulse on goals from the sandbox**

In `FreeKickSandbox.gd::_on_goal_scored` (find it — it currently triggers the goal banner), add:

```gdscript
	var camera := controller.camera_rig.get_camera()
	controller.ui.show_impact_pulse(GOAL_CENTER, camera, "GOAL!", Color(0.0, 0.95, 1.0))
```

- [ ] **Step 4: Verify**

Run: `godot --path .`
Manual: every outcome (goal, save, post, crossbar, wide) shows a ring pulse + label at the impact point; goal also pulses at net center.

Run: `godot --headless --script scripts/tests/ShotCalculatorSmokeTest.gd`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/ui/FreeKickUI.gd scripts/state_machine/ExecuteShotState.gd scripts/state_machine/FreeKickSandbox.gd
git commit -m "feat: impact highlight pulse on shot outcomes"
```

---

### Task 9: Compact result card (replaces banner + dense panel)

**Files:**
- Modify: `scripts/ui/FreeKickUI.gd`

**Interfaces:**
- Consumes: `show_result_banner(text, subtitle, highlight)` (existing entry points stay — callers unchanged), `show_feedback(report, delay)` (existing entry point), `FreeKickUIScale.widget_scale` (Task 1).
- Produces: rewritten rendering of both methods into one anchored compact card; `_draw_result_card()`.

- [ ] **Step 1: Replace the banner drawing with the card**

Keep `show_result_banner()`/`show_feedback()` signatures and callers untouched. Introduce one internal state + one card control:

```gdscript
var result_card: Control
var result_card_title := ""
var result_card_cause := ""
var result_card_data := ""
var result_card_color := Color.WHITE
var result_card_alpha := 1.0
var result_card_progress := 0.0
```

Create the card in `_ready()` (anchored top-center under the score HUD):

```gdscript
func _create_result_card() -> Control:
	var card := Control.new()
	card.name = "ResultCard"
	card.visible = false
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.draw.connect(_draw_result_card)
	card.anchor_left = 0.5
	card.anchor_top = 0.0
	card.anchor_right = 0.5
	card.anchor_bottom = 0.0
	card.offset_left = -210.0
	card.offset_right = 210.0
	card.offset_top = 190.0  # below the score HUD
	card.offset_bottom = 190.0 + 130.0
	if ui_root != null:
		ui_root.add_child(card)
	else:
		add_child(card)
	return card
```

Redefine `show_result_banner` to populate the card (keep the public signature):

```gdscript
func show_result_banner(text: String = "GOAL!", subtitle: String = "", highlight: Color = Color(0.0, 0.95, 1.0)) -> void:
	_show_result_card(text, subtitle, "", highlight)
```

Redefine `show_feedback(report, delay)` to use the card; extract the cause line from the report (the UI formats only — `_format_feedback_report` stays for data lines):

```gdscript
func show_feedback(report: Resource, auto_restart_delay_seconds: float = 4.0) -> void:
	hide_all()
	_set_active_step(4)
	set_phase_progress(1.0, "")
	var cause := _result_cause_from_report(report)
	var data := _result_data_from_report(report)
	_show_result_card(report_summary(report), cause, data, Color(0.0, 0.95, 1.0))
	instruction_label.visible = true
	instruction_label.text = "Auto restart in %.0fs" % auto_restart_delay_seconds
	set_status("Auto restart")
```

Helpers (keep the existing `_format_feedback_report` internals but reuse them for the data line):

```gdscript
func report_summary(report: Resource) -> String:
	if report == null or report.get("summary") == null:
		return "SHOT COMPLETE"
	return String(report.get("summary")).to_upper()

func _result_cause_from_report(report: Resource) -> String:
	if report == null:
		return ""
	var lines: Array[String] = []
	if report.get("support_feedback") != null and String(report.get("support_feedback")) != "":
		lines.append(String(report.get("support_feedback")))
	var curl_strength := String(report.get("curl_strength"))
	if curl_strength == "low":
		lines.append("add side contact for curl")
	elif curl_strength != "":
		lines.append("curl: %s" % curl_strength)
	if report.get("coach_tip") != null and String(report.get("coach_tip")) != "":
		lines.append(String(report.get("coach_tip")))
	return " · ".join(lines)

func _result_data_from_report(report: Resource) -> String:
	if report == null:
		return ""
	var power := roundi(float(report.get("power")) * 100.0)
	var elevation := roundi(float(report.get("elevation_angle")))
	var curl := String(report.get("curl_strength"))
	return "PWR %d%%  ·  ELEV %d°  ·  CURL %s" % [power, elevation, curl]
```

Draw the card (compact, three visual tiers; color + text, never color alone):

```gdscript
func _draw_result_card() -> void:
	if result_card == null or not result_card.visible:
		return
	var scale := FreeKickUIScale.widget_scale(get_viewport().get_visible_rect().size.y)
	var font := result_card.get_theme_default_font()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.01, 0.03, 0.72 * result_card_alpha)
	style.border_color = Color(result_card_color, 0.55 * result_card_alpha)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	result_card.draw_style_box(style, Rect2(Vector2.ZERO, result_card.size))
	var title_size := roundi(34.0 * scale)
	result_card.draw_string(font, Vector2(0.0, 46.0 * scale), result_card_title, HORIZONTAL_ALIGNMENT_CENTER, result_card.size.x, title_size, Color(result_card_color, result_card_alpha))
	if result_card_cause != "":
		result_card.draw_string(font, Vector2(0.0, 78.0 * scale), result_card_cause, HORIZONTAL_ALIGNMENT_CENTER, result_card.size.x, roundi(14.0 * scale), Color(1.0, 1.0, 1.0, 0.92 * result_card_alpha))
	if result_card_data != "":
		result_card.draw_string(font, Vector2(0.0, 104.0 * scale), result_card_data, HORIZONTAL_ALIGNMENT_CENTER, result_card.size.x, roundi(11.0 * scale), Color(1.0, 1.0, 1.0, 0.5 * result_card_alpha))
```

`_show_result_card` populates state + runs the existing pop/fade tween pattern (reuse the `goal_banner_tween`-style timing: pop 0.42s, hold 1.05s, fade 0.55s):

```gdscript
func _show_result_card(title: String, cause: String, data: String, color: Color) -> void:
	if result_card == null:
		return
	result_card_title = title
	result_card_cause = cause
	result_card_data = data
	result_card_color = color
	result_card_progress = 0.0
	result_card_alpha = 1.0
	result_card.visible = true
	result_card.queue_redraw()
	if goal_banner_tween != null and goal_banner_tween.is_valid():
		goal_banner_tween.kill()
	goal_banner_tween = create_tween()
	goal_banner_tween.tween_method(_set_goal_banner_progress, 0.0, 1.0, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	goal_banner_tween.tween_interval(1.05)
	goal_banner_tween.tween_method(_set_goal_banner_alpha, 1.0, 0.0, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	goal_banner_tween.tween_callback(func() -> void:
		result_card.visible = false
	)
```

Note: `result_card.size` must be set once after creation — add `card.size = Vector2(420.0 * scale, 130.0 * scale)` in `_create_result_card()` (scale from current viewport) and update it in `_update_uiroot_margins()` when the viewport changes.

Remove the old `_draw_goal_banner()` body (the celebration ring + big title draw) — the card replaces it. Keep the `goal_banner_*` state vars but the visible render now comes from `_draw_result_card`.

- [ ] **Step 2: Verify**

Run: `godot --path .`
Manual: take a kick — after outcome, the compact card appears top-center under the HUD with outcome / cause / data tiers; auto-restart countdown still shows; banner timing feels right; card stays within safe area at 800x360 and 1920x1080.

Run: `godot --headless --script scripts/tests/ShotCalculatorSmokeTest.gd`
Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add scripts/ui/FreeKickUI.gd
git commit -m "feat: compact result card for post-shot feedback"
```

---

### Task 10: Final verification pass

**Files:**
- None (verification only; fix regressions if found)

- [ ] **Step 1: Run all headless tests**

```bash
godot --headless --script scripts/tests/ShotCalculatorSmokeTest.gd
godot --headless --script scripts/tests/FreeKickUIScaleSmokeTest.gd
godot --headless --script scripts/tests/SupportGestureRouterSmokeTest.gd
```

Expected: all PASS.

- [ ] **Step 2: Full manual pass in sandbox**

Run: `godot --path .`

Checklist:
- Desktop 1280x720: all three steps behave as before (legacy two-substep plant flow intact), new AIM button hidden during non-plant steps.
- Phone-sized window (e.g. 800x360): widgets clamp inside safe area, buttons ≥48px, power meter notched + IDEAL label, contact circle ≥140px, step-2 toggle works with a second pointer (use multi-touch device or Godot's simulated touch from mouse drag while clicking).
- Shot: camera follows ball to net, trail fades, impact pulse + label on every outcome, result card legible.
- Determinism: two identical kicks produce the same trail and same camera behavior.
- No console errors.

- [ ] **Step 3: Confirm spec coverage**

Cross-check every section of `docs/superpowers/specs/2026-08-22-mobile-ui-flight-feedback-design.md` against the implemented behavior. Any gap → fix in the smallest slice, rerun tests, commit.

- [ ] **Step 4: Final commit (if fixes were made)**

```bash
git add -A
git commit -m "fix: verification pass adjustments for mobile UI and flight feedback"
```
