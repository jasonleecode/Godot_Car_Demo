"""Closed four-door hardtop conversion for the open Wrangler source mesh.
Coordinates here are Godot metres (+Y up, +Z forward), converted for Blender.
"""
import bpy,math
from mathutils import Vector

def build(body,paint,trim,roof,glass,leather,metal,badge_red):
    def to_blender(p):return (p[0],-p[2],p[1])
    def mesh(name,verts,faces,mat,smooth=False):
        data=bpy.data.meshes.new(name);data.from_pydata([to_blender(p) for p in verts],[],faces);data.update()
        obj=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(obj);obj.parent=body;data.materials.append(mat)
        for p in data.polygons:p.use_smooth=smooth
        bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.context.view_layer.objects.active=obj
        bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.mesh.normals_make_consistent(inside=False);bpy.ops.object.mode_set(mode='OBJECT')
        # Detail UVs remain independent of the source asset's authored texture atlas.
        uv=data.uv_layers.new(name='DetailUV');values=[]
        for loop in data.loops:
            p=data.vertices[loop.vertex_index].co;values.extend((p.y*6,p.z*6))
        uv.data.foreach_set('uv',values)
        return obj
    def rounded(points,radius=.04,steps=5):
        out=[]
        for i,p in enumerate(points):
            p=Vector(p);prev=Vector(points[i-1]);nxt=Vector(points[(i+1)%len(points)])
            a=p+(prev-p).normalized()*min(radius,(prev-p).length*.25)
            b=p+(nxt-p).normalized()*min(radius,(nxt-p).length*.25)
            for j in range(steps):
                t=j/(steps-1);q=a*(1-t)**2+p*2*t*(1-t)+b*t*t;out.append(q)
        return out
    def x_at(y):return .832-max(0,y-.82)*.145
    def panel(name,side,outline):
        # A continuous quad grid avoids the star-shaped reflections of a triangle fan.
        front=max(p[0] for p in outline);rear=min(p[0] for p in outline)
        is_rear=front<0;nx=32;ny=20;verts=[];faces=[]
        for j in range(ny+1):
            v=j/ny
            for i in range(nx+1):
                u=i/nx;z=front+(rear-front)*u
                lower=.155+.025*abs(2*u-1)**8
                if is_rear:lower+=.50*max(0,(-z-1.06)/.33)**1.3
                y=lower+(.856-lower)*v
                edge=min(u,1-u,v,1-v)
                bevel=.012*(1-min(1,edge/.06))**2
                x=x_at(y)+.012*math.sin(math.pi*u)*math.sin(math.pi*v)-bevel
                verts.append((side*x,y,z))
        for j in range(ny):
            for i in range(nx):
                a=j*(nx+1)+i;faces.append((a,a+1,a+nx+2,a+nx+1))
        shell=mesh(name,verts,faces,paint,True)
        solid=shell.modifiers.new('Door shell thickness','SOLIDIFY');solid.thickness=.035
        bpy.context.view_layer.objects.active=shell;bpy.ops.object.modifier_apply(modifier=solid.name)
        inner=[(x-side*.045,y,z) for x,y,z in verts]
        mesh(name+' interior',inner,faces,leather,True)
    def window(name,side,outer,inner,frame_material):
        outer=rounded(outer,.055);inner=rounded(inner,.055);n=len(outer)
        assert n==len(inner)
        verts=[(side*x_at(y),y,z) for z,y in outer]+[(side*(x_at(y)+.006),y,z) for z,y in inner]
        faces=[(j,(j+1)%n,(j+1)%n+n,j+n) for j in range(n)]
        frame=mesh(name+' frame',verts,faces,frame_material,True)
        solid=frame.modifiers.new('Window frame thickness','SOLIDIFY');solid.thickness=.033
        bpy.context.view_layer.objects.active=frame;bpy.ops.object.modifier_apply(modifier=solid.name)
        center=sum(inner,Vector((0,0)))/n
        glazing=[center+(p-center)*.965 for p in inner]
        verts=[(side*(x_at(y)+.009),y,z) for z,y in inner]+[(side*(x_at(y)+.009),y,z) for z,y in glazing]
        mesh(name+' rubber gasket',verts,faces,trim)
        mesh(name+' glass',[(side*(x_at(y)-.005),y,z) for z,y in glazing],[tuple(range(n))],glass)
    def box(name,size,pos,mat,r=.008):
        bpy.ops.mesh.primitive_cube_add(size=1,location=to_blender(pos));o=bpy.context.object
        o.name=name;o.dimensions=(size[0],size[2],size[1]);o.parent=body
        bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(mat)
        bevel=o.modifiers.new('Rounded manufacturing edges','BEVEL');bevel.width=r;bevel.segments=3
        bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=bevel.name)
        uv=o.data.uv_layers.new(name='DetailUV')
        values=[]
        for loop in o.data.loops:
            p=o.data.vertices[loop.vertex_index].co;values.extend((p.x*6+p.y*2,p.z*6+p.y*2))
        uv.data.foreach_set('uv',values)
        return o
    for side in [-1,1]:
        panel('Front sculpted door',side,[(.61,.20),(.64,.86),(-.43,.86),(-.43,.19),(-.32,.14),(.48,.14)])
        panel('Rear sculpted door',side,[(-.45,.17),(-.45,.86),(-1.39,.86),(-1.39,.67),(-1.17,.35),(-1.05,.16)])
        window('Front door',side,[(.64,.85),(.37,1.37),(-.43,1.37),(-.43,.85)],[(.54,.92),(.30,1.30),(-.355,1.30),(-.355,.92)],paint)
        window('Rear door',side,[(-.45,.85),(-.45,1.37),(-1.42,1.37),(-1.40,.85)],[(-.53,.92),(-.53,1.30),(-1.33,1.30),(-1.31,.92)],paint)
        window('Hardtop quarter',side,[(-1.44,.82),(-1.44,1.40),(-2.20,1.40),(-2.20,.82)],[(-1.53,.94),(-1.53,1.29),(-2.08,1.29),(-2.08,.94)],roof)
        for front,rear in [(.60,-.43),(-.47,-1.39)]:
            hz=rear+.15
            box('Handle recess',(.018,.055,.18),(side*.869,.785,hz),trim,.018)
            box('Pull handle',(.035,.028,.145),(side*.89,.795,hz),trim,.012)
            for y in [.34,.70]:
                box('Door hinge',(.025,.056,.075),(side*.862,y,front-.035),paint,.01)
                box('Hinge pin',(.027,.072,.022),(side*.878,y,front-.012),metal,.009)
        box('Beltline weatherstrip',(.025,.018,2.0),(side*.836,.864,-.40),trim,.006)
        box('Rain gutter',(.025,.035,2.59),(side*.815,1.408,-.91),roof,.012)
    # Separate front freedom panels and a rounded rear hardtop shell with a crowned cross section.
    for name,start,end in [('Front roof',.37,-.42),('Rear roof',-.43,-2.23)]:
        verts=[];nx=20;nz=16
        for j in range(nz+1):
            z=start+(end-start)*j/nz
            for i in range(nx+1):
                t=-1+2*i/nx;x=t*.82
                y=1.405+.067*math.sqrt(max(0,1-t*t))+.006*math.sin(math.pi*j/nz)
                verts.append((x,y,z))
        faces=[]
        for j in range(nz):
            for i in range(nx):
                a=j*(nx+1)+i;faces.append((a,a+1,a+nx+2,a+nx+1))
        top=mesh(name,verts,faces,roof,True)
        mod=top.modifiers.new('Hardtop shell thickness','SOLIDIFY');mod.thickness=.045
        bpy.context.view_layer.objects.active=top;bpy.ops.object.modifier_apply(modifier=mod.name)
    box('Freedom panel center seal',(.008,.009,.76),(0,1.477,-.015),trim,.003)
    # Rear liftglass and its black structural surround.
    box('Rear roof header',(1.56,.09,.055),(0,1.36,-2.22),roof,.025)
    box('Rear lower frame',(1.62,.10,.055),(0,.86,-2.22),roof,.018)
    for side in [-1,1]:box('Rear corner pillar',(.075,.48,.065),(side*.785,1.11,-2.21),roof,.025)
    mesh('Rear liftglass',[(-.745,.91,-2.223),(.745,.91,-2.223),(.735,1.32,-2.223),(-.735,1.32,-2.223)],[(0,1,2,3)],glass)

    # Hood lettering is separately authored instead of using the source's mismatched atlas.
    from mathutils.bvhtree import BVHTree
    hood=next(o for o in body.children if o.type=='MESH' and o.name.startswith('bonnet_') and o.data.materials[0]==paint)
    surface=BVHTree.FromPolygons([v.co.copy() for v in hood.data.vertices],[list(p.vertices) for p in hood.data.polygons])
    for side in [-1,1]:
        for label,size,offset,mat in [('RUBICON',.093,.001,badge_red),('RUBICON',.083,.002,trim)]:
            curve=bpy.data.curves.new('Rubicon hood lettering','FONT');curve.body=label;curve.size=size
            curve.align_x='CENTER';curve.align_y='CENTER';curve.extrude=.0002;curve.resolution_u=3
            o=bpy.data.objects.new('RUBICON',curve);bpy.context.collection.objects.link(o);o.parent=body
            o.location=to_blender((side*(.760+offset),.74,1.31))
            from mathutils import Matrix
            u=Vector(to_blender((0,0,-side)));v=Vector(to_blender((0,1,0)));n=u.cross(v)
            o.rotation_euler=Matrix((u,v,n)).transposed().to_euler();curve.materials.append(mat)
            bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o;bpy.ops.object.convert(target='MESH')

            bpy.context.view_layer.update()
            transform=o.matrix_world.copy();inverse=transform.inverted()
            for vertex in o.data.vertices:
                p=transform@vertex.co
                p.z+=.12*(p.y+1.31)
                hit,_,_,_=surface.ray_cast(Vector((side*2,p.y,p.z)),Vector((-side,0,0)),3)
                if hit is not None:p.x=hit.x+side*offset
                vertex.co=inverse@p
            o.data.update()
