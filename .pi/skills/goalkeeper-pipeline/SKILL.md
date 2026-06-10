---
name: goalkeeper-pipeline
description: Use when designing, modeling, rigging, animating, importing, or integrating the Flowball goalkeeper in Godot. Covers Blender-to-Godot pipeline, animation contract, placeholder-first workflow, and free-kick sandbox integration.
---

# Goalkeeper Pipeline Skill

Use this skill for any work related to the Flowball goalkeeper: model, rig, animation clips, import settings, Godot scene setup, controller behavior, and integration with the free-kick sandbox.

## Core Principle

Build the goalkeeper as a gameplay-readable, replaceable actor before treating it as final art.

The first goal is not a beautiful keeper. The first goal is a keeper that:

1. has correct scale;
2. stands in the goal;
3. plays named animation clips reliably;
4. reacts to a shot direction;
5. can be replaced by a better model without rewriting gameplay code.

## Workflow

Follow this order unless the user explicitly asks otherwise:

1. Define the goalkeeper's prototype behavior.
2. Create or update the animation contract.
3. Integrate a placeholder actor in Godot.
4. Validate timing/readability in the free-kick sandbox.
5. Model/rig/animate in Blender against the contract.
6. Import `.glb` into Godot.
7. Replace placeholder visuals while preserving the same scene/script API.

Do not start with final modeling details before the behavior and animation contract are clear.

## Prototype Scope

For the first Flowball goalkeeper pass, include only the minimum needed for free kicks:

- idle / ready stance;
- pre-shot anticipation;
- dive left;
- dive right;
- optional high/low variants;
- landing;
- recovery;
- simple reaction timing.

Out of scope until approved:

- full match goalkeeper AI;
- long locomotion sets;
- ball catching with finger IK;
- complex root motion;
- facial animation;
- cinematic save system;
- final production-quality model.

## Recommended Scene Structure

Use this target structure for Godot integration:

```text
scenes/actors/Goalkeeper.tscn

Goalkeeper CharacterBody3D
├── Model Node3D
│   └── <Imported GLB or placeholder mesh>
├── AnimationPlayer or AnimationTree
├── CollisionShape3D
├── SaveReachArea Area3D
└── GoalkeeperController.gd
```

If the model is imported as a nested scene, keep gameplay nodes outside the imported scene so the art can be reimported safely.

## Script/API Contract

The goalkeeper controller should expose a small API independent of the mesh:

```gdscript
class_name GoalkeeperController
extends CharacterBody3D

func reset_for_free_kick() -> void
func set_ready() -> void
func react_to_shot(shot_params: ShotParams, predicted_target: Vector3) -> void
func play_save_animation(save_zone: StringName) -> void
func play_goal_conceded_reaction() -> void
```

Prefer passing gameplay intent (`save_zone`, `predicted_target`, `ShotParams`) instead of directly commanding animation names from unrelated systems.

## Animation Contract

Start with this minimal clip set:

```text
gk_idle
gk_ready
gk_anticipation
gk_dive_left
gk_dive_right
gk_dive_up
gk_land
gk_recover
gk_concede
```

Optional expanded clips:

```text
gk_dive_left_low
gk_dive_left_mid
gk_dive_left_high
gk_dive_right_low
gk_dive_right_mid
gk_dive_right_high
gk_step_left
gk_step_right
gk_save_chest
gk_save_hands
```

Rules:

- Clip names must stay stable once referenced in code.
- Add aliases/mapping if the imported file uses different animation names.
- Keep prototype clips short and readable.
- Avoid root motion for the first pass unless explicitly approved.
- If using root motion later, document which node/bone owns displacement.

## Blender Modeling and Rigging Guidelines

Use Blender as the authoring source and export to `.glb`/`.gltf`.

Modeling constraints:

- Use real-world-ish scale: goalkeeper height roughly `1.85-1.95` Godot units/meters.
- Face Godot forward convention consistently before export.
- Keep origin/pivot at ground center between the feet.
- Keep silhouette readable from the free-kick camera.
- Favor clean shapes and strong poses over tiny details in the prototype.

Rig constraints:

- Use a humanoid skeleton with clear names.
- Required functional bones: pelvis/root, spine/chest, head, upper/lower arms, hands, upper/lower legs, feet.
- Keep transforms applied before export.
- Avoid non-uniform scale on armature or mesh.
- Keep one main armature for the character.

Animation constraints:

- Animate for gameplay readability first.
- Make dive direction obvious within the first few frames.
- Keep anticipation short so the shot remains responsive.
- Land/recover can be rough in prototype.
- Export clips as separate named actions or a single timeline split by Godot import settings.

## Godot Import Checklist

After importing a `.glb`:

- Confirm scale against the goal and ball.
- Confirm forward direction and ground contact.
- Confirm animation clips appear with expected names.
- Confirm animations do not unintentionally move the whole actor if root motion is disabled.
- Keep imported files under `assets/` or a dedicated actor asset folder.
- Keep editable gameplay scene under `scenes/actors/`.

Ask before changing broad import settings, `.import` metadata, or project-wide animation settings.

## Gameplay Integration Notes

For the first pass, reaction can be approximate:

1. Read final or predicted shot target.
2. Classify target into save zones:
   - `left`, `right`, `up`, `center`;
   - optionally `left_low`, `left_high`, `right_low`, `right_high`.
3. Wait a small reaction delay.
4. Play the matching animation.
5. Use a simple Area3D or timing window for save detection if needed.

Do not implement complex goalkeeper intelligence until the animation/readability loop works.

## Verification

A goalkeeper change is not done until there is evidence for the relevant layer:

- Model/rig: scale, origin, orientation, and exported clips verified in Godot.
- Animation: clips play by name and read clearly from the active camera.
- Godot integration: `Goalkeeper.tscn` can reset, ready, react, and recover.
- Gameplay: free-kick sandbox still launches shots and the keeper reaction does not break the ball flow.

If automated tests are not practical, provide manual verification steps in the sandbox.

## Common Mistakes to Avoid

- Modeling final details before defining the animation contract.
- Binding gameplay logic to a specific imported mesh hierarchy.
- Letting Blender scale/orientation issues leak into Godot scripts.
- Using root motion before the controller and save logic need it.
- Creating too many animation variants before validating basic left/right/up reactions.
- Editing generated Godot import metadata manually without a clear reason.

## Expected Output When Planning

When asked to plan goalkeeper work, return:

```text
status
prototype_goal
animation_contract
scene_structure
blender_pipeline
integration_steps
verification_steps
risks
next_recommended
```
