# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Full contributor rules (commands, gameplay design constraints, file-safety list, workflow) live in `AGENTS.md` at the repo root and are binding — read it, this file only adds architecture context that isn't obvious from a single file.

## Commands

Run from the repo root. If `godot` isn't on PATH, ask the user for the local executable (this machine has it at `/c/Users/malav/bin/godot`).

```bash
# Run the shot-math smoke test suite (the primary regression check).
godot --headless --script scripts/tests/ShotCalculatorSmokeTest.gd

# Other smoke tests under scripts/tests/ follow the same invocation pattern, e.g.:
godot --headless --script scripts/tests/SupportPlantGestureSmokeTest.gd
godot --headless --script scripts/tests/FreeKickUIScaleSmokeTest.gd
godot --headless --script scripts/tests/BallFlightSimulatorSmokeTest.gd   # offline flight vs real Jolt launch

# Historical free-kick feasibility (Collection mode, ~2 min); rewrites docs/validation/historical-feasibility.md.
godot --headless --script scripts/tools/HistoricalKickValidator.gd
godot --headless --script scripts/tools/HistoricalKickValidator.gd -- --only=<kick-id> --samples=40000

# After adding a new `class_name` script, refresh the global class cache or headless runs fail to resolve it.
godot --headless --path . --import

# Open the project in the editor / run the sandbox scene directly.
godot -e --path .
godot --path .
```

There is no build step (GDScript is interpreted) and no linter configured; the smoke tests are the correctness gate, especially for `ShotCalculator.gd`.

## Collection-mode validation

`data/historical_free_kicks.json` (loaded by `HistoricalFreeKickCatalog`) holds real free kicks as envelope ranges with cited sources. `scripts/physics/BallFlightSimulator.gd` replays a flight offline using the same `BallAerodynamics3D` force functions and Jolt's step order (damping → gravity → position → custom forces, spin clamped to Jolt's `max_angular_velocity`); keep it in parity with the runtime whenever `apply_forces` changes (the smoke test checks it). `docs/validation/phase1-findings.md` lists the confirmed gaps.

## Architecture

### Runtime loop

`scripts/state_machine/FreeKickSandbox.gd` is the scene root script for `res://scenes/sandbox/FreeKickSandbox.tscn`. It owns the *match-level* loop that sits above a single free kick: generating set pieces (distance/lateral offset/wall size scale with `set_piece_number`), positioning the wall dummies and goalkeeper, tracking goals/attempts/misses across a run, and driving the ground/grass shaders. It does not know how a single kick is scored — it just calls `controller.start_free_kick(...)` and reacts to `FreeKickController` signals (`shot_calculated`, `free_kick_finished`).

`FreeKickController` (`scripts/state_machine/FreeKickController.gd`) owns one *attempt*: input data (`FreeKickInputData`), the active `FreeKickStateMachine`, the `FreeKickUI`, the `FreeKickCameraRig`, `ShotObserver`, and `TrajectoryGhost3D`. States never talk to each other directly — they call back into the controller, which coordinates UI/camera/ball.

The state machine (`scripts/state_machine/FreeKickStateMachine.gd`) is a flat set of sibling `FreeKickState` nodes. Each state emits `finished(next_state_name: StringName)`; the machine looks up that child by node name and transitions. The fixed sequence for one attempt is:

```
PowerState → SupportFootState → BallContactState → CalculateShotState → ExecuteShotState → FeedbackState
```

- **PowerState** — Step 1, a saturating hold curve for shot power; also sets the step 2/3 time budgets via `controller.set_power_time_budget()` (more power = less time to plant/strike).
- **SupportFootState** — Step 2, unified plant-and-aim gesture (radial toe aim, tap-to-place, release-to-commit). This is the biomechanical anchor (stability/orientation/aim lane/curve bias), not the primary elevation control.
- **BallContactState** — Step 3, the ball-contact swipe/trace that drives elevation, spin, and curl intent (see `scripts/calculation/ContactGesture.gd` for trace classification: lace/puntera/instep-rosca/outstep-trivela/topspin).
- **CalculateShotState → ExecuteShotState → FeedbackState** — call `ShotCalculator.calculate()`, launch the ball, then build/display the post-shot report. There is no separate "shoot" button; execution is automatic once step 3 completes or times out.

`ShotCalculator` (`scripts/calculation/ShotCalculator.gd`) is a static/deterministic function of `(FreeKickInputData, PlayerFreeKickStats, FreeKickEnvironment, FreeKickDifficulty) -> ShotParams`. Same input must always produce the same output (see the smoke test's first case) — any variance (wind, wall jump timing) must live in `FreeKickSandbox`/environment setup, not inside the calculator.

Camera transitions are centralized in `FreeKickCameraRig` (`scripts/camera/FreeKickCameraRig.gd`) via `set_mode(&"MODE_NAME")`; states/controller request a mode (`MATCH_VIEW`, `POWER_VIEW`, `SUPPORT_TOP_DOWN`, `BALL_CONTACT_UI`, `SHOT_FOLLOW`, `FEEDBACK_REPLAY`) rather than manipulating the `Camera3D` directly.

Ball behavior is split: `FreeKickBall3D` (`scripts/ball/FreeKickBall3D.gd`) owns reset/launch/rest lifecycle; `BallAerodynamics3D` (`scripts/physics/BallAerodynamics3D.gd`) owns in-flight drag/Magnus-effect force tuning.

### UI layer

`FreeKickUI.gd` and the panel scripts under `scripts/ui/` (`PowerMeterPanel`, `SupportPlantPanel`, `BallContactPanel`) render player intent per step and read shared visual constants from `HudTheme.gd` (single source of truth for the HUD color palette/styleboxes — a broadcast/editorial navy+cyan+yellow+orange language, see its header comment). UI scripts only preview intent; the actual shot-outcome math stays in `scripts/calculation`/`scripts/resources`.

### Presentation/event-bus layer (in progress)

`scripts/core/FlowballEventBus.gd` is a new autoload (registered in `project.godot`) meant to decouple gameplay from presentation — a scoreboard, camera, or VFX layer should listen to its signals (`phase_changed`, `power_updated`, `shot_result`, `stats_updated`, etc.) instead of reaching into `FreeKickController` directly. `scripts/stadium/stadium_scoreboard.gd` (a 3D in-world scoreboard, instanced in the sandbox scene as `StadiumScoreboard`) already subscribes to it. **As of this writing nothing on the gameplay side emits these signals yet** — `FreeKickController`/the state machine don't call `FlowballEventBus.xxx.emit(...)` — so the scoreboard currently never updates past its `_ready()` defaults. `scripts/camera/BroadcastTransition.gd` (wipe/cut transition overlay) is similarly built but not yet instanced or invoked by the camera rig or state machine. Treat these as an unfinished feature slice, not a working reference implementation, until the emit side is wired.

### Design references

`SDD.md` has the full data-flow/formula-level design doc (power curve, stat normalization, error cone, launch velocity, shot classification math) — read it before changing `ShotCalculator.gd`. `flowballpromptGODOT.md` is the original design brief; `piedeapoyo.md` (Spanish) has the biomechanical rationale for support-foot placement — preserve it as source material, don't translate it.
