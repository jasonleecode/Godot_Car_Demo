extends "res://Scripts/World.gd"
const Coast = preload("res://Scenes/coastal/CoastalTerrain.gd")
const CoastalHUD = preload("res://Scenes/coastal/CoastalHUD.gd")
var coastal_hud: CoastalHUD
var terrain: Node3D
var route_label: Label
var safe_angle := Coast.SPAWN_ANGLE

func _ready() -> void:
	terrain = Coast.new()
	terrain.name = "Coastline"
	add_child(terrain)
	build_environment()
	spawn = road_spawn(Coast.SPAWN_ANGLE)
	super._ready()
	camera.far = 6000
	var layer := CanvasLayer.new()
	add_child(layer)
	route_label = Label.new()
	route_label.position = Vector2(36,360)
	route_label.add_theme_font_size_override("font_size",22)
	route_label.add_theme_color_override("font_color",Color("fff4d6"))
	route_label.add_theme_color_override("font_shadow_color",Color("1c3540"))
	route_label.add_theme_constant_override("shadow_offset_x",2)
	route_label.add_theme_constant_override("shadow_offset_y",2)
	layer.add_child(route_label)

func build_hud() -> void:
	super.build_hud()
	# Keep the shared driving controls, replacing only the coastal corner instruments.
	speed_label.hide()
	gear_label.hide()
	if suspension_panel:
		suspension_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		suspension_panel.position += Vector2(-250,35)
	var instruments := CanvasLayer.new()
	instruments.name = "CoastalInstruments"
	add_child(instruments)
	coastal_hud = CoastalHUD.new()
	coastal_hud.name = "MapAndSpeedometer"
	instruments.add_child(coastal_hud)
	coastal_hud.configure(car,terrain.road_length)

func build_environment() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	environment.environment = env
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ShaderMaterial.new()
	sky_material.shader = preload("res://Scenes/coastal/CoastalSky.gdshader")
	sky.sky_material = sky_material
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c6dbe5")
	env.ambient_light_energy = 0.52
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.ssao_enabled = true
	env.ssao_radius = 1.5
	env.ssao_intensity = 1.2
	env.fog_enabled = true
	env.fog_light_color = Color("a6cbd9")
	env.fog_density = 0.00012
	env.fog_sky_affect = 0.05
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42,-48,0)
	sun.light_color = Color("fff4d9")
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 220
	add_child(sun)

func road_spawn(angle: float) -> Transform3D:
	var forward := Coast.road_forward(angle)
	var point := Coast.road_point(angle)-Coast.road_outward(angle)*2.5+Vector3.UP*1.0
	return Transform3D(Basis(Vector3.UP,atan2(forward.x,forward.z)),point)

func get_camera_ground_height(x: float, z: float) -> float:
	return maxf(0,Coast.height_at(x,z))

func get_surface_grip(point: Vector3) -> float:
	return 1.0 if absf(Coast.road_distance(point.x,point.z))<6 else 0.75

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not is_instance_valid(car):
		return
	var distance := Coast.road_distance(car.position.x,car.position.z)
	if absf(distance)<4.7 and car.global_basis.y.y>0.65 and car.position.y>1:
		safe_angle = Coast.closest_angle(car.position.x,car.position.z)
	route_label.text = "滨海道路  ·  %.2f km 环线  ·  崂山印象 · 山海慢行" % (terrain.road_length/1000)
	# The sea is scenery, not a drivable plane. Recover to the last safe road section.
	if car.position.y<0.25 or maxf(absf(car.position.x),absf(car.position.z))>Coast.EXTENT-5:
		var initial_spawn := spawn
		spawn = road_spawn(safe_angle)
		super.reset_car()
		spawn = initial_spawn
	coastal_hud.update_telemetry(delta)

func reset_car() -> void:
	safe_angle = Coast.SPAWN_ANGLE
	super.reset_car()
