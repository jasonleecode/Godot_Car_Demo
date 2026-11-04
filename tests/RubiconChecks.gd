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
	var card := current_scene.find_child("VehicleCard_rubicon",true,false)
	check(card!=null,"Rubicon has its own third vehicle card")
	card.pressed.emit()
	current_scene.find_child("SceneCard_test",true,false).pressed.emit()
	await frames(180)
	var car = current_scene.car
	check(garage.VEHICLES[garage.selected].id=="rubicon","Rubicon card spawns the new vehicle")
	check(is_equal_approx(car.wheel_radius*2,0.889),"physical tire diameter is 35 inches")
	check(is_equal_approx(car.wheel_mounts[0].z-car.wheel_mounts[2].z,3.008),"physics uses a 3.008 metre wheelbase")
	check(car.contacts.all(func(v):return v),"four tires settle in contact")
	check(car.linear_velocity.length()<0.15,"Rubicon suspension settles stably")
	check(current_scene.camera!=null and current_scene.suspension_bars.size()==4,"Rubicon has follow camera and suspension HUD")
	var visual = car.get_node("Visual")
	for i in range(4):
		var expected: Vector3 = car.wheel_mounts[i]-Vector3(0,car.lengths[i],0)
		check(visual.wheels[i].position.distance_to(expected)<0.001,"rendered wheel matches suspension contact "+str(i))
	Input.action_press("gear")
	await frames(2)
	Input.action_release("gear")
	check(car.low_range,"Rubicon low range engages")
	current_scene.reset_car()
	await frames(2)
	check(car.position.distance_to(current_scene.spawn.origin)<0.2,"Rubicon resets correctly")
	garage.open_garage()
	await frames(3)
	current_scene.find_child("VehicleCard_rubicon",true,false).pressed.emit()
	current_scene.find_child("SceneCard_valley",true,false).pressed.emit()
	await frames(180)
	car = current_scene.car
	check(current_scene.name=="PineValley" and car.contacts.all(func(v):return v),"Rubicon is playable in the off-road world")
	var max_wet := 0.0
	var max_split := 0.0
	Input.action_press("forward")
	for i in range(660):
		await physics_frame
		max_wet = maxf(max_wet,current_scene.water_immersion)
		max_split = maxf(max_split,absf(car.lengths[0]-car.lengths[2]))
	Input.action_release("forward")
	print("RUBICON DRIVE position=",car.position," wet=",max_wet," travel difference=",max_split)
	check(max_wet>0.1 and car.position.z>-35,"Rubicon enters and exits a water pit under power")
	check(max_split>0.06,"new wheelbase produces suspension articulation over terrain")
	check(car.global_basis.y.y>0.8,"Rubicon stays upright after water and bumps")
	Input.action_press("brake")
	await frames(120)
	Input.action_release("brake")
	check(car.linear_velocity.length()<0.7,"Rubicon brakes to a stop")
	print("RESULT: ",failures," failures")
	quit(1 if failures else 0)
