extends "res://tests/live_combat.gd"


func _run() -> void:
	await load_level("res://scenes/battle.tscn", 1)
	await tactical_movement_checks()
	await load_level("res://scenes/battle.tscn", 0)
	await recovery_checks()
	check(completed_suites == 2, "Both tactical gameplay suites completed")
	player.set_mouse_captured(false)
	print("RIFTERMATH_TACTICAL_RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func isolate_bots() -> void:
	player.invulnerability = 10000
	for actor in game.match_director.actors:
		if actor is CombatBot:
			actor.set_physics_process(false)
			actor.global_position = Vector3(-32, 0.1, -32)
			actor._cancel_drawing()
			actor._attack_cooldown = 10000


func tactical_movement_checks() -> void:
	isolate_bots()
	var bot := game.match_director.actors[4] as CombatBot
	bot.global_position = Vector3(-20, 0.1, -8)
	player.global_position = Vector3(-7, 0.1, -8)
	await frames(3)
	check(not CombatRules.clear_line(bot, bot.combat_aim_point(), player.combat_aim_point()), "Tactical fixture begins behind real solid cover")
	var goal := bot.tactics.firing_goal(player, bot.navigation)
	var route := bot.navigation.route(bot.global_position, goal)
	var side_travel := 0.0
	for point in route:
		side_travel = maxf(side_travel, absf(point.z - bot.global_position.z))
	print("TACTICAL_FLANK_METRICS: kind=", bot.kind, " goal=", goal, " flanks=", bot.tactics.flanks, " lateral_route=", side_travel)
	check(bot.tactics.flanks > 0 and side_travel > 4.0, "Bot routes laterally around cover to a firing position")
	check(not route.is_empty() and CombatRules.clear_line(bot, goal + Vector3.UP * 2.5, player.combat_aim_point()), "Chosen flank is reachable and has a clear shot")
	check(bot.tactics.firing_goal(player, bot.navigation) == goal, "Tactical goal stays stable instead of jittering each think frame")
	bot.global_position = Vector3(18, 0.1, 12)
	bot.rotation = Vector3.ZERO
	bot.velocity = Vector3.ZERO
	bot.director = null
	bot.target = player
	bot._route.clear()
	bot._think = 1000
	bot._attack_cooldown = 0
	bot.tactics.reset()
	bot.tactics.cooldown = 0
	player.global_position = Vector3(18, 0.1, 25)
	await frames(3)
	var attack := incoming(bot, player)
	bot.set_physics_process(true)
	var origin := bot.global_position
	await frames(3)
	check(bot.tactics.reaction_remaining > 0 and bot.tactics.evasions == 0, "A visible approaching SCAR starts a finite reaction, not an instant dodge")
	await frames(23)
	check(bot.tactics.evasions == 1 and absf(bot.velocity.x) > 7.0, "The reaction produces real lateral evasive velocity")
	check(is_instance_valid(bot._telegraph), "Evasive movement preserves the creature's visible drawing windup")
	await frames(26)
	check(absf(bot.global_position.x - origin.x) > 1.4, "Evasion changes the creature's physical position")
	for i in range(50):
		if bot.tactics.dodge_remaining <= 0:
			break
		await frames(1)
	print("TACTICAL_EVASION_METRICS: cooldown=", bot.tactics.cooldown, " remaining=", bot.tactics.dodge_remaining, " travel=", bot.global_position - origin, " active=", bot.is_physics_processing())
	check(bot.tactics.cooldown > 1.8 and bot.tactics.dodge_remaining == 0, "Dodge ends and leaves a punishable cooldown window")
	incoming(bot, player)
	await frames(25)
	check(bot.tactics.evasions == 1, "Rapid follow-up attacks cannot trigger unlimited dodges")
	bot.set_physics_process(false)
	bot._cancel_drawing()
	for node in game.get_node("Rifts").get_children():
		node.queue_free()
	await frames(2)
	bot.rotation = Vector3.ZERO
	bot.tactics.cooldown = 0
	bot.tactics._scan_remaining = 0
	attack = incoming(bot, player, true)
	bot.tactics.update(0.08)
	check(bot.tactics.reaction_remaining == 0, "Shots from behind do not give the bot omniscient evasion")
	attack.queue_free()
	await frames(2)
	bot.tactics._scan_remaining = 0
	attack = incoming(bot, game.match_director.actors[5])
	bot.tactics.update(0.08)
	check(bot.tactics.reaction_remaining == 0, "Friendly attacks do not trigger evasive reactions")
	attack.queue_free()
	await frames(2)
	bot.global_position = Vector3(6, 3.1, 4)
	await frames(2)
	check(not bot.tactics._clear_step(Vector3.RIGHT), "Evasion rejects a dash off the raised altar")
	bot.rebuild(Vector3(18, 0.1, 12))
	check(bot.tactics.dodge_remaining == 0 and bot.tactics.reaction_remaining == 0, "Respawn clears pending evasive movement")
	bot.global_position = Vector3(18, 0.1, -5)
	player.global_position = Vector3(18, 0.1, 20)
	bot._think = 1000
	bot._attack_cooldown = 0
	var atmosphere := game.atmosphere as CombatAtmosphere
	atmosphere.set_physics_process(false)
	atmosphere.intensity = 1
	atmosphere.apply_visuals()
	var windups := bot.windups_started
	bot.set_physics_process(true)
	await frames(4)
	check(bot.vision_range() == 19.0 and bot.windups_started == windups, "Dense peak fog also limits enemy shooting range")
	atmosphere.reset()
	await frames(4)
	check(bot.vision_range() == 30.0 and bot.windups_started > windups, "The same enemy can draw a distant attack again when fog clears")
	bot.set_physics_process(false)
	bot._cancel_drawing()
	completed_suites += 1


func incoming(bot: CombatBot, source: Node, rear: bool = false) -> RiftProjectile:
	var at := bot.combat_aim_point() + Vector3(0, 0, -8 if rear else 8)
	var basis := Basis(Vector3.UP, PI) if rear else Basis.IDENTITY
	var data := GestureRecognizer.recognize(GestureRecognizer.template(&"SCAR"), 0.2)
	var shot := RiftCaster.cast(game, data, Transform3D(basis, at), at, source) as RiftProjectile
	shot.speed = 22.0
	shot.phase = RiftProjectile.Phase.PROPAGATION
	shot._muzzle_checked = true
	return shot


func recovery_checks() -> void:
	isolate_bots()
	player.global_position = Vector3(18, 0.1, 25)
	player.hp = 55
	player.energy = 100
	var enemy := game.match_director.actors[1] as CombatBot
	enemy.global_position = Vector3(18, 0.1, 18)
	enemy.invulnerability = 0
	CombatRules.hit(enemy, 10000, Vector3.FORWARD, Vector3.UP, enemy.combat_aim_point(), 987001, player)
	await frames(2)
	var shards := get_nodes_in_group("recovery_shards")
	check(shards.size() == 1, "Player elimination of a live enemy drops a real recovery shard")
	var shard := shards[0] as RecoveryShard
	check(shard.visual.mesh.get_faces().size() == 24, "Recovery item is an elongated eight-face 3D shard")
	var before := shard.global_position
	await frames(20)
	check(absf(shard.global_position.z - before.z) < 0.01 and player.hp == 55, "Distant recovery cannot heal a camping player")
	player.global_position = Vector3(18, 0.1, 21.5)
	await frames(70)
	check(player.hp == 67 and not is_instance_valid(shard), "Approaching a shard magnetically collects and restores twelve HP")
	check(game.hud.notice.contains("INTEGRITY"), "Recovery displays the actual resources restored")
	player.hp = 96
	player.energy = 97
	shard = RecoveryShard.spawn(game, player.combat_aim_point() + Vector3(0, 0, -0.5), player)
	await frames(2)
	check(player.hp == 100 and player.energy <= 100 and not is_instance_valid(shard), "Recovery respects health and energy caps")
	player.hp = 70
	var wall := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(10, 8, 0.5)
	collision.shape = shape
	wall.add_child(collision)
	game.add_child(wall)
	wall.position = player.global_position + Vector3(0, 3, -1.4)
	shard = RecoveryShard.spawn(game, player.combat_aim_point() + Vector3(0, 0, -3), player)
	await frames(50)
	check(player.hp == 70 and is_instance_valid(shard) and not shard._seeking, "Recovery shards cannot pass or heal through architecture")
	shard.age = RecoveryShard.LIFETIME - 0.01
	await frames(3)
	check(not is_instance_valid(shard), "Uncollected shards expire and clean up")
	wall.queue_free()
	player.hp = 100
	player.energy = 100
	for i in range(18):
		RecoveryShard.spawn(game, Vector3(18, 1, 12), player)
	await frames(2)
	check(get_nodes_in_group("recovery_shards").size() <= RecoveryShard.MAX_SHARDS, "Recovery geometry has a fixed twelve-item cap")
	completed_suites += 1
