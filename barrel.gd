# barrel.gd
extends RigidBody3D

signal collected

@export var lifetime: float = 60.0
var _time_alive: float = 0.0

func _ready() -> void:
	mass = 2.0
	gravity_scale = 1.0
	linear_damp = 0.5
	angular_damp = 0.5
	_build_visuals()
	_build_collision()
	set_meta("half_extents", Vector3(0.4, 0.6, 0.4))

func _build_visuals() -> void:
	var mesh_instance = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.4
	cyl.bottom_radius = 0.4
	cyl.height = 1.2
	mesh_instance.mesh = cyl
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.35, 0.20)
	mat.roughness = 0.9
	mesh_instance.material_override = mat
	add_child(mesh_instance)
	
	for y_offset in [-0.35, 0.35]:
		var ring = MeshInstance3D.new()
		var ring_cyl = CylinderMesh.new()
		ring_cyl.top_radius = 0.42
		ring_cyl.bottom_radius = 0.42
		ring_cyl.height = 0.1
		ring.mesh = ring_cyl
		var ring_mat = StandardMaterial3D.new()
		ring_mat.albedo_color = Color(0.3, 0.3, 0.3)
		ring_mat.metallic = 0.8
		ring_mat.roughness = 0.4
		ring.material_override = ring_mat
		ring.position.y = y_offset
		add_child(ring)

func _build_collision() -> void:
	var col = CollisionShape3D.new()
	var shape = CylinderShape3D.new()
	shape.radius = 0.4
	shape.height = 1.2
	col.shape = shape
	add_child(col)
	
	var area = Area3D.new()
	var area_col = CollisionShape3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = 2.0
	area_col.shape = sphere
	area.add_child(area_col)
	area.body_entered.connect(_on_body_entered)
	add_child(area)

func _physics_process(delta: float) -> void:
	_time_alive += delta
	if _time_alive >= lifetime:
		queue_free()

func _on_body_entered(body: Node3D) -> void:
	var parent = body.get_parent()
	if parent and parent.is_in_group("player"):
		collected.emit()
		if parent.has_method("add_item"):
			# AQUÍ ESTÁ EL ARREGLO: quitamos el ", 1"
			parent.add_item("barrel")
		queue_free()
