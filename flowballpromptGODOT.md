You are a senior gameplay programmer and technical game designer specialized in football games, Godot 4, GDScript, and Jolt physics.

Create an implementation-ready architecture and prototype plan for a realistic free kick system for a football game in Godot 4.

This must be more than a vague design document. Produce a buildable prototype architecture with concrete scenes, scripts, Resources, signals, formulas, state flow, pseudocode, and key GDScript examples.

## Target

Design a self-contained free kick prototype that can run in a dedicated sandbox scene, while also being integration-aware for an existing football match codebase.

The system should:
- use Godot 4;
- assume Jolt physics is the physics backend;
- use `RigidBody3D` for the ball;
- use `CharacterBody3D` for players/wall/goalkeeper actors;
- use `CanvasLayer` for UI;
- use a node-based state machine architecture;
- prioritize mobile touch input, with mouse as a desktop/debug fallback;
- be physically plausible, not arcade-only and not simulation-heavy;
- reward player skill instead of random outcomes;
- use mostly deterministic calculations with small bounded stat-driven error;
- use real-world units as much as possible.

Recommended physical baseline:
- `1 Godot unit = 1 meter`;
- ball mass around `0.43 kg`;
- ball radius around `0.11 m`;
- free kick launch speed roughly `20–35 m/s`;
- spin roughly `20–80 rad/s`;
- gravity around `9.8 m/s²`.

Expose tuning multipliers and ranges instead of hardcoding magic constants.

## Presentation and Camera Flow

Use a hybrid set-piece presentation:
1. enter from normal 3D match camera;
2. Step 1 power UI appears over the match/set-piece view;
3. Step 2 switches to a dedicated top-down ball/support-foot view;
4. Step 3 uses a large ball-contact UI view;
5. after execution, switch to a shot-follow/cinematic camera;
6. after the shot resolves, show post-shot feedback/replay.

A dedicated `FreeKickCameraRig` should own camera transitions. States should request camera modes instead of manipulating cameras directly.

Example modes:
- `MATCH_VIEW`
- `POWER_VIEW`
- `SUPPORT_TOP_DOWN`
- `BALL_CONTACT_UI`
- `SHOT_FOLLOW`
- `FEEDBACK_REPLAY`

## Core Mechanic

The free kick mechanic has 3 sequential input steps.

After Step 3 finishes, the shot is automatically executed. There is no separate shoot button.

### Step 1 — Power

The player presses and holds a button or touchscreen area to charge kick power.

Rules:
- longer press means stronger shot;
- this step has no timer restriction;
- power locks on release;
- there is no sweet-spot timing mechanic for the first prototype;
- excessive power reduces precision;
- power remains visible as a compact indicator during Steps 2 and 3.

Use a saturating charge curve, for example:

```gdscript
power = 1.0 - exp(-hold_time / charge_tau)
```

Then apply an overpower penalty above an ideal threshold:

```gdscript
overpower = max(0.0, power - ideal_power_max) / (1.0 - ideal_power_max)
```

Suggested initial values:
- `charge_tau = 0.75s`
- `ideal_power_max = 0.85`

The plan should explain the tuning effect of these values.

### Step 2 — Support Foot Placement / Plant Setup

This is the main directional and body setup mechanic.

The player sees a top-down view of the ball.

Depending on whether the player selected a left-footed or right-footed kick, a lateral sector around the ball becomes active.

The player may touch anywhere inside the active sector and drag. The input should be continuously clamped and previewed inside the valid sector.

This step must be completed within a difficulty-dependent time window.

Important design correction:
- Step 2 should not be the primary elevation control.
- Elevation is primarily controlled by Step 3 ball contact and swipe.

Step 2 controls:
- horizontal shot direction / aim offset;
- initial body orientation;
- approach angle;
- plant-foot distance/depth;
- stability/precision modifier;
- natural curve tendency / curve bias;
- animation setup information.

Interpretation:
- horizontal drag controls aim offset and curve bias;
- vertical drag controls plant depth, not direct elevation;
- middle plant depth gives best baseline precision;
- farther/open plant supports finesse/curl potential;
- closer/compact plant supports driven shots but can be riskier at high power.

Recommended conceptual mapping:

```text
Step 2 drag_x → aim angle + curve bias
Step 2 drag_y → plant_depth / approach depth / stability
```

Use ball-relative input space converted into goal/world-relative shot parameters.

Touch behavior:
- touch may start anywhere inside the active sector;
- marker is clamped continuously to sector bounds;
- UI previews qualitative setup values such as aim offset, plant depth, curve tendency, and stability;
- auto-commit when the input is good enough;
- if the timer expires before completion, commit the default setup plus a penalty.

Suggested Step 2 auto-commit threshold:

```text
touch_started_inside_sector == true
distance_from_ball_center >= min_plant_radius
hold_or_drag_duration >= min_commit_time
```

Suggested defaults:
- `min_plant_radius = 35% of sector radius`
- `min_commit_time = 0.12s`

Step 2 timeout default:
- balanced plant;
- zero aim offset;
- low curve bias;
- default/timer pressure penalty based on difficulty and composure.

### Step 3 — Ball Contact and Spin

The player sees a large ball UI.

The first touch defines the impact point on the ball.
The drag trajectory defines contact motion through the ball.

Step 3 controls:
- elevation;
- contact quality;
- spin axis;
- spin rate;
- ball rotation;
- Magnus effect direction;
- curve intensity;
- shot type classification after physical parameters are calculated.

Examples:
- center contact + short straight drag + high power → knuckle/power-like shot;
- side contact + curved/upward drag → curling finesse-like shot;
- upper contact + downward drag → low driven/topspin shot;
- lower contact + upward drag → lifted shot.

Shot type should be inferred from the resulting physical parameters and used mainly as a label for animation/feedback, not as a hidden physics override.

This step has a difficulty-dependent timer.

Touch behavior:
- impact point selected by first touch;
- swipe trajectory collected as points;
- auto-commit when good enough;
- if the timer expires before completion, commit a default contact plus penalty.

Suggested Step 3 auto-commit threshold:

```text
impact_point_selected == true
swipe_distance >= min_swipe_distance
swipe_duration >= min_swipe_time
```

Suggested defaults:
- `min_swipe_distance = 8–12% of ball_ui_radius`
- `min_swipe_time = 0.08s`

Step 3 timeout default:
- center contact;
- short straight swipe;
- low spin;
- default/timer pressure penalty based on difficulty and composure.

## Left Foot vs Right Foot

The selected kicking foot should affect more than UI mirroring.

It should affect:
- active support-foot sector side;
- natural curve tendency;
- body orientation;
- weak-foot penalty if using the non-preferred foot;
- animation selection;
- contact/curve interpretation where appropriate.

Typical tendency:
- right-footed instep tends to curve right-to-left;
- left-footed instep tends to curve left-to-right.

## Difficulty Model

Difficulty should affect both the set-piece scenario and the input/guidance layer.

Separate:

```text
base_difficulty = user/game mode setting
scenario_difficulty = computed from distance, angle, wall, goalkeeper, wind, pressure
final_difficulty = base_difficulty modifies scenario_difficulty
```

Difficulty should affect:
- Step 2 timer;
- Step 3 timer;
- active sector size / forgiveness;
- auto-commit threshold forgiveness;
- input smoothing/assist;
- default-on-timeout penalty;
- composure penalty scaling;
- visual guidance detail;
- set-piece context such as distance, angle, wall size, goalkeeper quality, and wind.

Hard mode should be less forgiving, not a different mechanic.

No pre-shot trajectory preview should be shown.

Before execution, guidance may include:
- valid sector/contact zones;
- power meter;
- qualitative labels such as low/drive/curl/finesse;
- wind arrow/intensity;
- timer pressure;
- visible wall/goal context.

After execution, feedback may include:
- ghost trajectory path;
- spin trail;
- support-foot marker replay;
- ball impact/contact replay;
- coaching text;
- optional numeric/debug values.

Feedback detail should scale by difficulty:
- Easy: explicit coaching and detailed breakdown;
- Normal: concise cause summary;
- Hard: mostly visual/replay feedback and minimal text.

## Player Stats

Use a small explicit stat set.

Suggested `PlayerFreeKickStats` fields:
- `kick_power` → max speed / power efficiency;
- `free_kick_accuracy` → direction/elevation error cone;
- `curve` → spin efficiency / Magnus strength;
- `technique` → contact quality, consistency, knuckle/finesse reliability;
- `composure` → reduces timer/default/pressure penalties;
- `weak_foot` → reduces penalty when using non-dominant foot.

## Data Architecture

Use typed GDScript Resources for gameplay data.

Required Resources/classes:

### `FreeKickInputData.gd`
Stores raw player inputs separately from final shot values.

Suggested fields:
- `hold_time`
- `power_normalized`
- `selected_foot`
- `support_touch_pos`
- `support_vector`
- `plant_depth`
- `support_timer_expired`
- `impact_point`
- `swipe_points`
- `swipe_duration`
- `contact_timer_expired`
- `used_default_support`
- `used_default_contact`

### `ShotParams.gd`
Stores calculated physical shot output.

Suggested fields:
- `power`
- `launch_velocity: Vector3`
- `spin_axis: Vector3`
- `spin_rate: float`
- `elevation_angle: float`
- `horizontal_angle: float`
- `contact_point: Vector2`
- `support_vector: Vector2`
- `plant_depth: float`
- `stability: float`
- `curve_bias: float`
- `error_cone_degrees: float`
- `final_error: Vector2`
- `shot_type: StringName`

### `PlayerFreeKickStats.gd`
Designer-editable player stats.

### `FreeKickDifficulty.gd`
Designer-editable difficulty preset.

Suggested fields:
- `step2_time_limit`
- `step3_time_limit`
- `sector_size_multiplier`
- `guidance_level`
- `default_penalty_scale`
- `composure_penalty_scale`
- `input_smoothing_assist`
- `auto_commit_threshold_multiplier`

### `FreeKickEnvironment.gd`
Per-free-kick environment/context.

Suggested fields:
- `wind_vector`
- `distance_to_goal`
- `angle_to_goal`
- `wall_player_count`
- `goalkeeper_rating`
- `pressure_context`

Wind should physically affect ball flight after launch. It should not be a hidden pre-shot accuracy penalty.

## Shot Calculation

Use a mostly stateless, deterministic `ShotCalculator` service.

Example shape:

```gdscript
class_name ShotCalculator
extends RefCounted

static func calculate(
    input: FreeKickInputData,
    stats: PlayerFreeKickStats,
    environment: FreeKickEnvironment,
    difficulty: FreeKickDifficulty
) -> ShotParams:
    pass
```

During Steps 1–3, calculate only qualitative previews.
At execution, calculate authoritative `ShotParams` once from:

```text
FreeKickInputData + PlayerFreeKickStats + FreeKickEnvironment + FreeKickDifficulty
```

The final result should be reproducible from saved raw inputs, stats, environment, difficulty, and deterministic seed if needed.

Use bounded stat-driven error, not uncontrolled randomness.

Formula principle:

```text
final_result = player_input_result
             + stat_limited_error
             + environmental_physics_after_launch
```

Include formulas for:
- power to launch speed;
- support vector to horizontal aim offset;
- plant depth to stability/curve/driven modifiers;
- contact point to elevation and spin tendency;
- swipe vector/path to spin axis and spin rate;
- stats to error cone and efficiency;
- overpower penalty;
- weak-foot penalty;
- composure/default timeout penalty;
- difficulty scaling.

Use design clamps around physical values to keep output believable.

Suggested clamps:
- launch speed: `12–36 m/s`;
- elevation angle: `-3° to 35°`;
- spin rate: `0–90 rad/s`;
- horizontal angle offset: `-25° to 25°`.

For every important formula, provide:
- purpose;
- recommended default;
- acceptable tuning range;
- effect when increased/decreased.

## Ball Physics and Jolt

The ball should be a `RigidBody3D` using Jolt physics.

At launch, set velocities directly for deterministic prototype behavior:

```gdscript
ball.linear_velocity = shot_params.launch_velocity
ball.angular_velocity = shot_params.spin_axis * shot_params.spin_rate
```

Then let Jolt simulate flight, collisions, bounces, and continuous forces.

Do not warp transforms per frame.

Use a reusable `BallAerodynamics3D` component attached to the ball.

Responsibilities:
- drag;
- Magnus force;
- wind force / relative air velocity;
- spin decay.

Use `_integrate_forces(state)` for continuous forces.

Include a complete GDScript example for `BallAerodynamics3D._integrate_forces()`.

The aerodynamic component should always exist, but support configurable modes:
- `aero_enabled`
- `magnus_enabled`
- `wind_enabled`

Use real-world-ish units with exposed tuning multipliers:
- drag coefficient multiplier;
- Magnus coefficient multiplier;
- spin decay multiplier;
- wind multiplier.

For Jolt/contact stability:
- use simple stable collision shapes;
- tune bounce/friction through `PhysicsMaterial`;
- use collision layers/masks cleanly;
- enable contact monitoring where needed:

```gdscript
ball.contact_monitor = true
ball.max_contacts_reported = 8
```

After launch, temporarily ignore collision between the ball and kicker using physics exceptions:

```gdscript
ball.add_collision_exception_with(kicker)
await get_tree().create_timer(0.2).timeout
ball.remove_collision_exception_with(kicker)
```

Or restore when the ball is more than roughly `0.5m` from the kicker.

## Goalkeeper, Wall, and Outcomes

Goalkeeper and wall interaction should be external to the shot calculation.

The free kick system calculates and launches the ball.
Then:
- wall players react/block via collision/animation;
- goalkeeper AI reacts after launch;
- goal/out/miss/save/block outcomes are detected by world triggers and collision events.

Do not fake ball path inside the shot calculator to account for wall/GK.

Use event-based outcome collection:
- `goal_scored`
- `shot_out`
- `ball_blocked`
- `goalkeeper_save`
- `shot_landed`

With Jolt, prefer:
- `Area3D` triggers for goal and out-of-bounds zones;
- `RigidBody3D.body_entered` / contact monitoring for impacts;
- simple shapes and robust collision masks;
- avoid relying on exact contact-point precision for critical game logic.

## State Machine

Use a node-based state machine, not one giant enum controller.

Suggested scene shape:

```text
FreeKickController
├── FreeKickStateMachine
│   ├── PowerState
│   ├── SupportFootState
│   ├── BallContactState
│   ├── CalculateShotState
│   ├── ExecuteShotState
│   └── FeedbackState
├── HumanFreeKickInputProvider
├── FreeKickUI
├── FreeKickCameraRig
├── ShotObserver
│   ├── BallFlightRecorder
│   └── ResultEventCollector
└── ShotDebugOverlay
```

Responsibilities:
- `FreeKickController`: orchestrates dependencies and starts/ends the mode;
- `FreeKickStateMachine`: transitions between states;
- `PowerState`: collects hold/release power;
- `SupportFootState`: collects support sector input with timer/default behavior;
- `BallContactState`: collects impact/swipe input with timer/default behavior;
- `CalculateShotState`: calls `ShotCalculator`;
- `ExecuteShotState`: plays animation and launches on contact frame;
- `FeedbackState`: shows replay and breakdown.

States should communicate with signals and high-level APIs.

## UI Architecture

Use a centralized `FreeKickUI` controller.

States should call methods such as:

```gdscript
ui.show_power(power_value)
ui.show_support_foot_sector(selected_foot, difficulty)
ui.show_ball_contact_ui()
ui.show_feedback(feedback_report)
ui.hide_all()
```

Specific widgets/panels can be child nodes, but states should not deeply manipulate labels, colors, and controls.

UI should include:
- large power UI for Step 1;
- compact persistent power meter for Steps 2 and 3;
- support-foot sector widget;
- ball contact widget;
- timers;
- valid-zone feedback;
- qualitative labels;
- post-shot feedback and replay overlay;
- optional debug numeric overlay.

## Input Handling

Use state-specific input handling through a shared mapper/helper.

State-specific:
- `PowerState` handles hold/release;
- `SupportFootState` handles sector touch/drag;
- `BallContactState` handles impact/swipe.

Shared helper:

```text
FreeKickInputMapper
- screen_to_support_space()
- clamp_to_sector()
- screen_to_ball_contact_space()
- normalize_swipe()
```

Mobile touch is primary.
Mouse should work as an equivalent for desktop/editor testing.
Gamepad can be listed as a future separate UX adaptation, not required for the first prototype.

Design a minimal input provider abstraction now for future AI/gamepad support.

Example:

```text
HumanFreeKickInputProvider
- emits power_committed
- emits support_committed
- emits contact_committed
```

Future AI can generate `FreeKickInputData` directly or use an `AI_FreeKickInputProvider`.

## Animation Integration

Include basic animation selection, not full procedural biomechanics.

Flow:

```text
selected_foot + shot_type + power_band
→ choose animation
→ animation emits contact_frame
→ ball.launch(shot_params)
```

Ball launch should wait for the animation contact frame.
If no animation event exists in the prototype, use a temporary fallback delay, but design the architecture around animation-driven contact timing.

## Telemetry, Replay, and Feedback

Record lightweight ball-flight telemetry during the shot.

Use a separate `ShotObserver` / `BallFlightRecorder`, not the ball physics component.

Suggested telemetry:
- sampled positions every `0.05s`;
- sampled velocities optionally;
- peak height;
- max lateral deviation;
- wall clearance height if available;
- total flight time;
- final outcome.

`ResultEventCollector` should subscribe to goal/wall/GK/outcome events during the free kick.

`FeedbackState` should combine:

```text
FreeKickInputData
ShotParams
BallFlightTelemetry
ExternalResultEvents
→ FreeKickFeedbackReport
```

Feedback should distinguish:
- player-controlled input causes;
- environmental effects such as wind;
- wall/GK/outcome events.

## Sandbox and Testing

Include a dedicated `FreeKickSandbox.tscn` for tuning and validation.

It should use the same production state machine/UI, plus debug controls around it.

Suggested scene:

```text
FreeKickSandbox.tscn
├── TestPitch
├── Ball3D
├── Player3D
├── Goal
├── Wall
├── GoalkeeperDummy
├── FreeKickController
└── DebugPanel
```

Debug panel should allow:
- selecting player stats preset;
- selecting difficulty preset;
- setting distance, angle, wall, wind;
- starting normal free kick flow;
- injecting/replaying saved `FreeKickInputData`;
- visualizing launch vector, spin axis, ghost path, telemetry, and feedback report.

Require lightweight test/simulation validation.

Suggested `ShotCalculator` deterministic tests:
- same input and seed produce same output;
- overpower increases error cone;
- weak foot applies penalty;
- side contact increases sidespin;
- lower/upper contact changes elevation/spin;
- timer defaults apply penalties.

Suggested aerodynamic sandbox checks:
- no spin means no Magnus lateral curve;
- sidespin curves in the expected direction;
- drag reduces speed;
- wind changes trajectory consistently;
- spin decays over time.

## Output Required

Generate the following:

1. System architecture.
2. Gameplay loop.
3. Scene tree structure.
4. Node hierarchy.
5. Suggested folder structure.
6. State machine flow.
7. UI implementation plan.
8. Input handling plan.
9. Data Resource definitions.
10. Shot calculation formulas with defaults/ranges/tuning notes.
11. Ball physics model using Godot 4 + Jolt.
12. Magnus effect implementation.
13. Timers and difficulty scaling.
14. Mobile touch implementation details.
15. Recommended signals and scripts.
16. Telemetry/replay/feedback architecture.
17. Sandbox/testing plan.
18. Integration points with match controller, player stats, animation tree, wall/GK AI, and world outcome triggers.
19. Pseudocode for the full flow.
20. GDScript examples.

For GDScript, provide implementation skeletons plus key complete methods, not an enormous full production implementation.

Include complete or near-complete examples for:
- `ShotCalculator.calculate()`;
- `BallAerodynamics3D._integrate_forces()`;
- support sector input clamping;
- ball contact/swipe normalization;
- launching the ball from `ShotParams`;
- basic state transition/signals;
- recording telemetry samples.

Prefer clear, maintainable Godot code over clever abstractions.
