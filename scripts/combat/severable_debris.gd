class_name SeverableDebris
extends RigidBody3D

const MAX_PIECES: int = 128
const MAX_GENERATION: int = 3

var generation: int = 0
var immune_scar_id: int = 0
var remaining_life: float = 6.0
var spent: bool = false
var geometry: Mesh
var surface: Material
var mesh_instance: MeshInstance3D


static func spawn(parent: Node, mesh: Mesh, shape: Shape3D, material: Material, pose: Transform3D, motion: Vector3, spin: Vector3, level: int = 0, immunity: int = 0, lifetime: float = 6.0) -> SeverableDebris:
	if parent.get_tree().get_nodes_in_group("combat_debris").size() >= MAX_PIECES:
		return null
	var piece := SeverableDebris.new()
	piece.geometry = mesh
	piece.surface = material
	piece.generation = level
	piece.immune_scar_id = immunity
	piece.remaining_life = lifetime
	piece.collision_layer = 8
	piece.collision_mask = 1
	piece.gravity_scale = 0.32
	piece.mass = 0.35
	piece.linear_damp = 0.12
	piece.angular_damp = 0.25
	piece.add_to_group("combat_debris")
	piece.mesh_instance = MeshInstance3D.new()
	piece.mesh_instance.mesh = mesh
	piece.mesh_instance.material_override = material
	piece.add_child(piece.mesh_instance)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	piece.add_child(collision)
	parent.add_child(piece)
	piece.global_transform = pose
	piece.linear_velocity = motion
	piece.angular_velocity = spin
	return piece


func _physics_process(delta: float) -> void:
	remaining_life -= delta
	if remaining_life <= 0.0 or global_position.y < -12:
		queue_free()


func receive_scar(_amount: float, direction: Vector3, cut_normal: Vector3, plane_point: Vector3 = Vector3.INF, scar_id: int = 0) -> bool:
	if spent or generation >= MAX_GENERATION or (scar_id != 0 and scar_id == immune_scar_id):
		return false
	if get_tree().get_nodes_in_group("combat_debris").size() > MAX_PIECES - 2:
		return false
	var local_normal := (global_basis.transposed() * cut_normal).normalized()
	var offset := local_normal.dot(to_local(plane_point)) if plane_point.is_finite() else 0.0
	var pieces := ConvexFracture.split_mesh(geometry, local_normal, offset)
	if pieces.size() != 2:
		return false
	spent = true
	collision_layer = 0
	mesh_instance.hide()
	for part in pieces:
		var local_center: Vector3 = part["center"]
		var side := 1.0 if local_center.dot(local_normal) > offset else -1.0
		var pose := Transform3D(global_basis, to_global(local_center))
		var motion := linear_velocity * 0.65 + direction * 1.8 + cut_normal * side * 2.2 + Vector3.UP * 1.4
		spawn(get_parent(), part["mesh"], part["shape"], surface, pose, motion, angular_velocity * 0.5 + Vector3(0.4, side * 0.7, 0.3), generation + 1, scar_id, minf(remaining_life + 0.25, 4.5))
	queue_free()
	return true
