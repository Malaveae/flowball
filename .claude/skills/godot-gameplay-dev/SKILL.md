---
name: godot-gameplay-dev
description: Recipes for extending Flowball's free-kick state machine, ShotCalculator math, and camera/UI wiring in Godot 4.7, plus the smoke-test verification loop. Use when adding or changing gameplay states, shot math, or camera modes in this repo.
---

# Godot gameplay dev loop (Flowball)

Full architecture is in `CLAUDE.md` and `SDD.md` — this skill is the *procedure*, not the description.

## Before touching anything

1. Read the relevant script(s) end to end — don't pattern-match from memory, this codebase iterates fast (check `git log --oneline -10` if unsure what's current).
2. State the current behavior and the proposed change in one or two sentences before editing (AGENTS.md workflow rule).

## Adding a new FreeKickState

1. Create `scripts/state_machine/<Name>State.gd` extending `FreeKickState` (`class_name <Name>State extends FreeKickState`).
2. Implement `enter(controller)` (call `super.enter(controller)` first) and `_process`/`_input` as needed; call `finished.emit(&"<NextState>")` when done — never call another state or the camera rig directly, only the controller.
3. Add it as a sibling node under the same parent as the other states in the scene the controller lives in (`FreeKickController`'s child `FreeKickStateMachine`), named to exactly match the StringName used in `finished.emit(...)` and in whichever state transitions *into* it.
4. If it needs a camera mode, request one via `controller.camera_rig.set_mode(&"MODE_NAME")` — add the mode to `FreeKickCameraRig.gd`'s `_apply_mode` if it doesn't exist yet, don't manipulate `Camera3D` from the state.
5. Update `docs`/SDD's state diagram section only if asked; don't let doc drift block the code change.

## Changing shot math (`ShotCalculator.gd`)

1. `ShotCalculator.calculate()` must stay a pure function of its four inputs — no `randf()`, no reading global/autoload state. If you need randomness, it must be seeded from something already in `FreeKickInputData`/`FreeKickEnvironment` so replays are reproducible.
2. Add or update a case in `scripts/tests/ShotCalculatorSmokeTest.gd` for the new behavior *before* declaring the change done — follow the existing `PASS:`/assertion style in that file.
3. Run the full suite and confirm nothing else regressed:
   ```bash
   godot --headless --script scripts/tests/ShotCalculatorSmokeTest.gd
   ```
   All lines must read `PASS:` — a `FAIL:`/error means stop and fix before moving on.
4. Re-check the "same input → same output" case specifically; it's the first test in the file and the one most likely to silently break from an incautious `randf()`/`randi()` addition.

## Other smoke tests

Same invocation pattern, run when touching their area:
```bash
godot --headless --script scripts/tests/SupportPlantGestureSmokeTest.gd   # step-2 plant/aim gesture
godot --headless --script scripts/tests/FreeKickUIScaleSmokeTest.gd       # HUD scaling across viewports
godot --headless --script scripts/tests/FreeKickUIStatsSmokeTest.gd       # scoreboard/stats HUD
```

## UI/HUD changes

- Visual constants (colors, radii, styleboxes) come from `scripts/ui/HudTheme.gd` — add a constant there rather than inlining a `Color(...)` in a panel script.
- UI scripts only preview player intent; if you find yourself computing an outcome (curve, elevation, power zone) inside a `scripts/ui/*.gd` file, that logic belongs in `scripts/calculation/` or `scripts/resources/` instead — move it.
- Since this repo can't run a Godot UI in a headless CI check, verify visually: `godot --path .` (or `-e` to poke at it in the editor) and exercise the actual step you changed before reporting done, per AGENTS.md.

## FlowballEventBus (presentation layer — currently half-wired)

If a task involves the stadium scoreboard, broadcast transitions, or anything under `scripts/stadium/` / `scripts/camera/BroadcastTransition.gd`: check whether `FreeKickController`/the state machine actually emits the `FlowballEventBus` signal that feature listens for. As of the last audit, nothing on the gameplay side emits them — the bus and its listeners exist, the publish side doesn't. Don't assume it's wired without grepping for `FlowballEventBus.<signal>.emit(` first.

## Reporting back

After edits: list changed files, the exact test command(s) run and their result, and anything you couldn't verify (e.g. "visual check not performed, no display available") — don't claim a gameplay/visual change works without having run or explicitly flagged why you couldn't.
