# water.gd
extends Node3D

@export var water_size: Vector3 = Vector3(200, 2, 200) # Ampliado para cubrir el terreno
@export var water_level: float = 0.0
@export var max_buoyancy_force: float = 24.0
@export var linear_drag: float = 2.5
@export var angular_drag: float = 3.0

# Configuración de las 3 olas
var wave_config: Array = [
	{"dir": Vector2(1.0, 0.0),  "amplitude": 0.15, "frequency": 0.5, "speed": 1.0, "phase": 0.0},
	{"dir": Vector2(0.7, 0.7),  "amplitude": 0.10, "frequency": 0.9, "speed": 1.4, "phase": 1.3},
	{"dir": Vector2(-0.4, 0.9), "amplitude": 0.06, "frequency": 1.6, "speed": 2.0, "phase": 2.1},
]

var current_time: float = 0.0
var water_area: Area3D
var water_material: ShaderMaterial
var bodies_in_water: Array[RigidBody3D] = []

func _ready() -> void:
	add_to_group("water")   # para que otros scripts nos encuentren
	_create_water_volume()
	water_area.body_entered.connect(_on_body_entered)
	water_area.body_exited.connect(_on_body_exited)

func _process(delta: float) -> void:
	current_time += delta
	if water_material:
		water_material.set_shader_parameter("world_time", current_time)

# --- API pública que usan otros scripts ---
func get_height_at(x: float, z: float) -> float:
	var h: float = 0.0
	var pos := Vector2(x, z)
	for w in wave_config:
		var k: float = w.frequency
		var phase: float = k * w.dir.dot(pos) - current_time * w.speed + w.phase
		h += w.amplitude * sin(phase)
	return h

func get_surface_y_at(x: float, z: float) -> float:
	return water_level + get_height_at(x, z)

# --- Construcción del agua ---
func _create_water_volume() -> void:
	# Material con shader
	water_material = ShaderMaterial.new()
	var shader: Shader = load("res://water.gdshader")
	water_material.shader = shader
	_push_waves_to_shader(water_material)

	# Superficie ondulada
	var surface := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(water_size.x, water_size.z)
	plane.subdivide_width = 64
	plane.subdivide_depth = 64
	surface.mesh = plane
	surface.material_override = water_material
	surface.position.y = water_level
	add_child(surface)

	# Volumen visual bajo la superficie (¡AHORA MUY TRANSPARENTE!)
	var volume := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(water_size.x, water_size.y, water_size.z)
	volume.mesh = box
	var vol_mat := StandardMaterial3D.new()
	vol_mat.albedo_color = Color(0.2, 0.7, 1.0, 0.15) # Transparencia alta para ver el fondo
	vol_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	volume.material_override = vol_mat
	volume.position.y = water_level - water_size.y * 0.5 - 0.05
	add_child(volume)

	# Área de detección
	water_area = Area3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(water_size.x, water_size.y + 1.0, water_size.z)
	col.shape = shape
	water_area.add_child(col)
	water_area.position.y = water_level + 0.5 - water_size.y * 0.5
	add_child(water_area)

func _push_waves_to_shader(mat: ShaderMaterial) -> void:
	for i in range(min(3, wave_config.size())):
		var w = wave_config[i]
		mat.set_shader_parameter("wave_dirs_%d" % i,
			Vector4(w.dir.x, w.dir.y, w.amplitude, w.frequency))
		mat.set_shader_parameter("wave_speed_%d" % i, w.speed)
		mat.set_shader_parameter("wave_phase_%d" % i, w.phase)

# --- Detección de cuerpos ---
func _on_body_entered(body: Node3D) -> void:
	if body is RigidBody3D and not bodies_in_water.has(body):
		bodies_in_water.append(body)

func _on_body_exited(body: Node3D) -> void:
	bodies_in_water.erase(body)

# --- Flotabilidad con 4 esquinas ---
func _physics_process(delta: float) -> void:
	for body in bodies_in_water:
		if is_instance_valid(body):
			_apply_buoyancy(body, delta)

func _apply_buoyancy(body: RigidBody3D, delta: float) -> void:
	var world_pos: Vector3 = body.global_position
	var body_basis: Basis = body.global_transform.basis
	var half: Vector3 = body.get_meta("half_extents", Vector3(1.0, 0.4, 1.0))

	var corners: Array[Vector3] = [
		body_basis.z * half.z + body_basis.x * half.x,
		body_basis.z * half.z - body_basis.x * half.x,
	   -body_basis.z * half.z + body_basis.x * half.x,
	   -body_basis.z * half.z - body_basis.x * half.x,
	]

	var total_force := Vector3.ZERO
	var total_torque := Vector3.ZERO
	var any_submerged := false
	var corner_force: float = max_buoyancy_force * 0.25
	var body_height: float = half.y * 2.0

	for off in corners:
		var p: Vector3 = world_pos + off
		var surface_y: float = get_surface_y_at(p.x, p.z)
		var bottom_y: float = p.y - half.y
		var sub: float = clampf((surface_y - bottom_y) / body_height, 0.0, 1.0)
		if sub <= 0.0:
			continue
		var force: Vector3 = Vector3.UP * corner_force * sub
		total_force += force
		total_torque += off.cross(force)
		any_submerged = true

	if not any_submerged:
		return

	body.apply_central_force(total_force)
	body.apply_torque(total_torque)
	body.apply_central_force(-body.linear_velocity * linear_drag)
	var angular_factor: float = 1.0 - clampf(angular_drag * delta, 0.0, 1.0)
	body.angular_velocity *= angular_factor
