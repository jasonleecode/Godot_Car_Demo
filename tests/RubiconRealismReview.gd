extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var studio := Node3D.new()
	root.add_child(studio)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("52748c")
	sky_mat.sky_horizon_color = Color("c6d5db")
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	environment.environment = env
	studio.add_child(environment)
	var sun := DirectionalLight3D.new()
	studio.add_child(sun)
	sun.rotation_degrees = Vector3(-40,-45,0)
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	var plane := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(200,200)
	plane.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("555f65")
	mat.roughness = 0.85
	plane.material_override = mat
	studio.add_child(plane)
	var camera := Camera3D.new()
	studio.add_child(camera)
	camera.current = true
	camera.fov = 40
	for model in ["Rubicon"]:
		var car = load("res://cars/%s.tscn" % model).instantiate()
		car.freeze = true
		car.position.y = 0.05 if model=="Sedan" else 0.465
		studio.add_child(car)
		car.set_physics_process(false)
		if model=="Sedan":
			var old: Camera3D = car.get_node("look/Camera3D")
			old.set_physics_process(false)
			old.current = false
		else:
			car.visual.update_suspension([0.44,0.44,0.44,0.44],0,0)
		camera.current = true
		for view in [["front",Vector3(3.8,2.1,5.5)],["side",Vector3(6.8,1.45,0.2)],["rear",Vector3(-3.8,2.0,-5.5)]]:
			camera.position = view[1]
			camera.look_at(Vector3(0,1.0,0))
			await create_timer(0.7).timeout
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/rubicon-realism-"+view[0]+".png")
		car.queue_free()
		await process_frame
	studio.queue_free()
	await process_frame
	root.get_node("Garage").drive(2,0)
	await create_timer(4).timeout
	var world = current_scene
	world.car.toggle_parking()
	world.camera.view = 2
	world.camera.reset_view()
	await create_timer(1).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/rubicon-realism-cockpit.png")
	world.camera.view = 0
	world.camera.reset_view()
	await create_timer(1).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/rubicon-realism-drive.png")
	quit()
