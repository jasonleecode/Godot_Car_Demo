extends "res://cars/OffroadChassis.gd"
## C8-inspired independent five-link suspension. Differentials remain on the body.
var air_springs: Array[MeshInstance3D] = []
var cv_boots: Array[Node3D] = []
var arm_starts: Array[Vector3] = []
var arm_offsets: Array[Vector3] = []
var shaft_starts: Array[Vector3] = []
var steering_links: Array[MeshInstance3D] = []
var disc_material := material(Color("a3a7a8"),0.85)

func bellows_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in range(28):
		for i in range(32):
			for corner in [Vector2i(0,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,0),Vector2i(1,1),Vector2i(0,1)]:
				var t := float(j+corner.y)/28
				var angle: float = (i+corner.x)*TAU/32
				var radius := 0.065+0.008*cos(t*TAU*4)
				surface.set_normal(Vector3(cos(angle),0,sin(angle)))
				surface.add_vertex(Vector3(radius*cos(angle),t-0.5,radius*sin(angle)))
	return surface.commit()

func configure(wheel_mounts: Array, _detailed: bool) -> void:
	mounts = wheel_mounts.duplicate()
	steel = material(Color("252b2f"),0.4)
	alloy = material(Color("858d90"),0.65)
	dark = material(Color("15191b"),0.05)
	box(self,"Underfloor aero panel",Vector3(1.42,0.035,1.87),Vector3(0,-0.13,-0.12),dark)
	box(self,"Engine protection",Vector3(1.11,0.04,0.93),Vector3(0,-0.17,1.47),steel)
	box(self,"Transmission guard",Vector3(0.50,0.035,0.68),Vector3(0,-0.17,0.60),steel)
	for side in [-1.0,1.0]:
		box(self,"Unibody sill reinforcement",Vector3(0.09,0.09,3.77),Vector3(side*0.68,-0.06,0),steel)
		for z in [0.60,-0.2,-0.8]:
			box(self,"Floor stiffener",Vector3(0.60,0.025,0.028),Vector3(side*0.36,-0.16,z),steel)
	for axle in range(2):
		var z: float = mounts[axle*2].z
		for side in [-1.0,1.0]:
			fixed_rod(self,"Subframe side",Vector3(side*0.42,0.025,z-0.35),Vector3(side*0.42,0.025,z+0.35),0.045,alloy)
			for dz in [-0.32,0.32]:
				fixed_rod(self,"Subframe bushing",Vector3(side*0.42,0.02,z+dz),Vector3(side*0.42,0.13,z+dz),0.048,dark)
		for dz in [-0.31,0.31]:fixed_rod(self,"Subframe crossmember",Vector3(-0.42,0.025,z+dz),Vector3(0.42,0.025,z+dz),0.045,alloy)
		var differential := Node3D.new()
		differential.name = "FixedDifferential%d" % axle
		add_child(differential)
		differential.position = Vector3(0,0.02,z)
		box(differential,"Cast final drive",Vector3(0.28,0.18,0.24),Vector3.ZERO,alloy)
		for x in [-0.10,-0.05,0,0.05,0.10]:
			box(differential,"Cooling rib",Vector3(0.012,0.02,0.21),Vector3(x,-0.10,0),alloy)
		differentials.append(differential)
	fixed_rod(self,"Longitudinal gearbox",Vector3(0,0.04,1.15),Vector3(0,0.04,0.34),0.13,alloy)
	fixed_rod(self,"Quattro propshaft",Vector3(0,0.02,0.34),Vector3(0,0.02,-1.33),0.032,steel)
	box(self,"Fuel tank",Vector3(0.96,0.14,0.50),Vector3(0,-0.005,-0.98),dark)
	var exhaust_mat := material(Color("857d70"),0.62)
	for side in [-1.0,1.0]:
		var path := [Vector3(side*0.27,0.02,1.30),Vector3(side*0.29,-0.10,0.64),Vector3(side*0.29,-0.10,-0.65),Vector3(side*0.51,0.06,-1.17),Vector3(side*0.54,0.08,-1.73),Vector3(side*0.62,-0.02,-2.19)]
		for i in range(path.size()-1):fixed_rod(self,"Twin exhaust",path[i],path[i+1],0.025,exhaust_mat)
		fixed_rod(self,"Catalyst",Vector3(side*0.29,-0.08,0.90),Vector3(side*0.29,-0.08,0.57),0.065,exhaust_mat)
		box(self,"Rear silencer",Vector3(0.28,0.13,0.43),Vector3(side*0.54,0.025,-1.98),exhaust_mat)
	var bellows := bellows_mesh()
	for i in range(4):
		var side := signf(mounts[i].x)
		var z: float = mounts[i].z
		# Two upper links, two lower links and a toe-control link per wheel.
		for geometry in [[Vector3(side*0.38,0.20,z+0.24),Vector3(-side*0.075,0.12,0.025)],[Vector3(side*0.37,0.20,z-0.23),Vector3(-side*0.075,0.12,-0.025)],[Vector3(side*0.32,-0.04,z+0.27),Vector3(-side*0.12,-0.09,0.04)],[Vector3(side*0.32,-0.04,z-0.29),Vector3(-side*0.12,-0.09,-0.04)],[Vector3(side*0.34,0.02,z-0.34),Vector3(-side*0.07,0,-0.12)]]:
			arm_starts.append(geometry[0])
			arm_offsets.append(geometry[1])
			arms.append(rod(self,"IndependentLink%d" % arms.size(),0.019,alloy))
			fixed_rod(self,"Link bushing",geometry[0]-Vector3(0,0,0.025),geometry[0]+Vector3(0,0,0.025),0.027,dark)
		shaft_starts.append(Vector3(side*0.13,0.02,z))
		shafts.append(rod(self,"CVHalfshaft%d" % i,0.020,steel))
		for end in range(2):
			var joint := Node3D.new()
			joint.name = "CVJoint%d_%d" % [i,end]
			add_child(joint)
			fixed_rod(joint,"CV housing",Vector3(-0.032,0,0),Vector3(0.032,0,0),0.042,steel)
			for x in [-0.04,-0.02,0,0.02,0.04]:fixed_rod(joint,"Boot rib",Vector3(x-0.005,0,0),Vector3(x+0.005,0,0),0.044,dark)
			cv_boots.append(joint)
		air_springs.append(piece(self,"AirSpringBellows%d" % i,bellows,Vector3.ZERO,dark))
		shocks.append(rod(self,"AdaptiveDamper%d" % i,0.029,steel))
		pistons.append(rod(self,"DamperRod%d" % i,0.011,chrome))
		var hub := Node3D.new()
		hub.name = "IndependentKnuckle%d" % i
		add_child(hub)
		hubs.append(hub)
		box(hub,"Upright",Vector3(0.055,0.24,0.10),Vector3(-side*0.06,0,0),alloy)
		fixed_rod(hub,"Vented brake disc",Vector3(-side*0.035,0,0),Vector3(-side*0.005,0,0),0.17 if i<2 else 0.155,disc_material)
		box(hub,"Caliper",Vector3(0.08,0.15,0.08),Vector3(-side*0.015,0.035,-0.13),steel)
		fixed_rod(hub,"Hub bearing",Vector3(-side*0.08,0,0),Vector3(side*0.02,0,0),0.055,steel)
	fixed_rod(self,"Steering rack",Vector3(-0.36,0.10,1.18),Vector3(0.36,0.10,1.18),0.033,steel)
	for i in range(2):steering_links.append(rod(self,"TieRod%d" % i,0.014,steel))

func update_suspension(lengths: Array, steering: float, _roll: float) -> void:
	for i in range(4):
		var c: Vector3 = mounts[i]-Vector3.UP*float(lengths[i])
		var side := signf(c.x)
		var wheel_basis := Basis(Vector3.UP,steering if i<2 else 0.0)
		hubs[i].transform = Transform3D(wheel_basis,c)
		for link in range(5):
			var index := i*5+link
			align_rod(arms[index],arm_starts[index],c+wheel_basis*arm_offsets[index])
		var outer := c+wheel_basis*Vector3(-side*0.055,0,0)
		align_rod(shafts[i],shaft_starts[i],outer)
		cv_boots[i*2].position = shaft_starts[i]
		cv_boots[i*2+1].position = outer
		var bottom := c+Vector3(-side*0.25,-0.04,0.05)
		var top: Vector3 = mounts[i]+Vector3(-side*0.27,-0.08,0.05)
		align_rod(air_springs[i],bottom,top)
		var damper_bottom := c+Vector3(-side*0.16,-0.06,-0.08)
		var damper_top: Vector3 = mounts[i]+Vector3(-side*0.18,0.04,-0.08)
		var split := damper_bottom.lerp(damper_top,0.64)
		align_rod(shocks[i],damper_bottom,split)
		align_rod(pistons[i],split,damper_top)
		if i<2:align_rod(steering_links[i],Vector3(side*0.36,0.10,1.18),c+wheel_basis*Vector3(-side*0.06,0,-0.12))
