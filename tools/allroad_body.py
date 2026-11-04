"""Continuous crowned body sections for the C8-inspired wagon; coordinates in Godot metres."""
import math
import numpy as np
from mathutils import Vector


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
    def width(z):
        return curve(z,[(-2.34,.935),(-2.06,.944),(-1.46,.948),(-.55,.925),(.55,.927),(1.46,.95),(2.05,.944),(2.34,.935)])
    def belt(z):
        return curve(z,[(-2.34,.625),(-1.9,.67),(-.5,.65),(.95,.655),(1.5,.64),(2.0,.60),(2.34,.55)])
    def lower(z):
        h=-.115
        for c in [-1.4625,1.4625]:
            if abs(z-c)<.416:h=max(h,math.sqrt(.416**2-(z-c)**2)+.008)
        return h
    def skin_x(z,y):
        # The entire side rolls inward at the sill and above the shoulder.
        roll=curve(y,[(-.15,-.105),(-.03,-.065),(.14,-.035),(.30,-.012),(.46,0),(.52,.006),(.555,-.005),(.61,-.029),(.69,-.065)])
        # A shallow lower door scallop, blending out before the flared fenders.
        scallop=.013*math.exp(-((y-.20)/.085)**2)*math.exp(-(z/.98)**6)
        return width(z)+roll-scallop
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
        center=sum((Vector(p) for p in poly),Vector((0,0)))/len(poly)
        verts=[fn(*center)];faces=[];count=len(poly)
        for ring in range(1,13):
            for p in poly:verts.append(fn(*(center.lerp(Vector(p),ring/12))))
            start=1+(ring-1)*count
            for i in range(count):
                nxt=(i+1)%count
                if ring==1:faces.append((0,start+i,start+nxt))
                else:faces.append((start-count+i,start+i,start+nxt,start-count+nxt))
        return mesh(name,verts,faces,mat,smooth=True)
    # Four flowing wheel shoulders emerge from a rounded lower body, not a box.
    for side in [-1,1]:
        def side_surface(u,v):
            z=-2.29+u*4.58;y=lower(z)+(belt(z)-lower(z))*v
            return (side*skin_x(z,y),y,z)
        shell(grid('Continuous convex body flank',side_surface,260,32,paint),.016)
        for c in [-1.4625,1.4625]:
            def arch(u,v,c=c):
                a=-.20+u*(math.pi+.40);r=.419+v*.037;y=math.sin(a)*r;z=c+math.cos(a)*r
                return (side*(skin_x(z,y)+.009+math.sin(v*math.pi)*.005),y,z)
            shell(grid('Rounded allroad arch cladding',arch,80,8,trim),.017)
            grid('Inner wheel housing',lambda u,v,c=c:(side*(.68+.26*v),math.sin(u*math.pi)*.414,c+math.cos(u*math.pi)*.414),64,10,black)
        # Wide shoulder becomes an inward-turning window sill, so the greenhouse
        # grows from the body instead of standing on a separate straight rail.
        grid('Window shoulder blend',lambda u,v:(side*((skin_x(-2.28+u*3.20,belt(-2.28+u*3.20)))*(1-v)+.866*v),belt(-2.28+u*3.20)*(1-v)+.675*v,-2.28+u*3.20),140,8,paint)
        box('Sill protection',(.07,.10,1.96),(side*.86,-.075,0),trim,.035)
        line('Sill aluminum accent',[(side*.903,-.078,z) for z in np.linspace(-.96,.96,40)],.009,chrome)
        for tz,bz in [(.91,.70),(-.43,-.41),(-1.48,-.94)]:
            pts=[]
            for t in np.linspace(0,1,65):
                y=-.025+t*.68;z=bz+(tz-bz)*t
                if y>lower(z)+.012:pts.append((side*(skin_x(z,y)+.0015),y,z))
            line('Pressed door shutline',pts,.0015,black)
        for z in [-.25,-1.16]:
            x=skin_x(z,.535)
            box('Handle recess',(.012,.039,.17),(side*(x+.006),.535,z),black,.015)
            box('Body colored pull handle',(.025,.025,.145),(side*(x+.018),.542,z),paint,.011)
        line('Mirror stalk',[(side*.84,.70,.65),(side*.98,.69,.64)],.018,black)
        box('Mirror sculpted shell',(.19,.09,.24),(side*1.01,.728,.63),paint,.043)
        box('Mirror face',(.15,.059,.007),(side*1.01,.73,.507),chrome,.022)
        line('Mirror repeater',[(side*.95,.71,.747),(side*1.08,.71,.722)],.004,led)
    # Hood with a rounded planform, crown, two shoulder creases and falling nose.
    def hood(u,v):
        t=-1+2*u;end=2.455-.20*abs(t)**2.3;z=.94+v*(end-.94)
        x=t*(width(z)-.052)
        y=.680-.150*(v*v*(3-2*v))+.025*(1-t*t)
        y+=.010*math.exp(-((abs(t)-.67)/.055)**2)*math.sin(math.pi*v)
        return x,y,z
    shell(grid('Crowned compound-curvature bonnet',hood,72,80,paint),.016)
    for side in [-1,1]:
        line('Bonnet shutline',[(side*hood(1,v)[0],hood(1,v)[1]+.0015,hood(1,v)[2]) for v in np.linspace(0,1,90)],.0017,black)
        def fender(u,v):
            edge=Vector(hood(1,u));z=edge.z;out=Vector((skin_x(z,belt(z)),belt(z),z))
            p=edge.lerp(out,v);p.y+=.010*math.sin(v*math.pi)
            return side*p.x,p.y,p.z
        grid('Flowing bonnet to fender crown',fender,90,12,paint)
    def nose_z(x,y):
        return 2.505-.14*(abs(x)/.94)**3.2+curve(y,[(-.12,-.10),(-.04,-.018),(.10,.0),(.28,-.012),(.43,-.030),(.61,-.050)])
    grille=rounded([(-.46,-.035),(-.57,.09),(-.56,.37),(-.44,.49),(.44,.49),(.56,.37),(.57,.09),(.46,-.035)],.030)
    lamps=[(.48,.535),(.65,.425),(.913,.455),(.912,.585)]
    def front(u,v):
        t=-1+2*u;y=-.11+v*.70;x=t*(.86+.065*math.sin(v*math.pi*.82))
        return x,y,nose_z(x,y)
    front_shell=perforated('Sculpted nose with real grille apertures',front,140,68,paint,lambda p:inside((p.x,p.y),grille) or inside((abs(p.x),p.y),lamps))
    shell(front_shell,.018)
    # Rounded returns share the same end cross-sections as the side skins.
    for side in [-1,1]:
        def corner(u,v,side=side):
            y=-.115+(belt(2.29)+.115)*v;a=Vector((side*skin_x(2.29,y),y,2.29));b=Vector(front(1 if side>0 else 0,v))
            control=Vector((a.x,(a.y+b.y)/2,b.z))
            return tuple(a*(1-u)**2+control*2*u*(1-u)+b*u*u)
        shell(grid('Swept front corner',corner,20,32,paint),.017)
    # Close the short curved lip between the bonnet and the nose.
    grid('Bonnet nose hem',lambda u,v:tuple(Vector(hood(u,1)).lerp(Vector(front(u,1)),v)),72,10,paint)
    projected('Deep black Singleframe',grille,lambda x,y:(x,y,nose_z(x,y)-.026),piano)
    line('Singleframe rim',[(x,y,nose_z(x,y)+.004) for x,y in grille+[grille[0]]],.010,chrome)
    for x in np.linspace(-.43,.43,6):
        line('Vertical grille blade',[(x,y,nose_z(x,y)-.009) for y in np.linspace(.01,.445,25)],.007,chrome)
    for y in np.linspace(.04,.42,8):line('Recessed grille crossbar',[(x,y,nose_z(x,y)-.015) for x in np.linspace(-.5,.5,50)],.004,trim)
    for x in [-.105,-.035,.035,.105]:oval('Audi rings',(x,.335,nose_z(0,.335)+.014),.051,.034,.0045,chrome)
    box('Number plate',(.48,.086,.015),(0,.14,nose_z(0,.14)+.012),black,.005)
    text('A6 allroad front plate','A6 allroad',(0,.14,nose_z(0,.14)+.022),.043,chrome)
    for side in [-1,1]:
        outline=rounded(lamps,.012)
        pts=[(side*x,y,nose_z(x,y)+.005) for x,y in outline]
        shell(projected('Recessed matrix lamp housing',outline,lambda x,y:(side*x,y,nose_z(x,y)+.005),piano),.012)
        line('Headlamp black perimeter',pts+[pts[0]],.009,black)
        projected('Optical lamp cover',outline,lambda x,y:(side*x,y,nose_z(x,y)+.026),lens)
        drl=[(.53,.526),(.666,.466),(.875,.484),(.884,.552)]
        line('Signature LED light guide',[(side*x,y,nose_z(x,y)+.017) for x,y in drl],.006,led)
        for x in np.linspace(.69,.85,5):
            y=.50+(x-.69)*.08
            line('Matrix emitter',[(side*x,y,nose_z(x,y)+.018),(side*(x+.012),y+.027,nose_z(x+.012,y+.027)+.018)],.003,led)
        intake=rounded([(.63,.015),(.86,.008),(.875,.19),(.65,.22)],.025)
        mesh('Lower corner intake',[(side*x,y,nose_z(x,y)+.006) for x,y in intake],[tuple(range(len(intake)))],black)
        for y in [.055,.10,.145]:line('Intake louvre',[(side*x,y,nose_z(x,y)+.014) for x in np.linspace(.66,.84,15)],.005,trim)
    line('Front aluminum protection',[(x,-.108,nose_z(x,-.108)+.008) for x in np.linspace(-.77,.77,70)],.019,chrome)
    grid('Curved lower front valance',lambda u,v:((-1+2*u)*.83,-.11+.065*v,nose_z((-1+2*u)*.83,-.11+.065*v)+.009),100,12,trim)
    # Greenhouse: one smooth painted shell with window openings, rather than bars
    # meeting at sharp corners. Its longitudinal crown follows the actual wagon roof.
    def cabin_top(z):return curve(z,[(-2.32,.67),(-2.04,1.025),(-1.77,1.09),(-1.1,1.125),(-.2,1.13),(.28,1.09),(.58,.91),(.94,.68)])
    def cabin_x(z,y):
        t=max(0,min(1,(y-.67)/.46));return .868-.176*t+.018*math.sin(t*math.pi)-.010*max(0,(-z-1.6)/.7)
    windows=[[(.85,.70),(.28,1.055),(-.43,1.075),(-.43,.695)],[(-.50,.695),(-.50,1.075),(-1.30,1.058),(-1.47,.699)],[(-1.55,.704),(-1.39,1.049),(-1.77,1.021),(-2.16,.717)]]
    holes=[rounded(p,.045) for p in windows]
    for side in [-1,1]:
        def side_cabin(u,v):
            z=-2.32+u*3.26;y=.671+(cabin_top(z)-.671)*v
            return side*cabin_x(z,y),y,z
        shell(perforated('Continuous painted greenhouse',side_cabin,180,36,paint,lambda p:any(inside((p.z,p.y),poly) for poly in holes)),.022)
        for idx,poly in enumerate(holes):
            # Glazing is a slightly inset curved patch. Its outline covers the
            # fine tessellation of the hole beneath a rubber seal.
            pts=[(side*(cabin_x(z,y)+.003),y,z) for z,y in poly]
            line('Window rubber seal',pts+[pts[0]],.009,black)
            mesh('Side glazing',[(side*(cabin_x(z,y)-.006),y,z) for z,y in poly],[tuple(range(len(poly)))],glass if idx==0 else smoked)
        line('Window chrome upper',[(side*(cabin_x(z,cabin_top(z))+.005),cabin_top(z),z) for z in np.linspace(-2.25,.88,170)],.005,chrome)
        line('Window chrome sill',[(side*(cabin_x(z,.68)+.003),.68,z) for z in np.linspace(-2.25,.88,130)],.005,chrome)
        grid('Satin black B pillar',lambda u,v:(side*(cabin_x(-.435-u*.06,.683+v*.404)+.006),.683+v*.404,-.435-u*.06),6,30,piano)
    # The roof has a crown along both axes and rolls down to meet the side shell.
    def roof(u,v):
        z=.28-v*2.28;t=-1+2*u;edge=cabin_top(z);w=cabin_x(z,edge)
        return t*w,edge+.036*(1-t*t),z
    shell(grid('Double curved wagon roof',roof,52,88,paint),.024)
    grid('Headliner',lambda u,v:(roof(u,v)[0],roof(u,v)[1]-.035,roof(u,v)[2]),28,45,m['headliner'])
    for rear in [False,True]:
        def wind(u,v,rear=rear):
            t=-1+2*u
            z=(-2.325+v*.325) if rear else (.94-v*.66)
            y=(.673+v*.40) if rear else (.686+v*.402)
            w=(.805-v*.09) if rear else (.812-v*.081)
            return t*w,y+.009*(1-t*t),z+(.022*(1-t*t))*(-1 if rear else 1)
        grid('Backlight' if rear else 'Curved windshield',wind,52,28,smoked if rear else glass)
        for edge in [[wind(i/50,0) for i in range(51)],[wind(i/50,1) for i in range(51)],[wind(0,i/40) for i in range(41)],[wind(1,i/40) for i in range(41)]]:line('Windshield bonding gasket',edge,.009,black)
        # Broad, smoothly joined pillars and headers eliminate daylight gaps.
        for side in [-1,1]:
            line('Painted windscreen pillar',[wind(0 if side<0 else 1,i/50) for i in range(51)],.023,paint)
        line('Windscreen header',[wind(i/50,1) for i in range(51)],.023,paint)
        if not rear:
            for x in [-.39,.31]:line('Aero wiper',[(x-.19,.699,.96),(x+.16,.708,.95)],.006,black)
        else:line('Rear wiper',[(-.33,.724,-2.30),(.12,.724,-2.30)],.006,black)
    for side in [-1,1]:
        pts=[]
        for z in np.linspace(.05,-1.75,65):
            t=(.05-z)/1.8;pts.append((side*.62,cabin_top(z)+.062+.012*math.sin(t*math.pi),z))
        line('Integrated roof rail',pts,.014,chrome)
        for z in [.03,-.83,-1.72]:box('Rail mounting foot',(.034,.04,.085),(side*.62,cabin_top(z)+.039,z),black,.013)
    box('Rear roof spoiler',(1.43,.035,.17),(0,1.08,-2.015),paint,.017)
    box('Roof antenna',(.045,.055,.105),(0,1.19,-1.31),paint,.018)
    line('High brake light',[(-.27,1.063,-2.105),(.27,1.063,-2.105)],.006,redled)
    # A rounded tailgate and rear quarters with lamps following the same surface.
    def tail_z(x,y):return -2.44+.08*(abs(x)/.91)**3+curve(y,[(-.12,.070),(-.04,.015),(.14,.0),(.30,.025),(.44,.015),(.58,.028),(.69,.055)])
    def rear(u,v):
        t=-1+2*u;y=-.11+v*.79;x=t*(.84+.06*math.sin(v*math.pi))
        return x,y,tail_z(x,y)
    shell(grid('Crowned tailgate and rear apron',rear,100,48,paint),.018)
    for side in [-1,1]:
        def corner(u,v):
            y=-.115+(belt(-2.29)+.115)*v;a=Vector((side*skin_x(-2.29,y),y,-2.29));b=Vector(rear(1 if side>0 else 0,v));c=Vector((a.x,(a.y+b.y)/2,b.z))
            return tuple(a*(1-u)**2+c*2*u*(1-u)+b*u*u)
        shell(grid('Rounded rear quarter return',corner,20,32,paint),.018)
        poly=rounded([(.28,.505),(.84,.47),(.875,.605),(.30,.60)],.014)
        pts=[(side*x,y,tail_z(x,y)-.008) for x,y in poly]
        projected('Tail lamp ruby lens',poly,lambda x,y:(side*x,y,tail_z(x,y)-.009),red)
        line('Rear light guide',[(side*x,y,tail_z(x,y)-.018) for x,y in [(.30,.571),(.81,.551),(.84,.50)]],.006,redled)
        for x in np.linspace(.34,.78,8):line('Rear light segment',[(side*x,.52,tail_z(x,.52)-.018),(side*(x+.012),.55,tail_z(x+.012,.55)-.018)],.004,redled)
        box('Rear exhaust trim',(.24,.046,.025),(side*.64,-.055,tail_z(.64,-.055)-.01),chrome,.019)
        box('Rear exhaust mouth',(.20,.025,.012),(side*.64,-.055,tail_z(.64,-.055)-.026),black,.010)
    line('Tailgate bright strip',[(x,.50,tail_z(x,.50)-.017) for x in np.linspace(-.80,.80,100)],.005,chrome)
    for side in [-1,1]:
        line('Tailgate shutline',[(side*x,y,tail_z(x,y)-.002) for x,y in [(.79,.64),(.78,.44),(.74,.20),(.68,.14),(0,.14)]],.0017,black)
    for x in [-.105,-.035,.035,.105]:oval('Tailgate four rings',(x,.61,tail_z(0,.61)-.016),.051,.032,.0045,chrome)
    box('Rear model plate',(.47,.087,.014),(0,.32,-2.447),black,.006)
    text('Rear number plate','A6 allroad',(0,.32,-2.458),.043,chrome,False)
    text('A6 badge','A6',(.67,.38,tail_z(.67,.38)-.012),.037,chrome,False)
    text('allroad badge','allroad',(-.62,.38,tail_z(.62,.38)-.012),.027,chrome,False)
    line('Rear bumper cladding',[(x,-.02,tail_z(x,-.02)+.005) for x in np.linspace(-.82,.82,100)],.045,trim)
    line('Rear aluminum skid',[(x,-.106,tail_z(x,-.106)-.006) for x in np.linspace(-.65,.65,70)],.019,chrome)
    box('Engine compartment liner',(1.48,.13,1.40),(0,.39,1.35),black,.025)
