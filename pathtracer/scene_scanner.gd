# scene_scanner.gd
class_name SceneScanner
extends RefCounted

static func scan(root: Node, exclude_groups: Array[String] = ["water"], exclude_dynamic: bool = true) -> Array:
	var mesh_instances: Array[MeshInstance3D] = []
	_collect_mesh_instances(root, mesh_instances)
	print("[SceneScanner] MeshInstance3D encontrados: ", mesh_instances.size())

	var triangles: Array = []
	var skipped_invisible: int = 0
	var skipped_camera: int = 0
	var skipped_dynamic: int = 0
	var _skipped_group: int = 0 # Corregido: prefijo _ para evitar warning
	for mi in mesh_instances:
		if not mi.is_visible_in_tree():
			skipped_invisible += 1
			continue
		if _has_ancestor_camera(mi):
			skipped_camera += 1
			continue
		if exclude_dynamic and _has_ancestor_dynamic(mi):
			skipped_dynamic += 1
			continue
		if _has_ancestor_in_groups(mi, exclude_groups):
			_skipped_group += 1
			continue
		_process_mesh_instance(mi, triangles)

	print("[SceneScanner] Triángulos estáticos: ", triangles.size(),
		" (inv:", skipped_invisible, " cam:", skipped_camera, " dyn:", skipped_dynamic, ")")
	return triangles

static func _collect_mesh_instances(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D: out.append(node)
	for child in node.get_children(): _collect_mesh_instances(child, out)

static func _has_ancestor_camera(node: Node) -> bool:
	var p: Node = node
	while p != null:
		if p is Camera3D: return true
		p = p.get_parent()
	return false

static func _has_ancestor_dynamic(node: Node) -> bool:
	var p: Node = node
	while p != null:
		if p is RigidBody3D or p is CharacterBody3D or p is AnimatableBody3D: return true
		p = p.get_parent()
	return false

static func _has_ancestor_in_groups(node: Node, groups: Array[String]) -> bool:
	var p: Node = node
	while p != null:
		for g in groups:
			if p.is_in_group(g): return true
		p = p.get_parent()
	return false

static func _process_mesh_instance(mi: MeshInstance3D, out_tris: Array) -> void:
	if mi.mesh == null: return
	var mesh: Mesh = mi.mesh
	var xform: Transform3D = mi.global_transform
	var basis: Basis = xform.basis

	for surf_idx in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(surf_idx)
		if arrays.is_empty(): continue
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		if verts.size() == 0: continue

		var normals: PackedVector3Array = PackedVector3Array()
		if arrays[Mesh.ARRAY_NORMAL] != null: normals = arrays[Mesh.ARRAY_NORMAL]
		var colors: PackedColorArray = PackedColorArray()
		if arrays[Mesh.ARRAY_COLOR] != null: colors = arrays[Mesh.ARRAY_COLOR]

		var indices_variant = arrays[Mesh.ARRAY_INDEX]
		var indices: PackedInt32Array = PackedInt32Array()
		if indices_variant != null: indices = indices_variant
		else:
			indices.resize(verts.size())
			for i in range(verts.size()): indices[i] = i

		var mat: Material = _get_material(mesh, mi, surf_idx)
		var albedo: Color = Color(0.8, 0.8, 0.8)
		var roughness: float = 0.9
		var metalness: float = 0.0
		var use_vcol: bool = false
		var emission: Color = Color.BLACK
		
		if mat is StandardMaterial3D:
			albedo = mat.albedo_color; roughness = mat.roughness; metalness = mat.metallic
			use_vcol = mat.vertex_color_use_as_albedo
			if mat.emission_enabled: emission = mat.emission * mat.emission_energy_multiplier

		var has_normals: bool = normals.size() == verts.size()
		var has_colors: bool = colors.size() == verts.size()

		var i: int = 0
		while i + 2 < indices.size():
			var ia: int = indices[i]; var ib: int = indices[i + 1]; var ic: int = indices[i + 2]
			i += 3
			if ia >= verts.size() or ib >= verts.size() or ic >= verts.size(): continue

			var va: Vector3 = xform * verts[ia]; var vb: Vector3 = xform * verts[ib]; var vc: Vector3 = xform * verts[ic]
			var na: Vector3 = Vector3.UP; var nb: Vector3 = Vector3.UP; var nc: Vector3 = Vector3.UP
			if has_normals:
				na = (basis * normals[ia]).normalized(); nb = (basis * normals[ib]).normalized(); nc = (basis * normals[ic]).normalized()

			var ca: Color = albedo; var cb: Color = albedo; var cc: Color = albedo
			if use_vcol and has_colors:
				ca = colors[ia]; cb = colors[ib]; cc = colors[ic]

			out_tris.append({
				"v0": va, "v1": vb, "v2": vc, "n0": na, "n1": nb, "n2": nc,
				"c0": ca, "c1": cb, "c2": cc, "roughness": roughness, "metalness": metalness,
				"emission": emission
			})

static func _get_material(mesh: Mesh, mi: MeshInstance3D, surf_idx: int) -> Material:
	if mi.material_override != null: return mi.material_override
	if surf_idx < mi.get_surface_override_material_count():
		var over: Material = mi.get_surface_override_material(surf_idx)
		if over != null: return over
	return mesh.surface_get_material(surf_idx)
