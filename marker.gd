# marker.gd
extends Node3D

@export var marker_color: Color = Color(1.0, 0.85, 0.2)
@export var ring_radius: float = 1.8
@export var pulse_speed: float = 4.0
@export var pulse_amount: float = 0.25
@export var rotation_speed: float = 0.8
@export var beam_height: float = 6.0

var _ring: MeshInstance3D
var _beam: MeshInstance3D
var _pulse_time: float = 0.0
var _tween: Tween
var _player: Node = null
var _water: Node = null

func _ready() -> void:
	_create_visuals()
	visible = false

	_player = get_tree().get_first_node_in_group("player")
	if _player == null:
		push_warning("marker.gd: no hay ningún nodo en el grupo 'player'")
	else:
		_player.navigation_started.connect(_on_nav_started)
		_player.navigation_finished.connect(_on_nav_finished)

	_water = get_tree().get_first_node_in_group("water")

func _create_visuals() -> void:
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = ring_radius * 0.82
	torus.outer_radius = ring_radius
	torus.rings = 32
	torus.ring_segments = 10
	_ring.mesh = torus

	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = marker_color
	ring_mat.emission_enabled = true
	ring_mat.emission = marker_color
	ring_mat.emission_energy_multiplier = 2.0
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring.material_override = ring_mat
	_ring.position.y = 0.05
	
	# --- NUEVO: Metadatos para el path tracer ---
	_ring.add_to_group("pt_dynamic")          # Para que el tracker lo encuentre
	_ring.set_meta("pt_sphere", true)         # Representarlo como esfera
	_ring.set_meta("pt_radius", 0.4)          # Radio visual en el path tracer
	# -------------------------------------------
	
	add_child(_ring)

	_beam = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.05
	cyl.bottom_radius = 0.15
	cyl.height = beam_height
	_beam.mesh = cyl

	var beam_mat := StandardMaterial3D.new()
	beam_mat.albedo_color = Color(marker_color.r, marker_color.g, marker_color.b, 0.35)
	beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_mat.no_depth_test = true
	_beam.material_override = beam_mat
	_beam.position.y = beam_height * 0.5
	add_child(_beam)

func _on_nav_started(target_pos: Vector3) -> void:
	global_position = Vector3(target_pos.x, 0.0, target_pos.z)
	_pulse_time = 0.0

	if _tween and _tween.is_valid():
		_tween.kill()

	visible = true
	scale = Vector3.ZERO
	_tween = create_tween()
	_tween.tween_property(self, "scale", Vector3.ONE, 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_nav_finished() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "scale", Vector3.ZERO, 0.2)
	_tween.tween_callback(func(): visible = false)

func _process(delta: float) -> void:
	if not visible:
		return

	if is_instance_valid(_water):
		global_position.y = _water.get_surface_y_at(global_position.x, global_position.z) + 0.05

	_pulse_time += delta * pulse_speed
	var s: float = 1.0 + sin(_pulse_time) * pulse_amount
	_ring.scale = Vector3(s, 1.0, s)
	rotate_y(delta * rotation_speed)
