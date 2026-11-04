extends Node3D
## Art and physics share metre-scale wheel centres. GLB wheels stay independently animated.
const MOUNTS = [Vector3(0.875,0.42,1.504),Vector3(-0.875,0.42,1.504),Vector3(0.875,0.42,-1.504),Vector3(-0.875,0.42,-1.504)]
var wheels: Array[Node3D] = []
var rotors: Array[Node3D] = []
var chassis := preload("res://cars/RubiconChassis.gd").new()
var model: Node3D

func _ready() -> void:
	model = preload("res://cars/Models/Rubicon/Rubicon.glb").instantiate()
	add_child(model)
	prepare_materials(model)
	for suffix in ["FL","FR","RL","RR"]:
		wheels.append(model.find_child("Wheel"+suffix,true,false))
		rotors.append(model.find_child("Rotor"+suffix,true,false))
	chassis.name = "Chassis"
	add_child(chassis)
	chassis.configure(MOUNTS,true)
	update_suspension([0.42,0.42,0.42,0.42],0,0)

func prepare_materials(node: Node) -> void:
	if node is MeshInstance3D:
		for i in range(node.mesh.get_surface_count()):
			var source: Material = node.mesh.surface_get_material(i)
			if source is StandardMaterial3D:
				var mat: StandardMaterial3D = source.duplicate()
				if "glazing" in source.resource_name.to_lower():
					mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
					mat.cull_mode = BaseMaterial3D.CULL_DISABLED
					node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				elif "clearcoat" in source.resource_name.to_lower():
					mat.clearcoat_enabled = true
					mat.clearcoat = 0.85
					mat.clearcoat_roughness = 0.12
				node.set_surface_override_material(i,mat)
	for child in node.get_children():
		prepare_materials(child)

func update_suspension(lengths: Array, steering: float, roll: float) -> void:
	if wheels.size()!=4:
		return
	for i in range(4):
		var center: Vector3 = MOUNTS[i]-Vector3(0,lengths[i],0)
		wheels[i].position = center
		wheels[i].rotation.y = steering if i<2 else 0.0
		rotors[i].rotation.x = roll
	chassis.update_suspension(lengths,steering,roll)
