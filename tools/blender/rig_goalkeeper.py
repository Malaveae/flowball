"""Create a local prototype humanoid rig for the Flowball goalkeeper GLB.

Usage:
  blender --background --python tools/blender/rig_goalkeeper.py -- \
    --input assets/models/textured_mesh.glb \
    --output assets/models/goalkeeper_rigged.glb

This is a prototype rigging pass, not final deformation work. It creates a simple
humanoid armature, rough coordinate-based vertex groups, and a few placeholder
animation clips so Godot can import a Skeleton3D + AnimationPlayer workflow.
"""

from __future__ import annotations

import argparse
import math
import os
import sys
from pathlib import Path

import bpy
from mathutils import Vector


def parse_args() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", default="assets/models/textured_mesh.glb")
    parser.add_argument("--output", default="assets/models/goalkeeper_rigged.glb")
    parser.add_argument("--height", type=float, default=1.9)
    return parser.parse_args(argv)


def clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()


def import_glb(path: str) -> None:
    bpy.ops.import_scene.gltf(filepath=path)


def scene_meshes() -> list[bpy.types.Object]:
    return [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]


def combined_bounds(objects: list[bpy.types.Object]) -> tuple[Vector, Vector]:
    points: list[Vector] = []
    for obj in objects:
        for corner in obj.bound_box:
            points.append(obj.matrix_world @ Vector(corner))
    min_v = Vector((min(p.x for p in points), min(p.y for p in points), min(p.z for p in points)))
    max_v = Vector((max(p.x for p in points), max(p.y for p in points), max(p.z for p in points)))
    return min_v, max_v


def normalize_model(objects: list[bpy.types.Object], target_height: float) -> tuple[Vector, Vector]:
    min_v, max_v = combined_bounds(objects)
    height = max_v.z - min_v.z
    if height <= 0.0001:
        raise RuntimeError("Imported model has invalid height")
    scale = target_height / height
    for obj in objects:
        obj.scale *= scale
    bpy.context.view_layer.update()
    min_v, max_v = combined_bounds(objects)
    offset = Vector(((min_v.x + max_v.x) * -0.5, (min_v.y + max_v.y) * -0.5, -min_v.z))
    for obj in objects:
        obj.location += offset
    bpy.context.view_layer.update()
    return combined_bounds(objects)


def create_armature(height: float) -> bpy.types.Object:
    bpy.ops.object.armature_add(enter_editmode=True, location=(0, 0, 0))
    armature = bpy.context.object
    armature.name = "GoalkeeperArmature"
    data = armature.data
    data.name = "GoalkeeperSkeleton"
    data.display_type = "STICK"

    # Remove default bone.
    data.edit_bones.remove(data.edit_bones[0])

    def add_bone(name: str, head: tuple[float, float, float], tail: tuple[float, float, float], parent: str | None = None) -> None:
        bone = data.edit_bones.new(name)
        bone.head = head
        bone.tail = tail
        bone.roll = 0.0
        if parent:
            bone.parent = data.edit_bones[parent]
            bone.use_connect = False

    h = height
    # Blender Z is up. Character faces -Y for Godot-ish forward after export.
    add_bone("root", (0, 0, 0.02 * h), (0, 0, 0.12 * h))
    add_bone("pelvis", (0, 0, 0.48 * h), (0, 0, 0.62 * h), "root")
    add_bone("spine", (0, 0, 0.62 * h), (0, 0, 0.78 * h), "pelvis")
    add_bone("chest", (0, 0, 0.78 * h), (0, 0, 0.90 * h), "spine")
    add_bone("neck", (0, 0, 0.90 * h), (0, 0, 0.95 * h), "chest")
    add_bone("head", (0, 0, 0.95 * h), (0, 0, 1.04 * h), "neck")

    add_bone("upper_arm.L", (-0.18 * h, 0, 0.86 * h), (-0.36 * h, 0, 0.78 * h), "chest")
    add_bone("forearm.L", (-0.36 * h, 0, 0.78 * h), (-0.52 * h, 0, 0.70 * h), "upper_arm.L")
    add_bone("hand.L", (-0.52 * h, 0, 0.70 * h), (-0.61 * h, 0, 0.68 * h), "forearm.L")
    add_bone("upper_arm.R", (0.18 * h, 0, 0.86 * h), (0.36 * h, 0, 0.78 * h), "chest")
    add_bone("forearm.R", (0.36 * h, 0, 0.78 * h), (0.52 * h, 0, 0.70 * h), "upper_arm.R")
    add_bone("hand.R", (0.52 * h, 0, 0.70 * h), (0.61 * h, 0, 0.68 * h), "forearm.R")

    add_bone("thigh.L", (-0.09 * h, 0, 0.48 * h), (-0.11 * h, 0, 0.27 * h), "pelvis")
    add_bone("shin.L", (-0.11 * h, 0, 0.27 * h), (-0.10 * h, 0, 0.06 * h), "thigh.L")
    add_bone("foot.L", (-0.10 * h, 0, 0.06 * h), (-0.10 * h, -0.14 * h, 0.03 * h), "shin.L")
    add_bone("thigh.R", (0.09 * h, 0, 0.48 * h), (0.11 * h, 0, 0.27 * h), "pelvis")
    add_bone("shin.R", (0.11 * h, 0, 0.27 * h), (0.10 * h, 0, 0.06 * h), "thigh.R")
    add_bone("foot.R", (0.10 * h, 0, 0.06 * h), (0.10 * h, -0.14 * h, 0.03 * h), "shin.R")

    bpy.ops.object.mode_set(mode="OBJECT")
    return armature


def closest_body_group(co: Vector, h: float) -> str:
    x = co.x
    z = co.z
    ax = abs(x)
    side = ".L" if x < 0 else ".R"

    if z > 0.90 * h:
        return "head"
    if ax > 0.50 * h and z > 0.58 * h:
        return "hand" + side
    if ax > 0.34 * h and z > 0.62 * h:
        return "forearm" + side
    if ax > 0.18 * h and z > 0.62 * h:
        return "upper_arm" + side
    if z < 0.10 * h and ax > 0.045 * h:
        return "foot" + side
    if z < 0.28 * h and ax > 0.035 * h:
        return "shin" + side
    if z < 0.52 * h and ax > 0.035 * h:
        return "thigh" + side
    if z < 0.60 * h:
        return "pelvis"
    if z < 0.78 * h:
        return "spine"
    return "chest"


def bind_meshes(meshes: list[bpy.types.Object], armature: bpy.types.Object, height: float) -> None:
    bone_names = [bone.name for bone in armature.data.bones]
    for mesh in meshes:
        bpy.context.view_layer.objects.active = mesh
        mesh.select_set(True)
        for name in bone_names:
            if name not in mesh.vertex_groups:
                mesh.vertex_groups.new(name=name)
        for vertex in mesh.data.vertices:
            world = mesh.matrix_world @ vertex.co
            group_name = closest_body_group(world, height)
            mesh.vertex_groups[group_name].add([vertex.index], 1.0, "REPLACE")
        modifier = mesh.modifiers.new("GoalkeeperArmature", "ARMATURE")
        modifier.object = armature
        mesh.parent = armature
        mesh.select_set(False)


def set_pose_rotation(armature: bpy.types.Object, rotations: dict[str, tuple[float, float, float]]) -> None:
    for bone_name, rotation in rotations.items():
        bone = armature.pose.bones.get(bone_name)
        if bone is None:
            continue
        bone.rotation_mode = "XYZ"
        bone.rotation_euler = tuple(math.radians(v) for v in rotation)


def keyframe_pose(armature: bpy.types.Object, frame: int) -> None:
    bpy.context.scene.frame_set(frame)
    for bone in armature.pose.bones:
        bone.keyframe_insert(data_path="rotation_euler", frame=frame)
        bone.keyframe_insert(data_path="location", frame=frame)


def clear_pose(armature: bpy.types.Object) -> None:
    for bone in armature.pose.bones:
        bone.rotation_mode = "XYZ"
        bone.rotation_euler = (0, 0, 0)
        bone.location = (0, 0, 0)


def create_action(armature: bpy.types.Object, name: str, keys: list[tuple[int, dict[str, tuple[float, float, float]]]]) -> None:
    clear_pose(armature)
    action = bpy.data.actions.new(name)
    armature.animation_data_create()
    armature.animation_data.action = action
    for frame, rotations in keys:
        clear_pose(armature)
        set_pose_rotation(armature, rotations)
        keyframe_pose(armature, frame)
    action.use_fake_user = True


def create_placeholder_actions(armature: bpy.types.Object) -> None:
    # Keep these action names aligned with GoalkeeperController.gd. Godot gameplay
    # calls stable clip names so generated, mocap, or hand-authored animation can
    # replace this prototype rig without script changes.
    create_action(armature, "gk_idle", [
        (1, {"spine": (2, 0, 0), "upper_arm.L": (0, 0, -8), "upper_arm.R": (0, 0, 8), "shin.L": (-4, 0, 0), "shin.R": (-4, 0, 0)}),
        (20, {"spine": (-1, 0, 1), "upper_arm.L": (0, 0, -11), "upper_arm.R": (0, 0, 11), "shin.L": (-7, 0, 0), "shin.R": (-7, 0, 0)}),
        (40, {"spine": (2, 0, 0), "upper_arm.L": (0, 0, -8), "upper_arm.R": (0, 0, 8), "shin.L": (-4, 0, 0), "shin.R": (-4, 0, 0)}),
    ])
    create_action(armature, "gk_ready", [
        (1, {"spine": (8, 0, 0), "thigh.L": (8, 0, 0), "thigh.R": (8, 0, 0), "shin.L": (-14, 0, 0), "shin.R": (-14, 0, 0), "upper_arm.L": (18, 0, -18), "upper_arm.R": (18, 0, 18), "forearm.L": (16, 0, -8), "forearm.R": (16, 0, 8)}),
        (30, {"spine": (10, 0, 0), "thigh.L": (10, 0, 0), "thigh.R": (10, 0, 0), "shin.L": (-18, 0, 0), "shin.R": (-18, 0, 0), "upper_arm.L": (22, 0, -20), "upper_arm.R": (22, 0, 20), "forearm.L": (18, 0, -8), "forearm.R": (18, 0, 8)}),
    ])
    create_action(armature, "gk_anticipation", [
        (1, {"spine": (8, 0, 0), "shin.L": (-12, 0, 0), "shin.R": (-12, 0, 0)}),
        (12, {"spine": (14, 0, 0), "shin.L": (-22, 0, 0), "shin.R": (-22, 0, 0), "upper_arm.L": (26, 0, -24), "upper_arm.R": (26, 0, 24)}),
    ])
    create_action(armature, "gk_dive_left", [
        (1, {}),
        (14, {"root": (0, 0, 18), "spine": (0, 0, 28), "upper_arm.L": (0, 0, -55), "forearm.L": (0, 0, -25), "upper_arm.R": (0, 0, -18), "thigh.L": (0, 0, -18), "thigh.R": (0, 0, -8)}),
    ])
    create_action(armature, "gk_dive_right", [
        (1, {}),
        (14, {"root": (0, 0, -18), "spine": (0, 0, -28), "upper_arm.R": (0, 0, 55), "forearm.R": (0, 0, 25), "upper_arm.L": (0, 0, 18), "thigh.R": (0, 0, 18), "thigh.L": (0, 0, 8)}),
    ])
    create_action(armature, "gk_dive_up", [
        (1, {"spine": (8, 0, 0), "shin.L": (-14, 0, 0), "shin.R": (-14, 0, 0)}),
        (12, {"root": (-8, 0, 0), "spine": (-10, 0, 0), "upper_arm.L": (-56, 0, -14), "upper_arm.R": (-56, 0, 14), "forearm.L": (-18, 0, -8), "forearm.R": (-18, 0, 8), "thigh.L": (18, 0, -6), "thigh.R": (18, 0, 6), "shin.L": (-32, 0, 0), "shin.R": (-32, 0, 0)}),
    ])
    create_action(armature, "gk_land", [
        (1, {"root": (0, 0, 16), "spine": (4, 0, 22), "upper_arm.L": (8, 0, -38), "upper_arm.R": (8, 0, -12)}),
        (18, {"spine": (12, 0, 8), "upper_arm.L": (24, 0, -18), "upper_arm.R": (24, 0, 18), "thigh.L": (18, 0, 0), "thigh.R": (18, 0, 0), "shin.L": (-34, 0, 0), "shin.R": (-34, 0, 0)}),
    ])
    create_action(armature, "gk_recover", [(1, {}), (24, {"spine": (8, 0, 0), "shin.L": (-10, 0, 0), "shin.R": (-10, 0, 0)})])
    create_action(armature, "gk_concede", [
        (1, {"spine": (6, 0, 0), "upper_arm.L": (12, 0, -12), "upper_arm.R": (12, 0, 12)}),
        (20, {"spine": (-8, 0, 0), "head": (12, 0, 0), "upper_arm.L": (30, 0, -28), "upper_arm.R": (30, 0, 28), "forearm.L": (24, 0, -16), "forearm.R": (24, 0, 16)}),
    ])
    clear_pose(armature)


def export_glb(path: str) -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        export_animations=True,
        export_nla_strips=False,
        export_apply=True,
    )


def main() -> None:
    args = parse_args()
    input_path = Path(args.input).resolve()
    output_path = Path(args.output).resolve()
    if not input_path.exists():
        raise FileNotFoundError(input_path)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    clear_scene()
    import_glb(str(input_path))
    meshes = scene_meshes()
    if not meshes:
        raise RuntimeError("No meshes found in imported GLB")
    normalize_model(meshes, args.height)
    armature = create_armature(args.height)
    bind_meshes(meshes, armature, args.height)
    create_placeholder_actions(armature)
    export_glb(str(output_path))
    print(f"Wrote rigged goalkeeper prototype: {output_path}")


if __name__ == "__main__":
    main()
