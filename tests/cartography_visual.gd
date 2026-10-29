extends "res://tests/expedition_picker_visual.gd"


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Map verification requires GPU rendering")
		quit(1)
		return
	output = ProjectSettings.globalize_path("res://.local/cartography-visual-qa")
	DirAccess.make_dir_recursive_absolute(output)
	set_meta("expedition_save_path", "res://.local/cartography-visual-qa-save.json")
	set_meta("expedition_new_seed", 37216)
	game = load("res://scenes/expedition.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	player = game.get_node("Player")
	capture = player.get_node("GestureCapture")
	player.invulnerability = 10000
	player.set_mouse_captured(true)
	native_guard = INPUT_GUARD.new()
	root.add_child(native_guard)
	var director := game.match_director as ExpeditionDirector
	director._wake_clock = 10000
	for actor in director.actors:
		if actor is CombatBot: actor.set_physics_process(false)
	await frames(5)
	press(KEY_TAB)
	await frames(4)
	await snapshot("01-unexplored-refuge-map")
	expect(director.profile.visited == [-1] and director.map_view.visible, "GPU map initially reveals only the visited refuge")
	director.profile.stage = 1
	director.track_target(0)
	press(KEY_TAB)
	await frames(2)
	press(KEY_TAB)
	await frames(3)
	await snapshot("02-known-quest-unknown-districts")
	press(KEY_DOWN)
	press(KEY_ENTER)
	await frames(3)
	await snapshot("03-select-live-waypoint")
	expect(director.profile.tracked == 1, "Visible map keyboard selection tracks the actual next shrine")
	player.global_position = Vector3(0, 0.12, 28)
	player.velocity = Vector3.ZERO
	player.rotation.y = 0
	Input.action_press("move_backward")
	await frames(48)
	Input.action_release("move_backward")
	await frames(3)
	await snapshot("04-discovered-second-district")
	expect(player.global_position.z > 30 and director.profile.visited.size() == 2, "GPU exploration updates through actual walking")
	press(KEY_TAB)
	await frames(3)
	await snapshot("05-compass-during-movement")
	press(KEY_TAB)
	press(KEY_F7)
	await frames(4)
	await snapshot("06-sixteen-color-map")
	expect(color_count() <= 16 and director.map_view.visible, "The entire exploration map and UI obey sixteen-color mode")
	player.set_mouse_captured(false)
	print("RIFTERMATH_CARTOGRAPHY_VISUAL_RESULT: %d GPU snapshots, %d failures" % [snapshots, errors])
	quit(0 if errors == 0 else 1)
