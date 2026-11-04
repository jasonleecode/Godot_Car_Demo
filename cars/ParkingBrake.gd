extends RefCounted
## Ground-relative parking constraint. Keeps suspension heave/roll free and never holds a car in the air.
const MAX_ENGAGE_SPEED := 0.8 # m/s, about 3 km/h
var engaged := false
var anchored := false
var support: Node3D
var local_anchor := Vector3.ZERO
var previous_target := Vector3.ZERO

func contacts(body: RigidBody3D) -> Dictionary:
	var hits: Array[Dictionary] = []
	var up := body.global_basis.y.normalized()
	var space := body.get_world_3d().direct_space_state
	if body.has_method("reset_suspension"):
		for mount in body.wheel_mounts:
			var origin: Vector3 = body.global_transform*mount
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(origin,origin-up*(0.69+body.wheel_radius+0.02),1,[body.get_rid()]))
			if not hit.is_empty() and hit.normal.dot(Vector3.UP)>0.25:
				hits.append(hit)
	else:
		for wheel in body.get_children():
			if wheel is VehicleWheel3D and wheel.is_in_contact():
				var origin: Vector3 = wheel.global_position+up*0.25
				var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(origin,wheel.global_position-up*(wheel.wheel_radius+0.25),1,[body.get_rid()]))
				if not hit.is_empty() and hit.normal.dot(Vector3.UP)>0.25:
					hits.append(hit)
	if hits.size()<2:
		return {}
	var normal := Vector3.ZERO
	for hit in hits:
		normal += hit.normal
	return {"normal":normal.normalized(),"support":hits[0].collider}

func toggle(body: RigidBody3D) -> String:
	if engaged:
		engaged = false
		anchored = false
		body.sleeping = false
		return "已解除驻车"
	if body.linear_velocity.length()>MAX_ENGAGE_SPEED:
		return "请先刹停，再按 P 驻车"
	if contacts(body).is_empty():
		return "车轮着地后可挂入 P 挡"
	engaged = true
	anchored = false
	body.sleeping = false
	return "P 驻车已开启 · 再按 P 解除"

func reset_anchor() -> void:
	anchored = false

func integrate(body: RigidBody3D, state: PhysicsDirectBodyState3D) -> void:
	if not engaged:
		return
	var contact := contacts(body)
	if contact.is_empty():
		anchored = false
		return
	var normal: Vector3 = contact.normal
	if not anchored or not is_instance_valid(support) or support!=contact.support:
		support = contact.support
		local_anchor = support.to_local(state.transform.origin)
		previous_target = state.transform.origin
		anchored = true
	var target := support.to_global(local_anchor)
	var ground_velocity := (target-previous_target)/state.step
	previous_target = target
	# Lock only the contact plane: springs still settle and tyres can leave the ground.
	var pose := state.transform
	pose.origin += (target-pose.origin).slide(normal)
	state.transform = pose
	state.linear_velocity = ground_velocity+normal*(state.linear_velocity-ground_velocity).dot(normal)
	state.angular_velocity = state.angular_velocity.slide(normal)
	state.apply_central_force(-state.total_gravity.slide(normal)*body.mass)
