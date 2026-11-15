# gpu_resources.gd
class_name GPUResources
extends RefCounted

const WORKGROUP_SIZE = 8
const VECS_PER_TRI = 10

var rd: RenderingDevice
var shader: RID; var pipeline: RID
var output_texture: RID; var accum_texture: RID; var uniform_set: RID
var params_buffer: RID; var tri_buffer: RID; var bvh_buffer: RID; var order_buffer: RID
var dyn_buffer: RID; var light_buffer: RID
var texture_rd: Texture2DRD; var texture_rect: TextureRect
var resolution: Vector2i
var _has_geometry: bool = false # Evita el crash al liberar el RID dummy

func initialize(res: Vector2i, shader_path: String) -> bool:
	resolution = res
	rd = RenderingServer.get_rendering_device()
	if rd == null: return false
	if not _setup_pipeline(shader_path): return false
	_setup_textures()
	_setup_buffers()
	_update_uniform_set()
	return true

func _setup_pipeline(shader_path: String) -> bool:
	var shader_file = load(shader_path)
	if shader_file == null: return false
	shader = rd.shader_create_from_spirv(shader_file.get_spirv())
	pipeline = rd.compute_pipeline_create(shader)
	return true

func _setup_textures():
	var fmt := RDTextureFormat.new()
	fmt.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
	fmt.width = resolution.x; fmt.height = resolution.y
	fmt.usage_bits = (RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT)
	output_texture = rd.texture_create(fmt, RDTextureView.new()); accum_texture = rd.texture_create(fmt, RDTextureView.new())

func _setup_buffers():
	params_buffer = rd.uniform_buffer_create(224, PackedByteArray())
	var dummy_f := PackedFloat32Array([0.0, 0.0, 0.0, 0.0]).to_byte_array()
	tri_buffer = rd.storage_buffer_create(dummy_f.size(), dummy_f)
	bvh_buffer = rd.storage_buffer_create(dummy_f.size(), dummy_f)
	var dummy_i := PackedInt32Array([0]).to_byte_array()
	order_buffer = rd.storage_buffer_create(dummy_i.size(), dummy_i)
	
	var dyn_empty := PackedFloat32Array(); dyn_empty.resize(DynamicTracker.MAX_DYNAMIC * DynamicTracker.DYN_FLOATS)
	dyn_buffer = rd.storage_buffer_create(dyn_empty.to_byte_array().size(), dyn_empty.to_byte_array())
	
	var light_empty := PackedFloat32Array(); light_empty.resize(LightCollector.MAX_LIGHTS * LightCollector.FLOATS_PER_LIGHT)
	light_buffer = rd.storage_buffer_create(light_empty.to_byte_array().size(), light_empty.to_byte_array())

func show_output(parent: Node):
	texture_rd = Texture2DRD.new(); texture_rd.texture_rd_rid = output_texture
	var canvas_layer := CanvasLayer.new(); canvas_layer.layer = 0; parent.add_child(canvas_layer)
	texture_rect = TextureRect.new(); texture_rect.texture = texture_rd
	texture_rect.set_anchors_preset(Control.PRESET_FULL_RECT); texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	canvas_layer.add_child(texture_rect)

func upload_static_geometry(triangles: Array, bvh: Dictionary):
	var data := PackedFloat32Array(); data.resize(triangles.size() * VECS_PER_TRI * 4)
	var idx := 0
	for t in triangles:
		var v0: Vector3 = t.v0; var v1: Vector3 = t.v1; var v2: Vector3 = t.v2
		var n0: Vector3 = t.n0; var n1: Vector3 = t.n1; var n2: Vector3 = t.n2
		var c0: Color = t.c0; var c1: Color = t.c1; var c2: Color = t.c2
		var r: float = t.roughness; var m: float = t.metalness; var em: Color = t.emission
		data[idx + 0] = v0.x; data[idx + 1] = v0.y; data[idx + 2] = v0.z; data[idx + 3] = 0.0
		data[idx + 4] = v1.x; data[idx + 5] = v1.y; data[idx + 6] = v1.z; data[idx + 7] = 0.0
		data[idx + 8] = v2.x; data[idx + 9] = v2.y; data[idx + 10] = v2.z; data[idx + 11] = 0.0
		data[idx + 12] = n0.x; data[idx + 13] = n0.y; data[idx + 14] = n0.z; data[idx + 15] = 0.0
		data[idx + 16] = n1.x; data[idx + 17] = n1.y; data[idx + 18] = n1.z; data[idx + 19] = 0.0
		data[idx + 20] = n2.x; data[idx + 21] = n2.y; data[idx + 22] = n2.z; data[idx + 23] = 0.0
		data[idx + 24] = c0.r; data[idx + 25] = c0.g; data[idx + 26] = c0.b; data[idx + 27] = r
		data[idx + 28] = c1.r; data[idx + 29] = c1.g; data[idx + 30] = c1.b; data[idx + 31] = m
		data[idx + 32] = c2.r; data[idx + 33] = c2.g; data[idx + 34] = c2.b; data[idx + 35] = 0.0
		data[idx + 36] = em.r; data[idx + 37] = em.g; data[idx + 38] = em.b; data[idx + 39] = 0.0
		idx += 40

	var tri_bytes := data.to_byte_array()
	if _has_geometry and tri_buffer.is_valid(): rd.free_rid(tri_buffer)
	tri_buffer = rd.storage_buffer_create(tri_bytes.size(), tri_bytes)

	var bvh_bytes: PackedByteArray = bvh["nodes_flat"].to_byte_array()
	if _has_geometry and bvh_buffer.is_valid(): rd.free_rid(bvh_buffer)
	bvh_buffer = rd.storage_buffer_create(bvh_bytes.size(), bvh_bytes)

	var order_bytes: PackedByteArray = bvh["tri_order"].to_byte_array()
	if _has_geometry and order_buffer.is_valid(): rd.free_rid(order_buffer)
	order_buffer = rd.storage_buffer_create(order_bytes.size(), order_bytes)

	_has_geometry = true
	if uniform_set.is_valid(): rd.free_rid(uniform_set)
	_update_uniform_set()

func update_dynamic_buffer(data: PackedFloat32Array):
	rd.buffer_update(dyn_buffer, 0, data.to_byte_array().size(), data.to_byte_array())

func update_lights_buffer(data: PackedFloat32Array):
	rd.buffer_update(light_buffer, 0, data.to_byte_array().size(), data.to_byte_array())

func update_params_buffer(data: PackedFloat32Array):
	rd.buffer_update(params_buffer, 0, data.to_byte_array().size(), data.to_byte_array())

func dispatch():
	if uniform_set.is_valid():
		var cl := rd.compute_list_begin()
		rd.compute_list_bind_compute_pipeline(cl, pipeline)
		rd.compute_list_bind_uniform_set(cl, uniform_set, 0)
		var gx := int(ceil(float(resolution.x) / float(WORKGROUP_SIZE)))
		var gy := int(ceil(float(resolution.y) / float(WORKGROUP_SIZE)))
		rd.compute_list_dispatch(cl, gx, gy, 1)
		rd.compute_list_end()

func _update_uniform_set():
	var u_img := RDUniform.new(); u_img.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE; u_img.binding = 0; u_img.add_id(output_texture)
	var u_params := RDUniform.new(); u_params.uniform_type = RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER; u_params.binding = 1; u_params.add_id(params_buffer)
	var u_tris := RDUniform.new(); u_tris.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER; u_tris.binding = 2; u_tris.add_id(tri_buffer)
	var u_accum := RDUniform.new(); u_accum.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE; u_accum.binding = 3; u_accum.add_id(accum_texture)
	var u_bvh := RDUniform.new(); u_bvh.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER; u_bvh.binding = 4; u_bvh.add_id(bvh_buffer)
	var u_order := RDUniform.new(); u_order.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER; u_order.binding = 5; u_order.add_id(order_buffer)
	var u_dyn := RDUniform.new(); u_dyn.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER; u_dyn.binding = 6; u_dyn.add_id(dyn_buffer)
	var u_light := RDUniform.new(); u_light.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER; u_light.binding = 7; u_light.add_id(light_buffer)
	uniform_set = rd.uniform_set_create([u_img, u_params, u_tris, u_accum, u_bvh, u_order, u_dyn, u_light], shader, 0)
