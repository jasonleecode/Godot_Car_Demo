extends SceneTree

var failures := 0
var garage: Node

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ",message)
	else:
		push_error("FAIL: "+message)
		failures += 1

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame

func run() -> void:
	garage = root.get_node("Garage")
	# Exercise actual menu signals and scene transitions for both choices.
	change_scene_to_file("res://Scenes/StartScreen.tscn")
	await frames(3)
	current_scene.show_cards()
	await frames(3)
	check(current_scene.find_child("VehicleCard_sedan",true,false) != null,"sedan card exists")
	check(current_scene.find_child("VehicleCard_wrangler",true,false) != null,"off-roader card exists")
	current_scene.find_child("VehicleCard_sedan",true,false).pressed.emit()
	await frames(3)
	check(current_scene.choosing_location,"vehicle selection opens scene cards")
	current_scene.find_child("SceneCard_test",true,false).pressed.emit()
	await frames(90)
	check(current_scene.car is VehicleBody3D,"sedan selection spawns original vehicle")
	var initial: Vector3 = current_scene.car.position
	Input.action_press("forward")
	await frames(100)
	Input.action_release("forward")
	check(current_scene.car.position.distance_to(initial)>2,"original sedan still drives")
	garage.open_garage()
	await frames(5)
	check(current_scene.selecting,"return to garage opens cards directly")
	current_scene.find_child("VehicleCard_wrangler",true,false).pressed.emit()
	await frames(3)
	current_scene.find_child("SceneCard_test",true,false).pressed.emit()
	await frames(100)
	check(current_scene.car.has_method("reset_suspension"),"off-roader selection spawns suspension vehicle")
	current_scene.reset_car()
	await frames(1)
	check(current_scene.car.position.distance_to(current_scene.spawn.origin)<0.2,"reset restores selected vehicle")
	# Isolated, deterministic terrain for meaningful suspension and drive checks.
	current_scene.queue_free()
	await frames(3)
	var arena := Node3D.new()
	root.add_child(arena)
	var ground := StaticBody3D.new()
	arena.add_child(ground)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(120,1,180)
	shape.shape = box
	ground.add_child(shape)
	shape.position.y = -0.5
	var car = load("res://cars/Wrangler.tscn").instantiate()
	arena.add_child(car)
	car.position = Vector3(0,1.5,0)
	await frames(240)
	print("SETTLE y=",car.position.y," speed=",car.linear_velocity.length()," lengths=",car.lengths)
	check(car.contacts.all(func(value): return value),"all four wheels settle in contact")
	check(car.linear_velocity.length()<0.15,"spring/damper system settles without perpetual bounce")
	check(car.global_basis.y.dot(Vector3.UP)>0.98,"vehicle rests upright")
	check(float(car.lengths[0])>0.15 and float(car.lengths[0])<0.54,"static suspension supports weight within travel")
	# A one-sided rounded obstacle makes the left and right suspension articulate differently.
	var obstacle := StaticBody3D.new()
	arena.add_child(obstacle)
	var obstacle_shape := CollisionShape3D.new()
	var bump := SphereShape3D.new()
	bump.radius = 0.75
	obstacle_shape.shape = bump
	obstacle.add_child(obstacle_shape)
	obstacle.position = Vector3(1.0,-0.43,9)
	var max_split := 0.0
	var max_roll := 0.0
	Input.action_press("forward")
	for i in range(240):
		await physics_frame
		max_split = maxf(max_split,absf(float(car.lengths[0])-float(car.lengths[1])))
		max_roll = maxf(max_roll,absf(car.rotation.z))
	Input.action_release("forward")
	print("DRIVE pos=",car.position," speed=",car.linear_velocity.length()," articulation=",max_split," roll=",max_roll)
	check(car.position.z>12,"four wheel drive crosses the obstacle")
	check(max_split>0.08,"uneven terrain produces independent wheel travel")
	check(max_roll>0.01,"suspension forces produce physical chassis roll")
	check(car.global_basis.y.dot(Vector3.UP)>0.75,"vehicle remains upright after obstacle")
	var braking_speed: float = car.linear_velocity.length()
	Input.action_press("brake")
	await frames(120)
	Input.action_release("brake")
	check(car.linear_velocity.length()<braking_speed*0.35,"braking reduces speed substantially")
	Input.action_press("gear")
	await frames(2)
	Input.action_release("gear")
	check(car.low_range,"low range can be selected")
	# Reverse and steering use the same tire contact forces as forward driving.
	car.transform = Transform3D(Basis.IDENTITY,Vector3(15,1.5,0))
	car.linear_velocity = Vector3.ZERO
	car.angular_velocity = Vector3.ZERO
	car.reset_suspension()
	await frames(120)
	Input.action_press("backward")
	await frames(100)
	Input.action_release("backward")
	check(car.position.z < -1.5,"reverse drives backward")
	car.transform = Transform3D(Basis.IDENTITY,Vector3(15,1.5,0))
	car.linear_velocity = Vector3.ZERO
	car.angular_velocity = Vector3.ZERO
	car.reset_suspension()
	await frames(120)
	Input.action_press("forward")
	Input.action_press("left")
	await frames(100)
	Input.action_release("forward")
	Input.action_release("left")
	check(car.position.x > 15.3 and car.global_basis.z.x > 0.1,"steering changes trajectory in the intended direction")
	# Climb a continuous slope and land on the flat beyond it.
	var ramp := StaticBody3D.new()
	arena.add_child(ramp)
	var ramp_shape := CollisionShape3D.new()
	var ramp_box := BoxShape3D.new()
	ramp_box.size = Vector3(7,0.25,14)
	ramp_shape.shape = ramp_box
	ramp.add_child(ramp_shape)
	ramp.position = Vector3(35,1.47,9)
	ramp.rotation.x = -0.22
	car.transform = Transform3D(Basis.IDENTITY,Vector3(35,1.5,-1))
	car.linear_velocity = Vector3.ZERO
	car.angular_velocity = Vector3.ZERO
	car.reset_suspension()
	await frames(120)
	var highest := 0.0
	Input.action_press("forward")
	for i in range(420):
		await physics_frame
		highest = maxf(highest,car.position.y)
	Input.action_release("forward")
	await frames(180)
	print("RAMP height=",highest," pos=",car.position," upright=",car.global_basis.y.y)
	check(highest>2.8 and car.position.z>17,"low range climbs ramp and clears the crest")
	check(car.global_basis.y.y>0.8 and car.position.y<1,"suspension recovers after landing")
	# Airborne tires must not generate traction.
	car.position = Vector3(20,8,0)
	car.linear_velocity = Vector3.ZERO
	car.angular_velocity = Vector3.ZERO
	car.reset_suspension()
	Input.action_press("forward")
	await frames(12)
	Input.action_release("forward")
	check(car.contacts.all(func(value): return not value),"airborne wheels report no ground contact")
	check(absf(car.linear_velocity.z)<0.1,"airborne throttle does not accelerate vehicle")
	arena.queue_free()
	await frames(3)
	print("RESULT: ",failures," failures")
	quit(1 if failures else 0)
