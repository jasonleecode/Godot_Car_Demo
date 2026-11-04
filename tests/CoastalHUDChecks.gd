extends SceneTree
const Coast = preload("res://Scenes/coastal/CoastalTerrain.gd")
var failures := 0
func _initialize() -> void:
	run.call_deferred()
func frames(n := 2) -> void:
	for i in range(n): await physics_frame
func check(ok: bool, message: String) -> void:
	if ok: print("PASS: ",message)
	else:
		push_error("FAIL: "+message)
		failures += 1
func run() -> void:
	root.get_node("Garage").drive(2,2)
	await frames(180)
	var world = current_scene
	var hud = world.coastal_hud
	var car = world.car
	world.set_physics_process(false)
	car.freeze = true
	check(not world.speed_label.visible and not world.gear_label.visible,"coastal dial replaces original speed readout")
	check(hud.mouse_filter==Control.MOUSE_FILTER_IGNORE,"instruments allow mouse camera interaction")
	check(world.suspension_panel.anchor_top==0 and world.suspension_panel.anchor_right==1,"suspension panel is moved to top right")
	check(hud.route.size()==257,"minimap uses continuous actual coastal route")
	for angle in [0.0,1.5,3.0,4.5]:
		car.position = Coast.road_point(angle)
		var forward := Coast.road_forward(angle)
		car.rotation.y = atan2(forward.x,forward.z)
		hud.update_telemetry(0,true)
		check(hud.marker_position.distance_to(hud.project_position(car.position))<0.01,"map marker follows position around the loop")
		check(hud.marker_direction.dot(Vector2(forward.x,forward.z))>0.999,"map arrow follows vehicle heading")
	car.linear_velocity = car.global_basis.z*20
	hud.update_telemetry(0,true)
	check(is_equal_approx(hud.speed_kph,72.0) and is_equal_approx(hud.needle_kph,72.0),"20 metres per second displays 72 km/h")
	check(hud.drive_mode=="D  ·  4H","forward high range is displayed")
	car.low_range = true
	car.linear_velocity = -car.global_basis.z*5
	hud.update_telemetry(0,true)
	check(hud.drive_mode=="R  ·  4L" and is_equal_approx(hud.speed_kph,18),"reverse and low range are displayed with positive speed")
	car.linear_velocity = Vector3.ZERO
	hud.update_telemetry(0,true)
	check(hud.speed_kph==0 and hud.needle_kph==0,"stopping returns dial and readout to zero")
	car.position = Vector3(2000,0,2000)
	hud.update_telemetry(0,true)
	check(hud.marker_position.distance_to(hud.map_center)<=hud.MAP_RADIUS-11.9,"off-map marker remains inside circular map")
	var old_center: Vector2 = hud.dial_center
	hud.size += Vector2(400,200)
	hud.update_layout()
	check(hud.dial_center.is_equal_approx(old_center+Vector2(400,200)),"dial follows bottom-right edge on resize")
	check(hud.map_center.y==hud.size.y-199,"map follows bottom-left edge on resize")
	root.get_node("Garage").drive(0,2)
	await frames(120)
	world = current_scene
	world.set_physics_process(false)
	world.car.freeze = true
	world.car.gearshift = 4
	world.car.linear_velocity = world.car.global_basis.z*10
	world.coastal_hud.update_telemetry(0,true)
	check(world.coastal_hud.drive_mode=="D  ·  4 挡","sedan displays its actual selected gear")
	root.get_node("Garage").drive(1,1)
	await frames(120)
	check(current_scene.speed_label.visible and current_scene.gear_label.visible,"prototype retains its original HUD")
	check(current_scene.suspension_panel.anchor_top==1,"prototype suspension stays in its original position")
	print("RESULT: ",failures," failures")
	quit(1 if failures else 0)
