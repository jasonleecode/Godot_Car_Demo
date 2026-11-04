extends SceneTree
func _initialize() -> void:
	run.call_deferred()
func shot(path: String) -> void:
	await create_timer(0.7).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
func run() -> void:
	var garage := root.get_node("Garage")
	garage.drive(2,0)
	await create_timer(3).timeout
	for mode in range(4):
		await shot("/tmp/camera-rubicon-%d.png" % mode)
		current_scene.camera.cycle_view()
	current_scene.camera.yaw = -2.4
	current_scene.camera.pitch = 0.12
	current_scene.camera.distance = 4.5
	await shot("/tmp/camera-rubicon-orbit.png")
	for vehicle in range(2):
		garage.drive(vehicle,0)
		await create_timer(3).timeout
		current_scene.camera.cycle_view()
		current_scene.camera.cycle_view()
		await shot("/tmp/camera-cockpit-%d.png" % vehicle)
	quit()
