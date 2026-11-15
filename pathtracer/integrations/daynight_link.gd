# daynight_link.gd
class_name DayNightLink
extends RefCounted

var _daynight: Node = null

# Datos astronómicos por defecto (si no hay daynight)
var sun_dir: Vector3 = Vector3(0.6, 1.0, 0.4).normalized()
var sun_col: Color = Color(1.0, 0.95, 0.85)
var sun_intensity: float = 1.5
var moon_dir: Vector3 = Vector3(-0.6, -1.0, -0.4).normalized()
var moon_col: Color = Color(0.55, 0.65, 1.00)
var moon_intensity: float = 0.0
var ambient_energy: float = 0.8
var sun_height: float = 1.0
var is_moving: bool = false


func _init(root: Node):
	_daynight = root.get_tree().get_first_node_in_group("dayandnight")
	if _daynight:
		print("[PT] Conectado al ciclo Día/Noche.")
	else:
		print("[PT] Advertencia: No se encontró nodo 'dayandnight'. Usando sol fijo.")


func update():
	if _daynight == null:
		is_moving = false
		return

	is_moving = not _daynight.paused
	sun_height = sin(_daynight.time_of_day * TAU - PI * 0.5)
	
	var sun_node = _daynight.get_node_or_null("Sun")
	var moon_node = _daynight.get_node_or_null("Moon")
	
	if sun_node:
		sun_dir = -sun_node.global_transform.basis.z
		sun_col = sun_node.light_color
		sun_intensity = sun_node.light_energy
	if moon_node:
		moon_dir = -moon_node.global_transform.basis.z
		moon_col = moon_node.light_color
		moon_intensity = moon_node.light_energy
		
	var day_amount = smoothstep(-0.1, 0.3, sun_height)
	ambient_energy = lerp(_daynight.ambient_night_energy, _daynight.ambient_day_energy, day_amount)
