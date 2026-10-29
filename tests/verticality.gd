extends "res://tests/live_combat.gd"


func _run() -> void:
	await load_level("res://scenes/battle.tscn", 0)
	player.invulnerability = 10000
	for actor in game.match_director.actors:
		if actor is CombatBot:
			actor.set_physics_process(false)
			actor.global_position = Vector3(-32, 0.1, -32)
	var nav := game.get_node("Navigation") as BattleNavigation
	var arena := game.get_node("Arena") as BattleArena
	var gallery := nav.route(Vector3(28, 0.5, 32), Vector3(28, 7.1, 0))
	var roof := nav.route(Vector3(0, 0.1, 22), Vector3(16, 11.1, -25))
	check(not gallery.is_empty() and gallery[-1].y > 6.9, "Navigation reaches seven-metre choir galleries via actual ramps")
	check(not roof.is_empty() and roof[-1].y > 10.9, "Navigation connects the eleven-metre bell tower roof")
	var gradual := true
	for path in [gallery, roof]:
		for i in range(1, path.size()):
			gradual = gradual and absf(path[i].y - path[i - 1].y) <= 0.86
	check(gradual, "Vertical routes contain no teleporting graph edges between floors")
	var lower := nav.graph.get_closest_point(Vector3(28, 0.05, 0))
	var upper := nav.graph.get_closest_point(Vector3(28, 7.05, 0))
	check(lower != upper and nav.graph.get_point_position(lower).y < 0.1 and nav.graph.get_point_position(upper).y > 6.9, "A single horizontal cell retains separate ground and bridge layers")
	check(arena.support_height(Vector3(28, 0.1, 0)) == 0 and arena.support_height(Vector3(28, 7.1, 0)) == 7, "Support height distinguishes walking underneath from walking on top")
	var lift := get_nodes_in_group("rift_lifts")[0] as RiftLift
	player.global_position = lift.global_position + Vector3.UP * 0.15
	player.velocity = Vector3.ZERO
	await frames(4)
	check(lift.launches > 0 and player.velocity.y > 20, "Entering a real lift applies vertical launch velocity")
	var peak := player.global_position.y
	for i in range(160):
		await frames(1)
		peak = maxf(peak, player.global_position.y)
	check(peak > 10, "The player physically reaches more than ten metres of height")
	await frames(90)
	check(player.is_on_floor() and player.global_position.y > 6.9, "Lift carry lands the player on a traversable upper gallery")
	var bot := game.match_director.actors[1] as CombatBot
	bot.global_position = Vector3(28, arena.floor_height(Vector2(28, 32)) + 0.12, 32)
	bot.velocity = Vector3.ZERO
	bot.director = null
	bot.target = null
	bot._route = gallery.duplicate()
	bot._waypoint = 1
	bot._think = 10000
	bot._attack_cooldown = 10000
	bot.set_physics_process(true)
	var bot_peak := 0.0
	for i in range(1000):
		await frames(1)
		bot_peak = maxf(bot_peak, bot.global_position.y)
	check(bot_peak > 6.8 and bot.global_position.y > 6.8, "A live bot physically walks the ramps to the upper floor")
	bot.target = player
	player.global_position = Vector3(18, 0.1, 5)
	# Fire from the gallery lip: its solid floor correctly blocks a steep shot from the centre.
	bot.global_position = Vector3(24.8, 7.1, 0)
	bot.rotation.y = atan2(player.global_position.x - bot.global_position.x, player.global_position.z - bot.global_position.z)
	bot._route.clear()
	bot._attack_cooldown = 0
	var previous := bot.casts_completed
	await frames(105)
	check(bot.casts_completed > previous, "An upper-gallery enemy can draw and shoot at a lower-floor player")
	print("VERTICAL_METRICS: player_peak=", peak, " bot_peak=", bot_peak, " gallery_nodes=", gallery.size(), " roof_nodes=", roof.size())
	player.set_mouse_captured(false)
	print("RIFTERMATH_VERTICAL_RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
