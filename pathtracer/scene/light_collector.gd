# light_collector.gd
class_name LightCollector
extends RefCounted

const MAX_LIGHTS = 16
const FLOATS_PER_LIGHT = 12

var light_count: int = 0
var buffer_data: PackedFloat32Array = PackedFloat32Array()
var has_changed: bool = false # Reemplaza el flag -1

var _prev_lights_state: Array = []

func update(root: Node, cam_pos: Vector3) -> void:
	var lights: Array[Light3D] = []
	_collect_lights(root, lights)
	
	# Ordenar por cercanía a la cámara
	lights.sort_custom(func(a, b): return a.global_position.distance_squared_to(cam_pos) < b.global_position.distance_squared_to(cam_pos))
	
	light_count = mini(lights.size(), MAX_LIGHTS)
	buffer_data.resize(MAX_LIGHTS * FLOATS_PER_LIGHT)
	
	var state: Array = []
	
	for i in range(light_count):
		var light: Light3D = lights[i]
		var pos: Vector3 = light.global_position
		var energy: float = light.light_energy
		
		state.append(pos)
		state.append(energy)
		
		var b: int = i * FLOATS_PER_LIGHT
		var type: float = 0.0; var range_val: float = 0.0; var spot_angle_cos: float = -1.0
		var dir: Vector3 = Vector3(0, -1, 0)
		
		if light is OmniLight3D:
			type = 0.0; range_val = light.omni_range
		elif light is SpotLight3D:
			type = 1.0; range_val = light.spot_range
			dir = -light.global_transform.basis.z
			spot_angle_cos = cos(deg_to_rad(light.spot_angle))
			
		var col: Color = light.light_color * energy
		
		buffer_data[b + 0] = pos.x; buffer_data[b + 1] = pos.y; buffer_data[b + 2] = pos.z; buffer_data[b + 3] = type
		buffer_data[b + 4] = col.r; buffer_data[b + 5] = col.g; buffer_data[b + 6] = col.b; buffer_data[b + 7] = range_val
		buffer_data[b + 8] = dir.x; buffer_data[b + 9] = dir.y; buffer_data[b + 10] = dir.z; buffer_data[b + 11] = spot_angle_cos

	has_changed = false
	if state.size() != _prev_lights_state.size():
		has_changed = true
	else:
		for i in range(state.size()):
			if state[i] is Vector3 and state[i].distance_squared_to(_prev_lights_state[i]) > 0.05:
				has_changed = true; break
			elif state[i] is float and abs(state[i] - _prev_lights_state[i]) > 0.5:
				has_changed = true; break
	_prev_lights_state = state

func _collect_lights(node: Node, out: Array[Light3D]) -> void:
	if node is OmniLight3D or node is SpotLight3D:
		var light := node as Light3D
		if light.is_visible_in_tree() and light.light_energy > 0.01: out.append(light)
	for child in node.get_children(): _collect_lights(child, out)
