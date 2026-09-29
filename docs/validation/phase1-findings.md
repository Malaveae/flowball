# Phase 1 findings — can Flowball replicate historical free kicks?

*2026-09-29. Analysis of `historical-feasibility.md` (generated, deterministic) for the 10-kick
pilot in `data/historical_free_kicks.json`. Envelope = goal entry point, flight time, curl
(chord deviation), height at the 9.15 m wall plane, launch speed and (for knuckleballs) a
knuckle strike. Neutral 70-rated kicker, the kick's own foot, no wind.*

## Headline

- **Physics can do it.** All 10 kicks are reachable by *some* launch inside the current caps (Stage 1).
  No kick needed a faster launch than `ShotCalculator.MAX_LAUNCH_SPEED` (36 m/s), a higher
  elevation, or a wider aim. At the spin cap, Flowball's Magnus term gives a lift coefficient of about
  0.27. That is inside the 0.23–0.29 Bray & Kerwin (2003) measured on real free kicks.
- **Players can reach it.** 9 of 10 kicks are reachable through real inputs (Stage 2). The
  exception (Ronaldinho, under the wall) fails because the *validator* doesn't model a skidding
  ball, not because of the game.
- **Repeatability was the problem; three fixes are in (G3, G1+G2, G9).** Skill window for the
  neutral kicker, original -> now: Beckham 2->26%, Messi 5->19%, Bale 0->19%, Nakamura 16->15%,
  Koeman 37->85%, Roberto Carlos 3->9% (now via an outside-foot trivela, his real technique),
  Ronaldinho fail->7%, Ronaldo 2018 4->5%, knuckles 0->2-3%. Most kicks now need power 0.5-0.9
  instead of maxing out. Remaining fragility: knuckles (G4), contact height/trace bend mapping,
  and tight measured envelopes.

## Gaps (confirmed, each a candidate fix slice)

| # | Gap | Evidence | Proposed slice | Needs your call |
|---|---|---|---|---|
| G1 ✅ | **Jolt silently clamped spin to 47.1 rad/s** while `ShotCalculator` asked for up to 140; worse, the intent->spin curve (neutral kicker ~300 rad/s at full swipe) saturated so far above the clamp that overpower-damping, follow-through length and rosca-vs-straight made no difference in flight for strong swipes. | Parity test: 140 vs 47 rad/s land 0.9 cm apart. | **Done:** `MAX_SPIN_RATE` = 47.12 (the flown maximum, inside measured 25-59 rad/s, lift ~0.27 within Bray & Kerwin), intent curve rescaled so a neutral full swipe = 47; run-up spin ceiling now real; knuckle damping re-tuned (x0.2 -> x1.0); feedback spin bands re-anchored. No `project.godot` change. | Decided (recommended) |
| G2 ✅ | **Air resistance was ~1.5x real**: Cd 0.25 plus Godot's default linear damping 0.1/s. | Ronaldo 2018 needed power 0.97 (RISK zone). | **Done:** `Ball3D.tscn` damping mode Replace (0), so only the aero model slows the ball; Cd kept at 0.25 (Bray & Kerwin field value). The simulator reads damping from the scene. Best inputs now need power 0.47-0.88 for most kicks. | Decided (recommended) |
| G3 ✅ | **Shot error was effectively a hash of the inputs** (`_deterministic_error`: sin/cos of inputs × 13–91). An imperceptible input change gave an unrelated miss, against AGENTS.md "input quality must stay legible". | Old skill windows 0–16% for 8 kicks; plant depth, which shouldn't aim, was among the most sensitive inputs. | **Done (2026-09-29):** replaced by `_flaw_terms`. Overpower lifts, cramped plant drops, overextended plant drags across the kicking foot (never by support side), plant depth tips up/down, over-open foot runs further across, messy trace slices, toe-poke pops up. A clean strike has zero error; `ShotParams.dominant_flaw` drives the coach tip. | Decided: directional flaws |
| G4 | **Knuckleballs can't be reproduced reliably.** Clean strike needs contact within 0.12 radii of centre plus a short straight trace. The wobble seed is quantized from the inputs, so every 0.05 input step is a new wobble. | Ronaldo 2008, Juninho 2003 and Bale 2016 all pass Stage 2 (only with targeted knuckle-shaped starting points), but their skill windows are 0–1% even without G3. | Decide what "replicating a knuckle" means: e.g. the success check ignores the wobble and judges the no-noise path (the trajectory ghost already tracks it). | Yes: design |
| G5 | **Technique doesn't matter to the outcome.** The winning inputs are classified Topspin/Backspin/Dirty rather than the real technique. Beckham's winning input reads as Topspin, Roberto Carlos's as dirty contact instead of an outside-foot trivela. | See "Stage 2 best input" in the report. | If the album should reward *how* a kick was struck, add technique to the success criteria and tighten the classifier→physics link. | Yes: design |
| G6 | **Weak-foot penalty conflicts with the skill-only kicker.** | Validator bypasses it (preferred foot = kick's foot). | Neutralize or remove `weak_foot` / the profile stats for Collection mode. | Confirm |
| G7 | **The data is thin.** 1 of 10 kicks is measured, 2 are press estimates, 7 are derived. Entry side is missing for Messi/Nakamura, and Koeman has no signatures at all. No spot has a known lateral offset. Pirlo and a tight-angle kick were dropped for lack of sources. | Constraints column in the report (0–6 per kick). | Footage review per kick (entry point, spot, wall) before scaling to 110. Kicks with ≤2 constraints prove little. | Help/sources welcome |
| G9 ✅ | **Run-up speed ceiling contradicted its own sources** (lateral run-up capped speed at 40%). Isokawa & Lees (1988): peak ball speed at 30-45 deg approach (their convention); Scurr & Hall (2009): no significant speed difference across 30/45/60 deg. | 9 of 10 best inputs skipped the run-up. | **Done:** `runup_speed_ceiling` peaks at 45-60 deg (game convention), easing to 0.85 lateral / 0.90 straight (end values are estimates). Curl ceiling unchanged. Now 5 of 10 best inputs use the run-up. | Decided: peak curve |
| G8 | **Validator limits.** No ground bounce/roll, no jumping wall, no keeper. The human-noise model is a first guess. | Ronaldinho passes only through a flat, fast line drive; a real skidding ball isn't modelled. | Add ground contact to `BallFlightSimulator`. Calibrate noise from playtest telemetry. | — |

Also noted (pre-existing, not from this work): `ShotCalculatorSmokeTest` "knuckle drift RMS"
fails (0.65 m vs 0.30–0.55 band) with the current uncommitted knuckle tuning.

## Recommended order

1. ~~G3 (error term)~~ done.
2. ~~G1 + G2 (spin cap, drag)~~ done.
2b. ~~G9 (run-up speed ceiling)~~ done.
3. **G7 (data)**: firm up the pilot, then draft the next 100 kicks with you.
4. **G4/G5 (knuckle, technique)**: design decisions that define the Collection-mode success rule.

## Sources

- Bray & Kerwin 2003, *Modelling the flight of a soccer ball in a direct free kick*, J. Sports Sci. 21(2) — Cd 0.25–0.30, Cl 0.23–0.29.
- Shankara 2018, *Analysis of Cristiano Ronaldo's Free Kick using CFD*, icSPORTS — 22 m, 26.8 m/s, ~5 rev/s, 0.82 s, ~3.5 m deflection; Telstar 18 Cd 0.20–0.22.
- Dupeux et al. 2010, *The spinning ball spiral*, New J. Phys. — Roberto Carlos 1997, ~35 m.
- Curled-kick spin rates 25–59 rad/s (semi-professional players): *'Bend it like Beckham': ball rotation in the curved football kick*.
- Per-kick press sources are listed in `data/historical_free_kicks.json`.
