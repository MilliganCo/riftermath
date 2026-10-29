extends "res://tests/expedition_picker_visual.gd"


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Perception verification needs GPU rendering")
		quit(1)
		return
	output = ProjectSettings.globalize_path("res://.local/perception-visual-qa")
	DirAccess.make_dir_recursive_absolute(output)
	set_meta("battle_mode", 0)
	game = load("res://scenes/battle.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	player = game.get_node("Player")
	capture = player.get_node("GestureCapture")
	player.invulnerability = 10000
	player.set_mouse_captured(true)
	native_guard = INPUT_GUARD.new()
	root.add_child(native_guard)
	var director := game.match_director as MatchDirector
	for actor in director.actors:
		if actor is CombatBot:
			actor.set_physics_process(false)
			actor.global_position = Vector3(-32, 0.1, -32)
	var bot := director.actors[1] as CombatBot
	director.actors = [player, bot]
	bot.global_position = Vector3(19, 0.1, 8)
	bot.rotation.y = 0
	bot._attack_cooldown = 10000
	bot.perception.clear()
	player.global_position = Vector3(19, 0.1, 20)
	player.velocity = Vector3.ZERO
	await frames(3)
	bot._choose_target_and_route()
	var remembered := bot.perception.last_position(player)
	var observer := Camera3D.new()
	game.add_child(observer)
	observer.global_position = Vector3(22, 15, 24)
	observer.look_at(Vector3(13, 2.8, 11))
	observer.fov = 70
	observer.make_current()
	await frames(3)
	await snapshot("01-frontal-sight-acquisition")
	expect(bot.target == player and not bot.searching, "GPU creature acquires its visible target")
	player.global_position = Vector3(8, 0.1, 8)
	player.velocity = Vector3.ZERO
	bot.set_physics_process(true)
	await frames(30)
	await snapshot("02-search-last-seen-position")
	expect(bot.searching and bot.perception.last_position(player).distance_to(remembered) < 0.1, "Opaque authored cover leaves the live creature searching an old position")
	var gesture := GestureRecognizer.recognize(GestureRecognizer.template(&"SCAR"), 0.3)
	game._release_scar(gesture["points"], player.camera.global_transform.translated_local(Vector3(0, 0, -2)), 0.3)
	await frames(5)
	await snapshot("03-heard-rift-changes-search")
	expect(bot.perception.heard_events > 0 and bot.perception.last_position(player).distance_to(player.global_position) < 0.2, "A real hidden cast becomes a spatial sound clue")
	player.global_position = Vector3(-32, 0.1, 32)
	player.velocity = Vector3.ZERO
	await frames(330)
	await snapshot("04-memory-expires-to-patrol")
	expect(bot.target == null and bot.patrol_steps > 0, "Live search memory expires into accessible patrol movement")
	expect(color_count() <= 32, "Sensory gameplay keeps the global palette constraint")
	player.set_mouse_captured(false)
	print("RIFTERMATH_PERCEPTION_VISUAL_RESULT: %d GPU snapshots, %d failures" % [snapshots, errors])
	quit(0 if errors == 0 else 1)
