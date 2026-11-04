extends Camera3D

## Shared camera for every vehicle and location. Vehicle forward is local +Z.
enum View { REAR, SIDE, DRIVER, TOP }
const VIEW_NAMES := ["后视", "侧视", "第一视角", "俯视"]
const EYES := [Vector3(0.40,1.18,0.0), Vector3(0.39,1.50,0.05), Vector3(0.42,1.30,-0.12)]
var vehicle: RigidBody3D
var ground_height: Callable
var eye := Vector3.ZERO
var view := View.REAR
var yaw := 0.0
var pitch := 0.0
var distance := 8.3
var shown_yaw := 0.0
var shown_pitch := 0.0
var shown_distance := 8.3
var target := Vector3.ZERO
var drag_button := MOUSE_BUTTON_NONE
var saved_cursor := Vector2.ZERO
var saved_mouse_mode := Input.MOUSE_MODE_VISIBLE

func configure(car: RigidBody3D, vehicle_index: int, height_query: Callable) -> void:
	vehicle = car
	eye = EYES[vehicle_index]
	ground_height = height_query
	near = 0.04
	far = 1500
	current = true
	reset_view()

func cycle_view() -> void:
	view = (view+1)%VIEW_NAMES.size() as View
	reset_view()

func reset_view() -> void:
	end_drag()
	fov = 75 if view == View.DRIVER else 60
	yaw = PI/2 if view == View.SIDE else 0.0
	pitch = deg_to_rad(18)
	distance = 8.3
	if view == View.SIDE:
		pitch = deg_to_rad(10)
		distance = 7.0
	elif view == View.DRIVER:
		pitch = 0
	elif view == View.TOP:
		pitch = deg_to_rad(85)
		distance = 12.0
	update_camera(0,true)

func update_camera(delta: float, snap := false) -> void:
	if not is_instance_valid(vehicle):
		return
	var blend := 1.0 if snap else 1-exp(-16*delta)
	shown_yaw = lerp_angle(shown_yaw,yaw,blend)
	shown_pitch = lerpf(shown_pitch,pitch,blend)
	shown_distance = lerpf(shown_distance,distance,blend)
	if view == View.DRIVER:
		# Stay attached to the cockpit even when the suspension pitches or rolls.
		global_position = vehicle.to_global(eye)
		var direction := Vector3(sin(shown_yaw)*cos(shown_pitch),sin(shown_pitch),cos(shown_yaw)*cos(shown_pitch))
		look_at(global_position+vehicle.global_basis*direction,vehicle.global_basis.y)
		return
	var forward := vehicle.global_basis.z
	var heading := atan2(forward.x,forward.z)
	var offset := Vector3(sin(shown_yaw)*cos(shown_pitch),sin(shown_pitch),-cos(shown_yaw)*cos(shown_pitch))
	# Keep close inspection outside the body, including long front/rear overhangs.
	var bounds := Vector3(1.2,1.2,2.85)
	var exit_distance := INF
	for axis in range(3):
		if absf(offset[axis])>0.001:
			exit_distance = minf(exit_distance,bounds[axis]/absf(offset[axis]))
	var follow := vehicle.global_position+Vector3.UP
	target = follow if snap else target.lerp(follow,1-exp(-12*delta))
	var desired := target+Basis(Vector3.UP,heading)*offset*maxf(shown_distance,exit_distance+0.25)
	desired.y = maxf(desired.y,float(ground_height.call(desired.x,desired.z))+0.5)
	var ray := PhysicsRayQueryParameters3D.create(target,desired,1,[vehicle.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	global_position = desired if hit.is_empty() else hit.position+hit.normal*0.3
	if global_position.distance_squared_to(target)>0.001:
		look_at(target,Vector3.UP)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT] and drag_button == MOUSE_BUTTON_NONE:
			drag_button = event.button_index
			saved_cursor = get_viewport().get_mouse_position()
			saved_mouse_mode = Input.mouse_mode
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled()
		elif event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			var step := -1.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0
			if view == View.DRIVER:
				fov = clampf(fov+step*4,45,90)
			else:
				distance = clampf(distance*pow(1.12,step),1.6,24)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and drag_button != MOUSE_BUTTON_NONE:
		# screen_relative keeps sensitivity independent of window stretch scaling.
		var motion: Vector2 = event.screen_relative
		yaw -= motion.x*0.005
		if view == View.DRIVER:
			yaw = clampf(yaw,deg_to_rad(-105),deg_to_rad(105))
			pitch = clampf(pitch-motion.y*0.004,deg_to_rad(-65),deg_to_rad(65))
		else:
			pitch = clampf(pitch+motion.y*0.004,deg_to_rad(-10),deg_to_rad(85))
		get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	# Release even over a HUD control, which may consume its GUI event.
	if event is InputEventMouseButton and not event.pressed and event.button_index == drag_button:
		end_drag()

func end_drag() -> void:
	if drag_button == MOUSE_BUTTON_NONE:
		return
	drag_button = MOUSE_BUTTON_NONE
	Input.mouse_mode = saved_mouse_mode
	if is_inside_tree() and saved_mouse_mode == Input.MOUSE_MODE_VISIBLE:
		get_viewport().warp_mouse(saved_cursor)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		end_drag()

func _exit_tree() -> void:
	end_drag()
