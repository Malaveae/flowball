"""Rebuild the editable TV Arcade kit. Run with Blender --background --python.

All coordinates are meters; Blender Z-up exports as Godot Y-up. No collision
geometry is exported. Existing gameplay colliders remain authoritative.
"""
from pathlib import Path
import sys
import math
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/models/tv_arcade"
SOURCE = ROOT / "art/blender/tv_arcade"
OUT.mkdir(parents=True, exist_ok=True)
SOURCE.mkdir(parents=True, exist_ok=True)
sys.path.insert(0, str(Path(__file__).parent))
import rig_goalkeeper as rig

PALETTE = {
    "Ivory": (0.94, 0.91, 0.83, 1), "Ink": (0.022, 0.038, 0.085, 1),
    "Blue": (0.0, 0.25, 0.67, 1), "Orange": (1, 0.34, 0.035, 1),
    "Green": (0.0, 0.45, 0.16, 1), "Purple": (0.43, 0.025, 0.65, 1),
    "Skin": (0.63, 0.31, 0.16, 1), "Hair": (0.045, 0.022, 0.018, 1),
    "Grass": (0.075, 0.32, 0.12, 1), "GrassLight": (0.10, 0.39, 0.15, 1),
    "Concrete": (0.16, 0.23, 0.34, 1), "Light": (1, 0.87, 0.60, 1),
}

def clean():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    bpy.context.scene.unit_settings.system = "METRIC"
    bpy.context.scene.unit_settings.scale_length = 1

def material(name):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.diffuse_color = PALETTE[name]
    mat.use_nodes = True
    node = mat.node_tree.nodes.get("Principled BSDF")
    node.inputs["Base Color"].default_value = PALETTE[name]
    node.inputs["Roughness"].default_value = 0.85
    return mat

def finish(obj, name, color):
    obj.name = name
    obj.data.materials.append(material(color))
    return obj

def box(name, pos, size, color, bevel=0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=pos)
    obj = bpy.context.object
    obj.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        mod = obj.modifiers.new("Chamfer", "BEVEL")
        mod.width = bevel
        mod.segments = 1
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return finish(obj, name, color)

def sphere(name, pos, size, color, segments=16, rings=8):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, radius=1, location=pos)
    obj = bpy.context.object
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(obj, name, color)

def rod(name, a, b, radius, color, vertices=10):
    direction = Vector(b) - Vector(a)
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=direction.length, location=(Vector(a)+Vector(b))/2)
    obj = bpy.context.object
    obj.rotation_euler = direction.to_track_quat("Z", "Y").to_euler()
    return finish(obj, name, color)

def export(name, animate=False):
    # Keep source files outside res:// importable assets to avoid duplicate imports.
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / f"{name}.blend"))
    bpy.ops.export_scene.gltf(filepath=str(OUT / f"{name}.glb"), export_format="GLB",
        export_animations=animate, export_nla_strips=False, export_apply=True)

def ball():
    clean()
    # Truncated icosahedron: 12 pentagons and 20 hexagons, with physical seams.
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=1)
    ico = bpy.context.object
    verts = [v.co.copy() for v in ico.data.vertices]
    faces = [list(p.vertices) for p in ico.data.polygons]
    bpy.data.objects.remove(ico, do_unlink=True)
    edges = set()
    for face in faces:
        for i in range(3):
            a,b = face[i], face[(i+1)%3]
            edges.add((a,b)); edges.add((b,a))
    points = {(a,b): (verts[a]*2+verts[b])/3 for a,b in edges}
    scale = 0.11 / next(iter(points.values())).length
    patches = []
    for face in faces:
        a,b,c = face
        patches.append(([points[e]*scale for e in [(a,b),(b,a),(b,c),(c,b),(c,a),(a,c)]], "Ivory"))
    colors = ["Blue", "Orange", "Green", "Purple"]
    for a,v in enumerate(verts):
        p = [pt*scale for (i,j),pt in points.items() if i==a]
        center = sum(p,Vector())/len(p)
        normal = v.normalized(); tangent = normal.cross(Vector((0,0,1)))
        if tangent.length < 0.01: tangent = normal.cross(Vector((1,0,0)))
        tangent.normalize(); bitangent = normal.cross(tangent)
        p.sort(key=lambda pt: math.atan2((pt-center).dot(bitangent),(pt-center).dot(tangent)))
        patches.append((p,colors[a%4]))
    sphere("Seams", (0,0,0), (0.094,)*3, "Ink",32,16)
    for i,(points,color) in enumerate(patches):
        center = sum(points,Vector())/len(points)
        points = [center+(p-center)*0.96 for p in points]
        mesh = bpy.data.meshes.new(f"Panel{i}")
        if (points[1]-points[0]).cross(points[2]-points[0]).dot(center) < 0: points.reverse()
        mesh.from_pydata(points,[],[list(range(len(points)))])
        obj = bpy.data.objects.new(f"Panel{i}",mesh); bpy.context.collection.objects.link(obj)
        finish(obj,f"Panel{i}",color)
        bpy.context.view_layer.objects.active=obj; obj.select_set(True)
        obj.select_set(False)
    export("ball")

def boot():
    clean()
    sphere("Upper",(0,-0.025,0.06),(0.048,0.145,0.055),"Blue")
    box("Sole",(0,-0.025,0.022),(0.096,0.275,0.023),"Ivory",0.012)
    sphere("Heel",(0,0.063,0.09),(0.042,0.05,0.064),"Ink")
    for i in range(4):
        rod("Lace",(-0.024,0.035-i*0.017,0.112),(0.024,0.029-i*0.017,0.112),0.003,"Ivory",6)
    for x in [-0.032,0.032]:
        for y in [-0.10,-0.02,0.072]:
            rod("Stud",(x,y,0.006),(x,y,0.020),0.008,"Orange",6)
    export("boot")
    # Orthographic top view for the power/support HUD, from the same editable model.
    scene=bpy.context.scene
    scene.render.engine="BLENDER_EEVEE_NEXT"
    scene.render.resolution_x=192; scene.render.resolution_y=320; scene.render.resolution_percentage=100
    scene.render.film_transparent=True
    bpy.ops.object.camera_add(location=(0,-0.025,1))
    scene.camera=bpy.context.object; scene.camera.data.type="ORTHO"; scene.camera.data.ortho_scale=0.34
    bpy.ops.object.light_add(type="AREA", location=(-0.4,-0.4,1))
    bpy.context.object.data.energy=60; bpy.context.object.data.shape="DISK"; bpy.context.object.data.size=0.8
    scene.render.image_settings.file_format="PNG"
    scene.render.filepath=str(ROOT / "assets/ui/tv_arcade/boot.png")
    bpy.ops.render.render(write_still=True)

def person(keeper=False):
    clean()
    shirt="Orange" if keeper else "Ivory"
    box("Jersey",(0,0,1.23),(0.48,0.27,0.55),shirt,0.07)
    box("Shorts",(0,0,0.87),(0.42,0.28,0.24),"Ink",0.035)
    sphere("Neck",(0,0,1.55),(0.075,0.075,0.12),"Skin")
    sphere("Face",(0,-0.01,1.72),(0.125,0.105,0.16),"Skin")
    sphere("Hair",(0,0.013,1.80),(0.133,0.108,0.10),"Hair")
    sphere("Nose",(0,-0.112,1.72),(0.024,0.035,0.026),"Skin",8,4)
    for x in [-0.05,0.05]:
        box("Eye",(x,-0.106,1.75),(0.022,0.009,0.016),"Ink")
    for side in [-1,1]:
        x=side*0.13
        rod("Thigh",(x,0,0.88),(x,-0.005,0.54),0.09,"Skin")
        rod("Sock",(x,-0.005,0.56),(x,0.015,0.14),0.067,shirt)
        rod("SockStripe",(x,0,0.41),(x,0,0.44),0.071,"Blue")
        sphere("Shoe",(x,-0.067,0.08),(0.079,0.15,0.065),"Ink")
        shoulder=(side*0.23,0,1.43)
        elbow=(side*0.53,-0.04,1.22) if keeper else (side*0.27,0,1.12)
        wrist=(side*0.71,-0.13,1.12) if keeper else (side*0.14,-0.16,0.96)
        rod("Sleeve",shoulder,Vector(shoulder).lerp(Vector(elbow),0.48),0.10,shirt)
        rod("UpperArm",Vector(shoulder).lerp(Vector(elbow),0.45),elbow,0.066,"Skin")
        rod("Forearm",elbow,wrist,0.052,"Skin")
        sphere("Glove" if keeper else "Hand",wrist,(0.065,0.07,0.09),"Ivory" if keeper else "Skin")
    # Original bone names and animation clips are retained for the controller.
    join_materials()
    meshes=rig.scene_meshes()
    if keeper:
        armature=rig.create_armature(1.75)
        rig.bind_meshes(meshes,armature,1.75)
        rig.create_goalkeeper_animations(armature)
    export("goalkeeper" if keeper else "wall_player",keeper)


def goal():
    clean()
    for x in [-3.66,3.66]:
        rod("Post",(x,0,0),(x,0,2.44),0.06,"Ivory",16)
        rod("BackSupport",(x,0,2.44),(x,2.0,0.1),0.026,"Ink")
    rod("Crossbar",(-3.66,0,2.44),(3.66,0,2.44),0.06,"Ivory",16)
    # Sparse readable net; the original invisible net collision remains unchanged.
    for i in range(38):
        x=-3.66+i*7.32/37
        rod("BackNet",(x,2,0),(x,2,2.44),0.007,"Ivory",4)
        rod("RoofNet",(x,0,2.44),(x,2,2.44),0.007,"Ivory",4)
    for i in range(13):
        z=i*2.44/12
        rod("BackWeft",(-3.66,2,z),(3.66,2,z),0.007,"Ivory",4)
        for x in [-3.66,3.66]: rod("SideNet",(x,0,z),(x,2,z),0.007,"Ivory",4)
    for i in range(11):
        y=i*0.2
        rod("RoofWeft",(-3.66,y,2.44),(3.66,y,2.44),0.007,"Ivory",4)
        for x in [-3.66,3.66]: rod("SideWeft",(x,y,0),(x,y,2.44),0.007,"Ivory",4)
    # Join by material for a small draw-call count.
    join_materials()
    export("goal")

def join_materials():
    for color in PALETTE:
        objs=[o for o in bpy.context.scene.objects if o.type=="MESH" and o.data.materials and o.data.materials[0].name==color]
        if not objs: continue
        bpy.ops.object.select_all(action="DESELECT")
        for obj in objs: obj.select_set(True)
        bpy.context.view_layer.objects.active=objs[0]
        bpy.ops.object.join()

def stadium():
    clean()
    box("Surround",(0,0,-0.13),(90,130,0.20),"Grass")
    for i in range(14):
        box("MowingStripe",(0,-52.5+(i+0.5)*7.5,-0.012),(68,7.5,0.02),"Grass" if i%2 else "GrassLight")
    for end in [-1,1]:
        for row in range(10):
            box("EndStand",(0,end*(59+row*1.1),0.5+row*0.6),(82,1.15,1.0),"Concrete")
        box("EndFascia",(0,end*57.5,1.0),(84,0.35,1.8),"Blue")
    for side in [-1,1]:
        for row in range(10):
            box("SideStand",(side*(39+row*1.1),0,0.5+row*0.6),(1.15,112,1),"Concrete")
        box("SideFascia",(side*37.5,0,1),(0.35,113,1.8),"Purple")
    for x in [-41,41]:
        for y in [-56,56]:
            rod("FloodlightMast",(x,y,0),(x,y,16),0.18,"Ink")
            box("FloodlightHousing",(x,y,16),(4,0.5,2),"Ink",0.1)
            for dx in [-1.3,0,1.3]:
                for dz in [-0.45,0.45]: box("Lamp",(x+dx,y-0.3,16+dz),(1.05,0.12,0.62),"Light",0.1)
    join_materials()
    export("stadium")

def crowd():
    clean()
    # One low-poly multimesh prototype, recolored per instance in Godot.
    box("Shirt",(0,0,0.65),(0.40,0.25,0.55),"Ivory",0.04)
    sphere("Head",(0,0,1.05),(0.14,0.13,0.18),"Ivory",8,4)
    bpy.ops.object.select_all(action="SELECT")
    bpy.context.view_layer.objects.active=next(o for o in bpy.context.scene.objects if o.type=="MESH")
    bpy.ops.object.join()
    export("spectator")

if "--ball-only" in sys.argv:
    ball()
elif "--actors-only" in sys.argv:
    person(True); person(False)
else:
    ball(); boot(); person(True); person(False); goal(); stadium(); crowd()
print("TV ARCADE KIT COMPLETE")
