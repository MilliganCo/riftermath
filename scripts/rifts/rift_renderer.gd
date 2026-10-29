class_name RiftRenderer
extends Node3D

@export var half_aperture: float = 0.12
@export var cavity_depth: float = 0.30
@export var sample_count: int = 30

var points := PackedVector2Array()
var opening: float = 0.45
var tint := Color(0.36, 0.96, 1.0)
var mesh_instance: MeshInstance3D
var _materials: Array[ShaderMaterial] = []
var _dirty: bool = false
var _echo_remaining: float = -1.0
var _echo_duration: float = 0.15


func _ready() -> void:
	mesh_instance = MeshInstance3D.new()
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh_instance)
	for shader_path in ["res://shaders/rift_void.gdshader", "res://shaders/rift_edge.gdshader", "res://shaders/rift_bank.gdshader"]:
		var material := ShaderMaterial.new()
		material.shader = load(shader_path)
		_materials.append(material)


func set_path(path: PackedVector2Array) -> void:
	points = path.duplicate()
	_dirty = true


func _process(delta: float) -> void:
	if _dirty:
		_rebuild()
		_dirty = false
	if _echo_remaining >= 0.0:
		_echo_remaining -= delta
		set_opening(maxf(0.01, _echo_remaining / _echo_duration) * 0.60, 0.22)
		if _echo_remaining <= 0.0:
			queue_free()


func set_opening(value: float, energy: float = 1.0) -> void:
	opening = maxf(0.001, value)
	for material in _materials:
		material.set_shader_parameter("aperture", opening)
		material.set_shader_parameter("energy", energy)


func set_tint(color: Color) -> void:
	tint = color
	for material in _materials:
		material.set_shader_parameter("rift_tint", color)
	if _materials.size() > 1:
		_materials[1].set_shader_parameter("edge_color", color)


func echo(parent: Node) -> void:
	var ghost := RiftRenderer.new()
	parent.add_child(ghost)
	ghost.global_transform = global_transform
	ghost.set_tint(tint)
	ghost.mesh_instance.mesh = mesh_instance.mesh
	for i in range(_materials.size()):
		ghost.mesh_instance.set_surface_override_material(i, ghost._materials[i])
	ghost._echo_remaining = _echo_duration
	ghost._echo_duration = _echo_duration


func _rebuild() -> void:
	var path := GestureRecognizer.sample_path(points, mini(sample_count, maxi(7, points.size() + 5)))
	var tools: Array[SurfaceTool] = []
	for i in range(3):
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		tools.append(tool)
	var cross_sections: Array[PackedVector3Array] = []
	for i in range(path.size()):
		var previous := path[maxi(0, i - 1)]
		var next := path[mini(path.size() - 1, i + 1)]
		var tangent := (next - previous).normalized()
		if tangent.length_squared() < 0.001:
			tangent = Vector2.RIGHT
		var normal := Vector3(-tangent.y, tangent.x, 0)
		var center := Vector3(path[i].x, path[i].y, 0)
		var t := float(i) / float(path.size() - 1)
		var taper := 0.12 + 0.88 * pow(sin(t * PI), 0.42)
		var tooth := 0.72 + 0.28 * sin(float(i) * 7.31 + 1.2)
		var width := half_aperture * taper * tooth
		var asymmetry := 1.0 + 0.20 * cos(float(i) * 5.17)
		cross_sections.append(PackedVector3Array([
			center + normal * width * 1.65 + Vector3(0, 0, -0.035),
			center + normal * width + Vector3(0, 0, 0.025),
			center + normal * width * 0.22 + Vector3(0, 0, -cavity_depth * taper),
			center - normal * width * 0.22 + Vector3(0, 0, -cavity_depth * taper),
			center - normal * width * asymmetry + Vector3(0, 0, 0.015),
			center - normal * width * 1.60 * asymmetry + Vector3(0, 0, -0.065),
			center + normal * (width + 0.009) + Vector3(0, 0, 0.026),
			center + normal * (width - 0.009) + Vector3(0, 0, 0.027),
			center - normal * (width * asymmetry + 0.009) + Vector3(0, 0, 0.016),
			center - normal * (width * asymmetry - 0.009) + Vector3(0, 0, 0.017)]))

	for i in range(1, path.size()):
		var a := cross_sections[i - 1]
		var b := cross_sections[i]
		for pair in [Vector2i(1, 2), Vector2i(2, 3), Vector2i(3, 4)]:
			_quad(tools[0], a[pair.x], b[pair.x], b[pair.y], a[pair.y], path[i - 1], path[i], i, 0.0)
		for pair in [Vector2i(6, 7), Vector2i(8, 9)]:
			_quad(tools[1], a[pair.x], b[pair.x], b[pair.y], a[pair.y], path[i - 1], path[i], i, 1.0)
		for pair in [Vector2i(0, 1), Vector2i(4, 5)]:
			_quad(tools[2], a[pair.x], b[pair.x], b[pair.y], a[pair.y], path[i - 1], path[i], i, 0.4)
		if i % 2 == 0:
			_fragment(tools[2], tools[1], path[i], (path[i] - path[i - 1]).normalized(), i)
	var mesh := ArrayMesh.new()
	for i in range(tools.size()):
		tools[i].generate_normals()
		tools[i].commit(mesh)
		mesh.surface_set_material(i, _materials[i])
	mesh_instance.mesh = mesh
	# Shader opening moves vertices beyond the original bounds.
	mesh_instance.extra_cull_margin = 1.5
	set_opening(opening)


func _quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, spine_a: Vector2, spine_b: Vector2, index: int, shade: float) -> void:
	var vertices := [a, b, c, a, c, d]
	var centers := [spine_a, spine_b, spine_b, spine_a, spine_b, spine_a]
	var u := float(index) / float(sample_count)
	var uvs := [Vector2(u - 0.04, 0), Vector2(u, 0), Vector2(u, 1), Vector2(u - 0.04, 0), Vector2(u, 1), Vector2(u - 0.04, 1)]
	for i in range(6):
		tool.set_uv(uvs[i])
		tool.set_uv2(centers[i])
		tool.set_color(Color(shade, 0, 0, 1))
		tool.add_vertex(vertices[i])


func _fragment(bank: SurfaceTool, edge: SurfaceTool, center: Vector2, tangent: Vector2, index: int) -> void:
	var side := -1.0 if index % 4 == 0 else 1.0
	var normal := Vector3(-tangent.y, tangent.x, 0) * side
	var along := Vector3(tangent.x, tangent.y, 0)
	var origin := Vector3(center.x, center.y, 0) + normal * (0.22 + 0.04 * sin(index * 4.0))
	var a := origin - along * 0.045
	var b := origin + along * 0.085 + normal * 0.025
	var c := origin + normal * 0.12 + Vector3(0, 0, -0.12)
	var d := origin + Vector3(0, 0, 0.055)
	for vertex in [a, b, c, a, d, b, a, c, d, b, d, c]:
		bank.set_uv(Vector2(0, 0))
		bank.set_uv2(center)
		bank.set_color(Color(0.75, 0, 0, 1))
		bank.add_vertex(vertex)
	for vertex in [a, b, b + Vector3(0, 0, 0.008)]:
		edge.set_uv(Vector2(0.3, 0))
		edge.set_uv2(center)
		edge.set_color(Color.WHITE)
		edge.add_vertex(vertex)
