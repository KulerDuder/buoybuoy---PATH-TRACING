# pathtracer_overlay.gd
extends Node

const CAMERA_MOVE_THRESHOLD_SQ := 0.0004
const CAMERA_ROT_THRESHOLD := 0.9999

@export var resolution_scale: float = 0.5
@export var samples_when_still: int = 4
@export var samples_when_moving: int = 2
@export var max_samples: int = 1024
@export var excluded_groups: Array[String] = ["water"]
@export var exposure: float = 1.0
@export var auto_scan: bool = true

@export_group("Agua")
@export var water_enabled: bool = true
@export var water_level: float = 0.0
@export var water_color: Color = Color(0.08, 0.28, 0.48)
@export var water_roughness: float = 0.15
@export var water_metalness: float = 0.65
@export var water_size: float = 500.0

var gpu: GPUResources
var _daynight_link: DayNightLink
var _dynamic_tracker: DynamicTracker
var _light_collector: LightCollector

var _resolution: Vector2i
var _needs_reset: bool = true
var _sample_count: int = 0
var _last_camera_xform: Transform3D = Transform3D()
var _samples_this_frame: int = 4
var _ready_ok: bool = false


func _ready():
	await get_tree().process_frame
	await get_tree().process_frame

	var vp := get_viewport()
	_resolution = Vector2i(int(vp.size.x * resolution_scale), int(vp.size.y * resolution_scale))
	_resolution.x = maxi(_resolution.x, 128); _resolution.y = maxi(_resolution.y, 128)

	gpu = GPUResources.new()
	if not gpu.initialize(_resolution, "res://pathtracer/pathtracer.glsl"): return
	gpu.show_output(self)

	_daynight_link = DayNightLink.new(self)
	_dynamic_tracker = DynamicTracker.new()
	_light_collector = LightCollector.new()
	_ready_ok = true

	if auto_scan:
		await get_tree().process_frame
		scan_and_upload()


func scan_and_upload():
	var t0 := Time.get_ticks_msec()
	var triangles: Array = SceneScanner.scan(get_tree().root, excluded_groups, true)
	var t1 := Time.get_ticks_msec()
	print("[PT] Scanner: ", t1 - t0, " ms, ", triangles.size(), " tris")
	if triangles.is_empty(): return

	if water_enabled:
		triangles.append_array(_build_water_quad())

	var bvh: Dictionary = BVHBuilder.build(triangles)
	var t2 := Time.get_ticks_msec()
	print("[PT] BVH: ", t2 - t1, " ms, ", bvh["node_count"], " nodos")

	gpu.upload_static_geometry(triangles, bvh)
	_needs_reset = true
	_sample_count = 0


func _build_water_quad() -> Array:
	var h: float = water_size; var lvl: float = water_level
	var n: Vector3 = Vector3(0.0, 1.0, 0.0); var c: Color = water_color; var r: float = water_roughness; var m: float = water_metalness
	var v0 := Vector3(-h, lvl, -h); var v1 := Vector3(h, lvl, -h); var v2 := Vector3(h, lvl, h); var v3 := Vector3(-h, lvl, h)
	return [
		{"v0": v0, "v1": v1, "v2": v2, "n0": n, "n1": n, "n2": n, "c0": c, "c1": c, "c2": c, "roughness": r, "metalness": m, "emission": Color.BLACK},
		{"v0": v0, "v1": v2, "v2": v3, "n0": n, "n1": n, "n2": n, "c0": c, "c1": c, "c2": c, "roughness": r, "metalness": m, "emission": Color.BLACK},
	]


func _process(_delta):
	if not _ready_ok: return
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null: return

	_dynamic_tracker.update(get_tree().root)
	gpu.update_dynamic_buffer(_dynamic_tracker.buffer_data)
	if _dynamic_tracker.has_movement: _needs_reset = true

	_light_collector.update(get_tree().root, cam.global_position)
	gpu.update_lights_buffer(_light_collector.buffer_data)
	if _light_collector.has_changed: _needs_reset = true

	_daynight_link.update()
	if _daynight_link.is_moving: _needs_reset = true

	var current_xform := cam.global_transform
	var pos_diff := current_xform.origin.distance_squared_to(_last_camera_xform.origin)
	var rot_diff := current_xform.basis.z.dot(_last_camera_xform.basis.z)
	if pos_diff > CAMERA_MOVE_THRESHOLD_SQ or rot_diff < CAMERA_ROT_THRESHOLD:
		_needs_reset = true; _last_camera_xform = current_xform

	_samples_this_frame = samples_when_moving if _needs_reset else samples_when_still
	if not _needs_reset and _sample_count >= max_samples: return

	gpu.update_params_buffer(_build_params_array(cam))
	gpu.dispatch()

	if _needs_reset:
		_needs_reset = false; _sample_count = _samples_this_frame
	else: _sample_count += _samples_this_frame


func _build_params_array(cam: Camera3D) -> PackedFloat32Array:
	var basis: Basis = cam.global_transform.basis
	var pos: Vector3 = cam.global_position
	var forward: Vector3 = -basis.z; var right: Vector3 = basis.x; var up: Vector3 = basis.y
	var is_ortho: bool = cam.projection == Camera3D.PROJECTION_ORTHOGONAL
	var tan_half: float = 0.0; var half_h: float = 0.0; var half_w: float = 0.0
	if is_ortho:
		half_h = cam.size * 0.5; half_w = half_h * (float(_resolution.x) / float(_resolution.y))
	else: tan_half = tan(deg_to_rad(cam.fov) * 0.5)

	var count_to_pass: int = 0 if _needs_reset else _sample_count
	var reset_flag: float = 1.0 if _needs_reset else 0.0

	var data := PackedFloat32Array()
	data.append_array([pos.x, pos.y, pos.z, 0.0])
	data.append_array([forward.x, forward.y, forward.z, 0.0])
	data.append_array([right.x, right.y, right.z, 0.0])
	data.append_array([up.x, up.y, up.z, 0.0])
	data.append_array([float(_resolution.x), float(_resolution.y), tan_half, 0.0])
	data.append_array([float(count_to_pass), reset_flag, float(_samples_this_frame), 1.0 if is_ortho else 0.0])
	data.append_array([half_h, half_w, 0.0, 0.0])
	data.append_array([_daynight_link.sun_dir.x, _daynight_link.sun_dir.y, _daynight_link.sun_dir.z, _daynight_link.sun_intensity])
	data.append_array([_daynight_link.sun_col.r, _daynight_link.sun_col.g, _daynight_link.sun_col.b, exposure])
	data.append_array([float(_dynamic_tracker.dyn_count), float(_light_collector.light_count), 0.0, 0.0])
	data.append_array([_daynight_link.moon_dir.x, _daynight_link.moon_dir.y, _daynight_link.moon_dir.z, _daynight_link.moon_intensity])
	data.append_array([_daynight_link.moon_col.r, _daynight_link.moon_col.g, _daynight_link.moon_col.b, _daynight_link.sun_height])
	data.append_array([_daynight_link.ambient_energy, 0.0, 0.0, 0.0])
	return data
