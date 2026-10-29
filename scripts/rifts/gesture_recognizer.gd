class_name GestureRecognizer
extends RefCounted

const MIN_SCAR_LENGTH: float = 0.44
const MAX_SCAR_LENGTH: float = 9.0


static func recognize(raw: PackedVector2Array, duration: float) -> Dictionary:
	var clean := PackedVector2Array()
	for point in raw:
		if point.is_finite() and (clean.is_empty() or clean[-1].distance_to(point) >= 0.02):
			clean.append(point)
	var length := path_length(clean)
	var weak := length < 0.18
	if weak:
		clean = PackedVector2Array([Vector2(-0.22, 0), Vector2(0.22, 0)])
		length = MIN_SCAR_LENGTH
	elif length > MAX_SCAR_LENGTH:
		# Trim the tail rather than scaling/recentering the entire visible gesture.
		clean = trim_path(clean, MAX_SCAR_LENGTH)
		length = MAX_SCAR_LENGTH
	return {
		"ability": &"SCAR" if weak else classify(clean), "points": clean, "length": length,
		"damage": 28.0 if weak else clampf(48.0 + length * 22.0, 48.0, 110.0),
		"weak": weak, "duration": maxf(0.0, duration)
	}


static func classify(path: PackedVector2Array) -> StringName:
	if path.size() < 3:
		return &"SCAR"
	var low := path[0]
	var high := path[0]
	for point in path:
		low = low.min(point)
		high = high.max(point)
	var diagonal := low.distance_to(high)
	if diagonal < 0.25:
		return &"SCAR"
	var length := path_length(path)
	if path[0].distance_to(path[-1]) / maxf(length, 0.001) > 0.90:
		return &"SCAR"
	var closed := path[0].distance_to(path[-1]) < diagonal * 0.26 and length > diagonal * 1.8
	var corners := simplify(path, diagonal * 0.075)
	if closed:
		if corners[0].distance_to(corners[-1]) < diagonal * 0.28:
			corners.remove_at(corners.size() - 1)
		if corners.size() == 3:
			return &"SIMPLEX"
		if corners.size() == 4:
			return &"HYPERCUT"
		if corners.size() >= 5:
			return &"HOLLOW"
	if corners.size() == 3:
		var a := corners[0]
		var b := corners[1]
		var c := corners[2]
		if b.y < minf(a.y, c.y) - (high.y - low.y) * 0.35 and absf(a.y - c.y) < (high.y - low.y) * 0.55:
			return &"FANG"
		return &"FOLD"
	if corners.size() >= 4:
		var a := (corners[1] - corners[0]).normalized()
		var b := (corners[2] - corners[1]).normalized()
		var c := (corners[3] - corners[2]).normalized()
		if a.dot(c) > 0.45 and a.dot(b) < 0.35 and a.cross(b) * b.cross(c) < -0.10:
			return &"CHAINBREAK"
	return &"SCAR"


static func simplify(path: PackedVector2Array, tolerance: float) -> PackedVector2Array:
	if path.size() < 3:
		return path.duplicate()
	var first := path[0]
	var last := path[-1]
	var line := last - first
	var greatest := 0.0
	var split := 0
	for i in range(1, path.size() - 1):
		var t := clampf((path[i] - first).dot(line) / maxf(line.length_squared(), 0.000001), 0, 1)
		var distance := path[i].distance_to(first + line * t)
		if distance > greatest:
			greatest = distance
			split = i
	if greatest <= tolerance:
		return PackedVector2Array([first, last])
	var left := simplify(path.slice(0, split + 1), tolerance)
	var right := simplify(path.slice(split), tolerance)
	left.remove_at(left.size() - 1)
	left.append_array(right)
	return left


static func template(ability: StringName) -> PackedVector2Array:
	match ability:
		&"FANG": return PackedVector2Array([Vector2(-0.8, 0.6), Vector2(0, -0.6), Vector2(0.8, 0.6)])
		&"CHAINBREAK": return PackedVector2Array([Vector2(-0.8, 0.6), Vector2(0.8, 0.6), Vector2(-0.8, -0.6), Vector2(0.8, -0.6)])
		&"SIMPLEX": return PackedVector2Array([Vector2(0, 0.9), Vector2(0.8, -0.6), Vector2(-0.8, -0.6), Vector2(0, 0.9)])
		&"HYPERCUT": return PackedVector2Array([Vector2(-0.7, 0.7), Vector2(0.7, 0.7), Vector2(0.7, -0.7), Vector2(-0.7, -0.7), Vector2(-0.7, 0.7)])
		&"FOLD": return PackedVector2Array([Vector2(-0.7, 0.7), Vector2(-0.7, -0.6), Vector2(0.8, -0.6)])
		&"HOLLOW":
			var points := PackedVector2Array()
			for i in range(25):
				points.append(Vector2(cos(float(i) / 24 * TAU), sin(float(i) / 24 * TAU)) * 0.75)
			return points
	return PackedVector2Array([Vector2(-0.75, 0), Vector2(0.75, 0)])


static func path_length(path: PackedVector2Array) -> float:
	var length := 0.0
	for i in range(1, path.size()):
		length += path[i - 1].distance_to(path[i])
	return length


static func trim_path(path: PackedVector2Array, limit: float) -> PackedVector2Array:
	var result := PackedVector2Array([path[0]])
	var remaining := limit
	for i in range(1, path.size()):
		var distance := path[i - 1].distance_to(path[i])
		if distance >= remaining:
			result.append(path[i - 1].lerp(path[i], remaining / maxf(distance, 0.0001)))
			break
		result.append(path[i])
		remaining -= distance
	return result


static func sample_path(path: PackedVector2Array, count: int) -> PackedVector2Array:
	if path.size() < 2:
		return PackedVector2Array([Vector2(-0.035, 0), Vector2(0.035, 0)])
	var length := path_length(path)
	if length < 0.001:
		return PackedVector2Array([path[0], path[0] + Vector2(0.07, 0)])
	var result := PackedVector2Array()
	var segment := 1
	var traversed := 0.0
	for i in range(count):
		var distance := length * float(i) / float(count - 1)
		while segment < path.size() - 1 and traversed + path[segment - 1].distance_to(path[segment]) < distance:
			traversed += path[segment - 1].distance_to(path[segment])
			segment += 1
		var span := path[segment - 1].distance_to(path[segment])
		result.append(path[segment - 1].lerp(path[segment], clampf((distance - traversed) / maxf(span, 0.0001), 0.0, 1.0)))
	return result
