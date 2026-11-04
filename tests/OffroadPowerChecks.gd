extends SceneTree
## Measure acceleration and uphill starts through real wheel contacts, not direct force calls.
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
func measure(scene: String, grade: float, low: bool) -> Dictionary:
	var arena := Node3D.new()
	root.add_child(arena)
	var basis := Basis(Vector3.RIGHT,-atan(grade))
	var ground := StaticBody3D.new()
	arena.add_child(ground)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60,1,1600)
	shape.shape = box
	ground.add_child(shape)
	ground.transform = Transform3D(basis,basis*Vector3(0,-0.5,400))
	var car = load(scene).instantiate()
	car.transform = Transform3D(basis,basis*Vector3(0,1.2,0))
	arena.add_child(car)
	car.low_range = low
	Input.action_press("brake")
	await frames(180)
	Input.action_release("brake")
	var start: Vector3 = car.position
	var time_to_60 := -1.0
	var speed_at_8 := 0.0
	var min_upright := 1.0
	var rollback := 0.0
	Input.action_press("forward")
	for i in range(960 if grade==0 else 480):
		await physics_frame
		var speed: float = car.linear_velocity.dot(basis.z)*3.6
		if speed>=60 and time_to_60<0: time_to_60 = float(i+1)/60
		if i==479: speed_at_8 = speed
		min_upright = minf(min_upright,car.global_basis.y.dot(basis.y))
		rollback = minf(rollback,(car.position-start).dot(basis.z))
	Input.action_release("forward")
	var result := {"grade":grade,"low":low,"time_to_60":time_to_60,"speed_at_8":speed_at_8,"end_speed":car.linear_velocity.length()*3.6,"distance":(car.position-start).dot(basis.z),"min_upright":min_upright,"rollback":rollback}
	var brake_start: Vector3 = car.position
	var brake_time := 4.0
	Input.action_press("brake")
	for i in range(240):
		await physics_frame
		if car.linear_velocity.length()*3.6<1:
			brake_time = float(i+1)/60
			break
	Input.action_release("brake")
	result["brake_time"] = brake_time
	result["brake_distance"] = car.position.distance_to(brake_start)
	result["braked_speed"] = car.linear_velocity.length()*3.6
	arena.queue_free()
	await frames(3)
	return result
func run() -> void:
	for model in ["Wrangler","Rubicon"]:
		for setup in [[0.0,false],[0.18,false],[0.30,true]]:
			var result := await measure("res://cars/%s.tscn" % model,setup[0],setup[1])
			print("POWER ",model," ",JSON.stringify(result))
			if setup[0]==0:
				check(result.time_to_60>0 and result.time_to_60<6.5,model+" reaches 60 km/h within 6.5 seconds")
				check(result.speed_at_8>75,model+" sustains useful road acceleration")
				check(result.braked_speed<1 and result.brake_time<4 and result.brake_distance<60,model+" brakes from road speed within 4 seconds and 60 metres")
			elif not setup[1]:
				check(result.speed_at_8>40,model+" pulls up an 18 percent grade in high range")
			else:
				check(result.speed_at_8>17 and result.end_speed<37,model+" low range climbs 30 percent at controlled speed")
			check(result.rollback> -0.7,model+" uphill start has no prolonged rollback")
			check(result.min_upright>0.9,model+" remains stable under full throttle")
	print("RESULT: ",failures," failures")
	quit(1 if failures else 0)
