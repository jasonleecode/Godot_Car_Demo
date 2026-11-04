extends SceneTree

const Terrain = preload("res://Scenes/offroad/OffroadTerrain.gd")
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame

func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ",message)
	else:
		push_error("FAIL: "+message)
		failures += 1

func run() -> void:
	var garage := root.get_node("Garage")
	change_scene_to_file("res://Scenes/StartScreen.tscn")
	await frames(3)
	current_scene.show_cards()
	current_scene.find_child("VehicleCard_wrangler",true,false).pressed.emit()
	await frames(3)
	check(current_scene.choosing_location,"vehicle card leads to scene selection")
	check(current_scene.find_child("SceneCard_test",true,false)!=null,"original playground scene card exists")
	check(current_scene.find_child("SceneCard_valley",true,false)!=null,"off-road scene card exists")
	current_scene.show_cards()
	check(garage.selected==1,"going back preserves vehicle choice")
	current_scene.find_child("VehicleCard_wrangler",true,false).pressed.emit()
	current_scene.find_child("SceneCard_valley",true,false).pressed.emit()
	await frames(180)
	var world = current_scene
	var car = world.car
	check(world.name=="PineValley" and garage.LOCATIONS[garage.selected_location].id=="valley","scene card starts selected off-road world")
	check(car.contacts.all(func(v): return v),"off-roader spawns with four supported wheels")
	check(car.position.distance_to(world.spawn.origin)<1.5,"off-roader settles safely in clearing")
	check(world.terrain.tree_positions.size()>200,"forest has hundreds of trees")
	check(world.terrain.get_node("TreeTrunks").get_child_count()>200,"tree trunks have physical collisions")
	check(Terrain.height_at(27,22)-Terrain.height_at(0,-72)>10,"terrain contains climbable hills with elevation gain")
	# The collision must follow the same surface the user sees, including submerged basins.
	for p in [Vector2(0,-72),Vector2(27,22),Vector2(0,-42),Vector2(-48,27),Vector2(61,48)]:
		var query := PhysicsRayQueryParameters3D.create(Vector3(p.x,70,p.y),Vector3(p.x,-10,p.y),1,[car.get_rid()])
		var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(query)
		check(not hit.is_empty() and absf(hit.position.y-Terrain.height_at(p.x,p.y))<0.3,"terrain collision follows height at "+str(p))
	for pool in Terrain.POOLS:
		check(Terrain.pool_level(pool)-Terrain.height_at(pool.center.x,pool.center.y)>0.35,"puddle has a shallow drivable basin")
	Input.action_press("forward")
	var max_wet := 0.0
	var moving_in_water := false
	for i in range(660):
		await physics_frame
		max_wet = maxf(max_wet,world.water_immersion)
		if world.water_immersion>0.1 and car.linear_velocity.length()>0.8:
			moving_in_water = true
	Input.action_release("forward")
	print("WATER RUN pos=",car.position," wet=",max_wet," speed=",car.linear_velocity.length())
	check(max_wet>0.1,"driving from spawn reaches the water pit")
	check(moving_in_water,"vehicle can continue moving through water")
	check(car.position.z>-35,"vehicle exits the far bank under its own power")
	check(car.global_basis.y.y>0.8,"vehicle stays upright through terrain and water")
	check(world.get_surface_grip(Vector3(0,Terrain.height_at(0,-42),-42))<world.get_surface_grip(world.spawn.origin),"wet ground reduces off-roader grip")
	world.reset_car()
	await frames(2)
	check(world.water_immersion==0 and not world.spray.emitting,"reset clears water effects")
	# Compare coasting over dry ground and underwater from the same speed.
	car.position = Vector3(0,Terrain.height_at(0,-72)+0.43,-72)
	car.linear_velocity = Vector3(0,0,4)
	await frames(18)
	var dry_speed: float = Vector2(car.linear_velocity.x,car.linear_velocity.z).length()
	car.transform = Transform3D(Basis.IDENTITY,Vector3(0,Terrain.height_at(0,-42)+0.43,-42))
	car.linear_velocity = Vector3(0,0,4)
	car.angular_velocity = Vector3.ZERO
	car.reset_suspension()
	await frames(18)
	var wet_speed: float = Vector2(car.linear_velocity.x,car.linear_velocity.z).length()
	print("DRAG dry=",dry_speed," wet=",wet_speed)
	check(wet_speed<dry_speed,"water drag reduces coasting speed")
	garage.open_garage()
	await frames(3)
	current_scene.find_child("VehicleCard_sedan",true,false).pressed.emit()
	current_scene.find_child("SceneCard_valley",true,false).pressed.emit()
	await frames(150)
	check(current_scene.car is VehicleBody3D,"sedan also enters off-road world")
	check(current_scene.car.position.y>Terrain.height_at(0,-72)-0.2,"sedan is supported by terrain")
	check(current_scene.camera!=null,"sedan receives terrain-aware follow camera")
	garage.open_garage()
	await frames(3)
	current_scene.find_child("VehicleCard_sedan",true,false).pressed.emit()
	current_scene.find_child("SceneCard_test",true,false).pressed.emit()
	await frames(90)
	check(current_scene.name=="Main" and garage.LOCATIONS[garage.selected_location].id=="test","can return to preserved purple playground")
	print("RESULT: ",failures," failures")
	quit(1 if failures else 0)
