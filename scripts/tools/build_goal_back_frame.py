"""Build the rear support frame for the Flowball goal.

The goal.glb model only has posts, crossbar, a bottom back bar (BackBottom)
and two diagonal supports. The realistic net built by build_goal_net.py has a
sloped back (bottom y=1.8 z=0 -> top y=2.0 z=1.6) and a sloping roof
(crossbar z=2.44 -> back top z=1.6). This script generates the rear frame
that follows that exact net shape:

- TopBackBar:      horizontal bar along the back net crest (y=2.0, z=1.6)
- Left/RightBackPost: corner posts framing the sloped back net
- Left/RightRoofSupport: diagonals along the roof slope (crossbar -> crest)

Coordinates are REAL meters in GoalNetVisual local space (depth = -z in
Godot, +y in Blender), matching goal_net.glb exactly. The goal.glb itself is
NOT touched; the sandbox instance scales it by ~1.027, which would misalign
any new frame attached to it.

Run from the repo root:
    blender --background --python scripts/tools/build_goal_back_frame.py
Output: assets/models/goal_back_frame.glb
"""

import os
import sys

import bpy

# Reuse helpers from the net builder (make_object, clear_scene, tubes).
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
if SCRIPT_DIR not in sys.path:
    sys.path.insert(0, SCRIPT_DIR)
import build_goal_net as net

ROOT = net.ROOT
OUT_PATH = os.path.join(ROOT, "assets", "models", "goal_back_frame.glb")

BACK_BOTTOM_Y = 1.8          # matches net base and existing BackBottom
BACK_BOTTOM_Z = 0.08         # height of the existing BackBottom bar
FRAME_RADIUS = 0.04          # ~8 cm diameter, close to existing supports


def build_material() -> bpy.types.Material:
    """Replicate the goal's painted white metal material."""
    mat = bpy.data.materials.new("painted_white_metal")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (0.92, 0.92, 0.88, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.42
    bsdf.inputs["Metallic"].default_value = 0.0
    return mat


def main() -> None:
    net.clear_scene()
    objects = []

    # 1) Top back bar: along the back net crest.
    bm = net_bmesh()
    net.build_reinforced_tube(
        bm,
        [(-net.HALF_WIDTH, net.BACK_TOP_Y, net.BACK_TOP_Z),
         (net.HALF_WIDTH, net.BACK_TOP_Y, net.BACK_TOP_Z)],
        FRAME_RADIUS,
    )
    objects.append(net.make_object("TopBackBar", bm))

    # 2) Corner posts framing the sloped back net (bottom bar -> crest).
    for name, x in (("LeftBackPost", -net.HALF_WIDTH), ("RightBackPost", net.HALF_WIDTH)):
        bm = net_bmesh()
        net.build_reinforced_tube(
            bm,
            [(x, BACK_BOTTOM_Y, BACK_BOTTOM_Z), (x, net.BACK_TOP_Y, net.BACK_TOP_Z)],
            FRAME_RADIUS,
        )
        objects.append(net.make_object(name, bm))

    # 3) Roof supports along the roof slope (crossbar -> crest).
    for name, x in (("LeftRoofSupport", -net.HALF_WIDTH), ("RightRoofSupport", net.HALF_WIDTH)):
        bm = net_bmesh()
        net.build_reinforced_tube(
            bm,
            [(x, 0.0, net.HEIGHT), (x, net.BACK_TOP_Y, net.BACK_TOP_Z)],
            FRAME_RADIUS,
        )
        objects.append(net.make_object(name, bm))

    material = build_material()
    for obj in objects:
        obj.data.materials.append(material)

    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    final_obj = bpy.context.active_object
    final_obj.name = "GoalBackFrame"
    final_obj.data.name = "GoalBackFrame"

    tri_count = sum(len(p.vertices) - 2 for p in final_obj.data.polygons)
    print(f"[back_frame] vertices={len(final_obj.data.vertices)} triangles={tri_count}")

    os.makedirs(os.path.dirname(OUT_PATH), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=OUT_PATH, export_format="GLB")
    print(f"[back_frame] exported {OUT_PATH}")


def net_bmesh():
    import bmesh
    return bmesh.new()


if __name__ == "__main__":
    main()
