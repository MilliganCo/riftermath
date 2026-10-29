class_name ConvexFracture
extends RefCounted

## Only our prepared convex body parts and their convex descendants are supported.
## No world meshes, concave models, CSG or third-party runtime slicer.
static func tapered_part(size: Vector3, taper: float = 0.65) -> ArrayMesh:
	var primitive := CylinderMesh.new()
	primitive.height = size.y
	primitive.bottom_radius = 0.5
	primitive.top_radius = 0.5 * taper
	primitive.radial_segments = 6
	primitive.rings = 1
	var tool := SurfaceTool.new()
	tool.append_from(primitive, 0, Transform3D(Basis.from_scale(Vector3(size.x, 1, size.z)), Vector3.ZERO))
	return tool.commit()


static func split_mesh(mesh: Mesh, cut_normal: Vector3, plane_offset: float = 0.0) -> Array[Dictionary]:
	var normal := cut_normal.normalized()
	if not normal.is_finite() or normal.length_squared() < 0.5 or not is_finite(plane_offset):
		return []
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices := PackedInt32Array()
	if arrays[Mesh.ARRAY_INDEX] != null:
		indices = arrays[Mesh.ARRAY_INDEX]
	if indices.is_empty():
		for i in range(vertices.size()):
			indices.append(i)
	var result: Array[Dictionary] = []
	for side in [-1.0, 1.0]:
		var polygons: Array[Dictionary] = []
		var cap: Array[Vector3] = []
		var all_points: Array[Vector3] = []
		for i in range(0, indices.size(), 3):
			var triangle: Array[Vector3] = [vertices[indices[i]], vertices[indices[i + 1]], vertices[indices[i + 2]]]
			var clipped := _clip(triangle, normal * side, plane_offset * side)
			if clipped.size() < 3:
				continue
			polygons.append({"points": clipped, "normal": normals[indices[i]]})
			for point in clipped:
				_unique_append(all_points, point)
				if absf(point.dot(normal) - plane_offset) < 0.0001:
					_unique_append(cap, point)
		if all_points.size() < 4 or cap.size() < 3:
			return []
		var low := Vector3.INF
		var high := -Vector3.INF
		var center := Vector3.ZERO
		var cap_center := Vector3.ZERO
		for point in all_points:
			center += point
			low = low.min(point)
			high = high.max(point)
		center /= float(all_points.size())
		var extent := high - low
		if extent.x * extent.y * extent.z < 0.0008:
			return []
		for point in cap:
			cap_center += point
		cap_center /= float(cap.size())
		var outward: Vector3 = -normal * side
		var tangent: Vector3 = outward.cross(Vector3.FORWARD if absf(outward.z) < 0.9 else Vector3.UP).normalized()
		var bitangent: Vector3 = outward.cross(tangent)
		cap.sort_custom(func(a: Vector3, b: Vector3) -> bool:
			var aa := a - cap_center
			var bb := b - cap_center
			return atan2(aa.dot(bitangent), aa.dot(tangent)) > atan2(bb.dot(bitangent), bb.dot(tangent)))
		polygons.append({"points": cap, "normal": outward})
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for polygon in polygons:
			var points: Array = polygon["points"]
			for i in range(1, points.size() - 1):
				if (points[i] - points[0]).cross(points[i + 1] - points[0]).length_squared() < 0.00000001:
					continue
				for point in [points[0], points[i], points[i + 1]]:
					tool.set_normal(polygon["normal"])
					tool.add_vertex(point - center)
		var shape := ConvexPolygonShape3D.new()
		var hull := PackedVector3Array()
		for point in all_points:
			hull.append(point - center)
		shape.points = hull
		result.append({"mesh": tool.commit(), "shape": shape, "center": center})
	return result


static func _unique_append(points: Array[Vector3], point: Vector3) -> void:
	for existing in points:
		if existing.distance_squared_to(point) < 0.00000001:
			return
	points.append(point)


static func _clip(polygon: Array[Vector3], normal: Vector3, offset: float) -> Array[Vector3]:
	var result: Array[Vector3] = []
	var previous := polygon[-1]
	var previous_distance := previous.dot(normal) - offset
	for current in polygon:
		var distance := current.dot(normal) - offset
		if (distance >= 0.0) != (previous_distance >= 0.0):
			result.append(previous.lerp(current, previous_distance / (previous_distance - distance)))
		if distance >= 0.0:
			result.append(current)
		previous = current
		previous_distance = distance
	return result
