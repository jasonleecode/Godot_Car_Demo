extends Node3D
## Deterministic landscape shared by the playable world and its scene-selection preview.
const EXTENT := 160.0
const ROUTE = [Vector2(0,-72), Vector2(0,-42), Vector2(12,-14), Vector2(25,22), Vector2(-12,51), Vector2(-48,27), Vector2(-59,-9), Vector2(-32,-48), Vector2(0,-72)]
const POOLS = [
	{"center": Vector2(0,-42), "radius": Vector2(8,7)},
	{"center": Vector2(-48,27), "radius": Vector2(12,8)},
	{"center": Vector2(61,48), "radius": Vector2(13,9)}
]
@export var preview_mode := false
var tree_positions: Array[Vector3] = []
var terrain_body: StaticBody3D
var terrain_mesh: ArrayMesh
var water_material: ShaderMaterial
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.seed = 728451
	build_ground()
	build_water()
	build_forest()
	build_rocks()
	if not preview_mode:
		build_signs()

static func base_height(x: float, z: float) -> float:
	var h := 0.8 + sin(x*0.027)*1.4 + cos(z*0.034)*0.8
	for hill in [Vector4(27,22,13,25),Vector4(-30,60,17,29),Vector4(70,90,27,33),Vector4(-92,-57,25,36),Vector4(100,-35,20,31),Vector4(-108,100,34,37)]:
		var d := Vector2(x-hill.x,z-hill.y).length_squared()
		h += hill.z*exp(-d/(hill.w*hill.w))
	# Surrounding ridges frame the valley, with gentler terrain in the central driving loop.
	h += pow(clampf((Vector2(x,z).length()-108.0)/65.0,0,1),2)*24
	return h

static func route_distance(p: Vector2) -> float:
	var closest := 10000.0
	for i in range(ROUTE.size()-1):
		var a: Vector2 = ROUTE[i]
		var b: Vector2 = ROUTE[i+1]
		var t := clampf((p-a).dot(b-a)/(b-a).length_squared(),0,1)
		closest = minf(closest,p.distance_to(a+(b-a)*t))
	return closest

static func pool_distance(p: Vector2, pool: Dictionary) -> float:
	return ((p-pool.center)/pool.radius).length()

static func pool_level(pool: Dictionary) -> float:
	return base_height(pool.center.x,pool.center.y)-0.12

static func height_at(x: float, z: float) -> float:
	var p := Vector2(x,z)
	var path := route_distance(p)
	var rough := (sin(x*0.68+z*0.11)*cos(z*0.51)+sin(z*1.2+x*0.43)*0.3)*0.16
	var h := base_height(x,z)+rough*lerpf(0.25,1.0,smoothstep(3.0,7.0,path))
	for pool in POOLS:
		var r := pool_distance(p,pool)
		if r<2.1:
			var basin := pool_level(pool)-0.48+pow(minf(r,1.3),3)*0.65
			h = lerpf(basin,h,smoothstep(1.0,2.1,r))
	# A smooth, level clearing makes spawning safe for both vehicle types.
	var clearing := p.distance_to(Vector2(0,-72))
	return lerpf(base_height(0,-72),h,smoothstep(5,11,clearing))

static func water_at(p: Vector3) -> float:
	for pool in POOLS:
		if pool_distance(Vector2(p.x,p.z),pool)<1.0:
			var level := pool_level(pool)
			if height_at(p.x,p.z)<level:
				return level
	return -1000.0

func ground_color(p: Vector3) -> Color:
	var distance := route_distance(Vector2(p.x,p.z))
	var green := Color("778652").lerp(Color("98a46a"),clampf(p.y/25.0,0,1))
	var variation := sin(p.x*0.21+p.z*0.38)*0.035
	green += Color(variation,variation,variation,0)
	if p.y>21:
		green = green.lerp(Color("8e907e"),clampf((p.y-21)/20,0,0.8))
	var dirt := Color("b19b71")
	if absf(distance-1.05)<0.35:
		dirt = Color("97825d")
	green = green.lerp(dirt,1-smoothstep(2.8,4.7,distance))
	for pool in POOLS:
		var r := pool_distance(Vector2(p.x,p.z),pool)
		if r<1.4:
			green = green.lerp(Color("77694a"),1-smoothstep(0.95,1.4,r))
	return green

func build_ground() -> void:
	var step := 5.0 if preview_mode else 2.0
	var count := int(EXTENT*2/step)
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for z in range(count+1):
		for x in range(count+1):
			var px := -EXTENT+x*step
			var pz := -EXTENT+z*step
			var p := Vector3(px,height_at(px,pz),pz)
			vertices.append(p)
			colors.append(ground_color(p))
			normals.append(Vector3(height_at(px-0.3,pz)-height_at(px+0.3,pz),0.6,height_at(px,pz-0.3)-height_at(px,pz+0.3)).normalized())
	for z in range(count):
		for x in range(count):
			var a := z*(count+1)+x
			indices.append_array(PackedInt32Array([a,a+1,a+count+1,a+1,a+count+2,a+count+1]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	terrain_mesh = ArrayMesh.new()
	terrain_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.95
	terrain_mesh.surface_set_material(0,material)
	var mesh := MeshInstance3D.new()
	mesh.name = "RollingHills"
	mesh.mesh = terrain_mesh
	add_child(mesh)
	if not preview_mode:
		terrain_body = StaticBody3D.new()
		terrain_body.name = "TerrainCollision"
		add_child(terrain_body)
		var collision := CollisionShape3D.new()
		collision.shape = terrain_mesh.create_trimesh_shape()
		terrain_body.add_child(collision)

func build_water() -> void:
	water_material = ShaderMaterial.new()
	water_material.shader = preload("res://Scenes/offroad/Water.gdshader")
	for i in range(POOLS.size()):
		var pool: Dictionary = POOLS[i]
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for j in range(64):
			for p in [Vector3.ZERO,Vector3(cos(TAU*(j+1)/64)*pool.radius.x,0,sin(TAU*(j+1)/64)*pool.radius.y),Vector3(cos(TAU*j/64)*pool.radius.x,0,sin(TAU*j/64)*pool.radius.y)]:
				surface.set_normal(Vector3.UP)
				surface.add_vertex(p)
		var water := MeshInstance3D.new()
		water.name = "Puddle_%d" % i
		water.mesh = surface.commit()
		water.material_override = water_material
		water.position = Vector3(pool.center.x,pool_level(pool),pool.center.y)
		add_child(water)

func material(color: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color)
	m.roughness = 0.9
	return m

func instances(mesh: Mesh, transforms: Array[Transform3D], mat: Material) -> void:
	var batch := MultiMeshInstance3D.new()
	batch.multimesh = MultiMesh.new()
	batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	batch.multimesh.mesh = mesh
	batch.multimesh.instance_count = transforms.size()
	batch.material_override = mat
	for i in range(transforms.size()):
		batch.multimesh.set_instance_transform(i,transforms[i])
	add_child(batch)

func build_forest() -> void:
	var trunks: Array[Transform3D] = []
	var crowns: Array[Transform3D] = []
	var tree_collision := StaticBody3D.new()
	tree_collision.name = "TreeTrunks"
	if not preview_mode:
		add_child(tree_collision)
	var collision_shape := CylinderShape3D.new()
	collision_shape.radius = 0.28
	collision_shape.height = 3.6
	for i in range(520):
		var p := Vector2(rng.randf_range(-145,145),rng.randf_range(-145,145))
		if p.length()>150 or route_distance(p)<6.5 or p.distance_to(Vector2(0,-72))<12:
			continue
		var near_water := false
		for pool in POOLS:
			if pool_distance(p,pool)<1.55:
				near_water = true
		if near_water:
			continue
		var h := height_at(p.x,p.y)
		var scale_y := rng.randf_range(0.8,1.5)
		var pos := Vector3(p.x,h,p.y)
		tree_positions.append(pos)
		var basis := Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*scale_y)
		trunks.append(Transform3D(basis,pos+Vector3.UP*1.6*scale_y))
		crowns.append(Transform3D(basis,pos))
		if not preview_mode:
			var collider := CollisionShape3D.new()
			collider.shape = collision_shape
			collider.position = pos+Vector3.UP*1.8
			tree_collision.add_child(collider)
	if preview_mode:
		tree_collision.free()
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.13
	trunk.bottom_radius = 0.26
	trunk.height = 3.2
	trunk.radial_segments = 7
	instances(trunk,trunks,material("64533c"))
	for layer in range(3):
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 1.9-layer*0.42
		cone.height = 3.6-layer*0.4
		cone.radial_segments = 7
		var transforms: Array[Transform3D] = []
		for t in crowns:
			transforms.append(Transform3D(t.basis,t.origin+t.basis*Vector3(0,3.4+layer*1.3,0)))
		instances(cone,transforms,material(["405c46","526d4b","638055"][layer]))

func build_rocks() -> void:
	var transforms: Array[Transform3D] = []
	var bodies := StaticBody3D.new()
	bodies.name = "RockCollisions"
	if not preview_mode:
		add_child(bodies)
	var shape := SphereShape3D.new()
	shape.radius = 0.7
	for i in range(110):
		var p := Vector2(rng.randf_range(-130,130),rng.randf_range(-120,135))
		if route_distance(p)<5 or water_at(Vector3(p.x,0,p.y))> -900:
			continue
		var pos := Vector3(p.x,height_at(p.x,p.y),p.y)
		var scale_x := rng.randf_range(0.65,1.6)
		transforms.append(Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3(scale_x,0.8,1)),pos))
		if not preview_mode:
			var collider := CollisionShape3D.new()
			collider.shape = shape
			collider.position = pos
			bodies.add_child(collider)
	if preview_mode:
		bodies.free()
	var stone := SphereMesh.new()
	stone.radius = 0.9
	stone.height = 1.6
	stone.radial_segments = 7
	stone.rings = 3
	instances(stone,transforms,material("96958a"))

func build_signs() -> void:
	for info in [{"p":Vector2(-5,-65),"text":"松林山谷\nPINE VALLEY\n↑ 涉水路段 / 山丘环线"},{"p":Vector2(6,-51),"text":"浅水坑\n低速通过  ·  R 切换 4L"},{"p":Vector2(19,-5),"text":"山丘环线\n↑ 沿土路攀爬"}]:
		var pos := Vector3(info.p.x,height_at(info.p.x,info.p.y),info.p.y)
		var pole := MeshInstance3D.new()
		var pole_mesh := CylinderMesh.new()
		pole_mesh.top_radius = 0.08
		pole_mesh.bottom_radius = 0.08
		pole_mesh.height = 2.6
		pole.mesh = pole_mesh
		pole.material_override = material("67543b")
		pole.position = pos+Vector3.UP*1.3
		add_child(pole)
		var board := MeshInstance3D.new()
		var board_mesh := BoxMesh.new()
		board_mesh.size = Vector3(3.8,1.25,0.12)
		board.mesh = board_mesh
		board.material_override = material("344d3f")
		board.position = pos+Vector3.UP*2.4
		add_child(board)
		var text := Label3D.new()
		text.text = info.text
		text.font_size = 42
		text.pixel_size = 0.007
		text.outline_size = 0
		text.modulate = Color("f0e8cf")
		text.position = pos+Vector3(0,2.4,-0.075)
		text.rotation.y = PI
		add_child(text)
