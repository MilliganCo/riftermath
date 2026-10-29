extends CanvasLayer

var palette_size: int = 32
var material: ShaderMaterial


func _ready() -> void:
	layer = 100
	var screen := ColorRect.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	material = ShaderMaterial.new()
	material.shader = preload("res://shaders/palette_32.gdshader")
	screen.material = material
	add_child(screen)
	set_palette_size(palette_size)


func set_palette_size(value: int) -> void:
	palette_size = 16 if value == 16 else 32
	if material != null:
		material.set_shader_parameter("palette_size", palette_size)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F7:
		set_palette_size(16 if palette_size == 32 else 32)
		get_viewport().set_input_as_handled()
