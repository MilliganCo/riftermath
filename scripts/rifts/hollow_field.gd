class_name HollowField
extends Node3D

var source_ref: WeakRef
var radius: float = 3.5
var lifetime: float = 2.8
var age: float = 0.0
var absorbed: int = 0
var affected: int = 0
var collapsed: bool = false
var rim: RiftRenderer
var cavity: MeshInstance3D
var collapse_damage: float = 60.0


func configure(gesture: Dictionary, pose: Transform3D, source: Node) -> void:
	global_transform = pose
	if is_instance_valid(source):
		source_ref = weakref(source)
	var path: PackedVector2Array = gesture["points"]
	var low := path[0]
	var high := path[0]
	for point in path:
		low = low.min(point)
		high = high.max(point)
	radius = clampf((high - low).length() * 1.8, 2.5, 5.0)
	rim = RiftRenderer.new()
	add_child(rim)
	rim.set_path(path)
	rim.half_aperture = 0.10
	var aperture := maxf(0.2, minf(high.x - low.x, high.y - low.y) * 0.5)
	cavity = SpatialEffects.well(self, aperture, 0.9)
	add_to_group("spatial_fields")


func _physics_process(delta: float) -> void:
	age += delta
	if age < 0.4:
		global_position -= global_basis.z * delta * 14.0
	var opening := minf(1.0, age * 6.0) * maxf(0.01, minf(1.0, (lifetime - age) * 4.0))
	rim.set_opening(opening)
	cavity.scale = Vector3.ONE * maxf(0.01, opening)
	var world := get_tree().current_scene as Node3D
	var source: Node = source_ref.get_ref() if source_ref != null else null
	for actor: Node3D in CombatRules.actors(world):
		if not CombatRules.can_hit(source, actor):
			continue
		var offset := global_position - CombatRules.aim_point(actor)
		if offset.length() < radius and CombatRules.clear_line(world, global_position, CombatRules.aim_point(actor)):
			if actor.has_method("field_contact"):
				actor.field_contact(&"HOLLOW", source)
			if actor is CharacterBody3D:
				actor.velocity += offset.normalized() * delta * 36.0
			affected += 1
	for piece: SeverableDebris in get_tree().get_nodes_in_group("combat_debris"):
		var offset := global_position - piece.global_position
		if offset.length() < radius:
			piece.apply_central_force(offset.normalized() * 9.0)
	for attack: Node3D in SpatialEffects.attacks(world):
		if not is_instance_valid(attack):
			continue
		if attack is SimplexProjectile and attack.get_source() == source:
			var interactions := world.get_node_or_null("RiftInteractions") as RiftInteractions
			if interactions != null and interactions.try_pocket(self, attack): return
			continue
		var offset := global_position - attack.global_position
		if offset.length() < radius and offset.length() > 0.10:
			attack.look_at(attack.global_position + offset, Vector3.UP if absf(offset.normalized().y) < 0.95 else Vector3.RIGHT)
			if offset.length() < 0.65:
				attack.queue_free()
				absorbed += 1
	if age >= lifetime:
		collapse()


func collapse() -> void:
	if collapsed:
		return
	collapsed = true
	SpatialEffects.burst(get_tree().current_scene, global_position, radius, collapse_damage + absorbed * 5, source_ref.get_ref() if source_ref != null else null, get_instance_id(), &"HOLLOW")
	queue_free()
