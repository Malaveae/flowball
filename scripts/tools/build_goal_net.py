"""Build a realistic football goal net mesh for Flowball.

Technique: grid quads + Wireframe modifier (fast, stable in headless
Blender where the Skin modifier is pathologically slow on large grids).
Every grid edge becomes a cord with a real square cross-section; the
boundary is included; reinforced cords are added manually along the
crossbar and posts.

Conventions (must match the existing sandbox):
- Blender scene units are meters (1 unit = 1 m).
- Goal mouth: 7.32 m wide (x = -3.66..3.66), crossbar at 2.44 m (z).
- Goal line is the plane y = 0; the net hangs BEHIND the goal (Blender +y).
- Blender axes: x = width, y = net depth, z = height.
- glTF export maps Blender +y to Godot -z, so the net ends up behind the
  goal line in Godot (matches GoalNetVisual local space: depth = -z).

Realistic shape (not a box):
- Back net sloped: bottom at y=1.8 z=0, top at y=2.0 z=1.6.
- Roof slopes down from the crossbar (z=2.44) to the back top (z=1.6).
- Side nets are quadrilaterals following post, roof and back edges.
- Floor net closes the bottom from the goal line to the back bottom.
- Cord ~3 mm; reinforced cords ~8 mm along crossbar and posts.

Run from the repo root:
    blender --background --python scripts/tools/build_goal_net.py
Output: assets/models/goal_net.glb
"""

import math
import os

import bpy
import bmesh
from mathutils import Vector

# ---------------------------------------------------------------------------
# Tuning constants
# ---------------------------------------------------------------------------

HALF_WIDTH = 3.66        # goal width 7.32 m
HEIGHT = 2.44            # crossbar height
BACK_BOTTOM_Y = 1.8      # floor depth behind the goal line
BACK_TOP_Y = 2.0         # depth of the back net top edge
BACK_TOP_Z = 1.6         # height of the back net top edge
CELL = 0.12              # mesh cell size (m) - matches regulation netting
CORD_THICKNESS = 0.003   # wireframe cord cross-section (3 mm)
REINFORCE_RADIUS = 0.004  # reinforced cord radius along bar/posts (8 mm)
ALPHA = 0.6              # net opacity

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT_PATH = os.path.join(ROOT, "assets", "models", "goal_net.glb")

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for mesh in list(bpy.data.meshes):
        bpy.data.meshes.remove(mesh)
    for mat in list(bpy.data.materials):
        bpy.data.materials.remove(mat)


def build_grid(bm: bmesh.types.BMesh, point_fn, u_cells: int, v_cells: int) -> list:
    """Build a (u, v) grid of vertices, edges AND quads.

    point_fn(u, v) -> (x, y, z) with u, v in [0, 1].
    Quads are required by the Wireframe modifier.
    """
    grid = [
        [bm.verts.new(point_fn(i / u_cells, j / v_cells)) for j in range(v_cells + 1)]
        for i in range(u_cells + 1)
    ]
    for i in range(u_cells + 1):
        for j in range(v_cells):
            bm.edges.new((grid[i][j], grid[i][j + 1]))
    for i in range(u_cells):
        for j in range(v_cells + 1):
            bm.edges.new((grid[i][j], grid[i + 1][j]))
    for i in range(u_cells):
        for j in range(v_cells):
            bm.faces.new((grid[i][j], grid[i][j + 1], grid[i + 1][j + 1], grid[i + 1][j]))
    return grid


def make_object(name: str, bm: bmesh.types.BMesh) -> bpy.types.Object:
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return obj


def apply_wireframe(obj: bpy.types.Object, thickness: float) -> None:
    """Turn every grid edge into a cord using the Wireframe modifier."""
    mod = obj.modifiers.new(name="Wire", type="WIREFRAME")
    mod.thickness = thickness
    mod.use_boundary = True
    mod.use_even_offset = True
    mod.use_replace = True
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.modifier_apply(modifier="Wire")


def build_material() -> bpy.types.Material:
    mat = bpy.data.materials.new("NetMaterial")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (0.96, 0.97, 1.0, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.85
    bsdf.inputs["Alpha"].default_value = ALPHA
    mat.blend_method = "BLEND"
    return mat


def build_reinforced_tube(bm: bmesh.types.BMesh, points, radius: float, seg: int = 8) -> None:
    """Closed tube along a polyline with per-point radius (reinforcement cord).

    points: iterable of (x, y, z). The tube has no caps (ends are hidden at
    the goal corners by construction).
    """
    pts = [Vector(p) for p in points]
    n = len(pts)
    ring = []
    for i in range(n):
        prev_ = pts[i - 1] if i > 0 else pts[0]
        nxt = pts[i + 1] if i < n - 1 else pts[n - 1]
        tangent = (nxt - prev_).normalized()
        # Pick an arbitrary perpendicular frame; refine with cross products.
        up = Vector((0.0, 0.0, 1.0))
        if abs(tangent.dot(up)) > 0.95:
            up = Vector((1.0, 0.0, 0.0))
        axis = tangent.cross(up).normalized()
        axis2 = tangent.cross(axis).normalized()
        ring.append([])
        for k in range(seg):
            angle = 2.0 * math.pi * k / seg
            offset = (axis * math.cos(angle) + axis2 * math.sin(angle)) * radius
            ring[i].append(bm.verts.new(pts[i] + offset))
    for i in range(n - 1):
        for k in range(seg):
            k2 = (k + 1) % seg
            bm.faces.new((ring[i][k], ring[i][k2], ring[i + 1][k2], ring[i + 1][k]))


# ---------------------------------------------------------------------------
# Face construction
# ---------------------------------------------------------------------------


def build_roof(bm: bmesh.types.BMesh) -> None:
    """Roof: slopes down from the crossbar to the back top edge."""
    slope = math.hypot(BACK_TOP_Y, HEIGHT - BACK_TOP_Z)

    def point(u: float, v: float):
        y = BACK_TOP_Y * u
        z = HEIGHT - (HEIGHT - BACK_TOP_Z) * u
        x = -HALF_WIDTH + 2.0 * HALF_WIDTH * v
        return (x, y, z)

    build_grid(bm, point, math.ceil(slope / CELL), math.ceil(2.0 * HALF_WIDTH / CELL))


def build_back(bm: bmesh.types.BMesh) -> None:
    """Back net: sloped plane from the floor to the back top edge."""
    slope = math.hypot(BACK_TOP_Y - BACK_BOTTOM_Y, BACK_TOP_Z)

    def point(u: float, v: float):
        y = BACK_BOTTOM_Y + (BACK_TOP_Y - BACK_BOTTOM_Y) * u
        z = BACK_TOP_Z * u
        x = -HALF_WIDTH + 2.0 * HALF_WIDTH * v
        return (x, y, z)

    build_grid(bm, point, math.ceil(slope / CELL), math.ceil(2.0 * HALF_WIDTH / CELL))


def build_floor(bm: bmesh.types.BMesh) -> None:
    """Floor net: closes the bottom from the goal line to the back bottom."""
    def point(u: float, v: float):
        y = BACK_BOTTOM_Y * u
        x = -HALF_WIDTH + 2.0 * HALF_WIDTH * v
        return (x, y, 0.0)

    build_grid(bm, point, math.ceil(BACK_BOTTOM_Y / CELL), math.ceil(2.0 * HALF_WIDTH / CELL))


def build_side(bm: bmesh.types.BMesh, side_x: float) -> None:
    """Side net: quadrilateral between post, roof edge, back edge, floor."""
    a = (side_x, 0.0, 0.0)
    b = (side_x, 0.0, HEIGHT)
    c = (side_x, BACK_TOP_Y, BACK_TOP_Z)
    d = (side_x, BACK_BOTTOM_Y, 0.0)

    def point(s: float, t: float):
        return tuple(
            (1.0 - s) * (1.0 - t) * a[i] + s * (1.0 - t) * b[i]
            + s * t * c[i] + (1.0 - s) * t * d[i]
            for i in range(3)
        )

    u_cells = math.ceil(math.hypot(BACK_TOP_Y, HEIGHT - BACK_TOP_Z) / CELL)
    v_cells = math.ceil(HEIGHT / CELL)
    build_grid(bm, point, u_cells, v_cells)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------


def main() -> None:
    clear_scene()

    objects = []
    for name, builder in (
        ("NetRoof", build_roof),
        ("NetBack", build_back),
        ("NetFloor", build_floor),
        ("NetSideLeft", lambda bm: build_side(bm, -HALF_WIDTH)),
        ("NetSideRight", lambda bm: build_side(bm, HALF_WIDTH)),
    ):
        bm = bmesh.new()
        builder(bm)
        objects.append(make_object(name, bm))

    material = build_material()
    for obj in objects:
        obj.data.materials.append(material)
        print(f"[goal_net] wireframe {obj.name} ({len(obj.data.vertices)} verts)", flush=True)
        apply_wireframe(obj, CORD_THICKNESS)
        print(f"[goal_net]   -> {len(obj.data.vertices)} verts", flush=True)

    # Reinforced cords along crossbar and posts (the visible attachment line).
    bm = bmesh.new()
    build_reinforced_tube(
        bm,
        [(-HALF_WIDTH, 0.0, HEIGHT), (HALF_WIDTH, 0.0, HEIGHT)],
        REINFORCE_RADIUS,
    )
    build_reinforced_tube(
        bm,
        [(-HALF_WIDTH, 0.0, 0.0), (-HALF_WIDTH, 0.0, HEIGHT)],
        REINFORCE_RADIUS,
    )
    build_reinforced_tube(
        bm,
        [(HALF_WIDTH, 0.0, 0.0), (HALF_WIDTH, 0.0, HEIGHT)],
        REINFORCE_RADIUS,
    )
    reinforce = make_object("NetReinforce", bm)
    reinforce.data.materials.append(material)
    objects.append(reinforce)

    # Join everything into a single mesh (single draw call in Godot).
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    final_obj = bpy.context.active_object
    final_obj.name = "GoalNet"
    final_obj.data.name = "GoalNet"

    tri_count = sum(len(p.vertices) - 2 for p in final_obj.data.polygons)
    print(f"[goal_net] joined vertices={len(final_obj.data.vertices)} triangles={tri_count}")

    os.makedirs(os.path.dirname(OUT_PATH), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=OUT_PATH, export_format="GLB")
    print(f"[goal_net] exported {OUT_PATH}")


if __name__ == "__main__":
    main()
