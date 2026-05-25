import math
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "models" / "soccer_ball.glb"
RADIUS = 0.11

# Clear scene.
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete()

# Materials.
def mat(name, color, roughness=0.55):
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    bsdf = material.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Roughness"].default_value = roughness
    return material

white_mat = mat("panel_white", (0.92, 0.90, 0.84, 1.0), 0.68)
black_mat = mat("panel_black", (0.015, 0.014, 0.012, 1.0), 0.7)
seam_mat = mat("rubber_seams", (0.02, 0.018, 0.016, 1.0), 0.8)

# Main ball.
bpy.ops.mesh.primitive_uv_sphere_add(segments=96, ring_count=48, radius=RADIUS, location=(0, 0, 0))
ball = bpy.context.object
ball.name = "SoccerBall_WhitePanels"
ball.data.materials.append(white_mat)

# Add subtle black seam rings so the ball reads well from distance.
def add_torus(name, rotation, major_radius=RADIUS * 1.002, minor_radius=RADIUS * 0.006):
    bpy.ops.mesh.primitive_torus_add(
        major_radius=major_radius,
        minor_radius=minor_radius,
        major_segments=144,
        minor_segments=8,
        location=(0, 0, 0),
        rotation=rotation,
    )
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(seam_mat)
    return obj

add_torus("EquatorSeam", (0, 0, 0))
add_torus("VerticalSeam_A", (math.pi / 2, 0, 0))
add_torus("VerticalSeam_B", (0, math.pi / 2, 0))
add_torus("DiagonalSeam_A", (math.pi / 3, math.pi / 5, 0))
add_torus("DiagonalSeam_B", (-math.pi / 3, math.pi / 5, 0))

# Black pentagonal patches placed on icosahedron directions.
phi = (1 + math.sqrt(5)) / 2
raw_dirs = [
    (0, 1, phi), (0, -1, phi), (0, 1, -phi), (0, -1, -phi),
    (1, phi, 0), (-1, phi, 0), (1, -phi, 0), (-1, -phi, 0),
    (phi, 0, 1), (-phi, 0, 1), (phi, 0, -1), (-phi, 0, -1),
]

def add_patch(direction, index):
    normal = Vector(direction).normalized()
    center = normal * (RADIUS * 1.012)
    # A filled 5-vertex circle acts as a pentagonal decal hovering just above the sphere.
    bpy.ops.mesh.primitive_circle_add(vertices=5, radius=RADIUS * 0.235, fill_type="TRIFAN", location=center)
    patch = bpy.context.object
    patch.name = f"BlackPentagon_{index:02d}"
    patch.data.materials.append(black_mat)
    # Circle starts facing +Z; rotate +Z to target normal.
    patch.rotation_euler = normal.to_track_quat("Z", "Y").to_euler()
    return patch

for i, direction in enumerate(raw_dirs):
    add_patch(direction, i)

# Add a few smaller dark hex-like panels between pentagons for stronger soccer-ball readability.
hex_dirs = [
    (1, 1, 1), (-1, 1, 1), (1, -1, 1), (-1, -1, 1),
    (1, 1, -1), (-1, 1, -1), (1, -1, -1), (-1, -1, -1),
]
for i, direction in enumerate(hex_dirs):
    normal = Vector(direction).normalized()
    center = normal * (RADIUS * 1.014)
    bpy.ops.mesh.primitive_circle_add(vertices=6, radius=RADIUS * 0.18, fill_type="TRIFAN", location=center)
    patch = bpy.context.object
    patch.name = f"BlackHex_{i:02d}"
    patch.data.materials.append(black_mat)
    patch.rotation_euler = normal.to_track_quat("Z", "Y").to_euler()

# Parent visuals under an empty for clean import.
empty = bpy.data.objects.new("SoccerBallVisual", None)
bpy.context.collection.objects.link(empty)
for obj in list(bpy.context.scene.objects):
    if obj != empty:
        obj.parent = empty

# Lighting/camera are not exported, but help if opened in Blender.
bpy.ops.object.light_add(type="AREA", location=(0, -1.2, 1.0))
light = bpy.context.object
light.name = "PreviewLight"
light.data.energy = 300
light.data.size = 1.0

OUT.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.export_scene.gltf(
    filepath=str(OUT),
    export_format="GLB",
    use_selection=False,
    export_apply=True,
    export_materials="EXPORT",
)
print(f"Exported {OUT}")
