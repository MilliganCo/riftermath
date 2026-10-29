extends "res://tests/live_visual.gd"


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Advanced visual test requires GPU rendering.")
		quit(1)
		return
	output = ProjectSettings.globalize_path("res://.local/advanced-visual-qa")
	DirAccess.make_dir_recursive_absolute(output)
	var menu: Control = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu)
	await frames(3)
	await snapshot("01-mode-selection")
	var buttons: Array[Node] = menu.find_children("*", "Button", true, false)
	expect(buttons.size() == 5, "Menu offers three match modes, training, and the new expedition")
	menu.queue_free()
	await frames(1)
	set_meta("battle_mode", 1)
	game = load("res://scenes/battle.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	player = game.get_node("Player")
	capture = player.get_node("GestureCapture")
	native_guard = INPUT_GUARD.new()
	root.add_child(native_guard)
	player.invulnerability = 10000
	var director := game.get_node("MatchDirector") as MatchDirector
	for actor in director.actors:
		if actor is CombatBot:
			actor._attack_cooldown = 10000
	await frames(10)
	var observer := Camera3D.new()
	game.add_child(observer)
	observer.fov = 62
	observer.make_current()
	for ability in [&"HOLLOW", &"SIMPLEX", &"FOLD", &"HYPERCUT"]:
		var at := Vector3(20, 5.5, 9)
		var data := GestureRecognizer.recognize(GestureRecognizer.template(ability), 0.4)
		var attack := RiftCaster.cast(game, data, Transform3D(Basis.IDENTITY, at), at, player)
		if attack is HollowField:
			attack.age = 0.5
		if attack is RiftProjectile:
			attack.set_physics_process(false)
		observer.global_position = at + Vector3(1.5, 1.1, 3.4)
		observer.look_at(at)
		await frames(6)
		await snapshot(String(ability).to_lower())
		expect(is_instance_valid(attack), String(ability) + " is a real rendered 3D object")
		attack.queue_free()
		await frames(2)
	var bot := director.actors[4] as CombatBot
	observer.global_position = bot.global_position + Vector3(3, 2.7, 5)
	observer.look_at(bot.global_position + Vector3.UP * 2.7)
	game.get_node("HUD/Display").hide()
	bot.hull.status.hide()
	await frames(2)
	await snapshot("06-connected-creature")
	game.get_node("HUD/Display").show()
	bot.hull.status.show()
	player.camera.make_current()
	game.hud.show_scoreboard = true
	await frames(2)
	await snapshot("07-team-scoreboard")
	game.hud.show_scoreboard = false
	player.set_mouse_captured(false)
	print("RIFTERMATH_ADVANCED_VISUAL_RESULT: %d GPU snapshots, %d failures" % [snapshots, errors])
	quit(0 if errors == 0 else 1)
