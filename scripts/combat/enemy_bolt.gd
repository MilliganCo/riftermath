class_name EnemyBolt
extends Node3D

@export var damage: float = 14.0
var speed: float = 18.0
var remaining_life: float = 4.0
var _cast: ShapeCast3D
var _configured: bool = false
var reflected: bool = false
var source_ref: WeakRef
var previous_position := Vector3.ZERO


func _ready() -> void:
	add_to_group("enemy_bolts")
	var mesh_node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = 0.14
	mesh.height = 0.70
	mesh.radial_segments = 4
	mesh_node.mesh = mesh
	mesh_node.rotation.x = -PI / 2
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("ff5738")
	material.emission_enabled = true
	material.emission = Color("ff5738")
	material.emission_energy_multiplier = 2.7
	mesh_node.material_override = material
	add_child(mesh_node)
	_cast = ShapeCast3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.12
	_cast.shape = shape
	_cast.collision_mask = 3
	_cast.enabled = false
	add_child(_cast)


func configure(from: Vector3, aim: Vector3, velocity: float = 18.0) -> void:
	global_position = from
	previous_position = from
	if from.distance_squared_to(aim) > 0.0001:
		look_at(aim, Vector3.UP if absf((aim - from).normalized().y) < 0.99 else Vector3.FORWARD)
	speed = velocity
	_configured = true


func _physics_process(delta: float) -> void:
	if not _configured:
		return
	previous_position = global_position
	remaining_life -= delta
	var motion := -global_basis.z * speed * delta
	for field in get_tree().get_nodes_in_group("spatial_fields"):
		if field is HypercutField:
			motion = field.transport_step(self, motion)
	_cast.target_position = global_basis.inverse() * motion
	_cast.force_shapecast_update()
	if _cast.is_colliding():
		for i in range(_cast.get_collision_count()):
			var body := _cast.get_collider(i)
			if reflected and is_instance_valid(body) and body.has_method("receive_scar"):
				CombatRules.hit(body, damage, -global_basis.z, global_basis.y, global_position, get_instance_id(), get_source(), &"REFLECTED", true)
				break
			elif is_instance_valid(body) and body.has_method("receive_damage"):
				body.receive_damage(damage)
				break
		queue_free()
		return
	global_position += motion
	if remaining_life <= 0.0:
		queue_free()


func get_source() -> Node:
	return source_ref.get_ref() if source_ref != null else null


func reflect_by(actor: Node3D) -> void:
	var source := get_source() as Node3D
	var aim: Vector3 = CombatRules.aim_point(source) if CombatRules.alive(source) else global_position - actor.camera.global_basis.z * 20
	source_ref = weakref(actor)
	look_at(aim)
	damage *= 2.6
	speed *= 1.4
	reflected = true
	_cast.collision_mask = 13
	var visual := get_child(0) as MeshInstance3D
	var material := visual.material_override as StandardMaterial3D
	material.albedo_color = Color("a2ffff")
	material.emission = Color("a2ffff")
