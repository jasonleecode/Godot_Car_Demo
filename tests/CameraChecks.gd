extends SceneTree
var failures := 0
func _initialize() -> void:
	run.call_deferred()
func frames(n := 2) -> void:
	for i in range(n):
		await physics_frame
func check(ok: bool, message: String) -> void:
	if ok: print("PASS: ",message)
	else:
		push_error("FAIL: "+message)
		failures += 1
func key(code: int, echo := false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	event.echo = echo
	Input.parse_input_event(event)
	event = event.duplicate()
	event.pressed = false
	event.echo = false
	Input.parse_input_event(event)
func mouse(button: int, pressed: bool, point := Vector2(950,550)) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.position = point
	event.global_position = point
	Input.parse_input_event(event)
func motion(relative: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.relative = relative
	event.screen_relative = relative
	event.position = Vector2(950,550)
	Input.parse_input_event(event)
func run() -> void:
	var garage := root.get_node("Garage")
	for location in range(garage.LOCATIONS.size()):
		for vehicle in range(3):
			garage.drive(vehicle,location)
			await frames(120)
			var world = current_scene
			var camera = world.camera
			world.car.freeze = true
			var initial: Transform3D = world.car.global_transform
			var positions: Array[Vector3] = []
			for mode in range(4):
				check(camera.view==mode,"V order %d on vehicle %d / scene %d" % [mode,vehicle,location])
				await frames()
				positions.append(camera.global_position)
				check(camera.global_transform.is_finite(),"camera transform is finite")
				if mode==2:
					check(camera.global_position.distance_to(world.car.to_global(camera.eye))<0.001,"cockpit follows driver eye without terrain correction")
					check((-camera.global_basis.z).dot(world.car.global_basis.z)>0.99,"cockpit looks forward")
				key(KEY_V)
				await frames()
			check(camera.view==0 and current_scene==world,"V wraps to rear without opening garage")
			check(initial.is_equal_approx(world.car.global_transform),"changing views does not move vehicle")
			check(positions[0].distance_to(positions[1])>3 and positions[2].distance_to(positions[3])>5,"presets have distinct positions")
	var world = current_scene
	var camera = world.camera
	key(KEY_V,true)
	await frames()
	check(camera.view==0,"held V does not repeatedly cycle")
	mouse(MOUSE_BUTTON_LEFT,true)
	motion(Vector2(150,60))
	await frames()
	check(camera.drag_button==MOUSE_BUTTON_LEFT and absf(camera.yaw)>0.1,"left drag orbits camera")
	mouse(MOUSE_BUTTON_LEFT,false,Vector2(60,60))
	await frames()
	check(camera.drag_button==MOUSE_BUTTON_NONE and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"release over HUD restores cursor")
	var orbit: float = camera.yaw
	await frames(60)
	check(is_equal_approx(camera.yaw,orbit),"inspection angle persists after release")
	var before: float = camera.distance
	mouse(MOUSE_BUTTON_WHEEL_UP,true)
	await frames()
	check(camera.distance<before,"wheel zooms in")
	for i in range(100): mouse(MOUSE_BUTTON_WHEEL_DOWN,true)
	await frames()
	check(camera.distance<=24,"zoom is bounded")
	key(KEY_C)
	await frames()
	check(is_zero_approx(camera.yaw) and is_equal_approx(camera.distance,8.3),"C restores preset")
	mouse(MOUSE_BUTTON_LEFT,true,Vector2(60,60))
	await frames()
	if DisplayServer.get_name() != "headless":
		check(camera.drag_button==MOUSE_BUTTON_NONE,"HUD clicks do not start orbit")
	else:
		print("SKIP: headless display has no GUI mouse picking; covered by desktop run")
	mouse(MOUSE_BUTTON_LEFT,false)
	mouse(MOUSE_BUTTON_RIGHT,true)
	await frames()
	check(camera.drag_button==MOUSE_BUTTON_RIGHT,"right drag also supported")
	camera.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	check(camera.drag_button==MOUSE_BUTTON_NONE and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"focus loss releases mouse capture")
	key(KEY_V)
	key(KEY_V)
	await frames()
	mouse(MOUSE_BUTTON_RIGHT,true)
	motion(Vector2(10000,-10000))
	await frames()
	check(absf(camera.yaw)<=deg_to_rad(105) and absf(camera.pitch)<=deg_to_rad(65),"cockpit freelook is clamped")
	mouse(MOUSE_BUTTON_RIGHT,false)
	before = camera.fov
	mouse(MOUSE_BUTTON_WHEEL_UP,true)
	await frames()
	check(camera.fov<before,"cockpit wheel adjusts FOV")
	mouse(MOUSE_BUTTON_RIGHT,true)
	key(KEY_G)
	await frames(5)
	check(current_scene!=world and current_scene.find_child("VehicleCard_rubicon",true,false)!=null,"G returns to garage")
	check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"leaving scene releases mouse capture")
	print("RESULT: ",failures," failures")
	quit(1 if failures else 0)
