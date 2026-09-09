"""Create stadium asset meshes for Flowball free-kick sandbox.

Usage:
    blender --background --python tools/blender/create_stadium_assets.py -- \
        --output-dir assets/models \
        --stadium-type full  # full | simple | seats-only

Creates:
    - stadium_seats.glb    : Curved stands geometry
    - stadium_roof.glb     : Roof structure (optional)
    - stadium_detail.glb    : Corner posts, corner flags, etc.
"""
from __future__ import annotations

import argparse
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def parse_args() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser(description="Create stadium asset meshes")
    parser.add_argument(
        "--output-dir",
        default="assets/models",
        type=Path,
    )
    parser.add_argument(
        "--stadium-type",
        default="simple",
        choices=["full", "simple", "seats-only"],
    )
    parser.add_argument(
        "--rows",
        default=15,
        type=int,
        help="Number of seat rows",
    )
    parser.add_argument(
        "--radius-inner",
        default=38.0,
        type=float,
        help="Inner radius of stands (meters)",
    )
    parser.add_argument(
        "--radius-outer",
        default=52.0,
        type=float,
        help="Outer radius of stands (meters)",
    )
    parser.add_argument(
        "--seat-width",
        default=0.55,
        type=float,
        help="Width of each seat (meters)",
    )
    parser.add_argument(
        "--row-rise",
        default=0.65,
        type=float,
        help="Height rise per row (meters)",
    )
    return parser.parse_args(argv)


# ---------------------------------------------------------------------------
# Material helpers
# ---------------------------------------------------------------------------

def mat(name: str, color: tuple, roughness: float = 0.5, metallic: float = 0.0):
    """Create a Principled BSDF material."""
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    bsdf = material.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    return material


# ---------------------------------------------------------------------------
# Seat geometry (curved stadium stands)
# ---------------------------------------------------------------------------

def create_seat_unit(width: float, depth: float, height: float) -> bpy.types.Object:
    """Create a single seat mesh (box-like with slight taper)."""
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, 0))
    seat = bpy.context.object
    seat.name = "SeatUnit"
    # Scale to seat dimensions
    seat.scale = (width, depth, height)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return seat


def create_stadium_seats(
    rows: int,
    radius_inner: float,
    radius_outer: float,
    seat_width: float,
    row_rise: float,
    seat_depth: float = 0.5,
    seat_height: float = 0.7,
) -> bpy.types.Object:
    """Create curved stadium stands using curve and bevel."""
    # Calculate arc length for seat count
    arc_span = math.pi  # 180 degrees (behind goal)
    arc_length = arc_span * (radius_inner + radius_outer) / 2
    seats_per_row = max(int(arc_length / seat_width), 4)
    
    # Create the curve for the stands
    bpy.ops.curve.primitive_bezier_curve_add()
    curve = bpy.context.object
    curve.name = "StandsCurve"
    
    # Set bezier points for a semicircle arc
    spline = curve.data.splines[0]
    spline.bezier_points[0].co = (radius_inner, 0, 0)
    spline.bezier_points[0].handle_left = (radius_inner, -radius_inner * 0.55, 0)
    spline.bezier_points[0].handle_right = (radius_inner + radius_inner * 0.55, 0, 0)
    
    # Add more points for smoother curve (need 4 points total for semicircle)
    while len(spline.bezier_points) < 4:
        spline.bezier_points.add()
    
    mid_radius = (radius_inner + radius_outer) / 2
    spline.bezier_points[1].co = (mid_radius + (radius_outer - radius_inner) * 0.3, mid_radius, 0)
    spline.bezier_points[1].handle_left = (radius_inner, mid_radius, 0)
    spline.bezier_points[1].handle_right = (radius_outer, mid_radius * 0.7, 0)
    
    spline.bezier_points[2].co = (radius_outer, radius_outer * 0.7, 0)
    spline.bezier_points[2].handle_left = (radius_outer, mid_radius * 0.9, 0)
    spline.bezier_points[2].handle_right = (radius_outer, radius_outer * 0.4, 0)
    
    spline.bezier_points[3].co = (radius_outer * 0.7, radius_outer * 0.3, 0)
    # End of arc
    
    # Extrude to full circle gradually
    # For simplicity, use a torus segment approach instead
    
    # Alternative: Create a curved plane and extrude it
    bpy.ops.object.select_all(action='DESELECT')
    bpy.ops.mesh.primitive_plane_add(size=1)
    plane = bpy.context.object
    plane.name = "StandsPlane"
    
    # Go to edit mode and create curved shape
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    
    # Subdivide for curve deformation
    bpy.ops.mesh.subdivide(number_cuts=seats_per_row * 2)
    bpy.ops.mesh.subdivide(number_cuts=rows * 2, direction='C')
    
    bpy.ops.object.mode_set(mode='OBJECT')
    
    # Now bend the plane into a curve using SimpleDeform
    bpy.ops.object.modifier_add(type='SIMPLEDEFORM')
    deform = plane.modifiers[-1]
    deform.deform_method = 'BEND'
    deform.angle = math.pi  # 180 degrees
    
    bpy.ops.object.modifier_add(type='WARP')
    warp = plane.modifiers[-1]
    warp.deform_method = 'BEND'
    warp.angle = math.pi
    
    # Add solidify for thickness
    bpy.ops.object.modifier_add(type='SOLIDIFY')
    solid = plane.modifiers[-1]
    solid.thickness = 0.1  # Seat depth
    solid.offset = 1
    
    # Apply modifiers
    bpy.ops.object.modifier_apply(modifier=deform.name)
    bpy.ops.object.modifier_apply(modifier=solid.name)
    
    # Add slight taper for realistic seat look
    bpy.ops.object.modifier_add(type='TAPER')
    taper = plane.modifiers[-1]
    taper.curve_percent_y = 0.8  # Slight taper toward top
    taper.factor = 0.3
    bpy.ops.object.modifier_apply(modifier=taper.name)
    
    # Rename and return
    plane.name = "StadiumSeats"
    return plane


def create_simple_stands(
    rows: int,
    width: float,
    depth: float,
    row_height: float,
) -> bpy.types.Object:
    """Create simple tiered stands using boxes (faster for prototype)."""
    stands = []
    
    # Materials
    seat_color = mat("seat_blue", (0.08, 0.2, 0.6, 1.0), roughness=0.6)
    aisle_color = mat("aisle_gray", (0.3, 0.3, 0.35, 1.0), roughness=0.8)
    
    for row in range(rows):
        y_pos = row * depth
        z_pos = row * row_height
        
        # Create seat row
        bpy.ops.mesh.primitive_cube_add(size=1, location=(0, y_pos, z_pos))
        row_mesh = bpy.context.object
        row_mesh.name = f"SeatRow_{row}"
        row_mesh.scale = (width, depth * 0.9, row_height * 0.8)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        
        # Assign material
        if row % 3 == 0:
            row_mesh.data.materials.append(seat_color)
        else:
            row_mesh.data.materials.append(seat_color)
        
        # Add variation for aisles (every 5 rows)
        if row > 0 and row % 5 == 0:
            # Add aisle marking
            bpy.ops.mesh.primitive_cube_add(size=1, location=(0, y_pos, z_pos - 0.05))
            aisle = bpy.context.object
            aisle.name = f"Aisle_{row}"
            aisle.scale = (width * 1.02, depth * 0.15, 0.05)
            bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
            aisle.data.materials.append(aisle_color)
        
        stands.append(row_mesh)
    
    # Join all into one object
    ctx = bpy.context
    ctx.view_layer.objects.active = stands[0]
    for mesh in stands[1:]:
        mesh.select_set(True)
    bpy.ops.object.join()
    stands[0].name = "StadiumSeats"
    
    return stands[0]


# ---------------------------------------------------------------------------
# Roof structure
# ---------------------------------------------------------------------------

def create_roof_structure(
    width: float,
    depth: float,
    height: float,
) -> bpy.types.Object:
    """Create simple roof structure (beams + supports)."""
    metal = mat("roof_metal", (0.4, 0.42, 0.45, 1.0), roughness=0.4, metallic=0.8)
    
    objects = []
    
    # Main beam (front)
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=8,
        radius=0.3,
        depth=width,
        location=(0, 0, height)
    )
    front_beam = bpy.context.object
    front_beam.name = "RoofBeam_Front"
    front_beam.rotation_euler = (0, math.radians(90), 0)
    front_beam.data.materials.append(metal)
    objects.append(front_beam)
    
    # Support columns
    num_columns = 6
    column_spacing = width / (num_columns - 1)
    for i in range(num_columns):
        x_pos = -width/2 + i * column_spacing
        bpy.ops.mesh.primitive_cylinder_add(
            vertices=8,
            radius=0.2,
            depth=height,
            location=(x_pos, 0, height/2)
        )
        column = bpy.context.object
        column.name = f"RoofColumn_{i}"
        column.data.materials.append(metal)
        objects.append(column)
    
    # Cross beams
    for z in [height * 0.3, height * 0.7]:
        bpy.ops.mesh.primitive_cylinder_add(
            vertices=8,
            radius=0.15,
            depth=width,
            location=(0, 0, z)
        )
        cross = bpy.context.object
        cross.name = "RoofCrossBeam"
        cross.rotation_euler = (0, math.radians(90), 0)
        cross.data.materials.append(metal)
        objects.append(cross)
    
    # Join into one mesh
    bpy.context.view_layer.objects.active = objects[0]
    for obj in objects[1:]:
        obj.select_set(True)
    bpy.ops.object.join()
    objects[0].name = "RoofStructure"
    
    return objects[0]


# ---------------------------------------------------------------------------
# Corner details and stadium props
# ---------------------------------------------------------------------------

def create_corner_posts(height: float = 8.0) -> bpy.types.Object:
    """Create corner posts with flags."""
    post_mat = mat("post_metal", (0.7, 0.7, 0.72, 1.0), roughness=0.35, metallic=0.9)
    flag_mat = mat("flag_fifa", (0.9, 0.9, 0.2, 1.0), roughness=0.7)
    
    posts = []
    corner_positions = [
        (-34, 52),  # Front left
        (34, 52),   # Front right
        (-34, -52), # Back left
        (34, -52),  # Back right
    ]
    
    for i, (x, y) in enumerate(corner_positions):
        # Pole
        bpy.ops.mesh.primitive_cylinder_add(
            vertices=8,
            radius=0.1,
            depth=height,
            location=(x, y, height/2)
        )
        pole = bpy.context.object
        pole.name = f"CornerPost_{i}"
        pole.data.materials.append(post_mat)
        posts.append(pole)
        
        # Flag (simple plane)
        bpy.ops.mesh.primitive_plane_add(size=1, location=(x + 0.5, y, height * 0.8))
        flag = bpy.context.object
        flag.name = f"CornerFlag_{i}"
        flag.scale = (1.2, 0.8, 1)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        flag.data.materials.append(flag_mat)
        posts.append(flag)
    
    # Join all
    bpy.context.view_layer.objects.active = posts[0]
    for post in posts[1:]:
        post.select_set(True)
    bpy.ops.object.join()
    posts[0].name = "CornerPosts"
    
    return posts[0]


def create_field_boundary(width: float = 68, length: float = 105) -> bpy.types.Object:
    """Create field boundary lines (visible from above)."""
    line_mat = mat("boundary_white", (0.95, 0.95, 0.95, 1.0), roughness=0.5)
    
    # Create a plane with lines as UV texture would be better,
    # but for now create simple border
    bpy.ops.mesh.primitive_cube_add(size=1)
    border = bpy.context.object
    border.name = "FieldBoundary"
    border.scale = (width, length, 0.02)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    border.location = (0, 0, -0.01)
    border.data.materials.append(line_mat)
    
    return border


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def clear_scene() -> None:
    """Remove all objects from scene."""
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete()


def main():
    args = parse_args()
    
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    
    clear_scene()
    
    # Materials
    seat_blue = mat("seat_blue", (0.08, 0.2, 0.6, 1.0), roughness=0.6)
    seat_red = mat("seat_red", (0.6, 0.1, 0.1, 1.0), roughness=0.6)
    metal = mat("structure_metal", (0.35, 0.38, 0.42, 1.0), roughness=0.4, metallic=0.8)
    
    if args.stadium_type == "full":
        # Full stadium with seats, roof, and details
        print("Creating full stadium...")
        
        # Main stands (behind goal)
        stands = create_simple_stands(
            rows=args.rows,
            width=68,
            depth=3.0,
            row_height=args.row_rise,
        )
        stands.location = (0, -52, 0)  # Behind goal
        stands.data.materials[0] = seat_blue
        
        # Add some red seats for visual interest
        for i in range(5):
            x = -20 + i * 8
            bpy.ops.mesh.primitive_cube_add(size=1)
            red_seat = bpy.context.object
            red_seat.name = f"RedSeatCluster_{i}"
            red_seat.scale = (4, 2.5, 0.6)
            red_seat.location = (x, -50 - (i % 3) * 0.2, 3 + (i % 3) * 0.6)
            bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
            red_seat.data.materials.append(seat_red)
        
        # Roof structure
        roof = create_roof_structure(
            width=72,
            depth=5,
            height=12,
        )
        roof.location = (0, -52, 0)
        
        # Corner posts
        corners = create_corner_posts(height=8)
        
        # Export all
        bpy.ops.export_scene.gltf(
            filepath=str(output_dir / "stadium_full.glb"),
            export_format="GLB",
            export_apply=True,
            export_materials="EXPORT",
        )
        print(f"Exported {output_dir / 'stadium_full.glb'}")
        
    elif args.stadium_type == "simple":
        # Simple stands only - good for prototype
        print("Creating simple stadium stands...")
        
        stands = create_simple_stands(
            rows=args.rows,
            width=68,
            depth=2.5,
            row_height=args.row_rise,
        )
        stands.location = (0, -52, 0)
        
        # Add corner posts
        corners = create_corner_posts(height=8)
        
        bpy.ops.export_scene.gltf(
            filepath=str(output_dir / "stadium_seats.glb"),
            export_format="GLB",
            export_apply=True,
            export_materials="EXPORT",
        )
        print(f"Exported {output_dir / 'stadium_seats.glb'}")
        
    else:  # seats-only
        print("Creating seats-only...")
        
        stands = create_simple_stands(
            rows=args.rows,
            width=68,
            depth=2.5,
            row_height=args.row_rise,
        )
        stands.location = (0, -52, 0)
        
        bpy.ops.export_scene.gltf(
            filepath=str(output_dir / "stadium_seats.glb"),
            export_format="GLB",
            export_apply=True,
            export_materials="EXPORT",
        )
        print(f"Exported {output_dir / 'stadium_seats.glb'}")
    
    print("Done!")


if __name__ == "__main__":
    main()
