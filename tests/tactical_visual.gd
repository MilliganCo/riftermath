extends "res://tests/expansion_visual.gd"


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Tactical visual verification requires GPU rendering.")
		quit(1)
		return
	output = ProjectSettings.globalize_path("res://.local/tactical-visual-qa")
	DirAccess.make_dir_recursive_absolute(output)
	root.title = "RIFTERMATH / evasive drawing and recovery"
	set_meta("battle_mode", 1)
	game = load("res://scenes/battle.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	player = game.get_node("Player")
	capture = player.get_node("GestureCapture")
	native_guard = INPUT_GUARD.new()
	root.add_child(native_guard)
	player.invulnerability = 10000
	player.global_position = Vector3(18, 0.1, 25)
	player.set_mouse_captured(true)
	var director := game.match_director as MatchDirector
	for actor in director.actors:
		if actor is CombatBot:
			actor.set_physics_process(false)
			actor.global_position = Vector3(-32, 0.1, -32)
	var bot := director.actors[4] as CombatBot
	bot.global_position = Vector3(18, 0.1, 12)
	bot.rotation = Vector3.ZERO
	bot.invulnerability = 10000
	bot.director = null
	bot.target = player
	bot._think = 10000
	bot._attack_cooldown = 0
	bot.tactics.cooldown = 0
	var observer := Camera3D.new()
	game.add_child(observer)
	observer.global_position = Vector3(23, 5.5, 21)
	observer.look_at(bot.global_position + Vector3.UP * 2.5)
	observer.fov = 68
	observer.make_current()
	await frames(5)
	var data := GestureRecognizer.recognize(GestureRecognizer.template(&"SCAR"), 0.2)
	var at := bot.combat_aim_point() + Vector3(0, 0, 8)
	var attack := RiftCaster.cast(game, data, Transform3D(Basis.IDENTITY, at), at, player) as RiftProjectile
	attack.speed = 22
	attack.phase = RiftProjectile.Phase.PROPAGATION
	attack._muzzle_checked = true
	bot.set_physics_process(true)
	await frames(4)
	await snapshot("01-incoming-rift-and-windup")
	var before := bot.global_position
	await frames(10)
	await snapshot("02-evasive-drawing")
	expect(bot.tactics.evasions == 1 and bot.global_position.distance_to(before) > 0.45, "GPU creature physically evades an incoming spatial cut")
	expect(is_instance_valid(bot._telegraph), "GPU creature keeps drawing during its evasive move")
	await frames(ceili(bot.windup_duration() * 60) + 6)
	expect(bot.casts_completed > 0, "Evasive creature completes and releases its attack")
	bot.set_physics_process(false)
	bot._cancel_drawing()
	player.camera.make_current()
	aim_at(Vector3(18, 1.7, 19))
	player.hp = 55
	player.energy = 100
	var victim := director.actors[5] as CombatBot
	victim.global_position = Vector3(18, 0.1, 19)
	victim.invulnerability = 0
	CombatRules.hit(victim, 10000, Vector3.FORWARD, Vector3.UP, victim.combat_aim_point(), 4682001, player)
	await frames(6)
	await snapshot("03-recovery-shard")
	expect(get_nodes_in_group("recovery_shards").size() == 1, "GPU enemy elimination creates a visible recovery shard")
	player.global_position = Vector3(18, 0.1, 21.7)
	await frames(30)
	await snapshot("04-mended-in-the-field")
	expect(player.hp == 67 and get_nodes_in_group("recovery_shards").is_empty(), "GPU player collects the shard and regains twelve HP")
	player.set_mouse_captured(false)
	print("RIFTERMATH_TACTICAL_VISUAL_RESULT: %d GPU snapshots, %d failures" % [snapshots, errors])
	quit(0 if errors == 0 else 1)
