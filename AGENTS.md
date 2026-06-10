# Flowball Agent Instructions

Flowball is a Godot 4.6 free-kick prototype. Treat this repo as a gameplay sandbox first: keep changes small, deterministic, and easy to verify in the dedicated free-kick scene.

## Project Snapshot

| Area | Current convention |
| --- | --- |
| Engine | Godot 4.6 project (`project.godot`) |
| Physics | 3D physics uses Jolt (`3d/physics_engine="Jolt Physics"`) |
| Main scene | `res://scenes/sandbox/FreeKickSandbox.tscn` |
| Core gameplay | `scripts/state_machine`, `scripts/calculation`, `scripts/ball`, `scripts/physics` |
| UI | `scripts/ui` with a CanvasLayer-driven free-kick flow |
| Resources/data | `scripts/resources` |
| Tests | GDScript smoke tests under `scripts/tests` |
| Design notes | `flowballpromptGODOT.md`, `piedeapoyo.md` |

## Commands

Run these from the repo root unless noted otherwise.

```bash
# Run the current smoke-test suite.
godot --headless --script scripts/tests/ShotCalculatorSmokeTest.gd

# Open the project in the Godot editor.
godot -e --path .

# Run the main sandbox scene.
godot --path .
```

If `godot` is not on PATH, ask the user for the local Godot executable path instead of guessing.

## Architecture Rules

- Keep the free-kick flow state-machine based. Add or change states under `scripts/state_machine` rather than burying flow control in UI or physics scripts.
- `FreeKickController` owns attempt lifecycle, input data, shot calculation, UI/camera coordination, and reset behavior.
- `FreeKickStateMachine` handles state transitions. States emit their next state instead of directly sequencing unrelated systems.
- `ShotCalculator` should remain deterministic for identical inputs. Any randomness must be bounded, explicit, and replay-friendly.
- `FreeKickBall3D` owns ball reset/launch/rest behavior. Aerodynamic force tuning belongs in `BallAerodynamics3D`.
- Camera changes should go through `FreeKickCameraRig`; gameplay states should request modes, not manipulate cameras directly.
- UI scripts should collect and preview player intent; shot outcome formulas belong in calculation/resource scripts.

## Gameplay Design Constraints

- Prototype target: realistic-but-readable football free kicks, not full simulation and not pure arcade.
- Prefer real-world-ish units: `1 Godot unit = 1 meter`, ball radius around `0.11 m`, ball mass around `0.43 kg`, free-kick launch speeds roughly `20-35 m/s`.
- Reward player skill over random outcome. Stats may shape error, but input quality must stay legible.
- Step 1 power uses a saturating hold curve. Excessive power should reduce precision.
- Step 2 support-foot placement is the biomechanical anchor: stability, body orientation, aim lane, and curve bias. It should not be the primary elevation control.
- Step 3 ball contact/swipe controls elevation, spin, and curl intent.
- Support-foot side is physical: right-footed kicks plant the support foot on the ball's left side; left-footed kicks mirror this.

## Testing and Verification

Before reporting gameplay/math changes as done:

1. Run the smoke test command when Godot CLI is available.
2. If tests cannot run, explain exactly why and provide manual verification steps.
3. For shot math changes, add or update focused cases in `scripts/tests/ShotCalculatorSmokeTest.gd`.
4. Verify that identical input produces identical shot output unless an explicit seeded-random design was approved.

## File Safety

Ask before changing:

- `project.godot` engine/project settings;
- imported asset files or `.import` metadata;
- `.godot/` generated state;
- broad scene rewrites that Godot may reorder heavily;
- exported build settings or platform configuration.

Do not edit generated `.uid` files manually unless the user explicitly asks and the reason is clear.

## Development Workflow for Agents

For non-trivial work:

1. Inspect the relevant scene/script/resource flow first.
2. Summarize the current behavior and proposed change before editing.
3. Keep implementation slices reviewable; avoid mixing gameplay math, UI redesign, assets, and scene restructuring in one change.
4. Prefer focused tests for calculation/input-mapping changes.
5. After edits, report changed files, verification evidence, and remaining risks.

## Style Notes

- Use typed GDScript where practical, matching the existing style.
- Prefer `class_name` resources and scripts when they represent reusable concepts.
- Keep tuning constants named and documented instead of scattering magic numbers.
- Comments should explain gameplay/physics intent, not restate syntax.
- Artifact text and code comments should be in English unless the user asks otherwise; preserve Spanish design notes as source material.
