extends "res://cars/OffroadCar.gd"

func _ready() -> void:
	# Dimensions are separate from the stylized vehicle: 3.008 m wheelbase, 35-inch tires.
	wheel_radius = 0.4445
	wheel_mounts = [Vector3(0.875,0.42,1.504),Vector3(-0.875,0.42,1.504),Vector3(0.875,0.42,-1.504),Vector3(-0.875,0.42,-1.504)]
	add_collision(Vector3(1.65,0.40,3.92),Vector3(0,0.34,-0.03))
	add_collision(Vector3(1.61,0.87,2.52),Vector3(0,0.96,-0.78))
	add_collision(Vector3(1.48,0.27,1.33),Vector3(0,0.79,1.38))
	add_collision(Vector3(1.95,0.22,0.26),Vector3(0,0.32,2.20))
	add_collision(Vector3(1.88,0.20,0.25),Vector3(0,0.29,-2.18))
