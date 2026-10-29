class_name ExpeditionMap
extends Control

var director: ExpeditionDirector
var selection: int = 0
var _font: Font
const INK := Color("e8dcc5")
const MUTED := Color("8e795c")
const MAP := Rect2(280, 190, 390, 390)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = get_parent()._font
	visible = false
	var targets := director.journal_targets()
	for i in range(targets.size()):
		if targets[i]["id"] == director.profile.tracked: selection = i


func _process(_delta: float) -> void:
	var open: bool = get_parent().show_scoreboard
	if open and not visible:
		var targets := director.journal_targets()
		for i in range(targets.size()):
			if targets[i]["id"] == director.profile.tracked: selection = i
	visible = open
	if visible: queue_redraw()


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed or event.echo: return
	var targets := director.journal_targets()
	if event.physical_keycode in [KEY_UP, KEY_DOWN]:
		selection = posmod(selection + (-1 if event.physical_keycode == KEY_UP else 1), targets.size())
	elif event.physical_keycode == KEY_ENTER:
		selection = clampi(selection, 0, targets.size() - 1)
		director.track_target(int(targets[selection]["id"]))
	elif event.physical_keycode == KEY_BACKSPACE:
		director.track_target(-2)
	else: return
	get_viewport().set_input_as_handled()


static func bearing(offset: Vector3) -> String:
	return ("С" if offset.z < -6 else ("Ю" if offset.z > 6 else "")) + ("В" if offset.x > 6 else ("З" if offset.x < -6 else ""))


func point(world: Vector3) -> Vector2:
	return MAP.position + Vector2((world.x + 96) / 192, (world.z + 96) / 192) * MAP.size


func _label(at: Vector2, text: String, size: int = 16, color: Color = INK) -> void:
	draw_string(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _draw() -> void:
	if director == null: return
	draw_rect(Rect2(250, 125, 940, 575), Color("100c0b"))
	draw_rect(Rect2(250, 125, 940, 575), MUTED, false, 1)
	_label(Vector2(280, 160), "ПЕПЕЛЬНЫЕ МАРКИ / ОТКРЫТО %d ИЗ 9" % director.profile.visited.size(), 21)
	draw_rect(MAP, Color("080706"))
	for district in director.region.districts:
		var center: Vector3 = district["center"]
		var top := point(center - Vector3(30, 0, 30))
		var box := Rect2(top, MAP.size * 60.0 / 192.0)
		var known: bool = director.profile.visited.has(int(district["index"]))
		draw_rect(box.grow(-2), Color("3b2d23") if known and district["hostile"] else (Color("281e18") if known else Color("100c0b")))
		if known:
			_label(point(center) + Vector2(-26, 30), "ОПАСНО" if district["hostile"] else "ТИХО", 11, MUTED)
		else:
			_label(point(center) + Vector2(-5, 5), "?", 19, MUTED)
	for deck in director.region.decks:
		var bounds: Rect2 = deck["rect"]
		var center := Vector3(bounds.get_center().x, 0, bounds.get_center().y)
		if not director.profile.visited.has(int(director.region.district_at(center)["index"])): continue
		var origin := point(Vector3(bounds.position.x, 0, bounds.position.y))
		draw_rect(Rect2(origin, bounds.size / 192 * MAP.size), MUTED, false, 1)
	for obstacle: Rect2 in director.region.obstacles:
		var center := Vector3(obstacle.get_center().x, 0, obstacle.get_center().y)
		if not director.profile.visited.has(int(director.region.district_at(center)["index"])): continue
		draw_rect(Rect2(point(Vector3(obstacle.position.x, 0, obstacle.position.y)), obstacle.size / 192 * MAP.size).grow(0.5), Color("6f5b46"))
	var targets := director.journal_targets()
	var player := director.world.get_node("Player") as PlayerController
	selection = clampi(selection, 0, targets.size() - 1)
	_label(Vector2(705, 200), "ЦЕЛИ / ENTER — ОТМЕТИТЬ", 16)
	for i in range(targets.size()):
		var target: Dictionary = targets[i]
		var at: Vector3 = target["at"]
		var map_at := point(at)
		var tint: Color = target.get("color", INK)
		var marked: bool = int(target["id"]) == director.profile.tracked
		draw_polyline(PackedVector2Array([map_at + Vector2(0, -5), map_at + Vector2(5, 0), map_at + Vector2(0, 5), map_at + Vector2(-5, 0), map_at + Vector2(0, -5)]), tint, 1.5)
		if marked: draw_circle(map_at, 9, tint, false, 1.0)
		var y := 240.0 + i * 62
		if i == selection: draw_rect(Rect2(695, y - 23, 470, 53), Color("3b2d23"))
		_label(Vector2(708, y), ("> " if marked else "") + String(target["name"]), 15, tint)
		_label(Vector2(708, y + 20), "%d м / %s / %s" % [int(player.global_position.distance_to(at)), bearing(at - player.global_position), target.get("status", "")], 12, MUTED)
	var location := point(player.global_position)
	var forward := Vector2(-sin(player.rotation.y), -cos(player.rotation.y))
	var sideways := Vector2(-forward.y, forward.x)
	draw_colored_polygon(PackedVector2Array([location + forward * 8, location - forward * 5 + sideways * 4, location - forward * 5 - sideways * 4]), Color("86b8bb"))
	_label(Vector2(MAP.get_center().x - 5, MAP.position.y - 8), "С", 14)
	_label(Vector2(280, 610), "↑↓ ЦЕЛЬ / ENTER ОТМЕТИТЬ / BACKSPACE СНЯТЬ / TAB ЗАКРЫТЬ", 14)
	_label(Vector2(280, 641), "SEED %d / ОТКРЫТИЯ И ОТМЕТКА СОХРАНЯЮТСЯ" % director.profile.seed_value, 12, MUTED)
	_label(Vector2(280, 670), "Карта не останавливает движение и рисование.", 13, MUTED)
