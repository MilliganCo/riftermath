extends Node3D

var concrete: Material = _stone_material(Color("484d4b"), 1.0)
var dark: Material = _stone_material(Color("141917"), 1.4)
var pale: Material = _stone_material(Color("747c77"), 1.5)
var seam := _material(Color("87958d"), 0.7)
var orange := _material(Color("a4b0a7"), 0.7)


func _ready() -> void:
	_box("Foundation", Vector3(0, -0.6, 0), Vector3(108, 1.2, 112), concrete)
	_box("WestWall", Vector3(-54, 5, 0), Vector3(1.5, 10, 112), dark)
	_box("EastWall", Vector3(54, 5, 0), Vector3(1.5, 10, 112), dark)
	_box("BackWall", Vector3(0, 5, -56), Vector3(108, 10, 2), concrete)
	_box("EntryWall", Vector3(0, 4.5, 56), Vector3(108, 9, 2), dark)
	# Elevated routes with physical ramps; the central firing lane stays clear.
	_box("WestDeck", Vector3(-18, 1.5, -6), Vector3(10, 3, 24), pale)
	_box("EastDeck", Vector3(18, 2.4, -14), Vector3(10, 4.8, 18), concrete)
	_ramp("WestRamp", Vector3(-18, 0, 6), 10.0, 8.0, 3.0)
	_ramp("EastRamp", Vector3(18, 0, -5), 10.0, 12.0, 4.8)
	_box("Bridge", Vector3(0, 4.15, -22), Vector3(32, 0.7, 4), pale)
	for side in [-1.0, 1.0]:
		for z in [-47.0, -28.0, -9.0, 10.0, 29.0, 48.0]:
			_box("Buttress", Vector3(side * 52, 6.0, z), Vector3(1.0, 12, 2.0), concrete)
			_box("WallLight", Vector3(side * 51.45, 4.4, z), Vector3(0.06, 4.0, 0.12), seam, false)
		_box("DeckSeam", Vector3(side * 12.95, 3.06 if side < 0 else 4.86, -11), Vector3(0.10, 0.04, 13), seam, false)
	for x in [-8.0, 8.0]:
		_box("RunwaySeam", Vector3(x, 0.018, 0), Vector3(0.045, 0.02, 56), seam, false)
	for z in range(-48, 50, 16):
		_box("FloorJoint", Vector3(0, 0.006, z), Vector3(105, 0.008, 0.025), dark, false)
	for x in range(-48, 49, 8):
		_box("FloorJoint", Vector3(x, 0.006, 0), Vector3(0.025, 0.008, 108), dark, false)
	_box("MonolithLeft", Vector3(-9, 3.6, -7), Vector3(2.5, 7.2, 3.5), dark)
	_box("MonolithRight", Vector3(10, 2.5, 3), Vector3(2.0, 5.0, 3.0), dark)
	_box("HoverBlock", Vector3(-6, 10.0, -21), Vector3(6, 2.5, 5), dark)
	_box("HoverBlock", Vector3(12, 12.0, -28), Vector3(5, 4, 5), dark)
	_box("SlideGateTop", Vector3(-5, 1.75, 20), Vector3(6, 0.7, 2), dark)
	_box("SlideGateLeg", Vector3(-8.2, 1.0, 20), Vector3(0.4, 2, 2), pale)
	_box("SlideGateLeg", Vector3(-1.8, 1.0, 20), Vector3(0.4, 2, 2), pale)
	_sign("R I F T E R M A T H", Vector3(0, 6.5, -54.91), 0.070, Color("e2e5d7"))
	_sign("01  /  SPATIAL RESEARCH", Vector3(0, 4.9, -54.90), 0.028, Color("63d8d6"))
	_sign("SCAR   //   DRAW. RELEASE. RUPTURE.", Vector3(0, 0.035, 7), 0.018, Color("273b40"), true)
	_sign("SLIDE", Vector3(-5, 2.6, 21.03), 0.02, Color("63d8d6"), false, PI)
	for location in [Vector3(0, 0, -9), Vector3(-17, 3, -8), Vector3(16, 4.8, -15)]:
		_box("TargetPlinth", location + Vector3(0, 0.12, 0), Vector3(2.9, 0.24, 2.9), dark)
		_box("TargetMarker", location + Vector3(0, 0.25, 1.35), Vector3(2.9, 0.02, 0.09), orange, false)
	# Longer side routes open into two marked live-fire courts.
	for side in [-1.0, 1.0]:
		_box("WingGuide", Vector3(side * 35, 0.03, 16), Vector3(24, 0.02, 0.08), seam, false)
		_box("WingCover", Vector3(side * 36, 2.4, -10 if side < 0 else -25), Vector3(1.2, 4.8, 3.8), dark)
		_box("WingSpire", Vector3(side * 48, 7.0, -35), Vector3(1.3, 14, 2.0), dark)
		_box("WingSpireSeam", Vector3(side * 47.3, 7.0, -35), Vector3(0.06, 8, 0.10), orange, false)
	_sign("WEST / LIVE FIRE", Vector3(-36, 0.035, 16), 0.016, Color("ff9f47"), true)
	_sign("EAST / LIVE FIRE", Vector3(36, 0.035, 5), 0.016, Color("ff9f47"), true)
	_sign("SAFE / CENTRAL RANGE", Vector3(0, 0.035, 21), 0.013, Color("63d8d6"), true)
	WorldTheme.arches(self, 54, 56)


func _material(color: Color, emission: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.86
	if emission > 0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emission
	return mat


func _stone_material(color: Color, density: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/gothic_stone.gdshader")
	material.set_shader_parameter("base_tint", color)
	material.set_shader_parameter("stone_scale", density)
	return material


func _box(label: String, at: Vector3, size: Vector3, mat: Material, solid: bool = true) -> void:
	var node := MeshInstance3D.new()
	node.name = label
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = mat
	node.position = at
	add_child(node)
	if solid:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		node.add_child(body)
		body.add_child(collision)


func _ramp(label: String, at: Vector3, width: float, length: float, height: float, yaw: float = 0.0) -> void:
	var points := PackedVector3Array([
		Vector3(-width / 2, 0, 0), Vector3(width / 2, 0, 0),
		Vector3(-width / 2, 0, length), Vector3(width / 2, 0, length),
		Vector3(-width / 2, height, 0), Vector3(width / 2, height, 0)])
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in [4, 5, 3, 4, 3, 2, 0, 4, 2, 1, 3, 5, 0, 1, 5, 0, 5, 4, 0, 2, 3, 0, 3, 1]:
		tool.add_vertex(points[index])
	tool.generate_normals()
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = tool.commit()
	node.material_override = concrete
	node.position = at
	node.rotation.y = yaw
	add_child(node)
	var body := StaticBody3D.new()
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	var collision := CollisionShape3D.new()
	collision.shape = shape
	add_child(body)
	body.position = at
	body.rotation.y = yaw
	body.add_child(collision)


func _sign(text: String, at: Vector3, pixel: float, color: Color, floor_label: bool = false, yaw: float = 0.0) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 64
	label.pixel_size = pixel
	var luminance := color.get_luminance()
	label.modulate = Color(luminance, luminance, luminance)
	label.outline_size = 0
	label.no_depth_test = false
	label.position = at
	label.rotation.y = yaw
	if floor_label:
		label.rotation.x = -PI / 2
	add_child(label)
