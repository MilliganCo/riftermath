class_name WorldTheme
extends RefCounted


static func apply(world: Node3D) -> CombatAtmosphere:
	var environment_node := world.get_node_or_null("WorldEnvironment") as WorldEnvironment
	var environment: Environment
	if environment_node != null:
		environment = environment_node.environment.duplicate(true) as Environment
		environment_node.environment = environment
	var post := CanvasLayer.new()
	post.name = "RetroWorld"
	post.layer = 0
	world.add_child(post)
	var rectangle := ColorRect.new()
	rectangle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rectangle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/retro_world.gdshader")
	rectangle.material = material
	post.add_child(rectangle)
	var atmosphere := CombatAtmosphere.new()
	atmosphere.name = "CombatAtmosphere"
	world.add_child(atmosphere)
	atmosphere.configure(world, world.get_node("Player") as PlayerController, environment, material)
	var cycle := CelestialCycle.new()
	cycle.name = "CelestialCycle"
	world.add_child(cycle)
	cycle.configure(world, atmosphere)
	return atmosphere


static func arches(arena: Node3D, half_width: float, half_length: float) -> void:
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color("373c3b")
	stone.roughness = 0.95
	for side in [-1.0, 1.0]:
		for z in range(-int(half_length) + 8, int(half_length) - 4, 12):
			var x: float = side * (half_width - 0.7)
			for edge in [-1.0, 1.0]:
				_pillar(arena, Vector3(x, 0, z + edge * 4), Vector3(x, 8, z + edge * 4), stone)
				_pillar(arena, Vector3(x, 8, z + edge * 4), Vector3(x, 12.5, z), stone)


static func _pillar(parent: Node3D, from: Vector3, to: Vector3, material: Material) -> void:
	var node := MeshInstance3D.new()
	var mesh := ConvexFracture.tapered_part(Vector3(0.65, from.distance_to(to), 0.8), 0.85)
	node.mesh = mesh
	node.position = (from + to) * 0.5
	var axis := (to - from).normalized()
	var x_axis := Vector3.FORWARD.cross(axis).normalized()
	if x_axis.length_squared() < 0.1:
		x_axis = Vector3.RIGHT.cross(axis).normalized()
	node.basis = Basis(x_axis, axis, x_axis.cross(axis))
	node.material_override = material
	parent.add_child(node)
