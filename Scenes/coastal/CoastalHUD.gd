extends Control
## North-up route map and a speedometer driven by the actual rigid-body velocity.
const Coast = preload("res://Scenes/coastal/CoastalTerrain.gd")
const MAX_SPEED := 200.0
const MAP_RADIUS := 142.0
const DIAL_RADIUS := 164.0
const WHITE := Color(0.93,0.97,0.96,0.95)
const MUTED := Color(0.67,0.81,0.84,0.85)
const AQUA := Color(0.36,0.88,0.93,1)
const GOLD := Color(1,0.81,0.36,1)
var vehicle: RigidBody3D
var route: PackedVector2Array
var map_origin := Vector2.ZERO
var map_scale := 1.0
var map_center := Vector2.ZERO
var dial_center := Vector2.ZERO
var marker_position := Vector2.ZERO
var marker_direction := Vector2.UP
var speed_kph := 0.0
var needle_kph := 0.0
var drive_mode := "D"
var route_km := 0.0
var font: Font

func configure(car: RigidBody3D, length_m: float) -> void:
	vehicle = car
	route_km = length_m/1000
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	font = ThemeDB.fallback_font
	var bounds := Rect2(Vector2(Coast.road_point(0).x,Coast.road_point(0).z),Vector2.ZERO)
	for i in range(257):
		var point := Coast.road_point(TAU*i/256)
		var flat := Vector2(point.x,point.z)
		route.append(flat)
		bounds = bounds.expand(flat)
	map_origin = bounds.get_center()
	var farthest := 1.0
	for point in route:
		farthest = maxf(farthest,point.distance_to(map_origin))
	map_scale = (MAP_RADIUS-29)/farthest
	resized.connect(update_layout)
	update_layout()
	update_telemetry(0,true)

func update_layout() -> void:
	map_center = Vector2(190,size.y-199)
	dial_center = Vector2(size.x-218,size.y-221)
	queue_redraw()

func project_position(point: Vector3) -> Vector2:
	return map_center+(Vector2(point.x,point.z)-map_origin)*map_scale

func update_telemetry(delta: float, snap := false) -> void:
	if not is_instance_valid(vehicle):
		return
	speed_kph = vehicle.linear_velocity.length()*3.6
	needle_kph = speed_kph if snap else lerpf(needle_kph,speed_kph,1-exp(-10*delta))
	marker_position = project_position(vehicle.global_position)
	marker_position = map_center+(marker_position-map_center).limit_length(MAP_RADIUS-12)
	var forward := vehicle.global_basis.z
	var heading := Vector2(forward.x,forward.z)
	if heading.length_squared()>0.001:
		marker_direction = heading.normalized()
	var reverse := vehicle.linear_velocity.dot(forward)<-0.35
	if vehicle.has_method("reset_suspension"):
		drive_mode = ("R  ·  " if reverse else "D  ·  ")+("4L" if vehicle.low_range else "4H")
	else:
		drive_mode = "R" if reverse else "D  ·  %d 挡" % vehicle.gearshift
	queue_redraw()

func text_at(text: String, center: Vector2, font_size: int, color := WHITE) -> void:
	var width := font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	draw_string(font,center-Vector2(width/2,0),text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)

func _draw() -> void:
	if route.is_empty() or font == null:
		return
	draw_map()
	draw_speedometer()

func draw_map() -> void:
	draw_circle(map_center+Vector2(0,3),MAP_RADIUS+4,Color(0,0,0,0.18))
	draw_circle(map_center,MAP_RADIUS,Color(0.035,0.12,0.17,0.87))
	draw_arc(map_center,MAP_RADIUS,0,TAU,120,Color(0.74,0.88,0.91,0.7),2,true)
	var points := PackedVector2Array()
	for point in route:
		points.append(map_center+(point-map_origin)*map_scale)
	draw_colored_polygon(points,Color(0.18,0.30,0.29,0.55))
	draw_polyline(points,Color(0.02,0.07,0.10,0.8),8,true)
	draw_polyline(points,WHITE,3.2,true)
	text_at("N",map_center+Vector2(0,-MAP_RADIUS+23),17,MUTED)
	var start := project_position(Coast.road_point(Coast.SPAWN_ANGLE))
	draw_circle(start,5,GOLD)
	draw_circle(start,2,Color(0.08,0.16,0.18))
	var side := Vector2(-marker_direction.y,marker_direction.x)
	draw_circle(marker_position,13,Color(0.10,0.68,0.81,0.22))
	var triangle := PackedVector2Array([marker_position+marker_direction*12,marker_position-marker_direction*8+side*7,marker_position-marker_direction*4,marker_position-marker_direction*8-side*7])
	draw_colored_polygon(triangle,AQUA)
	triangle.append(triangle[0])
	draw_polyline(triangle,WHITE,1.4,true)
	text_at("滨海环线  /  %.2f km" % route_km,map_center+Vector2(0,MAP_RADIUS+30),19)

func speed_angle(value: float) -> float:
	return deg_to_rad(135+270*clampf(value/MAX_SPEED,0,1))

func draw_speedometer() -> void:
	draw_circle(dial_center+Vector2(0,3),DIAL_RADIUS+4,Color(0,0,0,0.18))
	draw_circle(dial_center,DIAL_RADIUS,Color(0.025,0.09,0.14,0.87))
	draw_arc(dial_center,DIAL_RADIUS,0,TAU,160,Color(0.74,0.88,0.91,0.7),2,true)
	var arc_start := speed_angle(0)
	var arc_end := speed_angle(MAX_SPEED)
	draw_arc(dial_center,DIAL_RADIUS-10,arc_start,arc_end,120,Color(0.42,0.64,0.70,0.3),4,true)
	if needle_kph>0.1:
		draw_arc(dial_center,DIAL_RADIUS-10,arc_start,speed_angle(needle_kph),100,AQUA,4,true)
	for i in range(41):
		var angle := speed_angle(i*5)
		var direction := Vector2(cos(angle),sin(angle))
		var major := i%4==0
		var outside := DIAL_RADIUS-20
		draw_line(dial_center+direction*(outside-(13 if major else 6)),dial_center+direction*outside,WHITE if major else MUTED,2 if major else 1,true)
		if major:
			text_at(str(i*5),dial_center+direction*(DIAL_RADIUS-48)+Vector2(0,6),17,MUTED)
	var angle := speed_angle(needle_kph)
	var direction := Vector2(cos(angle),sin(angle))
	draw_line(dial_center+direction*94,dial_center+direction*148,Color(0.05,0.15,0.20,0.8),7,true)
	draw_line(dial_center+direction*96,dial_center+direction*148,AQUA,3,true)
	text_at("SPEED",dial_center+Vector2(0,-47),16,MUTED)
	text_at("%03d" % roundi(speed_kph),dial_center+Vector2(0,25),72)
	text_at("km/h",dial_center+Vector2(0,56),21,MUTED)
	text_at(drive_mode,dial_center+Vector2(0,103),26)
	text_at("滨海道路  /  COASTAL DRIVE",dial_center+Vector2(0,DIAL_RADIUS+29),17,MUTED)
