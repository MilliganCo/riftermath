extends "res://scripts/main.gd"

var profile: ExpeditionState


func _enter_tree() -> void:
	profile = ExpeditionState.read(get_tree())


func _ready() -> void:
	_bind_gameplay()
	var navigation := BattleNavigation.new()
	navigation.name = "Navigation"
	navigation.cell_step = 3.0
	navigation.half_cells = 30
	add_child(navigation)
	navigation.configure($Arena)
	match_director = ExpeditionDirector.new()
	match_director.name = "MatchDirector"
	add_child(match_director)
	match_director.start(self, 3, navigation)
	hud.director = match_director


func _unhandled_input(event: InputEvent) -> void:
	super._unhandled_input(event)
	if event.is_action_pressed("interact") and player.mouse_captured:
		if match_director.interact(): hud.show_scoreboard = false
	if event is InputEventKey and event.pressed and not event.echo and player.mouse_captured:
		if event.physical_keycode in [KEY_1, KEY_KP_1]: match_director.choose_rune(&"fracture")
		elif event.physical_keycode in [KEY_2, KEY_KP_2]: match_director.choose_rune(&"binding")
