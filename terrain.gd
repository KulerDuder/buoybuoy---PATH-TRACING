# terrain.gd
extends Node3D

@export_group("Tamaño del Mundo")
@export var world_size: float = 200.0
@export var resolution: int = 128

@export_group("Generación de Terreno")
@export var water_level: float = 0.0
@export var border_width: float = 35.0
@export var border_height: float = 45.0
@export var island_scale: float = 40.0
@export var island_height: float = 25.0
@export var noise_seed: int = 1337

var noise: FastNoiseLite

func _ready() -> void:
	# Nos unimos al grupo para que island_props.gd nos encuentre
	add_to_group("terrain")
	
	_setup_noise()
	_generate_mesh()

func _setup_noise() -> void:
	noise = FastNoiseLite.new()
	noise.seed = noise_seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 1.0 / island_scale
	noise.fractal_octaves = 4

# Función auxiliar privada para calcular la altura en un punto exacto (x, z)
func _get_height_at(x: float, z: float) -> float:
	var half_size: float = world_size * 0.5
	var dist_x: float = min(x + half_size, half_size - x)
	var dist_z: float = min(z + half_size, half_size - z)
	var dist_to_edge: float = min(dist_x, dist_z)
	
	var edge_factor: float = 1.0 - smoothstep(border_width - 15.0, border_width, dist_to_edge)
	var edge_height: float = edge_factor * border_height
	
	var n_val: float = noise.get_noise_2d(x, z)
	var island_mask: float = smoothstep(0.0, 0.6, n_val)
	var island_val: float = island_mask * island_height
	
	var height: float = edge_height + island_val
	if dist_to_edge > border_width and island_val < 1.0:
		height = -10.0 # Fondo marino
		
	return height

# Función pública para que otros scripts (como island_props.gd) consulten la altura
func get_height_at(x: float, z: float) -> float:
	return _get_height_at(x, z)

func _generate_mesh() -> void:
	var half_size: float = world_size * 0.5
	var step: float = world_size / float(resolution - 1)

	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var vertex_colors: PackedColorArray = PackedColorArray()
	var indices: PackedInt32Array = PackedInt32Array()

	# 1. Vértices, normales y colores
	for z in range(resolution):
		for x in range(resolution):
			var world_x: float = x * step - half_size
			var world_z: float = z * step - half_size
			
			var height: float = _get_height_at(world_x, world_z)
			
			# Calcular la normal usando los vecinos (diferencia finita)
			var h_left: float = _get_height_at(world_x - step, world_z)
			var h_right: float = _get_height_at(world_x + step, world_z)
			var h_down: float = _get_height_at(world_x, world_z - step)
			var h_up: float = _get_height_at(world_x, world_z + step)
			
			# La normal apunta hacia arriba y se inclina según la pendiente
			var normal: Vector3 = Vector3(h_left - h_right, 2.0 * step, h_down - h_up).normalized()
			
			vertices.append(Vector3(world_x, height, world_z))
			normals.append(normal)

			var color: Color
			if height < 1.0:
				color = Color(0.25, 0.60, 0.85) # Azul fondo marino
			elif height < 3.0:
				color = Color(0.76, 0.70, 0.50) # Arena
			else:
				color = Color(0.60, 0.35, 0.20) # Marrón tierra
			vertex_colors.append(color)

	# 2. Índices (triángulos)
	for z in range(resolution - 1):
		for x in range(resolution - 1):
			var i: int = z * resolution + x
			indices.append(i)
			indices.append(i + resolution)
			indices.append(i + 1)
			
			indices.append(i + 1)
			indices.append(i + resolution)
			indices.append(i + resolution + 1)

	# 3. Construir ArrayMesh
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = vertex_colors
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	# 4. Crear MeshInstance3D
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED # Para no ver el interior de las montañas
	mesh_instance.material_override = mat
	add_child(mesh_instance)

	# 5. Colisión
	var static_body := StaticBody3D.new()
	var collision_shape := CollisionShape3D.new()
	collision_shape.shape = mesh.create_trimesh_shape()
	static_body.add_child(collision_shape)
	add_child(static_body)

	print("¡Terreno generado con éxito y registrado en el grupo 'terrain'!")
