"""Build an original JL Rubicon-inspired game mesh in metres; run with Blender -b -P.
Godot axes: +Y up, +Z front. 3.008 m wheelbase, 35 x 12.50 R17 tires.
Geometry is authored here, not extracted from a commercial game.
"""
import bpy, math, os, random
from mathutils import Vector, Matrix, Euler
from collections import defaultdict

bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
C = Matrix(((1,0,0),(0,0,-1),(0,1,0)))
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT,'cars','Models','Rubicon','Rubicon.glb')
random.seed(35)

def vec(p): return C @ Vector(p)
def mat(name, color, metal=0, rough=.5, coat=0, alpha=1, emission=0):
    m=bpy.data.materials.new(name); m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value=(*color,alpha)
    p.inputs['Metallic'].default_value=metal; p.inputs['Roughness'].default_value=rough
    p.inputs['Coat Weight'].default_value=coat
    p.inputs['Coat Roughness'].default_value=.12
    p.inputs['Alpha'].default_value=alpha
    if emission:
        p.inputs['Emission Color'].default_value=(*color,1)
        p.inputs['Emission Strength'].default_value=emission
    m.diffuse_color=(*color,alpha)
    return m
paint=mat('Granite metallic clearcoat',(.24,.29,.31),.65,.24,.85)
plastic=mat('Textured charcoal trim',(.018,.022,.025),0,.72)
roofmat=mat('Hardtop satin black',(.025,.03,.033),0,.57)
rubber=mat('Tire rubber',(.013,.016,.018),0,.84)
letter_rubber=mat('Raised sidewall rubber',(.038,.042,.045),0,.63)
tread=mat('Tread rubber',(.022,.025,.027),0,.86)
metal=mat('Brushed alloy',(.42,.46,.49),.9,.25)
blackmetal=mat('Graphite wheel finish',(.045,.055,.065),.8,.26)
chrome=mat('Machined edge',(.7,.74,.78),1,.13)
red=mat('Rubicon red',(.56,.018,.025),.18,.27,.5)
leather=mat('Charcoal leather',(.025,.029,.032),0,.68)
seatinsert=mat('Seat inserts',(.055,.06,.065),0,.82)
glass=mat('Clear tinted glazing',(.54,.67,.71),0,.07,alpha=.16)
lens=mat('Optical lens',(.75,.85,.92),.12,.08,alpha=.22)
led=mat('LED white',(.85,.93,1),0,.15,emission=1.5)
redled=mat('Tail lens red',(.52,.008,.012),.1,.18,emission=.25)
amber=mat('Amber reflector',(.86,.20,.015),.1,.27)
screen=mat('Dashboard display',(.025,.10,.14),.1,.19,emission=.25)
objects=[]

def empty(name, pos=(0,0,0), parent=None):
    o=bpy.data.objects.new(name,None); bpy.context.collection.objects.link(o)
    o.parent=parent; o.location=vec(pos); return o
body=empty('Body')

def finish(o,name,pos,material,parent=body,rot=None,bevel=0,smooth=False):
    o.name=name; o.parent=parent; o.location=vec(pos)
    if rot: o.rotation_euler=(C @ Euler(rot,'XYZ').to_matrix() @ C.inverted()).to_euler()
    o.data.materials.append(material)
    if bevel:
        m=o.modifiers.new('Manufactured edge radii','BEVEL'); m.width=bevel; m.segments=3
        bpy.context.view_layer.objects.active=o; bpy.ops.object.modifier_apply(modifier=m.name)
        n=o.modifiers.new('Weighted panel normals','WEIGHTED_NORMAL'); n.keep_sharp=True
        bpy.ops.object.modifier_apply(modifier=n.name)
    if smooth:
        for p in o.data.polygons:p.use_smooth=True
    objects.append(o); return o

box_cache={}
def box(name,size,pos,material,parent=body,bevel=.006,rot=None):
    key=(tuple(size),bevel,material.name)
    if key in box_cache:
        o=bpy.data.objects.new(name,box_cache[key]);bpy.context.collection.objects.link(o)
        o.parent=parent;o.location=vec(pos)
        if rot:o.rotation_euler=(C @ Euler(rot,'XYZ').to_matrix() @ C.inverted()).to_euler()
        objects.append(o);return o
    bpy.ops.mesh.primitive_cube_add()
    o=bpy.context.object; o.dimensions=(size[0],size[2],size[1])
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    o=finish(o,name,pos,material,parent,rot,bevel)
    box_cache[key]=o.data
    return o

def mesh(name,verts,faces,material,parent=body,bevel=0,smooth=False):
    m=bpy.data.meshes.new(name);m.from_pydata([vec(v) for v in verts],[],faces);m.update()
    o=bpy.data.objects.new(name,m);bpy.context.collection.objects.link(o)
    # Recalculate outward normals, especially on side extrusions.
    bpy.context.view_layer.objects.active=o; o.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.mesh.normals_make_consistent(inside=False);bpy.ops.object.mode_set(mode='OBJECT')
    o.select_set(False)
    return finish(o,name,(0,0,0),material,parent,bevel=bevel,smooth=smooth)

def cyl(name,r,h,pos,material,axis=(0,1,0),parent=body,verts=40):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts,radius=r,depth=h)
    o=bpy.context.object
    finish(o,name,pos,material,parent,smooth=True)
    o.rotation_euler=Vector((0,0,1)).rotation_difference(vec(axis).normalized()).to_euler()
    return o

def rod(name,a,b,r,material,parent=body):
    d=Vector(b)-Vector(a)
    return cyl(name,r,d.length,(Vector(a)+Vector(b))*.5,material,d,parent,16)

def torus(name,major,minor,pos,material,axis=(0,1,0),parent=body,segments=64):
    bpy.ops.mesh.primitive_torus_add(major_radius=major,minor_radius=minor,major_segments=segments,minor_segments=10)
    o=bpy.context.object;finish(o,name,pos,material,parent,smooth=True)
    o.rotation_euler=Vector((0,0,1)).rotation_difference(vec(axis).normalized()).to_euler()
    return o

def text(name,string,size,pos,material,u=(1,0,0),v=(0,1,0),parent=body):
    curve=bpy.data.curves.new(name,'FONT');curve.body=string;curve.size=size
    curve.align_x='CENTER';curve.align_y='CENTER';curve.extrude=.00035;curve.resolution_u=4
    o=bpy.data.objects.new(name,curve);bpy.context.collection.objects.link(o)
    o.parent=parent;o.location=vec(pos)
    u=Vector(u);v=Vector(v);n=u.cross(v)
    o.rotation_euler=Matrix((vec(u),vec(v),vec(n))).transposed().to_euler()
    o.data.materials.append(material)
    bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o;bpy.ops.object.convert(target='MESH')
    objects.append(o);return o

def side_panel(name,x,outline,thickness,material):
    vs=[(xx,y,z) for xx in (x-thickness/2,x+thickness/2) for z,y in outline]
    n=len(outline);fs=[tuple(range(n-1,-1,-1)),tuple(range(n,n*2))]
    fs += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    return mesh(name,vs,fs,material,bevel=.008)

def pane(name,verts):
    return mesh(name,verts,[(0,1,2,3)],glass)

# Chassis and separate lower body panels.
for x in [-.53,.53]:box('Frame rail',(.11,.17,4.1),(x,.13,0),blackmetal,bevel=.018)
box('Belly skid',(1.1,.075,2.0),(0,.09,-.1),metal,bevel=.025)
box('Cabin floor',(1.64,.11,2.72),(0,.30,-.70),plastic,bevel=.025)
box('Rear body',(1.72,.52,.10),(0,.59,-2.09),paint,bevel=.025)
# Hood has tapered plan, panel depth and gently sloping top.
vs=[(-.78,.71,.66),(.78,.71,.66),(.73,.68,2.08),(-.73,.68,2.08),(-.80,1.01,.66),(.80,1.01,.66),(.75,.93,2.08),(-.75,.93,2.08)]
hood=mesh('Sculpted hood',vs,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],paint,bevel=.025)
box('Hood center power dome',(.80,.045,.94),(0,1.015,1.20),paint,bevel=.025,rot=(-.045,0,0))
box('Cowl',(1.69,.16,.27),(0,.98,.60),paint,bevel=.035)
box('Engine bay enclosure',(1.34,.47,1.30),(0,.50,1.34),plastic,bevel=.04)
for side in [-1,1]:
    arc=[]
    for j in range(34):
        z=.63+j*1.47/33;d=z-1.504
        y=max(.20,.02+math.sqrt(max(0,.55**2-d*d))) if abs(d)<.55 else .20
        arc.append((z,y))
    side_panel('Front inner fender panel',side*.759,arc+[(2.10,.72),(.63,.82)],.045,paint)
    box('Fender upper ledge',(.19,.055,1.12),(side*.84,.655,1.38),plastic,bevel=.024)

for side in [-1,1]:
    x=side*.838
    # Lower tub leaves a real wheel opening around the rear axle.
    bottom=[]
    for j in range(45):
        z=-2.10+j*2.72/44
        d=z+1.504
        y=max(.22,.02+math.sqrt(max(0,.57**2-d*d))) if abs(d)<.57 else .22
        bottom.append((z,y))
    outline=bottom+[(.62,.98),(-2.10,.98)]
    side_panel('Rear quarter tub',x,outline,.065,paint)
    # Four individual door skins, with black seams and convex manufactured edges.
    for front,rear in [(.58,-.51),(-.55,-1.48)]:
        lower=[]
        for j in range(18):
            z=rear+.015+j*(front-rear-.03)/17
            d=z+1.504;y=max(.245,.02+math.sqrt(max(0,.58**2-d*d))) if abs(d)<.58 else .245
            lower.append((z,y))
        side_panel('Door perimeter',side*.878,lower+[(front-.015,.99),(rear+.015,.99)],.024,plastic)
        inset=[(z,y+.012) for z,y in lower]+[(front-.026,.975),(rear+.026,.975)]
        side_panel('Door skin',side*.895,inset,.035,paint)
        for y in [.42,.82]:
            z=front-.07
            box('Exposed door hinge',(.025,.076,.105),(side*.921,y,z),paint,bevel=.009)
            cyl('Hinge pin',.014,.10,(side*.934,y,z+.025),metal)
            for zz in [z-.025,z+.025]:cyl('Hinge bolt',.008,.008,(side*.94,y,zz),blackmetal,axis=(side,0,0),verts=12)
        hz=rear+.19
        box('Handle recess',(.025,.064,.22),(side*.921,.884,hz),plastic,bevel=.026)
        box('Pull handle',(.052,.037,.17),(side*.949,.89,hz),plastic,bevel=.014)
    box('Rock rail',(.10,.085,2.08),(side*.932,.18,-.24),blackmetal,bevel=.027)
    for z in [.53,-.52,-1.54,-2.04]:
        box('Window pillar',(.065,.58,.055),(side*.84,1.24,z),paint if z> -1.6 else roofmat,bevel=.012)
    # Rubicon hood badging and cowl side vent.
    u=(0,0,-side)
    text('Rubicon badge outline','RUBICON',.145,(side*.807,.899,1.28),red,u=u)
    text('Rubicon badge inlay','RUBICON',.130,(side*.809,.899,1.28),plastic,u=u)
    text('Jeep badge','Jeep',.062,(side*.935,.72,.53),chrome,u=u)
    text('Wrangler badge','WRANGLER',.021,(side*.935,.66,.53),metal,u=u)
    cyl('Trail rated badge',.037,.008,(side*.935,.83,.59),red,axis=(side,0,0),verts=32)
    box('Cowl vent',(.016,.15,.18),(side*.851,.94,.61),plastic,bevel=.012)
    for i in range(5):box('Vent slat',(.023,.009,.13),(side*.865,.895+i*.023,.61),blackmetal,bevel=.003)
    for z in [.80,1.84]:
        box('Hood latch base',(.026,.10,.06),(side*.785,.85,z),plastic,bevel=.009)
        rod('Hood latch lever',(side*.81,.82,z),(side*.81,.94,z),.013,blackmetal)
    # Mirrors, gasket and reflective insert.
    rod('Mirror arm',(side*.86,1.08,.49),(side*1.065,1.13,.50),.026,plastic)
    box('Mirror housing',(.10,.19,.235),(side*1.07,1.23,.45),plastic,bevel=.043)
    box('Mirror glass',(.012,.143,.182),(side*1.125,1.23,.45),chrome,bevel=.027)
# Windshield tilted rearward, independent glass and rubber surround.
for x in [-.815,.815]:rod('A pillar',(x,1.005,.77),(x,1.49,.48),.035,paint)
for a,b in [((-.82,1.005,.77),(.82,1.005,.77)),((-.82,1.49,.48),(.82,1.49,.48))]:rod('Windshield seal',a,b,.028,plastic)
pane('Windshield',[(-.785,1.03,.756),(.785,1.03,.756),(.785,1.465,.495),(-.785,1.465,.495)])
for side in [-1,1]:
    x=side*.847
    pane('Front door glass',[(x,1.01,-.49),(x,1.01,.52),(x,1.47,.45),(x,1.47,-.49)])
    pane('Rear door glass',[(x,1.01,-1.51),(x,1.01,-.57),(x,1.47,-.57),(x,1.47,-1.51)])
    pane('Quarter glass',[(x,1.02,-2.01),(x,1.02,-1.59),(x,1.47,-1.59),(x,1.47,-2.01)])
    for y in [1.0,1.49]:box('Window horizontal seal',(.05,.032,2.6),(side*.85,y,-.78),plastic,bevel=.012)
pane('Rear hatch glass',[(-.80,1.01,-2.058),(.80,1.01,-2.058),(.80,1.46,-2.058),(-.80,1.46,-2.058)])
box('Hardtop',(1.78,.095,2.69),(0,1.525,-.79),roofmat,bevel=.045)
for z in [.05,-.85]:box('Removable roof seam',(1.71,.006,.009),(0,1.575,z),plastic,bevel=.002)
for x in [-.55,-.28,0,.28,.55]:box('Roof molded rib',(.038,.012,1.12),(x,1.58,-1.43),roofmat,bevel=.008)
for x in [-.43,.33]:
    rod('Wiper arm',(x,1.025,.79),(x+.20,1.11,.733),.009,blackmetal)
    rod('Wiper blade',(x+.02,1.12,.727),(x+.45,1.12,.727),.012,plastic)
# Actual grille cutouts and recessed mesh.
grille=box('Seven-slot grille',(1.60,.51,.09),(0,.717,2.072),paint,bevel=.04)
for i in range(7):
    x=(i-3)*.132
    cutter=box('Slot cutter',(.085,.345,.30),(x,.728,2.07),plastic,bevel=.038)
    mod=grille.modifiers.new('Open grille slot','BOOLEAN');mod.operation='DIFFERENCE';mod.object=cutter
    bpy.context.view_layer.objects.active=grille;bpy.ops.object.modifier_apply(modifier=mod.name)
    objects.remove(cutter);bpy.data.objects.remove(cutter,do_unlink=True)
box('Radiator recess',(1.12,.40,.025),(0,.72,2.014),plastic,bevel=.02)
for i in range(19):box('Grille mesh rib',(1.03,.003,.008),(0,.55+i*.018,2.035),blackmetal,bevel=0)
for i in range(35):box('Grille mesh wire',(.003,.34,.008),(-.5+i*.0294,.72,2.037),blackmetal,bevel=0)
for side in [-1,1]:
    x=side*.635
    cyl('Headlight surround',.155,.05,(x,.75,2.099),plastic,axis=(0,0,1),verts=64)
    cyl('Headlight reflector',.139,.024,(x,.75,2.130),chrome,axis=(0,0,1),verts=64)
    cyl('Headlight dark interior',.128,.025,(x,.75,2.144),blackmetal,axis=(0,0,1),verts=64)
    torus('LED halo',.119,.007,(x,.75,2.163),led,axis=(0,0,1))
    for y in [.704,.79]:cyl('LED projector',.043,.025,(x,y,2.163),lens,axis=(0,0,1),verts=32)
    box('Headlight bridge',(.17,.014,.016),(x,.751,2.165),chrome,bevel=.004)
    # Black high-clearance arched fenders, inner opening clears the 35-inch tires.
    for z in [1.504,-1.504]:
        verts=[]
        for xx in [side*.82,side*1.045]:
            for r in [.535,.615]:
                for j in range(33):
                    a=math.radians(-13+j*206/32)
                    verts.append((xx,.02+math.sin(a)*r,z+math.cos(a)*r))
        faces=[]
        for j in range(32):
            faces += [(j,j+1,33+j+1,33+j),(66+j,99+j,99+j+1,66+j+1),(j,66+j,66+j+1,j+1),(33+j,33+j+1,99+j+1,99+j)]
        faces += [(0,33,99,66),(32,98,131,65)]
        mesh('High clearance fender',verts,faces,plastic,bevel=.008,smooth=True)
        for j in range(7):
            a=math.pi*j/6
            cyl('Fender fastener',.009,.01,(side*1.051,.02+math.sin(a)*.578,z+math.cos(a)*.578),blackmetal,axis=(side,0,0),verts=12)
    box('Fender DRL housing',(.22,.052,.10),(side*.935,.50,2.028),plastic,bevel=.015)
    box('Fender LED strip',(.18,.019,.012),(side*.935,.515,2.083),led,bevel=.006)
    box('Fender indicator',(.11,.016,.012),(side*.96,.489,2.084),amber,bevel=.005)
# Segmented steel bumpers, red tow hooks and winch.
box('Front steel bumper',(1.82,.22,.26),(0,.32,2.205),blackmetal,bevel=.045)
for side in [-1,1]:
    box('Bumper wing',(.28,.18,.29),(side*.91,.33,2.15),blackmetal,bevel=.035,rot=(0,side*.12,0))
    cyl('Fog lamp bezel',.075,.025,(side*.72,.33,2.345),plastic,axis=(0,0,1))
    cyl('Fog lamp',.056,.027,(side*.72,.33,2.363),lens,axis=(0,0,1))
    for a,b in [((side*.48,.39,2.25),(side*.48,.51,2.25)),((side*.48,.51,2.25),(side*.48,.51,2.36)),((side*.48,.51,2.36),(side*.48,.45,2.39))]:rod('Red recovery hook',a,b,.027,red)
box('Winch base',(.64,.08,.28),(0,.48,2.18),blackmetal,bevel=.02)
cyl('Winch drum',.075,.37,(0,.57,2.15),blackmetal,axis=(1,0,0))
for i in range(22):torus('Winch rope coil',.075,.004,(-.16+i*.015,.57,2.15),metal,axis=(1,0,0),segments=32)
box('Winch motor',(.16,.15,.17),(.26,.57,2.15),plastic,bevel=.025)
box('Fairlead',(.32,.09,.05),(0,.43,2.355),metal,bevel=.025)
box('Fairlead opening',(.25,.035,.055),(0,.43,2.366),plastic,bevel=.015)
box('Front skid',(1.15,.06,.28),(0,.195,2.16),metal,bevel=.025,rot=(.18,0,0))
box('Rear bumper',(1.87,.19,.24),(0,.29,-2.18),blackmetal,bevel=.04)
for side in [-1,1]:
    box('Tail light body',(.18,.24,.095),(side*.72,.73,-2.17),plastic,bevel=.025)
    box('Tail light lens',(.147,.21,.055),(side*.72,.73,-2.22),redled,bevel=.024)
    for angle in [-.65,.65]:box('Tail light X',(.022,.18,.012),(side*.72,.73,-2.251),red,bevel=.005,rot=(0,0,angle))
    box('Tail reverse lens',(.12,.034,.015),(side*.72,.66,-2.255),led,bevel=.005)
    for x in [side*.4,side*.8]:cyl('Parking sensor',.013,.012,(x,.30,-2.305),plastic,axis=(0,0,-1))
box('Rear plate',(.32,.10,.012),(-.49,.35,-2.311),plastic,bevel=.01)
text('Plate text','RUBICON',.042,(-.49,.35,-2.320),metal,u=(-1,0,0))
cyl('Exhaust',.039,.28,(.63,.10,-2.11),metal,axis=(0,0,1))
# Seats, controls, instrument binnacle and modern wide screen.
for x in [-.43,.43]:
    box('Front seat base',(.55,.13,.58),(x,.44,-.04),leather,bevel=.055)
    box('Front seat cushion',(.39,.045,.45),(x,.518,-.04),seatinsert,bevel=.025)
    box('Front seat back',(.54,.57,.15),(x,.79,-.32),leather,bevel=.055,rot=(-.12,0,0))
    box('Seat back inset',(.34,.41,.02),(x,.81,-.232),seatinsert,bevel=.025,rot=(-.12,0,0))
    box('Headrest',(.26,.20,.13),(x,1.18,-.38),leather,bevel=.045)
    for sx in [-.22,.22]:rod('Red seat stitching',(x+sx,.57,-.235),(x+sx,1.0,-.283),.0022,red)
for x in [-.48,0,.48]:
    box('Rear bench cushion',(.46,.13,.48),(x,.46,-1.14),leather,bevel=.04)
    box('Rear backrest',(.46,.53,.14),(x,.77,-1.39),leather,bevel=.045)
    box('Rear headrest',(.23,.19,.12),(x,1.12,-1.41),leather,bevel=.035)
box('Dashboard',(1.58,.24,.29),(0,.87,.47),plastic,bevel=.05)
box('Dashboard red accent',(1.37,.055,.018),(0,.90,.315),red,bevel=.018)
box('Infotainment surround',(.42,.19,.035),(-.10,.94,.291),blackmetal,bevel=.015)
box('Infotainment screen',(.38,.15,.009),(-.10,.94,.267),screen,bevel=.007)
for x in [-.67,.20,.67]:
    cyl('Round dashboard vent',.061,.02,(x,.88,.304),metal,axis=(0,0,-1),verts=32)
    cyl('Vent interior',.049,.022,(x,.88,.29),plastic,axis=(0,0,-1),verts=32)
    for i in range(3):box('Vent blade',(.075,.006,.013),(x,.856+i*.022,.27),blackmetal,bevel=.002)
box('Instrument cluster',(.32,.17,.07),(.42,.99,.32),plastic,bevel=.04)
for x in [.35,.49]:cyl('Instrument dial',.052,.012,(x,1.0,.278),screen,axis=(0,0,-1))
rod('Steering column',(.42,.84,.40),(.42,1.0,.08),.034,plastic)
torus('Leather steering rim',.166,.017,(.42,1.0,.08),leather,axis=(0,.4,-.9))
for i in range(3):
    a=math.tau*i/3
    rod('Steering spoke',(.42,1.0,.08),(.42+math.cos(a)*.15,1.0+math.sin(a)*.135,.08+math.sin(a)*.06),.014,metal)
box('Center console',(.24,.23,.66),(0,.48,-.08),plastic,bevel=.04)
for z in [.08,-.06]:
    rod('Gear lever',(0,.6,z),(0,.75,z-.025),.015,blackmetal)
    box('Gear knob',(.048,.06,.065),(0,.76,z-.025),leather,bevel=.018)
# Wheel build, with true 0.889 m outside diameter including tread tips.
def build_wheel(parent):
    profile=[(-.105,.216),(-.14,.228),(-.158,.285),(-.15875,.35),(-.145,.39),(-.115,.414),(-.07,.415),(0,.416),(.07,.415),(.115,.414),(.145,.39),(.15875,.35),(.158,.285),(.14,.228),(.105,.216)]
    vs=[];n=96
    for x,r in profile:
        for i in range(n):
            a=math.tau*i/n;vs.append((x,math.cos(a)*r,math.sin(a)*r))
    fs=[]
    for j in range(len(profile)):
        for i in range(n):fs.append((j*n+i,j*n+(i+1)%n,((j+1)%len(profile))*n+(i+1)%n,((j+1)%len(profile))*n+i))
    mesh('Radial tire casing',vs,fs,rubber,parent,smooth=True)
    # Staggered shoulder lugs and interlocked center blocks; top radius = 0.4445 m.
    for i in range(40):
        for row in range(4):
            x=(row-1.5)*.073
            a=math.tau*(i+(row%2)*.48)/40
            radius=.4285 if row in [1,2] else .420
            block=box('35 inch tread block',(.063,.032,.048),(x,math.cos(a)*radius,math.sin(a)*radius),tread,parent,bevel=.003,rot=(a,0,.22 if row%2 else -.22))
            # A dark transverse sipe on each raised block.
            box('Tread sipe',(.029,.0009,.0025),(x,math.cos(a)*(radius+.0165),math.sin(a)*(radius+.0165)),rubber,parent,bevel=0,rot=(a,0,.22 if row%2 else -.22))
    for side in [-1,1]:
        torus('Sidewall bead',.236,.008,(side*.144,0,0),rubber,axis=(1,0,0),parent=parent)
        torus('Sidewall ridge',.365,.0017,(side*.159,0,0),letter_rubber,axis=(1,0,0),parent=parent)
        torus('17 inch rim lip',.213,.008,(side*.145,0,0),chrome,axis=(1,0,0),parent=parent)
        cyl('Rim barrel',.207,.052,(side*.114,0,0),blackmetal,axis=(1,0,0),parent=parent,verts=64)
        cyl('Brake rotor',.17,.012,(side*.149,0,0),metal,axis=(1,0,0),parent=parent,verts=64)
        # Recessed dark rotor face and machined split spokes.
        cyl('Wheel well',.195,.01,(side*.158,0,0),plastic,axis=(1,0,0),parent=parent,verts=64)
        for j in range(5):
            a=math.tau*j/5
            for split in [-.11,.11]:
                start=(side*.17,math.cos(a)*.062,math.sin(a)*.062)
                end=(side*.17,math.cos(a+split)*.195,math.sin(a+split)*.195)
                d=Vector(end)-Vector(start); perpendicular=Vector((0,-d.z,d.y)).normalized()
                outline=[Vector(start)-perpendicular*.017,Vector(end)-perpendicular*.011,Vector(end)+perpendicular*.011,Vector(start)+perpendicular*.017]
                verts=[(side*xx,p.y,p.z) for xx in [.158,.184] for p in outline]
                mesh('Cast split spoke',verts,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],blackmetal,parent,bevel=.002)
                rod('Machined spoke edge',(side*.186,start[1],start[2]),(side*.186,end[1],end[2]),.003,metal,parent)
            cyl('Lug nut',.009,.018,(side*.187,math.cos(a)*.045,math.sin(a)*.045),chrome,axis=(1,0,0),parent=parent,verts=6)
        cyl('Center hub',.032,.021,(side*.18,0,0),blackmetal,axis=(1,0,0),parent=parent,verts=32)
        for j in range(24):
            a=math.tau*j/24
            cyl('Beadlock ring bolt',.004,.008,(side*.158,math.cos(a)*.208,math.sin(a)*.208),metal,axis=(1,0,0),parent=parent,verts=6)
        text('Raised tire size','35 x 12.50 R17',.032,(side*.161,.292,0),letter_rubber,u=(0,0,-side),parent=parent)
        text('Raised tire type','ALL TERRAIN',.034,(side*.161,-.29,0),letter_rubber,u=(0,0,-side),parent=parent)
        for j in range(48):
            a=math.tau*j/48
            box('Sidewall shoulder lug',(.008,.034,.017),(side*.151,math.cos(a)*.39,math.sin(a)*.39),tread,parent,bevel=.002,rot=(a,0,0))

# Build once then instance a mesh hierarchy after merging.
wheel=empty('WheelFL',(.875,.02,1.504))
rotor=empty('RotorFL',parent=wheel)
build_wheel(rotor)
# Combine meshes per parent and material; retain moving pivots and transparent panes.
groups=defaultdict(list)
for o in objects:
    if o.name not in bpy.data.objects:continue
    groups[(o.parent,o.data.materials[0])].append(o)
for (parent,material),obs in groups.items():
    bpy.ops.object.select_all(action='DESELECT')
    for o in obs:o.select_set(True)
    bpy.context.view_layer.objects.active=obs[0]
    bpy.ops.object.join();combined=bpy.context.object
    combined.name=('Glass' if material==glass else material.name.replace(' ','_'))
    # Freeze object transforms in mesh so duplicates inherit no stray offsets.
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
# Normalize the actual rubber vertices, including lug corners, to the specified outside radius.
tire_meshes=[o.data for o in rotor.children if o.type=='MESH' and o.data.materials[0] in [rubber,tread,letter_rubber]]
outer=max(math.hypot(v.co.y,v.co.z) for m in tire_meshes for v in m.vertices)
for m in tire_meshes:
    for v in m.vertices:
        v.co.y *= .4445/outer;v.co.z *= .4445/outer
    m.update()
for name,pos in [('FR',(-.875,.02,1.504)),('RL',(.875,.02,-1.504)),('RR',(-.875,.02,-1.504)),('Spare',(0,.88,-2.32))]:
    pivot=empty('Wheel'+name,pos,parent=body if name=='Spare' else None)
    child=empty('Rotor'+name,parent=pivot)
    if name=='Spare':pivot.rotation_euler=(C@Euler((0,math.pi/2,0)).to_matrix()@C.inverted()).to_euler()
    for source in rotor.children:
        o=source.copy();o.data=source.data;bpy.context.collection.objects.link(o);o.parent=child
# Export only geometry and moving pivots. The generated model is the source for all game views.
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=OUT,export_format='GLB',export_apply=True,export_yup=True,export_materials='EXPORT',export_cameras=False,export_lights=False)
triangles=sum(len(o.data.loop_triangles) for o in bpy.context.scene.objects if o.type=='MESH')
print('RUBICON_EXPORT',OUT,'bytes',os.path.getsize(OUT),'objects',len(bpy.context.scene.objects))
