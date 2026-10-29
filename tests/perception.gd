extends "res://tests/live_combat.gd"


func _run() -> void:
	await load_level("res://scenes/battle.tscn", 0)
	var director := game.match_director as MatchDirector
	for actor in director.actors:
		if actor is CombatBot:
			actor.set_physics_process(false)
			actor.global_position = Vector3(-32, 0.1, -32)
	var bot := director.actors[1] as CombatBot
	director.actors = [player, bot]
	bot.global_position = Vector3(18, 0.1, 10)
	bot.rotation = Vector3.ZERO
	bot.velocity = Vector3.ZERO
	bot._attack_cooldown = 10000
	bot.perception.clear()
	player.global_position = Vector3(18, 0.1, 22)
	player.velocity = Vector3.ZERO
	player.invulnerability = 10000
	await frames(3)
	bot._choose_target_and_route()
	check(bot.target == player and not bot.searching and bot.perception.seen_events > 0, "A visible frontal player is acquired through actual sight")
	var known := bot.perception.last_position(player)
	var wall := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(10, 8, 0.6)
	collision.shape = shape
	wall.add_child(collision)
	game.add_child(wall)
	wall.global_position = Vector3(18, 4, 16)
	await frames(3)
	check(not bot.perception.can_see(player), "Opaque architecture blocks sight acquisition")
	player.global_position = Vector3(21, 0.1, 22)
	await frames(2)
	bot._choose_target_and_route()
	check(bot.searching and bot.perception.last_position(player).distance_to(known) < 0.01, "Moving behind cover cannot update the bot's last-seen coordinates")
	check(not bot._route.is_empty() and bot._route[-1].distance_to(known) < 2, "Search route leads to the remembered location rather than the hidden live position")
	bot.perception.step(5)
	bot._choose_target_and_route()
	check(bot.target == null and bot.patrol_steps > 0, "Expired memory gives way to a real patrol route")
	check(not bot.perception.has_memory(player), "The bot cannot keep an invisible actor in memory indefinitely")
	var gesture := GestureRecognizer.recognize(GestureRecognizer.template(&"FOLD"), 0.35)
	game._release_scar(gesture["points"], player.camera.global_transform.translated_local(Vector3(0, 0, -2)), 0.35)
	check(bot.perception.heard_events == 1 and bot.perception.has_memory(player) and is_instance_valid(game.last_cast), "An actual player rift release is heard through the muffled wall")
	var heard := bot.perception.last_position(player)
	player.global_position = Vector3(22, 0.1, 24)
	await frames(2)
	check(bot.perception.last_position(player).distance_to(heard) < 0.01, "A sound event records one position snapshot, not continuous hidden tracking")
	bot._choose_target_and_route()
	check(bot.searching and bot.target == player, "Heard noise gives a search objective without granting wall vision")
	bot.perception.clear()
	player.global_position = Vector3(18, 0.1, -6)
	await frames(2)
	check(not bot.perception.can_see(player) and not bot.perception.observe(player), "Distant targets directly behind the creature do not bypass its field of view")
	player.global_position = Vector3(18, 0.1, -50)
	await frames(2)
	check(not bot.perception.hear(player, player.camera.global_position), "Remote rift noises cannot trigger omniscient pursuit")
	var ally := CombatBot.new()
	ally.team_id = bot.team_id
	game.get_node("Targets").add_child(ally)
	ally.set_physics_process(false)
	ally.global_position = Vector3(18, 0.1, 20)
	check(not bot.perception.hear(ally, ally.combat_aim_point()), "Friendly casting does not create a hostile clue")
	wall.queue_free()
	player.global_position = Vector3(18, 0.1, 22)
	await frames(3)
	bot.rotation = Vector3.ZERO
	bot._choose_target_and_route()
	check(bot.target == player and not bot.searching and bot.perception.last_position(player).distance_to(player.global_position) < 0.01, "Reappearing in sight reacquires the current real position")
	bot.rebuild(Vector3(18, 0.1, 10))
	check(not bot.perception.has_memory(player) and not bot.searching, "Rebuild clears obsolete sensory memory")
	director.actors = [bot]
	bot.target = null
	bot._think = 0
	bot._route.clear()
	bot._patrol_until = 0
	bot.set_physics_process(true)
	var from := bot.global_position
	await frames(90)
	check(bot.global_position.distance_to(from) > 1 and bot.patrol_steps > 0, "An idle creature physically patrols accessible geometry")
	player.set_mouse_captured(false)
	print("RIFTERMATH_PERCEPTION_RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
