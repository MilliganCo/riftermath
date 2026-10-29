extends "res://tests/live_combat.gd"


func _run() -> void:
	set_meta("expedition_save_path", "res://.local/echo-contract-qa-save.json")
	set_meta("expedition_new_seed", 37216)
	await load_level("res://scenes/expedition.tscn")
	player.invulnerability = 10000
	await contract_checks()
	await rune_checks()
	check(completed_suites == 2, "Both echo contract and rune suites completed")
	player.set_mouse_captured(false)
	print("RIFTERMATH_ECHO_CONTRACT_RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func talk_to_scribe() -> void:
	var director := game.match_director as ExpeditionDirector
	player.global_position = director.scribe.global_position + Vector3(0, 0, 4.2)
	player.velocity = Vector3.ZERO
	player.rotation.y = 0
	player.head.rotation.x = 0
	player.set_mouse_captured(true)
	await frames(3)
	key(KEY_E)
	await frames(2)


func contract_checks() -> void:
	var director := game.match_director as ExpeditionDirector
	director._wake_clock = 10000
	for actor in director.actors:
		if actor is CombatBot: actor.set_physics_process(false)
	check(director.scribe != null and director.scribe.scribe_mode and director.region.district_at(director.scribe.global_position)["index"] == 7, "A distinct animated scribe lives in the actual market district")
	await talk_to_scribe()
	check(director.profile.side_stage == 0 and player.rune.is_empty(), "Scribe does not skip the first quest or grant an early rune")
	director.profile.stage = 3
	director.profile.seals = [0, 1, 2]
	await talk_to_scribe()
	check(director.profile.side_stage == 1 and director.profile.tracked == 4, "Actual E input starts the follow-up contract and tracks its first echo")
	var echoes: Array[CombatBot] = []
	for actor in director.actors:
		if actor is CombatBot and actor.has_meta("echo_id"):
			actor.set_physics_process(false)
			echoes.append(actor)
	check(echoes.size() == 2 and echoes[0].elite and echoes[1].elite, "Contract spawns two real named elite enemies")
	check(echoes[0].hull.max_hp > 390 and echoes[1].hull.max_hp > 170, "Elite anatomy has actual increased health, not only a label")
	for echo in echoes:
		echo.invulnerability = 0
		var before := echo.attack_ability()
		CombatRules.hit(echo, echo.hull.max_hp * 0.55, Vector3.BACK, Vector3.UP, echo.combat_aim_point(), 92710, player, &"HYPERCUT")
		echo.set_physics_process(true)
		await frames(2)
		echo.set_physics_process(false)
		check(echo.elite_phase == 2 and echo.phase_changes == 1 and echo.attack_ability() != before, "Wounded echo enters a single new phase with a genuinely different rift")
		echo._update_elite_phase()
		check(echo.phase_changes == 1 and echo.windup_duration() >= 0.7, "Elite phase cannot stack repeatedly and retains a readable windup")
		player.global_position = echo.global_position + Vector3(0, 0, 9)
		echo.target = player
		echo._begin_drawing()
		var muzzle := echo.combat_aim_point()
		echo._telegraph.global_transform = Transform3D(Basis.looking_at((player.combat_aim_point() - muzzle).normalized()), muzzle)
		echo._release_rift(muzzle)
		var phase_attack := false
		for node in game.get_node("Rifts").get_children():
			if echo.kind == CombatBot.Kind.TANK and node is FangProjectile: phase_attack = true
			elif echo.kind == CombatBot.Kind.PHASE_ENTITY and node is ChainbreakProjectile: phase_attack = true
		check(phase_attack, "Second phase releases its new real projectile geometry")
		for node in game.get_node("Rifts").get_children(): node.queue_free()
		await frames(2)
		CombatRules.hit(echo, 10000, Vector3.BACK, Vector3.UP, echo.combat_aim_point(), 92711, player, &"SIMPLEX")
	await frames(2)
	check(director.profile.echoes.size() == 2 and director.profile.side_stage == 2 and director.profile.tracked == 3, "Real elite eliminations complete the hunt and direct the player back")
	await talk_to_scribe()
	check(game.hud.dialog_text.contains("1 —") and game.hud.dialog_text.contains("2 —"), "Return conversation presents two explicit reward choices")
	director.profile.write_allowed = false
	check(not director.choose_rune(&"fracture") and director.profile.side_stage == 2 and player.rune.is_empty(), "A failed save does not consume the reward choice or grant an uncommitted rune")
	director.profile.write_allowed = true
	key(KEY_1)
	await frames(2)
	check(director.profile.side_stage == 3 and player.rune == &"fracture" and director.profile.rune == &"fracture", "Real number-key input grants and saves the fracture rune")
	check(not director.choose_rune(&"binding") and player.rune == &"fracture", "Completed contract cannot duplicate or replace its chosen permanent reward")
	await load_level("res://scenes/expedition.tscn")
	director = game.match_director as ExpeditionDirector
	check(director.profile.side_stage == 3 and player.rune == &"fracture" and director.profile.echoes.size() == 2, "Quest, elite defeats and rune restore after loading the same expedition")
	var remaining := 0
	for actor in director.actors:
		if actor is CombatBot and actor.has_meta("echo_id"): remaining += 1
	check(remaining == 0, "Defeated contract elites are not duplicated on reload")
	var alternate := ExpeditionState.new()
	alternate.path = "res://.local/echo-binding-choice-qa-save.json"
	alternate.seed_value = 37217
	alternate.stage = 3
	alternate.seals = [0, 1, 2]
	alternate.side_stage = 2
	alternate.echoes = [0, 1]
	alternate.save()
	set_meta("expedition_save_path", alternate.path)
	await load_level("res://scenes/expedition.tscn")
	player.invulnerability = 10000
	await talk_to_scribe()
	key(KEY_2)
	await frames(2)
	check(player.rune == &"binding" and game.profile.rune == &"binding" and game.profile.side_stage == 3, "The alternative number-key choice grants its own binding build in a separate expedition")
	await load_level("res://scenes/expedition.tscn")
	check(player.rune == &"binding", "Alternative reward persists independently from the fracture world")
	completed_suites += 1


func cast(ability: StringName, rune: StringName) -> Node3D:
	player.rune = rune
	var at := Vector3(20, 6, 18)
	var data := GestureRecognizer.recognize(GestureRecognizer.template(ability), 0.35)
	var result := RiftCaster.cast(game, data, Transform3D(Basis.IDENTITY, at), at, player)
	result.set_physics_process(false)
	return result


func rune_checks() -> void:
	var plain := cast(&"FANG", &"") as FangProjectile
	var empowered := cast(&"FANG", &"fracture") as FangProjectile
	check(is_equal_approx(empowered.damage, plain.damage * 1.18), "Fracture rune changes real FANG damage by eighteen percent")
	var a := cast(&"SIMPLEX", &"") as SimplexProjectile
	var b := cast(&"SIMPLEX", &"fracture") as SimplexProjectile
	check(is_equal_approx(b.blast_damage, a.blast_damage * 1.18) and b.damage > a.damage, "Fracture rune modifies both tetrahedron contact and actual blast damage")
	var scar_a := cast(&"SCAR", &"") as RiftProjectile
	var scar_b := cast(&"SCAR", &"fracture") as RiftProjectile
	check(scar_a.damage == scar_b.damage, "Rune is a specific build choice rather than an invisible bonus to line spam")
	for node in game.get_node("Rifts").get_children(): node.queue_free()
	await frames(2)
	var circle_a := cast(&"HOLLOW", &"") as HollowField
	var circle_b := cast(&"HOLLOW", &"binding") as HollowField
	check(circle_b.radius > circle_a.radius and is_equal_approx(circle_b.lifetime, circle_a.lifetime * 1.25), "Binding rune changes real circular field radius and duration")
	var fold_a := cast(&"FOLD", &"") as FoldField
	var fold_b := cast(&"FOLD", &"binding") as FoldField
	check(is_equal_approx(fold_b.lifetime, fold_a.lifetime * 1.35), "Binding rune prolongs actual redirecting folds")
	player.rune = &"fracture"
	completed_suites += 1
