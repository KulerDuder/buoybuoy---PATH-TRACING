# dayandnight.gd
extends Node3D

const SKY_SHADER := preload("res://sky_with_stars.gdshader")
const STARS_SHADER := preload("res://stars_quad.gdshader")

@export_group("Ciclo")
@export var day_duration_seconds: float = 120.0
@export_range(0.0, 1.0) var time_of_day: float = 0.35
@export var paused: bool = false

@export_group("Cielo — Día")
@export var sky_top_day: Color = Color(0.30, 0.55, 0.90)
@export var sky_horizon_day: Color = Color(0.70, 0.85, 0.95)

@export_group("Cielo — Noche")
@export var sky_top_night: Color = Color(0.02, 0.02, 0.06)
@export var sky_horizon_night: Color = Color(0.05, 0.08, 0.15)

@export_group("Cielo — Crepúsculo")
@export var sky_twilight: Color = Color(1.00, 0.45, 0.20)

@export_group("Estrellas")
@export_range(50.0, 800.0) var star_grid_scale: float = 200.0
@export_range(0.80, 1.0) var star_density: float = 0.985
@export_range(0.05, 0.5) var star_size: float = 0.25
@export_range(0.0, 5.0) var star_brightness: float = 2.5
@export var stars_quad_size: float = 40.0
@export var stars_quad_distance: float = 180.0

@export_group("Sol")
@export var sun_max_energy: float = 1.5
@export var sun_day_color: Color = Color(1.00, 0.95, 0.85)
@export var sun_horizon_color: Color = Color(1.00, 0.55, 0.25)

@export_group("Luna")
@export var moon_max_energy: float = 0.35
@export var moon_color: Color = Color(0.55, 0.65, 1.00)

@export_group("Ambiente")
@export var ambient_day_energy: float = 0.8
@export var ambient_night_energy: float = 0.10
@export var fog_density: float = 0.004

var _sun: DirectionalLight3D
var _moon: DirectionalLight3D
var _world_env: WorldEnvironment
var _env: Environment
var _sky_mat: ShaderMaterial
var _stars_mat: ShaderMaterial
var _stars_quad: MeshInstance3D

func _ready() -> void:
	add_to_group("dayandnight")
	_create_lights()
	_create_environment()
	_create_stars_layer()
	_update()

func _process(delta: float) -> void:
	if paused:
		return
	time_of_day = fmod(time_of_day + delta / day_duration_seconds, 1.0)
	_update()

# ============================================================
#  CONSTRUCCIÓN
# ============================================================
func _create_lights() -> void:
	_sun = DirectionalLight3D.new()
	_sun.name = "Sun"
	_sun.shadow_enabled = true
	_sun.directional_shadow_max_distance = 80.0
	_sun.shadow_bias = 0.05
	add_child(_sun)

	_moon = DirectionalLight3D.new()
	_moon.name = "Moon"
	_moon.shadow_enabled = true
	_moon.directional_shadow_max_distance = 80.0
	_moon.shadow_bias = 0.05
	add_child(_moon)

func _create_environment() -> void:
	_sky_mat = ShaderMaterial.new()
	_sky_mat.shader = SKY_SHADER

	var sky := Sky.new()
	sky.sky_material = _sky_mat

	_env = Environment.new()
	_env.background_mode = Environment.BG_SKY
	_env.sky = sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_env.ambient_light_energy = ambient_day_energy
	_env.tonemap_mode = Environment.TONE_MAPPER_ACES
	_env.glow_enabled = true
	_env.glow_intensity = 0.35
	_env.glow_bloom = 0.10
	_env.glow_hdr_threshold = 1.1
	_env.fog_enabled = true
	_env.fog_density = fog_density

	_world_env = WorldEnvironment.new()
	_world_env.name = "WorldEnvironment"
	_world_env.environment = _env
	add_child(_world_env)

func _create_stars_layer() -> void:
	# Esperar un frame para que la cámara del player exista y sea la activa
	await get_tree().process_frame
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		await get_tree().process_frame
		cam = get_viewport().get_camera_3d()
	if cam == null:
		push_warning("dayandnight.gd: no se encontró la cámara para las estrellas")
		return

	_stars_mat = ShaderMaterial.new()
	_stars_mat.shader = STARS_SHADER

	_stars_quad = MeshInstance3D.new()
	_stars_quad.name = "StarsLayer"
	var quad := QuadMesh.new()
	quad.size = Vector2(stars_quad_size, stars_quad_size)
	_stars_quad.mesh = quad
	_stars_quad.material_override = _stars_mat
	_stars_quad.position = Vector3(0, 0, -stars_quad_distance)
	_stars_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cam.add_child(_stars_quad)

# ============================================================
#  ACTUALIZACIÓN
# ============================================================
func _update() -> void:
	var sun_angle: float = time_of_day * TAU - PI * 0.5
	var sun_height: float = sin(sun_angle)

	var day_amount: float = smoothstep(-0.1, 0.3, sun_height)
	var twilight_amount: float = 1.0 - smoothstep(0.0, 0.4, abs(sun_height))
	var star_alpha: float = 1.0 - smoothstep(-0.05, 0.2, sun_height)

	# --- SOL ---
	_sun.rotation = Vector3(deg_to_rad(-90.0 * sun_height), deg_to_rad(-45.0), 0.0)
	_sun.light_energy = smoothstep(-0.05, 0.25, sun_height) * sun_max_energy
	_sun.light_color = sun_horizon_color.lerp(sun_day_color, smoothstep(0.0, 0.3, sun_height))
	_sun.visible = sun_height > -0.15

	# --- LUNA ---
	_moon.rotation = Vector3(deg_to_rad(90.0 * sun_height), deg_to_rad(135.0), 0.0)
	_moon.light_energy = smoothstep(-0.05, 0.25, -sun_height) * moon_max_energy
	_moon.light_color = moon_color
	_moon.visible = sun_height < 0.15

	# --- AMBIENTE ---
	_env.ambient_light_energy = lerp(ambient_night_energy, ambient_day_energy, day_amount)
	_env.fog_light_color = sky_horizon_night.lerp(sky_horizon_day, day_amount)

	# --- SKY SHADER ---
	_sky_mat.set_shader_parameter("sky_top_day", sky_top_day)
	_sky_mat.set_shader_parameter("sky_horizon_day", sky_horizon_day)
	_sky_mat.set_shader_parameter("sky_top_night", sky_top_night)
	_sky_mat.set_shader_parameter("sky_horizon_night", sky_horizon_night)
	_sky_mat.set_shader_parameter("sky_twilight", sky_twilight)
	_sky_mat.set_shader_parameter("day_amount", day_amount)
	_sky_mat.set_shader_parameter("twilight_amount", twilight_amount)

	var sun_dir: Vector3 = -_sun.global_transform.basis.z
	var moon_dir: Vector3 = -_moon.global_transform.basis.z
	_sky_mat.set_shader_parameter("sun_direction", sun_dir)
	_sky_mat.set_shader_parameter("moon_direction", moon_dir)
	_sky_mat.set_shader_parameter("sun_disc_strength",
		smoothstep(-0.05, 0.25, sun_height) * (1.0 - twilight_amount * 0.3))
	_sky_mat.set_shader_parameter("moon_disc_strength",
		smoothstep(-0.05, 0.25, -sun_height) * 0.8)

	# --- STARS QUAD ---
	if _stars_mat:
		_stars_mat.set_shader_parameter("star_alpha", star_alpha)
		_stars_mat.set_shader_parameter("star_grid_scale", star_grid_scale)
		_stars_mat.set_shader_parameter("star_density", star_density)
		_stars_mat.set_shader_parameter("star_size", star_size)
		_stars_mat.set_shader_parameter("star_brightness", star_brightness)
