extends "res://tests/visual_probe.gd"

var errors: int = 0
var snapshots: int = 0


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Expansion visual probe requires a GPU window.")
		quit(1)
		return
	output = ProjectSettings.globalize_path("res://.local/expansion-visual-qa")
	DirAccess.make_dir_recursive_absolute(output)
	root.title = "RIFTERMATH / expansion verification"
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	player = game.get_node("Player")
	capture = player.get_node("GestureCapture")
	# Last root child receives input before the game. Ignore the user's physical
	# mouse motion while injecting marked events through the real game input path.
	native_guard = INPUT_GUARD.new()
	root.add_child(native_guard)
	await frames(20)
	player.set_mouse_captured(true)
	print("VISUAL_RENDERER: ", RenderingServer.get_video_adapter_name(), " / ", RenderingServer.get_current_rendering_method())
	var observer := Camera3D.new()
	game.add_child(observer)
	observer.global_position = Vector3(67, 59, 71)
	observer.look_at(Vector3(0, 0, -3))
	observer.fov = 72
	observer.make_current()
	await frames(3)
	await snapshot("01-expanded-arena")
	player.camera.make_current()
	player.global_position = Vector3(0, 0.05, -1)
	player.velocity = Vector3.ZERO
	await frames(8)
	await snapshot("02-elongated-enemy")
	player.head.rotation.x = -1.25
	await frames(3)
	await snapshot("03-player-body")
	player.head.rotation.x = 0
	button(true)
	motion(Vector2(260, -65))
	await frames(3)
	motion(Vector2(-460, 95))
	await frames(3)
	motion(Vector2(170, -65))
	await frames(3)
	expect(capture.active and GestureRecognizer.path_length(capture.points) > 5, "Long incision through actual mouse events")
	await snapshot("04-long-incision")
	capture.cancel()
	button(false)
	player.respawn()
	player.global_position = Vector3(0, 0.05, -1)
	player.velocity = Vector3.ZERO
	await frames(6)
	for i in range(4):
		# This scenario verifies the click/shot/collision path from a known aim.
		# Physical input or a window recapture must not change the test fixture.
		player.velocity = Vector3.ZERO
		aim_at(game.get_node("Targets").get_child(0).global_position + Vector3.UP * 2.0)
		button(true)
		await frames(1)
		button(false)
		await frames(20)
	expect(game.hud.kills >= 1, "Elongated enemy is killed through actual click input")
	var piece := big_piece()
	if is_instance_valid(piece):
		var point := piece.global_position
		observer.global_position = point + Vector3(2.7, 1.4, 4.0)
		observer.look_at(point)
		observer.fov = 68
		observer.make_current()
		await frames(2)
		await snapshot("05-airborne-fragments")
		player.camera.make_current()
		for attempt in range(2):
			piece = big_piece()
			if not is_instance_valid(piece):
				break
			var time := 0.115 + maxf(0, player.camera.global_position.distance_to(piece.global_position) - 2.0) / 48.0
			var lead := piece.global_position + piece.linear_velocity * time - Vector3.UP * 1.568 * time * time
			aim_at(lead)
			button(true)
			await frames(1)
			button(false)
			await frames(20)
			if game.hud.air_cuts > 0:
				break
		expect(game.hud.air_cuts > 0, "Airborne recut works through the player's input path")
		await snapshot("06-air-cut-feedback")
	else:
		expect(false, "Live airborne fragment available for visual check")
	player.respawn()
	player.global_position = Vector3(36, 0.05, -20)
	player.invulnerability = 0
	player.velocity = Vector3.ZERO
	await frames(65)
	observer.global_position = Vector3(52, 11, -3)
	observer.look_at(Vector3(36, 1.5, -20))
	observer.make_current()
	await frames(3)
	await snapshot("07-live-fire-court")
	player.camera.make_current()
	aim_at(Vector3(43, 2.3, -13))
	await frames(13)
	expect(game.hud.active_zone == "EAST" and player.hp < player.max_hp, "Live court damages the player and identifies the zone")
	await snapshot("08-under-fire")
	print("VISUAL_HITS: ", game.hud.hits, " KILLS: ", game.hud.kills, " AIR_CUTS: ", game.hud.air_cuts, " HP: ", player.hp)
	player.set_mouse_captured(false)
	observer.queue_free()
	print("NATIVE_MOUSE_EVENTS_FILTERED: ", native_guard.filtered)
	print("RIFTERMATH_EXPANSION_VISUAL_RESULT: %d GPU snapshots, %d failures" % [snapshots, errors])
	quit(0 if errors == 0 else 1)


func snapshot(label: String) -> void:
	await super.snapshot(label)
	snapshots += 1


func aim_at(point: Vector3) -> void:
	var direction := (point - player.camera.global_position).normalized()
	player.rotation.y = atan2(-direction.x, -direction.z)
	player.head.rotation.x = asin(clampf(direction.y, -0.99, 0.99))


func big_piece() -> SeverableDebris:
	var selected: SeverableDebris
	var volume := 0.0
	for body: SeverableDebris in get_nodes_in_group("combat_debris"):
		if body.spent or body.generation >= SeverableDebris.MAX_GENERATION:
			continue
		var size := body.geometry.get_aabb().size
		var next_volume := size.x * size.y * size.z
		if next_volume > volume:
			volume = next_volume
			selected = body
	return selected


func expect(condition: bool, label: String) -> void:
	if condition:
		print("VISUAL_PASS: ", label)
	else:
		errors += 1
		push_error("VISUAL_FAIL: " + label)
