import math
from pathlib import Path

import bpy
import mathutils

ROOT = Path(__file__).resolve().parents[2]
OUT_DIR = ROOT / "assets" / "models"
GOAL_OUT = OUT_DIR / "goal.glb"
GK_OUT = OUT_DIR / "goalkeeper.glb"

# IMPORTANT AXIS MODEL
# Blender is Z-up. Godot is Y-up. The glTF importer converts Blender Z to Godot Y.
# Therefore all authored vertical dimensions MUST use Blender Z, not Blender Y.
# Blender +Y becomes roughly Godot -Z, which is the shot direction in the sandbox.

def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()

def mat(name, color, roughness=0.55):
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    bsdf = material.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Roughness"].default_value = roughness
    return material

def cube(name, location, scale, material):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material)
    return obj

def cylinder_between(name, start, end, radius, material):
    start_v = mathutils.Vector(start)
    end_v = mathutils.Vector(end)
    mid = (start_v + end_v) * 0.5
    direction = end_v - start_v
    length = direction.length
    bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=radius, depth=length, location=mid)
    obj = bpy.context.object
    obj.name = name
    obj.rotation_euler = direction.to_track_quat("Z", "Y").to_euler()
    obj.data.materials.append(material)
    return obj

OUT_DIR.mkdir(parents=True, exist_ok=True)

# -----------------------------------------------------------------------------
# Goal, authored in Blender coordinates:
# X = width, Z = vertical, Y = depth away from pitch into net.
# After Godot import: X = width, Y = vertical, -Z = depth/shot direction.
# Origin: goal mouth center on ground line.
# -----------------------------------------------------------------------------
clear_scene()
white = mat("painted_white_metal", (0.92, 0.92, 0.88, 1.0), 0.42)
net = mat("net_cord_bluewhite", (0.75, 0.9, 1.0, 0.42), 0.8)
net.blend_method = "BLEND"

inside_w = 7.32
crossbar_lower_height = 2.44
depth = 1.8
post_r = 0.06
post_center_x = inside_w / 2.0 + post_r
crossbar_center_height = crossbar_lower_height + post_r

# Front frame at Blender Y=0. Professional goal dimensions are 7.32m between the inside
# of the posts and 2.44m from ground to the underside of the crossbar.
cylinder_between("LeftPost", (-post_center_x, 0, 0), (-post_center_x, 0, crossbar_lower_height), post_r, white)
cylinder_between("RightPost", (post_center_x, 0, 0), (post_center_x, 0, crossbar_lower_height), post_r, white)
cylinder_between("Crossbar", (-post_center_x, 0, crossbar_center_height), (post_center_x, 0, crossbar_center_height), post_r, white)
# Back support/net frame at Blender Y=depth.
cylinder_between("LeftBackSupport", (-post_center_x, 0, crossbar_center_height), (-post_center_x, depth, 0.08), post_r * 0.65, white)
cylinder_between("RightBackSupport", (post_center_x, 0, crossbar_center_height), (post_center_x, depth, 0.08), post_r * 0.65, white)
cylinder_between("BackBottom", (-post_center_x, depth, 0.08), (post_center_x, depth, 0.08), post_r * 0.55, white)

# Net grid.
for i in range(9):
    x = -inside_w / 2.0 + (inside_w / 8.0) * i
    cylinder_between(f"NetVertical_{i}", (x, depth, 0.12), (x, 0, crossbar_lower_height), 0.008, net)
for j in range(5):
    z = 0.18 + ((crossbar_lower_height - 0.18) / 4.0) * j
    y = depth * (1.0 - z / crossbar_lower_height * 0.35)
    cylinder_between(f"NetHorizontal_{j}", (-inside_w / 2.0, y, z), (inside_w / 2.0, y, z), 0.008, net)

bpy.ops.export_scene.gltf(filepath=str(GOAL_OUT), export_format="GLB", export_apply=True, export_materials="EXPORT")
print(f"Exported {GOAL_OUT}")

# -----------------------------------------------------------------------------
# Goalkeeper, authored upright on Blender Z axis.
# Origin at feet center. Faces Blender -Y, which imports facing roughly Godot +Z;
# rotate in Godot only if needed for visual facing, not for uprightness.
# -----------------------------------------------------------------------------
clear_scene()
kit = mat("goalkeeper_green_kit", (0.05, 0.75, 0.28, 1.0), 0.6)
skin = mat("skin_warm", (0.82, 0.58, 0.42, 1.0), 0.58)
shorts = mat("goalkeeper_black_shorts", (0.02, 0.025, 0.025, 1.0), 0.62)
gloves = mat("white_gloves", (0.96, 0.95, 0.9, 1.0), 0.5)
boots = mat("orange_boots", (1.0, 0.32, 0.05, 1.0), 0.55)

cube("Torso", (0, 0, 1.15), (0.55, 0.28, 0.75), kit)
bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=16, radius=0.18, location=(0, 0, 1.72))
head = bpy.context.object
head.name = "Head"
head.data.materials.append(skin)

cylinder_between("LeftArm", (-0.28, 0, 1.38), (-0.95, 0, 1.18), 0.065, kit)
cylinder_between("RightArm", (0.28, 0, 1.38), (0.95, 0, 1.18), 0.065, kit)
bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, radius=0.11, location=(-1.03, -0.02, 1.14))
bpy.context.object.name = "LeftGlove"
bpy.context.object.data.materials.append(gloves)
bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, radius=0.11, location=(1.03, -0.02, 1.14))
bpy.context.object.name = "RightGlove"
bpy.context.object.data.materials.append(gloves)

cube("Shorts", (0, 0, 0.73), (0.48, 0.24, 0.28), shorts)
cylinder_between("LeftLeg", (-0.16, 0, 0.58), (-0.22, 0, 0.12), 0.075, kit)
cylinder_between("RightLeg", (0.16, 0, 0.58), (0.22, 0, 0.12), 0.075, kit)
cube("LeftBoot", (-0.23, -0.04, 0.05), (0.22, 0.34, 0.08), boots)
cube("RightBoot", (0.23, -0.04, 0.05), (0.22, 0.34, 0.08), boots)

bpy.ops.export_scene.gltf(filepath=str(GK_OUT), export_format="GLB", export_apply=True, export_materials="EXPORT")
print(f"Exported {GK_OUT}")
