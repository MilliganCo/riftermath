class_name SpatialEffects
extends RefCounted


static func localize(gesture: Dictionary, pose: Transform3D) -> Dictionary:
	var points: PackedVector2Array = gesture["points"]
	var low := points[0]
	var high := points[0]
	for point in points:
		low = low.min(point)
		high = high.max(point)
	var center := (low + high) * 0.5
	var local_points := PackedVector2Array()
	for point in points:
		local_points.append(point - center)
	var data := gesture.duplicate()
	data["points"] = local_points
	return {"gesture": data, "pose": pose.translated_local(Vector3(center.x, center.y, 0)), "extent": high - low}


static func report(world: Node, source: Node, damage: float, killed: bool) -> void:
	if damage <= 0: return
	if source == world.get_node_or_null("Player") and world.has_node("HUD/Display"):
		world.get_node("HUD/Display").register_hit(damage, killed)


static func burst(world: Node3D, center: Vector3, radius: float, damage: float, source: Node, token: int, ability: StringName = &"SPATIAL_COMBO") -> int:
	var hits := 0
	for actor: Node3D in CombatRules.actors(world):
		if not CombatRules.can_hit(source, actor):
			continue
		var point := CombatRules.aim_point(actor)
		var distance := center.distance_to(point)
		if distance <= radius and CombatRules.clear_line(world, center, point):
			var direction := (point - center).normalized()
			var dealt := damage * (1.0 - 0.45 * distance / maxf(radius, 0.01))
			var killed := CombatRules.hit(actor, dealt, direction, Vector3.UP, point, token, source, ability)
			report(world, source, float(actor.get_meta("last_rift_damage", dealt)), killed)
			if actor is CharacterBody3D:
				actor.velocity += direction * 7.0 + Vector3.UP * 2.0
			hits += 1
	for piece: SeverableDebris in world.get_tree().get_nodes_in_group("combat_debris"):
		var offset := piece.global_position - center
		if offset.length() < radius and not piece.spent:
			piece.apply_central_impulse(offset.normalized() * 1.8 + Vector3.UP * 0.6)
	for i in range(7):
		var angle := float(i) / 7 * TAU
		var to := center + Vector3(cos(angle), sin(angle * 2.7) * 0.35, sin(angle)) * minf(radius, 3.0)
		RiftCaster.seam(world, center, to, Color("91edff"))
	return hits


static func well(parent: Node3D, radius: float, depth: float, sides: int = 20, angle_offset: float = 0.0) -> MeshInstance3D:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(sides):
		var angle := float(i) / sides * TAU + angle_offset
		var next := float(i + 1) / sides * TAU + angle_offset
		var a := Vector3(cos(angle) * radius, sin(angle) * radius, 0)
		var b := Vector3(cos(next) * radius, sin(next) * radius, 0)
		var c := Vector3(b.x * 0.72, b.y * 0.72, -depth)
		var d := Vector3(a.x * 0.72, a.y * 0.72, -depth)
		for vertex in [a, b, c, a, c, d, Vector3(0, 0, -depth), d, c]:
			tool.set_uv(Vector2(vertex.x / radius * 0.5 + 0.5, vertex.y / radius * 0.5 + 0.5))
			tool.set_uv2(Vector2.ZERO)
			tool.add_vertex(vertex)
	tool.generate_normals()
	var node := MeshInstance3D.new()
	node.mesh = tool.commit()
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/rift_void.gdshader")
	material.set_shader_parameter("aperture", 1.0)
	node.material_override = material
	parent.add_child(node)
	return node


static func crosses(pose: Transform3D, from: Vector3, to: Vector3, half_size: float) -> bool:
	var a := pose.affine_inverse() * from
	var b := pose.affine_inverse() * to
	if a.z * b.z > 0 and minf(absf(a.z), absf(b.z)) > 0.20:
		return false
	var t := clampf(a.z / (a.z - b.z), 0.0, 1.0) if absf(a.z - b.z) > 0.00001 else 0.5
	var point := a.lerp(b, t)
	return absf(point.x) <= half_size and absf(point.y) <= half_size


static func attacks(world: Node) -> Array:
	return world.get_tree().get_nodes_in_group("rift_projectiles") + world.get_tree().get_nodes_in_group("enemy_bolts")
