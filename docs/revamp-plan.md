# Flowball Graphic Revamp Plan

| | |
|---|---|
| **Goal** | Move Flowball's look from prototype to the mockup direction: night stadium, cyan/blue palette, bright floodlights, packed tribunes with LED boards, stylized characters, sci-fi HUD |
| **Mockup source** | `assets/Inputs RAW/REvamp/` (12 reference images) |
| **Engine** | Godot 4.7 (Forward+, Jolt) |
| **Pipeline** | Hedra (2D/texture/reference generation) → Blender (3D modeling/retopo/export) → Godot 4.7 (import/material/scene integration) |
| **Skill** | `.pi/skills/flowball-revamp-pipeline/` — workflow contract for this pipeline |

---

## 1. Style Direction (from mockups)

| Element | Mockup target | Current state |
|---|---|---|
| Time of day | Night match, dark blue sky | Day sky (procedural blue) |
| Floodlights | Bright floodlight banks with glow/haze | Generic stadium lights, low visual identity |
| Tribunes | Packed crowd, dark tones, LED "FOOTBALL" ad boards | Flat `Tribuna.png` backdrop |
| Pitch | Lush green, checkerboard mowing, crisp white lines | Stripes shader (linear bands, no checkerboard) |
| Ball | Colorful streak design (blue/red/yellow on white) | `trionda.png` albedo |
| Goalkeeper | Stylized Pixar-like, yellow kit, black trim | Old rigged model, placeholder textures |
| HUD | Cyan neon rounded panels, vertical power meter, phase stepper | Functional custom-drawn HUD, no panel art |

**Non-goals:** full PBR photorealism, new gameplay states, animation rework (only materials/mesh/lighting), mobile performance regression beyond current budget.

---

## 2. Phases

### Phase 0 — Baseline (0.5 day)
- Capture before screenshots: POWER_VIEW, SUPPORT_TOP_DOWN, SHOT_FOLLOW, FEEDBACK_REPLAY camera modes at 1280x720 and 2560x1440.
- Record current FPS in sandbox scene (target baseline to protect).
- Freeze scope: the 12 mockups define acceptance; no new elements invented mid-phase.

### Phase 1 — Hedra asset generation (1-2 days, parallel-friendly)
Generate 2D assets and references with the prompt library in
`.pi/skills/flowball-revamp-pipeline/assets/hedra-prompts.md`.

| Asset | Type | Used for |
|---|---|---|
| `stadium_bowl_night.png` | 4K, 21:9 (panorama, mirror-tiled in shader) | Tribune inner-cylinder texture |
| `crowd_tile.png` | 2K, 1:1 seamless | Crowd variation / far tribune fill |
| `led_board_football.png` | 4K, 16:9 (crop text row in Godot) | Ad-board strip texture |
| `floodlight_bank.png` | 2K, 1:1 | Floodlight bank emissive + glow sprite |
| `turf_checker_albedo.png` | 4K, 1:1 seamless | Pitch ground shader albedo rework |
| `ball_uv_revamp.png` | 2K, 1:1 (projected onto ball UVs in Blender) | Ball albedo replacement |
| `goalkeeper_ref_sheet.png` | 2K, 2:3 character sheet | Blender modeling/texture reference |
| `hud_panel_frame.png` | 2K, 16:9 transparent PNG | Optional HUD panel backing art |
| `power_meter_frame.png` | 2K, 9:16 transparent PNG | Power meter bezel art |

All assets are generated with Nano Banana Pro / Gemini image models (see
`.pi/skills/flowball-revamp-pipeline/assets/nano-banana-prompts.md`): fixed aspect
ratios only (1:1, 3:2, 2:3, 3:4, 4:3, 4:5, 5:4, 9:16, 16:9, 21:9), mockup attached as
reference image per prompt.

Gate: every asset checked against its mockup (palette, composition, lighting) before moving on.

### Phase 2 — Blender 3D work (2-4 days)
1. **Stadium bowl**: low-poly inner cylinder/ring geometry for tribunes (UV for the panorama), roof ring, corner fills. Target: replaces flat `TribunaBackground` planes.
2. **Floodlight towers**: 4 corner towers + roof light banks. Emissive planes use `floodlight_bank.png`; real lights stay as 2-3 `DirectionalLight3D`/`SpotLight3D` (fake the rest with glow).
3. **LED boards**: thin box strips along tribune base, emissive material with `led_board_football.png`, optional slow UV scroll shader.
4. **Goalkeeper retopo/refit** (optional slice 2): keep existing rig; only reskin with new texture derived from `goalkeeper_ref_sheet.png` if current mesh accepts it. New mesh only if texture path fails.
5. **Ball**: keep `soccer_ball.glb` mesh; only swap albedo texture (no Blender needed unless UV layout differs — verify first).
6. Export all as glTF 2.0 `.glb`, meters, +Y up (Blender glTF exporter handles conversion), transforms applied.

Gate: each `.glb` opens in Godot 4.7 with correct scale (goal 7.32m wide), correct orientation, textures bound.

### Phase 3 — Godot environment & materials (1-2 days)
- `Environment` rework in `FreeKickSandbox.tscn`: night `ProceduralSkyMaterial`, ambient tuned down, `volumetric_fog_enabled` (or fog + glow fallback for mobile), glow tuned up for floodlights/LED, `adjustment_*` to hit the cyan/teal grade of the mockups.
- Pitch shader (`pitch_ground.gdshader`): switch stripes to checkerboard mode (add `stripe_mode` uniform, checker logic in world space), feed new albedo.
- Grass card shader: tint adjustments to match mockup green under night lighting.
- Net, ball, keeper materials: assign new textures; ball gets slight clearcoat for night speculars.
- Keep `1 unit = 1 m`; no scene restructuring beyond swapping tribune/wall nodes.

### Phase 4 — HUD pass (1 day)
- Re-skin `ModernScoreHud`, power meter, wind/distance panels to mockup style: cyan neon rounded panels, dark translucent backing, color-zone vertical power meter (blue→green→yellow→red).
- Prefer custom drawing updates (current approach) using panel art only where it saves effort. Keep HUD resolution-independent (`FreeKickUIScale`).
- Phase stepper `[1. POWER][2. PLANT][3. CONTACT]` visual match.

### Phase 5 — Verification (0.5 day)
- Side-by-side screenshot comparison against mockups per camera mode.
- FPS check: no more than 10% regression vs Phase 0 baseline at 1440p.
- Smoke tests still pass (`godot --headless --script scripts/tests/ShotCalculatorSmokeTest.gd`).
- Determinism untouched (no gameplay math changed).

---

## 3. File Conventions

- Hedra outputs land in `assets/Inputs RAW/REvamp/generated/` first (review staging).
- Approved assets move to `assets/textures/` (env) or `assets/ui/` (HUD), renamed per Phase 1 table.
- Blender source files in `tools/blender/` (`.blend` kept out of exports), exports to `assets/models/`.
- Never edit `.import` metadata by hand except for documented import params.

## 4. Risks

| Risk | Mitigation |
|---|---|
| Hedra textures not seamless | Tile in shader with world-space UV (existing pattern in pitch shader) |
| Volumetric fog cost on mobile | Feature-gate: full fog desktop, plain fog+glow mobile |
| Goalkeeper retexture fails on old UVs | Fallback: keep old texture, only environment/HUD ship this revamp |
| Panorama stretching on bowl corners | Author corners separately or keep flat planes at corners |
