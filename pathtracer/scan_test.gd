# scan_test.gd
# Nodo temporal para validar el scanner y la BVH. NO forma parte del juego final.
extends Node

func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	print("========== TEST DE SCANNER ==========")
	var t0: int = Time.get_ticks_msec()
	var triangles: Array = SceneScanner.scan(get_tree().root, ["water"])
	var t1: int = Time.get_ticks_msec()
	print("[Scanner] Tiempo: ", t1 - t0, " ms")

	# Desglose por mesh: los 5 más pesados
	var mesh_instances: Array[MeshInstance3D] = []
	SceneScanner._collect_mesh_instances(get_tree().root, mesh_instances)
	var counts: Array = []
	for mi in mesh_instances:
		if not mi.is_visible_in_tree():
			continue
		if SceneScanner._is_excluded(mi, ["water"]):
			continue
		if mi.mesh == null:
			continue
		var tri_count: int = 0
		for s in range(mi.mesh.get_surface_count()):
			var arrays: Array = mi.mesh.surface_get_arrays(s)
			if arrays.is_empty():
				continue
			var idx = arrays[Mesh.ARRAY_INDEX]
			if idx != null:
				tri_count += idx.size() / 3
			else:
				tri_count += arrays[Mesh.ARRAY_VERTEX].size() / 3
		counts.append({"name": mi.name, "count": tri_count})
	counts.sort_custom(func(a, b): return a.count > b.count)
	print("[Scanner] Top 5 mallas más pesadas:")
	for i in range(min(5, counts.size())):
		print("    ", i + 1, ") ", counts[i].name, " = ", counts[i].count, " tris")

	var t2: int = Time.get_ticks_msec()
	var bvh: Dictionary = BVHBuilder.build(triangles)
	var t3: int = Time.get_ticks_msec()
	print("[BVH] Tiempo: ", t3 - t2, " ms")
	print("[BVH] Nodos: ", bvh["node_count"])
	print("[BVH] Profundidad máxima: ", bvh["depth"])
	print("=====================================")
