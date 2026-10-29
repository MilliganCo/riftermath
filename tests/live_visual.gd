extends "res://tests/expansion_visual.gd"


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Live visual test requires GPU rendering.")
		quit(1)
		return
	output = ProjectSettings.globalize_path("res://.local/live-visual-qa")
	DirAccess.make_dir_recursive_absolute(output)
	root.title = "RIFTERMATH / cathedral visual verification"
	set_meta("battle_mode", 0)
	game = load("res://scenes/battle.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	player = game.get_node("Player")
	capture = player.get_node("GestureCapture")
	native_guard = INPUT_GUARD.new()
	root.add_child(native_guard)
	player.invulnerability = 10000
	await frames(12)
	var observer := Camera3D.new()
	game.add_child(observer)
	observer.global_position = Vector3(49, 34, 48)
	observer.look_at(Vector3(0, 3, 0))
	observer.fov = 73
	observer.make_current()
	await frames(3)
	await snapshot("01-gothic-cathedral")
	var director := game.get_node("MatchDirector") as MatchDirector
	var bot := director.actors[1] as CombatBot
	observer.global_position = bot.global_position + Vector3(3, 2.8, 5)
	observer.look_at(bot.global_position + Vector3.UP * 2.7)
	observer.fov = 64
	await frames(2)
	await snapshot("02-crooked-anatomy")
	var seen_drawing := false
	for i in range(330):
		await frames(1)
		for actor in director.actors:
			if actor is CombatBot and is_instance_valid(actor._telegraph):
				bot = actor
				seen_drawing = true
				break
		if seen_drawing:
			break
	if seen_drawing:
		observer.global_position = bot.global_position + Vector3(3, 3.7, 5)
		observer.look_at(bot.combat_aim_point())
		await frames(12)
		await snapshot("03-enemy-drawing")
	expect(seen_drawing, "Live bot draws a spatial rift during actual navigation")
	await frames(180)
	observer.global_position = Vector3(18, 14, 28)
	observer.look_at(Vector3(0, 3, 0))
	observer.fov = 72
	await frames(2)
	await snapshot("04-mobile-deathmatch")
	var travelled := 0.0
	var casts := 0
	for actor in director.actors:
		if actor is CombatBot:
			travelled += actor.distance_travelled
			casts += actor.casts_completed
	expect(travelled > 25 and casts > 0, "GPU match contains moving, attacking bots")
	var pose := Transform3D(Basis.IDENTITY, Vector3(8, 6, 11))
	var gesture := GestureRecognizer.recognize(GestureRecognizer.template(&"FANG"), 0.3)
	var fang := RiftCaster.cast(game, gesture, pose, pose.origin, player)
	observer.global_position = Vector3(10, 7, 14)
	observer.look_at(Vector3(8, 6, 11))
	observer.fov = 60
	await frames(5)
	await snapshot("05-fang-fracture")
	await frames(12)
	await snapshot("06-fang-shards")
	player.camera.make_current()
	player.global_position = Vector3(0, 3.1, 5)
	player.rotation.y = 0
	player.head.rotation.x = 0
	game.hud.show_help = true
	await frames(3)
	await snapshot("07-shape-help")
	game.hud.show_help = false
	game.hud.show_scoreboard = true
	await frames(2)
	await snapshot("08-deathmatch-scoreboard")
	print("LIVE_VISUAL_METRICS: travelled=", travelled, " casts=", casts, " snapshots=", snapshots)
	player.set_mouse_captured(false)
	print("RIFTERMATH_LIVE_VISUAL_RESULT: %d GPU snapshots, %d failures" % [snapshots, errors])
	quit(0 if errors == 0 else 1)
