class_name FoldField
extends Node3D

var source_ref: WeakRef
var lifetime: float = 3.0
var angle: float = PI / 2
var redirected: Dictionary = {}
var redirects: int = 0


func configure(gesture: Dictionary, pose: Transform3D, source: Node) -> void:
	global_transform = pose
	if is_instance_valid(source):
		source_ref = weakref(source)
	var path := GestureRecognizer.simplify(gesture["points"], 0.15)
	if path.size() >= 3:
		var a := (path[1] - path[0]).normalized()
		var b := (path[2] - path[1]).normalized()
		angle = clampf(acos(clampf(a.dot(b), -1, 1)), 0.55, 2.3) * (1.0 if a.cross(b) > 0 else -1.0)
	for i in range(2):
		var panel := Node3D.new()
		add_child(panel)
		panel.rotation.y = (float(i) - 0.5) * absf(angle)
		var visual := RiftRenderer.new()
		panel.add_child(visual)
		visual.set_path(PackedVector2Array([Vector2(-0.7, 0.9), Vector2(-0.7, -0.9), Vector2(0.7, -0.9), Vector2(0.7, 0.9)]))
		visual.set_tint(Color("c18bff"))
		visual.set_opening(0.7)
		SpatialEffects.well(panel, 0.70, 0.32)
	add_to_group("spatial_fields")


func _physics_process(delta: float) -> void:
	lifetime -= delta
	for attack: Node3D in SpatialEffects.attacks(get_tree().current_scene):
		if not is_instance_valid(attack) or redirected.has(attack.get_instance_id()):
			continue
		if SpatialEffects.crosses(global_transform, attack.previous_position, attack.global_position, 1.25):
			redirected[attack.get_instance_id()] = true
			var direction := (-attack.global_basis.z).rotated(global_basis.y, angle)
			attack.look_at(attack.global_position + direction, Vector3.UP if absf(direction.y) < 0.95 else Vector3.RIGHT)
			var source: Node = source_ref.get_ref() if source_ref != null else null
			if is_instance_valid(source):
				attack.source_ref = weakref(source)
			attack.reflected = true
			if attack is RiftProjectile:
				RiftCaster.wire(attack, get_tree().current_scene, source)
			if attack is EnemyBolt:
				attack._cast.collision_mask = 15
				attack.reflected = true
			redirects += 1
	if lifetime <= 0:
		queue_free()
