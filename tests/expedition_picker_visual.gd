extends "res://tests/style_visual.gd"


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Picker verification needs GPU rendering")
		quit(1)
		return
	output = ProjectSettings.globalize_path("res://.local/phase2-picker-qa")
	DirAccess.make_dir_recursive_absolute(output)
	var folder := "res://.local/picker-save-qa/" + str(Time.get_ticks_usec())
	set_meta("expedition_library_path", folder.path_join("index.json"))
	set_meta("expedition_worlds_dir", folder.path_join("worlds"))
	set_meta("expedition_legacy_path", folder.path_join("legacy.json"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var file := FileAccess.open(folder.path_join("legacy.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": 1, "seed": 91, "stage": 0, "seals": [], "cleared": []}))
	file.close()
	var menu: Control = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	native_guard = INPUT_GUARD.new()
	root.add_child(native_guard)
	await frames(3)
	open_picker(menu)
	await frames(4)
	var picker := menu.picker as ExpeditionPicker
	expect(picker != null and picker.worlds.item_count == 1, "Expedition entry opens a real picker containing the legacy world")
	await snapshot("01-choose-existing-or-seed")
	picker.seed_entry.get_line_edit().text = "117"
	picker._create()
	await frames(10)
	game = current_scene as Node3D
	player = game.get_node("Player")
	capture = player.get_node("GestureCapture")
	player.invulnerability = 10000
	var new_path: String = game.profile.path
	expect(game.profile.seed_value == 117 and new_path.contains("/worlds/"), "New-seed UI launches a real independent generated world")
	await snapshot("02-new-world-117")
	press(KEY_M)
	await frames(5)
	menu = current_scene as Control
	open_picker(menu)
	await frames(4)
	picker = menu.picker as ExpeditionPicker
	expect(picker.worlds.item_count == 2 and picker.library.active_path() == new_path, "Returning to the menu preserves and selects the new expedition")
	await snapshot("03-two-preserved-expeditions")
	var legacy_index := -1
	for i in range(picker.library.entries.size()):
		if picker.library.entries[i]["id"] == "legacy": legacy_index = i
	picker._select(legacy_index)
	picker._continue()
	await frames(10)
	game = current_scene as Node3D
	player = game.get_node("Player")
	capture = player.get_node("GestureCapture")
	player.invulnerability = 10000
	expect(game.profile.seed_value == 91 and FileAccess.file_exists(new_path), "Continue loads the selected old expedition without removing the newer one")
	expect(FileAccess.file_exists(folder.path_join("legacy.json.bak")) and color_count() <= 32, "Legacy migration keeps a backup and the native UI keeps the palette limit")
	await snapshot("04-continue-legacy-world")
	player.set_mouse_captured(false)
	print("RIFTERMATH_PICKER_VISUAL_RESULT: %d GPU snapshots, %d failures" % [snapshots, errors])
	quit(0 if errors == 0 else 1)


func open_picker(menu: Control) -> void:
	for node in menu.find_children("*", "Button", true, false):
		if node.text.begins_with("Пепельные марки"):
			node.pressed.emit()
			return


func press(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	event.set_meta("riftermath_qa", true)
	Input.parse_input_event(event)
	Input.flush_buffered_events()
