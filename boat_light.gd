# boat_light.gd
class_name BoatLight
extends Node3D

var _omni: OmniLight3D
var _spot: SpotLight3D
var _current_energy: float = 0.0
var is_light_on: bool = false

func _ready() -> void:
	# Luz de ambiente alrededor del barco (tipo farol)
	_omni = OmniLight3D.new()
	_omni.light_color = Color(1.0, 0.8, 0.5) # Cálido
	_omni.omni_range = 15.0
	_omni.light_energy = 0.0
	_omni.position = Vector3(0, 2.0, 0)
	add_child(_omni)
	
	# Foco delantero (tipo faro buscador)
	_spot = SpotLight3D.new()
	_spot.light_color = Color(1.0, 0.9, 0.7)
	_spot.spot_range = 30.0
	_spot.spot_angle = 45.0
	_spot.light_energy = 0.0
	_spot.position = Vector3(0, 0.5, 2.0) # En la proa
	_spot.rotation_degrees = Vector3(-10, 0, 0) # Ligeramente hacia abajo
	add_child(_spot)

func _unhandled_input(event: InputEvent) -> void:
	# Detectar la pulsación de la tecla "L"
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_L:
			is_light_on = not is_light_on

func _process(delta: float) -> void:
	# Si la luz está encendida, la energía objetivo es 1. Si está apagada, es 0.
	var target_energy := 1.0 if is_light_on else 0.0
	
	# Transición suave de encendido/apagado (como un efecto de encendido de farol)
	_current_energy = move_toward(_current_energy, target_energy, delta * 2.0)
	
	# Aplicamos la energía resultante
	_omni.light_energy = _current_energy * 2.0
	_spot.light_energy = _current_energy * 4.0
