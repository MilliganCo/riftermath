extends Control

var picker: ExpeditionPicker


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var background := ColorRect.new()
	background.color = Color("0d0b09")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for direction in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + direction, 200)
	margin.add_theme_constant_override("margin_top", 85)
	add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 15)
	margin.add_child(layout)
	var title := Label.new()
	title.text = "R I F T E R M A T H"
	title.modulate = Color("e8dcc5")
	title.add_theme_font_size_override("font_size", 48)
	var title_font := SystemFont.new()
	title_font.font_names = PackedStringArray(["Georgia", "Times New Roman"])
	title_font.font_weight = 700
	title.add_theme_font_override("font", title_font)
	layout.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "THE SEVERED CATHEDRAL\nТела принадлежат праху. Цвет принадлежит разлому."
	subtitle.modulate = Color("b6aa95")
	layout.add_child(subtitle)
	for i in range(3):
		var button := Button.new()
		button.text = ["Каждый за себя  /  Deathmatch", "Команда на команду  /  Team Deathmatch", "Один против всех  /  Survival"][i]
		button.custom_minimum_size.y = 64
		button.add_theme_font_size_override("font_size", 23)
		_style_button(button)
		button.pressed.connect(_start_match.bind(i))
		layout.add_child(button)
	var training := Button.new()
	training.text = "Тренировочный полигон"
	training.custom_minimum_size.y = 52
	_style_button(training)
	training.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main.tscn"))
	layout.add_child(training)
	var expedition := Button.new()
	expedition.text = "Пепельные марки / экспедиция и продолжение пути"
	expedition.custom_minimum_size.y = 54
	_style_button(expedition)
	expedition.pressed.connect(_open_expeditions)
	layout.add_child(expedition)
	var controls := Label.new()
	controls.text = "Локальные матчи с ботами.  ЛКМ — рисовать.  ПКМ — парировать.\nWASD / Space x2 / Shift / Ctrl     H — фигуры     Tab — счёт     M — меню"
	controls.add_theme_font_size_override("font_size", 16)
	layout.add_child(controls)


func _style_button(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("1d1914")
	normal.border_color = Color("796b58")
	normal.set_border_width_all(1)
	normal.content_margin_left = 24
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("342a20")
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)


func _start_match(mode: int) -> void:
	get_tree().set_meta("battle_mode", mode)
	get_tree().change_scene_to_file("res://scenes/battle.tscn")


func _open_expeditions() -> void:
	if is_instance_valid(picker) and not picker.is_queued_for_deletion(): return
	picker = ExpeditionPicker.new()
	add_child(picker)
	picker.selected.connect(_launch_expedition)


func _launch_expedition(path: String) -> void:
	get_tree().set_meta("expedition_save_path", path)
	get_tree().change_scene_to_file("res://scenes/expedition.tscn")
