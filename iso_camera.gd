# iso_camera.gd
class_name IsoCamera
extends Camera3D

@export_group("Seguimiento")
@export var follow_speed: float = 4.0
@export var distance: float = 60.0
@export var camera_size: float = 60.0

@export_group("Rotación")
@export var mouse_sensitivity: float = 0.3
@export var min_pitch: float = 10.0   # Límite para no ponerse a ras de agua
@export var max_pitch: float = 80.0   # Límite para no ponerse cenital puro

@export_group("Zoom")
@export var zoom_step: float = 5.0    # Cuánto cambia el tamaño por cada "clic" de rueda
@export var min_size: float = 20.0    # Zoom máximo (más cerca)
@export var max_size: float = 150.0   # Zoom mínimo (más lejos)
@export var zoom_smoothness: float = 8.0 # Velocidad de la transición del zoom

var target: Node3D

# Ángulos de la órbita
var yaw: float = 45.0
var pitch: float = 35.264 # El ángulo isométrico perfecto

# Variable para el zoom suave
var target_size: float

func _ready() -> void:
	projection = Camera3D.PROJECTION_ORTHOGONAL
	size = camera_size
	target_size = camera_size
	near = 0.1
	far = 400.0

func _unhandled_input(event: InputEvent) -> void:
	# Rotar con el clic central (rueda) pulsado y arrastrando
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
		yaw -= event.relative.x * mouse_sensitivity
		pitch = clampf(pitch + event.relative.y * mouse_sensitivity, min_pitch, max_pitch)
		
	# Zoom con la rueda del ratón
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_size = clampf(target_size - zoom_step, min_size, max_size)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_size = clampf(target_size + zoom_step, min_size, max_size)

func _process(delta: float) -> void:
	# 1. Aplicar el zoom suavemente
	size = lerpf(size, target_size, clampf(zoom_smoothness * delta, 0.0, 1.0))
	
	# 2. Seguir al barco
	if not is_instance_valid(target): return
	
	var dir := _get_orbit_direction()
	var desired_pos: Vector3 = target.global_position + dir * distance
	var weight: float = clampf(follow_speed * delta, 0.0, 1.0)
	
	global_position = global_position.lerp(desired_pos, weight)
	look_at(target.global_position, Vector3.UP)

# Coloca la cámara instantáneamente en su sitio (sin lerp) al arrancar
func snap_to_target() -> void:
	if not is_instance_valid(target): return
	var dir := _get_orbit_direction()
	global_position = target.global_position + dir * distance
	look_at(target.global_position, Vector3.UP)

# Calcula el vector de dirección usando trigonometría esférica
func _get_orbit_direction() -> Vector3:
	var y_rad = deg_to_rad(pitch)
	var x_rad = deg_to_rad(yaw)
	return Vector3(
		sin(x_rad) * cos(y_rad),
		sin(y_rad),
		cos(x_rad) * cos(y_rad)
	).normalized()
