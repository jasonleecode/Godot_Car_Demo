extends SceneTree
const Coast = preload("res://Scenes/coastal/CoastalTerrain.gd")
var failures := 0
func _initialize() -> void:
	run.call_deferred()
func frames(n: int) -> void:
	for i in range(n): await physics_frame
func check(ok: bool, message: String) -> void:
	if ok: print("PASS: ",message)
	else:
		push_error("FAIL: "+message)
		failures += 1
func run() -> void:
	var garage := root.get_node("Garage")
	check(garage.LOCATIONS[0].id=="coast" and garage.LOCATIONS[1].id=="valley" and garage.LOCATIONS[2].id=="test","scene order is coast, valley, prototype")
	change_scene_to_file("res://Scenes/StartScreen.tscn")
	await frames(3)
	current_scene.show_cards()
	current_scene.find_child("VehicleCard_rubicon",true,false).pressed.emit()
	await frames(3)
	check(current_scene.find_child("SceneCard_coast",true,false)!=null,"coastal scene has a selectable card")
	current_scene.find_child("SceneCard_coast",true,false).pressed.emit()
	await frames(180)
	var world = current_scene
	check(world.name=="CoastalDrive" and garage.selected==2,"card starts coast with selected Rubicon")
	check(world.terrain.road_length>2400 and world.terrain.road_length<3000,"mountain coast has a continuous 2.6 km driving loop")
	check(world.terrain.tree_count>100 and world.terrain.house_count>=15,"wooded slopes and village are populated")
	check(Coast.road_point(0).distance_to(Coast.road_point(TAU))<0.001,"loop closes without a positional seam")
	check(Coast.road_forward(0).dot(Coast.road_forward(TAU))>0.999,"loop closes without a heading seam")
	check(world.terrain.rock_count>200 and world.terrain.tea_row_count==27,"granite outcrops and terraced tea gardens populate the coast")
	var low := INF
	var high := -INF
	var max_grade := 0.0
	var left_bends := 0
	var right_bends := 0
	for i in range(720):
		var angle := TAU*i/720
		var a := Coast.road_point(angle)
		var b := Coast.road_point(angle+0.002)
		low = minf(low,a.y)
		high = maxf(high,a.y)
		max_grade = maxf(max_grade,absf(b.y-a.y)/Vector2(b.x-a.x,b.z-a.z).length())
		var turn := Coast.road_forward(angle).cross(Coast.road_forward(angle+0.002)).y
		if turn>0.0001: left_bends += 1
		if turn< -0.0001: right_bends += 1
	check(high-low>55 and low>8,"route climbs through more than 55 metres of elevation above sea level")
	check(max_grade<0.18,"road grades stay below 18 percent for the playable vehicles")
	check(left_bends>40 and right_bends>40,"route includes alternating left and right bends")
	check(Coast.height_at(155,140)>180,"mountain massif rises well above the coastal road")
	print("ROUTE metres=",world.terrain.road_length," height=",low,"..",high," grade=",max_grade," trees=",world.terrain.tree_count," rocks=",world.terrain.rock_count)
	var supported := true
	var rails := true
	for i in range(360):
		var angle := TAU*i/360
		for lane in [-2.5,2.5]:
			var p: Vector3 = Coast.road_point(angle)+Coast.road_outward(angle)*lane
			var ray := PhysicsRayQueryParameters3D.create(p+Vector3.UP*2,p-Vector3.UP,1,[world.car.get_rid()])
			var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(ray)
			supported = supported and not hit.is_empty() and absf(hit.position.y-p.y-0.14)<0.08
		var p := Coast.road_point(angle)+Vector3.UP*0.88
		var ray := PhysicsRayQueryParameters3D.create(p+Coast.road_outward(angle)*5.6,p+Coast.road_outward(angle)*6.7,1,[world.car.get_rid()])
		var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(ray)
		rails = rails and not hit.is_empty()
	check(supported,"both lanes have matching collision around the entire loop (720 samples)")
	check(rails,"ocean-side guardrails physically block vehicles (360 samples)")
	for vehicle in range(3):
		garage.drive(vehicle,0)
		await frames(180)
		world = current_scene
		var car = world.car
		check(car.global_position.distance_to(world.spawn.origin)<2,"vehicle %d settles safely on coastal road" % vehicle)
		if car.has_method("reset_suspension"):
			check(car.contacts.all(func(v):return v),"vehicle %d has four supported tires" % vehicle)
		for mode in range(4):
			check(world.camera.global_transform.is_finite(),"coastal view %d is valid for vehicle %d" % [mode,vehicle])
			world.camera.cycle_view()
		var start: Vector3 = car.position
		Input.action_press("forward")
		await frames(120)
		Input.action_release("forward")
		check(car.position.distance_to(start)>3 and car.global_basis.y.y>0.9,"vehicle %d accelerates on road and stays upright" % vehicle)
		world.reset_car()
		await frames(2)
		check(car.position.distance_to(world.spawn.origin)<0.3,"Esc reset returns vehicle %d to coastal start" % vehicle)
	# Ocean recovery returns to the last safe road section, not an invisible water floor.
	world.safe_angle = 1.4
	world.car.position = Coast.road_point(1.4)+Coast.road_outward(1.4)*55
	world.car.position.y = -0.2
	await frames(3)
	check(world.car.position.distance_to(world.road_spawn(1.4).origin)<0.5,"falling into sea recovers to last safe road section")
	garage.open_garage()
	await frames(4)
	check(current_scene.find_child("VehicleCard_rubicon",true,false)!=null,"G garage navigation remains available")
	print("RESULT: ",failures," failures")
	quit(1 if failures else 0)
