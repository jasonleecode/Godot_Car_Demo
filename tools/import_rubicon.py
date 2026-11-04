"""Adapt the locally supplied Wrangler mesh to the game's metre-scale animated rig.
Run: blender -b -t 4 --python tools/import_rubicon.py -- --source /path/to/package
The resulting GLB embeds its textures; the source package is only needed to rebuild.
"""
import argparse, math, os, sys
from pathlib import Path
from collections import defaultdict
import bpy
import bmesh
from mathutils import Vector, Matrix
import numpy as np
sys.path.insert(0,str(Path(__file__).resolve().parent))
from rubicon_body_panels import build as build_closed_body

parser = argparse.ArgumentParser()
parser.add_argument('--source', required=True, type=Path)
args = parser.parse_args(sys.argv[sys.argv.index('--')+1:])
source = next(args.source.rglob('*.glb'))
texture_dir = next(args.source.rglob('textures'))
out = Path(__file__).resolve().parents[1] / 'cars/Models/Rubicon/Rubicon.glb'
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(source))
original = list(bpy.context.scene.objects)
# Source faces +Y in Blender; Godot driving faces +Z (Blender -Y).
wheelbase_scale = 3.008 / (1.74020779 + 1.26895261)
body_transform = Matrix(((-1,0,0,0),(0,-wheelbase_scale,0,0.23562759*wheelbase_scale),(0,0,1,-0.417),(0,0,0,1)))

def principled(m):
    return next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')

def material(name, color, metal=0, rough=0.5, alpha=1, coat=0):
    m=bpy.data.materials.new(name);m.use_nodes=True
    p=principled(m)
    p.inputs['Base Color'].default_value=(*color,alpha)
    p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough
    p.inputs['Alpha'].default_value=alpha;p.inputs['Coat Weight'].default_value=coat
    p.inputs['Coat Roughness'].default_value=.14
    m.diffuse_color=(*color,alpha)
    if alpha<1:m.surface_render_method='DITHERED'
    return m

def image_node(m,filename,noncolor=False):
    node=m.node_tree.nodes.new('ShaderNodeTexImage')
    node.image=bpy.data.images.load(str(texture_dir/filename),check_existing=True)
    if noncolor:node.image.colorspace_settings.name='Non-Color'
    node.image.pack()
    return node

def diffuse(m,filename,alpha=False):
    tex=image_node(m,filename);p=principled(m)
    m.node_tree.links.new(tex.outputs['Color'],p.inputs['Base Color'])
    if alpha:
        m.node_tree.links.new(tex.outputs['Alpha'],p.inputs['Alpha'])
        m.surface_render_method='DITHERED'

def normal(m,filename,strength=.35):
    tex=image_node(m,filename,True);n=m.node_tree.nodes.new('ShaderNodeNormalMap')
    n.inputs['Strength'].default_value=strength
    m.node_tree.links.new(tex.outputs['Color'],n.inputs['Color'])
    m.node_tree.links.new(n.outputs['Normal'],principled(m).inputs['Normal'])

paint=material('Granite metallic clearcoat',(.105,.145,.18),.32,.27,coat=.85)
trim=material('Molded charcoal trim',(.019,.023,.027),0,.68)
roof=material('Textured hardtop',(.014,.018,.021),0,.72)
rubber=material('35 inch tire rubber',(.014,.017,.021),0,.84)
alloy=material('Satin graphite alloy',(.075,.088,.10),.78,.28)
edge=material('Machined wheel face',(.43,.46,.49),.92,.23)
steel=material('Underbody steel',(.055,.065,.073),.65,.53)
leather=material('Grained charcoal leather',(.022,.027,.031),0,.58)
red=material('Red brake calipers',(.42,.015,.012),.15,.32)
glass=material('Clear tinted glazing',(.28,.39,.43),0,.09,alpha=.13)
lens=material('Optical lens',(.65,.75,.8),0,.12,alpha=.17)
reflector=material('Reflector chrome',(.52,.56,.6),.95,.17)
white=material('LED white',(.80,.9,1),0,.20)
principled(white).inputs['Emission Color'].default_value=(.65,.8,1,1)
principled(white).inputs['Emission Strength'].default_value=.7
redlight=material('Tail lens red',(.38,.005,.009),0,.24,coat=.6)
amber=material('Amber marker',(.65,.12,.005),0,.27)
badge=material('Factory badges',(1,1,1),.35,.4);diffuse(badge,'t_logo_d.png',True)
interior_badge=material('Interior labels',(1,1,1),0,.65);diffuse(interior_badge,'t_logo_a_d.png',True);normal(interior_badge,'t_logo_a_n.png',.3)
carpet=material('Carpet',(1,1,1),0,.95);diffuse(carpet,'carpet02_c_mip0.png');normal(carpet,'carpet02_nm_mip0.png',.4)
cloth=material('Seat fabric',(1,1,1),0,.85);diffuse(cloth,'cloth09.png')
dashboard=material('Dashboard molded grain',(.025,.03,.035),0,.65);normal(dashboard,'alck_nm.png',.28)
engine=material('Engine casting',(.10,.11,.12),.3,.67);normal(engine,'t_engine_n.png',.5)
display=material('Instrument display',(1,1,1),0,.35);diffuse(display,'T_Dashboard_E_1.png')
meshgrid=material('Speaker grille',(1,1,1),0,.7);diffuse(meshgrid,'t_grid_a_d.png',True)
ventgrid=material('Vent perforations',(1,1,1),.15,.7);diffuse(ventgrid,'t_grid_d_d.png',True)
spare_tire=material('Spare tire',(1,1,1),0,.85);diffuse(spare_tire,'t_tyre_d.png')
normal(rubber,'wheel_01_nm.png',.18)

# Numerically authored, seamless microstructure. No photographic/generated art is needed.
# Explicit UVs and embedded normal/roughness maps survive GLB export into Godot.
def grain(m,seed,roughness,strength,tiles):
    print("DETAIL",m.name,flush=True)
    rng=np.random.default_rng(seed);size=256
    freq=np.fft.fftfreq(size)
    kx,ky=np.meshgrid(freq,freq)
    field=np.fft.ifft2(np.fft.fft2(rng.normal(size=(size,size)))*np.exp(-(kx*kx+ky*ky)*18)).real
    field=(field-field.mean())/(field.std()+1e-6)
    dx=(np.roll(field,-1,axis=1)-np.roll(field,1,axis=1))*.12
    dy=(np.roll(field,-1,axis=0)-np.roll(field,1,axis=0))*.12
    normals=np.stack((-dx,-dy,np.ones_like(dx)),axis=-1)
    normals/=np.linalg.norm(normals,axis=-1,keepdims=True)
    for kind in ['Normal','Roughness']:
        image=bpy.data.images.new(m.name+' '+kind,width=size,height=size,alpha=True)
        image.colorspace_settings.name='Non-Color'
        pixels=np.ones((size,size,4),dtype=np.float32)
        if kind=='Normal':pixels[:,:,:3]=normals*.5+.5
        else:pixels[:,:,:3]=np.clip(roughness+field[:,:,None]*.035,.05,.97)
        image.pixels.foreach_set(pixels.ravel());image.pack()
        tex=m.node_tree.nodes.new('ShaderNodeTexImage');tex.image=image
        uv=m.node_tree.nodes.new('ShaderNodeUVMap');uv.uv_map='DetailUV'
        m.node_tree.links.new(uv.outputs['UV'],tex.inputs['Vector'])
        p=principled(m)
        if kind=='Normal':
            n=m.node_tree.nodes.new('ShaderNodeNormalMap');n.inputs['Strength'].default_value=strength;n.uv_map='DetailUV'
            m.node_tree.links.new(tex.outputs['Color'],n.inputs['Color']);m.node_tree.links.new(n.outputs['Normal'],p.inputs['Normal'])
        else:m.node_tree.links.new(tex.outputs['Color'],p.inputs['Roughness'])
    m['detail_tiles']=tiles
for m,seed,roughness,strength,tiles in [(paint,4,.27,.055,4),(trim,5,.68,.22,8),(roof,6,.72,.30,7),(leather,7,.58,.28,6)]:
    grain(m,seed,roughness,strength,tiles)

def empty(name,pos=(0,0,0),parent=None):
    o=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(o);o.location=pos;o.parent=parent;return o
body=empty('Body')
wheel_pivots={};rotors={}
for label,x,y in [('FL',.875,-1.504),('FR',-.875,-1.504),('RL',.875,1.504),('RR',-.875,1.504)]:
    wheel_pivots[label]=empty('Wheel'+label,(x,y,0))
    rotors[label]=empty('Rotor'+label,parent=wheel_pivots[label])

mapping={'black.038':trim,'black.037':steel,'black.039':reflector,'darkgrey2':steel,
 'vehicle_generic_smallspecmap_PRIMARY.004':paint,'t_logo_d':badge,'t_logo_a_d':interior_badge,
 't_tyre_d':spare_tire,'t_rim_d':alloy,'univ-glass':lens,'t_grid_d_d':ventgrid,
 't_grid_a_d':meshgrid,'T_Dashboard_E':display,'script_rt_dials_race':display,
 'script_rt_dials_race.001':display,'t_engine_d':engine,'192364':reflector,'mix2':edge,
 'vehicle_generic_smallspecmap_SECONDARY.010':red,'t_light_d':white,'t_light_d.001':redlight,
 't_light_d.002':amber,'t_light_d.003':trim,'dash_plastic01':dashboard,'carpet02_c_mip0':carpet,
 'tdu2_leather2':leather,'org_grain_004_w_INTERIOR_TRIM':leather,'cloth09':cloth,
 'cloth02_darkgrey':leather,'grey':edge,'alcantara_diff_DASHBOARD':dashboard,
 't_cabin_d':trim,'t_grid_c_d':trim,'t_grid_f_d':trim,'vehicle_licenseplate':trim,
 'vehicle_generic_smallspecmap':reflector,'t_grid_b_d':trim}

# Remove static suspension/axles; the game animates its complete running gear instead.
seen_faces=set()
remove={'Object_461','Object_396','Object_397','Object_399','Object_400','Object_402','Object_403','Object_405','Object_406'}
for o in original:
    if o.type!='MESH':continue
    print('ADAPT',o.name,flush=True)
    if o.name in remove:
        bpy.data.objects.remove(o,do_unlink=True);continue
    world=o.matrix_world.copy();is_wheel=o.parent and o.parent.name.startswith('wheel_lf.child')
    source_name=o.data.name
    source_mat=o.data.materials[0].name
    if source_name.startswith('bonnet_t_logo_d'):
        bpy.data.objects.remove(o,do_unlink=True);continue
    o.data=o.data.copy();o.data.transform(world)
    if source_name.startswith(('chassis_','misc_e_')):
        # The supplied open 392-style body includes static rear exhaust hardware.
        # Replace that with the photograph-referenced animated-chassis assembly.
        bm=bmesh.new();bm.from_mesh(o.data)
        obsolete=[f for f in bm.faces if all(v.co.y < -1.60 and v.co.z < .62 for v in f.verts)]
        bmesh.ops.delete(bm,geom=obsolete,context='FACES')
        bm.to_mesh(o.data);bm.free()
    o.parent=None;o.matrix_world=Matrix.Identity(4)
    if is_wheel:
        # Both imported subassemblies are required: tire casing and the separate rim.
        coords=[v.co for v in o.data.vertices]
        lo=Vector([min(v[i] for v in coords) for i in range(3)])
        hi=Vector([max(v[i] for v in coords) for i in range(3)])
        rear=(lo.y+hi.y)*.5<0
        left=(lo.x+hi.x)*.5<0
        label=('R' if rear else 'F')+('L' if left else 'R')
        if '[WHEEL]' in source_name:
            if label in seen_faces:
                bpy.data.objects.remove(o,do_unlink=True);continue
            seen_faces.add(label)
        center=Vector((-.85 if left else .85,-1.26895 if rear else 1.74021,.417))
        # Match a measured 35-inch envelope; stock tread is retained.
        for v in o.data.vertices:
            p=v.co-center
            v.co=Vector((-p.x,-p.y,p.z))
        o.parent=rotors[label]
        is_tire='[WHEEL]' not in source_name and (hi.z-lo.z)>.7
        mat=rubber if is_tire else edge if '[WHEEL]' in source_name else alloy
        o.name=('Tire' if is_tire else 'WheelFace' if '[WHEEL]' in source_name else 'WheelRim')+label
    else:
        o.data.transform(body_transform);o.parent=body
        mat=mapping.get(source_mat,trim)
        # Give the actual windshield dedicated glazing, distinct from lamp lenses.
        if o.name=='Object_463':mat=glass
        o.name=source_name.split('_0')[0].replace(' ','_').replace('[','').replace(']','')
    o.data.materials.clear();o.data.materials.append(mat)
    for polygon in o.data.polygons:polygon.material_index=0
    if mat==paint:
        o.data.materials.append(roof)
        for poly in o.data.polygons:
            c=poly.center
            if (c.z>1.26 and c.y>-.35) or (c.z>0.78 and c.y>1.20):poly.material_index=1
    if mat in [paint,trim,roof,leather]:
        mesh=o.data
        normals=np.empty(len(mesh.polygons)*3,dtype=np.float32)
        mesh.polygons.foreach_get('normal',normals)
        axes=np.argmax(np.abs(normals.reshape(-1,3)),axis=1)
        verts=np.empty(len(mesh.vertices)*3,dtype=np.float32)
        mesh.vertices.foreach_get('co',verts);verts=verts.reshape(-1,3)
        indices=np.empty(len(mesh.loops),dtype=np.int32)
        mesh.loops.foreach_get('vertex_index',indices)
        uv_data=np.zeros((len(mesh.loops),2),dtype=np.float32)
        tiles=mat.get('detail_tiles',6)
        for poly,axis in zip(mesh.polygons,axes):
            columns=[i for i in range(3) if i!=axis]
            start=poly.loop_start;end=start+poly.loop_total
            uv_data[start:end]=verts[indices[start:end]][:,columns]*tiles
        uv=mesh.uv_layers.new(name='DetailUV')
        uv.data.foreach_set('uv',uv_data.ravel())
    # Simplify hidden engine/interior surfaces while retaining the exterior silhouette.
    if source_mat in ['t_engine_d','dash_plastic01','tdu2_leather2','org_grain_004_w_INTERIOR_TRIM']:
        dec=o.modifiers.new('Interior game LOD','DECIMATE');dec.ratio=.52
        bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=dec.name)

# Empty imported armatures/locators have no game role (some are 443 m off origin).
for o in list(bpy.context.scene.objects):
    if o.type!='MESH' and o not in [body,*wheel_pivots.values(),*rotors.values()]:bpy.data.objects.remove(o,do_unlink=True)
# Normalize every tire independently, including its widest tread corner.
print('NORMALIZE WHEELS',flush=True)
for label,rotor in rotors.items():
    tire=next(o for o in rotor.children if o.name.startswith('Tire'))
    radius=max(math.hypot(v.co.y,v.co.z) for v in tire.data.vertices)
    for o in rotor.children:
        for v in o.data.vertices:
            v.co.y*=.4445/radius;v.co.z*=.4445/radius
        o.data.update()

# Frame, protective plates and exhaust are supplied by RubiconChassis.gd.
# Match the spare to the 35 inch running tires while retaining its bespoke carrier/rim.
for o in body.children:
    if o.type=='MESH' and (o.data.materials[0]==spare_tire or o.name.startswith('boot_t_rim')):
        coords=[v.co for v in o.data.vertices]
        center=Vector(((min(v.x for v in coords)+max(v.x for v in coords))/2,(min(v.y for v in coords)+max(v.y for v in coords))/2,(min(v.z for v in coords)+max(v.z for v in coords))/2))
        for v in o.data.vertices:
            p=v.co-center;p.x*=.889/.865;p.z*=.889/.865;v.co=center+p
build_closed_body(body,paint,trim,roof,glass,leather,steel,red)

# Merge opaque static parts by material and wheel parts by their pivot.
groups=defaultdict(list)
for o in list(bpy.context.scene.objects):
    if o.type=='MESH' and len(o.data.materials)==1:groups[(o.parent,o.data.materials[0])].append(o)
for (parent,mat),obs in groups.items():
    bpy.ops.object.select_all(action='DESELECT')
    for o in obs:o.select_set(True)
    bpy.context.view_layer.objects.active=obs[0];bpy.ops.object.join()
    merged=bpy.context.object;merged.name=mat.name.replace(' ','_')
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=str(out),export_format='GLB',export_apply=True,export_yup=True,export_materials='EXPORT',export_cameras=False,export_lights=False)
print('RUBICON_ADAPTED',out,'bytes',out.stat().st_size)
