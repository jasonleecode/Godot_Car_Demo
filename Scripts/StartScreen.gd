extends Control

const INK := Color("243d35")
const MUTED := Color("6e786b")
const PAPER := Color("eeeadd")
const GOLD := Color("b68d50")
var content: MarginContainer
var previews: Array[Node3D] = []
var selecting := false
var choosing_location := false
var transition_pending := false

func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = PAPER
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var strip := ColorRect.new()
	strip.color = INK
	strip.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	strip.offset_bottom = 12
	add_child(strip)
	content = MarginContainer.new()
	add_child(content)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left","right"]:
		content.add_theme_constant_override("margin_"+edge,110)
	for edge in ["top","bottom"]:
		content.add_theme_constant_override("margin_"+edge,65)
	if Garage.show_selection:
		Garage.show_selection = false
		show_cards()
	else:
		show_home()

func clear_content() -> void:
	previews.clear()
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()

func label(text: String, size_px: int, color: Color = INK) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size",size_px)
	node.add_theme_color_override("font_color",color)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

func style(color: Color, border: Color, width: int = 1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(18)
	s.content_margin_left = 28
	s.content_margin_right = 28
	s.content_margin_top = 20
	s.content_margin_bottom = 20
	return s

func action_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(240,76)
	b.add_theme_font_size_override("font_size",25)
	b.add_theme_color_override("font_color",PAPER)
	b.add_theme_color_override("font_hover_color",Color.WHITE)
	b.add_theme_stylebox_override("normal",style(INK,INK))
	b.add_theme_stylebox_override("hover",style(Color("3f5948"),GOLD,2))
	b.add_theme_stylebox_override("focus",style(Color(0,0,0,0),GOLD,3))
	return b

func show_home() -> void:
	clear_content()
	selecting = false
	choosing_location = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation",20)
	content.add_child(v)
	v.add_child(label("CAR DEMO     /     THE OPEN ROAD",22,MUTED))
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(row)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 610
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_theme_constant_override("separation",28)
	row.add_child(left)
	left.add_child(label("下一程，\n去往山野。",86))
	left.add_child(label("从熟悉的公路，到未曾走过的崎岖。\n选一辆车，自由出发。",27,MUTED))
	var start := action_button("开始游戏    →")
	start.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	start.pressed.connect(show_cards)
	left.add_child(start)
	start.grab_focus()
	var preview := make_preview(2)
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(preview)
	v.add_child(label("自由驾驶     /     %d 种车型     /     %d 种场景" % [Garage.VEHICLES.size(),Garage.LOCATIONS.size()],21,MUTED))

func show_cards() -> void:
	clear_content()
	selecting = true
	choosing_location = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation",18)
	content.add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	var eyebrow := label("01  选择车辆     /     02  选择场景",22,MUTED)
	eyebrow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(eyebrow)
	var back := action_button("←  返回")
	back.custom_minimum_size = Vector2(170,55)
	back.pressed.connect(show_home)
	top.add_child(back)
	v.add_child(label("选择座驾，自由出发。",57))
	v.add_child(label("先选择车辆，再选择目的地。每一种驾驶方式，都有自己的乐趣。",25,MUTED))
	var scroll := ScrollContainer.new()
	scroll.name = "VehicleScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	v.add_child(scroll)
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation",22)
	scroll.add_child(row)
	for i in range(Garage.VEHICLES.size()):
		var card := make_card(i)
		card.custom_minimum_size.x = 405
		row.add_child(card)
		if i == Garage.selected:
			focus_vehicle.call_deferred(scroll,card)
	v.add_child(label("左右滚动选择更多车辆   ·   WASD 驾驶   ·   SPACE 刹车   ·   P 驻车   ·   V 切换视角   ·   G 返回车库",21,MUTED))

func focus_vehicle(scroll: ScrollContainer, card: Control) -> void:
	# Wait for the containers to size the row before revealing the selected car.
	if not is_inside_tree():
		return
	var tree := get_tree()
	await tree.process_frame
	await tree.process_frame
	if is_instance_valid(scroll) and is_instance_valid(card):
		card.grab_focus()
		scroll.ensure_control_visible(card)

func show_locations() -> void:
	clear_content()
	selecting = true
	choosing_location = true
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation",18)
	content.add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	var eyebrow := label("01  选择车辆  ✓     /     02  选择场景",22,MUTED)
	eyebrow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(eyebrow)
	var back := action_button("←  重新选车")
	back.custom_minimum_size = Vector2(220,55)
	back.pressed.connect(show_cards)
	top.add_child(back)
	v.add_child(label("这一程，去哪里？",57))
	v.add_child(label("已选车辆："+Garage.VEHICLES[Garage.selected].name+"   ·   点击场景卡片，开始驾驶。",25,MUTED))
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation",34)
	v.add_child(row)
	for i in range(Garage.LOCATIONS.size()):
		var card := make_card(i,true)
		row.add_child(card)
		if i == Garage.selected_location:
			card.grab_focus()
	v.add_child(label("所有车辆均可进入任意场景     ·     游戏中按 G 重新选择     ·     ESC 返回选车",21,MUTED))

func make_location_preview(index: int) -> SubViewportContainer:
	var is_valley: bool = Garage.LOCATIONS[index].id == "valley"
	var is_coast: bool = Garage.LOCATIONS[index].id == "coast"
	var container := SubViewportContainer.new()
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var viewport := SubViewport.new()
	viewport.size = Vector2i(680,400)
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_2X
	container.add_child(viewport)
	var stage := Node3D.new()
	viewport.add_child(stage)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("d9dfcc") if is_valley else Color("b4c9d1")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("e1e8db")
	environment.environment.ambient_light_energy = 0.65
	stage.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48,-30,0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	stage.add_child(sun)
	if is_coast:
		var coast := preload("res://Scenes/coastal/CoastalTerrain.gd").new()
		coast.preview_mode = true
		stage.add_child(coast)
	elif is_valley:
		var landscape := Node3D.new()
		landscape.set_script(preload("res://Scenes/offroad/OffroadTerrain.gd"))
		landscape.preview_mode = true
		stage.add_child(landscape)
	else:
		var playground := preload("res://main.tscn").instantiate()
		playground.set_script(null)
		playground.process_mode = Node.PROCESS_MODE_DISABLED
		for node_name in ["WorldEnvironment","DirectionalLight3D"]:
			var node := playground.get_node(node_name)
			playground.remove_child(node)
			node.free()
		stage.add_child(playground)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.position = Vector3(100,110,-120) if is_valley else Vector3(38,28,-40)
	var target := Vector3(0,3,3) if is_valley else Vector3(0,1,18)
	camera.basis = Basis.looking_at(target-camera.position)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 132 if is_valley else 62
	if is_coast:
		camera.position = Vector3(790,620,-820)
		camera.basis = Basis.looking_at(Vector3(60,45,-70)-camera.position)
		camera.size = 750
		environment.environment.background_color = Color("90c7df")
	camera.current = true
	return container

func make_card(index: int, is_location: bool = false) -> Button:
	var info: Dictionary = Garage.LOCATIONS[index] if is_location else Garage.VEHICLES[index]
	var card := Button.new()
	card.name = ("SceneCard_" if is_location else "VehicleCard_")+info.id
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("normal",style(Color("f8f5eb"),Color("d4d5c7")))
	card.add_theme_stylebox_override("hover",style(Color("fffdf4"),GOLD,3))
	card.add_theme_stylebox_override("pressed",style(Color("e1e5d6"),INK,3))
	card.add_theme_stylebox_override("focus",style(Color(0,0,0,0),INK,3))
	card.pressed.connect(func():
		if transition_pending:
			return
		if is_location:
			transition_pending = true
			Garage.drive(Garage.selected,index)
		else:
			Garage.selected = index
			show_locations()
	)
	var margin := MarginContainer.new()
	card.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_"+edge,32 if is_location else 24)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation",14)
	margin.add_child(v)
	v.add_child(label(info.tag,20,GOLD))
	var preview := make_location_preview(index) if is_location else make_preview(index)
	preview.custom_minimum_size.y = 280
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(preview)
	v.add_child(label(info.name,34 if is_location else 28))
	v.add_child(label(info.subtitle,20,MUTED))
	var description := label(info.description,20,MUTED)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size.y = 64
	v.add_child(description)
	var line := HSeparator.new()
	v.add_child(line)
	var action := HBoxContainer.new()
	v.add_child(action)
	var action_text := label("进入这片场地" if is_location else "选择车辆，继续",25 if is_location else 22)
	action_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action.add_child(action_text)
	action.add_child(label("→",25))
	ignore_mouse(margin)
	return card

func ignore_mouse(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		ignore_mouse(child)

func make_preview(index: int) -> SubViewportContainer:
	var container := SubViewportContainer.new()
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var viewport := SubViewport.new()
	viewport.size = Vector2i(680,400)
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_4X
	container.add_child(viewport)
	var stage := Node3D.new()
	viewport.add_child(stage)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = PAPER
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("dfe8ef")
	environment.environment.ambient_light_energy = 0.7
	environment.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	stage.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48,-30,0)
	sun.light_color = Color("fff0d3")
	sun.light_energy = 1.9
	sun.shadow_enabled = true
	stage.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20,130,0)
	fill.light_energy = 0.65
	stage.add_child(fill)
	var platform := MeshInstance3D.new()
	var disk := CylinderMesh.new()
	disk.top_radius = 3.1
	disk.bottom_radius = 3.1
	disk.height = 0.13
	disk.radial_segments = 64
	platform.mesh = disk
	platform.material_override = preload("res://cars/WranglerVisual.gd").material(Color("d8dccb"))
	stage.add_child(platform)
	platform.position.y = -0.09
	var model: Node3D
	if Garage.VEHICLES[index].id == "allroad":
		model = Node3D.new()
		model.set_script(preload("res://cars/AllroadVisual.gd"))
		model.position.y = 0.36
	elif Garage.VEHICLES[index].id == "jimny":
		model = Node3D.new()
		model.set_script(preload("res://cars/JimnyVisual.gd"))
		model.position.y = 0.35
	elif Garage.VEHICLES[index].id == "rubicon":
		model = Node3D.new()
		model.set_script(preload("res://cars/RubiconVisual.gd"))
		model.position.y = 0.43
	elif Garage.VEHICLES[index].id == "wrangler":
		model = Node3D.new()
		model.set_script(preload("res://cars/WranglerVisual.gd"))
		model.position.y = 0.42
	else:
		model = preload("res://cars/Sedan.tscn").instantiate()
		model.freeze = true
		model.process_mode = Node.PROCESS_MODE_DISABLED
		var look := model.get_node("look")
		model.remove_child(look)
		look.free()
		model.position.y = 0.10
	stage.add_child(model)
	model.rotation.y = -0.22
	previews.append(model)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.position = Vector3(5.3,3.4,6.8)
	camera.basis = Basis.looking_at(Vector3(0,1.05,0)-camera.position)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 4.0 if selecting else 6.6
	camera.current = true
	return container

func _process(delta: float) -> void:
	for preview in previews:
		preview.rotation.y += delta*0.09

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reset") and selecting:
		if choosing_location:
			show_cards()
		else:
			show_home()
