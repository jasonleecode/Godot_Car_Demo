extends Node3D
## Shared articulated running gear. All dimensions are metres, front is +Z.
var mounts: Array = []
var axles: Array[MeshInstance3D] = []
var differentials: Array[Node3D] = []
var shafts: Array[MeshInstance3D] = []
var joints: Array[Node3D] = []
var shocks: Array[MeshInstance3D] = []
var pistons: Array[MeshInstance3D] = []
var springs: Array[MeshInstance3D] = []
var arms: Array[MeshInstance3D] = []
var hubs: Array[Node3D] = []
var track_bars: Array[MeshInstance3D] = []
var tie_rod: MeshInstance3D
var steel := material(Color("41494d"),0.65)
var alloy := material(Color("9aa1a2"),0.75)
var dark := material(Color("242b2d"),0.35)
var red := material(Color("a34330"),0.25)
var chrome := material(Color("d0d7d9"),0.9)
var segments := 20

static func material(color: Color, metallic: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = 0.4 if metallic>0.7 else 0.65
	return mat

func piece(parent: Node3D, label: String, mesh: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	node.material_override = mat
	parent.add_child(node)
	node.position = pos
	return node

func box(parent: Node3D, label: String, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return piece(parent,label,mesh,pos,mat)

func rod(parent: Node3D, label: String, radius: float, mat: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 1.0
	mesh.radial_segments = segments
	return piece(parent,label,mesh,Vector3.ZERO,mat)

static func align_rod(node: Node3D, a: Vector3, b: Vector3) -> void:
	var axis := (b-a).normalized()
	var side := axis.cross(Vector3.FORWARD)
	if side.length_squared()<0.001:
		side = axis.cross(Vector3.RIGHT)
	side = side.normalized()
	# Cylinders extend along LOCAL Y. Global scaling shortens transverse axles incorrectly.
	node.transform = Transform3D(Basis(side,axis,side.cross(axis)).scaled_local(Vector3(1,maxf(a.distance_to(b),0.001),1)),(a+b)*0.5)

func fixed_rod(parent: Node3D, label: String, a: Vector3, b: Vector3, radius: float, mat: Material) -> MeshInstance3D:
	var node := rod(parent,label,radius,mat)
	align_rod(node,a,b)
	return node

func coil_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(112):
		for j in range(6):
			for corner in [Vector2i(0,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,0),Vector2i(1,1),Vector2i(0,1)]:
				var t := float(i+corner.x)/112
				var a := t*TAU*7
				var b := float(j+corner.y)/6*TAU
				var normal := Vector3(cos(a)*cos(b),sin(b),sin(a)*cos(b))
				surface.set_normal(normal)
				surface.add_vertex(Vector3(cos(a)*0.075,t-0.5,sin(a)*0.075)+normal*0.012)
	return surface.commit()

func configure(wheel_mounts: Array, detailed: bool) -> void:
	mounts = wheel_mounts.duplicate()
	segments = 20 if detailed else 12
	var front: float = mounts[0].z
	var rear: float = mounts[2].z
	# Rubicon's imported model already supplies frame rails and its main belly plate.
	if not detailed:
		for side in [-1.0,1.0]:
			box(self,"FrameRail",Vector3(0.13,0.18,3.65),Vector3(side*0.55,0.22,0),dark)
		box(self,"TransferSkid",Vector3(1.02,0.055,1.02),Vector3(0,0.08,-0.1),alloy)
	for z in [rear+0.32,-0.55,0.55,front+0.25]:
		box(self,"FrameCrossmember",Vector3(1.1,0.1,0.12),Vector3(0,0.2,z),steel)
	box(self,"EngineSump",Vector3(0.48,0.20,0.48),Vector3(0,0.22,front-0.25),dark)
	box(self,"TransmissionCase",Vector3(0.34,0.22,0.62),Vector3(0,0.18,0.38),alloy)
	box(self,"TransferCase",Vector3(0.42,0.20,0.28),Vector3(0.08,0.13,-0.12),steel)
	box(self,"FuelTankSkid",Vector3(0.42,0.10,0.85),Vector3(-0.36,0.08,rear+0.62),dark)
	for z in [rear+0.32,rear+0.87]:
		box(self,"TankStrap",Vector3(0.45,0.025,0.045),Vector3(-0.36,0.02,z),alloy)
	# Raised exhaust route stays clear of the propshaft and axle centre housings.
	fixed_rod(self,"ExhaustFront",Vector3(0.38,0.2,front-0.3),Vector3(0.4,0.12,-0.75),0.035,alloy)
	box(self,"Muffler",Vector3(0.28,0.16,0.45),Vector3(0.38,0.2,rear+0.25),alloy)
	fixed_rod(self,"TailpipeRise",Vector3(0.4,0.12,-0.75),Vector3(0.43,0.29,rear),0.035,alloy)
	fixed_rod(self,"Tailpipe",Vector3(0.43,0.29,rear),Vector3(0.65,0.22,rear-0.48),0.035,steel)
	var coil := coil_mesh()
	for i in range(4):
		shocks.append(rod(self,"ShockBody%d" % i,0.043,red if detailed else alloy))
		pistons.append(rod(self,"ShockPiston%d" % i,0.018,chrome))
		springs.append(piece(self,"CoilSpring%d" % i,coil,Vector3.ZERO,dark if detailed else alloy))
		var hub := Node3D.new()
		hub.name = "SteeringKnuckle%d" % i
		add_child(hub)
		hubs.append(hub)
		box(hub,"Knuckle",Vector3(0.10,0.23,0.14),Vector3.ZERO,steel)
		fixed_rod(hub,"HubBearing",Vector3(-0.10,0,0),Vector3(0.10,0,0),0.10,dark)
		var sign_x := signf(mounts[i].x)
		box(self,"UpperShockBracket",Vector3(0.09,0.16,0.12),mounts[i]+Vector3(-sign_x*0.24,0.04,0.13),steel)
		for upper in range(2):
			arms.append(rod(self,"ControlArm%d_%d" % [i,upper],0.025 if upper else 0.036,steel))
	for axle in range(2):
		axles.append(rod(self,"SolidAxle%d" % axle,0.072,steel))
		var diff := Node3D.new()
		diff.name = "Differential%d" % axle
		add_child(diff)
		differentials.append(diff)
		var housing := SphereMesh.new()
		housing.radius = 0.19
		housing.height = 0.34
		housing.radial_segments = segments
		housing.rings = 10
		var shell := piece(diff,"CastHousing",housing,Vector3.ZERO,steel)
		shell.scale.z = 1.2
		var outside := 1.0 if axle==0 else -1.0
		fixed_rod(diff,"DifferentialCover",Vector3(0,0,outside*0.18),Vector3(0,0,outside*0.225),0.155,alloy)
		for bolt in range(10):
			var a := TAU*bolt/10
			var pos := Vector3(cos(a)*0.133,sin(a)*0.133,outside*0.235)
			fixed_rod(diff,"CoverBolt",pos,pos+Vector3(0,0,outside*0.014),0.012,dark)
		shafts.append(rod(self,"PropellerShaft%d" % axle,0.043,dark))
		track_bars.append(rod(self,"PanhardBar%d" % axle,0.026,steel))
		for end in range(2):
			var joint := Node3D.new()
			joint.name = "UniversalJoint%d_%d" % [axle,end]
			add_child(joint)
			fixed_rod(joint,"CrossPinX",Vector3(-0.065,0,0),Vector3(0.065,0,0),0.025,alloy)
			fixed_rod(joint,"CrossPinY",Vector3(0,-0.065,0),Vector3(0,0.065,0),0.025,alloy)
			joints.append(joint)
	tie_rod = rod(self,"FrontSteeringTieRod",0.024,alloy)

func update_suspension(lengths: Array, steering: float, roll: float) -> void:
	var centers: Array[Vector3] = []
	for i in range(4):
		var center: Vector3 = mounts[i]-Vector3.UP*float(lengths[i])
		centers.append(center)
		var sign_x := signf(center.x)
		var inner := Vector3(-sign_x*0.24,0,0)
		var top: Vector3 = mounts[i]+inner+Vector3(0,0.12,0.13)
		var bottom := center+inner+Vector3(0,0,0.13)
		align_rod(shocks[i],top,top.lerp(bottom,0.57))
		align_rod(pistons[i],top.lerp(bottom,0.38),bottom)
		align_rod(springs[i],center+inner-Vector3(0,0,0.13),mounts[i]+inner+Vector3(0,0.04,-0.13))
		hubs[i].position = center+Vector3(-sign_x*0.12,0,0)
		hubs[i].rotation.y = steering if i<2 else 0.0
		var end_sign := 1.0 if i<2 else -1.0
		for upper in range(2):
			var a := Vector3(sign_x*(0.40 if upper else 0.56),0.24 if upper else 0.14,end_sign*0.45)
			var b := center+Vector3(-sign_x*(0.38 if upper else 0.25),0.09 if upper else -0.065,-end_sign*0.08)
			align_rod(arms[i*2+upper],a,b)
	for axle in range(2):
		var a := centers[axle*2]
		var b := centers[axle*2+1]
		align_rod(axles[axle],a,b)
		var center := (a+b)*0.5
		var lateral := (a-b).normalized()
		var forward := lateral.cross(Vector3.UP).normalized()
		var axle_basis := Basis(lateral,forward.cross(lateral),forward)
		var diff_center := center+lateral*(0.13 if axle==0 else 0.0)
		differentials[axle].transform = Transform3D(axle_basis,diff_center)
		var transfer := Vector3(0.13 if axle==0 else 0,0.09,0.04 if axle==0 else -0.26)
		var pinion := diff_center+forward*(-0.20 if axle==0 else 0.20)
		align_rod(shafts[axle],transfer,pinion)
		for end in range(2):
			joints[axle*2+end].position = transfer if end==0 else pinion
			joints[axle*2+end].rotation.z = roll
		align_rod(track_bars[axle],Vector3(-0.53,0.23,center.z+0.22),a+Vector3(-0.26,0.02,0.22))
	var steer_offset := Vector3(0,0,0.16).rotated(Vector3.UP,steering)
	align_rod(tie_rod,hubs[0].position+steer_offset,hubs[1].position+steer_offset)
