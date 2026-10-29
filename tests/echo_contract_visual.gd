extends "res://tests/expedition_visual.gd"


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Echo contract verification needs GPU rendering")
		quit(1)
		return
	output = ProjectSettings.globalize_path("res://.local/echo-contract-visual-qa")
	DirAccess.make_dir_recursive_absolute(output)
	var state := ExpeditionState.new()
	state.path = "res://.local/echo-contract-visual-qa-save.json"
	state.seed_value = 37216
	state.stage = 3
	state.seals = [0, 1, 2]
	state.save()
	set_meta("expedition_save_path", state.path)
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
	await speak()
	await snapshot("01-scribe-and-new-contract")
	expect(director.profile.side_stage == 1, "Native scribe interaction starts the second quest")
	game.hud.dialog_remaining = 0
	var observer := Camera3D.new()
	game.add_child(observer)
	observer.fov = 66
	observer.make_current()
	var echoes: Array[CombatBot] = []
	for actor in director.actors:
		if actor is CombatBot and actor.has_meta("echo_id"):
			actor.set_physics_process(false)
			echoes.append(actor)
	var heavy := echoes[0]
	observer.global_position = heavy.global_position + Vector3(4, 3.6, 7)
	observer.look_at(heavy.combat_aim_point() + Vector3.UP * 0.7)
	await frames(4)
	await snapshot("02-bell-echo-before-wound")
	heavy.invulnerability = 0
	CombatRules.hit(heavy, heavy.hull.max_hp * 0.55, Vector3.BACK, Vector3.UP, heavy.combat_aim_point(), 74101, player, &"HYPERCUT")
	heavy._update_elite_phase()
	heavy.target = player
	heavy._begin_drawing()
	heavy._telegraph.global_transform = Transform3D(Basis.looking_at(Vector3(0, 0, 1)), heavy.combat_aim_point())
	heavy._telegraph.set_path(GestureRecognizer.template(heavy.attack_ability()))
	await frames(4)
	await snapshot("03-wounded-echo-changes-symbol")
	expect(heavy.elite_phase == 2 and heavy.attack_ability() == &"FANG", "Wounded elite visibly changes its real attack from triangle to V")
	for echo in echoes:
		echo.invulnerability = 0
		CombatRules.hit(echo, 10000, Vector3.BACK, Vector3.UP, echo.combat_aim_point(), 74102, player, &"HYPERCUT")
	player.camera.make_current()
	await speak()
	await snapshot("04-choose-one-permanent-rune")
	expect(director.profile.side_stage == 2 and game.hud.dialog_remaining > 0, "Quest return shows the explicit two-rune reward choice")
	press_key(KEY_1)
	await frames(4)
	await snapshot("05-fracture-rune-committed")
	expect(player.rune == &"fracture" and director.profile.side_stage == 3, "Native reward input commits the actual fracture build")
	game.hud.show_help = true
	await frames(3)
	await snapshot("06-rune-and-glyph-help")
	expect(color_count() <= 32, "Elite effects and rune UI preserve the global limited palette")
	player.set_mouse_captured(false)
	print("RIFTERMATH_ECHO_CONTRACT_VISUAL_RESULT: %d GPU snapshots, %d failures" % [snapshots, errors])
	quit(0 if errors == 0 else 1)


func speak() -> void:
	var scribe := (game.match_director as ExpeditionDirector).scribe
	player.global_position = scribe.global_position + Vector3(0, 0, 4.2)
	player.velocity = Vector3.ZERO
	player.set_mouse_captured(true)
	aim_at(scribe.global_position + Vector3.UP * 2.6)
	await frames(3)
	press_key(KEY_E)
	await frames(3)


func press_key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	event.set_meta("riftermath_qa", true)
	Input.parse_input_event(event)
	Input.flush_buffered_events()
