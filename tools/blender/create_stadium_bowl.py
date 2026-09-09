"""Build Flowball's oval stadium bowl from the approved revamp references.

Usage:
    blender --background --python tools/blender/create_stadium_bowl.py -- \
      --output-dir "G:/Coding/Flowball III/assets/models" \
      --assets-dir "G:/Coding/Flowball III/assets/Inputs RAW/REvamp/generated"

The stadium is an ellipse around the 68 x 105 m pitch, not a rectangular stand
and not a texture-wrapped cylinder. Crowd surfaces, structural rings, and LED
boards have separate geometry. Each LED board is a short tangent segment with
local UVs, so FOOTBALL remains readable instead of stretching or reversing.

Coordinate contract: Blender X -> Godot X; Blender Z -> Godot Y; Blender +Y ->
Godot -Z (behind the target goal).
"""
from __future__ import annotations

import argparse
import math
import sys
from pathlib import Path

import bpy

SEGMENTS = 96
ROWS = 10

# Ellipse around the actual 68 x 105 m pitch. Inner rim leaves 9 m behind the
# goal line and 9 m at the touchlines; outer rim provides a compact, readable bowl.
INNER_A = 43.0  # X semi-axis (pitch half-width is 34 m)
INNER_B = 62.0  # Y semi-axis (pitch half-length is 52.5 m)
OUTER_A = 58.0
OUTER_B = 78.0
BASE_HEIGHT = 2.8
TOP_HEIGHT = 18.0

LED_RADIUS_OFFSET = -0.20
LED_BOTTOM = 0.95
LED_TOP = 2.20
LED_SEGMENTS = 24
LED_V_MIN = 0.40  # Text row in led_board_football.png
LED_V_MAX = 0.52

APRON_A = 43.0
APRON_B = 62.0
ROOF_OUTER_A = 61.0
ROOF_OUTER_B = 81.0


def parse_args() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser(description="Build Flowball oval stadium bowl.")
    parser.add_argument("--output-dir", type=Path, default=Path("assets/models"))
    parser.add_argument(
        "--assets-dir", type=Path,
        default=Path("assets/Inputs RAW/REvamp/generated"),
    )
    return parser.parse_args(argv)


def clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()


def load_image(path: Path):
    if not path.exists():
        raise FileNotFoundError(f"Missing required asset: {path}")
    image = bpy.data.images.load(str(path), check_existing=True)
    image.colorspace_settings.name = "sRGB"
    print(f"Loaded texture: {path.name}")
    return image


def solid_material(name: str, color: tuple[float, float, float, float], roughness: float) -> bpy.types.Material:
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    material.use_backface_culling = False
    bsdf = material.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = 0.2
    return material


def textured_material(name: str, image, roughness: float = 0.8) -> bpy.types.Material:
    material = solid_material(name, (1.0, 1.0, 1.0, 1.0), roughness)
    texture = material.node_tree.nodes.new("ShaderNodeTexImage")
    texture.image = image
    texture.extension = "REPEAT"
    texture.interpolation = "Linear"
    bsdf = material.node_tree.nodes.get("Principled BSDF")
    material.node_tree.links.new(texture.outputs["Color"], bsdf.inputs["Base Color"])
    return material


def emissive_material(name: str, image, strength: float) -> bpy.types.Material:
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    material.use_backface_culling = False
    nodes = material.node_tree.nodes
    nodes.clear()
    output = nodes.new("ShaderNodeOutputMaterial")
    emission = nodes.new("ShaderNodeEmission")
    emission.inputs["Strength"].default_value = strength
    texture = nodes.new("ShaderNodeTexImage")
    texture.image = image
    texture.extension = "REPEAT"
    texture.interpolation = "Linear"
    material.node_tree.links.new(texture.outputs["Color"], emission.inputs["Color"])
    material.node_tree.links.new(emission.outputs["Emission"], output.inputs["Surface"])
    return material


def ellipse_point(a: float, b: float, angle: float, z: float) -> tuple[float, float, float]:
    return (a * math.cos(angle), b * math.sin(angle), z)


def add_mesh(
    name: str,
    vertices: list[tuple[float, float, float]],
    faces: list[tuple[int, ...]],
    material: bpy.types.Material,
    uv_by_vertex: list[tuple[float, float]] | None = None,
) -> bpy.types.Object:
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    if uv_by_vertex:
        mesh.uv_layers.new(name="UVMap")
        for polygon in mesh.polygons:
            for loop_index in polygon.loop_indices:
                vertex_index = mesh.loops[loop_index].vertex_index
                mesh.uv_layers[0].data[loop_index].uv = uv_by_vertex[vertex_index]
    mesh.materials.append(material)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return obj


def add_cube(
    name: str, location: tuple[float, float, float], dimensions: tuple[float, float, float],
    material: bpy.types.Material,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material)
    return obj


def build_ellipse_surface(
    name: str,
    profiles: list[tuple[float, float, float]],  # (a, b, z), inner/bottom -> outer/top
    material: bpy.types.Material,
    u_repeats: float = 1.0,
) -> bpy.types.Object:
    """Build a closed elliptical surface with UVs continuous around its perimeter."""
    vertices: list[tuple[float, float, float]] = []
    uvs: list[tuple[float, float]] = []
    faces: list[tuple[int, int, int, int]] = []
    rings = len(profiles)

    for ring, (a, b, z) in enumerate(profiles):
        v = ring / (rings - 1)
        for segment in range(SEGMENTS + 1):
            angle = math.tau * segment / SEGMENTS
            vertices.append(ellipse_point(a, b, angle, z))
            uvs.append((u_repeats * segment / SEGMENTS, v))

    for ring in range(rings - 1):
        start = ring * (SEGMENTS + 1)
        next_start = (ring + 1) * (SEGMENTS + 1)
        for segment in range(SEGMENTS):
            faces.append((
                start + segment,
                next_start + segment,
                next_start + segment + 1,
                start + segment + 1,
            ))
    return add_mesh(name, vertices, faces, material, uvs)


def build_annular_band(
    name: str,
    inner_a: float, inner_b: float, outer_a: float, outer_b: float, z: float,
    material: bpy.types.Material,
) -> bpy.types.Object:
    """Horizontal elliptical strip used for stair/readability bands and roof rim."""
    vertices: list[tuple[float, float, float]] = []
    faces: list[tuple[int, int, int, int]] = []
    for segment in range(SEGMENTS + 1):
        angle = math.tau * segment / SEGMENTS
        vertices.append(ellipse_point(inner_a, inner_b, angle, z))
        vertices.append(ellipse_point(outer_a, outer_b, angle, z))
    for segment in range(SEGMENTS):
        i = segment * 2
        faces.append((i, i + 1, i + 3, i + 2))
    return add_mesh(name, vertices, faces, material)


def build_apron(material: bpy.types.Material) -> bpy.types.Object:
    """Green ellipse beneath the pitch/goal clearance; replaces the old grey void."""
    vertices = [(0.0, 0.0, -0.05)]
    for segment in range(SEGMENTS):
        vertices.append(ellipse_point(APRON_A, APRON_B, math.tau * segment / SEGMENTS, -0.05))
    faces = [tuple(range(1, SEGMENTS + 1))]
    return add_mesh("StadiumApron", vertices, faces, material)


def build_led_boards(led_material: bpy.types.Material) -> list[bpy.types.Object]:
    """Build short flat tangential signs with stable local UV orientation.

    U follows -tangent around the ellipse. At the target-end board this maps
    left->right from the free-kick camera, making FOOTBALL readable.
    """
    boards: list[bpy.types.Object] = []
    for index in range(LED_SEGMENTS):
        angle = math.tau * (index + 0.5) / LED_SEGMENTS
        next_angle = math.tau * (index + 1.0) / LED_SEGMENTS
        previous_angle = math.tau * index / LED_SEGMENTS

        # Segment endpoints on the LED ellipse. Endpoints, rather than a curve,
        # keep each sign flat and preserve its source-image aspect ratio.
        a = INNER_A + LED_RADIUS_OFFSET
        b = INNER_B + LED_RADIUS_OFFSET
        p0 = ellipse_point(a, b, previous_angle, LED_BOTTOM)
        p1 = ellipse_point(a, b, next_angle, LED_BOTTOM)
        p2 = ellipse_point(a, b, next_angle, LED_TOP)
        p3 = ellipse_point(a, b, previous_angle, LED_TOP)

        # Reverse local U so the target stand (+Y in Blender) reads left->right
        # from the gameplay camera. Every segment uses the same clockwise order.
        boards.append(add_mesh(
            f"LEDBoard_{index:02d}",
            [p1, p0, p3, p2],
            [(0, 1, 2, 3)],
            led_material,
            [
                (0.0, LED_V_MIN),
                (1.0, LED_V_MIN),
                (1.0, LED_V_MAX),
                (0.0, LED_V_MAX),
            ],
        ))
    return boards


def build_roof_lights(
    structure: bpy.types.Material,
    floodlight: bpy.types.Material,
) -> list[bpy.types.Object]:
    """Place twelve roofline banks following the oval, matching the mockup's crown."""
    objects: list[bpy.types.Object] = []
    for index in range(12):
        angle = math.tau * index / 12
        x, y, _ = ellipse_point(OUTER_A + 0.5, OUTER_B + 0.5, angle, TOP_HEIGHT + 2.0)
        # Tangential housing: long side follows the ellipse tangent.
        housing = add_cube(
            f"FloodlightHousing_{index:02d}", (x, y, TOP_HEIGHT + 2.0),
            (7.5, 1.0, 1.5), structure,
        )
        tangent_angle = angle + math.pi / 2
        housing.rotation_euler[2] = tangent_angle

        # Small inward-facing emissive plane just below the housing.
        normal_x = -math.cos(angle)
        normal_y = -math.sin(angle)
        half_tangent_x = -math.sin(angle) * 3.2
        half_tangent_y = math.cos(angle) * 3.2
        centre = (x + normal_x * 0.5, y + normal_y * 0.5)
        z0, z1 = TOP_HEIGHT + 1.1, TOP_HEIGHT + 3.0
        vertices = [
            (centre[0] - half_tangent_x, centre[1] - half_tangent_y, z0),
            (centre[0] + half_tangent_x, centre[1] + half_tangent_y, z0),
            (centre[0] + half_tangent_x, centre[1] + half_tangent_y, z1),
            (centre[0] - half_tangent_x, centre[1] - half_tangent_y, z1),
        ]
        objects.append(housing)
        objects.append(add_mesh(
            f"Floodlight_{index:02d}", vertices, [(0, 1, 2, 3)], floodlight,
            [(0, 0), (1, 0), (1, 1), (0, 1)],
        ))
    return objects


def join_objects(objects: list[bpy.types.Object]) -> bpy.types.Object:
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    stadium = bpy.context.object
    stadium.name = "OvalStadium"
    return stadium


def build_stadium(assets_dir: Path) -> bpy.types.Object:
    crowd = textured_material("Crowd", load_image(assets_dir / "crowd_tile.png"))
    led = emissive_material("LED", load_image(assets_dir / "led_board_football.png"), 1.8)
    floodlight = emissive_material("Floodlight", load_image(assets_dir / "floodlight_bank.png"), 6.0)
    structure = solid_material("Structure", (0.025, 0.045, 0.080, 1.0), 0.78)
    grass_apron = solid_material("ApronGrass", (0.035, 0.16, 0.045, 1.0), 0.95)

    objects: list[bpy.types.Object] = [build_apron(grass_apron)]

    # Crowd bowl rises outward around the oval field.
    objects.append(build_ellipse_surface(
        "CrowdBowl",
        [(INNER_A, INNER_B, BASE_HEIGHT), (OUTER_A, OUTER_B, TOP_HEIGHT)],
        crowd,
        u_repeats=18.0,
    ))
    # Dark inner wall beneath boards and a dark outer shell keep the silhouette tidy.
    objects.append(build_ellipse_surface(
        "InnerWall",
        [(INNER_A, INNER_B, 0.0), (INNER_A, INNER_B, BASE_HEIGHT)],
        structure,
    ))
    objects.append(build_ellipse_surface(
        "OuterWall",
        [(OUTER_A, OUTER_B, 0.0), (OUTER_A, OUTER_B, TOP_HEIGHT)],
        structure,
    ))

    # Thin horizontal bands divide crowd levels and make the raked geometry read as seats.
    for row in range(1, ROWS):
        t = row / ROWS
        a = INNER_A + (OUTER_A - INNER_A) * t
        b = INNER_B + (OUTER_B - INNER_B) * t
        z = BASE_HEIGHT + (TOP_HEIGHT - BASE_HEIGHT) * t
        objects.append(build_annular_band(
            f"SeatBand_{row:02d}", a - 0.22, b - 0.22, a + 0.22, b + 0.22, z, structure,
        ))

    # Roof rim follows the same ellipse. No rectangular canopy blocks.
    objects.append(build_annular_band(
        "RoofRim", OUTER_A - 0.6, OUTER_B - 0.6, ROOF_OUTER_A, ROOF_OUTER_B,
        TOP_HEIGHT + 1.0, structure,
    ))
    objects += build_led_boards(led)
    objects += build_roof_lights(structure, floodlight)
    return join_objects(objects)


def export(stadium: bpy.types.Object, path: Path) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    stadium.select_set(True)
    bpy.context.view_layer.objects.active = stadium
    bpy.ops.export_scene.gltf(
        filepath=str(path), export_format="GLB", use_selection=True,
        export_apply=True, export_materials="EXPORT",
    )
    print(f"Exported: {path}")


def main() -> None:
    args = parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)
    clear_scene()
    export(build_stadium(args.assets_dir), args.output_dir / "stadium_bowl.glb")
    print("Done: oval stadium bowl generated from revamp references.")


if __name__ == "__main__":
    main()
