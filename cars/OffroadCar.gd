extends RigidBody3D
## Four contact patches, load-limited tire forces and asymmetric spring/damper suspension.
## SI units: kg, metres, seconds, newtons. Wheel travel is independent of rendering FPS.
@export var wheel_mounts: Array[Vector3] = [Vector3(1.0,0.46,1.32),Vector3(-1.0,0.46,1.32),Vector3(1.0,0.46,-1.25),Vector3(-1.0,0.46,-1.25)]
@export var wheel_radius := 0.47
const REST := 0.55
const DROOP := 0.14
@export var suspension_min_length := 0.13
@export var bump_stop_length := 0.20
@export var spring_rate := 34000.0
@export var compression_damping := 2600.0
@export var rebound_damping := 3900.0
@export var anti_roll_rate := 2400.0
@export var tire_grip := 1.15
@export var drive_force := 9600.0
@export var input_enabled := true
var lengths: Array = [REST, REST, REST, REST]
var contacts: Array = [false, false, false, false]
var loads: Array = [0.0, 0.0, 0.0, 0.0]
var steering := 0.0
var wheel_roll := 0.0
var low_range := false
var throttle := 0.0
var speed := 0.0
var _previous: Array = [REST, REST, REST, REST]
@onready var visual: Node3D = $Visual

func _ready() -> void:
	add_collision(Vector3(1.6,0.48,3.55),Vector3(0,0.61,0))
	add_collision(Vector3(1.54,0.87,2.1),Vector3(0,1.28,-0.59))
	add_collision(Vector3(1.9,0.19,0.24),Vector3(0,0.38,1.96))
	add_collision(Vector3(1.85,0.19,0.24),Vector3(0,0.38,-1.94))

func add_collision(size: Vector3, pos: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var node := CollisionShape3D.new()
	node.shape = shape
	add_child(node)
	node.position = pos

func _physics_process(delta: float) -> void:
	if freeze:
		return
	var accel := Input.get_action_strength("forward")-Input.get_action_strength("backward") if input_enabled else 0.0
	throttle = move_toward(throttle,accel,delta*3.0)
	speed = linear_velocity.length()
	var steer_input := Input.get_action_strength("left")-Input.get_action_strength("right") if input_enabled else 0.0
	var limit := lerpf(0.53,0.20,clampf(speed/24.0,0,1))
	steering = move_toward(steering,steer_input*limit,delta*1.4)
	if input_enabled and Input.is_action_just_pressed("gear"):
		low_range = not low_range
	var handbrake := input_enabled and Input.is_action_pressed("brake")
	var up := global_basis.y.normalized()
	var forward := global_basis.z.normalized()
	var signed_speed := linear_velocity.dot(forward)
	var space := get_world_3d().direct_space_state
	for i in range(4):
		var mount: Vector3 = global_transform*wheel_mounts[i]
		var ray := PhysicsRayQueryParameters3D.create(mount,mount-up*(REST+DROOP+wheel_radius),1,[get_rid()])
		var hit := space.intersect_ray(ray)
		var was_contact: bool = contacts[i]
		contacts[i] = not hit.is_empty()
		loads[i] = 0.0
		if not contacts[i]:
			lengths[i] = move_toward(lengths[i],REST+DROOP,delta*1.8)
			_previous[i] = lengths[i]
			continue
		var point: Vector3 = hit.position
		var normal: Vector3 = hit.normal
		var length := clampf(mount.distance_to(point)-wheel_radius,suspension_min_length,REST+DROOP)
		var rate := clampf((length-float(_previous[i]))/delta,-5.0,5.0) if was_contact else 0.0
		lengths[i] = length
		_previous[i] = length
		var damping := compression_damping if rate < 0 else rebound_damping
		var spring := maxf(0.0,(REST-length)*spring_rate-rate*damping)
		# Progressive bump stops resist bottoming out on landings.
		spring += maxf(0.0,bump_stop_length-length)*90000.0
		loads[i] = clampf(spring,0,22000)
		var offset := point-global_position
		apply_force(up*loads[i],mount-global_position)
		var tire_forward := forward.rotated(up,steering if i < 2 else 0.0)
		tire_forward = tire_forward.slide(normal).normalized()
		var tire_side := normal.cross(tire_forward).normalized()
		var velocity := linear_velocity+angular_velocity.cross(offset)
		if hit.collider is RigidBody3D:
			var ground: RigidBody3D = hit.collider
			velocity -= ground.linear_velocity+ground.angular_velocity.cross(point-ground.global_position)
		var longitudinal := velocity.dot(tire_forward)
		var lateral := velocity.dot(tire_side)
		var max_speed := 10.0 if low_range else 28.0
		var torque_falloff := clampf(1.0-absf(longitudinal)/max_speed,0,1)
		var force := throttle*drive_force*0.25*torque_falloff*(1.5 if low_range else 1.0)
		# Opposite pedal first slows the vehicle, then smoothly engages reverse.
		if longitudinal*throttle < -0.7:
			force = throttle*3800
		var rolling := -longitudinal*65.0
		if absf(throttle) < 0.03:
			rolling = -longitudinal*380.0
		if handbrake:
			force = -longitudinal*2000.0
		var lateral_force := -lateral*mass*0.25/maxf(delta,0.001)*0.22
		if handbrake and i >= 2:
			lateral_force *= 0.4
		# Friction circle: an unloaded/airborne tire cannot generate full drive or cornering force.
		var tire_force := tire_forward*(force+rolling)+tire_side*lateral_force
		var surface_grip: float = get_parent().get_surface_grip(point) if get_parent().has_method("get_surface_grip") else 1.0
		tire_force = tire_force.limit_length(loads[i]*tire_grip*surface_grip)
		apply_force(tire_force,offset)
	# Modest anti-roll coupling preserves articulation on uneven ground.
	for axle in range(2):
		var a := axle*2
		var b := a+1
		if contacts[a] and contacts[b]:
			var transfer := clampf((float(lengths[b])-float(lengths[a]))*anti_roll_rate,-1800,1800)
			apply_force(up*transfer,global_basis*wheel_mounts[a])
			apply_force(-up*transfer,global_basis*wheel_mounts[b])
	apply_central_force(-linear_velocity*speed*0.45)
	wheel_roll += signed_speed/wheel_radius*delta
	visual.update_suspension(lengths,steering,wheel_roll)

func reset_suspension() -> void:
	lengths = [REST,REST,REST,REST]
	_previous = lengths.duplicate()
	contacts = [false,false,false,false]
	loads = [0.0,0.0,0.0,0.0]
	throttle = 0
	steering = 0
