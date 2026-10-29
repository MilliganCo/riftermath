extends "res://tests/live_combat.gd"


func _run() -> void:
	await load_level("res://scenes/battle.tscn", 1)
	player.invulnerability = 10000
	player.global_position = Vector3(18, 0.1, 26)
	for actor in game.match_director.actors:
		if actor is CombatBot:
			actor.set_physics_process(false)
			actor.global_position = Vector3(-32, 0.1, -32)
	await profile_checks()
	await attack_and_support_checks()
	await animation_checks()
	check(completed_suites == 3, "All archetype and animation suites completed")
	player.set_mouse_captured(false)
	print("RIFTERMATH_ARCHETYPES_RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func fixture(index: int) -> CombatBot:
	var bot := game.match_director.actors[index] as CombatBot
	bot.global_position = Vector3(18, 0.1, 12)
	bot.rotation = Vector3.ZERO
	bot.invulnerability = 0
	bot.hull.hp = bot.hull.max_hp
	bot.traits.exposed = 0
	bot.traits.combo_window = 0
	bot.traits.last_ability = &""
	bot.traits.phase_clock = 0
	return bot


func strike(bot: CombatBot, ability: StringName, direction: Vector3 = Vector3.FORWARD, reflected: bool = false) -> float:
	var hp := bot.hull.hp
	CombatRules.hit(bot, 60, direction, Vector3.UP, bot.combat_aim_point(), 884410, player, ability, reflected)
	return hp - bot.hull.hp


func profile_checks() -> void:
	var tank := fixture(4)
	check(tank.kind == CombatBot.Kind.TANK and tank.hull.max_hp == 260, "The match includes a distinct heavy TANK")
	var line := strike(tank, &"SCAR")
	check(line < 15, "Front armor meaningfully resists a plain line")
	tank = fixture(4)
	var fang := strike(tank, &"FANG")
	check(fang > line * 4 and tank.traits.exposed > 2, "A V breaks frontal armor and opens a follow-up window")
	check(strike(tank, &"SCAR") > line * 3, "A line becomes effective after opening the armor")
	tank = fixture(4)
	check(strike(tank, &"SIMPLEX") > 80, "Triangle damage is particularly effective against armor")
	tank = fixture(4)
	check(strike(tank, &"SCAR", Vector3.BACK) == 60, "A real rear attack bypasses frontal armor")
	var phase := fixture(5)
	check(phase.kind == CombatBot.Kind.PHASE_ENTITY and phase.traits.phased(), "PHASE ENTITY begins with displaced projections")
	var weak := strike(phase, &"SCAR")
	check(weak < 10, "An unanchored phase entity strongly resists plain cuts")
	phase = fixture(5)
	check(strike(phase, &"CHAINBREAK") > 70 and not phase.traits.phased(), "Z anchors the phase entity and deals effective damage")
	phase = fixture(5)
	phase.field_contact(&"HOLLOW", player)
	check(not phase.traits.phased() and strike(phase, &"SCAR") == 60, "A circular field anchors a projection for subsequent cuts")
	phase = fixture(5)
	check(strike(phase, &"HYPERCUT") > 70, "Spatial-window attacks pierce the phase defense")
	phase = fixture(5)
	phase.traits.phase_clock = 3.3
	check(not phase.traits.phased() and strike(phase, &"SCAR") == 60, "Phase cycle provides a natural vulnerability window too")
	completed_suites += 1


func attack_and_support_checks() -> void:
	for index in [4, 5, 6]:
		var bot := fixture(index)
		bot.target = player
		bot._begin_drawing()
		var muzzle := bot.combat_aim_point()
		var toward := (player.combat_aim_point() - muzzle).normalized()
		bot._telegraph.global_transform = Transform3D(Basis.looking_at(toward), muzzle)
		bot._release_rift(muzzle)
		var found := false
		for node in game.get_node("Rifts").get_children():
			if index == 4 and node is SimplexProjectile:
				found = node.blast_damage == 26 and node.fuse > 0.9
			elif index == 5 and node is HollowField:
				found = node.collapse_damage == 24 and node.age == 0.4
			elif index == 6 and node is FoldField:
				found = true
		check(found, "New archetype %d creates its real distinct attack" % index)
		if index == 6:
			await frames(4)
			var outbound := 0
			for node in game.get_node("Rifts").get_children():
				if node is RiftProjectile and node.get_source() == bot:
					var aim: Vector3 = (player.combat_aim_point() - node.global_position).normalized()
					if not node.reflected and (-node.global_basis.z).dot(aim) > 0.9: outbound += 1
			check(outbound == 2, "Cantor volleys reach beyond its own fold and keep aiming at the player")
		for node in game.get_node("Rifts").get_children():
			node.queue_free()
		await frames(2)
	var cantor := fixture(6)
	var ally := fixture(4)
	ally.global_position.x += 3
	ally.hull.hp -= 40
	var health := ally.hull.hp
	cantor.traits.heal_clock = 0
	cantor.traits.step(0.1)
	check(ally.hull.hp == health + 14 and cantor.traits.heals_sent > 0, "CANTOR really mends a nearby injured ally")
	cantor.traits.exposed = 2
	cantor.traits.heal_clock = 0
	health = ally.hull.hp
	cantor.traits.step(0.1)
	check(ally.hull.hp == health, "An interrupted cantor cannot heal allies")
	cantor = fixture(6)
	cantor._begin_drawing()
	check(strike(cantor, &"SCAR", Vector3.FORWARD, true) > 80 and cantor._windup == 0, "A reflected attack interrupts the chant and rewards its counter")
	completed_suites += 1


func animation_checks() -> void:
	var bot := fixture(1)
	bot.velocity = Vector3(6, 0, 0)
	var foot: Node3D
	var claw: Node3D
	for part in bot.hull._parts:
		if part["tag"] == "foot": foot = part["node"]
		if part["tag"] == "claw": claw = part["node"]
	var initial_foot := foot.position
	for i in range(8): bot.hull.animator.step(0.1)
	check(foot.position.distance_to(initial_foot) > 0.2, "Locomotion animates individual feet rather than only the whole body")
	var initial_hand := claw.position
	bot._windup = 0.55
	bot.hull.animator.step(0.2)
	check(claw.position.y > initial_hand.y + 0.5, "Drawing raises articulated arms and claws")
	var finite := true
	for part in bot.hull._parts:
		var node := part["node"] as Node3D
		finite = finite and node.transform.is_finite() and node.basis.determinant() > 0.01
	check(finite, "All animated anatomical transforms remain finite and nondegenerate")
	bot.hull.scale = Vector3(1.5, 1.12, 0.65)
	var hand_pose := claw.global_position
	var cut_normal := Vector3(0.7, 1.0, 0.3).normalized()
	var cut_point := bot.combat_aim_point()
	CombatRules.hit(bot, 10000, Vector3.FORWARD, cut_normal, cut_point, 884411, game.match_director.actors[4])
	var plane_respected := true
	var examined := 0
	for piece in get_nodes_in_group("combat_debris"):
		if piece.immune_scar_id != 884411 or piece.geometry.get_aabb().size.length() < 0.7: continue
		var low := INF
		var high := -INF
		for vertex in piece.geometry.get_faces():
			var signed_distance := cut_normal.dot(piece.to_global(vertex) - cut_point)
			low = minf(low, signed_distance)
			high = maxf(high, signed_distance)
		if low < -0.025 and high > 0.025: plane_respected = false
		examined += 1
	check(plane_respected and examined > 5, "Animated nonuniform anatomy is cut along the actual world-space gesture plane")
	await frames(2)
	var close_fragment := false
	for piece in get_nodes_in_group("combat_debris"):
		if piece.global_position.distance_to(hand_pose) < 0.7:
			close_fragment = true
	check(bot.dead and close_fragment, "Death emits actual fragments from the current articulated pose")
	completed_suites += 1
