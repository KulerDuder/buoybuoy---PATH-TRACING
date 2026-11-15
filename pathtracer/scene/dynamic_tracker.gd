# dynamic_tracker.gd
class_name DynamicTracker
extends RefCounted

const MAX_DYNAMIC = 32
const DYN_FLOATS = 36 # Aumentado de 32 a 36 para la emisión
const MOVEMENT_THRESHOLD_SQ := 0.05

var dyn_count: int = 0
var buffer_data: PackedFloat32Array = PackedFloat32Array()
var has_movement: bool = false
var _prev_state: Array = []


func update(root: Node) -> void:
	var meshes: Array[MeshInstance3D] = _find_dynamic_meshes(root)
	var count: int = mini(meshes.size(), MAX_DYNAMIC)
	dyn_count = count
	buffer_data.resize(MAX_DYNAMIC * DYN_FLOATS)
	var state: Array = []
	has_movement = false

	for i in range(count):
		var mi: MeshInstance3D = meshes[i]
		var xform: Transform3D = mi.global_transform
		var pos: Vector3 = xform.origin
		var r0: Vector3 = xform.basis.x
		var r1: Vector3 = xform.basis.y
		var r2: Vector3 = xform.basis.z
		state.append(pos)

		var aabb: AABB = mi.mesh.get_aabb()
		var albedo: Color = Color(0.7, 0.7, 0.7)
		var roughness: float = 0.9
		var metalness: float = 0.0
		var emission: Color = Color.BLACK
		
		if mi.material_override is StandardMaterial3D:
			var m: StandardMaterial3D = mi.material_override
			albedo = m.albedo_color; roughness = m.roughness; metalness = m.metallic
			if m.emission_enabled: emission = m.emission * m.emission_energy_multiplier
		elif mi.mesh.get_surface_count() > 0:
			var m2: Material = mi.mesh.surface_get_material(0)
			if m2 is StandardMaterial3D:
				var m: StandardMaterial3D = m2
				albedo = m.albedo_color; roughness = m.roughness; metalness = m.metallic
				if m.emission_enabled: emission = m.emission * m.emission_energy_multiplier

		var shape_type: float = 0.0
		var radius: float = 0.0
		if mi.has_meta("pt_sphere") and mi.get_meta("pt_sphere") == true:
			shape_type = 1.0
			radius = mi.get_meta("pt_radius", aabb.size.length() * 0.5)

		var b: int = i * DYN_FLOATS
		buffer_data[b + 0] = pos.x; buffer_data[b + 1] = pos.y; buffer_data[b + 2] = pos.z; buffer_data[b + 3] = shape_type
		buffer_data[b + 4] = r0.x; buffer_data[b + 5] = r0.y; buffer_data[b + 6] = r0.z; buffer_data[b + 7] = roughness
		buffer_data[b + 8] = r1.x; buffer_data[b + 9] = r1.y; buffer_data[b + 10] = r1.z; buffer_data[b + 11] = metalness
		buffer_data[b + 12] = r2.x; buffer_data[b + 13] = r2.y; buffer_data[b + 14] = r2.z; buffer_data[b + 15] = radius
		buffer_data[b + 16] = aabb.position.x; buffer_data[b + 17] = aabb.position.y; buffer_data[b + 18] = aabb.position.z; buffer_data[b + 19] = 0.0
		buffer_data[b + 20] = aabb.position.x + aabb.size.x; buffer_data[b + 21] = aabb.position.y + aabb.size.y; buffer_data[b + 22] = aabb.position.z + aabb.size.z; buffer_data[b + 23] = 0.0
		buffer_data[b + 24] = albedo.r; buffer_data[b + 25] = albedo.g; buffer_data[b + 26] = albedo.b; buffer_data[b + 27] = 0.0
		buffer_data[b + 28] = emission.r; buffer_data[b + 29] = emission.g; buffer_data[b + 30] = emission.b; buffer_data[b + 31] = 0.0

	if state.size() != _prev_state.size():
		has_movement = true
	else:
		for i in range(state.size()):
			if state[i].distance_squared_to(_prev_state[i]) > MOVEMENT_THRESHOLD_SQ:
				has_movement = true
				break
	_prev_state = state


func _find_dynamic_meshes(root: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	_collect_dynamic_meshes(root, result)
	return result


func _collect_dynamic_meshes(node: Node, out: Array[MeshInstance3D]) -> void:
	# Buscar dentro de cuerpos físicos
	if node is RigidBody3D or node is CharacterBody3D or node is AnimatableBody3D:
		_collect_meshes_under(node, out)
		return
	
	# Buscar meshes explícitamente marcados como dinámicos
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.is_in_group("pt_dynamic") and mi.mesh != null and mi.is_visible_in_tree():
			if not out.has(mi):
				out.append(mi)
				
	for child in node.get_children():
		_collect_dynamic_meshes(child, out)


func _collect_meshes_under(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh != null and mi.is_visible_in_tree() and not out.has(mi):
			out.append(mi)
		return
	for child in node.get_children():
		_collect_meshes_under(child, out)
