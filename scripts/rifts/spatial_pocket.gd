class_name SpatialPocket
extends Node3D

var radius: float = 3.6
var lifetime: float = 2.6
var age: float = 0
var source_ref: WeakRef
var contained: int = 0
var snared: Dictionary = {}
var released: bool = false


func configure(at: Vector3, size: float, source: Node) -> void:
	global_position = at
	radius = clampf(size, 2.8, 4.4)
	if is_instance_valid(source): source_ref = weakref(source)
	add_to_group("spatial_pockets")
	add_to_group("spatial_fields")
	var vertices := [Vector3.RIGHT, Vector3.LEFT, Vector3.UP * 0.85, Vector3.DOWN * 0.85, Vector3.BACK, Vector3.FORWARD]
	for i in range(vertices.size()):
		for j in range(i + 1, vertices.size()):
			if i / 2 == j / 2: continue
			_edge(vertices[i] * radius, vertices[j] * radius)


func _edge(from: Vector3, to: Vector3) -> void:
	var axis := (to - from).normalized()
	var radial := ((from + to) * 0.5).normalized()
	var y := radial.cross(axis).normalized()
	var visual := RiftRenderer.new()
	visual.half_aperture = 0.05
	visual.cavity_depth = 0.18
	add_child(visual)
	visual.transform = Transform3D(Basis(axis, y, axis.cross(y)), from)
	visual.set_path(PackedVector2Array([Vector2.ZERO, Vector2(from.distance_to(to) * 0.5, 0.04), Vector2(from.distance_to(to), 0)]))
	visual.set_tint(RiftCaster.tint_for(&"HYPERCUT"))
	visual.set_opening(0.75)


func metric(offset: Vector3) -> float:
	return absf(offset.x) + absf(offset.y) / 0.85 + absf(offset.z)


func _physics_process(delta: float) -> void:
	age += delta
	var world := get_tree().current_scene as Node3D
	if world == null:
		queue_free()
		return
	var source := get_source()
	for actor: Node3D in CombatRules.actors(world):
		if not actor is CharacterBody3D or not CombatRules.can_hit(source, actor): continue
		var offset := CombatRules.aim_point(actor) - global_position
		if metric(offset) > radius * 1.10 or not CombatRules.clear_line(world, global_position, CombatRules.aim_point(actor)): continue
		contained += 1
		if actor.has_method("field_contact"): actor.field_contact(&"SPATIAL_POCKET", source)
		var predicted: Vector3 = offset + actor.velocity * delta
		if metric(predicted) > radius * 0.78:
			var normal := offset.normalized()
			var outward: float = actor.velocity.dot(normal)
			if outward > -3: actor.velocity -= normal * (outward + 5.0)
	for attack: Node3D in SpatialEffects.attacks(world):
		if attack.is_queued_for_deletion() or snared.has(attack.get_instance_id()): continue
		var owner: Node = attack.get_source()
		if owner == source or (is_instance_valid(owner) and is_instance_valid(source) and owner.has_method("combat_team") and source.has_method("combat_team") and owner.combat_team() == source.combat_team()): continue
		if metric(attack.global_position - global_position) > radius or not CombatRules.clear_line(world, global_position, attack.global_position): continue
		if snared.size() >= 12:
			attack.queue_free()
			continue
		snared[attack.get_instance_id()] = {"ref": weakref(attack), "speed": attack.speed}
		attack.speed = 0
		attack.set_physics_process(false)
	if age >= lifetime:
		release_attacks()
		SpatialEffects.burst(world, global_position, radius, 72, source, get_instance_id(), &"SPATIAL_COMBO")
		queue_free()


func get_source() -> Node:
	return source_ref.get_ref() if source_ref != null else null


func release_attacks() -> void:
	if released: return
	released = true
	var source := get_source()
	var world := get_tree().current_scene as Node3D
	for record: Dictionary in snared.values():
		var attack := record["ref"].get_ref() as Node3D
		if not is_instance_valid(attack) or attack.is_queued_for_deletion() or not attack.is_inside_tree(): continue
		var direction := (attack.global_position - global_position).normalized()
		if direction.length_squared() < 0.01: direction = Vector3.UP
		attack.look_at(attack.global_position + direction, Vector3.UP if absf(direction.y) < 0.95 else Vector3.RIGHT)
		attack.speed = maxf(28, record["speed"])
		if is_instance_valid(source): attack.source_ref = weakref(source)
		attack.reflected = true
		if attack is RiftProjectile:
			attack.phase = RiftProjectile.Phase.PROPAGATION
			attack._phase_age = 0
			if world != null and world.is_ancestor_of(attack): RiftCaster.wire(attack, world, source)
		elif attack is EnemyBolt:
			attack._cast.collision_mask = 15
		attack.set_physics_process(true)


func _exit_tree() -> void:
	release_attacks()
