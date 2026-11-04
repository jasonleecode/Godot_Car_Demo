extends SceneTree
var failures := 0
func _initialize() -> void: run.call_deferred()
func frames(n: int) -> void:
	for i in range(n): await physics_frame
func check(ok: bool, message: String) -> void:
	if ok: print("PASS: ",message)
	else:
		push_error("FAIL: "+message)
		failures += 1
func measure(model: String, slope: Vector2) -> void:
	var arena := Node3D.new()
	root.add_child(arena)
	var basis := Basis(Vector3.RIGHT,-atan(slope.x))*Basis(Vector3.FORWARD,atan(slope.y))
	var ground := StaticBody3D.new()
	arena.add_child(ground)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(80,1,100)
	shape.shape = box
	ground.add_child(shape)
	ground.transform = Transform3D(basis,basis*Vector3(0,-0.5,0))
	var car = load("res://cars/%s.tscn" % model).instantiate()
	car.transform = Transform3D(basis,basis*Vector3(0,1.2,0))
	arena.add_child(car)
	Input.action_press("brake")
	await frames(180)
	Input.action_release("brake")
	print("ENGAGE ",model," slope=",slope," speed=",car.linear_velocity.length()," ",car.toggle_parking())
	check(car.is_parked(),model+" engages P on grade "+str(slope))
	await frames(120)
	var start: Vector3 = car.position
	var drift := 0.0
	Input.action_press("forward")
	for i in range(600):
		await physics_frame
		drift = maxf(drift,(car.position-start).slide(basis.y).length())
	Input.action_release("forward")
	print("PARK ",model," slope=",slope," 10s drift=",drift," speed=",car.linear_velocity.length())
	check(drift<0.025,model+" stays within 2.5 cm for 10 s with accelerator held")
	check(not car.freeze and car.global_basis.y.dot(basis.y)>0.95,model+" keeps suspension active and body upright")
	car.toggle_parking()
	check(not car.is_parked(),model+" releases P")
	Input.action_press("forward")
	await frames(120)
	Input.action_release("forward")
	check(car.position.distance_to(start)>1,model+" moves after release")
	car.linear_velocity = basis.z*5
	await frames(1)
	car.toggle_parking()
	check(not car.is_parked(),model+" rejects P at road speed")
	car.position = Vector3(0,12,0)
	car.linear_velocity = Vector3.ZERO
	car.angular_velocity = Vector3.ZERO
	if car.has_method("reset_suspension"): car.reset_suspension()
	await frames(1)
	car.toggle_parking()
	check(not car.is_parked(),model+" rejects P in the air")
	# Re-engage and remove support; parking must not suspend the vehicle in space.
	car.transform = Transform3D(basis,basis*Vector3(0,1.2,0))
	car.linear_velocity = Vector3.ZERO
	car.angular_velocity = Vector3.ZERO
	if car.has_method("reset_suspension"): car.reset_suspension()
	Input.action_press("brake")
	await frames(180)
	Input.action_release("brake")
	car.toggle_parking()
	check(car.is_parked(),model+" re-engages after landing")
	await frames(30)
	var height: float = car.position.y
	ground.queue_free()
	car.sleeping = false
	await frames(60)
	check(car.position.y<height-2,model+" falls naturally when ground is removed")
	arena.queue_free()
	await frames(3)
func run() -> void:
	for model in ["Sedan","Wrangler","Rubicon","Jimny","Allroad"]:
		for slope in [Vector2(0.18,0),Vector2(-0.30,0),Vector2(0,0.25)]:
			await measure(model,slope)
	# Real P key handling, repeat suppression, reset and both kinds of HUD.
	var garage := root.get_node("Garage")
	for scene_index in [2,0]:
		garage.drive(2,scene_index)
		await frames(180)
		var world = current_scene
		var key := InputEventKey.new()
		key.physical_keycode = KEY_P
		key.pressed = true
		world._unhandled_input(key)
		await frames(3)
		check(world.car.is_parked() and world.gear_label.text.begins_with("P"),"P key engages and standard HUD shows P")
		if scene_index==0:
			check(world.coastal_hud.drive_mode.begins_with("P"),"coastal speedometer shows P")
		key.echo = true
		world._unhandled_input(key)
		check(world.car.is_parked(),"held key repeat does not release P")
		world.reset_car()
		await frames(180)
		check(world.car.is_parked() and world.car.position.distance_to(world.spawn.origin)<1,"reset keeps P and reacquires ground at spawn")
	print("RESULT: ",failures," failures")
	quit(1 if failures else 0)
