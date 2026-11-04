extends SceneTree
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if ok: print("PASS: ",message)
	else:
		push_error("FAIL: "+message)
		failures += 1
func run() -> void:
	var visual = load("res://cars/JimnyVisual.gd").new()
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
	check(normals.size()>=4 and roughness.size()>=3,"normal and roughness textures reach the runtime materials")
	check(glazing,"window glazing remains transparent")
	for i in range(4):
		var rotor: Node3D = visual.rotors[i]
		var radius := 0.0
		for node in rotor.find_children("*","MeshInstance3D",true,false):
			for surface in range(node.mesh.get_surface_count()):
				var mat: Material = node.get_active_material(surface)
				if not "r15 rubber" in mat.resource_name.to_lower(): continue
				var points: PackedVector3Array = node.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
				for p in points:
					var local: Vector3 = rotor.global_transform.affine_inverse()*node.global_transform*p
					radius = maxf(radius,Vector2(local.y,local.z).length())
		print("TIRE ",i," diameter=",radius*2)
		check(absf(radius-0.3465)<0.001,"rendered tire %d has a true 195/80 R15 envelope" % i)
	var chassis: Node3D = visual.chassis
	check(chassis.find_child("SeparateTransferCase",true,false)!=null and chassis.find_child("CentreXBrace",true,false)!=null,"JB74 separate transfer case and X-braced ladder frame exist")
	check(chassis.find_child("RearBrakeDrum",true,false)!=null and chassis.find_child("VentilatedBrakeDisc",true,false)!=null,"front disc and rear drum brakes exist")
	check(chassis.arms.size()==4 and chassis.track_bars.size()==2,"two radius arms and one Panhard rod per axle")
	print("RESULT: ",failures," failures")
	quit(1 if failures else 0)
