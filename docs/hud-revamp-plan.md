# Flowball HUD Revamp Plan

| | |
|---|---|
| **Goal** | Bring every in-game HUD surface to the sci-fi mockup look: one shared visual system, phase-consistent overlays, live feedback, mobile-safe scaling. |
| **Mockup source** | `assets/Inputs RAW/REvamp/` — `Sci-Fi Soccer HUD Edits.png` (primary, orange palette), `Cleaned Power Meter HUD.png` (power meter structure), `Soccer Power Meter HUD Interface.png`, `Sci-Fi Soccer Stage HUD Edit.png` |
| **Palette decision** | **Orange accents for CONVERSION / MISSES / phase labels** (mockup variant "HUD Edits"). Cyan stays the frame/border color. Green is reserved for success semantics (legal plant side, curl meter), red for risk. |
| **Scope** | HUD controls only (scoreboard, phase stepper, wind, dist/angle, power meter, plant overlay, contact overlay, result card, instruction hierarchy). Scene/stadium revamp is tracked in `docs/revamp-plan.md`. |
| **Engine** | Godot 4.7 (Forward+), custom `_draw()` controls (no atlas textures required) |

---

## 0. Current state inventory

| Surface | File | Notes |
|---|---|---|
| Scoreboard (SET PIECE / CONVERSION / MISSES + glass frame) | `FreeKickUI.gd` (`ModernScoreHud`) | Custom drawn, pulse glow, dividers |
| Phase stepper | `ModernScoreHud._draw_phase_bar` | 3 segments in one bar + labels + countdown text |
| Wind | `FreeKickUI.gd` (`WindHud`) | bottom-left, fixed 156x78 px |
| Dist + Angle | `FreeKickUI.gd` (`DistAngleHud`) | bottom-right, fixed 148x68 px |
| Power meter | `PowerMeterPanel.gd` | Vertical zones (LOW/CONTROL/IDEAL/RISK), boot texture, % pill, notches |
| Plant overlay | `FreeKickUI.gd` (`SupportZoneOverlay` + `SupportMarkerHint`) | World-anchored on the ball |
| Plant panel (legacy) | `SupportPlantPanel.gd` | **Dead code** — never shown, replaced by overlay |
| Contact overlay | `BallContactPanel.gd` | Screen-aligned circle over the 3D ball, swipe trace, curl meter |
| Result card | `FreeKickUI.gd` (`_create_result_card`) | Title/cause/data, animated in/out |
| Instruction / status / feedback labels | `FreeKickUI.gd` | 3 separate labels + phase bar text = 5 text surfaces saying overlapping things |
| Goal banner | `FreeKickUI.gd` (`_draw_goal_banner`) | **Dead** — body is `pass`, replaced by result card |
| Scaling | `FreeKickUIScale` | Applies to score HUD + result card only. **WindHud/DistAngleHud do not scale.** |

---

## Phase A — Shared HUD theme system

Foundation: one place owns the visual language; every later phase consumes it.

- [ ] Create `scripts/ui/HudTheme.gd` (static consts/helpers): palette (cyan frame, orange accents, semantic green/red), corner radii, border alphas, scrim style, glass stylebox factory, label color helpers.
- [ ] Refactor `ModernScoreHud`, `WindHud`, `DistAngleHud`, result card, `PowerMeterPanel`, `BallContactPanel` to consume `HudTheme` (delete per-file StyleBoxFlat duplication).
- [ ] Apply `FreeKickUIScale.widget_scale()` to `WindHud` and `DistAngleHud` (they currently use fixed px — blind spot on phones).
- [ ] Add optional dark scrim/shadow behind translucent panels so text stays legible over bright pitch/floodlights.
- [ ] Phase stepper restyle: 3 separate segmented boxes under the `[1] POWER` labels, matching the mockup, with fill + active glow + countdown inside the active box.

**Acceptance:** palette change requires editing only `HudTheme.gd`; screenshot at 1280x720 and 2560x1440 matches mockup layout; panels stay proportional at 640x360 (phone landscape).

## Phase B — Power meter fidelity

- [ ] Numeric scale labels 0 / 25 / 50 / 75 / 100 next to the bar (mockup).
- [ ] % value pill anchored to the pointer on the bar (mockup), replacing the boot-attached pill.
- [ ] Zone bands re-colored via `HudTheme` (LOW cyan, CONTROL green, IDEAL yellow, RISK red) + keep shape notches (accessibility: never color alone).
- [ ] Position decision: meter anchored screen-left (mockup) vs follow-the-ball (current). Default: follow-the-ball clamped to the safe band, mockup-style sizing.
- [ ] Boot texture keeps traveling the bar (identity element), scaled via `HudTheme`.

**Acceptance:** power readout readable at 720p and 360p heights; ideal window (70-85%) visually identical to mockup proportions.

## Phase C — Plant & Contact coherence

- [ ] Delete `SupportPlantPanel.gd` dead path or repurpose as the guided-mode panel (see Phase D guidance level); remove references from `FreeKickUI`.
- [ ] Remove dead `_draw_goal_banner` / `goal_banner_*` state; result card is the only outcome surface.
- [ ] Plant overlay: legal/illegal side encoded with **shape + color** (hatched illegal zone) for color-blind safety; aim fan shows the current `support_angle_scale` live (already partially done).
- [ ] Contact overlay: curl strength meter restyled via `HudTheme`; contact point marker and follow-through arrow get shape-differentiated styles.
- [ ] Text hierarchy: panel headers adopt the instruction split — one primary instruction (what to do now) + one consequence line (what it affects). Status label becomes the only persistent echo line.

**Acceptance:** no dead UI code paths (`grep` finds no orphan draw methods); plant/contact overlays share `HudTheme` styling; color-blind simulation (deuteranopia filter) still communicates legal side and contact zones.

## Phase D — Live feedback & guidance level

- [ ] MISSES circles pulse when a miss registers; CONVERSION updates immediately after each attempt (already driven by `set_stats` — verify timing at outcome, not only at restart).
- [ ] Wire `FreeKickDifficulty.guidance_level` (0-3) to HUD verbosity: 0 = score HUD + countdown only; 3 = full helper text everywhere. `hide_all()` respects the level.
- [ ] Game over and auto-restart adopt the result-card visual language.
- [ ] Impact pulse + outcome banner reviewed for consistency with new palette.

**Acceptance:** guidance level 0 hides all helper text without breaking usability; changing difficulty resource changes HUD verbosity without code edits.

---

## Deferred (explicit non-goals this iteration)

- Screenshot/visual regression test harness (needs a tool choice — Godot headless capture vs CI diff; revisit after Phase A).
- Localization of HUD strings (all hardcoded English; defer until product language decision).
- Atlas/texture panel art (`hud_panel_frame.png` in the Hedra asset list) — custom `_draw` stays unless perf or fidelity demands it.
- Perf tuning of per-frame `queue_redraw` (revisit only if web export profiling shows a problem).

## Risks

| Risk | Mitigation |
|---|---|
| Refactor touching 6 UI files at once → regressions | Phase A is pure restyling; run the game after each control refactor; keep `_draw` behavior identical where possible |
| `widget_scale` on new panels shifting layout on wide screens | Reuse the `_place_anchored` helper already in `FreeKickUI` instead of ad-hoc anchors |
| Removing `SupportPlantPanel` breaks saved scenes | It is only referenced from `FreeKickUI.gd`; remove references in the same commit |
