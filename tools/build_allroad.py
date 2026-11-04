"""Author a C8 A6 allroad-inspired game mesh from dimensioned surfaces.
Blender 5: blender -b -t 4 --python tools/build_allroad.py
No third-party vehicle mesh or photographs are embedded. Godot metres, +Z forward.
"""
import math
from pathlib import Path
from collections import defaultdict
import bpy, bmesh
import numpy as np
from mathutils import Vector,Matrix
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
OUT=Path(__file__).resolve().parents[1]/'cars/Models/Allroad/Allroad.glb'

def B(p):return Vector((p[0],-p[2],p[1]))
def shader(m):return next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
def material(name,color,rough=.5,metal=0,alpha=1,coat=0,emission=0):
 m=bpy.data.materials.new(name);m.use_nodes=True;p=shader(m)
 p.inputs['Base Color'].default_value=(*color,alpha);p.inputs['Roughness'].default_value=rough;p.inputs['Metallic'].default_value=metal
 p.inputs['Alpha'].default_value=alpha;p.inputs['Coat Weight'].default_value=coat;p.inputs['Coat Roughness'].default_value=.12
 if emission:p.inputs['Emission Color'].default_value=(*color,1);p.inputs['Emission Strength'].default_value=emission
 if alpha<1:m.surface_render_method='DITHERED'
 m.diffuse_color=(*color,alpha);return m
paint=material('Gavial green metallic clearcoat',(.062,.115,.089),.25,.55,coat=.85)
cladding=material('Graphite allroad cladding',(.052,.060,.065),.65,.05)
black=material('Rubber seals',(.009,.013,.016),.78)
rubber=material('235 55 R18 tire rubber',(.015,.018,.020),.87)
chrome=material('Brushed aluminum',(.52,.58,.62),.25,.88)
alloy=material('Machined alloy spokes',(.42,.47,.51),.23,.88)
wheelblack=material('Graphite wheel pockets',(.043,.052,.06),.38,.65)
glass=material('Clear tinted glazing',(.055,.085,.092),.08,0,.25)
smoked=material('Rear privacy glazing',(.025,.041,.044),.10,0,.52)
lens=material('Headlamp lens',(.55,.68,.74),.07,0,.15)
led=material('Matrix LED',(.77,.91,1),.18,.15,emission=2.4)
red=material('Tail lamp ruby',(.42,.006,.013),.22,.1,coat=.7)
redled=material('Tail LED',(.9,.008,.015),.25,emission=1.8)
leather=material('Charcoal upholstery',(.024,.029,.031),.72)
headliner=material('Headliner',(.08,.085,.08),.95)
piano=material('Piano black console',(.009,.012,.014),.22,coat=.5)
screen=material('Digital display',(.009,.025,.035),.32,emission=.2)
white=material('Display lettering',(.63,.78,.82),.6,emission=.7)
steel=material('Underbody coated steel',(.025,.032,.035),.65,.4)

def grain(m,seed,rough,strength,tiles):
 rng=np.random.default_rng(seed);n=128;f=rng.normal(size=(n,n));f=(f+np.roll(f,1,0)+np.roll(f,1,1))/3
 dx=(np.roll(f,-1,1)-np.roll(f,1,1))*.13;dy=(np.roll(f,-1,0)-np.roll(f,1,0))*.13
 norm=np.stack([-dx,-dy,np.ones_like(dx)],-1);norm/=np.linalg.norm(norm,axis=-1,keepdims=True)
 for kind in ['Normal','Roughness']:
  img=bpy.data.images.new(m.name+' '+kind,width=n,height=n,alpha=True);img.colorspace_settings.name='Non-Color'
  a=np.ones((n,n,4),dtype=np.float32);a[:,:,:3]=norm*.5+.5 if kind=='Normal' else np.clip(rough+f[:,:,None]*.025,.05,.96)
  img.pixels.foreach_set(a.ravel());img.pack()
  tex=m.node_tree.nodes.new('ShaderNodeTexImage');tex.image=img
  uv=m.node_tree.nodes.new('ShaderNodeUVMap');uv.uv_map='DetailUV';m.node_tree.links.new(uv.outputs['UV'],tex.inputs['Vector'])
  if kind=='Normal':
   node=m.node_tree.nodes.new('ShaderNodeNormalMap');node.uv_map='DetailUV';node.inputs['Strength'].default_value=strength
   m.node_tree.links.new(tex.outputs['Color'],node.inputs['Color']);m.node_tree.links.new(node.outputs['Normal'],shader(m).inputs['Normal'])
  else:m.node_tree.links.new(tex.outputs['Color'],shader(m).inputs['Roughness'])
 m['tiles']=tiles
for args in [(paint,8,.25,.035,7),(cladding,9,.65,.17,10),(leather,10,.72,.24,8),(rubber,11,.87,.17,6)]:grain(*args)

def empty(name,pos=(0,0,0),parent=None):
 o=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(o);o.location=B(pos);o.parent=parent;return o
body=empty('Body')
def mesh(name,verts,faces,mat,parent=body,smooth=False):
 data=bpy.data.meshes.new(name);data.from_pydata([B(p) for p in verts],[],faces);data.update()
 bm=bmesh.new();bm.from_mesh(data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(data);bm.free()
 o=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(o);o.parent=parent;data.materials.append(mat)
 for poly in data.polygons:poly.use_smooth=smooth
 return o

def grid(name,fn,n,m,mat,parent=body):
 verts=[fn(i/n,j/m) for j in range(m+1) for i in range(n+1)]
 faces=[]
 for j in range(m):
  for i in range(n):
   a=j*(n+1)+i;faces.append((a,a+1,a+n+2,a+n+1))
 return mesh(name,verts,faces,mat,parent,True)
def shell(o,t=.015):
 mod=o.modifiers.new('Panel thickness','SOLIDIFY');mod.thickness=t
 bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=mod.name)
 return o

def box(name,size,pos,mat,bevel=.012,parent=body):
 bpy.ops.mesh.primitive_cube_add(size=1,location=B(pos));o=bpy.context.object;o.name=name;o.parent=parent
 o.dimensions=(size[0],size[2],size[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(mat)
 if bevel:
  mod=o.modifiers.new('Manufactured edge radius','BEVEL');mod.width=bevel;mod.segments=3;bpy.ops.object.modifier_apply(modifier=mod.name)
  mod=o.modifiers.new('Weighted face normals','WEIGHTED_NORMAL');mod.keep_sharp=True;bpy.ops.object.modifier_apply(modifier=mod.name)
 return o

def line(name,pts,r,mat,parent=body):
 c=bpy.data.curves.new(name,'CURVE');c.dimensions='3D';c.resolution_u=1;c.bevel_depth=r;c.bevel_resolution=2
 sp=c.splines.new('POLY');sp.points.add(len(pts)-1)
 for v,p in zip(sp.points,pts):v.co=(*B(p),1)
 o=bpy.data.objects.new(name,c);bpy.context.collection.objects.link(o);o.parent=parent;c.materials.append(mat);return o

def cyl(name,a,b,r,mat,parent=body,segments=32):
 a=B(a);b=B(b);bpy.ops.mesh.primitive_cylinder_add(vertices=segments,radius=r,depth=(b-a).length,location=(a+b)/2)
 o=bpy.context.object;o.name=name;o.parent=parent;o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();o.data.materials.append(mat)
 for p in o.data.polygons:p.use_smooth=len(p.vertices)==4
 return o

def oval(name,center,rx,ry,wire,mat,parent=body,axis='Z'):
 pts=[]
 for i in range(65):
  a=i*math.tau/64
  p=(0,math.cos(a)*ry,math.sin(a)*rx) if axis=='X' else (math.cos(a)*rx,math.sin(a)*ry,0)
  pts.append(tuple(center[j]+p[j] for j in range(3)))
 return line(name,pts,wire,mat,parent)
def text(name,words,pos,size,mat,front=True,parent=body):
 c=bpy.data.curves.new(name,'FONT');c.body=words;c.size=size;c.align_x='CENTER';c.align_y='CENTER';c.extrude=.0004;c.resolution_u=3
 o=bpy.data.objects.new(name,c);bpy.context.collection.objects.link(o);o.parent=parent;o.location=B(pos)
 u=B((1 if front else -1,0,0));v=B((0,1,0));normal=u.cross(v)
 o.rotation_euler=Matrix((u,v,normal)).transposed().to_euler();c.materials.append(mat);return o

# Body surfaces are isolated so silhouette iteration does not alter the wheel rig.
import sys
sys.path.insert(0,str(Path(__file__).resolve().parent))
from allroad_body import build as build_body
build_body({name:globals()[name] for name in ['paint','cladding','black','chrome','glass','smoked','lens','led','red','redled','piano','headliner']},
           {name:globals()[name] for name in ['mesh','grid','shell','box','line','oval','text']})
# Cabin, seating and luggage compartment visible through transparent glazing.
box('Passenger floor',(1.48,.04,2.64),(0,.035,-.32),leather,.025)
box('Luggage floor',(1.38,.055,1.02),(0,.27,-1.75),leather,.016)
for side in [-1,1]:
 for z in [-.15,-1.12]:
  box('Seat cushion',(.47,.12,.45),(side*.39,.23,z),leather,.06)
  backrest=box('Contoured seat back',(.46,.49,.12),(side*.39,.51,z-.23),leather,.06)
  backrest.rotation_euler.x=math.radians(-9)
  for xoff in [-.19,.19]:box('Seat bolster',(.075,.35,.09),(side*.39+xoff,.49,z-.16),leather,.034)
  box('Headrest',(.23,.18,.12),(side*.39,.85,z-.27),leather,.043)
  for xoff in [-.075,.075]:cyl('Headrest post',(side*.39+xoff,.68,z-.27),(side*.39+xoff,.79,z-.27),.009,chrome)
  for xoff in [-.11,.11]:line('Seat stitch',[(side*.39+xoff,.34,z-.167),(side*.39+xoff,.67,z-.22)],.0015,headliner)
 box('Interior door card',(.065,.31,1.92),(side*.84,.39,-.35),leather,.025)
 line('Door aluminum inlay',[(side*.798,.57,.55),(side*.798,.57,-1.23)],.008,chrome)
 box('Armrest',(.09,.045,.40),(side*.77,.38,-.05),leather,.018)
# Dashboard is a continuous curved upper pad, not a block closing the windscreen.
grid('Dashboard pad',lambda u,v:((-1+2*u)*.80,.59+.055*math.sin(v*math.pi)-.025*abs(-1+2*u),.49+v*.43),40,16,leather)
box('Dashboard fascia',(1.57,.17,.12),(0,.52,.52),piano,.028)
line('Dash brushed trim',[(-.77,.59,.445),(.77,.59,.445)],.008,chrome)
box('Virtual cockpit',(.43,.155,.017),(.39,.56,.444),screen,.014)
for x in [.285,.49]:
 oval('Digital gauge',(x,.56,.431),.061,.061,.002,white)
 for i in range(11):
  a=math.radians(-40+i*26)
  line('Gauge graduation',[(x+math.cos(a)*.047,.56+math.sin(a)*.047,.429),(x+math.cos(a)*.055,.56+math.sin(a)*.055,.429)],.0015,white)
text('Speed display','0',(.39,.56,.426),.035,white,False)
box('MMI upper screen',(.29,.145,.018),(-.10,.51,.438),screen,.01)
text('Navigation display','allroad',(-.10,.53,.425),.027,white,False)
for i in range(3):line('Map road',[(-.22+i*.05,.46,.424),(-.14+i*.035,.51,.424),(-.07+i*.03,.56,.424)],.0018,chrome)
box('Center tunnel',(.25,.22,.76),(0,.19,-.02),piano,.035)
box('MMI lower climate screen',(.22,.09,.022),(0,.34,.33),screen,.008)
text('Climate display','21.0', (0,.34,.315),.025,white,False)
box('Gear selector',(.075,.07,.12),(0,.33,.04),leather,.018)
box('Center armrest',(.23,.075,.33),(0,.35,-.34),leather,.03)
for x in [-.072,.072]:oval('Cupholder',(x,.305,-.13),.045,.045,.006,black,axis='Z')
# Steering wheel and three spokes, plus interior mirror.
center=Vector((.39,.53,.265))
oval('Leather steering rim',center,.17,.17,.018,leather)
for a in [0,math.pi,math.pi*1.5]:
 end=center+Vector((math.cos(a)*.15,math.sin(a)*.15,0))
 line('Steering spoke',[center,end],.015,chrome)
box('Steering hub',(.135,.095,.055),center,leather,.023)
for x in [.354,.378,.402,.426]:oval('Steering Audi ring',(x,.536,.234),.018,.012,.002,chrome)
box('Interior mirror',(.22,.065,.035),(0,.94,.34),piano,.014)
box('Mirror reflective face',(.20,.047,.004),(0,.94,.317),chrome,.008)
# Wheels use independent yaw / roll nodes, with measured nominal tire dimensions.
def lathe(name,profile,mat,parent):
 verts=[];faces=[];n=128
 for x,r in profile:
  for i in range(n):
   a=i*math.tau/n;verts.append((x,math.cos(a)*r,math.sin(a)*r))
 for j in range(len(profile)-1):
  for i in range(n):
   a=j*n+i;b=j*n+(i+1)%n;faces.append((a,b,b+n,a+n))
 return mesh(name,verts,faces,mat,parent,True)
for i,label in enumerate(['FL','FR','RL','RR']):
 side=1 if i%2==0 else -1;x=side*(.8225 if i<2 else .8055);z=1.4625 if i<2 else -1.4625
 pivot=empty('Wheel'+label,(x,0,z));rotor=empty('Rotor'+label,parent=pivot)
 profile=[(-.092,.226),(-.112,.246),(-.1175,.29),(-.112,.328),(-.095,.350),(-.077,.35785),(-.073,.354),(-.067,.354),(-.063,.35785),(-.027,.35785),(-.023,.354),(-.017,.354),(-.013,.35785),(.013,.35785),(.017,.354),(.023,.354),(.027,.35785),(.063,.35785),(.067,.354),(.073,.354),(.077,.35785),(.095,.350),(.112,.328),(.1175,.29),(.112,.246),(.092,.226)]
 lathe('Road tire '+label,profile,rubber,rotor)
 for j in range(72):
  a=j*math.tau/72
  for s in [-1,1]:
   pts=[]
   for t in np.linspace(0,1,5):
    xx=s*(.032+t*.069);aa=a+t*.06;r=.3577-max(0,t-.64)*.024
    pts.append((xx,math.cos(aa)*r,math.sin(aa)*r))
   line('Tread siping',pts,.0012,black,rotor)
 lathe('Alloy barrel '+label,[(-.09,.215),(-.09,.229),(.09,.229),(.106,.222),(.106,.212),(-.09,.212)],wheelblack,rotor)
 oval('Polished rim lip',(side*.107,0,0),.225,.225,.007,chrome,rotor,'X')
 # Five twin spokes, machined faces over dark recessed pockets.
 for k in range(5):
  a=k*math.tau/5
  for branch in [-1,1]:
   shape=[(.045,-.015),(.11,branch*.021-.014),(.216,branch*.037-.010),(.219,branch*.037+.012),(.11,branch*.021+.015),(.045,.015)]
   verts=[]
   for xx in [side*.075,side*.103]:
    for rad,tan in shape:verts.append((xx,rad*math.cos(a)-tan*math.sin(a),rad*math.sin(a)+tan*math.cos(a)))
   faces=[tuple(range(6)),tuple(range(6,12))]+[(j,(j+1)%6,(j+1)%6+6,j+6) for j in range(6)]
   mesh('Twin alloy spoke',verts,faces,alloy,rotor)
 cyl('Wheel center',(side*.07,0,0),(side*.112,0,0),.058,wheelblack,rotor)
 for j in range(5):
  a=j*math.tau/5;cyl('Lug bolt',(side*.111,.042*math.cos(a),.042*math.sin(a)),(side*.119,.042*math.cos(a),.042*math.sin(a)),.008,chrome,rotor,12)
 for j in range(4):oval('Wheel Audi ring',(side*.119,0,(j-1.5)*.015),.012,.009,.0017,chrome,rotor,'X')
# Convert native curves/text, merge only within a shared parent/material boundary.
bpy.ops.object.select_all(action='DESELECT')
curves=[o for o in bpy.context.scene.objects if o.type in ['CURVE','FONT']]
for o in curves:o.select_set(True)
if curves:
 bpy.context.view_layer.objects.active=curves[0]
 bpy.ops.object.convert(target='MESH')
groups=defaultdict(list)
for o in bpy.context.scene.objects:
 if o.type=='MESH':groups[(o.parent,o.data.materials[0])].append(o)
for (parent,mat),obs in groups.items():
 bpy.ops.object.select_all(action='DESELECT')
 for o in obs:o.select_set(True)
 bpy.context.view_layer.objects.active=obs[0];bpy.ops.object.join();o=bpy.context.object;o.name=mat.name.replace(' ','_')
 bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
 data=o.data;verts=np.array([v.co[:] for v in data.vertices]);ids=np.empty(len(data.loops),dtype=np.int32);data.loops.foreach_get('vertex_index',ids)
 values=np.zeros((len(data.loops),2),dtype=np.float32)
 for poly in data.polygons:
  axis=int(np.argmax(np.abs(poly.normal)));columns=[a for a in range(3) if a!=axis];start=poly.loop_start;end=start+poly.loop_total
  values[start:end]=verts[ids[start:end]][:,columns]*mat.get('tiles',6)
 uv=data.uv_layers.new(name='DetailUV');uv.data.foreach_set('uv',values.ravel())
bpy.ops.export_scene.gltf(filepath=str(OUT),export_format='GLB',export_apply=True,export_yup=True,export_materials='EXPORT',export_cameras=False,export_lights=False)
print('ALLROAD_BUILT',OUT,OUT.stat().st_size)
