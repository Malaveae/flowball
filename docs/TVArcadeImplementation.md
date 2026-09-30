# TV Arcade gameplay and persistent results

The sandbox now uses the approved compact FLOWBALL HUD, separate phase clock,
four frozen feedback cards, explicit result actions, and a Blender-generated
visual kit. Gameplay remains in the existing state machine; shot formulas and
collision dimensions are unchanged.

## Run and review

Open the normal main scene in Godot 4.7.2. The project uses the Mobile renderer.
Drag to choose the run-up, tap to stop power, place/aim the support foot, and
swipe the ball. Feedback waits for a button press. **R** performs the primary
result action and has no effect during an active shot or while the selector is open.

| Result | Available actions |
|---|---|
| Miss 1 or 2 | Reintentar, Elegir tiro |
| Miss 3 | Restart, Elegir tiro |
| Goal | Siguiente, Repetir tiro, Elegir tiro |
| Goal on final available scenario | Repetir tiro, Elegir tiro |

Restart clears local misses and grants three new attempts on the same scenario.
It preserves the kicking foot, ball position, wall, wind, accumulated statistics,
and unlocks. Each attempt closes once at the FeedbackState boundary; goal
detection records the goal without independently incrementing statistics.

The selector exposes **60 existing procedural sandbox scenarios**, using stable
`sandbox:001` through `sandbox:060` IDs. This is a bounded sandbox catalog for
the first playable slice, not the future 10-shot tutorial or 110 historical
challenges. Those collections must have their own namespaces and authored data.
A replay adds an attempt to statistics but does not duplicate completion/unlocks.

Progress is saved to `user://flowball_progress.cfg` after results and selection.
The save holds unlocks, completion, selection, goals, and attempts. Local miss
budgets restart when opening a new session. Tests use separate files under
`build/` and never modify the player's save.

## Editable art

| Resource | Location and editing boundary |
|---|---|
| Wordmark | `assets/ui/tv_arcade/flowball.svg`; custom angular outlines, no system font dependency |
| UI fonts | `assets/ui/tv_arcade/fonts/`; Barlow Condensed SemiBold and ExtraBoldItalic, OFL included |
| Blender sources | `art/blender/tv_arcade/`; seven `.blend` files, excluded from Godot automatic import |
| Runtime models | `assets/models/tv_arcade/`; ball, boot, goalkeeper, wall player, goal/net, stadium, spectator GLBs |
| External materials | `assets/materials/tv_arcade/`; editable ShaderMaterial resources preserved across GLB reimports |
| Cel shading | `assets/shaders/tv_arcade_cel.gdshader`; three light bands, selective outlines, subtle turf detail |
| Scene integration | `scripts/stadium/TVArcadeArt.gd`; visual replacement and lighting, existing physics retained |

Regenerate the kit with:

```powershell
& 'C:/Program Files/Blender Foundation/Blender 4.4/blender.exe' --background --python tools/blender/build_tv_arcade.py
```

This overwrites generated GLBs and Blender sources. Preserve hand edits before
regenerating. `-- --ball-only` and `-- --actors-only` rebuild limited subsets.
The boot HUD image is an orthographic render of the same boot model.
Blender units are meters; exported ball radius is 0.11 m and the goal opening
is 7.32 by 2.44 m. Goalkeeper bone and clip names match the existing controller.
Runtime inspection confirmed `gk_ready` plays with 12 animation tracks.

The model materials use flat colors in Blender. The final cel shader is assigned
in Godot from external `.tres` files; arbitrary Blender shader nodes are not used
as the runtime shader. Material colors in those resources are sRGB values.

The palette order in BALL is blue, orange, green, purple. The upper HUD contains
the shot number, wordmark with percentage and goals/attempts below it, and three
miss indicators. The vertical power meter retains LOW/CONTROL/IDEAL/RISK zones.
Plant and contact use a separate 270-degree clock with one decimal place and an
orange final quarter. Decorative controls do not intercept gameplay input.

## Verification recorded on 2026-09-30

Run each test with `godot --headless --path . --script scripts/tests/<name>.gd`.

| Test | Result |
|---|---|
| ArcadeProgressSmokeTest | PASS: accounting, replay, unlock bounds, save/reload |
| ArcadeFlowSmokeTest | PASS: three failures, persistent feedback, contextual restart, preserved scenario, manual goal advance, selector, timed phase transitions, final scenario |
| FreeKickUIStatsSmokeTest | PASS |
| FreeKickUIScaleSmokeTest | PASS |
| SupportPlantGestureSmokeTest | PASS |
| BallFlightSimulatorSmokeTest | PASS, including deterministic flight and Jolt parity |
| ShotCalculatorSmokeTest | 57 PASS, 1 FAIL: pre-existing knuckle drift calibration |

The calculation failure measures RMS 0.65 m / maximum 2.20 m against expected
0.30–0.55 m / maximum 1.60 m. `scripts/calculation`, `scripts/physics`, and this
test have no changes from the versioned baseline. The visual work does not
change that calibration or weaken its assertion.

Capture the actual running scene with:

```powershell
godot --path . --rendering-method mobile --resolution 1280x720 --script scripts/tests/ArcadeVisualCapture.gd
```

This harness stages deterministic input snapshots in the real scene. Its output
is in `build/tv_arcade_captures/`: five gameplay views, feedback, Restart,
selector, left-foot views, wide/tablet layouts, and a wall scenario. Reviewed
resolutions: 1280×720, 1560×720, 1024×768. Both kicking sides were inspected.
The desktop run used Vulkan Mobile on a GTX 1070; an instantaneous sample was
73 FPS / 393 draw calls. This is not a sustained benchmark or an iPhone result.

Real iPhone touch accuracy, thermal behavior, battery cost, and sustained 60 FPS
remain device validation tasks. No iOS package or distribution configuration
is included. The original local files remain; superseded visual nodes are hidden
and their unnecessary processing/viewports disabled by the adapter.

## Review and rollback units

| Unit | Review first | Independent rollback boundary |
|---|---|---|
| HUD and feedback presentation | FreeKickUI, ArcadeScoreHud, ArcadeClock, HudTheme, timer calls | Reverse the UI/theme/timer-interface changes together; retain result action behavior |
| Manual result flow and progression | FreeKickProgress, FeedbackState, sandbox/controller action routing, new smoke tests | Reverse lifecycle and progress changes together; preserve visual kit and unrelated local work |
| Art kit | Blender builder, `.blend`, GLBs, material and shader resources | Remove only this kit and its integration; do not reset other local assets |
| Visual integration | TVArcadeArt, goalkeeper scene resource, boot reference, renderer/environment edits | Restore the previous visual wiring without changing collision or shot calculation code |

Do not use a blanket checkout/reset for rollback: the workspace contained
unapproved local work before this implementation. This delivery is included in v2.0.0.
