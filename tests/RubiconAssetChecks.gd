extends SceneTree
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if ok: print("PASS: ",message)
	else:
		push_error("FAIL: "+message)
		failures += 1
func run() -> void:
	var visual = load("res://cars/RubiconVisual.gd").new()
	root.add_child(visual)
	var normals := {}
	var roughness := {}
	var glazing := false
	for node in visual.model.find_children("*","MeshInstance3D",true,false):
		for surface in range(node.mesh.get_surface_count()):
			var mat: StandardMaterial3D = node.get_active_material(surface)
			if mat.normal_enabled and mat.normal_texture: normals[mat.normal_texture.get_rid()] = true
			if mat.roughness_texture: roughness[mat.roughness_texture.get_rid()] = true
			if "glazing" in mat.resource_name.to_lower():
				glazing = mat.transparency==BaseMaterial3D.TRANSPARENCY_ALPHA and mat.albedo_color.a<0.3
	check(normals.size()>=5 and roughness.size()>=3,"normal and roughness textures reach the runtime materials")
	check(glazing,"window glazing remains transparent")
	for i in range(4):
		var rotor: Node3D = visual.rotors[i]
		var radius := 0.0
		for node in rotor.find_children("*","MeshInstance3D",true,false):
			for surface in range(node.mesh.get_surface_count()):
				var mat: Material = node.get_active_material(surface)
				if not "tire rubber" in mat.resource_name.to_lower(): continue
				var points: PackedVector3Array = node.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
				for p in points:
					var local: Vector3 = rotor.global_transform.affine_inverse()*node.global_transform*p
					radius = maxf(radius,Vector2(local.y,local.z).length())
		print("TIRE ",i," diameter=",radius*2)
		check(absf(radius-0.4445)<0.001,"rendered tire %d has a true 35 inch envelope" % i)
	var chassis: Node3D = visual.chassis
	check(chassis.find_child("FuelTankCradle",true,false)!=null and chassis.find_child("RearTransverseMuffler",true,false)!=null,"photograph-referenced tank protection and transverse muffler exist")
	check(chassis.find_child("FrontSwayDisconnectHousing",true,false)!=null and chassis.find_child("SteeringDamperBody",true,false)!=null,"front sway-bar housing and steering stabilizer exist")
	print("RESULT: ",failures," failures")
	quit(1 if failures else 0)
