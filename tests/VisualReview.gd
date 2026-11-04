extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func shot(file: String) -> void:
	await create_timer(1.5).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(file)

func run() -> void:
	change_scene_to_file("res://Scenes/StartScreen.tscn")
	await process_frame
	await process_frame
	await shot("/tmp/car-home.png")
	current_scene.show_cards()
	await shot("/tmp/car-cards.png")
	root.get_node("Garage").drive(1,2)
	await create_timer(3).timeout
	await shot("/tmp/car-wrangler.png")
	# Front three-quarter view of the actual vehicle in the existing world.
	var world = current_scene
	world.set_physics_process(false)
	world.camera.position = world.car.global_position+world.car.global_basis*Vector3(5,3,6)
	world.camera.look_at(world.car.global_position+Vector3.UP)
	await shot("/tmp/car-wrangler-front.png")
	quit()
