"""Remove the diagonal back supports from goal.glb.

The goal model has two diagonal bars (LeftBackSupport/RightBackSupport)
running from the top front crossbar down to the back bottom bar. They are
redundant with the new rear frame (goal_back_frame.glb), so this script
round-trips the original GLB through Blender and deletes them, keeping the
posts, crossbar and bottom back bar untouched.

Run from the repo root:
    blender --background --python scripts/tools/remove_goal_supports.py
Rewrites: assets/models/goal.glb
"""

import os

import bpy

GOAL_PATH = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "models", "goal.glb"
)

REMOVE_NAMES = {"LeftBackSupport", "RightBackSupport"}


def main() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=GOAL_PATH)
    bpy.ops.object.select_all(action="DESELECT")

    removed = []
    for obj in list(bpy.data.objects):
        if obj.name in REMOVE_NAMES:
            obj.select_set(True)
            removed.append(obj.name)
    if removed:
        bpy.ops.object.delete(use_global=False)

    remaining = [o.name for o in bpy.data.objects if o.type == "MESH"]
    print(f"[goal] removed: {removed}")
    print(f"[goal] remaining meshes: {remaining}")

    if not removed:
        raise SystemExit("No support meshes found; aborting export.")

    bpy.ops.export_scene.gltf(filepath=GOAL_PATH, export_format="GLB")
    print(f"[goal] exported {GOAL_PATH}")


if __name__ == "__main__":
    main()
