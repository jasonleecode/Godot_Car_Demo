extends SceneTree
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if ok: print("PASS: ",message)
	else:
		push_error("FAIL: "+message)
		failures += 1
func run() -> void:
	var visual = load("res://cars/AllroadVisual.gd").new()
	root.add_child(visual)
	var normals := {}
	var roughness := {}
	var glazing := false
	for node in visual.model.find_children("*","MeshInstance3D",true,false):
		for surface in range(node.mesh.get_surface_count()):
			var mat: StandardMaterial3D = node.get_active_material(surface)
			if mat.normal_enabled and mat.normal_texture: normals[mat.normal_texture.get_rid()] = true
			if mat.roughness_texture: roughness[mat.roughness_texture.get_rid()] = true
			if "clear tinted glazing" in mat.resource_name.to_lower():
				glazing = mat.transparency==BaseMaterial3D.TRANSPARENCY_ALPHA and mat.albedo_color.a<0.3
	check(normals.size()>=4 and roughness.size()>=3,"normal and roughness textures reach the runtime materials")
	check(glazing,"window glazing remains transparent")
	for i in range(4):
		var rotor: Node3D = visual.rotors[i]
		var radius := 0.0
		for node in rotor.find_children("*","MeshInstance3D",true,false):
			for surface in range(node.mesh.get_surface_count()):
				var mat: Material = node.get_active_material(surface)
				if not "r18 tire rubber" in mat.resource_name.to_lower(): continue
				var points: PackedVector3Array = node.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
				for p in points:
					var local: Vector3 = rotor.global_transform.affine_inverse()*node.global_transform*p
					radius = maxf(radius,Vector2(local.y,local.z).length())
		print("TIRE ",i," diameter=",radius*2)
		check(absf(radius-0.35785)<0.001,"rendered tire %d has a true 235/55 R18 envelope" % i)
	var chassis: Node3D = visual.chassis
	check(chassis.arms.size()==20 and chassis.air_springs.size()==4,"four independent five-link corners with air bellows")
	check(chassis.axles.is_empty() and chassis.shafts.size()==4,"four independent CV shafts and no rigid axle")
	var fixed_front: Vector3 = chassis.differentials[0].position
	var fixed_rear: Vector3 = chassis.differentials[1].position
	for travel in [[0.45,0.45,0.45,0.45],[0.37,0.69,0.58,0.39],[0.69,0.37,0.37,0.69]]:
		visual.update_suspension(travel,0.35,1.2)
		check(chassis.differentials[0].position==fixed_front and chassis.differentials[1].position==fixed_rear,"differentials stay fixed to the subframes")
		var connected := true
		for i in range(4):
			var shaft: Node3D = chassis.shafts[i]
			connected = connected and (shaft.transform*Vector3(0,-0.5,0)).distance_to(chassis.cv_boots[i*2].position)<0.001
			connected = connected and (shaft.transform*Vector3(0,0.5,0)).distance_to(chassis.cv_boots[i*2+1].position)<0.001
			connected = connected and chassis.hubs[i].position.distance_to(visual.wheels[i].position)<0.001
		check(connected,"CV shafts and knuckles remain connected during articulation")
	print("RESULT: ",failures," failures")
	quit(1 if failures else 0)
