extends Node3D

const VehicleCamera = preload("res://Scripts/VehicleCamera.gd")

var car: RigidBody3D
var spawn := Transform3D(Basis(Vector3.UP,PI+0.28),Vector3(5.58,0.9,4.54))
var camera: VehicleCamera
var camera_label: Label
var speed_label: Label
var gear_label: Label
var suspension_label: Label
var suspension_panel: VBoxContainer
var suspension_bars: Array[ProgressBar] = []

func _ready() -> void:
	car = load(Garage.VEHICLES[Garage.selected].scene).instantiate()
	car.name = "PlayerCar"
	car.transform = spawn
	add_child(car)
	var old_camera := car.get_node_or_null("look/Camera3D")
	if old_camera:
		old_camera.set_physics_process(false)
		old_camera.current = false
	camera = VehicleCamera.new()
	camera.name = "VehicleCamera"
	add_child(camera)
	camera.configure(car,Garage.selected,get_camera_ground_height)
	build_hud()

func build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	var hud_theme := Theme.new()
	hud_theme.set_color("font_shadow_color","Label",Color(0.06,0.1,0.08,0.85))
	hud_theme.set_constant("shadow_offset_x","Label",2)
	hud_theme.set_constant("shadow_offset_y","Label",2)
	root.theme = hud_theme
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	var panel := PanelContainer.new()
	panel.position = Vector2(36,30)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.065,0.09,0.08,0.88)
	style.set_corner_radius_all(12)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel",style)
	root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation",8)
	panel.add_child(v)
	var title := Label.new()
	title.text = Garage.VEHICLES[Garage.selected].name+"  /  "+Garage.LOCATIONS[Garage.selected_location].name
	title.add_theme_font_size_override("font_size",26)
	v.add_child(title)
	var help := Label.new()
	help.text = "WASD / 方向键  驾驶    SPACE  刹车\nESC  复位    R  %s    G  选车 / 场景\n鼠标左 / 右键拖拽  旋转    滚轮  缩放" % ("高低速四驱" if car.has_method("reset_suspension") else "换挡")
	help.add_theme_font_size_override("font_size",19)
	help.add_theme_color_override("font_color",Color("bcc8b7"))
	v.add_child(help)
	camera_label = Label.new()
	camera_label.add_theme_font_size_override("font_size",19)
	v.add_child(camera_label)
	var button := Button.new()
	button.text = "选车 / 场景  ↗"
	button.add_theme_font_size_override("font_size",18)
	button.pressed.connect(Garage.open_garage)
	v.add_child(button)
	speed_label = Label.new()
	root.add_child(speed_label)
	speed_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	speed_label.position -= Vector2(270,150)
	speed_label.add_theme_font_size_override("font_size",58)
	gear_label = Label.new()
	root.add_child(gear_label)
	gear_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	gear_label.position -= Vector2(270,75)
	gear_label.add_theme_font_size_override("font_size",23)
	if car.has_method("reset_suspension"):
		var suspension := VBoxContainer.new()
		suspension_panel = suspension
		root.add_child(suspension)
		suspension.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
		suspension.position += Vector2(40,-190)
		suspension_label = Label.new()
		suspension_label.text = "悬挂行程 / WHEEL TRAVEL"
		suspension_label.add_theme_font_size_override("font_size",20)
		suspension.add_child(suspension_label)
		for label in ["前左", "前右", "后左", "后右"]:
			var row := HBoxContainer.new()
			suspension.add_child(row)
			var name_label := Label.new()
			name_label.text = label
			name_label.add_theme_font_size_override("font_size",18)
			row.add_child(name_label)
			var bar := ProgressBar.new()
			bar.custom_minimum_size = Vector2(150,12)
			bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			bar.show_percentage = false
			row.add_child(bar)
			suspension_bars.append(bar)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(car):
		return
	speed_label.text = "%02d km/h" % roundi(car.linear_velocity.length()*3.6)
	if car.has_method("reset_suspension"):
		gear_label.text = "4L · 低速攀爬" if car.low_range else "4H · 全地形"
		for i in range(4):
			suspension_bars[i].value = clampf((0.69-float(car.lengths[i]))/(0.69-car.suspension_min_length)*100,0,100)
			suspension_bars[i].modulate = Color("dbc38e") if car.contacts[i] else Color("758079")
	else:
		gear_label.text = "RWD · 挡位 %d" % car.gearshift
	if camera:
		camera.update_camera(delta)
		camera_label.text = "V  切换视角：%s    C  还原视角" % camera.VIEW_NAMES[camera.view]
	if car.global_position.y < -20:
		reset_car()

func get_camera_ground_height(_x: float, _z: float) -> float:
	return -INF

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reset"):
		reset_car()
	elif event.is_action_pressed("camera_next"):
		camera.cycle_view()
	elif event.is_action_pressed("camera_reset"):
		camera.reset_view()
	elif event.is_action_pressed("garage"):
		Garage.open_garage()

func reset_car() -> void:
	car.global_transform = spawn
	car.linear_velocity = Vector3.ZERO
	car.angular_velocity = Vector3.ZERO
	car.sleeping = false
	if car.has_method("reset_suspension"):
		car.reset_suspension()
	if camera:
		camera.reset_view()
