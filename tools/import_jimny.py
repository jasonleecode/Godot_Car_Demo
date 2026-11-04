"""Adapt tonielpro520's CC-BY 2023 Jimny Sierra to a playable JB74.
blender -b -t 4 --python tools/import_jimny.py -- --source /path/to/gltf/package
Source-specific face regions separate wheels from Sketchfab's material chunks.
Game coordinates: +Z front, +Y up, metres; Blender: -Y front, +Z up.
"""
import argparse, sys, math
from pathlib import Path
from collections import defaultdict
import bpy, bmesh
import numpy as np
from mathutils import Matrix, Vector

parser=argparse.ArgumentParser()
parser.add_argument('--source',required=True,type=Path)
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:])
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(args.source/'scene.gltf'))
original=list(bpy.context.scene.objects)
original_empties=[o for o in original if o.type!='MESH']

def shader(m):return next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
def tint(m,color,rough,metal=0,alpha=1,coat=0):
 p=shader(m)
 for field,value in [('Base Color',(*color,alpha)),('Metallic',metal),('Roughness',rough),('Alpha',alpha),('Coat Weight',coat),('Coat Roughness',.15)]:
  for link in list(p.inputs[field].links):m.node_tree.links.remove(link)
  p.inputs[field].default_value=value
 m.diffuse_color=(*color,alpha)
 if alpha<1:m.surface_render_method='DITHERED'
def newmat(name,color,rough,metal=0):
 m=bpy.data.materials.new(name);m.use_nodes=True;tint(m,color,rough,metal);return m
mats={m.name:m for m in bpy.data.materials}
paint=mats['Carro_Pintura'];paint.name='Kinetic Yellow clearcoat'
tint(paint,(.64,.73,.075),.27,0,coat=.8)
roof=newmat('Bluish Black roof clearcoat',(.012,.018,.024),.27,.12)
shader(roof).inputs['Coat Weight'].default_value=.8
trim=mats['Carro_Plastico'];trim.name='Textured exterior plastic';tint(trim,(.019,.023,.027),.69)
rubber=mats['Carro_Pneu'];rubber.name='195 80 R15 rubber';tint(rubber,(.014,.017,.019),.86)
for name in ['Carro_Metal_Preto','Carro_Metal_Preto_1','Carro_Plastico_1']:
 tint(mats[name],(.023,.028,.033),.58,.15 if 'Metal' in name else 0)
tint(mats['Carro_Interno'],(.032,.037,.041),.85)
tint(mats['Carro_Interno_1'],(.024,.029,.034),.76)
tint(mats['Carro_Cromado'],(.35,.39,.43),.28,.88)
tint(mats['Carro_Metal_Farol'],(.52,.57,.61),.19,.93)
tint(mats['Carro_Roda'],(.10,.12,.14),.38,.65)
tint(mats['Carro_Espelhos'],(.55,.61,.65),.06,.95)
glass=mats['Carro_Vidros'];glass.name='Clear tinted glazing';tint(glass,(.22,.32,.34),.095,0,.16)
tint(mats['Carro_Vidro_Laranja'],(.8,.22,.01),.24,.05,.8,coat=.7)
tint(mats['Carro_Vidros_Vermelhos'],(.48,.008,.012),.22,0,.82,coat=.7)
for name in ['Carro_Painel4','Carro_Freio','Carro_Disco']:
 shader(mats[name]).inputs['Roughness'].default_value=.56
# Preserve the source colour atlas UVs; use a separate metre-based UV for subtle grain.
def grain(m,seed,rough,strength):
 rng=np.random.default_rng(seed);n=128
 field=rng.normal(size=(n,n));field=(field+np.roll(field,1,0)+np.roll(field,1,1))/3
 dx=(np.roll(field,-1,1)-np.roll(field,1,1))*.15;dy=(np.roll(field,-1,0)-np.roll(field,1,0))*.15
 normals=np.stack([-dx,-dy,np.ones_like(dx)],-1);normals/=np.linalg.norm(normals,axis=-1,keepdims=True)
 for kind in ['Normal','Roughness']:
  image=bpy.data.images.new(m.name+' '+kind,width=n,height=n,alpha=True);image.colorspace_settings.name='Non-Color'
  pixels=np.ones((n,n,4),dtype=np.float32)
  pixels[:,:,:3]=normals*.5+.5 if kind=='Normal' else np.clip(rough+field[:,:,None]*.035,.05,.96)
  image.pixels.foreach_set(pixels.ravel());image.pack()
  tex=m.node_tree.nodes.new('ShaderNodeTexImage');tex.image=image
  uv=m.node_tree.nodes.new('ShaderNodeUVMap');uv.uv_map='DetailUV';m.node_tree.links.new(uv.outputs['UV'],tex.inputs['Vector'])
  if kind=='Normal':
   normal=m.node_tree.nodes.new('ShaderNodeNormalMap');normal.uv_map='DetailUV';normal.inputs['Strength'].default_value=strength
   m.node_tree.links.new(tex.outputs['Color'],normal.inputs['Color']);m.node_tree.links.new(normal.outputs['Normal'],shader(m).inputs['Normal'])
  else:m.node_tree.links.new(tex.outputs['Color'],shader(m).inputs['Roughness'])
for mat,seed,rough,strength in [(paint,74,.27,.035),(trim,75,.69,.18),(rubber,76,.86,.16),(mats['Carro_Interno_1'],77,.76,.18)]:grain(mat,seed,rough,strength)

def empty(name,pos=(0,0,0),parent=None):
 o=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(o);o.location=pos;o.parent=parent;return o
body=empty('Body');rotors={};pivots={}
source_centres=[Vector((.695,-1.167,.3475)),Vector((-.695,-1.167,.3475)),Vector((.695,1.073,.3475)),Vector((-.695,1.073,.3475))]
labels=['FL','FR','RL','RR']
for i,label in enumerate(labels):
 pivots[label]=empty('Wheel'+label,((1 if i%2==0 else -1)*(.6975 if i<2 else .7025),-1.125 if i<2 else 1.125,0))
 rotors[label]=empty('Rotor'+label,parent=pivots[label])
# Membership is deliberately explicit: these source materials contain wheel pieces.
wheel_materials={'Carro_Cromado','Carro_Disco','Carro_Freio','Carro_Metal_Preto_1','Carro_Pneu','Carro_Plastico'}
groups=defaultdict(list)
for o in original:
 if o.type!='MESH':continue
 source_name=o.name
 original_mat=next((name for name,m in mats.items() if m==o.data.materials[0]),'')
 if original_mat in ['Carro_Disco','Carro_Freio']:
  bpy.data.objects.remove(o,do_unlink=True);continue # Runtime front discs / rear drums.
 o.data=o.data.copy();o.data.transform(o.matrix_world);o.parent=None;o.matrix_world=Matrix.Identity(4)
 mesh=o.data
 coords=np.empty(len(mesh.vertices)*3,dtype=np.float32);mesh.vertices.foreach_get('co',coords);coords=coords.reshape(-1,3)
 # Assign polygons by their centres. The original chunks cut across assemblies.
 centres=np.array([p.center[:] for p in mesh.polygons])
 region=np.full(len(mesh.polygons),-1,dtype=np.int32)
 if original_mat in wheel_materials:
  for i,c in enumerate(source_centres):
   radial=(centres[:,1]-c.y)**2+(centres[:,2]-c.z)**2
   region[(np.abs(centres[:,0]-c.x)<.11)&(radial<.354**2)]=i
  if original_mat=='Carro_Cromado':
   for i,c in enumerate(source_centres):
    radial=(centres[:,1]-c.y)**2+(centres[:,2]-c.z)**2
    region[(region==i)&(np.abs(centres[:,0])<.684)&(radial<.18**2)]=-2
 # Retire old static axles/links/springs; preserve sills, bumper and cabin floor.
 underside=(np.abs(centres[:,0])<.59)&(centres[:,1]>-1.52)&(centres[:,1]<1.41)&(centres[:,2]<.40)
 coil_region=(np.abs(centres[:,0])>.33)&(np.abs(centres[:,0])<.52)&(centres[:,2]<.56)&((np.abs(centres[:,1]+1.167)<.24)|(np.abs(centres[:,1]-1.073)<.24))
 running_gear=(np.abs(centres[:,0])<.65)&(centres[:,1]>-1.52)&(centres[:,1]<1.65)&(centres[:,2]<.60)
 if original_mat not in ['Carro_Cromado','Carro_Metal_Preto_1','Carro_Metal_Preto']:running_gear[:]=False
 region[(region==-1)&(underside|coil_region|running_gear)]=-2
 for part in [-1,0,1,2,3]:
  wanted=np.flatnonzero(region==part)
  if not len(wanted):continue
  data=mesh.copy()
  source_normals=[n.vector[:] for n in data.corner_normals]
  bm=bmesh.new();bm.from_mesh(data);bm.faces.ensure_lookup_table()
  loop_id=bm.loops.layers.int.new('_source_corner')
  corner=0
  for f in bm.faces:
   for loop in f.loops:loop[loop_id]=corner;corner+=1
  bmesh.ops.delete(bm,geom=[f for f in bm.faces if region[f.index]!=part],context='FACES')
  bmesh.ops.delete(bm,geom=[v for v in bm.verts if not v.link_faces],context='VERTS')
  normals=[source_normals[loop[loop_id]] for f in bm.faces for loop in f.loops]
  bm.to_mesh(data);bm.free()
  data.normals_split_custom_set(normals)
  obj=bpy.data.objects.new(source_name+'_'+str(part),data);bpy.context.collection.objects.link(obj)
  if part>=0:
   center=source_centres[part]
   data.transform(Matrix.Translation(-center));obj.parent=rotors[labels[part]]
  else:
   # 2.25 m wheelbase; match body height separately without distorting tires.
   data.transform(Matrix(((1.0092,0,0,0),(0,2.25/2.24,0,.047*2.25/2.24),(0,0,1.042,-.3475*1.042),(0,0,0,1))))
   obj.parent=body
   if source_name=='Object_77':data.materials[0]=trim # Factory black five-slot grille.
   if original_mat=='Carro_Pintura':
    data.materials.append(mats['Carro_Metal_Preto_1'])
    for poly in data.polygons:
     if poly.center.z<.02:poly.material_index=len(data.materials)-1
   if original_mat=='Carro_Pintura' or source_name=='Object_35':
    data.materials.append(roof)
    for poly in data.polygons:
     if poly.center.z>1.28:poly.material_index=len(data.materials)-1
  groups[(obj.parent,tuple(data.materials))].append(obj)
 bpy.data.objects.remove(o,do_unlink=True)
for o in original_empties:bpy.data.objects.remove(o,do_unlink=True)
# Join material chunks before simplifying hidden parts; retain imported custom normals.
for (parent,materials),obs in groups.items():
 bpy.ops.object.select_all(action='DESELECT')
 for o in obs:o.select_set(True)
 bpy.context.view_layer.objects.active=obs[0];bpy.ops.object.join();o=bpy.context.object
 o.name=materials[0].name.replace(' ','_')
 # Preserve authored split normals on broad bodywork; welding these destroys highlights.
 if materials[0] in [rubber,mats['Carro_Interno'],mats['Carro_Interno_1']]:
  # Weld the tire's material-chunk seams before decimation; otherwise it opens cracks.
  bm=bmesh.new();bm.from_mesh(o.data)
  bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.000002)
  bm.to_mesh(o.data);bm.free()
  dec=o.modifiers.new('Game detail budget','DECIMATE');dec.ratio=.55 if materials[0]==rubber else .65
  bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=dec.name)
 # Dedicated detail UV, preserving the source texture coordinates in UV0.
 mesh=o.data
 vertices=np.array([v.co[:] for v in mesh.vertices]);indices=np.empty(len(mesh.loops),dtype=np.int32);mesh.loops.foreach_get('vertex_index',indices)
 uvdata=np.zeros((len(mesh.loops),2),dtype=np.float32)
 for poly in mesh.polygons:
  axis=int(np.argmax(np.abs(poly.normal)));columns=[a for a in range(3) if a!=axis]
  a=poly.loop_start;b=a+poly.loop_total;uvdata[a:b]=vertices[indices[a:b]][:,columns]*6
 uv=mesh.uv_layers.new(name='DetailUV');uv.data.foreach_set('uv',uvdata.ravel())
for label,rotor in rotors.items():
 tire=next(o for o in rotor.children if o.data.materials[0]==rubber)
 radius=max(math.hypot(v.co.y,v.co.z) for v in tire.data.vertices)
 width=max(v.co.x for v in tire.data.vertices)-min(v.co.x for v in tire.data.vertices)
 for o in rotor.children:
  for v in o.data.vertices:v.co.y*=.3465/radius;v.co.z*=.3465/radius;v.co.x*=.195/width
 print('WHEEL',label,'source radius',radius,'width',width,flush=True)
for image in bpy.data.images:
 if image.has_data:image.pack()
out=Path(__file__).resolve().parents[1]/'cars/Models/Jimny/Jimny.glb'
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=str(out),export_format='GLB',export_apply=True,export_yup=True,export_materials='EXPORT',export_cameras=False,export_lights=False)
print('JIMNY_EXPORTED',out,out.stat().st_size,flush=True)
