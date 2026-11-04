extends Node

const VEHICLES = [
	{"id": "sedan", "name": "经典轿车", "tag": "01  /  ROAD", "subtitle": "低重心 · 后轮驱动", "description": "熟悉的公路搭档。灵活转向，享受加速与漂移。", "scene": "res://cars/Sedan.tscn"},
	{"id": "wrangler", "name": "牧马人 · 越野", "tag": "02  /  ALL TERRAIN", "subtitle": "四轮驱动 · 长行程悬挂", "description": "离开平路，去翻越山丘。大颗粒轮胎与充足离地间隙。", "scene": "res://cars/Wrangler.tscn"},
	{"id": "rubicon", "name": "牧马人 · 卢比肯", "tag": "03  /  RUBICON 35", "subtitle": "写实四门 · 35 英寸越野胎", "description": "金属灰车漆、透明玻璃与完整内饰，搭配深胎纹越野轮胎。", "scene": "res://cars/Rubicon.tscn"},
	{"id": "jimny", "name": "吉姆尼 · JB74", "tag": "04  /  JIMNY SIERRA", "subtitle": "轻巧三门 · 短轴距四驱", "description": "嫩黄车身与黑色车顶。灵活穿行山路，感受整体桥悬挂的起伏。", "scene": "res://cars/Jimny.tscn"},
	{"id": "allroad", "name": "奥迪 A6 allroad", "tag": "05  /  QUATTRO TOURING", "subtitle": "全地形旅行车 · 独立悬挂", "description": "深绿金属漆、银色护板与旅行车长车顶。舒适巡航，也能驶入山谷。", "scene": "res://cars/Allroad.tscn"}
]
const LOCATIONS = [
	{"id": "coast", "name": "滨海道路", "tag": "01  /  COASTAL DRIVE", "subtitle": "崂山印象 · 盘山海岸 · 红瓦茶田", "description": "翻越花岗岩山坡，绕过岬角与海湾，穿行红瓦渔村和梯田茶园。", "scene": "res://Scenes/coastal/CoastalWorld.tscn"},
	{"id": "valley", "name": "松林山谷", "tag": "02  /  PINE VALLEY", "subtitle": "浅水坑 · 起伏山丘 · 林间土路", "description": "沿环线驶入松林，涉过浅水、翻越山丘。推荐越野车。", "scene": "res://Scenes/offroad/OffroadWorld.tscn"},
	{"id": "test", "name": "原型测试场", "tag": "03  /  PROTOTYPE", "subtitle": "平整场地 · 坡道 · 减速带", "description": "熟悉的紫色场地。测试加速、漂移和悬挂表现。", "scene": "res://main.tscn"}
]
var selected := 0
var selected_location := 0
var show_selection := false

func drive(index: int, location_index: int = -1) -> void:
	selected = clampi(index,0,VEHICLES.size()-1)
	if location_index >= 0:
		selected_location = clampi(location_index,0,LOCATIONS.size()-1)
	get_tree().change_scene_to_file(LOCATIONS[selected_location].scene)

func open_garage() -> void:
	show_selection = true
	get_tree().change_scene_to_file("res://Scenes/StartScreen.tscn")
