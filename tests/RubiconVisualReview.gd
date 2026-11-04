extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func shot(path: String) -> void:
	await create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)

func run() -> void:
	change_scene_to_file("res://Scenes/StartScreen.tscn")
	await process_frame
	await process_frame
	await shot("/tmp/rubicon-home.png")
	current_scene.show_cards()
	await shot("/tmp/rubicon-cards.png")
	current_scene.find_child("VehicleCard_rubicon",true,false).pressed.emit()
	current_scene.find_child("SceneCard_test",true,false).pressed.emit()
	await create_timer(3).timeout
	var world = current_scene
	world.car.input_enabled = false
	world.set_physics_process(false)
	world.camera.position = world.car.global_position+world.car.global_basis*Vector3(4,2.2,5.0)
	world.camera.look_at(world.car.global_position+Vector3.UP*0.85)
	await shot("/tmp/rubicon-front.png")
	world.camera.position = world.car.global_position+world.car.global_basis*Vector3(-4,2.0,-5)
	world.camera.look_at(world.car.global_position+Vector3.UP*0.85)
	await shot("/tmp/rubicon-rear.png")
	world.camera.position = world.car.global_position+world.car.global_basis*Vector3(2.5,0.65,2.8)
	world.camera.look_at(world.car.global_transform*Vector3(0.875,0.25,1.504))
	await shot("/tmp/rubicon-tire.png")
	quit()
