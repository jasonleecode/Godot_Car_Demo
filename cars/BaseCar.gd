extends VehicleBody3D
class_name BaseCar

@export var STEER_SPEED = 1.5
@export var STEER_LIMIT = 0.6
var steer_target = 0
@export var engine_force_value = 40

var gearshift = 3
var gear_multiplicator = 1
var gear_locked = false

var fwd_mps : float
var speed: float


func _physics_process(delta):
	speed = linear_velocity.length()
	fwd_mps = linear_velocity.dot(global_transform.basis.z)
	traction(speed)
	process_gear_shift()
	process_accel(delta)
	process_steer(delta)
	process_brake(delta)

func process_accel(delta):
	var accel = Input.get_action_strength("forward")
	var reverse = Input.get_action_strength("backward")

	if accel > 0:
		# Increase engine force at low speeds to make the initial acceleration faster.
		if speed < 30 and speed != 0:
			engine_force = clamp(engine_force_value * 10 / speed, 0, 300)
		else:
			engine_force = engine_force_value
		engine_force = engine_force * gear_multiplicator * accel
		return

	if reverse > 0:
		# Increase engine force at low speeds to make the initial acceleration faster.
		if speed < 20 and speed != 0:
			engine_force = -clamp(engine_force_value * 3 / speed, 0, 300)
		else:
			engine_force = -engine_force_value
		engine_force = engine_force * reverse
		return
	engine_force = 0
	brake = 0

func process_gear_shift():
	# Gear shift for driving faster!
	if Input.is_action_pressed("gear"):
		if gear_locked == false:
			gear_locked = true
			gearshift +=1
			if gearshift == 6: gearshift = 1
			if gearshift == 1: gear_multiplicator = 0.3
			elif gearshift == 2: gear_multiplicator = 0.7
			elif gearshift == 3: gear_multiplicator = 1
			elif gearshift == 4: gear_multiplicator = 1.3
			elif gearshift == 5: gear_multiplicator = 1.8
			await get_tree().create_timer(1.0).timeout
			gear_locked = false

func process_steer(delta):
	steer_target = Input.get_action_strength("left") - Input.get_action_strength("right")
	steer_target *= STEER_LIMIT
	steering = move_toward(steering, steer_target, STEER_SPEED * delta)

func process_brake(delta):
	if Input.is_action_pressed("brake"):
		brake=0.5
		$wheel_rear_left.wheel_friction_slip=2
		$wheel_rear_right.wheel_friction_slip=2
	else:
		brake = 0
		$wheel_rear_left.wheel_friction_slip=2.9
		$wheel_rear_right.wheel_friction_slip=2.9


func traction(speed):
	apply_central_force(Vector3.DOWN*speed)
