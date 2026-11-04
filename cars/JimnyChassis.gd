extends "res://cars/OffroadChassis.gd"
## JB74-inspired ladder frame and three-link live axles, driven by wheel contact travel.
## Each axle has two forked radius arms and one Panhard rod, not the JL four-link layout.
var forks: Array[MeshInstance3D] = []
var bushings: Array[Node3D] = []
var spring_seats: Array[Node3D] = []
var drag_link: MeshInstance3D
var hoses: Array[MeshInstance3D] = []
var exhaust := material(Color("78766d"),0.65)

func ring(parent: Node3D, label: String, radius: float, wire: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius-wire
	mesh.outer_radius = radius+wire
	mesh.rings = 24
	mesh.ring_segments = 8
	return piece(parent,label,mesh,pos,mat)

func frame(side: float) -> void:
	var path := [Vector3(side*0.43,0.16,1.63),Vector3(side*0.43,0.22,1.1),Vector3(side*0.43,0.11,0.57),Vector3(side*0.43,0.10,-0.55),Vector3(side*0.43,0.24,-1.04),Vector3(side*0.43,0.20,-1.55)]
	for i in range(path.size()-1):
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.085,1,0.13)
		var rail := piece(self,"BoxedFrameRail",mesh,Vector3.ZERO,steel)
		align_rod(rail,path[i],path[i+1])
	for z in [1.35,0.40,-0.35,-1.4]:
		box(self,"BodyOutrigger",Vector3(0.24,0.05,0.10),Vector3(side*0.52,0.22,z),steel)
		fixed_rod(self,"BodyMountBushing",Vector3(side*0.61,0.22,z),Vector3(side*0.61,0.28,z),0.043,dark)

func configure(wheel_mounts: Array, _detailed: bool) -> void:
	mounts = wheel_mounts.duplicate()
	steel = material(Color("292e31"),0.38)
	steel.roughness = 0.60
	dark = material(Color("141a1d"),0.08)
	for side in [-1.0,1.0]: frame(side)
	for z in [1.55,0.46,-0.52,-1.48]:
		box(self,"FrameCrossmember",Vector3(0.94,0.07,0.09),Vector3(0,0.16,z),steel)
	# Central X brace is characteristic of the fourth-generation Jimny frame.
	for side in [-1.0,1.0]:
		var beam := box(self,"CentreXBrace",Vector3(0.06,1,0.07),Vector3.ZERO,steel)
		align_rod(beam,Vector3(side*0.39,0.10,0.41),Vector3(-side*0.39,0.10,-0.49))
	box(self,"PressedFloorPan",Vector3(1.15,0.028,1.72),Vector3(0,0.18,-0.18),dark)
	for x in [-0.48,-0.30,0.30,0.48]:
		box(self,"FloorPanRib",Vector3(0.025,0.02,1.50),Vector3(x,0.16,-0.18),steel)
	box(self,"EngineSump",Vector3(0.30,0.17,0.36),Vector3(0,0.18,0.89),alloy)
	fixed_rod(self,"Bellhousing",Vector3(0,0.18,0.65),Vector3(0,0.18,0.43),0.14,alloy)
	fixed_rod(self,"Gearbox",Vector3(0,0.17,0.45),Vector3(0,0.17,0.02),0.085,alloy)
	for z in [0.35,0.22,0.09]:
		box(self,"GearboxRib",Vector3(0.17,0.018,0.025),Vector3(0,0.08,z),alloy)
	fixed_rod(self,"IntermediatePropellerShaft",Vector3(0,0.15,0.01),Vector3(-0.10,0.13,-0.20),0.027,steel)
	box(self,"SeparateTransferCase",Vector3(0.24,0.19,0.27),Vector3(-0.14,0.13,-0.28),alloy)
	box(self,"TransferGuard",Vector3(0.36,0.025,0.36),Vector3(-0.14,0.025,-0.28),steel)
	box(self,"FuelTank",Vector3(0.38,0.18,0.66),Vector3(0.23,0.10,-0.69),dark)
	box(self,"TankCradle",Vector3(0.42,0.025,0.71),Vector3(0.23,-0.005,-0.69),steel)
	for z in [-0.46,-0.91]:
		box(self,"FuelTankStrap",Vector3(0.43,0.027,0.035),Vector3(0.23,-0.025,z),steel)
	var exhaust_path := [Vector3(-0.26,0.24,1.03),Vector3(-0.34,0.10,0.53),Vector3(-0.35,0.06,-0.64),Vector3(-0.36,0.25,-1.04),Vector3(-0.35,0.28,-1.25),Vector3(-0.29,0.15,-1.47)]
	for i in range(exhaust_path.size()-1):
		fixed_rod(self,"ExhaustPipe",exhaust_path[i],exhaust_path[i+1],0.023,exhaust)
	fixed_rod(self,"CatalyticConverter",Vector3(-0.34,0.09,0.48),Vector3(-0.35,0.08,0.17),0.064,exhaust)
	var muffler := fixed_rod(self,"RearMuffler",Vector3(-0.31,0.16,-1.44),Vector3(0.29,0.16,-1.44),0.095,exhaust)
	muffler.basis = muffler.basis.scaled(Vector3(1,0.70,1))
	fixed_rod(self,"Tailpipe",Vector3(-0.31,0.13,-1.44),Vector3(-0.51,0.12,-1.70),0.024,exhaust)
	var coil := coil_mesh()
	for i in range(4):
		arms.append(rod(self,"RadiusArm%d" % i,0.030,steel))
		forks.append(rod(self,"RadiusArmFork%d" % i,0.024,steel))
		var bush := Node3D.new()
		bush.name = "RadiusArmBush%d" % i
		add_child(bush)
		fixed_rod(bush,"RubberEye",Vector3(-0.05,0,0),Vector3(0.05,0,0),0.048,dark)
		fixed_rod(bush,"Bolt",Vector3(-0.06,0,0),Vector3(0.06,0,0),0.015,alloy)
		bushings.append(bush)
		shocks.append(rod(self,"ShockBody%d" % i,0.027,dark))
		pistons.append(rod(self,"ShockRod%d" % i,0.011,chrome))
		springs.append(piece(self,"CoilSpring%d" % i,coil,Vector3.ZERO,steel))
		spring_seats.append(ring(self,"LowerSpringSeat%d" % i,0.073,0.012,Vector3.ZERO,steel))
		var sign_x := signf(mounts[i].x)
		var top: Vector3 = mounts[i]+Vector3(-sign_x*0.23,-0.09,0)
		ring(self,"UpperSpringSeat",0.073,0.014,top,steel)
		fixed_rod(self,"BumpStop",top-Vector3(0,0.02,0),top-Vector3(0,0.10,0),0.035,dark)
		var hub := Node3D.new()
		hub.name = "FrontKnuckle%d" % i if i<2 else "RearDrumHub%d" % i
		add_child(hub)
		hubs.append(hub)
		fixed_rod(hub,"HubBearing",Vector3(-0.07,0,0),Vector3(0.07,0,0),0.065,steel)
		if i<2:
			fixed_rod(hub,"VentilatedBrakeDisc",Vector3(-0.024,0,0),Vector3(0.024,0,0),0.117,alloy)
			box(hub,"BrakeCaliper",Vector3(0.075,0.105,0.055),Vector3(0,0.035,-0.087),steel)
		else:
			fixed_rod(hub,"RearBrakeDrum",Vector3(-0.035,0,0),Vector3(0.035,0,0),0.112,steel)
		hoses.append(rod(self,"BrakeHose%d" % i,0.005,dark))
	for axle in range(2):
		axles.append(rod(self,"SolidAxle%d" % axle,0.046,steel))
		var diff := Node3D.new()
		diff.name = "Differential%d" % axle
		add_child(diff)
		differentials.append(diff)
		var sphere := SphereMesh.new()
		sphere.radius = 0.135
		sphere.height = 0.24
		sphere.radial_segments = 24
		sphere.rings = 12
		var casting := piece(diff,"CastDifferentialHousing",sphere,Vector3.ZERO,steel)
		casting.scale.z = 1.12
		var inward := -1.0 if axle==0 else 1.0
		fixed_rod(diff,"ThirdMember",Vector3(0,0,0),Vector3(0,0,inward*0.18),0.085,steel)
		for bolt in range(10):
			var a := bolt*TAU/10
			var p := Vector3(sin(a)*0.095,cos(a)*0.095,inward*0.105)
			fixed_rod(diff,"HousingBolt",p,p+Vector3(0,0,inward*0.014),0.009,alloy)
		shafts.append(rod(self,"PropellerShaft%d" % axle,0.027,steel))
		for end in range(2):
			var joint := Node3D.new()
			joint.name = "UniversalJoint%d_%d" % [axle,end]
			add_child(joint)
			box(joint,"Yoke",Vector3(0.075,0.07,0.055),Vector3.ZERO,steel)
			joints.append(joint)
		track_bars.append(rod(self,"PanhardRod%d" % axle,0.020,steel))
	tie_rod = rod(self,"SteeringTieRod",0.019,steel)
	drag_link = rod(self,"SteeringDragLink",0.019,steel)
	fixed_rod(self,"FrontAntiRollBar",Vector3(-0.47,0.25,1.38),Vector3(0.47,0.25,1.38),0.018,steel)

func update_suspension(lengths: Array, steering: float, _roll: float) -> void:
	var centers: Array[Vector3] = []
	for i in range(4): centers.append(mounts[i]-Vector3.UP*float(lengths[i]))
	for axle in range(2):
		var a := centers[axle*2]
		var b := centers[axle*2+1]
		align_rod(axles[axle],a,b)
		# Both differentials line up with the offset transfer-case output.
		var midpoint := a.lerp(b,0.60)
		differentials[axle].position = midpoint
		differentials[axle].rotation.z = atan2(a.y-b.y,a.x-b.x)
		var transfer := Vector3(-0.14,0.11,-0.13 if axle==0 else -0.43)
		var nose: Vector3 = midpoint+differentials[axle].basis*Vector3(0,0,-0.18 if axle==0 else 0.18)
		align_rod(shafts[axle],transfer,nose)
		joints[axle*2].position = transfer
		joints[axle*2+1].position = nose
		var panhard_body := Vector3(0.43 if axle==0 else -0.43,0.23,a.z+0.10)
		var panhard_axle := (b if axle==0 else a)+Vector3(0,0.03,0.10)
		align_rod(track_bars[axle],panhard_body,panhard_axle)
	for i in range(4):
		var c := centers[i]
		var side := signf(c.x)
		var direction := -1.0 if i<2 else 1.0
		var lower := c+Vector3(-side*0.23,0.015,0)
		var top: Vector3 = mounts[i]+Vector3(-side*0.23,-0.09,0)
		align_rod(springs[i],lower,top)
		spring_seats[i].position = lower
		var shock_top: Vector3 = mounts[i]+Vector3(-side*0.15,0.01,direction*0.11)
		var shock_bottom := c+Vector3(-side*0.15,-0.035,-direction*0.07)
		var split := shock_bottom.lerp(shock_top,0.59)
		align_rod(shocks[i],shock_bottom,split)
		align_rod(pistons[i],split,shock_top)
		var frame_end := Vector3(side*0.43,0.07,c.z+direction*0.73)
		var fork_end := c+Vector3(-side*0.23,-0.035,-direction*0.10)
		align_rod(arms[i],frame_end,fork_end)
		align_rod(forks[i],frame_end.lerp(fork_end,0.63),c+Vector3(-side*0.23,0.025,direction*0.12))
		bushings[i].position = frame_end
		hubs[i].position = c
		hubs[i].rotation.y = steering if i<2 else 0
		align_rod(hoses[i],top+Vector3(0,0.01,0.09),c+Vector3(-side*0.09,0.07,0.09))
	align_rod(tie_rod,centers[0]+Vector3(-0.08,0,-0.10),centers[1]+Vector3(0.08,0,-0.10))
	align_rod(drag_link,Vector3(-0.43,0.26,1.27),centers[0]+Vector3(-0.10,0.02,0.08))
