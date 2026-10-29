extends "res://tests/live_combat.gd"

const MAP_SAVE := "res://.local/cartography-qa-save.json"


func _run() -> void:
	set_meta("expedition_save_path", MAP_SAVE)
	set_meta("expedition_new_seed", 37216)
	await load_level("res://scenes/expedition.tscn")
	player.invulnerability = 10000
	var director := game.match_director as ExpeditionDirector
	check(director.profile.visited == [-1], "Only the physically visited refuge is revealed at expedition start")
	check(not director.profile.visited.has(7) and director.profile.visited.size() < director.region.districts.size(), "Unvisited districts remain unexplored")
	check(ExpeditionMap.bearing(Vector3(10, 0, -10)) == "СВ" and ExpeditionMap.bearing(Vector3(-10, 0, 10)) == "ЮЗ", "Compass diagonals use conventional north/south-first bearings")
	check(not director.track_target(88) and director.profile.tracked == -2, "Unknown waypoint IDs cannot replace the active objective")
	check(director.track_target(-1) and director.navigation_hint().contains("ХРАНИТЕЛЬ"), "Tracking the NPC exposes a live navigation hint")
	player.global_position = Vector3(0, 0.15, 28)
	player.velocity = Vector3.ZERO
	player.rotation.y = 0
	Input.action_press("move_backward")
	await frames(85)
	Input.action_release("move_backward")
	var district: Dictionary = director.region.district_at(player.global_position)
	check(player.global_position.z > 30 and district["index"] != -1 and director.profile.visited.has(int(district["index"])), "Actual FPS movement across a boundary discovers the entered district")
	check(director.profile.visited.size() == 2, "Exploration does not reveal adjacent districts by proximity alone")
	check(ExpeditionState.load_path(MAP_SAVE).visited.size() == 2, "Discovered districts are committed to the selected world's save")
	director.profile.stage = 1
	check(director.journal_targets().size() == 4 and director.track_target(1), "Accepted quest exposes its three real shrine targets")
	key(KEY_TAB)
	await frames(3)
	check(game.hud.show_scoreboard and director.map_view.visible, "Tab opens the actual exploration map control")
	var before := director.profile.tracked
	key(KEY_DOWN)
	key(KEY_ENTER)
	await frames(2)
	check(director.profile.tracked != before and ExpeditionState.load_path(MAP_SAVE).tracked == director.profile.tracked, "Map arrow/Enter input selects and persists a new waypoint")
	var from := player.global_position
	Input.action_press("move_backward")
	mouse_button(true)
	for i in range(5):
		mouse_motion(Vector2(15, 0))
		await frames(2)
	check(capture.active and player.global_position.distance_to(from) > 0.25 and director.map_view.visible, "Map allows real relative drawing and physical movement without pausing")
	mouse_button(false)
	Input.action_release("move_backward")
	key(KEY_H)
	await frames(2)
	check(game.hud.show_help and not game.hud.show_scoreboard, "Figure help replaces the map instead of hiding behind it")
	var selected := director.profile.tracked
	await load_level("res://scenes/expedition.tscn")
	director = game.match_director as ExpeditionDirector
	check(director.profile.visited.size() == 2 and director.profile.tracked == selected, "Reload restores exploration and the tracked destination")
	check(director.navigation_hint().contains("м") and director.navigation_hint() != "TAB — КАРТА И ЖУРНАЛ", "Restored waypoint produces updated distance and direction after returning to refuge")
	check(director.track_target(-2) and director.navigation_hint() == "TAB — КАРТА И ЖУРНАЛ", "Waypoint can be cleared without changing quest progress")
	player.set_mouse_captured(false)
	print("RIFTERMATH_CARTOGRAPHY_RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
