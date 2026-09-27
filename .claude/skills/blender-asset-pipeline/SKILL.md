---
name: blender-asset-pipeline
description: Create, edit, and export 3D assets (props, pitch furniture, characters) from Blender into this Godot 4.7 project's assets/models pipeline, either via headless bpy scripts or the live Blender MCP connection. Use when asked to model, retouch, or export a 3D asset for Flowball.
---

# Blender → Godot asset pipeline (Flowball)

This project has two working ways to get a mesh from Blender into `res://assets/models/`. Pick based on the task, don't default to one.

## Route A — headless bpy script (default for anything parametric/proportioned)

Existing examples: `tools/blender/create_soccer_ball.py`, `tools/blender/create_goal_and_goalkeeper.py`, `scripts/tools/build_goal_net.py`, `scripts/tools/build_goal_back_frame.py`, `scripts/tools/remove_goal_supports.py`. Check these first — the asset you need may already exist or be one parameter tweak away.

Run with:
```bash
blender --background --python tools/blender/<script>.py
```

Write new scripts following the existing pattern:
- Build entirely in code (`bpy.ops.mesh.primitive_*`, `mathutils.Vector`), no manual scene state.
- Name dimension/position constants at the top (radius, thickness, offsets) instead of scattering literals — mirrors the project's "no magic numbers" rule.
- Export at the end with `bpy.ops.export_scene.gltf(filepath=str(OUT), export_format="GLB", export_apply=True, export_materials="EXPORT")`.
- Output path is always `assets/models/<name>.glb`, resolved from `Path(__file__).resolve().parents[N]` — don't hardcode absolute paths.

This route is preferred because the script *is* the asset source of truth — reproducible, diffable, and re-runnable if a dimension needs to change later.

## Route B — live Blender MCP (for freeform modeling, sculpting, texture/material iteration, or visually checking Route A output)

The `blender` MCP server is registered (user scope) and bridges to a *running* Blender instance over a local socket (`127.0.0.1:9876`).

Before calling any Blender MCP tool:
1. Confirm Blender is open with the BlenderMCP addon installed and its socket server started inside Blender — the MCP process here is only the bridge, it does nothing if no Blender instance is listening.
2. If a tool call fails with a connection error, that's almost always "Blender isn't running with the server on," not a config problem.

When done editing live, still export through the same `bpy.ops.export_scene.gltf(...)` call (via the MCP's code-execution tool) with `export_apply=True` so transforms are baked — don't rely on "File > Export" defaults, they drift from the project's settings.

## Non-negotiable conventions (apply to both routes)

- **Axis mapping**: Blender is Z-up, Godot is Y-up. The glTF importer converts Blender Z → Godot Y automatically. Always author the *vertical* dimension of a model on Blender's Z axis — never fake verticality on Blender Y. See the header comment in `tools/blender/create_goal_and_goalkeeper.py` for the worked example (goal width=X, height=Z, depth=Y → imports as width=X, height=Y, shot-direction=-Z).
- **Units**: 1 Blender unit = 1 Godot unit = 1 meter (AGENTS.md). Match real-world references already used in this repo: ball radius `0.11 m`, goal `7.32 m × 2.44 m`, wall distance `9.15 m`.
- **Origin placement**: put the origin where gameplay code expects it — e.g. goalkeeper origin at feet-center (ground plane), ball origin at sphere center. Check the consuming GDScript (`FreeKickBall3D.gd`, `GoalkeeperController.gd`) before picking an origin if unsure.
- **Materials**: use `Principled BSDF` via `use_nodes = True`, set `Base Color`/`Roughness` only — keep it simple, this project doesn't use exotic shader graphs for base meshes (custom look goes through Godot-side `.gdshader` files in `assets/shaders/`, not baked into the glTF material).

## After export

Godot auto-generates a `.import` file for any new `.glb` the next time the editor scans `assets/models/`. Per AGENTS.md file-safety rules: **never hand-edit `.import` files** — if the editor doesn't pick up a new/changed model, open it (`godot -e --path .`) to force a reimport rather than writing import metadata by hand. If the asset replaces an existing `.glb` at the same path, Godot reimports in place and existing scene references keep working.

Wire the new model into a scene the same way existing props are wired (see `scenes/sandbox/FreeKickSandbox.tscn`'s `ext_resource`/`instance` pattern) — don't restructure the sandbox scene wholesale to add one prop; per AGENTS.md, broad scene rewrites need to be flagged before doing them.
