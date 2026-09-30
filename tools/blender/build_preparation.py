"""Build the concept-matched stadium and round ball, with editable packed textures.

Blender Z-up, meters. Visuals only: gameplay physics stay in the sandbox.
Run: blender --background --python tools/blender/build_preparation.py
"""
from pathlib import Path
import bpy, math, json
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/models/preparation'
SOURCE = ROOT / 'art/blender/preparation'
TEXTURES = ROOT / 'assets/textures/preparation'
LAYOUT = json.loads((ROOT / 'assets/models/preparation/layout.json').read_text(encoding='utf-8'))
for folder in [OUT, SOURCE]: folder.mkdir(parents=True, exist_ok=True)
bpy.context.preferences.filepaths.save_version = 0

def clean():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    bpy.context.scene.unit_settings.system = 'METRIC'

def mat(name, color, texture=None, emission=0):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    bs = m.node_tree.nodes.get('Principled BSDF')
    bs.inputs['Base Color'].default_value = (*color, 1)
    bs.inputs['Roughness'].default_value = .82
    if emission:
        bs.inputs['Emission Color'].default_value = (*color, 1)
        bs.inputs['Emission Strength'].default_value = emission
    if texture:
        tex = m.node_tree.nodes.new('ShaderNodeTexImage')
        tex.image = bpy.data.images.load(str(TEXTURES / texture))
        tex.image.pack()
        m.node_tree.links.new(tex.outputs['Color'], bs.inputs['Base Color'])
    return m

def mesh(name, verts, faces, material, uvs=None):
    data = bpy.data.meshes.new(name)
    data.from_pydata(verts, [], faces)
    data.update()
    ob = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(ob)
    data.materials.append(material)
    if uvs:
        layer = data.uv_layers.new(name='UVMap')
        for polygon in data.polygons:
            for li in polygon.loop_indices:
                layer.data[li].uv = uvs[data.loops[li].vertex_index]
    return ob

def box(name, pos, size, material):
    verts=[(x*size[0]/2,y*size[1]/2,z*size[2]/2) for x,y,z in [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]]
    ob=mesh(name,verts,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],material)
    ob.location=pos
    return ob

def rod(name, a, b, radius, material):
    delta = Vector(b)-Vector(a)
    verts=[(radius*math.cos(i*math.tau/6),radius*math.sin(i*math.tau/6),z) for z in [-delta.length/2,delta.length/2] for i in range(6)]
    faces=[tuple(reversed(range(6))),tuple(range(6,12))]+[(i,(i+1)%6,(i+1)%6+6,i+6) for i in range(6)]
    ob=mesh(name,verts,faces,material)
    ob.location=(Vector(a)+Vector(b))/2
    ob.rotation_euler=delta.to_track_quat('Z','Y').to_euler()
    return ob

def low_sphere(name, pos, radius, material):
    verts=[]; faces=[]
    for j in range(5):
        lat=math.pi*j/4
        for i in range(8):
            lon=math.tau*i/8
            verts.append((radius*math.sin(lat)*math.cos(lon),radius*math.sin(lat)*math.sin(lon),radius*math.cos(lat)))
            if j<4: faces.append((j*8+i,j*8+(i+1)%8,(j+1)*8+(i+1)%8,(j+1)*8+i))
    ob=mesh(name,verts,faces,material); ob.location=pos
    return ob

def pt(angle, depth, height):
    # Rounded rectangle: the old ellipse intersected the rectangular pitch corners.
    sine, cosine = math.sin(angle), math.cos(angle)
    power = LAYOUT['power']
    radius = (abs(sine/(LAYOUT['half_width']+depth))**power +
              abs(cosine/(LAYOUT['half_length']+depth))**power)**(-1.0/power)
    return Vector((radius*sine,radius*cosine,height))

def tangent_angle(angle, depth):
    tangent = pt(angle+.0001,depth,0)-pt(angle-.0001,depth,0)
    return math.atan2(tangent.y,tangent.x)

def strip(name, a, b, d1, h1, d2, h2, material, steps=8, u0=0, u1=1):
    verts=[]; uv=[]; faces=[]
    for i in range(steps+1):
        angle=a+(b-a)*i/steps
        verts += [pt(angle,d1,h1), pt(angle,d2,h2)]
        uv += [(u0+(u1-u0)*i/steps,0), (u0+(u1-u0)*i/steps,1)]
        if i<steps: faces.append((2*i,2*i+2,2*i+3,2*i+1))
    return mesh(name,verts,faces,material,uv)

def export(name):
    # Merge by material: deep architecture without thousands of draw calls.
    groups={}
    for ob in list(bpy.context.scene.objects):
        if ob.type=='MESH': groups.setdefault(ob.data.materials[0].name,[]).append(ob)
    for key, objects in groups.items():
        bpy.ops.object.select_all(action='DESELECT')
        for ob in objects: ob.select_set(True)
        bpy.context.view_layer.objects.active=objects[0]
        bpy.ops.object.join()
        objects[0].name=key
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/(name+'.blend')))
    bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')), export_format='GLB', export_animations=False, export_apply=True)

def stadium():
    clean()
    ink=mat('PrepInk',(.008,.018,.048))
    steel=mat('PrepSteel',(.025,.065,.16))
    blue=mat('PrepBlue',(.002,.045,.8),emission=.65)
    cyan=mat('PrepCyan',(.0,.3,.8),emission=1)
    ivory=mat('PrepIvory',(.92,.94,1),emission=.3)
    lamp=mat('PrepLamp',(1,.79,.48),emission=3)
    orange=mat('PrepOrange',(1,.23,.012),emission=.2)
    green=mat('PrepGreen',(.0,.55,.14),emission=.1)
    purple=mat('PrepPurple',(.37,.008,.8),emission=.2)
    crowd=mat('PrepCrowd',(1,1,1),'crowd_albedo.png')
    turf=mat('PrepTurf',(1,1,1),'turf_albedo.png')
    apron=mat('PrepApron',(.045,.085,.12))
    mesh('RunoffApron',[(-80,-100,.025),(80,-100,.025),(80,100,.025),(-80,100,.025)],[(0,1,2,3)],apron)
    mesh('PlayingSurface',[(-38,-56,.014),(38,-56,.014),(38,56,.014),(-38,56,.014)],[(0,1,2,3)],turf,[(0,0),(38,0),(38,56),(0,56)])
    # Three steep concentric tiers fill the camera frame like the approved concept.
    for tier,(depth,height,rise) in enumerate([(0,.8,5.4),(8,7.0,6.3),(17,14.7,6.3)]):
        strip('Concourse',0,math.tau,depth,height-.5,depth,height,ink,128)
        strip('LED',0,math.tau,depth-.05,height-.1,depth-.05,height+.7,blue,128,u1=24)
        strip('LEDTrim',0,math.tau,depth-.1,height+.72,depth-.1,height+.78,cyan,128)
        for sector in range(24):
            a=sector*math.tau/24; b=(sector+1)*math.tau/24
            strip('Terrace',a+.016,b-.016,depth+.3,height+.8,depth+7.7,height+rise,crowd,8)
            # Real steps, aisle lamps and handrails interrupt texture repetition.
            for step in range(10):
                d=depth+.35+step*.74; z=height+.6+step*rise/10
                p=pt(a,d,z)
                ob=box('AisleStep',p,(1.05,.8,.20),steel); ob.rotation_euler.z=tangent_angle(a,d)
                light=box('AisleLight',pt(a,d-.3,z+.12),(.22,.055,.07),lamp); light.rotation_euler.z=tangent_angle(a,d)
            for offset in [-.012,.012]:
                rod('AisleRail',pt(a+offset,depth+.4,height+1.4),pt(a+offset,depth+7.5,height+rise+.7),.035,steel)
            rod('FrontRail',pt(a,depth,height+1),pt(b,depth,height+1),.035,steel)
            rod('Column',pt(a,depth+7.7,height),pt(a,depth+7.7,height+rise+1.5),.14,steel)
    # Pitch-side faceted broadcast boards.
    strip('PitchBarrier',0,math.tau,-.8,.05,-.8,.9,ink,128)
    for sector in range(48):
        a=sector*math.tau/48+.007; b=(sector+1)*math.tau/48-.007
        mesh('BoardInlay',[pt(a+.009,-.85,.18),pt(b-.009,-.85,.18),pt(b,-.85,.72),pt(a,-.85,.72)],[(0,1,2,3)],[blue,blue,orange,blue,green,purple][sector%6],[(0,0),(1,0),(1,1),(0,1)])
    # Suspended roof ring, trusses and luminous ceiling panels.
    strip('Roof',0,math.tau,12,24.4,29,26.2,ink,128)
    for sector in range(32):
        a=sector*math.tau/32; b=(sector+1)*math.tau/32
        strip('RoofPanel',a+.022,b-.022,13,24.35,18,24.8,[blue,blue,orange,blue][sector%4],4)
        rod('RoofRafter',pt(a,10,24),pt(a,29,26),.13,steel)
        rod('RoofDiagonal',pt(a,10,24),pt(b,24,25.5),.08,steel)
        if sector%2==0:
            rod('LampSuspension',pt(a,12,24),pt(a,12,21),.09,steel)
            p=pt(a,12,21)
            ob=box('FloodlightHousing',p,(3.0,.65,1.35),ink); ob.rotation_euler.z=tangent_angle(a,12)
            for x in range(5):
                for z in range(2):
                    tangent=tangent_angle(a,12)
                    p=pt(a,11.62,20.65+z*.6)+Vector((math.cos(tangent),math.sin(tangent),0))*((x-2)*.56)
                    low_sphere('Lamp',p,.21,ivory)
    # Cloth banners sit inside the bowl, with actual folds and silhouette graphics.
    for angle,color in [(-.42,orange),(-.57,purple),(.46,green),(.65,blue),(2.6,orange),(3.6,green)]:
        verts=[]; faces=[]
        for j in range(9):
            for i in range(7):
                p=pt(angle+(i-3)*.009,8+.10*math.sin(i*2+j*.3),10+j*.68)
                verts.append(p)
                if i<6 and j<8:
                    k=j*7+i; faces.append((k,k+1,k+8,k+7))
        mesh('FoldedBanner',verts,faces,color)
        rod('BannerBar',pt(angle-.035,8,15.5),pt(angle+.035,8,15.5),.065,ivory)
        # Stylized running footballer as extruded dark silhouette on flag surface.
        center=pt(angle,7.8,12.7)
        direction=tangent_angle(angle,8)
        tangent=Vector((math.cos(direction),math.sin(direction),0))
        def q(x,z): return center+tangent*x+Vector((0,0,z))
        rod('BannerTorso',q(-.1,-.2),q(.12,.7),.20,ink)
        for a,b in [((-.05,-.2),(-.65,-1)),((-.65,-1),(-.9,-1.6)),((0,-.2),(.65,-.65)),((.65,-.65),(.85,-.35)),((.05,.45),(-.6,.2)),((-.6,.2),(-.8,.6)),((.05,.45),(.65,.8))]:
            rod('BannerLimb',q(*a),q(*b),.10,ink)
        low_sphere('BannerHead',q(.2,1),.26,ink)
    export('stadium')

def ball():
    clean()
    leather=mat('PrepBall',(1,1,1),'ball_albedo.png')
    bpy.ops.mesh.primitive_uv_sphere_add(segments=64,ring_count=32,radius=.11)
    ob=bpy.context.object; ob.name='MatchBall'; ob.data.materials.append(leather)
    for p in ob.data.polygons: p.use_smooth=True
    export('ball')

stadium()
if '--stadium-only' not in __import__('sys').argv:
    ball()
