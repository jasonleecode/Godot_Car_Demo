extends "res://cars/OffroadChassis.gd"
## JL layout referenced against real underside photographs; +X is driver/left, +Z front.
var seats: Array[Node3D] = []
var boots: Array[MeshInstance3D] = []
var arm_eyes: Array[Node3D] = []
var sway_links: Array[MeshInstance3D] = []
var hoses: Array[MeshInstance3D] = []
var drag_link: MeshInstance3D
var steering_damper: MeshInstance3D
var steering_piston: MeshInstance3D
var exhaust := material(Color("79766b"),0.65)
var cast_alloy := material(Color("727777"),0.55)

func ring(parent: Node3D, label: String, radius: float, wire: float, pos: Vector3, mat: Material) -> Node3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius-wire
	mesh.outer_radius = radius+wire
	mesh.rings = 24
	mesh.ring_segments = 8
	return piece(parent,label,mesh,pos,mat)

func housing(parent: Node3D, outline: Array[Vector2], depth: float, mat: Material, label: String) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := outline.size()
	for i in range(n):
		var a := outline[i]
		var b := outline[(i+1)%n]
		for front in [-1.0,1.0]:
			var normal := Vector3(0,0,front)
			var vertices := [Vector3(0,0,front*depth/2),Vector3(a.x,a.y,front*depth/2),Vector3(b.x,b.y,front*depth/2)]
			if front<0: vertices.reverse()
			for vertex in vertices:
				surface.set_normal(normal)
				surface.add_vertex(vertex)
		var normal := Vector3(b.y-a.y,a.x-b.x,0).normalized()
		for vertex in [Vector3(a.x,a.y,-depth/2),Vector3(b.x,b.y,-depth/2),Vector3(b.x,b.y,depth/2),Vector3(a.x,a.y,-depth/2),Vector3(b.x,b.y,depth/2),Vector3(a.x,a.y,depth/2)]:
			surface.set_normal(normal)
			surface.add_vertex(vertex)
	piece(parent,label,surface.commit(),Vector3.ZERO,mat)

func frame_rail(side: float) -> void:
	var path := [Vector3(side*0.52,0.24,2.2),Vector3(side*0.52,0.32,1.50),Vector3(side*0.53,0.16,0.75),Vector3(side*0.54,0.13,-0.72),Vector3(side*0.56,0.30,-1.35),Vector3(side*0.56,0.32,-1.72),Vector3(side*0.56,0.24,-2.2)]
	for i in range(path.size()-1):
		var a: Vector3 = path[i]
		var b: Vector3 = path[i+1]
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		var corners := [Vector3(-0.055,-0.08,0),Vector3(0.055,-0.08,0),Vector3(0.055,0.08,0),Vector3(-0.055,0.08,0)]
		for edge in range(4):
			var p: Vector3 = corners[edge]
			var q: Vector3 = corners[(edge+1)%4]
			for v in [a+p,b+p,b+q,a+p,b+q,a+q]:surface.add_vertex(v)
		surface.generate_normals()
		piece(self,"BoxedFrameRail",surface.commit(),Vector3.ZERO,steel)
	for z in [0.7,-0.3,-1.1]:
		box(self,"BodyMountOutrigger",Vector3(0.26,0.06,0.12),Vector3(side*0.64,0.17,z),steel)
		fixed_rod(self,"BodyMountRubber",Vector3(side*0.74,0.17,z),Vector3(side*0.74,0.24,z),0.052,dark)

func configure(wheel_mounts: Array, _detailed: bool) -> void:
	mounts = wheel_mounts.duplicate()
	steel = material(Color("242a2c"),0.40)
	steel.roughness = 0.52
	dark = material(Color("171c1d"),0.10)
	exhaust.roughness = 0.66
	cast_alloy.roughness = 0.66
	for side in [-1.0,1.0]: frame_rail(side)
	for z in [1.95,0.55,-0.5,-1.9]:
		box(self,"FrameCrossmember",Vector3(1.12,0.08,0.12),Vector3(0,0.19,z),steel)
	# Cast sump, bellhousing and gearbox lead into an offset transfer case.
	box(self,"EngineOilSump",Vector3(0.42,0.16,0.40),Vector3(0,0.19,0.98),cast_alloy)
	fixed_rod(self,"Bellhousing",Vector3(0,0.18,0.79),Vector3(0,0.18,0.57),0.19,cast_alloy)
	fixed_rod(self,"Transmission",Vector3(0,0.16,0.62),Vector3(0,0.16,-0.22),0.125,cast_alloy)
	for z in [0.45,0.25,0.05,-0.15]:
		box(self,"GearboxCastingRib",Vector3(0.25,0.018,0.035),Vector3(0,0.028,z),alloy)
	var transfer := Node3D.new()
	transfer.name = "TransferCase"
	add_child(transfer)
	transfer.position = Vector3(0.13,0.13,-0.28)
	housing(transfer,[Vector2(-0.2,-0.09),Vector2(0.16,-0.11),Vector2(0.24,0.03),Vector2(0.13,0.15),Vector2(-0.16,0.12)],0.22,cast_alloy,"CastTransferHousing")
	# Separate ribbed protective plates leave the propshafts and exhaust visible.
	for setup in [[Vector3(0,0.005,0.78),Vector3(0.56,0.035,0.52)],[Vector3(0.05,-0.015,-0.24),Vector3(0.66,0.04,0.55)]]:
		var p: Vector3 = setup[0]
		box(self,"PressedSkidPlate",setup[1],p,steel)
		for x in [-0.19,0,0.19]:
			box(self,"SkidPressedRib",Vector3(0.025,0.018,0.37),p+Vector3(x,-0.023,0),steel)
	# Passenger-side tank and stamped cradle, opposite the longitudinal exhaust.
	box(self,"FuelTank",Vector3(0.43,0.16,1.62),Vector3(-0.31,0.07,-0.42),dark)
	box(self,"FuelTankCradle",Vector3(0.48,0.035,1.70),Vector3(-0.31,-0.025,-0.42),steel)
	for x in [-0.49,-0.31,-0.13]:
		box(self,"TankSkidPressedRib",Vector3(0.025,0.018,1.43),Vector3(x,-0.05,-0.42),steel)
	for z in [0.28,-0.35,-1.10]:
		box(self,"TankStrap",Vector3(0.50,0.025,0.045),Vector3(-0.31,-0.06,z),steel)
	# Exhaust rises over the rear axle, then enters a transverse rear muffler.
	var exhaust_path := [Vector3(0.30,0.19,1.1),Vector3(0.39,0.06,0.65),Vector3(0.40,0.07,-0.65),Vector3(0.39,0.25,-1.15),Vector3(0.40,0.38,-1.50),Vector3(0.40,0.25,-1.88)]
	for i in range(exhaust_path.size()-1):
		fixed_rod(self,"ExhaustPipe",exhaust_path[i],exhaust_path[i+1],0.033,exhaust)
	fixed_rod(self,"CatalystResonator",Vector3(0.4,0.09,0.12),Vector3(0.4,0.09,-0.40),0.08,exhaust)
	var muffler := fixed_rod(self,"RearTransverseMuffler",Vector3(-0.50,0.21,-1.97),Vector3(0.50,0.21,-1.97),0.155,exhaust)
	muffler.basis = muffler.basis.scaled(Vector3(1,0.72,1))
	for x in [-0.5,0.5]:fixed_rod(self,"MufflerSeam",Vector3(x-0.008,0.21,-1.97),Vector3(x+0.008,0.21,-1.97),0.15,alloy)
	fixed_rod(self,"TailpipeBend",Vector3(0.49,0.21,-1.97),Vector3(0.62,0.15,-2.16),0.033,exhaust)
	fixed_rod(self,"TailpipeOutlet",Vector3(0.62,0.15,-2.16),Vector3(0.62,0.14,-2.31),0.038,steel)
	box(self,"ExhaustHeatShield",Vector3(0.27,0.015,1.18),Vector3(0.35,0.19,-0.25),alloy)
	var coil := coil_mesh()
	for i in range(4):
		shocks.append(rod(self,"RedShockBody%d" % i,0.034,red))
		pistons.append(rod(self,"ShockPiston%d" % i,0.014,chrome))
		boots.append(rod(self,"ShockDustShield%d" % i,0.036,dark))
		springs.append(piece(self,"CoilSpring%d" % i,coil,Vector3.ZERO,steel))
		var seat := Node3D.new()
		seat.name = "AxleSpringSeat%d" % i
		add_child(seat)
		seats.append(seat)
		fixed_rod(seat,"SpringCup",Vector3(0,-0.01,0),Vector3(0,0.012,0),0.098,steel)
		box(seat,"WeldedAxleBracket",Vector3(0.14,0.075,0.13),Vector3(0,-0.04,0),steel)
		var side := signf(mounts[i].x)
		var bump: Vector3 = mounts[i]+Vector3(-side*0.27,-0.13,0)
		fixed_rod(self,"BumpStop",bump,bump-Vector3.UP*0.095,0.044,material(Color("a89464"),0))
		var hub := Node3D.new()
		hub.name = "SteeringKnuckle%d" % i
		add_child(hub)
		hubs.append(hub)
		fixed_rod(hub,"AxleHub",Vector3(-0.08,0,0),Vector3(0.08,0,0),0.073,steel)
		fixed_rod(hub,"BrakeDisc",Vector3(-0.01,0,0),Vector3(0.01,0,0),0.16,alloy)
		box(hub,"BrakeCaliper",Vector3(0.07,0.15,0.09),Vector3(0,0.07,-0.115),steel)
		for y in [-0.08,0.08]:
			box(hub,"KnuckleEar",Vector3(0.095,0.045,0.08),Vector3(-side*0.045,y,0),steel)
		for upper in range(2):
			arms.append(rod(self,"UpperControlArm" if upper else "LowerControlArm",0.023 if upper else 0.029,steel))
			for end in range(2):
				var eye := Node3D.new()
				add_child(eye)
				fixed_rod(eye,"RubberLinkBushing",Vector3(-0.035,0,0),Vector3(0.035,0,0),0.041,dark)
				fixed_rod(eye,"LinkPivotBolt",Vector3(-0.047,0,0),Vector3(0.047,0,0),0.013,alloy)
				arm_eyes.append(eye)
		sway_links.append(rod(self,"SwayBarEndLink",0.012,steel))
		for segment in range(2):hoses.append(rod(self,"FlexibleBrakeHose",0.005,dark))
	for axle in range(2):
		axles.append(rod(self,"SolidAxleTube%d" % axle,0.052,steel))
		var diff := Node3D.new()
		diff.name = "DanaStyleDifferential%d" % axle
		add_child(diff)
		differentials.append(diff)
		var outline: Array[Vector2] = [Vector2(-0.10,0.15),Vector2(0.09,0.15),Vector2(0.16,0.10),Vector2(0.18,-0.025),Vector2(0.13,-0.14),Vector2(0,-0.18),Vector2(-0.13,-0.14),Vector2(-0.18,-0.025),Vector2(-0.16,0.10)]
		housing(diff,outline,0.24,steel,"CastAxleHousing")
		var outside := 1.0 if axle==0 else -1.0
		var cover := Node3D.new()
		diff.add_child(cover)
		cover.position.z = outside*0.14
		housing(cover,outline,0.04,steel,"BoltedDifferentialCover")
		var dome := SphereMesh.new()
		dome.radius = 0.125
		dome.height = 0.25
		dome.radial_segments = 24
		dome.rings = 12
		var face := piece(cover,"PressedCoverDome",dome,Vector3(0,-0.01,outside*0.02),steel)
		face.scale = Vector3(1,0.95,0.30)
		for j in range(10):
			var angle := TAU*j/10
			var p := Vector3(cos(angle)*0.144,sin(angle)*0.137-0.012,outside*0.172)
			fixed_rod(diff,"DifferentialCoverBolt",p,p+Vector3(0,0,outside*0.014),0.010,alloy)
		fixed_rod(diff,"FillPlug",Vector3(0.035,0.04,outside*0.18),Vector3(0.035,0.04,outside*0.21),0.018,steel)
		fixed_rod(diff,"PinionNose",Vector3(0,0.045,-outside*0.08),Vector3(0,0.045,-outside*0.25),0.071,steel)
		shafts.append(rod(self,"PropellerShaft%d" % axle,0.037,steel))
		track_bars.append(rod(self,"PanhardBar%d" % axle,0.021,steel))
		for end in range(2):
			var joint := Node3D.new()
			joint.name = "UniversalJoint%d_%d" % [axle,end]
			add_child(joint)
			fixed_rod(joint,"JointFlange",Vector3(0,-0.02,0),Vector3(0,0.02,0),0.063,steel)
			fixed_rod(joint,"JointCross",Vector3(-0.06,0,0),Vector3(0.06,0,0),0.024,alloy)
			joints.append(joint)
		var z: float = mounts[axle*2].z+(0.39 if axle==0 else -0.36)
		fixed_rod(self,"SwayBar",Vector3(-0.62,0.28,z),Vector3(0.62,0.28,z),0.023,steel)
		for side in [-1.0,1.0]:fixed_rod(self,"SwayBarArm",Vector3(side*0.62,0.28,z),Vector3(side*0.62,0.27,mounts[axle*2].z),0.022,steel)
		if axle==0:box(self,"FrontSwayDisconnectHousing",Vector3(0.22,0.11,0.12),Vector3(0,0.28,z),steel)
	tie_rod = rod(self,"FrontSteeringTieRod",0.022,steel)
	drag_link = rod(self,"SteeringDragLink",0.023,steel)
	steering_damper = rod(self,"SteeringDamperBody",0.034,alloy)
	steering_piston = rod(self,"SteeringDamperPiston",0.012,chrome)

func update_suspension(lengths: Array, steering: float, roll: float) -> void:
	var centers: Array[Vector3] = []
	for i in range(4):
		var center: Vector3 = mounts[i]-Vector3.UP*float(lengths[i])
		centers.append(center)
		var side := signf(center.x)
		var direction := 1.0 if i<2 else -1.0
		var inner := Vector3(-side*0.25,0,0)
		var bottom := center+Vector3(-side*0.12,-0.08,direction*0.09)
		var top: Vector3 = mounts[i]+Vector3(-side*0.16,0.12,-direction*0.16)
		align_rod(shocks[i],bottom,bottom.lerp(top,0.64))
		align_rod(pistons[i],bottom.lerp(top,0.55),top)
		align_rod(boots[i],top,top.lerp(bottom,0.28))
		seats[i].position = center+inner+Vector3.UP*0.045
		align_rod(springs[i],seats[i].position,mounts[i]+inner+Vector3.UP*0.06)
		hubs[i].position = center+Vector3(-side*0.10,0,0)
		hubs[i].rotation.y = steering if i<2 else 0.0
		for upper in range(2):
			var a := Vector3(side*(0.41 if upper else 0.55),0.22 if upper else 0.11,direction*0.65)
			var b := center+Vector3(-side*(0.39 if upper else 0.22),0.09 if upper else -0.07,-direction*0.05)
			align_rod(arms[i*2+upper],a,b)
			arm_eyes[i*4+upper*2].position = a
			arm_eyes[i*4+upper*2+1].position = b
		align_rod(sway_links[i],Vector3(side*0.62,0.27,center.z),center+Vector3(-side*0.2,0.055,0.09))
		var hose_top: Vector3 = mounts[i]+Vector3(-side*0.08,0,0.12)
		var hose_middle := center.lerp(hose_top,0.5)+Vector3(-side*0.1,0,-0.1)
		align_rod(hoses[i*2],hose_top,hose_middle)
		align_rod(hoses[i*2+1],hose_middle,hubs[i].position+Vector3(0,0.1,-0.1))
	for axle in range(2):
		var a := centers[axle*2]
		var b := centers[axle*2+1]
		align_rod(axles[axle],a,b)
		var center := (a+b)*0.5
		var lateral := (a-b).normalized()
		var forward := lateral.cross(Vector3.UP).normalized()
		var axle_basis := Basis(lateral,forward.cross(lateral),forward)
		var diff_center := center+lateral*(0.24 if axle==0 else 0.0)
		differentials[axle].transform = Transform3D(axle_basis,diff_center)
		var transfer := Vector3(0.24 if axle==0 else 0,0.13,-0.15 if axle==0 else -0.40)
		var pinion := diff_center+axle_basis*Vector3(0,0.045,-0.25 if axle==0 else 0.25)
		align_rod(shafts[axle],transfer,pinion)
		for end in range(2):
			joints[axle*2+end].transform = Transform3D(shafts[axle].basis.orthonormalized()*Basis(Vector3.UP,roll*4.1),transfer if end==0 else pinion)
		var side := 1.0 if axle==0 else -1.0
		align_rod(track_bars[axle],Vector3(side*0.53,0.31,center.z+side*0.20),center+Vector3(-side*0.60,0.08,side*0.20))
	var offset := Vector3(0,-0.025,0.16).rotated(Vector3.UP,steering)
	align_rod(tie_rod,hubs[0].position+offset,hubs[1].position+offset)
	align_rod(drag_link,Vector3(0.57,0.32,1.70),hubs[1].position+offset+Vector3.UP*0.07)
	var damper_a := centers[0].lerp(centers[1],0.43)+Vector3(0,0.03,0.08)
	var damper_b := hubs[1].position+offset
	align_rod(steering_damper,damper_a,damper_a.lerp(damper_b,0.63))
	align_rod(steering_piston,damper_a.lerp(damper_b,0.55),damper_b)
