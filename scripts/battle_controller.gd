extends "res://scripts/main.gd"


func _ready() -> void:
	_bind_gameplay()
	var navigation := BattleNavigation.new()
	navigation.name = "Navigation"
	add_child(navigation)
	navigation.configure($Arena)
	match_director = MatchDirector.new()
	match_director.name = "MatchDirector"
	add_child(match_director)
	match_director.start(self, int(get_tree().get_meta("battle_mode", 0)), navigation)
	hud.director = match_director


func show_results(result: String) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 8
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(400, 180)
	panel.custom_minimum_size = Vector2(640, 380)
	layer.add_child(panel)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 22)
	panel.add_child(layout)
	var title := Label.new()
	title.text = "MATCH COMPLETE\n" + result
	title.add_theme_font_size_override("font_size", 30)
	layout.add_child(title)
	var score := Label.new()
	score.text = match_director.board_text()
	layout.add_child(score)
	var retry := Button.new()
	retry.text = "Ещё матч / R"
	retry.pressed.connect(func(): get_tree().reload_current_scene())
	layout.add_child(retry)
	var menu := Button.new()
	menu.text = "Главное меню / M"
	menu.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/menu.tscn"))
	layout.add_child(menu)
