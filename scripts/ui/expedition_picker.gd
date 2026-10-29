class_name ExpeditionPicker
extends Control

signal selected(path: String)
var library: ExpeditionLibrary
var worlds: ItemList
var seed_entry: SpinBox
var continue_button: Button
var message: Label
var selection: int = -1


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	library = ExpeditionLibrary.read(get_tree())
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.02, 0.015, 0.95)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var panel := PanelContainer.new()
	panel.position = (get_viewport_rect().size - Vector2(800, 520)) * 0.5
	panel.size = Vector2(800, 520)
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color("171210")
	frame.border_color = Color("6f5b46")
	frame.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", frame)
	add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 22)
	panel.add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 14)
	margin.add_child(layout)
	var title := Label.new()
	title.text = "ПЕПЕЛЬНЫЕ МАРКИ / ПОХОДЫ"
	title.add_theme_font_size_override("font_size", 24)
	title.modulate = Color("e8dcc5")
	layout.add_child(title)
	worlds = ItemList.new()
	worlds.custom_minimum_size.y = 170
	worlds.add_theme_font_size_override("font_size", 18)
	layout.add_child(worlds)
	for i in range(library.entries.size()):
		var row: Dictionary = library.entries[i]
		worlds.add_item(library.label(row))
		if row["id"] == library.active_id: selection = i
	worlds.item_selected.connect(_select)
	continue_button = Button.new()
	continue_button.text = "Продолжить выбранный поход"
	continue_button.custom_minimum_size.y = 43
	layout.add_child(continue_button)
	continue_button.pressed.connect(_continue)
	var line := HBoxContainer.new()
	layout.add_child(line)
	var label := Label.new()
	label.text = "Seed нового мира: "
	line.add_child(label)
	seed_entry = SpinBox.new()
	seed_entry.min_value = 1
	seed_entry.max_value = 2147483647
	seed_entry.step = 1
	seed_entry.value = randi_range(1, 2147483647)
	seed_entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(seed_entry)
	var create := Button.new()
	create.text = "Начать новый поход / прежние миры сохранятся"
	create.custom_minimum_size.y = 43
	create.disabled = not library.writable
	create.pressed.connect(_create)
	layout.add_child(create)
	message = Label.new()
	message.text = library.error if not library.error.is_empty() else "Каждый поход хранит собственные печати, открытия и награды."
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.custom_minimum_size.y = 42
	layout.add_child(message)
	var back := Button.new()
	back.text = "Назад / Esc"
	back.pressed.connect(queue_free)
	layout.add_child(back)
	if get_parent().has_method("_style_button"):
		for button in [continue_button, create, back]: get_parent()._style_button(button)
	if selection >= 0: worlds.select(selection)
	_select(selection)


func _select(index: int) -> void:
	selection = index
	continue_button.disabled = index < 0 or not library.writable


func _continue() -> void:
	if selection < 0: return
	var id: String = library.entries[selection]["id"]
	if library.select(id): selected.emit(library.world_path(id))
	else: message.text = library.error


func _create() -> void:
	seed_entry.apply()
	var id := library.create(int(seed_entry.value))
	if id.is_empty():
		message.text = library.error
		return
	selected.emit(library.world_path(id))


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		queue_free()
		get_viewport().set_input_as_handled()
