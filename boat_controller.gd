# boat_controller.gd
class_name BoatController
extends RigidBody3D

@export var move_force: float = 25.0
@export var max_speed: float = 12.0
@export var turn_force: float = 10.0
@export var max_torque: float = 15.0
@export var turn_align_threshold: float = 0.15
@export var brake_while_turning: float = 5.0
@export var arrive_radius: float = 2.0
@export var slow_radius: float = 10.0

var target_position: Vector3
var has_target: bool = false

func _ready() -> void:
	mass = 1.0
	gravity_scale = 1.0
	linear_damp = 0.05
	angular_damp = 0.5
	_build_visuals()
	_build_collision()

func _build_visuals() -> void:
	var hull := MeshInstance3D.new()
	hull.mesh = BoatMesh.build_hull()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.32, 0.18)
	mat.roughness = 0.75
	hull.material_override = mat
	add_child(hull)

	var cabin := MeshInstance3D.new()
	var cabin_mesh := BoxMesh.new()
	cabin_mesh.size = Vector3(0.7, 0.5, 1.0)
	cabin.mesh = cabin_mesh
	var cabin_mat := StandardMaterial3D.new()
	cabin_mat.albedo_color = Color(0.85, 0.80, 0.70)
	cabin.material_override = cabin_mat
	cabin.position = Vector3(0, 0.60, -0.5)
	add_child(cabin)

	var mast := MeshInstance3D.new()
	var mast_mesh := CylinderMesh.new()
	mast_mesh.top_radius = 0.04; mast_mesh.bottom_radius = 0.06; mast_mesh.height = 2.8
	mast.mesh = mast_mesh
	mast.position = Vector3(0, 0.35 + 1.4, 0.2)
	add_child(mast)

	var sail := MeshInstance3D.new()
	sail.mesh = BoatMesh.build_sail()
	var sail_mat := StandardMaterial3D.new()
	sail_mat.albedo_color = Color(0.95, 0.95, 0.90)
	sail_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	sail.material_override = sail_mat
	sail.position = Vector3(0, 0.35, 0.2)
	add_child(sail)

func _build_collision() -> void:
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.9, 0.8, 4.0)
	col.shape = box
	col.position = Vector3(0, -0.05, 0)
	add_child(col)
	set_meta("half_extents", box.size * 0.5)

func _physics_process(_delta: float) -> void:
	if not has_target: return

	var to_target: Vector3 = target_position - global_position
	to_target.y = 0.0
	var distance: float = to_target.length()

	if distance <= arrive_radius:
		has_target = false
		return

	var target_dir: Vector3 = to_target.normalized()
	var boat_forward: Vector3 = global_transform.basis.z
	boat_forward.y = 0.0
	boat_forward = boat_forward.normalized()

	var angle: float = boat_forward.signed_angle_to(target_dir, Vector3.UP)
	var hv: Vector3 = Vector3(linear_velocity.x, 0.0, linear_velocity.z)
	var speed: float = hv.length()

	# ESTADO 1: GIRAR
	if abs(angle) > turn_align_threshold:
		var torque: float = clampf(angle * turn_force, -max_torque, max_torque)
		apply_torque(Vector3.UP * torque)
		if speed > 0.1:
			apply_central_force(-hv.normalized() * brake_while_turning)
		return

	# ESTADO 2: AVANZAR RECTO
	var torque_correction: float = clampf(angle * turn_force * 0.5, -max_torque * 0.5, max_torque * 0.5)
	apply_torque(Vector3.UP * torque_correction)

	var desired_speed: float = max_speed
	if distance < slow_radius:
		desired_speed = max_speed * (distance / slow_radius)

	if speed < desired_speed:
		apply_central_force(boat_forward * move_force)
	if speed > desired_speed + 0.5:
		apply_central_force(-hv.normalized() * move_force * 0.5)
