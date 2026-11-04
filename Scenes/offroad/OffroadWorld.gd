extends "res://Scripts/World.gd"

const Terrain = preload("res://Scenes/offroad/OffroadTerrain.gd")
var terrain: Node3D
var water_immersion := 0.0
var spray: CPUParticles3D
var terrain_status: Label
var wake_pool: Array[MeshInstance3D] = []
var wake_age: Array[float] = []
var wake_timer := 0.0
var wake_index := 0

func _ready() -> void:
	terrain = Node3D.new()
	terrain.name = "Landscape"
	terrain.set_script(Terrain)
	add_child(terrain)
	build_environment()
	spawn = Transform3D(Basis.IDENTITY,Vector3(0,Terrain.height_at(0,-72)+1.1,-72))
	super._ready()
	build_water_feedback()

func build_environment() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("769fae")
	sky_material.sky_horizon_color = Color("d9decb")
	sky_material.ground_bottom_color = Color("717a59")
	sky_material.ground_horizon_color = Color("d9decb")
	sky.sky_material = sky_material
	env.environment.background_mode = Environment.BG_SKY
	env.environment.sky = sky
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("d8e1d4")
	env.environment.ambient_light_energy = 0.55
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment.ssao_enabled = true
	env.environment.ssao_radius = 1.8
	env.environment.ssao_intensity = 1.3
	env.environment.fog_enabled = true
	env.environment.fog_light_color = Color("c1d0bd")
	env.environment.fog_density = 0.0018
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38,-38,0)
	sun.light_color = Color("fff0d1")
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 180
	add_child(sun)

func build_water_feedback() -> void:
	spray = CPUParticles3D.new()
	spray.name = "WaterSpray"
	spray.emitting = false
	spray.amount = 32
	spray.lifetime = 0.65
	spray.local_coords = false
	spray.direction = Vector3.UP
	spray.spread = 65
	spray.initial_velocity_min = 1.3
	spray.initial_velocity_max = 3.0
	spray.gravity = Vector3(0,-7,0)
	spray.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	spray.emission_box_extents = Vector3(1,0.02,1.3)
	var drop := SphereMesh.new()
	drop.radius = 0.045
	drop.height = 0.09
	drop.radial_segments = 6
	drop.rings = 3
	drop.material = terrain.material("a8ccc0")
	spray.mesh = drop
	add_child(spray)
	for i in range(16):
		var wake := MeshInstance3D.new()
		var ring := TorusMesh.new()
		ring.inner_radius = 0.91
		ring.outer_radius = 1.0
		ring.rings = 24
		ring.ring_segments = 4
		wake.mesh = ring
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.63,0.81,0.73,0.55)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		wake.material_override = mat
		wake.visible = false
		add_child(wake)
		wake_pool.append(wake)
		wake_age.append(2.0)
	var layer := CanvasLayer.new()
	add_child(layer)
	terrain_status = Label.new()
	terrain_status.position = Vector2(36,360)
	terrain_status.add_theme_font_size_override("font_size",22)
	terrain_status.add_theme_color_override("font_color",Color("fff1cd"))
	terrain_status.add_theme_color_override("font_shadow_color",Color("243d35"))
	terrain_status.add_theme_constant_override("shadow_offset_x",2)
	terrain_status.add_theme_constant_override("shadow_offset_y",2)
	layer.add_child(terrain_status)

func get_camera_ground_height(x: float, z: float) -> float:
	return Terrain.height_at(x,z)

func get_surface_grip(point: Vector3) -> float:
	var level := Terrain.water_at(point)
	return 0.68 if point.y<level+0.08 else 1.0

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not is_instance_valid(car):
		return
	var level := Terrain.water_at(car.global_position)
	water_immersion = clampf((level-(car.global_position.y-0.44))/0.42,0,1)
	if water_immersion>0:
		var horizontal := Vector3(car.linear_velocity.x,0,car.linear_velocity.z)
		# Mass-scaled drag gives both cars meaningful resistance without altering their base tune.
		car.apply_central_force(-horizontal*car.mass*1.15*water_immersion)
		terrain_status.text = "涉水中  ·  阻力增加，建议低速通过"
	else:
		terrain_status.text = "松林山谷  ·  沿土路探索水坑与山丘"
	spray.emitting = water_immersion>0.05 and car.linear_velocity.length()>0.8
	if water_immersion>0:
		spray.global_position = Vector3(car.global_position.x,level+0.06,car.global_position.z)
	wake_timer -= delta
	if water_immersion>0.05 and car.linear_velocity.length()>0.5 and wake_timer<=0:
		wake_timer = 0.18
		for side in [-1.0,1.0]:
			var p: Vector3 = car.global_position+car.global_basis.x*side*0.9
			wake_pool[wake_index].position = Vector3(p.x,level+0.04,p.z)
			wake_age[wake_index] = 0
			wake_index = (wake_index+1)%wake_pool.size()
	for i in range(wake_pool.size()):
		wake_age[i] += delta
		var age := wake_age[i]
		wake_pool[i].visible = age<1.3
		if age<1.3:
			var radius := 0.25+age*1.4
			wake_pool[i].scale = Vector3(radius,0.12,radius)
			wake_pool[i].material_override.albedo_color.a = (1-age/1.3)*0.5
	if maxf(absf(car.position.x),absf(car.position.z))>153:
		reset_car()

func reset_car() -> void:
	super.reset_car()
	water_immersion = 0
	if spray:
		spray.emitting = false
	for i in range(wake_pool.size()):
		wake_age[i] = 2.0
		wake_pool[i].visible = false
