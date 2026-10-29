class_name BotTactics
extends RefCounted

## Tactical decisions use visible geometry and a finite reaction/cooldown window.
var bot: CharacterBody3D
var evasions: int = 0
var flanks: int = 0
var goal := Vector3.ZERO
var dodge_velocity := Vector3.ZERO
var dodge_remaining: float = 0.0
var reaction_remaining: float = 0.0
var cooldown: float = 0.0
var _scan_remaining: float = 0.0
var _goal_remaining: float = 0.0
var _goal_target: WeakRef
var _pending_direction := Vector3.ZERO


func update(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)
	dodge_remaining = maxf(0.0, dodge_remaining - delta)
	_goal_remaining -= delta
	if reaction_remaining > 0.0:
		reaction_remaining = maxf(0.0, reaction_remaining - delta)
		if reaction_remaining == 0.0 and _clear_step(_pending_direction):
			dodge_velocity = _pending_direction * (11.5 if bot.kind != CombatBot.Kind.RUSHER else 10.0)
			dodge_remaining = 0.23
			cooldown = 2.7 + float(bot.get_instance_id() % 4) * 0.25
			evasions += 1
		return
	_scan_remaining -= delta
	if cooldown > 0.0 or dodge_remaining > 0.0 or _scan_remaining > 0.0:
		return
	_scan_remaining = 0.08
	var attacks := bot.get_tree().get_nodes_in_group("rift_projectiles") + bot.get_tree().get_nodes_in_group("enemy_bolts")
	for attack: Node3D in attacks:
		if attack.is_queued_for_deletion() or (attack is RiftProjectile and attack.phase != RiftProjectile.Phase.PROPAGATION):
			continue
		var source: Node = attack.get_source()
		if source == bot or (is_instance_valid(source) and source.has_method("combat_team") and source.combat_team() == bot.team_id):
			continue
		var speed: float = attack.speed
		if speed <= 0.1:
			continue
		var direction := -attack.global_basis.z
		var offset: Vector3 = bot.combat_aim_point() - attack.global_position
		var time_to_pass := offset.dot(direction) / speed
		# Point-blank/rear shots cannot be answered by an instant omniscient dodge.
		if time_to_pass < 0.16 or time_to_pass > 0.52 or offset.length_squared() > 26.0 * 26.0:
			continue
		if bot.global_basis.z.dot(-offset.normalized()) < 0.10:
			continue
		var miss := offset - direction * offset.dot(direction)
		if miss.length_squared() > 2.4 * 2.4 or not CombatRules.clear_line(bot, bot.combat_aim_point(), attack.global_position):
			continue
		var side := Vector3(-direction.z, 0, direction.x).normalized()
		if side.length_squared() < 0.5:
			continue
		side *= 1.0 if (bot.get_instance_id() + evasions) % 2 else -1.0
		if not _clear_step(side):
			side = -side
		if _clear_step(side):
			_pending_direction = side
			reaction_remaining = 0.14 + float(bot.get_instance_id() % 3) * 0.02
			break


func _clear_step(direction: Vector3) -> bool:
	if bot.test_move(bot.global_transform, direction * 2.7):
		return false
	if bot.navigation != null:
		var end: Vector3 = bot.global_position + direction * 2.7
		var floor_y: float = bot.navigation.arena.support_height(end)
		var start_y: float = bot.navigation.arena.support_height(bot.global_position)
		var boundary: float = bot.navigation.half_cells * bot.navigation.cell_step
		if absf(floor_y - start_y) > 0.85 or absf(end.x) > boundary or absf(end.z) > boundary:
			return false
	return true


func firing_goal(target: Node3D, navigation: BattleNavigation) -> Vector3:
	var previous: Node = _goal_target.get_ref() if _goal_target != null else null
	if previous == target and _goal_remaining > 0.0 and bot.global_position.distance_to(goal) > 1.1:
		return goal
	_goal_target = weakref(target)
	_goal_remaining = 1.1
	var toward: Vector3 = target.global_position - bot.global_position
	toward.y = 0
	toward = toward.normalized() if toward.length_squared() > 0.01 else Vector3.FORWARD
	var preferred := 4.0 if bot.kind == CombatBot.Kind.RUSHER else (9.0 if bot.kind == CombatBot.Kind.SWARM else 12.0)
	var side := 1.0 if bot.get_instance_id() % 2 else -1.0
	var best_score := INF
	var best := target.global_position
	var found := false
	for angle in [0.42, 0.90, -0.65, 1.50, -1.35, 2.30, -2.30]:
		var desired: Vector3 = target.global_position - toward.rotated(Vector3.UP, angle * side) * preferred
		var id := navigation.graph.get_closest_point(desired)
		if id < 0:
			continue
		var cell := Vector2i(roundi(desired.x / navigation.cell_step), roundi(desired.z / navigation.cell_step))
		var candidates: Array = navigation.cells.get(cell, []).duplicate()
		if not candidates.has(id): candidates.append(id)
		for candidate_id: int in candidates:
			var candidate := navigation.graph.get_point_position(candidate_id)
			if Vector2(candidate.x - desired.x, candidate.z - desired.z).length() > 2.0:
				continue
			var eye := candidate + Vector3.UP * (1.7 if bot.kind == CombatBot.Kind.SWARM else 2.5)
			if not CombatRules.clear_line(bot, eye, CombatRules.aim_point(target)):
				continue
			var score: float = bot.global_position.distance_to(candidate) + (2.5 if angle < 0 else 0.0)
			score -= minf(3.0, maxf(0, candidate.y - target.global_position.y) * 0.3)
			# Do not select the same doorway for every member of a team/swarm.
			if is_instance_valid(bot.director):
				for other in bot.director.actors:
					if other != bot and CombatRules.alive(other) and other.global_position.distance_to(candidate) < 3.0:
						score += 5.0
			if score < best_score:
				best_score = score
				best = candidate
				found = true
	if found and not CombatRules.clear_line(bot, bot.combat_aim_point(), CombatRules.aim_point(target)):
		flanks += 1
	goal = best
	return goal


func reset() -> void:
	dodge_remaining = 0.0
	reaction_remaining = 0.0
	cooldown = 0.6
	_goal_remaining = 0.0
	_goal_target = null
	dodge_velocity = Vector3.ZERO
