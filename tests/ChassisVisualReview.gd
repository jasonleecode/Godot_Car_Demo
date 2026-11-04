extends SceneTree
func _initialize() -> void: run.call_deferred()
func shot(path: String) -> void:
	await create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
func run() -> void:
	var studio := Node3D.new()
	root.add_child(studio)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("37434c")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("d2e0eb")
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = env
	studio.add_child(environment)
	var key := DirectionalLight3D.new()
	studio.add_child(key)
	key.rotation_degrees = Vector3(35,-35,0)
	key.light_energy = 2.3
	var fill := OmniLight3D.new()
	studio.add_child(fill)
	fill.position = Vector3(-3,-1,-3)
	fill.omni_range = 12
	fill.light_energy = 3
	var camera := Camera3D.new()
	studio.add_child(camera)
	camera.current = true
	camera.fov = 48
	for model in ["Wrangler","Rubicon"]:
		var visual = load("res://cars/%sVisual.gd" % model).new()
		studio.add_child(visual)
		visual.update_suspension([0.42,0.42,0.42,0.42],0.15,0)
		camera.position = Vector3(3.4,-2.6,4.7)
		camera.look_at(Vector3(0,0.25,0))
		await shot("/tmp/chassis-"+model+"-under.png")
		visual.update_suspension([0.31,0.65,0.6,0.34],0.35,0)
		camera.position = Vector3(-3,-1.4,-4.3)
		camera.look_at(Vector3(0,0.2,0))
		await shot("/tmp/chassis-"+model+"-articulation.png")
		if model=="Rubicon":
			visual.update_suspension([0.42,0.42,0.42,0.42],0,0)
			camera.position = Vector3(0,-6.0,0)
			camera.look_at(Vector3.ZERO,Vector3.FORWARD)
			await shot("/tmp/chassis-Rubicon-layout.png")
			camera.position = Vector3(1.8,-0.8,3.4)
			camera.look_at(Vector3(0,0.1,1.45))
			await shot("/tmp/chassis-Rubicon-front-axle.png")
		visual.queue_free()
		await process_frame
	studio.queue_free()
	await process_frame
	root.get_node("Garage").drive(2,0)
	await create_timer(4).timeout
	var world = current_scene
	var key_event := InputEventKey.new()
	key_event.physical_keycode = KEY_P
	key_event.pressed = true
	world._unhandled_input(key_event)
	await shot("/tmp/parking-coast.png")
	quit()
