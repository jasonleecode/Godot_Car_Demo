extends SceneTree
func _initialize() -> void:
	run.call_deferred()
func shot(path: String) -> void:
	await create_timer(1.5).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
func run() -> void:
	change_scene_to_file("res://Scenes/StartScreen.tscn")
	await process_frame
	await process_frame
	current_scene.show_cards()
	current_scene.find_child("VehicleCard_rubicon",true,false).pressed.emit()
	await shot("/tmp/coast-scene-cards.png")
	current_scene.find_child("SceneCard_coast",true,false).pressed.emit()
	await create_timer(4).timeout
	current_scene.car.freeze = true
	current_scene.car.linear_velocity = Vector3.ZERO
	current_scene.car.angular_velocity = Vector3.ZERO
	await shot("/tmp/coast-drive.png")
	current_scene.camera.cycle_view()
	current_scene.camera.cycle_view()
	await shot("/tmp/coast-cockpit.png")
	current_scene.set_physics_process(false)
	current_scene.camera.position = Vector3(680,550,-790)
	current_scene.camera.look_at(Vector3(-65,70,0))
	current_scene.camera.fov = 55
	await shot("/tmp/coast-overview.png")
	for angle in [0.7,1.75,3.4]:
		var coast = preload("res://Scenes/coastal/CoastalTerrain.gd")
		var point: Vector3 = coast.road_point(angle)
		current_scene.camera.position = point+coast.road_outward(angle)*75+Vector3.UP*65-coast.road_forward(angle)*50
		current_scene.camera.look_at(point-coast.road_outward(angle)*35)
		await shot("/tmp/coast-mountain-%.2f.png" % angle)
	quit()
