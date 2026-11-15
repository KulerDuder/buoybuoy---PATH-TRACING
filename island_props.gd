# island_props.gd
extends Node3D

@export var terrain: Node3D # Arrastra tu nodo Terrain aquí (o déjalo vacío)
@export var prop_count: int = 12 # Cuántos puestecitos intentar crear
@export var min_height: float = 1.0 # Altura mínima sobre el agua
@export var max_height: float = 8.0 # Altura máxima (no en la cima de la montaña)
@export var max_slope: float = 0.5 # Qué tan plano debe ser el terreno

var _lanterns: Array[OmniLight3D] = []
var _lantern_phases: Array[float] = []
var _time: float = 0.0
var _daynight: Node = null

func _ready() -> void:
	if not terrain:
		terrain = get_tree().get_first_node_in_group("terrain")
	
	if not terrain:
		push_warning("island_props.gd: No se encontró el nodo Terrain.")
		return
		
	# Buscamos el ciclo día/noche
	_daynight = get_tree().get_first_node_in_group("dayandnight")
		
	# Esperamos 2 frames de física para que la colisión del terreno se genere
	await get_tree().physics_frame
	await get_tree().physics_frame
	
	_scatter_props()

func _process(delta: float) -> void:
	_time += delta
	
	if _lanterns.is_empty() or not _daynight:
		return
		
	# Calcular si es de noche basándonos en la altura del sol
	var sun_angle = _daynight.time_of_day * TAU - PI * 0.5
	var sun_height = sin(sun_angle)
	
	# Las luces se encienden cuando el sol empieza a bajar (atardecer)
	var target_energy = 0.0
	if sun_height < 0.1:
		target_energy = 1.0
		
	for i in range(_lanterns.size()):
		var light = _lanterns[i]
		var phase = _lantern_phases[i]
		
		# 1. Transición suave de encendido/apagado
		var current_ratio = light.light_energy / 2.0
		current_ratio = move_toward(current_ratio, target_energy, delta * 1.5)
		
		# 2. Efecto de parpadeo (flicker) para que parezca fuego
		var flicker = 0.0
		if current_ratio > 0.05:
			var t = _time * 5.0
			flicker = sin(t + phase) * 0.15 + sin(t * 2.3 + phase * 1.7) * 0.05
			
		light.light_energy = max(0.0, (current_ratio + flicker) * 2.0)

func _scatter_props() -> void:
	var placed = 0
	var attempts = 0
	var world_half = terrain.world_size * 0.5
	var edge = terrain.border_width
	
	while placed < prop_count and attempts < 500:
		attempts += 1
		
		var x = randf_range(-world_half + edge, world_half - edge)
		var z = randf_range(-world_half + edge, world_half - edge)
		
		var y = terrain.get_height_at(x, z)
		
		if y < min_height or y > max_height:
			continue
			
		var step = 1.0
		var h1 = terrain.get_height_at(x + step, z)
		var h2 = terrain.get_height_at(x - step, z)
		var h3 = terrain.get_height_at(x, z + step)
		var h4 = terrain.get_height_at(x, z - step)
		
		var d1 = abs(h1 - y)
		var d2 = abs(h2 - y)
		var d3 = abs(h3 - y)
		var d4 = abs(h4 - y)
		var max_diff = max(d1, max(d2, max(d3, d4)))
		
		if max_diff > max_slope:
			continue
			
		_spawn_stall(Vector3(x, y, z))
		placed += 1
		
	print("Puestecitos isleños colocados: ", placed)

func _spawn_stall(pos: Vector3) -> void:
	var stall = Node3D.new()
	stall.position = pos
	stall.rotation.y = randf_range(0, TAU)
	
	var wood_mat = StandardMaterial3D.new()
	wood_mat.albedo_color = Color(0.45, 0.30, 0.18)
	wood_mat.roughness = 0.9
	
	var roof_mat = StandardMaterial3D.new()
	var colors = [Color(0.8, 0.2, 0.2), Color(0.2, 0.4, 0.8), Color(0.2, 0.7, 0.3)]
	roof_mat.albedo_color = colors[randi() % colors.size()]
	roof_mat.roughness = 0.8
	
	# 1. Base de madera
	var deck = MeshInstance3D.new()
	var deck_mesh = BoxMesh.new()
	deck_mesh.size = Vector3(3, 0.2, 3)
	deck.mesh = deck_mesh
	deck.material_override = wood_mat
	stall.add_child(deck)
	
	# 2. Postes de madera
	var offsets = [Vector3(-1.3, 1.5, -1.3), Vector3(1.3, 1.5, -1.3), Vector3(-1.3, 1.5, 1.3), Vector3(1.3, 1.5, 1.3)]
	for offset in offsets:
		var pole = MeshInstance3D.new()
		var pole_mesh = CylinderMesh.new()
		pole_mesh.top_radius = 0.1
		pole_mesh.bottom_radius = 0.1
		pole_mesh.height = 3.0
		pole_mesh.radial_segments = 8  # OPTIMIZACIÓN: 64 -> 8
		pole.mesh = pole_mesh
		pole.position = offset
		pole.material_override = wood_mat
		stall.add_child(pole)
		
	# 3. Mostrador
	var counter = MeshInstance3D.new()
	var counter_mesh = BoxMesh.new()
	counter_mesh.size = Vector3(2.5, 0.8, 0.6)
	counter.mesh = counter_mesh
	counter.position = Vector3(0, 0.5, 1.0)
	counter.material_override = wood_mat
	stall.add_child(counter)
	
	# 4. Techo de lona (pirámide)
	var roof = MeshInstance3D.new()
	var roof_mesh = CylinderMesh.new()
	roof_mesh.top_radius = 0.0
	roof_mesh.bottom_radius = 2.5
	roof_mesh.height = 1.2
	roof_mesh.radial_segments = 4
	roof.mesh = roof_mesh
	roof.position = Vector3(0, 3.0, 0)
	roof.rotation_degrees.y = 45
	roof.material_override = roof_mat
	stall.add_child(roof)
	
	# 5. Farolillo (Luz cálida)
	var lantern = OmniLight3D.new()
	lantern.light_color = Color(1.0, 0.75, 0.3)
	lantern.omni_range = 8.0
	lantern.light_energy = 0.0 # Empieza apagada
	lantern.shadow_enabled = false # Desactivamos sombras para rendimiento
	lantern.position = Vector3(0, 2.5, 0)
	stall.add_child(lantern)
	
	# Guardamos la luz para animarla luego
	_lanterns.append(lantern)
	_lantern_phases.append(randf_range(0.0, TAU))
	
	# 6. Bombilla brillante (esfera)
	var lantern_mesh = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.15
	sphere.height = 0.3
	sphere.radial_segments = 8  # OPTIMIZACIÓN: 64 -> 8
	sphere.rings = 4            # OPTIMIZACIÓN: 32 -> 4
	lantern_mesh.mesh = sphere
	var l_mat = StandardMaterial3D.new()
	l_mat.albedo_color = Color(1.0, 0.8, 0.2)
	l_mat.emission_enabled = true
	l_mat.emission = Color(1.0, 0.8, 0.2)
	l_mat.emission_energy_multiplier = 2.0
	lantern_mesh.material_override = l_mat
	lantern_mesh.position = Vector3(0, 2.5, 0)
	stall.add_child(lantern_mesh)
	
	# 7. Colisión
	var static_body = StaticBody3D.new()
	var col = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(3, 3.2, 3)
	col.shape = box
	col.position = Vector3(0, 1.6, 0)
	static_body.add_child(col)
	stall.add_child(static_body)
	
	add_child(stall)
