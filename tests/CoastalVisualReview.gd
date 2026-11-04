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
	await shot("/tmp/coast-drive.png")
	current_scene.camera.cycle_view()
	current_scene.camera.cycle_view()
	await shot("/tmp/coast-cockpit.png")
	current_scene.set_physics_process(false)
	current_scene.camera.position = Vector3(300,180,-260)
	current_scene.camera.look_at(Vector3(90,5,-20))
	await shot("/tmp/coast-overview.png")
	quit()
