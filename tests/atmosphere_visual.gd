extends "res://tests/expansion_visual.gd"


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Atmosphere visual verification requires GPU rendering.")
		quit(1)
		return
	output = ProjectSettings.globalize_path("res://.local/atmosphere-visual-qa")
	DirAccess.make_dir_recursive_absolute(output)
	root.title = "RIFTERMATH / bone, ember, soot"
	set_meta("battle_mode", 0)
	game = load("res://scenes/battle.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	player = game.get_node("Player")
	capture = player.get_node("GestureCapture")
	native_guard = INPUT_GUARD.new()
	root.add_child(native_guard)
	player.invulnerability = 10000
	player.global_position = Vector3(17, 0.1, 23)
	player.set_mouse_captured(true)
	var director := game.match_director as MatchDirector
	var locations := [Vector3(16, 0.1, 13), Vector3(24, 0.1, 3), Vector3(7, 3.1, 0)]
	for i in range(1, director.actors.size()):
		var bot := director.actors[i] as CombatBot
		# Freeze this comparison fixture so lighting, rather than actor motion, differs.
		bot.set_physics_process(false)
		bot.global_position = locations[i - 1] if i <= locations.size() else Vector3(-32, 0.1, -32)
		bot.hull.status.hide()
	aim_at(Vector3(10, 4, -2))
	await frames(10)
	var atmosphere := game.atmosphere as CombatAtmosphere
	atmosphere.set_physics_process(false)
	atmosphere.reset()
	var scar := RiftRenderer.new()
	game.add_child(scar)
	scar.global_transform = player.camera.global_transform.translated_local(Vector3(-1.5, -0.1, -4.5))
	scar.set_path(PackedVector2Array([Vector2(-0.7, -0.3), Vector2(0.65, 0.35)]))
	scar.set_tint(Color("68e9f4"))
	scar.set_opening(0.85)
	var fold := RiftRenderer.new()
	game.add_child(fold)
	fold.global_transform = player.camera.global_transform.translated_local(Vector3(1.8, 0.35, -6))
	fold.set_path(GestureRecognizer.template(&"FOLD"))
	fold.set_tint(Color("b780ff"))
	fold.set_opening(0.80)
	await frames(20)
	await snapshot("01-quiet-bone")
	var quiet := frame_metrics()
	var quiet_fov := player.camera.fov
	atmosphere.intensity = 0.53
	atmosphere.apply_visuals()
	await frames(30)
	await snapshot("02-combat-ember")
	atmosphere.intensity = 1.0
	atmosphere.apply_visuals()
	await frames(40)
	await snapshot("03-peak-soot-fog")
	var peak := frame_metrics()
	expect(player.camera.fov > quiet_fov + 9, "GPU gameplay camera widens at peak combat pressure")
	expect(quiet["warm"] > 150, "Quiet GPU frame contains the warm bone/ochre world palette")
	expect(peak["luma"] < quiet["luma"] * 0.85, "Peak GPU frame actually darkens under the denser 3D fog")
	expect(quiet["cyan"] > 10 and peak["cyan"] > 10 and peak["violet"] > 10, "Cyan and violet rifts retain distinct colour through the atmosphere grade")
	atmosphere.reset()
	await frames(40)
	await snapshot("04-recovered-clear-world")
	expect(absf(player.camera.fov - quiet_fov) < 0.5, "GPU gameplay FOV returns to its quiet setting")
	print("ATMOSPHERE_GPU_METRICS: quiet=", quiet, " peak=", peak, " quiet_fov=", quiet_fov)
	player.set_mouse_captured(false)
	print("RIFTERMATH_ATMOSPHERE_VISUAL_RESULT: %d GPU snapshots, %d failures" % [snapshots, errors])
	quit(0 if errors == 0 else 1)


func frame_metrics() -> Dictionary:
	var rendered := root.get_texture().get_image()
	var result := {"warm": 0, "cyan": 0, "violet": 0, "luma": 0.0}
	var samples := 0
	for y in range(145, rendered.get_height() - 155, 3):
		for x in range(80, rendered.get_width() - 80, 3):
			var color := rendered.get_pixel(x, y)
			result["warm"] += int(color.r > color.b + 0.025 and color.r > color.g and color.r > 0.12)
			result["cyan"] += int(color.g > color.r * 1.25 and color.b > color.r * 1.25 and color.g > 0.3)
			result["violet"] += int(color.b > color.g * 1.20 and color.r > color.g * 1.10 and color.b > 0.3)
			result["luma"] += color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722
			samples += 1
	result["luma"] /= samples
	return result
