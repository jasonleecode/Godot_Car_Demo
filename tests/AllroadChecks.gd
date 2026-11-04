extends SceneTree
var failures := 0
func _initialize() -> void:
	run.call_deferred()
func frames(n: int) -> void:
	for i in range(n):
		await physics_frame
func check(ok: bool, message: String) -> void:
	if ok: print("PASS: ",message)
	else:
		push_error("FAIL: "+message)
		failures += 1
func run() -> void:
	var garage := root.get_node("Garage")
	change_scene_to_file("res://Scenes/StartScreen.tscn")
	await frames(3)
	current_scene.show_cards()
	check(current_scene.find_child("VehicleCard_sedan",true,false)!=null and current_scene.find_child("VehicleCard_wrangler",true,false)!=null,"original vehicles remain selectable")
	var card := current_scene.find_child("VehicleCard_allroad",true,false)
	check(card!=null,"Allroad has its own fifth vehicle card")
	card.pressed.emit()
	current_scene.find_child("SceneCard_test",true,false).pressed.emit()
	await frames(180)
	var car = current_scene.car
	check(garage.VEHICLES[garage.selected].id=="allroad","Allroad card spawns the new vehicle")
	check(is_equal_approx(car.wheel_radius*2,0.7157),"physical tire diameter is 235/55 R18")
	check(is_equal_approx(car.wheel_mounts[0].z-car.wheel_mounts[2].z,2.925),"physics uses a 2.925 metre wheelbase")
	check(car.contacts.all(func(v):return v),"four tires settle in contact")
	check(car.linear_velocity.length()<0.15,"Allroad suspension settles stably")
	check(current_scene.camera!=null and current_scene.suspension_bars.size()==4,"Allroad has follow camera and suspension HUD")
	var visual = car.get_node("Visual")
	for i in range(4):
		var expected: Vector3 = car.wheel_mounts[i]-Vector3(0,car.lengths[i],0)
		check(visual.wheels[i].position.distance_to(expected)<0.001,"rendered wheel matches suspension contact "+str(i))
	Input.action_press("gear")
	await frames(2)
	Input.action_release("gear")
	check(car.terrain_mode and not car.low_range,"Allroad changes damping mode without a low-range gearbox")
	current_scene.reset_car()
	await frames(2)
	check(car.position.distance_to(current_scene.spawn.origin)<0.2,"Allroad resets correctly")
	garage.open_garage()
	await frames(12)
	var vehicle_scroll: ScrollContainer = current_scene.find_child("VehicleScroll",true,false)
	var selected_card: Control = current_scene.find_child("VehicleCard_allroad",true,false)
	check(vehicle_scroll.get_global_rect().encloses(selected_card.get_global_rect()),"returning to garage reveals the selected fifth card")
	current_scene.find_child("VehicleCard_allroad",true,false).pressed.emit()
	current_scene.find_child("SceneCard_valley",true,false).pressed.emit()
	await frames(180)
	car = current_scene.car
	check(current_scene.name=="PineValley" and car.contacts.all(func(v):return v),"Allroad is playable in the off-road world")
	var max_wet := 0.0
	var max_split := 0.0
	Input.action_press("forward")
	for i in range(660):
		await physics_frame
		max_wet = maxf(max_wet,current_scene.water_immersion)
		max_split = maxf(max_split,absf(car.lengths[0]-car.lengths[2]))
	Input.action_release("forward")
	print("ALLROAD DRIVE position=",car.position," wet=",max_wet," travel difference=",max_split)
	check(max_wet>0.1 and car.position.z>-35,"Allroad enters and exits a water pit under power")
	check(max_split>0.06,"new wheelbase produces suspension articulation over terrain")
	check(car.global_basis.y.y>0.8,"Allroad stays upright after water and bumps")
	Input.action_press("brake")
	await frames(120)
	Input.action_release("brake")
	check(car.linear_velocity.length()<0.7,"Allroad brakes to a stop")
	garage.drive(4,0)
	await frames(180)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_P
	key.pressed = true
	current_scene._unhandled_input(key)
	await frames(5)
	check(current_scene.car.is_parked() and current_scene.coastal_hud.drive_mode.begins_with("P"),"Allroad coastal scene and P HUD work together")
	print("RESULT: ",failures," failures")
	quit(1 if failures else 0)
