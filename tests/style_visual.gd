extends "res://tests/expansion_visual.gd"


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Style verification needs GPU rendering")
		quit(1)
		return
	output = ProjectSettings.globalize_path("res://.local/style-visual-qa")
	DirAccess.make_dir_recursive_absolute(output)
	game = load("res://scenes/battle.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	player = game.get_node("Player")
	capture = player.get_node("GestureCapture")
	player.invulnerability = 10000
	native_guard = INPUT_GUARD.new()
	root.add_child(native_guard)
	for actor in game.match_director.actors:
		if actor is CombatBot:
			actor.set_physics_process(false)
	game.get_node("RiftInteractions").set_physics_process(false)
	var observer := Camera3D.new()
	game.add_child(observer)
	observer.global_position = Vector3(1, 7, 18)
	observer.look_at(Vector3(1, 5, 0))
	observer.fov = 67
	observer.make_current()
	var abilities := [&"SCAR", &"FANG", &"CHAINBREAK", &"HOLLOW", &"SIMPLEX", &"FOLD", &"HYPERCUT"]
	for i in range(abilities.size()):
		var at := Vector3(-8 + i * 3, 5, 0)
		var data := GestureRecognizer.recognize(GestureRecognizer.template(abilities[i]), 0.4)
		var attack := RiftCaster.cast(game, data, Transform3D(Basis.IDENTITY, at), at, player)
		attack.set_physics_process(false)
	await frames(10)
	await snapshot("01-seven-muted-colors-32")
	var colors32 := color_count()
	expect(colors32 <= 32 and colors32 >= 16, "Entire GPU frame including UI and rifts uses no more than 32 colors")
	var palette := root.get_node("RetroPalette")
	var event := InputEventKey.new()
	event.physical_keycode = KEY_F7
	event.pressed = true
	event.set_meta("riftermath_qa", true)
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await frames(4)
	await snapshot("02-seven-muted-colors-16")
	var colors16 := color_count()
	expect(palette.palette_size == 16 and colors16 <= 16, "F7 really switches the complete GPU frame to sixteen colors")
	palette.set_palette_size(32)
	game.hud.show_help = true
	await frames(4)
	await snapshot("03-readable-glyph-legend")
	game.hud.show_help = false
	for index in [4, 5, 6]:
		var bot := game.match_director.actors[index] as CombatBot
		observer.global_position = bot.global_position + Vector3(3, 3.2, 6)
		observer.look_at(bot.global_position + Vector3.UP * 3.0)
		bot.traits.step(0.1)
		await frames(3)
		await snapshot("archetype-%d" % index)
	print("PALETTE_GPU_METRICS: colors32=", colors32, " colors16=", colors16)
	player.set_mouse_captured(false)
	print("RIFTERMATH_STYLE_VISUAL_RESULT: %d GPU snapshots, %d failures" % [snapshots, errors])
	quit(0 if errors == 0 else 1)


func color_count() -> int:
	var rendered := root.get_texture().get_image()
	rendered.convert(Image.FORMAT_RGB8)
	var data := rendered.get_data()
	var colors: Dictionary = {}
	for i in range(0, data.size(), 3):
		var color := (int(data[i]) << 16) | (int(data[i + 1]) << 8) | int(data[i + 2])
		colors[color] = true
	return colors.size()
