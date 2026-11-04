extends "res://cars/OffroadCar.gd"
## quattro touring wagon; no low-range transfer gearbox.
var terrain_mode := false
func _ready() -> void:
	wheel_radius = 0.35785
	allow_low_range = false
	wheel_mounts.assign(preload("res://cars/AllroadVisual.gd").MOUNTS)
	add_collision(Vector3(1.77,0.34,4.55),Vector3(0,0.23,0.025))
	add_collision(Vector3(1.47,0.47,2.02),Vector3(0,0.84,-0.69))
	add_collision(Vector3(1.70,0.16,1.25),Vector3(0,0.51,1.65))
	add_collision(Vector3(1.79,0.22,0.24),Vector3(0,0.04,2.38))
	add_collision(Vector3(1.77,0.22,0.23),Vector3(0,0.05,-2.31))

func _physics_process(delta: float) -> void:
	if input_enabled and Input.is_action_just_pressed("gear"):
		terrain_mode = not terrain_mode
		anti_roll_rate = 2800.0 if terrain_mode else 4800.0
		compression_damping = 2600.0 if terrain_mode else 3300.0
		rebound_damping = 3900.0 if terrain_mode else 4600.0
		high_range_speed = 24.0 if terrain_mode else 52.0
	super._physics_process(delta)

func drive_label() -> String:
	return "quattro · 全地形" if terrain_mode else "quattro · 舒适"
func drive_indicator() -> String:
	return "quattro / ALLROAD" if terrain_mode else "quattro"
func gear_help() -> String:
	return "舒适 / 全地形"
