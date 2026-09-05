"""Create an improved prototype humanoid rig for the Flowball goalkeeper GLB.

Usage:
  blender --background --python tools/blender/rig_goalkeeper.py -- \
    --input assets/models/textured_mesh.glb \
    --output assets/models/goalkeeper_rigged.glb

This rigging pass creates a humanoid armature with improved animation clips:
  - More keyframes per clip (6-12 vs 2-3) for smoother motion
  - Bezier interpolation with proper handles for natural easing
  - Realistic goalkeeper poses (full extension, arm reaching, spine curl)
  - Secondary motion (weight shift, follow-through, anticipation)

Action names stay aligned with GoalkeeperController.gd so generated,
mocap, or hand-authored animation can replace this prototype rig
without script changes.
"""

from __future__ import annotations

import argparse
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector, Quaternion


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def parse_args() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", default="assets/models/textured_mesh.glb")
    parser.add_argument("--output", default="assets/models/goalkeeper_rigged.glb")
    parser.add_argument("--height", type=float, default=1.9)
    return parser.parse_args(argv)


# ---------------------------------------------------------------------------
# Scene helpers
# ---------------------------------------------------------------------------

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


# ---------------------------------------------------------------------------
# Armature
# ---------------------------------------------------------------------------

def create_armature(height: float) -> bpy.types.Object:
    bpy.ops.object.armature_add(enter_editmode=True, location=(0, 0, 0))
    armature = bpy.context.object
    armature.name = "GoalkeeperArmature"
    data = armature.data
    data.name = "GoalkeeperSkeleton"
    data.display_type = "STICK"

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


# ---------------------------------------------------------------------------
# Mesh binding (nearest-bone distance-based vertex groups)
# ---------------------------------------------------------------------------

def _bone_midpoints(armature: bpy.types.Object) -> dict[str, Vector]:
    """Compute midpoint of each bone in Blender coordinates from edit bones.
    Must be called while armature is in EDIT mode."""
    midpoints: dict[str, Vector] = {}
    for bone in armature.data.edit_bones:
        midpoints[bone.name] = (Vector(bone.head) + Vector(bone.tail)) * 0.5
    return midpoints


def _build_bone_positions(height: float) -> dict[str, Vector]:
    """Fallback: compute bone midpoints from height-scaled coordinates.
    Used if armature edit bones are not available."""
    h = height
    return {
        "root":       Vector((0, 0, 0.07 * h)),
        "pelvis":     Vector((0, 0, 0.55 * h)),
        "spine":      Vector((0, 0, 0.70 * h)),
        "chest":      Vector((0, 0, 0.84 * h)),
        "neck":       Vector((0, 0, 0.925 * h)),
        "head":       Vector((0, 0, 0.995 * h)),
        "upper_arm.L": Vector((-0.27 * h, 0, 0.82 * h)),
        "forearm.L":  Vector((-0.44 * h, 0, 0.74 * h)),
        "hand.L":     Vector((-0.565 * h, 0, 0.69 * h)),
        "upper_arm.R": Vector((0.27 * h, 0, 0.82 * h)),
        "forearm.R":  Vector((0.44 * h, 0, 0.74 * h)),
        "hand.R":     Vector((0.565 * h, 0, 0.69 * h)),
        "thigh.L":    Vector((-0.10 * h, 0, 0.375 * h)),
        "shin.L":     Vector((-0.105 * h, 0, 0.165 * h)),
        "foot.L":     Vector((-0.10 * h, -0.07 * h, 0.045 * h)),
        "thigh.R":    Vector((0.10 * h, 0, 0.375 * h)),
        "shin.R":     Vector((0.105 * h, 0, 0.165 * h)),
        "foot.R":     Vector((0.10 * h, -0.07 * h, 0.045 * h)),
    }


def closest_bones(co: Vector, bone_positions: dict[str, Vector], k: int = 3) -> list[tuple[str, float]]:
    """Find k nearest bones with smooth weights based on inverse distance.

    Fast path: uses squared distances and keeps only the k smallest via a
    linear scan instead of sorting the full bone set per vertex. Called once
    per vertex, so avoiding sqrt + full sort is a large win for dense meshes.
    """
    best: list[tuple[str, float]] = []  # (name, dist_squared), keep k smallest
    for name, pos in bone_positions.items():
        d2 = (co - pos).length_squared
        if len(best) < k:
            best.append((name, d2))
            best.sort(key=lambda x: x[1])
        elif d2 < best[-1][1]:
            # Replace the largest of the current k with this closer one
            best[-1] = (name, d2)
            best.sort(key=lambda x: x[1])

    # Convert squared distances to smooth inverse-distance weights
    weights = []
    total = 0.0
    for name, d2 in best:
        w = 1.0 / (d2 + 1e-6)
        weights.append(w)
        total += w
    return [(name, w / total) for (name, _), w in zip(best, weights)]


def bind_meshes(meshes: list[bpy.types.Object], armature: bpy.types.Object, height: float) -> None:
    # Freeze each mesh's world transform into its vertices so the mesh sits at
    # the armature origin with no residual offset. normalize_model leaves the
    # mesh with a location offset (z ~0.97) that would otherwise be applied on
    # top of the skinning in Godot and either float or sink the keeper.
    for mesh in meshes:
        mesh.data.transform(mesh.matrix_world)
        mesh.location = (0.0, 0.0, 0.0)
        mesh.rotation_euler = (0.0, 0.0, 0.0)
        mesh.scale = (1.0, 1.0, 1.0)
        bpy.context.view_layer.update()

    # Bone midpoints in armature-local space.
    # NOTE: do NOT use _bone_midpoints() here — it requires EDIT mode
    # (armature.data.edit_bones is empty in OBJECT mode) and silently returns an
    # empty dict, which would leave every vertex unweighted and the exported GLB
    # without any skin. Use the deterministic builder instead.
    local_bone_positions = _build_bone_positions(height)

    # The armature's foot bone heads sit at z = 0.06*height (see create_armature)
    # while the frozen mesh has its feet at z=0. Drop the armature so the foot
    # bones touch the ground (z=0) and line up with the mesh feet. This keeps
    # the exported skeleton's foot joints at y=0 in Godot instead of ~1.7.
    foot_head_z = 0.06 * height
    armature.location.z -= foot_head_z
    bpy.context.view_layer.update()

    # Transform bone positions to world space
    armature_world = armature.matrix_world
    bone_positions_world = {
        name: armature_world @ pos for name, pos in local_bone_positions.items()
    }

    bone_names = [bone.name for bone in armature.data.bones]
    for mesh in meshes:
        bpy.context.view_layer.objects.active = mesh
        mesh.select_set(True)

        # Create all vertex groups first
        for name in bone_names:
            if name not in mesh.vertex_groups:
                mesh.vertex_groups.new(name=name)

        # Assign vertices to multiple bones with weights. Accumulate per-bone
        # (vertex_index, weight) pairs first, then commit each bone in one API
        # call — much faster than calling vertex_groups[].add() per vertex.
        bone_weights: dict[str, list[tuple[int, float]]] = {}
        for vertex in mesh.data.vertices:
            world = mesh.matrix_world @ vertex.co
            weighted_bones = closest_bones(world, bone_positions_world, k=3)
            for bone_name, weight in weighted_bones:
                bone_weights.setdefault(bone_name, []).append((vertex.index, weight))
        for bone_name, pairs in bone_weights.items():
            vg = mesh.vertex_groups[bone_name]
            for vindex, weight in pairs:
                vg.add([vindex], weight, "REPLACE")

        modifier = mesh.modifiers.new("GoalkeeperArmature", "ARMATURE")
        modifier.object = armature
        # Reparent the mesh from its import wrapper ("world") onto the armature.
        # Directly assigning parent when already parented is ignored by Blender,
        # so clear it first.
        mesh.parent = None
        mesh.parent = armature
        mesh.select_set(False)


# Animation helpers — improved with Bezier handles and more keyframes
# ---------------------------------------------------------------------------

def _r(degrees: float) -> tuple[float, float, float]:
    """Shorthand: degrees -> radians tuple (x, y, z)."""
    return (math.radians(degrees), 0.0, 0.0)


def _rz(degrees: float) -> tuple[float, float, float]:
    """Rotation around Z axis only."""
    return (0.0, 0.0, math.radians(degrees))


def _rx(degrees: float) -> tuple[float, float, float]:
    """Rotation around X axis only."""
    return (math.radians(degrees), 0.0, 0.0)


def _loc(x: float = 0.0, y: float = 0.0, z: float = 0.0) -> dict:
    """Location offset on the root bone (whole-body dive displacement).

    Returns a bone->location dict so it can be passed directly as the
    `locations` argument of set_pose/create_action.
    """
    return {"root": (x, y, z)}


def _empty() -> dict:
    """Empty pose dict — all bones at rest."""
    return {}


def clear_pose(armature: bpy.types.Object) -> None:
    for bone in armature.pose.bones:
        bone.rotation_mode = "XYZ"
        bone.rotation_euler = (0, 0, 0)
        bone.location = (0, 0, 0)
        bone.scale = (1, 1, 1)


def set_pose(armature: bpy.types.Object, rotations: dict[str, tuple[float, float, float]],
             locations: dict[str, tuple[float, float, float]] | None = None) -> None:
    """Set bone rotations and optional locations for a pose."""
    for bone_name, rotation in rotations.items():
        bone = armature.pose.bones.get(bone_name)
        if bone is None:
            continue
        bone.rotation_mode = "XYZ"
        bone.rotation_euler = tuple(math.radians(v) if isinstance(v, (int, float)) else v for v in rotation)
    if locations:
        for bone_name, location in locations.items():
            bone = armature.pose.bones.get(bone_name)
            if bone is None:
                continue
            bone.location = location


def keyframe_pose(armature: bpy.types.Object, frame: int,
                  handle_type: str = "AUTO_CLAMPED") -> None:
    """Keyframe all bone transforms at the given frame with Bezier handles."""
    bpy.context.scene.frame_set(frame)
    for bone in armature.pose.bones:
        # Keyframe rotation
        bone.keyframe_insert(data_path="rotation_euler", frame=frame)
        # Keyframe location
        bone.keyframe_insert(data_path="location", frame=frame)
        # Set Bezier interpolation on all fcurves for this bone
        if armature.animation_data and armature.animation_data.action:
            for fcurve in armature.animation_data.action.fcurves:
                if bone.name in fcurve.data_path:
                    for kp in fcurve.keyframe_points:
                        kp.interpolation = "BEZIER"
                        kp.handle_left_type = handle_type
                        kp.handle_right_type = handle_type


def set_fcurve_interpolation(action: bpy.types.Action, interpolation: str = "BEZIER",
                             handle_type: str = "AUTO_CLAMPED") -> None:
    """Set interpolation and handle type for all fcurves in an action."""
    for fcurve in action.fcurves:
        for kp in fcurve.keyframe_points:
            kp.interpolation = interpolation
            kp.handle_left_type = handle_type
            kp.handle_right_type = handle_type


def create_action(armature: bpy.types.Object, name: str,
                  keyframes: list[tuple[int, dict, dict | None]],
                  loop: bool = False) -> bpy.types.Action:
    """Create an animation action with multiple keyframes.

    Each keyframe tuple is (frame, rotations_dict, locations_dict_or_None).
    Rotations are in degrees. Locations are optional Blender-space offsets.
    """
    clear_pose(armature)
    action = bpy.data.actions.new(name)
    armature.animation_data_create()
    armature.animation_data.action = action

    for frame, rotations, locations in keyframes:
        clear_pose(armature)
        set_pose(armature, rotations, locations)
        keyframe_pose(armature, frame)

    # Apply smooth Bezier easing
    set_fcurve_interpolation(action, "BEZIER", "AUTO_CLAMPED")

    if loop:
        action.use_cyclic = True

    action.use_fake_user = True
    clear_pose(armature)
    return action


# ---------------------------------------------------------------------------
# Improved goalkeeper animations
#
# Action names MUST stay aligned with GoalkeeperController.gd.
# Rotation convention: (X_pitch, Y_yaw, Z_roll) in degrees.
#   X = forward/backward lean (positive = lean forward)
#   Y = twist
#   Z = lateral tilt (positive = tilt left for .L bones)
#
# Blender coordinate system:
#   Z = up, Y = depth (toward camera/away from pitch)
#   Godot import flips: Y = up, -Z = forward
# ---------------------------------------------------------------------------

def create_goalkeeper_animations(armature: bpy.types.Object) -> None:
    """Create all goalkeeper animation clips with improved posing and timing."""

    # ── gk_idle: gentle breathing loop ──────────────────────────────────
    # Soft sway with arm breathing. Loops.
    create_action(armature, "gk_idle", [
        (1, {
            "spine": _r(2), "chest": _r(1),
            "upper_arm.L": (0, 0, math.radians(-8)),
            "upper_arm.R": (0, 0, math.radians(8)),
            "forearm.L": _r(6), "forearm.R": _r(6),
            "shin.L": _r(-4), "shin.R": _r(-4),
        }, None),
        (15, {
            "spine": _r(-1), "chest": _r(-0.5),
            "upper_arm.L": (0, 0, math.radians(-12)),
            "upper_arm.R": (0, 0, math.radians(12)),
            "forearm.L": _r(10), "forearm.R": _r(10),
            "shin.L": _r(-7), "shin.R": _r(-7),
            "head": _r(-1),
        }, None),
        (30, {
            "spine": _r(2), "chest": _r(1),
            "upper_arm.L": (0, 0, math.radians(-8)),
            "upper_arm.R": (0, 0, math.radians(8)),
            "forearm.L": _r(6), "forearm.R": _r(6),
            "shin.L": _r(-4), "shin.R": _r(-4),
        }, None),
    ], loop=True)

    # ── gk_ready: athletic ready stance ──────────────────────────────────
    # Low center of gravity, arms out, weight on balls of feet. Loops.
    create_action(armature, "gk_ready", [
        (1, {
            "spine": _r(8), "chest": _r(4),
            "thigh.L": _r(8), "thigh.R": _r(8),
            "shin.L": _r(-14), "shin.R": _r(-14),
            "upper_arm.L": (math.radians(18), 0, math.radians(-20)),
            "upper_arm.R": (math.radians(18), 0, math.radians(20)),
            "forearm.L": (math.radians(16), 0, math.radians(-10)),
            "forearm.R": (math.radians(16), 0, math.radians(10)),
            "head": _r(-3),
        }, None),
        (12, {
            "spine": _r(10), "chest": _r(5),
            "thigh.L": _r(10), "thigh.R": _r(10),
            "shin.L": _r(-18), "shin.R": _r(-18),
            "upper_arm.L": (math.radians(22), 0, math.radians(-24)),
            "upper_arm.R": (math.radians(22), 0, math.radians(24)),
            "forearm.L": (math.radians(20), 0, math.radians(-12)),
            "forearm.R": (math.radians(20), 0, math.radians(12)),
            "head": _r(-4),
        }, None),
        (24, {
            "spine": _r(8), "chest": _r(4),
            "thigh.L": _r(8), "thigh.R": _r(8),
            "shin.L": _r(-14), "shin.R": _r(-14),
            "upper_arm.L": (math.radians(18), 0, math.radians(-20)),
            "upper_arm.R": (math.radians(18), 0, math.radians(20)),
            "forearm.L": (math.radians(16), 0, math.radians(-10)),
            "forearm.R": (math.radians(16), 0, math.radians(10)),
            "head": _r(-3),
        }, None),
    ], loop=True)

    # ── gk_anticipation: coiled spring before dive ───────────────────────
    # Crouch deeper, arms pull back, weight shifts to push-off leg.
    # Not looped — plays once before the dive.
    create_action(armature, "gk_anticipation", [
        (1, {
            "spine": _r(8), "chest": _r(4),
            "shin.L": _r(-12), "shin.R": _r(-12),
            "thigh.L": _r(6), "thigh.R": _r(6),
            "upper_arm.L": (math.radians(12), 0, math.radians(-10)),
            "upper_arm.R": (math.radians(12), 0, math.radians(10)),
        }, None),
        (6, {
            "spine": _r(14), "chest": _r(8),
            "shin.L": _r(-22), "shin.R": _r(-22),
            "thigh.L": _r(12), "thigh.R": _r(12),
            "upper_arm.L": (math.radians(20), 0, math.radians(-16)),
            "upper_arm.R": (math.radians(20), 0, math.radians(16)),
            "forearm.L": (math.radians(10), 0, math.radians(-6)),
            "forearm.R": (math.radians(10), 0, math.radians(6)),
            "head": _r(-5),
        }, None),
        (12, {
            "spine": _r(16), "chest": _r(10),
            "shin.L": _r(-26), "shin.R": _r(-26),
            "thigh.L": _r(14), "thigh.R": _r(14),
            "upper_arm.L": (math.radians(26), 0, math.radians(-24)),
            "upper_arm.R": (math.radians(26), 0, math.radians(24)),
            "forearm.L": (math.radians(14), 0, math.radians(-8)),
            "forearm.R": (math.radians(14), 0, math.radians(8)),
            "head": _r(-6),
        }, None),
    ], loop=False)

    # ── gk_dive_left: full extension dive to goalkeeper's left ────────────
    # NOTE: root bone stays at rest — CharacterBody3D tween handles body tilt.
    # Spine/chest Z-rotation creates the visual lean within the skeleton.
    create_action(armature, "gk_dive_left", [
        (1, {
            "spine": _r(6), "chest": _r(4),
            "thigh.L": _r(10), "thigh.R": _r(6),
            "shin.L": _r(-16), "shin.R": _r(-10),
            "upper_arm.L": (math.radians(14), 0, math.radians(-12)),
            "upper_arm.R": (math.radians(14), 0, math.radians(12)),
        }, None),
        (5, {
            "spine": _rz(16), "chest": _rz(10),
            "thigh.L": (0, 0, math.radians(-12)),
            "thigh.R": (0, 0, math.radians(-6)),
            "upper_arm.L": (math.radians(20), 0, math.radians(-35)),
            "forearm.L": (math.radians(10), 0, math.radians(-16)),
            "upper_arm.R": (math.radians(16), 0, math.radians(-12)),
            "shin.L": (0, 0, math.radians(-10)),
            "shin.R": (0, 0, math.radians(-4)),
        }, _loc(0, 0, 0.08)),
        (10, {
            "spine": _rz(28), "chest": _rz(18),
            "thigh.L": (0, 0, math.radians(-20)),
            "thigh.R": (0, 0, math.radians(-10)),
            "upper_arm.L": (math.radians(8), 0, math.radians(-55)),
            "forearm.L": (math.radians(4), 0, math.radians(-28)),
            "upper_arm.R": (math.radians(10), 0, math.radians(-22)),
            "forearm.R": (math.radians(6), 0, math.radians(-8)),
            "shin.L": (0, 0, math.radians(-14)),
            "shin.R": (0, 0, math.radians(-6)),
            "head": _r(4),
        }, _loc(0, 0, 0.15)),
        (16, {
            "spine": _rz(34), "chest": _rz(22),
            "thigh.L": (0, 0, math.radians(-24)),
            "thigh.R": (0, 0, math.radians(-12)),
            "upper_arm.L": (math.radians(4), 0, math.radians(-62)),
            "forearm.L": (math.radians(2), 0, math.radians(-32)),
            "upper_arm.R": (math.radians(8), 0, math.radians(-26)),
            "forearm.R": (math.radians(4), 0, math.radians(-10)),
            "shin.L": (0, 0, math.radians(-16)),
            "shin.R": (0, 0, math.radians(-8)),
            "head": _r(6),
        }, _loc(0, 0, 0.18)),
        (22, {
            "spine": _rz(30), "chest": _rz(20),
            "upper_arm.L": (math.radians(6), 0, math.radians(-58)),
            "forearm.L": (math.radians(3), 0, math.radians(-30)),
            "upper_arm.R": (math.radians(10), 0, math.radians(-24)),
            "thigh.L": (0, 0, math.radians(-22)),
            "thigh.R": (0, 0, math.radians(-11)),
            "head": _r(5),
        }, _loc(0, 0, 0.16)),
    ], loop=False)

    # ── gk_dive_right: mirror of dive_left ───────────────────────────────
    # NOTE: root bone stays at rest — CharacterBody3D tween handles body tilt.
    create_action(armature, "gk_dive_right", [
        (1, {
            "spine": _r(6), "chest": _r(4),
            "thigh.L": _r(6), "thigh.R": _r(10),
            "shin.L": _r(-10), "shin.R": _r(-16),
            "upper_arm.L": (math.radians(14), 0, math.radians(-12)),
            "upper_arm.R": (math.radians(14), 0, math.radians(12)),
        }, None),
        (5, {
            "spine": _rz(-16), "chest": _rz(-10),
            "thigh.L": (0, 0, math.radians(6)),
            "thigh.R": (0, 0, math.radians(12)),
            "upper_arm.R": (math.radians(20), 0, math.radians(35)),
            "forearm.R": (math.radians(10), 0, math.radians(16)),
            "upper_arm.L": (math.radians(16), 0, math.radians(12)),
            "shin.L": (0, 0, math.radians(4)),
            "shin.R": (0, 0, math.radians(10)),
        }, _loc(0, 0, 0.08)),
        (10, {
            "spine": _rz(-28), "chest": _rz(-18),
            "thigh.L": (0, 0, math.radians(10)),
            "thigh.R": (0, 0, math.radians(20)),
            "upper_arm.R": (math.radians(8), 0, math.radians(55)),
            "forearm.R": (math.radians(4), 0, math.radians(28)),
            "upper_arm.L": (math.radians(10), 0, math.radians(22)),
            "forearm.L": (math.radians(6), 0, math.radians(8)),
            "shin.L": (0, 0, math.radians(6)),
            "shin.R": (0, 0, math.radians(14)),
            "head": _r(4),
        }, _loc(0, 0, 0.15)),
        (16, {
            "spine": _rz(-34), "chest": _rz(-22),
            "thigh.L": (0, 0, math.radians(12)),
            "thigh.R": (0, 0, math.radians(24)),
            "upper_arm.R": (math.radians(4), 0, math.radians(62)),
            "forearm.R": (math.radians(2), 0, math.radians(32)),
            "upper_arm.L": (math.radians(8), 0, math.radians(26)),
            "forearm.L": (math.radians(4), 0, math.radians(10)),
            "shin.L": (0, 0, math.radians(8)),
            "shin.R": (0, 0, math.radians(16)),
            "head": _r(6),
        }, _loc(0, 0, 0.18)),
        (22, {
            "spine": _rz(-30), "chest": _rz(-20),
            "upper_arm.R": (math.radians(6), 0, math.radians(58)),
            "forearm.R": (math.radians(3), 0, math.radians(30)),
            "upper_arm.L": (math.radians(10), 0, math.radians(24)),
            "thigh.L": (0, 0, math.radians(11)),
            "thigh.R": (0, 0, math.radians(22)),
            "head": _r(5),
        }, _loc(0, 0, 0.16)),
    ], loop=False)

    # ── gk_dive_up: vertical jump with arm reach ─────────────────────────
    # Push off both legs, arms reach up, full body extension at peak.
    # NOTE: root bone stays at rest — CharacterBody3D tween handles body tilt.
    create_action(armature, "gk_dive_up", [
        (1, {
            "spine": _r(8), "chest": _r(4),
            "shin.L": _r(-14), "shin.R": _r(-14),
            "thigh.L": _r(8), "thigh.R": _r(8),
            "upper_arm.L": (math.radians(14), 0, math.radians(-12)),
            "upper_arm.R": (math.radians(14), 0, math.radians(12)),
        }, None),
        (5, {
            "spine": _r(4), "chest": _r(2),
            "shin.L": _r(-24), "shin.R": _r(-24),
            "thigh.L": _r(16), "thigh.R": _r(16),
            "upper_arm.L": (math.radians(-20), 0, math.radians(-14)),
            "upper_arm.R": (math.radians(-20), 0, math.radians(14)),
            "forearm.L": (math.radians(-8), 0, math.radians(-4)),
            "forearm.R": (math.radians(-8), 0, math.radians(4)),
            "head": _r(-4),
        }, _loc(0, 0, 0.06)),
        (9, {
            "spine": _r(-6), "chest": _r(-4),
            "shin.L": _r(-32), "shin.R": _r(-32),
            "thigh.L": _r(22), "thigh.R": _r(22),
            "upper_arm.L": (math.radians(-50), 0, math.radians(-16)),
            "upper_arm.R": (math.radians(-50), 0, math.radians(16)),
            "forearm.L": (math.radians(-16), 0, math.radians(-6)),
            "forearm.R": (math.radians(-16), 0, math.radians(6)),
            "head": _r(-6),
        }, _loc(0, 0, 0.14)),
        (14, {
            "spine": _r(-10), "chest": _r(-6),
            "shin.L": _r(-36), "shin.R": _r(-36),
            "thigh.L": _r(26), "thigh.R": _r(26),
            "upper_arm.L": (math.radians(-58), 0, math.radians(-18)),
            "upper_arm.R": (math.radians(-58), 0, math.radians(18)),
            "forearm.L": (math.radians(-20), 0, math.radians(-8)),
            "forearm.R": (math.radians(-20), 0, math.radians(8)),
            "head": _r(-8),
        }, _loc(0, 0, 0.20)),
        (20, {
            "spine": _r(-8), "chest": _r(-5),
            "upper_arm.L": (math.radians(-54), 0, math.radians(-17)),
            "upper_arm.R": (math.radians(-54), 0, math.radians(17)),
            "forearm.L": (math.radians(-18), 0, math.radians(-7)),
            "forearm.R": (math.radians(-18), 0, math.radians(7)),
            "shin.L": _r(-34), "shin.R": _r(-34),
            "thigh.L": _r(24), "thigh.R": _r(24),
            "head": _r(-7),
        }, _loc(0, 0, 0.18)),
    ], loop=False)

    # ── gk_land: landing impact absorption ───────────────────────────────
    # Plays after a dive. Knees bend to absorb, arms come down, body stabilizes.
    # NOTE: root bone stays at rest — CharacterBody3D tween handles body tilt.
    create_action(armature, "gk_land", [
        (1, {
            "spine": _rz(18), "chest": _rz(10),
            "upper_arm.L": (math.radians(6), 0, math.radians(-38)),
            "upper_arm.R": (math.radians(8), 0, math.radians(-12)),
            "forearm.L": (math.radians(4), 0, math.radians(-16)),
            "thigh.L": (0, 0, math.radians(-12)),
            "thigh.R": (0, 0, math.radians(-6)),
        }, _loc(0, 0, 0.10)),
        (6, {
            "spine": _rz(12), "chest": _rz(6),
            "upper_arm.L": (math.radians(12), 0, math.radians(-28)),
            "upper_arm.R": (math.radians(14), 0, math.radians(14)),
            "forearm.L": (math.radians(8), 0, math.radians(-12)),
            "forearm.R": (math.radians(8), 0, math.radians(8)),
            "thigh.L": (0, 0, math.radians(-8)),
            "thigh.R": (0, 0, math.radians(-4)),
            "shin.L": _r(-20), "shin.R": _r(-18),
        }, _loc(0, 0, 0.04)),
        (12, {
            "spine": _rz(6), "chest": _rz(3),
            "upper_arm.L": (math.radians(18), 0, math.radians(-20)),
            "upper_arm.R": (math.radians(18), 0, math.radians(18)),
            "forearm.L": (math.radians(12), 0, math.radians(-8)),
            "forearm.R": (math.radians(12), 0, math.radians(8)),
            "thigh.L": _r(14), "thigh.R": _r(14),
            "shin.L": _r(-28), "shin.R": _r(-28),
        }, _loc(0, 0, 0.01)),
        (18, {
            "spine": _r(8), "chest": _r(4),
            "upper_arm.L": (math.radians(20), 0, math.radians(-18)),
            "upper_arm.R": (math.radians(20), 0, math.radians(18)),
            "thigh.L": _r(10), "thigh.R": _r(10),
            "shin.L": _r(-18), "shin.R": _r(-18),
        }, None),
    ], loop=False)

    # ── gk_recover: stand up from ground ─────────────────────────────────
    # Transition from landing pose back to ready stance.
    create_action(armature, "gk_recover", [
        (1, {
            "spine": _r(4), "chest": _r(2),
            "thigh.L": _r(12), "thigh.R": _r(12),
            "shin.L": _r(-20), "shin.R": _r(-20),
            "upper_arm.L": (math.radians(12), 0, math.radians(-10)),
            "upper_arm.R": (math.radians(12), 0, math.radians(10)),
        }, None),
        (10, {
            "spine": _r(6), "chest": _r(3),
            "thigh.L": _r(8), "thigh.R": _r(8),
            "shin.L": _r(-14), "shin.R": _r(-14),
            "upper_arm.L": (math.radians(16), 0, math.radians(-14)),
            "upper_arm.R": (math.radians(16), 0, math.radians(14)),
            "forearm.L": (math.radians(8), 0, math.radians(-6)),
            "forearm.R": (math.radians(8), 0, math.radians(6)),
        }, None),
        (20, {
            "spine": _r(8), "chest": _r(4),
            "thigh.L": _r(6), "thigh.R": _r(6),
            "shin.L": _r(-10), "shin.R": _r(-10),
            "upper_arm.L": (math.radians(18), 0, math.radians(-16)),
            "upper_arm.R": (math.radians(18), 0, math.radians(16)),
            "forearm.L": (math.radians(12), 0, math.radians(-8)),
            "forearm.R": (math.radians(12), 0, math.radians(8)),
        }, None),
        (28, {
            "spine": _r(8), "chest": _r(4),
            "shin.L": _r(-14), "shin.R": _r(-14),
            "upper_arm.L": (math.radians(18), 0, math.radians(-20)),
            "upper_arm.R": (math.radians(18), 0, math.radians(20)),
            "forearm.L": (math.radians(16), 0, math.radians(-10)),
            "forearm.R": (math.radians(16), 0, math.radians(10)),
            "head": _r(-3),
        }, None),
    ], loop=False)

    # ── gk_concede: frustration reaction ─────────────────────────────────
    # Drop head, arms raise in frustration, then slump.
    create_action(armature, "gk_concede", [
        (1, {
            "spine": _r(6), "chest": _r(3),
            "upper_arm.L": (math.radians(12), 0, math.radians(-12)),
            "upper_arm.R": (math.radians(12), 0, math.radians(12)),
        }, None),
        (8, {
            "spine": _r(2), "chest": _r(0),
            "upper_arm.L": (math.radians(24), 0, math.radians(-22)),
            "upper_arm.R": (math.radians(24), 0, math.radians(22)),
            "forearm.L": (math.radians(16), 0, math.radians(-12)),
            "forearm.R": (math.radians(16), 0, math.radians(12)),
            "head": _r(8),
        }, None),
        (16, {
            "spine": _r(-6), "chest": _r(-3),
            "upper_arm.L": (math.radians(32), 0, math.radians(-30)),
            "upper_arm.R": (math.radians(32), 0, math.radians(30)),
            "forearm.L": (math.radians(24), 0, math.radians(-18)),
            "forearm.R": (math.radians(24), 0, math.radians(18)),
            "head": _r(14),
        }, None),
        (24, {
            "spine": _r(-8), "chest": _r(-4),
            "upper_arm.L": (math.radians(30), 0, math.radians(-28)),
            "upper_arm.R": (math.radians(30), 0, math.radians(28)),
            "forearm.L": (math.radians(22), 0, math.radians(-16)),
            "forearm.R": (math.radians(22), 0, math.radians(16)),
            "head": _r(12),
        }, None),
        (32, {
            "spine": _r(-4), "chest": _r(-2),
            "upper_arm.L": (math.radians(20), 0, math.radians(-18)),
            "upper_arm.R": (math.radians(20), 0, math.radians(18)),
            "forearm.L": (math.radians(14), 0, math.radians(-10)),
            "forearm.R": (math.radians(14), 0, math.radians(10)),
            "head": _r(6),
        }, None),
    ], loop=False)


# ---------------------------------------------------------------------------
# Export
# ---------------------------------------------------------------------------

def export_glb(path: str) -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        export_animations=True,
        export_nla_strips=False,
        export_apply=True,
    )


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

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
    create_goalkeeper_animations(armature)
    export_glb(str(output_path))
    print(f"Wrote improved goalkeeper rig: {output_path}")


if __name__ == "__main__":
    main()
