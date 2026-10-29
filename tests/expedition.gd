extends "res://tests/live_combat.gd"

const SAVE := "res://.local/expedition-qa-save.json"


func _run() -> void:
	set_meta("expedition_save_path", SAVE)
	set_meta("expedition_new_seed", 37216)
	await load_level("res://scenes/expedition.tscn")
	player.invulnerability = 10000
	await generation_checks()
	await quest_checks()
	await persistence_checks()
	await traversal_checks()
	check(completed_suites == 4, "All procedural region and quest suites completed")
	player.set_mouse_captured(false)
	print("RIFTERMATH_EXPEDITION_RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func generation_checks() -> void:
	var director := game.match_director as ExpeditionDirector
	var region := director.region
	check(region.districts.size() == 9 and region.sites.size() == 3, "The open region contains nine districts and three real quest sites")
	var hostile := 0
	for district in region.districts:
		hostile += int(district["hostile"])
	check(hostile == 4 and director.safe_at(Vector3.ZERO), "The world includes both hostile districts and a safe central refuge")
	check(director.keeper != null and director.pylons.size() == 3, "A living NPC and spatial quest receivers exist in the world")
	var kinds: Dictionary = {}
	for actor in director.actors:
		if actor is CombatBot: kinds[actor.kind] = true
	check(kinds.size() == 6, "Regional encounters include all six enemy behaviours")
	var nav := game.get_node("Navigation") as BattleNavigation
	var paths := true
	for site in region.sites:
		var path := nav.route(Vector3(0, 0.1, 14), site["at"])
		paths = paths and not path.is_empty() and path[-1].distance_to(site["at"]) < 5
	check(paths, "Every shrine, including the rooftop one, has a connected route from refuge")
	var holder := Node3D.new()
	root.add_child(holder)
	var copy := ExpeditionRegion.new()
	copy.seed_value = region.seed_value
	copy.position.x = 450
	holder.add_child(copy)
	check(copy.fingerprint == region.fingerprint and copy.obstacles == region.obstacles, "The same seed reproduces district order and actual obstacle placement")
	var other := ExpeditionRegion.new()
	other.seed_value = region.seed_value + 41
	other.position.x = 900
	holder.add_child(other)
	check(other.fingerprint != region.fingerprint or other.obstacles != region.obstacles, "A different seed changes the generated region")
	holder.queue_free()
	await frames(180)
	var safe := true
	for actor in director.actors:
		if actor is CombatBot and actor.target == player: safe = false
	check(safe, "Enemies do not acquire the player through the safe-refuge boundary")
	player.invulnerability = 0
	var health := player.hp
	player.receive_damage(30)
	check(player.hp == health and player.invulnerability == 0 and not player.can_receive_hit(), "Sanctuary itself protects against damage without a temporary invulnerability timer")
	var attacker: CombatBot
	for actor in director.actors:
		if actor is CombatBot:
			attacker = actor
			break
	var data := GestureRecognizer.recognize(GestureRecognizer.template(&"HOLLOW"), 0.4)
	var at := player.combat_aim_point() + Vector3(1.5, 0, 0)
	var field := RiftCaster.cast(game, data, Transform3D(Basis.IDENTITY, at), at, attacker) as HollowField
	field.age = 0.5
	await frames(8)
	check(absf(player.velocity.x) < 0.01, "Hostile spatial fields cannot pull a player out of sanctuary")
	field.queue_free()
	player.invulnerability = 10000
	completed_suites += 1


func traversal_checks() -> void:
	var director := game.match_director as ExpeditionDirector
	director._wake_clock = 10000
	for actor in director.actors:
		if actor is CombatBot: actor.set_physics_process(false)
	player.global_position = Vector3(0, 0.15, 14)
	player.velocity = Vector3.ZERO
	player.invulnerability = 10000
	player.set_mouse_captured(true)
	var destination: Vector3 = director.region.sites[1]["center"] + Vector3(12, 14, -8)
	var route := (game.get_node("Navigation") as BattleNavigation).route(player.global_position, destination)
	var waypoint := 1
	var peak := 0.0
	var largest_step := 0.0
	Input.action_press("move_forward")
	for i in range(7000):
		if waypoint >= route.size(): break
		var offset := route[waypoint] - player.global_position
		var flat := Vector2(offset.x, offset.z)
		if flat.length() < 0.9 and absf(offset.y) < 1.3:
			waypoint += 1
			continue
		player.rotation.y = atan2(-offset.x, -offset.z)
		var before := player.global_position
		await frames(1)
		peak = maxf(peak, player.global_position.y)
		largest_step = maxf(largest_step, player.global_position.distance_to(before))
	Input.action_release("move_forward")
	check(waypoint >= route.size() and peak > 13.8, "Normal FPS movement traverses the region and climbs both real ramps to the fourteen-metre watchtower")
	check(largest_step < 0.7, "The regional walk reaches its destination without respawn or teleport shortcuts")
	print("REGION_TRAVERSAL_METRICS: reached=", waypoint, "/", route.size(), " peak=", peak, " max_step=", largest_step, " at=", player.global_position)
	completed_suites += 1


func speak_to_keeper() -> void:
	var keeper := (game.match_director as ExpeditionDirector).keeper
	player.global_position = keeper.global_position + Vector3(0, 0, 4.2)
	player.velocity = Vector3.ZERO
	player.rotation.y = 0
	player.head.rotation.x = 0
	player.set_mouse_captured(true)
	await frames(4)
	key(KEY_E)
	await frames(2)


func quest_checks() -> void:
	var director := game.match_director as ExpeditionDirector
	await speak_to_keeper()
	check(director.profile.stage == 1 and game.hud.dialog_remaining > 0, "Real E input starts the NPC quest with visible dialogue")
	check(not director.try_seal(0, &"HOLLOW") and director.profile.seals.is_empty(), "A protected shrine cannot be claimed before defeating its guards")
	for site in range(3):
		for actor in director.actors:
			if actor is CombatBot and int(actor.get_meta("site_index", -1)) == site:
				actor.invulnerability = 0
				CombatRules.hit(actor, 10000, Vector3.FORWARD, Vector3.UP, actor.combat_aim_point(), 553200 + site, player, &"SIMPLEX")
		check(director.guards_left(site) == 0, "Defeating the real guards unlocks site %d" % site)
		check(not director.try_seal(site, &"SCAR"), "A plain line cannot substitute for site %d's required symbol" % site)
		var pylon := director.pylons[site]
		player.global_position = pylon.global_position + Vector3(0, 0.2, 7)
		player.velocity = Vector3.ZERO
		var at := pylon.combat_aim_point() + Vector3(0, 0, 3)
		var data := GestureRecognizer.recognize(GestureRecognizer.template(pylon.required), 0.35)
		var attack := RiftCaster.cast(game, data, Transform3D(Basis.IDENTITY, at), at, player)
		if attack is HollowField:
			attack.global_position = pylon.combat_aim_point()
			attack.age = 0.5
		await frames(100)
		check(director.profile.seals.has(site), "Actual %s geometry activates its shrine" % String(pylon.required))
	check(director.profile.stage == 2, "All three different symbols advance the quest to the return stage")
	await speak_to_keeper()
	check(director.profile.stage == 3 and player.max_hp == 120 and player.hp == 120, "Returning to the NPC completes the quest and grants the permanent reward")
	await speak_to_keeper()
	check(player.max_hp == 120, "Repeated conversations cannot duplicate the maximum-health reward")
	completed_suites += 1


func persistence_checks() -> void:
	await load_level("res://scenes/expedition.tscn")
	var director := game.match_director as ExpeditionDirector
	check(director.profile.seed_value == 37216 and director.profile.stage == 3 and director.profile.seals.size() == 3, "Reload preserves the actual seed and completed quest")
	check(player.max_hp == 120 and director.guards_left(0) == 0 and director.guards_left(1) == 0, "The reward and cleared encounters survive regeneration")
	player.global_position = director.region.sites[2]["at"] + Vector3(0, 0.15, 10)
	player.invulnerability = 0
	player.receive_damage(10000)
	await frames(330)
	check(not player.dead and player.global_position.distance_to(Vector3(0, 0.1, 14)) < 1, "Expedition death physically returns the player to refuge")
	check(director.profile.stage == 3 and player.max_hp == 120, "Death preserves restored seals and the earned reward")
	var protected_path := "res://.local/expedition-unknown-qa.json"
	var original := "{\"version\":777,\"keep\":\"original unknown data\"}"
	var file := FileAccess.open(protected_path, FileAccess.WRITE)
	file.store_string(original)
	file.close()
	set_meta("expedition_save_path", protected_path)
	var unknown := ExpeditionState.read(self)
	check(not unknown.write_allowed and not unknown.save() and FileAccess.get_file_as_string(protected_path) == original, "Unknown save formats are preserved byte-for-byte")
	completed_suites += 1
