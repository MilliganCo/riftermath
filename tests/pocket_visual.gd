extends "res://tests/style_visual.gd"


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Pocket visual verification needs a GPU")
		quit(1)
		return
	output = ProjectSettings.globalize_path("res://.local/pocket-visual-qa")
	DirAccess.make_dir_recursive_absolute(output)
	game = load("res://scenes/battle.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	player = game.get_node("Player")
	capture = player.get_node("GestureCapture")
	player.invulnerability = 10000
	player.global_position = Vector3(10, 0.1, 10)
	native_guard = INPUT_GUARD.new()
	root.add_child(native_guard)
	for actor in game.match_director.actors:
		if actor is CombatBot:
			actor.set_physics_process(false)
			actor.global_position = Vector3(-32, 0.1, -32)
	var bot := game.match_director.actors[1] as CombatBot
	bot.global_position = Vector3(22, 0.1, 0)
	bot.invulnerability = 10000
	bot.hull.status.hide()
	var center := Vector3(20, 2.6, 0)
	var circle_data := GestureRecognizer.recognize(GestureRecognizer.template(&"HOLLOW"), 0.3)
	var circle := RiftCaster.cast(game, circle_data, Transform3D(Basis.IDENTITY, center), center, player) as HollowField
	circle.age = 0.5
	var triangle_data := GestureRecognizer.recognize(GestureRecognizer.template(&"SIMPLEX"), 0.3)
	var triangle := RiftCaster.cast(game, triangle_data, Transform3D(Basis.IDENTITY, center), center, player) as SimplexProjectile
	triangle.speed = 0
	var observer := Camera3D.new()
	game.add_child(observer)
	observer.global_position = center + Vector3(7, 4, 8)
	observer.look_at(center)
	observer.fov = 65
	observer.make_current()
	await frames(8)
	await snapshot("01-circle-triangle-closed-pocket")
	expect(get_nodes_in_group("spatial_pockets").size() == 1, "The rendered circle/triangle combination creates its real 3D cage")
	var pocket := get_nodes_in_group("spatial_pockets")[0] as SpatialPocket
	var shot_data := GestureRecognizer.recognize(GestureRecognizer.template(&"SCAR"), 0.3)
	var shot := RiftCaster.cast(game, shot_data, Transform3D(Basis.IDENTITY, center + Vector3(0, 0, 1)), center + Vector3(0, 0, 1), bot) as RiftProjectile
	shot.speed = 18
	await frames(4)
	observer.global_position = center + Vector3(-6, 3, 7)
	observer.look_at(center)
	await snapshot("02-held-spatial-cut-and-parallax")
	expect(pocket.snared.size() == 1 and not shot.is_physics_processing(), "GPU pocket holds a real cavity-shaped hostile cut")
	for i in range(200):
		await frames(1)
		if not is_instance_valid(pocket): break
	await snapshot("03-pressure-release")
	expect(is_instance_valid(shot) and shot.reflected and shot.get_source() == player, "GPU collapse releases the attack with its new ownership")
	await frames(75)
	await snapshot("04-pocket-cleanup")
	expect(get_nodes_in_group("spatial_pockets").is_empty() and color_count() <= 32, "Pocket geometry cleans up and the world retains its limited palette")
	player.set_mouse_captured(false)
	print("RIFTERMATH_POCKET_VISUAL_RESULT: %d GPU snapshots, %d failures" % [snapshots, errors])
	quit(0 if errors == 0 else 1)
