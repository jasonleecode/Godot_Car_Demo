extends SceneTree
const Terrain = preload("res://Scenes/offroad/OffroadTerrain.gd")

func _initialize() -> void:
	run.call_deferred()

func shot(file: String) -> void:
	await create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(file)

func run() -> void:
	change_scene_to_file("res://Scenes/StartScreen.tscn")
	await process_frame
	await process_frame
	current_scene.show_cards()
	current_scene.find_child("VehicleCard_wrangler",true,false).pressed.emit()
	await shot("/tmp/car-scene-cards.png")
	current_scene.find_child("SceneCard_valley",true,false).pressed.emit()
	await create_timer(3).timeout
	await shot("/tmp/car-valley-spawn.png")
	var world = current_scene
	await physics_frame
	world.car.sleeping = false
	world.car.transform = Transform3D(Basis.IDENTITY,Vector3(0,Terrain.height_at(0,-44)+0.45,-44))
	PhysicsServer3D.body_set_state(world.car.get_rid(),PhysicsServer3D.BODY_STATE_TRANSFORM,world.car.transform)
	world.car.linear_velocity = Vector3.ZERO
	world.car.reset_suspension()
	world.car.low_range = true
	await create_timer(2).timeout
	print("WATER VIEW position=",world.car.position," immersion=",world.water_immersion)
	await shot("/tmp/car-valley-water.png")
	world.set_physics_process(false)
	world.camera.position = Vector3(88,95,-110)
	world.camera.look_at(Vector3(0,5,5))
	await shot("/tmp/car-valley-overview.png")
	quit()
