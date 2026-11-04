extends SceneTree
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if ok: print("PASS: ",message)
	else:
		push_error("FAIL: "+message)
		failures += 1
func run() -> void:
	for model in ["Wrangler","Rubicon","Jimny"]:
		var visual = load("res://cars/%sVisual.gd" % model).new()
		root.add_child(visual)
		for travel in [[0.42,0.42,0.42,0.42],[0.31,0.69,0.69,0.31],[0.69,0.69,0.31,0.31]]:
			visual.update_suspension(travel,0.4,2.0)
			var chassis = visual.chassis
			var connected := true
			for i in range(2):
				var axle: Node3D = chassis.axles[i]
				var a: Vector3 = axle.transform*Vector3(0,-0.5,0)
				var b: Vector3 = axle.transform*Vector3(0,0.5,0)
				connected = connected and a.distance_to(visual.wheels[i*2].position)<0.001 and b.distance_to(visual.wheels[i*2+1].position)<0.001
				var shaft: Node3D = chassis.shafts[i]
				connected = connected and (shaft.transform*Vector3(0,-0.5,0)).distance_to(chassis.joints[i*2].position)<0.001
				connected = connected and (shaft.transform*Vector3(0,0.5,0)).distance_to(chassis.joints[i*2+1].position)<0.001
			check(connected,model+" axles and propshaft joints stay attached at travel "+str(travel))
			var finite := true
			for child in chassis.get_children():
				finite = finite and child.transform.is_finite() and absf(child.basis.determinant())>0.0001
			check(finite,model+" articulated geometry has valid transforms")
		var expected_arms := 4 if model=="Jimny" else 8
		check(visual.chassis.arms.size()==expected_arms and visual.chassis.shocks.size()==4 and visual.chassis.differentials.size()==2,model+" has its own suspension layout and both differentials")
		visual.queue_free()
		await process_frame
	print("RESULT: ",failures," failures")
	quit(1 if failures else 0)
