class_name GothicArchitecture
extends RefCounted


static func crypt(arena: BattleArena, at: Vector3) -> void:
	for side in [-1.0, 1.0]:
		for z in [-4.0, 1.0]:
			var point := Vector2(at.x + side * 3.8, at.z + z)
			arena._cover(point, Vector2(1.0, 2.6), 0.85, at.y)
			WorldTheme._pillar(arena, Vector3(point.x, at.y + 0.85, point.y - 0.8), Vector3(point.x, at.y + 2.5, point.y - 0.8), arena.pale)
		arena._cover(Vector2(at.x + side * 5.8, at.z - 6), Vector2(0.65, 0.8), 5, at.y)
		WorldTheme._pillar(arena, at + Vector3(side * 5.8, 5, -6), at + Vector3(0, 8, -6), arena.pale)
	var altar := ConvexFracture.tapered_part(Vector3(1.1, 2.7, 0.8), 0.6)
	var statue := MeshInstance3D.new()
	statue.mesh = altar
	statue.material_override = arena.dark
	statue.position = at + Vector3(0, 1.4, -7)
	arena.add_child(statue)


static func facade(arena: BattleArena, at: Vector3, bays: int = 3) -> void:
	for i in range(bays):
		var center := at + Vector3((i - (bays - 1) * 0.5) * 5.5, 0, 0)
		for side in [-1.0, 1.0]:
			arena._cover(Vector2(center.x + side * 2, center.z), Vector2(0.65, 0.7), 8, center.y)
			WorldTheme._pillar(arena, center + Vector3(side * 2, 8, 0), center + Vector3(0, 11.5, 0), arena.pale)
			WorldTheme._pillar(arena, center + Vector3(side * 1.8, 3.5, 0), center + Vector3(side * 0.9, 6, 0), arena.concrete)
			arena._cover(Vector2(center.x + side * 1.42, center.z), Vector2(1.05, 0.7), 2.4, center.y + 5.4)
			WorldTheme._pillar(arena, center + Vector3(side * 0.95, 5.4, 0.24), center + Vector3(side * 0.95, 7.5, 0.24), arena.pale)
			WorldTheme._pillar(arena, center + Vector3(side * 0.95, 7.5, 0.24), center + Vector3(0, 9.25, 0.24), arena.pale)
			WorldTheme._pillar(arena, center + Vector3(side * 1.28, 0, 0.25), center + Vector3(side * 1.28, 2.1, 0.25), arena.concrete)
			WorldTheme._pillar(arena, center + Vector3(side * 1.28, 2.1, 0.25), center + Vector3(0, 3.0, 0.25), arena.pale)
		arena._cover(Vector2(center.x, center.z), Vector2(3.7, 0.7), 2.4, center.y + 3.0)
		var window := SurfaceTool.new()
		window.begin(Mesh.PRIMITIVE_TRIANGLES)
		var points := [Vector3(-0.9, 5.4, 0), Vector3(0.9, 5.4, 0), Vector3(0.9, 7.5, 0), Vector3(0, 9.2, 0), Vector3(-0.9, 7.5, 0)]
		for index in [0, 1, 2, 0, 2, 3, 0, 3, 4]: window.add_vertex(points[index])
		window.generate_normals()
		var pane := MeshInstance3D.new()
		pane.mesh = window.commit()
		pane.material_override = arena.dark
		pane.position = center - Vector3(0, 0, 0.18)
		arena.add_child(pane)
		arena._box("BrokenCornice", center + Vector3(0, 5, 0.2), Vector3(4.2, 0.25, 0.4), arena.concrete, false)
		arena._box("Drainpipe", center + Vector3(2.5, 3, 0), Vector3(0.12, 6, 0.12), arena.dark, false)


static func bell(parent: Node3D, at: Vector3) -> MeshInstance3D:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var heights := [0.0, 0.15, 0.55, 0.92, 1.10]
	var radii := [0.67, 0.58, 0.35, 0.25, 0.10]
	for ring in range(4):
		for i in range(12):
			var a := float(i) / 12 * TAU
			var b := float(i + 1) / 12 * TAU
			var p := Vector3(cos(a) * radii[ring], heights[ring], sin(a) * radii[ring])
			var q := Vector3(cos(b) * radii[ring], heights[ring], sin(b) * radii[ring])
			var r := Vector3(cos(a) * radii[ring + 1], heights[ring + 1], sin(a) * radii[ring + 1])
			var s := Vector3(cos(b) * radii[ring + 1], heights[ring + 1], sin(b) * radii[ring + 1])
			for point in [p, r, q, q, r, s]: tool.add_vertex(point)
	tool.generate_normals()
	var node := MeshInstance3D.new()
	node.mesh = tool.commit()
	node.position = at
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("8e795c")
	material.metallic = 0.68
	material.roughness = 0.58
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	node.material_override = material
	parent.add_child(node)
	return node
