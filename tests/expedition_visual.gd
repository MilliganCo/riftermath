extends "res://tests/style_visual.gd"


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Expedition visual verification needs GPU rendering")
		quit(1)
		return
	output = ProjectSettings.globalize_path("res://.local/expedition-visual-qa")
	DirAccess.make_dir_recursive_absolute(output)
	set_meta("expedition_save_path", "res://.local/expedition-visual-qa-save.json")
	set_meta("expedition_new_seed", 37216)
	var menu: Control = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu)
	await frames(3)
	await snapshot("01-menu-with-expedition")
	expect(menu.find_children("*", "Button", true, false).size() == 5, "Menu preserves all four previous entries and adds expedition")
	menu.queue_free()
	await frames(1)
	game = load("res://scenes/expedition.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	player = game.get_node("Player")
	capture = player.get_node("GestureCapture")
	player.invulnerability = 10000
	native_guard = INPUT_GUARD.new()
	root.add_child(native_guard)
	var director := game.match_director as ExpeditionDirector
	director._wake_clock = 10000
	for actor in director.actors:
		if actor is CombatBot: actor.set_physics_process(false)
	await talk()
	await snapshot("02-refuge-and-bellkeeper-quest")
	expect(director.profile.stage == 1 and game.hud.dialog_remaining > 0, "GPU conversation begins the actual quest")
	game.hud.dialog_remaining = 0
	game.hud.hide()
	var observer := Camera3D.new()
	game.add_child(observer)
	observer.fov = 72
	observer.make_current()
	await photo(observer, Vector3(135, 130, 138), Vector3(0, 3, 0), "03-seeded-open-region")
	var crypt: Vector3 = director.region.sites[0]["center"]
	await photo(observer, crypt + Vector3(10, 4, 14), crypt + Vector3(0, 3, -3), "04-ossuary-district")
	var borough: Vector3 = director.region.sites[1]["center"]
	await photo(observer, borough + Vector3(23, 5, 20), borough + Vector3(0, 6, -4), "05-ruined-borough-and-roofs")
	player.global_position = borough + Vector3(12, 14.12, -8)
	player.velocity = Vector3.ZERO
	player.camera.make_current()
	game.hud.show()
	aim_at(borough + Vector3(0, 3, 15))
	await frames(5)
	await snapshot("06-fourteen-metre-watchtower")
	expect(player.is_on_floor() and player.global_position.y > 13.9, "Procedural borough has a real playable fourteen-metre roof")
	observer.make_current()
	game.hud.hide()
	var ashes: Vector3 = director.region.sites[2]["center"]
	await photo(observer, ashes + Vector3(15, 8, 17), ashes + Vector3(0, 3.5, -4), "07-ashen-rift-and-spires")
	for district in director.region.districts:
		if district["index"] == 4:
			var at: Vector3 = district["center"]
			await photo(observer, at + Vector3(0, 4, 19), at + Vector3(0, 4, -2), "08-quiet-garden")
	for site in range(3):
		for actor in director.actors:
			if actor is CombatBot and int(actor.get_meta("site_index", -1)) == site:
				actor.invulnerability = 0
				CombatRules.hit(actor, 10000, Vector3.FORWARD, Vector3.UP, actor.combat_aim_point(), 778100 + site, player, &"SIMPLEX")
		var pylon := director.pylons[site]
		var at := pylon.combat_aim_point() + Vector3(0, 0, 3)
		var data := GestureRecognizer.recognize(GestureRecognizer.template(pylon.required), 0.35)
		var attack := RiftCaster.cast(game, data, Transform3D(Basis.IDENTITY, at), at, player)
		if attack is HollowField:
			attack.global_position = pylon.combat_aim_point()
			attack.age = 0.5
			await photo(observer, pylon.global_position + Vector3(4, 4, 7), pylon.combat_aim_point(), "09-real-circle-restores-seal")
		await frames(100)
	expect(director.profile.stage == 2, "Rendered quest sites respond to three actual different rift shapes")
	player.camera.make_current()
	game.hud.show()
	await talk()
	await snapshot("10-bellkeeper-vow-and-reward")
	expect(director.profile.stage == 3 and player.max_hp == 120, "GPU quest return grants the real maximum-health reward")
	var colors := color_count()
	expect(colors <= 32, "Generated world and quest interface still obey the thirty-two-color limit")
	player.set_mouse_captured(false)
	print("RIFTERMATH_EXPEDITION_VISUAL_RESULT: %d GPU snapshots, %d failures" % [snapshots, errors])
	quit(0 if errors == 0 else 1)


func photo(observer: Camera3D, from: Vector3, to: Vector3, label: String) -> void:
	observer.global_position = from
	observer.look_at(to)
	await frames(4)
	await snapshot(label)


func talk() -> void:
	var keeper := (game.match_director as ExpeditionDirector).keeper
	player.global_position = keeper.global_position + Vector3(0, 0, 4.2)
	player.velocity = Vector3.ZERO
	player.set_mouse_captured(true)
	aim_at(keeper.global_position + Vector3.UP * 2.6)
	await frames(3)
	var event := InputEventKey.new()
	event.physical_keycode = KEY_E
	event.pressed = true
	event.set_meta("riftermath_qa", true)
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await frames(3)
