extends Node3D
## A compact, Laoshan-inspired mountain coast; not a survey or one-to-one road replica.
const ROAD_HALF := 5.5
const SPAWN_ANGLE := -1.1816
const EXTENT := 900.0
const ROAD_SEGMENTS := 1440
const VILLAGES := [5.10,0.40,3.80]
const TEA_GARDENS := [5.55,1.75,3.40]
@export var preview_mode := false
var rng := RandomNumberGenerator.new()
var road_mesh: ArrayMesh
var road_length := 0.0
var tree_count := 0
var house_count := 0
var batches: Dictionary = {}
var materials: Dictionary = {}
var terrain_noise := FastNoiseLite.new()
var height_texture: ImageTexture
var rock_count := 0
var tea_row_count := 0
var terrain_mesh: ArrayMesh

static func road_point(angle: float) -> Vector3:
	# Broad headlands alternate with tight coves; harmonics introduce genuine S bends.
	var radius := 400.0+65*sin(angle*3+0.4)+35*sin(angle*5-0.7)+18*sin(angle*7)
	var height := 50.0+25*sin(angle-0.4)+15*sin(angle*2+0.8)
	return Vector3(radius*cos(angle),height,radius*sin(angle)*0.85)

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
	for i in range(5):
		var center := road_point(angle)
		var derivative := (road_point(angle+0.001)-road_point(angle-0.001))/0.002
		derivative.y = 0
		var difference := point-center
		difference.y = 0
		angle += clampf(difference.dot(derivative)/derivative.length_squared(),-0.07,0.07)
	return angle

static func road_distance(x: float, z: float) -> float:
	var angle := closest_angle(x,z)
	return (Vector3(x,0,z)-road_point(angle)).dot(road_outward(angle))

static func angular_distance(a: float, b: float) -> float:
	return absf(wrapf(a-b,-PI,PI))

static func bay_factor(angle: float) -> float:
	return pow(0.5+0.5*sin(angle*3-0.8),3)

static func mountain_height(x: float, z: float) -> float:
	var height := 24.0
	for peak in [Vector4(-115,60,165,135),Vector4(65,-100,150,115),Vector4(155,140,195,105),Vector4(-220,-155,140,125),Vector4(-495,90,170,155)]:
		height += peak.z*exp(-Vector2(x-peak.x,z-peak.y).length_squared()/(peak.w*peak.w))
	var ridge := absf(sin(x*0.028+sin(z*0.012)*2))*absf(cos(z*0.023-x*0.009))
	return height+ridge*16+sin(x*0.13)*cos(z*0.16)*2.8

static func height_at(x: float, z: float) -> float:
	var angle := closest_angle(x,z)
	var road := road_point(angle)
	var outward := (Vector3(x,0,z)-road).dot(road_outward(angle))
	if outward>0:
		# Short, steep rock faces on headlands; long low beaches inside the bays.
		var beach := bay_factor(angle)
		var width := lerpf(23,105,beach)
		var h := lerpf(road.y-0.18,-2.0,smoothstep(8,width,outward))-maxf(0,outward-width)*0.16
		var rock_relief := sin(x*0.24)*sin(z*0.19)*2.8+cos(x*0.11+z*0.17)*1.6
		h += rock_relief*smoothstep(9,15,outward)*(1-smoothstep(width-6,width+8,outward))
		# An inland mountain neck breaks the old isolated oval-island silhouette.
		var neck := smoothstep(0.65,0.94,cos(angle-PI))*(1-smoothstep(145,360,outward))
		return lerpf(h,mountain_height(x,z),neck*smoothstep(8,45,outward))
	var inland := -outward
	var natural := mountain_height(x,z)
	var h := lerpf(road.y-0.18,natural,smoothstep(8,65,inland))
	for garden in TEA_GARDENS:
		var weight := (1-smoothstep(0.12,0.21,angular_distance(angle,garden)))*smoothstep(24,35,inland)*(1-smoothstep(100,125,inland))
		var terrace := floorf(h/3.0)*3+smoothstep(0.78,1.0,fposmod(h/3.0,1.0))*3
		h = lerpf(h,terrace,weight)
	return h

func _ready() -> void:
	rng.seed = 541297
	terrain_noise.seed = 926
	terrain_noise.frequency = 0.05
	build_ground()
	build_road_bed()
	build_road()
	build_ocean()
	build_village()
	build_trees()
	build_rocks()
	build_tea_gardens()
	build_viewpoints()
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

func ground_color(x: float, z: float, h: float, slope: float = 0.0) -> Color:
	var variation := terrain_noise.get_noise_2d(x,z)*0.5+0.5
	var grass := Color("3c583c").lerp(Color("718553"),variation)
	var granite := Color("8f8e82").lerp(Color("bab6a5"),variation)
	if h<2.5:
		return Color("c1b894").lerp(granite,smoothstep(0.25,0.8,slope))
	var rock := maxf(smoothstep(0.85,1.9,slope),smoothstep(135,230,h)*0.55)
	return grass.lerp(granite,rock)

func build_ground() -> void:
	var count := 120 if preview_mode else 300
	var step := EXTENT*2/count
	var vertices := PackedVector3Array()
	var heights := PackedFloat32Array()
	var distances := PackedFloat32Array()
	for z in range(count+1):
		for x in range(count+1):
			var px := -EXTENT+x*step
			var pz := -EXTENT+z*step
			var h := height_at(px,pz)
			vertices.append(Vector3(px,h,pz))
			heights.append(h)
			distances.append(absf(road_distance(px,pz)))
	var height_image := Image.create_from_data(count+1,count+1,false,Image.FORMAT_RF,heights.to_byte_array())
	height_texture = ImageTexture.create_from_image(height_image)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in range(count+1):
		for x in range(count+1):
			var index := z*(count+1)+x
			var dx := heights[z*(count+1)+maxi(x-1,0)]-heights[z*(count+1)+mini(x+1,count)]
			var dz := heights[maxi(z-1,0)*(count+1)+x]-heights[mini(z+1,count)*(count+1)+x]
			var normal := Vector3(dx,step*2,dz).normalized()
			var point := vertices[index]
			surface.set_color(ground_color(point.x,point.z,point.y,Vector2(dx,dz).length()/(step*2)))
			surface.set_normal(normal)
			surface.add_vertex(point)
	for z in range(count):
		for x in range(count):
			var a := z*(count+1)+x
			# An exact, finely sampled road bed replaces coarse triangles near the tarmac.
			if (not preview_mode and minf(minf(distances[a],distances[a+1]),minf(distances[a+count+1],distances[a+count+2]))<12) or (preview_mode and (distances[a]+distances[a+1]+distances[a+count+1]+distances[a+count+2])/4<12):
				continue
			for i in [a,a+1,a+count+1,a+1,a+count+2,a+count+1]:
				surface.add_index(i)
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://Scenes/coastal/CoastalGround.gdshader")
	materials["terrain"] = mat
	terrain_mesh = surface.commit()
	mesh_node(terrain_mesh,mat,"GraniteMountainCoast",true)

func build_road_bed() -> void:
	var count := 360 if preview_mode else ROAD_SEGMENTS
	var offsets := [-30.0,-24.0,-18.0,-12.0,-9.0,-7.0,0.0,7.0,9.0,12.0,18.0,24.0,30.0]
	var width := offsets.size()
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(count+1):
		var angle := TAU*i/count
		for offset in offsets:
			var point: Vector3 = road_point(angle)+road_outward(angle)*offset
			point.y = height_at(point.x,point.z)
			var dx := height_at(point.x-0.4,point.z)-height_at(point.x+0.4,point.z)
			var dz := height_at(point.x,point.z-0.4)-height_at(point.x,point.z+0.4)
			surface.set_color(ground_color(point.x,point.z,point.y,Vector2(dx,dz).length()/0.8))
			surface.set_normal(Vector3(dx,0.8,dz).normalized())
			surface.add_vertex(point)
	for i in range(count):
		for j in range(width-1):
			var a := i*width+j
			for index in [a,a+1,a+width,a+1,a+width+1,a+width]:
				surface.add_index(index)
	mesh_node(surface.commit(),materials["terrain"],"MountainRoadBed",true)

func ribbon(from: float, to: float, lift: float, mat: Material, node_name: String, collision := false) -> ArrayMesh:
	var count := 360 if preview_mode else ROAD_SEGMENTS
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
	for i in range(1,ROAD_SEGMENTS+1):
		var angle := TAU*i/ROAD_SEGMENTS
		var point := road_point(angle)
		var segment := point.distance_to(previous)
		road_length += segment
		marking_distance += segment
		post_distance += segment
		lamps_distance += segment
		var middle := (point+previous)*0.5
		var tangent := (point-previous).normalized()
		var normal := road_outward(angle-TAU/(ROAD_SEGMENTS*2))
		var basis := Basis(normal,tangent.cross(normal).normalized(),tangent)
		if fmod(marking_distance,9)<4.5:
			box("CenterDashes",Vector3(0.14,0.012,segment+0.02),Transform3D(basis,middle+Vector3.UP*0.16),yellow)
		# A continuous barrier, with overlapping collision segments at bends.
		box("SeaGuardrail",Vector3(0.13,0.36,segment+0.30),Transform3D(basis,middle+normal*6.15+Vector3.UP*0.88),steel,true)
		if post_distance>4:
			post_distance = 0
			box("GuardrailPosts",Vector3(0.12,1.15,0.13),Transform3D(basis,point+normal*6.15+Vector3.UP*0.57),post_mat)
			box("Reflectors",Vector3(0.15,0.12,0.10),Transform3D(basis,point+normal*6.05+Vector3.UP*0.95),white)
		if lamps_distance>65 and in_village(angle):
			lamps_distance = 0
			var base := point-normal*7.5
			box("LampPosts",Vector3(0.12,7.2,0.12),Transform3D(Basis.IDENTITY,base+Vector3.UP*3.6),post_mat)
			box("LampArms",Vector3(1.8,0.10,0.12),Transform3D(basis,base+normal*0.8+Vector3.UP*7.15),post_mat)
			box("LampHeads",Vector3(0.7,0.14,0.3),Transform3D(basis,base+normal*1.65+Vector3.UP*7.1),white)
		previous = point

func build_ocean() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(14000,14000)
	plane.subdivide_width = 80
	plane.subdivide_depth = 80
	var sea := ShaderMaterial.new()
	sea.shader = preload("res://Scenes/coastal/Sea.gdshader")
	sea.set_shader_parameter("height_map",height_texture)
	sea.set_shader_parameter("terrain_extent",EXTENT)
	mesh_node(plane,sea,"TurquoiseSea")

func build_village() -> void:
	var plaster := material("plaster","ece8d5")
	var timber := material("timber","554738")
	var stone := material("stone","999b8c")
	var roof_mat := material("roof","a6553e",0.0,0.88)
	var glass := material("glass","446b7c",0.5,0.16)
	var flower := material("flowers","c97f6b")
	var curb := material("curb","c5c5ad")
	for i in range(42):
		var cluster := int(i/14)
		var row := int((i%14)/7)
		var angle: float = VILLAGES[cluster]+(i%7-3)*0.028
		var normal := road_outward(angle)
		var forward := road_forward(angle)
		var p := road_point(angle)-normal*(19+row*20)
		var low := INF
		var high := -INF
		for corner in [Vector2(-5,-4),Vector2(-5,4),Vector2(5,-4),Vector2(5,4)]:
			var foot: Vector3 = p+forward*corner.x+normal*corner.y
			var h := height_at(foot.x,foot.z)
			low = minf(low,h)
			high = maxf(high,h)
		p.y = high-0.15
		var foundation_height := maxf(2.2,high-low+1.2)
		var basis := Basis(-forward,Vector3.UP,normal)
		var origin := Transform3D(basis,p)
		var width := rng.randf_range(7,10)
		var depth := rng.randf_range(6,8)
		var height := 6.0 if i%3!=1 else 3.4
		house_count += 1
		box("HouseFoundations",Vector3(width+1.2,foundation_height,depth+1.2),origin.translated_local(Vector3(0,0.3-foundation_height/2,0)),stone,true)
		box("VillageWalls",Vector3(width,height,depth),origin.translated_local(Vector3(0,height/2,0)),plaster,true)
		for x in [-width/2+0.09,width/2-0.09]:
			box("CornerTimbers",Vector3(0.17,height+0.1,0.17),origin.translated_local(Vector3(x,height/2,depth/2+0.04)),timber)
		var rise := width*0.28
		var slope := atan2(rise,width/2+0.5)
		for side in [-1,1]:
			var roof_transform := origin.translated_local(Vector3(side*(width/4+0.25),height+rise/2,0))
			roof_transform.basis = basis*Basis(Vector3.BACK,-side*slope)
			box("RedTileRoofs",Vector3((width/2+0.5)/cos(slope),0.20,depth+1.1),roof_transform,roof_mat)
			# Raised rows suggest the traditional red clay roof tiles.
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
		sign.text = "崂山印象\nMOUNTAIN COAST\n依山临海 · 弯多慢行"
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
	for i in range(10500 if not preview_mode else 2800):
		var x := rng.randf_range(-690,500)
		var z := rng.randf_range(-460,470)
		var inland := -road_distance(x,z)
		if inland<15 and not (x<-450 and height_at(x,z)>15):
			continue
		var tree_angle := closest_angle(x,z)
		if (in_village(tree_angle) and inland<65) or in_tea_garden(tree_angle,inland):
			continue
		var p := Vector3(x,height_at(x,z),z)
		var slope := Vector2(height_at(x+2,z)-height_at(x-2,z),height_at(x,z+2)-height_at(x,z-2)).length()/4
		if p.y<3 or slope>1.25 or (p.y>150 and rng.randf()<0.65):
			continue
		var height := rng.randf_range(6.5,11)
		var width := rng.randf_range(3.6,5.6)
		var tint := Color("315739").lerp(Color("688547"),rng.randf())
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

static func in_village(angle: float) -> bool:
	for center in VILLAGES:
		if angular_distance(angle,center)<0.14:
			return true
	return false

static func in_tea_garden(angle: float, inland: float) -> bool:
	for center in TEA_GARDENS:
		if angular_distance(angle,center)<0.19 and inland>26 and inland<122:
			return true
	return false

func rock_mesh() -> ArrayMesh:
	var sphere := SphereMesh.new()
	sphere.radius = 1
	sphere.height = 2
	sphere.radial_segments = 12
	sphere.rings = 7
	var arrays := sphere.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in range(vertices.size()):
		var p := vertices[i]
		var noise := sin(p.x*6+p.y*3)*cos(p.z*5-p.x*2)*0.12+sin(p.z*11+p.y*7)*0.04
		vertices[i] *= 1+noise
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var surface := SurfaceTool.new()
	surface.create_from(mesh,0)
	surface.generate_normals()
	return surface.commit()

func build_rocks() -> void:
	var mesh := rock_mesh()
	var granite := ShaderMaterial.new()
	granite.shader = preload("res://Scenes/coastal/Granite.gdshader")
	var collisions := StaticBody3D.new()
	collisions.name = "GraniteOutcropsCollision"
	if not preview_mode:
		add_child(collisions)
	else:
		collisions.free()
	for i in range(580 if not preview_mode else 240):
		var angle := rng.randf_range(0,TAU)
		var offset := rng.randf_range(12,90) if i%3==0 else rng.randf_range(-260,-20)
		var point := road_point(angle)+road_outward(angle)*offset
		point.y = height_at(point.x,point.z)
		if point.y < -1.5 or (offset<0 and (in_village(angle) or in_tea_garden(angle,-offset))):
			continue
		var radius := rng.randf_range(2.2,6.5) if offset>0 else rng.randf_range(3,12)
		var scale := Vector3(radius,radius*rng.randf_range(0.6,1.3),radius*rng.randf_range(0.7,1.15))
		point.y += scale.y*0.18
		var rotation := Basis(Vector3.UP,rng.randf_range(0,TAU))
		batch("WeatheredGranite",mesh,granite,Transform3D(rotation.scaled_local(scale),point))
		rock_count += 1
		if not preview_mode:
			var shape := CollisionShape3D.new()
			var bounds := BoxShape3D.new()
			bounds.size = scale*1.45
			shape.shape = bounds
			shape.transform = Transform3D(rotation,point)
			collisions.add_child(shape)

func build_tea_gardens() -> void:
	var leaf := material("tea","405c2d")
	var stone := material("terrace_stone","878b76")
	for garden in TEA_GARDENS:
		for row in range(9):
			tea_row_count += 1
			for segment in range(72):
				var angle: float = garden-0.13+segment*(0.264/72)
				var offset := 32.0+row*8.0
				var point := road_point(angle)-road_outward(angle)*offset
				point.y = height_at(point.x,point.z)
				var next := road_point(angle+0.264/72)-road_outward(angle+0.264/72)*offset
				next.y = height_at(next.x,next.z)
				var direction := (next-point).normalized()
				var outward := Vector3(direction.z,0,-direction.x).normalized()
				var basis := Basis(outward,direction.cross(outward).normalized(),direction)
				var length := point.distance_to(next)
				var middle := (point+next)/2
				box("TeaHedges",Vector3(1.8,1.05,length+0.15),Transform3D(basis,middle+Vector3.UP*0.55),leaf)
				if row%3==0:
					box("TeaTerraceWalls",Vector3(0.35,0.6,length+0.15),Transform3D(basis,middle+outward*1.8),stone)

func build_viewpoints() -> void:
	if preview_mode:
		return
	for angle in [0.85,2.2,3.2,4.35]:
		var forward := road_forward(angle)
		var outward := road_outward(angle)
		var position := road_point(angle)-outward*7.6+Vector3.UP*2.2
		var basis := Basis.looking_at(forward)
		var label := Label3D.new()
		label.text = "连续弯道\n慢行  30"
		label.font_size = 40
		label.pixel_size = 0.009
		label.position = position
		label.basis = basis
		label.modulate = Color("fff3bc")
		add_child(label)
		box("BendSignBoard",Vector3(2.2,1.5,0.1),Transform3D(basis,position-basis.z*0.08),material("sign","284f54"))
		box("BendSignPosts",Vector3(0.1,2.3,0.1),Transform3D(Basis.IDENTITY,position-Vector3.UP*1.2-basis.z*0.1),material("posts","7b8891",0.65,0.45))
