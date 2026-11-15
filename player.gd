# player.gd
extends Node3D

signal navigation_started(target_pos: Vector3)
signal navigation_finished()
signal inventory_changed()

var boat: BoatController
var camera: IsoCamera
var economy: PlayerEconomy # NUEVO: Economía

var inventory: Array[String] = []

func _ready() -> void:
	add_to_group("player")
	
	# 1. Crear la economía
	economy = PlayerEconomy.new()
	economy.name = "Economy"
	add_child(economy)
	
	var spawn_pos: Vector3 = await _find_safe_spawn()
	
	boat = BoatController.new()
	boat.name = "Boat"
	boat.position = spawn_pos
	add_child(boat)
	
	var light = BoatLight.new()
	light.name = "BoatLight"
	boat.add_child(light)

	camera = IsoCamera.new()
	camera.name = "IsoCamera"
	camera.target = boat
	add_child(camera)
	camera.snap_to_target()
	
	var ui = CanvasLayer.new()
	ui.set_script(load("res://inventory_ui.gd"))
	add_child(ui)

func add_item(item_name: String) -> void:
	inventory.append(item_name)
	inventory_changed.emit()

# NUEVO: Quitar un objeto del inventario
func remove_item(item_name: String) -> bool:
	var idx = inventory.find(item_name)
	if idx != -1:
		inventory.remove_at(idx)
		inventory_changed.emit()
		return true
	return false

# NUEVO: Abrir un barril, ganar oro y destruirlo
func open_barrel() -> void:
	if remove_item("barrel"):
		var gold_reward = randi_range(0, 10)
		economy.add_gold(gold_reward)
		print("¡Barril abierto! Has ganado ", gold_reward, " monedas.")

# ... (El resto de funciones: _find_safe_spawn, _input, _set_move_target, _physics_process se quedan IGUAL)
func _find_safe_spawn() -> Vector3:
	var terrain = get_tree().get_first_node_in_group("terrain")
	if not terrain: return Vector3(0, 0.5, 0)
	while terrain.noise == null: await get_tree().process_frame
	var half_size: float = terrain.world_size * 0.5
	var border: float = terrain.border_width
	var w_level: float = terrain.water_level
	for i in range(200):
		var x = randf_range(-half_size + border + 10.0, half_size - border - 10.0)
		var z = randf_range(-half_size + border + 10.0, half_size - border - 10.0)
		if terrain.get_height_at(x, z) < w_level - 1.0:
			return Vector3(x, w_level + 0.5, z)
	return Vector3(0, w_level + 0.5, 0)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_set_move_target(event.position)

func _set_move_target(screen_pos: Vector2) -> void:
	if not camera: return
	var ray_origin := camera.project_ray_origin(screen_pos)
	var ray_normal := camera.project_ray_normal(screen_pos)
	var water_plane := Plane(Vector3.UP, 0.0)
	var hit: Variant = water_plane.intersects_ray(ray_origin, ray_normal)
	if hit is Vector3:
		boat.target_position = hit
		boat.has_target = true
		navigation_started.emit(boat.target_position)

func _physics_process(_delta: float) -> void:
	if boat and boat.has_target == false and boat.target_position != Vector3.ZERO:
		if boat.global_position.distance_to(boat.target_position) <= boat.arrive_radius + 1.0:
			navigation_finished.emit()
			boat.target_position = Vector3.ZERO
