"""Continuous crowned body sections for the C8-inspired wagon; coordinates in Godot metres."""
import math
import numpy as np
from mathutils import Vector
from mathutils.geometry import tessellate_polygon
import bmesh


def build(m, g):
    mesh,grid,shell,box,line,oval,text=[g[k] for k in ['mesh','grid','shell','box','line','oval','text']]
    paint,trim,black,chrome,glass,smoked,lens,led,red,redled,piano=[m[k] for k in ['paint','cladding','black','chrome','glass','smoked','lens','led','red','redled','piano']]
    # Cubic Hermite interpolation avoids a faceted longitudinal silhouette.
    def curve(z, points):
        xs=[p[0] for p in points];ys=[p[1] for p in points]
        z=max(xs[0],min(xs[-1],z));i=min(len(xs)-2,max(0,int(np.searchsorted(xs,z))-1))
        h=xs[i+1]-xs[i];t=(z-xs[i])/h
        d0=(ys[i+1]-ys[max(0,i-1)])/(xs[i+1]-xs[max(0,i-1)])
        d1=(ys[min(len(xs)-1,i+2)]-ys[i])/(xs[min(len(xs)-1,i+2)]-xs[i])
        return (2*t**3-3*t*t+1)*ys[i]+(t**3-2*t*t+t)*h*d0+(-2*t**3+3*t*t)*ys[i+1]+(t**3-t*t)*h*d1
    def rounded(points,r=.045):
        result=[]
        for i,p in enumerate(points):
            p=Vector(p);prev=Vector(points[i-1]);nxt=Vector(points[(i+1)%len(points)])
            a=p+(prev-p).normalized()*min(r,(prev-p).length*.25)
            b=p+(nxt-p).normalized()*min(r,(nxt-p).length*.25)
            for t in np.linspace(0,1,7):result.append(a*(1-t)**2+2*p*t*(1-t)+b*t*t)
        return result
    def inside(p,poly):
        x,y=p;hit=False;j=len(poly)-1
        for i in range(len(poly)):
            xi,yi=poly[i];xj,yj=poly[j]
            if (yi>y)!=(yj>y) and x<(xj-xi)*(y-yi)/(yj-yi)+xi:hit=not hit
            j=i
        return hit
    def perforated(name,fn,n,k,mat,exclude):
        verts=[fn(i/n,j/k) for j in range(k+1) for i in range(n+1)];faces=[]
        for j in range(k):
            for i in range(n):
                a=j*(n+1)+i;ids=(a,a+1,a+n+2,a+n+1)
                center=sum((Vector(verts[v]) for v in ids),Vector())/4
                if not exclude(center):faces.append(ids)
        return mesh(name,verts,faces,mat,smooth=True)
    def projected(name,poly,fn,mat):
        # Subdivide in surface coordinates before projection. A single n-gon
        # cuts through a crowned panel, hiding the middle of a lens or grille.
        verts=[];faces=[];cache={};n=8
        def vertex(p):
            key=(round(p.x,8),round(p.y,8))
            if key not in cache:
                cache[key]=len(verts);verts.append(fn(p.x,p.y))
            return cache[key]
        # Ear clipping also handles concave valance strips without overlapping fans.
        polygon=[Vector((p[0],p[1],0)) for p in poly]
        for tri in tessellate_polygon([polygon]):
            a,b,c=[polygon[index] for index in tri] if isinstance(tri[0],int) else tri
            ids={}
            for i in range(n+1):
                for j in range(n+1-i):ids[i,j]=vertex(a+(b-a)*(i/n)+(c-a)*(j/n))
            for i in range(n):
                for j in range(n-i):
                    faces.append((ids[i,j],ids[i+1,j],ids[i,j+1]))
                    if i+j<n-1:faces.append((ids[i+1,j],ids[i+1,j+1],ids[i,j+1]))
        return outward(name,verts,faces,mat)
    def outward(name,verts,faces,mat):
        # Open detail patches do not enclose a volume. Recalculating normals
        # alone cannot decide which way faces out, especially on mirrored lamps.
        center=sum((Vector(v) for v in verts),Vector())/len(verts)
        normal=sum(((Vector(verts[f[1]])-Vector(verts[f[0]])).cross(Vector(verts[f[2]])-Vector(verts[f[0]])) for f in faces),Vector())
        direction=Vector((0,0,math.copysign(1,center.z))) if abs(center.z)>1.9 else Vector((math.copysign(1,center.x),0,0))
        if normal.dot(direction)<0:faces=[tuple(reversed(f)) for f in faces]
        return mesh(name,verts,faces,mat,smooth=True)
    # The 2019 factory drawing locates the axles at +/-1.4625 m, with
    # 921 mm front and 1105 mm rear overhangs. The former mesh reversed this bias.
    FRONT, REAR = 2.3835, -2.5675
    FRONT_TANGENT, REAR_TANGENT = 2.04, -2.2475
    def width(z):
        return curve(z,[(-2.25,.923),(-1.7,.942),(-1.46,.949),(-.7,.921),(.6,.925),(1.46,.951),(2.04,.923)])
    def belt(z):
        return curve(z,[(-2.57,.655),(-2.25,.677),(-1.7,.700),(-.7,.682),(.90,.648),(1.45,.610),(1.95,.515),(2.18,.451),(2.3835,.388)])
    def roll(y,z=0):
        # Shoulder highlight, concave lower doors and an inward-turned sill.
        result=curve(y,[(-.17,-.072),(-.08,-.041),(.02,-.036),(.09,-.059),(.22,-.031),(.37,-.010),(.49,.002),(.535,.004),(.56,-.004),(.63,-.025),(.71,-.056)])
        result-=.016*math.exp(-((y-.105)/.075)**2)*math.exp(-(z/1.02)**8)
        return result
    def side_x(z,y):return width(z)+roll(y,z)
    def front_offset(y):
        return curve(y,[(-.17,-.105),(-.10,-.025),(.05,0),(.18,0),(.30,-.012),(.46,-.034),(.7,-.06)])
    def rear_offset(y):
        return curve(y,[(-.17,.095),(-.08,.005),(.05,0),(.17,.020),(.27,.060),(.38,.058),(.52,.045),(.66,.135)])
    def front_z(x,y):
        w=.923+roll(y,2.2); t=min(.999999,abs(x)/w)
        return FRONT_TANGENT+(FRONT-FRONT_TANGENT)*math.sqrt(1-t*t)+front_offset(y)
    def rear_z(x,y):
        w=.923+roll(y,-2.4);t=min(.999999,abs(x)/w)
        # Plate pocket is an actual depression in the tailgate.
        pocket=.034*math.exp(-(x/.31)**6)*math.exp(-((y-.385)/.075)**6)
        return REAR_TANGENT-(REAR_TANGENT-REAR)*math.sqrt(1-t*t)+rear_offset(y)+pocket
    def lower(z):
        h=-.155
        for c in [-1.4625,1.4625]:
            if abs(z-c)<.420:h=max(h,math.sqrt(.420**2-(z-c)**2)+.004)
        return h
    def plan(u):
        if u<.16:
            a=u/.16*math.pi/2
            return .923*math.sin(a),FRONT_TANGENT+(FRONT-FRONT_TANGENT)*math.cos(a)
        if u>.84:
            a=(u-.84)/.16*math.pi/2
            return .923*math.cos(a),REAR_TANGENT-(REAR_TANGENT-REAR)*math.sin(a)
        z=FRONT_TANGENT+(REAR_TANGENT-FRONT_TANGENT)*(u-.16)/.68
        return width(z),z
    def hull(u,v,side=1):
        px,z=plan(u);y=lower(z)+(belt(z)-lower(z))*v
        x=px*(1+roll(y,z)/width(z))
        if u<.16:z+=front_offset(y)
        elif u>.84:z+=rear_offset(y)+.034*math.exp(-(x/.31)**6)*math.exp(-((y-.385)/.075)**6)
        return side*x,y,z
    grille=rounded([(-.405,-.035),(-.465,-.010),(-.535,.295),(-.425,.382),(.425,.382),(.535,.295),(.465,-.010),(.405,-.035)],.023)
    lamps=rounded([(.433,.385),(.862,.447),(.902,.330),(.678,.285)],.014)
    intakes=rounded([(.585,-.067),(.856,-.064),(.858,.145),(.638,.163)],.028)
    def is_open(p):
        return p.z>1.94 and (inside((p.x,p.y),grille) or inside((abs(p.x),p.y),lamps) or inside((abs(p.x),p.y),intakes))
    # Each half is a single continuous wrap from the centre of the nose to the
    # centre of the tail. This removes the old vertical side/end panel joints.
    body_wrap=perforated('Continuous body and bumper wrap',lambda u,v:hull(u*2,v,1) if u<=.5 else hull(2-u*2,v,-1),760,54,paint,is_open)
    bm=bmesh.new();bm.from_mesh(body_wrap.data)
    bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.000001)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(body_wrap.data);bm.free()
    shell(body_wrap,.009)
    for side in [-1,1]:
        # The allroad arch is a broad molded strip, with lips returning into the well.
        for c in [-1.4625,1.4625]:
            def arch(u,v,c=c):
                a=-.31+u*(math.pi+.62);r=.423+.052*v;y=math.sin(a)*r;z=c+math.cos(a)*r
                return side*(side_x(z,y)+.005+math.sin(v*math.pi)*.009),y,z
            shell(grid('Molded wide allroad wheel arch',arch,96,12,trim),.014)
            grid('Wheelhouse return',lambda u,v,c=c:(side*(.69+.24*v),math.sin(u*math.pi)*.418,c+math.cos(u*math.pi)*.418),80,12,black)
            liner=[(side*.68,-.045,c+.418),(side*.68,-.045,c-.418)]
            liner.extend((side*.68,math.sin(a)*.418,c+math.cos(a)*.418) for a in np.linspace(math.pi,0,80))
            shell(mesh('Closed inner wheelhouse liner',liner,[tuple(range(len(liner)))],black),.004)
        grid('Pressed rocker cladding',lambda u,v:(side*(side_x(-.99+1.98*u,-.147+.12*v)+.008),-.147+.12*v,-.99+1.98*u),100,14,trim)
        grid('Sill aluminum insert',lambda u,v:(side*(side_x(-.95+1.90*u,-.128+.038*v)+.012),-.128+.038*v,-.95+1.90*u),80,6,chrome)
        # True door outlines: front hinge is almost vertical; the B pillar leans.
        for controls in [[(.98,-.03),(.95,.24),(.91,.56),(.85,.65)], [(-.16,-.05),(-.19,.30),(-.22,.68)], [(-.93,-.04),(-1.08,.18),(-1.25,.49),(-1.19,.70)]]:
            pts=[]
            for a,b in zip(controls,controls[1:]):
                for t in np.linspace(0,1,18):
                    z=a[0]*(1-t)+b[0]*t;y=a[1]*(1-t)+b[1]*t
                    if y>lower(z)+.012:pts.append((side*(side_x(z,y)+.0018),y,z))
            line('Door shut line',pts,.0014,black)
        for z in [-.04,-.98]:
            x=side_x(z,.545)
            box('Recessed handle pocket',(.009,.035,.158),(side*(x+.004),.545,z),black,.014)
            box('Flush painted pull',(.027,.026,.149),(side*(x+.012),.549,z),paint,.012)
        # Fuel door and the fine fender crease stay attached to the crowned skin.
        if side<0:
            poly=rounded([(-1.69,.59),(-1.38,.588),(-1.40,.43),(-1.68,.44)],.035)
            pts=[(side*(side_x(z,y)+.002),y,z) for z,y in poly]
            line('Fuel filler shut line',pts+[pts[0]],.0014,black)
        line('Mirror pedestal',[(side*.833,.674,.63),(side*.925,.668,.64)],.017,black)
        box('Mirror black lower cap',(.19,.048,.26),(side*.960,.690,.625),piano,.024)
        box('Mirror painted crown',(.185,.066,.25),(side*.960,.725,.625),paint,.032)
        box('Mirror glass',(.15,.064,.008),(side*.960,.713,.496),chrome,.025)
        line('Mirror signal',[(side*.907,.708,.748),(side*1.036,.708,.724)],.003,led)
    # Bonnet and fender crowns share the same wrap boundary. The nose falls
    # approximately 250 mm from the cowl; the old 150 mm drop made it slab-fronted.
    def front_edge(t):
        a=math.asin(abs(t)*.96);px=.923*math.sin(a);z=FRONT_TANGENT+(FRONT-FRONT_TANGENT)*math.cos(a)
        y=belt(z);x=px*(1+roll(y,z)/width(z))
        return math.copysign(x,t),y,z+front_offset(y),z
    def hood(u,v):
        t=-1+2*u;ex,ey,ez,bz=front_edge(t)
        x=t*.813*(1-v)+ex*v
        z=(.9-.025*(1-t*t))*(1-v)+ez*v
        y=(.650+.015*(1-t*t))*(1-v)+ey*v+.053*math.sin(math.pi*v)*(1-.32*t*t)
        y+=.007*math.exp(-((abs(t)-.77)/.055)**2)*math.sin(math.pi*v)
        return x,y,z
    shell(grid('Sculpted falling bonnet',hood,90,90,paint),.009)
    for side in [-1,1]:
        edge=[hood(1,v) for v in np.linspace(0,1,90)]
        line('Bonnet side shutline',[(side*x,y+.001,z) for x,y,z in edge],.0015,black)
        def crown(u,v):
            a=Vector(hood(1,u));z=a.z
            if z<=FRONT_TANGENT: b=Vector((side_x(z,belt(z)),belt(z),z))
            else:
                # Interpolate to the matching point on the rounded front wrap.
                basez=z-front_offset(a.y);c=max(0,min(1,(basez-FRONT_TANGENT)/(FRONT-FRONT_TANGENT)))
                angle=math.acos(c);u_wrap=angle/(math.pi/2)*.16;b=Vector(hull(u_wrap,1))
            p=a.lerp(b,v);p.y+=.009*math.sin(math.pi*v)*(1-u)
            return side*p.x,p.y,p.z
        grid('Bonnet to wheel shoulder',crown,100,16,paint)
    line('Bonnet front panel gap',[(hood(u,1)[0],hood(u,1)[1]+.001,hood(u,1)[2]) for u in np.linspace(0,1,150)],.0015,black)
    # Broad flat metal borders, rather than round tubes, make the Singleframe
    # read as a production pressing. All lamp/grille patches follow the wrap.
    def inset(poly,amount):
        center=sum((Vector(p) for p in poly),Vector((0,0)))/len(poly)
        return [Vector(p).lerp(center,amount) for p in poly]
    def band(name,outer,inner,fn,mat):
        n=len(outer);verts=[];faces=[];sub=6
        for j in range(5):
            for i in range(n*sub):
                k=i//sub;t=(i%sub)/sub
                a=Vector(outer[k]).lerp(Vector(outer[(k+1)%n]),t)
                b=Vector(inner[k]).lerp(Vector(inner[(k+1)%n]),t)
                verts.append(fn(*a.lerp(b,j/4)))
        count=n*sub
        for j in range(4):
            for i in range(count):
                nxt=(i+1)%count;faces.append((j*count+i,j*count+nxt,(j+1)*count+nxt,(j+1)*count+i))
        return outward(name,verts,faces,mat)
    f=lambda x,y:(x,y,front_z(x,y))
    projected('Singleframe recessed background',grille,lambda x,y:(x,y,front_z(x,y)-.033),piano)
    band('Singleframe satin aluminum frame',grille,inset(grille,.055),lambda x,y:(x,y,front_z(x,y)+.004),chrome)
    for y in np.linspace(.015,.345,8):
        half=.45 if y<.08 else (.49 if y<.28 else .45)
        projected('Grille horizontal black louvre',[(-half,y-.008),(half,y-.008),(half,y+.008),(-half,y+.008)],lambda x,y:(x,y,front_z(x,y)-.022),trim)
    for x in np.linspace(-.395,.395,6):
        poly=[(x-.007,-.008),(x+.007,-.008),(x+.008,.354),(x-.008,.354)]
        projected('Polished vertical grille blade',poly,lambda x,y:(x,y,front_z(x,y)-.010),chrome)
        for y in [.24,.31]:box('Grille cell',(.075,.028,.018),(x+.03,y,front_z(x+.03,y)-.024),piano,.004)
    for x in [-.12,-.04,.04,.12]:oval('Front four rings',(x,.302,front_z(0,.302)+.006),.056,.041,.0045,chrome)
    box('Front plate plinth',(.535,.112,.020),(0,.135,front_z(0,.135)+.001),black,.009)
    box('Front plate',(.515,.098,.007),(0,.135,front_z(0,.135)+.015),chrome,.004)
    text('Front plate lettering','A6 allroad',(0,.135,front_z(0,.135)+.020),.050,black)
    for side in [-1,1]:
        projected('Dark sculpted headlamp',lamps,lambda x,y:(side*x,y,front_z(x,y)-.006),piano)
        band('Headlamp perimeter seal',lamps,inset(lamps,.045),lambda x,y:(side*x,y,front_z(x,y)+.001),black)
        projected('Clear optical cover',lamps,lambda x,y:(side*x,y,front_z(x,y)+.013),lens)
        for i in range(3):
            yoff=i*.009;xoff=i*.011
            pts=[(.511,.371-yoff),(.691,.321-yoff),(.824+xoff,.346-yoff),(.852+xoff,.411)]
            line('Bent LED light guide',[(side*x,y,front_z(x,y)+.007) for x,y in pts],.0027,led)
        for x in [.62,.70,.78]:
            poly=[(x-.026,.371),(x+.026,.378),(x+.024,.396),(x-.026,.389)]
            projected('Matrix optic reflector',poly,lambda x,y:(side*x,y,front_z(x,y)+.002),chrome)
        projected('Recessed bumper intake',intakes,lambda x,y:(side*x,y,front_z(x,y)-.024),piano)
        band('Molded intake surround',intakes,inset(intakes,.10),lambda x,y:(side*x,y,front_z(x,y)+.004),trim)
        for y in np.linspace(-.035,.115,8):
            line('Bumper intake vane',[(side*x,y,front_z(x,y)-.012) for x in np.linspace(.65,.825,24)],.0034,trim)
        for x,y in [(.73,.21),(.84,.23)]:
            oval('Front parking sensor',(side*x,y,front_z(x,y)+.002),.012,.012,.0012,black)
        # Bumper recess and silver corners follow its plan-view turn into the side.
        strip=rounded([(.50,-.102),(.84,-.11),(.883,-.06),(.86,-.073),(.53,-.080)],.009)
        projected('Swept front silver corner',strip,lambda x,y:(side*x,y,front_z(x,y)+.006),chrome)
    projected('Lower central air slot',rounded([(-.49,-.084),(.49,-.084),(.43,-.052),(-.43,-.052)],.012),lambda x,y:(x,y,front_z(x,y)+.004),black)
    projected('Front skid plate',rounded([(-.55,-.148),(.55,-.148),(.60,-.112),(-.60,-.112)],.015),lambda x,y:(x,y,front_z(x,y)+.005),chrome)
    # Side glass is traced from the factory side elevation. The shorter roof and
    # long raked rear screen replace the former almost vertical station-wagon tail.
    def roofline(z):
        return curve(z,[(-2.23,.665),(-2.17,.704),(-1.85,.977),(-1.70,1.047),(-1.48,1.070),(-.8,1.087),(-.12,1.078),(.05,1.055),(.25,.986),(.52,.850),(.9,.650)])
    def cabin_x(z,y):
        t=max(0,min(1,(y-.665)/.43))
        return .865-.171*t+.010*math.sin(math.pi*t)-.016*max(0,min(1,(-z-1.6)/.8))
    windows=[[(.805,.666),(.23,.984),(.07,1.016),(-.22,1.018),(-.153,.684)],
             [(-.23,.686),(-.30,1.019),(-.95,1.009),(-1.18,.704)],
             [(-1.26,.707),(-1.07,.998),(-1.42,.979),(-1.91,.730)]]
    holes=[rounded(p,.032) for p in windows]
    for side in [-1,1]:
        def cabin(u,v):
            z=-2.23+3.13*u;y=.665+(roofline(z)-.665)*v
            return side*cabin_x(z,y),y,z
        shell(perforated('Continuous roof-side pressing',cabin,250,50,paint,lambda p:any(inside((p.z,p.y),poly) for poly in holes)),.012)
        for idx,poly in enumerate(holes):
            pts=[(side*(cabin_x(z,y)+.002),y,z) for z,y in poly]
            line('Thin window bonding seal',pts+[pts[0]],.0048,black)
            projected('Curved side glazing',poly,lambda z,y:(side*(cabin_x(z,y)-.003),y,z),glass if idx==0 else smoked)
        # A single bright surround frames all the windows; B/C pillars stay black.
        outer=rounded([(.84,.656),(.25,1.011),(.07,1.037),(-.95,1.033),(-1.44,1.003),(-2.02,.717),(-1.94,.698),(-.15,.665)],.05)
        pts=[(side*(cabin_x(z,y)+.003),y,z) for z,y in outer]
        line('Continuous bright window surround',pts+[pts[0]],.0042,chrome)
        for poly in [[(-.153,.68),(-.22,1.025),(-.30,1.025),(-.23,.68)],[(-1.18,.70),(-.95,1.014),(-1.07,1.01),(-1.26,.704)]]:
            projected('Gloss black pillar finish',poly,lambda z,y:(side*(cabin_x(z,y)+.004),y,z),piano)
        # Shoulder rolls gently inward to the glass; no raised chrome ridge.
        def shoulder(u,v):
            z=-2.24+3.14*u;yb=belt(z)
            return side*((1-v)*side_x(z,yb)+v*cabin_x(z,.665)),yb*(1-v)+.665*v,z
        grid('Shoulder into window sill',shoulder,150,10,paint)
    def roof(u,v):
        t=-1+2*u;z=.05-(1.85-.10*t*t)*v;y=roofline(z)
        return t*cabin_x(z,y),y+.029*(1-t*t),z
    shell(grid('Low doubly crowned roof',roof,70,90,paint),.015)
    grid('Cabin headliner',lambda u,v:(roof(u,v)[0],roof(u,v)[1]-.027,roof(u,v)[2]),35,45,m['headliner'])
    for back in [False,True]:
        def wind(u,v,back=back):
            t=-1+2*u
            if back:
                p=Vector((t*.845,.677,rear_z(t*.845,.677)+.003));q=Vector(roof(u,1))
                r=p.lerp(q,v);r.z-=.012*(1-t*t)*math.sin(math.pi*v)
                return tuple(r)
            z=.90-.85*v
            y=.650+.405*v
            w=cabin_x(z,y)-.015
            return t*w,y+.012*(1-t*t),z+(-1 if back else 1)*.027*(1-t*t)*math.sin(math.pi*v)
        # Ceramic frit is a border on a curved surface, not a round structural bar.
        for edge in range(4):
            def border(u,v,edge=edge):
                if edge==0:return wind(u,.035*v)
                if edge==1:return wind(u,1-.045*v)
                if edge==2:return wind(.025*v,u)
                return wind(1-.025*v,u)
            grid('Black ceramic glass border',border,70,6,piano)
        grid('Raked rear glazing' if back else 'Curved windshield',lambda u,v:wind(.025+.95*u,.034+.922*v),70,45,smoked if back else glass)
        for side in [-1,1]:
            def post(u,v,side=side):
                p=Vector(wind(0 if side<0 else 1,u));q=Vector((side*cabin_x(p.z,p.y),p.y,p.z))
                return tuple(p.lerp(q,v))
            grid('Integrated windscreen pillar',post,90,8,paint)
        if back:
            line('Rear screen wiper',[(-.30,.712,rear_z(-.30,.677)+.037),(.12,.712,rear_z(.12,.677)+.037)],.006,black)
        else:
            for x in [-.38,.32]:line('Flush aero wiper',[(x-.18,.670,.898),(x+.16,.681,.878)],.005,black)
    # A sculpted short spoiler continues the roof curvature over the rear screen.
    def spoiler(u,v):
        t=-1+2*u;x=t*.717;z=-1.76-.18*v+.10*t*t
        return x,roofline(-1.80+.10*t*t)+.029*(1-t*t)-.022*v+.008*math.sin(math.pi*v),z
    shell(grid('Integrated tail spoiler',spoiler,60,14,paint),.018)
    line('Spoiler stop lamp',[(-.25,1.018,-1.933),(.25,1.018,-1.933)],.004,redled)
    box('Shark fin antenna',(.042,.055,.112),(0,1.134,-1.48),paint,.019)
    for side in [-1,1]:
        def rail(u,v):
            z=-.08-1.53*u;a=v*math.tau;y=roofline(z)+.036+.015*math.sin(math.pi*u)
            return side*.625+.016*math.cos(a),y+.009*math.sin(a),z
        grid('Low oval aluminum roof rail',rail,90,12,chrome)
        for z in [-.08,-1.61]:box('Rail foot',(.033,.031,.10),(side*.625,roofline(z)+.019,z),trim,.014)
    # A rear deck joins the raked screen to the upper tailgate shoulder.
    for side in [-1,1]:
        def deck(u,v):
            x=side*u*.86;y=.677
            p=Vector((x,y,rear_z(x,y)+.003));q=Vector((x,.655,rear_z(x,.655)))
            return tuple(p.lerp(q,v))
        grid('Rear window to tailgate crown',deck,60,10,paint)
    tail_lamp=rounded([(.31,.574),(.75,.613),(.906,.623),(.910,.456),(.783,.443),(.355,.514)],.015)
    for side in [-1,1]:
        projected('Smoked rear lamp housing',tail_lamp,lambda x,y:(side*x,y,rear_z(x,y)-.005),piano)
        band('Ruby perimeter of rear lamp',tail_lamp,inset(tail_lamp,.13),lambda x,y:(side*x,y,rear_z(x,y)-.010),red)
        pts=[(.33,.547),(.75,.548),(.805,.592),(.884,.600),(.857,.484),(.79,.480)]
        line('Continuous rear light guide',[(side*x,y,rear_z(x,y)-.014) for x,y in pts],.0065,redled)
        for x in np.linspace(.40,.77,9):
            y=.505+(x-.40)*.015
            line('Rear segmented LED',[(side*x,y,rear_z(x,y)-.012),(side*(x-.012),y+.025,rear_z(x-.012,y+.025)-.012)],.0037,redled)
        # Reflectors, rather than the fictitious exposed chrome exhaust tubes.
        reflector=rounded([(.48,-.010),(.84,-.014),(.875,.031),(.50,.038)],.018)
        projected('Rear bumper reflector',reflector,lambda x,y:(side*x,y,rear_z(x,y)-.007),red)
        for x,y in [(.74,.14),(.34,.15)]:oval('Rear parking sensor',(side*x,y,rear_z(x,y)-.004),.012,.012,.0012,black)
        pts=[]
        for x,y in [(.66,.67),(.655,.56),(.64,.37),(.61,.27),(.54,.225),(0,.225)]:
            pts.append((side*x,y,rear_z(x,y)-.002))
        line('Tailgate opening line',pts,.0016,black)
        text('A6 rear badge' if side>0 else 'allroad rear badge','A6' if side>0 else 'allroad',(side*.54,.34,rear_z(.54,.34)-.010),.038 if side>0 else .025,chrome,False)
    line('Rear aluminum light bridge',[(x,.550,rear_z(x,.550)-.010) for x in np.linspace(-.83,.83,120)],.004,chrome)
    for cx in [-.12,-.04,.04,.12]:
        pts=[]
        for a in np.linspace(0,math.tau,65):
            x=cx+.055*math.cos(a);y=.627+.038*math.sin(a)
            pts.append((x,y,rear_z(x,y)-.013))
        line('Tailgate four rings',pts,.004,chrome)
    box('Rear plate surround',(.535,.115,.015),(0,.385,rear_z(0,.385)-.008),black,.009)
    box('Rear registration plate',(.515,.098,.007),(0,.385,rear_z(0,.385)-.019),chrome,.004)
    text('Rear registration lettering','A6 allroad',(0,.385,rear_z(0,.385)-.024),.050,black,False)
    grid('Rear lower molded valance',lambda u,v:((-1+2*u)*.875,-.151+.095*v,rear_z((-1+2*u)*.875,-.151+.095*v)-.007),120,18,trim)
    strip=rounded([(-.84,-.045),(-.48,-.038),(-.39,.002),(.39,.002),(.48,-.038),(.84,-.045),(.86,-.014),(.49,-.010),(.39,.033),(-.39,.033),(-.49,-.010),(-.86,-.014)],.012)
    projected('Shaped rear silver bumper strip',strip,lambda x,y:(x,y,rear_z(x,y)-.011),chrome)
    guard=rounded([(-.56,-.135),(.56,-.135),(.40,-.064),(-.40,-.064)],.02)
    projected('Rear underbody aluminum guard',guard,lambda x,y:(x,y,rear_z(x,y)-.012),chrome)
    box('Engine bay dark enclosure',(1.43,.10,1.25),(0,.27,1.38),black,.025)
