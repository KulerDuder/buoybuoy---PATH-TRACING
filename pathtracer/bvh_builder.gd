# bvh_builder.gd
class_name BVHBuilder
extends RefCounted

const MAX_TRIS_PER_LEAF := 8
const FLOATS_PER_NODE := 12

static func build(triangles: Array) -> Dictionary:
	var n: int = triangles.size()
	if n == 0: return {"nodes_flat": PackedFloat32Array(), "tri_order": PackedInt32Array(), "depth": 0, "node_count": 0}

	var centroids := PackedFloat32Array(); centroids.resize(n * 3)
	var bbox_min := PackedFloat32Array(); var bbox_max := PackedFloat32Array()
	bbox_min.resize(n * 3); bbox_max.resize(n * 3)

	for i in range(n):
		var t: Dictionary = triangles[i]; var a: Vector3 = t.v0; var b: Vector3 = t.v1; var c: Vector3 = t.v2
		centroids[i * 3 + 0] = (a.x + b.x + c.x) / 3.0; centroids[i * 3 + 1] = (a.y + b.y + c.y) / 3.0; centroids[i * 3 + 2] = (a.z + b.z + c.z) / 3.0
		bbox_min[i * 3 + 0] = min(a.x, min(b.x, c.x)); bbox_min[i * 3 + 1] = min(a.y, min(b.y, c.y)); bbox_min[i * 3 + 2] = min(a.z, min(b.z, c.z))
		bbox_max[i * 3 + 0] = max(a.x, max(b.x, c.x)); bbox_max[i * 3 + 1] = max(a.y, max(b.y, c.y)); bbox_max[i * 3 + 2] = max(a.z, max(b.z, c.z))

	var tri_order := PackedInt32Array(); tri_order.resize(n)
	for i in range(n): tri_order[i] = i

	var nodes_flat := PackedFloat32Array()
	var depth_tracker: Array = [0]
	_build_recursive(nodes_flat, tri_order, centroids, bbox_min, bbox_max, 0, n, 0, depth_tracker)

	return {"nodes_flat": nodes_flat, "tri_order": tri_order, "depth": depth_tracker[0], "node_count": int(nodes_flat.size() / float(FLOATS_PER_NODE))}

static func _build_recursive(nodes_flat: PackedFloat32Array, tri_order: PackedInt32Array, centroids: PackedFloat32Array, bbox_min: PackedFloat32Array, bbox_max: PackedFloat32Array, start: int, end: int, depth: int, depth_tracker: Array) -> int:
	var my_idx: int = int(nodes_flat.size() / float(FLOATS_PER_NODE)) # Corregido
	if depth > depth_tracker[0]: depth_tracker[0] = depth

	var mnx: float = 1e30; var mny: float = 1e30; var mnz: float = 1e30
	var mxx: float = -1e30; var mxy: float = -1e30; var mxz: float = -1e30
	for i in range(start, end):
		var t: int = tri_order[i]; var b: int = t * 3
		if bbox_min[b] < mnx: mnx = bbox_min[b]
		if bbox_min[b + 1] < mny: mny = bbox_min[b + 1]
		if bbox_min[b + 2] < mnz: mnz = bbox_min[b + 2]
		if bbox_max[b] > mxx: mxx = bbox_max[b]
		if bbox_max[b + 1] > mxy: mxy = bbox_max[b + 1]
		if bbox_max[b + 2] > mxz: mxz = bbox_max[b + 2]

	var count: int = end - start
	if count <= MAX_TRIS_PER_LEAF:
		nodes_flat.append_array([mnx, mny, mnz, float(count), mxx, mxy, mxz, 1.0, 0.0, 0.0, float(start), 0.0])
		return my_idx

	var sx: float = mxx - mnx; var sy: float = mxy - mny; var sz: float = mxz - mnz
	var axis: int = 0
	if sy > sx and sy >= sz: axis = 1
	elif sz > sx and sz > sy: axis = 2

	var mid: int = _partition(tri_order, centroids, start, end, axis)
	if mid <= start or mid >= end:
		mid = (start + end) >> 1
		if mid == start: mid = start + 1

	nodes_flat.append_array([mnx, mny, mnz, 0.0, mxx, mxy, mxz, 0.0, 0.0, 0.0, 0.0, 0.0])
	var left_idx: int = _build_recursive(nodes_flat, tri_order, centroids, bbox_min, bbox_max, start, mid, depth + 1, depth_tracker)
	var right_idx: int = _build_recursive(nodes_flat, tri_order, centroids, bbox_min, bbox_max, mid, end, depth + 1, depth_tracker)
	nodes_flat[my_idx * FLOATS_PER_NODE + 8] = float(left_idx)
	nodes_flat[my_idx * FLOATS_PER_NODE + 9] = float(right_idx)
	return my_idx

static func _partition(tri_order: PackedInt32Array, centroids: PackedFloat32Array, start: int, end: int, axis: int) -> int:
	var a_idx: int = tri_order[start]; var b_idx: int = tri_order[end - 1]; var m_idx: int = tri_order[(start + end) >> 1]
	var va: float = centroids[a_idx * 3 + axis]; var vb: float = centroids[b_idx * 3 + axis]; var vm: float = centroids[m_idx * 3 + axis]
	var pivot: float
	if (va < vm and vm < vb) or (vb < vm and vm < va): pivot = vm
	elif (vm < va and va < vb) or (vb < va and va < vm): pivot = va
	else: pivot = vb

	var i: int = start; var j: int = end - 1
	while true:
		while centroids[tri_order[i] * 3 + axis] < pivot: i += 1
		while centroids[tri_order[j] * 3 + axis] > pivot: j -= 1
		if i >= j: break
		var tmp: int = tri_order[i]; tri_order[i] = tri_order[j]; tri_order[j] = tmp
		i += 1; j -= 1

	if i == start: return (start + end) >> 1
	if i >= end: return (start + end) >> 1
	return i
