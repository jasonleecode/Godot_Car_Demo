extends SceneTree
## Drive the physical Rubicon through the complete road with a simple look-ahead controller.
const Coast = preload("res://Scenes/coastal/CoastalTerrain.gd")
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	root.get_node("Garage").drive(2,0)
	for i in range(180): await physics_frame
	var world = current_scene
	var car = world.car
	var previous := Coast.SPAWN_ANGLE
	var progress := 0.0
	var max_deviation := 0.0
	var lowest_up := 1.0
	var max_height := 0.0
	var finished := false
	for frame in range(30000):
		var angle := Coast.closest_angle(car.position.x,car.position.z)
		progress += wrapf(angle-previous,-PI,PI)
		previous = angle
		var speed: float = car.linear_velocity.length()
		var derivative := (Coast.road_point(angle+0.001)-Coast.road_point(angle-0.001)).length()/0.002
		var ahead := angle+(5.0+speed*0.65)/derivative
		var target := Coast.road_point(ahead)-Coast.road_outward(ahead)*2.5
		var direction: Vector3 = target-car.position
		direction.y = 0
		var forward: Vector3 = car.global_basis.z
		forward.y = 0
		var error := forward.normalized().signed_angle_to(direction.normalized(),Vector3.UP)
		var steering := clampf(error*2.8,-1,1)
		Input.action_release("left")
		Input.action_release("right")
		if steering>0: Input.action_press("left",steering)
		else: Input.action_press("right",-steering)
		Input.action_press("forward",clampf((9.0-speed)*0.35+0.38,0,1))
		if speed>10: Input.action_press("brake")
		else: Input.action_release("brake")
		var deviation := absf(Coast.road_distance(car.position.x,car.position.z)+2.5)
		max_deviation = maxf(max_deviation,deviation)
		lowest_up = minf(lowest_up,car.global_basis.y.y)
		max_height = maxf(max_height,car.position.y)
		if frame%3000==0:
			print("LAP progress=",progress/TAU," speed=",speed," height=",car.position.y," lane error=",deviation)
		if deviation>5 or car.global_basis.y.y<0.7:
			push_error("Vehicle left its lane corridor or tipped on mountain route")
			break
		if progress>=TAU:
			finished = true
			break
		await physics_frame
	for action in ["forward","left","right","brake"]: Input.action_release(action)
	print("LAP RESULT finished=",finished," max_lane_error=",max_deviation," min_up=",lowest_up," max_height=",max_height)
	quit(0 if finished and max_height>69 and max_deviation<5 else 1)
