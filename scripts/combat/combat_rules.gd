class_name CombatRules
extends RefCounted


static func alive(actor: Node) -> bool:
	return is_instance_valid(actor) and not actor.is_queued_for_deletion() and (not actor.has_method("combat_alive") or actor.combat_alive())


static func can_hit(source: Node, target: Node) -> bool:
	if not alive(target) or source == target:
		return false
	if target is SeverableDebris:
		return true
	if target.has_method("can_receive_hit") and not target.can_receive_hit():
		return false
	if is_instance_valid(source) and source.has_method("combat_team") and target.has_method("combat_team"):
		return source.combat_team() != target.combat_team()
	return true


static func actors(world: Node) -> Array[Node]:
	var result: Array[Node] = []
	if world.has_node("MatchDirector"):
		for actor in world.get_node("MatchDirector").actors:
			if alive(actor):
				result.append(actor)
	else:
		for actor in world.get_tree().get_nodes_in_group("targets"):
			if alive(actor):
				result.append(actor)
		if world.has_node("Player"):
			result.append(world.get_node("Player"))
	return result


static func aim_point(actor: Node3D) -> Vector3:
	return actor.combat_aim_point() if actor.has_method("combat_aim_point") else actor.global_position + Vector3.UP * 1.8


static func clear_line(world: Node3D, from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	return world.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


static func hit(target: Node3D, damage: float, direction: Vector3, normal: Vector3, point: Vector3, token: int, source: Node, ability: StringName = &"SCAR", reflected: bool = false) -> bool:
	if not can_hit(source, target) or not target.has_method("receive_scar"):
		return false
	if target.has_method("rift_multiplier"):
		damage *= target.rift_multiplier(ability, direction, reflected, source)
	target.set_meta("last_rift_damage", damage)
	if damage <= 0:
		return false
	if target is SeverableDebris:
		return target.receive_scar(damage, direction, normal, point, token)
	return target.receive_scar(damage, direction, normal, point, token, source)
