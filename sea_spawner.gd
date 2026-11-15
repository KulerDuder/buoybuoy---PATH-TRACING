# sea_spawner.gd
extends Node3D

@export_group("Configuración de Spawn")
# Aquí es donde añadirás futuras cosas (cofres, enemigos, etc.)
@export var spawn_table: Array[PackedScene] = [
	preload("res://barrel.tscn")
]
# Probabilidades (debe tener el mismo tamaño que spawn_table)
@export var spawn_weights: Array[float] = [
	1.0
]

@export var spawn_interval: float = 4.0 # Segundos entre intentos
@export var max_objects: int = 8        # Máximo de objetos a la vez en el mapa

var _timer: float = 0.0
var _active_objects: Array = []

func _ready() -> void:
	add_to_group("sea_spawner")
	# Esperamos a que el terreno esté generado
	await get_tree().physics_frame
	await get_tree().physics_frame

func _process(delta: float) -> void:
	_timer += delta
	if _timer >= spawn_interval:
		_timer = 0.0
		_try_spawn()

func _try_spawn() -> void:
	# 1. Limpiar la lista de objetos recogidos/caducados
	_active_objects = _active_objects.filter(func(o): return is_instance_valid(o))
	
	if _active_objects.size() >= max_objects:
		return
		
	var terrain = get_tree().get_first_node_in_group("terrain")
	if not terrain: return
	
	var half_size = terrain.world_size * 0.5
	var border = terrain.border_width
	var w_level = terrain.water_level
	
	# 2. Elegir qué objeto spawnear basado en los pesos
	var chosen_scene = _pick_weighted_scene()
	if not chosen_scene:
		return
	
	# 3. Buscar un punto de agua válido
	for i in range(50):
		var x = randf_range(-half_size + border + 5.0, half_size - border - 5.0)
		var z = randf_range(-half_size + border + 5.0, half_size - border - 5.0)
		
		if terrain.get_height_at(x, z) < w_level - 1.0:
			# Instanciar la escena elegida
			var instance = chosen_scene.instantiate()
			instance.position = Vector3(x, w_level + 0.5, z)
			add_child(instance)
			_active_objects.append(instance)
			break

# Función auxiliar para elegir una escena basándonos en pesos de probabilidad
func _pick_weighted_scene() -> PackedScene:
	if spawn_table.is_empty(): return null
	if spawn_table.size() != spawn_weights.size():
		push_warning("sea_spawner: spawn_table y spawn_weights no coinciden en tamaño.")
		return spawn_table.pick_random() # Fallback: aleatorio uniforme
		
	var total_weight = 0.0
	for w in spawn_weights:
		total_weight += w
		
	var roll = randf() * total_weight
	for i in range(spawn_table.size()):
		roll -= spawn_weights[i]
		if roll <= 0.0:
			return spawn_table[i]
			
	return spawn_table[0]
