extends "res://cars/OffroadCar.gd"
## JB74 three-door dimensions. Tune dynamics for its much lighter body.
func _ready() -> void:
	wheel_radius = 0.3465 # 195/80 R15: (381 + 2*156) / 2000.
	wheel_mounts.assign(preload("res://cars/JimnyVisual.gd").MOUNTS)
	add_collision(Vector3(1.43,0.35,2.93),Vector3(0,0.24,-0.02))
	add_collision(Vector3(1.39,0.82,1.96),Vector3(0,0.87,-0.58))
	add_collision(Vector3(1.38,0.27,0.98),Vector3(0,0.57,1.05))
	add_collision(Vector3(1.61,0.25,0.24),Vector3(0,0.20,1.66))
	add_collision(Vector3(1.61,0.23,0.22),Vector3(0,0.19,-1.58))
