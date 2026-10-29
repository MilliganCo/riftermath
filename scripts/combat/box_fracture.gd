class_name BoxFracture
extends RefCounted

## Prepared cuboid fracture only: generates two capped convex pieces along the
## stroke plane. This deliberately does not attempt to slice arbitrary world meshes.
static func split(size: Vector3, cut_normal: Vector3) -> Array[Dictionary]:
	var normal := cut_normal.normalized()
	if normal.length_squared() < 0.1:
		normal = Vector3.UP
	var box := BoxMesh.new()
	box.size = size
	var arrays := box.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var result: Array[Dictionary] = []
	for side in [-1.0, 1.0]:
		var polygons: Array[Dictionary] = []
		var cap: Array[Vector3] = []
		var all_points: Array[Vector3] = []
		for i in range(0, indices.size(), 3):
			var triangle: Array[Vector3] = [vertices[indices[i]], vertices[indices[i + 1]], vertices[indices[i + 2]]]
			var clipped := _clip(triangle, normal * side)
			if clipped.size() >= 3:
				polygons.append({"points": clipped, "normal": normals[indices[i]]})
				for point in clipped:
					all_points.append(point)
					if absf(point.dot(normal)) < 0.0001:
						var unique := true
						for existing in cap:
							if point.is_equal_approx(existing):
								unique = false
								break
						if unique:
							cap.append(point)
		var center := Vector3.ZERO
		for point in all_points:
			center += point
		center /= float(maxi(1, all_points.size()))
		var outward: Vector3 = -normal * side
		var tangent: Vector3 = outward.cross(Vector3.FORWARD if absf(outward.z) < 0.9 else Vector3.UP).normalized()
		var bitangent: Vector3 = outward.cross(tangent)
		cap.sort_custom(func(a: Vector3, b: Vector3) -> bool:
			return atan2(a.dot(bitangent), a.dot(tangent)) > atan2(b.dot(bitangent), b.dot(tangent)))
		if cap.size() >= 3:
			polygons.append({"points": cap, "normal": outward})
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for polygon in polygons:
			var points: Array = polygon["points"]
			for i in range(1, points.size() - 1):
				if (points[i] - points[0]).cross(points[i + 1] - points[0]).length_squared() < 0.000001:
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


static func _clip(polygon: Array[Vector3], normal: Vector3) -> Array[Vector3]:
	var result: Array[Vector3] = []
	var previous := polygon[-1]
	var previous_distance := previous.dot(normal)
	for current in polygon:
		var distance := current.dot(normal)
		if (distance >= 0.0) != (previous_distance >= 0.0):
			var weight := previous_distance / (previous_distance - distance)
			result.append(previous.lerp(current, weight))
		if distance >= 0.0:
			result.append(current)
		previous = current
		previous_distance = distance
	return result
