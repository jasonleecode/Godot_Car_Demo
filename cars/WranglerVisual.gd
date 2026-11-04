extends Node3D
## Original low-poly short-wheelbase off-roader. Front is local +Z, axle is X.

var paint := material(Color("b99559"))
var dark := material(Color("242c2b"))
var rubber := material(Color("202321"))
var glass := glass_material()
var metal := material(Color("92988d"), 0.4, 0.6)
var lamp := material(Color("fff1c3"))
var red := material(Color("ad4432"))
var wheels: Array[Node3D] = []
var axles: Array[MeshInstance3D] = []
var shocks: Array[MeshInstance3D] = []
var springs: Array[Node3D] = []
const MOUNTS = [Vector3(1.0, 0.46, 1.32), Vector3(-1.0, 0.46, 1.32), Vector3(1.0, 0.46, -1.25), Vector3(-1.0, 0.46, -1.25)]

static func material(color: Color, roughness: float = 0.8, metallic: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	return m

static func glass_material() -> StandardMaterial3D:
	var m := material(Color(0.63,0.78,0.82,0.16),0.08,0.0)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.metallic_specular = 0.5
	return m

func window_pane(node_name: String, size: Vector2, pos: Vector3, yaw: float) -> void:
	# Separate thin panes avoid a solid transparent volume and allow views through the cabin.
	var mesh := QuadMesh.new()
	mesh.size = size
	var pane := piece(self,mesh,pos,glass)
	pane.name = node_name
	pane.rotation.y = yaw
	pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func build_interior() -> void:
	var upholstery := material(Color("615e50"))
	var cushion := material(Color("7b7766"))
	box(self,Vector3(1.5,0.06,2.08),Vector3(0,0.76,-0.6),dark)
	# Two front seats and a rear bench are visible through the clear glazing.
	for x in [-0.39,0.39]:
		box(self,Vector3(0.55,0.14,0.53),Vector3(x,0.88,-0.12),cushion)
		var back := box(self,Vector3(0.55,0.48,0.13),Vector3(x,1.13,-0.40),upholstery)
		back.rotation.x = -0.12
		box(self,Vector3(0.28,0.19,0.13),Vector3(x,1.46,-0.43),upholstery)
	box(self,Vector3(1.32,0.15,0.43),Vector3(0,0.9,-1.13),cushion)
	box(self,Vector3(1.32,0.46,0.13),Vector3(0,1.16,-1.39),upholstery)
	box(self,Vector3(1.47,0.19,0.23),Vector3(0,1.06,0.31),dark)
	box(self,Vector3(0.34,0.13,0.02),Vector3(0.4,1.1,0.182),metal)
	box(self,Vector3(0.22,0.12,0.64),Vector3(0,0.88,-0.09),dark)
	rod(self,Vector3(0,0.95,0.02),Vector3(0,1.13,0.06),0.017,metal)
	rod(self,Vector3(0.4,1.04,0.3),Vector3(0.4,1.2,0.05),0.032,dark)
	var steering := Node3D.new()
	add_child(steering)
	steering.position = Vector3(0.4,1.2,0.05)
	steering.rotation.x = deg_to_rad(62)
	var rim := TorusMesh.new()
	rim.inner_radius = 0.145
	rim.outer_radius = 0.175
	rim.rings = 24
	rim.ring_segments = 8
	piece(steering,rim,Vector3.ZERO,dark)
	for i in range(3):
		var angle := TAU*i/3
		rod(steering,Vector3.ZERO,Vector3(cos(angle),0,sin(angle))*0.15,0.014,metal)

func _ready() -> void:
	build()

func box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return piece(parent, mesh, pos, mat)

func piece(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	parent.add_child(node)
	node.position = pos
	return node

func cylinder(parent: Node3D, radius: float, height: float, pos: Vector3, mat: Material, segments: int = 16) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	return piece(parent, mesh, pos, mat)

func rod(parent: Node3D, a: Vector3, b: Vector3, radius: float, mat: Material) -> MeshInstance3D:
	var node := cylinder(parent, radius, 1.0, Vector3.ZERO, mat, 8)
	align_rod(node, a, b)
	return node

func align_rod(node: Node3D, a: Vector3, b: Vector3) -> void:
	var direction := b - a
	var axis := direction.normalized()
	var side := axis.cross(Vector3.FORWARD)
	if side.length_squared() < 0.001:
		side = axis.cross(Vector3.RIGHT)
	side = side.normalized()
	node.transform = Transform3D(Basis(side, axis, side.cross(axis)).scaled(Vector3(1, direction.length(), 1)), (a+b)*0.5)

func wheel(parent: Node3D) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	var tire := cylinder(root, 0.47, 0.34, Vector3.ZERO, rubber, 24)
	tire.rotation.z = PI/2
	for side in [-1.0, 1.0]:
		var rim := cylinder(root, 0.265, 0.025, Vector3(side*0.177,0,0), metal, 12)
		rim.rotation.z = PI/2
		var hub := cylinder(root, 0.105, 0.04, Vector3(side*0.195,0,0), dark, 12)
		hub.rotation.z = PI/2
		for i in range(5):
			var angle := TAU*i/5
			var hole := cylinder(root, 0.055, 0.028, Vector3(side*0.194, sin(angle)*0.18, cos(angle)*0.18), dark, 8)
			hole.rotation.z = PI/2
	for i in range(24):
		var a := TAU*i/24
		for side in [-1.0,1.0]:
			var tread := box(root, Vector3(0.165,0.055,0.105), Vector3(side*0.09,cos(a)*0.465,sin(a)*0.465), rubber)
			tread.rotation.x = a
	return root

func build() -> void:
	# Frame rails, raised tub and flat hood.
	for x in [-0.55, 0.55]:
		box(self, Vector3(0.13,0.18,3.65), Vector3(x,0.22,0), dark)
	box(self, Vector3(1.68,0.34,3.62), Vector3(0,0.56,0), paint)
	box(self, Vector3(1.48,0.32,1.26), Vector3(0,0.88,1.13), paint)
	box(self, Vector3(1.53,0.08,1.32), Vector3(0,1.08,1.13), paint)
	# Hollow cabin with individually glazed front, side and rear windows.
	window_pane("Windshield",Vector2(1.56,0.64),Vector3(0,1.4,0.463),0)
	window_pane("RearWindow",Vector2(1.56,0.60),Vector3(0,1.42,-1.665),PI)
	for side in [-1.0,1.0]:
		window_pane("DoorWindowLeft" if side>0 else "DoorWindowRight",Vector2(0.85,0.64),Vector3(side*0.805,1.4,-0.005),side*PI/2)
		window_pane("QuarterWindowLeft" if side>0 else "QuarterWindowRight",Vector2(1.10,0.60),Vector3(side*0.805,1.42,-1.06),side*PI/2)
	build_interior()
	box(self, Vector3(1.72,0.11,2.28), Vector3(0,1.79,-0.61), dark)
	for side in [-1.0,1.0]:
		box(self,Vector3(0.075,0.19,2.16),Vector3(side*0.79,0.98,-0.61),paint)
	box(self,Vector3(1.64,0.28,0.09),Vector3(0,0.98,-1.65),paint)
	box(self,Vector3(1.64,0.07,0.08),Vector3(0,1.1,0.46),dark)
	for x in [-0.82,0.82]:
		for z in [-1.65,-0.47,0.46]:
			box(self, Vector3(0.075,0.76,0.08), Vector3(x,1.4,z), dark)
		box(self, Vector3(0.055,0.55,0.88), Vector3(x,0.82,-0.0), paint)
		box(self, Vector3(0.065,0.3,1.04), Vector3(x,0.98,-1.08), paint)
		# Door seams, handles, exposed hinges, mirror stalks, rock sliders.
		box(self, Vector3(0.015,0.48,0.018), Vector3(x*1.015,0.8,-0.47), dark)
		box(self, Vector3(0.055,0.035,0.17), Vector3(x*1.05,1.03,-0.32), dark)
		for y in [0.72,0.98]:
			box(self, Vector3(0.04,0.045,0.1), Vector3(x*1.04,y,0.39), metal)
		rod(self, Vector3(x,1.21,0.39), Vector3(x*1.27,1.29,0.39),0.025,dark)
		box(self, Vector3(0.08,0.2,0.18), Vector3(x*1.28,1.32,0.39),dark)
		box(self, Vector3(0.24,0.11,1.34), Vector3(x*1.13,0.31,0),dark)
	# Seven slot grille, round headlights, indicators and steel bumper.
	box(self, Vector3(1.52,0.53,0.1), Vector3(0,0.85,1.79),paint)
	for i in range(7):
		box(self, Vector3(0.065,0.34,0.024), Vector3((i-3)*0.113,0.86,1.85),dark)
	for x in [-0.59,0.59]:
		var bezel := cylinder(self,0.165,0.06,Vector3(x,0.9,1.86),dark,20)
		bezel.rotation.x = PI/2
		var light := cylinder(self,0.13,0.065,Vector3(x,0.9,1.89),lamp,20)
		light.rotation.x = PI/2
		box(self,Vector3(0.15,0.065,0.04),Vector3(x,0.63,1.86),material(Color("e3a247")))
		box(self,Vector3(0.19,0.23,0.075),Vector3(x,0.87,-1.86),red)
	box(self,Vector3(2.0,0.18,0.24),Vector3(0,0.38,1.96),dark)
	box(self,Vector3(1.88,0.17,0.22),Vector3(0,0.37,-1.94),dark)
	box(self,Vector3(0.55,0.14,0.23),Vector3(0,0.52,1.98),metal)
	for x in [-0.52,0.52]:
		rod(self,Vector3(x,0.33,2.09),Vector3(x,0.49,2.09),0.035,red)
	# Arched wheel flares leave the entire suspension stroke visible.
	for x in [-1.0,1.0]:
		for z in [-1.25,1.32]:
			box(self,Vector3(0.35,0.1,0.78),Vector3(x,0.87,z),dark)
			for sign_z in [-1.0,1.0]:
				var flare := box(self,Vector3(0.35,0.1,0.43),Vector3(x,0.73,z+sign_z*0.5),dark)
				flare.rotation.x = sign_z*0.65
	# Rear mounted matching spare.
	var spare := wheel(self)
	spare.position = Vector3(0,1.12,-2.02)
	spare.rotation.y = PI/2
	box(self,Vector3(0.31,0.15,0.04),Vector3(-0.54,0.5,-2.07),lamp)
	# Roof rails and two low-profile expedition cases.
	for x in [-0.63,0.63]:
		rod(self,Vector3(x,1.91,-1.49),Vector3(x,1.91,0.23),0.03,dark)
	for z in [-1.45,0.2]:
		rod(self,Vector3(-0.63,1.91,z),Vector3(0.63,1.91,z),0.03,dark)
	box(self,Vector3(0.73,0.23,0.91),Vector3(-0.19,1.96,-0.83),material(Color("727b65")))
	for z in [-1.1,-0.56]:
		box(self,Vector3(0.75,0.025,0.045),Vector3(-0.19,2.09,z),dark)
	for mount in MOUNTS:
		var steer := Node3D.new()
		add_child(steer)
		wheel(steer)
		wheels.append(steer)
		shocks.append(rod(self,mount,mount-Vector3(0,0.5,0),0.035,metal))
		var coil := Node3D.new()
		add_child(coil)
		for j in range(8):
			var ring := TorusMesh.new()
			ring.inner_radius = 0.065
			ring.outer_radius = 0.09
			ring.rings = 12
			ring.ring_segments = 6
			piece(coil,ring,Vector3(0,j/7.0,0),paint)
		springs.append(coil)
	for i in range(2):
		axles.append(rod(self,Vector3.ZERO,Vector3.RIGHT,0.075,dark))
	update_suspension([0.4,0.4,0.4,0.4],0,0)

func update_suspension(lengths: Array, steering: float, roll: float) -> void:
	if wheels.is_empty():
		return
	for i in range(4):
		var center: Vector3 = MOUNTS[i]-Vector3(0,lengths[i],0)
		wheels[i].position = center
		wheels[i].rotation.y = steering if i < 2 else 0.0
		wheels[i].get_child(0).rotation.x = roll
		var top: Vector3 = MOUNTS[i]+Vector3(-signf(MOUNTS[i].x)*0.16,0.12,0)
		var bottom := center+Vector3(-signf(MOUNTS[i].x)*0.16,0,0)
		align_rod(shocks[i],top,bottom)
		springs[i].position = bottom
		springs[i].scale.y = maxf(0.04,top.y-bottom.y)
	for i in range(2):
		align_rod(axles[i],wheels[2*i].position,wheels[2*i+1].position)
