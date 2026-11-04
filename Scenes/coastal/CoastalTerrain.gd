extends Node3D
## A continuous island road: shared geometry in the menu preview and playable scene.
const ROAD_HALF := 5.5
const SPAWN_ANGLE := -0.62
const EXTENT := 310.0
@export var preview_mode := false
var rng := RandomNumberGenerator.new()
var road_mesh: ArrayMesh
var road_length := 0.0
var tree_count := 0
var house_count := 0
var batches: Dictionary = {}
var materials: Dictionary = {}
var terrain_noise := FastNoiseLite.new()

static func road_point(angle: float) -> Vector3:
	var radius := 185.0+22.0*sin(angle*2)+12.0*sin(angle*3+0.7)
	return Vector3(radius*cos(angle),5.5+1.6*sin(angle*2-0.4)+0.8*cos(angle*3),radius*sin(angle)*0.85)

static func road_forward(angle: float) -> Vector3:
	var tangent := road_point(angle+0.001)-road_point(angle-0.001)
	tangent.y = 0
	return tangent.normalized()

static func road_outward(angle: float) -> Vector3:
	var tangent := road_forward(angle)
	return Vector3(tangent.z,0,-tangent.x)

static func closest_angle(x: float, z: float) -> float:
	var angle := atan2(z/0.85,x)
	var point := Vector3(x,0,z)
	# Project onto the smooth centerline instead of approximating distance with a circle.
	for i in range(3):
		var center := road_point(angle)
		var derivative := (road_point(angle+0.001)-road_point(angle-0.001))/0.002
		derivative.y = 0
		var difference := point-center
		difference.y = 0
		angle += difference.dot(derivative)/derivative.length_squared()
	return angle

static func road_distance(x: float, z: float) -> float:
	var angle := closest_angle(x,z)
	return (Vector3(x,0,z)-road_point(angle)).dot(road_outward(angle))

static func height_at(x: float, z: float) -> float:
	var angle := closest_angle(x,z)
	var road := road_point(angle)
	var outward := (Vector3(x,0,z)-road).dot(road_outward(angle))
	if outward>0:
		return lerpf(road.y,-1.8,smoothstep(8,40,outward))-maxf(0,outward-45)*0.035
	var inland := -outward
	var hills := 14.0+12.0*sin(x*0.019+0.4)*cos(z*0.022)+15.0*exp(-Vector2(x+30,z-30).length_squared()/6000.0)
	var rough := sin(x*0.33)*cos(z*0.27)*0.45
	return road.y+smoothstep(10,90,inland)*(hills+rough)

func _ready() -> void:
	rng.seed = 541297
	terrain_noise.seed = 926
	terrain_noise.frequency = 0.05
	build_ground()
	build_road()
	build_ocean()
	build_village()
	build_trees()
	build_mountains()
	flush_batches()

func material(key: String, color: String, metallic := 0.0, roughness := 0.8) -> StandardMaterial3D:
	if materials.has(key):
		return materials[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color)
	mat.metallic = metallic
	mat.roughness = roughness
	materials[key] = mat
	return mat

func mesh_node(mesh: Mesh, mat: Material, node_name: String, collision := false) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.material_override = mat
	add_child(node)
	if collision and not preview_mode:
		var body := StaticBody3D.new()
		body.name = node_name+"Collision"
		add_child(body)
		var shape := CollisionShape3D.new()
		shape.shape = mesh.create_trimesh_shape()
		body.add_child(shape)
	return node

func batch(key: String, mesh: Mesh, mat: Material, transform: Transform3D, color := Color.WHITE) -> void:
	if not batches.has(key):
		batches[key] = {"mesh":mesh,"material":mat,"transforms":[],"colors":[]}
	batches[key].transforms.append(transform)
	batches[key].colors.append(color)

func flush_batches() -> void:
	for key in batches:
		var data: Dictionary = batches[key]
		var instance := MultiMeshInstance3D.new()
		instance.name = key
		instance.multimesh = MultiMesh.new()
		instance.multimesh.transform_format = MultiMesh.TRANSFORM_3D
		instance.multimesh.use_colors = true
		instance.multimesh.use_custom_data = true
		instance.multimesh.mesh = data.mesh
		instance.multimesh.instance_count = data.transforms.size()
		instance.material_override = data.material
		for i in range(data.transforms.size()):
			instance.multimesh.set_instance_transform(i,data.transforms[i])
			instance.multimesh.set_instance_color(i,data.colors[i])
			instance.multimesh.set_instance_custom_data(i,data.colors[i])
		add_child(instance)
	batches.clear()

func box(key: String, size: Vector3, transform: Transform3D, mat: Material, collision := false) -> void:
	var mesh := BoxMesh.new()
	batch(key,mesh,mat,Transform3D(transform.basis.scaled_local(size),transform.origin))
	if collision and not preview_mode:
		var body := StaticBody3D.new()
		body.name = key+"Collision"
		body.transform = transform
		var shape := CollisionShape3D.new()
		var bounds := BoxShape3D.new()
		bounds.size = size
		shape.shape = bounds
		body.add_child(shape)
		add_child(body)

func ground_color(x: float, z: float, h: float) -> Color:
	var distance := road_distance(x,z)
	var variation := terrain_noise.get_noise_2d(x,z)*0.5+0.5
	var grass := Color("69884b").lerp(Color("b1b76c"),variation)
	if distance>8:
		return grass.lerp(Color("d4c99b"),smoothstep(8,27,distance))
	if absf(distance)<8:
		return Color("a9aa8c")
	return grass.lerp(Color("819063"),smoothstep(25,50,h)*0.4)

func build_ground() -> void:
	var step := 8.0 if preview_mode else 3.0
	var count := int(EXTENT*2/step)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in range(count+1):
		for x in range(count+1):
			var px := -EXTENT+x*step
			var pz := -EXTENT+z*step
			var h := height_at(px,pz)
			surface.set_color(ground_color(px,pz,h))
			surface.set_normal(Vector3(height_at(px-0.4,pz)-height_at(px+0.4,pz),0.8,height_at(px,pz-0.4)-height_at(px,pz+0.4)).normalized())
			surface.add_vertex(Vector3(px,h,pz))
	for z in range(count):
		for x in range(count):
			var a := z*(count+1)+x
			for i in [a,a+1,a+count+1,a+1,a+count+2,a+count+1]:
				surface.add_index(i)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 0.96
	mesh_node(surface.commit(),mat,"CoastalHills",true)

func ribbon(from: float, to: float, lift: float, mat: Material, node_name: String, collision := false) -> ArrayMesh:
	var count := 240 if preview_mode else 720
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(count+1):
		var angle := TAU*i/count
		var p := road_point(angle)+Vector3.UP*lift
		var normal := road_outward(angle)
		for side in [from,to]:
			surface.set_uv(Vector2(side,i*0.4))
			surface.add_vertex(p+normal*side)
	for i in range(count):
		var a := i*2
		for index in [a,a+1,a+2,a+1,a+3,a+2]:
			surface.add_index(index)
	surface.generate_normals()
	var mesh := surface.commit()
	mesh_node(mesh,mat,node_name,collision)
	return mesh

func build_road() -> void:
	var asphalt := material("asphalt","414751",0,0.97)
	# Fine generated asphalt grain; no external texture or downloaded asset is needed.
	var noise := NoiseTexture2D.new()
	noise.width = 256
	noise.height = 256
	noise.seamless = true
	var detail := FastNoiseLite.new()
	detail.frequency = 0.75
	noise.noise = detail
	asphalt.albedo_texture = noise
	asphalt.uv1_scale = Vector3(2,4,1)
	var shoulder := material("shoulder","b3b6ac")
	ribbon(-6.8,6.8,0.10,shoulder,"Shoulders")
	road_mesh = ribbon(-ROAD_HALF,ROAD_HALF,0.14,asphalt,"AsphaltLoop",true)
	var white := material("markings","eeeadd")
	ribbon(-5.15,-5.00,0.155,white,"InnerEdgeLine")
	ribbon(5.00,5.15,0.155,white,"SeaEdgeLine")
	var steel := material("guardrail","a5b8c4",0.75,0.32)
	var yellow := material("centerline","efdc96")
	var post_mat := material("posts","7b8891",0.65,0.45)
	var previous := road_point(0)
	var marking_distance := 0.0
	var post_distance := 0.0
	var lamps_distance := 0.0
	for i in range(1,721):
		var angle := TAU*i/720
		var point := road_point(angle)
		var segment := point.distance_to(previous)
		road_length += segment
		marking_distance += segment
		post_distance += segment
		lamps_distance += segment
		var middle := (point+previous)*0.5
		var tangent := (point-previous).normalized()
		var normal := road_outward(angle-TAU/1440)
		var basis := Basis(normal,Vector3.UP,tangent).orthonormalized()
		if fmod(marking_distance,9)<4.5:
			box("CenterDashes",Vector3(0.14,0.012,segment+0.02),Transform3D(basis,middle+Vector3.UP*0.16),yellow)
		# A continuous barrier, with overlapping collision segments at bends.
		box("SeaGuardrail",Vector3(0.13,0.36,segment+0.30),Transform3D(basis,middle+normal*6.15+Vector3.UP*0.88),steel,true)
		if post_distance>4:
			post_distance = 0
			box("GuardrailPosts",Vector3(0.12,1.15,0.13),Transform3D(basis,point+normal*6.15+Vector3.UP*0.57),post_mat)
			box("Reflectors",Vector3(0.15,0.12,0.10),Transform3D(basis,point+normal*6.05+Vector3.UP*0.95),white)
		if lamps_distance>42:
			lamps_distance = 0
			var base := point-normal*7.5
			box("LampPosts",Vector3(0.12,7.2,0.12),Transform3D(Basis.IDENTITY,base+Vector3.UP*3.6),post_mat)
			box("LampArms",Vector3(1.8,0.10,0.12),Transform3D(basis,base+normal*0.8+Vector3.UP*7.15),post_mat)
			box("LampHeads",Vector3(0.7,0.14,0.3),Transform3D(basis,base+normal*1.65+Vector3.UP*7.1),white)
		previous = point

func build_ocean() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(4000,4000)
	plane.subdivide_width = 80
	plane.subdivide_depth = 80
	var sea := ShaderMaterial.new()
	sea.shader = preload("res://Scenes/coastal/Sea.gdshader")
	mesh_node(plane,sea,"TurquoiseSea")

func build_village() -> void:
	var plaster := material("plaster","ece8d5")
	var timber := material("timber","554738")
	var stone := material("stone","999b8c")
	var roof_mat := material("roof","344c5d",0.35,0.53)
	var glass := material("glass","446b7c",0.5,0.16)
	var flower := material("flowers","c97f6b")
	var curb := material("curb","c5c5ad")
	for i in range(19):
		var angle := -0.85+i*0.29
		var normal := road_outward(angle)
		var forward := road_forward(angle)
		var p := road_point(angle)-normal*19
		p.y = height_at(p.x,p.z)
		var basis := Basis(-forward,Vector3.UP,normal)
		var origin := Transform3D(basis,p)
		var width := rng.randf_range(7,10)
		var depth := rng.randf_range(6,8)
		var height := 6.0 if i%3!=1 else 3.4
		house_count += 1
		box("HouseFoundations",Vector3(width+1.2,2.2,depth+1.2),origin.translated_local(Vector3(0,-0.8,0)),stone,true)
		box("VillageWalls",Vector3(width,height,depth),origin.translated_local(Vector3(0,height/2,0)),plaster,true)
		for x in [-width/2+0.09,width/2-0.09]:
			box("CornerTimbers",Vector3(0.17,height+0.1,0.17),origin.translated_local(Vector3(x,height/2,depth/2+0.04)),timber)
		var rise := width*0.28
		var slope := atan2(rise,width/2+0.5)
		for side in [-1,1]:
			var roof_transform := origin.translated_local(Vector3(side*(width/4+0.25),height+rise/2,0))
			roof_transform.basis = basis*Basis(Vector3.BACK,-side*slope)
			box("SlateRoofs",Vector3((width/2+0.5)/cos(slope),0.20,depth+1.1),roof_transform,roof_mat)
			# Narrow raised seams catch sunlight along the standing-seam roof.
			for seam in range(12):
				var strip := roof_transform.translated_local(Vector3(0,0.12,-depth/2+seam*depth/11))
				box("RoofSeams",Vector3((width/2+0.5)/cos(slope),0.035,0.025),strip,roof_mat)
		var gables := SurfaceTool.new()
		gables.begin(Mesh.PRIMITIVE_TRIANGLES)
		for side in [-1,1]:
			var a := Vector3(-width/2,height,side*depth/2)
			var b := Vector3(width/2,height,side*depth/2)
			var c := Vector3(0,height+rise,side*depth/2)
			for vertex in ([a,c,b] if side>0 else [a,b,c]):
				gables.add_vertex(origin*vertex)
		gables.generate_normals()
		mesh_node(gables.commit(),plaster,"Gable_%02d" % i)
		box("Chimneys",Vector3(0.65,1.8,0.7),origin.translated_local(Vector3(width*0.26,height+rise*0.8,-depth*0.25)),stone)
		# Doors and window frames sit on the ocean-facing facade.
		box("Doors",Vector3(1.1,2.3,0.12),origin.translated_local(Vector3(0,1.15,depth/2+0.05)),timber)
		for floor_index in range(2 if height>4 else 1):
			var y := 1.75+floor_index*2.8
			for x in [-width*0.30,width*0.30]:
				box("WindowFrames",Vector3(1.7,1.9,0.17),origin.translated_local(Vector3(x,y,depth/2+0.10)),timber)
				box("Windows",Vector3(1.4,1.6,0.18),origin.translated_local(Vector3(x,y,depth/2+0.13)),glass)
				box("Mullions",Vector3(0.06,1.65,0.07),origin.translated_local(Vector3(x,y,depth/2+0.25)),plaster)
				box("Sills",Vector3(1.9,0.13,0.4),origin.translated_local(Vector3(x,y-0.93,depth/2+0.19)),plaster)
				if floor_index==0:
					box("FlowerBoxes",Vector3(1.5,0.25,0.35),origin.translated_local(Vector3(x,y-0.75,depth/2+0.30)),flower)
		# Side windows make the houses readable as the car passes.
		for side in [-1,1]:
			for z in [-depth*0.25,depth*0.25]:
				box("SideWindowFrames",Vector3(0.16,1.7,1.5),origin.translated_local(Vector3(side*(width/2+0.05),1.8,z)),timber)
				box("SideWindows",Vector3(0.18,1.4,1.2),origin.translated_local(Vector3(side*(width/2+0.08),1.8,z)),glass)
		var entry := road_point(angle)-normal*8.8
		box("VillagePavement",Vector3(width+8,0.15,3.6),Transform3D(basis,entry+Vector3.UP*0.17),curb)
		for side in [-1,1]:
			var wall: Vector3 = entry+forward*side*(width/2+2)+normal*-1.9+Vector3.UP*0.65
			box("GardenWalls",Vector3(2.8,1.2,0.45),Transform3D(basis,wall),stone,true)
		for step in range(5):
			var stair := entry-normal*(2.4+step*0.52)
			stair.y += 0.15+step*0.16
			box("EntrySteps",Vector3(1.9,0.18,0.56),Transform3D(basis,stair),plaster)
	# A scenic pull-off on the inland side of the start, plus route signs.
	var start := road_point(SPAWN_ANGLE+0.035)
	var out := road_outward(SPAWN_ANGLE+0.035)
	if not preview_mode:
		var sign := Label3D.new()
		sign.name = "CoastalRouteSign"
		sign.text = "滨海道路\nCOASTAL DRIVE\n环岛公路 · 海风山景"
		sign.font_size = 36
		sign.pixel_size = 0.010
		sign.modulate = Color("f2efdb")
		sign.outline_size = 3
		sign.position = start-out*10+Vector3.UP*2.8
		sign.basis = Basis.looking_at(road_forward(SPAWN_ANGLE))
		add_child(sign)
		box("RouteSignBoard",Vector3(4.8,2.1,0.18),Transform3D(sign.basis,sign.position-sign.basis.z*0.13),material("sign","284f54"))

		for side in [-1,1]:
			box("SignPosts",Vector3(0.13,1.8,0.13),Transform3D(Basis.IDENTITY,sign.position+sign.basis.x*side*1.8-Vector3.UP*1.9-sign.basis.z*0.13),material("posts","7b8891",0.65,0.45))

func build_trees() -> void:
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.12
	trunk_mesh.bottom_radius = 0.22
	trunk_mesh.height = 1
	trunk_mesh.radial_segments = 7
	var leaf_mesh := SphereMesh.new()
	leaf_mesh.radius = 1
	leaf_mesh.height = 2
	leaf_mesh.radial_segments = 12
	leaf_mesh.rings = 6
	var bark := material("bark","66583d")
	var foliage := ShaderMaterial.new()
	foliage.shader = preload("res://Scenes/coastal/Foliage.gdshader")
	var collisions := StaticBody3D.new()
	collisions.name = "TreeTrunks"
	if not preview_mode:
		add_child(collisions)
	else:
		collisions.free()
	for i in range(650 if not preview_mode else 260):
		var x := rng.randf_range(-205,205)
		var z := rng.randf_range(-190,190)
		var inland := -road_distance(x,z)
		if inland<29 or inland>155:
			continue
		var p := Vector3(x,height_at(x,z),z)
		var height := rng.randf_range(5.5,10)
		var width := rng.randf_range(2.8,4.3)
		var tint := Color("3c6b37").lerp(Color("8fa958"),rng.randf())
		tree_count += 1
		batch("BroadleafTrunks",trunk_mesh,bark,Transform3D(Basis.IDENTITY.scaled(Vector3(1,height*0.65,1)),p+Vector3.UP*height*0.325))
		for lobe in range(6):
			var angle := lobe*TAU/5
			var center := p+Vector3(cos(angle)*width*0.48,height*0.73+sin(lobe*2.0)*0.7,sin(angle)*width*0.48)
			if lobe==5:
				center = p+Vector3.UP*height
			var scale := Vector3(width*0.73,width*0.78,width*0.73)
			batch("BroadleafCanopies",leaf_mesh,foliage,Transform3D(Basis.IDENTITY.scaled(scale),center),tint)
		if not preview_mode:
			var shape := CollisionShape3D.new()
			var cylinder := CylinderShape3D.new()
			cylinder.radius = 0.25
			cylinder.height = height*0.65
			shape.shape = cylinder
			shape.position = p+Vector3.UP*cylinder.height/2
			collisions.add_child(shape)
	# Low coastal bushes and stones stay beyond the shoulder.
	for i in range(220):
		var angle := rng.randf_range(0,TAU)
		var p := road_point(angle)+road_outward(angle)*rng.randf_range(10,27)
		p.y = height_at(p.x,p.z)
		var size := rng.randf_range(0.35,1.0)
		batch("CoastalScrub",leaf_mesh,foliage,Transform3D(Basis.IDENTITY.scaled(Vector3(size*1.5,size,size)),p+Vector3.UP*size*0.5),Color("899862"))

func build_mountains() -> void:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 1
	# Distant mainland peaks across the water. They are scenery beyond the driving area.
	for peak in range(9):
		var center := Vector3(-780+peak*185,0,680+sin(peak*2.0)*110)
		var height := 155+sin(peak*1.6)*70+peak*7
		var radius := 175.0+peak*5
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		var rings := 24
		var segments := 56
		for ring in range(rings+1):
			var r := float(ring)/rings
			for segment in range(segments+1):
				var angle := TAU*segment/segments
				var ridge := sin(angle*7+peak)*sin(r*12+angle*3)*0.14+sin(angle*11)*0.08
				var y := pow(1-r,1.35)*height*(1+ridge*minf(r*5,1))
				var pos := center+Vector3(cos(angle)*r*radius,y,sin(angle)*r*radius)
				var color := Color("647d83").lerp(Color("889598"),y/height)
				if y>height*(0.60+sin(angle*9+r*25)*0.07):
					color = Color("e3ece9")
				surface.set_color(color)
				surface.add_vertex(pos)
		for ring in range(rings):
			for segment in range(segments):
				var a := ring*(segments+1)+segment
				for index in [a,a+segments+1,a+1,a+1,a+segments+1,a+segments+2]:
					surface.add_index(index)
		surface.generate_normals()
		mesh_node(surface.commit(),mat,"SnowPeak_%d" % peak)
