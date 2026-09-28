# Flowball — Game Mechanics Summary

*For principal-design review. Written from the current codebase (not from `SDD.md`, which
predates the run-up step and several other systems below and is now out of date in places —
flagged inline where relevant). Prototype status: single free-kick minigame, no full match
context yet.*

---

## 1. What the game is, right now

A single-player free-kick minigame. Each attempt is a four-step input sequence (run-up →
power → plant → contact) that feeds a deterministic physics/shot-math model, resolved into
a real 3D ball flight the player watches play out, then a short feedback recap before the
next attempt. Attempts are strung into escalating "set pieces" with a miss limit — the
closest thing to a session-level goal right now.

There is no full match simulation, no possession/fouls, no sound, and no online/local
multiplayer. This is a mechanics-and-feel prototype for the kicking interaction itself.

---

## 2. The core loop

```
Set piece spawns (distance/wall/angle escalate)
        │
        ▼
  Run-up  →  Power  →  Plant  →  Contact  →  [calculate]  →  Flight  →  Feedback recap
   (Step 1)  (Step 2)  (Step 3)  (Step 4)                                     │
        ▲                                                                    │
        └──────────────── auto-restart after 4s (or on goal) ────────────────┘
```

Miss 3 attempts on one set piece → game over (press restart to run it back). Score a goal →
immediately advance to a harder set piece. There are currently **50+ escalating set pieces**
before the loop starts biasing toward tight penalty-box angles — this is a soft ceiling, not
a designed "campaign end."

Each attempt's shot math is **fully deterministic** — same inputs always produce the same
`ShotParams`, including the "error" that represents human imperfection (it's a fixed
trigonometric function of the input values, not `randf()`). The only non-deterministic
elements per attempt are external context: wind (randomized every attempt, 0.5–7 m/s from a
random direction), the defensive wall's jump timing, and the goalkeeper's dive.

---

## 3. The four-step kick sequence

Each step hands off to the next via a state machine; nothing is skippable, but steps 2 and 3
(plant, contact) are **timed** and silently resolve to a weaker default if the player doesn't
act in time — steps 1 and 4 (run-up, and committing the final shot) are effectively
untimed/instant. This asymmetry (some steps punish hesitation, one doesn't) is worth a
design pass — see §8.

### Step 1 — Run-up (angle + distance)

**Player action:** press-drag-release near the ball, before anything else. This is **opt-in**
— a plain tap (no real drag) skips the mechanic entirely with no penalty and no bonus, as if
it didn't exist.

**What it captures:**
- **Approach angle** (0–90°): dragging into a "lateral" direction (parallel to the goal line)
  vs. a "straight-on" approach (perpendicular). This is grounded in real kicking-biomechanics
  literature (cited in code comments) on how run-up angle trades power for hip-rotation room.
  It **never steers the shot** — purely a technique trade-off:
  - Lateral (0°) → full curl/spin ceiling later, but capped straight-line pace and a
    softer power-hold curve (slower to build, wider forgiving window once it does).
  - Straight-on (90°) → full top speed and a faster/more forgiving power charge, but the
    Step 4 curl gesture's effect is capped at half strength no matter how well it's executed.
- **Approach distance** (0–15m): a literal run-up length. Longer = a small launch-speed bonus
  (up to +18% at max, tunable) but a **harsher power-hold timing window** in Step 2 (the
  "sweet spot" narrows, so a long run-up rewards precise timing and punishes sloppy timing
  more than a short one does).
- **Which foot** is locked in by which side of the ball the player's first press lands on —
  physical, not a menu toggle.

**Camera:** the near-ground "power view" camera pulls back live as the drag distance grows
(capped at +3.5m beyond the base framing), so a longer run-up is visibly a longer run-up.

### Step 2 — Power (hold-to-charge)

**Player action:** press and hold, release to lock in power. A saturating charge curve
(`1 - e^(-t/τ)`), not linear — a well-timed release matters more than raw hold duration.

**What shapes the curve:**
- `kick_power` stat shifts how fast the "ideal" zone arrives (a power player reaches it
  sooner).
- `accuracy + technique + composure` (averaged) shape how *wide/forgiving* that ideal zone
  is.
- Step 1's run-up angle and distance further reshape the curve on top of stats (see §3,
  Step 1).

**Power zones surfaced to the player** (color-coded meter): LOW (0–40%) → CONTROL (40–70%)
→ IDEAL (70–85%) → RISK (85–100%). Going past 85% ("overpowering") doesn't just risk a wild
shot — it actively **shrinks the time budget** for steps 2 and 3 afterward (narrower plant
and contact windows) and **dampens curl** on the eventual strike, so it's a real, felt
trade-off, not just a bigger error cone.

**Camera:** frozen at wherever the run-up left it throughout the entire hold (no live
movement while charging), then a one-shot "swoop" into the top-down Plant camera on release
— **swoop speed scales with the power reached** (harder strike = snappier cut; soft strike =
a more graceful move).

### Step 3 — Plant (support-foot placement)

**Player action:** tap to plant the non-kicking foot beside the ball (constrained to the
anatomically correct side — a right-footed kick must plant to the ball's left), then drag to
set the foot's aim angle before releasing (or just release immediately for a neutral 0°
aim). Auto-commits early if the placement is clearly decisive; otherwise a 1.5s timer forces
a default.

**Why it matters (the biomechanical anchor):** this step doesn't aim the shot by itself —
placement quality gates how much aim range and stability the later contact gesture can use.
Distance bands (from `piedeapoyo.md`, real free-kick technique reference):

| Lateral distance from ball | Read as |
|---|---|
| 0–15cm | Too close — foot crowds the ball, penalized |
| 20–35cm | **Optimal** — full aim lane, full stability |
| 40–55cm | Risky — aim lane and stability start narrowing |
| \>55cm | Overextended — heavily penalized |

The foot-angle drag (±30° visually) sets the actual aim lane (left post / center / right
post) within whatever range the plant distance allows, and a moderately open angle (10–25°)
gives a small extra curl assist; fully closed or extreme angles are penalized.

**Live 3D feedback added this cycle:** the post-shot recap for this step now states the
literal plant distance in cm alongside the aim angle, not just a word-bucket ("risky anchor"
etc.) — the number was previously missing.

### Step 4 — Contact (the actual strike)

**Player action:** tap a point on the ball, then drag a short follow-through trace, release
to commit. Untimed within a ~2.8s window; the trace length available shrinks the harder Step
2's power was charged (over-powering leaves less room to sweep a curl trace, nudging the
result toward a straight/knuckle strike).

**This is where technique is read from raw gesture shape**, classified deterministically
into one of eight signatures:

| Technique | Gesture shape | Feel |
|---|---|---|
| Puntera (toe-poke) | Tap, no real drag | Chipped, unpredictable, low power, extra dispersion |
| Empeine (lace) | Short straight trace | Clean, moderate power |
| Empeine largo (long lace) | Long straight trace | Power + stability, knuckle-candidate if centered |
| Rosca (instep curl) | Inward-curving trace | Strongest curl on the kicker's natural side |
| Trivela (outstep curl) | Outward-curving trace | Curl the "wrong" way — a specialist move |
| Topspin | Ascending sweep | Ball dips late — good for going over a wall |
| Backspin | Descending sweep | Ball floats/holds up |
| "Dirty" contact | Ambiguous/low-confidence trace | Catch-all — extra random-feeling dispersion, not a technique reward |

Where on the ball is struck (center vs. off-center, high vs. low) independently sets
elevation and contributes to spin axis; the trace direction/length independently sets spin
rate and confirms/adjusts the technique read. A gesture's **quality** (0–1, from path
cleanliness + speed consistency + whether the start point matches what that technique
expects) directly scales how much of its effect actually lands, and low quality adds
targeting dispersion on top of the stat-driven error cone — composure stat partially buys
that back.

---

## 4. From inputs to a shot: the resolution model

`ShotCalculator.calculate()` is a **pure, stateless, deterministic function** of (player
inputs, player stats, environment, difficulty) → launch parameters. No RNG anywhere in shot
math — replay-safe by construction. Concretely, it composes (all steps stack, not
mutually exclusive):

1. **Stability** — a 0.35–1.0 score blending plant depth, plant quality, and foot-angle
   quality. Feeds directly into how tight the error cone is.
2. **Aim** — support foot's aim-lane target, scaled down if the plant distance wasn't in the
   optimal band, plus a small curl-side bias from an open foot angle.
3. **Elevation** — from contact height + how much the follow-through swept upward (10° base,
   ±16° from contact point, ±9° from swipe direction, clamped to a realistic −3°…35° window).
4. **Spin axis & rate** — from contact offset + swipe vector, scaled by the `curve` stat and
   `technique` stat, then further shaped/capped by the Step 4 technique classification and
   its quality score, then capped again by the Step 1 run-up angle's curl ceiling, then
   damped by power-pressure if overpowered.
5. **Error cone** — driven by `accuracy`/`technique`/`stability`, worsened by overpowering,
   wrong-foot use, and any step a player let time out on; widened further by low Step-4
   gesture quality. The actual error vector is a deterministic trig function of the raw
   input values (not random) — same inputs, same "miss," every time.
6. **Launch speed** — power × `kick_power` stat × plant-quality transfer, with small bonuses
   for a quick Step 2→3 transition and for run-up distance, capped by the run-up angle's
   speed ceiling if it was engaged.
7. **Shot classification** — a label (`knuckle_power`, `low_driven`, `curling_finesse`,
   `lifted`, `balanced`) derived from the final numbers, mostly for the feedback text/recap
   rather than gameplay effect.

The result launches a real `RigidBody3D` ball with drag + Magnus-effect aerodynamics (air
density, drag coefficient, spin decay all tuned constants) rather than a scripted/faked
trajectory — wind, curl, and gravity all genuinely act on it in flight, and a wall of dummy
defenders (which sometimes jump, probability scaling with set-piece difficulty) and a
goalkeeper (reacts to the calculated shot with a delay + dive toward a simple ballistic
prediction of where it'll cross the goal line) can block it before it reaches goal.

---

## 5. Player identity: stats & roster

Six 1–100 stats per player (`kick_power`, `free_kick_accuracy`, `curve`, `technique`,
`composure`, `weak_foot`) plus a `preferred_foot`, normalized to 0.01–1.0 internally. A
JSON-driven roster (`data/free_kick_players.json`) currently ships **10 archetyped
players** — Rookie (balanced baseline), two power builds, two curl builds, a knuckle
specialist, a placement/accuracy specialist, a composure specialist, a two-footed
generalist, and a technique-heavy "street" build. There's a `token_cost` /
`unlocked_by_default` field on every profile pointing at an unimplemented unlock/shop
system — currently everything is unlocked and cost is unused.

Using the "wrong" foot (`selected_foot != preferred_foot`) applies a real penalty
(`0.7 + 0.3 × weak_foot_stat` multiplier on technique) rather than just being cosmetic,
so `weak_foot` is a meaningful stat, not a flavor number.

---

## 6. Difficulty & pressure systems

`FreeKickDifficulty` is one exported resource controlling several distinct pressure levers,
all currently tuned as a single global profile (no Easy/Medium/Hard variants yet):

- **Step timers**: Step 2 (plant) 1.5s, Step 3 (contact) 2.8s baseline — both **shrink
  further** the harder Step 2's power was charged (charging past 85% eats into your own
  remaining time on the following steps).
- **Timeout penalty**: any step that hits its timer (or Step 1's run-up, if engaged but
  cut off — not applicable since Step 1 is untimed) stacks a penalty scaled by
  `(1 - composure)` — a composed player is punished less for a rushed/missed step.
- **Run-up trade-off knobs**: max speed bonus (18%) vs. max precision penalty (55%) at full
  run-up distance — currently symmetric-feeling but independently tunable.
- **Set-piece escalation** (in `FreeKickSandbox`, not `FreeKickDifficulty`): distance
  20→34m, lateral offset growing, wall size growing, wall height variance and jump
  probability kicking in from set piece 30 onward, then a late-game bias toward tight
  penalty-box angles after set piece 50.

Difficulty and set-piece escalation currently live in two different places conceptually
(a resource vs. hardcoded constants in the sandbox script) — worth a design conversation on
whether that split is intentional or should be unified into one designer-facing difficulty
surface.

---

## 7. Feedback & presentation layer

- **Live per-step HUD**: power meter with the LOW/CONTROL/IDEAL/RISK zones always visible;
  plant panel shows legal-side shading, distance rings, and aim lanes; contact panel shows
  high/low and left/right zones plus the live swipe trail. A ground-painted 3D wedge (this
  cycle's addition) now shows the run-up's legal arc and chosen angle/distance directly on
  the pitch grass rather than as a floating 2D readout.
- **Camera** cuts/eases between five purpose-built framings per step (run-up/power view,
  top-down plant view, tight first-person-ish contact view, low chase view during flight,
  wide diagonal replay view) — the run-up→power camera pull-back and the power→plant swoop
  (both added this cycle) are the first steps toward the camera *reacting* to player input
  intensity rather than just cutting between fixed poses.
- **Post-shot recap**: four frozen mini-diagrams (run-up, power, plant, contact) plus a
  short text report (shot type, speed, curl direction/strength, elevation, a support-foot
  quality readout, and a rule-based "coach tip" — e.g. "too much lift, start contact closer
  to center").
- **`FlowballEventBus`** exists (an autoload with signals for phase changes, power updates,
  shot results, stats) and a 3D stadium scoreboard already listens to it — **but nothing on
  the gameplay side emits to it yet**, so the scoreboard never updates past its defaults.
  This is a half-built decoupling layer, not a working feature — flagging so it isn't
  mistaken for finished.

---

## 8. Open questions worth a principal-design pass

- **Timer asymmetry**: Steps 2 and 3 punish hesitation with a hard timeout-and-default;
  Steps 1 and 4 don't (Step 1 is untimed by design; Step 4's window is generous at 2.8s and
  its "bad" outcome is just a weaker gesture read, not a full default). Is this the intended
  tension curve, or should Step 4 carry real time pressure too?
- **Run-up is fully opt-in with no downside for skipping** beyond forgoing its bonuses —
  is a zero-cost skip the intended framing, or should skipping it cost something (the way
  timing out Steps 2/3 does)?
- **Difficulty is a single global profile**; there's no Easy/Medium/Hard/Legendary split yet
  despite `guidance_level` existing as a stub field.
- **No progression/meta-loop**: stats are fixed per pre-built profile; the `token_cost` /
  unlock fields are wired into data but not into any spendable-currency or unlock gate.
- **Goalkeeper AI is a simple gravity-only ballistic prediction** — it doesn't account for
  spin/curve, so a heavily curled shot can beat it in a way that may read as "the keeper
  should have had that."
- **No audio, no full match context, no replay/highlight system, no multiplayer** — all
  explicitly out of scope for this prototype slice, listed here only so the reviewer knows
  they're absent by design-stage choice, not oversight.

---

*Grounded in the current state of `scripts/` as of this write-up. For deep
implementation/architecture detail (file-by-file breakdown, class diagrams, scene trees),
see `SDD.md` — but note it predates the run-up step, the camera reactivity work, and the
mouse-capture input fix described above, so treat this document as the current mechanics
source of truth and `SDD.md` as needing a refresh pass.*
