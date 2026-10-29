extends "res://tests/integration.gd"


func _run() -> void:
	await load_level("res://scenes/main.tscn")
	await shape_and_attack_checks()
	await load_level("res://scenes/battle.tscn", 0)
	await navigation_and_bot_checks()
	await load_level("res://scenes/battle.tscn", 1)
	await team_checks()
	await load_level("res://scenes/battle.tscn", 2)
	await survival_checks()
	check(completed_suites == 4, "Every live-combat suite completed")
	player.set_mouse_captured(false)
	print("RIFTERMATH_LIVE_RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func load_level(path: String, mode: int = 0) -> void:
	if is_instance_valid(game):
		game.queue_free()
		await process_frame
	get_tree_mode(mode)
	game = load(path).instantiate()
	root.add_child(game)
	current_scene = game
	player = game.get_node("Player")
	capture = player.get_node("GestureCapture")
	await frames(8)


func get_tree_mode(mode: int) -> void:
	set_meta("battle_mode", mode)


func shape_and_attack_checks() -> void:
	for ability in [&"SCAR", &"FANG", &"CHAINBREAK", &"HOLLOW", &"SIMPLEX", &"FOLD", &"HYPERCUT"]:
		var result := GestureRecognizer.recognize(GestureRecognizer.template(ability), 0.3)
		check(result["ability"] == ability, "Canonical shape recognizes " + String(ability))
	var noisy := PackedVector2Array()
	var v := GestureRecognizer.template(&"FANG")
	for i in range(2):
		for j in range(15):
			noisy.append(v[i].lerp(v[i + 1], float(j) / 14) + Vector2(sin(j * 2.1), cos(j * 3.1)) * 0.012)
	check(GestureRecognizer.recognize(noisy, 0.4)["ability"] == &"FANG", "Noisy V remains a FANG")
	var pose := Transform3D(Basis.IDENTITY, Vector3(0, 3, 8))
	var data := GestureRecognizer.recognize(v, 0.3)
	var fang := RiftCaster.cast(game, data, pose, pose.origin, player) as FangProjectile
	await frames(45)
	check(fang.burst and get_nodes_in_group("rift_projectiles").size() >= 5, "FANG actually opens and emits a geometric fan")
	await frames(140)
	var a := game.get_node("Targets").get_child(0) as EnemyController
	a.hp = 100
	a.dead = false
	a.visual.show()
	a.collision.set_deferred("disabled", false)
	var extra := load("res://scenes/target.tscn").instantiate() as EnemyController
	game.get_node("Targets").add_child(extra)
	extra.position = Vector3(4, 0, -9)
	await frames(2)
	var chain_data := GestureRecognizer.recognize(GestureRecognizer.template(&"CHAINBREAK"), 0.3)
	chain_data["damage"] = 20.0
	pose.origin = Vector3(0, 2.5, -6)
	var chain := RiftCaster.cast(game, chain_data, pose, pose.origin, player) as ChainbreakProjectile
	await frames(65)
	check(chain.chain_started and extra.hp < 100, "CHAINBREAK reaches another nearby target after first contact")
	extra.queue_free()
	player.invulnerability = 0
	player.hp = 75
	var bolt := EnemyBolt.new()
	game.get_node("HostileProjectiles").add_child(bolt)
	bolt.source_ref = weakref(a)
	bolt.configure(player.camera.global_position + Vector3.FORWARD * 2.5, player.combat_aim_point(), 10)
	var parry := player.get_node("Parry") as ParryController
	check(parry.activate(), "RMB parry window can activate")
	await frames(2)
	check(bolt.reflected and bolt.get_source() == player and parry.count == 1, "Parry reverses a hostile projectile and its ownership")
	check(player.hp == 83 and not parry.activate(), "Parry heals and its cooldown blocks repeat activation")
	check(SynthAudio.make_sound(&"parry").get_length() > 0.2, "Procedural combat audio contains actual PCM samples")
	game.hud.register_parry()
	check(game.hud.style_points >= 90 and game.hud.style_rank() != "D", "Actions feed the D to SSS style meter")
	player.energy = 0
	var previous_cast: Node3D = game.last_cast
	game._release_scar(GestureRecognizer.template(&"SCAR"), pose, 0.2)
	check(game.last_cast == previous_cast and game.hud.notice == "RIFT RECHARGING", "Insufficient rift energy rejects the cast with visible feedback")
	player.energy = 100
	completed_suites += 1


func navigation_and_bot_checks() -> void:
	var nav := game.get_node("Navigation") as BattleNavigation
	var arena := game.get_node("Arena") as BattleArena
	check(nav.graph.get_point_count() > 1000, "Battle map has a connected 3D navigation graph")
	var path := nav.route(Vector3(-20, 0, -8), Vector3(-7, 0, -8))
	var length := 0.0
	var avoids_cover := true
	for i in range(path.size()):
		if i > 0:
			length += path[i].distance_to(path[i - 1])
		for obstacle in arena.obstacles:
			if obstacle.grow(0.5).has_point(Vector2(path[i].x, path[i].z)):
				avoids_cover = false
	check(avoids_cover and length > 16.0, "Navigation goes around solid cover instead of aiming through it")
	var high_path := nav.route(Vector3(0, 0, 22), Vector3(4, 3, 4))
	check(not high_path.is_empty() and high_path[-1].y > 2.9, "Routes reach the raised altar via a ramp")
	var director := game.get_node("MatchDirector") as MatchDirector
	check(director.actors.size() == 8, "Deathmatch includes the player and seven live bots")
	player.max_hp = 10000
	player.hp = 10000
	player.invulnerability = 0
	director.score_limit = 1000
	var observed_drawing := false
	var observed_moving_drawing := false
	var bots_fight_bots := false
	for i in range(950):
		await frames(1)
		for actor in director.actors:
			if actor is CombatBot:
				observed_drawing = observed_drawing or is_instance_valid(actor._telegraph)
				observed_moving_drawing = observed_moving_drawing or (is_instance_valid(actor._telegraph) and Vector2(actor.velocity.x, actor.velocity.z).length() > 1.0)
				bots_fight_bots = bots_fight_bots or actor.target is CombatBot
	var travelled := 0.0
	var attacks := 0
	var replans := 0
	var hovering := false
	for actor in director.actors:
		if actor is CombatBot:
			travelled += actor.distance_travelled
			attacks += actor.casts_completed
			replans += actor.nav_replans
			if actor.kind == CombatBot.Kind.SWARM and actor.global_position.y > arena.support_height(actor.global_position) + 0.8:
				hovering = true
	check(travelled > 35 and replans > 20, "Bots actually pursue and replan while moving")
	check(observed_drawing and attacks >= 3, "Moving bots visibly draw and release their own rifts")
	check(observed_moving_drawing, "Enemy drawing does not stop its physical movement")
	check(hovering, "SWARM creatures physically hover above the floor instead of walking")
	check(bots_fight_bots, "FFA bots fight one another, not only the player")
	var one := director.actors[1] as CombatBot
	one.invulnerability = 0
	var before: int = director.scores[player.get_instance_id()]["kills"]
	CombatRules.hit(one, 10000, Vector3.FORWARD, Vector3.UP, one.combat_aim_point(), 778899, player)
	check(director.scores[player.get_instance_id()]["kills"] == before + 1, "Attributed FFA kill increments the attacker's score")
	await frames(320)
	check(not one.dead and director.respawns > 0, "Deathmatch bots respawn and return to combat")
	director.score_limit = director.scores[player.get_instance_id()]["kills"] + 1
	one.invulnerability = 0
	CombatRules.hit(one, 10000, Vector3.FORWARD, Vector3.UP, one.combat_aim_point(), 778900, player)
	check(director.ended and director.winner == "YOU", "FFA reaches its score limit and declares a winner")
	completed_suites += 1


func team_checks() -> void:
	var director := game.get_node("MatchDirector") as MatchDirector
	var ally := director.actors[1] as CombatBot
	var enemy := director.actors[4] as CombatBot
	check(ally.global_position.x < 0 and enemy.global_position.x > 0 and ally.bot_name.begins_with("ASH"), "Teams have separate spawn sides and readable faction labels")
	var pools := [0.0, 0.0]
	for actor in director.actors:
		if actor is PlayerController: pools[actor.team_id] += actor.max_hp
		elif actor is CombatBot: pools[actor.team_id] += actor.hull.max_hp
	check(absf(pools[0] - pools[1]) < 50, "Heavy new archetypes are distributed across both teams instead of stacking one health pool")
	ally.invulnerability = 0
	enemy.invulnerability = 0
	var health := ally.hull.hp
	CombatRules.hit(ally, 100, Vector3.FORWARD, Vector3.UP, ally.combat_aim_point(), 222, player)
	check(ally.hull.hp == health and not CombatRules.can_hit(player, ally), "Team mode prevents friendly fire")
	check(CombatRules.can_hit(player, enemy), "Opposing team is a valid target")
	CombatRules.hit(enemy, 10000, Vector3.FORWARD, Vector3.UP, enemy.combat_aim_point(), 223, player)
	check(director.team_scores[0] == 1 and director.team_scores[1] == 0, "Team elimination updates the correct team score")
	check(director.board_text().contains("YOU") and director.board_text().contains("K / D"), "Scoreboard exposes names and kills/deaths")
	await load_level("res://scenes/battle.tscn", 0)
	var timed := game.get_node("MatchDirector") as MatchDirector
	timed.time_limit = 0.001
	timed._process(0.01)
	check(timed.ended and timed.winner.contains("DRAW"), "A time-limit tie is declared as a draw")
	completed_suites += 1


func survival_checks() -> void:
	var director := game.get_node("MatchDirector") as MatchDirector
	check(director.wave == 1 and director.living_enemies() == 4, "Survival opens with a live enemy wave")
	for actor in director.actors.duplicate():
		if actor is CombatBot:
			actor.invulnerability = 0
			CombatRules.hit(actor, 10000, Vector3.FORWARD, Vector3.UP, actor.combat_aim_point(), 224, player)
	await frames(375)
	check(director.wave == 2 and director.living_enemies() == 6, "Clearing a wave produces a larger next wave")
	player.invulnerability = 0
	player.receive_damage(10000, director.actors[-1])
	check(director.ended and player.dead, "Survival ends on player death without an endless free respawn")
	completed_suites += 1
