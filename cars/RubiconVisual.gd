extends Node3D
## Art and physics share metre-scale wheel centres. GLB wheels stay independently animated.
const MOUNTS = [Vector3(0.875,0.42,1.504),Vector3(-0.875,0.42,1.504),Vector3(0.875,0.42,-1.504),Vector3(-0.875,0.42,-1.504)]
const Helpers = preload("res://cars/WranglerVisual.gd")
var wheels: Array[Node3D] = []
var rotors: Array[Node3D] = []
var shocks: Array[MeshInstance3D] = []
var axles: Array[MeshInstance3D] = []
var differentials: Array[MeshInstance3D] = []
var springs: Array[MeshInstance3D] = []
var model: Node3D

func _ready() -> void:
	model = preload("res://cars/Models/Rubicon/Rubicon.glb").instantiate()
	add_child(model)
	prepare_materials(model)
	for suffix in ["FL","FR","RL","RR"]:
		wheels.append(model.find_child("Wheel"+suffix,true,false))
		rotors.append(model.find_child("Rotor"+suffix,true,false))
	var steel := Helpers.material(Color("40464b"),0.34,0.8)
	var shock_material := Helpers.material(Color("c3c9ca"),0.26,0.8)
	var spring_material := Helpers.material(Color("35393b"),0.44,0.65)
	for i in range(4):
		shocks.append(cylinder(0.026,shock_material))
		var spring := MeshInstance3D.new()
		spring.mesh = coil_mesh()
		spring.material_override = spring_material
		add_child(spring)
		springs.append(spring)
	for i in range(2):
		axles.append(cylinder(0.045,steel))
		var diff := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.14
		sphere.height = 0.23
		sphere.radial_segments = 24
		sphere.rings = 12
		diff.mesh = sphere
		diff.scale = Vector3(1,1,1.35)
		diff.material_override = steel
		add_child(diff)
		differentials.append(diff)
	update_suspension([0.42,0.42,0.42,0.42],0,0)

func prepare_materials(node: Node) -> void:
	if node is MeshInstance3D:
		for i in range(node.mesh.get_surface_count()):
			var source: Material = node.mesh.surface_get_material(i)
			if source is StandardMaterial3D:
				var mat: StandardMaterial3D = source.duplicate()
				if "glazing" in source.resource_name.to_lower():
					mat = Helpers.glass_material()
					node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				elif "clearcoat" in source.resource_name.to_lower():
					mat.clearcoat_enabled = true
					mat.clearcoat = 0.85
					mat.clearcoat_roughness = 0.12
				node.set_surface_override_material(i,mat)
	for child in node.get_children():
		prepare_materials(child)

func cylinder(radius: float, mat: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 1
	mesh.radial_segments = 16
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	add_child(node)
	return node

func coil_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(128):
		for j in range(8):
			for corner in [Vector2i(0,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,0),Vector2i(1,1),Vector2i(0,1)]:
				var t := float(i+corner.x)/128
				var a := t*TAU*8
				var b := float(j+corner.y)/8*TAU
				var normal := Vector3(cos(a)*cos(b),sin(b),sin(a)*cos(b))
				surface.set_normal(normal)
				surface.add_vertex(Vector3(cos(a)*0.055,t,sin(a)*0.055)+normal*0.008)
	return surface.commit()

func align_rod(node: Node3D, a: Vector3, b: Vector3) -> void:
	var direction := b-a
	var axis := direction.normalized()
	var side := axis.cross(Vector3.FORWARD).normalized()
	node.transform = Transform3D(Basis(side,axis,side.cross(axis)).scaled(Vector3(1,direction.length(),1)),(a+b)*0.5)

func update_suspension(lengths: Array, steering: float, roll: float) -> void:
	if wheels.size()!=4:
		return
	for i in range(4):
		var center: Vector3 = MOUNTS[i]-Vector3(0,lengths[i],0)
		wheels[i].position = center
		wheels[i].rotation.y = steering if i<2 else 0.0
		rotors[i].rotation.x = roll
		var inner: Vector3 = Vector3(-signf(MOUNTS[i].x)*0.23,0,0)
		align_rod(shocks[i],MOUNTS[i]+inner+Vector3(0,0.12,0.12),center+inner)
		springs[i].position = center+inner+Vector3(0,0,-0.12)
		springs[i].scale.y = maxf(0.05,float(lengths[i]))
	for i in range(2):
		align_rod(axles[i],wheels[2*i].position,wheels[2*i+1].position)
		differentials[i].position = (wheels[2*i].position+wheels[2*i+1].position)*0.5
