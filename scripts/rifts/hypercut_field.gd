class_name HypercutField
extends Node3D

var lifetime: float = 3.0
var exit: Node3D
var teleported: Dictionary = {}
var transports: int = 0
var exit_valid: bool = false


func configure(_gesture: Dictionary, pose: Transform3D, _source: Node) -> void:
	global_transform = pose
	_frame(self)
	exit = Node3D.new()
	add_child(exit)
	exit.position.z = -6.0
	_frame(exit)
	add_to_group("spatial_fields")


func _frame(parent: Node3D) -> void:
	var visual := RiftRenderer.new()
	parent.add_child(visual)
	visual.set_path(GestureRecognizer.template(&"HYPERCUT"))
	visual.set_tint(Color("bb83ff"))
	visual.cavity_depth = 0.5
	visual.set_opening(1.1)
	SpatialEffects.well(parent, 0.92, 0.55, 4, PI / 4)
	var tesseract := TesseractVisual.new()
	tesseract.position.z = 0.10
	parent.add_child(tesseract)


func _physics_process(delta: float) -> void:
	lifetime -= delta
	_check_exit()
	if lifetime <= 0:
		queue_free()


func _check_exit() -> void:
	var query := PhysicsShapeQueryParameters3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.25
	query.shape = shape
	query.transform = exit.global_transform
	query.collision_mask = 1
	exit_valid = get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func transport_step(attack: Node3D, motion: Vector3) -> Vector3:
	if teleported.has(attack.get_instance_id()):
		return motion
	var a := to_local(attack.global_position)
	var b := to_local(attack.global_position + motion)
	if a.z < -0.2 or b.z >= a.z or b.z > 0:
		return motion
	var t := clampf(a.z / (a.z - b.z), 0.0, 1.0)
	var point := a.lerp(b, t)
	if absf(point.x) > 0.9 or absf(point.y) > 0.9:
		return motion
	_check_exit()
	if not exit_valid:
		return motion
	# Sweep the approach before teleporting, so a wall in front of the entry
	# still blocks a fast attack. Only the six-metre interior gap is skipped.
	if attack is RiftProjectile:
		if attack._sweep(attack.global_transform, motion * t) < 1.0:
			return motion
	elif not CombatRules.clear_line(self, attack.global_position, to_global(point)):
		return motion
	teleported[attack.get_instance_id()] = true
	point.z = -0.30
	attack.global_position = exit.to_global(point)
	attack.previous_position = attack.global_position
	attack.set_meta("phase_pierce", true)
	transports += 1
	return motion * (1.0 - t)
