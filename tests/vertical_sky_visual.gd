extends "res://tests/expansion_visual.gd"


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Vertical/sky verification needs a GPU")
		quit(1)
		return
	output = ProjectSettings.globalize_path("res://.local/vertical-sky-qa")
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
		if actor is CombatBot: actor.set_physics_process(false)
	var cycle := game.get_node("CelestialCycle") as CelestialCycle
	cycle.set_physics_process(false)
	cycle.phase = 0.08
	cycle.apply_cycle()
	var observer := Camera3D.new()
	game.add_child(observer)
	observer.global_position = Vector3(0, 12, 28)
	observer.look_at(observer.global_position + Vector3(0, 0.22, -1))
	observer.fov = 84
	observer.make_current()
	await frames(6)
	await snapshot("01-red-and-smaller-green-sun")
	var colors := sun_pixels()
	expect(colors.x > 100 and colors.y > 20, "GPU sky contains the real red and green solar discs")
	cycle.phase = 0.48
	cycle.apply_cycle()
	var horizon := cycle.red_direction
	horizon.y = 0.06
	observer.look_at(observer.global_position + horizon)
	await frames(4)
	await snapshot("02-red-sunset")
	cycle.phase = 0.70
	cycle.apply_cycle()
	observer.look_at(observer.global_position + Vector3(0, 0.22, -1))
	await frames(4)
	await snapshot("03-green-sun-at-night")
	expect(cycle.sun.light_energy == 0 and cycle.green_light.light_energy > 0, "Red sunset leaves dim green night lighting")
	cycle.phase = 0.08
	cycle.apply_cycle()
	observer.global_position = Vector3(54, 40, 53)
	observer.look_at(Vector3(0, 4, -2))
	observer.fov = 75
	await frames(4)
	await snapshot("04-galleries-crypt-and-bell-tower")
	var lift := get_nodes_in_group("rift_lifts")[0] as RiftLift
	player.global_position = lift.global_position + Vector3.UP * 0.15
	player.velocity = Vector3.ZERO
	player.camera.make_current()
	player.set_mouse_captured(true)
	var peak := 0.0
	for i in range(90):
		await frames(1)
		peak = maxf(peak, player.global_position.y)
		if player.global_position.y > 10.7: break
	aim_at(Vector3(0, 3, -3))
	await snapshot("05-real-rift-lift-flight")
	expect(peak > 10.7, "GPU player truly rises over ten metres using the lift")
	await frames(70)
	aim_at(Vector3(0, 3, -3))
	await snapshot("06-upper-gallery-landing")
	expect(player.is_on_floor() and player.global_position.y > 6.8, "GPU lift route lands on the actual gallery collision")
	player.global_position = Vector3(16, 11.12, -25)
	player.velocity = Vector3.ZERO
	aim_at(Vector3(0, 2, 3))
	await frames(5)
	await snapshot("07-eleven-metre-bell-roof")
	expect(player.global_position.y > 10.9 and player.is_on_floor(), "The bell tower roof is a playable upper floor")
	player.set_mouse_captured(false)
	print("SKY_GPU_METRICS: red_pixels=", colors.x, " green_pixels=", colors.y, " lift_peak=", peak)
	print("RIFTERMATH_VERTICAL_SKY_VISUAL_RESULT: %d GPU snapshots, %d failures" % [snapshots, errors])
	quit(0 if errors == 0 else 1)


func sun_pixels() -> Vector2i:
	var rendered := root.get_texture().get_image()
	var result := Vector2i.ZERO
	for y in range(90, rendered.get_height() / 2):
		for x in range(60, rendered.get_width() - 60):
			var pixel := rendered.get_pixel(x, y)
			result.x += int(pixel.r > 0.20 and pixel.r > pixel.g * 1.6 and pixel.r > pixel.b * 1.6)
			result.y += int(pixel.g > 0.20 and pixel.g > pixel.r * 1.12 and pixel.g > pixel.b * 1.12)
	return result
